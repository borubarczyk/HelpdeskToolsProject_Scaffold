# Przestrzeń «Grupy i zespoły»: wszystkie grupy Microsoft 365 / Entra ID (Microsoft 365, zabezpieczeń, pocztowe) na liście
# po lewej - członkowie, właściciele, szczegóły, nowe grupy, edycja, usuwanie i przywracanie; zespoły Teams; grupy dynamiczne
# Exchange; porządki (grupy bez właściciela i bez członków).

Register-HTWorkspace -Key 'Groups' -Title 'Grupy i zespoły' -Icon 'E902' -Panel 'm365groups' -Service 'Graph' `
    -Description 'Wszystkie grupy Microsoft 365 / Entra ID: członkowie, właściciele, szczegóły, nowe grupy, edycja i usuwanie; zespoły Teams; grupy dynamiczne Exchange' `
    -Categories @('Grupa', 'Zarządzanie', 'Zespoły Teams', 'Grupy dynamiczne (Exchange)', 'Raporty')

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

#region Raporty
Register-HTModule -Workspace 'Groups' -Category 'Raporty' -Key 'grp.hygiene' -Title 'Grupy do uporządkowania' -Icon 'E9D2' -Service 'Graph' `
    -Description 'Grupy bez właściciela (nikt nie zarządza członkami) i bez członków - kandydaci do uzupełnienia albo usunięcia. Grupy pocztowe i z AD mają właścicieli poza Entra ID - pomijane.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż grupy' -Icon 'E9D2' -Primary -OnClick { param($m) Invoke-HTQuery -Module $m -Name 'Grupy do uporządkowania' -ScriptBlock { Get-HTM365GroupHygiene } } | Out-Null
}
#endregion
