# Funkcja do logowania i zarządzania historią logów w aplikacji Helpdesk Tools
function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("Info", "Warn", "Error")]
        [string]$Type = "Info"
    )

    if (-not $global:LogHistory) {
        $global:LogHistory = New-Object System.Collections.Generic.List[object]
    }

    switch ($Type) {
        "Info" {
            $Message = "ℹ️ $Message"
        }
        "Warn" {
            $Message = "⚠️ $Message"
        }
        "Error" {
            $Message = "❌ $Message"
        }
        default {
            $Message = "[UNKNOWN] $Message"
        }
    }

    $logEntry = [PSCustomObject]@{
        Time    = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Type    = $Type
        Message = $Message
    }

    $global:LogHistory.Add($logEntry)
    Update-LogView
}

# Funkcja do aktualizacji widoku logów w GUI
function Update-LogView {
    # Sprawdź czy kontrolki są dostępne
    if (-not $HT_UI.LogsTab.FilterBox -or -not $HT_UI.LogsTab.FilterType -or -not $HT_UI.LogsTab.TextBox) {
        return
    }

    $filterText = $HT_UI.LogsTab.FilterBox.Text
    $selectedType = $HT_UI.LogsTab.FilterType.SelectedItem

    # Filtrowanie danych
    $filtered = $global:LogHistory | Where-Object {
        ($_.Message -like "*$filterText*") -and
        ($selectedType -eq "Wszystkie" -or $_.Type -eq $selectedType)
    }

    $textbox = $HT_UI.LogsTab.TextBox

    # Aktualizacja RichTextBoxa
    if ($textbox.InvokeRequired) {
        $textbox.Invoke([Action] {
                $textbox.Clear()
                foreach ($entry in $filtered) {
                    $textbox.AppendText("$($entry.Time) [$($entry.Type)] $($entry.Message)`r`n")
                }
                $textbox.ScrollToCaret()
            })
    }
    else {
        $textbox.Clear()
        foreach ($entry in $filtered) {
            $textbox.AppendText("$($entry.Time) [$($entry.Type)] $($entry.Message)`r`n")
        }
        $textbox.ScrollToCaret()
    }
}


# Funkcja do wyświetlania powiadomień w systemie
function Show-Toast {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$Title = "Helpdesk Tools",
        # Domyślny tytuł zmieniony na nazwę aplikacji
        [int]$Timeout = 2000,
        # Domyślny czas wyświetlania w milisekundach
        [ValidateSet("Info", "Warning", "Error")]
        [string]$NotificationType = "Info" # Typ komunikatu dla Write-ToTextBox
    )
	
    try {
        # Ładowanie wymaganych assembly
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
		
        # Tworzenie obiektu NotifyIcon
        $notify = New-Object System.Windows.Forms.NotifyIcon
		
        # Pobieranie ikony z bieżącego procesu lub domyślnej ikony systemowej
        try {
            $path = (Get-Process -Id $pid).Path
            if ($path -and (Test-Path $path)) {
                $notify.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($path)
            }
            else {
                $notify.Icon = [System.Drawing.SystemIcons]::Information
            }
        }
        catch {
            $notify.Icon = [System.Drawing.SystemIcons]::Information
        }
		
        # Konfiguracja powiadomienia
        $notify.BalloonTipTitle = $Title
        $notify.BalloonTipText = $Message
        $notify.Visible = $true
		
        # Wyświetlenie powiadomienia
        $notify.ShowBalloonTip($Timeout)
		
        # Zapisanie powiadomienia do TextBox za pomocą Write-ToTextBox
        try {
            Write-Log -Text "$Title : $Message" -Type $NotificationType
        }
        catch {
            Write-Warning "Nie udało się zapisać powiadomienia do TextBox: $_"
        }
		
		
        # Czyszczenie
        $notify.Visible = $false
        $notify.Dispose()
    }
    catch {
        Write-ToTextBox "Błąd podczas wyświetlania powiadomienia: $_"
    }
}

# Funkcja do sprawdzania, czy moduł jest zainstalowany
function Test-InstalledModule {
    param (
        [string]$ModuleName
    )
    return @(Get-Module -ListAvailable -Name $ModuleName).Count -gt 0
}

# Funkcja do ustawiania stanu wszystkich przycisków w GUI
function Set-ButtonsEnabled {
    param (
        [bool]$Enabled
    )

    $HT_UI.Buttons.Values | ForEach-Object {
        $_.Enabled = $Enabled
    }
}

# Funkcja odczytu konfiguracji z pliku JSON
function Read-Config {
    param (
        [string]$Path = ".\config.json"
    )

    if (-not (Test-Path $Path)) {
        Write-Log -Message "Plik konfiguracyjny nie istnieje: $Path" -Type "Warn"
        return $null
    }

    try {
        $json = Get-Content $Path -Raw | ConvertFrom-Json
        Write-Log -Message "Wczytano konfigurację z $Path" -Type "Info"
        return $json
    } catch {
        Write-Log -Message "Błąd odczytu pliku konfiguracyjnego: $($_.Exception.Message)" -Type "Error"
        return $null
    }
}

# Funkcja do wczytywania konfiguracji z pliku config.json
function Load-Configuration {
    [CmdletBinding()]
    param (
        [string]$Path = "$PSScriptRoot\Configs\config.json"
    )

    if (-not (Test-Path $Path)) {
        Write-Log -Message "Plik konfiguracyjny nie istnieje: $Path" -Type "Warn"
        return
    }

    try {
        $configContent = Get-Content -Raw -Path $Path | ConvertFrom-Json

        $Global:PasswordEmailAdress         = $configContent.PasswordEmailAdress
        $Global:PasswordEmailTitle          = $configContent.PasswordEmailTitle
        $Global:PasswordSpecialCharacters   = $configContent.PasswordSpecialCharacters
        $Global:PasswordUseWordBased        = $configContent.PasswordUseWordBased

        Write-Log -Message "Wczytano konfigurację z pliku config.json" -Type "Info"
    }
    catch {
        Write-Log -Message "Błąd wczytywania config.json: $($_.Exception.Message)" -Type "Error"
    }
}

# Funkcja do zapisywania danych do pliku
function Save-ContentToFile {
    param (
        [Parameter(Mandatory)]
        [array]$Data,

        [Parameter(Mandatory)]
        [ValidateSet("txt", "csv", "json")]
        [string]$Format,

        [string]$Path,  # <-- opcjonalna ścieżka

        [string]$Title = "Zapisz plik",
        [string]$DefaultName = "output",
        [string]$DefaultPath = "$PSScriptRoot\Exports"
    )

    if (-not $Data -or !$Data.Count) {
        Write-Log -Message "Brak danych do zapisania!" -Type "Warn"
        return
    }

    if (-not $Path) {
        if (-not (Test-Path $DefaultPath)) {
            New-Item -ItemType Directory -Path $DefaultPath | Out-Null
        }

        $dialog = New-Object System.Windows.Forms.SaveFileDialog
        $dialog.Title = $Title
        $dialog.Filter = switch ($Format) {
            "txt"  { "Pliki tekstowe (*.txt)|*.txt" }
            "csv"  { "Pliki CSV (*.csv)|*.csv" }
            "json" { "Pliki JSON (*.json)|*.json" }
        }
        $dialog.InitialDirectory = $DefaultPath
        $dialog.FileName = "$($DefaultName)_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').$Format"

        if ($dialog.ShowDialog() -ne "OK") {
            Write-Log -Message "Zapis anulowany przez użytkownika." -Type "Warn"
            return
        }

        $Path = $dialog.FileName
    }

    try {
        switch ($Format) {
            "txt"  { $Data | Out-File -FilePath $Path -Encoding UTF8 }
            "csv"  { $Data | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8 }
            "json" { $Data | ConvertTo-Json -Depth 5 | Out-File -FilePath $Path -Encoding UTF8 }
        }
        Write-Log -Message "✅ Zapisano dane do pliku: $Path" -Type "Info"
    }
    catch {
        Write-Log -Message "❌ Błąd zapisu: $($_.Exception.Message)" -Type "Error"
    }
}

