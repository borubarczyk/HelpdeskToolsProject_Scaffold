# === Mapa funkcji do akcji ===
$LocalAD_ActionHandlers = @{
    # === Użytkownicy ===
    "Odśwież"           = { Invoke-LocalADRefresh }
    "Resetuj hasło"     = { Invoke-LocalADResetPassword }
    "Zablokuj/Odblokuj" = { Invoke-LocalADLockUnlock }
    "Zmień grupy"       = { Invoke-LocalADChangeGroups }
    "Przypisz profil"   = { Invoke-LocalADAssignProfile }
    "Wyeksportuj dane"  = { Invoke-LocalADExport }
    "Przenieś OU"       = { Invoke-LocalADMoveOU }
    "Usuń konto"        = { Invoke-LocalADDelete }
    "Akcje specjalne"   = { Invoke-LocalADSpecial }

    # === Komputery ===
    "Zrestartuj"        = { Invoke-LocalADRestartComputer }
    "Zablokuj"          = { Invoke-LocalADBlockComputer }
    "Zmień OU"          = { Invoke-LocalADChangeOU }
    "Wyłącz konto"      = { Invoke-LocalADDisableComputer }
    "Wyczyść SID"       = { Invoke-LocalADClearSID }

    # === Grupy ===
    "Dodaj członków"    = { Invoke-LocalADAddMembers }
    "Usuń członków"     = { Invoke-LocalADRemoveMembers }
    "Zmień nazwę"       = { Invoke-LocalADRenameGroup }
    "Zmień typ grupy"   = { Invoke-LocalADChangeGroupType }
    "Zmień zakres"      = { Invoke-LocalADChangeGroupScope }
    "Usuń grupę"        = { Invoke-LocalADDeleteGroup }
}

# === Podpinanie eventów ===
foreach ($panelName in $LocalAD_ActionSets.Keys) {
    $actions = $LocalAD_ActionSets[$panelName]

    foreach ($action in $actions) {
        $button = $HT_UI.LocalADTab.Views[$panelName].Buttons[$action]

        if ($button -and $LocalAD_ActionHandlers.ContainsKey($action)) {
            $button.Add_Click($LocalAD_ActionHandlers[$action])
        } else {
            #Write-Log "⚠️ Brak handlera lub przycisku: $panelName -> $action" -Type 'Error&Notification'
        }
    }
}

# === Wybór obiektu z listy ===
$HT_UI.LocalADTab.ObjectBox.Add_SelectedIndexChanged({
    $selectedObject = $HT_UI.LocalADTab.ObjectBox.SelectedItem
    $section = $HT_UI.LocalADTab.SectionBox.SelectedItem

    if (-not $selectedObject) {
        return
    }

    try {
        switch ($section) {
            "Użytkownicy" {
                $details = Get-ADUser -Identity $selectedObject -Properties * |
                    Select-Object Name,
                                  SamAccountName,
                                  UserPrincipalName,
                                  Enabled,
                                  Department,
                                  Title,
                                  Company,
                                  EmailAddress,
                                  PasswordLastSet,
                                  PasswordNeverExpires,
                                  LastLogonDate,
                                  DistinguishedName |
                    Format-List | Out-String

                $details = $details.Trim()
            }

            "Komputery" {
                $details = Get-ADComputer -Identity $selectedObject -Properties * |
                    Select-Object Name,
                                  DNSHostName,
                                  OperatingSystem,
                                  OperatingSystemVersion,
                                  IPv4Address,
                                  LastLogonDate,
                                  Enabled,
                                  WhenCreated,
                                  DistinguishedName |
                    Format-List | Out-String

                $details = $details.Trim()
            }

            "Grupy" {
                $members = Get-ADGroupMember -Identity $selectedObject | 
                    Select-Object -ExpandProperty SamAccountName |
                    ForEach-Object { $_.Trim() }

                $details = Get-ADGroup -Identity $selectedObject -Properties * |
                    Select-Object Name,
                                  SamAccountName,
                                  GroupScope,
                                  GroupCategory,
                                  ManagedBy,
                                  WhenCreated,
                                  DistinguishedName |
                    Format-List | Out-String

                $details = $details.Trim()
                $details += "`n=== Members ===`n" + ($members -join "`n")
            }

            default {
                $details = "❌ Nieobsługiwany typ obiektu."
            }
        }

        $HT_UI.LocalADTab.DetailsBox.Text = $details
        Write-Log -Message "✅ Załadowano szczegóły dla: $selectedObject" -Type "Info"
    }
    catch {
        Write-Log -Message "❌ Błąd ładowania szczegółów: $_" -Type "Error"
    }
})

# === Zmiana sekcji ===
$HT_UI.LocalADTab.SectionBox.Add_SelectedIndexChanged({
    Show-LocalADButtons
    $HT_UI.LocalADTab.ObjectBox.Items.Clear()
    $HT_UI.LocalADTab.ObjectBox.Items.Add('Lista niezaładowana - kliknij "Odśwież" / Wybierz obiekt z sekcji')
    $HT_UI.LocalADTab.DetailsBox.Clear()
    Write-Log -Message "📂 Zmieniono sekcję na: $($HT_UI.LocalADTab.SectionBox.SelectedItem). Lista wyczyszczona." -Type "Info"
    Invoke-LocalADRefresh
    $HT_UI.LocalADTab.ObjectBox.SelectedIndex = 0
})
