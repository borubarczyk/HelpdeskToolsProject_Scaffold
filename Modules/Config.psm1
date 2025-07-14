function Get-HTConfig {
    [CmdletBinding()]
    param ([string]$Path = $Global:ConfigPath)

    if (Test-Path $Path) {
        try {
            return Get-Content -Raw -Path $Path | ConvertFrom-Json
        } catch {
            Write-Log -Message "Błąd parsowania JSON: $_" -Type "Error&Notification"
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

    if ($Config -is [pscustomobject]) {
        $Config = $Config | ConvertTo-Json -Depth 10 | ConvertFrom-Json -AsHashtable
    }

    $Config | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Force
    Write-Log -Message "Zapisano konfigurację do: $Path" -Type "Info"

}

function New-HTConfig {
    [CmdletBinding()]
    param ([string]$Path = $Global:ConfigPath)

    $defaultConfig = @{
        PasswordEmailAdress       = ""
        PasswordEmailTitle        = "Nowe hasło"
        PasswordSpecialCharacters = "!@#$%^&*?"
        PasswordUseWordBased      = $false
        LogPasswordGeneration     = $true
    }

    try {
        if (-not (Test-Path (Split-Path $Path))) {
            New-Item -ItemType Directory -Path (Split-Path $Path) | Out-Null
        }
        $defaultConfig | ConvertTo-Json -Depth 5 | Set-Content -Path $Path -Encoding UTF8
        Write-Log -Message "Utworzono plik konfiguracyjny: $Path" -Type "Info"
    } catch {
        Write-Log -Message "Błąd przy tworzeniu pliku konfiguracyjnego: $($_.Exception.Message)" -Type "Error&Notification"
    }
}

function Ensure-HTConfig {
    [CmdletBinding()]
    param ([string]$Path = $Global:ConfigPath)

    if (-not (Test-Path $Path)) {
        Write-Log -Message "Plik konfiguracyjny nie istnieje: $Path" -Type "Warn"

        $response = Show-Dialog -Message "Plik konfiguracyjny nie istnieje:`n$Path`nUtworzyć go?" `
            -Buttons "YesNo" -Type "Question" -Title "Brak pliku konfiguracyjnego"

        if ($response -ne 'Yes') {
            Write-Log -Message "Użytkownik anulował tworzenie config." -Type "Info"
            return $null
        }

        New-HTConfig -Path $Path
    }

    return Get-HTConfig -Path $Path
}

function Apply-HTConfig {
    [CmdletBinding()]
    param ([object]$Config)

    if (-not $Config) {
        Write-Log -Message "Brak obiektu konfiguracji do zastosowania." -Type "Warn"
        return
    }

    $Global:PasswordEmailAdress       = $Config.PasswordEmailAdress
    $Global:PasswordEmailTitle        = $Config.PasswordEmailTitle
    $Global:PasswordSpecialCharacters = $Config.PasswordSpecialCharacters
    $Global:PasswordUseWordBased      = $Config.PasswordUseWordBased
    $Global:LogPasswordGeneration     = $Config.LogPasswordGeneration

    Write-Log -Message "Zastosowano konfigurację:" -Type "Info"
    Write-Log -Message " - Email: $($Global:PasswordEmailAdress)" -Type "Info"
    Write-Log -Message " - Tytuł: $($Global:PasswordEmailTitle)" -Type "Info"
    Write-Log -Message " - Znaki: $($Global:PasswordSpecialCharacters)" -Type "Info"
    Write-Log -Message " - Hasła słowne: $($Global:PasswordUseWordBased)" -Type "Info"
    Write-Log -Message " - Loguj generowanie: $($Global:LogPasswordGeneration)" -Type "Info"

    if ($HT_UI -and $HT_UI.PasswordGeneratorWindow.SpecialCharacters) {
        $HT_UI.PasswordGeneratorWindow.SpecialCharacters.Text = $Global:PasswordSpecialCharacters
    }

}