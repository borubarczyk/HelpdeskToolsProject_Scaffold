# Panel dla zakładki "Logi"
$theme = $Global:HTTheme

$panel_Logs = New-Object System.Windows.Forms.Panel
$panel_Logs.Dock = [System.Windows.Forms.DockStyle]::Fill
$panel_Logs.BackColor = $theme.Background
$panel_Logs.Padding = New-Object System.Windows.Forms.Padding(12, 10, 12, 12)

# Pasek narzędzi: filtr tekstowy i typ
$flow_LogToolbar = New-Object System.Windows.Forms.FlowLayoutPanel
$flow_LogToolbar.Dock = [System.Windows.Forms.DockStyle]::Top
$flow_LogToolbar.Height = 46
$flow_LogToolbar.WrapContents = $false

$textbox_LogFilter = New-Object System.Windows.Forms.TextBox
$textbox_LogFilter.Width = 340
$textbox_LogFilter.PlaceholderText = "Filtruj logi... (Esc - wyczyść)"
$textbox_LogFilter.Margin = New-Object System.Windows.Forms.Padding(0, 6, 8, 0)

$combobox_LogType = New-Object System.Windows.Forms.ComboBox
$combobox_LogType.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$combobox_LogType.Width = 130
$combobox_LogType.Items.AddRange(@("Wszystkie", "Info", "Warn", "Error"))
$combobox_LogType.SelectedIndex = 0
$combobox_LogType.Margin = New-Object System.Windows.Forms.Padding(0, 6, 8, 0)

$checkbox_LogAutoScroll = New-Object System.Windows.Forms.CheckBox
$checkbox_LogAutoScroll.Text = "Przewijaj automatycznie"
$checkbox_LogAutoScroll.Checked = $true
$checkbox_LogAutoScroll.AutoSize = $true
$checkbox_LogAutoScroll.Margin = New-Object System.Windows.Forms.Padding(4, 9, 8, 0)

$flow_LogToolbar.Controls.AddRange(@($textbox_LogFilter, $combobox_LogType, $checkbox_LogAutoScroll))

# RichTextBox do logów
$richtextbox_Logs = New-Object System.Windows.Forms.RichTextBox
$richtextbox_Logs.Dock = [System.Windows.Forms.DockStyle]::Fill
$richtextbox_Logs.ReadOnly = $true
$richtextbox_Logs.BackColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
$richtextbox_Logs.ForeColor = [System.Drawing.Color]::FromArgb(226, 232, 240)
$richtextbox_Logs.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$richtextbox_Logs.Font = $theme.FontMono
$richtextbox_Logs.WordWrap = $false
$richtextbox_Logs.DetectUrls = $false

# Panel z przyciskami (po prawej)
$actionPanel_Logs = New-HTActionPanel -Actions @(
    @{ Group = "Log" }
    @{ Key = "CopyLog"; Text = "Kopiuj widoczne"; Icon = "Copy.png" }
    @{ Key = "SaveLog"; Text = "Zapisz do pliku"; Icon = "Save.png" }
    @{ Key = "ClearLog"; Text = "Wyczyść widok"; Icon = "Clear Symbol.png" }
    @{ Group = "Pliki" }
    @{ Key = "OpenLogFile"; Text = "Otwórz plik logu"; Icon = "filing-cabinet.png" }
    @{ Key = "ConfigLocation"; Text = "Folder konfiguracji i logów"; Icon = "Opened Folder.png" }
)

$spacer_Logs = New-Object System.Windows.Forms.Panel
$spacer_Logs.Dock = [System.Windows.Forms.DockStyle]::Right
$spacer_Logs.Width = 10

$panel_Logs.Controls.Add($richtextbox_Logs)
$panel_Logs.Controls.Add($spacer_Logs)
$panel_Logs.Controls.Add($actionPanel_Logs.Panel)
$panel_Logs.Controls.Add($flow_LogToolbar)
$richtextbox_Logs.BringToFront()

# Podłączenie do zakładki
$HT_UI.Tabs["Logi"].Controls.Clear()
$HT_UI.Tabs["Logi"].Controls.Add($panel_Logs)

# Eksport referencji
$global:HT_UI.LogsTab = [ordered]@{
    Panel      = $panel_Logs
    TextBox    = $richtextbox_Logs
    Buttons    = $actionPanel_Logs.Buttons
    FilterBox  = $textbox_LogFilter
    FilterType = $combobox_LogType
    AutoScroll = $checkbox_LogAutoScroll
}
