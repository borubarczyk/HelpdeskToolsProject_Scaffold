# Połączenie z Exchange Online
$HT_UI.Buttons.ConnectExchange.Add_Click({
    if (-not $Global:ConnectedToExchange) {
        $response = Show-Dialog -Message "Czy chcesz się połączyć korzystając z konta GDAP?" -Title "GDAP" -Type "Question" -Buttons "YesNo"
        if ($response -eq "Yes") {
            Connect-Module -Name "ExchangeOnlineManagementGDAP" | Out-Null
        }
        elseif ($response -eq "No") {
            Connect-Module -Name "ExchangeOnlineManagement" | Out-Null
        }
    } else {
        Set-Connections -Action "Disconnect" -Service "Exchange"
    }
})
# Połączenie z Graph API
$HT_UI.Buttons.ConnectGraph.Add_Click({
    if (-not $Global:ConnectedToGraphAPI) {
        $response = Show-Dialog -Message "Czy chcesz się połączyć korzystając z konta GDAP?" -Title "GDAP" -Type "Question" -Buttons "YesNo"
        if ($response -eq "Yes") {
            Connect-Module -Name "Microsoft.GraphGDAP" | Out-Null
        }
        elseif ($response -eq "No") {
            Connect-Module -Name "Microsoft.Graph" | Out-Null
        }
    } else {
        Set-Connections -Action "Disconnect" -Service "Graph"
    }
})
# Połączenie z SharePoint
$HT_UI.Buttons.ConnectSharePoint.Add_Click({
    if (-not $Global:ConnectedToSharepointPnP) {
        Connect-Module -Name "PnP.PowerShell" | Out-Null
    } else {
        Set-Connections -Action "Disconnect" -Service "SharePoint"
    }
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
        Set-ButtonsState -Action "Lock"
        Set-Connections -Action "Disconnect" 
        Write-Log -Message "Zamykanie aplikacji..." -Type "Info"
        Set-ButtonsState -Action "Unlock"
        $HT_UI.Form.Close()
        $HT_UI.Form.Dispose()
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

# LogsPanel - Escape jako wyczyszczenie filtrowania
$HT_UI.LogsTab.FilterBox.Add_KeyDown({
        if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
            $HT_UI.LogsTab.FilterBox.Clear()
        }
    })

# Generator haseł - Obsługa przycisku zamknięcia
$HT_UI.PasswordGeneratorWindow.Actions.Close.Add_Click({
        Write-Log -Message "Zamknięto generator haseł" -Type "Info"
        $form_PasswordGenerator.Close()
    })

# Generator haseł - Obsługa przycisku wysyłania hasła e-mailem
$HT_UI.PasswordGeneratorWindow.Actions.Send.Add_Click({
        if ($richtextbox_Password.Text -ne "" -and $Global:PasswordEmailAdress -ne "" -or $Global:PasswordEmailAdress -ne $null -and $Global:dPasswordEmailTitle -ne "" -or $Global:dPasswordEmailTitle -ne $null) {
            try {
                $phoneNumber = Show-InputBox -Prompt "Podaj numer telefonu do wysłania SMS z hasłem (opcjonalnie - pozostaw puste):" -Title "Numer telefonu:" -ValidationType "Phone"
                if ($phoneNumber) {
                    $subject = [System.Web.HttpUtility]::UrlEncode($Global:PasswordEmailTitle + $phoneNumber)
                    $body = [System.Web.HttpUtility]::UrlEncode($richtextbox_Password.Text)
                    $mailtoUri = "mailto:$($Global:PasswordEmailAdress)?subject=$subject&body=$body"
                    Start-Process $mailtoUri
                    Write-Log -Message "E-mail z hasłem został wysłany do $($Global:PasswordEmailAdress)" -Type "Info"
                }
                else {
                    Write-Log -Message "Anulowane przez użytkownika" -Type "Warn"
                }
            }
            catch {
                Write-Log -Message "Błąd podczas wysyłania e-maila z hasłem: $_" -Type "Error&Notification"
            }
        }
        else {
            Write-Log -Message "Brak hasła lub adresu e-mail do wysłania" -Type "Warning&Notification"
        }
    
    })

# Generator haseł - Obsługa przycisku kopiowania
$HT_UI.PasswordGeneratorWindow.CopyButton.Add_Click({
        if ( $richtextbox_Password.Text -ne "" ) {
            try {
                [System.Windows.Forms.Clipboard]::SetText($richtextbox_Password.Text)
                Write-Log -Message "Hasło skopiowane do schowka" -NotificationType "Info"
                Show-Toast -Message "Hasło skopiowane do schowka" -NotificationType "Info"
            }
            catch {
                Write-Log -Message "Błąd podczas kopiowania hasła do schowka: $_" -Type "Error&Notification"
            }
        }
        else {
            Write-Log -Message "Brak hasła do skopiowania" -Type "Warning&Notification"
        }
    })

# Generator haseł - Zmiana ustawień checkboxów - używaj znaków specjalnych
$HT_UI.PasswordGeneratorWindow.Checkboxes.UseSymbols.Add_CheckedChanged({
        $HT_UI.PasswordGeneratorWindow.SpecialCharacters.Enabled = $HT_UI.PasswordGeneratorWindow.Checkboxes.UseSymbols.Checked
    })

# Generator haseł - Zmiana ustawień checkboxów - Przyjazne hasła
$HT_UI.PasswordGeneratorWindow.Checkboxes.Friendly.Add_CheckedChanged({
        if ($this.Checked) {
            $HT_UI.PasswordGeneratorWindow.Checkboxes.Words.Checked = $false
            try {
                Set-GeneratedPassword
            }
            catch {
                <#Do this if a terminating exception happens#>
                Write-Log -Message "Błąd podczas generowania hasła: $_" -Type "Error"
                Show-Dialog -Message "Błąd podczas generowania hasła: $_" -Title "Błąd" -Type "Error"
            }

        }
    })

# Generator haseł - Zmiana ustawień checkboxów - Słownikowe hasła
$HT_UI.PasswordGeneratorWindow.Checkboxes.Words.Add_CheckedChanged({
        if ($this.Checked) {
            $HT_UI.PasswordGeneratorWindow.Checkboxes.Friendly.Checked = $false
            try {
                Set-GeneratedPassword
            }
            catch {
                Write-Log -Message "Błąd podczas generowania hasła: $_" -Type "Error"
                Show-Dialog -Message "Błąd podczas generowania hasła: $_" -Title "Błąd" -Type "Error"
            }
        }
    })

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
# Generator haseł - Generuj hasło po załadowaniu formularza
$HT_UI.PasswordGeneratorWindow.Form.Add_Load({
        try {
            Set-GeneratedPassword
        }
        catch {

            Write-Log -Message "Błąd podczas generowania hasła: $_" -Type "Error"
            Show-Dialog -Message "Błąd podczas generowania hasła: $_" -Title "Błąd" -Type "Error"
        }
    })

# Generator haseł - Obsługa przycisku generowania hasła
$HT_UI.PasswordGeneratorWindow.Actions.Generate.Add_Click({
        try {
            Set-GeneratedPassword
        }
        catch {
            Write-Log -Message "Błąd podczas generowania hasła: $_" -Type "Error"
            Show-Dialog -Message "Błąd podczas generowania hasła: $_" -Title "Błąd" -Type "Error"
        }
    })

# Generator haseł - Zmiana wartości długości hasła
$HT_UI.PasswordGeneratorWindow.Length.Add_ValueChanged({
        try {
            Set-GeneratedPassword
        }
        catch {
            Write-Log -Message "Błąd podczas zmiany długości hasła: $_" -Type "Error"
            Show-Dialog -Message "Błąd podczas zmiany długości hasła: $_" -Title "Błąd" -Type "Error"
        }
    })

$HT_UI.PasswordGeneratorWindow.Form.Add_KeyDown({
        if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
            $HT_UI.PasswordGeneratorWindow.Actions.Close.PerformClick()
        }
    })
