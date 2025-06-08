# Funkcja do logowania i zarządzania historią logów w aplikacji Helpdesk Tools
function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("Info", "Warn", "Error", "Error&Notification", "Warning&Notification")]
        [string]$Type = "Info"
    )

    if (-not $global:LogHistory) {
        $global:LogHistory = New-Object System.Collections.Generic.List[object]
    }

    switch ($Type) {
        "Info" {
            $Message = "ℹ️ $Message"
            Append-LogToFile -Message $Message -Type "Info"
        }
        "Warn" {
            $Message = "⚠️ $Message"
            Append-LogToFile -Message $Message -Type "Warn"
        }
        "Warning&Notification" {
            $Message = "⚠️ $Message"
            Show-Toast -Message $Message -Title "Ostrzeżenie" -NotificationType "Warning"
            Append-LogToFile -Message $Message -Type "Warn"
        }
        "Error" {
            $Message = "❌ $Message"
            Append-LogToFile -Message $Message -Type "Error"
        }
        "Error&Notification" {
            $Message = "❌ $Message"
            Show-Toast -Message $Message -Title "Błąd" -NotificationType "Error"
            Append-LogToFile -Message $Message -Type "Error"
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

# Funkcja do wczytywania konfiguracji z pliku config.json
function Load-Configuration {
    [CmdletBinding()]
    param (
        [string]$Path = $Global:ConfigPath
    )

    if (-not (Test-Path $Path)) {
        Write-Log -Message "Plik konfiguracyjny nie istnieje: $Path" -Type "Warn"

        $response = Show-Dialog -Message "Plik konfiguracyjny nie istnieje:`n$Path`nCzy chcesz go utworzyć?" `
                                -Buttons "YesNo" -Type "Question" -Title "Brak pliku konfiguracyjnego"

        if ($response -ne 'Yes') {
            Write-Log -Message "Użytkownik anulował ładowanie konfiguracji." -Type "Info"
            return
        }
        else {
            Write-Log -Message "Tworzenie nowego pliku konfiguracyjnego: $Path" -Type "Info"
            Create-ConfigFile -Path $Path

            # Po utworzeniu pliku, spróbuj ponownie go wczytać
            if (-not (Test-Path $Path)) {
                Write-Log -Message "Nie udało się utworzyć pliku konfiguracyjnego: $Path" -Type 'Error&Notification'
                return
            }
        }

        return
    }

    try {
        $configContent = Get-Content -Raw -Path $Path | ConvertFrom-Json

        $Global:PasswordEmailAdress       = $configContent.PasswordEmailAdress
        $Global:PasswordEmailTitle        = $configContent.PasswordEmailTitle
        $Global:PasswordSpecialCharacters = $configContent.PasswordSpecialCharacters
        $Global:PasswordUseWordBased      = $configContent.PasswordUseWordBased

        Write-Log -Message "Wczytano konfigurację z pliku: $Path" -Type "Info"
        Show-Toast -Message "Konfiguracja została wczytana pomyślnie." -NotificationType "Info"
    }
    catch {
        Write-Log -Message "Błąd przy ładowaniu config.json: $($_.Exception.Message)" -Type "Error&Notification"
    }
}

# Funkcja do tworzenia pliku konfiguracyjnego
function Create-ConfigFile {
    [CmdletBinding()]
    param (
        [string]$Path = $Global:ConfigPath
    )

    $defaultConfig = @{
        PasswordEmailAdress         = ""
        PasswordEmailTitle          = "Nowe hasło"
        PasswordSpecialCharacters   = "!@#$%^&*?"
        PasswordUseWordBased        = $false
    }
    
    try {
        $jsonContent = $defaultConfig | ConvertTo-Json -Depth 5
        if (-not (Test-Path (Split-Path $Path))) {
            New-Item -ItemType Directory -Path (Split-Path $Path) | Out-Null
        }
        Set-Content -Path $Path -Value $jsonContent -Encoding UTF8
        Write-Log -Message "Utworzono plik konfiguracyjny: $Path" -Type "Info"
    }
    catch {
        Write-Log -Message "Błąd przy tworzeniu pliku konfiguracyjnego: $($_.Exception.Message)" -Type "Error&Notification"
    }
}

# Funkcja do podejmowania decyzji tak/nie/cancel oraz do wyświetlania komunikatów
function Show-Dialog {
    param (
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("OK", "OKCancel", "YesNo", "YesNoCancel")]
        [string]$Buttons = "OK",

        [ValidateSet("Info", "Error", "Warning", "Question")]
        [string]$Type = "Info",

        [string]$Title = "Komunikat"
    )

    $buttonEnum = [System.Windows.Forms.MessageBoxButtons]::$Buttons
    $iconEnum = switch ($Type) {
        "Info"     { [System.Windows.Forms.MessageBoxIcon]::Information }
        "Error"    { [System.Windows.Forms.MessageBoxIcon]::Error }
        "Warning"  { [System.Windows.Forms.MessageBoxIcon]::Warning }
        "Question" { [System.Windows.Forms.MessageBoxIcon]::Question }
    }

    return [System.Windows.Forms.MessageBox]::Show($Message, $Title, $buttonEnum, $iconEnum)
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
        Write-Log -Message "Zapisano dane do pliku: $Path" -Type "Info"
    }
    catch {
        Write-Log -Message "Błąd zapisu: $($_.Exception.Message)" -Type "Error&Notification"
    }
}

# Funckja dopisywania logów do pliku
function Append-LogToFile {
    param (
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("Info", "Warn", "Error")]
        [string]$Type = "Info",

        [string]$Path = "$Global:ConfigDir\logs.txt"
    )

    if (-not (Test-Path $Path)) {
        try {
            New-Item -ItemType File -Path $Path | Out-Null
            Write-Log -Message "Utworzono nowy plik logów: $Path" -Type "Info"
        }
        catch {
            Write-Log -Message "Błąd przy tworzeniu pliku logów: $($_.Exception.Message)" -Type "Error&Notification"
            return
        }
    }
    $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Type] $Message`r`n"
    Add-Content -Path $Path -Value $logEntry
}

# Funkcja do wyświetlania okna wejściowego z polem tekstowym
function Show-InputBox {
    param (
        [Parameter(Mandatory)]
        [string]$Prompt,

        [string]$Title = "Input",

        [ValidateSet("Text", "Email", "Phone", "Url")]
        [string]$ValidationType = "Text"
    )

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object Windows.Forms.Form
    $form.Text = $Title
    $form.Size = '500,180'
    $form.StartPosition = 'CenterParent'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MinimizeBox = $false
    $form.MaximizeBox = $false
    $form.TopMost = $true

    $label = New-Object Windows.Forms.Label
    $label.Text = $Prompt
    $label.Location = '10,10'
    $label.AutoSize = $true

    $textbox = New-Object Windows.Forms.TextBox
    $textbox.Location = '10,40'
    $textbox.Width = 360

    $errorLabel = New-Object Windows.Forms.Label
    $errorLabel.ForeColor = 'Red'
    $errorLabel.Location = '10,65'
    $errorLabel.Size = '360,20'
    $errorLabel.Text = ''

    $ok = New-Object Windows.Forms.Button
    $ok.Text = 'OK'
    $ok.Location = '180,95'
    $ok.Size = '90,30'
    $ok.Enabled = $true

    $cancel = New-Object Windows.Forms.Button
    $cancel.Text = 'Anuluj'
    $cancel.Location = '280,95'
    $cancel.Size = '90,30'
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $cancel

    # Funkcja walidująca
    $validate = {
        $value = $textbox.Text
        $isValid = $true
        $ValidationError = ""

        switch ($ValidationType) {
            "Email" {
                if ($value -notmatch '^[\w\.-]+@[\w\.-]+\.\w+$') {
                    $isValid = $false
                    $ValidationError = "Nieprawidłowy adres e-mail."
                }
            }
            "Phone" {
                if ($value -notmatch '^\+?[0-9\s\-]{9,}$') {
                    $isValid = $false
                    $ValidationError = "Nieprawidłowy numer telefonu."
                }
            }
            "Url" {
                if ($value -notmatch '^https?://[\w\-\.]+\.\w{2,}.*$') {
                    $isValid = $false
                    $ValidationError = "Nieprawidłowy adres URL."
                }
            }
        }

        $ok.Enabled = $isValid
        $errorLabel.Text = $ValidationError
    }

    $textbox.add_TextChanged($validate)
    $ok.Add_Click({
        $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $form.Close()
    })

    $form.Controls.AddRange(@($label, $textbox, $errorLabel, $ok, $cancel))

    if ($form.ShowDialog() -eq 'OK') {
        return $textbox.Text
    }

    return $null
}

