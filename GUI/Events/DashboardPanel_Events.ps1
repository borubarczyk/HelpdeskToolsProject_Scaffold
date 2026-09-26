# Dashboard - aktualizacja kafelków na podstawie statystyk
function Update-HTDashboardTiles {
    param ([Parameter(Mandatory)][System.Collections.IDictionary]$Stats)

    $colors = @{
        Ok    = $Global:HTTheme.Success
        Warn  = $Global:HTTheme.Warning
        Error = $Global:HTTheme.Danger
        Off   = $Global:HTTheme.Border
    }

    foreach ($key in $HT_UI.DashboardTab.Tiles.Keys) {
        $tile = $HT_UI.DashboardTab.Tiles[$key]
        $value = $Stats[$key]
        if (-not $value) { continue }
        $tile.Value.Text = $value.Value
        $tile.Note.Text = $value.Note
        $tile.Stripe.BackColor = $colors[$value.State]
        $tile.Value.ForeColor = if ($value.State -eq "Off") { $Global:HTTheme.Muted } else { $Global:HTTheme.Text }
    }

    $HT_UI.DashboardTab.LastStats = $Stats
    $HT_UI.DashboardTab.UpdatedLabel.Text = "Ostatnia aktualizacja: $($Stats.Updated.ToString('yyyy-MM-dd HH:mm:ss'))"
}

# Dashboard - odświeżenie statystyk
$HT_UI.DashboardTab.RefreshButton.Add_Click({
        Invoke-HTAction -Name "Odświeżanie statystyk" -ScriptBlock {
            $stats = Get-HTDashboardStats
            Update-HTDashboardTiles -Stats $stats
            Write-Log -Message "Zaktualizowano statystyki Dashboardu." -Type "Info"
        }
    })

# Dashboard - pierwsze wyświetlenie: statystyki "offline" (stan połączeń)
$HT_UI.SectionShown["Dashboard"] = {
    if (-not $HT_UI.DashboardTab.LastStats) {
        Update-HTDashboardTiles -Stats (Get-HTDashboardStats)
    }
}

# Dashboard - ostatnie zdarzenia (odbiorca logów)
function Add-HTRecentEvent {
    param ([Parameter(Mandatory)][object]$Entry)
    $list = $HT_UI.DashboardTab.RecentList
    if (-not $list -or $list.IsDisposed) { return }

    $item = New-Object System.Windows.Forms.ListViewItem($Entry.Time.ToString("yyyy-MM-dd HH:mm:ss"))
    [void]$item.SubItems.Add($Entry.Type)
    [void]$item.SubItems.Add($Entry.Message)
    $item.ForeColor = switch ($Entry.Type) {
        "Warn" { $Global:HTTheme.Warning }
        "Error" { $Global:HTTheme.Danger }
        default { $Global:HTTheme.Text }
    }
    $list.Items.Insert(0, $item) | Out-Null
    while ($list.Items.Count -gt 200) { $list.Items.RemoveAt($list.Items.Count - 1) }
}

foreach ($entry in (Get-HTLogHistory | Select-Object -Last 50)) { Add-HTRecentEvent -Entry $entry }
Register-HTLogSink -ScriptBlock { param($entry) Add-HTRecentEvent -Entry $entry }
