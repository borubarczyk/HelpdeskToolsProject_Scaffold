<#
    Wszystkie testy programu lokalnie - to samo, co sprawdza GitHub przy każdej zmianie (bez połączenia z tenantem):
      1. testy jednostkowe Pester (funkcje modułów z atrapami Graph / Exchange / PnP, kontrola statyczna wywołań),
      2. analiza PSScriptAnalyzer (błędy w skryptach),
      3. test interfejsu WPF - budowa okna i wszystkich modułów (tylko Windows).
    Testy funkcji na prawdziwym tenancie: w programie Organizacja > Diagnostyka > «Autotest funkcji».

    Uruchomienie (PowerShell 7):  pwsh -File Tests\Invoke-HTTests.ps1
      -Quick    tylko testy jednostkowe Pester
      -Install  doinstaluj brakujące moduły Pester i PSScriptAnalyzer (PowerShell Gallery, bieżący użytkownik)
      -Path     wybrane pliki testów, np. -Path Tests\Graph.Tests.ps1
#>
param(
    [switch]$Quick,
    [switch]$Install,
    [string[]]$Path = @()
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$failed = New-Object System.Collections.Generic.List[string]

function Test-HTTestModuleAvailable {
    param([Parameter(Mandatory)][string]$Name, [string]$MinimumVersion = '0.0')
    if (@(Get-Module -ListAvailable -Name $Name | Where-Object { $_.Version -ge [version]$MinimumVersion }).Count) { return $true }
    if (-not $Install) {
        Write-Warning "Brak modułu $Name $MinimumVersion+ - uruchom skrypt z parametrem -Install albo: Install-Module $Name -Scope CurrentUser"
        return $false
    }
    Write-Output "Instalowanie modułu $Name…"
    Install-Module -Name $Name -MinimumVersion $MinimumVersion -Scope CurrentUser -Force -SkipPublisherCheck -AllowClobber
    return $true
}

# 1. Pester
if (Test-HTTestModuleAvailable -Name 'Pester' -MinimumVersion '5.5.0') {
    Import-Module Pester -MinimumVersion 5.5.0
    $config = New-PesterConfiguration
    $config.Run.Path = $(if ($Path.Count) { $Path } else { Join-Path $root 'Tests' })
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'Normal'
    $result = Invoke-Pester -Configuration $config
    if ($result.FailedCount -or $result.FailedBlocksCount -or $result.FailedContainersCount) { $failed.Add("Pester: niezaliczone testy $($result.FailedCount), bloki $($result.FailedBlocksCount), pliki $($result.FailedContainersCount)") }
}
else { $failed.Add('Pester: brak modułu') }

# 2. PSScriptAnalyzer
if (-not $Quick -and -not $Path.Count) {
    if (Test-HTTestModuleAvailable -Name 'PSScriptAnalyzer') {
        $issues = @(Invoke-ScriptAnalyzer -Path $root -Recurse -Settings (Join-Path $root 'PSScriptAnalyzerSettings.psd1'))
        if ($issues.Count) {
            $issues | Sort-Object ScriptName, Line | Format-Table RuleName, ScriptName, Line, Message -AutoSize -Wrap | Out-String -Width 200 | Write-Output
            $failed.Add("PSScriptAnalyzer: błędów $($issues.Count)")
        }
        else { Write-Output 'PSScriptAnalyzer: bez błędów.' }
    }
    else { $failed.Add('PSScriptAnalyzer: brak modułu') }
}

# 3. Test interfejsu (WPF - tylko Windows)
if (-not $Quick -and -not $Path.Count) {
    if ($IsWindows) {
        & (Join-Path $PSHOME 'pwsh') -STA -NoProfile -File (Join-Path $PSScriptRoot 'UiSmoke.ps1')
        if ($LASTEXITCODE) { $failed.Add('Test interfejsu: błędy (powyżej)') }
    }
    else { Write-Warning 'Test interfejsu pominięty - wymaga Windows (WPF).' }
}

Write-Output ''
if ($failed.Count) {
    foreach ($f in $failed) { Write-Output "NIE ZALICZONO - $f" }
    exit 1
}
Write-Output 'Wszystkie testy zaliczone.'
