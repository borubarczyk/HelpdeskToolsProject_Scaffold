# Funkcja do logowania i zarządzania historią logów w aplikacji Helpdesk Tools
function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("Info", "Warn", "Error","Info&Notification", "Error&Notification", "Warning&Notification")]
        [string]$Type = "Info"
    )

    if (-not $global:LogHistory) {
        $global:LogHistory = New-Object System.Collections.Generic.List[object]
    }

    switch ($Type) {
        "Info" {
            $Message = "ℹ️ $Message"
            Add-LogToFile -Message $Message -Type "Info"
        }
        "Info&Notification" {
            $Message = "ℹ️ $Message"
            Show-Toast -Message $Message -Title "Informacja" -NotificationType "Info"
            Add-LogToFile -Message $Message -Type "Info"
        }
        "Warn" {
            $Message = "⚠️ $Message"
            Add-LogToFile -Message $Message -Type "Warn"
        }
        "Warning&Notification" {
            $Message = "⚠️ $Message"
            Show-Toast -Message $Message -Title "Ostrzeżenie" -NotificationType "Warning"
            Add-LogToFile -Message $Message -Type "Warn"
        }
        "Error" {
            $Message = "❌ $Message"
            Add-LogToFile -Message $Message -Type "Error"
        }
        "Error&Notification" {
            $Message = "❌ $Message"
            Show-Toast -Message $Message -Title "Błąd" -NotificationType "Error"
            Add-LogToFile -Message $Message -Type "Error"
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
        "Info" { [System.Windows.Forms.MessageBoxIcon]::Information }
        "Error" { [System.Windows.Forms.MessageBoxIcon]::Error }
        "Warning" { [System.Windows.Forms.MessageBoxIcon]::Warning }
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

        [string]$Path, # <-- opcjonalna ścieżka

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
            "txt" { "Pliki tekstowe (*.txt)|*.txt" }
            "csv" { "Pliki CSV (*.csv)|*.csv" }
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
            "txt" { $Data | Out-File -FilePath $Path -Encoding UTF8 }
            "csv" { $Data | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8 }
            "json" { $Data | ConvertTo-Json -Depth 5 | Out-File -FilePath $Path -Encoding UTF8 }
        }
        Write-Log -Message "Zapisano dane do pliku: $Path" -Type "Info"
    }
    catch {
        Write-Log -Message "Błąd zapisu: $($_.Exception.Message)" -Type "Error&Notification"
    }
}

# Funkcja dopisywania logów do pliku
function Add-LogToFile {
    param (
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("Info", "Warn", "Error")]
        [string]$Type = "Info",

        [string]$Path = "$Global:ConfigDir\logs.txt"
    )

    if (-not (Test-Path $Path)) {
        try {
            New-Item -ItemType Directory -Path "$Global:ConfigDir" -ErrorAction SilentlyContinue | Out-Null
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
    $textbox.Width = 460

    $errorLabel = New-Object Windows.Forms.Label
    $errorLabel.ForeColor = 'Red'
    $errorLabel.Location = '10,65'
    $errorLabel.Size = '460,20'
    $errorLabel.Text = ''

    $ok = New-Object Windows.Forms.Button
    $ok.Text = 'OK'
    $ok.Location = '280,95'
    $ok.Size = '90,30'
    $ok.Enabled = $true

    $cancel = New-Object Windows.Forms.Button
    $cancel.Text = 'Anuluj'
    $cancel.Location = '380,95'
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

    $textbox.add_KeyDown({
            if ($_.KeyCode -eq 'Enter') {
                $validate.Invoke()
                if ($ok.Enabled) {
                    $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
                    $form.Close()
                }
            }
        })

    $form.Controls.AddRange(@($label, $textbox, $errorLabel, $ok, $cancel))

    if ($form.ShowDialog() -eq 'OK') {
        return $textbox.Text
    }

    return $null
}

# Funkcja do ustawiania stanu przycisków w GUI
function Set-ButtonsState {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Lock", "Unlock")]
        [string]$Action,

        [Parameter(Mandatory = $false)]
        [string]$PanelName = $HT_UI.TabControl.SelectedTab.Text,

        [Parameter(Mandatory = $false)]
        [bool]$LockMainButtons = $true
    )

    if ($LockMainButtons -eq $true) {
        if ($HT_UI.Buttons) {
            foreach ($btn in $HT_UI.Buttons.Values) {
                if ($btn -is [System.Windows.Forms.Button]) {
                    $btn.Enabled = ($Action -eq "Unlock")
                }
            }
        }
    }

    if (-not $HT_UI.Tabs.Contains($PanelName)) {
        Write-Log "Panel '$PanelName' nie istnieje w HT_UI.Tabs." "Error"
        return
    }

    $panel = $HT_UI.Tabs[$PanelName]

    if (-not $panel.Controls) {
        Write-Log "Panel '$PanelName' nie zawiera kontrolek." "Error"
        return
    }

    function Set-StateRecursive {
        param (
            [System.Windows.Forms.Control]$Parent
        )

        foreach ($ctrl in $Parent.Controls) {
            if ($ctrl -is [System.Windows.Forms.Button]) {
                $ctrl.Enabled = ($Action -eq "Unlock")
            }
            if ($ctrl.HasChildren) {
                Set-StateRecursive -Parent $ctrl
            }
        }
    }

    Set-StateRecursive -Parent $panel
}

# Funkcja do walidacji i podświetlania składni JSON w RichTextBox
function Test-AndHighlightJson {
    param (
        [Parameter(Mandatory)] [System.Windows.Forms.RichTextBox]$RichTextBox,
        [Parameter(Mandatory=$false)] [System.Windows.Forms.ToolTip]$ErrorToolTip,
        [Parameter(Mandatory=$false)] [switch]$ShowDialogOnError
    )

    $RichTextBox.SuspendLayout()

    # Pamiętaj pozycję kursora
    $originalSelectionStart = $RichTextBox.SelectionStart
    $originalSelectionLength = $RichTextBox.SelectionLength

    try {
        # Reset stylów
        $RichTextBox.SelectAll()
        $RichTextBox.SelectionBackColor = [System.Drawing.Color]::White
        $RichTextBox.SelectionColor = [System.Drawing.Color]::Black
        $RichTextBox.SelectionFont = New-Object System.Drawing.Font(
            $RichTextBox.Font.FontFamily,
            $RichTextBox.Font.Size,
            [System.Drawing.FontStyle]::Regular
        )

        # === 1) Prosty pre-check ===
        $text = $RichTextBox.Text

        $braceCount = ($text -split '[{}]').Length - 1
        $bracketCount = ($text -split '[\[\]]').Length - 1
        $quoteCount = ($text -split '"').Length - 1

        $preCheckOk = $true
        $errorMsg = ""

        if ($braceCount % 2 -ne 0) {
            $preCheckOk = $false
            $errorMsg = "Niezamknięta klamra { }"
        } elseif ($bracketCount % 2 -ne 0) {
            $preCheckOk = $false
            $errorMsg = "Niezamknięty nawias [ ]"
        } elseif ($quoteCount % 2 -ne 0) {
            $preCheckOk = $false
            $errorMsg = "Nieparzysta liczba cudzysłowów"
        }

        if (-not $preCheckOk) {
            # Podświetl wszystko na LightYellow
            $RichTextBox.SelectAll()
            $RichTextBox.SelectionBackColor = [System.Drawing.Color]::LightYellow

            if ($ShowDialogOnError) {
                Show-Dialog -Message $errorMsg -Type "Error" -Title "Pre-check JSON"
            }
            if ($ErrorToolTip) {
                $ErrorToolTip.SetToolTip($RichTextBox, $errorMsg)
            }
            Write-Log -Message "Pre-check błąd: $errorMsg" -Type "Warning"
            return $false
        }

        # === 2) Głębsze sprawdzenie ConvertFrom-Json ===
        $parsed = $text | ConvertFrom-Json

        # Syntax highlighting
        $patterns = @{
            Key         = '"([^"]*)"\s*:'
            StringValue = ':\s*"([^"]*)"'
            Number      = ':\s*([-]?\d+(\.\d+)?)'
            Boolean     = ':\s*(true|false)\b'
            Null        = ':\s*(null)\b'
            Brackets    = '[{}[\]]'
            Comma       = ','
        }
        $colors = @{
            Key         = [System.Drawing.Color]::DarkBlue
            StringValue = [System.Drawing.Color]::DarkGreen
            Number      = [System.Drawing.Color]::DarkRed
            Boolean     = [System.Drawing.Color]::Purple
            Null        = [System.Drawing.Color]::Gray
            Brackets    = [System.Drawing.Color]::Navy
            Comma       = [System.Drawing.Color]::DarkGray
        }

        $lines = $RichTextBox.Lines
        $currentIndex = 0

        for ($lineNumber = 0; $lineNumber -lt $lines.Length; $lineNumber++) {
            $line = $lines[$lineNumber]
            $startIndex = $currentIndex

            foreach ($type in $patterns.Keys) {
                [regex]::Matches($line, $patterns[$type]) | ForEach-Object {
                    $offset = $startIndex + $_.Index
                    $length = $_.Length

                    if ($type -in @('Key', 'StringValue')) {
                        $offset += $_.Groups[1].Index - $_.Index
                        $length = $_.Groups[1].Length
                    }

                    if ($length -gt 0) {
                        $RichTextBox.Select($offset, $length)
                        $RichTextBox.SelectionColor = $colors[$type]
                        if ($type -eq 'Key') {
                            $RichTextBox.SelectionFont = New-Object System.Drawing.Font(
                                $RichTextBox.Font.FontFamily,
                                $RichTextBox.Font.Size,
                                [System.Drawing.FontStyle]::Bold
                            )
                        } else {
                            $RichTextBox.SelectionFont = New-Object System.Drawing.Font(
                                $RichTextBox.Font.FontFamily,
                                $RichTextBox.Font.Size,
                                [System.Drawing.FontStyle]::Regular
                            )
                        }
                    }
                }
            }

            $currentIndex += $line.Length + 1
        }

        return $true
        }
    catch {
        $errorMsg = $_.Exception.Message

        $lineNumber = -1
        $position = -1

        if ($errorMsg -match "line (\d+), position (\d+)") {
            $lineNumber = [int]$matches[1] - 1
            $position = [int]$matches[2] - 1

            # Sprytne przesunięcie TYLKO gdy błąd parsera to brak separatora lub koniec
            if ($errorMsg -match "Expected" -or $errorMsg -match "Unexpected end") {
                if ($lineNumber -gt 0) { $lineNumber-- }
            }
        }

        if ($lineNumber -ge 0 -and $lineNumber -lt $RichTextBox.Lines.Length) {
            $startIndex = $RichTextBox.GetFirstCharIndexFromLine($lineNumber)
            $lineText = $RichTextBox.Lines[$lineNumber]
            $length = $lineText.Length
            $RichTextBox.Select($startIndex, $length)
            $RichTextBox.SelectionBackColor = [System.Drawing.Color]::LightPink
        } else {
            $RichTextBox.SelectAll()
            $RichTextBox.SelectionBackColor = [System.Drawing.Color]::LightPink
        }

        if ($ShowDialogOnError) {
            Show-Dialog -Message $errorMsg -Type "Error" -Title "Błąd JSON"
        }
        if ($ErrorToolTip) {
            $ErrorToolTip.SetToolTip($RichTextBox, $errorMsg)
        }

        Write-Log -Message "Parser JSON: $errorMsg" -Type "Error"
        return $false
    }
    finally {
        # Przywróć pozycję kursora!
        $RichTextBox.SelectionStart = $originalSelectionStart
        $RichTextBox.SelectionLength = $originalSelectionLength
        $RichTextBox.ResumeLayout()
    }
}

# Funkcja do usuwania wewnętrznych białych znaków z ciągu znaków
function Remove-InnerWhitespace {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$InputString,
        [switch]$TrimEnds # Dodatkowo: czy przyciąć początek/koniec
    )

    $result = $InputString -replace '\s',''
    if ($TrimEnds) {
        $result = $result.Trim()
    }
    return $result
}

# Generator haseł - Funkcja do generowania
function Set-GeneratedPassword {
    $pgw = $HT_UI.PasswordGeneratorWindow

    $length = $pgw.Length.Value
    $symbols = $pgw.SpecialCharacters.Text
    $useNumbers = $pgw.Checkboxes.UseNumbers.Checked
    $useSymbols = $pgw.Checkboxes.UseSymbols.Checked

    if ($pgw.Checkboxes.Words.Checked) {
        $pgw.Password.Text = New-WordBasedPassword `
            -Length $length `
            -UseNumbers $useNumbers `
            -UseSymbols $useSymbols `
            -SpecialCharacters $symbols
    }
    else {
        $pgw.Password.Text = New-Password `
            -Length $length `
            -SpecialCharacters $symbols `
            -StartWithLetter $pgw.Checkboxes.StartLetter.Checked `
            -IncludeNumbers $useNumbers `
            -IncludeSymbols $useSymbols `
            -NoSimilarChars $pgw.Checkboxes.NoSimilar.Checked `
            -FriendlyMode $pgw.Checkboxes.Friendly.Checked
    }

    if ($Global:LogPasswordGeneration) {
        Write-Log -Message "Wygenerowano hasło: $($pgw.Password.Text)" -Type "Info"
    }
}