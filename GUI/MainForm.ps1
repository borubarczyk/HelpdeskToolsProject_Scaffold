
#requires -version 7
#requires -RunAsAdministrator

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Form
$mainForm = New-Object System.Windows.Forms.Form
$mainForm.Text = "Helpdesk Tools"
$mainForm.Size = New-Object System.Drawing.Size(900, 800)
$mainForm.StartPosition = "CenterScreen"
$mainForm.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$mainForm.FormBorderStyle = 'FixedSingle'
$mainForm.MaximizeBox = $false
$mainForm.Icon = [System.Drawing.Icon]::ExtractIcon(("$PSScriptRoot/../Resources/Icons/Tools.ico"), 0, $true)


# Tab Control
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Dock = 'Fill'

# Tabs
$tabNames = @("Dashboard", "Użytkownicy", "Skrzynki", "Intune", "SharePoint", "Lokalne AD", "Logi")
$tabs = @{}
# Tworzenie zakładek
foreach ($name in $tabNames) {
    $tab = New-Object System.Windows.Forms.TabPage
    $tab.Text = $name
    $tab.BackColor = 'White'
    $tabControl.TabPages.Add($tab)
    $tabs[$name] = $tab  # dodaj do HT_UI
}

# Bottom Button Panel
$bottomPanel = New-Object System.Windows.Forms.Panel
$bottomPanel.Height = 70
$bottomPanel.Dock = 'Bottom'
$bottomPanel.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)

function New-Button($text, $x) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $text
    $btn.Size = New-Object System.Drawing.Size(150, 50)
    $btn.Location = New-Object System.Drawing.Point($x, 10)
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 11)
    $btn.BackColor = "White"
    return $btn
}

$button_ConnectExchange   = New-Button "Połącz z Exchange" 10
$button_ConnectSharePoint = New-Button "Połącz z SharePoint" 160
$button_ConnectGraph      = New-Button "Połącz z MS GraphAPI" 310
$button_PasswordGen       = New-Button "Generator haseł" 570
$button_Exit              = New-Button "Rozłącz i wyjdź" 720

$bottomPanel.Controls.AddRange(@(
    $button_ConnectExchange,
    $button_ConnectSharePoint,
    $button_ConnectGraph,
    $button_PasswordGen,
    $button_Exit
))

# Add controls to form
$mainForm.Controls.Add($tabControl)
$mainForm.Controls.Add($bottomPanel)

# Output for future use
$global:HT_UI = [ordered]@{
    Form = $mainForm
    Tabs = $tabs
    TabControl = $tabControl
    Buttons = @{
        ConnectExchange   = $button_ConnectExchange
        ConnectSharePoint = $button_ConnectSharePoint
        ConnectGraph      = $button_ConnectGraph
        PasswordGen       = $button_PasswordGen
        Exit              = $button_Exit
    }
}
