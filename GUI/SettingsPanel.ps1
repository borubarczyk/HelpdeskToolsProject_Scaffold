# Panel dla zakładki "Ustawienia": edytor config.json z walidacją i opisem kluczy
$theme = $Global:HTTheme

$panel_Settings = New-Object System.Windows.Forms.Panel
$panel_Settings.Dock = [System.Windows.Forms.DockStyle]::Fill
$panel_Settings.BackColor = $theme.Background
$panel_Settings.Padding = New-Object System.Windows.Forms.Padding(12, 10, 12, 12)

# Informacja o pliku
$label_ConfigPath = New-Object System.Windows.Forms.Label
$label_ConfigPath.Dock = [System.Windows.Forms.DockStyle]::Top
$label_ConfigPath.Height = 30
$label_ConfigPath.ForeColor = $theme.Muted
$label_ConfigPath.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$label_ConfigPath.Text = "Plik: $($Global:ConfigPath)   (Ctrl+S - zapisz)"

# RichTextBox do edycji konfiguracji JSON
$richtextbox_ConfigEditor = New-Object System.Windows.Forms.RichTextBox
$richtextbox_ConfigEditor.Dock = [System.Windows.Forms.DockStyle]::Fill
$richtextbox_ConfigEditor.BackColor = [System.Drawing.Color]::White
$richtextbox_ConfigEditor.ForeColor = [System.Drawing.Color]::Black
$richtextbox_ConfigEditor.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$richtextbox_ConfigEditor.Font = New-Object System.Drawing.Font("Consolas", 11)
$richtextbox_ConfigEditor.WordWrap = $false
$richtextbox_ConfigEditor.AcceptsTab = $true
$richtextbox_ConfigEditor.DetectUrls = $false

# Opis dostępnych ustawień
$label_ConfigHelp = New-Object System.Windows.Forms.Label
$label_ConfigHelp.Dock = [System.Windows.Forms.DockStyle]::Bottom
$label_ConfigHelp.Height = 150
$label_ConfigHelp.Padding = New-Object System.Windows.Forms.Padding(4, 8, 4, 4)
$label_ConfigHelp.ForeColor = $theme.Muted
$label_ConfigHelp.Font = $theme.FontSmall
$label_ConfigHelp.Text = @"
PasswordEmailAdress / PasswordEmailTitle - adres i temat wiadomości z hasłem (generator haseł)
PasswordSpecialCharacters - znaki specjalne używane w hasłach  |  PasswordUseWordBased - domyślnie hasła słownikowe  |  PasswordDefaultLength - domyślna długość (8-64)
LogPasswordGeneration - zapisuj wygenerowane hasła w logu (NIEZALECANE)  |  LogClientIDForPnP / LastUsedClientID - zapamiętanie Client ID aplikacji PnP
DefaultSharepointSite - domyślna witryna SharePoint  |  DefaultUsageLocation - kraj ustawiany przy przypisywaniu licencji (np. PL)
GraphScopes - uprawnienia Microsoft Graph żądane przy logowaniu  |  ShowNotifications - powiadomienia w zasobniku systemowym
LogFileMaxSizeMB - rozmiar pliku logu, po którym tworzone jest archiwum  |  ExportPath - folder eksportu (puste = folder konfiguracji\Exports)
"@

$panel_EditorHost = New-Object System.Windows.Forms.Panel
$panel_EditorHost.Dock = [System.Windows.Forms.DockStyle]::Fill
$panel_EditorHost.BackColor = [System.Drawing.Color]::White
$panel_EditorHost.Padding = New-Object System.Windows.Forms.Padding(8)
$panel_EditorHost.Controls.Add($richtextbox_ConfigEditor)

$label_ConfigStatus = New-Object System.Windows.Forms.Label
$label_ConfigStatus.Dock = [System.Windows.Forms.DockStyle]::Bottom
$label_ConfigStatus.Height = 26
$label_ConfigStatus.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$label_ConfigStatus.ForeColor = $theme.Success
$label_ConfigStatus.Text = ""

$tooltip_ConfigError = New-Object System.Windows.Forms.ToolTip

# Panel z przyciskami po prawej stronie
$actionPanel_Settings = New-HTActionPanel -Actions @(
    @{ Group = "Konfiguracja" }
    @{ Key = "SaveConfig"; Text = "Zapisz i zastosuj"; Icon = "Save.png"; Style = "Primary" }
    @{ Key = "LoadConfig"; Text = "Załaduj ponownie"; Icon = "Refresh.png" }
    @{ Key = "FormatConfig"; Text = "Formatuj JSON"; Icon = "validation.png" }
    @{ Key = "ResetConfig"; Text = "Przywróć domyślne"; Icon = "update-left-rotation.png"; Style = "Danger" }
    @{ Group = "Pliki" }
    @{ Key = "OpenFolder"; Text = "Otwórz folder"; Icon = "Opened Folder.png" }
)

$spacer_Settings = New-Object System.Windows.Forms.Panel
$spacer_Settings.Dock = [System.Windows.Forms.DockStyle]::Right
$spacer_Settings.Width = 10

$panel_Settings.Controls.Add($panel_EditorHost)
$panel_Settings.Controls.Add($label_ConfigStatus)
$panel_Settings.Controls.Add($label_ConfigHelp)
$panel_Settings.Controls.Add($spacer_Settings)
$panel_Settings.Controls.Add($actionPanel_Settings.Panel)
$panel_Settings.Controls.Add($label_ConfigPath)
$panel_EditorHost.BringToFront()

# Podłączenie do zakładki
$HT_UI.Tabs["Ustawienia"].Controls.Clear()
$HT_UI.Tabs["Ustawienia"].Controls.Add($panel_Settings)

# Opóźniona walidacja podczas pisania
$timer_ConfigValidation = New-Object System.Windows.Forms.Timer
$timer_ConfigValidation.Interval = 600

# Eksport referencji
$global:HT_UI.SettingsTab = [ordered]@{
    Panel           = $panel_Settings
    ConfigEditor    = $richtextbox_ConfigEditor
    StatusLabel     = $label_ConfigStatus
    ErrorToolTip    = $tooltip_ConfigError
    ValidationTimer = $timer_ConfigValidation
    Buttons         = $actionPanel_Settings.Buttons
}

# Wczytanie bieżącej konfiguracji do edytora
function Load-Config {
    param ([object]$Config = $Global:HTConfig)
    if ($null -ne $Config) {
        $HT_UI.SettingsTab.ConfigEditor.Text = $Config | ConvertTo-Json -Depth 10
        Test-AndHighlightJson -RichTextBox $HT_UI.SettingsTab.ConfigEditor -Quiet | Out-Null
        $HT_UI.SettingsTab.StatusLabel.ForeColor = $Global:HTTheme.Success
        $HT_UI.SettingsTab.StatusLabel.Text = "✔ Konfiguracja wczytana."
    }
    else {
        Write-Log -Message "Nie wczytano konfiguracji — brak pliku." -Type "Warn"
    }
}

Load-Config
