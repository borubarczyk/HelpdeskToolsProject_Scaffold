# Panel główny dla zakładki "Intune"
$panel_Intune = New-Object System.Windows.Forms.Panel
$panel_Intune.Dock = 'Fill'

# ComboBox z urządzeniami
$combobox_DeviceList = New-Object System.Windows.Forms.ComboBox
$combobox_DeviceList.Location = '10,10'
$combobox_DeviceList.Width = 660
$combobox_DeviceList.DropDownStyle = 'DropDownList'
$combobox_DeviceList.Items.Add('Lista niezaładowana - kliknij "Odśwież"')
$combobox_DeviceList.SelectedIndex = 0

# RichTextBox z informacjami
$richtextbox_DeviceDetails = New-Object System.Windows.Forms.RichTextBox
$richtextbox_DeviceDetails.Location = '10,50'
$richtextbox_DeviceDetails.Size = '660,600'
$richtextbox_DeviceDetails.ReadOnly = $true

# Panel boczny z przyciskami
$panel_DeviceActions = New-Object System.Windows.Forms.FlowLayoutPanel
$panel_DeviceActions.Location = '680,50'
$panel_DeviceActions.Size = '190,700'
$panel_DeviceActions.FlowDirection = 'TopDown'
$panel_DeviceActions.WrapContents = $false
$panel_DeviceActions.AutoScroll = $true

function New-DeviceActionButton($text) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Size = '170,45'
    $btn.Text = $text
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    return $btn
}

$buttons_DeviceActions = @{
    Refresh         = New-DeviceActionButton "Odśwież"
    RenameDevice    = New-DeviceActionButton "Zmień nazwę"
    SetPrimaryUser  = New-DeviceActionButton "Zmień Primary User"
    DeviceInfo      = New-DeviceActionButton "Informacje o sprzęcie"
    AppList         = New-DeviceActionButton "Zainstalowane aplikacje"
    Memberships     = New-DeviceActionButton "Członkostwa grup"
    RecoveryKey     = New-DeviceActionButton "Klucz odzyskiwania"
    LAPS            = New-DeviceActionButton "LAPS"
}

$panel_DeviceActions.Controls.AddRange(@(
    $buttons_DeviceActions.Refresh,
    $buttons_DeviceActions.RenameDevice,
    $buttons_DeviceActions.SetPrimaryUser,
    $buttons_DeviceActions.DeviceInfo,
    $buttons_DeviceActions.AppList,
    $buttons_DeviceActions.Memberships,
    $buttons_DeviceActions.RecoveryKey,
    $buttons_DeviceActions.LAPS
))

# Dodaj wszystkie kontrolki do panelu głównego
$panel_Intune.Controls.AddRange(@(
    $combobox_DeviceList,
    $richtextbox_DeviceDetails,
    $panel_DeviceActions
))

# Dołącz panel do zakładki "Intune"
$HT_UI.Tabs["Intune"].Controls.Add($panel_Intune)

# Eksport referencji do globalnego słownika
$global:HT_UI.IntuneTab = [ordered]@{
    Panel      = $panel_Intune
    ComboBox   = $combobox_DeviceList
    DetailsBox = $richtextbox_DeviceDetails
    Actions    = $buttons_DeviceActions
}
