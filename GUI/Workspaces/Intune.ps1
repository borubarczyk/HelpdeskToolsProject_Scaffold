# Przestrzeń robocza: Intune - urządzenia zarządzane (Microsoft Graph)

Register-HTWorkspace -Key 'Intune' -Title 'Intune' -Icon 'E7F8' -Panel 'devices' -Service 'Graph' `
    -Description 'Urządzenia Intune: szczegóły, zgodność, akcje zdalne (Defender, blokada, wipe), BitLocker i LAPS, raporty' `
    -Categories @('Urządzenie', 'Akcje zdalne', 'Bezpieczeństwo', 'Raporty')

$panel = New-HTTargetPanel -Key 'devices' -Title 'Urządzenia Intune' -Placeholder 'Szukaj (nazwa, użytkownik, numer seryjny, model)…' -EmptyIcon 'E7F8' `
    -EmptyText 'Połącz z Microsoft 365 i kliknij «Wczytaj».' -Describe {
    param($d)
    $sync = Get-HTDaysSince $d.LastSync
    @{ Key = $d.Id; Title = $d.DeviceName; Sub = "$(if ($d.UserPrincipalName) { $d.UserPrincipalName } else { 'bez użytkownika' }) • $($d.OperatingSystem) $($d.OsVersion)"
        Dot = $(switch ($d.ComplianceState) { 'compliant' { if ($null -ne $sync -and $sync -gt 30) { 'warn' } else { 'ok' } } 'noncompliant' { 'crit' } default { 'warn' } })
        Search = "$($d.SerialNumber) $($d.Model) $($d.Manufacturer) $($d.UserDisplayName) $($d.ComplianceState) $($d.Ownership)" }
}
Add-HTPanelLoader -Panel $panel -Service 'Graph' -Loader { param($p) Get-HTIntuneDevices } | Out-Null
Add-HTPanelHint -Panel $panel -Text 'Kropka: zielona - zgodne, czerwona - niezgodne, żółta - stan nieznany lub brak synchronizacji ponad 30 dni.' | Out-Null

function Get-HTDeviceLabel { param($d) [string]$d.DeviceName }

#region Urządzenie
Register-HTModule -Workspace 'Intune' -Category 'Urządzenie' -Key 'int.details' -Title 'Szczegóły' -Icon 'E8A1' `
    -Description 'Użytkownik, system, zgodność, sprzęt, szyfrowanie i identyfikatory. «Sprzęt» - TPM, BIOS, bateria, adresy IP (API beta).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż szczegóły' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Szczegóły urządzenia' -Label { param($t) Get-HTDeviceLabel $t } -Action { param($t) ConvertTo-HTDetailRows -Data (Get-HTIntuneDeviceDetail -Id $t.Id) }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Sprzęt' -Icon 'E950' -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Informacje sprzętowe' -Label { param($t) Get-HTDeviceLabel $t } -Action { param($t) ConvertTo-HTDetailRows -Data (Get-HTIntuneHardwareInfo -Id $t.Id) }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Otwórz w Intune' -Icon 'E8A7' -OnClick {
        param($m)
        foreach ($t in @(Get-HTTargets -Module $m | Select-Object -First 5)) { Start-Process "https://intune.microsoft.com/#view/Microsoft_Intune_Devices/DeviceSettingsMenuBlade/~/overview/mdmDeviceId/$($t.Id)" }
    } | Out-Null
}

Register-HTModule -Workspace 'Intune' -Category 'Urządzenie' -Key 'int.apps' -Title 'Aplikacje' -Icon 'ECAA' `
    -Description 'Wykryte (zainstalowane) aplikacje - np. sprawdzenie wersji programu na wielu komputerach (filtr wyników).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż aplikacje' -Icon 'ECAA' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Wykryte aplikacje' -Label { param($t) Get-HTDeviceLabel $t } -Action { param($t) Get-HTIntuneDetectedApps -Id $t.Id }
    } | Out-Null
}

Register-HTModule -Workspace 'Intune' -Category 'Urządzenie' -Key 'int.groups' -Title 'Grupy urządzenia' -Icon 'E902' `
    -Description 'Grupy Entra ID, do których należy urządzenie (przypisania zasad i aplikacji), z regułami grup dynamicznych.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż grupy' -Icon 'E902' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Grupy urządzeń' -AlwaysShowObject -Label { param($t) Get-HTDeviceLabel $t } -Action {
            param($t)
            if (-not $t.AzureADDeviceId) { throw 'Urządzenie nie ma identyfikatora Entra ID.' }
            Get-HTIntuneDeviceGroups -AzureADDeviceId $t.AzureADDeviceId
        }
    } | Out-Null
}

Register-HTModule -Workspace 'Intune' -Category 'Urządzenie' -Key 'int.primary' -Title 'Użytkownik podstawowy' -Icon 'E77B' `
    -Description 'Primary User urządzenia (Portal firmy, przypisania, raporty). Zmiana np. po przekazaniu komputera innej osobie.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Użytkownik podstawowy' -AlwaysShowObject -Label { param($t) Get-HTDeviceLabel $t } -Action {
            param($t)
            $users = @(Get-HTIntunePrimaryUsers -Id $t.Id)
            if ($users.Count -eq 0) { return [PSCustomObject]@{ Użytkownik = '(brak)'; UPN = ''; __flag = 'muted' } }
            foreach ($u in $users) { [PSCustomObject]@{ Użytkownik = $u.displayName; UPN = $u.userPrincipalName } }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Zmień…' -Icon 'E8FA' -OnClick {
        param($m)
        $targets = @(Get-HTTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $user = Select-HTM365User -Title 'Użytkownik podstawowy' -Prompt "Dla urządzeń: $($targets.Count)"
        if (-not $user) { return }
        Invoke-HTTargetAction -Module $m -Name 'Zmiana użytkownika podstawowego' -Targets $targets -Label { param($t) Get-HTDeviceLabel $t } -Action { param($t) Set-HTIntunePrimaryUser -Id $t.Id -UserId $user.Id; "Użytkownik: $($user.UserPrincipalName)" }
    } | Out-Null
}

Register-HTModule -Workspace 'Intune' -Category 'Urządzenie' -Key 'int.rename' -Title 'Zmiana nazwy' -Icon 'E8AC' `
    -Description 'Zmiana nazwy urządzenia Windows / macOS (wymaga restartu urządzenia; maks. 15 znaków: litery, cyfry, myślnik).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Nowa nazwa'
    $m.C.Name = Add-HTTextBox -Parent $row -Width 200 -Placeholder 'np. PL-LAP-0123'
    Add-HTButton -Parent $row -Module $m -Text 'Zmień nazwę' -Icon 'E8AC' -Primary -OnClick {
        param($m)
        $name = $m.C.Name.Text.Trim()
        $t = @(Get-HTTargets -Module $m -Single)[0]
        if (-not $t -or -not $name) { return }
        Invoke-HTTargetAction -Module $m -Name 'Zmiana nazwy' -Targets @($t) -Confirm "Zmienić nazwę $($t.DeviceName) na $($name)?" -Label { param($t) Get-HTDeviceLabel $t } -Action { param($t) Rename-HTIntuneDevice -Id $t.Id -NewName $name; "Nowa nazwa: $name (po restarcie)" }
    } | Out-Null
}
#endregion

#region Akcje zdalne
Register-HTModule -Workspace 'Intune' -Category 'Akcje zdalne' -Key 'int.actions' -Title 'Akcje zdalne' -Icon 'E7E8' `
    -Description 'Synchronizacja, restart, skanowanie i aktualizacja Microsoft Defender, zdalna blokada, rotacja kluczy BitLocker i hasła LAPS.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Zarządzanie'
    Add-HTButton -Parent $row -Module $m -Text 'Synchronizuj' -Icon 'E895' -Primary -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Synchronizacja' -Label { param($t) Get-HTDeviceLabel $t } -Action { param($t) Sync-HTIntuneDevice -Id $t.Id; 'Wysłano żądanie synchronizacji' }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Uruchom ponownie' -Icon 'E777' -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Restart' -Confirm 'Uruchomić ponownie wybrane urządzenia? Użytkownik może utracić niezapisane dane.' -Label { param($t) Get-HTDeviceLabel $t } -Action { param($t) Restart-HTIntuneDevice -Id $t.Id; 'Wysłano żądanie restartu' }
    } | Out-Null
    $row2 = Add-HTToolbarRow -Module $m -Title 'Microsoft Defender'
    foreach ($a in @(@('QuickScan', 'Szybkie skanowanie', 'E721'), @('FullScan', 'Pełne skanowanie', 'E9F5'), @('UpdateSignatures', 'Aktualizuj sygnatury', 'E896'))) {
        $b = Add-HTButton -Parent $row2 -Module $m -Text $a[1] -Icon $a[2] -OnClick {
            param($m, $s)
            $action = [string]$s.Tag
            Invoke-HTTargetAction -Module $m -Name $(switch ($action) { 'QuickScan' { 'Szybkie skanowanie' } 'FullScan' { 'Pełne skanowanie' } default { 'Aktualizacja sygnatur' } }) -Label { param($t) Get-HTDeviceLabel $t } -Action { param($t) Invoke-HTIntuneDeviceAction -Id $t.Id -Action $action }
        }
        $b.Tag = $a[0]
    }
    $row3 = Add-HTToolbarRow -Module $m -Title 'Bezpieczeństwo'
    Add-HTButton -Parent $row3 -Module $m -Text 'Zablokuj zdalnie' -Icon 'E72E' -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Zdalna blokada' -Confirm 'Zablokować ekran wybranych urządzeń (telefony / tablety)?' -Label { param($t) Get-HTDeviceLabel $t } -Action { param($t) Invoke-HTIntuneDeviceAction -Id $t.Id -Action RemoteLock }
    } | Out-Null
    Add-HTButton -Parent $row3 -Module $m -Text 'Rotuj klucze BitLocker' -Icon 'E8D7' -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Rotacja kluczy BitLocker' -Confirm 'Wygenerować nowe klucze odzyskiwania BitLocker (np. po podaniu klucza użytkownikowi)?' -Label { param($t) Get-HTDeviceLabel $t } -Action { param($t) Invoke-HTIntuneDeviceAction -Id $t.Id -Action RotateBitLocker }
    } | Out-Null
    Add-HTButton -Parent $row3 -Module $m -Text 'Rotuj hasło LAPS' -Icon 'E8D7' -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Rotacja hasła LAPS' -Confirm 'Wymusić zmianę hasła lokalnego administratora (Windows LAPS)?' -Label { param($t) Get-HTDeviceLabel $t } -Action { param($t) Invoke-HTIntuneDeviceAction -Id $t.Id -Action RotateLaps }
    } | Out-Null
    Add-HTButton -Parent $row3 -Module $m -Text 'Zlokalizuj' -Icon 'E81D' -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Lokalizacja urządzenia' -Label { param($t) Get-HTDeviceLabel $t } -Action { param($t) Invoke-HTIntuneDeviceAction -Id $t.Id -Action Locate }
    } | Out-Null
}

Register-HTModule -Workspace 'Intune' -Category 'Akcje zdalne' -Key 'int.wipe' -Title 'Wycofanie i czyszczenie' -Icon 'E74D' `
    -Description 'Akcje nieodwracalne: wycofanie (usunięcie danych firmowych), przywrócenie ustawień fabrycznych i usunięcie rekordu z Intune.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Wycofanie'
    Add-HTButton -Parent $row -Module $m -Text 'Wycofaj (retire)' -Icon 'E8F8' -Danger -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Wycofanie urządzenia' -Danger -TypeToConfirm 'WYCOFAJ' -Confirm 'Usunąć dane, aplikacje i profile firmowe z wybranych urządzeń? Dane prywatne pozostaną.' -Label { param($t) Get-HTDeviceLabel $t } -Action { param($t) Invoke-HTIntuneDeviceAction -Id $t.Id -Action Retire }
    } | Out-Null
    $row2 = Add-HTToolbarRow -Module $m -Title 'Ustawienia fabryczne'
    $m.C.KeepEnrollment = Add-HTCheckBox -Parent $row2 -Text 'Zachowaj rejestrację (Autopilot)'
    $m.C.KeepUser = Add-HTCheckBox -Parent $row2 -Text 'Zachowaj dane użytkownika'
    Add-HTButton -Parent $row2 -Module $m -Text 'Wyczyść (wipe)' -Icon 'E74D' -Danger -OnClick {
        param($m)
        $keepEnrollment = Test-HTChecked $m.C.KeepEnrollment
        $keepUser = Test-HTChecked $m.C.KeepUser
        Invoke-HTTargetAction -Module $m -Name 'Przywrócenie ustawień fabrycznych' -Danger -TypeToConfirm 'WYCZYŚĆ' -Confirm 'Przywrócić ustawienia fabryczne wybranych urządzeń? Wszystkie dane zostaną usunięte.' -Label { param($t) Get-HTDeviceLabel $t } -Action {
            param($t)
            Invoke-HTIntuneWipe -Id $t.Id -KeepEnrollmentData $keepEnrollment -KeepUserData $keepUser
            'Wysłano żądanie wipe'
        }
    } | Out-Null
    $row3 = Add-HTToolbarRow -Module $m -Title 'Rekord Intune'
    Add-HTButton -Parent $row3 -Module $m -Text 'Usuń z Intune' -Icon 'E74D' -Danger -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Usunięcie z Intune' -Danger -TypeToConfirm 'USUŃ' -Confirm 'Usunąć rekordy urządzeń z Intune (np. sprzęt wycofany z użycia)? Urządzenie przestanie być zarządzane.' -Label { param($t) Get-HTDeviceLabel $t } -Action {
            param($t)
            Remove-HTIntuneDevice -Id $t.Id
            Remove-HTTargetItem -Panel (Get-HTPanel 'devices') -Item $t
            'Usunięto'
        }
    } | Out-Null
}
#endregion

#region Bezpieczeństwo
Register-HTModule -Workspace 'Intune' -Category 'Bezpieczeństwo' -Key 'int.compliance' -Title 'Zgodność i zasady' -Icon 'E73E' `
    -Description 'Stan zasad zgodności i profili konfiguracji na urządzeniu z listą niespełnionych ustawień - dlaczego urządzenie jest niezgodne?' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Sprawdź zasady' -Icon 'E73E' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Zasady urządzenia' -Label { param($t) Get-HTDeviceLabel $t } -Action { param($t) Get-HTIntunePolicyStates -Id $t.Id }
    } | Out-Null
}

Register-HTModule -Workspace 'Intune' -Category 'Bezpieczeństwo' -Key 'int.secrets' -Title 'BitLocker i LAPS' -Icon 'E8D7' `
    -Description 'Klucze odzyskiwania BitLocker i hasło lokalnego administratora (Windows LAPS) zapisane w Entra ID. Odczyt jest audytowany.' -Build {
    param($m)
    $m.SecretColumns = @('Klucz', 'Hasło')
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Klucze BitLocker' -Icon 'E8D7' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Klucze BitLocker' -AlwaysShowObject -Label { param($t) Get-HTDeviceLabel $t } -Action {
            param($t)
            if (-not $t.AzureADDeviceId) { throw 'Urządzenie nie ma identyfikatora Entra ID.' }
            $keys = @(Get-HTBitLockerRecoveryKeys -AzureADDeviceId $t.AzureADDeviceId)
            if ($keys.Count -eq 0) { return [PSCustomObject]@{ 'ID klucza' = '(brak kluczy w Entra ID)'; __flag = 'muted' } }
            foreach ($k in $keys) { [PSCustomObject]@{ 'ID klucza' = $k.KeyId; Wolumin = $k.VolumeType; Utworzono = $k.Created; Klucz = $k.Key } }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Hasło LAPS' -Icon 'E7EF' -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Hasła LAPS' -AlwaysShowObject -Label { param($t) Get-HTDeviceLabel $t } -Action {
            param($t)
            if (-not $t.AzureADDeviceId) { throw 'Urządzenie nie ma identyfikatora Entra ID.' }
            $laps = Get-HTIntuneLapsPassword -AzureADDeviceId $t.AzureADDeviceId
            if (-not $laps) { return [PSCustomObject]@{ Konto = '(brak hasła LAPS)'; __flag = 'muted' } }
            [PSCustomObject]@{ Konto = $laps.Account; Hasło = $laps.Password; 'Kopia zapasowa' = $laps.BackupTime; 'Następna zmiana' = $laps.RefreshTime }
        }
    } | Out-Null
    Add-HTLabel -Parent $row -Hint -Text 'Wartości są ukryte - zaznacz «Pokaż poufne» lub skopiuj wiersz (schowek czyszczony po 60 s).' | Out-Null
}
#endregion

#region Raporty
function Register-HTIntuneReport {
    param([string]$Key, [string]$Title, [string]$Icon, [string]$Description, [scriptblock]$Filter, [switch]$Days)
    $script:IntuneReportDefs[$Key] = @{ Filter = $Filter; Days = [bool]$Days }
    Register-HTModule -Workspace 'Intune' -Category 'Raporty' -Key $Key -Title $Title -Icon $Icon -Description $Description -Build {
        param($m)
        $def = $script:IntuneReportDefs[$m.Key]
        $m.Data.Filter = $def.Filter
        $row = Add-HTToolbarRow -Module $m
        if ($def.Days) {
            Add-HTLabel -Parent $row -Text 'Brak synchronizacji od (dni):' | Out-Null
            $m.C.Days = Add-HTNumeric -Parent $row -Value 30 -Minimum 1 -Maximum 3650
        }
        Add-HTButton -Parent $row -Module $m -Text 'Generuj raport' -Icon 'E9D2' -Primary -OnClick {
            param($m)
            $days = if ($m.C.Days) { Get-HTNum $m.C.Days } else { 0 }
            $filter = $m.Data.Filter
            Invoke-HTQuery -Module $m -Name $m.Title -ScriptBlock {
                $devices = @(Get-HTIntuneDevices)
                $p = Get-HTPanel 'devices'
                if ($p) { Set-HTTargetItems -Panel $p -Items $devices }
                & $filter $devices $days
            }
        } | Out-Null
        Add-HTRowAction -Module $m -Text 'Zaznacz na liście urządzeń' -Icon 'E8B3' -Action {
            param($m, $rows)
            $p = Get-HTPanel 'devices'
            $ids = @($rows | ForEach-Object { [string]$_.Id })
            foreach ($r in $p.Table.Rows) { if ($ids -contains [string]$r['Key']) { $r['Sel'] = $true } }
            Update-HTTargetCount $p
            Show-HTToast 'Zaznaczono urządzenia na liście - wybierz akcję w module.' 'ok'
        }
    }
}
$script:IntuneReportDefs = @{}

function ConvertTo-HTDeviceReportRow {
    param($d, [string]$Flag = '')
    [PSCustomObject]@{
        Urządzenie            = $d.DeviceName
        Użytkownik            = $d.UserPrincipalName
        System                = "$($d.OperatingSystem) $($d.OsVersion)"
        Zgodność              = $d.ComplianceState
        'Ostatnia synchronizacja' = $d.LastSync
        'Dni bez synchronizacji' = Get-HTDaysSince $d.LastSync
        Szyfrowanie           = $d.Encrypted
        'Wolne (GB)'          = $d.StorageFreeGB
        Model                 = $d.Model
        'Numer seryjny'       = $d.SerialNumber
        Własność              = $d.Ownership
        Id                    = $d.Id
        __flag                = $Flag
    }
}

Register-HTIntuneReport -Key 'int.rep.noncompliant' -Title 'Niezgodne urządzenia' -Icon 'E7BA' -Description 'Urządzenia niezgodne z zasadami lub w okresie karencji.' -Filter {
    param($devices, $days)
    $devices | Where-Object { $_.ComplianceState -in 'noncompliant', 'inGracePeriod', 'error', 'conflict' } | ForEach-Object { ConvertTo-HTDeviceReportRow $_ $(if ($_.ComplianceState -eq 'noncompliant') { 'crit' } else { 'warn' }) }
}
Register-HTIntuneReport -Key 'int.rep.stale' -Title 'Nieaktywne urządzenia' -Icon 'E916' -Days -Description 'Urządzenia bez synchronizacji od wskazanej liczby dni (zgubione, wycofane, nieużywane).' -Filter {
    param($devices, $days)
    $devices | Where-Object { $idle = Get-HTDaysSince $_.LastSync; $null -eq $idle -or $idle -ge $days } | ForEach-Object { ConvertTo-HTDeviceReportRow $_ 'warn' }
}
Register-HTIntuneReport -Key 'int.rep.encryption' -Title 'Bez szyfrowania' -Icon 'E785' -Description 'Komputery Windows / macOS bez włączonego szyfrowania dysku.' -Filter {
    param($devices, $days)
    $devices | Where-Object { -not $_.Encrypted -and $_.OperatingSystem -match 'Windows|macOS' } | ForEach-Object { ConvertTo-HTDeviceReportRow $_ 'crit' }
}
Register-HTIntuneReport -Key 'int.rep.storage' -Title 'Mało miejsca na dysku' -Icon 'EDA2' -Description 'Urządzenia z mniej niż 10% lub 10 GB wolnego miejsca.' -Filter {
    param($devices, $days)
    $devices | Where-Object { $_.StorageTotalGB -gt 0 -and ($_.StorageFreeGB -lt 10 -or ($_.StorageFreeGB / $_.StorageTotalGB) -lt 0.1) } | Sort-Object StorageFreeGB | ForEach-Object { ConvertTo-HTDeviceReportRow $_ 'warn' }
}
Register-HTIntuneReport -Key 'int.rep.os' -Title 'Wersje systemów' -Icon 'E7F8' -Description 'Liczba urządzeń według systemu i wersji - planowanie aktualizacji.' -Filter {
    param($devices, $days)
    $devices | Group-Object { "$($_.OperatingSystem) $($_.OsVersion)" } | Sort-Object Count -Descending | ForEach-Object {
        [PSCustomObject]@{ System = $_.Name; Urządzenia = $_.Count; Niezgodne = @($_.Group | Where-Object { $_.ComplianceState -eq 'noncompliant' }).Count }
    }
}
#endregion
