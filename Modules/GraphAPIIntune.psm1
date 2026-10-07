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
