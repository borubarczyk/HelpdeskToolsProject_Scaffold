<#
.SYNOPSIS
    Główny plik uruchamiający aplikację Helpdesk Tools.
.DESCRIPTION
    Aplikacja WPF do zarządzania Active Directory, Microsoft 365 (Graph), Exchange Online, Intune i SharePoint.
    Wygląd i układ są wspólne z Domain Ops (AD-ManagerDiamond) i ServerReview.
    Uruchom w PowerShell 7 (pwsh) jako administrator: pwsh -File .\HelpdeskTools.ps1
.PARAMETER Connect
    Usługa, z którą program połączy się zaraz po uruchomieniu (używane przy ponownym uruchomieniu po konflikcie bibliotek).
.NOTES
    Pliki programu: konfiguracja %APPDATA%\HelpdeskTools\config.json, dziennik %LOCALAPPDATA%\HelpdeskTools\Logs,
    eksport Dokumenty\HelpdeskTools\Eksport (zmiana w Ustawieniach).
#>

#Requires -RunAsAdministrator
#Requires -Version 7

param (
    [ValidateSet("", "Exchange", "Graph", "SharePoint")]
    [string]$Connect = ""
)

$ErrorActionPreference = "Continue"

if (-not $IsWindows) {
    Write-Error "Helpdesk Tools wymaga systemu Windows (interfejs WPF)."
    return
}

# WPF wymaga wątku STA - w razie potrzeby uruchom ponownie w trybie STA
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne [System.Threading.ApartmentState]::STA) {
    Write-Warning "Ponowne uruchamianie w trybie STA..."
    Start-Process -FilePath (Get-Process -Id $PID).Path -ArgumentList @("-STA", "-NoProfile", "-File", "`"$PSCommandPath`"")
    return
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml

# Zmienne globalne
$Global:AppVersion = "3.0.0"
$Global:HTScriptPath = $PSCommandPath
$Global:HTRestarting = $false
$Global:ConfigDir = Join-Path -Path $env:APPDATA -ChildPath "HelpdeskTools"
$Global:LogDir = Join-Path -Path $env:LOCALAPPDATA -ChildPath "HelpdeskTools\Logs"
$Global:ConfigPath = Join-Path -Path $Global:ConfigDir -ChildPath "config.json"
$Global:IconsPath = Join-Path -Path $PSScriptRoot -ChildPath "Resources/Icons"
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
    "Security",
    "UIComponents",
    "Config",
    "ModulesConnection",
    "PasswordGenerator",
    "LocalActiveDirectory",
    "GraphAPIM365Users",
    "MailboxesExchangeOnline",
    "GraphAPIIntune",
    "GraphAPISharePoint",
    "Dashboard",
    "Startup"
)

foreach ($moduleName in $moduleNames) {
    $path = Join-Path $PSScriptRoot "Modules/$moduleName.psm1"
    if (Test-Path $path) {
        Import-Module $path -Force -Global -DisableNameChecking -ErrorAction Stop
    }
    else {
        Write-Warning "Moduł nie znaleziony: $path"
    }
}

# Dziennik operacji w oknie (wpisy sprzed utworzenia okna też trafią do panelu)
Register-HTLogSink -ScriptBlock { param($entry) Add-HTLogItem -Entry $entry }
Remove-HTOldLogs -Days 30
Write-Log -Message "Uruchamianie Helpdesk Tools $($Global:AppVersion) (PowerShell $($PSVersionTable.PSVersion))" -Type "Info"

# Interfejs: okno główne, przestrzenie robocze i moduły
$guiFiles = @(
    "GUI/Common.ps1",
    "GUI/Dialogs.ps1",
    "GUI/MainWindow.ps1",
    "GUI/Workspaces/Dashboard.ps1",
    "GUI/Workspaces/M365Users.ps1",
    "GUI/Workspaces/Exchange.ps1",
    "GUI/Workspaces/Intune.ps1",
    "GUI/Workspaces/Sites.ps1",
    "GUI/Workspaces/SharePoint.ps1",
    "GUI/Workspaces/ActiveDirectory.ps1"
)
foreach ($file in $guiFiles) {
    . (Join-Path $PSScriptRoot $file)
}

try {
    $window = New-HTMainWindow
    foreach ($p in $HT_UI.Panels.Values) { [void]$HT_UI.Controls.targetHost.Children.Add($p.Root) }
    Initialize-HTNavigation

    # Wczytanie konfiguracji (przy pierwszym uruchomieniu pytanie o utworzenie pliku - okno już istnieje)
    $Global:HTConfig = Ensure-HTConfig -Path $Global:ConfigPath
    Apply-HTConfig -Config $Global:HTConfig

    # PIN przed oknem głównym (przy pierwszym uruchomieniu - ustawienie PIN-u)
    if (-not (Unlock-HTApplication)) {
        Write-Log -Message "Program nie został odblokowany - zamykanie." -Type "Warn"
        return
    }

    # Nieobsłużone wyjątki w zdarzeniach interfejsu - wpis w dzienniku i komunikat zamiast zamknięcia programu
    $window.Dispatcher.add_UnhandledException({
            param($s, $e)
            $message = $e.Exception.Message
            if ($e.Exception.InnerException) { $message += "`n$($e.Exception.InnerException.Message)" }
            $e.Handled = $true
            try {
                Write-Log -Message "Nieobsłużony wyjątek: $message" -Type "Error"
                Show-HTError -Text 'Wystąpił nieoczekiwany błąd.' -ErrorObject $message
            }
            catch { Write-Warning $message }
        })

    $script:Started = $false
    $window.add_ContentRendered({
            if ($script:Started) { return }
            $script:Started = $true
            try {
                Update-HTHeaderLayout
                Initialize-HelpdeskTools
                Start-HTAutoLock
                if ($Connect) { Invoke-HTUiAction -Module $null -Action { Invoke-HTConnectionClick -Service $Connect } }
            }
            catch {
                Write-Log -Message "Błąd inicjalizacji: $($_.Exception.Message)" -Type "Error"
            }
        })

    [void]$window.ShowDialog()
}
catch {
    Write-Error "Błąd uruchamiania GUI: $_"
}
finally {
    # Sprzątanie zmiennych globalnych aplikacji (pozostałe zmienne sesji pozostają bez zmian)
    $appVariables = @(
        "HT_UI", "HTConfig", "AppVersion", "ConfigDir", "ConfigPath", "IconsPath", "AppIconPath",
        "PasswordSpecialCharacters", "PasswordUseWordBased", "PasswordDefaultLength", "PasswordEmailAdress", "PasswordEmailTitle",
        "ConnectedToExchange", "ConnectedToGraphAPI", "ConnectedToSharepoint", "ConnectedToSharepointPnP",
        "LogPasswordGeneration", "LogClientIDForPnP", "LastUsedClientID", "IsModuleActiveDirectoryLoaded",
        "DefaultSharepointSite", "DefaultUsageLocation", "GraphScopes", "ShowNotifications", "LogFileMaxSizeMB", "ExportPath",
        "InactiveDays", "AadSyncServer", "LoginTimeoutMinutes", "ConfirmBeforeClose", "AutoLockMinutes", "LogDir", "HTScriptPath", "HTRestarting"
    )
    Remove-Variable -Name $appVariables -Scope Global -ErrorAction SilentlyContinue
}
