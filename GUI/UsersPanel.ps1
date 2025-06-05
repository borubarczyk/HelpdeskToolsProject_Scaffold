
# Panel główny dla zakładki "Użytkownicy"
$panel_Users = New-Object System.Windows.Forms.Panel
$panel_Users.Dock = 'Fill'

# ComboBox z użytkownikami
$combobox_UsersList = New-Object System.Windows.Forms.ComboBox
$combobox_UsersList.Location = '10,10'
$combobox_UsersList.Width = 660
$combobox_UsersList.DropDownStyle = 'DropDownList'
$combobox_UsersList.Items.Add('Lista niezaładowana - kliknij "Odśwież"')
$combobox_UsersList.SelectedIndex = 0

# RichTextBox z informacjami
$richtextbox_UserDetails = New-Object System.Windows.Forms.RichTextBox
$richtextbox_UserDetails.Location = '10,50'
$richtextbox_UserDetails.Size = '660,600'
$richtextbox_UserDetails.ReadOnly = $true

# Panel boczny z przyciskami
$panel_UserActions = New-Object System.Windows.Forms.FlowLayoutPanel
$panel_UserActions.Location = '680,50'
$panel_UserActions.Size = '190,700'
$panel_UserActions.FlowDirection = 'TopDown'
$panel_UserActions.WrapContents = $false
$panel_UserActions.AutoScroll = $true

function New-UserActionButton($text) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Size = '170,45'
    $btn.Text = $text
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    return $btn
}

$buttons_UserActions = @{
    Refresh        = New-UserActionButton "Odśwież"
    ResetPassword  = New-UserActionButton "Reset hasła"
    ToggleBlock    = New-UserActionButton "Zablokuj/Odblokuj"
    ChangeLicense  = New-UserActionButton "Zmień licencję"
    AddToGroup     = New-UserActionButton "Dodaj do grupy"
    RemoveFromGroup= New-UserActionButton "Usuń z grupy"
    ChangeMFA      = New-UserActionButton "Zmień MFA"
    EditContact    = New-UserActionButton "Zmień dane kotnatkowe"
    Mailbox        = New-UserActionButton "Skrzynka"
    Devices        = New-UserActionButton "Urządzenia"
}

$panel_UserActions.Controls.AddRange(@(
    $buttons_UserActions.Refresh,
    $buttons_UserActions.ResetPassword,
    $buttons_UserActions.ToggleBlock,
    $buttons_UserActions.ChangeLicense,
    $buttons_UserActions.AddToGroup,
    $buttons_UserActions.RemoveFromGroup,
    $buttons_UserActions.ChangeMFA,
    $buttons_UserActions.EditContact,
    $buttons_UserActions.Mailbox,
    $buttons_UserActions.Devices
))


# Dodaj wszystkie kontrolki do panelu głównego
$panel_Users.Controls.AddRange(@(
    $combobox_UsersList,
    $richtextbox_UserDetails,
    $panel_UserActions
))

# Dołącz panel do zakładki "Użytkownicy"
$HT_UI.Tabs["Użytkownicy"].Controls.Add($panel_Users)

# Eksport referencji do globalnego słownika
$global:HT_UI.UsersTab = [ordered]@{
    Panel      = $panel_Users
    ComboBox   = $combobox_UsersList
    DetailsBox = $richtextbox_UserDetails
    Actions    = $buttons_UserActions
}
