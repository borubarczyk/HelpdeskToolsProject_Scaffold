# Funkcje pomocnicze aplikacji Helpdesk Tools: logowanie, powiadomienia, dialogi, eksport, walidacja JSON

# Historia logów przechowywana w module (dostęp przez Get-HTLogHistory / Clear-HTLogHistory)
$script:LogHistory = [System.Collections.Generic.List[object]]::new()
# Lista funkcji (scriptblocków) wywoływanych po każdym wpisie logu (np. odświeżenie zakładki "Logi")
$script:LogSinks = [System.Collections.Generic.List[scriptblock]]::new()
# Ikona w zasobniku używana do powiadomień (tworzona leniwie)
$script:NotifyIcon = $null
# Blokada ponownego wejścia w podświetlanie JSON
$script:IsHighlightingJson = $false

# Funkcja do logowania i zarządzania historią logów w aplikacji Helpdesk Tools
function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [AllowEmptyString()]
        [string]$Message,

        [Parameter(Position = 1)]
        [ValidateSet("Info", "Warn", "Warning", "Error", "Info&Notification", "Warn&Notification", "Warning&Notification", "Error&Notification")]
        [string]$Type = "Info"
    )

    $level = switch -Wildcard ($Type) {
        "Info*" { "Info" }
        "Warn*" { "Warn" }
        "Error*" { "Error" }
    }
    $icon = switch ($level) {
        "Info" { "ℹ️" }
        "Warn" { "⚠️" }
        "Error" { "❌" }
    }

    $entry = [PSCustomObject]@{
        Time    = Get-Date
        Type    = $level
        Message = "$icon $Message"
    }

    $script:LogHistory.Add($entry)
    Add-LogToFile -Message $entry.Message -Type $level

    if ($Type -like "*&Notification") {
        $title = switch ($level) {
            "Info" { "Informacja" }
            "Warn" { "Ostrzeżenie" }
            "Error" { "Błąd" }
        }
        $notificationType = switch ($level) {
            "Info" { "Info" }
            "Warn" { "Warning" }
            "Error" { "Error" }
        }
        Show-Toast -Message $Message -Title $title -NotificationType $notificationType
    }

    foreach ($sink in @($script:LogSinks)) {
        try { & $sink $entry | Out-Null } catch { Write-Verbose "Błąd odbiorcy logów: $_" }
    }
}

# Rejestracja funkcji wywoływanej po każdym wpisie logu (np. aktualizacja GUI)
function Register-HTLogSink {
    param ([Parameter(Mandatory)][scriptblock]$ScriptBlock)
    $script:LogSinks.Add($ScriptBlock)
}

# Zwraca kopię historii logów
function Get-HTLogHistory {
    return @($script:LogHistory)
}

# Czyści historię logów w pamięci (plik logu pozostaje bez zmian)
function Clear-HTLogHistory {
    $script:LogHistory.Clear()
}

# Formatowanie pojedynczego wpisu logu
function Format-HTLogEntry {
    param ([Parameter(Mandatory)][object]$Entry)
    $time = if ($Entry.Time -is [datetime]) { $Entry.Time.ToString("yyyy-MM-dd HH:mm:ss") } else { "$($Entry.Time)" }
    return "$time [$($Entry.Type)] $($Entry.Message)"
}

# Sprawdza, czy wpis logu pasuje do filtra tekstowego i typu
function Test-HTLogEntryMatch {
    param (
        [Parameter(Mandatory)][object]$Entry,
        [string]$FilterText,
        [string]$FilterType = "Wszystkie"
    )
    if ($FilterType -and $FilterType -ne "Wszystkie" -and $Entry.Type -ne $FilterType) { return $false }
    if ($FilterText -and $Entry.Message.IndexOf($FilterText, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { return $false }
    return $true
}

# Funkcja do wyświetlania powiadomień w systemie
function Show-Toast {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$Title = "Helpdesk Tools",
        [int]$Timeout = 3000,
        [ValidateSet("Info", "Warning", "Error")]
        [string]$NotificationType = "Info"
    )

    if ($Global:ShowNotifications -eq $false) { return }

    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop

        if (-not $script:NotifyIcon) {
            $script:NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
            $script:NotifyIcon.Text = "Helpdesk Tools"
            if ($Global:AppIconPath -and (Test-Path $Global:AppIconPath)) {
                $script:NotifyIcon.Icon = New-Object System.Drawing.Icon($Global:AppIconPath)
            }
            else {
                $script:NotifyIcon.Icon = [System.Drawing.SystemIcons]::Information
            }
        }

        $tipIcon = switch ($NotificationType) {
            "Info" { [System.Windows.Forms.ToolTipIcon]::Info }
            "Warning" { [System.Windows.Forms.ToolTipIcon]::Warning }
            "Error" { [System.Windows.Forms.ToolTipIcon]::Error }
        }

        # Balloon ma limit długości tekstu
        if ($Message.Length -gt 250) { $Message = $Message.Substring(0, 247) + "..." }

        $script:NotifyIcon.Visible = $true
        $script:NotifyIcon.ShowBalloonTip($Timeout, $Title, $Message, $tipIcon)
    }
    catch {
        Write-Verbose "Błąd podczas wyświetlania powiadomienia: $_"
    }
}

# Zwalnia ikonę powiadomień (wywoływane przy zamykaniu aplikacji)
function Remove-HTNotifyIcon {
    if ($script:NotifyIcon) {
        $script:NotifyIcon.Visible = $false
        $script:NotifyIcon.Dispose()
        $script:NotifyIcon = $null
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

    $owner = if ($Global:HT_UI -and $Global:HT_UI.Form -and $Global:HT_UI.Form.Visible) { $Global:HT_UI.Form } else { $null }
    if ($owner) {
        return [System.Windows.Forms.MessageBox]::Show($owner, $Message, $Title, $buttonEnum, $iconEnum)
    }
    return [System.Windows.Forms.MessageBox]::Show($Message, $Title, $buttonEnum, $iconEnum)
}

# Pytanie Tak/Nie zwracające wartość logiczną
function Show-HTConfirm {
    param (
        [Parameter(Mandatory)][string]$Message,
        [string]$Title = "Potwierdzenie",
        [switch]$Warning
    )
    $type = if ($Warning) { "Warning" } else { "Question" }
    return ((Show-Dialog -Message $Message -Title $Title -Buttons "YesNo" -Type $type) -eq [System.Windows.Forms.DialogResult]::Yes)
}

# Domyślny katalog eksportu
function Get-HTExportDirectory {
    $path = if ($Global:ExportPath) { $Global:ExportPath }
    elseif ($Global:ConfigDir) { Join-Path $Global:ConfigDir "Exports" }
    else { [Environment]::GetFolderPath("MyDocuments") }

    if (-not (Test-Path $path)) {
        try { New-Item -ItemType Directory -Path $path -Force | Out-Null } catch { $path = [Environment]::GetFolderPath("MyDocuments") }
    }
    return $path
}

# Funkcja do zapisywania danych do pliku
function Save-ContentToFile {
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Data,

        [Parameter(Mandatory)]
        [ValidateSet("txt", "csv", "json")]
        [string]$Format,

        [string]$Path,

        [string]$Title = "Zapisz plik",
        [string]$DefaultName = "output",
        [string]$DefaultPath
    )

    if (-not $Data -or $Data.Count -eq 0) {
        Write-Log -Message "Brak danych do zapisania!" -Type "Warn"
        return $null
    }

    if (-not $Path) {
        if (-not $DefaultPath) { $DefaultPath = Get-HTExportDirectory }

        $dialog = New-Object System.Windows.Forms.SaveFileDialog
        $dialog.Title = $Title
        $dialog.Filter = switch ($Format) {
            "txt" { "Pliki tekstowe (*.txt)|*.txt" }
            "csv" { "Pliki CSV (*.csv)|*.csv" }
            "json" { "Pliki JSON (*.json)|*.json" }
        }
        $dialog.InitialDirectory = $DefaultPath
        $dialog.FileName = "$($DefaultName)_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').$Format"

        try {
            if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
                Write-Log -Message "Zapis anulowany przez użytkownika." -Type "Warn"
                return $null
            }
            $Path = $dialog.FileName
        }
        finally {
            $dialog.Dispose()
        }
    }

    try {
        switch ($Format) {
            "txt" { $Data | Out-File -FilePath $Path -Encoding utf8 }
            "csv" { $Data | Export-Csv -Path $Path -NoTypeInformation -Encoding utf8BOM -Delimiter ";" }
            "json" { ConvertTo-Json -InputObject @($Data) -Depth 6 | Out-File -FilePath $Path -Encoding utf8 }
        }
        Write-Log -Message "Zapisano dane do pliku: $Path" -Type "Info&Notification"
        return $Path
    }
    catch {
        Write-Log -Message "Błąd zapisu: $($_.Exception.Message)" -Type "Error&Notification"
        return $null
    }
}

# Funkcja dopisywania logów do pliku (z prostą rotacją)
function Add-LogToFile {
    param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Message,

        [ValidateSet("Info", "Warn", "Error")]
        [string]$Type = "Info",

        [string]$Path
    )

    if (-not $Path) {
        if (-not $Global:ConfigDir) { return }
        $Path = Join-Path $Global:ConfigDir "logs.txt"
    }

    try {
        $dir = Split-Path -Path $Path -Parent
        if ($dir -and -not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        $maxSizeMB = if ($Global:LogFileMaxSizeMB -gt 0) { [double]$Global:LogFileMaxSizeMB } else { 5 }
        if ((Test-Path $Path) -and ((Get-Item $Path).Length -gt ($maxSizeMB * 1MB))) {
            $archive = Join-Path $dir ("logs_{0}.txt" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
            Move-Item -Path $Path -Destination $archive -Force
        }

        $logEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Type] $Message"
        Add-Content -Path $Path -Value $logEntry -Encoding utf8
    }
    catch {
        Write-Verbose "Nie udało się zapisać logu do pliku: $($_.Exception.Message)"
    }
}

# Walidacja wartości wprowadzanej w polach tekstowych
function Test-HTInputValue {
    param (
        [AllowEmptyString()][string]$Value,
        [ValidateSet("Text", "Email", "Phone", "Url", "Upn", "Guid")]
        [string]$ValidationType = "Text"
    )

    switch ($ValidationType) {
        "Email" { return $Value -match '^[\w\.\+\-'']+@[\w\.-]+\.\w{2,}$' }
        "Upn" { return $Value -match '^[\w\.\+\-'']+@[\w\.-]+\.\w{2,}$' }
        "Phone" { return $Value -match '^\+?[0-9\s\-\(\)]{9,}$' }
        "Url" { return $Value -match '^https?://[\w\-\.]+\.\w{2,}(/.*)?$' }
        "Guid" { return $Value -match '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$' }
        default { return -not [string]::IsNullOrWhiteSpace($Value) }
    }
}

# Funkcja do wyświetlania okna wejściowego z polem tekstowym
function Show-InputBox {
    param (
        [Parameter(Mandatory)]
        [string]$Prompt,

        [string]$Title = "Wprowadź wartość",

        [ValidateSet("Text", "Email", "Phone", "Url", "Upn", "Guid")]
        [string]$ValidationType = "Text",

        [string]$DefaultText = "",

        # Pozwala zatwierdzić puste pole (np. pola opcjonalne)
        [switch]$AllowEmpty,

        # Ukrywa wpisywane znaki
        [switch]$Password
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.ClientSize = New-Object System.Drawing.Size(480, 150)
    $form.StartPosition = 'CenterParent'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MinimizeBox = $false
    $form.MaximizeBox = $false
    $form.ShowInTaskbar = $false
    $form.Font = New-Object System.Drawing.Font("Segoe UI", 9.75)
    if (-not ($Global:HT_UI -and $Global:HT_UI.Form -and $Global:HT_UI.Form.Visible)) {
        $form.StartPosition = 'CenterScreen'
        $form.TopMost = $true
    }

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Prompt
    $label.Location = New-Object System.Drawing.Point(12, 12)
    $label.Size = New-Object System.Drawing.Size(456, 38)

    $textbox = New-Object System.Windows.Forms.TextBox
    $textbox.Location = New-Object System.Drawing.Point(12, 52)
    $textbox.Width = 456
    $textbox.Text = $DefaultText
    $textbox.UseSystemPasswordChar = [bool]$Password

    $errorLabel = New-Object System.Windows.Forms.Label
    $errorLabel.ForeColor = [System.Drawing.Color]::Firebrick
    $errorLabel.Location = New-Object System.Drawing.Point(12, 80)
    $errorLabel.Size = New-Object System.Drawing.Size(456, 20)

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'OK'
    $ok.Location = New-Object System.Drawing.Point(282, 108)
    $ok.Size = New-Object System.Drawing.Size(90, 30)

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Anuluj'
    $cancel.Location = New-Object System.Drawing.Point(378, 108)
    $cancel.Size = New-Object System.Drawing.Size(90, 30)
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $cancel

    $messages = @{
        Text  = "Pole nie może być puste."
        Email = "Nieprawidłowy adres e-mail."
        Upn   = "Nieprawidłowa nazwa UPN (np. jan.kowalski@firma.pl)."
        Phone = "Nieprawidłowy numer telefonu."
        Url   = "Nieprawidłowy adres URL (https://...)."
        Guid  = "Nieprawidłowy identyfikator GUID."
    }

    $validate = {
        $value = $textbox.Text.Trim()
        $isValid = if ($AllowEmpty -and -not $value) { $true } else { Test-HTInputValue -Value $value -ValidationType $ValidationType }
        $ok.Enabled = $isValid
        $errorLabel.Text = if ($isValid -or -not $value) { "" } else { $messages[$ValidationType] }
    }

    $textbox.Add_TextChanged($validate)
    $ok.Add_Click({
            $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $form.Close()
        })
    $form.AcceptButton = $ok

    $form.Controls.AddRange(@($label, $textbox, $errorLabel, $ok, $cancel))
    & $validate

    try {
        if ($form.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            return $textbox.Text.Trim()
        }
        return $null
    }
    finally {
        $form.Dispose()
    }
}

# Funkcja do walidacji i podświetlania składni JSON w RichTextBox
function Test-AndHighlightJson {
    param (
        [Parameter(Mandatory)] [System.Windows.Forms.RichTextBox]$RichTextBox,
        [Parameter(Mandatory = $false)] [System.Windows.Forms.ToolTip]$ErrorToolTip,
        [Parameter(Mandatory = $false)] [switch]$ShowDialogOnError,
        # Nie zapisuje błędów parsowania do logu (np. podczas pisania)
        [Parameter(Mandatory = $false)] [switch]$Quiet
    )

    if ($script:IsHighlightingJson) { return $true }
    $script:IsHighlightingJson = $true

    $RichTextBox.SuspendLayout()
    $originalSelectionStart = $RichTextBox.SelectionStart
    $originalSelectionLength = $RichTextBox.SelectionLength

    $regularFont = New-Object System.Drawing.Font($RichTextBox.Font, [System.Drawing.FontStyle]::Regular)
    $boldFont = New-Object System.Drawing.Font($RichTextBox.Font, [System.Drawing.FontStyle]::Bold)

    try {
        # Reset stylów
        $RichTextBox.SelectAll()
        $RichTextBox.SelectionBackColor = $RichTextBox.BackColor
        $RichTextBox.SelectionColor = [System.Drawing.Color]::Black
        $RichTextBox.SelectionFont = $regularFont

        $text = $RichTextBox.Text
        if ([string]::IsNullOrWhiteSpace($text)) { throw "Pusta konfiguracja." }

        $null = $text | ConvertFrom-Json -ErrorAction Stop

        # Kolejność ma znaczenie - klucze nadpisują dopasowania wartości tekstowych
        $rules = @(
            @{ Pattern = '[{}\[\]]'; Group = 0; Color = [System.Drawing.Color]::Navy; Bold = $false }
            @{ Pattern = ':\s*(-?\d+(\.\d+)?)'; Group = 1; Color = [System.Drawing.Color]::DarkRed; Bold = $false }
            @{ Pattern = '\b(true|false)\b'; Group = 1; Color = [System.Drawing.Color]::Purple; Bold = $false }
            @{ Pattern = '\bnull\b'; Group = 0; Color = [System.Drawing.Color]::Gray; Bold = $false }
            @{ Pattern = '"(?:[^"\\]|\\.)*"'; Group = 0; Color = [System.Drawing.Color]::DarkGreen; Bold = $false }
            @{ Pattern = '("(?:[^"\\]|\\.)*")\s*:'; Group = 1; Color = [System.Drawing.Color]::DarkBlue; Bold = $true }
        )

        foreach ($rule in $rules) {
            foreach ($match in [regex]::Matches($text, $rule.Pattern)) {
                $group = $match.Groups[$rule.Group]
                if ($group.Length -le 0) { continue }
                $RichTextBox.Select($group.Index, $group.Length)
                $RichTextBox.SelectionColor = $rule.Color
                $RichTextBox.SelectionFont = if ($rule.Bold) { $boldFont } else { $regularFont }
            }
        }

        if ($ErrorToolTip) { $ErrorToolTip.SetToolTip($RichTextBox, "") }
        return $true
    }
    catch {
        $errorMsg = $_.Exception.Message
        $lineNumber = -1

        if ($errorMsg -match "line (\d+), position (\d+)") {
            $lineNumber = [int]$matches[1] - 1
        }

        if ($lineNumber -ge 0 -and $lineNumber -lt $RichTextBox.Lines.Length) {
            $startIndex = $RichTextBox.GetFirstCharIndexFromLine($lineNumber)
            $RichTextBox.Select($startIndex, [Math]::Max(1, $RichTextBox.Lines[$lineNumber].Length))
        }
        else {
            $RichTextBox.SelectAll()
        }
        $RichTextBox.SelectionBackColor = [System.Drawing.Color]::MistyRose

        if ($ShowDialogOnError) {
            Show-Dialog -Message $errorMsg -Type "Error" -Title "Błąd JSON" | Out-Null
        }
        if ($ErrorToolTip) {
            $ErrorToolTip.SetToolTip($RichTextBox, $errorMsg)
        }
        if (-not $Quiet) {
            Write-Log -Message "Parser JSON: $errorMsg" -Type "Error"
        }
        return $false
    }
    finally {
        $RichTextBox.SelectionStart = $originalSelectionStart
        $RichTextBox.SelectionLength = $originalSelectionLength
        $RichTextBox.SelectionColor = [System.Drawing.Color]::Black
        $RichTextBox.ResumeLayout()
        $script:IsHighlightingJson = $false
    }
}

# Czy trwa podświetlanie składni (zmiany formatowania mogą wywoływać TextChanged)
function Test-HTJsonHighlighting {
    return [bool]$script:IsHighlightingJson
}

# Funkcja do usuwania wewnętrznych białych znaków z ciągu znaków
function Remove-InnerWhitespace {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$InputString,
        [switch]$TrimEnds # Dodatkowo: czy przyciąć początek/koniec
    )

    $result = $InputString -replace '\s', ''
    if ($TrimEnds) {
        $result = $result.Trim()
    }
    return $result
}

# Konwersja wartości do postaci czytelnej w GUI
function ConvertTo-HTDisplayValue {
    param ([AllowNull()][object]$Value)

    if ($null -eq $Value) { return "" }
    if ($Value -is [bool]) { return $(if ($Value) { "Tak" } else { "Nie" }) }
    if ($Value -is [datetime]) { return $Value.ToString("yyyy-MM-dd HH:mm") }
    if ($Value -is [datetimeoffset]) { return $Value.LocalDateTime.ToString("yyyy-MM-dd HH:mm") }
    if ($Value -is [string]) {
        # Daty ISO 8601 zwracane przez Graph jako tekst
        if ($Value -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}') {
            $parsed = [datetimeoffset]::MinValue
            if ([datetimeoffset]::TryParse($Value, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) {
                return $parsed.LocalDateTime.ToString("yyyy-MM-dd HH:mm")
            }
        }
        return $Value
    }
    if ($Value -is [System.Collections.IDictionary]) {
        return (@($Value.Keys | ForEach-Object { "$_=$($Value[$_])" }) -join "; ")
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        return (@($Value | ForEach-Object { ConvertTo-HTDisplayValue $_ }) -join ", ")
    }
    return "$Value"
}

# Rozbija tekst (np. wklejoną listę) na unikalne, niepuste wpisy
function Split-HTInputList {
    param ([AllowEmptyString()][AllowNull()][string]$Text)
    if (-not $Text) { return @() }
    return @($Text -split '[\r\n,;\t]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique)
}

# Formatuje rozmiar w bajtach
function Format-HTBytes {
    param ([AllowNull()][object]$Bytes)
    if ($null -eq $Bytes -or "$Bytes" -eq "") { return "" }
    $value = [double]$Bytes
    $units = @("B", "KB", "MB", "GB", "TB")
    $i = 0
    while ($value -ge 1024 -and $i -lt $units.Count - 1) { $value /= 1024; $i++ }
    return ("{0:N1} {1}" -f $value, $units[$i])
}

# Usuwa polskie i inne znaki diakrytyczne (np. do tworzenia loginów)
function ConvertTo-HTAsciiName {
    param ([AllowEmptyString()][AllowNull()][string]$Text)
    if (-not $Text) { return "" }
    $text = $Text.Replace("ł", "l").Replace("Ł", "L")
    $normalized = $text.Normalize([System.Text.NormalizationForm]::FormD)
    $builder = New-Object System.Text.StringBuilder
    foreach ($char in $normalized.ToCharArray()) {
        if ([System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($char) -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$builder.Append($char)
        }
    }
    return $builder.ToString().Normalize([System.Text.NormalizationForm]::FormC)
}
