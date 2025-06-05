# Panel dla zakładki "Logi"
$panel_Logs = New-Object System.Windows.Forms.Panel
$panel_Logs.Dock = 'Fill'

# Zmienna do przechowywania wszystkich logów
$global:LogHistory = New-Object System.Collections.Generic.List[PSCustomObject]

# ComboBox do filtrowania typów logów
$combobox_LogType = New-Object System.Windows.Forms.ComboBox
$combobox_LogType.Location = '685,10'
$combobox_LogType.Size = '170,45'
$combobox_LogType.DropDownStyle = 'DropDownList'
$combobox_LogType.Items.AddRange(@("Wszystkie", "Info", "Warn", "Error"))
$combobox_LogType.SelectedIndex = 0

# TextBox do filtrowania logów
$textbox_LogFilter = New-Object System.Windows.Forms.TextBox
$textbox_LogFilter.Location = '10,10'
$textbox_LogFilter.Width = 660
$textbox_LogFilter.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$textbox_LogFilter.PlaceholderText = "Filtruj logi..."

# RichTextBox do logów
$richtextbox_Logs = New-Object System.Windows.Forms.RichTextBox
$richtextbox_Logs.Location = '10,50'
$richtextbox_Logs.Size = '660,600'
$richtextbox_Logs.ReadOnly = $true
$richtextbox_Logs.BackColor = 'Black'
$richtextbox_Logs.ForeColor = 'Lime'
$richtextbox_Logs.Font = New-Object System.Drawing.Font("Consolas", 10)

# Panel z przyciskami logowania (po prawej)
$panel_LogButtons = New-Object System.Windows.Forms.FlowLayoutPanel
$panel_LogButtons.Location = '680,50'
$panel_LogButtons.Size = '190,600'
$panel_LogButtons.FlowDirection = 'TopDown'
$panel_LogButtons.WrapContents = $false
$panel_LogButtons.AutoScroll = $true

function New-LogActionButton($text) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Size = '170,45'
    $btn.Text = $text
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    return $btn
}

$buttons_Logs = @{
    ClearLog = New-LogActionButton "Wyczyść log"
    SaveLog  = New-LogActionButton "Zapisz log"
    CopyLog  = New-LogActionButton "Kopiuj wszystko"
}

$panel_LogButtons.Controls.AddRange($buttons_Logs.Values)

# Dodanie do głównego panelu
$panel_Logs.Controls.AddRange(@(
    $textbox_LogFilter,
    $combobox_LogType,
    $richtextbox_Logs,
    $panel_LogButtons
))

# Podłączenie do zakładki
$HT_UI.Tabs["Logi"].Controls.Clear()
$HT_UI.Tabs["Logi"].Controls.Add($panel_Logs)

# Eksport referencji
$global:HT_UI.LogsTab = @{
    Panel     = $panel_Logs
    TextBox   = $richtextbox_Logs
    Buttons   = $buttons_Logs
    FilterBox = $textbox_LogFilter
    FilterType = $combobox_LogType
}