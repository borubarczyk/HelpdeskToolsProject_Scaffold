BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    Import-HTTestModule -Name "Utils", "ServiceWorker"
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
    # Atrapa modułu PnP: połączenie zapamiętane w wątku SharePoint, połączenie zwracane (-ReturnConnection) i lista
    $Global:HTFakePnPPath = Join-Path $TestDrive 'HTFakePnP.psm1'
    Set-Content -LiteralPath $Global:HTFakePnPPath -Encoding utf8 -Value @'
$script:Current = $null
function Connect-PnPOnline {
    [CmdletBinding()]
    param([string]$Url, [string]$ClientId, [switch]$Interactive, [switch]$ReturnConnection)
    $c = [PSCustomObject]@{ Url = $Url; ClientId = $ClientId; Thread = [System.Threading.Thread]::CurrentThread.ManagedThreadId }
    if ($ReturnConnection) { return $c }
    $script:Current = $c
}
function Get-PnPConnection { [CmdletBinding()] param() if (-not $script:Current) { throw 'Brak połączenia PnP.' }; $script:Current }
function Get-HTFakePnPList {
    [CmdletBinding()]
    param([string]$Identity, $Connection)
    $site = if ($Connection) { $Connection.Url } else { (Get-PnPConnection).Url }
    [PSCustomObject]@{ Title = $Identity; Site = $site; Thread = [System.Threading.Thread]::CurrentThread.ManagedThreadId }
}
function Get-HTFakePnPSlow { [CmdletBinding()] param([int]$Seconds = 3) Start-Sleep -Seconds $Seconds; 'koniec PnP' }
Export-ModuleMember -Function *
'@
    Start-HTServiceWorker -Service 'Exchange' -ModulePath $Global:HTFakeExoPath
    $Global:HTFakeProxies = Register-HTServiceProxies -Service 'Exchange' -Names @('Get-HTFakeMailbox', 'Set-HTFakeMailbox', 'Get-HTFakeError', 'Get-HTFakeSlow', 'Connect-ExchangeOnline', 'Get-ChildItem') -Modules @('HTFakeExo')
}

AfterAll {
    Remove-HTServiceProxies -Service 'Exchange'
    Remove-HTServiceProxies -Service 'SharePoint'
    Stop-HTServiceWorker -All
    Remove-Item -LiteralPath Function:Update-HTUi -ErrorAction SilentlyContinue
}

Describe "Exchange w osobnym wątku" {
    It "tworzy pośredników tylko dla poleceń modułu Exchange (bez Connect-ExchangeOnline i poleceń PowerShell)" {
        $Global:HTFakeProxies | Should -Be 4
        Test-HTServiceProxies -Service 'Exchange' | Should -BeTrue
        Test-Path function:global:Get-HTFakeMailbox | Should -BeTrue
        # Bez pośrednika (inna funkcja o tej nazwie, np. atrapa z innego testu, może istnieć)
        "$((Get-Command -Name Connect-ExchangeOnline -ErrorAction Ignore).Definition)" | Should -Not -Match 'Invoke-HTServiceProxyCall'
        (Get-Command -Name Get-ChildItem).CommandType | Should -Be 'Cmdlet'
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
        function global:Update-HTUi { if ($Global:HTStopAt -and [datetime]::Now -ge $Global:HTStopAt) { $Global:HTStopAt = $null; [void](Stop-HTServiceWorkerCommand) } }
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        { Get-HTFakeSlow -Seconds 6 } | Should -Throw '*Przerwano*'
        $sw.Elapsed.TotalSeconds | Should -BeLessThan 4
        Remove-Item -LiteralPath Function:Update-HTUi
        Get-HTFakeSlow -Seconds 0 | Should -Be 'koniec'
    }
    It "nie wczytuje w wątku innych modułów z poleceniami o nazwach używanych w programie (np. AD, Graph, PnP)" {
        $root = Join-Path $TestDrive 'mods'
        $dir = Join-Path $root 'HTAutoMod'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $dir 'HTAutoMod.psm1') -Value 'function Get-HTAutoThing { 1 }; Export-ModuleMember -Function Get-HTAutoThing'
        $old = $env:PSModulePath
        try {
            $env:PSModulePath = $root + [System.IO.Path]::PathSeparator + $old
            $count = Register-HTServiceProxies -Service 'Exchange' -Names @('Get-HTFakeMailbox', 'Set-HTFakeMailbox', 'Get-HTFakeError', 'Get-HTFakeSlow', 'Get-HTAutoThing') -Modules @('HTFakeExo', 'HTAutoMod')
            $loaded = @((Invoke-HTServiceWorker -Service 'Exchange' -Script '@(Get-Module).Name').Output)
        }
        finally { $env:PSModulePath = $old }
        $count | Should -Be 4
        $loaded | Should -Not -Contain 'HTAutoMod'
        Test-Path function:global:Get-HTAutoThing | Should -BeFalse
        Test-Path function:global:Get-HTFakeMailbox | Should -BeTrue
    }
}

Describe "SharePoint (PnP) w osobnym wątku" {
    BeforeAll {
        Start-HTServiceWorker -Service 'SharePoint' -ModulePath $Global:HTFakePnPPath
        $Global:HTFakePnPProxies = Register-HTServiceProxies -Service 'SharePoint' -Names @('Get-HTFakePnPList', 'Get-HTFakePnPSlow') -Modules @('HTFakePnP')
    }
    It "logowanie PnP też idzie przez wątek SharePoint (pośrednik Connect-PnPOnline i Get-PnPConnection)" {
        $Global:HTFakePnPProxies | Should -Be 4
        Test-Path function:global:Connect-PnPOnline | Should -BeTrue
        Test-Path function:global:Get-PnPConnection | Should -BeTrue
        Test-HTServiceProxies -Service 'SharePoint' | Should -BeTrue
    }
    It "zapamiętuje połączenie w wątku SharePoint między poleceniami" {
        Connect-PnPOnline -Url 'https://firma.sharepoint.com/sites/Dzial' -ClientId 'c-1' -Interactive
        (Get-PnPConnection).Url | Should -Be 'https://firma.sharepoint.com/sites/Dzial'
        $list = Get-HTFakePnPList -Identity 'Dokumenty'
        $list.Site | Should -Be 'https://firma.sharepoint.com/sites/Dzial'
        $list.Thread | Should -Not -Be ([System.Threading.Thread]::CurrentThread.ManagedThreadId)
    }
    It "zwraca dodatkowe połączenie (-ReturnConnection) jako obiekt do parametru -Connection" {
        $admin = Connect-PnPOnline -Url 'https://firma-admin.sharepoint.com' -ClientId 'c-1' -Interactive -ReturnConnection
        (Get-HTFakePnPList -Identity 'Witryny' -Connection $admin).Site | Should -Be 'https://firma-admin.sharepoint.com'
        (Get-PnPConnection).Url | Should -Be 'https://firma.sharepoint.com/sites/Dzial'
    }
    It "działa w innym wątku niż Exchange; zamknięcie wątku SharePoint nie zamyka Exchange" {
        $sp = (Get-HTFakePnPList -Identity 'A').Thread
        $exo = (Get-HTFakeMailbox -Identity 'a@firma.pl' -WarningAction SilentlyContinue).Thread
        $sp | Should -Not -Be $exo
        Stop-HTServiceWorker -Service 'SharePoint'
        Test-HTServiceWorker -Service 'SharePoint' | Should -BeFalse
        Test-HTServiceWorker -Service 'Exchange' | Should -BeTrue
        { Get-HTFakePnPList -Identity 'A' -ErrorAction Stop } | Should -Throw '*SharePoint (PnP) nie działa*'
        Start-HTServiceWorker -Service 'SharePoint' -ModulePath $Global:HTFakePnPPath
        (Get-HTFakePnPList -Identity 'B' -Connection ([PSCustomObject]@{ Url = 'https://x' })).Site | Should -Be 'https://x'
    }
    It "«Przerwij» zatrzymuje polecenie PnP w trakcie" {
        $Global:HTStopAt = [datetime]::Now.AddMilliseconds(600)
        function global:Update-HTUi { if ($Global:HTStopAt -and [datetime]::Now -ge $Global:HTStopAt) { $Global:HTStopAt = $null; [void](Stop-HTServiceWorkerCommand) } }
        { Get-HTFakePnPSlow -Seconds 6 } | Should -Throw '*Przerwano*'
        Remove-Item -LiteralPath Function:Update-HTUi
        Get-HTFakePnPSlow -Seconds 0 | Should -Be 'koniec PnP'
    }
    It "usuwa pośredników SharePoint bez ruszania pośredników Exchange" {
        Remove-HTServiceProxies -Service 'SharePoint'
        Test-Path function:global:Connect-PnPOnline | Should -BeFalse
        Test-Path function:global:Get-HTFakePnPList | Should -BeFalse
        Test-Path function:global:Get-HTFakeMailbox | Should -BeTrue
    }
}

Describe "Pośrednicy poleceń usług - treść i lista poleceń" {
    It "buduje funkcję z parametrami bez typów, przełącznikami i aliasami" {
        $text = ConvertTo-HTServiceProxyScript -Service 'Exchange' -Descriptor ([PSCustomObject]@{ Name = 'Get-EXOMailbox'; Parameters = @(
                    [PSCustomObject]@{ Name = 'Identity'; Switch = $false; Aliases = @() }
                    [PSCustomObject]@{ Name = 'Archive'; Switch = $true; Aliases = @() }
                    [PSCustomObject]@{ Name = 'PropertySets'; Switch = $false; Aliases = @('PS') }
                    [PSCustomObject]@{ Name = 'Bad Name'; Switch = $false; Aliases = @() }
                ) })
        $text | Should -Match "\[Parameter\(\)\]\`$Identity"
        $text | Should -Match "\[switch\]\`$Archive"
        $text | Should -Match "\[Alias\('PS'\)\]\`$PropertySets"
        $text | Should -Not -Match 'Bad Name'
        $text | Should -Match "Invoke-HTServiceProxyCall -Service 'Exchange' -Name 'Get-EXOMailbox'"
        { [scriptblock]::Create($text) } | Should -Not -Throw
    }
    It "znajduje polecenia Exchange i PnP używane w programie" {
        $names = @(Get-HTProgramCommandNames)
        $names | Should -Contain 'Get-EXOMailbox'
        $names | Should -Contain 'Set-Mailbox'
        $names | Should -Contain 'Get-OrganizationConfig'
        $names | Should -Contain 'Get-PnPList'
        $names | Should -Contain 'Invoke-PnPQuery'
    }
}
