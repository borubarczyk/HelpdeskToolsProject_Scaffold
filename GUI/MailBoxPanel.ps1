# Panel główny dla zakładki "Skrzynki" (Exchange Online)

# Filtr typu skrzynki
$combobox_MailboxType = New-Object System.Windows.Forms.ComboBox
$combobox_MailboxType.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$combobox_MailboxType.Width = 170
$combobox_MailboxType.Items.AddRange(@("Wszystkie typy", "UserMailbox", "SharedMailbox", "RoomMailbox", "EquipmentMailbox"))
$combobox_MailboxType.SelectedIndex = 0

$view_Mailboxes = New-HTSectionView -ToolbarControls @($combobox_MailboxType) -SearchPlaceholder "Szukaj po nazwie lub adresie... (Esc - wyczyść)" -Columns @(
    @{ Text = "Nazwa"; Property = "DisplayName"; Width = 190 }
    @{ Text = "Adres"; Property = "PrimarySmtpAddress"; Width = 230 }
    @{ Text = "Typ"; Property = "RecipientTypeDetails"; Width = 120 }
    @{ Text = "Ukryta w GAL"; Property = "HiddenFromGAL"; Width = 90 }
    @{ Text = "Archiwum"; Property = "Archive"; Width = 75 }
    @{ Text = "Przekierowanie"; Property = "Forwarding"; Width = 180 }
) -Actions @(
    @{ Group = "Uprawnienia" }
    @{ Key = "CheckPerms"; Text = "Sprawdź uprawnienia"; Icon = "Eye open.png"; ToolTip = "FullAccess, SendAs i SendOnBehalf" }
    @{ Key = "GrantPerms"; Text = "Nadaj uprawnienia"; Icon = "Add Male User Group.png" }
    @{ Key = "RemovePerms"; Text = "Odbierz uprawnienia"; Icon = "Minus.png" }
    @{ Key = "Calendar"; Text = "Uprawnienia kalendarza"; Icon = "User Groups.png" }
    @{ Group = "Ustawienia" }
    @{ Key = "Convert"; Text = "Konwersja typu"; Icon = "Process.png"; ToolTip = "Użytkownika / współdzielona / sala / sprzęt" }
    @{ Key = "Autoresponder"; Text = "Autoodpowiedź"; Icon = "reply.png" }
    @{ Key = "Forwards"; Text = "Przekierowanie"; Icon = "forward-message.png" }
    @{ Key = "HideFromGAL"; Text = "Ukryj / pokaż w GAL"; Icon = "hide-item.png" }
    @{ Key = "EnableArchive"; Text = "Włącz archiwum"; Icon = "shared-mail.png" }
    @{ Group = "Diagnostyka" }
    @{ Key = "InboxRules"; Text = "Reguły skrzynki"; Icon = "administrative-tools.png" }
    @{ Key = "MessageTrace"; Text = "Śledzenie wiadomości"; Icon = "send-mail.png" }
    @{ Key = "MobileDevices"; Text = "Urządzenia mobilne"; Icon = "Multiple Devices.png" }
    @{ Key = "Export"; Text = "Eksport listy (CSV)"; Icon = "CSV.png" }
)

# Dołącz panel do zakładki "Skrzynki"
$HT_UI.Tabs["Skrzynki"].Controls.Clear()
$HT_UI.Tabs["Skrzynki"].Controls.Add($view_Mailboxes.Panel)

# Eksport referencji do globalnego słownika
$view_Mailboxes.TypeFilter = $combobox_MailboxType
$view_Mailboxes.AllData = @()
$global:HT_UI.MailboxesTab = $view_Mailboxes
$HT_UI.RefreshButtons["Skrzynki"] = $view_Mailboxes.RefreshButton
