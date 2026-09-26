# Panel główny dla zakładki "Dashboard": kafelki ze statystykami i ostatnie zdarzenia
$theme = $Global:HTTheme

$panel_Dashboard = New-Object System.Windows.Forms.Panel
$panel_Dashboard.Dock = [System.Windows.Forms.DockStyle]::Fill
$panel_Dashboard.BackColor = $theme.Background
$panel_Dashboard.Padding = New-Object System.Windows.Forms.Padding(14, 10, 14, 14)

# Pasek narzędzi
$panel_DashboardToolbar = New-Object System.Windows.Forms.FlowLayoutPanel
$panel_DashboardToolbar.Dock = [System.Windows.Forms.DockStyle]::Top
$panel_DashboardToolbar.Height = 46
$panel_DashboardToolbar.WrapContents = $false

$button_DashboardRefresh = New-HTButton -Text "Odśwież statystyki" -Icon "Refresh.png" -Style "Primary" -Width 170 -Height 32 -ToolTip "Pobiera aktualne dane z połączonych usług (F5)"
$button_DashboardRefresh.Margin = New-Object System.Windows.Forms.Padding(2, 3, 10, 0)

$label_DashboardUpdated = New-Object System.Windows.Forms.Label
$label_DashboardUpdated.AutoSize = $true
$label_DashboardUpdated.ForeColor = $theme.Muted
$label_DashboardUpdated.Margin = New-Object System.Windows.Forms.Padding(0, 10, 0, 0)
$label_DashboardUpdated.Text = "Statystyki nie zostały jeszcze pobrane."

$panel_DashboardToolbar.Controls.AddRange(@($button_DashboardRefresh, $label_DashboardUpdated))

# Siatka kafelków (4 x 2)
$tileGrid = New-Object System.Windows.Forms.TableLayoutPanel
$tileGrid.Dock = [System.Windows.Forms.DockStyle]::Top
$tileGrid.Height = 316
$tileGrid.ColumnCount = 4
$tileGrid.RowCount = 2
$tileGrid.BackColor = $theme.Background
for ($i = 0; $i -lt 4; $i++) {
    [void]$tileGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 25)))
}
for ($i = 0; $i -lt 2; $i++) {
    [void]$tileGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 50)))
}

function New-CompactTile {
    param (
        [string]$Key,
        [string]$IconName,
        [string]$LabelText,
        [string]$Target
    )

    $tile = New-Object System.Windows.Forms.Panel
    $tile.Dock = [System.Windows.Forms.DockStyle]::Fill
    $tile.Margin = New-Object System.Windows.Forms.Padding(5)
    $tile.BackColor = $Global:HTTheme.Surface
    $tile.Cursor = [System.Windows.Forms.Cursors]::Hand
    $tile.Tag = $Target

    $stripe = New-Object System.Windows.Forms.Panel
    $stripe.Dock = [System.Windows.Forms.DockStyle]::Left
    $stripe.Width = 5
    $stripe.BackColor = $Global:HTTheme.Border

    $icon = New-Object System.Windows.Forms.PictureBox
    $icon.Size = New-Object System.Drawing.Size(44, 44)
    $icon.Location = New-Object System.Drawing.Point(18, 16)
    $icon.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
    $icon.Image = Get-HTIcon -Name $IconName -Size 44

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $LabelText
    $label.Location = New-Object System.Drawing.Point(72, 16)
    $label.Font = $Global:HTTheme.FontBold
    $label.ForeColor = $Global:HTTheme.Muted
    $label.AutoSize = $true

    $value = New-Object System.Windows.Forms.Label
    $value.Text = "—"
    $value.Location = New-Object System.Drawing.Point(70, 36)
    $value.Font = $Global:HTTheme.FontLarge
    $value.ForeColor = $Global:HTTheme.Text
    $value.AutoSize = $true

    $note = New-Object System.Windows.Forms.Label
    $note.Text = ""
    $note.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $note.Height = 42
    $note.Padding = New-Object System.Windows.Forms.Padding(13, 0, 8, 8)
    $note.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $note.Font = $Global:HTTheme.FontSmall
    $note.ForeColor = $Global:HTTheme.Muted
    $note.AutoEllipsis = $true

    $tile.Controls.AddRange(@($icon, $label, $value, $note, $stripe))

    foreach ($control in @($tile, $icon, $label, $value, $note)) {
        $control.Tag = $Target
        $control.Cursor = [System.Windows.Forms.Cursors]::Hand
        $control.Add_Click({
                param($src, $evt)
                $target = $src.Tag
                if ($target -eq "Alerts") {
                    $alerts = @($HT_UI.DashboardTab.LastStats.AlertList)
                    if ($alerts.Count -gt 0) {
                        Show-Dialog -Message ($alerts -join "`n") -Title "Aktywne alerty" -Type "Warning" | Out-Null
                    }
                    else {
                        Show-Dialog -Message "Brak aktywnych alertów." -Title "Alerty" -Type "Info" | Out-Null
                    }
                }
                elseif ($target) {
                    Show-HTSection -Name $target
                }
            })
    }
    Set-HTToolTip -Control $tile -Text $(if ($Target -eq "Alerts") { "Kliknij, aby zobaczyć alerty" } elseif ($Target) { "Przejdź do: $Target" } else { "" })

    return @{
        Panel  = $tile
        Stripe = $stripe
        Value  = $value
        Note   = $note
    }
}

$tileDefinitions = @(
    @{ Key = "Users"; Icon = "users_120x120.png"; Label = "Użytkownicy M365"; Target = "Użytkownicy" }
    @{ Key = "Mailboxes"; Icon = "Mail_120x120.png"; Label = "Skrzynki"; Target = "Skrzynki" }
    @{ Key = "SharePoint"; Icon = "Web_120x120.png"; Label = "SharePoint"; Target = "SharePoint" }
    @{ Key = "Intune"; Icon = "multiple-devices_120x120.png"; Label = "Urządzenia Intune"; Target = "Intune" }
    @{ Key = "Licenses"; Icon = "Software License_120x120.png"; Label = "Licencje"; Target = "Użytkownicy" }
    @{ Key = "AD"; Icon = "Organization.png"; Label = "Lokalne AD"; Target = "Lokalne AD" }
    @{ Key = "Connections"; Icon = "api.png"; Label = "Połączenia"; Target = $null }
    @{ Key = "Alerts"; Icon = "Error_120x120.png"; Label = "Alerty"; Target = "Alerts" }
)

$tiles = [ordered]@{}
foreach ($definition in $tileDefinitions) {
    $tile = New-CompactTile -Key $definition.Key -IconName $definition.Icon -LabelText $definition.Label -Target $definition.Target
    $tileGrid.Controls.Add($tile.Panel)
    $tiles[$definition.Key] = $tile
}

# Ostatnie zdarzenia
$panel_RecentHeader = New-Object System.Windows.Forms.Label
$panel_RecentHeader.Dock = [System.Windows.Forms.DockStyle]::Top
$panel_RecentHeader.Height = 34
$panel_RecentHeader.Text = "OSTATNIE ZDARZENIA"
$panel_RecentHeader.Font = $theme.FontSmallBold
$panel_RecentHeader.ForeColor = $theme.Muted
$panel_RecentHeader.TextAlign = [System.Drawing.ContentAlignment]::BottomLeft
$panel_RecentHeader.Padding = New-Object System.Windows.Forms.Padding(6, 0, 0, 4)

$listview_Recent = New-Object System.Windows.Forms.ListView
$listview_Recent.Dock = [System.Windows.Forms.DockStyle]::Fill
$listview_Recent.View = [System.Windows.Forms.View]::Details
$listview_Recent.FullRowSelect = $true
$listview_Recent.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$listview_Recent.HeaderStyle = [System.Windows.Forms.ColumnHeaderStyle]::Nonclickable
[void]$listview_Recent.Columns.Add("Czas", 140)
[void]$listview_Recent.Columns.Add("Typ", 70)
[void]$listview_Recent.Columns.Add("Komunikat", 900)

$panel_RecentHost = New-Object System.Windows.Forms.Panel
$panel_RecentHost.Dock = [System.Windows.Forms.DockStyle]::Fill
$panel_RecentHost.Padding = New-Object System.Windows.Forms.Padding(5, 0, 5, 0)
$panel_RecentHost.Controls.Add($listview_Recent)

$panel_Dashboard.Controls.Add($panel_RecentHost)
$panel_Dashboard.Controls.Add($panel_RecentHeader)
$panel_Dashboard.Controls.Add($tileGrid)
$panel_Dashboard.Controls.Add($panel_DashboardToolbar)
$panel_RecentHost.BringToFront()

$HT_UI.Tabs["Dashboard"].Controls.Clear()
$HT_UI.Tabs["Dashboard"].Controls.Add($panel_Dashboard)

$global:HT_UI.DashboardTab = @{
    Panel         = $panel_Dashboard
    Tiles         = $tiles
    RefreshButton = $button_DashboardRefresh
    UpdatedLabel  = $label_DashboardUpdated
    RecentList    = $listview_Recent
    LastStats     = $null
}
$HT_UI.RefreshButtons["Dashboard"] = $button_DashboardRefresh
