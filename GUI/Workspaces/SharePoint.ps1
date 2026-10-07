# Przestrzeń robocza: SharePoint - biblioteki i foldery witryny (PnP.PowerShell)

Register-HTWorkspace -Key 'SharePoint' -Title 'SharePoint' -Icon 'E8F1' -Panel 'spTree' -Service 'SharePoint' `
    -Description 'Połączona witryna SharePoint (PnP): uprawnienia bibliotek i folderów, grupy, kosz, pliki, raport uprawnień, aplikacja PnP' `
    -Categories @('Uprawnienia', 'Zawartość', 'Witryna', 'Raporty')

$panel = New-HTTargetPanel -Key 'spTree' -Title 'Biblioteki i foldery' -Tree -EmptyIcon 'E8F1' -EmptyText 'Połącz z witryną SharePoint (przycisk w prawym górnym rogu).' -Describe { param($n) @{ Key = $n.ServerRelativeUrl; Title = $n.Title } }
Add-HTPanelLoader -Panel $panel -Service 'SharePoint' -Text 'Wczytaj biblioteki' -Loader {
    param($p)
    $p.pTree.Items.Clear()
    foreach ($lib in @(Get-HTSPLibraries)) { [void]$p.pTree.Items.Add((New-HTTreeItem -Item $lib -Text "$($lib.Title) ($($lib.ItemCount))" -Icon 'E8F1' -Lazy)) }
} | Out-Null
Add-HTPanelHint -Panel $panel -Text 'Rozwiń bibliotekę, aby zobaczyć foldery. Pole wyboru - obiekt operacji (albo kliknięty element).' | Out-Null

$script:SPTreeEvents = @{
    Expanded = {
        param($s, $e)
        try {
            $node = $e.OriginalSource
            if (-not ($node -is [System.Windows.Controls.TreeViewItem])) { return }
            if ($node.Items.Count -ne 1 -or $node.Items[0].Tag -ne '__placeholder__') { return }
            $node.Items.Clear()
            Set-HTBusy -Busy $true -Text "Wczytywanie folderów: $($node.Tag.Title)…"
            try {
                foreach ($folder in @(Get-HTSPSubFolders -ServerRelativeUrl $node.Tag.ServerRelativeUrl -ListTitle $node.Tag.ListTitle)) {
                    [void]$node.Items.Add((New-HTTreeItem -Item $folder -Text $folder.Title -Icon 'E8B7' -Lazy))
                }
            }
            finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        }
        catch {
            Write-Log -Message "Wczytywanie folderów: $($_.Exception.Message)" -Type 'Error'
            Show-HTError 'Nie udało się wczytać folderów.' $_
        }
    }
    Checked  = {
        param($s, $e)
        try { if ($e.OriginalSource -is [System.Windows.Controls.CheckBox]) { Update-HTTargetCount (Get-HTPanel 'spTree') } } catch { Write-Verbose $_ }
    }
}
$panel.pTree.AddHandler([System.Windows.Controls.TreeViewItem]::ExpandedEvent, [System.Windows.RoutedEventHandler]$script:SPTreeEvents.Expanded)
$panel.pTree.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]$script:SPTreeEvents.Checked)

function Get-HTSPNodeLabel { param($n) [string]$n.ServerRelativeUrl }

#region Uprawnienia
Register-HTModule -Workspace 'SharePoint' -Category 'Uprawnienia' -Key 'sp.perms' -Title 'Uprawnienia' -Icon 'E8D7' `
    -Description 'Kto ma dostęp do biblioteki / folderu i czy uprawnienia są dziedziczone. Nadawanie i odbieranie uprawnień, zarządzanie dziedziczeniem.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż uprawnienia' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Uprawnienia' -AlwaysShowObject -Label { param($t) Get-HTSPNodeLabel $t } -Action {
            param($t)
            foreach ($p in @(Get-HTSPPermissions -Node $t)) {
                [PSCustomObject]@{ Podmiot = $p.Principal; Typ = $p.PrincipalType; Uprawnienia = $p.Roles; Unikalne = $p.Unique; Login = $p.LoginName; __assignment = $p }
            }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Nadaj uprawnienia…' -Icon 'E8FA' -OnClick {
        param($m)
        $targets = @(Get-HTTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        Set-HTBusy -Busy $true -Text 'Pobieranie poziomów uprawnień…'
        try {
            $roles = @(Get-HTSPRoleDefinitions)
            $groups = @(Get-HTSPGroups | ForEach-Object { $_.Title })
        }
        finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        $form = Show-HTFormDialog -Title 'Nadaj uprawnienia' -Description "Obiekty: $($targets.Count). Nadanie uprawnień obiektowi z dziedziczeniem przerywa dziedziczenie." -Icon 'E8D7' -OkText 'Nadaj' -Fields @(
            @{ Name = 'Type'; Label = 'Rodzaj podmiotu'; Type = 'Combo'; Options = @('Użytkownik lub grupa zabezpieczeń (e-mail)', 'Grupa SharePoint') }
            @{ Name = 'Principal'; Label = 'Podmiot (e-mail, login lub nazwa grupy SharePoint)'; Type = 'Combo'; Editable = $true; Options = $groups; Required = $true }
            @{ Name = 'Role'; Label = 'Poziom uprawnień'; Type = 'Combo'; Options = $roles }
        )
        if (-not $form) { return }
        $type = if ($form.Type -like 'Grupa SharePoint*') { 'SharePointGroup' } else { 'User' }
        Invoke-HTTargetAction -Module $m -Name 'Nadanie uprawnień' -Targets $targets -Label { param($t) Get-HTSPNodeLabel $t } -Action {
            param($t)
            Grant-HTSPPermission -Node $t -Principal $form.Principal -PrincipalType $type -Role $form.Role
            "$($form.Principal): $($form.Role)"
        }
    } | Out-Null
    $row2 = Add-HTToolbarRow -Module $m -Title 'Dziedziczenie'
    $m.C.Copy = Add-HTCheckBox -Parent $row2 -Text 'Kopiuj obecne uprawnienia' -Checked $true
    Add-HTButton -Parent $row2 -Module $m -Text 'Przerwij dziedziczenie' -Icon 'E71A' -OnClick {
        param($m)
        $copy = Test-HTChecked $m.C.Copy
        Invoke-HTTargetAction -Module $m -Name 'Przerwanie dziedziczenia' -Confirm 'Przerwać dziedziczenie uprawnień wybranych obiektów?' -Label { param($t) Get-HTSPNodeLabel $t } -Action { param($t) Set-HTSPInheritance -Node $t -Inherit $false -CopyExisting $copy; 'Uprawnienia unikalne' }
    } | Out-Null
    Add-HTButton -Parent $row2 -Module $m -Text 'Przywróć dziedziczenie' -Icon 'E777' -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Przywrócenie dziedziczenia' -Danger -Confirm 'Przywrócić dziedziczenie? Unikalne uprawnienia wybranych obiektów zostaną usunięte.' -Label { param($t) Get-HTSPNodeLabel $t } -Action { param($t) Set-HTSPInheritance -Node $t -Inherit $true; 'Dziedziczone' }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Odbierz uprawnienia' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Odebranie uprawnień' -Rows @($rows | Where-Object { $_.__assignment }) -Danger -Confirm 'Odebrać zaznaczone uprawnienia?' -Label { param($r) "$($r.Obiekt): $($r.Podmiot) ($($r.Uprawnienia))" } `
            -Action { param($r) Revoke-HTSPPermission -Node $r.__target -Assignment $r.__assignment } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}
#endregion

#region Zawartość
Register-HTModule -Workspace 'SharePoint' -Category 'Zawartość' -Key 'sp.files' -Title 'Pliki' -Icon 'E8A5' `
    -Description 'Pliki w zaznaczonej bibliotece / folderze: rozmiar i daty. Prawy przycisk - otwarcie w przeglądarce.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż pliki' -Icon 'E8A5' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Pliki' -Label { param($t) Get-HTSPNodeLabel $t } -Action { param($t) Get-HTSPFolderFiles -Node $t }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Otwórz folder w przeglądarce' -Icon 'E8A7' -OnClick {
        param($m)
        foreach ($t in @(Get-HTTargets -Module $m | Select-Object -First 3)) { Start-Process (Get-HTSPAbsoluteUrl -ServerRelativeUrl $t.ServerRelativeUrl) }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Otwórz w przeglądarce' -Icon 'E8A7' -Action {
        param($m, $rows)
        foreach ($r in @($rows | Select-Object -First 5)) { Start-Process (Get-HTSPAbsoluteUrl -ServerRelativeUrl $r.ServerRelativeUrl) }
    }
}

Register-HTModule -Workspace 'SharePoint' -Category 'Zawartość' -Key 'sp.newfolder' -Title 'Nowy folder' -Icon 'E8F4' `
    -Description 'Tworzy folder w zaznaczonej bibliotece lub folderze (po utworzeniu można nadać mu osobne uprawnienia).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Nazwa folderu'
    $m.C.Name = Add-HTTextBox -Parent $row -Width 280
    Add-HTButton -Parent $row -Module $m -Text 'Utwórz' -Icon 'E8F4' -Primary -OnClick {
        param($m)
        $name = $m.C.Name.Text.Trim()
        if (-not $name) { Show-HTWarning 'Podaj nazwę folderu.'; return }
        $t = @(Get-HTTargets -Module $m -Single)[0]
        if (-not $t) { return }
        Invoke-HTTargetAction -Module $m -Name 'Nowy folder' -Targets @($t) -Label { param($t) Get-HTSPNodeLabel $t } -Action {
            param($t)
            $folder = New-HTSPFolder -ParentNode $t -Name $name
            "Utworzono: $($folder.ServerRelativeUrl)"
        }
        $m.C.Name.Text = ''
    } | Out-Null
}

Register-HTModule -Workspace 'SharePoint' -Category 'Zawartość' -Key 'sp.recycle' -Title 'Kosz witryny' -Icon 'E74D' -Service 'SharePoint' `
    -Description 'Usunięte pliki i foldery (kosz witryny i kosz zbiorczy, do 93 dni). Przywracanie - np. po przypadkowym usunięciu folderu przez użytkownika.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Filtr'
    Add-HTLabel -Parent $row -Text 'Ostatnie dni:' | Out-Null
    $m.C.Days = Add-HTNumeric -Parent $row -Value 30 -Minimum 1 -Maximum 93
    $m.C.By = Add-HTTextBox -Parent $row -Width 220 -Placeholder 'Usunięte przez (opcjonalnie)'
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż kosz' -Icon 'E72C' -Primary -OnClick {
        param($m)
        $days = Get-HTNum $m.C.Days
        $by = $m.C.By.Text.Trim()
        Invoke-HTQuery -Module $m -Name 'Kosz witryny' -ScriptBlock { Get-HTSPRecycleBinItems -Days $days -DeletedBy $by }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Przywróć' -Icon 'E777' -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Przywrócenie z kosza' -Rows $rows -Confirm 'Przywrócić zaznaczone elementy do pierwotnej lokalizacji?' -Label { param($r) "$($r.Lokalizacja)/$($r.Nazwa)" } `
            -Action { param($r) Restore-HTSPRecycleBinItem -Id $r.Id } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
    Add-HTRowAction -Module $m -Text 'Usuń trwale' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Trwałe usunięcie' -Rows $rows -Danger -TypeToConfirm 'USUŃ' -Confirm 'Trwale usunąć zaznaczone elementy z kosza?' -Label { param($r) "$($r.Lokalizacja)/$($r.Nazwa)" } `
            -Action { param($r) Clear-HTSPRecycleBinItem -Id $r.Id } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}
#endregion

#region Witryna
Register-HTModule -Workspace 'SharePoint' -Category 'Witryna' -Key 'sp.groups' -Title 'Grupy SharePoint' -Icon 'E902' -Service 'SharePoint' `
    -Description 'Grupy witryny (Właściciele, Członkowie, Odwiedzający i własne): członkowie, dodawanie i usuwanie, nowe grupy.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż grupy' -Icon 'E902' -Primary -OnClick { param($m) Invoke-HTQuery -Module $m -Name 'Grupy SharePoint' -ScriptBlock { Get-HTSPGroups | ForEach-Object { [PSCustomObject]@{ Nazwa = $_.Title; Właściciel = $_.Owner; Opis = $_.Description; Id = $_.Id } } } } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Nowa grupa…' -Icon 'E710' -OnClick {
        param($m)
        if (-not (Assert-HTConnection -Service 'SharePoint')) { return }
        $form = Show-HTFormDialog -Title 'Nowa grupa SharePoint' -Icon 'E902' -OkText 'Utwórz' -Fields @(
            @{ Name = 'Title'; Label = 'Nazwa'; Required = $true }
            @{ Name = 'Description'; Label = 'Opis' }
            @{ Name = 'Members'; Label = 'Członkowie (e-mail, jeden w linii)'; Type = 'Multiline'; Height = 80 }
        )
        if (-not $form) { return }
        Invoke-HTQuery -Module $m -Name 'Tworzenie grupy' -KeepResults -ScriptBlock {
            New-HTSPGroup -Title $form.Title -Description $form.Description -Members @(Split-HTInputList $form.Members) | Out-Null
            [PSCustomObject]@{ Nazwa = $form.Title; Właściciel = ''; Opis = 'Utworzono'; Id = '' }
        }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Członkowie' -Icon 'E716' -Action {
        param($m, $rows)
        $g = @($rows)[0]
        $members = @(Get-HTSPGroupMembers -Group $g.Nazwa)
        Show-HTDataViewer -Title "Członkowie: $($g.Nazwa)" -Description "$($members.Count) członków" -Data $members -ExportName "sp_$($g.Nazwa)"
    }
    Add-HTRowAction -Module $m -Text 'Dodaj członków…' -Icon 'E8FA' -Action {
        param($m, $rows)
        $g = @($rows)[0]
        $text = Show-InputBox -Title "Dodaj do: $($g.Nazwa)" -Prompt 'Adresy e-mail lub loginy (jeden w linii):' -Multiline -Icon 'E8FA'
        $logins = @(Split-HTInputList $text)
        if ($logins.Count -eq 0) { return }
        Invoke-HTRowAction -Module $m -Name "Dodanie do $($g.Nazwa)" -Rows $logins -Label { param($r) $r } -Action { param($r) Add-HTSPGroupMember -Group $g.Nazwa -LoginName $r }
    }
    Add-HTRowAction -Module $m -Text 'Usuń członków…' -Icon 'E738' -Danger -Action {
        param($m, $rows)
        $g = @($rows)[0]
        $members = @(Get-HTSPGroupMembers -Group $g.Nazwa)
        $selected = @(Show-HTSelectionDialog -Title "Usuń z: $($g.Nazwa)" -Items $members -MultiSelect -OkText 'Usuń')
        if ($selected.Count -eq 0) { return }
        Invoke-HTRowAction -Module $m -Name "Usunięcie z $($g.Nazwa)" -Rows $selected -Danger -Confirm 'Usunąć wybranych członków z grupy?' -Label { param($r) $r.Title } -Action { param($r) Remove-HTSPGroupMember -Group $g.Nazwa -LoginName $r.LoginName }
    }
}

Register-HTModule -Workspace 'SharePoint' -Category 'Witryna' -Key 'sp.site' -Title 'Informacje o witrynie' -Icon 'E946' -Service 'SharePoint' `
    -Description 'Adres, właściciel, administratorzy kolekcji, wykorzystanie miejsca i limit, daty utworzenia i ostatniej zmiany.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż' -Icon 'E946' -Primary -OnClick { param($m) Invoke-HTQuery -Module $m -Name 'Informacje o witrynie' -ScriptBlock { ConvertTo-HTDetailRows -Data (Get-HTSPSiteInfo) } } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Otwórz witrynę' -Icon 'E8A7' -OnClick { param($m) if (Assert-HTConnection -Service 'SharePoint') { Start-Process (Get-PnPConnection).Url } } | Out-Null
}

Register-HTModule -Workspace 'SharePoint' -Category 'Witryna' -Key 'sp.app' -Title 'Aplikacja PnP (Client ID)' -Icon 'E8D7' -Service '' `
    -Description 'PnP PowerShell wymaga własnej rejestracji aplikacji w Entra ID. Tu utworzysz ją jednym kliknięciem (Client ID zapisze się w ustawieniach) i wygenerujesz klucz tajny.' -Build {
    param($m)
    $m.SecretColumns = @('Wartość')
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Utwórz Client ID…' -Icon 'E710' -Primary -OnClick {
        param($m)
        $site = if ($Global:ConnectedToSharepointPnP) { (Get-PnPConnection).Url } else { $Global:DefaultSharepointSite }
        $result = Show-HTPnPAppRegistrationDialog -SiteUrl $site
        if ($result) {
            Reset-HTResults -Module $m
            Add-HTResultRows -Module $m -Objects @(
                [PSCustomObject]@{ Pole = 'Aplikacja'; Wartość = $result.DisplayName }
                [PSCustomObject]@{ Pole = 'Client ID'; Wartość = $result.ClientId }
                [PSCustomObject]@{ Pole = 'Tenant'; Wartość = $result.TenantId }
                [PSCustomObject]@{ Pole = 'Zgoda administratora'; Wartość = $result.ConsentGranted }
            )
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Nowy klucz tajny…' -Icon 'E8D7' -ToolTip 'Client secret dla istniejącej aplikacji (Microsoft Graph)' -OnClick { param($m) Show-HTAppSecretDialog } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Bieżący Client ID' -Icon 'E946' -OnClick {
        param($m)
        Reset-HTResults -Module $m
        Add-HTResultRows -Module $m -Objects @(
            [PSCustomObject]@{ Pole = 'Client ID (ustawienia)'; Wartość = "$($Global:LastUsedClientID)" }
            [PSCustomObject]@{ Pole = 'Zapamiętywanie Client ID'; Wartość = [bool]$Global:LogClientIDForPnP }
            [PSCustomObject]@{ Pole = 'Domyślna witryna'; Wartość = "$($Global:DefaultSharepointSite)" }
        )
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Rejestracje aplikacji (Entra)' -Icon 'E8A7' -OnClick { param($m) Start-Process 'https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade' } | Out-Null
    Add-HTLabel -Parent $row -Hint -Text 'Przeglądanie witryn bez Client ID: przestrzeń «Witryny».' | Out-Null
}
#endregion

#region Raporty
Register-HTModule -Workspace 'SharePoint' -Category 'Raporty' -Key 'sp.rep.unique' -Title 'Unikalne uprawnienia' -Icon 'E9D2' -Service 'SharePoint' `
    -Description 'Audyt: biblioteki i foldery z przerwanym dziedziczeniem oraz ich uprawnienia (wyróżnione - dostęp dla wszystkich). Zaznaczone węzły lub cała witryna.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTLabel -Parent $row -Text 'Głębokość folderów:' | Out-Null
    $m.C.Depth = Add-HTNumeric -Parent $row -Value 2 -Minimum 0 -Maximum 10
    $m.C.Scope = Add-HTSegmented -Parent $row -Items @('Cała witryna', 'Zaznaczone węzły')
    Add-HTButton -Parent $row -Module $m -Text 'Generuj raport' -Icon 'E9D2' -Primary -OnClick {
        param($m)
        $depth = Get-HTNum $m.C.Depth
        $nodes = $null
        if ((Get-HTSegmentIndex $m.C.Scope) -eq 1) {
            $nodes = @(Get-HTTargets -Module $m)
            if ($nodes.Count -eq 0) { return }
        }
        Invoke-HTQuery -Module $m -Name 'Raport unikalnych uprawnień' -ScriptBlock {
            Get-HTSPUniquePermissionsReport -Depth $depth -Nodes $nodes -OnProgress { param($path) Set-HTStatus -Text "Sprawdzanie: $path"; Update-HTUi }
        }
    } | Out-Null
}
#endregion
