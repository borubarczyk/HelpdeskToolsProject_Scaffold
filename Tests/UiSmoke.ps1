<#
    Test interfejsu (Windows, pwsh -STA): ładuje moduły i pliki GUI jak HelpdeskTools.ps1, buduje okno główne, wszystkie
    przestrzenie robocze i moduły (bez połączeń z usługami) oraz paletę poleceń. Błędem jest wyjątek, wpis «Error»
    w dzienniku albo okno dialogowe otwarte w czasie budowy modułu (np. komunikat o błędzie).
    Uruchomienie: pwsh -STA -NoProfile -File Tests/UiSmoke.ps1
#>
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { Write-Host 'Test interfejsu wymaga Windows - pominięto.'; return }
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne [System.Threading.ApartmentState]::STA) { throw 'Uruchom w trybie STA: pwsh -STA -File Tests/UiSmoke.ps1' }
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml

$root = Split-Path -Parent $PSScriptRoot
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ('HelpdeskToolsSmoke_' + [guid]::NewGuid().ToString('N'))
$Global:ConfigDir = Join-Path $temp 'config'
$Global:LogDir = Join-Path $temp 'logs'
$Global:ConfigPath = Join-Path $Global:ConfigDir 'config.json'
$Global:AppVersion = '0.0.0'
$Global:HTScriptPath = Join-Path $root 'HelpdeskTools.ps1'
$Global:IconsPath = Join-Path $root 'Resources/Icons'
$Global:AppIconPath = Join-Path $Global:IconsPath 'Tools.ico'
$Global:ShowNotifications = $false
$Global:ShowOnPremises = $true
$Global:ConnectedToExchange = $false
$Global:ConnectedToGraphAPI = $false
$Global:ConnectedToSharepointPnP = $false
New-Item -ItemType Directory -Path $Global:ConfigDir, $Global:LogDir -Force | Out-Null

# Listy modułów i plików GUI z HelpdeskTools.ps1 (jedno źródło prawdy)
$main = [System.IO.File]::ReadAllText($Global:HTScriptPath)
$moduleBlock = [regex]::Match($main, '(?s)\$moduleNames = @\((.*?)\)').Groups[1].Value
$guiBlock = [regex]::Match($main, '(?s)\$guiFiles = @\((.*?)\)').Groups[1].Value
$moduleNames = @([regex]::Matches($moduleBlock, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
$guiFiles = @([regex]::Matches($guiBlock, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value }) + @('GUI/Workspaces/ActiveDirectory.ps1')
if ($moduleNames.Count -lt 10 -or $guiFiles.Count -lt 5) { throw 'Nie odczytano list modułów z HelpdeskTools.ps1.' }

foreach ($name in $moduleNames) { Import-Module (Join-Path $root "Modules/$name.psm1") -Force -Global -DisableNameChecking }
$Global:HTConfig = (Merge-HTConfig -Config $null).Config
Apply-HTConfig -Config $Global:HTConfig

$Global:SmokeErrors = New-Object System.Collections.Generic.List[string]
$Global:SmokeDialogs = New-Object System.Collections.Generic.List[string]
Register-HTLogSink -ScriptBlock { param($entry) if ($entry.Type -eq 'Error') { $Global:SmokeErrors.Add([string]$entry.Message) } }

# Okna dialogowe w czasie testu są zamykane od razu (i zgłaszane jako błąd)
$closer = [System.Windows.RoutedEventHandler] {
    param($s, $e)
    if ($HT_UI -and [object]::ReferenceEquals($s, $HT_UI.Window)) { return }
    $sections = $s.FindName('fmNav')
    $Global:SmokeDialogs.Add("$($s.Title): $((@($s.FindName('dlgSubtitle'), $s.FindName('msgText')) | Where-Object { $_ } | ForEach-Object { $_.Text }) -join ' ')$(if ($sections) { " [sekcje: $($sections.Children.Count)]" })")
    $window = $s
    [void]$window.Dispatcher.BeginInvoke([action] { try { $window.DialogResult = $false } catch { $window.Close() } }.GetNewClosure())
}
[System.Windows.EventManager]::RegisterClassHandler([System.Windows.Window], [System.Windows.FrameworkElement]::LoadedEvent, $closer)

foreach ($file in $guiFiles) { . (Join-Path $root $file) }

$failures = New-Object System.Collections.Generic.List[string]
$window = New-HTMainWindow
foreach ($p in $HT_UI.Panels.Values) { [void]$HT_UI.Controls.targetHost.Children.Add($p.Root) }
Initialize-HTNavigation

$built = 0
foreach ($ws in @($HT_UI.Workspaces.Keys)) {
    try { Show-HTWorkspace -Key $ws } catch { $failures.Add("Przestrzeń ${ws}: $($_.Exception.Message)") }
    foreach ($d in @($HT_UI.ModuleDefs | Where-Object { $_.Workspace -eq $ws })) {
        $errorsBefore = $Global:SmokeErrors.Count
        $dialogsBefore = $Global:SmokeDialogs.Count
        try {
            Show-HTModule -Key $d.Key
            $built++
        }
        catch { $failures.Add("Moduł $($d.Key): $($_.Exception.Message)") }
        # Zdarzenia okna (zamknięcie dialogów) przed sprawdzeniem
        $frame = New-Object System.Windows.Threading.DispatcherFrame
        [void][System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [System.Windows.Threading.DispatcherOperationCallback] { param($f) $f.Continue = $false; $null }, $frame)
        [System.Windows.Threading.Dispatcher]::PushFrame($frame)
        for ($i = $errorsBefore; $i -lt $Global:SmokeErrors.Count; $i++) { $failures.Add("Moduł $($d.Key) - dziennik: $($Global:SmokeErrors[$i])") }
        for ($i = $dialogsBefore; $i -lt $Global:SmokeDialogs.Count; $i++) { $failures.Add("Moduł $($d.Key) - okno: $($Global:SmokeDialogs[$i])") }
    }
}

# Okna otwierane na żądanie: Ustawienia (formularz z sekcjami) i paleta poleceń - mają się zbudować bez błędów
foreach ($dialog in @(
        @{ Name = 'Ustawienia'; Open = { [void](Show-HTSettingsDialog) }; Expect = '[sekcje: 9]' }
        @{ Name = 'Paleta poleceń'; Open = { Show-HTCommandPalette }; Expect = '' }
    )) {
    $errorsBefore = $Global:SmokeErrors.Count
    $dialogsBefore = $Global:SmokeDialogs.Count
    try { & $dialog.Open } catch { $failures.Add("$($dialog.Name): $($_.Exception.Message)") }
    if ($Global:SmokeDialogs.Count -ne $dialogsBefore + 1) { $failures.Add("$($dialog.Name): okno nie zostało otwarte") }
    elseif ($dialog.Expect -and $Global:SmokeDialogs[$dialogsBefore] -notlike "*$($dialog.Expect)*") { $failures.Add("$($dialog.Name): oczekiwano $($dialog.Expect), jest: $($Global:SmokeDialogs[$dialogsBefore])") }
    for ($i = $errorsBefore; $i -lt $Global:SmokeErrors.Count; $i++) { $failures.Add("$($dialog.Name) - dziennik: $($Global:SmokeErrors[$i])") }
}

$palette = @(Get-HTPaletteItems -Query 'licencje')
if ($palette.Count -eq 0) { $failures.Add('Paleta poleceń: brak wyników dla «licencje».') }
if (@(Get-HTPaletteItems -Query '').Count -eq 0) { $failures.Add('Paleta poleceń: brak poleceń bez zapytania.') }

try { $window.Close() } catch { Write-Verbose $_ }
Close-HTBackground
Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Zbudowano modułów: $built w przestrzeniach: $($HT_UI.Workspaces.Count); paleta: $($palette.Count) wyników."
if ($failures.Count) {
    foreach ($f in $failures) { Write-Host "BŁĄD: $f" }
    exit 1
}
Write-Host 'Test interfejsu: OK'
