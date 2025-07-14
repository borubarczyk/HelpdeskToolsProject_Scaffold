# Panel SettingsTab - Obsługa edytora konfiguracji - sprawdzanie i podświetlanie błędów JSON
$HT_UI.SettingsTab.ConfigEditor.Add_TextChanged({
    $isValid = Test-AndHighlightJson -RichTextBox $HT_UI.SettingsTab.ConfigEditor
    # np. zmień kolor obramowania na zielony/czerwony
    if ($isValid) {
        $HT_UI.SettingsTab.ConfigEditor.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    }
    else {
        $HT_UI.SettingsTab.ConfigEditor.BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D
    }
})

# Panel SettingsTab - Funkcja do testowania i podświetlania błędów JSON
$HT_UI.SettingsTab.Buttons.SaveConfig.Add_Click({
    $isValid = Test-AndHighlightJson -RichTextBox $HT_UI.SettingsTab.ConfigEditor -ShowDialogOnError

    if ($isValid) {
        try {
            $parsed = $HT_UI.SettingsTab.ConfigEditor.Text | ConvertFrom-Json -ErrorAction Stop

            # Zapisz do pliku
            Set-HTConfig -Config $parsed -Path $Global:ConfigPath

            # Od razu załaduj do zmiennych globalnych i GUI
            Apply-HTConfig -Config $parsed | Out-Null

            [System.Windows.Forms.MessageBox]::Show(
                "Konfiguracja została zapisana i zastosowana od razu.",
                "Informacja",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )

            Write-Log -Message "Konfiguracja została zapisana i zastosowana." -Type "Info&Notification"
        }
        catch {
            Write-Log -Message "Błąd podczas zapisywania konfiguracji: $_" -Type "Error&Notification"
        }
    }
    else {
        Write-Log -Message "Konfiguracja NIE została zapisana — błąd JSON." -Type "Error&Notification"
    }
})

# Panel SettingsTab - Obsługa przycisku ładowania konfiguracji
$HT_UI.SettingsTab.Buttons.LoadConfig.Add_Click({
    try {
        $config = Ensure-HTConfig -Path $Global:ConfigPath

        if ($null -ne $config) {
            $HT_UI.SettingsTab.ConfigEditor.Text = $config | ConvertTo-Json -Depth 10
            Test-AndHighlightJson -RichTextBox $HT_UI.SettingsTab.ConfigEditor
            Write-Log -Message "Konfiguracja została załadowana." -Type "Info&Notification"
        }
        else {
            Write-Log -Message "Konfiguracja NIE została załadowana — brak pliku lub użytkownik anulował." -Type "Warn"
        }
    }
    catch {
        Write-Log -Message "Błąd podczas ładowania konfiguracji: $_" -Type "Error&Notification"
    }
})

# Panel SettingsTab - Obsługa zapisywania konfiguracji przez Ctrl+S
$HT_UI.SettingsTab.ConfigEditor.Add_KeyDown({
    if ($_.Control -and $_.KeyCode -eq [System.Windows.Forms.Keys]::S) {
        $HT_UI.SettingsTab.Buttons.SaveConfig.PerformClick()
    }
})

