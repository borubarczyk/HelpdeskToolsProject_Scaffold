# Zakładka "Użytkownicy" (Microsoft 365) - obsługa zdarzeń

# Zaznaczony użytkownik (wymaga połączenia z Graph)
function Get-HTSelectedM365User {
    if (-not (Assert-HTConnection -Service "Graph")) { return $null }
    return Get-HTSelectedObject -View $HT_UI.UsersTab -What "użytkownika"
}

# Odświeżenie listy użytkowników
function Update-HTUsersList {
    Invoke-HTAction -Name "Pobieranie użytkowników" -RequiredService "Graph" -ScriptBlock {
        $users = Get-HTM365Users
        Set-HTListData -ListView $HT_UI.UsersTab.List -Data $users
        Set-HTDetails -ListView $HT_UI.UsersTab.Details -Data $null -Message "Wybierz użytkownika z listy, aby zobaczyć szczegóły."
        Write-Log -Message "Załadowano użytkowników M365: $($users.Count)" -Type "Info"
    }
}

$HT_UI.UsersTab.RefreshButton.Add_Click({ Update-HTUsersList })

# Szczegóły zaznaczonego użytkownika
Register-HTDetailsLoader -View $HT_UI.UsersTab -Loader {
    param($user)
    Get-HTM365UserDetail -Id $user.Id
}

# Reset hasła
$HT_UI.UsersTab.Actions.ResetPassword.Add_Click({
        $user = Get-HTSelectedM365User
        if (-not $user) { return }

        $generated = New-Password -Length $Global:PasswordDefaultLength -StartWithLetter $true -NoSimilarChars $true
        $form = Show-HTFormDialog -Title "Reset hasła" -Description "Użytkownik: $($user.DisplayName) <$($user.UserPrincipalName)>" -OkText "Resetuj hasło" -Fields @(
            @{ Name = "Password"; Label = "Nowe hasło"; Default = $generated; Required = $true }
            @{ Name = "ForceChange"; Label = "Wymagaj zmiany hasła przy następnym logowaniu"; Type = "Check"; Default = $true }
            @{ Name = "Revoke"; Label = "Unieważnij aktywne sesje użytkownika"; Type = "Check"; Default = $false }
        )
        if (-not $form) { return }

        Invoke-HTAction -Name "Reset hasła" -RequiredService "Graph" -ScriptBlock {
            Reset-HTM365UserPassword -Id $user.Id -Password $form.Password -ForceChange $form.ForceChange
            if ($form.Revoke) { Revoke-HTM365UserSessions -Id $user.Id }
            Write-Log -Message "Zresetowano hasło użytkownika $($user.UserPrincipalName)" -Type "Info&Notification"
            Show-HTSecretDialog -Title "Nowe hasło" -Items @(
                @{ Label = "Użytkownik"; Value = $user.UserPrincipalName }
                @{ Label = "Hasło"; Value = $form.Password }
            )
        }
    })

# Blokada / odblokowanie logowania
$HT_UI.UsersTab.Actions.ToggleBlock.Add_Click({
        $user = Get-HTSelectedM365User
        if (-not $user) { return }

        $enable = -not $user.AccountEnabled
        $message = if ($enable) { "Odblokować logowanie dla użytkownika $($user.DisplayName)?" }
        else { "Zablokować logowanie dla użytkownika $($user.DisplayName)?`nAktywne sesje zostaną unieważnione." }
        if (-not (Show-HTConfirm -Message $message -Title "Blokada konta" -Warning:(-not $enable))) { return }

        Invoke-HTAction -Name "Zmiana blokady konta" -RequiredService "Graph" -ScriptBlock {
            Set-HTM365UserEnabled -Id $user.Id -Enabled $enable -RevokeSessions (-not $enable)
            $user.AccountEnabled = $enable
            $state = if ($enable) { "odblokowane" } else { "zablokowane" }
            Write-Log -Message "Logowanie użytkownika $($user.UserPrincipalName): $state" -Type "Info&Notification"
            Invoke-HTDetailsReload -View $HT_UI.UsersTab
        }
    })

# Unieważnienie sesji
$HT_UI.UsersTab.Actions.RevokeSessions.Add_Click({
        $user = Get-HTSelectedM365User
        if (-not $user) { return }
        if (-not (Show-HTConfirm -Message "Unieważnić wszystkie sesje użytkownika $($user.DisplayName)?`nUżytkownik zostanie wylogowany ze wszystkich aplikacji i urządzeń." -Title "Unieważnienie sesji")) { return }

        Invoke-HTAction -Name "Unieważnianie sesji" -RequiredService "Graph" -ScriptBlock {
            Revoke-HTM365UserSessions -Id $user.Id
            Write-Log -Message "Unieważniono sesje użytkownika $($user.UserPrincipalName)" -Type "Info&Notification"
        }
    })

# Metody MFA
$HT_UI.UsersTab.Actions.ChangeMFA.Add_Click({
        $user = Get-HTSelectedM365User
        if (-not $user) { return }

        $methods = @(Invoke-HTAction -Name "Pobieranie metod MFA" -RequiredService "Graph" -ScriptBlock { Get-HTM365AuthMethods -Id $user.Id })
        $summary = if ($methods.Count -gt 0) { ($methods | ForEach-Object { "• $($_.Type) $(if ($_.Detail) { "($($_.Detail))" })" }) -join "`n" } else { "(brak metod)" }

        $choice = Show-HTChoiceDialog -Title "Metody MFA - $($user.DisplayName)" -Prompt "Zarejestrowane metody:`n$summary" -Choices @(
            @{ Key = "View"; Text = "Pokaż szczegóły metod"; Icon = "Eye open.png" }
            @{ Key = "Remove"; Text = "Usuń wybrane metody"; Icon = "Remove.png" }
            @{ Key = "ResetAll"; Text = "Wymuś ponowną rejestrację MFA"; Icon = "Restart.png"; Style = "Danger"; Description = "Usuwa wszystkie metody poza hasłem" }
            @{ Key = "AddPhone"; Text = "Dodaj numer telefonu"; Icon = "add.png" }
            @{ Key = "TAP"; Text = "Wygeneruj Temporary Access Pass"; Icon = "one-time-password.png"; Description = "Jednorazowy kod do zalogowania i rejestracji nowych metod" }
        )

        switch ($choice) {
            "View" {
                Show-HTDataViewer -Title "Metody MFA - $($user.DisplayName)" -Data $methods -ExportName "MFA_$($user.UserPrincipalName)" -Columns @(
                    @{ Text = "Metoda"; Property = "Type"; Width = 220 }
                    @{ Text = "Szczegóły"; Property = "Detail"; Width = 260 }
                    @{ Text = "Utworzono"; Property = "Created"; Width = 150 }
                    @{ Text = "Można usunąć"; Property = "Removable"; Width = 100 }
                )
            }
            "Remove" {
                $selected = Show-HTSelectionDialog -Title "Usuń metody MFA" -MultiSelect -OkText "Usuń" -Items @($methods | Where-Object { $_.Removable }) -Columns @(
                    @{ Text = "Metoda"; Property = "Type"; Width = 240 }
                    @{ Text = "Szczegóły"; Property = "Detail"; Width = 300 }
                )
                if (-not $selected) { return }
                if (-not (Show-HTConfirm -Message "Usunąć $(@($selected).Count) metod(y) uwierzytelniania?" -Title "Usuń metody MFA" -Warning)) { return }
                Invoke-HTAction -Name "Usuwanie metod MFA" -RequiredService "Graph" -ScriptBlock {
                    $ok = Invoke-HTForEach -Items @($selected) -Action { param($m) Remove-HTM365AuthMethod -UserId $user.Id -Method $m } -Describe { param($m) $m.Type }
                    Write-Log -Message "Usunięto metody MFA ($ok) użytkownika $($user.UserPrincipalName)" -Type "Info&Notification"
                    Invoke-HTDetailsReload -View $HT_UI.UsersTab
                }
            }
            "ResetAll" {
                $removable = @($methods | Where-Object { $_.Removable })
                if ($removable.Count -eq 0) { Show-Dialog -Message "Brak metod do usunięcia." -Title "MFA" | Out-Null; return }
                if (-not (Show-HTConfirm -Message "Usunąć WSZYSTKIE metody MFA użytkownika $($user.DisplayName) ($($removable.Count))?`nPrzy następnym logowaniu użytkownik będzie musiał ponownie zarejestrować MFA." -Title "Reset MFA" -Warning)) { return }
                Invoke-HTAction -Name "Reset MFA" -RequiredService "Graph" -ScriptBlock {
                    # Metoda domyślna może być usunięta dopiero jako ostatnia - kolejność: pozostałe, potem Authenticator
                    $ordered = @($removable | Sort-Object { $_.Type -eq "Microsoft Authenticator" })
                    $ok = Invoke-HTForEach -Items $ordered -Action { param($m) Remove-HTM365AuthMethod -UserId $user.Id -Method $m } -Describe { param($m) $m.Type }
                    Revoke-HTM365UserSessions -Id $user.Id
                    Write-Log -Message "Reset MFA użytkownika $($user.UserPrincipalName): usunięto $ok metod, unieważniono sesje." -Type "Info&Notification"
                    Invoke-HTDetailsReload -View $HT_UI.UsersTab
                }
            }
            "AddPhone" {
                $phone = Show-InputBox -Prompt "Numer telefonu komórkowego (np. +48 600 100 200):" -Title "Dodaj telefon MFA" -ValidationType "Phone"
                if (-not $phone) { return }
                Invoke-HTAction -Name "Dodawanie telefonu MFA" -RequiredService "Graph" -ScriptBlock {
                    $number = Add-HTM365PhoneMethod -UserId $user.Id -PhoneNumber $phone
                    Write-Log -Message "Dodano telefon MFA $number dla $($user.UserPrincipalName)" -Type "Info&Notification"
                    Invoke-HTDetailsReload -View $HT_UI.UsersTab
                }
            }
            "TAP" {
                $form = Show-HTFormDialog -Title "Temporary Access Pass" -Description "Użytkownik: $($user.UserPrincipalName)" -OkText "Wygeneruj" -Fields @(
                    @{ Name = "Lifetime"; Label = "Ważność (minuty)"; Type = "Number"; Default = 60; Min = 10; Max = 480 }
                    @{ Name = "Once"; Label = "Kod jednorazowy"; Type = "Check"; Default = $true }
                )
                if (-not $form) { return }
                Invoke-HTAction -Name "Generowanie TAP" -RequiredService "Graph" -ScriptBlock {
                    $tap = New-HTM365TemporaryAccessPass -UserId $user.Id -LifetimeInMinutes $form.Lifetime -IsUsableOnce $form.Once
                    Write-Log -Message "Wygenerowano Temporary Access Pass dla $($user.UserPrincipalName) (ważny $($form.Lifetime) min)" -Type "Info"
                    Show-HTSecretDialog -Title "Temporary Access Pass" -Items @(
                        @{ Label = "Użytkownik"; Value = $user.UserPrincipalName }
                        @{ Label = "Kod TAP"; Value = $tap.temporaryAccessPass }
                        @{ Label = "Ważny od"; Value = (ConvertTo-HTDisplayValue $tap.startDateTime) }
                        @{ Label = "Ważność (min)"; Value = $tap.lifetimeInMinutes }
                    )
                }
            }
        }
    })

# Dane kontaktowe
$HT_UI.UsersTab.Actions.EditContact.Add_Click({
        $user = Get-HTSelectedM365User
        if (-not $user) { return }

        $current = Invoke-HTAction -Name "Pobieranie danych kontaktowych" -RequiredService "Graph" -ScriptBlock {
            Invoke-HTGraphRequest -Uri "users/$($user.Id)?`$select=displayName,givenName,surname,jobTitle,department,companyName,officeLocation,mobilePhone,businessPhones,streetAddress,city,postalCode,country,usageLocation,employeeId,onPremisesSyncEnabled"
        }
        if (-not $current) { return }

        $fields = @(
            @{ Name = "displayName"; Label = "Nazwa wyświetlana"; Default = $current.displayName; Required = $true }
            @{ Name = "givenName"; Label = "Imię"; Default = $current.givenName }
            @{ Name = "surname"; Label = "Nazwisko"; Default = $current.surname }
            @{ Name = "jobTitle"; Label = "Stanowisko"; Default = $current.jobTitle }
            @{ Name = "department"; Label = "Dział"; Default = $current.department }
            @{ Name = "companyName"; Label = "Firma"; Default = $current.companyName }
            @{ Name = "officeLocation"; Label = "Biuro"; Default = $current.officeLocation }
            @{ Name = "mobilePhone"; Label = "Telefon komórkowy"; Default = $current.mobilePhone; Validation = "Phone" }
            @{ Name = "businessPhones"; Label = "Telefon służbowy"; Default = (@($current.businessPhones) | Select-Object -First 1); Validation = "Phone" }
            @{ Name = "streetAddress"; Label = "Ulica"; Default = $current.streetAddress }
            @{ Name = "postalCode"; Label = "Kod pocztowy"; Default = $current.postalCode }
            @{ Name = "city"; Label = "Miasto"; Default = $current.city }
            @{ Name = "country"; Label = "Kraj"; Default = $current.country }
            @{ Name = "usageLocation"; Label = "Lokalizacja użycia (kod kraju)"; Default = $current.usageLocation }
            @{ Name = "employeeId"; Label = "ID pracownika"; Default = $current.employeeId }
        )
        $description = if ($current.onPremisesSyncEnabled) { "Uwaga: konto synchronizowane z lokalnym AD - większość pól należy zmieniać w AD." } else { "Użytkownik: $($user.UserPrincipalName)" }
        $form = Show-HTFormDialog -Title "Dane kontaktowe - $($user.DisplayName)" -Description $description -Fields $fields
        if (-not $form) { return }

        $changes = @{}
        foreach ($field in $fields) {
            $old = "$($field.Default)"
            $new = "$($form[$field.Name])"
            if ($old -ne $new) {
                $changes[$field.Name] = if ($field.Name -eq "businessPhones") { @($new) } else { $new }
            }
        }
        if ($changes.Count -eq 0) { Set-HTStatus -Text "Brak zmian."; return }

        Invoke-HTAction -Name "Zapis danych kontaktowych" -RequiredService "Graph" -ScriptBlock {
            Set-HTM365UserContact -Id $user.Id -Properties $changes
            if ($changes.ContainsKey("displayName")) { $user.DisplayName = $changes.displayName }
            if ($changes.ContainsKey("jobTitle")) { $user.JobTitle = $changes.jobTitle }
            if ($changes.ContainsKey("department")) { $user.Department = $changes.department }
            Write-Log -Message "Zaktualizowano dane użytkownika $($user.UserPrincipalName): $($changes.Keys -join ', ')" -Type "Info&Notification"
            Invoke-HTDetailsReload -View $HT_UI.UsersTab
        }
    })

# Licencje
$HT_UI.UsersTab.Actions.ChangeLicense.Add_Click({
        $user = Get-HTSelectedM365User
        if (-not $user) { return }

        $data = Invoke-HTAction -Name "Pobieranie licencji" -RequiredService "Graph" -ScriptBlock {
            @{
                Skus     = @(Get-HTSubscribedSkus -Force)
                Assigned = @(Get-HTM365UserLicenses -Id $user.Id)
            }
        }
        if (-not $data) { return }

        $assignedText = if ($data.Assigned.Count -gt 0) { ($data.Assigned | ForEach-Object { "• $($_.SkuPartNumber)" }) -join "`n" } else { "(brak)" }
        $choice = Show-HTChoiceDialog -Title "Licencje - $($user.DisplayName)" -Prompt "Przypisane licencje:`n$assignedText" -Choices @(
            @{ Key = "Add"; Text = "Przypisz licencje"; Icon = "add.png" }
            @{ Key = "Remove"; Text = "Usuń licencje"; Icon = "Remove.png" }
            @{ Key = "Overview"; Text = "Przegląd licencji w tenancie"; Icon = "Software License.png" }
        )

        $skuColumns = @(
            @{ Text = "Licencja"; Property = "SkuPartNumber"; Width = 260 }
            @{ Text = "Wolne"; Property = "Available"; Width = 70 }
            @{ Text = "Przypisane"; Property = "Consumed"; Width = 80 }
            @{ Text = "Zakupione"; Property = "Enabled"; Width = 80 }
        )

        switch ($choice) {
            "Add" {
                $assignedIds = @($data.Assigned | ForEach-Object { "$($_.SkuId)" })
                $candidates = @($data.Skus | Where-Object { $assignedIds -notcontains "$($_.SkuId)" -and $_.Enabled -gt 0 })
                $selected = Show-HTSelectionDialog -Title "Przypisz licencje" -MultiSelect -OkText "Przypisz" -Items $candidates -Columns $skuColumns
                if (-not $selected) { return }
                Invoke-HTAction -Name "Przypisywanie licencji" -RequiredService "Graph" -ScriptBlock {
                    Set-HTM365UserLicense -Id $user.Id -AddSkuIds @($selected | ForEach-Object { "$($_.SkuId)" })
                    Write-Log -Message "Przypisano licencje $((@($selected) | ForEach-Object { $_.SkuPartNumber }) -join ', ') dla $($user.UserPrincipalName)" -Type "Info&Notification"
                    Invoke-HTDetailsReload -View $HT_UI.UsersTab
                }
            }
            "Remove" {
                $selected = Show-HTSelectionDialog -Title "Usuń licencje" -MultiSelect -OkText "Usuń" -Items $data.Assigned -Columns @(@{ Text = "Licencja"; Property = "SkuPartNumber"; Width = 400 })
                if (-not $selected) { return }
                if (-not (Show-HTConfirm -Message "Usunąć wybrane licencje ($(@($selected).Count))?`nDane usług (np. skrzynka) mogą zostać usunięte po okresie przejściowym." -Title "Usuń licencje" -Warning)) { return }
                Invoke-HTAction -Name "Usuwanie licencji" -RequiredService "Graph" -ScriptBlock {
                    Set-HTM365UserLicense -Id $user.Id -RemoveSkuIds @($selected | ForEach-Object { "$($_.SkuId)" })
                    Write-Log -Message "Usunięto licencje $((@($selected) | ForEach-Object { $_.SkuPartNumber }) -join ', ') użytkownikowi $($user.UserPrincipalName)" -Type "Info&Notification"
                    Invoke-HTDetailsReload -View $HT_UI.UsersTab
                }
            }
            "Overview" {
                Show-HTDataViewer -Title "Licencje w tenancie" -Data $data.Skus -Columns $skuColumns -ExportName "Licencje"
            }
        }
    })

# Dodanie do grup
$HT_UI.UsersTab.Actions.AddToGroup.Add_Click({
        $user = Get-HTSelectedM365User
        if (-not $user) { return }

        $data = Invoke-HTAction -Name "Pobieranie grup" -RequiredService "Graph" -ScriptBlock {
            @{
                All     = @(Get-HTM365Groups)
                Current = @(Get-HTM365UserGroups -Id $user.Id | ForEach-Object { $_.Id })
            }
        }
        if (-not $data) { return }

        $candidates = @($data.All | Where-Object { (Test-HTM365GroupManageable -Group $_) -and $data.Current -notcontains $_.Id })
        $selected = Show-HTSelectionDialog -Title "Dodaj $($user.DisplayName) do grup" -MultiSelect -OkText "Dodaj" -Prompt "Grupy dynamiczne i synchronizowane z AD są pominięte." -Items $candidates -Columns @(
            @{ Text = "Grupa"; Property = "DisplayName"; Width = 280 }
            @{ Text = "Typ"; Property = "Type"; Width = 140 }
            @{ Text = "E-mail"; Property = "Mail"; Width = 240 }
        )
        if (-not $selected) { return }

        Invoke-HTAction -Name "Dodawanie do grup" -RequiredService "Graph" -ScriptBlock {
            $ok = Invoke-HTForEach -Items @($selected) -Action { param($g) Add-HTM365UserToGroup -Group $g -User $user } -Describe { param($g) $g.DisplayName }
            Write-Log -Message "Dodano $($user.UserPrincipalName) do $ok grup(y)." -Type "Info&Notification"
            Invoke-HTDetailsReload -View $HT_UI.UsersTab
        }
    })

# Usunięcie z grup
$HT_UI.UsersTab.Actions.RemoveFromGroup.Add_Click({
        $user = Get-HTSelectedM365User
        if (-not $user) { return }

        $groups = @(Invoke-HTAction -Name "Pobieranie grup użytkownika" -RequiredService "Graph" -ScriptBlock { Get-HTM365UserGroups -Id $user.Id })
        $candidates = @($groups | Where-Object { Test-HTM365GroupManageable -Group $_ })
        if ($candidates.Count -eq 0) {
            Show-Dialog -Message "Użytkownik nie należy do grup, którymi można zarządzać z tego miejsca (grupy dynamiczne i synchronizowane z AD są pomijane)." -Title "Usuń z grupy" | Out-Null
            return
        }

        $selected = Show-HTSelectionDialog -Title "Usuń $($user.DisplayName) z grup" -MultiSelect -OkText "Usuń" -Items $candidates -Columns @(
            @{ Text = "Grupa"; Property = "DisplayName"; Width = 280 }
            @{ Text = "Typ"; Property = "Type"; Width = 140 }
            @{ Text = "E-mail"; Property = "Mail"; Width = 240 }
        )
        if (-not $selected) { return }
        if (-not (Show-HTConfirm -Message "Usunąć użytkownika z $(@($selected).Count) grup(y)?" -Title "Usuń z grup")) { return }

        Invoke-HTAction -Name "Usuwanie z grup" -RequiredService "Graph" -ScriptBlock {
            $ok = Invoke-HTForEach -Items @($selected) -Action { param($g) Remove-HTM365UserFromGroup -Group $g -User $user } -Describe { param($g) $g.DisplayName }
            Write-Log -Message "Usunięto $($user.UserPrincipalName) z $ok grup(y)." -Type "Info&Notification"
            Invoke-HTDetailsReload -View $HT_UI.UsersTab
        }
    })

# Przejście do skrzynki użytkownika
$HT_UI.UsersTab.Actions.Mailbox.Add_Click({
        $user = Get-HTSelectedObject -View $HT_UI.UsersTab -What "użytkownika"
        if (-not $user) { return }
        if (-not (Assert-HTConnection -Service "Exchange")) { return }

        Show-HTSection -Name "Skrzynki"
        $mailboxes = $HT_UI.MailboxesTab
        if ((Get-HTListData -ListView $mailboxes.List).Count -eq 0) {
            Update-HTMailboxesList
        }
        $address = if ($user.Mail) { $user.Mail } else { $user.UserPrincipalName }
        $mailboxes.SearchBox.Text = $address
        Update-HTListFilter -ListView $mailboxes.List -Text $address
        $found = Select-HTListObject -ListView $mailboxes.List -Predicate {
            param($m) $m.PrimarySmtpAddress -eq $address -or $m.UserPrincipalName -eq $user.UserPrincipalName
        }
        if (-not $found) {
            Set-HTStatus -Text "Nie znaleziono skrzynki dla $address"
        }
    })

# Urządzenia użytkownika
$HT_UI.UsersTab.Actions.Devices.Add_Click({
        $user = Get-HTSelectedM365User
        if (-not $user) { return }
        $devices = @(Invoke-HTAction -Name "Pobieranie urządzeń" -RequiredService "Graph" -ScriptBlock { Get-HTM365UserDevices -Id $user.Id })
        Show-HTDataViewer -Title "Urządzenia - $($user.DisplayName)" -Data $devices -ExportName "Urzadzenia_$($user.UserPrincipalName)"
    })

# Nowy użytkownik
$HT_UI.UsersTab.Actions.NewUser.Add_Click({
        if (-not (Assert-HTConnection -Service "Graph")) { return }
        $domains = @(Invoke-HTAction -Name "Pobieranie domen" -RequiredService "Graph" -ScriptBlock { Get-HTM365Domains })
        if ($domains.Count -eq 0) { return }

        $form = Show-HTFormDialog -Title "Nowy użytkownik Microsoft 365" -OkText "Utwórz" -Description "Login (alias) zostanie utworzony automatycznie jako imie.nazwisko, jeśli pozostawisz pole puste." -Fields @(
            @{ Name = "GivenName"; Label = "Imię"; Required = $true }
            @{ Name = "Surname"; Label = "Nazwisko"; Required = $true }
            @{ Name = "Alias"; Label = "Login (alias)"; Placeholder = "imie.nazwisko" }
            @{ Name = "Domain"; Label = "Domena"; Type = "Combo"; Options = $domains }
            @{ Name = "Password"; Label = "Hasło"; Default = (New-Password -Length $Global:PasswordDefaultLength -StartWithLetter $true -NoSimilarChars $true); Required = $true }
            @{ Name = "JobTitle"; Label = "Stanowisko" }
            @{ Name = "Department"; Label = "Dział" }
            @{ Name = "UsageLocation"; Label = "Lokalizacja użycia"; Default = $Global:DefaultUsageLocation }
            @{ Name = "ForceChange"; Label = "Wymagaj zmiany hasła przy pierwszym logowaniu"; Type = "Check"; Default = $true }
        )
        if (-not $form) { return }

        $alias = if ($form.Alias) { $form.Alias } else { "$($form.GivenName).$($form.Surname)" }
        $alias = (ConvertTo-HTAsciiName $alias).ToLowerInvariant() -replace '[^a-z0-9\.\-_]', ''
        $upn = "$alias@$($form.Domain)"

        Invoke-HTAction -Name "Tworzenie użytkownika" -RequiredService "Graph" -ScriptBlock {
            $created = New-HTM365User -DisplayName "$($form.GivenName) $($form.Surname)" -UserPrincipalName $upn -Password $form.Password `
                -GivenName $form.GivenName -Surname $form.Surname -JobTitle $form.JobTitle -Department $form.Department `
                -UsageLocation $form.UsageLocation -ForceChange $form.ForceChange
            Write-Log -Message "Utworzono użytkownika $upn" -Type "Info&Notification"
            Show-HTSecretDialog -Title "Utworzono użytkownika" -Items @(
                @{ Label = "Login (UPN)"; Value = $created.userPrincipalName }
                @{ Label = "Hasło"; Value = $form.Password }
            )
        }
        Update-HTUsersList
    })

# Eksport listy
$HT_UI.UsersTab.Actions.Export.Add_Click({
        Export-HTListView -ListView $HT_UI.UsersTab.List -Name "Uzytkownicy_M365"
    })
