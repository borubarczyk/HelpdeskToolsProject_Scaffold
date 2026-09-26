# Panel SettingsTab - walidacja JSON z opóźnieniem (nie przy każdym naciśnięciu klawisza)
function Update-ConfigValidationState {
    $settings = $HT_UI.SettingsTab
    $isValid = Test-AndHighlightJson -RichTextBox $settings.ConfigEditor -ErrorToolTip $settings.ErrorToolTip -Quiet
    if ($isValid) {
        $settings.StatusLabel.ForeColor = $Global:HTTheme.Success
        $settings.StatusLabel.Text = "✔ Poprawny JSON (niezapisane zmiany - Ctrl+S)"
    }
    else {
        $settings.StatusLabel.ForeColor = $Global:HTTheme.Danger
        $settings.StatusLabel.Text = "✖ Błąd składni JSON - najedź na edytor, aby zobaczyć szczegóły"
    }
    return $isValid
}

$HT_UI.SettingsTab.ValidationTimer.Add_Tick({
        $HT_UI.SettingsTab.ValidationTimer.Stop()
        Update-ConfigValidationState | Out-Null
    })

$HT_UI.SettingsTab.ConfigEditor.Add_TextChanged({
        if (Test-HTJsonHighlighting) { return }
        $HT_UI.SettingsTab.ValidationTimer.Stop()
        $HT_UI.SettingsTab.ValidationTimer.Start()
    })

# Panel SettingsTab - zapis konfiguracji do pliku i zastosowanie
$HT_UI.SettingsTab.Buttons.SaveConfig.Add_Click({
        $HT_UI.SettingsTab.ValidationTimer.Stop()
        $isValid = Test-AndHighlightJson -RichTextBox $HT_UI.SettingsTab.ConfigEditor -ShowDialogOnError

        if (-not $isValid) {
            Write-Log -Message "Konfiguracja NIE została zapisana — błąd JSON." -Type "Error"
            return
        }

        try {
            $parsed = $HT_UI.SettingsTab.ConfigEditor.Text | ConvertFrom-Json -ErrorAction Stop
            $merged = (Merge-HTConfig -Config $parsed).Config

            Set-HTConfig -Config $merged -Path $Global:ConfigPath
            Apply-HTConfig -Config $merged | Out-Null
            Load-Config -Config $merged

            $HT_UI.SettingsTab.StatusLabel.ForeColor = $Global:HTTheme.Success
            $HT_UI.SettingsTab.StatusLabel.Text = "✔ Zapisano i zastosowano: $(Get-Date -Format 'HH:mm:ss')"
            Write-Log -Message "Konfiguracja została zapisana i zastosowana." -Type "Info&Notification"
        }
        catch {
            Write-Log -Message "Błąd podczas zapisywania konfiguracji: $_" -Type "Error&Notification"
            Show-Dialog -Message "Błąd podczas zapisywania konfiguracji:`n$_" -Title "Ustawienia" -Type "Error" | Out-Null
        }
    })

# Panel SettingsTab - ponowne wczytanie konfiguracji z pliku
$HT_UI.SettingsTab.Buttons.LoadConfig.Add_Click({
        try {
            $config = Ensure-HTConfig -Path $Global:ConfigPath
            if ($null -ne $config) {
                Apply-HTConfig -Config $config
                Load-Config -Config $Global:HTConfig
                Write-Log -Message "Konfiguracja została załadowana z pliku." -Type "Info"
            }
        }
        catch {
            Write-Log -Message "Błąd podczas ładowania konfiguracji: $_" -Type "Error&Notification"
        }
    })

# Panel SettingsTab - formatowanie JSON
$HT_UI.SettingsTab.Buttons.FormatConfig.Add_Click({
        try {
            $parsed = $HT_UI.SettingsTab.ConfigEditor.Text | ConvertFrom-Json -ErrorAction Stop
            $HT_UI.SettingsTab.ConfigEditor.Text = $parsed | ConvertTo-Json -Depth 10
            Update-ConfigValidationState | Out-Null
        }
        catch {
            Test-AndHighlightJson -RichTextBox $HT_UI.SettingsTab.ConfigEditor -ShowDialogOnError | Out-Null
        }
    })

# Panel SettingsTab - przywrócenie ustawień domyślnych (w edytorze - wymaga zapisania)
$HT_UI.SettingsTab.Buttons.ResetConfig.Add_Click({
        if (Show-HTConfirm -Message "Wczytać do edytora ustawienia domyślne?`nZmiany zostaną zapisane dopiero po kliknięciu 'Zapisz i zastosuj'." -Title "Ustawienia domyślne") {
            $HT_UI.SettingsTab.ConfigEditor.Text = (Get-HTDefaultConfig) | ConvertTo-Json -Depth 10
            Update-ConfigValidationState | Out-Null
        }
    })

# Panel SettingsTab - otwarcie folderu konfiguracji
$HT_UI.SettingsTab.Buttons.OpenFolder.Add_Click({
        if (-not (Test-Path $Global:ConfigDir)) { New-Item -ItemType Directory -Path $Global:ConfigDir -Force | Out-Null }
        Start-Process -FilePath $Global:ConfigDir
    })

# Panel SettingsTab - zapis przez Ctrl+S
$HT_UI.SettingsTab.ConfigEditor.Add_KeyDown({
        param($src, $evt)
        if ($evt.Control -and $evt.KeyCode -eq [System.Windows.Forms.Keys]::S) {
            $HT_UI.SettingsTab.Buttons.SaveConfig.PerformClick()
            $evt.SuppressKeyPress = $true
        }
    })
