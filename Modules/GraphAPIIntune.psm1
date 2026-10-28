# Urządzenia Intune przez Microsoft Graph REST
# Część operacji (zmiana nazwy, Primary User, informacje sprzętowe) dostępna jest wyłącznie w API beta.

# Nagłówki wymagane przez API BitLocker i LAPS (audyt)
$script:AuditHeaders = @{
    "ocp-client-name"    = "HelpdeskTools"
    "ocp-client-version" = "1.0"
}

# Lista zarządzanych urządzeń
function Get-HTIntuneDevices {
    $select = "id,deviceName,userPrincipalName,userDisplayName,operatingSystem,osVersion,complianceState,lastSyncDateTime,enrolledDateTime,serialNumber,model,manufacturer,azureADDeviceId,managedDeviceOwnerType,isEncrypted,totalStorageSpaceInBytes,freeStorageSpaceInBytes"
    $devices = Invoke-HTGraphRequest -Uri "deviceManagement/managedDevices?`$select=$select" -All
    return @($devices | ForEach-Object {
            [PSCustomObject]@{
                Id               = $_.id
                DeviceName       = $_.deviceName
                UserPrincipalName = $_.userPrincipalName
                UserDisplayName  = $_.userDisplayName
                OperatingSystem  = $_.operatingSystem
                OsVersion        = $_.osVersion
                ComplianceState  = $_.complianceState
                LastSync         = $_.lastSyncDateTime
                Enrolled         = $_.enrolledDateTime
                SerialNumber     = $_.serialNumber
                Model            = $_.model
                Manufacturer     = $_.manufacturer
                AzureADDeviceId  = $_.azureADDeviceId
                Ownership        = $_.managedDeviceOwnerType
                Encrypted        = [bool]$_.isEncrypted
                StorageTotalGB   = if ($_.totalStorageSpaceInBytes) { [Math]::Round($_.totalStorageSpaceInBytes / 1GB, 1) } else { $null }
                StorageFreeGB    = if ($_.freeStorageSpaceInBytes) { [Math]::Round($_.freeStorageSpaceInBytes / 1GB, 1) } else { $null }
            }
        } | Sort-Object DeviceName)
}

# Szczegóły urządzenia
function Get-HTIntuneDeviceDetail {
    param ([Parameter(Mandatory)][string]$Id)

    $d = Invoke-HTGraphRequest -Uri "deviceManagement/managedDevices/$Id"
    $primaryUsers = @()
    try {
        $primaryUsers = @(Get-HTIntunePrimaryUsers -Id $Id | ForEach-Object { "$($_.displayName) <$($_.userPrincipalName)>" })
    }
    catch { }

    return [ordered]@{
        "Nazwa"              = $d.deviceName
        "Użytkownik"         = "$($d.userDisplayName) <$($d.userPrincipalName)>"
        "Primary User"       = $primaryUsers
        "System"             = "$($d.operatingSystem) $($d.osVersion)"
        "Zgodność"           = $d.complianceState
        "Własność"           = $d.managedDeviceOwnerType
        "Ostatnia synchronizacja" = $d.lastSyncDateTime
        "Zarejestrowano"     = $d.enrolledDateTime
        "Sprzęt"             = [ordered]@{
            "Producent"       = $d.manufacturer
            "Model"           = $d.model
            "Numer seryjny"   = $d.serialNumber
            "Pamięć (całk.)"  = Format-HTBytes $d.totalStorageSpaceInBytes
            "Pamięć (wolna)"  = Format-HTBytes $d.freeStorageSpaceInBytes
            "Szyfrowanie"     = [bool]$d.isEncrypted
            "Adres MAC Wi-Fi" = $d.wiFiMacAddress
            "IMEI"            = $d.imei
        }
        "Zarządzanie"        = [ordered]@{
            "Agent"               = $d.managementAgent
            "Stan rejestracji"    = $d.deviceEnrollmentType
            "Azure AD Device ID"  = $d.azureADDeviceId
            "Zarejestrowane w AAD" = [bool]$d.azureADRegistered
            "Intune Device ID"    = $d.id
            "Kategoria"           = $d.deviceCategoryDisplayName
        }
    }
}

# Zmiana nazwy urządzenia (Windows / macOS - akcja setDeviceName, API beta)
function Rename-HTIntuneDevice {
    param (
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][ValidateLength(1, 15)][string]$NewName
    )
    if ($NewName -notmatch '^[A-Za-z0-9\-]+$') { throw "Nazwa może zawierać wyłącznie litery, cyfry i myślnik (max 15 znaków)." }
    Invoke-HTGraphRequest -Uri "deviceManagement/managedDevices/$Id/setDeviceName" -Method POST -Beta -Body @{ deviceName = $NewName } | Out-Null
}

# Primary User urządzenia
function Get-HTIntunePrimaryUsers {
    param ([Parameter(Mandatory)][string]$Id)
    return @(Invoke-HTGraphRequest -Uri "deviceManagement/managedDevices/$Id/users" -Beta)
}

function Set-HTIntunePrimaryUser {
    param (
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$UserId
    )
    $body = @{ "@odata.id" = "https://graph.microsoft.com/beta/users/$UserId" }
    Invoke-HTGraphRequest -Uri "deviceManagement/managedDevices/$Id/users/`$ref" -Method POST -Beta -Body $body | Out-Null
}

# Informacje sprzętowe (API beta - hardwareInformation)
function Get-HTIntuneHardwareInfo {
    param ([Parameter(Mandatory)][string]$Id)
    $d = Invoke-HTGraphRequest -Uri "deviceManagement/managedDevices/$Id`?`$select=id,deviceName,hardwareInformation,physicalMemoryInBytes,processorArchitecture,skuFamily,ethernetMacAddress" -Beta
    $hw = $d.hardwareInformation
    return [ordered]@{
        "Urządzenie"            = $d.deviceName
        "Procesor (architektura)" = $d.processorArchitecture
        "Pamięć RAM"            = Format-HTBytes $d.physicalMemoryInBytes
        "Edycja systemu"        = $d.skuFamily
        "MAC Ethernet"          = $d.ethernetMacAddress
        "Szczegóły sprzętu"     = [ordered]@{
            "Producent"             = $hw.manufacturer
            "Model"                 = $hw.model
            "Numer seryjny"         = $hw.serialNumber
            "Wersja BIOS/firmware"  = $hw.systemManagementBIOSVersion
            "TPM - wersja"          = $hw.tpmVersion
            "TPM - producent"       = $hw.tpmManufacturer
            "Pojemność dysku"       = Format-HTBytes $hw.totalStorageSpace
            "Wolne miejsce"         = Format-HTBytes $hw.freeStorageSpace
            "Adresy IP"             = @($hw.ipAddressV4)
            "Podsieć"               = $hw.subnetAddress
            "FQDN"                  = $hw.deviceFullQualifiedDomainName
            "Bateria (stan)"        = $hw.batteryHealthPercentage
            "Język systemu"         = $hw.operatingSystemLanguage
            "Edycja systemu"        = $hw.operatingSystemEdition
            "Wersja produktu"       = $hw.osBuildNumber
        }
    }
}

# Wykryte (zainstalowane) aplikacje
function Get-HTIntuneDetectedApps {
    param ([Parameter(Mandatory)][string]$Id)
    return @(Invoke-HTGraphRequest -Uri "deviceManagement/managedDevices/$Id/detectedApps" -All | ForEach-Object {
            [PSCustomObject]@{
                Name      = $_.displayName
                Version   = $_.version
                Publisher = $_.publisher
                Platform  = $_.platform
                SizeInMB  = if ($_.sizeInByte) { [Math]::Round($_.sizeInByte / 1MB, 1) } else { $null }
            }
        } | Sort-Object Name)
}

# Obiekt urządzenia w Entra ID na podstawie azureADDeviceId
function Get-HTEntraDevice {
    param ([Parameter(Mandatory)][string]$AzureADDeviceId)
    $found = @(Invoke-HTGraphRequest -Uri "devices?`$filter=deviceId eq '$AzureADDeviceId'&`$select=id,deviceId,displayName")
    if ($found.Count -eq 0) { throw "Nie znaleziono urządzenia w Entra ID (deviceId: $AzureADDeviceId)." }
    return $found[0]
}

# Grupy, do których należy urządzenie
function Get-HTIntuneDeviceGroups {
    param ([Parameter(Mandatory)][string]$AzureADDeviceId)
    $device = Get-HTEntraDevice -AzureADDeviceId $AzureADDeviceId
    return @(Invoke-HTGraphRequest -Uri "devices/$($device.id)/memberOf?`$select=id,displayName,groupTypes,membershipRule" -All | ForEach-Object {
            [PSCustomObject]@{
                Name    = $_.displayName
                Dynamic = (@($_.groupTypes) -contains "DynamicMembership")
                Rule    = $_.membershipRule
                Id      = $_.id
            }
        } | Sort-Object Name)
}

# Klucze odzyskiwania BitLocker (wymaga BitlockerKey.Read.All)
function Get-HTBitLockerRecoveryKeys {
    param ([Parameter(Mandatory)][string]$AzureADDeviceId)
    $keys = @(Invoke-HTGraphRequest -Uri "informationProtection/bitlocker/recoveryKeys?`$filter=deviceId eq '$AzureADDeviceId'" -Headers $script:AuditHeaders)
    return @($keys | ForEach-Object {
            $full = Invoke-HTGraphRequest -Uri "informationProtection/bitlocker/recoveryKeys/$($_.id)?`$select=key" -Headers $script:AuditHeaders
            [PSCustomObject]@{
                KeyId      = $_.id
                Created    = $_.createdDateTime
                VolumeType = $_.volumeType
                Key        = $full.key
            }
        } | Sort-Object Created -Descending)
}

# Hasło LAPS (Windows LAPS w Entra ID; wymaga DeviceLocalCredential.Read.All)
function Get-HTIntuneLapsPassword {
    param ([Parameter(Mandatory)][string]$AzureADDeviceId)
    $result = Invoke-HTGraphRequest -Uri "directory/deviceLocalCredentials/$AzureADDeviceId`?`$select=credentials,deviceName,lastBackupDateTime,refreshDateTime" -Headers $script:AuditHeaders
    $latest = @($result.credentials) | Sort-Object backupDateTime -Descending | Select-Object -First 1
    if (-not $latest) { return $null }
    $password = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($latest.passwordBase64))
    return [PSCustomObject]@{
        Account     = $latest.accountName
        Password    = $password
        BackupTime  = $latest.backupDateTime
        RefreshTime = $result.refreshDateTime
    }
}

# Wymuszenie synchronizacji
function Sync-HTIntuneDevice {
    param ([Parameter(Mandatory)][string]$Id)
    Invoke-HTGraphRequest -Uri "deviceManagement/managedDevices/$Id/syncDevice" -Method POST | Out-Null
}

# Zdalny restart
function Restart-HTIntuneDevice {
    param ([Parameter(Mandatory)][string]$Id)
    Invoke-HTGraphRequest -Uri "deviceManagement/managedDevices/$Id/rebootNow" -Method POST | Out-Null
}

# Podsumowanie urządzeń (Dashboard)
function Get-HTIntuneSummary {
    $devices = @(Invoke-HTGraphRequest -Uri "deviceManagement/managedDevices?`$select=id,complianceState" -All)
    return [PSCustomObject]@{
        Total        = $devices.Count
        NonCompliant = @($devices | Where-Object { $_.complianceState -eq "noncompliant" }).Count
    }
}

#region Akcje zdalne
# Definicje akcji: ścieżka API, treść żądania, wersja API
$script:DeviceActions = @{
    QuickScan        = @{ Path = "windowsDefenderScan"; Body = @{ quickScan = $true }; Text = "Szybkie skanowanie Defender" }
    FullScan         = @{ Path = "windowsDefenderScan"; Body = @{ quickScan = $false }; Text = "Pełne skanowanie Defender" }
    UpdateSignatures = @{ Path = "windowsDefenderUpdateSignatures"; Text = "Aktualizacja sygnatur Defender" }
    RemoteLock       = @{ Path = "remoteLock"; Text = "Zdalna blokada" }
    RotateBitLocker  = @{ Path = "rotateBitLockerKeys"; Beta = $true; Text = "Rotacja kluczy BitLocker" }
    RotateLaps       = @{ Path = "rotateLocalAdminPassword"; Beta = $true; Text = "Rotacja hasła LAPS" }
    Locate           = @{ Path = "locateDevice"; Text = "Lokalizacja urządzenia" }
    Retire           = @{ Path = "retire"; Text = "Wycofanie (usunięcie danych firmowych)" }
    Shutdown         = @{ Path = "shutDown"; Text = "Wyłączenie" }
}

function Invoke-HTIntuneDeviceAction {
    param (
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][ValidateSet("QuickScan", "FullScan", "UpdateSignatures", "RemoteLock", "RotateBitLocker", "RotateLaps", "Locate", "Retire", "Shutdown")][string]$Action
    )
    $definition = $script:DeviceActions[$Action]
    $body = if ($definition.Body) { $definition.Body } else { $null }
    Invoke-HTGraphRequest -Uri "deviceManagement/managedDevices/$Id/$($definition.Path)" -Method POST -Body $body -Beta:([bool]$definition.Beta) | Out-Null
    return $definition.Text
}

# Przywrócenie ustawień fabrycznych (wipe). KeepEnrollmentData / KeepUserData - zgodnie z opcjami Intune.
function Invoke-HTIntuneWipe {
    param (
        [Parameter(Mandatory)][string]$Id,
        [bool]$KeepEnrollmentData = $false,
        [bool]$KeepUserData = $false
    )
    $body = @{ keepEnrollmentData = $KeepEnrollmentData; keepUserData = $KeepUserData }
    Invoke-HTGraphRequest -Uri "deviceManagement/managedDevices/$Id/wipe" -Method POST -Body $body | Out-Null
}

# Usunięcie urządzenia z Intune (rekord zarządzania)
function Remove-HTIntuneDevice {
    param ([Parameter(Mandatory)][string]$Id)
    Invoke-HTGraphRequest -Uri "deviceManagement/managedDevices/$Id" -Method DELETE | Out-Null
}
#endregion

#region Zasady zgodności i konfiguracji urządzenia
function Get-HTIntunePolicyStates {
    param ([Parameter(Mandatory)][string]$Id)
    $stateNames = @{ compliant = "Zgodne"; noncompliant = "Niezgodne"; error = "Błąd"; conflict = "Konflikt"; notApplicable = "Nie dotyczy"; unknown = "Nieznany"; remediated = "Naprawione"; notAssigned = "Nieprzypisane" }
    $sources = @(
        @{ Kind = "Zgodność"; Uri = "deviceManagement/managedDevices/$Id/deviceCompliancePolicyStates" }
        @{ Kind = "Konfiguracja"; Uri = "deviceManagement/managedDevices/$Id/deviceConfigurationStates" }
    )
    foreach ($source in $sources) {
        $states = @()
        try { $states = @(Invoke-HTGraphRequest -Uri $source.Uri) }
        catch {
            [PSCustomObject]@{ Rodzaj = $source.Kind; Zasada = "(brak dostępu)"; Stan = "Błąd"; Ustawienie = ""; Szczegóły = $_.Exception.Message; __flag = "muted" }
            continue
        }
        foreach ($policy in $states) {
            $state = "$($policy.state)"
            $bad = @($policy.settingStates | Where-Object { "$($_.state)" -in "noncompliant", "nonCompliant", "error", "conflict" })
            [PSCustomObject]@{
                Rodzaj     = $source.Kind
                Zasada     = $policy.displayName
                Stan       = $stateNames[$state] ?? $state
                Ustawienie = ""
                Szczegóły  = "Platforma: $($policy.platformType); ustawień: $($policy.settingCount)"
                __flag     = if ($state -in "noncompliant", "nonCompliant", "error", "conflict") { "crit" } elseif ($state -in "notApplicable", "unknown") { "muted" } else { "" }
            }
            foreach ($setting in $bad) {
                $settingState = "$($setting.state)"
                [PSCustomObject]@{
                    Rodzaj     = $source.Kind
                    Zasada     = $policy.displayName
                    Stan       = $stateNames[$settingState] ?? $settingState
                    Ustawienie = if ($setting.settingName) { $setting.settingName } else { $setting.setting }
                    Szczegóły  = (@($setting.errorDescription, $setting.currentValue) | Where-Object { $_ }) -join "; "
                    __flag     = "warn"
                }
            }
        }
    }
}
#endregion

#region Autopilot
function Get-HTAutopilotDevices {
    # Urządzenia zarejestrowane w Windows Autopilot (DeviceManagementServiceConfig.Read.All)
    foreach ($d in @(Invoke-HTGraphRequest -Uri 'deviceManagement/windowsAutopilotDeviceIdentities?$top=1000' -All | Sort-Object serialNumber)) {
        [PSCustomObject]@{
            'Numer seryjny'      = $d.serialNumber
            Producent            = $d.manufacturer
            Model                = $d.model
            'Group tag'          = $d.groupTag
            'Stan profilu'       = $d.deploymentProfileAssignmentStatus
            'Stan rejestracji'   = $d.enrollmentState
            Użytkownik           = $d.userPrincipalName
            'Ostatni kontakt'    = $d.lastContactedDateTime
            'Urządzenie Intune'  = $d.managedDeviceId
            Id                   = $d.id
            __flag               = if ("$($d.deploymentProfileAssignmentStatus)" -match 'notAssigned|failed') { 'warn' } else { '' }
        }
    }
}

function Get-HTAutopilotProfiles {
    foreach ($p in @(Invoke-HTGraphRequest -Uri 'deviceManagement/windowsAutopilotDeploymentProfiles?$expand=assignments' -Beta -All)) {
        [PSCustomObject]@{
            Profil              = $p.displayName
            Opis                = $p.description
            Typ                 = ("$($p.'@odata.type')" -replace '#microsoft.graph.', '' -replace 'WindowsAutopilotDeploymentProfile', '')
            'Nazwa urządzenia'  = $p.deviceNameTemplate
            Język               = $p.language
            'Tryb użytkownika'  = $p.outOfBoxExperienceSettings.userType
            Przypisania         = @($p.assignments | Where-Object { $_ }).Count
            Zmieniono           = $p.lastModifiedDateTime
            Id                  = $p.id
        }
    }
}

function Set-HTAutopilotGroupTag {
    param ([Parameter(Mandatory)][string]$Id, [AllowEmptyString()][string]$GroupTag)
    Invoke-HTGraphRequest -Uri "deviceManagement/windowsAutopilotDeviceIdentities/$Id/updateDeviceProperties" -Method POST -Body @{ groupTag = $GroupTag } | Out-Null
}

function Remove-HTAutopilotDevice {
    param ([Parameter(Mandatory)][string]$Id)
    Invoke-HTGraphRequest -Uri "deviceManagement/windowsAutopilotDeviceIdentities/$Id" -Method DELETE | Out-Null
}

function Import-HTAutopilotCsv {
    <#
        Plik skrótu sprzętowego (Get-WindowsAutopilotInfo -OutputFile): kolumny «Device Serial Number», «Windows Product ID»,
        «Hardware Hash», opcjonalnie «Group Tag» i «Assigned User». Zwraca obiekty do importu.
    #>
    param ([Parameter(Mandatory)][string]$Path, [string]$GroupTag = '')
    $first = Get-Content -LiteralPath $Path -TotalCount 1 -Encoding utf8
    $delimiter = if ($first -match ';' -and $first -notmatch ',') { ';' } else { ',' }
    foreach ($r in @(Import-Csv -LiteralPath $Path -Delimiter $delimiter -Encoding utf8)) {
        $serial = ([string]$r.'Device Serial Number').Trim()
        $hash = ([string]$r.'Hardware Hash').Trim()
        if (-not $serial -or -not $hash) { continue }
        [PSCustomObject]@{
            SerialNumber = $serial
            ProductKey   = ([string]$r.'Windows Product ID').Trim()
            HardwareHash = $hash
            GroupTag     = $(if ($GroupTag) { $GroupTag } else { ([string]$r.'Group Tag').Trim() })
            AssignedUser = ([string]$r.'Assigned User').Trim()
        }
    }
}

function Add-HTAutopilotDevice {
    # Import urządzenia do Autopilot (stan importu: Get-HTAutopilotImportStatus)
    param ([Parameter(Mandatory)][object]$Device)
    $body = @{
        '@odata.type'      = '#microsoft.graph.importedWindowsAutopilotDeviceIdentity'
        serialNumber       = $Device.SerialNumber
        productKey         = [string]$Device.ProductKey
        hardwareIdentifier = $Device.HardwareHash
        groupTag           = [string]$Device.GroupTag
        state              = @{ '@odata.type' = 'microsoft.graph.importedWindowsAutopilotDeviceIdentityState'; deviceImportStatus = 'pending'; deviceRegistrationId = ''; deviceErrorCode = 0; deviceErrorName = '' }
    }
    if ($Device.AssignedUser) { $body.assignedUserPrincipalName = $Device.AssignedUser }
    return Invoke-HTGraphRequest -Uri 'deviceManagement/importedWindowsAutopilotDeviceIdentities' -Method POST -Body $body
}

function Get-HTAutopilotImportStatus {
    param ([Parameter(Mandatory)][string]$Id)
    $i = Invoke-HTGraphRequest -Uri "deviceManagement/importedWindowsAutopilotDeviceIdentities/$Id"
    return [PSCustomObject]@{ Stan = $i.state.deviceImportStatus; Błąd = $i.state.deviceErrorName; Kod = $i.state.deviceErrorCode }
}

function Sync-HTAutopilot {
    Invoke-HTGraphRequest -Uri 'deviceManagement/windowsAutopilotSettings/sync' -Method POST -Body @{} | Out-Null
}
#endregion

#region Raporty Intune (API raportów: Schema + Values)
function ConvertFrom-HTIntuneReport {
    # Odpowiedź raportu Intune ({ Schema = [{ Column }], Values = [[...]] }) jako obiekty
    param ([Parameter(Mandatory)][object]$Report)
    $columns = @($Report.Schema | ForEach-Object { [string]$_.Column })
    foreach ($values in @($Report.Values)) {
        $o = [ordered]@{}
        for ($i = 0; $i -lt $columns.Count; $i++) { $o[$columns[$i]] = @($values)[$i] }
        [PSCustomObject]$o
    }
}

function Invoke-HTIntuneReport {
    # Raport Intune (beta deviceManagement/reports/<Name>) - odpowiedź jest strumieniem JSON, zapis do pliku tymczasowego
    param ([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][hashtable]$Body)
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("HelpdeskTools_intune_" + [guid]::NewGuid().ToString('N') + '.json')
    try {
        Invoke-MgGraphRequest -Uri (Resolve-HTGraphUri -Uri "deviceManagement/reports/$Name" -Beta) -Method POST -Body ($Body | ConvertTo-Json -Depth 6 -Compress) -ContentType 'application/json' -OutputFilePath $tmp -ErrorAction Stop
        $report = Get-Content -LiteralPath $tmp -Raw -Encoding utf8 | ConvertFrom-Json
        return @(ConvertFrom-HTIntuneReport -Report $report)
    }
    finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
}

function Get-HTAppInstallSummary {
    # Aplikacje Intune z liczbą instalacji udanych, nieudanych i oczekujących; -OnlyFailed - tylko z błędami
    param ([switch]$OnlyFailed)
    $rows = @(Invoke-HTIntuneReport -Name 'getAppsInstallSummaryReport' -Body @{ top = 2000; skip = 0; select = @('DisplayName', 'Publisher', 'Platform', 'AppVersion', 'FailedDeviceCount', 'PendingInstallDeviceCount', 'InstalledDeviceCount', 'NotInstalledDeviceCount', 'NotApplicableDeviceCount', 'FailedUserCount', 'ApplicationId'); orderBy = @('FailedDeviceCount desc') })
    foreach ($r in $rows) {
        $failed = [int]$r.FailedDeviceCount
        if ($OnlyFailed -and $failed -eq 0) { continue }
        [PSCustomObject]@{
            Aplikacja        = $r.DisplayName
            Wydawca          = $r.Publisher
            Platforma        = $r.Platform
            Wersja           = $r.AppVersion
            'Błędy (urządzenia)' = $failed
            Oczekujące       = [int]$r.PendingInstallDeviceCount
            Zainstalowane    = [int]$r.InstalledDeviceCount
            'Nie zainstalowane' = [int]$r.NotInstalledDeviceCount
            'Błędy (użytkownicy)' = [int]$r.FailedUserCount
            Id               = $r.ApplicationId
            __flag           = if ($failed -gt 0) { 'crit' } elseif ([int]$r.PendingInstallDeviceCount -gt 0) { 'warn' } else { '' }
        }
    }
}

function Get-HTAppInstallFailures {
    # Urządzenia z nieudaną (albo każdą, -All) instalacją aplikacji: kod błędu i opis
    param ([Parameter(Mandatory)][string]$AppId, [string]$AppName = '', [switch]$All)
    $filter = "(ApplicationId eq '$AppId')"
    if (-not $All) { $filter += " and (InstallState eq '5')" }
    $rows = @(Invoke-HTIntuneReport -Name 'getDeviceInstallStatusReport' -Body @{ top = 2000; skip = 0; filter = $filter; select = @('DeviceName', 'UserPrincipalName', 'Platform', 'AppVersion', 'InstallState', 'InstallStateDetail', 'ErrorCode', 'HexErrorCode', 'LastModifiedDateTime', 'DeviceId') })
    foreach ($r in $rows) {
        [PSCustomObject]@{
            Aplikacja       = $AppName
            Urządzenie      = $r.DeviceName
            Użytkownik      = $r.UserPrincipalName
            Wersja          = $r.AppVersion
            Stan            = $r.InstallState_loc ?? $r.InstallState
            Szczegóły       = $r.InstallStateDetail_loc ?? $r.InstallStateDetail
            'Kod błędu'     = $(if ($r.HexErrorCode) { $r.HexErrorCode } else { $r.ErrorCode })
            Zmieniono       = $r.LastModifiedDateTime
            Id              = $r.DeviceId
            __flag          = if ("$($r.InstallState)" -in '5', 'failed') { 'crit' } else { '' }
        }
    }
}
#endregion

#region Aktualizacje Windows
# Koniec wsparcia wydań (Home/Pro oraz Enterprise/Education) - aktualizuj przy nowych wydaniach Windows
$script:WindowsBuilds = @{
    19044 = @{ Name = 'Windows 10 21H2'; EndPro = '2023-06-13'; EndEnt = '2024-06-11' }
    19045 = @{ Name = 'Windows 10 22H2'; EndPro = '2025-10-14'; EndEnt = '2025-10-14' }
    22000 = @{ Name = 'Windows 11 21H2'; EndPro = '2023-10-10'; EndEnt = '2024-10-08' }
    22621 = @{ Name = 'Windows 11 22H2'; EndPro = '2024-10-08'; EndEnt = '2025-10-14' }
    22631 = @{ Name = 'Windows 11 23H2'; EndPro = '2025-11-11'; EndEnt = '2026-11-10' }
    26100 = @{ Name = 'Windows 11 24H2'; EndPro = '2026-10-13'; EndEnt = '2027-10-12' }
    26200 = @{ Name = 'Windows 11 25H2'; EndPro = '2027-10-12'; EndEnt = '2028-10-10' }
}

function Get-HTWindowsVersionInfo {
    <#
        Wersja z numeru systemu (np. 10.0.22631.4317): kompilacja, UBR (poziom poprawek), nazwa wydania i wsparcie:
        Level 2 - pełne, 1 - tylko Enterprise/Education, 0 - brak (Windows 10 - tylko płatne ESU).
    #>
    param ([AllowEmptyString()][AllowNull()][string]$OsVersion, [datetime]$Now = (Get-Date))
    $parts = @("$OsVersion".Split('.'))
    $build = 0; $ubr = 0
    if ($parts.Count -ge 3) { [void][int]::TryParse($parts[2], [ref]$build) }
    if ($parts.Count -ge 4) { [void][int]::TryParse($parts[3], [ref]$ubr) }
    $known = $script:WindowsBuilds[$build]
    if (-not $known) {
        $name = if ($build -ge 22000) { "Windows 11 (kompilacja $build)" } elseif ($build -gt 0) { "Windows 10 (kompilacja $build)" } else { '' }
        $level = if ($build -gt 26200) { 2 } else { 0 }
        return @{ Build = $build; Ubr = $ubr; Name = $name; Level = $level; Support = $(if ($level -eq 2) { 'pełne' } else { 'brak' }) }
    }
    $endPro = [datetime]$known.EndPro
    $endEnt = [datetime]$known.EndEnt
    $level = if ($Now -lt $endPro) { 2 } elseif ($Now -lt $endEnt) { 1 } else { 0 }
    $support = switch ($level) { 2 { "pełne (Pro do $($known.EndPro))" } 1 { "tylko Enterprise/Education (do $($known.EndEnt))" } default { "brak (od $($known.EndEnt))" } }
    return @{ Build = $build; Ubr = $ubr; Name = $known.Name; Level = $level; Support = $support }
}

function Get-HTWindowsUpdateStatus {
    <#
        Komputery Windows: wydanie systemu i poziom poprawek (UBR) na tle najnowszego poziomu w firmie dla tej samej
        kompilacji. Czerwone - wydanie bez wsparcia, żółte - wsparcie tylko Enterprise albo poprawki starsze niż na
        najnowszym komputerze w firmie.
    #>
    param ([object[]]$Devices)
    if (-not $Devices) { $Devices = @(Get-HTIntuneDevices) }
    $windows = @($Devices | Where-Object { $_.OperatingSystem -eq 'Windows' })
    $info = @{}
    $maxUbr = @{}
    foreach ($d in $windows) {
        $v = Get-HTWindowsVersionInfo $d.OsVersion
        $info[$d.Id] = $v
        if (-not $maxUbr.ContainsKey($v.Build) -or $v.Ubr -gt $maxUbr[$v.Build]) { $maxUbr[$v.Build] = $v.Ubr }
    }
    foreach ($d in $windows) {
        $v = $info[$d.Id]
        $behind = $maxUbr[$v.Build] - $v.Ubr
        [PSCustomObject]@{
            Urządzenie                = $d.DeviceName
            Użytkownik                = $d.UserPrincipalName
            Wydanie                   = $v.Name
            Wersja                    = $d.OsVersion
            'Poziom poprawek (UBR)'   = $v.Ubr
            'Najnowszy w firmie'      = $maxUbr[$v.Build]
            Wsparcie                  = $v.Support
            'Ostatnia synchronizacja' = $d.LastSync
            Zgodność                  = $d.ComplianceState
            Id                        = $d.Id
            __flag                    = if ($v.Level -eq 0) { 'crit' } elseif ($v.Level -eq 1 -or $behind -gt 0) { 'warn' } else { '' }
        }
    }
}

function Get-HTWindowsUpdateRings {
    # Pierścienie aktualizacji Windows Update for Business
    $configs = @(Invoke-HTGraphRequest -Uri "deviceManagement/deviceConfigurations?`$filter=isof('microsoft.graph.windowsUpdateForBusinessConfiguration')" -All)
    foreach ($c in $configs) {
        [PSCustomObject]@{
            Pierścień                       = $c.displayName
            'Odroczenie poprawek (dni)'     = $c.qualityUpdatesDeferralPeriodInDays
            'Odroczenie wydań (dni)'        = $c.featureUpdatesDeferralPeriodInDays
            'Poprawki wstrzymane'           = [bool]$c.qualityUpdatesPaused
            'Wydania wstrzymane'            = [bool]$c.featureUpdatesPaused
            'Termin poprawek (dni)'         = $c.deadlineForQualityUpdatesInDays
            'Termin wydań (dni)'            = $c.deadlineForFeatureUpdatesInDays
            'Okres karencji (dni)'          = $c.deadlineGracePeriodInDays
            Zmieniono                       = $c.lastModifiedDateTime
            Id                              = $c.id
            __flag                          = if ($c.qualityUpdatesPaused -or $c.featureUpdatesPaused) { 'warn' } else { '' }
        }
    }
}
#endregion

#region Skrypty naprawcze (Remediations)
function Get-HTRemediationScripts {
    foreach ($s in @(Invoke-HTGraphRequest -Uri 'deviceManagement/deviceHealthScripts?$select=id,displayName,description,publisher,isGlobalScript,runAsAccount,lastModifiedDateTime' -Beta -All | Sort-Object displayName)) {
        [PSCustomObject]@{ Skrypt = $s.displayName; Opis = $s.description; Wydawca = $s.publisher; 'Skrypt Microsoft' = [bool]$s.isGlobalScript; Konto = $s.runAsAccount; Zmieniono = $s.lastModifiedDateTime; Id = $s.id }
    }
}

function Get-HTRemediationRunStates {
    param ([Parameter(Mandatory)][string]$ScriptId, [string]$ScriptName = '')
    foreach ($r in @(Invoke-HTGraphRequest -Uri "deviceManagement/deviceHealthScripts/$ScriptId/deviceRunStates?`$expand=managedDevice(`$select=deviceName,userPrincipalName)" -Beta -All)) {
        [PSCustomObject]@{
            Skrypt            = $ScriptName
            Urządzenie        = $r.managedDevice.deviceName
            Użytkownik        = $r.managedDevice.userPrincipalName
            Wykrycie          = $r.detectionState
            Naprawa           = $r.remediationState
            'Ostatni wynik'   = $r.lastStateUpdateDateTime
            'Wynik wykrycia'  = $r.preRemediationDetectionScriptOutput
            'Błąd'            = $(if ($r.remediationScriptError) { $r.remediationScriptError } else { $r.preRemediationDetectionScriptError })
            __flag            = if ("$($r.detectionState)" -eq 'fail' -or "$($r.remediationState)" -match 'Failed') { 'crit' } elseif ("$($r.detectionState)" -eq 'scriptError') { 'warn' } else { '' }
        }
    }
}

function Start-HTRemediationOnDemand {
    # Uruchomienie skryptu naprawczego na urządzeniu teraz (DeviceManagementManagedDevices.PrivilegedOperations.All)
    param ([Parameter(Mandatory)][string]$DeviceId, [Parameter(Mandatory)][string]$ScriptId)
    Invoke-HTGraphRequest -Uri "deviceManagement/managedDevices/$DeviceId/initiateOnDemandProactiveRemediation" -Method POST -Body @{ scriptPolicyId = $ScriptId } -Beta | Out-Null
}
#endregion

#region Duplikaty i nieaktywne obiekty urządzeń
function Find-HTDuplicateDevices {
    # Urządzenia Intune z tym samym numerem seryjnym - starsze wpisy (ostatnia synchronizacja) są kandydatami do usunięcia
    param ([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Devices)
    $groups = @($Devices | Where-Object { $_.SerialNumber -and $_.SerialNumber -notmatch '^(0+|Default string|System Serial Number|To be filled by O\.E\.M\.)$' } | Group-Object SerialNumber | Where-Object { $_.Count -gt 1 })
    foreach ($g in $groups) {
        $sorted = @($g.Group | Sort-Object { if ($_.LastSync) { [datetime]$_.LastSync } else { [datetime]::MinValue } } -Descending)
        for ($i = 0; $i -lt $sorted.Count; $i++) {
            $d = $sorted[$i]
            [PSCustomObject]@{
                'Numer seryjny'           = $g.Name
                Urządzenie                = $d.DeviceName
                Użytkownik                = $d.UserPrincipalName
                'Ostatnia synchronizacja' = $d.LastSync
                Zarejestrowano            = $d.Enrolled
                Wpis                      = $(if ($i -eq 0) { 'najnowszy - zostaw' } else { 'starszy - do usunięcia' })
                Id                        = $d.Id
                __stale                   = ($i -gt 0)
                __flag                    = if ($i -gt 0) { 'warn' } else { '' }
            }
        }
    }
}

function Get-HTStaleEntraDevices {
    # Urządzenia Entra ID bez logowania od -Days dni (Device.Read.All) - do wyłączenia, a później usunięcia
    param ([int]$Days = 90, [switch]$IncludeDisabled)
    $select = 'id,deviceId,displayName,operatingSystem,operatingSystemVersion,approximateLastSignInDateTime,accountEnabled,trustType,registrationDateTime,isManaged,isCompliant'
    foreach ($d in @(Invoke-HTGraphRequest -Uri "devices?`$select=$select&`$top=999" -All)) {
        if (-not $IncludeDisabled -and -not $d.accountEnabled) { continue }
        $idle = Get-HTDaysSince $d.approximateLastSignInDateTime
        if ($null -ne $idle -and $idle -lt $Days) { continue }
        $join = switch ("$($d.trustType)") { 'AzureAd' { 'Entra ID (dołączone)' } 'ServerAd' { 'hybrydowe (AD)' } 'Workplace' { 'zarejestrowane (BYOD)' } default { "$($d.trustType)" } }
        [PSCustomObject]@{
            Urządzenie           = $d.displayName
            System               = "$($d.operatingSystem) $($d.operatingSystemVersion)"
            Dołączenie           = $join
            'Ostatnie logowanie' = $d.approximateLastSignInDateTime
            'Dni bez logowania'  = $(if ($null -ne $idle) { $idle } else { 'nigdy' })
            Włączone             = [bool]$d.accountEnabled
            Zarządzane           = [bool]$d.isManaged
            Zarejestrowano       = $d.registrationDateTime
            DeviceId             = $d.deviceId
            Id                   = $d.id
            __flag               = if (-not $d.accountEnabled) { 'muted' } elseif ("$($d.trustType)" -eq 'ServerAd') { '' } else { 'warn' }
        }
    }
}

function Set-HTEntraDeviceEnabled {
    param ([Parameter(Mandatory)][string]$Id, [Parameter(Mandatory)][bool]$Enabled)
    Invoke-HTGraphRequest -Uri "devices/$Id" -Method PATCH -Body @{ accountEnabled = $Enabled } | Out-Null
}

function Remove-HTEntraDevice {
    param ([Parameter(Mandatory)][string]$Id)
    Invoke-HTGraphRequest -Uri "devices/$Id" -Method DELETE | Out-Null
}
#endregion
