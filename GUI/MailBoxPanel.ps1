# Panel główny dla zakładki "Skrzynki"
$panel_Mailboxes = New-Object System.Windows.Forms.Panel
$panel_Mailboxes.Dock = 'Fill'

# ComboBox z listą skrzynek
$combobox_MailboxList = New-Object System.Windows.Forms.ComboBox
$combobox_MailboxList.Location = '10,10'
$combobox_MailboxList.Width = 660
$combobox_MailboxList.DropDownStyle = 'DropDownList'
$combobox_MailboxList.Items.Add('Lista niezaładowana - kliknij "Odśwież"')
$combobox_MailboxList.SelectedIndex = 0

# RichTextBox z informacjami o skrzynce
$richtextbox_MailboxDetails = New-Object System.Windows.Forms.RichTextBox
$richtextbox_MailboxDetails.Location = '10,50'
$richtextbox_MailboxDetails.Size = '660,600'
$richtextbox_MailboxDetails.ReadOnly = $true

# Panel boczny z przyciskami
$panel_MailboxActions = New-Object System.Windows.Forms.FlowLayoutPanel
$panel_MailboxActions.Location = '680,50'
$panel_MailboxActions.Size = '190,700'
$panel_MailboxActions.FlowDirection = 'TopDown'
$panel_MailboxActions.WrapContents = $false
$panel_MailboxActions.AutoScroll = $true

function New-MailboxActionButton($text) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Size = '170,45'
    $btn.Text = $text
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    return $btn
}

$buttons_MailboxActions = @{
    Refresh       = New-MailboxActionButton "Odśwież"
    CheckPerms    = New-MailboxActionButton "Sprawdź uprawnienia"
    GrantPerms    = New-MailboxActionButton "Nadaj uprawnienia"
    RemovePerms   = New-MailboxActionButton "Odbierz uprawnienia"
    Convert       = New-MailboxActionButton "Konwersja"
    Autoresponder = New-MailboxActionButton "Autoresponder"
    HideFromGAL   = New-MailboxActionButton "Ukryj z GAL"
    EnableArchive = New-MailboxActionButton "Włącz Archiwum"
    Forwards      = New-MailboxActionButton "Przekierowania"
    Advanced      = New-MailboxActionButton "Ustawienia zaawansowane"
}

$panel_MailboxActions.Controls.AddRange(@(
    $buttons_MailboxActions.Refresh,
    $buttons_MailboxActions.CheckPerms,
    $buttons_MailboxActions.GrantPerms,
    $buttons_MailboxActions.RemovePerms,
    $buttons_MailboxActions.Convert,
    $buttons_MailboxActions.Autoresponder,
    $buttons_MailboxActions.HideFromGAL,
    $buttons_MailboxActions.EnableArchive,
    $buttons_MailboxActions.Forwards,
    $buttons_MailboxActions.Advanced
))

# Dodaj wszystkie kontrolki do panelu głównego
$panel_Mailboxes.Controls.AddRange(@(
    $combobox_MailboxList,
    $richtextbox_MailboxDetails,
    $panel_MailboxActions
))

# Dołącz panel do zakładki "Skrzynki"
$HT_UI.Tabs["Skrzynki"].Controls.Add($panel_Mailboxes)

# Eksport referencji do globalnego słownika
$global:HT_UI.MailboxesTab = [ordered]@{
    Panel      = $panel_Mailboxes
    ComboBox   = $combobox_MailboxList
    DetailsBox = $richtextbox_MailboxDetails
    Actions    = $buttons_MailboxActions
}
