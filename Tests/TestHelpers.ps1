# Wspólne przygotowanie testów: import modułów bez GUI (UIComponents wymaga WPF - tylko Windows)
$script:RepoRoot = Split-Path -Parent $PSScriptRoot

function Import-HTTestModule {
    param ([Parameter(Mandatory)][string[]]$Name)
    foreach ($module in $Name) {
        Import-Module (Join-Path $script:RepoRoot "Modules/$module.psm1") -Force -Global -DisableNameChecking -WarningAction SilentlyContinue
    }
}

function Initialize-HTTestEnvironment {
    param ([Parameter(Mandatory)][string]$Root)
    $Global:ConfigDir = Join-Path $Root "config"
    $Global:ConfigPath = Join-Path $Global:ConfigDir "config.json"
    $Global:ShowNotifications = $false
    $Global:HT_UI = $null
    $Global:PasswordSpecialCharacters = "!@#$%^&*?"
    $Global:PasswordDefaultLength = 12
}

# Tworzy globalną atrapę polecenia z podanymi parametrami (wymagane przez Mock -ParameterFilter)
function New-HTTestStub {
    param (
        [Parameter(Mandatory)][string]$Name,
        [string[]]$Parameters = @(),
        [string[]]$Switches = @()
    )
    $params = @($Parameters | ForEach-Object { "`$$_" }) + @($Switches | ForEach-Object { "[switch]`$$_" })
    $body = "[CmdletBinding()] param($($params -join ', '))"
    Set-Item -Path "function:global:$Name" -Value ([scriptblock]::Create($body))
}
