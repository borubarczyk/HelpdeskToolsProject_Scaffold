# Generator haseł - Obsługa przycisku zamknięcia
$HT_UI.PasswordGeneratorWindow.Actions.Close.Add_Click({
        Write-Log -Message "Zamknięto generator haseł" -Type "Info"
        $form_PasswordGenerator.Close()
    })

# Generator haseł - Obsługa przycisku wysyłania hasła przez e-mail
$HT_UI.PasswordGeneratorWindow.Actions.Send.Add_Click({

        try {
            # Numer telefonu (opcjonalny)
            $phoneNumber = Show-InputBox -Prompt "Podaj numer telefonu do wysłania SMS z hasłem (opcjonalnie - pozostaw puste):" -Title "Numer telefonu:" -ValidationType "Phone"
            $cleanPhoneNumber = if ($phoneNumber) { Remove-InnerWhitespace -InputString $phoneNumber -Trim } else { "" }

            # Składamy temat
            $subjectText = ""
            if ($Global:PasswordEmailTitle) { $subjectText = $Global:PasswordEmailTitle }
            if ($cleanPhoneNumber) {
                $subjectText += $cleanPhoneNumber
            }

            # Składamy parametry mailto
            $subject = if ($subjectText) { [System.Web.HttpUtility]::UrlEncode($subjectText) } else { "" }
            $body = if ($richtextbox_Password.Text) { [System.Web.HttpUtility]::UrlEncode($richtextbox_Password.Text) } else { "" }

            $mailtoUri = "mailto:$($Global:PasswordEmailAdress)"
            $params = @()

            if ($subject) { $params += "subject=$subject" }
            if ($body) { $params += "body=$body" }

            if ($params.Count -gt 0) {
                $mailtoUri += "?" + ($params -join "&")
            }

            Start-Process $mailtoUri

            Write-Log -Message "Przygotowano e-mail do: $($Global:PasswordEmailAdress); Numer: $cleanPhoneNumber" -Type "Info"
        }
        catch {
            Write-Log -Message "Błąd podczas uruchamiania klienta e-mail: $_" -Type "Error&Notification"
        }
    })

# Generator haseł - Obsługa przycisku kopiowania
$HT_UI.PasswordGeneratorWindow.CopyButton.Add_Click({
        if ( $richtextbox_Password.Text -ne "" ) {
            try {
                [System.Windows.Forms.Clipboard]::SetText($richtextbox_Password.Text)
                Write-Log -Message "Hasło skopiowane do schowka" -Type "Info&Notification"
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

# Generator haseł - Zmiana ustawień checkboxów - Używaj liczb
$HT_UI.PasswordGeneratorWindow.Checkboxes.UseNumbers.Add_CheckedChanged({
        try {
            Set-GeneratedPassword
        }
        catch {
            Write-Log -Message "Błąd podczas generowania hasła: $_" -Type "Error"
            Show-Dialog -Message "Błąd podczas generowania hasła: $_" -Title "Błąd" -Type "Error"
        }
    })

# Generator haseł - Zmiana ustawień checkboxów - Rozpoczynaj od litery
$HT_UI.PasswordGeneratorWindow.Checkboxes.StartLetter.Add_CheckedChanged({
        try {
            Set-GeneratedPassword
        }
        catch {
            Write-Log -Message "Błąd podczas generowania hasła: $_" -Type "Error"
            Show-Dialog -Message "Błąd podczas generowania hasła: $_" -Title "Błąd" -Type "Error"
        }
    })

# Generator haseł - Zmiana ustawień checkboxów - Nie używaj podobnych znaków
$HT_UI.PasswordGeneratorWindow.Checkboxes.NoSimilar.Add_CheckedChanged({
        try {
            Set-GeneratedPassword
        }
        catch {
            Write-Log -Message "Błąd podczas generowania hasła: $_" -Type "Error"
            Show-Dialog -Message "Błąd podczas generowania hasła: $_" -Title "Błąd" -Type "Error"
        }
    })

# Generator haseł - Zmiana ustawień checkboxów - Używaj znaków specjalnych
$HT_UI.PasswordGeneratorWindow.Checkboxes.UseSymbols.Add_CheckedChanged({
        try {
            Set-GeneratedPassword
        }
        catch {
            Write-Log -Message "Błąd podczas generowania hasła: $_" -Type "Error"
            Show-Dialog -Message "Błąd podczas generowania hasła: $_" -Title "Błąd" -Type "Error"
        }
    })

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

# Generator haseł - Obsługa przycisku escape do zamknięcia
$HT_UI.PasswordGeneratorWindow.Form.Add_KeyDown({
        if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
            $HT_UI.PasswordGeneratorWindow.Actions.Close.PerformClick()
        }
    })
