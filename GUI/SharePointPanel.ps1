# Panel główny dla zakładki "SharePoint": drzewo bibliotek i folderów + uprawnienia wybranego elementu
$theme = $Global:HTTheme

# Pasek narzędzi: adres witryny
$textbox_SiteUrl = New-Object System.Windows.Forms.TextBox
$textbox_SiteUrl.Width = 440
$textbox_SiteUrl.PlaceholderText = "https://twojtenant.sharepoint.com/sites/..."
$textbox_SiteUrl.Text = $Global:DefaultSharepointSite

$button_SPConnectSite = New-HTButton -Text "Połącz z witryną" -Icon "Website.png" -Width 160 -Height 32 -ToolTip "Łączy (lub przełącza) PnP PowerShell na wpisaną witrynę"

$view_SharePoint = New-HTSectionView -ToolbarControls @($textbox_SiteUrl, $button_SPConnectSite) -SearchPlaceholder "Filtruj uprawnienia..." -ListRatio 0.45 -Columns @(
    @{ Text = "Podmiot"; Property = "Principal"; Width = 200 }
    @{ Text = "Typ"; Property = "PrincipalType"; Width = 110 }
    @{ Text = "Uprawnienia"; Property = "Roles"; Width = 160 }
    @{ Text = "Login"; Property = "LoginName"; Width = 260 }
) -Actions @(
    @{ Group = "Uprawnienia" }
    @{ Key = "CheckPermissions"; Text = "Sprawdź uprawnienia"; Icon = "Eye open.png"; ToolTip = "Pokazuje uprawnienia zaznaczonego elementu drzewa" }
    @{ Key = "GrantPermissions"; Text = "Nadaj uprawnienia"; Icon = "Add Male User Group.png"; ToolTip = "Dla zaznaczonego elementu lub wszystkich zaznaczonych checkboxami" }
    @{ Key = "RemovePermissions"; Text = "Odbierz uprawnienia"; Icon = "Minus.png"; ToolTip = "Odbiera uprawnienia zaznaczone na liście po prawej" }
    @{ Key = "ToggleInheritance"; Text = "Dziedziczenie"; Icon = "Process.png"; ToolTip = "Przerwij lub przywróć dziedziczenie uprawnień" }
    @{ Group = "Grupy SharePoint" }
    @{ Key = "CreateSecurityGroup"; Text = "Utwórz grupę"; Icon = "User Groups.png" }
    @{ Key = "CheckGroup"; Text = "Członkowie grupy"; Icon = "Info.png"; ToolTip = "Podgląd i edycja członków grupy SharePoint" }
    @{ Group = "Foldery" }
    @{ Key = "AddFolder"; Text = "Dodaj folder"; Icon = "Add Folder.png" }
    @{ Key = "OpenInBrowser"; Text = "Otwórz w przeglądarce"; Icon = "Website.png" }
    @{ Key = "Export"; Text = "Eksport uprawnień (CSV)"; Icon = "CSV.png" }
)

# Lewa część: drzewo zamiast listy obiektów
$treeview_SharePoint = New-Object System.Windows.Forms.TreeView
$treeview_SharePoint.Dock = [System.Windows.Forms.DockStyle]::Fill
$treeview_SharePoint.CheckBoxes = $true
$treeview_SharePoint.HideSelection = $false
$treeview_SharePoint.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$treeview_SharePoint.Font = $theme.Font
$treeview_SharePoint.ItemHeight = 24
$treeview_SharePoint.ShowLines = $true
$treeview_SharePoint.ShowNodeToolTips = $true

$imageList_SharePoint = New-Object System.Windows.Forms.ImageList
$imageList_SharePoint.ImageSize = New-Object System.Drawing.Size(18, 18)
$imageList_SharePoint.ColorDepth = [System.Windows.Forms.ColorDepth]::Depth32Bit
foreach ($iconName in @("filing-cabinet.png", "Opened Folder.png", "lock.png")) {
    $image = Get-HTIcon -Name $iconName -Size 18
    if ($image) { $imageList_SharePoint.Images.Add($iconName, $image) }
}
$treeview_SharePoint.ImageList = $imageList_SharePoint

$label_TreeHeader = New-Object System.Windows.Forms.Label
$label_TreeHeader.Dock = [System.Windows.Forms.DockStyle]::Top
$label_TreeHeader.Height = 28
$label_TreeHeader.Padding = New-Object System.Windows.Forms.Padding(6, 0, 0, 0)
$label_TreeHeader.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$label_TreeHeader.Font = $theme.FontSmallBold
$label_TreeHeader.ForeColor = $theme.Muted
$label_TreeHeader.Text = "BIBLIOTEKI I FOLDERY"

# Zamiana: lista uprawnień trafia na prawą stronę, drzewo na lewą
$split_SP = $view_SharePoint.Split
$list_SPPermissions = $view_SharePoint.List
$split_SP.Panel1.Controls.Clear()
$split_SP.Panel2.Controls.Clear()
$split_SP.Panel1.Controls.Add($treeview_SharePoint)
$split_SP.Panel1.Controls.Add($label_TreeHeader)
$treeview_SharePoint.BringToFront()

$label_PermHeader = New-Object System.Windows.Forms.Label
$label_PermHeader.Dock = [System.Windows.Forms.DockStyle]::Top
$label_PermHeader.Height = 44
$label_PermHeader.Padding = New-Object System.Windows.Forms.Padding(6, 2, 0, 2)
$label_PermHeader.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
$label_PermHeader.ForeColor = $theme.Muted
$label_PermHeader.Text = "Zaznacz bibliotekę lub folder, aby zobaczyć uprawnienia."
$split_SP.Panel2.Controls.Add($list_SPPermissions)
$split_SP.Panel2.Controls.Add($label_PermHeader)
$list_SPPermissions.BringToFront()
$list_SPPermissions.MultiSelect = $true

$view_SharePoint.RefreshButton.Text = "Wczytaj"
Set-HTToolTip -Control $view_SharePoint.RefreshButton -Text "Wczytuje biblioteki dokumentów połączonej witryny (F5)"
$view_SharePoint.CountLabel.Text = "Połącz się z witryną SharePoint i kliknij 'Wczytaj'"

# Dołącz panel do zakładki "SharePoint"
$HT_UI.Tabs["SharePoint"].Controls.Clear()
$HT_UI.Tabs["SharePoint"].Controls.Add($view_SharePoint.Panel)

# Eksport referencji do globalnego słownika
$view_SharePoint.TreeView = $treeview_SharePoint
$view_SharePoint.SiteBox = $textbox_SiteUrl
$view_SharePoint.ConnectSiteButton = $button_SPConnectSite
$view_SharePoint.PermissionHeader = $label_PermHeader
$view_SharePoint.CurrentNode = $null
$global:HT_UI.SharePointTab = $view_SharePoint
$HT_UI.RefreshButtons["SharePoint"] = $view_SharePoint.RefreshButton
