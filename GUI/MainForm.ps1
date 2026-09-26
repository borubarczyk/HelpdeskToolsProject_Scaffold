# Główne okno aplikacji: nawigacja (lewa kolumna), nagłówek z połączeniami, obszar sekcji i pasek statusu
$theme = $Global:HTTheme

# Sekcje aplikacji: nazwa, ikona nawigacji i opis w nagłówku
$sectionDefinitions = @(
    @{ Name = "Dashboard"; Icon = "Tools.png"; Info = "Podsumowanie środowiska i stan połączeń" }
    @{ Name = "Użytkownicy"; Icon = "users.png"; Info = "Konta Microsoft 365 / Entra ID (Microsoft Graph)" }
    @{ Name = "Skrzynki"; Icon = "mailbox.png"; Info = "Skrzynki pocztowe Exchange Online" }
    @{ Name = "Intune"; Icon = "multiple-devices.png"; Info = "Urządzenia zarządzane przez Microsoft Intune" }
    @{ Name = "SharePoint"; Icon = "microsoft-sharepoint-2019.png"; Info = "Biblioteki, foldery i uprawnienia (PnP PowerShell)" }
    @{ Name = "Lokalne AD"; Icon = "Organization.png"; Info = "Użytkownicy, komputery i grupy domeny Active Directory" }
    @{ Name = "Akcje masowe"; Icon = "Group Objects.png"; Info = "Ta sama operacja na wielu kontach jednocześnie" }
    @{ Name = "Logi"; Icon = "filing-cabinet.png"; Info = "Historia działań aplikacji" }
    @{ Name = "Ustawienia"; Icon = "Security Configuration.png"; Info = "Konfiguracja aplikacji (config.json)" }
)

# Form
$mainForm = New-Object System.Windows.Forms.Form
$mainForm.Text = "Helpdesk Tools"
$mainForm.Size = New-Object System.Drawing.Size(1380, 860)
$mainForm.MinimumSize = New-Object System.Drawing.Size(1120, 700)
$mainForm.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$mainForm.Font = $theme.Font
$mainForm.BackColor = $theme.Background
$mainForm.KeyPreview = $true
if (Test-Path $Global:AppIconPath) {
    $mainForm.Icon = New-Object System.Drawing.Icon($Global:AppIconPath)
}

#region Nawigacja
$panel_Navigation = New-Object System.Windows.Forms.Panel
$panel_Navigation.Dock = [System.Windows.Forms.DockStyle]::Left
$panel_Navigation.Width = 224
$panel_Navigation.BackColor = $theme.NavBack

# Logo i nazwa
$panel_Logo = New-Object System.Windows.Forms.Panel
$panel_Logo.Dock = [System.Windows.Forms.DockStyle]::Top
$panel_Logo.Height = 72

$picture_Logo = New-Object System.Windows.Forms.PictureBox
$picture_Logo.Size = New-Object System.Drawing.Size(34, 34)
$picture_Logo.Location = New-Object System.Drawing.Point(18, 19)
$picture_Logo.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
$picture_Logo.Image = Get-HTIcon -Name "Tools.png" -Size 34

$label_AppName = New-Object System.Windows.Forms.Label
$label_AppName.Text = "Helpdesk Tools"
$label_AppName.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 13)
$label_AppName.ForeColor = [System.Drawing.Color]::White
$label_AppName.AutoSize = $true
$label_AppName.Location = New-Object System.Drawing.Point(60, 14)

$label_AppVersion = New-Object System.Windows.Forms.Label
$label_AppVersion.Text = "wersja $($Global:AppVersion)"
$label_AppVersion.Font = $theme.FontSmall
$label_AppVersion.ForeColor = $theme.NavMuted
$label_AppVersion.AutoSize = $true
$label_AppVersion.Location = New-Object System.Drawing.Point(62, 40)

$panel_Logo.Controls.AddRange(@($picture_Logo, $label_AppName, $label_AppVersion))

# Przyciski sekcji
$flow_Navigation = New-Object System.Windows.Forms.FlowLayoutPanel
$flow_Navigation.Dock = [System.Windows.Forms.DockStyle]::Fill
$flow_Navigation.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
$flow_Navigation.WrapContents = $false
$flow_Navigation.Padding = New-Object System.Windows.Forms.Padding(10, 6, 10, 6)

$navButtons = [ordered]@{}
$shortcut = 1
foreach ($section in $sectionDefinitions) {
    $button = New-HTButton -Text "  $($section.Name)" -Icon $section.Icon -Style "Nav" -Width 204 -Height 40 -ToolTip "$($section.Info) (Ctrl+$shortcut)"
    $button.Margin = New-Object System.Windows.Forms.Padding(0, 1, 0, 1)
    $button.Tag = $section.Name
    $flow_Navigation.Controls.Add($button)
    $navButtons[$section.Name] = $button
    $shortcut++
}

# Narzędzia na dole nawigacji
$flow_NavigationTools = New-Object System.Windows.Forms.FlowLayoutPanel
$flow_NavigationTools.Dock = [System.Windows.Forms.DockStyle]::Bottom
$flow_NavigationTools.Height = 108
$flow_NavigationTools.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
$flow_NavigationTools.WrapContents = $false
$flow_NavigationTools.Padding = New-Object System.Windows.Forms.Padding(10, 6, 10, 6)

$button_PasswordGen = New-HTButton -Text "  Generator haseł" -Icon "password.png" -Style "Nav" -Width 204 -Height 40 -ToolTip "Generator haseł (Ctrl+G)"
$button_Exit = New-HTButton -Text "  Rozłącz i wyjdź" -Icon "close.png" -Style "Nav" -Width 204 -Height 40 -ToolTip "Rozłącza wszystkie usługi i zamyka aplikację"
$button_PasswordGen.Margin = New-Object System.Windows.Forms.Padding(0, 1, 0, 1)
$button_Exit.Margin = New-Object System.Windows.Forms.Padding(0, 1, 0, 1)
$flow_NavigationTools.Controls.AddRange(@($button_PasswordGen, $button_Exit))

$panel_Navigation.Controls.Add($flow_Navigation)
$panel_Navigation.Controls.Add($flow_NavigationTools)
$panel_Navigation.Controls.Add($panel_Logo)
$flow_Navigation.BringToFront()
#endregion

#region Nagłówek
$panel_Content = New-Object System.Windows.Forms.Panel
$panel_Content.Dock = [System.Windows.Forms.DockStyle]::Fill
$panel_Content.BackColor = $theme.Background

$panel_Header = New-Object System.Windows.Forms.Panel
$panel_Header.Dock = [System.Windows.Forms.DockStyle]::Top
$panel_Header.Height = 66
$panel_Header.BackColor = $theme.Surface

$label_HeaderTitle = New-Object System.Windows.Forms.Label
$label_HeaderTitle.Font = $theme.FontTitle
$label_HeaderTitle.ForeColor = $theme.Text
$label_HeaderTitle.AutoSize = $true
$label_HeaderTitle.Location = New-Object System.Drawing.Point(20, 8)

$label_HeaderSubtitle = New-Object System.Windows.Forms.Label
$label_HeaderSubtitle.Font = $theme.Font
$label_HeaderSubtitle.ForeColor = $theme.Muted
$label_HeaderSubtitle.AutoSize = $true
$label_HeaderSubtitle.Location = New-Object System.Drawing.Point(22, 38)

$flow_Connections = New-Object System.Windows.Forms.FlowLayoutPanel
$flow_Connections.Dock = [System.Windows.Forms.DockStyle]::Right
$flow_Connections.Width = 600
$flow_Connections.FlowDirection = [System.Windows.Forms.FlowDirection]::RightToLeft
$flow_Connections.WrapContents = $false
$flow_Connections.Padding = New-Object System.Windows.Forms.Padding(0, 15, 14, 0)

$button_ConnectSharePoint = New-HTButton -Text "Połącz: SharePoint" -Icon "microsoft-sharepoint-2019.png" -Width 190 -Height 36
$button_ConnectGraph = New-HTButton -Text "Połącz: Graph" -Icon "api.png" -Width 190 -Height 36
$button_ConnectExchange = New-HTButton -Text "Połącz: Exchange" -Icon "microsoft-exchange-2019.png" -Width 190 -Height 36
foreach ($b in @($button_ConnectSharePoint, $button_ConnectGraph, $button_ConnectExchange)) {
    $b.Margin = New-Object System.Windows.Forms.Padding(6, 0, 0, 0)
    $b.AutoEllipsis = $true
}
$flow_Connections.Controls.AddRange(@($button_ConnectSharePoint, $button_ConnectGraph, $button_ConnectExchange))

$panel_Header.Controls.AddRange(@($flow_Connections, $label_HeaderTitle, $label_HeaderSubtitle))

$panel_HeaderBorder = New-Object System.Windows.Forms.Panel
$panel_HeaderBorder.Dock = [System.Windows.Forms.DockStyle]::Top
$panel_HeaderBorder.Height = 1
$panel_HeaderBorder.BackColor = $theme.Border
#endregion

#region Obszar sekcji
$panel_ContentHost = New-Object System.Windows.Forms.Panel
$panel_ContentHost.Dock = [System.Windows.Forms.DockStyle]::Fill
$panel_ContentHost.BackColor = $theme.Background

$tabs = [ordered]@{}
$sectionInfo = @{}
foreach ($section in $sectionDefinitions) {
    $sectionPanel = New-Object System.Windows.Forms.Panel
    $sectionPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $sectionPanel.BackColor = $theme.Background
    $sectionPanel.Visible = $false
    $sectionPanel.Name = "Section_$($section.Name)"
    $panel_ContentHost.Controls.Add($sectionPanel)
    $tabs[$section.Name] = $sectionPanel
    $sectionInfo[$section.Name] = $section.Info
}

$panel_Content.Controls.Add($panel_ContentHost)
$panel_Content.Controls.Add($panel_HeaderBorder)
$panel_Content.Controls.Add($panel_Header)
$panel_ContentHost.BringToFront()
#endregion

#region Pasek statusu
$statusStrip = New-Object System.Windows.Forms.StatusStrip
$statusStrip.BackColor = $theme.Surface
$statusStrip.SizingGrip = $true
$statusStrip.ShowItemToolTips = $true

$status_Label = New-Object System.Windows.Forms.ToolStripStatusLabel
$status_Label.Spring = $true
$status_Label.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$status_Label.Text = "Uruchamianie..."

$status_Progress = New-Object System.Windows.Forms.ToolStripProgressBar
$status_Progress.Size = New-Object System.Drawing.Size(160, 16)
$status_Progress.Style = [System.Windows.Forms.ProgressBarStyle]::Marquee
$status_Progress.MarqueeAnimationSpeed = 30
$status_Progress.Visible = $false

[void]$statusStrip.Items.Add($status_Label)
[void]$statusStrip.Items.Add($status_Progress)

$statusConnections = [ordered]@{}
foreach ($service in @("AD", "Exchange", "Graph", "SharePoint")) {
    $indicator = New-Object System.Windows.Forms.ToolStripStatusLabel
    $indicator.Text = "● $service"
    $indicator.ForeColor = $theme.Muted
    $indicator.Margin = New-Object System.Windows.Forms.Padding(8, 3, 0, 2)
    $indicator.ToolTipText = "$service - brak połączenia"
    [void]$statusStrip.Items.Add($indicator)
    $statusConnections[$service] = $indicator
}
#endregion

# Dodanie kontrolek do formularza (kolejność ma znaczenie dla dokowania)
$mainForm.Controls.Add($panel_Content)
$mainForm.Controls.Add($panel_Navigation)
$mainForm.Controls.Add($statusStrip)
$panel_Content.BringToFront()

# Globalna struktura UI
$global:HT_UI = [ordered]@{
    Form           = $mainForm
    Tabs           = $tabs
    ContentHost    = $panel_ContentHost
    NavButtons     = $navButtons
    SectionInfo    = $sectionInfo
    SectionShown   = @{}
    RefreshButtons = @{}
    CurrentSection = $null
    Header         = @{
        Panel    = $panel_Header
        Title    = $label_HeaderTitle
        Subtitle = $label_HeaderSubtitle
    }
    Status         = @{
        Strip       = $statusStrip
        Label       = $status_Label
        Progress    = $status_Progress
        Connections = $statusConnections
    }
    Buttons        = @{
        ConnectExchange   = $button_ConnectExchange
        ConnectSharePoint = $button_ConnectSharePoint
        ConnectGraph      = $button_ConnectGraph
        PasswordGen       = $button_PasswordGen
        Exit              = $button_Exit
    }
}

foreach ($service in @("Exchange", "Graph", "SharePoint", "AD")) {
    Update-ConnectionButtonText -Service $service
}
