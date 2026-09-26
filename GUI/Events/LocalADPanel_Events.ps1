# Zakładka "Lokalne AD" - obsługa zdarzeń

# Bieżąca sekcja (Użytkownicy / Komputery / Grupy)
function Get-HTADCurrentSection {
    return "$($HT_UI.LocalADTab.SectionBox.SelectedItem)"
}

# Zaznaczony obiekt AD
function Get-HTSelectedADObject {
    param ([string]$What = "obiekt")
    if (-not (Assert-HTConnection -Service "AD")) { return $null }
    return Get-HTSelectedObject -View $HT_UI.LocalADTab -What $What
}

# Przyciski akcji sekcji
function Get-HTADButtons {
    param ([Parameter(Mandatory)][string]$Section)
    return $HT_UI.LocalADTab.ActionPanels[$Section].Buttons
}

# Wczytanie listy obiektów bieżącej sekcji
function Update-HTADList {
    $section = Get-HTADCurrentSection
    Invoke-HTAction -Name "Pobieranie obiektów AD ($section)" -RequiredService "AD" -ScriptBlock {
        $data = @(Get-HTADObjectList -Section $section)
        $HT_UI.LocalADTab.Loaded[$section] = $data
        Set-HTListData -ListView $HT_UI.LocalADTab.List -Data $data
        Set-HTDetails -ListView $HT_UI.LocalADTab.Details -Data $null -Message "Wybierz obiekt z listy, aby zobaczyć szczegóły."
        Write-Log -Message "Załadowano ($section): $($data.Count) obiektów." -Type "Info"
    }
}

# Usunięcie obiektu z listy (po usunięciu w AD)
function Remove-HTADListObject {
    param ([Parameter(Mandatory)][object]$Object)
    $section = Get-HTADCurrentSection
    $data = @($HT_UI.LocalADTab.Loaded[$section] | Where-Object { $_.ObjectGUID -ne $Object.ObjectGUID })
    $HT_UI.LocalADTab.Loaded[$section] = $data
    Set-HTListData -ListView $HT_UI.LocalADTab.List -Data $data
    Set-HTDetails -ListView $HT_UI.LocalADTab.Details -Data $null -Message "Obiekt został usunięty."
}

# Wybór jednostki organizacyjnej
function Select-HTADOrganizationalUnit {
    param ([string]$Title = "Wybierz jednostkę organizacyjną")
    $ous = @(Invoke-HTAction -Name "Pobieranie OU" -RequiredService "AD" -ScriptBlock { Get-HTADOrganizationalUnits })
    $ou = Show-HTSelectionDialog -Title $Title -Items $ous -Columns @(
        @{ Text = "Ścieżka"; Property = "CanonicalName"; Width = 420 }
        @{ Text = "Opis"; Property = "Description"; Width = 260 }
    )
    if ($ou) { return @($ou)[0] }
    return $null
}

# Przeniesienie obiektu do OU (wspólne dla wszystkich sekcji)
function Invoke-HTADMoveObject {
    $object = Get-HTSelectedADObject
    if (-not $object) { return }
    $ou = Select-HTADOrganizationalUnit -Title "Przenieś: $($object.Name)"
    if (-not $ou) { return }
    if (-not (Show-HTConfirm -Message "Przenieść $($object.Name) do:`n$($ou.CanonicalName)?" -Title "Przenieś do OU")) { return }

    Invoke-HTAction -Name "Przenoszenie obiektu" -RequiredService "AD" -ScriptBlock {
        Move-HTADObject -Identity $object.DistinguishedName -TargetPath $ou.DistinguishedName
        $rdn = ($object.DistinguishedName -split '(?<!\\),', 2)[0]
        $object.DistinguishedName = "$rdn,$($ou.DistinguishedName)"
        Write-Log -Message "Przeniesiono $($object.Name) do $($ou.CanonicalName)" -Type "Info&Notification"
        Invoke-HTDetailsReload -View $HT_UI.LocalADTab
    }
}

# Zmiana członkostwa w grupach (użytkownik / komputer)
function Invoke-HTADChangeGroups {
    $object = Get-HTSelectedADObject
    if (-not $object) { return }

    $choice = Show-HTChoiceDialog -Title "Grupy - $($object.Name)" -Choices @(
        @{ Key = "Add"; Text = "Dodaj do grup"; Icon = "Add Male User Group.png" }
        @{ Key = "Remove"; Text = "Usuń z grup"; Icon = "Minus.png" }
        @{ Key = "View"; Text = "Pokaż grupy"; Icon = "Eye open.png" }
    )
    if (-not $choice) { return }

    $current = @(Invoke-HTAction -Name "Pobieranie grup obiektu" -RequiredService "AD" -ScriptBlock { Get-HTADObjectGroups -DistinguishedName $object.DistinguishedName })
    $groupColumns = @(
        @{ Text = "Grupa"; Property = "Name"; Width = 300 }
        @{ Text = "DN"; Property = "DistinguishedName"; Width = 420 }
    )

    switch ($choice) {
        "View" {
            Show-HTDataViewer -Title "Grupy - $($object.Name)" -Data $current -Columns $groupColumns -ExportName "Grupy_$($object.Name)"
        }
        "Add" {
            $all = @(Invoke-HTAction -Name "Pobieranie grup" -RequiredService "AD" -ScriptBlock { Get-HTADGroupList })
            $currentDns = @($current | ForEach-Object { $_.DistinguishedName })
            $candidates = @($all | Where-Object { $currentDns -notcontains $_.DistinguishedName })
            $selected = Show-HTSelectionDialog -Title "Dodaj $($object.Name) do grup" -MultiSelect -OkText "Dodaj" -Items $candidates -Columns @(
                @{ Text = "Grupa"; Property = "Name"; Width = 260 }
                @{ Text = "Typ"; Property = "GroupCategory"; Width = 90 }
                @{ Text = "Zakres"; Property = "GroupScope"; Width = 90 }
                @{ Text = "Opis"; Property = "Description"; Width = 260 }
            )
            if (-not $selected) { return }
            Invoke-HTAction -Name "Dodawanie do grup" -RequiredService "AD" -ScriptBlock {
                $ok = Invoke-HTForEach -Items @($selected) -Action { param($g) Add-HTADGroupMember -Group $g.DistinguishedName -Members @($object.DistinguishedName) } -Describe { param($g) $g.Name }
                Write-Log -Message "Dodano $($object.Name) do $ok grup(y)." -Type "Info&Notification"
                Invoke-HTDetailsReload -View $HT_UI.LocalADTab
            }
        }
        "Remove" {
            if ($current.Count -eq 0) { Show-Dialog -Message "Obiekt nie należy do żadnej grupy (poza grupą podstawową)." -Title "Grupy" | Out-Null; return }
            $selected = Show-HTSelectionDialog -Title "Usuń $($object.Name) z grup" -MultiSelect -OkText "Usuń" -Items $current -Columns $groupColumns
            if (-not $selected) { return }
            if (-not (Show-HTConfirm -Message "Usunąć $($object.Name) z $(@($selected).Count) grup(y)?" -Title "Usuń z grup")) { return }
            Invoke-HTAction -Name "Usuwanie z grup" -RequiredService "AD" -ScriptBlock {
                $ok = Invoke-HTForEach -Items @($selected) -Action { param($g) Remove-HTADGroupMember -Group $g.DistinguishedName -Members @($object.DistinguishedName) } -Describe { param($g) $g.Name }
                Write-Log -Message "Usunięto $($object.Name) z $ok grup(y)." -Type "Info&Notification"
                Invoke-HTDetailsReload -View $HT_UI.LocalADTab
            }
        }
    }
}

# Usunięcie obiektu (wspólne)
function Invoke-HTADDeleteObject {
    $section = Get-HTADCurrentSection
    $object = Get-HTSelectedADObject
    if (-not $object) { return }
    if (-not (Show-HTConfirm -Message "Czy na pewno usunąć obiekt:`n$($object.Name)`n$($object.DistinguishedName)`n`nOperacji nie można cofnąć (chyba że włączony jest Kosz AD)." -Title "Usuń obiekt" -Warning)) { return }

    Invoke-HTAction -Name "Usuwanie obiektu AD" -RequiredService "AD" -ScriptBlock {
        Remove-HTADObject -Section $section -Identity $object.ObjectGUID
        Write-Log -Message "Usunięto obiekt AD: $($object.DistinguishedName)" -Type "Info&Notification"
        Remove-HTADListObject -Object $object
    }
}

#region Lista, sekcje, szczegóły

$HT_UI.LocalADTab.RefreshButton.Add_Click({ Update-HTADList })

# Zmiana sekcji: kolumny, akcje i (jeśli wczytane wcześniej) dane
$HT_UI.LocalADTab.SectionBox.Add_SelectedIndexChanged({
        $section = Get-HTADCurrentSection
        Set-HTListColumns -ListView $HT_UI.LocalADTab.List -Columns $HT_UI.LocalADTab.ColumnSets[$section]
        Show-LocalADButtons
        Set-HTDetails -ListView $HT_UI.LocalADTab.Details -Data $null -Message "Wybierz obiekt z listy, aby zobaczyć szczegóły."
        if ($HT_UI.LocalADTab.Loaded.ContainsKey($section)) {
            Set-HTListData -ListView $HT_UI.LocalADTab.List -Data $HT_UI.LocalADTab.Loaded[$section]
        }
        else {
            $HT_UI.LocalADTab.CountLabel.Text = "Lista niezaładowana - kliknij 'Odśwież'"
        }
        Write-Log -Message "Lokalne AD - sekcja: $section" -Type "Info"
    })

Register-HTDetailsLoader -View $HT_UI.LocalADTab -Loader {
    param($object)
    Get-HTADObjectDetail -Section (Get-HTADCurrentSection) -Identity "$($object.ObjectGUID)"
}

#endregion

#region Użytkownicy
$buttons = Get-HTADButtons -Section "Użytkownicy"

$buttons.ResetPassword.Add_Click({
        $user = Get-HTSelectedADObject -What "użytkownika"
        if (-not $user) { return }

        $form = Show-HTFormDialog -Title "Reset hasła AD" -Description "Użytkownik: $($user.Name) ($($user.SamAccountName))" -OkText "Resetuj hasło" -Fields @(
            @{ Name = "Password"; Label = "Nowe hasło"; Default = (New-Password -Length $Global:PasswordDefaultLength -StartWithLetter $true -NoSimilarChars $true); Required = $true }
            @{ Name = "ChangeAtLogon"; Label = "Wymagaj zmiany hasła przy następnym logowaniu"; Type = "Check"; Default = $true }
            @{ Name = "Unlock"; Label = "Odblokuj konto"; Type = "Check"; Default = $true }
        )
        if (-not $form) { return }

        Invoke-HTAction -Name "Reset hasła AD" -RequiredService "AD" -ScriptBlock {
            Reset-HTADUserPassword -Identity "$($user.ObjectGUID)" -Password $form.Password -ChangeAtLogon $form.ChangeAtLogon -Unlock $form.Unlock
            if ($form.Unlock) { $user.LockedOut = $false }
            Write-Log -Message "Zresetowano hasło AD użytkownika $($user.SamAccountName)" -Type "Info&Notification"
            Show-HTSecretDialog -Title "Nowe hasło" -Items @(
                @{ Label = "Login"; Value = $user.SamAccountName }
                @{ Label = "Hasło"; Value = $form.Password }
            )
            Invoke-HTDetailsReload -View $HT_UI.LocalADTab
        }
    })

$buttons.LockUnlock.Add_Click({
        $user = Get-HTSelectedADObject -What "użytkownika"
        if (-not $user) { return }

        $status = "Konto: $(if ($user.Enabled) { 'włączone' } else { 'wyłączone' }), $(if ($user.LockedOut) { 'ZABLOKOWANE' } else { 'niezablokowane' })"
        $choice = Show-HTChoiceDialog -Title "Stan konta - $($user.Name)" -Prompt $status -Choices @(
            @{ Key = "Unlock"; Text = "Odblokuj (po błędnych logowaniach)"; Icon = "padlock.png" }
            @{ Key = "Enable"; Text = "Włącz konto"; Icon = "validation.png" }
            @{ Key = "Disable"; Text = "Wyłącz konto"; Icon = "Denied.png"; Style = "Danger" }
        )
        if (-not $choice) { return }

        Invoke-HTAction -Name "Zmiana stanu konta" -RequiredService "AD" -ScriptBlock {
            Set-HTADAccountState -Identity "$($user.ObjectGUID)" -State $choice
            switch ($choice) {
                "Unlock" { $user.LockedOut = $false }
                "Enable" { $user.Enabled = $true }
                "Disable" { $user.Enabled = $false }
            }
            Write-Log -Message "Konto $($user.SamAccountName): $choice" -Type "Info&Notification"
            Invoke-HTDetailsReload -View $HT_UI.LocalADTab
        }
    })

$buttons.EditAttributes.Add_Click({
        $user = Get-HTSelectedADObject -What "użytkownika"
        if (-not $user) { return }

        $current = Invoke-HTAction -Name "Pobieranie danych" -RequiredService "AD" -ScriptBlock {
            $u = Get-ADUser -Identity "$($user.ObjectGUID)" -Properties DisplayName, Title, Department, Company, Office, OfficePhone, MobilePhone, EmailAddress, Description, Manager
            $managerLogin = if ($u.Manager) { (Get-ADUser -Identity $u.Manager).SamAccountName } else { "" }
            [PSCustomObject]@{ User = $u; Manager = $managerLogin }
        }
        if (-not $current) { return }
        $u = $current.User

        $fields = @(
            @{ Name = "DisplayName"; Label = "Nazwa wyświetlana"; Default = $u.DisplayName }
            @{ Name = "Title"; Label = "Stanowisko"; Default = $u.Title }
            @{ Name = "Department"; Label = "Dział"; Default = $u.Department }
            @{ Name = "Company"; Label = "Firma"; Default = $u.Company }
            @{ Name = "Office"; Label = "Biuro"; Default = $u.Office }
            @{ Name = "OfficePhone"; Label = "Telefon"; Default = $u.OfficePhone }
            @{ Name = "MobilePhone"; Label = "Komórka"; Default = $u.MobilePhone }
            @{ Name = "EmailAddress"; Label = "E-mail"; Default = $u.EmailAddress; Validation = "Email" }
            @{ Name = "Description"; Label = "Opis"; Default = $u.Description }
            @{ Name = "Manager"; Label = "Przełożony (login)"; Default = $current.Manager }
        )
        $form = Show-HTFormDialog -Title "Edytuj dane - $($user.Name)" -Fields $fields
        if (-not $form) { return }

        $changes = @{}
        foreach ($field in $fields) {
            if ("$($field.Default)" -ne "$($form[$field.Name])") { $changes[$field.Name] = $form[$field.Name] }
        }
        if ($changes.Count -eq 0) { Set-HTStatus -Text "Brak zmian."; return }

        Invoke-HTAction -Name "Zapis danych użytkownika" -RequiredService "AD" -ScriptBlock {
            Set-HTADUserAttributes -Identity "$($user.ObjectGUID)" -Attributes $changes
            if ($changes.ContainsKey("Department")) { $user.Department = $changes.Department }
            if ($changes.ContainsKey("Title")) { $user.Title = $changes.Title }
            if ($changes.ContainsKey("EmailAddress")) { $user.EmailAddress = $changes.EmailAddress }
            Write-Log -Message "Zaktualizowano dane AD $($user.SamAccountName): $($changes.Keys -join ', ')" -Type "Info&Notification"
            Invoke-HTDetailsReload -View $HT_UI.LocalADTab
        }
    })

$buttons.AssignProfile.Add_Click({
        $user = Get-HTSelectedADObject -What "użytkownika"
        if (-not $user) { return }

        $u = Invoke-HTAction -Name "Pobieranie profilu" -RequiredService "AD" -ScriptBlock {
            Get-ADUser -Identity "$($user.ObjectGUID)" -Properties ProfilePath, ScriptPath, HomeDirectory, HomeDrive
        }
        if (-not $u) { return }

        $form = Show-HTFormDialog -Title "Profil i katalog domowy - $($user.Name)" -Width 640 -Description "Puste pole usuwa wartość. Zmienna %username% nie jest rozwijana - wpisz pełną ścieżkę." -Fields @(
            @{ Name = "ProfilePath"; Label = "Ścieżka profilu"; Default = $u.ProfilePath; Placeholder = "\\serwer\profile$\$($user.SamAccountName)" }
            @{ Name = "ScriptPath"; Label = "Skrypt logowania"; Default = $u.ScriptPath }
            @{ Name = "HomeDirectory"; Label = "Katalog domowy"; Default = $u.HomeDirectory; Placeholder = "\\serwer\home$\$($user.SamAccountName)" }
            @{ Name = "HomeDrive"; Label = "Litera dysku"; Type = "Combo"; Editable = $true; Options = @("", "H:", "U:", "P:", "Z:"); Default = $u.HomeDrive }
        )
        if (-not $form) { return }

        Invoke-HTAction -Name "Zapis profilu" -RequiredService "AD" -ScriptBlock {
            Set-HTADUserProfile -Identity "$($user.ObjectGUID)" -ProfilePath $form.ProfilePath -ScriptPath $form.ScriptPath -HomeDirectory $form.HomeDirectory -HomeDrive $form.HomeDrive
            Write-Log -Message "Zaktualizowano profil użytkownika $($user.SamAccountName)" -Type "Info&Notification"
            Invoke-HTDetailsReload -View $HT_UI.LocalADTab
        }
    })

$buttons.Special.Add_Click({
        $user = Get-HTSelectedADObject -What "użytkownika"
        if (-not $user) { return }

        $choice = Show-HTChoiceDialog -Title "Akcje specjalne - $($user.Name)" -Choices @(
            @{ Key = "ChangeAtLogon"; Text = "Wymuś zmianę hasła przy logowaniu"; Icon = "Password Reset.png" }
            @{ Key = "NeverExpires"; Text = "Przełącz: hasło nigdy nie wygasa"; Icon = "lock.png" }
            @{ Key = "Expiration"; Text = "Data wygaśnięcia konta"; Icon = "Restart.png" }
            @{ Key = "CopyDN"; Text = "Kopiuj DN do schowka"; Icon = "Copy.png" }
            @{ Key = "CopyUPN"; Text = "Kopiuj UPN do schowka"; Icon = "Copy.png" }
        )

        switch ($choice) {
            "ChangeAtLogon" {
                Invoke-HTAction -Name "Wymuszenie zmiany hasła" -RequiredService "AD" -ScriptBlock {
                    Set-HTADChangePasswordAtLogon -Identity "$($user.ObjectGUID)" -Value $true
                    Write-Log -Message "Wymuszono zmianę hasła przy logowaniu: $($user.SamAccountName)" -Type "Info&Notification"
                    Invoke-HTDetailsReload -View $HT_UI.LocalADTab
                }
            }
            "NeverExpires" {
                $currentValue = Invoke-HTAction -Name "Odczyt ustawień hasła" -RequiredService "AD" -ScriptBlock { (Get-ADUser -Identity "$($user.ObjectGUID)" -Properties PasswordNeverExpires).PasswordNeverExpires }
                $newValue = -not [bool]$currentValue
                if (-not (Show-HTConfirm -Message "Ustawić 'hasło nigdy nie wygasa' = $(if ($newValue) { 'TAK' } else { 'NIE' }) dla $($user.SamAccountName)?" -Title "Hasło")) { return }
                Invoke-HTAction -Name "Zmiana wygasania hasła" -RequiredService "AD" -ScriptBlock {
                    Set-HTADPasswordNeverExpires -Identity "$($user.ObjectGUID)" -Value $newValue
                    Write-Log -Message "PasswordNeverExpires=$newValue dla $($user.SamAccountName)" -Type "Info&Notification"
                    Invoke-HTDetailsReload -View $HT_UI.LocalADTab
                }
            }
            "Expiration" {
                $form = Show-HTFormDialog -Title "Wygaśnięcie konta - $($user.Name)" -Description "Odznacz datę, aby konto nigdy nie wygasało." -Fields @(
                    @{ Name = "Date"; Label = "Konto wygasa"; Type = "Date"; Optional = $true; DateOnly = $true; Default = (Get-Date).Date.AddDays(30) }
                )
                if (-not $form) { return }
                Invoke-HTAction -Name "Data wygaśnięcia konta" -RequiredService "AD" -ScriptBlock {
                    Set-HTADAccountExpiration -Identity "$($user.ObjectGUID)" -Date $form.Date
                    Write-Log -Message "Wygaśnięcie konta $($user.SamAccountName): $(if ($form.Date) { $form.Date.ToString('yyyy-MM-dd') } else { 'nigdy' })" -Type "Info&Notification"
                    Invoke-HTDetailsReload -View $HT_UI.LocalADTab
                }
            }
            "CopyDN" { Set-HTClipboard -Text $user.DistinguishedName; Set-HTStatus -Text "Skopiowano DN." }
            "CopyUPN" { Set-HTClipboard -Text $user.UserPrincipalName; Set-HTStatus -Text "Skopiowano UPN." }
        }
    })

$buttons.ChangeGroups.Add_Click({ Invoke-HTADChangeGroups })
$buttons.MoveOU.Add_Click({ Invoke-HTADMoveObject })
$buttons.Delete.Add_Click({ Invoke-HTADDeleteObject })
$buttons.Export.Add_Click({ Export-HTListView -ListView $HT_UI.LocalADTab.List -Name "AD_Uzytkownicy" })

$buttons.NewUser.Add_Click({
        if (-not (Assert-HTConnection -Service "AD")) { return }

        $context = Invoke-HTAction -Name "Pobieranie danych domeny" -RequiredService "AD" -ScriptBlock {
            $domain = Get-ADDomain
            $forest = Get-ADForest
            @{
                Suffixes = @(@($domain.DNSRoot) + @($forest.UPNSuffixes) | Where-Object { $_ } | Select-Object -Unique)
                OUs      = @(Get-HTADOrganizationalUnits)
            }
        }
        if (-not $context) { return }

        $ouNames = @($context.OUs | ForEach-Object { $_.CanonicalName })
        $form = Show-HTFormDialog -Title "Nowy użytkownik AD" -Width 640 -OkText "Utwórz" -Description "Login zostanie utworzony automatycznie (imie.nazwisko), jeśli pozostawisz pole puste." -Fields @(
            @{ Name = "GivenName"; Label = "Imię"; Required = $true }
            @{ Name = "Surname"; Label = "Nazwisko"; Required = $true }
            @{ Name = "Login"; Label = "Login (sAMAccountName)"; Placeholder = "imie.nazwisko" }
            @{ Name = "Suffix"; Label = "Sufiks UPN"; Type = "Combo"; Options = $context.Suffixes }
            @{ Name = "OU"; Label = "Jednostka organizacyjna"; Type = "Combo"; Options = $ouNames }
            @{ Name = "Password"; Label = "Hasło"; Default = (New-Password -Length $Global:PasswordDefaultLength -StartWithLetter $true -NoSimilarChars $true); Required = $true }
            @{ Name = "Title"; Label = "Stanowisko" }
            @{ Name = "Department"; Label = "Dział" }
            @{ Name = "Enabled"; Label = "Konto włączone"; Type = "Check"; Default = $true }
            @{ Name = "ChangeAtLogon"; Label = "Wymagaj zmiany hasła przy pierwszym logowaniu"; Type = "Check"; Default = $true }
        )
        if (-not $form) { return }

        $login = if ($form.Login) { $form.Login } else { "$($form.GivenName).$($form.Surname)" }
        $login = (ConvertTo-HTAsciiName $login).ToLowerInvariant() -replace '[^a-z0-9\.\-_]', ''
        if ($login.Length -gt 20) { $login = $login.Substring(0, 20).TrimEnd(".") }
        $ou = $context.OUs | Where-Object { $_.CanonicalName -eq $form.OU } | Select-Object -First 1

        Invoke-HTAction -Name "Tworzenie użytkownika AD" -RequiredService "AD" -ScriptBlock {
            New-HTADUser -GivenName $form.GivenName -Surname $form.Surname -SamAccountName $login -UserPrincipalName "$login@$($form.Suffix)" `
                -Password $form.Password -Path $ou.DistinguishedName -Title $form.Title -Department $form.Department `
                -Enabled $form.Enabled -ChangeAtLogon $form.ChangeAtLogon | Out-Null
            Write-Log -Message "Utworzono użytkownika AD $login ($($form.OU))" -Type "Info&Notification"
            Show-HTSecretDialog -Title "Utworzono użytkownika" -Items @(
                @{ Label = "Login"; Value = $login }
                @{ Label = "UPN"; Value = "$login@$($form.Suffix)" }
                @{ Label = "Hasło"; Value = $form.Password }
            )
        }
        Update-HTADList
    })
#endregion

#region Komputery
$buttons = Get-HTADButtons -Section "Komputery"

$buttons.Ping.Add_Click({
        $computer = Get-HTSelectedADObject -What "komputer"
        if (-not $computer) { return }
        $target = if ($computer.DNSHostName) { $computer.DNSHostName } else { $computer.Name }
        Invoke-HTAction -Name "Test połączenia z $target" -ScriptBlock {
            $result = Test-HTComputerReachable -ComputerName $target
            Set-HTDetails -ListView $HT_UI.LocalADTab.Details -Data ([ordered]@{ "Test połączenia" = $result })
            Write-Log -Message "Test połączenia $target`: ping=$($result['Odpowiada na ping'])" -Type "Info"
        }
    })

$buttons.Restart.Add_Click({
        $computer = Get-HTSelectedADObject -What "komputer"
        if (-not $computer) { return }
        $target = if ($computer.DNSHostName) { $computer.DNSHostName } else { $computer.Name }
        if (-not (Show-HTConfirm -Message "Zrestartować komputer $target?`nZalogowani użytkownicy mogą utracić niezapisane dane." -Title "Restart komputera" -Warning)) { return }
        Invoke-HTAction -Name "Restart komputera" -ScriptBlock {
            Restart-HTComputer -ComputerName $target
            Write-Log -Message "Wysłano polecenie restartu do $target" -Type "Info&Notification"
        }
    })

$buttons.ToggleEnabled.Add_Click({
        $computer = Get-HTSelectedADObject -What "komputer"
        if (-not $computer) { return }
        $state = if ($computer.Enabled) { "Disable" } else { "Enable" }
        $question = if ($computer.Enabled) { "Wyłączyć konto komputera $($computer.Name)?`nKomputer nie będzie mógł uwierzytelniać się w domenie." } else { "Włączyć konto komputera $($computer.Name)?" }
        if (-not (Show-HTConfirm -Message $question -Title "Konto komputera" -Warning:($state -eq "Disable"))) { return }

        Invoke-HTAction -Name "Zmiana stanu konta komputera" -RequiredService "AD" -ScriptBlock {
            Set-HTADAccountState -Identity "$($computer.ObjectGUID)" -State $state
            $computer.Enabled = ($state -eq "Enable")
            Write-Log -Message "Konto komputera $($computer.Name): $state" -Type "Info&Notification"
            Invoke-HTDetailsReload -View $HT_UI.LocalADTab
        }
    })

$buttons.EditDescription.Add_Click({
        $computer = Get-HTSelectedADObject -What "komputer"
        if (-not $computer) { return }
        $description = Show-InputBox -Prompt "Opis komputera $($computer.Name) (np. użytkownik, lokalizacja):" -Title "Opis komputera" -DefaultText "$($computer.Description)" -AllowEmpty
        if ($null -eq $description) { return }

        Invoke-HTAction -Name "Zmiana opisu komputera" -RequiredService "AD" -ScriptBlock {
            Set-HTADComputerDescription -Identity "$($computer.ObjectGUID)" -Description $description
            $computer.Description = $description
            Write-Log -Message "Opis komputera $($computer.Name): $description" -Type "Info&Notification"
            Invoke-HTDetailsReload -View $HT_UI.LocalADTab
        }
    })

$buttons.Groups.Add_Click({ Invoke-HTADChangeGroups })
$buttons.MoveOU.Add_Click({ Invoke-HTADMoveObject })
$buttons.Delete.Add_Click({ Invoke-HTADDeleteObject })
$buttons.Export.Add_Click({ Export-HTListView -ListView $HT_UI.LocalADTab.List -Name "AD_Komputery" })

$buttons.LAPS.Add_Click({
        $computer = Get-HTSelectedADObject -What "komputer"
        if (-not $computer) { return }
        $laps = Invoke-HTAction -Name "Pobieranie hasła LAPS" -RequiredService "AD" -ScriptBlock { Get-HTADLapsPassword -ComputerName $computer.Name }
        if (-not $laps) {
            Show-Dialog -Message "Brak hasła LAPS dla $($computer.Name) lub brak uprawnień do jego odczytu." -Title "LAPS" | Out-Null
            return
        }
        Write-Log -Message "Wyświetlono hasło LAPS komputera $($computer.Name)" -Type "Info"
        Show-HTSecretDialog -Title "LAPS - $($computer.Name)" -Items @(
            @{ Label = "Konto"; Value = $laps.Account }
            @{ Label = "Hasło"; Value = $laps.Password }
            @{ Label = "Wygasa"; Value = (ConvertTo-HTDisplayValue $laps.Expiration) }
            @{ Label = "Źródło"; Value = $laps.Source }
        )
    })

$buttons.BitLocker.Add_Click({
        $computer = Get-HTSelectedADObject -What "komputer"
        if (-not $computer) { return }
        $keys = @(Invoke-HTAction -Name "Pobieranie kluczy BitLocker" -RequiredService "AD" -ScriptBlock { Get-HTADBitLockerKeys -ComputerName $computer.Name })
        if ($keys.Count -eq 0) {
            Show-Dialog -Message "Brak kluczy odzyskiwania BitLocker dla $($computer.Name) w AD." -Title "BitLocker" | Out-Null
            return
        }
        Write-Log -Message "Wyświetlono klucze BitLocker komputera $($computer.Name)" -Type "Info"
        $items = foreach ($key in $keys) {
            @{ Label = "Klucz ($((ConvertTo-HTDisplayValue $key.Created)))"; Value = $key.RecoveryPassword }
            @{ Label = "ID klucza"; Value = $key.KeyId }
        }
        Show-HTSecretDialog -Title "BitLocker - $($computer.Name)" -Items @($items)
    })
#endregion

#region Grupy
$buttons = Get-HTADButtons -Section "Grupy"

$buttons.AddMembers.Add_Click({
        $group = Get-HTSelectedADObject -What "grupę"
        if (-not $group) { return }

        $candidates = @(Invoke-HTAction -Name "Pobieranie obiektów" -RequiredService "AD" -ScriptBlock {
                $current = @(Get-HTADGroupMembers -Identity "$($group.ObjectGUID)" | ForEach-Object { $_.DistinguishedName })
                $objects = @()
                $objects += Get-ADUser -Filter * | ForEach-Object { [PSCustomObject]@{ Name = $_.Name; Login = $_.SamAccountName; Type = "Użytkownik"; DistinguishedName = $_.DistinguishedName } }
                $objects += Get-ADGroup -Filter * | ForEach-Object { [PSCustomObject]@{ Name = $_.Name; Login = $_.SamAccountName; Type = "Grupa"; DistinguishedName = $_.DistinguishedName } }
                $objects += Get-ADComputer -Filter * | ForEach-Object { [PSCustomObject]@{ Name = $_.Name; Login = $_.SamAccountName; Type = "Komputer"; DistinguishedName = $_.DistinguishedName } }
                $objects | Where-Object { $current -notcontains $_.DistinguishedName -and $_.DistinguishedName -ne $group.DistinguishedName } | Sort-Object Type, Name
            })
        $selected = Show-HTSelectionDialog -Title "Dodaj członków do $($group.Name)" -MultiSelect -OkText "Dodaj" -Items $candidates -Columns @(
            @{ Text = "Nazwa"; Property = "Name"; Width = 260 }
            @{ Text = "Login"; Property = "Login"; Width = 160 }
            @{ Text = "Typ"; Property = "Type"; Width = 100 }
        )
        if (-not $selected) { return }

        Invoke-HTAction -Name "Dodawanie członków" -RequiredService "AD" -ScriptBlock {
            Add-HTADGroupMember -Group "$($group.ObjectGUID)" -Members @($selected | ForEach-Object { $_.DistinguishedName })
            Write-Log -Message "Dodano $(@($selected).Count) członków do grupy $($group.Name)" -Type "Info&Notification"
            Invoke-HTDetailsReload -View $HT_UI.LocalADTab
        }
    })

$buttons.RemoveMembers.Add_Click({
        $group = Get-HTSelectedADObject -What "grupę"
        if (-not $group) { return }
        $members = @(Invoke-HTAction -Name "Pobieranie członków" -RequiredService "AD" -ScriptBlock { Get-HTADGroupMembers -Identity "$($group.ObjectGUID)" })
        if ($members.Count -eq 0) { Show-Dialog -Message "Grupa $($group.Name) nie ma członków." -Title "Członkowie" | Out-Null; return }

        $selected = Show-HTSelectionDialog -Title "Usuń członków z $($group.Name)" -MultiSelect -OkText "Usuń" -Items $members -Columns @(
            @{ Text = "Nazwa"; Property = "Name"; Width = 260 }
            @{ Text = "Login"; Property = "SamAccountName"; Width = 160 }
            @{ Text = "Typ"; Property = "ObjectClass"; Width = 100 }
        )
        if (-not $selected) { return }
        if (-not (Show-HTConfirm -Message "Usunąć $(@($selected).Count) członków z grupy $($group.Name)?" -Title "Usuń członków")) { return }

        Invoke-HTAction -Name "Usuwanie członków" -RequiredService "AD" -ScriptBlock {
            Remove-HTADGroupMember -Group "$($group.ObjectGUID)" -Members @($selected | ForEach-Object { $_.DistinguishedName })
            Write-Log -Message "Usunięto $(@($selected).Count) członków z grupy $($group.Name)" -Type "Info&Notification"
            Invoke-HTDetailsReload -View $HT_UI.LocalADTab
        }
    })

$buttons.ExportMembers.Add_Click({
        $group = Get-HTSelectedADObject -What "grupę"
        if (-not $group) { return }
        $members = @(Invoke-HTAction -Name "Pobieranie członków" -RequiredService "AD" -ScriptBlock { Get-HTADGroupMembers -Identity "$($group.ObjectGUID)" })
        Show-HTDataViewer -Title "Członkowie - $($group.Name)" -Data $members -ExportName "Czlonkowie_$($group.Name)"
    })

$buttons.Rename.Add_Click({
        $group = Get-HTSelectedADObject -What "grupę"
        if (-not $group) { return }
        $newName = Show-InputBox -Prompt "Nowa nazwa grupy $($group.Name):" -Title "Zmień nazwę" -DefaultText $group.Name
        if (-not $newName -or $newName -eq $group.Name) { return }

        Invoke-HTAction -Name "Zmiana nazwy grupy" -RequiredService "AD" -ScriptBlock {
            Rename-HTADGroup -Identity "$($group.ObjectGUID)" -NewName $newName
            $group.DistinguishedName = (Get-ADGroup -Identity "$($group.ObjectGUID)").DistinguishedName
            $oldName = $group.Name
            $group.Name = $newName
            $group.SamAccountName = $newName
            Write-Log -Message "Zmieniono nazwę grupy $oldName -> $newName" -Type "Info&Notification"
            Invoke-HTDetailsReload -View $HT_UI.LocalADTab
        }
    })

$buttons.ChangeType.Add_Click({
        $group = Get-HTSelectedADObject -What "grupę"
        if (-not $group) { return }
        $category = Show-HTChoiceDialog -Title "Typ grupy - $($group.Name)" -Prompt "Obecny typ: $($group.GroupCategory)" -Choices @(
            @{ Key = "Security"; Text = "Zabezpieczeń (Security)"; Icon = "Secure.png" }
            @{ Key = "Distribution"; Text = "Dystrybucyjna (Distribution)"; Icon = "Email.png"; Description = "Grupa dystrybucyjna nie nadaje uprawnień" }
        )
        if (-not $category -or $category -eq $group.GroupCategory) { return }

        Invoke-HTAction -Name "Zmiana typu grupy" -RequiredService "AD" -ScriptBlock {
            Set-HTADGroupCategory -Identity "$($group.ObjectGUID)" -Category $category
            $group.GroupCategory = $category
            Write-Log -Message "Typ grupy $($group.Name): $category" -Type "Info&Notification"
            Invoke-HTDetailsReload -View $HT_UI.LocalADTab
        }
    })

$buttons.ChangeScope.Add_Click({
        $group = Get-HTSelectedADObject -What "grupę"
        if (-not $group) { return }
        $scope = Show-HTChoiceDialog -Title "Zakres grupy - $($group.Name)" -Prompt "Obecny zakres: $($group.GroupScope)" -Choices @(
            @{ Key = "DomainLocal"; Text = "Lokalna domeny (DomainLocal)" }
            @{ Key = "Global"; Text = "Globalna (Global)" }
            @{ Key = "Universal"; Text = "Uniwersalna (Universal)" }
        )
        if (-not $scope -or $scope -eq $group.GroupScope) { return }

        Invoke-HTAction -Name "Zmiana zakresu grupy" -RequiredService "AD" -ScriptBlock {
            Set-HTADGroupScope -Identity "$($group.ObjectGUID)" -Scope $scope
            $group.GroupScope = $scope
            Write-Log -Message "Zakres grupy $($group.Name): $scope" -Type "Info&Notification"
            Invoke-HTDetailsReload -View $HT_UI.LocalADTab
        }
    })

$buttons.MoveOU.Add_Click({ Invoke-HTADMoveObject })
$buttons.Delete.Add_Click({ Invoke-HTADDeleteObject })
$buttons.Export.Add_Click({ Export-HTListView -ListView $HT_UI.LocalADTab.List -Name "AD_Grupy" })

$buttons.NewGroup.Add_Click({
        if (-not (Assert-HTConnection -Service "AD")) { return }
        $ous = @(Invoke-HTAction -Name "Pobieranie OU" -RequiredService "AD" -ScriptBlock { Get-HTADOrganizationalUnits })
        $form = Show-HTFormDialog -Title "Nowa grupa AD" -Width 620 -OkText "Utwórz" -Fields @(
            @{ Name = "Name"; Label = "Nazwa"; Required = $true }
            @{ Name = "Category"; Label = "Typ"; Type = "Combo"; Options = @("Security", "Distribution") }
            @{ Name = "Scope"; Label = "Zakres"; Type = "Combo"; Options = @("Global", "DomainLocal", "Universal") }
            @{ Name = "OU"; Label = "Jednostka organizacyjna"; Type = "Combo"; Options = @($ous | ForEach-Object { $_.CanonicalName }) }
            @{ Name = "Description"; Label = "Opis" }
        )
        if (-not $form) { return }
        $ou = $ous | Where-Object { $_.CanonicalName -eq $form.OU } | Select-Object -First 1

        Invoke-HTAction -Name "Tworzenie grupy AD" -RequiredService "AD" -ScriptBlock {
            New-HTADGroup -Name $form.Name -Category $form.Category -Scope $form.Scope -Path $ou.DistinguishedName -Description $form.Description | Out-Null
            Write-Log -Message "Utworzono grupę AD $($form.Name) ($($form.OU))" -Type "Info&Notification"
        }
        Update-HTADList
    })
#endregion

Remove-Variable -Name buttons -ErrorAction SilentlyContinue
