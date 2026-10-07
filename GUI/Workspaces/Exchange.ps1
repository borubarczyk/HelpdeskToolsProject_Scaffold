# Przestrzeń robocza: Exchange Online - skrzynki, uprawnienia, poczta, zgodność, raporty

Register-HTWorkspace -Key 'Exchange' -Title 'Exchange' -Icon 'E715' -Panel 'mailboxes' -Service 'Exchange' `
    -Description 'Skrzynki Exchange Online: uprawnienia, kalendarze, autoodpowiedzi, reguły, kwarantanna i raporty' `
    -Categories @('Skrzynka', 'Uprawnienia', 'Poczta', 'Grupy i adresy', 'Zgodność', 'Raporty')

$panel = New-HTTargetPanel -Key 'mailboxes' -Title 'Skrzynki' -Placeholder 'Szukaj (nazwa, adres, typ: shared, room)…' -EmptyIcon 'E715' `
    -EmptyText 'Połącz z Exchange Online i kliknij «Wczytaj».' -Describe {
    param($x)
    $types = @{ UserMailbox = 'użytkownika'; SharedMailbox = 'współdzielona'; RoomMailbox = 'sala'; EquipmentMailbox = 'zasób' }
    $type = $types[$x.RecipientTypeDetails] ?? $x.RecipientTypeDetails
    $sub = "$($x.PrimarySmtpAddress) • $type"
    if ($x.Forwarding) { $sub += " • → $($x.Forwarding)" }
    @{ Key = $x.PrimarySmtpAddress; Title = $x.DisplayName; Sub = $sub
        Dot = $(if ($x.Forwarding) { 'warn' } elseif ($x.RecipientTypeDetails -eq 'UserMailbox') { 'ok' } else { 'info' })
        Search = "$($x.UserPrincipalName) $($x.RecipientTypeDetails) $type $(if ($x.HiddenFromGAL) { 'ukryta' })" }
}
Add-HTPanelLoader -Panel $panel -Service 'Exchange' -Loader { param($p) Get-HTMailboxes } | Out-Null
Add-HTPanelHint -Panel $panel -Text 'Kropka: zielona - użytkownika, niebieska - współdzielona/sala/zasób, żółta - ustawione przekierowanie.' | Out-Null

function Get-HTMailboxLabel { param($x) [string]$x.PrimarySmtpAddress }

#region Skrzynka
Register-HTModule -Workspace 'Exchange' -Category 'Skrzynka' -Key 'exo.details' -Title 'Szczegóły skrzynki' -Icon 'E8A1' `
    -Description 'Typ, rozmiar i limity, archiwum, Litigation Hold, przekierowanie, autoodpowiedź, aliasy i delegaci.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż szczegóły' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Szczegóły skrzynki' -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) ConvertTo-HTDetailRows -Data (Get-HTMailboxDetail -Identity $t.PrimarySmtpAddress) }
    } | Out-Null
}

Register-HTModule -Workspace 'Exchange' -Category 'Skrzynka' -Key 'exo.usage' -Title 'Rozmiar i limity' -Icon 'EDA2' `
    -Description 'Rozmiar, liczba elementów, wykorzystanie limitu, archiwum i ostatnia aktywność. Wyróżnione - ponad 85% limitu.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Sprawdź rozmiar' -Icon 'EDA2' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Rozmiar skrzynek' -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Get-HTMailboxUsage -Identity $t.PrimarySmtpAddress }
    } | Out-Null
    Add-HTLabel -Parent $row -Hint -Text 'Zaznacz wszystkie skrzynki na liście, aby uzyskać raport rozmiarów całej organizacji.' | Out-Null
}

Register-HTModule -Workspace 'Exchange' -Category 'Skrzynka' -Key 'exo.type' -Title 'Typ i widoczność' -Icon 'E8AB' `
    -Description 'Konwersja na skrzynkę współdzieloną / użytkownika / salę, ukrycie w książce adresowej, archiwum online.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Typ skrzynki'
    $m.C.Type = Add-HTComboBox -Parent $row -Items @('Shared', 'Regular', 'Room', 'Equipment') -Width 140
    Add-HTButton -Parent $row -Module $m -Text 'Konwertuj' -Icon 'E8AB' -Primary -OnClick {
        param($m)
        $type = Get-HTComboText $m.C.Type
        Invoke-HTTargetAction -Module $m -Name "Konwersja na $type" -Confirm "Zmienić typ wybranych skrzynek na $($type)?" -Label { param($t) Get-HTMailboxLabel $t } -Action {
            param($t)
            Convert-HTMailboxType -Identity $t.PrimarySmtpAddress -Type $type
            "Typ: $type"
        }
    } | Out-Null
    $row2 = Add-HTToolbarRow -Module $m -Title 'Książka adresowa'
    Add-HTButton -Parent $row2 -Module $m -Text 'Ukryj w GAL' -Icon 'ED1A' -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Ukrycie w GAL' -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Set-HTMailboxHiddenFromGAL -Identity $t.PrimarySmtpAddress -Hidden $true; 'Ukryta' }
    } | Out-Null
    Add-HTButton -Parent $row2 -Module $m -Text 'Pokaż w GAL' -Icon 'E7B3' -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Pokazanie w GAL' -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Set-HTMailboxHiddenFromGAL -Identity $t.PrimarySmtpAddress -Hidden $false; 'Widoczna' }
    } | Out-Null
    $row3 = Add-HTToolbarRow -Module $m -Title 'Archiwum'
    $m.C.AutoExpand = Add-HTCheckBox -Parent $row3 -Text 'Archiwum automatycznie rozszerzane'
    Add-HTButton -Parent $row3 -Module $m -Text 'Włącz archiwum' -Icon 'E7B8' -OnClick {
        param($m)
        $auto = Test-HTChecked $m.C.AutoExpand
        Invoke-HTTargetAction -Module $m -Name 'Włączenie archiwum' -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Enable-HTMailboxArchive -Identity $t.PrimarySmtpAddress -AutoExpanding:$auto; 'Archiwum włączone' }
    } | Out-Null
}

Register-HTModule -Workspace 'Exchange' -Category 'Skrzynka' -Key 'exo.mobile' -Title 'Urządzenia mobilne' -Icon 'E8EA' `
    -Description 'Telefony i tablety synchronizujące pocztę (ActiveSync / Outlook Mobile). Usunięcie powiązania wymusza ponowną konfigurację.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż urządzenia' -Icon 'E8EA' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Urządzenia mobilne' -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Get-HTMailboxMobileDevices -Identity $t.PrimarySmtpAddress }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Usuń powiązanie urządzenia' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Usunięcie urządzenia mobilnego' -Rows @($rows | Where-Object { $_.DeviceIdentity }) -Danger -Confirm 'Usunąć powiązanie zaznaczonych urządzeń ze skrzynką?' `
            -Label { param($r) "$($r.Device) ($($r.Model))" } -Action { param($r) Remove-HTMailboxMobileDevice -Identity $r.DeviceIdentity } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}
#endregion

#region Uprawnienia
Register-HTModule -Workspace 'Exchange' -Category 'Uprawnienia' -Key 'exo.perms' -Title 'Uprawnienia do skrzynki' -Icon 'E8D7' `
    -Description 'Pełny dostęp, Wyślij jako i Wyślij w imieniu. Prawy przycisk na wierszu - odebranie uprawnienia.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż uprawnienia' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Uprawnienia do skrzynek' -AlwaysShowObject -Label { param($t) Get-HTMailboxLabel $t } -Action {
            param($t)
            foreach ($p in @(Get-HTMailboxPermissions -Identity $t.PrimarySmtpAddress)) { [PSCustomObject]@{ Uprawnienie = $p.Type; Użytkownik = $p.User; Prawa = $p.AccessRights } }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Nadaj uprawnienia…' -Icon 'E8FA' -OnClick {
        param($m)
        $targets = @(Get-HTTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $form = Show-HTFormDialog -Title 'Nadaj uprawnienia' -Description "Skrzynki: $($targets.Count)" -Icon 'E8D7' -OkText 'Nadaj' -Fields @(
            @{ Name = 'User'; Label = 'Użytkownicy (adres e-mail, kilka - jeden w linii)'; Type = 'Multiline'; Required = $true; Height = 70 }
            @{ Name = 'Full'; Label = 'Pełny dostęp (FullAccess)'; Type = 'Check'; Default = $true }
            @{ Name = 'AutoMap'; Label = 'Automatyczne dodanie skrzynki w Outlooku (AutoMapping)'; Type = 'Check'; Default = $true }
            @{ Name = 'SendAs'; Label = 'Wyślij jako (SendAs)'; Type = 'Check' }
            @{ Name = 'OnBehalf'; Label = 'Wyślij w imieniu (SendOnBehalf)'; Type = 'Check' }
        )
        if (-not $form) { return }
        $users = @(Split-HTInputList $form.User)
        $types = @()
        if ($form.Full) { $types += 'FullAccess' }
        if ($form.SendAs) { $types += 'SendAs' }
        if ($form.OnBehalf) { $types += 'SendOnBehalf' }
        if ($types.Count -eq 0) { Show-HTWarning 'Wybierz rodzaj uprawnień.'; return }
        Invoke-HTTargetAction -Module $m -Name 'Nadanie uprawnień' -Targets $targets -Label { param($t) Get-HTMailboxLabel $t } -Action {
            param($t)
            foreach ($u in $users) { Add-HTMailboxPermission -Identity $t.PrimarySmtpAddress -User $u -Type $types -AutoMapping $form.AutoMap }
            "$($types -join ', ') dla: $($users -join ', ')"
        }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Odbierz uprawnienie' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Odebranie uprawnień' -Rows @($rows | Where-Object { $_.Uprawnienie }) -Danger -Confirm 'Odebrać zaznaczone uprawnienia?' `
            -Label { param($r) "$($r.Obiekt): $($r.Uprawnienie) - $($r.Użytkownik)" } -Action { param($r) Remove-HTMailboxPermission -Identity $r.__target.PrimarySmtpAddress -User $r.Użytkownik -Type $r.Uprawnienie } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}

Register-HTModule -Workspace 'Exchange' -Category 'Uprawnienia' -Key 'exo.access' -Title 'Dostęp użytkownika' -Icon 'E716' `
    -Description 'Do których skrzynek ma dostęp wskazany użytkownik (FullAccess, SendAs, SendOnBehalf)? Przegląd wszystkich skrzynek może potrwać kilka minut.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Użytkownik'
    $m.C.User = Add-HTTextBox -Parent $row -Width 300 -Placeholder 'adres e-mail (puste = zaznaczona skrzynka)'
    Add-HTButton -Parent $row -Module $m -Text 'Sprawdź dostęp' -Icon 'E721' -Primary -OnClick {
        param($m)
        $user = $m.C.User.Text.Trim()
        if (-not $user) {
            $t = @(Get-HTTargets -Module $m -Single)[0]
            if (-not $t) { return }
            $user = $t.PrimarySmtpAddress
        }
        Invoke-HTQuery -Module $m -Name "Dostęp użytkownika $user" -ScriptBlock {
            Get-HTUserMailboxAccess -User $user -OnProgress { param($i, $total, $name) if ($i % 5 -eq 0 -or $i -eq $total) { Set-HTProgress -Value $i -Maximum $total -Text "Sprawdzanie skrzynek [$i/$total] $name" } }
        }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Odbierz uprawnienie' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        $user = $m.C.User.Text.Trim()
        if (-not $user) { Show-HTWarning 'Wpisz adres użytkownika w polu powyżej.'; return }
        Invoke-HTRowAction -Module $m -Name 'Odebranie uprawnień' -Rows $rows -Danger -Confirm "Odebrać użytkownikowi $user zaznaczone uprawnienia?" `
            -Label { param($r) "$($r.Adres): $($r.Uprawnienie)" } -Action { param($r) Remove-HTMailboxPermission -Identity $r.Adres -User $user -Type $r.Uprawnienie }
    }
}

Register-HTModule -Workspace 'Exchange' -Category 'Uprawnienia' -Key 'exo.calendar' -Title 'Kalendarz' -Icon 'E787' `
    -Description 'Uprawnienia do kalendarza (Reviewer, Editor, AvailabilityOnly…). Nazwa folderu wykrywana automatycznie (Kalendarz / Calendar).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż uprawnienia' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Uprawnienia kalendarza' -AlwaysShowObject -Label { param($t) Get-HTMailboxLabel $t } -Action {
            param($t)
            foreach ($p in @(Get-HTCalendarPermissions -Identity $t.PrimarySmtpAddress)) { [PSCustomObject]@{ Użytkownik = $p.User; Uprawnienia = $p.AccessRights; Delegat = $p.SharingPermissionFlags; Folder = $p.Folder } }
        }
    } | Out-Null
    $row2 = Add-HTToolbarRow -Module $m -Title 'Nadaj'
    $m.C.User = Add-HTTextBox -Parent $row2 -Width 260 -Placeholder 'Użytkownik (e-mail) lub Default'
    $m.C.Level = Add-HTComboBox -Parent $row2 -Items @('Reviewer', 'LimitedDetails', 'AvailabilityOnly', 'Author', 'Editor', 'PublishingEditor', 'Owner', 'None') -Width 160
    Add-HTButton -Parent $row2 -Module $m -Text 'Ustaw' -Icon 'E73E' -OnClick {
        param($m)
        $user = $m.C.User.Text.Trim()
        if (-not $user) { Show-HTWarning 'Podaj użytkownika.'; return }
        $level = Get-HTComboText $m.C.Level
        Invoke-HTTargetAction -Module $m -Name 'Uprawnienia kalendarza' -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Set-HTCalendarPermission -Identity $t.PrimarySmtpAddress -User $user -AccessRights $level; "$user : $level" }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Usuń uprawnienie' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Usunięcie uprawnień kalendarza' -Rows @($rows | Where-Object { $_.Użytkownik -notin 'Default', 'Anonymous', 'Domyślne', 'Anonimowe' }) -Confirm 'Usunąć zaznaczone uprawnienia do kalendarza?' `
            -Label { param($r) "$($r.Obiekt): $($r.Użytkownik)" } -Action { param($r) Remove-HTCalendarPermission -Identity $r.__target.PrimarySmtpAddress -User $r.Użytkownik } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}
#endregion

#region Poczta
Register-HTModule -Workspace 'Exchange' -Category 'Poczta' -Key 'exo.autoreply' -Title 'Autoodpowiedź' -Icon 'E8BD' `
    -Description 'Odpowiedzi automatyczne (poza biurem): podgląd, włączenie, zaplanowanie w czasie i wyłączenie.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż stan' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Autoodpowiedzi' -AlwaysShowObject -Label { param($t) Get-HTMailboxLabel $t } -Action {
            param($t)
            $a = Get-HTMailboxAutoReply -Identity $t.PrimarySmtpAddress
            [PSCustomObject]@{ Stan = "$($a.AutoReplyState)"; Od = $(if ("$($a.AutoReplyState)" -eq 'Scheduled') { $a.StartTime }); Do = $(if ("$($a.AutoReplyState)" -eq 'Scheduled') { $a.EndTime })
                'Odbiorcy zewn.' = "$($a.ExternalAudience)"; Wewnętrzna = (ConvertFrom-HTAutoReplyHtml $a.InternalMessage); Zewnętrzna = (ConvertFrom-HTAutoReplyHtml $a.ExternalMessage)
                __flag = $(if ("$($a.AutoReplyState)" -eq 'Disabled') { 'muted' } else { '' }) }
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Ustaw…' -Icon 'E70F' -OnClick {
        param($m)
        $targets = @(Get-HTTargets -Module $m)
        if ($targets.Count -eq 0) { return }
        $current = $null
        if ($targets.Count -eq 1) { try { $current = Get-HTMailboxAutoReply -Identity $targets[0].PrimarySmtpAddress } catch { $current = $null } }
        $form = Show-HTFormDialog -Title 'Autoodpowiedź' -Description "Skrzynki: $($targets.Count)" -Icon 'E8BD' -Width 640 -Fields @(
            @{ Name = 'State'; Label = 'Tryb'; Type = 'Combo'; Options = @('Enabled', 'Scheduled', 'Disabled'); Default = $(if ($current) { "$($current.AutoReplyState)" } else { 'Enabled' }) }
            @{ Name = 'Start'; Label = 'Od (dla Scheduled)'; Type = 'Date'; Optional = $true; Default = $(if ($current -and "$($current.AutoReplyState)" -eq 'Scheduled') { $current.StartTime } else { (Get-Date).Date.AddHours(8) }) }
            @{ Name = 'End'; Label = 'Do (dla Scheduled)'; Type = 'Date'; Optional = $true; Default = $(if ($current -and "$($current.AutoReplyState)" -eq 'Scheduled') { $current.EndTime } else { (Get-Date).Date.AddDays(7).AddHours(17) }) }
            @{ Name = 'Internal'; Label = 'Wiadomość wewnętrzna'; Type = 'Multiline'; Default = $(if ($current) { ConvertFrom-HTAutoReplyHtml $current.InternalMessage }) }
            @{ Name = 'External'; Label = 'Wiadomość zewnętrzna (puste = jak wewnętrzna)'; Type = 'Multiline'; Default = $(if ($current) { ConvertFrom-HTAutoReplyHtml $current.ExternalMessage }) }
            @{ Name = 'Audience'; Label = 'Odbiorcy zewnętrzni'; Type = 'Combo'; Options = @('All', 'Known', 'None'); Default = $(if ($current) { "$($current.ExternalAudience)" } else { 'All' }) }
        )
        if (-not $form) { return }
        if ($form.State -ne 'Disabled' -and -not $form.Internal) { Show-HTWarning 'Wpisz treść wiadomości.'; return }
        Invoke-HTTargetAction -Module $m -Name 'Autoodpowiedź' -Targets $targets -Label { param($t) Get-HTMailboxLabel $t } -Action {
            param($t)
            Set-HTMailboxAutoReply -Identity $t.PrimarySmtpAddress -State $form.State -InternalMessage $form.Internal -ExternalMessage $form.External -ExternalAudience $form.Audience -StartTime $form.Start -EndTime $form.End
            "Tryb: $($form.State)"
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Wyłącz' -Icon 'E711' -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Wyłączenie autoodpowiedzi' -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Set-HTMailboxAutoReply -Identity $t.PrimarySmtpAddress -State Disabled; 'Wyłączona' }
    } | Out-Null
}

Register-HTModule -Workspace 'Exchange' -Category 'Poczta' -Key 'exo.forward' -Title 'Przekierowanie' -Icon 'E89C' `
    -Description 'Przekierowanie poczty na inny adres (z kopią w skrzynce lub bez) i jego usunięcie.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Przekieruj do'
    $m.C.To = Add-HTTextBox -Parent $row -Width 280 -Placeholder 'adres@domena.pl'
    $m.C.Keep = Add-HTCheckBox -Parent $row -Text 'Zachowaj kopię w skrzynce' -Checked $true
    Add-HTButton -Parent $row -Module $m -Text 'Ustaw' -Icon 'E89C' -Primary -OnClick {
        param($m)
        $to = $m.C.To.Text.Trim()
        if (-not (Test-HTInputValue -Value $to -ValidationType Email)) { Show-HTWarning 'Podaj prawidłowy adres e-mail.'; return }
        $keep = Test-HTChecked $m.C.Keep
        Invoke-HTTargetAction -Module $m -Name 'Przekierowanie' -Confirm "Przekierować pocztę do $($to)?" -Label { param($t) Get-HTMailboxLabel $t } -Action {
            param($t)
            Set-HTMailboxForwarding -Identity $t.PrimarySmtpAddress -ForwardTo $to -KeepCopy $keep
            $t.Forwarding = $to
            Update-HTTargetItem -Panel (Get-HTPanel 'mailboxes') -Item $t
            "Do: $to$(if ($keep) { ' (z kopią)' })"
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Usuń przekierowanie' -Icon 'E711' -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Usunięcie przekierowania' -Label { param($t) Get-HTMailboxLabel $t } -Action {
            param($t)
            Set-HTMailboxForwarding -Identity $t.PrimarySmtpAddress -ForwardTo ''
            $t.Forwarding = ''
            Update-HTTargetItem -Panel (Get-HTPanel 'mailboxes') -Item $t
            'Usunięto'
        }
    } | Out-Null
}

Register-HTModule -Workspace 'Exchange' -Category 'Poczta' -Key 'exo.rules' -Title 'Reguły skrzynki' -Icon 'E71C' `
    -Description 'Reguły Outlooka użytkownika. Wyróżnione - przekazujące lub usuwające pocztę (częsty ślad przejęcia konta).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż reguły' -Icon 'E71C' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Reguły skrzynki' -AlwaysShowObject -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Get-HTInboxRules -Identity $t.PrimarySmtpAddress }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Wyłącz regułę' -Icon 'E711' -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Wyłączenie reguły' -Rows @($rows | Where-Object { $_.RuleIdentity }) -Label { param($r) "$($r.Obiekt): $($r.Name)" } `
            -Action { param($r) Disable-HTInboxRule -Mailbox $r.__target.PrimarySmtpAddress -Identity $r.RuleIdentity } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
    Add-HTRowAction -Module $m -Text 'Usuń regułę' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Usunięcie reguły' -Rows @($rows | Where-Object { $_.RuleIdentity }) -Danger -Confirm 'Usunąć zaznaczone reguły?' -Label { param($r) "$($r.Obiekt): $($r.Name)" } `
            -Action { param($r) Remove-HTInboxRule -Mailbox $r.__target.PrimarySmtpAddress -Identity $r.RuleIdentity } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}

Register-HTModule -Workspace 'Exchange' -Category 'Poczta' -Key 'exo.trace' -Title 'Śledzenie wiadomości' -Icon 'E721' `
    -Description 'Czy wiadomość dotarła? Wyniki śledzenia (do 10 dni wstecz) dla adresu wpisanego lub zaznaczonych skrzynek.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Parametry'
    $m.C.Address = Add-HTTextBox -Parent $row -Width 260 -Placeholder 'adres (puste = zaznaczone skrzynki)'
    $m.C.Direction = Add-HTSegmented -Parent $row -Items @('Odebrane', 'Wysłane')
    Add-HTLabel -Parent $row -Text 'Dni:' | Out-Null
    $m.C.Days = Add-HTNumeric -Parent $row -Value 2 -Minimum 1 -Maximum 10
    Add-HTButton -Parent $row -Module $m -Text 'Szukaj' -Icon 'E721' -Primary -OnClick {
        param($m)
        $direction = if ((Get-HTSegmentIndex $m.C.Direction) -eq 1) { 'Sent' } else { 'Received' }
        $days = Get-HTNum $m.C.Days
        $address = $m.C.Address.Text.Trim()
        if ($address) {
            Invoke-HTQuery -Module $m -Name 'Śledzenie wiadomości' -ScriptBlock { Get-HTMessageTrace -Address $address -Direction $direction -Days $days }
        }
        else {
            Invoke-HTTargetQuery -Module $m -Name 'Śledzenie wiadomości' -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Get-HTMessageTrace -Address $t.PrimarySmtpAddress -Direction $direction -Days $days }
        }
    } | Out-Null
}
#endregion

#region Grupy i adresy
Register-HTModule -Workspace 'Exchange' -Category 'Grupy i adresy' -Key 'exo.aliases' -Title 'Adresy e-mail' -Icon 'E910' `
    -Description 'Aliasy (dodatkowe adresy) skrzynki. Dla skrzynek synchronizowanych z AD adresy zmienia się w lokalnym AD (proxyAddresses).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż adresy' -Icon 'E8A1' -Primary -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Adresy e-mail' -AlwaysShowObject -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Get-HTMailboxAddresses -Identity $t.PrimarySmtpAddress }
    } | Out-Null
    $m.C.Alias = Add-HTTextBox -Parent $row -Width 260 -Placeholder 'nowy.alias@domena.pl'
    Add-HTButton -Parent $row -Module $m -Text 'Dodaj alias' -Icon 'E710' -OnClick {
        param($m)
        $alias = $m.C.Alias.Text.Trim()
        $t = @(Get-HTTargets -Module $m -Single)[0]
        if (-not $t) { return }
        Invoke-HTTargetAction -Module $m -Name 'Dodanie aliasu' -Targets @($t) -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Add-HTMailboxAddress -Identity $t.PrimarySmtpAddress -Address $alias; "Dodano: $alias" }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Usuń adres' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Usunięcie adresu' -Rows @($rows | Where-Object { $_.Wartość }) -Confirm 'Usunąć zaznaczone adresy?' -Label { param($r) "$($r.Obiekt): $($r.Adres)" } `
            -Action { param($r) Remove-HTMailboxAddress -Identity $r.__target.PrimarySmtpAddress -Value $r.Wartość } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}

Register-HTModule -Workspace 'Exchange' -Category 'Grupy i adresy' -Key 'exo.dl' -Title 'Grupy dystrybucyjne' -Icon 'E902' `
    -Description 'Listy dystrybucyjne: członkowie, przynależność skrzynek oraz dodawanie / usuwanie zaznaczonych skrzynek.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Wszystkie grupy' -Icon 'E902' -Primary -OnClick { param($m) Invoke-HTQuery -Module $m -Name 'Grupy dystrybucyjne' -ScriptBlock { Get-HTDistributionGroups } } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Grupy zaznaczonych skrzynek' -Icon 'E716' -OnClick {
        param($m)
        Invoke-HTTargetQuery -Module $m -Name 'Przynależność do grup' -AlwaysShowObject -Label { param($t) Get-HTMailboxLabel $t } -Action {
            param($t)
            foreach ($g in @(Get-HTRecipientGroups -Identity $t.PrimarySmtpAddress)) { [PSCustomObject]@{ Nazwa = $g.Grupa; Adres = $g.Adres; Typ = $g.Typ; Identity = $g.Adres } }
        }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Pokaż członków' -Icon 'E716' -Action {
        param($m, $rows)
        $g = @($rows)[0]
        Set-HTBusy -Busy $true -Text "Członkowie $($g.Nazwa)…"
        try { $members = @(Get-HTDistributionGroupMembers -Identity $g.Identity) } finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        Show-HTDataViewer -Title "Członkowie: $($g.Nazwa)" -Description "$($members.Count) członków" -Data $members -ExportName "czlonkowie_$($g.Nazwa)"
    }
    Add-HTRowAction -Module $m -Text 'Dodaj zaznaczone skrzynki do grupy' -Icon 'E710' -Action {
        param($m, $rows)
        $mailboxes = @(Get-HTTargets -Module $m)
        if ($mailboxes.Count -eq 0) { return }
        foreach ($g in @($rows)) {
            Invoke-HTRowAction -Module $m -Name "Dodanie do $($g.Nazwa)" -Rows $mailboxes -Confirm "Dodać $($mailboxes.Count) skrzynek do grupy $($g.Nazwa)?" -Label { param($r) Get-HTMailboxLabel $r } `
                -Action { param($r) Add-HTDistributionGroupMember -Group $g.Identity -Member $r.PrimarySmtpAddress }
        }
    }
    Add-HTRowAction -Module $m -Text 'Usuń zaznaczone skrzynki z grupy' -Icon 'E738' -Danger -Action {
        param($m, $rows)
        $mailboxes = @(Get-HTTargets -Module $m)
        if ($mailboxes.Count -eq 0) { return }
        foreach ($g in @($rows)) {
            Invoke-HTRowAction -Module $m -Name "Usunięcie z $($g.Nazwa)" -Rows $mailboxes -Danger -Confirm "Usunąć $($mailboxes.Count) skrzynek z grupy $($g.Nazwa)?" -Label { param($r) Get-HTMailboxLabel $r } `
                -Action { param($r) Remove-HTDistributionGroupMember -Group $g.Identity -Member $r.PrimarySmtpAddress }
        }
    }
}
#endregion

#region Zgodność
Register-HTModule -Workspace 'Exchange' -Category 'Zgodność' -Key 'exo.quarantine' -Title 'Kwarantanna' -Icon 'EA18' -Service 'Exchange' `
    -Description 'Wiadomości zatrzymane przez filtr spamu / phishingu / malware. Zwolnienie, podgląd treści i usunięcie (prawy przycisk).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Zakres'
    $m.C.Scope = Add-HTSegmented -Parent $row -Items @('Zaznaczone skrzynki', 'Cała organizacja')
    Add-HTLabel -Parent $row -Text 'Dni:' | Out-Null
    $m.C.Days = Add-HTNumeric -Parent $row -Value 7 -Minimum 1 -Maximum 30
    $m.C.Sender = Add-HTTextBox -Parent $row -Width 220 -Placeholder 'Nadawca (opcjonalnie)'
    Add-HTButton -Parent $row -Module $m -Text 'Pokaż' -Icon 'E72C' -Primary -OnClick {
        param($m)
        $days = Get-HTNum $m.C.Days
        $fromAddress = $m.C.Sender.Text.Trim()
        $recipients = @()
        if ((Get-HTSegmentIndex $m.C.Scope) -eq 0) {
            $recipients = @(Get-HTTargets -Module $m | ForEach-Object { $_.PrimarySmtpAddress })
            if ($recipients.Count -eq 0) { return }
        }
        Invoke-HTQuery -Module $m -Name 'Kwarantanna' -ScriptBlock { Get-HTQuarantineMessages -Recipients $recipients -Days $days -SenderAddress $fromAddress }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Podgląd treści' -Icon 'E8A1' -Action {
        param($m, $rows)
        $r = @($rows)[0]
        Set-HTBusy -Busy $true -Text 'Pobieranie wiadomości…'
        try { $text = Get-HTQuarantinePreview -Identity $r.Identity } finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        Show-HTTextDialog -Title "Kwarantanna: $($r.Temat)" -Subtitle $r.Nadawca -Text $text
    }
    Add-HTRowAction -Module $m -Text 'Zwolnij do odbiorców' -Icon 'E73E' -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Zwolnienie z kwarantanny' -Rows $rows -Confirm 'Zwolnić zaznaczone wiadomości do wszystkich odbiorców?' -Label { param($r) "$($r.Nadawca): $($r.Temat)" } -Action { param($r) Invoke-HTQuarantineRelease -Identity $r.Identity }
    }
    Add-HTRowAction -Module $m -Text 'Zwolnij i zezwól nadawcy' -Icon 'E8FB' -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Zwolnienie i zezwolenie' -Rows $rows -Confirm 'Zwolnić wiadomości i dodać nadawców do listy dozwolonych?' -Label { param($r) "$($r.Nadawca): $($r.Temat)" } -Action { param($r) Invoke-HTQuarantineRelease -Identity $r.Identity -AllowSender }
    }
    Add-HTRowAction -Module $m -Text 'Usuń z kwarantanny' -Icon 'E74D' -Danger -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Usunięcie z kwarantanny' -Rows $rows -Danger -Confirm 'Trwale usunąć zaznaczone wiadomości?' -Label { param($r) "$($r.Nadawca): $($r.Temat)" } -Action { param($r) Remove-HTQuarantineMessage -Identity $r.Identity }
    }
}

Register-HTModule -Workspace 'Exchange' -Category 'Zgodność' -Key 'exo.recover' -Title 'Odzyskiwanie elementów' -Icon 'E777' `
    -Description 'Przywracanie usuniętych wiadomości i elementów z folderu Elementy możliwe do odzyskania (wymaga roli Mailbox Import Export).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Filtr'
    Add-HTLabel -Parent $row -Text 'Usunięte w ciągu dni:' | Out-Null
    $m.C.Days = Add-HTNumeric -Parent $row -Value 14 -Minimum 1 -Maximum 90
    $m.C.Subject = Add-HTTextBox -Parent $row -Width 240 -Placeholder 'Temat zawiera (opcjonalnie)'
    Add-HTButton -Parent $row -Module $m -Text 'Szukaj' -Icon 'E721' -Primary -OnClick {
        param($m)
        $days = Get-HTNum $m.C.Days
        $subject = $m.C.Subject.Text.Trim()
        Invoke-HTTargetQuery -Module $m -Name 'Elementy do odzyskania' -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Get-HTRecoverableItems -Identity $t.PrimarySmtpAddress -Days $days -SubjectContains $subject }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Przywróć' -Icon 'E777' -Action {
        param($m, $rows)
        Invoke-HTRowAction -Module $m -Name 'Przywrócenie elementów' -Rows @($rows | Where-Object { $_.EntryID }) -Confirm 'Przywrócić zaznaczone elementy do pierwotnych folderów?' -Label { param($r) "$($r.Skrzynka): $($r.Temat)" } `
            -Action { param($r) Restore-HTRecoverableItem -Identity $r.Skrzynka -EntryID $r.EntryID }
    }
}

Register-HTModule -Workspace 'Exchange' -Category 'Zgodność' -Key 'exo.hold' -Title 'Litigation Hold i retencja' -Icon 'E72E' `
    -Description 'Blokada postępowania sądowego (zachowanie całej zawartości skrzynki) i czas przechowywania usuniętych elementów (do 30 dni).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Litigation Hold'
    Add-HTLabel -Parent $row -Text 'Czas (dni, 0 = bez limitu):' | Out-Null
    $m.C.Duration = Add-HTNumeric -Parent $row -Value 0 -Minimum 0 -Maximum 36500
    Add-HTButton -Parent $row -Module $m -Text 'Włącz' -Icon 'E72E' -Primary -OnClick {
        param($m)
        $days = Get-HTNum $m.C.Duration
        Invoke-HTTargetAction -Module $m -Name 'Litigation Hold' -Confirm 'Włączyć Litigation Hold dla wybranych skrzynek? (wymaga licencji Exchange Plan 2 lub archiwum)' -Label { param($t) Get-HTMailboxLabel $t } -Action {
            param($t)
            Set-HTMailboxLitigationHold -Identity $t.PrimarySmtpAddress -Enabled $true -DurationDays $days
            "Włączono$(if ($days) { " na $days dni" } else { ' bez limitu' })"
        }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Wyłącz' -Icon 'E785' -OnClick {
        param($m)
        Invoke-HTTargetAction -Module $m -Name 'Wyłączenie Litigation Hold' -Confirm 'Wyłączyć Litigation Hold?' -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Set-HTMailboxLitigationHold -Identity $t.PrimarySmtpAddress -Enabled $false; 'Wyłączono' }
    } | Out-Null
    $row2 = Add-HTToolbarRow -Module $m -Title 'Usunięte elementy'
    Add-HTLabel -Parent $row2 -Text 'Przechowuj (dni):' | Out-Null
    $m.C.Retain = Add-HTNumeric -Parent $row2 -Value 30 -Minimum 1 -Maximum 30
    Add-HTButton -Parent $row2 -Module $m -Text 'Ustaw' -Icon 'E73E' -OnClick {
        param($m)
        $days = Get-HTNum $m.C.Retain
        Invoke-HTTargetAction -Module $m -Name 'Retencja usuniętych elementów' -Label { param($t) Get-HTMailboxLabel $t } -Action { param($t) Set-HTMailboxRetainDeletedItems -Identity $t.PrimarySmtpAddress -Days $days; "$days dni" }
    } | Out-Null
}
#endregion

#region Raporty
Register-HTModule -Workspace 'Exchange' -Category 'Raporty' -Key 'exo.rep.forwarding' -Title 'Przekierowania zewnętrzne' -Icon 'E7BA' -Service 'Exchange' `
    -Description 'Audyt bezpieczeństwa: skrzynki i reguły przekazujące pocztę poza organizację (na czerwono - adresy spoza domen akceptowanych).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    $m.C.Rules = Add-HTCheckBox -Parent $row -Text 'Sprawdź także reguły skrzynek (wolniej)' -Checked $true
    Add-HTButton -Parent $row -Module $m -Text 'Generuj raport' -Icon 'E9D2' -Primary -OnClick {
        param($m)
        $rules = Test-HTChecked $m.C.Rules
        Invoke-HTQuery -Module $m -Name 'Przekierowania zewnętrzne' -ScriptBlock {
            Get-HTExternalForwardingReport -IncludeInboxRules:$rules -OnProgress { param($i, $total, $name) if ($i % 5 -eq 0 -or $i -eq $total) { Set-HTProgress -Value $i -Maximum $total -Text "Reguły skrzynek [$i/$total] $name" } }
        }
    } | Out-Null
}

Register-HTModule -Workspace 'Exchange' -Category 'Raporty' -Key 'exo.rep.inactive' -Title 'Nieaktywne skrzynki' -Icon 'E916' -Service 'Exchange' `
    -Description 'Skrzynki bez aktywności użytkownika od wskazanej liczby dni (kandydaci do konwersji lub usunięcia licencji). Sprawdzane są skrzynki z listy.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTLabel -Parent $row -Text 'Brak aktywności od (dni):' | Out-Null
    $m.C.Days = Add-HTNumeric -Parent $row -Value (Get-HTInactiveDaysDefault) -Minimum 1 -Maximum 3650
    Add-HTButton -Parent $row -Module $m -Text 'Generuj raport' -Icon 'E9D2' -Primary -OnClick {
        param($m)
        $days = Get-HTNum $m.C.Days
        $all = @(Get-HTPanelObjects -Key 'mailboxes' | Where-Object { $_.RecipientTypeDetails -in 'UserMailbox', 'SharedMailbox' })
        if ($all.Count -eq 0) { return }
        Invoke-HTQuery -Module $m -Name 'Nieaktywne skrzynki' -ScriptBlock {
            $i = 0
            foreach ($x in $all) {
                $i++
                if ($i % 5 -eq 0 -or $i -eq $all.Count) { Set-HTProgress -Value $i -Maximum $all.Count -Text "Statystyki skrzynek [$i/$($all.Count)]" }
                try {
                    $u = Get-HTMailboxUsage -Identity $x.PrimarySmtpAddress
                    $idle = $u.'Dni bez aktywności'
                    if ($null -eq $idle -or $idle -ge $days) { $u.__flag = 'warn'; $u }
                }
                catch { [PSCustomObject]@{ Skrzynka = $x.DisplayName; Adres = $x.PrimarySmtpAddress; Status = 'Błąd'; Szczegóły = $_.Exception.Message } }
            }
        }
    } | Out-Null
}
#endregion
