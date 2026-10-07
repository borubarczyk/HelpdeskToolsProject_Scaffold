# Funkcje pomocnicze aplikacji Helpdesk Tools: dziennik, eksport do plików, walidacja i formatowanie wartości.
# Moduł nie zależy od interfejsu - powiadomienia (toasty) wyświetla odbiorca logów zarejestrowany przez GUI.

# Historia logów przechowywana w module (dostęp przez Get-HTLogHistory / Clear-HTLogHistory)
$script:LogHistory = [System.Collections.Generic.List[object]]::new()
# Lista funkcji (scriptblocków) wywoływanych po każdym wpisie logu (np. odświeżenie zakładki "Logi")
$script:LogSinks = [System.Collections.Generic.List[scriptblock]]::new()

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

    # Notify: wpis ma być pokazany jako powiadomienie w oknie (o ile powiadomienia są włączone)
    $entry = [PSCustomObject]@{
        Time    = Get-Date
        Type    = $level
        Message = "$icon $Message"
        Notify  = ($Type -like "*&Notification" -and $Global:ShowNotifications -ne $false)
    }

    $script:LogHistory.Add($entry)
    Add-LogToFile -Message $entry.Message -Type $level

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

# Domyślny katalog eksportu: ustawienie ExportPath albo Dokumenty\HelpdeskTools\Eksport
function Get-HTExportDirectory {
    $documents = [Environment]::GetFolderPath("MyDocuments")
    $path = if ($Global:ExportPath) { $Global:ExportPath }
    elseif ($documents) { Join-Path $documents "HelpdeskTools\Eksport" }
    elseif ($Global:ConfigDir) { Join-Path $Global:ConfigDir "Exports" }
    else { [System.IO.Path]::GetTempPath() }

    if (-not (Test-Path $path)) {
        try { New-Item -ItemType Directory -Path $path -Force | Out-Null } catch { $path = $documents }
    }
    return $path
}

# Katalog dziennika: %LOCALAPPDATA%\HelpdeskTools\Logs (jak w Domain Ops); bez zmiennej LogDir - katalog konfiguracji
function Get-HTLogDirectory {
    if ($Global:LogDir) { return $Global:LogDir }
    return $Global:ConfigDir
}

# Bieżący plik dziennika: jeden plik na dzień (HelpdeskTools_RRRRMMDD.log)
function Get-HTLogFile {
    $dir = Get-HTLogDirectory
    if (-not $dir) { return $null }
    return (Join-Path $dir ("HelpdeskTools_{0:yyyyMMdd}.log" -f (Get-Date)))
}

# Usuwa pliki dziennika starsze niż wskazana liczba dni
function Remove-HTOldLogs {
    param ([int]$Days = 30)
    $dir = Get-HTLogDirectory
    if (-not $dir -or -not (Test-Path $dir)) { return }
    $cutoff = (Get-Date).AddDays(-$Days)
    Get-ChildItem -Path $dir -Filter "HelpdeskTools_*.log" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoff } |
        Remove-Item -Force -ErrorAction SilentlyContinue
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

        $dialog = New-Object Microsoft.Win32.SaveFileDialog
        $dialog.Title = $Title
        $dialog.Filter = switch ($Format) {
            "txt" { "Pliki tekstowe (*.txt)|*.txt" }
            "csv" { "Pliki CSV (*.csv)|*.csv" }
            "json" { "Pliki JSON (*.json)|*.json" }
        }
        $dialog.InitialDirectory = $DefaultPath
        $dialog.FileName = "$($DefaultName)_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').$Format"
        $owner = if ($Global:HT_UI -and $Global:HT_UI.Window -and $Global:HT_UI.Window.IsVisible) { $Global:HT_UI.Window } else { $null }
        $accepted = if ($owner) { $dialog.ShowDialog($owner) } else { $dialog.ShowDialog() }
        if ($accepted -ne $true) {
            Write-Log -Message "Zapis anulowany przez użytkownika." -Type "Warn"
            return $null
        }
        $Path = $dialog.FileName
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
        $Path = Get-HTLogFile
        if (-not $Path) { return }
    }

    try {
        $dir = Split-Path -Path $Path -Parent
        if ($dir -and -not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        $maxSizeMB = if ($Global:LogFileMaxSizeMB -gt 0) { [double]$Global:LogFileMaxSizeMB } else { 5 }
        if ((Test-Path $Path) -and ((Get-Item $Path).Length -gt ($maxSizeMB * 1MB))) {
            $archive = Join-Path $dir ("{0}_{1}{2}" -f [System.IO.Path]::GetFileNameWithoutExtension($Path), (Get-Date -Format "HHmmss"), [System.IO.Path]::GetExtension($Path))
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

# Odczyt identyfikatorów z pliku CSV (wskazana kolumna) lub TXT (jeden na linię)
function Import-HTIdentityFile {
    param (
        [Parameter(Mandatory)][string]$Path,
        [string]$Column
    )
    if ($Path -match '\.csv$') {
        $firstLine = Get-Content -Path $Path -TotalCount 1 -Encoding utf8
        $delimiter = if ($firstLine -match ';') { ';' } else { ',' }
        $rows = @(Import-Csv -Path $Path -Delimiter $delimiter -Encoding utf8)
        if ($rows.Count -eq 0) { return @() }
        $columns = @($rows[0].PSObject.Properties.Name)
        if (-not $Column) {
            # Kolumna wg priorytetu nazw (identyfikatory przed nazwami wyświetlanymi)
            $priority = "UserPrincipalName", "UPN", "Mail", "Email", "E-mail", "PrimarySmtpAddress", "SamAccountName", "Login", "Identity", "DeviceName", "Name"
            $Column = $priority | Where-Object { $columns -contains $_ } | Select-Object -First 1
            if (-not $Column) { $Column = $columns[0] }
        }
        return @($rows | ForEach-Object { "$($_.$Column)".Trim() } | Where-Object { $_ } | Select-Object -Unique)
    }
    return Split-HTInputList -Text (Get-Content -Path $Path -Raw -Encoding utf8)
}

# Spłaszcza słownik szczegółów (z zagnieżdżonymi sekcjami) do wierszy Sekcja / Pole / Wartość
function ConvertTo-HTDetailRows {
    param (
        [Parameter(Mandatory)][System.Collections.IDictionary]$Data,
        [string]$Section = "Ogólne"
    )
    foreach ($key in $Data.Keys) {
        $value = $Data[$key]
        if ($value -is [System.Collections.IDictionary]) {
            ConvertTo-HTDetailRows -Data $value -Section ([string]$key)
            continue
        }
        $text = if ($value -is [array]) { (@($value | ForEach-Object { ConvertTo-HTDisplayValue $_ }) -join "`n") } else { ConvertTo-HTDisplayValue $value }
        [PSCustomObject]@{
            Sekcja  = $Section
            Pole    = [string]$key
            Wartość = $text
        }
    }
}

# Liczba dni od podanej daty (null, gdy brak daty)
function Get-HTDaysSince {
    param ([AllowNull()][object]$Date)
    if ($null -eq $Date -or "$Date" -eq "") { return $null }
    $value = $null
    if ($Date -is [datetime]) { $value = $Date }
    elseif ($Date -is [datetimeoffset]) { $value = $Date.LocalDateTime }
    else {
        $parsed = [datetimeoffset]::MinValue
        if (-not [datetimeoffset]::TryParse("$Date", [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) { return $null }
        $value = $parsed.LocalDateTime
    }
    if ($value.Year -lt 1700) { return $null }
    return [int][Math]::Floor(((Get-Date) - $value).TotalDays)
}
