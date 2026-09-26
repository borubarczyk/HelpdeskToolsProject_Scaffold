# Zarządzanie konfiguracją aplikacji (plik JSON w %APPDATA%\HelpdeskTools\config.json)

# Domyślne uprawnienia (scopes) Microsoft Graph wymagane przez zakładki Użytkownicy, Intune i Dashboard
$script:DefaultGraphScopes = @(
    "User.ReadWrite.All",
    "Directory.AccessAsUser.All",
    "Group.ReadWrite.All",
    "GroupMember.ReadWrite.All",
    "UserAuthenticationMethod.ReadWrite.All",
    "Organization.Read.All",
    "AuditLog.Read.All",
    "Device.Read.All",
    "DeviceManagementManagedDevices.ReadWrite.All",
    "DeviceManagementManagedDevices.PrivilegedOperations.All",
    "BitlockerKey.Read.All",
    "DeviceLocalCredential.Read.All",
    "Sites.Read.All"
)

# Zwraca domyślną konfigurację
function Get-HTDefaultConfig {
    return [ordered]@{
        PasswordEmailAdress       = ""
        PasswordEmailTitle        = "Nowe hasło"
        PasswordSpecialCharacters = "!@#$%^&*?"
        PasswordUseWordBased      = $false
        PasswordDefaultLength     = 12
        LogPasswordGeneration     = $false
        LogClientIDForPnP         = $false
        LastUsedClientID          = $null
        DefaultSharepointSite     = "https://contoso.sharepoint.com/sites/DefaultSite"
        DefaultUsageLocation      = "PL"
        GraphScopes               = $script:DefaultGraphScopes
        ShowNotifications         = $true
        LogFileMaxSizeMB          = 5
        ExportPath                = ""
    }
}

# Uzupełnia konfigurację o brakujące klucze domyślne. Zwraca obiekt oraz informację, czy coś dodano.
function Merge-HTConfig {
    [CmdletBinding()]
    param (
        [AllowNull()][object]$Config
    )

    $defaults = Get-HTDefaultConfig
    $merged = [ordered]@{}
    $added = @()

    if ($Config -is [System.Collections.IDictionary]) {
        foreach ($key in $Config.Keys) { $merged[$key] = $Config[$key] }
    }
    elseif ($Config) {
        foreach ($property in $Config.PSObject.Properties) {
            $merged[$property.Name] = $property.Value
        }
    }

    foreach ($key in $defaults.Keys) {
        if (-not $merged.Contains($key)) {
            $merged[$key] = $defaults[$key]
            $added += $key
        }
    }

    return [PSCustomObject]@{
        Config    = [PSCustomObject]$merged
        AddedKeys = $added
    }
}

function Get-HTConfig {
    [CmdletBinding()]
    param ([string]$Path = $Global:ConfigPath)
    if (Test-Path $Path) {
        try {
            $raw = Get-Content -Raw -Path $Path -Encoding utf8
            if ([string]::IsNullOrWhiteSpace($raw) -or $raw.Trim() -eq "null") {
                throw "Plik konfiguracyjny jest pusty."
            }
            return $raw | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Log -Message "Błąd parsowania pliku konfiguracyjnego: $($_.Exception.Message)" -Type "Error&Notification"
            return $null
        }
    }
    else {
        Write-Log -Message "Brak pliku konfiguracyjnego: $Path" -Type "Warn"
        return $null
    }
}

function Set-HTConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][object]$Config,
        [string]$Path = $Global:ConfigPath
    )

    $dir = Split-Path -Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $Config | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Force -Encoding utf8
    Write-Log -Message "Zapisano konfigurację do: $Path" -Type "Info"
}

function New-HTConfig {
    [CmdletBinding()]
    param ([string]$Path = $Global:ConfigPath)

    try {
        Set-HTConfig -Config (Get-HTDefaultConfig) -Path $Path
        Write-Log -Message "Utworzono plik konfiguracyjny: $Path" -Type "Info"
    }
    catch {
        Write-Log -Message "Błąd przy tworzeniu pliku konfiguracyjnego: $($_.Exception.Message)" -Type "Error&Notification"
    }
}

# Sprawdza istnienie konfiguracji, tworzy ją w razie potrzeby i uzupełnia brakujące klucze
function Ensure-HTConfig {
    [CmdletBinding()]
    param (
        [string]$Path = $Global:ConfigPath,
        # Tworzy plik bez pytania użytkownika
        [switch]$Force
    )

    if (-not (Test-Path $Path)) {
        Write-Log -Message "Plik konfiguracyjny nie istnieje: $Path" -Type "Warn"

        $create = $Force
        if (-not $create) {
            $response = Show-Dialog -Message "Plik konfiguracyjny nie istnieje:`n$Path`n`nUtworzyć go z ustawieniami domyślnymi?" `
                -Buttons "YesNo" -Type "Question" -Title "Brak pliku konfiguracyjnego"
            $create = ($response -eq [System.Windows.Forms.DialogResult]::Yes)
        }

        if (-not $create) {
            Write-Log -Message "Użytkownik anulował tworzenie konfiguracji - używam ustawień domyślnych (tylko w pamięci)." -Type "Info"
            return (Merge-HTConfig -Config $null).Config
        }

        New-HTConfig -Path $Path
    }

    $config = Get-HTConfig -Path $Path
    if ($null -eq $config) {
        Write-Log -Message "Nie udało się wczytać konfiguracji - używam ustawień domyślnych." -Type "Warn"
        return (Merge-HTConfig -Config $null).Config
    }

    $merge = Merge-HTConfig -Config $config
    if ($merge.AddedKeys.Count -gt 0) {
        Write-Log -Message "Uzupełniono konfigurację o nowe ustawienia: $($merge.AddedKeys -join ', ')" -Type "Info"
        try { Set-HTConfig -Config $merge.Config -Path $Path } catch { Write-Log -Message "Nie udało się zapisać uzupełnionej konfiguracji: $_" -Type "Warn" }
    }
    return $merge.Config
}

# Ustawia zmienne globalne na podstawie konfiguracji
function Apply-HTConfig {
    [CmdletBinding()]
    param ([object]$Config)

    if (-not $Config) {
        Write-Log -Message "Brak obiektu konfiguracji do zastosowania." -Type "Warn"
        return
    }

    $Config = (Merge-HTConfig -Config $Config).Config
    $Global:HTConfig = $Config

    $Global:PasswordEmailAdress = $Config.PasswordEmailAdress
    $Global:PasswordEmailTitle = $Config.PasswordEmailTitle
    $Global:PasswordSpecialCharacters = $Config.PasswordSpecialCharacters
    $Global:PasswordUseWordBased = [bool]$Config.PasswordUseWordBased
    $Global:PasswordDefaultLength = [int]$Config.PasswordDefaultLength
    $Global:LogPasswordGeneration = [bool]$Config.LogPasswordGeneration
    $Global:LogClientIDForPnP = [bool]$Config.LogClientIDForPnP
    $Global:LastUsedClientID = $Config.LastUsedClientID
    $Global:DefaultSharepointSite = $Config.DefaultSharepointSite
    $Global:DefaultUsageLocation = $Config.DefaultUsageLocation
    $Global:GraphScopes = @($Config.GraphScopes | Where-Object { $_ })
    $Global:ShowNotifications = [bool]$Config.ShowNotifications
    $Global:LogFileMaxSizeMB = $Config.LogFileMaxSizeMB
    $Global:ExportPath = $Config.ExportPath

    if ($Global:PasswordDefaultLength -lt 8 -or $Global:PasswordDefaultLength -gt 64) { $Global:PasswordDefaultLength = 12 }
    if ($Global:GraphScopes.Count -eq 0) { $Global:GraphScopes = $script:DefaultGraphScopes }

    Write-Log -Message "Zastosowano konfigurację (e-mail: '$($Global:PasswordEmailAdress)', hasła słowne: $($Global:PasswordUseWordBased), domyślna witryna SharePoint: $($Global:DefaultSharepointSite))." -Type "Info"

    if ($Global:HT_UI -and $Global:HT_UI.PasswordGeneratorWindow -and $Global:HT_UI.PasswordGeneratorWindow.SpecialCharacters) {
        $Global:HT_UI.PasswordGeneratorWindow.SpecialCharacters.Text = $Global:PasswordSpecialCharacters
    }
    if ($Global:HT_UI -and $Global:HT_UI.SharePointTab -and $Global:HT_UI.SharePointTab.SiteBox -and -not $Global:ConnectedToSharepointPnP) {
        $Global:HT_UI.SharePointTab.SiteBox.Text = $Global:DefaultSharepointSite
    }
}

# Zapisuje pojedyncze ustawienie w konfiguracji i pliku
function Set-HTConfigValue {
    param (
        [Parameter(Mandatory)][string]$Name,
        [AllowNull()][object]$Value
    )
    $config = (Merge-HTConfig -Config $Global:HTConfig).Config
    $config.$Name = $Value
    $Global:HTConfig = $config
    if ($Global:ConfigPath) { Set-HTConfig -Config $config -Path $Global:ConfigPath }
}
