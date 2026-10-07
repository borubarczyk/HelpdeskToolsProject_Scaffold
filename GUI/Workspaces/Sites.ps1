# Przestrzeń robocza: Witryny - przeglądanie witryn SharePoint w organizacji przez Microsoft Graph (bez PnP)

Register-HTWorkspace -Key 'Sites' -Title 'Witryny' -Icon 'E774' -Panel 'graphSites' -Service 'Graph' `
    -Description 'Witryny SharePoint w organizacji: szczegóły, biblioteki i zajęte miejsce, przeglądarka plików, listy, podwitryny' `
    -Categories @('Witryna', 'Zawartość', 'Połączenie')

$panel = New-HTTargetPanel -Key 'graphSites' -Title 'Witryny SharePoint' -Placeholder 'Szukaj (nazwa, adres)…' -EmptyIcon 'E774' `
    -EmptyText 'Połącz z Microsoft 365 i kliknij «Wczytaj».' -Describe {
    param($s)
    @{ Key = $s.Id; Title = $(if ($s.Nazwa) { $s.Nazwa } else { $s.Adres }); Sub = ([string]$s.Adres -replace '^https?://', ''); Dot = 'info'; Search = "$($s.Opis)" }
}
Add-HTPanelLoader -Panel $panel -Service 'Graph' -Loader { param($p) Find-HTSPSites -Search '*' } | Out-Null
Add-HTPanelButton -Panel $panel -Text 'Szukaj…' -Icon 'E721' -ToolTip 'Wyszukaj witryny w całym tenancie (Microsoft Graph)' -OnClick {
    param($p)
    if (-not (Assert-HTConnection -Service 'Graph')) { return }
    $query = Show-InputBox -Title 'Szukaj witryn' -Prompt 'Fragment nazwy lub adresu witryny:' -Icon 'E721'
    if (-not $query) { return }
    Set-HTBusy -Busy $true -Text "Szukanie witryn: $query…"
    try { Set-HTTargetItems -Panel $p -Items @(Find-HTSPSites -Search $query) }
    finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
} | Out-Null
Add-HTPanelHint -Panel $panel -Text 'Przeglądanie wymaga tylko połączenia z Microsoft 365. Zarządzanie uprawnieniami - «Połącz (PnP)».' | Out-Null

function Get-HTSiteLabel { param($s) if ($s.Nazwa) { [string]$s.Nazwa } else { [string]$s.Adres } }

#region Witryna
Register-HTModule -Workspace 'Sites' -Category 'Witryna' -Key 'sites.details' -Title 'Szczegóły witryny' -Icon 'E946' `
    -Description 'Adres, opis, daty, biblioteki z zajętym miejscem i podwitryny.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż szczegóły' -Icon 'E946' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Szczegóły witryny' -Label { param($t) Get-HTSiteLabel $t } -Action { param($t) ConvertTo-HTDetailRows -Data (Get-HTGraphSiteDetail -SiteId $t.Id) }
    } | Out-Null
}

Register-HTModule -Workspace 'Sites' -Category 'Witryna' -Key 'sites.drives' -Title 'Biblioteki i miejsce' -Icon 'EDA2' `
    -Description 'Biblioteki dokumentów z zajętym miejscem i limitem. Prawy przycisk - przeglądanie plików biblioteki.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż biblioteki' -Icon 'EDA2' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Biblioteki witryn' -Label { param($t) Get-HTSiteLabel $t } -Action { param($t) Get-HTGraphSiteDrives -SiteId $t.Id }
    } | Out-Null
    Add-HTLabel -Parent $row -Hint -Text 'Zaznacz wiele witryn, aby porównać zajęte miejsce.' | Out-Null
    Add-HTRowAction -Module $m -Text 'Przeglądaj pliki' -Icon 'E8B7' -Action {
        param($m, $rows)
        $r = @($rows)[0]
        Open-HTSiteFileBrowser -Site $r.__target -DriveId $r.DriveId
    }
    Add-HTRowAction -Module $m -Text 'Otwórz w przeglądarce' -Icon 'E8A7' -Action { param($m, $rows) foreach ($r in @($rows | Select-Object -First 5)) { Start-Process $r.Adres } }
    $m.RowDoubleClick = { param($m, $row) $r = Get-HTObjectValue $row '__obj'; if ($r.DriveId) { Open-HTSiteFileBrowser -Site $r.__target -DriveId $r.DriveId } }
}

Register-HTModule -Workspace 'Sites' -Category 'Witryna' -Key 'sites.subsites' -Title 'Podwitryny' -Icon 'E8B7' -Description 'Podwitryny (witryny podrzędne) zaznaczonych witryn.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż podwitryny' -Icon 'E8B7' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Podwitryny' -AlwaysShowObject -Label { param($t) Get-HTSiteLabel $t } -Action {
            param($t)
            $subs = @(Get-HTGraphSubsites -SiteId $t.Id)
            if ($subs.Count -eq 0) { return [PSCustomObject]@{ Nazwa = '(brak podwitryn)'; __flag = 'muted' } }
            $subs
        }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Dodaj do listy witryn' -Icon 'E710' -Action {
        param($m, $rows)
        $p = Get-HTPanel 'graphSites'
        $items = @($p.Objects.Values) + @($rows | Where-Object { $_.Id } | ForEach-Object { [PSCustomObject]@{ Nazwa = $_.Nazwa; Adres = $_.Adres; Id = $_.Id; Opis = $_.Opis; Utworzono = $_.Utworzono; 'Ostatnia zmiana' = $_.Zmodyfikowano } })
        Set-HTTargetItems -Panel $p -Items $items
        Show-HTToast 'Dodano podwitryny do listy po lewej.' 'ok'
    }
    Add-HTRowAction -Module $m -Text 'Otwórz w przeglądarce' -Icon 'E8A7' -Action { param($m, $rows) foreach ($r in @($rows | Where-Object { $_.Adres } | Select-Object -First 5)) { Start-Process $r.Adres } }
}
#endregion

#region Zawartość
function Update-HTSiteDrives {
    # Biblioteki witryny do listy wyboru przeglądarki plików
    param([Parameter(Mandatory)][hashtable]$Module, [object]$Site)
    if (-not $Site) { $Site = @(Get-HTTargets -Module $Module -Single)[0] }
    if (-not $Site) { return $false }
    Set-HTBusy -Busy $true -Text "Biblioteki witryny $(Get-HTSiteLabel $Site)…"
    try { $drives = @(Get-HTGraphSiteDrives -SiteId $Site.Id) }
    finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
    $Module.Data.Site = $Site
    $Module.Data.Drives = $drives
    $combo = $Module.C.Drive
    $combo.Items.Clear()
    foreach ($d in $drives) { [void]$combo.Items.Add("$($d.Biblioteka) ($($d.Wykorzystano))") }
    if ($combo.Items.Count -gt 0) { $combo.SelectedIndex = 0 }
    $Module.C.SiteLabel.Text = "Witryna: $(Get-HTSiteLabel $Site)"
    return ($drives.Count -gt 0)
}

function Open-HTDriveFolder {
    # Nawigacja w przeglądarce plików: -Reset (folder główny), -Up (folder nadrzędny), -Item (wejście do folderu)
    param([Parameter(Mandatory)][hashtable]$Module, [switch]$Reset, [switch]$Up, [object]$Item)
    if (-not (Assert-HTConnection -Service 'Graph')) { return }
    $selected = @(Get-HTTargets -Module $Module -Single -Quiet)[0]
    if (-not $Module.Data.Drives -or ($selected -and $Module.Data.Site -and $selected.Id -ne $Module.Data.Site.Id)) {
        if (-not (Update-HTSiteDrives -Module $Module -Site $selected)) { Show-HTWarning 'Wybierz witrynę z bibliotekami na liście po lewej.'; return }
        $Reset = $true
    }
    $index = $Module.C.Drive.SelectedIndex
    if ($index -lt 0) { return }
    $drive = $Module.Data.Drives[$index]
    if (-not $Module.Data.Stack -or $Reset -or $Module.Data.DriveId -ne $drive.DriveId) { $Module.Data.Stack = New-Object System.Collections.ArrayList }
    $Module.Data.DriveId = $drive.DriveId
    $stack = $Module.Data.Stack
    if ($Up -and $stack.Count -gt 0) { $stack.RemoveAt($stack.Count - 1) }
    if ($Item) { [void]$stack.Add(@{ Id = $Item.ItemId; Name = $Item.Nazwa }) }
    $itemId = if ($stack.Count -gt 0) { $stack[$stack.Count - 1].Id } else { 'root' }
    $path = '/' + (@($stack | ForEach-Object { $_.Name }) -join '/')
    $Module.C.Path.Text = "$($drive.Biblioteka)$path"
    $driveId = $drive.DriveId
    Invoke-HTQuery -Module $Module -Name "Pliki: $($drive.Biblioteka)$path" -ScriptBlock {
        $items = @(Get-HTGraphDriveItems -DriveId $driveId -ItemId $itemId)
        if ($items.Count -eq 0) { [PSCustomObject]@{ Nazwa = '(folder jest pusty)'; __flag = 'muted' } }
        $items
    }
}

function Open-HTSiteFileBrowser {
    # Przejście do przeglądarki plików dla witryny i biblioteki
    param([Parameter(Mandatory)][object]$Site, [string]$DriveId)
    Show-HTModule -Key 'sites.files'
    $fm = $HT_UI.Modules['sites.files']
    if (-not $fm) { return }
    if (-not (Update-HTSiteDrives -Module $fm -Site $Site)) { return }
    if ($DriveId) {
        for ($i = 0; $i -lt $fm.Data.Drives.Count; $i++) { if ($fm.Data.Drives[$i].DriveId -eq $DriveId) { $fm.C.Drive.SelectedIndex = $i; break } }
    }
    $p = Get-HTPanel 'graphSites'
    if ($p) {
        foreach ($r in $p.Table.Rows) { $r['Sel'] = ([string]$r['Key'] -eq [string]$Site.Id) }
        Update-HTTargetCount $p
    }
    Open-HTDriveFolder -Module $fm -Reset
}

Register-HTModule -Workspace 'Sites' -Category 'Zawartość' -Key 'sites.files' -Title 'Przeglądarka plików' -Icon 'E8B7' `
    -Description 'Foldery i pliki bibliotek: dwuklik na folderze - wejście, na pliku - otwarcie w przeglądarce. Prawy przycisk - pobranie pliku, kopiowanie linku.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Biblioteka'
    $m.C.Drive = Add-HTComboBox -Parent $row -Width 320
    Add-HTButton -Parent $row -Module $m -Text 'Otwórz' -Icon 'E838' -Primary -OnClick { param($m) Open-HTDriveFolder -Module $m -Reset } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Wczytaj biblioteki' -Icon 'E72C' -ToolTip 'Biblioteki witryny zaznaczonej po lewej' -OnClick { param($m) if (Update-HTSiteDrives -Module $m) { Open-HTDriveFolder -Module $m -Reset } } | Out-Null
    $m.C.SiteLabel = Add-HTLabel -Parent $row -Hint -Text 'Wybierz witrynę po lewej.'
    $row2 = Add-HTToolbarRow -Module $m -Title 'Folder'
    Add-HTButton -Parent $row2 -Module $m -Text 'W górę' -Icon 'E74A' -OnClick { param($m) Open-HTDriveFolder -Module $m -Up } | Out-Null
    Add-HTButton -Parent $row2 -Module $m -Text 'Odśwież' -Icon 'E72C' -OnClick { param($m) Open-HTDriveFolder -Module $m } | Out-Null
    $m.C.Path = Add-HTLabel -Parent $row2 -Bold -Text '/'
    $m.ResultHint = 'Dwuklik: folder - wejście, plik - otwarcie'
    $m.RowDoubleClick = {
        param($m, $row)
        $item = Get-HTObjectValue $row '__obj'
        if (-not $item -or -not $item.ItemId) { return }
        if ($item.Folder) { Open-HTDriveFolder -Module $m -Item $item }
        elseif ($item.Adres) { Start-Process $item.Adres }
    }
    Add-HTRowAction -Module $m -Text 'Otwórz w przeglądarce' -Icon 'E8A7' -Action { param($m, $rows) foreach ($r in @($rows | Where-Object { $_.Adres } | Select-Object -First 5)) { Start-Process $r.Adres } }
    Add-HTRowAction -Module $m -Text 'Pobierz…' -Icon 'E896' -Action {
        param($m, $rows)
        $files = @($rows | Where-Object { $_.ItemId -and -not $_.Folder })
        if ($files.Count -eq 0) { Show-HTWarning 'Zaznacz pliki (foldery nie są pobierane).'; return }
        if ($files.Count -eq 1) {
            $dialog = New-Object Microsoft.Win32.SaveFileDialog
            $dialog.FileName = $files[0].Nazwa
            $dialog.InitialDirectory = Get-HTExportDirectory
            if ($dialog.ShowDialog($HT_UI.Window) -ne $true) { return }
            $target = $dialog.FileName
            Invoke-HTRowAction -Module $m -Name 'Pobieranie pliku' -Rows $files -Label { param($r) $r.Nazwa } -Action { param($r) Save-HTGraphDriveItem -DriveId $r.DriveId -ItemId $r.ItemId -Path $target | Out-Null }
            Show-HTToast "Zapisano: $target" 'ok'
            return
        }
        $folder = Join-Path (Get-HTExportDirectory) ("Pobrane_{0:yyyyMMdd_HHmmss}" -f (Get-Date))
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        Invoke-HTRowAction -Module $m -Name 'Pobieranie plików' -Rows $files -Label { param($r) $r.Nazwa } -Action { param($r) Save-HTGraphDriveItem -DriveId $r.DriveId -ItemId $r.ItemId -Path (Join-Path $folder $r.Nazwa) | Out-Null }
        Start-Process -FilePath 'explorer.exe' -ArgumentList ('"{0}"' -f $folder)
    }
    Add-HTRowAction -Module $m -Text 'Kopiuj link' -Icon 'E71B' -Action {
        param($m, $rows)
        $links = @($rows | Where-Object { $_.Adres } | ForEach-Object { $_.Adres })
        if ($links) { Set-HTClipboard ($links -join "`r`n"); Show-HTToast "Skopiowano linków: $($links.Count)." 'ok' }
    }
}

Register-HTModule -Workspace 'Sites' -Category 'Zawartość' -Key 'sites.lists' -Title 'Listy i biblioteki' -Icon 'E8FD' -Description 'Listy SharePoint i biblioteki witryny z typem (szablonem) i datą ostatniej zmiany.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    $m.C.Hidden = Add-HTCheckBox -Parent $row -Text 'Także ukryte (systemowe)'
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż listy' -Icon 'E8FD' -Primary -OnClick {
        param($m)
        $hidden = Test-HTChecked $m.C.Hidden
        Invoke-HTTargetQuery -Module $m -Name 'Listy witryn' -Label { param($t) Get-HTSiteLabel $t } -Action { param($t) Get-HTGraphSiteLists -SiteId $t.Id -IncludeHidden:$hidden }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Otwórz w przeglądarce' -Icon 'E8A7' -Action { param($m, $rows) foreach ($r in @($rows | Where-Object { $_.Adres } | Select-Object -First 5)) { Start-Process $r.Adres } }
}
#endregion

#region Połączenie
Register-HTModule -Workspace 'Sites' -Category 'Połączenie' -Key 'sites.connect' -Title 'Otwórz i zarządzaj' -Icon 'E703' `
    -Description 'Otwarcie witryny w przeglądarce albo połączenie PnP PowerShell (uprawnienia, grupy, kosz - przestrzeń SharePoint).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Połącz (PnP)' -Icon 'E703' -Primary -ToolTip 'Połączenie z zaznaczoną witryną i przejście do przestrzeni SharePoint' -OnClick {
        param($m)
        $site = @(Get-HTTargets -Module $m -Single)[0]
        if (-not $site) { return }
        if (Connect-Module -Name 'PnP.PowerShell' -SiteUrl $site.Adres -NoPrompt) {
            Clear-HTPanelItems -Service 'SharePoint'
            Show-HTWorkspace -Key 'SharePoint'
            Invoke-HTPanelLoad -Panel (Get-HTPanel 'spTree') -Quiet
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Otwórz w przeglądarce' -Icon 'E8A7' -OnClick {
        param($m)
        foreach ($s in @(Get-HTTargets -Module $m | Select-Object -First 5)) { Start-Process $s.Adres }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Kopiuj adresy' -Icon 'E8C8' -OnClick {
        param($m)
        $urls = @(Get-HTTargets -Module $m | ForEach-Object { $_.Adres })
        if ($urls) { Set-HTClipboard ($urls -join "`r`n"); Show-HTToast "Skopiowano adresów: $($urls.Count)." 'ok' }
    } | Out-Null
}
#endregion
