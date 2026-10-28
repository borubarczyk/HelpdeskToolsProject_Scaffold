# Przestrzeń robocza: Bezpieczeństwo - Entra ID (dostęp warunkowy, ryzyko, inspekcja, role PIM), aplikacje
# (sekrety i certyfikaty, zgody) oraz Microsoft Defender (alerty, incydenty, izolacja urządzeń)

Register-HTWorkspace -Key 'Security' -Title 'Bezpieczeństwo' -Icon 'E83D' -Service 'Graph' `
    -Description 'Entra ID: dostęp warunkowy, ryzykowni użytkownicy, dziennik inspekcji i role PIM; aplikacje: wygasające sekrety i zgody; Microsoft Defender: alerty, incydenty i izolacja urządzeń' `
    -Categories @('Entra ID', 'Aplikacje', 'Defender', 'Raporty')

function Open-HTSecurityLink {
    param([string]$Url)
    if ($Url -match '^https://') { Start-Process $Url }
}

#region Entra ID
Register-HTModule -Workspace 'Security' -Category 'Entra ID' -Key 'sec.ca' -Title 'Dostęp warunkowy' -Icon 'E83D' -Service 'Graph' `
    -Description 'Zasady dostępu warunkowego: kogo obejmują i kogo wykluczają (z nazwami grup i ról), aplikacje, warunki, wymagane kontrole i sesja. Szare - wyłączone, żółte - blokujące.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pobierz zasady' -Icon 'E72C' -Primary -OnClick {
        param($m)
        if (-not (Assert-HTGraphScopes -Scopes @('Policy.Read.All') -Feature 'Dostęp warunkowy')) { return }
        Invoke-HTQuery -Module $m -Name 'Dostęp warunkowy' -Background -ScriptBlock { param($a) Get-HTConditionalAccessPolicies }
    } | Out-Null
    Add-HTLabel -Parent $row -Hint -Text 'Zasady obejmujące konkretne konto: Microsoft 365 > Bezpieczeństwo > Dostęp warunkowy konta.' | Out-Null
    Add-HTRowAction -Module $m -Text 'Pokaż definicję (JSON)' -Icon 'E943' -Action {
        param($m, $rows)
        foreach ($r in @($rows | Select-Object -First 3)) { Show-HTTextDialog -Title "Zasada: $($r.Zasada)" -Subtitle 'Definicja z Microsoft Graph' -Text (ConvertTo-Json -InputObject $r.__policy -Depth 12) }
    }
    Add-HTRowAction -Module $m -Text 'Otwórz w Entra' -Icon 'E8A7' -Action {
        param($m, $rows)
        foreach ($r in @($rows | Select-Object -First 3)) { Start-Process "https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/$($r.Id)" }
    }
}

Register-HTModule -Workspace 'Security' -Category 'Entra ID' -Key 'sec.risky' -Title 'Ryzykowni użytkownicy' -Icon 'E7BA' -Service 'Graph' `
    -Description 'Konta oznaczone przez Entra ID Protection (licencja P2): poziom i stan ryzyka. Prawy przycisk - potwierdzenie przejęcia, odrzucenie ryzyka, wykrycia, blokada konta.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    $m.C.All = Add-HTCheckBox -Parent $row -Text 'Także rozwiązane i odrzucone'
    Add-HTButton -Parent $row -Module $m -Text 'Pobierz' -Icon 'E72C' -Primary -OnClick {
        param($m)
        if (-not (Assert-HTGraphScopes -Scopes @('IdentityRiskyUser.ReadWrite.All', 'IdentityRiskEvent.Read.All') -Feature 'Ryzykowni użytkownicy')) { return }
        Invoke-HTQuery -Module $m -Name 'Ryzykowni użytkownicy' -Background -Arguments @{ All = (Test-HTChecked $m.C.All) } -ScriptBlock { param($a) Get-HTRiskyUsers -IncludeRemediated:$a.All }
    } | Out-Null
    $refresh = { param($m) Invoke-HTQuery -Module $m -Name 'Ryzykowni użytkownicy' -Background -Arguments @{ All = (Test-HTChecked $m.C.All) } -ScriptBlock { param($a) Get-HTRiskyUsers -IncludeRemediated:$a.All } }
    $m.Data.Refresh = $refresh
    Add-HTRowAction -Module $m -Text 'Pokaż wykrycia ryzyka (30 dni)' -Icon 'E721' -Action {
        param($m, $rows)
        $data = @(foreach ($r in @($rows | Select-Object -First 10)) { Get-HTRiskDetections -UserId $r.Id -Days 30 })
        Show-HTDataViewer -Title 'Wykrycia ryzyka' -Data $data -Description 'Zdarzenia Entra ID Protection (np. nietypowa lokalizacja, wyciek poświadczeń, anonimowy adres IP).' -ExportName 'wykrycia_ryzyka' -Icon 'E7BA'
    }
    Add-HTRowAction -Module $m -Text 'Odrzuć ryzyko (fałszywy alarm)' -Icon 'E73E' -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Odrzucenie ryzyka' -Rows $rows -Confirm 'Odrzucić ryzyko zaznaczonych kont (zweryfikowane - to był właściciel konta)?' -Label { param($r) $r.UPN } -Action { param($r) Set-HTRiskyUserState -UserIds @($r.Id) -Action Dismiss; 'Odrzucono' } -Refresh $m.Data.Refresh
    }
    Add-HTRowAction -Module $m -Text 'Potwierdź przejęcie konta' -Icon 'E7BA' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Potwierdzenie przejęcia konta' -Rows $rows -Danger -Confirm 'Oznaczyć konta jako przejęte (ryzyko wysokie - zasady ryzyka wymuszą zmianę hasła lub zablokują logowanie)?' -Label { param($r) $r.UPN } -Action { param($r) Set-HTRiskyUserState -UserIds @($r.Id) -Action ConfirmCompromised; 'Potwierdzono przejęcie' } -Refresh $m.Data.Refresh
    }
    Add-HTRowAction -Module $m -Text 'Zablokuj logowanie i unieważnij sesje' -Icon 'E72E' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Blokada logowania' -Rows $rows -Danger -Confirm 'Zablokować logowanie i unieważnić wszystkie sesje zaznaczonych kont?' -Label { param($r) $r.UPN } -Action {
            param($r)
            Set-HTM365UserEnabled -Id $r.Id -Enabled $false -RevokeSessions $true
            Register-HTUndo -Operation 'Blokada logowania' -Object $r.UPN -Kind 'UserEnabled' -Data @{ UserId = $r.Id; Enabled = $true }
            'Zablokowano, sesje unieważnione'
        }
    }
}

Register-HTModule -Workspace 'Security' -Category 'Entra ID' -Key 'sec.detections' -Title 'Wykrycia ryzyka' -Icon 'E721' -Service 'Graph' `
    -Description 'Zdarzenia ryzyka logowania i użytkowników (Entra ID Protection) z ostatnich dni: typ, adres IP, lokalizacja, poziom.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTLabel -Parent $row -Text 'Dni:' | Out-Null
    $m.C.Days = Add-HTNumeric -Parent $row -Value 7 -Minimum 1 -Maximum 90
    Add-HTButton -Parent $row -Module $m -Text 'Pobierz' -Icon 'E72C' -Primary -OnClick {
        param($m)
        if (-not (Assert-HTGraphScopes -Scopes @('IdentityRiskEvent.Read.All') -Feature 'Wykrycia ryzyka')) { return }
        Invoke-HTQuery -Module $m -Name 'Wykrycia ryzyka' -Background -Arguments @{ Days = (Get-HTNum $m.C.Days) } -ScriptBlock { param($a) Get-HTRiskDetections -Days $a.Days }
    } | Out-Null
}

Register-HTModule -Workspace 'Security' -Category 'Entra ID' -Key 'sec.audit' -Title 'Dziennik inspekcji Entra' -Icon 'E81C' -Service 'Graph' `
    -Description 'Kto co zmienił w katalogu: konta, grupy, role, aplikacje, zasady - z wartościami przed i po zmianie. Filtr po wykonującym (UPN), celu i kategorii.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTLabel -Parent $row -Text 'Dni:' | Out-Null
    $m.C.Days = Add-HTNumeric -Parent $row -Value 7 -Minimum 1 -Maximum 30
    $m.C.Actor = Add-HTTextBox -Parent $row -Width 220 -Placeholder 'Wykonał (UPN, opcjonalnie)'
    $m.C.Target = Add-HTTextBox -Parent $row -Width 200 -Placeholder 'Cel zawiera (opcjonalnie)'
    $m.C.Category = Add-HTComboBox -Parent $row -Width 200 -Items @('(wszystkie kategorie)', 'UserManagement', 'GroupManagement', 'RoleManagement', 'ApplicationManagement', 'Policy', 'DirectoryManagement', 'Device', 'UserAuthenticationMethod')
    Add-HTButton -Parent $row -Module $m -Text 'Szukaj' -Icon 'E721' -Primary -OnClick {
        param($m)
        $category = Get-HTComboText $m.C.Category
        if ($category -like '(*') { $category = '' }
        Invoke-HTQuery -Module $m -Name 'Dziennik inspekcji Entra' -Background -Arguments @{ Days = (Get-HTNum $m.C.Days); Actor = $m.C.Actor.Text.Trim(); Target = $m.C.Target.Text.Trim(); Category = $category } -ScriptBlock {
            param($a)
            Get-HTDirectoryAudits -Days $a.Days -Actor $a.Actor -Target $a.Target -Category $a.Category
        }
    } | Out-Null
}

Register-HTModule -Workspace 'Security' -Category 'Entra ID' -Key 'sec.pim' -Title 'Role uprzywilejowane (PIM)' -Icon 'E7EF' -Service 'Graph' `
    -Description 'Przypisania ról katalogu: aktywne stałe i czasowe oraz uprawnione w PIM (wymagające aktywacji). Żółte - stałe przypisanie roli Global Administrator lub Privileged Role Administrator.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pobierz przypisania' -Icon 'E72C' -Primary -OnClick {
        param($m)
        Invoke-HTQuery -Module $m -Name 'Role uprzywilejowane' -Background -ScriptBlock { param($a) Get-HTPrivilegedRoleAssignments }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Otwórz PIM' -Icon 'E8A7' -OnClick { param($m) Start-Process 'https://entra.microsoft.com/#view/Microsoft_Azure_PIMCommon/CommonMenuBlade/~/quickStart' } | Out-Null
}
#endregion

#region Aplikacje
Register-HTModule -Workspace 'Security' -Category 'Aplikacje' -Key 'sec.creds' -Title 'Sekrety i certyfikaty aplikacji' -Icon 'E8D7' -Service 'Graph' `
    -Description 'Wygasające i wygasłe sekrety klienta oraz certyfikaty rejestracji aplikacji i aplikacji firmowych (np. certyfikaty SAML) - zanim integracja przestanie działać.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTLabel -Parent $row -Text 'Wygasające w ciągu (dni):' | Out-Null
    $m.C.Days = Add-HTNumeric -Parent $row -Value 30 -Minimum 1 -Maximum 3650
    $m.C.All = Add-HTCheckBox -Parent $row -Text 'Pokaż wszystkie (także ważne dłużej)'
    $m.C.NoSp = Add-HTCheckBox -Parent $row -Text 'Bez aplikacji firmowych'
    Add-HTButton -Parent $row -Module $m -Text 'Sprawdź' -Icon 'E72C' -Primary -OnClick {
        param($m)
        if (-not (Assert-HTGraphScopes -Scopes @('Application.Read.All') -Feature 'Sekrety i certyfikaty aplikacji')) { return }
        Invoke-HTQuery -Module $m -Name 'Sekrety i certyfikaty aplikacji' -Background -Arguments @{ Days = (Get-HTNum $m.C.Days); All = (Test-HTChecked $m.C.All); NoSp = (Test-HTChecked $m.C.NoSp) } -ScriptBlock {
            param($a)
            Get-HTAppCredentialExpiry -Days $a.Days -IncludeAll:$a.All -NoServicePrincipals:$a.NoSp | Sort-Object { if ($null -eq $_.'Dni do końca') { 99999 } else { $_.'Dni do końca' } }
        }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Otwórz aplikację w Entra' -Icon 'E8A7' -Action {
        param($m, $rows)
        foreach ($r in @($rows | Select-Object -First 3)) {
            if ($r.__kind -eq 'Rejestracja aplikacji') { Start-Process "https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Credentials/appId/$($r.AppId)" }
            else { Start-Process "https://entra.microsoft.com/#view/Microsoft_AAD_IAM/ManagedAppMenuBlade/~/Overview/objectId/$($r.Id)/appId/$($r.AppId)" }
        }
    }
    Add-HTRowAction -Module $m -Text 'Usuń sekret klienta' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        $secrets = @($rows | Where-Object { $_.__type -eq 'Sekret' })
        if (-not $secrets.Count) { Show-HTWarning 'Zaznacz wiersze z sekretami (certyfikaty usuwa się w portalu Entra).'; return }
        if (-not (Assert-HTGraphScopes -Scopes @('Application.ReadWrite.All') -Feature 'Usuwanie sekretów aplikacji')) { return }
        Invoke-HTRowAction -Module $m -Name 'Usunięcie sekretu aplikacji' -Rows $secrets -Danger -TypeToConfirm 'USUŃ' -Confirm 'Usunąć wybrane sekrety klienta? Aplikacje korzystające z nich przestaną się uwierzytelniać - usuwaj tylko wygasłe lub nieużywane.' -Label { param($r) "$($r.Aplikacja) - $($r.Opis)" } -Action {
            param($r)
            Remove-HTAppPassword -ObjectId $r.Id -KeyId $r.KeyId -ServicePrincipal:($r.__kind -ne 'Rejestracja aplikacji')
            'Usunięto sekret'
        }
    }
}

Register-HTModule -Workspace 'Security' -Category 'Aplikacje' -Key 'sec.consents' -Title 'Zgody aplikacji' -Icon 'E8D7' -Service 'Graph' `
    -Description 'Zgody delegowane w całym tenancie: aplikacja, wydawca, kto udzielił i jakie uprawnienia. Czerwone - szerokie uprawnienia (poczta, pliki, katalog) od niezweryfikowanego wydawcy, udzielone przez użytkownika.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    $m.C.Risky = Add-HTCheckBox -Parent $row -Text 'Tylko szerokie uprawnienia' -Checked $true
    Add-HTButton -Parent $row -Module $m -Text 'Pobierz zgody' -Icon 'E72C' -Primary -OnClick {
        param($m)
        Invoke-HTQuery -Module $m -Name 'Zgody aplikacji' -Background -Arguments @{ Risky = (Test-HTChecked $m.C.Risky) } -ScriptBlock { param($a) Get-HTOAuthGrants -OnlyRisky:$a.Risky }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Cofnij zgodę' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        if (-not (Assert-HTGraphScopes -Scopes @('DelegatedPermissionGrant.ReadWrite.All') -Feature 'Cofanie zgód aplikacji')) { return }
        Invoke-HTRowAction -Module $m -Name 'Cofnięcie zgody aplikacji' -Rows $rows -Danger -Confirm 'Cofnąć wybrane zgody? Zgoda administratora (wszyscy) dotyczy całej organizacji.' -Label { param($r) "$($r.Aplikacja) ($($r.Zgoda))" } -Action { param($r) Remove-HTOAuthGrant -GrantId $r.Id; 'Cofnięto' }
    }
}
#endregion

#region Defender
Register-HTModule -Workspace 'Security' -Category 'Defender' -Key 'sec.alerts' -Title 'Alerty Defender' -Icon 'E7BA' -Service 'Graph' `
    -Description 'Alerty Microsoft Defender XDR (punkty końcowe, Office 365, tożsamości, aplikacje w chmurze). Prawy przycisk - zmiana stanu, portal, izolacja urządzenia z alertu.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTLabel -Parent $row -Text 'Dni:' | Out-Null
    $m.C.Days = Add-HTNumeric -Parent $row -Value 7 -Minimum 1 -Maximum 180
    $m.C.Resolved = Add-HTCheckBox -Parent $row -Text 'Także rozwiązane'
    $m.Data.Refresh = {
        param($m)
        Invoke-HTQuery -Module $m -Name 'Alerty Defender' -Background -Arguments @{ Days = (Get-HTNum $m.C.Days); Resolved = (Test-HTChecked $m.C.Resolved) } -ScriptBlock { param($a) Get-HTDefenderAlerts -Days $a.Days -IncludeResolved:$a.Resolved }
    }
    Add-HTButton -Parent $row -Module $m -Text 'Pobierz alerty' -Icon 'E72C' -Primary -OnClick {
        param($m)
        if (-not (Assert-HTGraphScopes -Scopes @('SecurityAlert.ReadWrite.All') -Feature 'Alerty Microsoft Defender')) { return }
        & $m.Data.Refresh $m
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Oznacz: w toku' -Icon 'E916' -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Alert w toku' -Rows $rows -Label { param($r) $r.Alert } -Action { param($r) Set-HTDefenderAlertStatus -AlertId $r.Id -Status inProgress; 'W toku' } -Refresh $m.Data.Refresh
    }
    Add-HTRowAction -Module $m -Text 'Rozwiąż alert…' -Icon 'E73E' -Action {
        param($m, $rows)
        $form = Show-HTFormDialog -Title 'Rozwiązanie alertów' -Description "Alerty: $($rows.Count)" -Icon 'E73E' -OkText 'Rozwiąż' -Fields @(
            @{ Name = 'Classification'; Label = 'Klasyfikacja'; Type = 'Combo'; Options = @('truePositive', 'falsePositive', 'informationalExpectedActivity', 'unknown') }
            @{ Name = 'Comment'; Label = 'Komentarz'; Type = 'Multiline'; Height = 60 }
        )
        if (-not $form) { return }
        Invoke-HTRowAction -Module $m -Name 'Rozwiązanie alertu' -Rows $rows -Label { param($r) $r.Alert } -Action { param($r) Set-HTDefenderAlertStatus -AlertId $r.Id -Status resolved -Classification $form.Classification -Comment $form.Comment; "Rozwiązano ($($form.Classification))" } -Refresh $m.Data.Refresh
    }
    Add-HTRowAction -Module $m -Text 'Otwórz w portalu Defender' -Icon 'E8A7' -Action {
        param($m, $rows)
        foreach ($r in @($rows | Select-Object -First 3)) { Open-HTSecurityLink $r.Link }
    }
    Add-HTRowAction -Module $m -Text 'Izoluj urządzenie z alertu…' -Icon 'E72E' -Danger -Action {
        param($m, $rows)
        $devices = @($rows | ForEach-Object { $_.__devices } | Where-Object { $_ -and $_.MdeId })
        if (-not $devices.Count) { Show-HTWarning 'Zaznaczone alerty nie wskazują urządzenia Defender for Endpoint.'; return }
        Invoke-HTDefenderIsolationInteractive -Machines @($devices | ForEach-Object { [PSCustomObject]@{ Urządzenie = $_.Name; Id = $_.MdeId } }) -Isolate $true -Module $m
    }
}

Register-HTModule -Workspace 'Security' -Category 'Defender' -Key 'sec.incidents' -Title 'Incydenty Defender' -Icon 'E7C1' -Service 'Graph' `
    -Description 'Incydenty Microsoft Defender XDR (powiązane alerty z wielu źródeł): ważność, stan, klasyfikacja, przypisanie.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTLabel -Parent $row -Text 'Dni:' | Out-Null
    $m.C.Days = Add-HTNumeric -Parent $row -Value 30 -Minimum 1 -Maximum 180
    $m.C.Resolved = Add-HTCheckBox -Parent $row -Text 'Także rozwiązane'
    $m.Data.Refresh = {
        param($m)
        Invoke-HTQuery -Module $m -Name 'Incydenty Defender' -Background -Arguments @{ Days = (Get-HTNum $m.C.Days); Resolved = (Test-HTChecked $m.C.Resolved) } -ScriptBlock { param($a) Get-HTDefenderIncidents -Days $a.Days -IncludeResolved:$a.Resolved }
    }
    Add-HTButton -Parent $row -Module $m -Text 'Pobierz incydenty' -Icon 'E72C' -Primary -OnClick {
        param($m)
        if (-not (Assert-HTGraphScopes -Scopes @('SecurityIncident.ReadWrite.All') -Feature 'Incydenty Microsoft Defender')) { return }
        & $m.Data.Refresh $m
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Oznacz: w toku' -Icon 'E916' -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Incydent w toku' -Rows $rows -Label { param($r) $r.Incydent } -Action { param($r) Set-HTDefenderIncidentStatus -IncidentId $r.Id -Status inProgress; 'W toku' } -Refresh $m.Data.Refresh
    }
    Add-HTRowAction -Module $m -Text 'Rozwiąż incydent…' -Icon 'E73E' -Action {
        param($m, $rows)
        $form = Show-HTFormDialog -Title 'Rozwiązanie incydentów' -Description "Incydenty: $($rows.Count)" -Icon 'E73E' -OkText 'Rozwiąż' -Fields @(
            @{ Name = 'Classification'; Label = 'Klasyfikacja'; Type = 'Combo'; Options = @('truePositive', 'falsePositive', 'informationalExpectedActivity', 'unknown') }
        )
        if (-not $form) { return }
        Invoke-HTRowAction -Module $m -Name 'Rozwiązanie incydentu' -Rows $rows -Label { param($r) $r.Incydent } -Action { param($r) Set-HTDefenderIncidentStatus -IncidentId $r.Id -Status resolved -Classification $form.Classification; 'Rozwiązano' } -Refresh $m.Data.Refresh
    }
    Add-HTRowAction -Module $m -Text 'Otwórz w portalu Defender' -Icon 'E8A7' -Action {
        param($m, $rows)
        foreach ($r in @($rows | Select-Object -First 3)) { Open-HTSecurityLink $r.Link }
    }
}

function Invoke-HTDefenderIsolationInteractive {
    # Izolacja lub zwolnienie urządzeń Defender for Endpoint z komentarzem (zapis w historii akcji urządzenia)
    param([Parameter(Mandatory)][object[]]$Machines, [bool]$Isolate = $true, [string]$Type = 'Full', [hashtable]$Module)
    if (-not (Assert-HTWriteAllowed -Operation 'Izolacja urządzenia')) { return }
    $names = @($Machines | ForEach-Object { $_.Urządzenie })
    $form = Show-HTFormDialog -Title $(if ($Isolate) { 'Izolacja urządzeń' } else { 'Zwolnienie z izolacji' }) -Icon 'E72E' -Danger:$Isolate -OkText $(if ($Isolate) { 'Izoluj' } else { 'Zwolnij' }) `
        -Description "Urządzenia: $($names -join ', ')" -Fields @(
        if ($Isolate) { @{ Name = 'Type'; Label = 'Rodzaj izolacji'; Type = 'Combo'; Options = @('Full', 'Selective'); Default = $Type; Hint = 'Selective - urządzenie zachowuje dostęp do Outlook, Teams i Skype (Windows 10 1709+).' } }
        @{ Name = 'Comment'; Label = 'Komentarz (widoczny w historii akcji urządzenia)'; Required = $true; Default = "Helpdesk Tools - $env:USERNAME" }
    )
    if (-not $form) { return }
    $mode = if ($Isolate) { [string]$form.Type } else { 'Full' }
    $rows = foreach ($mc in $Machines) {
        try {
            $text = Set-HTDefenderIsolation -MachineId $mc.Id -Isolate $Isolate -Comment $form.Comment -Type $mode
            Add-HTOperationRecord -Operation $(if ($Isolate) { 'Izolacja urządzenia' } else { 'Zwolnienie z izolacji' }) -Object $mc.Urządzenie -Details $text -Module 'Defender'
            if ($Isolate) { Register-HTUndo -Operation 'Izolacja urządzenia' -Object $mc.Urządzenie -Kind 'DefenderIsolation' -Data @{ MachineId = $mc.Id } }
            [PSCustomObject]@{ Obiekt = $mc.Urządzenie; Status = 'OK'; Szczegóły = $text }
        }
        catch {
            Add-HTOperationRecord -Operation $(if ($Isolate) { 'Izolacja urządzenia' } else { 'Zwolnienie z izolacji' }) -Object $mc.Urządzenie -Status 'Błąd' -Details $_.Exception.Message -Module 'Defender'
            [PSCustomObject]@{ Obiekt = $mc.Urządzenie; Status = 'Błąd'; Szczegóły = $_.Exception.Message; __flag = 'crit' }
        }
    }
    Show-HTDataViewer -Title 'Izolacja urządzeń' -Data @($rows) -Description 'Stan akcji: Izolacja urządzeń > «Historia akcji».' -ExportName 'izolacja' -Icon 'E72E'
}

Register-HTModule -Workspace 'Security' -Category 'Defender' -Key 'sec.isolate' -Title 'Izolacja urządzeń' -Icon 'E72E' -Service 'Graph' `
    -Description 'Odcięcie zainfekowanego komputera od sieci (Defender for Endpoint) i zwolnienie z izolacji. Wymaga aplikacji z uprawnieniami Machine.Read i Machine.Isolate (Ustawienia > Defender).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    $m.C.Name = Add-HTTextBox -Parent $row -Width 260 -Placeholder 'Nazwa komputera (początek nazwy)'
    Add-HTButton -Parent $row -Module $m -Text 'Szukaj' -Icon 'E721' -Primary -OnClick {
        param($m)
        $name = $m.C.Name.Text.Trim()
        if (-not $name) { Show-HTWarning 'Wpisz nazwę komputera.'; return }
        if (-not $Global:HTConfig.DefenderClientId) { Show-HTWarning -Title 'Defender for Endpoint' -Text "Ustaw Client ID aplikacji w Ustawieniach (Automatyzacja i Defender).`n`nAplikacja (rejestracja w Entra ID): uprawnienia delegowane WindowsDefenderATP > Machine.Read, Machine.Isolate (zgoda administratora), platforma «Aplikacje mobilne i klasyczne» z adresem http://localhost."; return }
        Invoke-HTQuery -Module $m -Name 'Urządzenia Defender' -ScriptBlock { Find-HTDefenderMachine -Name $name }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Izoluj (pełna izolacja)' -Icon 'E72E' -Danger -Action { param($m, $rows) Invoke-HTDefenderIsolationInteractive -Machines $rows -Isolate $true -Type 'Full' -Module $m }
    Add-HTRowAction -Module $m -Text 'Izoluj selektywnie (Outlook, Teams działają)' -Icon 'E72E' -Danger -Action { param($m, $rows) Invoke-HTDefenderIsolationInteractive -Machines $rows -Isolate $true -Type 'Selective' -Module $m }
    Add-HTRowAction -Module $m -Text 'Zwolnij z izolacji' -Icon 'E785' -Action { param($m, $rows) Invoke-HTDefenderIsolationInteractive -Machines $rows -Isolate $false -Module $m }
    Add-HTRowAction -Module $m -Text 'Historia akcji urządzenia' -Icon 'E81C' -Action {
        param($m, $rows)
        $data = @(foreach ($r in @($rows | Select-Object -First 5)) { Get-HTDefenderMachineActions -MachineId $r.Id | ForEach-Object { $_ | Add-Member -NotePropertyName Urządzenie -NotePropertyValue $r.Urządzenie -PassThru } })
        Show-HTDataViewer -Title 'Historia akcji' -Data $data -ExportName 'akcje_defender' -Icon 'E81C'
    }
}
#endregion

#region Raporty
Register-HTModule -Workspace 'Security' -Category 'Raporty' -Key 'sec.admins' -Title 'Administratorzy: MFA i hasła' -Icon 'E7EF' -Service 'Graph' `
    -Description 'Członkowie ról administracyjnych (także uprawnieni w PIM) bez MFA, ze starym hasłem, synchronizowani z AD albo zablokowani. Czerwone - administrator bez zarejestrowanego MFA.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTLabel -Parent $row -Text 'Hasło starsze niż (dni):' | Out-Null
    $m.C.Days = Add-HTNumeric -Parent $row -Value 365 -Minimum 30 -Maximum 3650
    Add-HTButton -Parent $row -Module $m -Text 'Generuj raport' -Icon 'E9D2' -Primary -OnClick {
        param($m)
        if (-not (Assert-HTGraphScopes -Scopes @('AuditLog.Read.All', 'RoleManagement.Read.Directory') -Feature 'Raport administratorów')) { return }
        Invoke-HTQuery -Module $m -Name 'Administratorzy: MFA i hasła' -Background -Arguments @{ Days = (Get-HTNum $m.C.Days) } -ScriptBlock { param($a) Get-HTAdminSecurityReport -PasswordDays $a.Days | Sort-Object @{ Expression = { switch ($_.__flag) { 'crit' { 0 } 'warn' { 1 } default { 2 } } } }, Nazwa }
    } | Out-Null
}
#endregion
