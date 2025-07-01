<#
.SYNOPSIS
    Główny plik uruchamiający aplikację Helpdesk Tools.
#>

#Requires -RunAsAdministrator
#Requires -Version 7

# Zmienne globalne
$Global:ConfigDir = Join-Path -Path $env:APPDATA -ChildPath "HelpdeskTools"
$Global:ConfigPath = Join-Path -Path $Global:ConfigDir -ChildPath "config.json"
$Global:BasePath = "$PSScriptRoot/../Resources/Icons"
$Global:PasswordSpecialCharacters = "!@#$%^&*()-_=+[]{}|;:,.<>?/"
$Global:PasswordUseWordBased = $false
$Global:ConnectedToExchange = $false
$Global:ConnectedToGraphAPI = $false
$Global:ConnectedToSharepoint = $false
$Global:ConnectedToSharepointPnP = $false
$Global:LogPasswordGeneration = $false

# Import modułów
$modulePaths = @(
    "$PSScriptRoot/Modules/Utils.psm1",
    "$PSScriptRoot/Modules/LocalActiveDirectory.psm1",
    "$PSScriptRoot/Modules/MailboxesExchangeOnline.psm1",
    "$PSScriptRoot/Modules/GraphAPISharePoint.psm1",
    "$PSScriptRoot/Modules/GraphAPIM365Users.psm1",
    "$PSScriptRoot/Modules/PasswordGenerator.psm1",
    "$PSScriptRoot/Modules/ModulesConnection.psm1"
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
. "$PSScriptRoot/GUI/PasswordGenerator.ps1"
. "$PSScriptRoot/GUI/GUIHelpers.ps1"
. "$PSScriptRoot/GUI/MainForm_Events.ps1"
. "$PSScriptRoot/GUI/Events/IntunePanel_Events.ps1"
. "$PSScriptRoot/GUI/Events/MailBoxPanel_Events.ps1"
. "$PSScriptRoot/GUI/Events/SharePointPanel_Events.ps1"
. "$PSScriptRoot/GUI/Events/LocalADPanel_Events.ps1"
. "$PSScriptRoot/GUI/Events/UsersPanel_Events.ps1"

# Sprawdź załaduj jak nie ma utwórz katalog konfiguracyjny i plik konfiguracyjny
Get-Configuration

# Załaduj ikony do przycisków
Get-AllIcons

# Uruchom GUI
try {
    [System.Threading.Thread]::CurrentThread.SetApartmentState([System.Threading.ApartmentState]::STA)
    [void][System.Windows.Forms.Application]::EnableVisualStyles()
    [System.Windows.Forms.Application]::Run($mainForm)
}
catch {
    Write-Error "Błąd uruchamiania GUI: $_" 
}

[System.Windows.Forms.Application]::Exit()