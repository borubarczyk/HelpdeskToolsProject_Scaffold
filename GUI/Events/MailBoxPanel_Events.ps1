# Zakładka "Skrzynki" (Exchange Online) - obsługa zdarzeń

# Zaznaczona skrzynka (wymaga połączenia z Exchange)
function Get-HTSelectedMailbox {
    if (-not (Assert-HTConnection -Service "Exchange")) { return $null }
    return Get-HTSelectedObject -View $HT_UI.MailboxesTab -What "skrzynkę"
}

# Zastosowanie filtra typu skrzynki do pobranych danych
function Update-HTMailboxTypeFilter {
    $view = $HT_UI.MailboxesTab
    $type = "$($view.TypeFilter.SelectedItem)"
    $data = if ($type -and $type -ne "Wszystkie typy") { @($view.AllData | Where-Object { $_.RecipientTypeDetails -eq $type }) } else { @($view.AllData) }
    Set-HTListData -ListView $view.List -Data $data
}

# Odświeżenie listy skrzynek
function Update-HTMailboxesList {
    Invoke-HTAction -Name "Pobieranie skrzynek" -RequiredService "Exchange" -ScriptBlock {
        $HT_UI.MailboxesTab.AllData = @(Get-HTMailboxes)
        Update-HTMailboxTypeFilter
        Set-HTDetails -ListView $HT_UI.MailboxesTab.Details -Data $null -Message "Wybierz skrzynkę z listy, aby zobaczyć szczegóły."
        Write-Log -Message "Załadowano skrzynki: $($HT_UI.MailboxesTab.AllData.Count)" -Type "Info"
    }
}

$HT_UI.MailboxesTab.RefreshButton.Add_Click({ Update-HTMailboxesList })
$HT_UI.MailboxesTab.TypeFilter.Add_SelectedIndexChanged({ Update-HTMailboxTypeFilter })

# Szczegóły skrzynki
Register-HTDetailsLoader -View $HT_UI.MailboxesTab -Loader {
    param($mailbox)
    Get-HTMailboxDetail -Identity $mailbox.Identity
}

$permissionColumns = @(
    @{ Text = "Typ"; Property = "Type"; Width = 120 }
    @{ Text = "Użytkownik"; Property = "User"; Width = 320 }
    @{ Text = "Prawa"; Property = "AccessRights"; Width = 200 }
)

# Sprawdzenie uprawnień
$HT_UI.MailboxesTab.Actions.CheckPerms.Add_Click({
        $mailbox = Get-HTSelectedMailbox
        if (-not $mailbox) { return }
        $permissions = @(Invoke-HTAction -Name "Pobieranie uprawnień" -RequiredService "Exchange" -ScriptBlock { Get-HTMailboxPermissions -Identity $mailbox.Identity })
        if ($permissions.Count -eq 0) {
            Show-Dialog -Message "Nikt poza właścicielem nie ma uprawnień do skrzynki $($mailbox.PrimarySmtpAddress)." -Title "Uprawnienia" | Out-Null
            return
        }
        Show-HTDataViewer -Title "Uprawnienia - $($mailbox.DisplayName)" -Data $permissions -Columns $permissionColumns -ExportName "Uprawnienia_$($mailbox.PrimarySmtpAddress)"
    })

# Nadanie uprawnień
$HT_UI.MailboxesTab.Actions.GrantPerms.Add_Click({
        $mailbox = Get-HTSelectedMailbox
        if (-not $mailbox) { return }

        $form = Show-HTFormDialog -Title "Nadaj uprawnienia - $($mailbox.DisplayName)" -Description "Skrzynka: $($mailbox.PrimarySmtpAddress)" -OkText "Nadaj" -Fields @(
            @{ Name = "User"; Label = "Użytkownik (e-mail)"; Required = $true; Validation = "Email" }
            @{ Name = "FullAccess"; Label = "Pełny dostęp (FullAccess)"; Type = "Check"; Default = $true }
            @{ Name = "AutoMapping"; Label = "Automatyczne mapowanie w Outlooku"; Type = "Check"; Default = $true }
            @{ Name = "SendAs"; Label = "Wysyłanie jako (SendAs)"; Type = "Check"; Default = $false }
            @{ Name = "SendOnBehalf"; Label = "Wysyłanie w imieniu (SendOnBehalf)"; Type = "Check"; Default = $false }
        )
        if (-not $form) { return }

        $types = @()
        if ($form.FullAccess) { $types += "FullAccess" }
        if ($form.SendAs) { $types += "SendAs" }
        if ($form.SendOnBehalf) { $types += "SendOnBehalf" }
        if ($types.Count -eq 0) { Show-Dialog -Message "Nie wybrano żadnego uprawnienia." -Title "Uprawnienia" -Type "Warning" | Out-Null; return }

        Invoke-HTAction -Name "Nadawanie uprawnień" -RequiredService "Exchange" -ScriptBlock {
            Add-HTMailboxPermission -Identity $mailbox.Identity -User $form.User -Type $types -AutoMapping $form.AutoMapping
            Write-Log -Message "Nadano $($types -join ', ') dla $($form.User) do skrzynki $($mailbox.PrimarySmtpAddress)" -Type "Info&Notification"
        }
    })

# Odebranie uprawnień
$HT_UI.MailboxesTab.Actions.RemovePerms.Add_Click({
        $mailbox = Get-HTSelectedMailbox
        if (-not $mailbox) { return }
        $permissions = @(Invoke-HTAction -Name "Pobieranie uprawnień" -RequiredService "Exchange" -ScriptBlock { Get-HTMailboxPermissions -Identity $mailbox.Identity })
        if ($permissions.Count -eq 0) {
            Show-Dialog -Message "Brak uprawnień do odebrania." -Title "Uprawnienia" | Out-Null
            return
        }

        $selected = Show-HTSelectionDialog -Title "Odbierz uprawnienia - $($mailbox.DisplayName)" -MultiSelect -OkText "Odbierz" -Items $permissions -Columns $permissionColumns
        if (-not $selected) { return }
        if (-not (Show-HTConfirm -Message "Odebrać $(@($selected).Count) uprawnień do skrzynki $($mailbox.PrimarySmtpAddress)?" -Title "Odbierz uprawnienia")) { return }

        Invoke-HTAction -Name "Odbieranie uprawnień" -RequiredService "Exchange" -ScriptBlock {
            $ok = Invoke-HTForEach -Items @($selected) -Action { param($p) Remove-HTMailboxPermission -Identity $mailbox.Identity -User $p.User -Type $p.Type } -Describe { param($p) "$($p.Type) $($p.User)" }
            Write-Log -Message "Odebrano $ok uprawnień do skrzynki $($mailbox.PrimarySmtpAddress)" -Type "Info&Notification"
        }
    })

# Uprawnienia kalendarza
$HT_UI.MailboxesTab.Actions.Calendar.Add_Click({
        $mailbox = Get-HTSelectedMailbox
        if (-not $mailbox) { return }

        $choice = Show-HTChoiceDialog -Title "Kalendarz - $($mailbox.DisplayName)" -Choices @(
            @{ Key = "View"; Text = "Pokaż uprawnienia"; Icon = "Eye open.png" }
            @{ Key = "Set"; Text = "Nadaj / zmień uprawnienia"; Icon = "Add Male User Group.png" }
            @{ Key = "Remove"; Text = "Usuń uprawnienia"; Icon = "Minus.png" }
        )
        switch ($choice) {
            "View" {
                $permissions = @(Invoke-HTAction -Name "Uprawnienia kalendarza" -RequiredService "Exchange" -ScriptBlock { Get-HTCalendarPermissions -Identity $mailbox.Identity })
                Show-HTDataViewer -Title "Kalendarz - $($mailbox.DisplayName)" -Data $permissions -ExportName "Kalendarz_$($mailbox.PrimarySmtpAddress)"
            }
            "Set" {
                $form = Show-HTFormDialog -Title "Uprawnienia kalendarza" -Description "Skrzynka: $($mailbox.PrimarySmtpAddress). Użyj 'Default', aby zmienić uprawnienia domyślne organizacji." -Fields @(
                    @{ Name = "User"; Label = "Użytkownik (e-mail lub Default)"; Required = $true }
                    @{ Name = "Rights"; Label = "Poziom"; Type = "Combo"; Options = @("Reviewer", "LimitedDetails", "AvailabilityOnly", "Author", "Editor", "PublishingEditor", "Owner"); Default = "Reviewer" }
                )
                if (-not $form) { return }
                Invoke-HTAction -Name "Uprawnienia kalendarza" -RequiredService "Exchange" -ScriptBlock {
                    Set-HTCalendarPermission -Identity $mailbox.Identity -User $form.User -AccessRights $form.Rights
                    Write-Log -Message "Kalendarz $($mailbox.PrimarySmtpAddress): $($form.User) -> $($form.Rights)" -Type "Info&Notification"
                }
            }
            "Remove" {
                $permissions = @(Invoke-HTAction -Name "Uprawnienia kalendarza" -RequiredService "Exchange" -ScriptBlock { Get-HTCalendarPermissions -Identity $mailbox.Identity })
                $candidates = @($permissions | Where-Object { $_.User -notin @("Default", "Anonymous", "Domyślne", "Anonimowe") })
                $selected = Show-HTSelectionDialog -Title "Usuń uprawnienia kalendarza" -MultiSelect -OkText "Usuń" -Items $candidates -Columns @(
                    @{ Text = "Użytkownik"; Property = "User"; Width = 320 }
                    @{ Text = "Prawa"; Property = "AccessRights"; Width = 200 }
                )
                if (-not $selected) { return }
                Invoke-HTAction -Name "Usuwanie uprawnień kalendarza" -RequiredService "Exchange" -ScriptBlock {
                    $ok = Invoke-HTForEach -Items @($selected) -Action { param($p) Remove-HTCalendarPermission -Identity $mailbox.Identity -User $p.User } -Describe { param($p) $p.User }
                    Write-Log -Message "Usunięto $ok uprawnień do kalendarza $($mailbox.PrimarySmtpAddress)" -Type "Info&Notification"
                }
            }
        }
    })

# Konwersja typu skrzynki
$HT_UI.MailboxesTab.Actions.Convert.Add_Click({
        $mailbox = Get-HTSelectedMailbox
        if (-not $mailbox) { return }

        $target = Show-HTChoiceDialog -Title "Konwersja - $($mailbox.DisplayName)" -Prompt "Obecny typ: $($mailbox.RecipientTypeDetails)`nWybierz typ docelowy:" -Choices @(
            @{ Key = "Shared"; Text = "Współdzielona (Shared)"; Icon = "shared-mail.png"; Description = "Nie wymaga licencji do 50 GB" }
            @{ Key = "Regular"; Text = "Użytkownika (Regular)"; Icon = "Email.png"; Description = "Wymaga licencji z Exchange Online" }
            @{ Key = "Room"; Text = "Sala (Room)"; Icon = "Organization.png" }
            @{ Key = "Equipment"; Text = "Sprzęt (Equipment)"; Icon = "Tools.png" }
        )
        if (-not $target) { return }
        if (-not (Show-HTConfirm -Message "Skonwertować skrzynkę $($mailbox.PrimarySmtpAddress) na typ $target?" -Title "Konwersja skrzynki")) { return }

        Invoke-HTAction -Name "Konwersja skrzynki" -RequiredService "Exchange" -ScriptBlock {
            Convert-HTMailboxType -Identity $mailbox.Identity -Type $target
            $mailbox.RecipientTypeDetails = switch ($target) { "Shared" { "SharedMailbox" } "Regular" { "UserMailbox" } "Room" { "RoomMailbox" } "Equipment" { "EquipmentMailbox" } }
            Write-Log -Message "Skonwertowano skrzynkę $($mailbox.PrimarySmtpAddress) na $target" -Type "Info&Notification"
            Invoke-HTDetailsReload -View $HT_UI.MailboxesTab
        }
    })

# Autoodpowiedź
$HT_UI.MailboxesTab.Actions.Autoresponder.Add_Click({
        $mailbox = Get-HTSelectedMailbox
        if (-not $mailbox) { return }

        $current = Invoke-HTAction -Name "Pobieranie autoodpowiedzi" -RequiredService "Exchange" -ScriptBlock { Get-HTMailboxAutoReply -Identity $mailbox.Identity }
        if (-not $current) { return }

        $state = "$($current.AutoReplyState)"
        $start = if ($current.StartTime -and $state -eq "Scheduled") { [datetime]$current.StartTime } else { (Get-Date).Date.AddHours(8) }
        $end = if ($current.EndTime -and $state -eq "Scheduled") { [datetime]$current.EndTime } else { (Get-Date).Date.AddDays(7).AddHours(17) }

        $form = Show-HTFormDialog -Title "Autoodpowiedź - $($mailbox.DisplayName)" -Width 640 -Fields @(
            @{ Name = "State"; Label = "Stan"; Type = "Combo"; Options = @("Disabled", "Enabled", "Scheduled"); Default = $state }
            @{ Name = "Start"; Label = "Od (dla Scheduled)"; Type = "Date"; Default = $start }
            @{ Name = "End"; Label = "Do (dla Scheduled)"; Type = "Date"; Default = $end }
            @{ Name = "Internal"; Label = "Wiadomość wewnętrzna"; Type = "Multiline"; Default = (ConvertFrom-HTAutoReplyHtml $current.InternalMessage) }
            @{ Name = "External"; Label = "Wiadomość zewnętrzna (puste = jak wewnętrzna)"; Type = "Multiline"; Default = (ConvertFrom-HTAutoReplyHtml $current.ExternalMessage) }
            @{ Name = "Audience"; Label = "Odbiorcy zewnętrzni"; Type = "Combo"; Options = @("All", "Known", "None"); Default = "$($current.ExternalAudience)" }
        )
        if (-not $form) { return }
        if ($form.State -ne "Disabled" -and -not $form.Internal) {
            Show-Dialog -Message "Podaj treść wiadomości." -Title "Autoodpowiedź" -Type "Warning" | Out-Null
            return
        }

        Invoke-HTAction -Name "Ustawianie autoodpowiedzi" -RequiredService "Exchange" -ScriptBlock {
            Set-HTMailboxAutoReply -Identity $mailbox.Identity -State $form.State -InternalMessage $form.Internal -ExternalMessage $form.External `
                -ExternalAudience $form.Audience -StartTime $form.Start -EndTime $form.End
            Write-Log -Message "Autoodpowiedź $($mailbox.PrimarySmtpAddress): $($form.State)" -Type "Info&Notification"
            Invoke-HTDetailsReload -View $HT_UI.MailboxesTab
        }
    })

# Przekierowanie
$HT_UI.MailboxesTab.Actions.Forwards.Add_Click({
        $mailbox = Get-HTSelectedMailbox
        if (-not $mailbox) { return }

        $form = Show-HTFormDialog -Title "Przekierowanie - $($mailbox.DisplayName)" -Description "Pozostaw adres pusty, aby wyłączyć przekierowanie. Przekierowanie na adres zewnętrzny może być blokowane przez zasady antyspamowe." -Fields @(
            @{ Name = "ForwardTo"; Label = "Przekieruj do (e-mail)"; Default = $mailbox.Forwarding; Validation = "Email" }
            @{ Name = "KeepCopy"; Label = "Zachowaj kopię w skrzynce"; Type = "Check"; Default = $true }
        )
        if (-not $form) { return }

        Invoke-HTAction -Name "Ustawianie przekierowania" -RequiredService "Exchange" -ScriptBlock {
            Set-HTMailboxForwarding -Identity $mailbox.Identity -ForwardTo $form.ForwardTo -KeepCopy $form.KeepCopy
            $mailbox.Forwarding = $form.ForwardTo
            $message = if ($form.ForwardTo) { "Przekierowanie $($mailbox.PrimarySmtpAddress) -> $($form.ForwardTo)" } else { "Wyłączono przekierowanie $($mailbox.PrimarySmtpAddress)" }
            Write-Log -Message $message -Type "Info&Notification"
            Invoke-HTDetailsReload -View $HT_UI.MailboxesTab
        }
    })

# Ukrycie / pokazanie w GAL
$HT_UI.MailboxesTab.Actions.HideFromGAL.Add_Click({
        $mailbox = Get-HTSelectedMailbox
        if (-not $mailbox) { return }

        $hide = -not $mailbox.HiddenFromGAL
        $question = if ($hide) { "Ukryć skrzynkę $($mailbox.PrimarySmtpAddress) w globalnej liście adresów?" } else { "Pokazać skrzynkę $($mailbox.PrimarySmtpAddress) w globalnej liście adresów?" }
        if (-not (Show-HTConfirm -Message $question -Title "Globalna lista adresów")) { return }

        Invoke-HTAction -Name "Zmiana widoczności w GAL" -RequiredService "Exchange" -ScriptBlock {
            Set-HTMailboxHiddenFromGAL -Identity $mailbox.Identity -Hidden $hide
            $mailbox.HiddenFromGAL = $hide
            Write-Log -Message "Skrzynka $($mailbox.PrimarySmtpAddress) - ukryta w GAL: $hide" -Type "Info&Notification"
            Invoke-HTDetailsReload -View $HT_UI.MailboxesTab
        }
    })

# Archiwum
$HT_UI.MailboxesTab.Actions.EnableArchive.Add_Click({
        $mailbox = Get-HTSelectedMailbox
        if (-not $mailbox) { return }

        $choice = Show-HTChoiceDialog -Title "Archiwum - $($mailbox.DisplayName)" -Prompt $(if ($mailbox.Archive) { "Archiwum jest już włączone." } else { "Archiwum jest wyłączone." }) -Choices @(
            @{ Key = "Enable"; Text = "Włącz archiwum"; Icon = "shared-mail.png" }
            @{ Key = "AutoExpand"; Text = "Włącz archiwum auto-rozszerzalne"; Icon = "filing-cabinet.png"; Description = "Wymaga odpowiedniej licencji (np. E3/E5)" }
        )
        if (-not $choice) { return }

        Invoke-HTAction -Name "Włączanie archiwum" -RequiredService "Exchange" -ScriptBlock {
            Enable-HTMailboxArchive -Identity $mailbox.Identity -AutoExpanding:($choice -eq "AutoExpand")
            $mailbox.Archive = $true
            Write-Log -Message "Włączono archiwum ($choice) dla $($mailbox.PrimarySmtpAddress)" -Type "Info&Notification"
            Invoke-HTDetailsReload -View $HT_UI.MailboxesTab
        }
    })

# Reguły skrzynki odbiorczej
$HT_UI.MailboxesTab.Actions.InboxRules.Add_Click({
        $mailbox = Get-HTSelectedMailbox
        if (-not $mailbox) { return }
        $rules = @(Invoke-HTAction -Name "Pobieranie reguł" -RequiredService "Exchange" -ScriptBlock { Get-HTInboxRules -Identity $mailbox.Identity })
        if ($rules.Count -eq 0) {
            Show-Dialog -Message "Skrzynka $($mailbox.PrimarySmtpAddress) nie ma reguł." -Title "Reguły skrzynki" | Out-Null
            return
        }
        $suspicious = @($rules | Where-Object { $_.ForwardTo -or $_.RedirectTo -or $_.DeleteMessage })
        $description = if ($suspicious.Count -gt 0) { "⚠ Reguły przekierowujące lub usuwające wiadomości: $($suspicious.Count) - sprawdź, czy są zamierzone." } else { "" }
        Show-HTDataViewer -Title "Reguły skrzynki - $($mailbox.DisplayName)" -Data $rules -Description $description -ExportName "Reguly_$($mailbox.PrimarySmtpAddress)"
    })

# Śledzenie wiadomości
$HT_UI.MailboxesTab.Actions.MessageTrace.Add_Click({
        $mailbox = Get-HTSelectedMailbox
        if (-not $mailbox) { return }

        $form = Show-HTFormDialog -Title "Śledzenie wiadomości" -Description "Skrzynka: $($mailbox.PrimarySmtpAddress)" -OkText "Szukaj" -Fields @(
            @{ Name = "Direction"; Label = "Kierunek"; Type = "Combo"; Options = @("Odebrane", "Wysłane") }
            @{ Name = "Days"; Label = "Ostatnie dni (1-10)"; Type = "Number"; Default = 2; Min = 1; Max = 10 }
        )
        if (-not $form) { return }
        $direction = if ($form.Direction -eq "Wysłane") { "Sent" } else { "Received" }

        $trace = @(Invoke-HTAction -Name "Śledzenie wiadomości" -RequiredService "Exchange" -ScriptBlock {
                Get-HTMessageTrace -Address $mailbox.PrimarySmtpAddress -Direction $direction -Days $form.Days
            })
        Show-HTDataViewer -Title "Śledzenie wiadomości ($($form.Direction)) - $($mailbox.PrimarySmtpAddress)" -Data $trace -ExportName "MessageTrace_$($mailbox.PrimarySmtpAddress)" -Columns @(
            @{ Text = "Data"; Property = "Received"; Width = 130 }
            @{ Text = "Nadawca"; Property = "Sender"; Width = 220 }
            @{ Text = "Odbiorca"; Property = "Recipient"; Width = 220 }
            @{ Text = "Temat"; Property = "Subject"; Width = 280 }
            @{ Text = "Status"; Property = "Status"; Width = 90 }
        )
    })

# Urządzenia mobilne
$HT_UI.MailboxesTab.Actions.MobileDevices.Add_Click({
        $mailbox = Get-HTSelectedMailbox
        if (-not $mailbox) { return }
        $devices = @(Invoke-HTAction -Name "Urządzenia mobilne" -RequiredService "Exchange" -ScriptBlock { Get-HTMailboxMobileDevices -Identity $mailbox.Identity })
        Show-HTDataViewer -Title "Urządzenia mobilne - $($mailbox.DisplayName)" -Data $devices -ExportName "Mobile_$($mailbox.PrimarySmtpAddress)"
    })

# Eksport listy
$HT_UI.MailboxesTab.Actions.Export.Add_Click({
        Export-HTListView -ListView $HT_UI.MailboxesTab.List -Name "Skrzynki"
    })
