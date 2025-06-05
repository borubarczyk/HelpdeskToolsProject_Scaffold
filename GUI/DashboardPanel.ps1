
# Panel główny dla zakładki "Dashboard"
$panel_Dashboard = New-Object System.Windows.Forms.Panel
$panel_Dashboard.Dock = 'Fill'
$panel_Dashboard.BackColor = [System.Drawing.Color]::White

# Tabela kafelków (3x2)
$tileGrid = New-Object System.Windows.Forms.TableLayoutPanel
$tileGrid.Location = '20,20'
$tileGrid.Size = '850,620'
$tileGrid.ColumnCount = 3
$tileGrid.RowCount = 2
$tileGrid.CellBorderStyle = 'None'
$tileGrid.BackColor = 'White'
$tileGrid.Padding = '0,0,0,0'

for ($i = 0; $i -lt 3; $i++) {
    $tileGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle('Percent', 33)))
}
for ($i = 0; $i -lt 2; $i++) {
    $tileGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle('Percent', 50)))
}

function New-CompactTile {
    param (
        [string]$iconPath,
        [string]$labelText,
        [string]$valueText,
        [string]$noteText = ""
    )

    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = 'Fill'
    $panel.Margin = New-Object System.Windows.Forms.Padding(5)
    $panel.BackColor = [System.Drawing.Color]::White
    $panel.BorderStyle = 'FixedSingle'

    $icon = New-Object System.Windows.Forms.PictureBox
    $icon.Size = '90,90'
    $icon.Location = '10,10'
    $icon.SizeMode = 'Zoom'
    if (Test-Path $iconPath) {
        $icon.Image = [System.Drawing.Image]::FromFile($iconPath)
    }

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $labelText
    $label.Location = '110,20'
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $label.AutoSize = $true

    $value = New-Object System.Windows.Forms.Label
    $value.Text = $valueText
    $value.Location = '110,50'
    $value.Font = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
    $value.AutoSize = $true

    $note = New-Object System.Windows.Forms.Label
    $note.Text = $noteText
    $note.Location = '110,80'
    $note.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $note.AutoSize = $true

    $panel.Controls.AddRange(@($icon, $label, $value, $note))
    return $panel
}


$basePath = "$PSScriptRoot/../Resources/Icons"
$tiles = @(
    New-CompactTile -iconPath (Join-Path $basePath "users_120x120.png") -labelText "Liczba użytkowników" -valueText "1245" 
    New-CompactTile -iconPath (Join-Path $basePath "Mail_120x120.png") -labelText "Skrzynki" -valueText "1123" -noteText "bez przypisania: 23" 
    New-CompactTile -iconPath (Join-Path $basePath "Web_120x120.png") -labelText "SharePoint" -valueText "20" -noteText "sites"
    New-CompactTile -iconPath (Join-Path $basePath "multiple-devices_120x120.png") -labelText "Intune" -valueText "87" -noteText "urządzeń"
    New-CompactTile -iconPath (Join-Path $basePath "Software License_120x120.png") -labelText "Licencje" -valueText "57" -noteText "przypisanych"
    New-CompactTile -iconPath (Join-Path $basePath "Error_120x120.png") -labelText "Alerty" -valueText "3" -noteText "aktywnych problemów"
)

foreach ($tile in $tiles) {
    $tileGrid.Controls.Add($tile)
}

# Dodaj do panelu
$panel_Dashboard.Controls.Add($tileGrid)
$HT_UI.Tabs["Dashboard"].Controls.Clear()
$HT_UI.Tabs["Dashboard"].Controls.Add($panel_Dashboard)

$global:HT_UI.DashboardTab = @{
    Panel = $panel_Dashboard
    Tiles = $tiles
}
