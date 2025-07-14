# Panel dla zakładki "Ustawienia"
$panel_Settings = New-Object System.Windows.Forms.Panel
$panel_Settings.Dock = 'Fill'

# Ścieżka do pliku konfiguracyjnego
$global:HT_ConfigFile = ".\config.json"

# RichTextBox do edycji konfiguracji JSON
$richtextbox_ConfigEditor = New-Object System.Windows.Forms.RichTextBox
$richtextbox_ConfigEditor.Location = '10,10'
$richtextbox_ConfigEditor.Size = '660,600'
$richtextbox_ConfigEditor.BackColor = 'White'
$richtextbox_ConfigEditor.ForeColor = 'Black'
$richtextbox_ConfigEditor.Font = New-Object System.Drawing.Font("Consolas", 15)
$richtextbox_ConfigEditor.WordWrap = $false



# Panel z przyciskami po prawej stronie
$panel_SettingsButtons = New-Object System.Windows.Forms.FlowLayoutPanel
$panel_SettingsButtons.Location = '680,10'
$panel_SettingsButtons.Size = '190,600'
$panel_SettingsButtons.FlowDirection = 'TopDown'
$panel_SettingsButtons.WrapContents = $false
$panel_SettingsButtons.AutoScroll = $true

function New-SettingsActionButton($text) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Size = '170,45'
    $btn.Text = $text
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    return $btn
} 

# Przycisk Zapisz konfigurację
$btn_SaveConfig = New-SettingsActionButton "Zapisz konfigurację"
$btn_LoadConfig = New-SettingsActionButton "Załaduj ponownie"

# Dodaj przyciski do panelu
$panel_SettingsButtons.Controls.Add($btn_SaveConfig)
$panel_SettingsButtons.Controls.Add($btn_LoadConfig)

# Dodaj kontrolki do głównego panelu Settings
$panel_Settings.Controls.AddRange(@(
    $richtextbox_ConfigEditor,
    $panel_SettingsButtons
))

# Podłączenie do zakładki
$HT_UI.Tabs["Ustawienia"].Controls.Clear()
$HT_UI.Tabs["Ustawienia"].Controls.Add($panel_Settings)

# Funkcja do wczytania konfiguracji
function Load-Config {
    $config = Ensure-HTConfig -Path $Global:ConfigPath

    if ($null -ne $config) {
        Apply-HTConfig -Config $config
        $richtextbox_ConfigEditor.Text = $config | ConvertTo-Json -Depth 10
        Test-AndHighlightJson -RichTextBox $richtextbox_ConfigEditor
        Write-Log -Message "Konfiguracja wczytana i ustawiona w UI." -Type "Info&Notification"
    } else {
        Write-Log -Message "Nie wczytano konfiguracji — brak pliku." -Type "Warn"
    }
    return $null
}

# Wczytaj konfigurację przy uruchomieniu panelu
Load-Config | Out-Null

# Eksport referencji
$global:HT_UI.SettingsTab = [ordered]@{
    Panel        = $panel_Settings
    ConfigEditor = $richtextbox_ConfigEditor
    Buttons      = [ordered]@{
        SaveConfig = $btn_SaveConfig
        LoadConfig = $btn_LoadConfig
    }
}
