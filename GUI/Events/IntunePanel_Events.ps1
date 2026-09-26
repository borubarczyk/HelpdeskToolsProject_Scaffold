# Zakładka "Intune" - obsługa zdarzeń

# Zaznaczone urządzenie (wymaga połączenia z Graph)
function Get-HTSelectedDevice {
    if (-not (Assert-HTConnection -Service "Graph")) { return $null }
    return Get-HTSelectedObject -View $HT_UI.IntuneTab -What "urządzenie"
}

# Wymaga identyfikatora urządzenia w Entra ID
function Test-HTDeviceHasEntraId {
    param ([Parameter(Mandatory)][object]$Device)
    if (-not $Device.AzureADDeviceId -or $Device.AzureADDeviceId -eq "00000000-0000-0000-0000-000000000000") {
        Show-Dialog -Message "Urządzenie $($Device.DeviceName) nie jest zarejestrowane w Entra ID." -Title "Intune" -Type "Warning" | Out-Null
        return $false
    }
    return $true
}

# Filtr systemu operacyjnego
function Update-HTDeviceOSFilter {
    $view = $HT_UI.IntuneTab
    $os = "$($view.OSFilter.SelectedItem)"
    $data = if ($os -and $os -ne "Wszystkie systemy") { @($view.AllData | Where-Object { $_.OperatingSystem -like "$os*" }) } else { @($view.AllData) }
    Set-HTListData -ListView $view.List -Data $data
}

# Odświeżenie listy urządzeń
function Update-HTDevicesList {
    Invoke-HTAction -Name "Pobieranie urządzeń Intune" -RequiredService "Graph" -ScriptBlock {
        $HT_UI.IntuneTab.AllData = @(Get-HTIntuneDevices)
        Update-HTDeviceOSFilter
        Set-HTDetails -ListView $HT_UI.IntuneTab.Details -Data $null -Message "Wybierz urządzenie z listy, aby zobaczyć szczegóły."
        Write-Log -Message "Załadowano urządzenia Intune: $($HT_UI.IntuneTab.AllData.Count)" -Type "Info"
    }
}

$HT_UI.IntuneTab.RefreshButton.Add_Click({ Update-HTDevicesList })
$HT_UI.IntuneTab.OSFilter.Add_SelectedIndexChanged({ Update-HTDeviceOSFilter })

# Szczegóły urządzenia
Register-HTDetailsLoader -View $HT_UI.IntuneTab -Loader {
    param($device)
    Get-HTIntuneDeviceDetail -Id $device.Id
}

# Zmiana nazwy
$HT_UI.IntuneTab.Actions.RenameDevice.Add_Click({
        $device = Get-HTSelectedDevice
        if (-not $device) { return }
        if ($device.OperatingSystem -notmatch 'Windows|macOS') {
            Show-Dialog -Message "Zmiana nazwy jest dostępna dla urządzeń Windows i macOS." -Title "Zmień nazwę" -Type "Warning" | Out-Null
            return
        }

        $newName = Show-InputBox -Prompt "Nowa nazwa urządzenia (max 15 znaków: litery, cyfry, myślnik).`nWindows zastosuje ją po ponownym uruchomieniu." -Title "Zmień nazwę - $($device.DeviceName)" -DefaultText $device.DeviceName
        if (-not $newName -or $newName -eq $device.DeviceName) { return }

        Invoke-HTAction -Name "Zmiana nazwy urządzenia" -RequiredService "Graph" -ScriptBlock {
            Rename-HTIntuneDevice -Id $device.Id -NewName $newName
            Write-Log -Message "Zlecono zmianę nazwy urządzenia $($device.DeviceName) na $newName" -Type "Info&Notification"
        }
    })

# Zmiana Primary User
$HT_UI.IntuneTab.Actions.SetPrimaryUser.Add_Click({
        $device = Get-HTSelectedDevice
        if (-not $device) { return }

        $upn = Show-InputBox -Prompt "UPN nowego użytkownika podstawowego urządzenia $($device.DeviceName):" -Title "Primary User" -ValidationType "Upn" -DefaultText $device.UserPrincipalName
        if (-not $upn) { return }

        Invoke-HTAction -Name "Zmiana Primary User" -RequiredService "Graph" -ScriptBlock {
            $user = Resolve-HTM365User -Identity $upn
            Set-HTIntunePrimaryUser -Id $device.Id -UserId $user.id
            $device.UserPrincipalName = $user.userPrincipalName
            Write-Log -Message "Primary User urządzenia $($device.DeviceName): $($user.userPrincipalName)" -Type "Info&Notification"
            Invoke-HTDetailsReload -View $HT_UI.IntuneTab
        }
    })

# Synchronizacja
$HT_UI.IntuneTab.Actions.Sync.Add_Click({
        $device = Get-HTSelectedDevice
        if (-not $device) { return }
        Invoke-HTAction -Name "Synchronizacja urządzenia" -RequiredService "Graph" -ScriptBlock {
            Sync-HTIntuneDevice -Id $device.Id
            Write-Log -Message "Wysłano żądanie synchronizacji do $($device.DeviceName)" -Type "Info&Notification"
        }
    })

# Restart
$HT_UI.IntuneTab.Actions.Restart.Add_Click({
        $device = Get-HTSelectedDevice
        if (-not $device) { return }
        if (-not (Show-HTConfirm -Message "Uruchomić ponownie urządzenie $($device.DeviceName)?`nUżytkownik ($($device.UserPrincipalName)) może utracić niezapisane dane." -Title "Restart urządzenia" -Warning)) { return }
        Invoke-HTAction -Name "Restart urządzenia" -RequiredService "Graph" -ScriptBlock {
            Restart-HTIntuneDevice -Id $device.Id
            Write-Log -Message "Wysłano polecenie restartu do $($device.DeviceName)" -Type "Info&Notification"
        }
    })

# Informacje o sprzęcie
$HT_UI.IntuneTab.Actions.DeviceInfo.Add_Click({
        $device = Get-HTSelectedDevice
        if (-not $device) { return }
        Invoke-HTAction -Name "Informacje o sprzęcie" -RequiredService "Graph" -ScriptBlock {
            $info = Get-HTIntuneHardwareInfo -Id $device.Id
            Set-HTDetails -ListView $HT_UI.IntuneTab.Details -Data $info
        }
    })

# Zainstalowane aplikacje
$HT_UI.IntuneTab.Actions.AppList.Add_Click({
        $device = Get-HTSelectedDevice
        if (-not $device) { return }
        $apps = @(Invoke-HTAction -Name "Pobieranie aplikacji" -RequiredService "Graph" -ScriptBlock { Get-HTIntuneDetectedApps -Id $device.Id })
        Show-HTDataViewer -Title "Aplikacje - $($device.DeviceName)" -Data $apps -ExportName "Aplikacje_$($device.DeviceName)" -Columns @(
            @{ Text = "Nazwa"; Property = "Name"; Width = 320 }
            @{ Text = "Wersja"; Property = "Version"; Width = 130 }
            @{ Text = "Wydawca"; Property = "Publisher"; Width = 220 }
            @{ Text = "Rozmiar (MB)"; Property = "SizeInMB"; Width = 100 }
        )
    })

# Członkostwa grup
$HT_UI.IntuneTab.Actions.Memberships.Add_Click({
        $device = Get-HTSelectedDevice
        if (-not $device -or -not (Test-HTDeviceHasEntraId -Device $device)) { return }
        $groups = @(Invoke-HTAction -Name "Pobieranie grup urządzenia" -RequiredService "Graph" -ScriptBlock { Get-HTIntuneDeviceGroups -AzureADDeviceId $device.AzureADDeviceId })
        if ($groups.Count -eq 0) {
            Show-Dialog -Message "Urządzenie $($device.DeviceName) nie należy do żadnej grupy." -Title "Grupy" | Out-Null
            return
        }
        Show-HTDataViewer -Title "Grupy - $($device.DeviceName)" -Data $groups -ExportName "Grupy_$($device.DeviceName)" -Columns @(
            @{ Text = "Grupa"; Property = "Name"; Width = 300 }
            @{ Text = "Dynamiczna"; Property = "Dynamic"; Width = 90 }
            @{ Text = "Reguła"; Property = "Rule"; Width = 420 }
        )
    })

# Klucz odzyskiwania BitLocker
$HT_UI.IntuneTab.Actions.RecoveryKey.Add_Click({
        $device = Get-HTSelectedDevice
        if (-not $device -or -not (Test-HTDeviceHasEntraId -Device $device)) { return }
        $keys = @(Invoke-HTAction -Name "Pobieranie kluczy BitLocker" -RequiredService "Graph" -ScriptBlock { Get-HTBitLockerRecoveryKeys -AzureADDeviceId $device.AzureADDeviceId })
        if ($keys.Count -eq 0) {
            Show-Dialog -Message "Brak kluczy odzyskiwania BitLocker dla $($device.DeviceName) w Entra ID." -Title "BitLocker" | Out-Null
            return
        }
        Write-Log -Message "Wyświetlono klucze BitLocker urządzenia $($device.DeviceName)" -Type "Info"
        $items = foreach ($key in $keys) {
            @{ Label = "Klucz ($((ConvertTo-HTDisplayValue $key.Created)))"; Value = $key.Key }
            @{ Label = "ID klucza"; Value = $key.KeyId }
        }
        Show-HTSecretDialog -Title "BitLocker - $($device.DeviceName)" -Items @($items)
    })

# Hasło LAPS
$HT_UI.IntuneTab.Actions.LAPS.Add_Click({
        $device = Get-HTSelectedDevice
        if (-not $device -or -not (Test-HTDeviceHasEntraId -Device $device)) { return }
        $laps = Invoke-HTAction -Name "Pobieranie hasła LAPS" -RequiredService "Graph" -ScriptBlock { Get-HTIntuneLapsPassword -AzureADDeviceId $device.AzureADDeviceId }
        if (-not $laps) {
            Show-Dialog -Message "Brak hasła LAPS dla $($device.DeviceName) (Windows LAPS w Entra ID nie jest skonfigurowany lub brak kopii zapasowej)." -Title "LAPS" | Out-Null
            return
        }
        Write-Log -Message "Wyświetlono hasło LAPS urządzenia $($device.DeviceName)" -Type "Info"
        Show-HTSecretDialog -Title "LAPS - $($device.DeviceName)" -Items @(
            @{ Label = "Konto"; Value = $laps.Account }
            @{ Label = "Hasło"; Value = $laps.Password }
            @{ Label = "Kopia z"; Value = (ConvertTo-HTDisplayValue $laps.BackupTime) }
        )
    })

# Eksport listy
$HT_UI.IntuneTab.Actions.Export.Add_Click({
        Export-HTListView -ListView $HT_UI.IntuneTab.List -Name "Urzadzenia_Intune"
    })
