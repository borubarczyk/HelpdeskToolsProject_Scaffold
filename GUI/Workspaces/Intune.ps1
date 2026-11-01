# Przestrzeń robocza: Intune - urządzenia zarządzane (Microsoft Graph)

Register-HTWorkspace -Key 'Intune' -Title 'Intune' -Icon 'E7F8' -Panel 'devices' -Service 'Graph' `
    -Description 'Urządzenia Intune: szczegóły, zgodność, akcje zdalne (Defender, blokada, wipe), BitLocker i LAPS, raporty' `
    -Categories @('Urządzenie', 'Akcje zdalne', 'Bezpieczeństwo', 'Autopilot', 'Aplikacje i aktualizacje', 'Porządki', 'Raporty')

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
        Invoke-HTTargetAction -Module $m -Name 'Zmiana użytkownika podstawowego' -Summary "Nowy użytkownik podstawowy: $($user.UserPrincipalName)" -Targets $targets -Label { param($t) Get-HTDeviceLabel $t } -Action { param($t) Set-HTIntunePrimaryUser -Id $t.Id -UserId $user.Id; "Użytkownik: $($user.UserPrincipalName)" }
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

# Akcje na urządzeniach z dowolnych wyników przestrzeni Intune (prawy przycisk > «Urządzenie Intune»)
Register-HTObjectKind -Kind 'IntuneDevice' -Title 'Urządzenie Intune' -Icon 'E7F8' -Service 'Graph' -Workspaces @('Intune') -Resolve {
    param($o)
    $guid = '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$'
    $p = $o.PSObject.Properties['ManagedDeviceId']
    if ($p -and "$($p.Value)" -match $guid) { return "$($p.Value)" }
    if ($o.PSObject.Properties['Urządzenie'] -or $o.PSObject.Properties['DeviceName']) {
        $p = $o.PSObject.Properties['Id']
        if ($p -and "$($p.Value)" -match $guid) { return "$($p.Value)" }
    }
    return $null
}
Register-HTObjectAction -Kind 'IntuneDevice' -Text 'Synchronizuj' -Icon 'E895' -Name 'Synchronizacja' -Action { param($Id, $Row) Sync-HTIntuneDevice -Id $Id; 'Wysłano żądanie synchronizacji' }
Register-HTObjectAction -Kind 'IntuneDevice' -Text 'Uruchom ponownie' -Icon 'E777' -Danger -Name 'Restart' -Confirm 'Uruchomić ponownie zaznaczone urządzenia? Użytkownik może utracić niezapisane dane.' -Action { param($Id, $Row) Restart-HTIntuneDevice -Id $Id; 'Wysłano polecenie restartu' }

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

#region Autopilot
Register-HTModule -Workspace 'Intune' -Category 'Autopilot' -Key 'int.autopilot' -Title 'Urządzenia Autopilot' -Icon 'E770' -Service 'Graph' `
    -Description 'Komputery zarejestrowane w Windows Autopilot: group tag, przypisanie profilu, stan rejestracji. Import skrótów sprzętowych z pliku CSV (Get-WindowsAutopilotInfo). Prawy przycisk - group tag, usunięcie.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    $m.Data.Refresh = { param($m) Invoke-HTQuery -Module $m -Name 'Urządzenia Autopilot' -Background -ScriptBlock { param($a) Get-HTAutopilotDevices } }
    Add-HTButton -Parent $row -Module $m -Text 'Pobierz urządzenia' -Icon 'E72C' -Primary -OnClick {
        param($m)
        if (-not (Assert-HTGraphScopes -Scopes @('DeviceManagementServiceConfig.ReadWrite.All') -Feature 'Windows Autopilot')) { return }
        & $m.Data.Refresh $m
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Importuj skróty (CSV)…' -Icon 'E8B5' -OnClick {
        param($m)
        if (-not (Assert-HTGraphScopes -Scopes @('DeviceManagementServiceConfig.ReadWrite.All') -Feature 'Windows Autopilot')) { return }
        $path = Select-HTOpenFile -Title 'Plik skrótów sprzętowych Autopilot' -Filter 'CSV (*.csv)|*.csv'
        if (-not $path) { return }
        $tag = Show-InputBox -Title 'Group tag' -Prompt 'Group tag dla importowanych urządzeń (opcjonalnie - puste: z pliku):' -AllowEmpty -Icon 'E8EC'
        if ($null -eq $tag) { return }
        $devices = @(Import-HTAutopilotCsv -Path $path -GroupTag $tag)
        if (-not $devices.Count) { Show-HTWarning 'Plik nie zawiera urządzeń (kolumny «Device Serial Number» i «Hardware Hash»).'; return }
        Invoke-HTTargetAction -Module $m -Name 'Import do Autopilot' -Targets $devices -Confirm "Zaimportować urządzeń: $($devices.Count)? Import trwa kilka-kilkanaście minut." -Label { param($d) $d.SerialNumber } -Action {
            param($d)
            $created = Add-HTAutopilotDevice -Device $d
            @{ Szczegóły = "Zlecono import$(if ($d.GroupTag) { " (group tag: $($d.GroupTag))" })"; __importId = $created.id }
        }
        Show-HTToast 'Import zlecony - stan sprawdzisz prawym przyciskiem («Stan importu») albo po kilku minutach w «Pobierz urządzenia».' 'info' 8
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Synchronizuj Autopilot' -Icon 'E895' -OnClick {
        param($m)
        try { Sync-HTAutopilot; Show-HTToast 'Zlecono synchronizację Autopilot.' 'ok' } catch { Show-HTError 'Nie zlecono synchronizacji.' $_ }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Stan importu' -Icon 'E916' -Action {
        param($m, $rows)
        $items = @($rows | Where-Object { $_.__importId })
        if (-not $items.Count) { Show-HTWarning 'Zaznacz wiersze zaimportowanych urządzeń.'; return }
        $data = @(foreach ($r in $items) { $st = Get-HTAutopilotImportStatus -Id $r.__importId; [PSCustomObject]@{ 'Numer seryjny' = $r.Obiekt; Stan = $st.Stan; Błąd = $st.Błąd; Kod = $st.Kod } })
        Show-HTDataViewer -Title 'Stan importu Autopilot' -Data $data -ExportName 'import_autopilot' -Icon 'E916'
    }
    Add-HTRowAction -Module $m -Text 'Ustaw group tag…' -Icon 'E8EC' -Action {
        param($m, $rows)
        $items = @($rows | Where-Object { $_.Id -and $_.'Numer seryjny' })
        if (-not $items.Count) { return }
        $tag = Show-InputBox -Title 'Group tag' -Prompt "Group tag dla urządzeń: $($items.Count) (puste - usunięcie tagu):" -AllowEmpty -DefaultText ([string]$items[0].'Group tag') -Icon 'E8EC'
        if ($null -eq $tag) { return }
        Invoke-HTRowAction -Module $m -Name 'Group tag Autopilot' -Summary "Group tag: $(if ($tag) { $tag } else { '(usunięcie tagu)' })" -Rows $items -Label { param($r) $r.'Numer seryjny' } -Action { param($r) Set-HTAutopilotGroupTag -Id $r.Id -GroupTag $tag; "Group tag: $(if ($tag) { $tag } else { '(brak)' })" } -Refresh $m.Data.Refresh
    }
    Add-HTRowAction -Module $m -Text 'Usuń z Autopilot' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        $items = @($rows | Where-Object { $_.Id -and $_.'Numer seryjny' })
        Invoke-HTRowAction -Module $m -Name 'Usunięcie z Autopilot' -Rows $items -Danger -TypeToConfirm 'USUŃ' -Confirm 'Usunąć urządzenia z Windows Autopilot (np. sprzedane lub zwrócone)? Urządzenie zarządzane w Intune usuń najpierw z Intune.' -Label { param($r) $r.'Numer seryjny' } -Action { param($r) Remove-HTAutopilotDevice -Id $r.Id; 'Usunięto' } -Refresh $m.Data.Refresh
    }
}

Register-HTModule -Workspace 'Intune' -Category 'Autopilot' -Key 'int.apprfiles' -Title 'Profile Autopilot' -Icon 'E770' -Service 'Graph' `
    -Description 'Profile wdrażania Windows Autopilot: tryb, szablon nazwy urządzenia, język, liczba przypisań.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pobierz profile' -Icon 'E72C' -Primary -OnClick {
        param($m)
        if (-not (Assert-HTGraphScopes -Scopes @('DeviceManagementServiceConfig.ReadWrite.All') -Feature 'Windows Autopilot')) { return }
        Invoke-HTQuery -Module $m -Name 'Profile Autopilot' -Background -ScriptBlock { param($a) Get-HTAutopilotProfiles }
    } | Out-Null
}
#endregion

#region Aplikacje i aktualizacje
Register-HTModule -Workspace 'Intune' -Category 'Aplikacje i aktualizacje' -Key 'int.appfail' -Title 'Błędy instalacji aplikacji' -Icon 'ECAA' -Service 'Graph' `
    -Description 'Aplikacje Intune z nieudanymi i oczekującymi instalacjami. Prawy przycisk - urządzenia z błędem, kod błędu i opis.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    $m.C.Failed = Add-HTCheckBox -Parent $row -Text 'Tylko aplikacje z błędami' -Checked $true
    Add-HTButton -Parent $row -Module $m -Text 'Pobierz' -Icon 'E72C' -Primary -OnClick {
        param($m)
        if (-not (Assert-HTGraphScopes -Scopes @('DeviceManagementApps.Read.All') -Feature 'Raport instalacji aplikacji')) { return }
        Invoke-HTQuery -Module $m -Name 'Instalacje aplikacji' -Background -Arguments @{ Failed = (Test-HTChecked $m.C.Failed) } -ScriptBlock { param($a) Get-HTAppInstallSummary -OnlyFailed:$a.Failed }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Urządzenia z błędem instalacji' -Icon 'E7BA' -Action {
        param($m, $rows)
        $data = @(foreach ($r in @($rows | Select-Object -First 10)) { Get-HTAppInstallFailures -AppId $r.Id -AppName $r.Aplikacja })
        Show-HTDataViewer -Title 'Błędy instalacji aplikacji' -Data $data -Description 'Kod błędu (hex) wyjaśnia przyczynę - np. 0x87D1041C: aplikacja nie wykryta po instalacji (reguła wykrywania).' -ExportName 'bledy_instalacji' -Icon 'E7BA'
    }
    Add-HTRowAction -Module $m -Text 'Wszystkie stany instalacji' -Icon 'E8FD' -Action {
        param($m, $rows)
        $data = @(foreach ($r in @($rows | Select-Object -First 5)) { Get-HTAppInstallFailures -AppId $r.Id -AppName $r.Aplikacja -All })
        Show-HTDataViewer -Title 'Stany instalacji aplikacji' -Data $data -ExportName 'stany_instalacji' -Icon 'E8FD'
    }
}

Register-HTModule -Workspace 'Intune' -Category 'Aplikacje i aktualizacje' -Key 'int.updates' -Title 'Aktualizacje Windows' -Icon 'E895' -Service 'Graph' `
    -Description 'Wydanie Windows i poziom poprawek (UBR) każdego komputera na tle najnowszego poziomu w firmie oraz wsparcie wydania. Pierścienie aktualizacji (odroczenia, wstrzymania, terminy).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Stan aktualizacji' -Icon 'E895' -Primary -OnClick {
        param($m)
        Invoke-HTQuery -Module $m -Name 'Stan aktualizacji Windows' -Background -ScriptBlock { param($a) Get-HTWindowsUpdateStatus | Sort-Object @{ Expression = { switch ($_.__flag) { 'crit' { 0 } 'warn' { 1 } default { 2 } } } }, Urządzenie }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Pierścienie aktualizacji' -Icon 'E9F5' -OnClick {
        param($m)
        Invoke-HTQuery -Module $m -Name 'Pierścienie aktualizacji' -Background -ScriptBlock { param($a) Get-HTWindowsUpdateRings }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Synchronizuj urządzenie' -Icon 'E895' -Action {
        param($m, $rows)
        $items = @($rows | Where-Object { $_.Urządzenie -and $_.Id })
        Invoke-HTRowAction -Module $m -Name 'Synchronizacja urządzenia' -Rows $items -Label { param($r) $r.Urządzenie } -Action { param($r) Sync-HTIntuneDevice -Id $r.Id; 'Zlecono synchronizację' }
    }
}

Register-HTModule -Workspace 'Intune' -Category 'Aplikacje i aktualizacje' -Key 'int.remediation' -Title 'Skrypty naprawcze' -Icon 'E90F' -Service 'Graph' `
    -Description 'Skrypty naprawcze Intune (Remediations): uruchomienie na żądanie na urządzeniach zaznaczonych na liście po lewej i wyniki wykrycia i naprawy. Wymaga licencji Windows Enterprise E3/E5.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pobierz skrypty' -Icon 'E72C' -Primary -OnClick {
        param($m)
        if (-not (Assert-HTGraphScopes -Scopes @('DeviceManagementConfiguration.ReadWrite.All') -Feature 'Skrypty naprawcze')) { return }
        Invoke-HTQuery -Module $m -Name 'Skrypty naprawcze' -Background -ScriptBlock { param($a) Get-HTRemediationScripts }
    } | Out-Null
    Add-HTLabel -Parent $row -Hint -Text 'Zaznacz urządzenia na liście po lewej, potem prawy przycisk na skrypcie - «Uruchom teraz».' | Out-Null
    Add-HTRowAction -Module $m -Text 'Uruchom teraz na zaznaczonych urządzeniach' -Icon 'E768' -Action {
        param($m, $rows)
        $script = @($rows)[0]
        $devices = @(Get-HTTargets -Module $m)
        if (-not $devices.Count) { return }
        Invoke-HTTargetAction -Module $m -Name "Skrypt naprawczy: $($script.Skrypt)" -Targets $devices -KeepResults -Confirm "Uruchomić skrypt «$($script.Skrypt)» na urządzeniach (przy najbliższej synchronizacji)?" -Label { param($t) Get-HTDeviceLabel $t } -Action {
            param($t)
            Start-HTRemediationOnDemand -DeviceId $t.Id -ScriptId $script.Id
            'Zlecono uruchomienie'
        }
    }
    Add-HTRowAction -Module $m -Text 'Pokaż wyniki na urządzeniach' -Icon 'E9D2' -Action {
        param($m, $rows)
        $data = @(foreach ($r in @($rows | Where-Object { $_.Skrypt -and $_.Id } | Select-Object -First 5)) { Get-HTRemediationRunStates -ScriptId $r.Id -ScriptName $r.Skrypt })
        Show-HTDataViewer -Title 'Wyniki skryptów naprawczych' -Data $data -ExportName 'skrypty_naprawcze' -Icon 'E9D2'
    }
}
#endregion

#region Porządki: duplikaty i nieaktywne obiekty
Register-HTModule -Workspace 'Intune' -Category 'Porządki' -Key 'int.duplicates' -Title 'Duplikaty urządzeń' -Icon 'E8C8' -Service 'Graph' `
    -Description 'Urządzenia Intune z tym samym numerem seryjnym (np. po ponownej instalacji Windows). Starsze wpisy są wyróżnione - prawy przycisk usuwa je z Intune.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Szukaj duplikatów' -Icon 'E721' -Primary -OnClick {
        param($m)
        Invoke-HTQuery -Module $m -Name 'Duplikaty urządzeń' -Background -ScriptBlock { param($a) Find-HTDuplicateDevices -Devices @(Get-HTIntuneDevices) }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Usuń starsze wpisy z Intune' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        $stale = @($rows | Where-Object { $_.__stale })
        if (-not $stale.Count) { Show-HTWarning 'Zaznacz wiersze oznaczone jako «starszy - do usunięcia».'; return }
        Invoke-HTRowAction -Module $m -Name 'Usunięcie duplikatu z Intune' -Rows $stale -Danger -TypeToConfirm 'USUŃ' -Confirm 'Usunąć starsze wpisy urządzeń z Intune? Najnowszy wpis każdego komputera zostaje.' -Label { param($r) "$($r.Urządzenie) ($($r.'Numer seryjny'))" } -Action { param($r) Remove-HTIntuneDevice -Id $r.Id; 'Usunięto' } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}

Register-HTModule -Workspace 'Intune' -Category 'Porządki' -Key 'int.staleentra' -Title 'Nieaktywne urządzenia Entra ID' -Icon 'E916' -Service 'Graph' `
    -Description 'Obiekty urządzeń w Entra ID bez logowania od N dni. Zalecane: najpierw wyłącz, po okresie obserwacji usuń. Urządzenia hybrydowe usuwaj w lokalnym AD (synchronizacja).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTLabel -Parent $row -Text 'Bez logowania od (dni):' | Out-Null
    $m.C.Days = Add-HTNumeric -Parent $row -Value 90 -Minimum 30 -Maximum 3650
    $m.C.Disabled = Add-HTCheckBox -Parent $row -Text 'Także wyłączone'
    Add-HTButton -Parent $row -Module $m -Text 'Szukaj' -Icon 'E721' -Primary -OnClick {
        param($m)
        Invoke-HTQuery -Module $m -Name 'Nieaktywne urządzenia Entra ID' -Background -Arguments @{ Days = (Get-HTNum $m.C.Days); Disabled = (Test-HTChecked $m.C.Disabled) } -ScriptBlock { param($a) Get-HTStaleEntraDevices -Days $a.Days -IncludeDisabled:$a.Disabled }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Wyłącz urządzenie' -Icon 'E711' -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Wyłączenie urządzenia Entra ID' -Rows $rows -Confirm 'Wyłączyć zaznaczone urządzenia? Logowanie z nich do usług Microsoft 365 przestanie działać (można je włączyć ponownie).' -Label { param($r) $r.Urządzenie } -Action {
            param($r)
            Set-HTEntraDeviceEnabled -Id $r.Id -Enabled $false
            Register-HTUndo -Operation 'Wyłączenie urządzenia Entra ID' -Object $r.Urządzenie -Kind 'EntraDevice' -Data @{ Id = $r.Id }
            'Wyłączono'
        }
    }
    Add-HTRowAction -Module $m -Text 'Włącz urządzenie' -Icon 'E73E' -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Włączenie urządzenia Entra ID' -Rows $rows -Label { param($r) $r.Urządzenie } -Action { param($r) Set-HTEntraDeviceEnabled -Id $r.Id -Enabled $true; 'Włączono' }
    }
    Add-HTRowAction -Module $m -Text 'Usuń urządzenie z Entra ID' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Usunięcie urządzenia Entra ID' -Rows $rows -Danger -TypeToConfirm 'USUŃ' -Confirm 'Trwale usunąć obiekty urządzeń z Entra ID? Usunięcie kasuje też klucze BitLocker zapisane przy urządzeniu.' -Label { param($r) $r.Urządzenie } -Action { param($r) Remove-HTEntraDevice -Id $r.Id; 'Usunięto' } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}
#endregion
