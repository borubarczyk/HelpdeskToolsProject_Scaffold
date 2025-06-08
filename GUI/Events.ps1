# Połączenie z Exchange
$HT_UI.Buttons.ConnectExchange.Add_Click({
        [System.Windows.Forms.MessageBox]::Show("🔄 Próba połączenia z Exchange...")
        Write-Log -Message "Próba połączenia z Exchange Online..." -Type "Info"
    })

# Połączenie z SharePoint
$HT_UI.Buttons.ConnectSharePoint.Add_Click({
        [System.Windows.Forms.MessageBox]::Show("🔄 Próba połączenia z SharePoint...")
        Write-Log -Message "Próba połączenia z SharePoint Online..." -Type "Info"
    })

# Połączenie z GraphAPI
$HT_UI.Buttons.ConnectGraph.Add_Click({
        [System.Windows.Forms.MessageBox]::Show("🔄 Próba połączenia z Microsoft Graph API...")
        Write-Log -Message "Próba połączenia z Microsoft Graph API..." -Type "Info"
    })

# Generator haseł
$HT_UI.Buttons.PasswordGen.Add_Click({
        Write-Log -Message "Otwieranie generatora haseł..." -Type "Info"
        try {
            $form_PasswordGenerator.ShowDialog()
        }
        catch {
            Write-Log -Message "Błąd podczas otwierania generatora haseł: $_" -Type "Error&Notification"
            Show-Dialog -Message "Błąd podczas otwierania generatora haseł: $_" -Title "Błąd" -Type "Error" 
        }
    })

# Wyjście
$HT_UI.Buttons.Exit.Add_Click({
        Write-Log -Message "Zamykanie aplikacji..." -Type "Info"
        $HT_UI.Form.Close()
    })

# Zmieniono zakładkę
$HT_UI.TabControl.Add_SelectedIndexChanged({
        $selectedTab = $HT_UI.TabControl.SelectedTab
        Write-Log -Message "Zmieniono zakładkę na: $($selectedTab.Text)" -Type "Info"
        $HT_UI.Form.Text = "Helpdesk Tools - $($selectedTab.Text)"
    })

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
            Show-Toast -Message "Logi skopiowane do schowka" -NotificationType "Info"
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
