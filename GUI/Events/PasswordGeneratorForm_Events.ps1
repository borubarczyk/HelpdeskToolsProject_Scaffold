# Generator haseł - generowanie hasła na podstawie ustawień okna
function Set-GeneratedPassword {
    $pgw = $HT_UI.PasswordGeneratorWindow

    $length = [int]$pgw.Length.Value
    $symbols = $pgw.SpecialCharacters.Text
    $useNumbers = $pgw.Checkboxes.UseNumbers.Checked
    $useSymbols = $pgw.Checkboxes.UseSymbols.Checked

    $password = if ($pgw.Modes.Words.Checked) {
        New-WordBasedPassword -Length $length -UseNumbers $useNumbers -UseSymbols $useSymbols -SpecialCharacters $symbols
    }
    else {
        New-Password -Length $length -SpecialCharacters $symbols `
            -StartWithLetter $pgw.Checkboxes.StartLetter.Checked `
            -IncludeNumbers $useNumbers `
            -IncludeSymbols $useSymbols `
            -NoSimilarChars $pgw.Checkboxes.NoSimilar.Checked `
            -FriendlyMode $pgw.Modes.Friendly.Checked
    }

    $pgw.Password.Text = $password
    Update-PasswordStrength

    if ($Global:LogPasswordGeneration) {
        Write-Log -Message "Wygenerowano hasło: $password" -Type "Info"
    }
}

# Generator haseł - wskaźnik siły hasła
function Update-PasswordStrength {
    $pgw = $HT_UI.PasswordGeneratorWindow
    $strength = Get-HTPasswordStrength -Password $pgw.Password.Text
    $color = switch ($strength.Score) {
        1 { $Global:HTTheme.Danger }
        2 { $Global:HTTheme.Warning }
        3 { $Global:HTTheme.Success }
        4 { $Global:HTTheme.Success }
        default { $Global:HTTheme.Border }
    }
    $pgw.StrengthBar.BackColor = $color
    $pgw.StrengthBar.Width = [int]($pgw.StrengthTrack.Width * $strength.Score / 4)
    $pgw.StrengthLabel.Text = "Siła: $($strength.Label) (~$($strength.Entropy) bit)   Długość: $($pgw.Password.Text.Length)"
}

# Generator haseł - bezpieczne wywołanie generowania
function Invoke-PasswordGeneration {
    if (-not $HT_UI.PasswordGeneratorWindow.Initialized) { return }
    try {
        Set-GeneratedPassword
    }
    catch {
        Write-Log -Message "Błąd podczas generowania hasła: $_" -Type "Error"
        Show-Dialog -Message "Błąd podczas generowania hasła: $_" -Title "Błąd" -Type "Error" | Out-Null
    }
}

# Generator haseł - przy otwarciu: ustawienia z konfiguracji i nowe hasło
$HT_UI.PasswordGeneratorWindow.Form.Add_Load({
        $pgw = $HT_UI.PasswordGeneratorWindow
        $pgw.Initialized = $false
        $pgw.SpecialCharacters.Text = $Global:PasswordSpecialCharacters
        if (-not $pgw.OpenedOnce) {
            $length = [Math]::Max(8, [Math]::Min(64, [int]$Global:PasswordDefaultLength))
            $pgw.Length.Value = $length
            $pgw.LengthSlider.Value = $length
            if ($Global:PasswordUseWordBased) { $pgw.Modes.Words.Checked = $true } else { $pgw.Modes.Friendly.Checked = $true }
            $pgw.OpenedOnce = $true
        }
        $pgw.SpecialCharacters.Enabled = $pgw.Checkboxes.UseSymbols.Checked
        $pgw.Initialized = $true
        Invoke-PasswordGeneration
    })

# Generator haseł - zmiana trybu / opcji generuje nowe hasło
foreach ($radio in $HT_UI.PasswordGeneratorWindow.Modes.Values) {
    $radio.Add_CheckedChanged({
            param($src, $evt)
            if ($src.Checked) {
                $pgw = $HT_UI.PasswordGeneratorWindow
                $isClassic = $pgw.Modes.Classic.Checked
                $pgw.Checkboxes.NoSimilar.Enabled = $isClassic
                $pgw.Checkboxes.StartLetter.Enabled = $isClassic
                Invoke-PasswordGeneration
            }
        })
}

foreach ($checkbox in $HT_UI.PasswordGeneratorWindow.Checkboxes.Values) {
    $checkbox.Add_CheckedChanged({ Invoke-PasswordGeneration })
}

$HT_UI.PasswordGeneratorWindow.Checkboxes.UseSymbols.Add_CheckedChanged({
        $HT_UI.PasswordGeneratorWindow.SpecialCharacters.Enabled = $HT_UI.PasswordGeneratorWindow.Checkboxes.UseSymbols.Checked
    })

$HT_UI.PasswordGeneratorWindow.SpecialCharacters.Add_Leave({ Invoke-PasswordGeneration })

# Generator haseł - synchronizacja długości (pole liczbowe <-> suwak)
$HT_UI.PasswordGeneratorWindow.LengthSlider.Add_Scroll({
        $HT_UI.PasswordGeneratorWindow.Length.Value = $HT_UI.PasswordGeneratorWindow.LengthSlider.Value
    })

$HT_UI.PasswordGeneratorWindow.Length.Add_ValueChanged({
        $HT_UI.PasswordGeneratorWindow.LengthSlider.Value = [int]$HT_UI.PasswordGeneratorWindow.Length.Value
        Invoke-PasswordGeneration
    })

# Generator haseł - przyciski
$HT_UI.PasswordGeneratorWindow.Actions.Generate.Add_Click({ Invoke-PasswordGeneration })

$HT_UI.PasswordGeneratorWindow.Actions.Close.Add_Click({
        Write-Log -Message "Zamknięto generator haseł" -Type "Info"
        $HT_UI.PasswordGeneratorWindow.Form.Close()
    })

$HT_UI.PasswordGeneratorWindow.CopyButton.Add_Click({
        $password = $HT_UI.PasswordGeneratorWindow.Password.Text
        if ($password) {
            Set-HTClipboard -Text $password
            Write-Log -Message "Hasło skopiowane do schowka" -Type "Info"
            Set-HTStatus -Text "Hasło skopiowane do schowka."
        }
        else {
            Write-Log -Message "Brak hasła do skopiowania" -Type "Warning&Notification"
        }
    })

# Generator haseł - wysłanie hasła e-mailem (mailto), opcjonalnie z numerem telefonu w temacie (bramka SMS)
$HT_UI.PasswordGeneratorWindow.Actions.Send.Add_Click({
        try {
            $password = $HT_UI.PasswordGeneratorWindow.Password.Text
            if (-not $password) { return }

            $phoneNumber = Show-InputBox -Prompt "Numer telefonu do wysłania SMS z hasłem (opcjonalnie - pozostaw puste):" -Title "Numer telefonu" -ValidationType "Phone" -AllowEmpty
            if ($null -eq $phoneNumber) { return }
            $cleanPhoneNumber = if ($phoneNumber) { Remove-InnerWhitespace -InputString $phoneNumber -TrimEnds } else { "" }

            $subjectText = "$($Global:PasswordEmailTitle)"
            if ($cleanPhoneNumber) { $subjectText = ("$subjectText $cleanPhoneNumber").Trim() }

            $params = @()
            if ($subjectText) { $params += "subject=$([uri]::EscapeDataString($subjectText))" }
            $params += "body=$([uri]::EscapeDataString($password))"

            $mailtoUri = "mailto:$($Global:PasswordEmailAdress)?" + ($params -join "&")
            Start-Process $mailtoUri

            Write-Log -Message "Przygotowano e-mail do: $($Global:PasswordEmailAdress); Numer: $cleanPhoneNumber" -Type "Info"
        }
        catch {
            Write-Log -Message "Błąd podczas uruchamiania klienta e-mail: $_" -Type "Error&Notification"
        }
    })

# Generator haseł - skróty klawiszowe
$HT_UI.PasswordGeneratorWindow.Form.Add_KeyDown({
        param($src, $evt)
        if ($evt.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
            $HT_UI.PasswordGeneratorWindow.Actions.Close.PerformClick()
        }
        elseif ($evt.KeyCode -eq [System.Windows.Forms.Keys]::F5) {
            Invoke-PasswordGeneration
            $evt.SuppressKeyPress = $true
        }
        elseif ($evt.Control -and $evt.KeyCode -eq [System.Windows.Forms.Keys]::C -and -not $HT_UI.PasswordGeneratorWindow.SpecialCharacters.Focused) {
            $HT_UI.PasswordGeneratorWindow.CopyButton.PerformClick()
            $evt.SuppressKeyPress = $true
        }
    })
