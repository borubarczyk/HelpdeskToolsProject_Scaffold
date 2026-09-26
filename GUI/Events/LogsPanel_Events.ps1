# LogsPanel - dopisanie wpisu do widoku (z kolorem zależnym od typu)
function Add-HTLogLine {
    param ([Parameter(Mandatory)][object]$Entry)
    $textbox = $HT_UI.LogsTab.TextBox
    if (-not $textbox -or $textbox.IsDisposed) { return }

    $color = switch ($Entry.Type) {
        "Warn" { [System.Drawing.Color]::FromArgb(251, 191, 36) }
        "Error" { [System.Drawing.Color]::FromArgb(248, 113, 113) }
        default { [System.Drawing.Color]::FromArgb(134, 239, 172) }
    }
    $textbox.SelectionStart = $textbox.TextLength
    $textbox.SelectionLength = 0
    $textbox.SelectionColor = $color
    $textbox.AppendText((Format-HTLogEntry -Entry $Entry) + "`n")
    $textbox.SelectionColor = $textbox.ForeColor
}

# Funkcja do aktualizacji (przebudowy) widoku logów w GUI zgodnie z filtrem
function Update-LogView {
    if (-not $HT_UI.LogsTab) { return }
    $textbox = $HT_UI.LogsTab.TextBox
    $filterText = $HT_UI.LogsTab.FilterBox.Text
    $selectedType = "$($HT_UI.LogsTab.FilterType.SelectedItem)"

    $textbox.SuspendLayout()
    try {
        $textbox.Clear()
        foreach ($entry in (Get-HTLogHistory)) {
            if (Test-HTLogEntryMatch -Entry $entry -FilterText $filterText -FilterType $selectedType) {
                Add-HTLogLine -Entry $entry
            }
        }
        $textbox.SelectionStart = $textbox.TextLength
        $textbox.ScrollToCaret()
    }
    finally {
        $textbox.ResumeLayout()
    }
}

# Nowe wpisy logu trafiają na bieżąco do widoku (jeśli pasują do filtra)
Register-HTLogSink -ScriptBlock {
    param($entry)
    if (-not $HT_UI.LogsTab) { return }
    if (Test-HTLogEntryMatch -Entry $entry -FilterText $HT_UI.LogsTab.FilterBox.Text -FilterType "$($HT_UI.LogsTab.FilterType.SelectedItem)") {
        Add-HTLogLine -Entry $entry
        if ($HT_UI.LogsTab.AutoScroll.Checked) { $HT_UI.LogsTab.TextBox.ScrollToCaret() }
    }
}
Update-LogView

# LogsPanel - filtrowanie treści logów
$HT_UI.LogsTab.FilterBox.Add_TextChanged({ Update-LogView })

# LogsPanel - zmiana typu filtra logów
$HT_UI.LogsTab.FilterType.Add_SelectedIndexChanged({ Update-LogView })

# LogsPanel - Escape jako wyczyszczenie filtrowania
$HT_UI.LogsTab.FilterBox.Add_KeyDown({
        param($src, $evt)
        if ($evt.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
            $src.Clear()
            $evt.SuppressKeyPress = $true
        }
    })

# LogsPanel - wyczyszczenie widoku (plik logu pozostaje)
$HT_UI.LogsTab.Buttons.ClearLog.Add_Click({
        Clear-HTLogHistory
        $HT_UI.LogsTab.TextBox.Clear()
        Write-Log -Message "Wyczyszczono widok logów (plik logu pozostaje bez zmian)." -Type "Info"
    })

# LogsPanel - kopiowanie logów do schowka
$HT_UI.LogsTab.Buttons.CopyLog.Add_Click({
        $logText = $HT_UI.LogsTab.TextBox.Text
        if ($logText) {
            Set-HTClipboard -Text $logText
            Set-HTStatus -Text "Logi skopiowane do schowka."
        }
        else {
            Write-Log -Message "Brak treści do skopiowania" -Type "Warning&Notification"
        }
    })

# LogsPanel - zapis logów do pliku
$HT_UI.LogsTab.Buttons.SaveLog.Add_Click({
        $logContent = $HT_UI.LogsTab.TextBox.Text
        if ($logContent) {
            Save-ContentToFile -Data @($logContent) -Format "txt" -Title "Zapis logów" -DefaultName "Logi_HelpdeskTools" | Out-Null
        }
        else {
            Write-Log -Message "Brak logów do zapisania." -Type "Warn"
        }
    })

# LogsPanel - otwarcie pliku logu
$HT_UI.LogsTab.Buttons.OpenLogFile.Add_Click({
        $path = Join-Path $Global:ConfigDir "logs.txt"
        if (Test-Path $path) {
            Start-Process -FilePath $path
        }
        else {
            Show-Dialog -Message "Plik logu jeszcze nie istnieje:`n$path" -Title "Plik logu" -Type "Info" | Out-Null
        }
    })

# LogsPanel - otwieranie lokalizacji pliku konfiguracyjnego i logów
$HT_UI.LogsTab.Buttons.ConfigLocation.Add_Click({
        try {
            if (-not (Test-Path $Global:ConfigDir)) { New-Item -ItemType Directory -Path $Global:ConfigDir -Force | Out-Null }
            Start-Process -FilePath $Global:ConfigDir
        }
        catch {
            Write-Log -Message "Nie udało się otworzyć folderu konfiguracji: $_" -Type "Error"
        }
    })
