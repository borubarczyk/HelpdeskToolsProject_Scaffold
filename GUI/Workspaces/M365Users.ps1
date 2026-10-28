# Przestrzeń robocza: Microsoft 365 - użytkownicy Entra ID (Microsoft Graph)

Register-HTWorkspace -Key 'M365' -Title 'Microsoft 365' -Icon 'E716' -Panel 'm365users' -Service 'Graph' `
    -Description 'Użytkownicy Microsoft 365 / Entra ID: konta, hasła i MFA, licencje, grupy, offboarding i raporty' `
    -Categories @('Konto', 'Bezpieczeństwo', 'Licencje i grupy', 'Teams', 'Cykl życia', 'Raporty')

$panel = New-HTTargetPanel -Key 'm365users' -Title 'Użytkownicy Microsoft 365' -Placeholder 'Szukaj (nazwa, UPN, dział)…' -EmptyIcon 'E716' `
    -EmptyText 'Połącz z Microsoft 365 i kliknij «Wczytaj».' -Describe {
    param($u)
    $sub = $u.UserPrincipalName
    if ($u.Department) { $sub += " • $($u.Department)" }
    if ($u.UserType -eq 'Guest') { $sub += ' • gość' }
    @{ Key = $u.Id; Title = $(if ($u.DisplayName) { $u.DisplayName } else { $u.UserPrincipalName }); Sub = $sub
        Dot = $(if (-not $u.AccountEnabled) { 'off' } elseif ($u.UserType -eq 'Guest') { 'info' } elseif (-not $u.Licenses) { 'warn' } else { 'ok' })
        Search = "$($u.Mail) $($u.JobTitle) $($u.Licenses) $($u.UserType)" }
}
Add-HTPanelLoader -Panel $panel -Service 'Graph' -Loader { param($p) Get-HTM365Users } | Out-Null
Add-HTPanelHint -Panel $panel -Text 'Kropka: zielona - aktywne z licencją, żółta - bez licencji, szara - zablokowane, niebieska - gość.' | Out-Null

function Get-HTM365Label { param($u) if ($u.UserPrincipalName) { [string]$u.UserPrincipalName } else { [string]$u.DisplayName } }

function Update-HTM365PanelUser {
    # Odświeża wpis użytkownika na liście po zmianie (np. blokada konta)
    param([Parameter(Mandatory)][object]$User, [hashtable]$Changes = @{})
    foreach ($k in $Changes.Keys) { $User.$k = $Changes[$k] }
    $p = Get-HTPanel 'm365users'
    if ($p) { Update-HTTargetItem -Panel $p -Item $User }
}

#region Konto
Register-HTModule -Workspace 'M365' -Category 'Konto' -Key 'm365.details' -Title 'Szczegóły konta' -Icon 'E77B' `
    -Description 'Pełne informacje o koncie: kontakt, logowanie, synchronizacja z AD, licencje, metody MFA i grupy.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż szczegóły' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Szczegóły konta' -Label { param($t) Get-HTM365Label $t } -Action { param($t) ConvertTo-HTDetailRows -Data (Get-HTM365UserDetail -Id $t.Id) }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Otwórz w Entra' -Icon 'E8A7' -OnClick {
        param($m)
        foreach ($t in @(Get-HTTargets -Module $m | Select-Object -First 5)) { Start-Process "https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserProfileMenuBlade/~/overview/userId/$($t.Id)" }
    } | Out-Null
}

Register-HTModule -Workspace 'M365' -Category 'Konto' -Key 'm365.edit' -Title 'Dane kontaktowe' -Icon 'E70F' `
    -Description 'Edycja stanowiska, działu, telefonów i adresu. Dla wielu kont - ustawienie wybranych pól hurtowo (puste pola pozostają bez zmian).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Edytuj…' -Icon 'E70F' -Primary -OnClick {
        param($m)
        $targets = @(Get-HTTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $single = $targets.Count -eq 1
        $d = if ($single) { Invoke-HTGraphRequest -Uri "users/$($targets[0].Id)?`$select=displayName,givenName,surname,jobTitle,department,companyName,officeLocation,mobilePhone,businessPhones,streetAddress,city,postalCode,country,usageLocation,employeeId" } else { $null }
        $names = [ordered]@{ displayName = 'Nazwa wyświetlana'; givenName = 'Imię'; surname = 'Nazwisko'; jobTitle = 'Stanowisko'; department = 'Dział'; companyName = 'Firma'; officeLocation = 'Biuro'
            mobilePhone = 'Telefon komórkowy'; businessPhones = 'Telefon służbowy'; streetAddress = 'Ulica'; city = 'Miasto'; postalCode = 'Kod pocztowy'; country = 'Kraj'; usageLocation = 'Lokalizacja użycia (np. PL)'; employeeId = 'ID pracownika' }
        $fields = @()
        if (-not $single) { $fields += @{ Type = 'Info'; Label = "Zmiana dla $($targets.Count) kont. Wypełnij tylko pola, które mają zostać ustawione." } }
        foreach ($k in $names.Keys) {
            if (-not $single -and $k -in 'displayName', 'givenName', 'surname', 'employeeId', 'mobilePhone', 'businessPhones') { continue }
            $value = if ($d) { if ($k -eq 'businessPhones') { @($d.businessPhones) -join ', ' } else { $d.$k } } else { '' }
            $fields += @{ Name = $k; Label = $names[$k]; Default = $value }
        }
        $result = Show-HTFormDialog -Title 'Dane kontaktowe' -Description $(if ($single) { Get-HTM365Label $targets[0] } else { "$($targets.Count) kont" }) -Fields $fields -Icon 'E70F'
        if (-not $result) { return }
        $changes = @{}
        foreach ($k in $result.Keys) {
            $new = [string]$result[$k]
            if ($single) {
                $old = if ($k -eq 'businessPhones') { @($d.businessPhones) -join ', ' } else { [string]$d.$k }
                if ($new -ne $old) { $changes[$k] = $(if ($k -eq 'businessPhones') { @(Split-HTInputList $new) } else { $new }) }
            }
            elseif ($new) { $changes[$k] = $new }
        }
        if ($changes.Count -eq 0) { Show-HTToast 'Brak zmian.' 'info'; return }
        Invoke-HTTargetAction -Module $m -Name 'Zmiana danych kontaktowych' -Targets $targets -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            Set-HTM365UserContact -Id $t.Id -Properties $changes
            "Zmieniono: $(@($changes.Keys) -join ', ')"
        }
    } | Out-Null
}

Register-HTModule -Workspace 'M365' -Category 'Konto' -Key 'm365.manager' -Title 'Przełożony' -Icon 'E902' `
    -Description 'Podgląd i ustawienie przełożonego (pole Manager w Entra ID) - używane m.in. w zatwierdzeniach i schemacie organizacyjnym.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Przełożeni' -AlwaysShowObject -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            $mgr = Get-HTM365UserManager -Id $t.Id
            [PSCustomObject]@{ Przełożony = $(if ($mgr) { $mgr.displayName } else { '(brak)' }); 'UPN przełożonego' = $mgr.userPrincipalName; Stanowisko = $mgr.jobTitle; __flag = $(if (-not $mgr) { 'muted' } else { '' }) }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Ustaw przełożonego…' -Icon 'E8FA' -OnClick {
        param($m)
        $targets = @(Get-HTTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $manager = Select-HTM365User -Title 'Przełożony' -Prompt "Przełożony dla: $($targets.Count) kont."
        if (-not $manager) { return }
        Invoke-HTTargetAction -Module $m -Name 'Ustawienie przełożonego' -Targets $targets -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            $previous = Get-HTM365UserManager -Id $t.Id
            Set-HTM365UserManager -Id $t.Id -ManagerId $manager.Id
            Register-HTUndo -Operation 'Ustawienie przełożonego' -Object (Get-HTM365Label $t) -Kind 'Manager' -Data @{ UserId = $t.Id; ManagerId = $(if ($previous) { [string]$previous.id } else { '' }) }
            "Przełożony: $($manager.DisplayName)"
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Usuń przełożonego' -Icon 'E74D' -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Usunięcie przełożonego' -Confirm 'Usunąć przypisanie przełożonego?' -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            $previous = Get-HTM365UserManager -Id $t.Id
            if (-not $previous) { return @{ Status = 'Pominięto'; Szczegóły = 'Brak przełożonego' } }
            Remove-HTM365UserManager -Id $t.Id
            Register-HTUndo -Operation 'Usunięcie przełożonego' -Object (Get-HTM365Label $t) -Kind 'Manager' -Data @{ UserId = $t.Id; ManagerId = [string]$previous.id }
            'Usunięto'
        }
    } | Out-Null
}

Register-HTModule -Workspace 'M365' -Category 'Konto' -Key 'm365.devices' -Title 'Urządzenia użytkownika' -Icon 'E7F8' `
    -Description 'Urządzenia zarządzane w Intune i zarejestrowane w Entra ID przypisane do użytkownika.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż urządzenia' -Icon 'E7F8' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Urządzenia użytkownika' -Label { param($t) Get-HTM365Label $t } -Action { param($t) Get-HTM365UserDevices -Id $t.Id }
    } | Out-Null
}
#endregion

#region Bezpieczeństwo
Register-HTModule -Workspace 'M365' -Category 'Bezpieczeństwo' -Key 'm365.block' -Title 'Blokada i sesje' -Icon 'E72E' `
    -Description 'Blokada logowania (z unieważnieniem sesji), odblokowanie i wylogowanie ze wszystkich urządzeń - np. przy podejrzeniu przejęcia konta.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Zablokuj logowanie' -Icon 'E72E' -Danger -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Blokada logowania' -Danger -Confirm 'Zablokować logowanie i unieważnić wszystkie sesje wybranych kont?' -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            Set-HTM365UserEnabled -Id $t.Id -Enabled $false -RevokeSessions $true
            Update-HTM365PanelUser -User $t -Changes @{ AccountEnabled = $false }
            Register-HTUndo -Operation 'Blokada logowania' -Object (Get-HTM365Label $t) -Kind 'UserEnabled' -Data @{ UserId = $t.Id; Enabled = $true }
            'Logowanie zablokowane, sesje unieważnione'
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Odblokuj' -Icon 'E785' -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Odblokowanie logowania' -Confirm 'Odblokować logowanie wybranych kont?' -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            Set-HTM365UserEnabled -Id $t.Id -Enabled $true
            Update-HTM365PanelUser -User $t -Changes @{ AccountEnabled = $true }
            Register-HTUndo -Operation 'Odblokowanie logowania' -Object (Get-HTM365Label $t) -Kind 'UserEnabled' -Data @{ UserId = $t.Id; Enabled = $false }
            'Logowanie odblokowane'
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Unieważnij sesje' -Icon 'E7E8' -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Unieważnienie sesji' -Confirm 'Wylogować wybrane konta ze wszystkich aplikacji i urządzeń?' -Label { param($t) Get-HTM365Label $t } -Action { param($t) Revoke-HTM365UserSessions -Id $t.Id; 'Sesje unieważnione' }
    } | Out-Null
}

Register-HTModule -Workspace 'M365' -Category 'Bezpieczeństwo' -Key 'm365.password' -Title 'Reset hasła' -Icon 'E8D7' `
    -Description 'Losowe hasła (wg ustawień generatora) lub jedno podane hasło; opcjonalnie wymuszenie zmiany przy logowaniu. Hasła są ukryte - «Pokaż poufne».' -Build {
    param($m)
    $m.SecretColumns = @('Hasło')
    $row = Add-HTToolbarRow -Module $m -Title 'Opcje'
    $m.C.Mode = Add-HTSegmented -Parent $row -Items @('Losowe hasła', 'Podane hasło')
    Add-HTLabel -Parent $row -Text 'Długość:' | Out-Null
    $m.C.Length = Add-HTNumeric -Parent $row -Value ([Math]::Max(8, [int]$Global:PasswordDefaultLength)) -Minimum 8 -Maximum 64
    $m.C.Force = Add-HTCheckBox -Parent $row -Text 'Zmiana hasła przy logowaniu' -Checked $true
    $m.C.Revoke = Add-HTCheckBox -Parent $row -Text 'Unieważnij sesje' -Checked $false
    $actions = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $actions -Module $m -Text 'Resetuj hasło' -Icon 'E8D7' -Primary -OnClick {
        param($m)
        $targets = @(Get-HTTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $fixed = $null
        if ((Get-HTSegmentIndex $m.C.Mode) -eq 1) {
            $fixed = Show-InputBox -Title 'Nowe hasło' -Prompt 'Hasło dla wybranych kont:' -Password -Icon 'E8D7'
            if (-not $fixed) { return }
        }
        $length = Get-HTNum $m.C.Length
        $force = Test-HTChecked $m.C.Force
        $revoke = Test-HTChecked $m.C.Revoke
        Invoke-HTTargetAction -Module $m -Name 'Reset hasła' -Targets $targets -Confirm "Zresetować hasło $($targets.Count) kont?" -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            $password = if ($fixed) { $fixed } else { New-HTRandomPassword -Length $length }
            Reset-HTM365UserPassword -Id $t.Id -Password $password -ForceChange $force
            if ($revoke) { Revoke-HTM365UserSessions -Id $t.Id }
            @{ Hasło = $password; Szczegóły = $(if ($force) { 'Zmiana przy logowaniu' } else { 'Hasło stałe' }) }
        }
    } | Out-Null
    Add-HTButton -Parent $actions -Module $m -Text 'Kopiuj hasła' -Icon 'E8C8' -ToolTip 'Kopiuje pary UPN - hasło do schowka (czyszczony po 60 s)' -OnClick {
        param($m)
        $rows = @(Get-HTResultSelection -Module $m -AllVisible | Where-Object { $_.Hasło })
        if ($rows.Count -eq 0) { return }
        Set-HTClipboard -Text (($rows | ForEach-Object { "$($_.Obiekt)`t$($_.Hasło)" }) -join "`r`n") -Secret
        Show-HTToast "Skopiowano hasła: $($rows.Count) (schowek zostanie wyczyszczony po 60 s)." 'ok'
    } | Out-Null
}

Register-HTModule -Workspace 'M365' -Category 'Bezpieczeństwo' -Key 'm365.mfa' -Title 'Metody MFA' -Icon 'E928' `
    -Description 'Zarejestrowane metody uwierzytelniania; usuwanie metod (np. zgubiony telefon), dodanie numeru telefonu i jednorazowy kod Temporary Access Pass.' -Build {
    param($m)
    $m.SecretColumns = @('Kod TAP')
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż metody' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Metody uwierzytelniania' -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            foreach ($method in @(Get-HTM365AuthMethods -Id $t.Id)) {
                [PSCustomObject]@{ Metoda = $method.Type; Szczegóły = $method.Detail; Utworzono = $method.Created; 'Można usunąć' = $method.Removable; __method = $method }
            }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Dodaj telefon…' -Icon 'E717' -OnClick {
        param($m)
        $t = @(Get-HTTargets -Module $m -Single)[0]
        if (-not $t) { return }
        $form = Show-HTFormDialog -Title 'Telefon MFA' -Description (Get-HTM365Label $t) -Icon 'E717' -OkText 'Dodaj' -Fields @(
            @{ Name = 'Phone'; Label = 'Numer telefonu'; Required = $true; Validation = 'Phone'; Placeholder = '+48 600 100 200'; Hint = 'Numer bez kierunkowego jest traktowany jako polski.' }
            @{ Name = 'Type'; Label = 'Rodzaj'; Type = 'Combo'; Options = @('mobile', 'alternateMobile', 'office') }
        )
        if (-not $form) { return }
        Invoke-HTTargetAction -Module $m -Name 'Dodanie telefonu MFA' -Targets @($t) -Label { param($t) Get-HTM365Label $t } -Action { param($t) "Dodano: $(Add-HTM365PhoneMethod -UserId $t.Id -PhoneNumber $form.Phone -PhoneType $form.Type)" }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Temporary Access Pass…' -Icon 'E8D7' -ToolTip 'Jednorazowy kod do zalogowania i zarejestrowania nowych metod (np. nowy telefon)' -OnClick {
        param($m)
        $targets = @(Get-HTTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $form = Show-HTFormDialog -Title 'Temporary Access Pass' -Description "Kody dla $($targets.Count) kont." -Icon 'E8D7' -OkText 'Generuj' -Fields @(
            @{ Name = 'Minutes'; Label = 'Ważność (minuty)'; Type = 'Number'; Default = 60; Min = 10; Max = 43200 }
            @{ Name = 'Once'; Label = 'Jednorazowy'; Type = 'Check'; Default = $true }
        )
        if (-not $form) { return }
        Invoke-HTTargetAction -Module $m -Name 'Temporary Access Pass' -Targets $targets -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            $tap = New-HTM365TemporaryAccessPass -UserId $t.Id -LifetimeInMinutes $form.Minutes -IsUsableOnce $form.Once
            @{ 'Kod TAP' = $tap.temporaryAccessPass; Szczegóły = "Ważny $($form.Minutes) min od $($tap.startDateTime)" }
        }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Usuń metodę' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        $rows = @($rows | Where-Object { $_.__method -and $_.__method.Removable })
        if ($rows.Count -eq 0) { Show-HTWarning 'Zaznaczone metody nie mogą być usunięte (np. hasło).'; return }
        Invoke-HTRowAction -Module $m -Name 'Usunięcie metody MFA' -Rows $rows -Danger -Confirm 'Usunąć zaznaczone metody uwierzytelniania? Użytkownik będzie musiał zarejestrować je ponownie.' `
            -Label { param($r) "$(Get-HTM365Label $r.__target): $($r.Metoda) $($r.Szczegóły)" } -Action { param($r) Remove-HTM365AuthMethod -UserId $r.__target.Id -Method $r.__method }
    }
}

Register-HTModule -Workspace 'M365' -Category 'Bezpieczeństwo' -Key 'm365.signins' -Title 'Logowania' -Icon 'E81C' `
    -Description 'Ostatnie logowania użytkownika: aplikacja, adres IP, lokalizacja, wynik i dostęp warunkowy (Entra ID P1, AuditLog.Read.All).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Zakres'
    Add-HTLabel -Parent $row -Text 'Liczba wpisów:' | Out-Null
    $m.C.Top = Add-HTNumeric -Parent $row -Value 50 -Minimum 1 -Maximum 1000
    $m.C.Failed = Add-HTCheckBox -Parent $row -Text 'Tylko nieudane'
    $actions = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $actions -Module $m -Text 'Pokaż logowania' -Icon 'E81C' -Primary -OnClick {
        param($m)
        $top = Get-HTNum $m.C.Top
        $failed = Test-HTChecked $m.C.Failed
        Invoke-HTTargetQuery -Module $m -Name 'Logowania' -Label { param($t) Get-HTM365Label $t } -Action { param($t) Get-HTM365SignIns -UserId $t.Id -Top $top -FailedOnly:$failed }
    } | Out-Null
}
#endregion

#region Licencje i grupy
Register-HTModule -Workspace 'M365' -Category 'Licencje i grupy' -Key 'm365.licenses' -Title 'Licencje' -Icon 'E8EC' `
    -Description 'Licencje przypisane do kont; przypisywanie i usuwanie licencji (lokalizacja użycia ustawiana automatycznie, gdy jej brakuje).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż licencje' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Licencje użytkowników' -AlwaysShowObject -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            $licenses = @(Get-HTM365UserLicenses -Id $t.Id)
            if ($licenses.Count -eq 0) { return [PSCustomObject]@{ Licencja = '(brak)'; SKU = ''; __flag = 'muted' } }
            foreach ($l in $licenses) { [PSCustomObject]@{ Licencja = Get-HTSkuFriendlyName $l.SkuPartNumber; SKU = $l.SkuPartNumber; __sku = $l } }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Przypisz licencję…' -Icon 'E710' -OnClick {
        param($m)
        $targets = @(Get-HTTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        Set-HTBusy -Busy $true -Text 'Pobieranie licencji…'
        try { $skus = @(Get-HTSubscribedSkus -Force | Where-Object { $_.Status -eq 'Enabled' } | ForEach-Object { [PSCustomObject]@{ Licencja = Get-HTSkuFriendlyName $_.SkuPartNumber; SKU = $_.SkuPartNumber; Dostępne = $_.Available; Przypisane = $_.Consumed; SkuId = $_.SkuId } }) }
        finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        $selected = Show-HTSelectionDialog -Title 'Przypisz licencję' -Prompt "Licencje dla $($targets.Count) kont." -Items $skus -MultiSelect -Icon 'E8EC'
        if (-not $selected) { return }
        $ids = @($selected | ForEach-Object { "$($_.SkuId)" })
        $names = @($selected | ForEach-Object { $_.Licencja }) -join ', '
        $short = @($selected | Where-Object { $_.Dostępne -lt $targets.Count })
        if ($short.Count -gt 0 -and -not (Show-HTConfirm -Warning -Title 'Za mało licencji' -Message "Niewystarczająca liczba wolnych licencji: $(@($short | ForEach-Object { "$($_.Licencja) ($($_.Dostępne))" }) -join ', '). Kontynuować?")) { return }
        Invoke-HTTargetAction -Module $m -Name 'Przypisanie licencji' -Targets $targets -Label { param($t) Get-HTM365Label $t } -Action { param($t) Set-HTM365UserLicense -Id $t.Id -AddSkuIds $ids; "Przypisano: $names" }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Usuń licencję…' -Icon 'E738' -OnClick {
        param($m)
        $targets = @(Get-HTTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        Set-HTBusy -Busy $true -Text 'Pobieranie licencji…'
        try { $skus = @(Get-HTSubscribedSkus -Force | Where-Object { $_.Consumed -gt 0 } | ForEach-Object { [PSCustomObject]@{ Licencja = Get-HTSkuFriendlyName $_.SkuPartNumber; SKU = $_.SkuPartNumber; Przypisane = $_.Consumed; SkuId = $_.SkuId } }) }
        finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        $selected = Show-HTSelectionDialog -Title 'Usuń licencję' -Prompt "Licencje do usunięcia z $($targets.Count) kont." -Items $skus -MultiSelect -Icon 'E8EC'
        if (-not $selected) { return }
        $ids = @($selected | ForEach-Object { "$($_.SkuId)" })
        $names = @($selected | ForEach-Object { $_.Licencja }) -join ', '
        Invoke-HTTargetAction -Module $m -Name 'Usunięcie licencji' -Targets $targets -Danger -Confirm "Usunąć licencje ($names)? Usunięcie licencji Exchange rozpoczyna 30-dniowy okres usunięcia skrzynki." -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            $owned = @(Get-HTM365UserLicenses -Id $t.Id | ForEach-Object { "$($_.SkuId)" })
            $remove = @($ids | Where-Object { $owned -contains $_ })
            if ($remove.Count -eq 0) { return @{ Status = 'Pominięto'; Szczegóły = 'Brak wskazanych licencji' } }
            Set-HTM365UserLicense -Id $t.Id -RemoveSkuIds $remove
            Register-HTUndo -Operation 'Usunięcie licencji' -Object (Get-HTM365Label $t) -Kind 'License' -Data @{ UserId = $t.Id; SkuIds = $remove }
            "Usunięto licencji: $($remove.Count)"
        }
    } | Out-Null
}

Register-HTModule -Workspace 'M365' -Category 'Licencje i grupy' -Key 'm365.groups' -Title 'Grupy' -Icon 'E902' `
    -Description 'Członkostwo w grupach (Microsoft 365, zabezpieczeń, dystrybucyjnych - te ostatnie wymagają Exchange). Kopiowanie grup z innego użytkownika.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż grupy' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Grupy użytkowników' -AlwaysShowObject -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            foreach ($g in @(Get-HTM365UserGroups -Id $t.Id)) {
                [PSCustomObject]@{ Grupa = $g.DisplayName; Typ = $g.Type; 'E-mail' = $g.Mail; Dynamiczna = $g.Dynamic; 'Z AD' = $g.Synced; __group = $g; __flag = $(if (-not (Test-HTM365GroupManageable -Group $g)) { 'muted' } else { '' }) }
            }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Dodaj do grup…' -Icon 'E710' -OnClick {
        param($m)
        $targets = @(Get-HTTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        Set-HTBusy -Busy $true -Text 'Pobieranie grup…'
        try { $groups = @(Get-HTM365Groups | Where-Object { Test-HTM365GroupManageable -Group $_ }) } finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        $columns = @(@{ Text = 'Nazwa'; Property = 'DisplayName' }, @{ Text = 'Typ'; Property = 'Type' }, @{ Text = 'E-mail'; Property = 'Mail' }, @{ Text = 'Opis'; Property = 'Description' })
        $selected = @(Show-HTSelectionDialog -Title 'Dodaj do grup' -Prompt "Grupy dla $($targets.Count) kont (bez dynamicznych i synchronizowanych z AD)." -Items $groups -Columns $columns -MultiSelect -Icon 'E902')
        if ($selected.Count -eq 0) { return }
        Invoke-HTTargetAction -Module $m -Name 'Dodanie do grup' -Targets $targets -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            $done = foreach ($g in $selected) { Add-HTM365UserToGroup -Group $g -User $t; $g.DisplayName }
            "Dodano do: $(@($done) -join ', ')"
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Kopiuj grupy od…' -Icon 'E8C8' -ToolTip 'Dodaje zaznaczonych użytkowników do grup, do których należy wskazany użytkownik wzorcowy' -OnClick {
        param($m)
        $targets = @(Get-HTTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $source = Select-HTM365User -Title 'Użytkownik wzorcowy' -Prompt 'Grupy tego użytkownika zostaną skopiowane.'
        if (-not $source) { return }
        Set-HTBusy -Busy $true -Text 'Pobieranie grup wzorca…'
        try { $groups = @(Get-HTM365UserGroups -Id $source.Id | Where-Object { Test-HTM365GroupManageable -Group $_ }) } finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        if ($groups.Count -eq 0) { Show-HTMessage -Text 'Użytkownik wzorcowy nie należy do grup, którymi można zarządzać.'; return }
        if (-not (Show-HTConfirm -Title 'Kopiowanie grup' -Message "Dodać $($targets.Count) kont do $($groups.Count) grup użytkownika $($source.DisplayName)?" -Items @($groups | ForEach-Object { $_.DisplayName }))) { return }
        Invoke-HTTargetAction -Module $m -Name 'Kopiowanie grup' -Targets $targets -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            $current = @(Get-HTM365UserGroups -Id $t.Id | ForEach-Object { $_.Id })
            $added = 0
            $errors = @()
            foreach ($g in $groups) {
                if ($current -contains $g.Id) { continue }
                try { Add-HTM365UserToGroup -Group $g -User $t; $added++ } catch { $errors += "$($g.DisplayName): $($_.Exception.Message)" }
            }
            @{ Status = $(if ($errors) { 'Błąd (częściowo)' } else { 'OK' }); Szczegóły = "Dodano do grup: $added$(if ($errors) { '; ' + ($errors -join '; ') })" }
        }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Usuń z grupy' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        $rows = @($rows | Where-Object { $_.__group -and (Test-HTM365GroupManageable -Group $_.__group) })
        if ($rows.Count -eq 0) { Show-HTWarning 'Zaznacz grupy, którymi można zarządzać (nie dynamiczne i nie synchronizowane z AD).'; return }
        Invoke-HTRowAction -Module $m -Name 'Usunięcie z grupy' -Rows $rows -Confirm 'Usunąć użytkowników z zaznaczonych grup?' -Label { param($r) "$(Get-HTM365Label $r.__target) - $($r.Grupa)" } `
            -Action {
            param($r)
            Remove-HTM365UserFromGroup -Group $r.__group -User $r.__target
            if ($r.__group.Type -notin 'Dystrybucyjna', 'Zabezpieczeń (mail)') { Register-HTUndo -Operation 'Usunięcie z grupy' -Object "$(Get-HTM365Label $r.__target) - $($r.Grupa)" -Kind 'GroupMember' -Data @{ GroupId = $r.__group.Id; UserId = $r.__target.Id; Added = $false } }
        } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}
#endregion

#region Cykl życia
Register-HTModule -Workspace 'M365' -Category 'Cykl życia' -Key 'm365.new' -Title 'Nowy użytkownik' -Icon 'E8FA' -Service 'Graph' `
    -Description 'Tworzy konto w chmurze z losowym hasłem; opcjonalnie od razu licencja i grupy skopiowane z użytkownika wzorcowego.' -Build {
    param($m)
    $m.SecretColumns = @('Hasło')
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Utwórz użytkownika…' -Icon 'E8FA' -Primary -OnClick {
        param($m)
        if (-not (Assert-HTConnection -Service 'Graph')) { return }
        Set-HTBusy -Busy $true -Text 'Pobieranie domen i licencji…'
        try {
            $domains = @(Get-HTM365Domains)
            $skus = @(Get-HTSubscribedSkus -Force | Where-Object { $_.Status -eq 'Enabled' -and $_.Available -gt 0 })
        }
        finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        $skuOptions = @('(bez licencji)') + @($skus | ForEach-Object { "$(Get-HTSkuFriendlyName $_.SkuPartNumber) [$($_.SkuPartNumber)] - wolne: $($_.Available)" })
        $form = Show-HTFormDialog -Title 'Nowy użytkownik Microsoft 365' -Icon 'E8FA' -OkText 'Utwórz' -Fields @(
            @{ Name = 'Given'; Label = 'Imię'; Required = $true }
            @{ Name = 'Surname'; Label = 'Nazwisko'; Required = $true }
            @{ Name = 'Login'; Label = 'Login (część UPN przed @)'; Placeholder = 'puste = imie.nazwisko' }
            @{ Name = 'Domain'; Label = 'Domena'; Type = 'Combo'; Options = $domains }
            @{ Name = 'JobTitle'; Label = 'Stanowisko' }
            @{ Name = 'Department'; Label = 'Dział' }
            @{ Name = 'UsageLocation'; Label = 'Lokalizacja użycia'; Default = $Global:DefaultUsageLocation }
            @{ Name = 'Sku'; Label = 'Licencja'; Type = 'Combo'; Options = $skuOptions }
            @{ Name = 'CopyGroups'; Label = 'Skopiuj grupy z użytkownika wzorcowego (wybór po kliknięciu «Utwórz»)'; Type = 'Check' }
            @{ Name = 'Force'; Label = 'Zmiana hasła przy pierwszym logowaniu'; Type = 'Check'; Default = $true }
        )
        if (-not $form) { return }
        $login = if ($form.Login) { $form.Login } else { New-HTADLoginName -GivenName $form.Given -Surname $form.Surname }
        $upn = "$login@$($form.Domain)"
        $template = if ($form.CopyGroups) { Select-HTM365User -Title 'Użytkownik wzorcowy' -Prompt 'Nowe konto otrzyma jego grupy.' } else { $null }
        $sku = if ($form.Sku -and $form.Sku -ne '(bez licencji)') { $skus[[array]::IndexOf($skuOptions, $form.Sku) - 1] } else { $null }
        Invoke-HTQuery -Module $m -Name 'Tworzenie użytkownika' -KeepResults -ScriptBlock {
            $password = New-HTRandomPassword
            $user = New-HTM365User -DisplayName "$($form.Given) $($form.Surname)" -UserPrincipalName $upn -Password $password -GivenName $form.Given -Surname $form.Surname `
                -JobTitle $form.JobTitle -Department $form.Department -UsageLocation $form.UsageLocation -ForceChange $form.Force
            $notes = @('Konto utworzone')
            if ($sku) {
                try { Set-HTM365UserLicense -Id $user.id -AddSkuIds @("$($sku.SkuId)") -UsageLocation $form.UsageLocation; $notes += "licencja $($sku.SkuPartNumber)" }
                catch { $notes += "błąd licencji: $($_.Exception.Message)" }
            }
            if ($template) {
                $added = 0
                foreach ($g in @(Get-HTM365UserGroups -Id $template.Id | Where-Object { Test-HTM365GroupManageable -Group $_ })) {
                    try { Add-HTM365UserToGroup -Group $g -User ([PSCustomObject]@{ Id = $user.id; UserPrincipalName = $upn }); $added++ } catch { $notes += "grupa $($g.DisplayName): $($_.Exception.Message)" }
                }
                $notes += "grup: $added"
            }
            Write-Log -Message "Utworzono użytkownika M365: $upn" -Type 'Info&Notification'
            [PSCustomObject]@{ Obiekt = $upn; Status = 'OK'; Hasło = $password; Szczegóły = ($notes -join '; ') }
        }
        $p = Get-HTPanel 'm365users'
        if ($p) { Invoke-HTPanelLoad -Panel $p -Quiet }
    } | Out-Null
    if ($Global:ShowOnPremises) { Add-HTLabel -Parent $row -Hint -Text 'Dla kont synchronizowanych z lokalnym AD użyj przestrzeni «Użytkownicy AD».' | Out-Null }
}

Register-HTModule -Workspace 'M365' -Category 'Cykl życia' -Key 'm365.offboarding' -Title 'Offboarding' -Icon 'E8F8' `
    -Description 'Odejście pracownika w jednym kroku: blokada, wylogowanie, reset hasła, autoodpowiedź i przekierowanie, skrzynka współdzielona, ukrycie w GAL, grupy, MFA i licencje.' -Build {
    param($m)
    $m.SecretColumns = @('Hasło')
    $row = Add-HTToolbarRow -Module $m -Title 'Konto'
    $m.C.Block = Add-HTCheckBox -Parent $row -Text 'Zablokuj logowanie i unieważnij sesje' -Checked $true
    $m.C.Password = Add-HTCheckBox -Parent $row -Text 'Losowe hasło' -Checked $true
    $m.C.Mfa = Add-HTCheckBox -Parent $row -Text 'Usuń metody MFA' -Checked $false
    $row2 = Add-HTToolbarRow -Module $m -Title 'Poczta (Exchange)'
    $m.C.Shared = Add-HTCheckBox -Parent $row2 -Text 'Konwertuj na skrzynkę współdzieloną' -Checked $true -ToolTip 'Skrzynka współdzielona do 50 GB nie wymaga licencji'
    $m.C.Hide = Add-HTCheckBox -Parent $row2 -Text 'Ukryj w książce adresowej' -Checked $true
    $m.C.Forward = Add-HTTextBox -Parent $row2 -Width 240 -Placeholder 'Przekieruj pocztę do (opcjonalnie)'
    $row3 = Add-HTToolbarRow -Module $m -Title 'Autoodpowiedź'
    $m.C.AutoReply = Add-HTTextBox -Parent $row3 -Width 560 -Multiline -Height 54 -Placeholder 'Treść autoodpowiedzi (opcjonalnie), np. Pracownik nie pracuje już w firmie. Proszę kontaktować się z ...'
    $row4 = Add-HTToolbarRow -Module $m -Title 'Dostęp'
    $m.C.Groups = Add-HTCheckBox -Parent $row4 -Text 'Usuń z grup' -Checked $true
    $m.C.Licenses = Add-HTCheckBox -Parent $row4 -Text 'Usuń licencje (po konwersji skrzynki)' -Checked $true
    $m.C.Manager = Add-HTCheckBox -Parent $row4 -Text 'Usuń przełożonego' -Checked $false
    $m.C.OneDrive = Add-HTCheckBox -Parent $row4 -Text 'Dostęp przełożonego do OneDrive' -Checked $false -ToolTip 'Przełożony zostaje administratorem OneDrive odchodzącego (PnP, rola SharePoint Administrator) - przed usunięciem przełożonego z konta'
    $actions = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $actions -Module $m -Text 'Wykonaj offboarding' -Icon 'E8F8' -Primary -Danger -OnClick {
        param($m)
        $targets = @(Get-HTTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $o = @{}
        if (-not (Assert-HTWriteAllowed -Operation 'Offboarding')) { return }
        foreach ($k in 'Block', 'Password', 'Mfa', 'Shared', 'Hide', 'Groups', 'Licenses', 'Manager', 'OneDrive') { $o[$k] = Test-HTChecked $m.C[$k] }
        $o.Forward = $m.C.Forward.Text.Trim()
        $o.AutoReply = $m.C.AutoReply.Text.Trim()
        if ($o.Forward -and -not (Test-HTInputValue -Value $o.Forward -ValidationType Email)) { Show-HTWarning 'Nieprawidłowy adres przekierowania.'; return }
        $needsExchange = $o.Shared -or $o.Hide -or $o.Forward -or $o.AutoReply
        if ($needsExchange -and -not $Global:ConnectedToExchange) {
            if (-not (Show-HTConfirm -Warning -Title 'Offboarding' -Message 'Brak połączenia z Exchange Online - kroki pocztowe zostaną pominięte. Kontynuować?')) { return }
        }
        $steps = @()
        if ($o.Block) { $steps += 'blokada i wylogowanie' }
        if ($o.Password) { $steps += 'reset hasła' }
        if ($o.AutoReply) { $steps += 'autoodpowiedź' }
        if ($o.Forward) { $steps += "przekierowanie do $($o.Forward)" }
        if ($o.Shared) { $steps += 'skrzynka współdzielona' }
        if ($o.Hide) { $steps += 'ukrycie w GAL' }
        if ($o.Mfa) { $steps += 'usunięcie MFA' }
        if ($o.OneDrive) { $steps += 'dostęp przełożonego do OneDrive' }
        if ($o.Groups) { $steps += 'usunięcie z grup' }
        if ($o.Manager) { $steps += 'usunięcie przełożonego' }
        if ($o.Licenses) { $steps += 'usunięcie licencji' }
        if ($steps.Count -eq 0) { Show-HTWarning 'Wybierz co najmniej jeden krok.'; return }
        if (-not (Show-HTConfirm -Danger -Title 'Offboarding' -Message "Kroki: $($steps -join ', ').`n`nKonta:" -Items @($targets | ForEach-Object { Get-HTM365Label $_ }) -TypeToConfirm 'OFFBOARDING')) { return }
        $exo = [bool]$Global:ConnectedToExchange
        $adminConnection = $null
        if ($o.OneDrive) {
            try { $adminConnection = Connect-HTPnPReturn -Url (Get-HTSharePointAdminUrl) }
            catch {
                Write-Log -Message "Offboarding - połączenie z centrum administracyjnym SharePoint: $($_.Exception.Message)" -Type 'Warn'
                if (-not (Show-HTConfirm -Warning -Title 'Offboarding' -Message "Nie połączono z centrum administracyjnym SharePoint - krok OneDrive zostanie pominięty. Kontynuować?`n`n$($_.Exception.Message)")) { return }
                $o.OneDrive = $false
            }
        }
        Reset-HTResults -Module $m
        Set-HTBusy -Busy $true -Text 'Offboarding…'
        try {
            $i = 0
            foreach ($t in $targets) {
                $i++
                $label = Get-HTM365Label $t
                Set-HTProgress -Value $i -Maximum $targets.Count -Text "Offboarding [$i/$($targets.Count)] $label"
                $run = {
                    param([string]$Step, [scriptblock]$Do)
                    $r = [ordered]@{ Obiekt = $label; Krok = $Step; Status = 'OK'; Szczegóły = ''; Hasło = '' }
                    try {
                        $out = & $Do
                        if ($out -is [hashtable]) { foreach ($k in $out.Keys) { $r[$k] = $out[$k] } } elseif ($out) { $r.Szczegóły = [string]$out }
                    }
                    catch { $r.Status = 'Błąd'; $r.Szczegóły = $_.Exception.Message }
                    Write-Log -Message "Offboarding $label - $($Step): $($r.Status) $(if ($r.Status -ne 'OK') { $r.Szczegóły })" -Type $(if ($r.Status -eq 'Błąd') { 'Warn' } else { 'Info' })
                    Add-HTOperationRecord -Operation "Offboarding: $Step" -Object $label -Status $r.Status -Details $(if ($r.Hasło) { '' } else { $r.Szczegóły }) -Module 'Offboarding' 
                    Add-HTResultRows -Module $m -Objects @([PSCustomObject]$r)
                }
                $mailbox = $t.UserPrincipalName
                if ($o.Block) { & $run 'Blokada i wylogowanie' { Set-HTM365UserEnabled -Id $t.Id -Enabled $false -RevokeSessions $true; Update-HTM365PanelUser -User $t -Changes @{ AccountEnabled = $false } } }
                if ($o.Password) { & $run 'Reset hasła' { $pw = New-HTRandomPassword; Reset-HTM365UserPassword -Id $t.Id -Password $pw -ForceChange $true; @{ Hasło = $pw } } }
                if ($exo) {
                    if ($o.AutoReply) { & $run 'Autoodpowiedź' { Set-HTMailboxAutoReply -Identity $mailbox -State Enabled -InternalMessage $o.AutoReply -ExternalMessage $o.AutoReply -ExternalAudience All } }
                    if ($o.Forward) { & $run 'Przekierowanie' { Set-HTMailboxForwarding -Identity $mailbox -ForwardTo $o.Forward -KeepCopy $true; "Do: $($o.Forward)" } }
                    if ($o.Shared) { & $run 'Skrzynka współdzielona' { Convert-HTMailboxType -Identity $mailbox -Type Shared } }
                    if ($o.Hide) { & $run 'Ukrycie w GAL' { Set-HTMailboxHiddenFromGAL -Identity $mailbox -Hidden $true } }
                }
                if ($o.Mfa) {
                    & $run 'Usunięcie metod MFA' {
                        $removed = 0
                        foreach ($method in @(Get-HTM365AuthMethods -Id $t.Id | Where-Object Removable)) { Remove-HTM365AuthMethod -UserId $t.Id -Method $method; $removed++ }
                        "Usunięto: $removed"
                    }
                }
                if ($o.Groups) {
                    & $run 'Usunięcie z grup' {
                        $removed = @()
                        $skipped = 0
                        foreach ($g in @(Get-HTM365UserGroups -Id $t.Id)) {
                            if (-not (Test-HTM365GroupManageable -Group $g)) { $skipped++; continue }
                            if ($g.Type -in 'Dystrybucyjna', 'Zabezpieczeń (mail)' -and -not $exo) { $skipped++; continue }
                            Remove-HTM365UserFromGroup -Group $g -User $t
                            $removed += $g.DisplayName
                        }
                        "Usunięto z: $($removed.Count)$(if ($skipped) { ", pominięto (dynamiczne/AD/pocztowe): $skipped" })"
                    }
                }
                if ($o.OneDrive) {
                    & $run 'Dostęp przełożonego do OneDrive' {
                        $mgr = Get-HTM365UserManager -Id $t.Id
                        if (-not $mgr) { throw 'konto nie ma przełożonego (ustaw go w module «Przełożony»)' }
                        $site = Grant-HTOneDriveAccess -UserId $t.Id -GrantTo @($mgr.userPrincipalName) -AdminConnection $adminConnection
                        "$($mgr.userPrincipalName) - $site"
                    }
                }
                if ($o.Manager) { & $run 'Usunięcie przełożonego' { if (Get-HTM365UserManager -Id $t.Id) { Remove-HTM365UserManager -Id $t.Id; 'Usunięto' } else { 'Brak przełożonego' } } }
                if ($o.Licenses) {
                    & $run 'Usunięcie licencji' {
                        $ids = @(Get-HTM365UserLicenses -Id $t.Id | ForEach-Object { "$($_.SkuId)" })
                        if ($ids.Count -eq 0) { return 'Brak licencji' }
                        Set-HTM365UserLicense -Id $t.Id -RemoveSkuIds $ids
                        "Usunięto licencji: $($ids.Count)"
                    }
                }
            }
        }
        finally { Set-HTBusy -Busy $false -Text 'Offboarding zakończony' }
        $failed = @($m.Table.Select("Status LIKE 'Błąd*'")).Count
        Show-HTToast "Offboarding zakończony$(if ($failed) { " - błędy: $failed" })." $(if ($failed) { 'warn' } else { 'ok' })
        [void](Send-HTTeamsMessage -Event 'Offboarding' -Title 'Offboarding zakończony' -Tone $(if ($failed) { 'warn' } else { 'ok' }) -Text "Kroki: $($steps -join ', ')." -Facts ([ordered]@{ Konta = (@($targets | ForEach-Object { Get-HTM365Label $_ }) -join ', '); Błędy = "$failed" }))
    } | Out-Null
    Add-HTLabel -Parent $actions -Hint -Text 'Wymaga potwierdzenia słowem OFFBOARDING. Wyniki każdego kroku pojawią się w tabeli.' | Out-Null
}

Register-HTModule -Workspace 'M365' -Category 'Cykl życia' -Key 'm365.deleted' -Title 'Usunięci użytkownicy' -Icon 'E74D' -Service 'Graph' `
    -Description 'Kosz katalogu: konta usunięte w ciągu 30 dni można przywrócić razem ze skrzynką, OneDrive i członkostwem.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż usuniętych' -Icon 'E72C' -Primary -OnClick { param($m) Invoke-HTQuery -Module $m -Name 'Usunięci użytkownicy' -ScriptBlock { Get-HTM365DeletedUsers } } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Usuń zaznaczone konta…' -Icon 'E74D' -Danger -ToolTip 'Usuwa konta zaznaczone na liście po lewej (trafiają do kosza na 30 dni)' -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Usunięcie konta' -Danger -TypeToConfirm 'USUŃ' -Confirm 'Usunąć wybrane konta? Można je przywrócić w ciągu 30 dni.' -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            Remove-HTM365User -Id $t.Id
            $p = Get-HTPanel 'm365users'
            if ($p) { Remove-HTTargetItem -Panel $p -Item $t }
            'Konto usunięte (kosz 30 dni)'
        }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Przywróć konto' -Icon 'E777' -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Przywrócenie konta' -Rows $rows -Confirm 'Przywrócić zaznaczone konta?' -Action { param($r) Restore-HTM365DeletedUser -Id $r.Id | Out-Null } `
            -Refresh { param($m) Invoke-HTQuery -Module $m -Name 'Usunięci użytkownicy' -ScriptBlock { Get-HTM365DeletedUsers } }
    }
    Add-HTRowAction -Module $m -Text 'Usuń trwale' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Trwałe usunięcie' -Rows $rows -Danger -TypeToConfirm 'USUŃ' -Confirm 'Trwale usunąć zaznaczone konta? Operacji nie można cofnąć.' -Action { param($r) Remove-HTM365DeletedUser -Id $r.Id } `
            -Refresh { param($m) Invoke-HTQuery -Module $m -Name 'Usunięci użytkownicy' -ScriptBlock { Get-HTM365DeletedUsers } }
    }
}
#endregion

#region Raporty
function Register-HTM365Report {
    param([string]$Key, [string]$Title, [string]$Icon, [string]$Description, [scriptblock]$Query, [switch]$Days, [int]$DefaultDays = 0, [string]$DaysLabel = 'Dni:', [scriptblock]$Extra)
    Register-HTModule -Workspace 'M365' -Category 'Raporty' -Key $Key -Title $Title -Icon $Icon -Service 'Graph' -Description $Description -Build {
        param($m)
        $def = $script:M365ReportDefs[$m.Key]
        foreach ($k in $def.Keys) { $m.Data[$k] = $def[$k] }
        $row = Add-HTToolbarRow -Module $m
        if ($m.Data.Days) {
            Add-HTLabel -Parent $row -Text $m.Data.DaysLabel | Out-Null
            $m.C.Days = Add-HTNumeric -Parent $row -Value $m.Data.DefaultDays -Minimum 1 -Maximum 3650
        }
        if ($m.Data.Extra) { & $m.Data.Extra $m $row }
        Add-HTButton -Parent $row -Module $m -Text 'Generuj raport' -Icon 'E9D2' -Primary -OnClick {
            param($m)
            $days = if ($m.C.Days) { Get-HTNum $m.C.Days } else { 0 }
            $query = $m.Data.Query
            Invoke-HTQuery -Module $m -Name $m.Title -ScriptBlock { & $query $m $days }
        } | Out-Null
        Add-HTRowAction -Module $m -Text 'Zaznacz na liście użytkowników' -Icon 'E8B3' -Action {
            param($m, $rows)
            $p = Get-HTPanel 'm365users'
            $ids = @($rows | ForEach-Object { if ($_.Id) { [string]$_.Id } })
            $found = 0
            foreach ($r in $p.Table.Rows) { if ($ids -contains [string]$r['Key']) { $r['Sel'] = $true; $found++ } }
            Update-HTTargetCount $p
            Show-HTToast "Zaznaczono na liście: $found (np. do blokady lub offboardingu)." 'ok'
        }
    }
    # Parametry raportu trafiają do kontekstu modułu przy pierwszym otwarciu
    $script:M365ReportDefs[$Key] = @{ Query = $Query; Days = [bool]$Days; DefaultDays = $DefaultDays; DaysLabel = $DaysLabel; Extra = $Extra }
}
$script:M365ReportDefs = @{}

Register-HTM365Report -Key 'm365.rep.inactive' -Title 'Nieaktywni użytkownicy' -Icon 'E916' -Days -DefaultDays (Get-HTInactiveDaysDefault) -DaysLabel 'Bez logowania od (dni):' `
    -Description 'Konta bez logowania (interaktywnego i nieinteraktywnego) od wskazanej liczby dni. Wyróżnione - z przypisanymi licencjami (koszt).' `
    -Extra { param($m, $row) $m.C.Disabled = Add-HTCheckBox -Parent $row -Text 'Także zablokowane'; $m.C.Guests = Add-HTCheckBox -Parent $row -Text 'Także goście' } `
    -Query { param($m, $days) Get-HTM365InactiveUsers -Days $days -IncludeDisabled:(Test-HTChecked $m.C.Disabled) -IncludeGuests:(Test-HTChecked $m.C.Guests) }
Register-HTM365Report -Key 'm365.rep.guests' -Title 'Goście' -Icon 'E8D4' -Description 'Konta gości: stan zaproszenia i ostatnie logowanie. Wyróżnione - nieaktywne ponad 90 dni.' -Query { param($m, $days) Get-HTM365GuestUsers }
Register-HTM365Report -Key 'm365.rep.mfa' -Title 'Rejestracja MFA' -Icon 'E928' -Description 'Kto nie ma zarejestrowanego MFA (czerwone - administratorzy bez MFA). Wymaga Entra ID P1.' -Query { param($m, $days) Get-HTM365MfaRegistration }
Register-HTM365Report -Key 'm365.rep.unlicensed' -Title 'Bez licencji' -Icon 'E8EC' -Description 'Konta członków organizacji bez żadnej licencji.' -Query { param($m, $days) Get-HTM365UnlicensedUsers }
Register-HTM365Report -Key 'm365.rep.admins' -Title 'Role administracyjne' -Icon 'E7EF' -Description 'Członkowie aktywnych ról katalogu (Global Administrator wyróżniony).' -Query { param($m, $days) Get-HTM365AdminRoles }
Register-HTM365Report -Key 'm365.rep.failed' -Title 'Nieudane logowania' -Icon 'E7BA' -Days -DefaultDays 24 -DaysLabel 'Ostatnie godziny:' `
    -Description 'Nieudane logowania w całej organizacji (np. ataki password spray, zablokowane konta, błędne MFA).' -Query { param($m, $hours) Get-HTM365FailedSignIns -Hours ([Math]::Min(720, $hours)) }
#endregion

#region Narzędzia helpdesku: wizytówka, porównanie kont, diagnoza logowania, dostęp warunkowy i zgody użytkownika
function Find-HTM365UserInteractive {
    # Użytkownik po UPN, adresie albo początku nazwy (paleta Ctrl+K); kilka trafień - okno wyboru
    param([Parameter(Mandatory)][string]$Query)
    if (-not (Assert-HTConnection -Service 'Graph')) { return $null }
    $q = $Query.Trim()
    if ($q -match '^[^@\s]+@[^@\s]+$') {
        try {
            $u = Resolve-HTM365User -Identity $q
            if ($u) { return [PSCustomObject]@{ Id = $u.id; DisplayName = $u.displayName; UserPrincipalName = $u.userPrincipalName } }
        }
        catch { Write-Verbose "Wyszukanie po UPN: $_" }
    }
    $e = $q.Replace("'", "''")
    $filter = [uri]::EscapeDataString("startswith(displayName,'$e') or startswith(userPrincipalName,'$e') or startswith(mail,'$e')")
    $found = @(Invoke-HTGraphRequest -Uri "users?`$filter=$filter&`$select=id,displayName,userPrincipalName,department,accountEnabled&`$top=25" | ForEach-Object {
            [PSCustomObject]@{ Id = $_.id; DisplayName = $_.displayName; UserPrincipalName = $_.userPrincipalName; Department = $_.department; AccountEnabled = [bool]$_.accountEnabled }
        })
    if ($found.Count -eq 0) { Show-HTWarning "Nie znaleziono użytkownika: $q"; return $null }
    if ($found.Count -eq 1) { return $found[0] }
    $columns = @(
        @{ Text = 'Nazwa'; Property = 'DisplayName' }
        @{ Text = 'UPN'; Property = 'UserPrincipalName' }
        @{ Text = 'Dział'; Property = 'Department' }
        @{ Text = 'Włączone'; Property = 'AccountEnabled' }
    )
    return @(Show-HTSelectionDialog -Title 'Wybierz użytkownika' -Prompt "Wyniki dla «$q»" -Items $found -Columns $columns -Icon 'E77B')[0]
}

function ConvertTo-HTCardDictionary {
    # Obiekt wiersza (np. urządzenie) jako słownik dla tabeli wizytówki
    param($Object)
    $d = [ordered]@{}
    foreach ($p in $Object.PSObject.Properties) {
        if ($p.Name -like '__*') { continue }
        $d[$p.Name] = if ($p.Value -is [datetime]) { $p.Value.ToString('yyyy-MM-dd HH:mm') } else { [string]$p.Value }
    }
    $d['__flag'] = [string]$Object.__flag
    return $d
}

function New-HTUserCardFile {
    # Wizytówka (HTML): konto Microsoft 365, skrzynka Exchange (po połączeniu), urządzenia i ostatnie logowania
    param([Parameter(Mandatory)]$User)
    $detail = Get-HTM365UserDetail -Id $User.Id
    $general = [ordered]@{}
    $sections = [ordered]@{ 'Microsoft 365' = $general }
    foreach ($k in $detail.Keys) {
        $v = $detail[$k]
        if ($v -is [System.Collections.IDictionary]) { $sections[$k] = $v } else { $general[$k] = $v }
    }
    $enabled = [bool]$general['Konto włączone']
    $chips = @(@{ Text = $(if ($enabled) { 'konto aktywne' } else { 'logowanie zablokowane' }); Tone = $(if ($enabled) { 'ok' } else { 'crit' }) })
    if ($general['Typ'] -eq 'Guest') { $chips += @{ Text = 'gość'; Tone = 'info' } }
    if ($sections['Konto'] -and $sections['Konto']['Synchronizacja z AD']) { $chips += @{ Text = 'synchronizowane z AD'; Tone = 'info' } }
    $tables = @()
    if ($Global:ConnectedToExchange) {
        try {
            $mbx = Get-HTMailboxDetail -Identity $User.UserPrincipalName
            $mGeneral = [ordered]@{}
            $sections['Skrzynka Exchange'] = $mGeneral
            foreach ($k in $mbx.Keys) { $v = $mbx[$k]; if ($v -is [System.Collections.IDictionary]) { $sections["Poczta - $k"] = $v } else { $mGeneral[$k] = $v } }
            if ("$($mbx['Rozmiar i limity']['Archiwum'])" -eq 'Active') { $chips += @{ Text = 'archiwum online'; Tone = 'info' } }
            $forward = [string]$mbx['Przekierowanie']['Przekieruj do']
            if ($forward -and $forward -ne '(brak)') { $chips += @{ Text = "przekierowanie: $forward"; Tone = 'warn' } }
            $perms = @(Get-HTMailboxPermissions -Identity $User.UserPrincipalName)
            $tables += @{ Title = 'Uprawnienia do skrzynki'; Columns = @('Typ', 'Użytkownik', 'Uprawnienia'); Rows = @($perms | ForEach-Object { [ordered]@{ Typ = $_.Type; 'Użytkownik' = $_.User; Uprawnienia = $_.AccessRights } }) }
        }
        catch { $sections['Skrzynka Exchange'] = [ordered]@{ Stan = "Brak skrzynki albo błąd: $($_.Exception.Message)" } }
    }
    else { $sections['Skrzynka Exchange'] = [ordered]@{ Stan = 'Połącz z Exchange Online, aby dołączyć dane skrzynki.' } }
    try {
        $devices = @(Get-HTM365UserDevices -Id $User.Id)
        $tables += @{ Title = 'Urządzenia (Intune i Entra ID)'; Columns = @('Źródło', 'Nazwa', 'System', 'Zgodność', 'Model', 'NumerSeryjny', 'OstatniaAktywność'); Rows = @($devices | ForEach-Object { ConvertTo-HTCardDictionary $_ }) }
        if (@($devices | Where-Object { $_.Zgodność -eq 'noncompliant' }).Count) { $chips += @{ Text = 'urządzenie niezgodne'; Tone = 'warn' } }
    }
    catch { Write-Log -Message "Wizytówka - urządzenia: $($_.Exception.Message)" -Type 'Warn' }
    try {
        $signIns = @(Get-HTM365SignIns -UserId $User.Id -Top 15)
        $tables += @{ Title = 'Ostatnie logowania'; Columns = @('Czas', 'Aplikacja', 'Adres IP', 'Lokalizacja', 'Wynik', 'Powód', 'Klient', 'System'); Rows = @($signIns | ForEach-Object { ConvertTo-HTCardDictionary $_ }) }
        if (@($signIns | Where-Object { $_.Wynik -ne 'Sukces' }).Count) { $chips += @{ Text = 'nieudane logowania'; Tone = 'warn' } }
    }
    catch { Write-Log -Message "Wizytówka - logowania (AuditLog.Read.All, Entra ID P1): $($_.Exception.Message)" -Type 'Warn' }
    $subtitle = (@($general['UPN'], $general['Stanowisko'], $general['Dział']) | Where-Object { $_ }) -join ' • '
    $html = ConvertTo-HTUserCardHtml -Title ([string]$general['Nazwa wyświetlana']) -Subtitle $subtitle -Sections $sections -Tables $tables -Chips $chips `
        -Meta ('Helpdesk Tools {0} • {1:yyyy-MM-dd HH:mm} • {2}' -f $Global:AppVersion, (Get-Date), $env:USERNAME)
    $name = ($User.UserPrincipalName -split '@')[0] -replace '[^\w\.\-]+', '_'
    $path = Join-Path (Get-HTExportDirectory) ('Wizytowka_{0}_{1:yyyy-MM-dd_HH-mm}.html' -f $name, (Get-Date))
    [System.IO.File]::WriteAllText($path, $html, (New-Object System.Text.UTF8Encoding($true)))
    return $path
}

function Show-HTUserCard {
    param([Parameter(Mandatory)]$User)
    Set-HTBusy -Busy $true -Text "Wizytówka: $(Get-HTM365Label $User)…"
    try {
        $path = New-HTUserCardFile -User $User
        Write-Log -Message "Utworzono wizytówkę użytkownika: $path" -Type 'Info'
        Start-Process -FilePath $path
    }
    catch {
        Write-Log -Message "Wizytówka $(Get-HTM365Label $User): $($_.Exception.Message)" -Type 'Error'
        Show-HTError 'Nie utworzono wizytówki.' $_
    }
    finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
}

function Show-HTLoginDiagnosisFor {
    # Diagnoza logowania w osobnym oknie (paleta Ctrl+K)
    param([Parameter(Mandatory)]$User, [int]$Days = 7)
    if (-not (Assert-HTGraphScopes -Scopes @('AuditLog.Read.All', 'Policy.Read.All', 'IdentityRiskyUser.Read.All') -Feature 'Diagnoza logowania')) { return }
    Set-HTBusy -Busy $true -Text "Diagnoza logowania: $(Get-HTM365Label $User)…"
    try { $rows = @(Get-HTLoginDiagnosis -UserId $User.Id -Days $Days) }
    finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
    Show-HTDataViewer -Title "Diagnoza logowania - $(Get-HTM365Label $User)" -Data $rows -Description "Konto, hasło, MFA, ryzyko, dostęp warunkowy i logowania z ostatnich $Days dni." -ExportName 'diagnoza_logowania' -Icon 'E9D9'
}

Register-HTModule -Workspace 'M365' -Category 'Konto' -Key 'm365.card' -Title 'Wizytówka (raport HTML)' -Icon 'E8A5' -Service 'Graph' `
    -Description 'Wszystko o użytkowniku na jednej stronie: konto i licencje, MFA, grupy, skrzynka Exchange (uprawnienia, przekierowanie, autoodpowiedź), urządzenia i ostatnie logowania. Plik HTML do zgłoszenia lub wydruku.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Utwórz wizytówkę' -Icon 'E8A5' -Primary -OnClick {
        param($m)
        $targets = @(Get-HTTargets -Module $m)
        if ($targets.Count -gt 5 -and -not (Show-HTConfirm -Title 'Wizytówki' -Message "Utworzyć $($targets.Count) plików wizytówek?")) { return }
        foreach ($t in $targets) { Show-HTUserCard -User $t }
    } | Out-Null
    Add-HTLabel -Parent $row -Hint -Text 'Dane skrzynki po połączeniu z Exchange. Ctrl+K > «Wizytówka» - dla dowolnego konta bez wczytywania listy.' | Out-Null
}

Register-HTModule -Workspace 'M365' -Category 'Konto' -Key 'm365.compare' -Title 'Porównanie kont' -Icon 'E8AB' -Service 'Graph' `
    -Description 'Grupy, licencje, role i aplikacje dwóch kont obok siebie (np. «nowa osoba ma mieć to samo co…»). Zaznacz dwa konta na liście albo jedno i wybierz drugie. Prawy przycisk - uzupełnienie brakujących grup.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    $m.C.OnlyDiff = Add-HTCheckBox -Parent $row -Text 'Tylko różnice' -Checked $true
    Add-HTButton -Parent $row -Module $m -Text 'Porównaj' -Icon 'E8AB' -Primary -OnClick {
        param($m)
        $targets = @(Get-HTTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        if ($targets.Count -eq 1) {
            $other = Select-HTM365User -Title 'Porównaj z' -Prompt "Drugie konto do porównania z $(Get-HTM365Label $targets[0])."
            if (-not $other) { return }
            $targets += $other
        }
        $m.Data.A = $targets[0]
        $m.Data.B = $targets[1]
        Invoke-HTQuery -Module $m -Name 'Porównanie kont' -Background -Arguments @{ A = $targets[0].Id; B = $targets[1].Id; NameA = (Get-HTM365Label $targets[0]); NameB = (Get-HTM365Label $targets[1]); OnlyDiff = (Test-HTChecked $m.C.OnlyDiff) } -ScriptBlock {
            param($x)
            $sa = Get-HTUserAccessSummary -UserId $x.A
            $sb = Get-HTUserAccessSummary -UserId $x.B
            $groups = @{}
            foreach ($g in @($sa.__groups) + @($sb.__groups)) { if ($g) { $groups[[string]$g.DisplayName] = $g } }
            $sa.Remove('__groups')
            $sb.Remove('__groups')
            foreach ($r in @(Compare-HTUserSets -A $sa -B $sb -NameA $x.NameA -NameB $x.NameB -OnlyDifferences:$x.OnlyDiff)) {
                if ($r.Kategoria -eq 'Grupy') { $r | Add-Member -NotePropertyName '__group' -NotePropertyValue $groups[$r.Nazwa] }
                $r
            }
        }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Uzupełnij brakujące grupy (drugie konto)' -Icon 'E902' -Action {
        param($m, $rows)
        $a = $m.Data.A
        $b = $m.Data.B
        $todo = @($rows | Where-Object { $_.Kategoria -eq 'Grupy' -and $_.__group -and ($_.__inA -xor $_.__inB) })
        if (-not $todo.Count) { Show-HTWarning 'Zaznacz wiersze grup, które ma tylko jedno z kont.'; return }
        Invoke-HTRowAction -Module $m -Name 'Uzupełnienie grup' -Rows $todo -Confirm "Dodać konta do grup, których im brakuje?`n$(Get-HTM365Label $a) ↔ $(Get-HTM365Label $b)" -Label { param($r) $r.Nazwa } -Action {
            param($r)
            $user = if ($r.__inA) { $b } else { $a }
            if (-not (Test-HTM365GroupManageable -Group $r.__group)) { throw 'grupa dynamiczna albo synchronizowana z AD' }
            Add-HTM365UserToGroup -Group $r.__group -User $user
            "Dodano: $(Get-HTM365Label $user)"
        }
    }
}

Register-HTModule -Workspace 'M365' -Category 'Bezpieczeństwo' -Key 'm365.diag' -Title 'Diagnoza logowania' -Icon 'E9D9' -Service 'Graph' `
    -Description '«Nie mogę się zalogować»: stan konta i hasła, MFA, ryzyko, zasady dostępu warunkowego i ostatnie błędy logowania z wyjaśnieniem kodów (50053, 50074, 53003…) i zaleceniem.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTLabel -Parent $row -Text 'Logowania z ostatnich (dni):' | Out-Null
    $m.C.Days = Add-HTNumeric -Parent $row -Value 7 -Minimum 1 -Maximum 30
    Add-HTButton -Parent $row -Module $m -Text 'Diagnozuj' -Icon 'E9D9' -Primary -OnClick {
        param($m)
        if (-not (Assert-HTGraphScopes -Scopes @('AuditLog.Read.All', 'Policy.Read.All', 'IdentityRiskyUser.Read.All') -Feature 'Diagnoza logowania')) { return }
        $days = Get-HTNum $m.C.Days
        Invoke-HTTargetQuery -Module $m -Name 'Diagnoza logowania' -Label { param($t) Get-HTM365Label $t } -Action { param($t) Get-HTLoginDiagnosis -UserId $t.Id -Days $days }
    } | Out-Null
}

Register-HTModule -Workspace 'M365' -Category 'Bezpieczeństwo' -Key 'm365.causer' -Title 'Dostęp warunkowy konta' -Icon 'E83D' -Service 'Graph' `
    -Description 'Zasady dostępu warunkowego obejmujące konto (bezpośrednio, przez grupy, role lub jako gościa) z wymaganą kontrolą. Ocena warunku «Użytkownicy» - aplikacje i lokalizacje opisuje kolumna «Warunki».' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    $m.C.All = Add-HTCheckBox -Parent $row -Text 'Pokaż też zasady, które nie obejmują konta'
    Add-HTButton -Parent $row -Module $m -Text 'Sprawdź zasady' -Icon 'E83D' -Primary -OnClick {
        param($m)
        if (-not (Assert-HTGraphScopes -Scopes @('Policy.Read.All') -Feature 'Dostęp warunkowy')) { return }
        $all = Test-HTChecked $m.C.All
        Invoke-HTTargetQuery -Module $m -Name 'Dostęp warunkowy konta' -Label { param($t) Get-HTM365Label $t } -Action { param($t) Get-HTConditionalAccessForUser -UserId $t.Id -IncludeNotApplied:$all }
    } | Out-Null
}

Register-HTModule -Workspace 'M365' -Category 'Bezpieczeństwo' -Key 'm365.consents' -Title 'Zgody aplikacji konta' -Icon 'E8D7' -Service 'Graph' `
    -Description 'Aplikacje, którym użytkownik udzielił dostępu do swoich danych (zgody delegowane) - np. po phishingu zgód. Wyróżnione - szerokie uprawnienia od niezweryfikowanych wydawców. Prawy przycisk - cofnięcie zgody.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż zgody' -Icon 'E8D7' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Zgody aplikacji' -Label { param($t) Get-HTM365Label $t } -Action { param($t) Get-HTOAuthGrants -UserId $t.Id | Where-Object { $_.Zgoda -eq 'Użytkownik' } }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Cofnij zgodę' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        if (-not (Assert-HTGraphScopes -Scopes @('DelegatedPermissionGrant.ReadWrite.All') -Feature 'Cofanie zgód aplikacji')) { return }
        Invoke-HTRowAction -Module $m -Name 'Cofnięcie zgody aplikacji' -Rows $rows -Danger -Confirm 'Cofnąć zgody wybranych aplikacji? Aplikacja straci dostęp do danych użytkownika (sesje aplikacji mogą działać do wygaśnięcia tokenu - rozważ też unieważnienie sesji).' -Label { param($r) $r.Aplikacja } -Action { param($r) Remove-HTOAuthGrant -GrantId $r.Id; 'Cofnięto' }
    }
}
#endregion

#region Licencje grupowe, licencje do odzyskania
Register-HTModule -Workspace 'M365' -Category 'Licencje i grupy' -Key 'm365.licerr' -Title 'Błędy licencji grupowych' -Icon 'E7BA' -Service 'Graph' `
    -Description 'Użytkownicy, którym grupa nie przypisała licencji (brak wolnych licencji, konflikt planów, brak lokalizacji użycia). Po usunięciu przyczyny - «Ponów przypisanie».' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Sprawdź błędy' -Icon 'E72C' -Primary -OnClick {
        param($m)
        Invoke-HTQuery -Module $m -Name 'Błędy licencji grupowych' -Background -ScriptBlock { param($a) Get-HTGroupLicenseErrors }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Ponów przypisanie licencji' -Icon 'E72C' -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Ponowne przetworzenie licencji' -Rows $rows -Label { param($r) $r.UPN } -Action { param($r) Invoke-HTLicenseReprocess -UserId $r.Id; 'Zlecono ponowne przetworzenie' }
    }
    Add-HTRowAction -Module $m -Text 'Ustaw lokalizację użycia…' -Icon 'E909' -Action {
        param($m, $rows)
        $loc = Show-InputBox -Title 'Lokalizacja użycia' -Prompt 'Dwuliterowy kod kraju (np. PL) dla zaznaczonych kont:' -DefaultText $(if ($Global:DefaultUsageLocation) { $Global:DefaultUsageLocation } else { 'PL' }) -Icon 'E909'
        if (-not $loc -or $loc -notmatch '^[A-Za-z]{2}$') { return }
        Invoke-HTRowAction -Module $m -Name 'Lokalizacja użycia' -Rows $rows -Label { param($r) $r.UPN } -Action {
            param($r)
            Invoke-HTGraphRequest -Uri "users/$($r.Id)" -Method PATCH -Body @{ usageLocation = $loc.ToUpperInvariant() } | Out-Null
            Invoke-HTLicenseReprocess -UserId $r.Id
            "Lokalizacja: $($loc.ToUpperInvariant()), ponowiono przypisanie"
        }
    }
}

Register-HTModule -Workspace 'M365' -Category 'Licencje i grupy' -Key 'm365.reclaim' -Title 'Licencje do odzyskania' -Icon 'E8EC' -Service 'Graph' `
    -Description 'Licencje przypisane kontom zablokowanym albo nieaktywnym (bez logowania od N dni). Prawy przycisk - usunięcie licencji bezpośrednich (licencje z grup usuwa się przez członkostwo).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTLabel -Parent $row -Text 'Bez logowania od (dni):' | Out-Null
    $m.C.Days = Add-HTNumeric -Parent $row -Value (Get-HTInactiveDaysDefault) -Minimum 1 -Maximum 3650
    $m.C.Guests = Add-HTCheckBox -Parent $row -Text 'Także goście'
    Add-HTButton -Parent $row -Module $m -Text 'Szukaj' -Icon 'E721' -Primary -OnClick {
        param($m)
        Invoke-HTQuery -Module $m -Name 'Licencje do odzyskania' -Background -Arguments @{ Days = (Get-HTNum $m.C.Days); Guests = (Test-HTChecked $m.C.Guests) } -ScriptBlock { param($a) Get-HTReclaimableLicenses -Days $a.Days -IncludeGuests:$a.Guests }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Usuń licencje bezpośrednie' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Usunięcie licencji' -Rows $rows -Danger -Confirm 'Usunąć bezpośrednio przypisane licencje zaznaczonych kont? Przed usunięciem licencji skrzynkę warto przekonwertować na współdzieloną (dane skrzynki bez licencji są usuwane po 30 dniach).' -Label { param($r) $r.UPN } -Action {
            param($r)
            $ids = @($r.__direct)
            if (-not $ids.Count) { return 'Brak licencji bezpośrednich (tylko z grup)' }
            Set-HTM365UserLicense -Id $r.Id -RemoveSkuIds $ids
            Register-HTUndo -Operation 'Usunięcie licencji' -Object $r.UPN -Kind 'License' -Data @{ UserId = $r.Id; SkuIds = $ids }
            "Usunięto licencji: $($ids.Count)"
        }
    }
}
#endregion

#region Teams
Register-HTModule -Workspace 'M365' -Category 'Teams' -Key 'm365.teams' -Title 'Zespoły Teams' -Icon 'E902' -Service 'Graph' `
    -Description 'Zespoły z właścicielami, liczbą członków i gości, archiwizacją i ostatnią aktywnością. Czerwone - zespół bez właściciela. Prawy przycisk - właściciel, archiwizacja, goście.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    $m.C.Issues = Add-HTCheckBox -Parent $row -Text 'Tylko z uwagami (bez właściciela, jeden właściciel, goście)'
    $m.C.Activity = Add-HTCheckBox -Parent $row -Text 'Ostatnia aktywność (raport użycia)' -Checked $true
    Add-HTButton -Parent $row -Module $m -Text 'Pobierz zespoły' -Icon 'E72C' -Primary -OnClick {
        param($m)
        if ((Test-HTChecked $m.C.Activity) -and -not (Assert-HTGraphScopes -Scopes @('Reports.Read.All') -Feature 'Aktywność zespołów')) { return }
        Invoke-HTQuery -Module $m -Name 'Zespoły Teams' -Background -Arguments @{ Issues = (Test-HTChecked $m.C.Issues); Activity = (Test-HTChecked $m.C.Activity) } -ScriptBlock { param($a) Get-HTTeamsOverview -OnlyIssues:$a.Issues -NoActivity:(-not $a.Activity) }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Dodaj właściciela…' -Icon 'E8FA' -Action {
        param($m, $rows)
        $owner = Select-HTM365User -Title 'Nowy właściciel' -Prompt "Właściciel dla zespołów: $($rows.Count)."
        if (-not $owner) { return }
        Invoke-HTRowAction -Module $m -Name 'Dodanie właściciela zespołu' -Rows $rows -Label { param($r) $r.Zespół } -Action { param($r) Add-HTTeamOwner -GroupId $r.Id -UserId $owner.Id; "Właściciel: $(Get-HTM365Label $owner)" }
    }
    Add-HTRowAction -Module $m -Text 'Archiwizuj zespół' -Icon 'E7B8' -Action {
        param($m, $rows)
        if (-not (Assert-HTGraphScopes -Scopes @('TeamSettings.ReadWrite.All') -Feature 'Archiwizacja zespołów')) { return }
        Invoke-HTRowAction -Module $m -Name 'Archiwizacja zespołu' -Rows $rows -Confirm 'Zarchiwizować wybrane zespoły? Zespół stanie się tylko do odczytu (można go przywrócić).' -Label { param($r) $r.Zespół } -Action {
            param($r)
            Set-HTTeamArchived -TeamId $r.Id -Archived $true
            Register-HTUndo -Operation 'Archiwizacja zespołu' -Object $r.Zespół -Kind 'TeamArchive' -Data @{ TeamId = $r.Id }
            'Zarchiwizowano'
        }
    }
    Add-HTRowAction -Module $m -Text 'Przywróć z archiwum' -Icon 'E777' -Action {
        param($m, $rows)
        if (-not (Assert-HTGraphScopes -Scopes @('TeamSettings.ReadWrite.All') -Feature 'Archiwizacja zespołów')) { return }
        Invoke-HTRowAction -Module $m -Name 'Przywrócenie zespołu' -Rows $rows -Label { param($r) $r.Zespół } -Action { param($r) Set-HTTeamArchived -TeamId $r.Id -Archived $false; 'Przywrócono' }
    }
    Add-HTRowAction -Module $m -Text 'Pokaż gości zespołu' -Icon 'E8D4' -Action {
        param($m, $rows)
        $guests = @(foreach ($r in $rows) { Get-HTTeamGuests -GroupId $r.Id -TeamName $r.Zespół })
        Show-HTDataViewer -Title 'Goście zespołów' -Data $guests -Description 'Usunięcie gościa z zespołu: moduł «Członkowie grup» (Licencje i grupy).' -ExportName 'goscie_zespolow' -Icon 'E8D4'
    }
}
#endregion

#region Masowe tworzenie kont z pliku CSV
Register-HTModule -Workspace 'M365' -Category 'Cykl życia' -Key 'm365.bulk' -Title 'Masowe tworzenie kont (CSV)' -Icon 'E8F4' -Service 'Graph' `
    -Description 'Nowe konta z pliku CSV według szablonu: imię, nazwisko, login, stanowisko, dział, licencje, grupy, przełożony. Najpierw sprawdzenie pliku (podgląd błędów), potem utworzenie kont z losowymi hasłami.' -Build {
    param($m)
    $m.SecretColumns = @('Hasło')
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Zapisz szablon CSV' -Icon 'E74E' -OnClick {
        param($m)
        $path = Select-HTSaveFile -Title 'Szablon CSV' -Filter 'CSV (*.csv)|*.csv' -FileName 'Nowe_konta.csv' -DefaultExt '.csv'
        if (-not $path) { return }
        [System.IO.File]::WriteAllText($path, (Get-HTBulkUserTemplate), (New-Object System.Text.UTF8Encoding($true)))
        Show-HTToast 'Zapisano szablon. Licencje: nazwa SKU (np. O365_BUSINESS_PREMIUM), kilka wartości po przecinku.' 'ok' 8
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Wczytaj i sprawdź plik…' -Icon 'E8E5' -Primary -OnClick {
        param($m)
        $path = Select-HTOpenFile -Title 'Plik CSV z nowymi kontami' -Filter 'CSV (*.csv)|*.csv'
        if (-not $path) { return }
        Invoke-HTQuery -Module $m -Name 'Sprawdzenie pliku CSV' -ScriptBlock {
            $rows = @(Import-HTBulkUserCsv -Path $path)
            $domains = @(Get-HTM365Domains)
            $skus = @(Get-HTSubscribedSkus | ForEach-Object { $_.SkuPartNumber })
            $existing = @(Get-HTM365Users | ForEach-Object { $_.UserPrincipalName })
            $seen = New-Object System.Collections.Generic.List[string]
            $m.Data.Bulk = New-Object System.Collections.Generic.List[object]
            $n = 0
            foreach ($r in $rows) {
                $n++
                $check = Test-HTBulkUserRow -Row $r -Domains $domains -ExistingUpns $existing -SeenUpns $seen.ToArray() -KnownSkus $skus
                if ($check.Upn) { $seen.Add($check.Upn) }
                $check.Source = $r
                $m.Data.Bulk.Add($check)
                [PSCustomObject]@{ Lp = $n; Nazwa = $check.DisplayName; UPN = $check.Upn; Licencje = ($check.Licenses -join ', '); Grupy = ($check.Groups -join ', '); Przełożony = $check.Manager
                    Status = $(if ($check.Valid) { 'Do utworzenia' } else { 'Błąd' }); Szczegóły = ($check.Errors -join '; '); Hasło = ''; __flag = $(if ($check.Valid) { '' } else { 'crit' }) }
            }
        }
        $bad = @($m.Data.Bulk | Where-Object { -not $_.Valid }).Count
        if ($m.Data.Bulk.Count) { Show-HTToast "Wierszy: $($m.Data.Bulk.Count), z błędami: $bad. Popraw plik albo utwórz poprawne konta." $(if ($bad) { 'warn' } else { 'ok' }) 6 }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Utwórz poprawne konta' -Icon 'E8FA' -Danger -OnClick {
        param($m)
        $valid = @($m.Data.Bulk | Where-Object { $_.Valid })
        if (-not $valid.Count) { Show-HTWarning 'Najpierw wczytaj i sprawdź plik CSV (brak poprawnych wierszy).'; return }
        if (-not (Assert-HTWriteAllowed -Operation 'Masowe tworzenie kont')) { return }
        if (-not (Show-HTConfirm -Title 'Masowe tworzenie kont' -ConfirmText 'Utwórz konta' -Message "Utworzyć kont: $($valid.Count)? Hasła zostaną wygenerowane (zmiana przy pierwszym logowaniu) i pokazane w kolumnie «Hasło» (przycisk «Pokaż poufne»)." -Items @($valid | ForEach-Object { $_.Upn }))) { return }
        $groupCache = @{}
        $skuMap = @{}
        foreach ($s in @(Get-HTSubscribedSkus)) { $skuMap[$s.SkuPartNumber.ToUpperInvariant()] = "$($s.SkuId)" }
        Reset-HTResults -Module $m
        Set-HTBusy -Busy $true -Text 'Tworzenie kont…'
        try {
            $i = 0
            foreach ($v in $valid) {
                $i++
                Set-HTProgress -Value $i -Maximum $valid.Count -Text "Tworzenie [$i/$($valid.Count)] $($v.Upn)"
                $src = $v.Source
                $notes = New-Object System.Collections.Generic.List[string]
                $password = if ("$($src.Haslo)".Trim()) { "$($src.Haslo)".Trim() } else { New-HTRandomPassword }
                try {
                    $created = New-HTM365User -DisplayName $v.DisplayName -UserPrincipalName $v.Upn -Password $password -GivenName "$($src.Imie)".Trim() -Surname "$($src.Nazwisko)".Trim() `
                        -JobTitle "$($src.Stanowisko)".Trim() -Department "$($src.Dzial)".Trim() -UsageLocation "$($src.LokalizacjaUzycia)".Trim().ToUpperInvariant()
                    $extra = @{}
                    if ("$($src.Firma)".Trim()) { $extra.companyName = "$($src.Firma)".Trim() }
                    if ("$($src.TelefonKomorkowy)".Trim()) { $extra.mobilePhone = "$($src.TelefonKomorkowy)".Trim() }
                    if ("$($src.Biuro)".Trim()) { $extra.officeLocation = "$($src.Biuro)".Trim() }
                    if ($extra.Count) { try { Set-HTM365UserContact -Id $created.id -Properties $extra } catch { $notes.Add("dane kontaktowe: $($_.Exception.Message)") } }
                    $skuIds = @(foreach ($l in $v.Licenses) { $skuMap[$l.ToUpperInvariant()] })
                    if ($skuIds.Count) { try { Set-HTM365UserLicense -Id $created.id -AddSkuIds $skuIds -UsageLocation "$($src.LokalizacjaUzycia)".Trim(); $notes.Add("licencje: $($v.Licenses -join ', ')") } catch { $notes.Add("licencje - błąd: $($_.Exception.Message)") } }
                    foreach ($gName in $v.Groups) {
                        try {
                            if (-not $groupCache.ContainsKey($gName)) { $groupCache[$gName] = Resolve-HTM365Group -Identity $gName }
                            Add-HTM365GroupMember -GroupId $groupCache[$gName].id -MemberId $created.id
                            $notes.Add("grupa: $gName")
                        }
                        catch { $notes.Add("grupa $gName - błąd: $($_.Exception.Message)") }
                    }
                    if ($v.Manager) {
                        try { $mgr = Resolve-HTM365User -Identity $v.Manager; Set-HTM365UserManager -Id $created.id -ManagerId $mgr.id; $notes.Add("przełożony: $($v.Manager)") }
                        catch { $notes.Add("przełożony - błąd: $($_.Exception.Message)") }
                    }
                    Add-HTOperationRecord -Operation 'Utworzenie konta (CSV)' -Object $v.Upn -Details ($notes -join '; ') -Module $m.Title
                    Write-Log -Message "Utworzono konto z pliku CSV: $($v.Upn)" -Type 'Info'
                    Add-HTResultRows -Module $m -Objects @([PSCustomObject]@{ Nazwa = $v.DisplayName; UPN = $v.Upn; Status = 'OK'; Szczegóły = ($notes -join '; '); Hasło = $password; __flag = $(if (@($notes | Where-Object { $_ -match 'błąd' }).Count) { 'warn' } else { '' }) })
                }
                catch {
                    Add-HTOperationRecord -Operation 'Utworzenie konta (CSV)' -Object $v.Upn -Status 'Błąd' -Details $_.Exception.Message -Module $m.Title
                    Add-HTResultRows -Module $m -Objects @([PSCustomObject]@{ Nazwa = $v.DisplayName; UPN = $v.Upn; Status = 'Błąd'; Szczegóły = $_.Exception.Message; Hasło = ''; __flag = 'crit' })
                }
            }
        }
        finally { Set-HTBusy -Busy $false -Text 'Tworzenie kont zakończone' }
        $m.Data.Bulk = $null
        $p = Get-HTPanel 'm365users'
        if ($p) { Invoke-HTPanelLoad -Panel $p -Quiet }
        Show-HTToast 'Utworzono konta - hasła w kolumnie «Hasło» (Pokaż poufne), eksport: Excel.' 'ok' 8
    } | Out-Null
}
#endregion

#region Polecenia palety (Ctrl+K)
Register-HTPaletteAction -Text 'Wizytówka użytkownika' -Icon 'E8A5' -Description 'Raport HTML: konto, MFA, grupy, skrzynka, urządzenia, logowania' -NeedsQuery -Action {
    param($q)
    $u = Find-HTM365UserInteractive -Query $q
    if ($u) { Show-HTUserCard -User $u }
}
Register-HTPaletteAction -Text 'Diagnoza logowania' -Icon 'E9D9' -Description '«Nie mogę się zalogować» - konto, MFA, ryzyko, dostęp warunkowy, błędy' -NeedsQuery -Action {
    param($q)
    $u = Find-HTM365UserInteractive -Query $q
    if ($u) { Show-HTLoginDiagnosisFor -User $u }
}
#endregion

#region OneDrive odchodzącego pracownika
Register-HTModule -Workspace 'M365' -Category 'Cykl życia' -Key 'm365.onedrive' -Title 'OneDrive odchodzącego' -Icon 'E753' -Service 'Graph' `
    -Description 'Dostęp przełożonego (lub innej osoby) do OneDrive odchodzącego pracownika - przed usunięciem konta (OneDrive jest usuwany po okresie przechowywania). Opcjonalnie odebranie dostępu po N dniach (zadania zaplanowane). Także udostępnienia z OneDrive.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Dostęp'
    $m.C.GrantTo = Add-HTTextBox -Parent $row -Width 300 -Placeholder 'Dla (UPN, puste - przełożony z Entra ID)'
    Add-HTLabel -Parent $row -Text 'Odbierz po (dni, 0 - nie):' | Out-Null
    $m.C.Days = Add-HTNumeric -Parent $row -Value 30 -Minimum 0 -Maximum 365
    Add-HTButton -Parent $row -Module $m -Text 'Nadaj dostęp' -Icon 'E8FA' -Primary -OnClick {
        param($m)
        $targets = @(Get-HTTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        if (-not (Assert-HTWriteAllowed -Operation 'Dostęp do OneDrive')) { return }
        $grantTo = $m.C.GrantTo.Text.Trim()
        $days = Get-HTNum $m.C.Days
        if (-not (Show-HTConfirm -Title 'OneDrive odchodzącego' -ConfirmText 'Nadaj dostęp' -Message "Nadać $(if ($grantTo) { $grantTo } else { 'przełożonym' }) rolę administratora OneDrive$(if ($days -gt 0) { " (odebranie za $days dni)" })? Wymaga roli SharePoint Administrator." -Items @($targets | ForEach-Object { Get-HTM365Label $_ }))) { return }
        try { $admin = Connect-HTPnPReturn -Url (Get-HTSharePointAdminUrl) }
        catch { Show-HTError 'Nie połączono z centrum administracyjnym SharePoint.' $_; return }
        Invoke-HTTargetAction -Module $m -Name 'Dostęp do OneDrive' -Targets $targets -Label { param($t) Get-HTM365Label $t } -Action {
            param($t)
            $who = $grantTo
            if (-not $who) {
                $mgr = Get-HTM365UserManager -Id $t.Id
                if (-not $mgr) { throw 'brak przełożonego - wpisz UPN osoby' }
                $who = $mgr.userPrincipalName
            }
            $site = Grant-HTOneDriveAccess -UserId $t.Id -GrantTo @($who) -AdminConnection $admin
            if ($days -gt 0) { [void](New-HTScheduledJob -Type 'RevokeOneDriveAccess' -RunAt (Get-Date).AddDays($days) -Object (Get-HTM365Label $t) -Description "Odebranie dostępu $who do OneDrive" -Data @{ SiteUrl = $site; Users = @($who) }) }
            @{ Szczegóły = "$who - administrator OneDrive$(if ($days -gt 0) { ", odebranie: $((Get-Date).AddDays($days).ToString('yyyy-MM-dd'))" })"; OneDrive = $site }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Otwórz OneDrive' -Icon 'E8A7' -OnClick {
        param($m)
        foreach ($t in @(Get-HTTargets -Module $m | Select-Object -First 3)) { try { Start-Process (Get-HTOneDriveSiteUrl -UserId $t.Id) } catch { Show-HTError "OneDrive $(Get-HTM365Label $t)" $_ } }
    } | Out-Null
    $row2 = Add-HTToolbarRow -Module $m -Title 'Udostępnienia'
    $m.C.External = Add-HTCheckBox -Parent $row2 -Text 'Tylko anonimowe i zewnętrzne' -Checked $true
    Add-HTButton -Parent $row2 -Module $m -Text 'Udostępnione pliki' -Icon 'E72D' -OnClick {
        param($m)
        $targets = @(Get-HTTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        if (-not (Assert-HTGraphScopes -Scopes @('Files.Read.All') -Feature 'Udostępnienia OneDrive')) { return }
        Invoke-HTQuery -Module $m -Name 'Udostępnienia OneDrive' -Background -Arguments @{ Users = @($targets | ForEach-Object { @{ Id = $_.Id; Label = (Get-HTM365Label $_) } }); External = (Test-HTChecked $m.C.External) } -ScriptBlock {
            param($a)
            foreach ($u in $a.Users) {
                try { Get-HTOneDriveSharing -UserId $u.Id -Label $u.Label -OnlyExternal:$a.External }
                catch { Write-Log -Message "Udostępnienia OneDrive $($u.Label): $($_.Exception.Message)" -Type 'Warn' }
            }
        }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Usuń link / udostępnienie' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        $items = @($rows | Where-Object { $_.__permId })
        if (-not $items.Count) { return }
        if (-not (Assert-HTGraphScopes -Scopes @('Files.ReadWrite.All') -Feature 'Usuwanie udostępnień')) { return }
        Invoke-HTRowAction -Module $m -Name 'Usunięcie udostępnienia' -Rows $items -Danger -Confirm 'Usunąć zaznaczone linki i udostępnienia? Osoby z linkiem stracą dostęp.' -Label { param($r) "$($r.Element) - $($r.Udostępnienie)" } -Action { param($r) Remove-HTDriveItemPermission -DriveId $r.__driveId -ItemId $r.__itemId -PermissionId $r.__permId; 'Usunięto' }
    }
}
#endregion
