# Statystyki dla zakładki Dashboard. Każdy kafelek jest liczony niezależnie - błąd jednej usługi nie blokuje pozostałych.

function New-HTTileValue {
    param (
        [string]$Value = "—",
        [string]$Note = "",
        [ValidateSet("Ok", "Warn", "Error", "Off")][string]$State = "Ok"
    )
    return [PSCustomObject]@{ Value = $Value; Note = $Note; State = $State }
}

# Oblicza wartości wszystkich kafelków
function Get-HTDashboardStats {
    $stats = [ordered]@{}
    $alerts = New-Object System.Collections.Generic.List[string]

    # Użytkownicy Microsoft 365
    if ($Global:ConnectedToGraphAPI) {
        try {
            $total = Invoke-HTGraphRequest -Uri "users/`$count" -ConsistencyLevelEventual
            $enabled = Invoke-HTGraphRequest -Uri "users/`$count?`$filter=accountEnabled eq true" -ConsistencyLevelEventual
            $stats.Users = New-HTTileValue -Value "$total" -Note "aktywnych: $enabled"
        }
        catch { $stats.Users = New-HTTileValue -Note "błąd: $($_.Exception.Message)" -State "Error" }

        try {
            $skus = @(Get-HTSubscribedSkus -Force | Where-Object { $_.Enabled -gt 0 -and $_.Status -eq "Enabled" })
            $consumed = ($skus | Measure-Object -Property Consumed -Sum).Sum
            $enabledUnits = ($skus | Measure-Object -Property Enabled -Sum).Sum
            $exhausted = @($skus | Where-Object { $_.Available -le 0 })
            foreach ($sku in $exhausted) { $alerts.Add("Brak wolnych licencji: $($sku.SkuPartNumber)") }
            $state = if ($exhausted.Count -gt 0) { "Warn" } else { "Ok" }
            $stats.Licenses = New-HTTileValue -Value "$consumed / $enabledUnits" -Note "przypisanych / dostępnych ($($skus.Count) SKU)" -State $state
        }
        catch { $stats.Licenses = New-HTTileValue -Note "błąd: $($_.Exception.Message)" -State "Error" }

        try {
            $intune = Get-HTIntuneSummary
            if ($intune.NonCompliant -gt 0) { $alerts.Add("Urządzenia niezgodne z zasadami: $($intune.NonCompliant)") }
            $state = if ($intune.NonCompliant -gt 0) { "Warn" } else { "Ok" }
            $stats.Intune = New-HTTileValue -Value "$($intune.Total)" -Note "niezgodnych: $($intune.NonCompliant)" -State $state
        }
        catch { $stats.Intune = New-HTTileValue -Note "brak dostępu do Intune" -State "Error" }
    }
    else {
        $stats.Users = New-HTTileValue -Note "połącz z Microsoft Graph" -State "Off"
        $stats.Licenses = New-HTTileValue -Note "połącz z Microsoft Graph" -State "Off"
        $stats.Intune = New-HTTileValue -Note "połącz z Microsoft Graph" -State "Off"
    }

    # Skrzynki Exchange Online
    if ($Global:ConnectedToExchange) {
        try {
            $mbx = Get-HTMailboxSummary
            $stats.Mailboxes = New-HTTileValue -Value "$($mbx.Total)" -Note "użytk.: $($mbx.User), współdz.: $($mbx.Shared), inne: $($mbx.Other)"
        }
        catch { $stats.Mailboxes = New-HTTileValue -Note "błąd: $($_.Exception.Message)" -State "Error" }
    }
    else {
        $stats.Mailboxes = New-HTTileValue -Note "połącz z Exchange Online" -State "Off"
    }

    # SharePoint (PnP - bieżąca witryna)
    if ($Global:ConnectedToSharepointPnP) {
        try {
            $libraries = @(Get-HTSPLibraries)
            $items = ($libraries | Measure-Object -Property ItemCount -Sum).Sum
            $stats.SharePoint = New-HTTileValue -Value "$($libraries.Count)" -Note "bibliotek, elementów: $items"
        }
        catch { $stats.SharePoint = New-HTTileValue -Note "błąd: $($_.Exception.Message)" -State "Error" }
    }
    elseif ($Global:ConnectedToGraphAPI) {
        try {
            $sites = @(Invoke-HTGraphRequest -Uri "sites?search=*&`$select=id" -All)
            $stats.SharePoint = New-HTTileValue -Value "$($sites.Count)" -Note "witryn (Graph)"
        }
        catch { $stats.SharePoint = New-HTTileValue -Note "połącz z SharePoint" -State "Off" }
    }
    else {
        $stats.SharePoint = New-HTTileValue -Note "połącz z SharePoint" -State "Off"
    }

    # Lokalne AD
    if ($Global:IsModuleActiveDirectoryLoaded) {
        try {
            $locked = @(Get-HTADLockedAccounts)
            if ($locked.Count -gt 0) { $alerts.Add("Zablokowane konta AD: $($locked.Count)") }
            $state = if ($locked.Count -gt 0) { "Warn" } else { "Ok" }
            $stats.AD = New-HTTileValue -Value "$($locked.Count)" -Note "zablokowanych kont" -State $state
        }
        catch { $stats.AD = New-HTTileValue -Note "błąd: $($_.Exception.Message)" -State "Error" }
    }
    else {
        $stats.AD = New-HTTileValue -Note "moduł ActiveDirectory niedostępny" -State "Off"
    }

    # Połączenia
    $connected = @($Global:ConnectedToExchange, $Global:ConnectedToGraphAPI, $Global:ConnectedToSharepointPnP, $Global:IsModuleActiveDirectoryLoaded) | Where-Object { $_ }
    $stats.Connections = New-HTTileValue -Value "$(@($connected).Count) / 4" -Note "aktywnych usług" -State $(if (@($connected).Count -gt 0) { "Ok" } else { "Off" })

    # Alerty
    $stats.Alerts = New-HTTileValue -Value "$($alerts.Count)" -Note $(if ($alerts.Count -gt 0) { "kliknij, aby zobaczyć" } else { "brak aktywnych problemów" }) -State $(if ($alerts.Count -gt 0) { "Warn" } else { "Ok" })
    $stats.AlertList = $alerts.ToArray()
    $stats.Updated = Get-Date

    return $stats
}
