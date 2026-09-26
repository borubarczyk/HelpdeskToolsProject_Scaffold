# Panel główny dla zakładki "Użytkownicy" (Microsoft 365 / Entra ID)

$view_Users = New-HTSectionView -SearchPlaceholder "Szukaj po nazwie, UPN, dziale, licencji... (Esc - wyczyść)" -Columns @(
    @{ Text = "Nazwa"; Property = "DisplayName"; Width = 190 }
    @{ Text = "UPN"; Property = "UserPrincipalName"; Width = 230 }
    @{ Text = "Włączone"; Property = "AccountEnabled"; Width = 70 }
    @{ Text = "Dział"; Property = "Department"; Width = 120 }
    @{ Text = "Stanowisko"; Property = "JobTitle"; Width = 120 }
    @{ Text = "Licencje"; Property = "Licenses"; Width = 200 }
    @{ Text = "Typ"; Property = "UserType"; Width = 70 }
) -Actions @(
    @{ Group = "Konto" }
    @{ Key = "ResetPassword"; Text = "Reset hasła"; Icon = "Password Reset.png"; ToolTip = "Ustawia nowe hasło (z generatora lub własne)" }
    @{ Key = "ToggleBlock"; Text = "Zablokuj / odblokuj"; Icon = "Denied.png"; ToolTip = "Blokuje lub odblokowuje logowanie" }
    @{ Key = "RevokeSessions"; Text = "Unieważnij sesje"; Icon = "Restart.png"; ToolTip = "Wylogowuje użytkownika ze wszystkich sesji" }
    @{ Key = "ChangeMFA"; Text = "Metody MFA"; Icon = "Microsoft Authenticator.png"; ToolTip = "Przegląd, usuwanie i dodawanie metod uwierzytelniania, Temporary Access Pass" }
    @{ Key = "EditContact"; Text = "Dane kontaktowe"; Icon = "Info.png"; ToolTip = "Stanowisko, dział, telefony, adres" }
    @{ Group = "Dostęp" }
    @{ Key = "ChangeLicense"; Text = "Licencje"; Icon = "Software License.png"; ToolTip = "Przypisz lub usuń licencje" }
    @{ Key = "AddToGroup"; Text = "Dodaj do grupy"; Icon = "Add Male User Group.png" }
    @{ Key = "RemoveFromGroup"; Text = "Usuń z grupy"; Icon = "Minus.png" }
    @{ Group = "Powiązane" }
    @{ Key = "Mailbox"; Text = "Skrzynka"; Icon = "Email.png"; ToolTip = "Przejdź do skrzynki użytkownika (Exchange)" }
    @{ Key = "Devices"; Text = "Urządzenia"; Icon = "Multiple Devices.png"; ToolTip = "Urządzenia Intune i Entra ID użytkownika" }
    @{ Group = "Inne" }
    @{ Key = "NewUser"; Text = "Nowy użytkownik"; Icon = "add.png" }
    @{ Key = "Export"; Text = "Eksport listy (CSV)"; Icon = "CSV.png" }
)

# Dołącz panel do zakładki "Użytkownicy"
$HT_UI.Tabs["Użytkownicy"].Controls.Clear()
$HT_UI.Tabs["Użytkownicy"].Controls.Add($view_Users.Panel)

# Eksport referencji do globalnego słownika
$global:HT_UI.UsersTab = $view_Users
$HT_UI.RefreshButtons["Użytkownicy"] = $view_Users.RefreshButton
