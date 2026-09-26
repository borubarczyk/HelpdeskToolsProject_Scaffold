# Panel główny dla zakładki "Intune"

# Filtr systemu operacyjnego
$combobox_DeviceOS = New-Object System.Windows.Forms.ComboBox
$combobox_DeviceOS.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$combobox_DeviceOS.Width = 150
$combobox_DeviceOS.Items.AddRange(@("Wszystkie systemy", "Windows", "iOS", "Android", "macOS"))
$combobox_DeviceOS.SelectedIndex = 0

$view_Intune = New-HTSectionView -ToolbarControls @($combobox_DeviceOS) -SearchPlaceholder "Szukaj po nazwie, użytkowniku, numerze seryjnym... (Esc - wyczyść)" -Columns @(
    @{ Text = "Nazwa"; Property = "DeviceName"; Width = 160 }
    @{ Text = "Użytkownik"; Property = "UserPrincipalName"; Width = 210 }
    @{ Text = "System"; Property = "OperatingSystem"; Width = 80 }
    @{ Text = "Wersja"; Property = "OsVersion"; Width = 110 }
    @{ Text = "Zgodność"; Property = "ComplianceState"; Width = 95 }
    @{ Text = "Ostatnia synchr."; Property = "LastSync"; Width = 125 }
    @{ Text = "Nr seryjny"; Property = "SerialNumber"; Width = 120 }
    @{ Text = "Model"; Property = "Model"; Width = 140 }
) -Actions @(
    @{ Group = "Zarządzanie" }
    @{ Key = "RenameDevice"; Text = "Zmień nazwę"; Icon = "Rename.png"; ToolTip = "Windows: wymaga ponownego uruchomienia urządzenia" }
    @{ Key = "SetPrimaryUser"; Text = "Zmień Primary User"; Icon = "Change User.png" }
    @{ Key = "Sync"; Text = "Synchronizuj"; Icon = "update-left-rotation.png" }
    @{ Key = "Restart"; Text = "Uruchom ponownie"; Icon = "Restart.png" }
    @{ Group = "Informacje" }
    @{ Key = "DeviceInfo"; Text = "Informacje o sprzęcie"; Icon = "Info.png" }
    @{ Key = "AppList"; Text = "Zainstalowane aplikacje"; Icon = "Software.png" }
    @{ Key = "Memberships"; Text = "Członkostwa grup"; Icon = "User Groups.png" }
    @{ Group = "Bezpieczeństwo" }
    @{ Key = "RecoveryKey"; Text = "Klucz BitLocker"; Icon = "Secure.png" }
    @{ Key = "LAPS"; Text = "Hasło LAPS"; Icon = "Key Security.png" }
    @{ Group = "Inne" }
    @{ Key = "Export"; Text = "Eksport listy (CSV)"; Icon = "CSV.png" }
)

# Dołącz panel do zakładki "Intune"
$HT_UI.Tabs["Intune"].Controls.Clear()
$HT_UI.Tabs["Intune"].Controls.Add($view_Intune.Panel)

# Eksport referencji do globalnego słownika
$view_Intune.OSFilter = $combobox_DeviceOS
$view_Intune.AllData = @()
$global:HT_UI.IntuneTab = $view_Intune
$HT_UI.RefreshButtons["Intune"] = $view_Intune.RefreshButton
