<#
.SYNOPSIS
    Główny plik uruchamiający aplikację Helpdesk Tools.
.DESCRIPTION
    Aplikacja Windows Forms do zarządzania Active Directory, Microsoft 365 (Graph), Exchange Online,
    Intune i SharePoint. Uruchom w PowerShell 7 (pwsh) jako administrator.
#>

#Requires -RunAsAdministrator
#Requires -Version 7

$ErrorActionPreference = "Continue"

# Windows Forms - style wizualne muszą zostać włączone przed utworzeniem pierwszej kontrolki
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
try { [System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false) } catch { Write-Verbose "Tryb renderowania tekstu już ustawiony." }
try { [System.Windows.Forms.Application]::SetUnhandledExceptionMode([System.Windows.Forms.UnhandledExceptionMode]::CatchException) } catch { Write-Verbose "Tryb obsługi wyjątków już ustawiony." }

# Nieobsłużone wyjątki w zdarzeniach GUI - wpis do logu i komunikat zamiast okna .NET
$threadExceptionHandler = [System.Threading.ThreadExceptionEventHandler] {
    param($src, $evt)
    $message = $evt.Exception.Message
    if ($evt.Exception.InnerException) { $message += "`n$($evt.Exception.InnerException.Message)" }
    try {
        Write-Log -Message "Nieobsłużony wyjątek: $message" -Type "Error"
        Set-HTBusy -Busy $false -Text "Błąd"
    }
    catch { Write-Warning $message }
    [System.Windows.Forms.MessageBox]::Show("Wystąpił nieoczekiwany błąd:`n`n$message", "Helpdesk Tools", "OK", "Error") | Out-Null
}
[System.Windows.Forms.Application]::add_ThreadException($threadExceptionHandler)

if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne [System.Threading.ApartmentState]::STA) {
    Write-Warning "Wątek nie działa w trybie STA - okna dialogowe i schowek mogą nie działać poprawnie. Uruchom: pwsh -STA -File HelpdeskTools.ps1"
}

# Zmienne globalne
$Global:AppVersion = "2.0.0"
$Global:ConfigDir = Join-Path -Path $env:APPDATA -ChildPath "HelpdeskTools"
$Global:ConfigPath = Join-Path -Path $Global:ConfigDir -ChildPath "config.json"
$Global:IconsPath = Join-Path -Path $PSScriptRoot -ChildPath "Resources/Icons"
$Global:BasePath = $Global:IconsPath
$Global:AppIconPath = Join-Path -Path $Global:IconsPath -ChildPath "Tools.ico"
$Global:PasswordSpecialCharacters = "!@#$%^&*?"
$Global:PasswordUseWordBased = $false
$Global:PasswordDefaultLength = 12
$Global:ConnectedToExchange = $false
$Global:ConnectedToGraphAPI = $false
$Global:ConnectedToSharepoint = $false
$Global:ConnectedToSharepointPnP = $false
$Global:LogPasswordGeneration = $false
$Global:LogClientIDForPnP = $false
$Global:LastUsedClientID = $null
$Global:IsModuleActiveDirectoryLoaded = $false
$Global:DefaultSharepointSite = $null
$Global:ShowNotifications = $true

# Import modułów (kolejność: najpierw moduły bazowe)
$moduleNames = @(
    "Utils",
    "UIComponents",
    "Config",
    "ModulesConnection",
    "PasswordGenerator",
    "LocalActiveDirectory",
    "GraphAPIM365Users",
    "MailboxesExchangeOnline",
    "GraphAPIIntune",
    "GraphAPISharePoint",
    "MassActions",
    "Dashboard",
    "Startup"
)

foreach ($moduleName in $moduleNames) {
    $path = Join-Path $PSScriptRoot "Modules/$moduleName.psm1"
    if (Test-Path $path) {
        Import-Module $path -Force -Global -DisableNameChecking -ErrorAction Stop
    }
    else {
        Write-Warning "❗ Moduł nie znaleziony: $path"
    }
}

Write-Log -Message "Uruchamianie Helpdesk Tools $($Global:AppVersion) (PowerShell $($PSVersionTable.PSVersion))" -Type "Info"

# Wczytanie konfiguracji (utworzenie pliku przy pierwszym uruchomieniu)
$Global:HTConfig = Ensure-HTConfig -Path $Global:ConfigPath
Apply-HTConfig -Config $Global:HTConfig

# Komponenty GUI (widoki), a następnie obsługa zdarzeń
$guiFiles = @(
    "GUI/MainForm.ps1",
    "GUI/DashboardPanel.ps1",
    "GUI/UsersPanel.ps1",
    "GUI/MailBoxPanel.ps1",
    "GUI/IntunePanel.ps1",
    "GUI/SharePointPanel.ps1",
    "GUI/LocalADPanel.ps1",
    "GUI/MassActionPanel.ps1",
    "GUI/LogsPanel.ps1",
    "GUI/SettingsPanel.ps1",
    "GUI/PasswordGenerator.ps1",
    "GUI/Events/MainForm_Events.ps1",
    "GUI/Events/DashboardPanel_Events.ps1",
    "GUI/Events/UsersPanel_Events.ps1",
    "GUI/Events/MailBoxPanel_Events.ps1",
    "GUI/Events/IntunePanel_Events.ps1",
    "GUI/Events/SharePointPanel_Events.ps1",
    "GUI/Events/LocalADPanel_Events.ps1",
    "GUI/Events/MassAction_Events.ps1",
    "GUI/Events/LogsPanel_Events.ps1",
    "GUI/Events/SettingsPanel_Events.ps1",
    "GUI/Events/PasswordGeneratorForm_Events.ps1"
)

foreach ($file in $guiFiles) {
    . (Join-Path $PSScriptRoot $file)
}
$HT_UI.PasswordGeneratorWindow.Initialized = $true

# Inicjalizacja ustawień formularza (AD, połączenia, sekcja startowa)
Initialize-HelpdeskTools

# Uruchom GUI
try {
    [System.Windows.Forms.Application]::Run($HT_UI.Form)
}
catch {
    Write-Error "Błąd uruchamiania GUI: $_"
}
finally {
    [System.Windows.Forms.Application]::remove_ThreadException($threadExceptionHandler)
    Remove-HTNotifyIcon
    if ($HT_UI -and $HT_UI.Form -and -not $HT_UI.Form.IsDisposed) { $HT_UI.Form.Dispose() }

    # Sprzątanie zmiennych globalnych aplikacji (pozostałe zmienne sesji pozostają bez zmian)
    $appVariables = @(
        "HT_UI", "HTTheme", "HTConfig", "AppVersion", "ConfigDir", "ConfigPath", "IconsPath", "BasePath", "AppIconPath",
        "PasswordSpecialCharacters", "PasswordUseWordBased", "PasswordDefaultLength", "PasswordEmailAdress", "PasswordEmailTitle",
        "ConnectedToExchange", "ConnectedToGraphAPI", "ConnectedToSharepoint", "ConnectedToSharepointPnP",
        "LogPasswordGeneration", "LogClientIDForPnP", "LastUsedClientID", "IsModuleActiveDirectoryLoaded",
        "DefaultSharepointSite", "DefaultUsageLocation", "GraphScopes", "ShowNotifications", "LogFileMaxSizeMB", "ExportPath"
    )
    Remove-Variable -Name $appVariables -Scope Global -ErrorAction SilentlyContinue
}
