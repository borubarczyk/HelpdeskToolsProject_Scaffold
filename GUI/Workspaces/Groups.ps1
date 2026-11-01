# Przestrzeń «Grupy i zespoły»: wszystkie grupy Microsoft 365 / Entra ID (Microsoft 365, zabezpieczeń, pocztowe) na liście
# po lewej - członkowie, właściciele, szczegóły, nowe grupy, edycja, usuwanie i przywracanie; zespoły Teams; grupy dynamiczne
# Exchange; porządki (grupy bez właściciela i bez członków).

Register-HTWorkspace -Key 'Groups' -Title 'Grupy i zespoły' -Icon 'E902' -Panel 'm365groups' -Service 'Graph' `
    -Description 'Wszystkie grupy Microsoft 365 / Entra ID: członkowie, właściciele, szczegóły, nowe grupy, edycja i usuwanie; zespoły Teams; grupy dynamiczne Exchange' `
    -Categories @('Grupa', 'Zarządzanie', 'Licencje', 'Zespoły Teams', 'Grupy dynamiczne (Exchange)', 'Raporty')

$panel = New-HTTargetPanel -Key 'm365groups' -Title 'Grupy Microsoft 365 / Entra ID' -Placeholder 'Szukaj (nazwa, adres, opis)…' -EmptyIcon 'E902' `
    -EmptyText 'Połącz z Microsoft 365 i kliknij «Wczytaj».' -Describe {
    param($g)
    $flags = @($g.Type)
    if ($g.Mail) { $flags += $g.Mail }
    if ($g.IsTeam) { $flags += 'zespół Teams' }
    if ($g.Dynamic) { $flags += 'dynamiczna' }
    if ($g.Synced) { $flags += 'z AD' }
    @{ Key = $g.Id; Title = $g.DisplayName; Sub = ($flags -join ' • ')
        Dot = $(if ($g.Synced) { 'off' } elseif ($g.Type -eq 'Microsoft 365') { 'ok' } elseif ($g.Type -eq 'Zabezpieczeń') { 'info' } else { 'warn' })
        Search = "$($g.Mail) $($g.MailNickname) $($g.Description) $($g.Type) $(if ($g.IsTeam) { 'teams zespół' })" }
}
Add-HTPanelLoader -Panel $panel -Service 'Graph' -Loader { param($p) Get-HTM365Groups } | Out-Null
Add-HTPanelHint -Panel $panel -Text 'Kropka: zielona - Microsoft 365, niebieska - zabezpieczeń, żółta - pocztowa (dystrybucyjna, zabezpieczeń z pocztą), szara - z AD.' | Out-Null

function Get-HTGroupLabel { param($g) "$($g.DisplayName)$(if ($g.Mail) { " <$($g.Mail)>" })" }

function Get-HTGroupTargetsFor {
    <#
        Grupy do zmiany członków / właścicieli: bez dynamicznych i synchronizowanych z AD (te zmienia się regułą albo w AD).
        Pominięte - ostrzeżenie z wyjaśnieniem. -Owners: także bez grup pocztowych (właściciele w Exchange).
    #>
    param([Parameter(Mandatory)][hashtable]$Module, [switch]$Owners)
    $targets = @(Get-HTChangeTargets -Module $Module)
    if (-not $targets.Count) { return @() }
    $ok = @($targets | Where-Object { if ($Owners) { Test-HTM365GroupOwnersEditable -Group $_ } else { Test-HTM365GroupManageable -Group $_ } })
    $skipped = @($targets | Where-Object { $ok -notcontains $_ })
    if ($skipped.Count) {
        $why = if ($Owners) { 'Właścicieli grup pocztowych zmienisz w Exchange > Grupy dystrybucyjne > «Ustawienia grupy…», a grup z AD - w Active Directory.' } else { 'Członkowie grup dynamicznych wynikają z reguły, a grup z AD - zmienia się w Active Directory.' }
        Show-HTWarning "Pominięto grupy ($($skipped.Count)): $(@($skipped | ForEach-Object { $_.DisplayName }) -join ', ').`n`n$why" -Title 'Grupy'
    }
    return $ok
}

#region Grupa
Register-HTModule -Workspace 'Groups' -Category 'Grupa' -Key 'grp.members' -Title 'Członkowie' -Icon 'E716' `
    -Description 'Członkowie zaznaczonych grup (użytkownicy, goście, grupy zagnieżdżone, urządzenia). Dodawanie kont z listy Microsoft 365; prawy przycisk - usunięcie z grupy. Grupy pocztowe przez Exchange.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż członków' -Icon 'E716' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Członkowie grup' -AlwaysShowObject -Label { param($t) Get-HTGroupLabel $t } -Action { param($t) Get-HTM365GroupMembers -Id $t.Id }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Dodaj członków…' -Icon 'E8FA' -Create -OnClick {
        param($m)
        $groups = @(Get-HTGroupTargetsFor -Module $m)
        if (-not $groups.Count) { return }
        $users = @(Select-HTM365User -Title 'Nowi członkowie' -Prompt "Konta dodawane do grup ($($groups.Count))." -Multi | Where-Object { $_ })
        if (-not $users.Count) { return }
        Invoke-HTTargetAction -Module $m -Name 'Dodanie członków' -Targets $groups -Label { param($t) Get-HTGroupLabel $t } -Summary "Nowi członkowie ($($users.Count)): $(@($users | Select-Object -First 15 | ForEach-Object { $_.UserPrincipalName }) -join ', ')$(if ($users.Count -gt 15) { '…' })" -Action {
            param($t)
            $added = 0; $already = 0; $errors = @()
            foreach ($u in $users) {
                try { Add-HTM365UserToGroup -Group $t -User $u; $added++ }
                catch { if ("$($_.Exception.Message)" -match 'already exist|już') { $already++ } else { $errors += "$($u.UserPrincipalName): $($_.Exception.Message)" } }
            }
            @{ Status = $(if ($errors) { 'Błąd (częściowo)' } else { 'OK' }); Szczegóły = "Dodano: $added$(if ($already) { ", już członkami: $already" })$(if ($errors) { '; ' + ($errors -join '; ') })" }
        }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Usuń z grupy' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        $rows = @($rows | Where-Object { $_.Id -and $_.__target })
        $blocked = @($rows | Where-Object { -not (Test-HTM365GroupManageable -Group $_.__target) })
        $rows = @($rows | Where-Object { $blocked -notcontains $_ })
        if ($blocked.Count) { Show-HTWarning "Pominięto członków grup dynamicznych albo z AD ($($blocked.Count)) - zmienia się regułą albo w Active Directory." -Title 'Usuń z grupy' }
        if (-not $rows.Count) { return }
        Invoke-HTRowAction -Module $m -Name 'Usunięcie z grupy' -Rows $rows -Confirm 'Usunąć zaznaczonych członków z grup?' -Label { param($r) "$($r.__target.DisplayName): $($r.Nazwa)" } -Action {
            param($r)
            Remove-HTM365UserFromGroup -Group $r.__target -User ([PSCustomObject]@{ Id = $r.Id; UserPrincipalName = $r.Adres })
            if ($r.__target.Type -notin 'Dystrybucyjna', 'Zabezpieczeń (mail)') { Register-HTUndo -Operation 'Usunięcie z grupy' -Object "$($r.Nazwa) - $($r.__target.DisplayName)" -Kind 'GroupMember' -Data @{ GroupId = $r.__target.Id; UserId = $r.Id; Added = $false } }
            'Usunięto'
        } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}

Register-HTModule -Workspace 'Groups' -Category 'Grupa' -Key 'grp.owners' -Title 'Właściciele' -Icon 'E7EF' `
    -Description 'Właściciele zaznaczonych grup (zarządzają członkami i ustawieniami). Dodawanie właścicieli z listy Microsoft 365; prawy przycisk - usunięcie. Grupy pocztowe - w Exchange.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż właścicieli' -Icon 'E7EF' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Właściciele grup' -AlwaysShowObject -Label { param($t) Get-HTGroupLabel $t } -Action {
            param($t)
            $owners = @(Get-HTM365GroupOwners -Id $t.Id)
            if ($owners.Count) { $owners } else { [PSCustomObject]@{ Nazwa = '(brak właściciela)'; Adres = ''; Rodzaj = ''; Włączone = $null; Id = ''; __flag = 'warn' } }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Dodaj właściciela…' -Icon 'E8FA' -Create -OnClick {
        param($m)
        $groups = @(Get-HTGroupTargetsFor -Module $m -Owners)
        if (-not $groups.Count) { return }
        $users = @(Select-HTM365User -Title 'Nowi właściciele' -Prompt "Właściciele grup ($($groups.Count))." -Multi | Where-Object { $_ })
        if (-not $users.Count) { return }
        Invoke-HTTargetAction -Module $m -Name 'Dodanie właściciela' -Targets $groups -Label { param($t) Get-HTGroupLabel $t } -Summary "Nowi właściciele: $(@($users | ForEach-Object { $_.UserPrincipalName }) -join ', ')" -Action {
            param($t)
            foreach ($u in $users) { try { Add-HTM365GroupOwner -GroupId $t.Id -UserId $u.Id } catch { if ("$($_.Exception.Message)" -notmatch 'already exist') { throw } } }
            "Właściciele: $(@($users | ForEach-Object { $_.UserPrincipalName }) -join ', ')"
        }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Usuń właściciela' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        $rows = @($rows | Where-Object { $_.Id -and $_.__target -and (Test-HTM365GroupOwnersEditable -Group $_.__target) })
        if (-not $rows.Count) { Show-HTWarning 'Zaznacz właścicieli grup Microsoft 365 albo zabezpieczeń (grup pocztowych - w Exchange).' -Title 'Usuń właściciela'; return }
        Invoke-HTRowAction -Module $m -Name 'Usunięcie właściciela' -Rows $rows -Confirm 'Usunąć zaznaczonych właścicieli? Grupa bez właściciela nie ma osoby, która zarządza jej członkami.' -Label { param($r) "$($r.__target.DisplayName): $($r.Nazwa)" } `
            -Action { param($r) Remove-HTM365GroupOwner -GroupId $r.__target.Id -OwnerId $r.Id; 'Usunięto' } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}

Register-HTModule -Workspace 'Groups' -Category 'Grupa' -Key 'grp.details' -Title 'Szczegóły' -Icon 'E8A1' `
    -Description 'Rodzaj, adres i alias, opis, widoczność, data utworzenia, zespół Teams, reguła grupy dynamicznej, synchronizacja z AD, liczba członków i właścicieli.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż szczegóły' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Szczegóły grup' -Label { param($t) Get-HTGroupLabel $t } -Action {
            param($t)
            $owners = @(Get-HTM365GroupOwners -Id $t.Id)
            [PSCustomObject][ordered]@{
                Grupa             = $t.DisplayName
                Rodzaj            = $t.Type
                'E-mail'          = $t.Mail
                Alias             = $t.MailNickname
                Opis              = $t.Description
                Widoczność        = $(switch ($t.Visibility) { 'Private' { 'prywatna' } 'Public' { 'publiczna' } 'HiddenMembership' { 'ukryci członkowie' } default { $t.Visibility } })
                Utworzono         = $t.Created
                'Zespół Teams'    = $t.IsTeam
                Dynamiczna        = $t.Dynamic
                Reguła            = $t.MembershipRule
                'Z AD'            = $t.Synced
                Członków          = @(Get-HTM365GroupMembers -Id $t.Id).Count
                Właściciele       = $(if ($owners.Count) { @($owners | ForEach-Object { $_.Adres }) -join ', ' } else { '(brak)' })
                Id                = $t.Id
                __flag            = $(if (-not $owners.Count -and (Test-HTM365GroupOwnersEditable -Group $t)) { 'warn' } else { '' })
            }
        }
    } | Out-Null
}
#endregion

#region Zarządzanie
Register-HTModule -Workspace 'Groups' -Category 'Zarządzanie' -Key 'grp.manage' -Title 'Nowe grupy i edycja' -Icon 'E70F' `
    -Description 'Nowa grupa zabezpieczeń albo Microsoft 365, zmiana nazwy, opisu i widoczności, usunięcie grupy (grupy Microsoft 365 - do przywrócenia przez 30 dni).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Nowa grupa…' -Icon 'E902' -Create -NoRowMenu -ToolTip 'Grupa zabezpieczeń albo Microsoft 365 - członkami mogą zostać konta wybrane w formularzu' -OnClick {
        param($m)
        $g = New-HTM365GroupInteractive
        if ($g) {
            Add-HTResultRows -Module $m -Objects @([PSCustomObject]@{ Obiekt = $g.DisplayName; Status = 'OK'; Szczegóły = "Utworzono: $($g.Type)$(if ($g.Mail) { ", $($g.Mail)" })" })
            $panel = Get-HTPanel 'm365groups'
            if ($panel) { Invoke-HTPanelLoad -Panel $panel -Quiet }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Edytuj…' -Icon 'E70F' -Danger -ToolTip 'Nazwa, opis i widoczność (grupy Microsoft 365) zaznaczonej grupy' -OnClick {
        param($m)
        $g = @(Get-HTChangeTargets -Module $m -Single)[0]
        if (-not $g) { return }
        if ($g.Synced) { Show-HTWarning 'Grupę synchronizowaną z AD edytuje się w Active Directory.' -Title 'Edycja grupy'; return }
        $fields = @(
            @{ Name = 'Name'; Label = 'Nazwa wyświetlana'; Required = $true; Default = $g.DisplayName }
            @{ Name = 'Description'; Label = 'Opis'; Default = $g.Description }
        )
        if ($g.Type -eq 'Microsoft 365') { $fields += @{ Name = 'Visibility'; Label = 'Widoczność'; Type = 'Combo'; Options = @('Prywatna', 'Publiczna'); Default = $(if ($g.Visibility -eq 'Public') { 'Publiczna' } else { 'Prywatna' }) } }
        $form = Show-HTFormDialog -Title "Grupa: $($g.DisplayName)" -Icon 'E70F' -OkText 'Dalej' -Width 600 -Fields $fields
        if (-not $form) { return }
        $changes = Get-HTM365GroupChanges -Group $g -DisplayName ([string]$form.Name) -Description ([string]$form.Description) -Visibility $(if ($form.Visibility -eq 'Publiczna') { 'Public' } elseif ($form.Visibility) { 'Private' } else { '' })
        if (-not $changes.Count) { Show-HTToast 'Bez zmian.' 'info'; return }
        Invoke-HTTargetAction -Module $m -Name 'Edycja grupy' -Targets @($g) -Label { param($t) Get-HTGroupLabel $t } -Summary @(ConvertTo-HTChangeSummary -Settings $changes -Labels @{ displayName = 'Nazwa'; description = 'Opis'; visibility = 'Widoczność' }) -Action {
            param($t)
            Set-HTM365Group -Id $t.Id -Changes $changes
            if ($changes.Contains('displayName')) { $t.DisplayName = $changes.displayName }
            if ($changes.Contains('description')) { $t.Description = $changes.description }
            if ($changes.Contains('visibility')) { $t.Visibility = $changes.visibility }
            $panel = Get-HTPanel 'm365groups'
            if ($panel) { Update-HTTargetItem -Panel $panel -Item $t }
            'Zmieniono'
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Usuń grupę' -Icon 'E74D' -Danger -ToolTip 'Usunięcie zaznaczonych grup (Microsoft 365 - do przywrócenia przez 30 dni w «Usunięte grupy»)' -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if (-not $targets.Count) { return }
        $mail = @($targets | Where-Object { $_.Type -in 'Dystrybucyjna', 'Zabezpieczeń (mail)' -or $_.Synced })
        $groups = @($targets | Where-Object { $mail -notcontains $_ })
        if ($mail.Count) { Show-HTWarning "Pominięto grupy pocztowe albo z AD ($($mail.Count)): $(@($mail | ForEach-Object { $_.DisplayName }) -join ', ') - usuń je w Exchange > Grupy dystrybucyjne albo w Active Directory." -Title 'Usuń grupę' }
        if (-not $groups.Count) { return }
        $summary = @('Grupy Microsoft 365: do przywrócenia przez 30 dni (Grupy i zespoły > Usunięte grupy) - razem z pocztą, plikami i zespołem Teams.', 'Grupy zabezpieczeń: usuwane trwale - uprawnienia nadane grupie przestaną działać.')
        Invoke-HTTargetAction -Module $m -Name 'Usunięcie grupy' -Targets $groups -Label { param($t) Get-HTGroupLabel $t } -Danger -TypeToConfirm 'USUŃ' -Summary $summary -Action {
            param($t)
            Remove-HTM365Group -Id $t.Id
            $panel = Get-HTPanel 'm365groups'
            if ($panel -and $panel.Objects.Count) { Invoke-HTPanelLoad -Panel $panel -Quiet }
            $(if ($t.Type -eq 'Microsoft 365') { 'Usunięto (do przywrócenia przez 30 dni)' } else { 'Usunięto' })
        }
    } | Out-Null
}

Register-HTModule -Workspace 'Groups' -Category 'Zarządzanie' -Key 'grp.deleted' -Title 'Usunięte grupy' -Icon 'E74D' -Service 'Graph' `
    -Description 'Grupy Microsoft 365 usunięte w ciągu ostatnich 30 dni (z pocztą, plikami i zespołem): przywrócenie albo trwałe usunięcie (prawy przycisk).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż usunięte' -Icon 'E74D' -Primary -OnClick { param($m) Invoke-HTQuery -Module $m -Name 'Usunięte grupy' -ScriptBlock { Get-HTM365DeletedGroups } } | Out-Null
    Add-HTRowAction -Module $m -Text 'Przywróć' -Icon 'E777' -Create -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Przywrócenie grupy' -Rows @($rows | Where-Object { $_.Id }) -Confirm 'Przywrócić zaznaczone grupy (z członkami, pocztą i plikami)?' -Label { param($r) $r.Grupa } `
            -Action { param($r) Restore-HTM365DeletedGroup -Id $r.Id; 'Przywrócono' } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
    Add-HTRowAction -Module $m -Text 'Usuń trwale' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Trwałe usunięcie grupy' -Rows @($rows | Where-Object { $_.Id }) -Danger -TypeToConfirm 'USUŃ' -Confirm 'Usunąć trwale zaznaczone grupy? Poczty, plików i zespołu nie da się potem odzyskać.' -Label { param($r) $r.Grupa } `
            -Action { param($r) Remove-HTM365DeletedGroup -Id $r.Id; 'Usunięto trwale' } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}
#endregion

#region Licencje grupy (licencjonowanie grupowe)
Register-HTModule -Workspace 'Groups' -Category 'Licencje' -Key 'grp.licenses' -Title 'Licencje grupy' -Icon 'E8EC' -Service 'Graph' `
    -Description 'Licencje przypisane do grupy: członkowie dostają je automatycznie, a po wyjściu z grupy tracą. Przypisywanie i usuwanie licencji grupy, członkowie z błędem przypisania (brak wolnych licencji, konflikt planów, brak lokalizacji użycia).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż licencje' -Icon 'E8EC' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Licencje grup' -AlwaysShowObject -Label { param($t) Get-HTGroupLabel $t } -Action {
            param($t)
            if (-not (Test-HTM365GroupLicensable -Group $t)) { return [PSCustomObject]@{ Licencja = '(licencje grupowe tylko dla grup zabezpieczeń i grup Microsoft 365 z zabezpieczeniami)'; SKU = ''; __flag = 'muted' } }
            $licenses = @(Get-HTM365GroupLicenses -Id $t.Id)
            if ($licenses.Count) { $licenses } else { [PSCustomObject]@{ Licencja = '(brak licencji grupowych)'; SKU = ''; __flag = 'muted' } }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Członkowie z błędem licencji' -Icon 'E7BA' -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Błędy licencji grup' -AlwaysShowObject -Label { param($t) Get-HTGroupLabel $t } -Action {
            param($t)
            $rows = @(Get-HTM365GroupLicenseErrors -Id $t.Id -GroupName $t.DisplayName)
            if ($rows.Count) { $rows } else { [PSCustomObject]@{ Użytkownik = '(brak błędów przypisania)'; __flag = 'muted' } }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Przypisz licencję…' -Icon 'E710' -Create -ToolTip 'Licencja dla grupy - wszyscy członkowie (także przyszli) dostaną ją automatycznie' -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if (-not $targets.Count) { return }
        $groups = @($targets | Where-Object { Test-HTM365GroupLicensable -Group $_ })
        $skipped = @($targets | Where-Object { $groups -notcontains $_ })
        if ($skipped.Count) { Show-HTWarning "Pominięto grupy bez licencji grupowych ($($skipped.Count)): $(@($skipped | ForEach-Object { $_.DisplayName }) -join ', ').`n`nLicencje przypisuje się grupom zabezpieczeń (także dynamicznym i z AD) i grupom Microsoft 365 z włączonymi zabezpieczeniami - nie grupom dystrybucyjnym." -Title 'Licencje grupy' }
        if (-not $groups.Count) { return }
        Set-HTBusy -Busy $true -Text 'Pobieranie licencji i członków…'
        try {
            $skus = @(Get-HTSubscribedSkus -Force | Where-Object { $_.Status -eq 'Enabled' } | ForEach-Object { [PSCustomObject]@{ Licencja = Get-HTSkuFriendlyName $_.SkuPartNumber; SKU = $_.SkuPartNumber; Dostępne = $_.Available; Przypisane = $_.Consumed; SkuId = $_.SkuId } })
            $members = 0
            foreach ($g in $groups) { $members += @(Get-HTM365GroupMembers -Id $g.Id | Where-Object { $_.Rodzaj -in 'Użytkownik', 'Gość' }).Count }
        }
        finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        $selected = Show-HTSelectionDialog -Title 'Licencja dla grupy' -Prompt "Licencje dla grup ($($groups.Count)) - członków (kont): $members." -Items $skus -MultiSelect -Icon 'E8EC'
        if (-not $selected) { return }
        $ids = @($selected | ForEach-Object { "$($_.SkuId)" })
        $names = @($selected | ForEach-Object { $_.Licencja }) -join ', '
        $short = @($selected | Where-Object { $_.Dostępne -lt $members })
        if ($short.Count -and -not (Show-HTConfirm -Warning -Title 'Za mało licencji' -Message "Członków (kont): $members, wolnych licencji: $(@($short | ForEach-Object { "$($_.Licencja) ($($_.Dostępne))" }) -join ', '). Część członków dostanie błąd przypisania (widoczny w «Członkowie z błędem licencji»). Kontynuować?")) { return }
        Invoke-HTTargetAction -Module $m -Name 'Przypisanie licencji grupie' -Targets $groups -Label { param($t) Get-HTGroupLabel $t } -Summary @("Licencje: $names", "Członkowie grup dostaną licencje automatycznie (zwykle w ciągu kilku minut); kont: $members") -Action {
            param($t)
            Set-HTM365GroupLicense -Id $t.Id -AddSkuIds $ids
            "Przypisano: $names"
        }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Usuń licencję z grupy' -Icon 'E738' -Danger -Action {
        param($m, $rows)
        $rows = @($rows | Where-Object { $_.SkuId -and $_.__target })
        if (-not $rows.Count) { Show-HTWarning 'Zaznacz licencje grup (najpierw «Pokaż licencje»).' -Title 'Usuń licencję z grupy'; return }
        Invoke-HTRowAction -Module $m -Name 'Usunięcie licencji grupy' -Rows $rows -Danger -Confirm 'Usunąć zaznaczone licencje z grup? Członkowie stracą je, o ile nie mają ich z innej grupy albo przypisanych bezpośrednio (usunięcie licencji Exchange zaczyna 30-dniowy okres usunięcia skrzynki).' `
            -Label { param($r) "$($r.__target.DisplayName): $($r.Licencja)" } -Action { param($r) Set-HTM365GroupLicense -Id $r.__target.Id -RemoveSkuIds @($r.SkuId); 'Usunięto' } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
    Add-HTRowAction -Module $m -Text 'Ponów przypisanie licencji' -Icon 'E72C' -Danger -Action {
        param($m, $rows)
        $rows = @($rows | Where-Object { $_.Id -and $_.UPN })
        if (-not $rows.Count) { Show-HTWarning 'Zaznacz członków z błędem (przycisk «Członkowie z błędem licencji»).' -Title 'Ponów przypisanie'; return }
        Invoke-HTRowAction -Module $m -Name 'Ponowne przetworzenie licencji' -Rows $rows -Label { param($r) $r.UPN } -Action { param($r) Invoke-HTLicenseReprocess -UserId $r.Id; 'Zlecono ponowne przetworzenie' }
    }
}
#endregion

#region Zespół Teams z grupy i kanały
$script:TeamChannelTypes = [ordered]@{ 'Standardowy - wszyscy członkowie zespołu' = 'standard'; 'Prywatny - tylko wybrane osoby z zespołu' = 'private'; 'Udostępniony - także osoby spoza zespołu' = 'shared' }

Register-HTModule -Workspace 'Groups' -Category 'Zespoły Teams' -Key 'grp.team' -Title 'Zespół i kanały' -Icon 'E8BD' -Service 'Graph' `
    -Description 'Kanały zespołu zaznaczonej grupy (standardowe, prywatne, udostępnione) i nowy kanał. Zespół Teams z istniejącej grupy Microsoft 365 - z jej członkami, pocztą i plikami. Prawy przycisk - usunięcie kanału.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż kanały' -Icon 'E8BD' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Kanały zespołów' -AlwaysShowObject -Label { param($t) Get-HTGroupLabel $t } -Action {
            param($t)
            if (-not $t.IsTeam) { return [PSCustomObject]@{ Kanał = $(if ($t.Type -eq 'Microsoft 365') { '(grupa bez zespołu Teams - «Utwórz zespół z grupy…»)' } else { '(zespół Teams można utworzyć tylko z grupy Microsoft 365)' }); __flag = 'muted' } }
            Get-HTTeamChannels -TeamId $t.Id -TeamName $t.DisplayName
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Utwórz zespół z grupy…' -Icon 'E902' -Create -ToolTip 'Zespół Teams z zaznaczonej grupy Microsoft 365 - członkowie, właściciele, poczta i witryna zostają' -OnClick {
        param($m)
        $targets = @(Get-HTChangeTargets -Module $m)
        if (-not $targets.Count) { return }
        $groups = @($targets | Where-Object { $_.Type -eq 'Microsoft 365' -and -not $_.IsTeam })
        $skipped = @($targets | Where-Object { $groups -notcontains $_ })
        if ($skipped.Count) { Show-HTWarning "Pominięto ($($skipped.Count)): $(@($skipped | ForEach-Object { "$($_.DisplayName)$(if ($_.IsTeam) { ' - już jest zespołem' } else { ' - nie jest grupą Microsoft 365' })" }) -join '; ').`n`nZespół tworzy się z grupy Microsoft 365; grupę zabezpieczeń albo dystrybucyjną trzeba zastąpić nową grupą Microsoft 365 («Nowa grupa…»)." -Title 'Zespół z grupy' }
        if (-not $groups.Count) { return }
        $form = Show-HTFormDialog -Title 'Zespół Teams z grupy' -Icon 'E902' -OkText 'Dalej' -Width 600 -Fields @(
            @{ Name = 'Create'; Label = 'Członkowie mogą tworzyć i edytować kanały (także prywatne)'; Type = 'Check'; Default = $true }
            @{ Name = 'Delete'; Label = 'Członkowie mogą usuwać kanały'; Type = 'Check'; Default = $false }
            @{ Name = 'Guests'; Label = 'Goście mogą tworzyć i edytować kanały'; Type = 'Check'; Default = $false }
            @{ Name = 'Giphy'; Label = 'Animacje Giphy (filtr treści: ścisły)'; Type = 'Check'; Default = $true }
            @{ Type = 'Info'; Label = 'Grupa musi mieć właściciela. Grupa utworzona przed chwilą może potrzebować do 15 minut, zanim Teams ją zobaczy - program ponawia próbę.' }
        )
        if (-not $form) { return }
        $settings = @{ MembersCanCreateChannels = [bool]$form.Create; MembersCanDeleteChannels = [bool]$form.Delete; GuestsCanCreateChannels = [bool]$form.Guests; AllowGiphy = [bool]$form.Giphy }
        Invoke-HTTargetAction -Module $m -Name 'Zespół z grupy' -Targets $groups -Label { param($t) Get-HTGroupLabel $t } -Action {
            param($t)
            if (-not @(Get-HTM365GroupOwners -Id $t.Id).Count) { throw 'Grupa nie ma właściciela - dodaj go w module «Właściciele» i spróbuj ponownie.' }
            New-HTTeamFromGroup -GroupId $t.Id -Settings $settings | Out-Null
            $t.IsTeam = $true
            $panel = Get-HTPanel 'm365groups'
            if ($panel) { Update-HTTargetItem -Panel $panel -Item $t }
            'Utworzono zespół Teams'
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Nowy kanał…' -Icon 'E710' -Create -ToolTip 'Kanał w zespole zaznaczonej grupy' -OnClick {
        param($m)
        $team = @(Get-HTChangeTargets -Module $m -Single)[0]
        if (-not $team) { return }
        if (-not $team.IsTeam) { Show-HTWarning "Grupa «$($team.DisplayName)» nie ma zespołu Teams - najpierw «Utwórz zespół z grupy…»." -Title 'Nowy kanał'; return }
        $me = ''
        try { $me = [string](Get-MgContext).Account } catch { Write-Verbose $_ }
        $types = @($script:TeamChannelTypes.Keys)
        $prev = @{}
        $get = { param($k, $d) if ($prev.Contains($k)) { $prev[$k] } else { $d } }
        while ($true) {
            $form = Show-HTFormDialog -Title "Nowy kanał: $($team.DisplayName)" -Icon 'E8BD' -OkText 'Dalej' -Width 620 -Fields @(
                @{ Name = 'Name'; Label = 'Nazwa kanału (do 50 znaków)'; Required = $true; Default = (& $get 'Name' '') }
                @{ Name = 'Description'; Label = 'Opis (opcjonalnie)'; Default = (& $get 'Description' '') }
                @{ Name = 'Type'; Label = 'Rodzaj kanału (nie można go później zmienić)'; Type = 'Combo'; Options = $types; Default = (& $get 'Type' $types[0]) }
                @{ Name = 'Owner'; Label = 'Właściciel kanału (UPN - członek zespołu)'; Default = (& $get 'Owner' $me); ShowWhen = @{ Field = 'Type'; Values = @($types[1], $types[2]) } }
            )
            if (-not $form) { return }
            $prev = $form
            $problem = Test-HTTeamChannelName ([string]$form.Name)
            $type = $script:TeamChannelTypes[[string]$form.Type]
            if (-not $problem -and $type -ne 'standard' -and -not ([string]$form.Owner).Trim()) { $problem = 'Kanał prywatny i udostępniony wymaga właściciela.' }
            if (-not $problem) { break }
            Show-HTWarning $problem -Title 'Nowy kanał'
        }
        $name = ([string]$form.Name).Trim()
        $description = [string]$form.Description
        $ownerUpn = ([string]$form.Owner).Trim()
        Invoke-HTTargetAction -Module $m -Name 'Nowy kanał' -Targets @($team) -Label { param($t) Get-HTGroupLabel $t } -Summary @(@("Kanał: $name", "Rodzaj: $($form.Type)", $(if ($type -ne 'standard') { "Właściciel: $ownerUpn" })) | Where-Object { $_ }) -Action {
            param($t)
            $owners = @()
            if ($type -ne 'standard') { $owners = @([string](Resolve-HTM365User -Identity $ownerUpn).id) }
            $c = New-HTTeamChannel -TeamId $t.Id -DisplayName $name -Description $description -MembershipType $type -OwnerIds $owners
            [ordered]@{ Kanał = [string]$c.displayName; Rodzaj = (@{ standard = 'standardowy'; private = 'prywatny'; shared = 'udostępniony' })[$type]; Szczegóły = 'Utworzono'; Link = [string]$c.webUrl }
        }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Usuń kanał' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        $general = @($rows | Where-Object { $_.IsGeneral })
        $rows = @($rows | Where-Object { $_.Id -and $_.__team -and -not $_.IsGeneral })
        if ($general.Count) { Show-HTWarning 'Kanału ogólnego nie można usunąć - pominięto.' -Title 'Usuń kanał' }
        if (-not $rows.Count) { return }
        Invoke-HTRowAction -Module $m -Name 'Usunięcie kanału' -Rows $rows -Danger -Confirm 'Usunąć zaznaczone kanały? Rozmowy kanału znikną z Teams (przywrócenie w Teams przez 30 dni), pliki zostają w witrynie zespołu.' `
            -Label { param($r) "$($r.Zespół): $($r.Kanał)" } -Action { param($r) Remove-HTTeamChannel -TeamId $r.__team -ChannelId $r.Id; 'Usunięto' } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}
#endregion

#region Raporty
Register-HTModule -Workspace 'Groups' -Category 'Raporty' -Key 'grp.hygiene' -Title 'Grupy do uporządkowania' -Icon 'E9D2' -Service 'Graph' `
    -Description 'Grupy bez właściciela (nikt nie zarządza członkami) i bez członków - kandydaci do uzupełnienia albo usunięcia. Grupy pocztowe i z AD mają właścicieli poza Entra ID - pomijane.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż grupy' -Icon 'E9D2' -Primary -OnClick { param($m) Invoke-HTQuery -Module $m -Name 'Grupy do uporządkowania' -ScriptBlock { Get-HTM365GroupHygiene } } | Out-Null
}
#endregion
