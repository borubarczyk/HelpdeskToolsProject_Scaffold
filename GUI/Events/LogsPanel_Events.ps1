# LogsPanel - filtrowanie treści logów
$HT_UI.LogsTab.FilterBox.Add_TextChanged({
        Update-LogView
    })

# LogsPanel - zmiana typu filtra logów
$HT_UI.LogsTab.FilterType.Add_SelectedIndexChanged({
        Update-LogView
    })

# LogsPanel - usunięcie logów
$HT_UI.LogsTab.Buttons.ClearLog.Add_Click({
        $global:LogHistory.Clear()
        $HT_UI.LogsTab.TextBox.Clear()
        Write-Log -Message "Wyczyszczono logi" -Type "Info"
    })

# LogsPanel - kopowanie logów do schowka
$HT_UI.LogsTab.Buttons.CopyLog.Add_Click({
        $logText = $HT_UI.LogsTab.TextBox.Text
        if ($logText) {
            [System.Windows.Forms.Clipboard]::SetText($logText)
            Write-Log -Message "Logi skopiowane do schowka" -Type "Info&Notification"
        }
        else {
            Write-Log -Message "Brak treści do skopiowania" -Type "Warning&Notification"
        }
    })

# LogsPanel - zapis logów do pliku
$HT_UI.LogsTab.Buttons.SaveLog.Add_Click({
        $logContent = $HT_UI.LogsTab.TextBox.Text
        if ($logContent) {
            Save-ContentToFile -Data $logContent -Format "txt" -Title "Zapis logów" -DefaultName "Logi_HelpdeskTools"
        }
    })

# LogsPanel - otwieranie lokalizacji pliku konfiguracyjnego
$HT_UI.LogsTab.Buttons.ConfigLocation.Add_Click({
        try {
            Start-Process -FilePath $Global:ConfigDir
        }
        catch {
            Write-Log -Message "Brak pliku konfiguracyjnego: $_" -Type "Error"
        }
    })

# LogsPanel - Escape jako wyczyszczenie filtrowania
$HT_UI.LogsTab.FilterBox.Add_KeyDown({
        if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
            $HT_UI.LogsTab.FilterBox.Clear()
        }
    })