BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    Import-HTTestModule -Name "Utils", "ExchangeWorker"
    Initialize-HTTestEnvironment -Root $TestDrive
    # Atrapa modułu Exchange: polecenia z ostrzeżeniem, błędem, potwierdzeniem i długim działaniem
    $Global:HTFakeExoPath = Join-Path $TestDrive 'HTFakeExo.psm1'
    Set-Content -LiteralPath $Global:HTFakeExoPath -Encoding utf8 -Value @'
function Get-HTFakeMailbox {
    [CmdletBinding()]
    param([string]$Identity, [switch]$Archive, [Alias('Props')][string[]]$Properties)
    Write-Warning "Ostrzeżenie dla $Identity"
    [PSCustomObject]@{ Identity = $Identity; Archive = [bool]$Archive; Properties = ($Properties -join ','); Thread = [System.Threading.Thread]::CurrentThread.ManagedThreadId }
}
function Set-HTFakeMailbox {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string]$Identity, $HiddenFromAddressListsEnabled)
    if ($PSCmdlet.ShouldProcess($Identity)) { "ustawiono $Identity $HiddenFromAddressListsEnabled" }
}
function Get-HTFakeError { [CmdletBinding()] param([string]$Identity) Write-Error "Nie znaleziono obiektu $Identity" }
function Get-HTFakeSlow { [CmdletBinding()] param([int]$Seconds = 3) Start-Sleep -Seconds $Seconds; 'koniec' }
function Connect-ExchangeOnline { [CmdletBinding()] param([switch]$ShowBanner) }
Export-ModuleMember -Function *
'@
    Start-HTExchangeWorker -ModulePath $Global:HTFakeExoPath
    $Global:HTFakeProxies = Register-HTExchangeProxies -Names @('Get-HTFakeMailbox', 'Set-HTFakeMailbox', 'Get-HTFakeError', 'Get-HTFakeSlow', 'Connect-ExchangeOnline', 'Get-ChildItem') -Modules @('HTFakeExo')
}

AfterAll {
    Remove-HTExchangeProxies
    Stop-HTExchangeWorker
    Remove-Item function:global:Update-HTUi -ErrorAction SilentlyContinue
}

Describe "Exchange w osobnym wątku" {
    It "tworzy pośredników tylko dla poleceń modułu Exchange (bez Connect-ExchangeOnline i poleceń PowerShell)" {
        $Global:HTFakeProxies | Should -Be 4
        Test-HTExchangeProxies | Should -BeTrue
        Test-Path function:global:Get-HTFakeMailbox | Should -BeTrue
        Test-Path function:global:Connect-ExchangeOnline | Should -BeFalse
        Test-Path function:global:Get-ChildItem | Should -BeFalse
    }
    It "wykonuje polecenie w innym wątku z przełącznikami i aliasami parametrów" {
        $r = Get-HTFakeMailbox -Identity 'jan@firma.pl' -Archive -Props 'a', 'b' -WarningAction SilentlyContinue
        $r.Identity | Should -Be 'jan@firma.pl'
        $r.Archive | Should -BeTrue
        $r.Properties | Should -Be 'a,b'
        $r.Thread | Should -Not -Be ([System.Threading.Thread]::CurrentThread.ManagedThreadId)
    }
    It "zwraca ostrzeżenia polecenia do wywołującego (przechwytywane do dziennika)" {
        $all = @(& { Get-HTFakeMailbox -Identity 'x@firma.pl' } 3>&1)
        @($all | Where-Object { $_ -is [System.Management.Automation.WarningRecord] }).Message | Should -Be 'Ostrzeżenie dla x@firma.pl'
    }
    It "przekazuje -Confirm:`$false i zwraca wynik zmiany" {
        Set-HTFakeMailbox -Identity 'x@firma.pl' -HiddenFromAddressListsEnabled $true -Confirm:$false | Should -Be 'ustawiono x@firma.pl True'
    }
    It "błąd polecenia: -ErrorAction Stop rzuca wyjątek z treścią błędu, SilentlyContinue - nie" {
        { Get-HTFakeError -Identity 'zz' -ErrorAction Stop } | Should -Throw '*Nie znaleziono obiektu zz*'
        $e = $null
        Get-HTFakeError -Identity 'yy' -ErrorAction SilentlyContinue -ErrorVariable e
        @($e).Count | Should -Be 1
    }
    It "«Przerwij» zatrzymuje polecenie w trakcie (odświeżanie okna wywołuje zatrzymanie)" {
        $Global:HTStopAt = [datetime]::Now.AddMilliseconds(600)
        function global:Update-HTUi { if ($Global:HTStopAt -and [datetime]::Now -ge $Global:HTStopAt) { $Global:HTStopAt = $null; [void](Stop-HTExchangeWorkerCommand) } }
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        { Get-HTFakeSlow -Seconds 6 } | Should -Throw '*Przerwano*'
        $sw.Elapsed.TotalSeconds | Should -BeLessThan 4
        Remove-Item function:global:Update-HTUi
        Get-HTFakeSlow -Seconds 0 | Should -Be 'koniec'
    }
}

Describe "Pośrednicy poleceń Exchange - treść i lista poleceń" {
    It "buduje funkcję z parametrami bez typów, przełącznikami i aliasami" {
        $text = ConvertTo-HTExchangeProxyScript -Descriptor ([PSCustomObject]@{ Name = 'Get-EXOMailbox'; Parameters = @(
                    [PSCustomObject]@{ Name = 'Identity'; Switch = $false; Aliases = @() }
                    [PSCustomObject]@{ Name = 'Archive'; Switch = $true; Aliases = @() }
                    [PSCustomObject]@{ Name = 'PropertySets'; Switch = $false; Aliases = @('PS') }
                    [PSCustomObject]@{ Name = 'Bad Name'; Switch = $false; Aliases = @() }
                ) })
        $text | Should -Match "\[Parameter\(\)\]\`$Identity"
        $text | Should -Match "\[switch\]\`$Archive"
        $text | Should -Match "\[Alias\('PS'\)\]\`$PropertySets"
        $text | Should -Not -Match 'Bad Name'
        $text | Should -Match "Invoke-HTExchangeProxyCall -Name 'Get-EXOMailbox'"
        { [scriptblock]::Create($text) } | Should -Not -Throw
    }
    It "znajduje polecenia Exchange używane w programie" {
        $names = @(Get-HTProgramCommandNames)
        $names | Should -Contain 'Get-EXOMailbox'
        $names | Should -Contain 'Set-Mailbox'
        $names | Should -Contain 'Get-OrganizationConfig'
    }
}
