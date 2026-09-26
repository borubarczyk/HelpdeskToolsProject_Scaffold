# Panel "Lokalne AD": użytkownicy, komputery i grupy (przełączane listą rozwijaną)

# ComboBox do wyboru sekcji (Użytkownicy, Komputery, Grupy)
$combobox_LocalAD_Section = New-Object System.Windows.Forms.ComboBox
$combobox_LocalAD_Section.Width = 150
$combobox_LocalAD_Section.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$combobox_LocalAD_Section.Items.AddRange(@("Użytkownicy", "Komputery", "Grupy"))

# Kolumny listy dla każdej sekcji
$LocalAD_Columns = @{
    "Użytkownicy" = @(
        @{ Text = "Nazwa"; Property = "Name"; Width = 180 }
        @{ Text = "Login"; Property = "SamAccountName"; Width = 120 }
        @{ Text = "UPN"; Property = "UserPrincipalName"; Width = 220 }
        @{ Text = "Włączone"; Property = "Enabled"; Width = 70 }
        @{ Text = "Zablokowane"; Property = "LockedOut"; Width = 85 }
        @{ Text = "Dział"; Property = "Department"; Width = 120 }
        @{ Text = "Ostatnie logowanie"; Property = "LastLogonDate"; Width = 130 }
    )
    "Komputery"   = @(
        @{ Text = "Nazwa"; Property = "Name"; Width = 160 }
        @{ Text = "System"; Property = "OperatingSystem"; Width = 210 }
        @{ Text = "Włączone"; Property = "Enabled"; Width = 70 }
        @{ Text = "Ostatnie logowanie"; Property = "LastLogonDate"; Width = 130 }
        @{ Text = "Opis"; Property = "Description"; Width = 200 }
        @{ Text = "DNS"; Property = "DNSHostName"; Width = 200 }
    )
    "Grupy"       = @(
        @{ Text = "Nazwa"; Property = "Name"; Width = 220 }
        @{ Text = "Typ"; Property = "GroupCategory"; Width = 100 }
        @{ Text = "Zakres"; Property = "GroupScope"; Width = 100 }
        @{ Text = "Opis"; Property = "Description"; Width = 320 }
    )
}

# Zestawy akcji dla każdej sekcji
$LocalAD_ActionSets = [ordered]@{
    "Użytkownicy" = @(
        @{ Group = "Konto" }
        @{ Key = "ResetPassword"; Text = "Resetuj hasło"; Icon = "Password Reset.png" }
        @{ Key = "LockUnlock"; Text = "Włącz / wyłącz / odblokuj"; Icon = "Denied.png" }
        @{ Key = "EditAttributes"; Text = "Edytuj dane"; Icon = "Writer male_1.png" }
        @{ Key = "AssignProfile"; Text = "Profil i katalog domowy"; Icon = "Opened Folder.png" }
        @{ Key = "Special"; Text = "Akcje specjalne"; Icon = "Screwdriver.png" }
        @{ Group = "Organizacja" }
        @{ Key = "ChangeGroups"; Text = "Zmień grupy"; Icon = "Add Male User Group.png" }
        @{ Key = "MoveOU"; Text = "Przenieś do OU"; Icon = "Organization.png" }
        @{ Group = "Inne" }
        @{ Key = "NewUser"; Text = "Nowy użytkownik"; Icon = "add.png" }
        @{ Key = "Export"; Text = "Eksport listy (CSV)"; Icon = "CSV.png" }
        @{ Key = "Delete"; Text = "Usuń konto"; Icon = "Remove.png"; Style = "Danger" }
    )
    "Komputery"   = @(
        @{ Group = "Diagnostyka" }
        @{ Key = "Ping"; Text = "Test połączenia"; Icon = "validation.png" }
        @{ Key = "Restart"; Text = "Zrestartuj"; Icon = "Restart.png" }
        @{ Group = "Konto" }
        @{ Key = "ToggleEnabled"; Text = "Włącz / wyłącz konto"; Icon = "Denied.png" }
        @{ Key = "EditDescription"; Text = "Zmień opis"; Icon = "Rename.png" }
        @{ Key = "Groups"; Text = "Zmień grupy"; Icon = "User Groups.png" }
        @{ Key = "MoveOU"; Text = "Przenieś do OU"; Icon = "Organization.png" }
        @{ Group = "Bezpieczeństwo" }
        @{ Key = "LAPS"; Text = "Hasło LAPS"; Icon = "Key Security.png" }
        @{ Key = "BitLocker"; Text = "Klucze BitLocker"; Icon = "Secure.png" }
        @{ Group = "Inne" }
        @{ Key = "Export"; Text = "Eksport listy (CSV)"; Icon = "CSV.png" }
        @{ Key = "Delete"; Text = "Usuń konto"; Icon = "Remove.png"; Style = "Danger" }
    )
    "Grupy"       = @(
        @{ Group = "Członkowie" }
        @{ Key = "AddMembers"; Text = "Dodaj członków"; Icon = "Add Male User Group.png" }
        @{ Key = "RemoveMembers"; Text = "Usuń członków"; Icon = "Minus.png" }
        @{ Key = "ExportMembers"; Text = "Eksport członków"; Icon = "CSV.png" }
        @{ Group = "Ustawienia" }
        @{ Key = "Rename"; Text = "Zmień nazwę"; Icon = "Rename.png" }
        @{ Key = "ChangeType"; Text = "Zmień typ grupy"; Icon = "Admin Settings Male.png" }
        @{ Key = "ChangeScope"; Text = "Zmień zakres"; Icon = "Group Objects.png" }
        @{ Key = "MoveOU"; Text = "Przenieś do OU"; Icon = "Organization.png" }
        @{ Group = "Inne" }
        @{ Key = "NewGroup"; Text = "Nowa grupa"; Icon = "add.png" }
        @{ Key = "Export"; Text = "Eksport listy (CSV)"; Icon = "CSV.png" }
        @{ Key = "Delete"; Text = "Usuń grupę"; Icon = "Remove.png"; Style = "Danger" }
    )
}

$view_LocalAD = New-HTSectionView -ToolbarControls @($combobox_LocalAD_Section) -Columns $LocalAD_Columns["Użytkownicy"] -Actions $LocalAD_ActionSets["Użytkownicy"]

# Dodatkowe panele akcji dla komputerów i grup (widoczny jest tylko panel bieżącej sekcji)
$LocalAD_ActionPanels = @{
    "Użytkownicy" = @{ Panel = $view_LocalAD.ActionPanel; Buttons = $view_LocalAD.Actions }
}
foreach ($section in @("Komputery", "Grupy")) {
    $actionPanel = New-HTActionPanel -Actions $LocalAD_ActionSets[$section]
    $actionPanel.Panel.Visible = $false
    $view_LocalAD.Panel.Controls.Add($actionPanel.Panel)
    $LocalAD_ActionPanels[$section] = $actionPanel
}
$view_LocalAD.ToolbarHost.SendToBack()
$view_LocalAD.Split.BringToFront()

# Pokazuje panel akcji i kolumny wybranej sekcji
function Show-LocalADButtons {
    $selected = $HT_UI.LocalADTab.SectionBox.SelectedItem
    if (-not $selected) { return }
    foreach ($section in $HT_UI.LocalADTab.ActionPanels.Keys) {
        $HT_UI.LocalADTab.ActionPanels[$section].Panel.Visible = ($section -eq $selected)
    }
}

# Dołącz panel do zakładki
$HT_UI.Tabs["Lokalne AD"].Controls.Clear()
$HT_UI.Tabs["Lokalne AD"].Controls.Add($view_LocalAD.Panel)

# Globalna struktura UI
$view_LocalAD.SectionBox = $combobox_LocalAD_Section
$view_LocalAD.ActionPanels = $LocalAD_ActionPanels
$view_LocalAD.ColumnSets = $LocalAD_Columns
$view_LocalAD.Loaded = @{}
$global:HT_UI.LocalADTab = $view_LocalAD
$HT_UI.RefreshButtons["Lokalne AD"] = $view_LocalAD.RefreshButton

# Ustawienie domyślnej sekcji
$combobox_LocalAD_Section.SelectedIndex = 0
Show-LocalADButtons
