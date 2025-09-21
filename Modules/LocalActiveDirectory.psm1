# Active Directory functions# === Odśwież dane z AD - pobierz listę obiektów ===
function Invoke-LocalADRefresh {
    try {

        if (-not (Get-Module -Name ActiveDirectory -ErrorAction SilentlyContinue)) {
            Write-Log -Message "Moduł ActiveDirectory nie jest załadowany!" -Type "Error&Notification"
            return
        }

        $section = $HT_UI.LocalADTab.SectionBox.SelectedItem
        if (-not $section) {
            Write-Log -Message "Wybierz sekcję (Użytkownicy, Komputery, Grupy)!" -Type "Warn"
            return
        }

        Write-Log -Message "Odświeżanie: $section ..." -Type "Info"

        switch ($section) {
            "Użytkownicy" {
                $Global:LocalAD_Objects = Get-ADUser -Filter * |
                    Select-Object -ExpandProperty SamAccountName |
                    ForEach-Object { $_.Trim() }
            }
            "Komputery" {
                $Global:LocalAD_Objects = Get-ADComputer -Filter * |
                    Select-Object -ExpandProperty Name |
                    ForEach-Object { $_.Trim() }
            }
            "Grupy" {
                $Global:LocalAD_Objects = Get-ADGroup -Filter * |
                    Select-Object -ExpandProperty Name |
                    ForEach-Object { $_.Trim() }
            }
            default {
                Write-Log -Message "Nieobsługiwana sekcja: $section" -Type "Warn"
                return
            }
        }

        $HT_UI.LocalADTab.ObjectBox.Items.Clear()
        $HT_UI.LocalADTab.ObjectBox.Items.AddRange($Global:LocalAD_Objects)

        $HT_UI.LocalADTab.DetailsBox.Clear()

        Write-Log -Message "Załadowano: $($Global:LocalAD_Objects.Count) obiektów." -Type "Info&Notification"
    }
    catch {
        Write-Log -Message "Błąd odświeżania: $_" -Type "Error"
    }
}

function Get-ObjectDetails {
    param (
        [string]$selectedObject
    )

    if (-not $selectedObject -and $Global:IsModuleActiveDirectoryLoaded -eq $true) {
        Write-Log -Message "Nie wybrano obiektu!" -Type "Warn"
        return
    }


    try {
        $section = $HT_UI.LocalADTab.SectionBox.SelectedItem
        if (-not $section) {
            Write-Log -Message "Wybierz sekcję (Użytkownicy, Komputery, Grupy)!" -Type "Warn"
            return
        }

        Write-Log -Message "Ładowanie szczegółów dla: $selectedObject" -Type "Info"

        switch ($section) {
            "Użytkownicy" {
                $details = Get-ADUser -Identity $selectedObject -Properties * |
                    Select-Object Name,
                                  Guid,
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
                                  DistinguishedName | Out-String
            }
            "Komputery" {
                $details = Get-ADComputer -Identity $selectedObject -Properties * |
                    Select-Object Name,
                                  Guid,
                                  DNSHostName,
                                  OperatingSystem,
                                  OperatingSystemVersion,
                                  IPv4Address,
                                  LastLogonDate,
                                  Enabled,
                                  WhenCreated,
                                  DistinguishedName | Out-String
            }
            "Grupy" {
                $members = Get-ADGroupMember -Identity $selectedObject | 
                    Select-Object -ExpandProperty SamAccountName |
                    ForEach-Object { $_.Trim() }

                $details = Get-ADGroup -Identity $selectedObject -Properties * |
                    Select-Object Name,
                                  SamAccountName,
                                  Guid,
                                  GroupScope,
                                  GroupCategory,
                                  ManagedBy,
                                  WhenCreated,
                                  DistinguishedName | Out-String
                                  $details = $details.Trim()
                $details += "`n=== Members ===`n" + ($members -join "`n")
            }
            default {
                Write-Log -Message "Nieobsługiwana sekcja: $section" -Type "Warn"
                return
            }
        }

        $HT_UI.LocalADTab.DetailsBox.Text = $details
    }
    catch {
        Write-Log -Message "Błąd ładowania szczegółów: $_" -Type "Error"
    }
}