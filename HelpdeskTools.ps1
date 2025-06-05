#Requires -RunAsAdministrator
#Requires -Version 7

<#
.SYNOPSIS
    Główny plik uruchamiający aplikację Helpdesk Tools.
#>

# Wczytaj konfigurację
$config = Get-Content -Path "$PSScriptRoot/config.json" | ConvertFrom-Json

# Import modułów
$modulePaths = @(
    "$PSScriptRoot/Modules/Utils.psm1",
    "$PSScriptRoot/Modules/ActiveDirectory.psm1",
    "$PSScriptRoot/Modules/ExchangeOnline.psm1",
    "$PSScriptRoot/Modules/SharePoint.psm1",
    "$PSScriptRoot/Modules/M365Users.psm1"  
)

foreach ($path in $modulePaths) {
    if (Test-Path $path) {
        Import-Module $path -Force -ErrorAction Stop
    }
    else {
        Write-Warning "❗ Moduł nie znaleziony: $path"
    }
}

# Załaduj komponenty GUI
. "$PSScriptRoot/GUI/MainForm.ps1"
. "$PSScriptRoot/GUI/Icons.ps1"
. "$PSScriptRoot/GUI/UsersPanel.ps1"
. "$PSScriptRoot/GUI/DashboardPanel.ps1"
. "$PSScriptRoot/GUI/IntunePanel.ps1"
. "$PSScriptRoot/GUI/MailBoxPanel.ps1"
. "$PSScriptRoot/GUI/SharePointPanel.ps1"
. "$PSScriptRoot/GUI/LogsPanel.ps1"
. "$PSScriptRoot/GUI/LocalADPanel.ps1"
. "$PSScriptRoot/Modules/PasswordGeneratorGUI.ps1"
. "$PSScriptRoot/GUI/GUIHelpers.ps1"
. "$PSScriptRoot/GUI/Events.ps1"


# Załaduj ikony do przycisków
Load-Configuration
Load-AllIcons


# Uruchom GUI
try {
    [void][System.Windows.Forms.Application]::EnableVisualStyles()
    [System.Windows.Forms.Application]::Run($mainForm) | Out-Null
}
catch {
    Write-Error "Błąd uruchamiania GUI: $_"
}