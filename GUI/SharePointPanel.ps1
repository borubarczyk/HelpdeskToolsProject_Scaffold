# Panel główny dla zakładki "SharePoint"
$panel_SharePoint = New-Object System.Windows.Forms.Panel
$panel_SharePoint.Dock = 'Fill'

# TextBox na adres witryny
$textbox_SiteUrl = New-Object System.Windows.Forms.TextBox
$textbox_SiteUrl.Location = '10,10'
$textbox_SiteUrl.Size = '660,25'
$textbox_SiteUrl.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$textbox_SiteUrl.PlaceholderText = "https://twojtenant.sharepoint.com/sites/..."
$textbox_SiteUrl.Text = $Global:DefaultSharepointSite

# TreeView z folderami SharePoint
$treeview_SharePoint = New-Object System.Windows.Forms.TreeView
$treeview_SharePoint.Location = '10,45'
$treeview_SharePoint.Size = '660,600'
$treeview_SharePoint.CheckBoxes = $true
$treeview_SharePoint.HideSelection = $false
$treeview_SharePoint.Font = New-Object System.Drawing.Font("Segoe UI", 10)

# Panel boczny z przyciskami
$panel_SharePointActions = New-Object System.Windows.Forms.FlowLayoutPanel
$panel_SharePointActions.Location = '680,45'
$panel_SharePointActions.Size = '190,660'
$panel_SharePointActions.FlowDirection = 'TopDown'
$panel_SharePointActions.WrapContents = $false
$panel_SharePointActions.AutoScroll = $true

function New-SPActionButton($text) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Size = '170,45'
    $btn.Text = $text
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    return $btn
}

$buttons_SharePoint = @{
    Refresh              = New-SPActionButton "Odśwież"
    CheckPermissions     = New-SPActionButton "Sprawdź uprawnienia"
    GrantPermissions     = New-SPActionButton "Nadaj uprawnienia"
    RemovePermissions    = New-SPActionButton "Odbierz uprawnienia"
    ToggleInheritance    = New-SPActionButton "Dziedziczenie"
    CreateSecurityGroup  = New-SPActionButton "Utwórz grupę"
    CheckGroup           = New-SPActionButton "Sprawdź grupę"
    AddFolder            = New-SPActionButton "Dodaj folder"
}

$panel_SharePointActions.Controls.AddRange(@(
    $buttons_SharePoint.Refresh,
    $buttons_SharePoint.CheckPermissions,
    $buttons_SharePoint.GrantPermissions,
    $buttons_SharePoint.RemovePermissions,
    $buttons_SharePoint.ToggleInheritance,
    $buttons_SharePoint.CreateSecurityGroup,
    $buttons_SharePoint.CheckGroup,
    $buttons_SharePoint.AddFolder
))

# Dodaj kontrolki do panelu głównego
$panel_SharePoint.Controls.AddRange(@(
    $textbox_SiteUrl,
    $treeview_SharePoint,
    $panel_SharePointActions
))

# Dołącz panel do zakładki "SharePoint"
$HT_UI.Tabs["SharePoint"].Controls.Add($panel_SharePoint)

# Eksport referencji do globalnego słownika
$global:HT_UI.SharePointTab = [ordered]@{
    Panel     = $panel_SharePoint
    TreeView  = $treeview_SharePoint
    SiteBox   = $textbox_SiteUrl
    Actions   = $buttons_SharePoint
}
