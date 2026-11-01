# Usługi Microsoft 365 w osobnych wątkach (runspace): Exchange Online i SharePoint (PnP)
<#
    Połączenie z usługą i wszystkie jej polecenia wykonują się w osobnym wątku usługi, a nie w wątku okna.
    W wątku okna działają funkcje-pośrednicy o nazwach poleceń usługi używanych przez program (Get-EXOMailbox,
    Set-Mailbox, Get-PnPList…): przekazują parametry do wątku usługi i czekają na wynik, odświeżając w tym czasie okno -
    istniejący kod programu działa bez zmian, a okno nie zamarza w czasie długich poleceń. Ostrzeżenia i błędy polecenia
    wracają do wywołującego (z jego -ErrorAction). «Przerwij» zatrzymuje bieżące polecenie.
    Wyłączenie (łączenie w wątku okna): Ustawienia > Microsoft 365 i Exchange > «Exchange w osobnym wątku»,
    Ustawienia > SharePoint > «SharePoint (PnP) w osobnym wątku».
#>

$script:Workers = @{}
# Parametry wspólne obsługiwane przez pośrednika (w wątku okna), nieprzekazywane do polecenia w wątku usługi
$script:LocalOnlyParameters = @('ErrorAction', 'WarningAction', 'InformationAction', 'ErrorVariable', 'WarningVariable', 'InformationVariable',
    'OutVariable', 'OutBuffer', 'PipelineVariable', 'Verbose', 'Debug', 'ProgressAction')
# Usługi: moduły, z których pochodzą polecenia (w wątku usługi), polecenia zawsze przekazywane i nigdy nieprzekazywane
$script:ServiceDefinitions = @{
    Exchange   = @{ Modules = @('ExchangeOnlineManagement', 'tmp*'); Always = @('Get-ConnectionInformation', 'Disconnect-ExchangeOnline', 'Get-OrganizationConfig'); Never = @('Connect-ExchangeOnline') }
    SharePoint = @{ Modules = @('PnP.PowerShell'); Always = @('Connect-PnPOnline', 'Disconnect-PnPOnline', 'Get-PnPConnection'); Never = @() }
}
$script:ProgramCommandNames = $null

function Get-HTServiceWorkerState {
    param([string]$Service = 'Exchange')
    if (-not $script:Workers.ContainsKey($Service)) { $script:Workers[$Service] = @{ Runspace = $null; ModulePath = ''; Current = $null; Proxies = @() } }
    return $script:Workers[$Service]
}

function Test-HTServiceWorker {
    # Czy wątek usługi działa
    param([string]$Service = 'Exchange')
    $rs = (Get-HTServiceWorkerState $Service).Runspace
    return [bool]($rs -and "$($rs.RunspaceStateInfo.State)" -eq 'Opened')
}

function Test-HTServiceProxies {
    param([string]$Service = 'Exchange')
    return (@((Get-HTServiceWorkerState $Service).Proxies).Count -gt 0)
}

function Start-HTServiceWorker {
    <#
        Uruchamia wątek usługi z modułem -ModulePath (manifest modułu usługi; w testach - dowolny moduł).
        Działający wątek z tym samym modułem jest używany ponownie.
    #>
    param([Parameter(Mandatory)][string]$ModulePath, [string]$Service = 'Exchange')
    $state = Get-HTServiceWorkerState $Service
    if ((Test-HTServiceWorker $Service) -and $state.ModulePath -eq $ModulePath) { return }
    Stop-HTServiceWorker -Service $Service
    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault2()
    if ($IsWindows) { $iss.ExecutionPolicy = [Microsoft.PowerShell.ExecutionPolicy]::Bypass }
    $rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($iss)
    # Logowanie (okno WAM w starszych modułach) wymaga wątku STA - tylko Windows
    if ($IsWindows) { $rs.ApartmentState = [System.Threading.ApartmentState]::STA }
    $rs.ThreadOptions = [System.Management.Automation.Runspaces.PSThreadOptions]::ReuseThread
    $rs.Open()
    $state.Runspace = $rs
    $state.ModulePath = ''
    try {
        $r = Invoke-HTServiceWorker -Service $Service -Script 'param($Path) Import-Module -Name $Path -Global -ErrorAction Stop -WarningAction SilentlyContinue -DisableNameChecking | Out-Null' -Arguments @{ Path = $ModulePath }
        if (@($r.Errors).Count) { throw $r.Errors[0].Exception }
    }
    catch {
        Stop-HTServiceWorker -Service $Service
        throw (New-Object System.InvalidOperationException("Nie wczytano modułu w wątku $($Service): $($_.Exception.Message)"))
    }
    $state.ModulePath = $ModulePath
    $debug = Get-Command -Name Write-HTDebug -ErrorAction Ignore
    if ($debug) { & $debug { "Wątek $($Service): uruchomiony, moduł $ModulePath" } }
}

function Stop-HTServiceWorker {
    # Zamyka wątek usługi (-All: wszystkie) - przy zamykaniu programu i przed ponownym uruchomieniem
    param([string]$Service = 'Exchange', [switch]$All)
    $services = if ($All) { @($script:Workers.Keys) } else { @($Service) }
    foreach ($s in $services) {
        $state = Get-HTServiceWorkerState $s
        $rs = $state.Runspace
        $state.Runspace = $null
        $state.ModulePath = ''
        if ($rs) { try { $rs.Dispose() } catch { Write-Verbose "Wątek $($s): $_" } }
    }
}

function Stop-HTServiceWorkerCommand {
    # «Przerwij»: zatrzymuje bieżące polecenie we wszystkich wątkach usług. Zwraca $true, gdy coś było uruchomione.
    $stopped = $false
    foreach ($state in @($script:Workers.Values)) {
        $ps = $state.Current
        if (-not $ps) { continue }
        try { [void]$ps.BeginStop($null, $null); $stopped = $true } catch { Write-Verbose $_ }
    }
    return $stopped
}

function Invoke-HTServiceWorker {
    <#
        Wykonuje polecenie (-Command z -Parameters) albo skrypt (-Script z -Arguments) w wątku usługi i czeka na wynik,
        odświeżając okno programu (Update-HTUi). Zwraca @{ Output; Errors; Warnings }. Błąd kończący - wyjątek,
        przerwanie («Przerwij») - OperationCanceledException.
    #>
    param(
        [string]$Service = 'Exchange',
        [string]$Command = '',
        [System.Collections.IDictionary]$Parameters = @{},
        [string]$Script = '',
        [System.Collections.IDictionary]$Arguments = @{}
    )
    $state = Get-HTServiceWorkerState $Service
    $serviceName = if ($Service -eq 'SharePoint') { 'SharePoint (PnP)' } else { $Service }
    if (-not (Test-HTServiceWorker $Service)) { throw (New-Object System.InvalidOperationException("Wątek $serviceName nie działa - połącz się ponownie z usługą.")) }
    $rs = $state.Runspace
    $pump = Get-Command -Name Update-HTUi -ErrorAction Ignore
    # Wywołanie zagnieżdżone (zdarzenie okna w czasie oczekiwania na inne polecenie) - czeka, aż wątek będzie wolny
    while ("$($rs.RunspaceAvailability)" -ne 'Available') {
        if ($pump) { & $pump }
        Start-Sleep -Milliseconds 20
        if (-not (Test-HTServiceWorker $Service)) { throw (New-Object System.InvalidOperationException("Wątek $serviceName został zamknięty.")) }
    }
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $rs
    if ($Script) {
        # Własny zakres skryptu - zmienne skryptu (np. $PSModuleAutoLoadingPreference) nie zostają w wątku usługi
        [void]$ps.AddScript($Script, $true)
        if ($Arguments.Count) { [void]$ps.AddParameters($Arguments) }
    }
    else {
        [void]$ps.AddCommand($Command)
        foreach ($k in @($Parameters.Keys)) { [void]$ps.AddParameter([string]$k, $Parameters[$k]) }
    }
    $inputData = New-Object 'System.Management.Automation.PSDataCollection[psobject]'
    $inputData.Complete()
    $output = New-Object 'System.Management.Automation.PSDataCollection[psobject]'
    $previous = $state.Current
    $state.Current = $ps
    $started = [datetime]::Now
    $longWait = $false
    $what = if ($Command) { $Command } else { "polecenie $serviceName" }
    try {
        $handle = $ps.BeginInvoke($inputData, $output)
        while (-not $handle.IsCompleted) {
            if ($pump) { & $pump }
            [void]$handle.AsyncWaitHandle.WaitOne(25)
            # Dłuższe polecenie: «Przerwij» na pasku stanu
            if (-not $longWait -and ([datetime]::Now - $started).TotalSeconds -ge 1) {
                $longWait = $true
                $show = Get-Command -Name Set-HTCancelVisible -ErrorAction Ignore
                if ($show) { & $show $true }
            }
        }
        try { [void]$ps.EndInvoke($handle) }
        catch [System.Management.Automation.PipelineStoppedException] { throw (New-Object System.OperationCanceledException("Przerwano: $what")) }
        catch {
            $inner = if ($_.Exception.InnerException) { $_.Exception.InnerException } else { $_.Exception }
            throw $inner
        }
        if ("$($ps.InvocationStateInfo.State)" -eq 'Stopped') { throw (New-Object System.OperationCanceledException("Przerwano: $what")) }
        return [PSCustomObject]@{
            Output   = @($output | ForEach-Object { $_ })
            Errors   = @($ps.Streams.Error | ForEach-Object { $_ })
            Warnings = @($ps.Streams.Warning | ForEach-Object { $_ })
        }
    }
    finally {
        $state.Current = $previous
        $ps.Dispose()
        if ($longWait) {
            $hide = Get-Command -Name Hide-HTCancelIfIdle -ErrorAction Ignore
            if ($hide) { & $hide }
        }
    }
}

function Invoke-HTServiceProxyCall {
    <#
        Wywołanie pośrednika: parametry do wątku usługi, wynik do wywołującego. Ostrzeżenia i błędy polecenia są
        zgłaszane przez pośrednika (-Caller = $PSCmdlet), więc działa -ErrorAction / -WarningAction wywołującego.
    #>
    param([Parameter(Mandatory)][string]$Name, [System.Collections.IDictionary]$Bound = @{}, $Caller = $null, [string]$Service = 'Exchange')
    $params = [ordered]@{}
    foreach ($k in @($Bound.Keys)) { if ($script:LocalOnlyParameters -notcontains [string]$k) { $params[[string]$k] = $Bound[$k] } }
    $r = Invoke-HTServiceWorker -Service $Service -Command $Name -Parameters $params
    foreach ($w in @($r.Warnings)) { if ($Caller) { $Caller.WriteWarning([string]$w.Message) } else { Write-Warning ([string]$w.Message) } }
    foreach ($e in @($r.Errors)) { if ($Caller) { $Caller.WriteError($e) } else { Write-Error -ErrorRecord $e } }
    foreach ($o in @($r.Output)) { $o }
}

function ConvertTo-HTServiceProxyScript {
    <#
        Treść funkcji-pośrednika dla opisu polecenia @{ Name; Parameters = @(@{ Name; Switch; Aliases }) }:
        parametry bez typów (konwersję robi polecenie w wątku usługi), przełączniki jako [switch].
    #>
    param([Parameter(Mandatory)]$Descriptor, [string]$Service = 'Exchange')
    $lines = foreach ($p in @($Descriptor.Parameters)) {
        $name = [string]$p.Name
        if ($name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') { continue }
        $aliases = @($p.Aliases | Where-Object { "$_" -match '^[A-Za-z0-9_\-]+$' })
        $alias = if ($aliases.Count) { "[Alias($(@($aliases | ForEach-Object { "'$_'" }) -join ', '))]" } else { '' }
        $type = if ($p.Switch) { '[switch]' } else { '' }
        "    [Parameter()]$alias$type`$$name"
    }
    $commandName = ([string]$Descriptor.Name) -replace "'", "''"
    $serviceName = $Service -replace "'", "''"
    return @"
[CmdletBinding(SupportsShouldProcess = `$true, ConfirmImpact = 'None')]
param(
$(@($lines) -join ",`n")
)
Invoke-HTServiceProxyCall -Service '$serviceName' -Name '$commandName' -Bound `$PSBoundParameters -Caller `$PSCmdlet
"@
}

function Get-HTProgramCommandNames {
    # Nazwy poleceń używanych w plikach programu (moduły, interfejs) - do wyboru poleceń usług do pośredników
    param([string]$Root = (Split-Path -Parent $PSScriptRoot))
    if ($script:ProgramCommandNames -and -not $PSBoundParameters.ContainsKey('Root')) { return $script:ProgramCommandNames }
    $names = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $files = @(Get-ChildItem -Path (Join-Path $Root 'Modules') -Filter '*.psm1' -File -ErrorAction SilentlyContinue) +
        @(Get-ChildItem -Path (Join-Path $Root 'GUI') -Recurse -Filter '*.ps1' -File -ErrorAction SilentlyContinue)
    foreach ($f in $files) {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$null)
        foreach ($c in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)) {
            $n = $c.GetCommandName()
            if ($n -and $n -match '^[A-Za-z]+-[A-Za-z0-9]+$') { [void]$names.Add($n) }
        }
        # Nazwy poleceń zapisane jako tekst - wywołania dynamiczne (& $command, Get-Command -Name 'Get-MessageTraceV2')
        foreach ($c in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true)) {
            $v = [string]$c.Value
            if ($v -match '^[A-Z][a-z]+-[A-Za-z][A-Za-z0-9]+$') { [void]$names.Add($v) }
        }
    }
    $result = @($names | Sort-Object)
    if (-not $PSBoundParameters.ContainsKey('Root')) { $script:ProgramCommandNames = $result }
    return $result
}

function Register-HTServiceProxies {
    <#
        Tworzy w wątku okna funkcje-pośredników dla poleceń z -Names (i stałej listy usługi), które w wątku usługi
        pochodzą z modułów usługi (albo -Modules). Zwraca liczbę pośredników.
    #>
    param([string[]]$Names = @(), [string]$Service = 'Exchange', [string[]]$Modules = @())
    $definition = $script:ServiceDefinitions[$Service]
    if (-not $Modules.Count) { $Modules = if ($definition) { @($definition.Modules) } else { @() } }
    $always = if ($definition) { @($definition.Always) } else { @() }
    $never = if ($definition) { @($definition.Never) } else { @() }
    $all = @(@($Names) + $always | Where-Object { $_ -and $never -notcontains $_ } | Select-Object -Unique)
    # Tylko polecenia z modułów usługi już wczytanych w wątku (ExportedCommands) - bez Get-Command po nazwach:
    # Get-Command automatycznie wczytuje każdy moduł z poleceniem o tej nazwie (np. ActiveDirectory, Graph, PnP
    # w wątku Exchange), co trwa długo albo się zawiesza (moduł AD łączy się z kontrolerem domeny)
    $describe = @'
param($Names, $Modules)
$PSModuleAutoLoadingPreference = 'None'
$wanted = New-Object 'System.Collections.Generic.HashSet[string]' ([string[]]@($Names), [System.StringComparer]::OrdinalIgnoreCase)
$seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
$common = @([System.Management.Automation.Cmdlet]::CommonParameters) + @([System.Management.Automation.Cmdlet]::OptionalCommonParameters)
foreach ($m in @(Get-Module)) {
    $module = [string]$m.Name
    if (-not @($Modules | Where-Object { $module -like $_ }).Count) { continue }
    foreach ($c in @($m.ExportedCommands.Values)) {
        if ("$($c.CommandType)" -notin 'Function', 'Cmdlet') { continue }
        if (-not $wanted.Contains($c.Name) -or -not $seen.Add($c.Name)) { continue }
        $params = foreach ($p in @($c.Parameters.Values)) {
            if ($common -contains $p.Name) { continue }
            [PSCustomObject]@{ Name = $p.Name; Switch = [bool]$p.SwitchParameter; Aliases = @($p.Aliases) }
        }
        [PSCustomObject]@{ Name = $c.Name; Module = $module; Parameters = @($params) }
    }
}
'@
    $r = Invoke-HTServiceWorker -Service $Service -Script $describe -Arguments @{ Names = [string[]]$all; Modules = [string[]]$Modules }
    $state = Get-HTServiceWorkerState $Service
    $created = New-Object System.Collections.Generic.List[string]
    foreach ($d in @($r.Output)) {
        $text = ConvertTo-HTServiceProxyScript -Descriptor $d -Service $Service
        Set-Item -Path "function:global:$($d.Name)" -Value ([scriptblock]::Create($text))
        $created.Add([string]$d.Name)
    }
    # Pośrednicy z poprzedniego połączenia, których już nie ma - usunięci
    foreach ($old in @($state.Proxies | Where-Object { $created -notcontains $_ })) { Remove-HTServiceProxyFunction -Name $old }
    $state.Proxies = $created.ToArray()
    $debug = Get-Command -Name Write-HTDebug -ErrorAction Ignore
    if ($debug) { & $debug { "Wątek $($Service): pośrednicy poleceń: $($created.Count) ($($created -join ', '))" } }
    return $created.Count
}

function Remove-HTServiceProxyFunction {
    <#
        Usuwa funkcję-pośrednika (tylko pośrednika - inną funkcję o tej nazwie zostawia). Uwaga: Remove-Item ze ścieżką
        «function:global:Nazwa» po cichu niczego nie usuwa - funkcja globalna jest znajdowana przez «Function:Nazwa».
    #>
    param([Parameter(Mandatory)][string]$Name)
    $f = Get-Item -LiteralPath "Function:$Name" -ErrorAction Ignore
    if ($f -and "$($f.Definition)" -match 'Invoke-HTServiceProxyCall') { Remove-Item -LiteralPath "Function:$Name" -Force -ErrorAction SilentlyContinue }
}

function Remove-HTServiceProxies {
    # Usuwa pośredników usługi - np. przed połączeniem w wątku okna (polecenia wracają do zwykłego działania)
    param([string]$Service = 'Exchange')
    $state = Get-HTServiceWorkerState $Service
    foreach ($name in @($state.Proxies)) { Remove-HTServiceProxyFunction -Name $name }
    $state.Proxies = @()
}

function Connect-HTExchangeWorker {
    <#
        Exchange: łączy z Exchange Online w wątku Exchange (Connect-ExchangeOnline z -Parameters) i tworzy pośredników
        poleceń używanych przez program (tymczasowy moduł poleceń Exchange powstaje dopiero po połączeniu).
    #>
    param([Parameter(Mandatory)][string]$ModulePath, [System.Collections.IDictionary]$Parameters = @{})
    Start-HTServiceWorker -Service 'Exchange' -ModulePath $ModulePath
    $params = [ordered]@{}
    foreach ($k in @($Parameters.Keys)) { if ($script:LocalOnlyParameters -notcontains [string]$k) { $params[[string]$k] = $Parameters[$k] } }
    $debug = Get-Command -Name Write-HTDebug -ErrorAction Ignore
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $r = Invoke-HTServiceWorker -Service 'Exchange' -Command 'Connect-ExchangeOnline' -Parameters $params
    if ($debug) { & $debug { "Wątek Exchange: Connect-ExchangeOnline zakończone po $([int]$sw.Elapsed.TotalSeconds) s (błędy: $(@($r.Errors).Count))" } }
    if (@($r.Errors).Count) { throw $r.Errors[0].Exception }
    foreach ($w in @($r.Warnings)) { Write-Warning ([string]$w.Message) }
    $sw.Restart()
    [void](Register-HTServiceProxies -Service 'Exchange' -Names (Get-HTProgramCommandNames))
    if ($debug) { & $debug { "Wątek Exchange: pośrednicy gotowi po $([math]::Round($sw.Elapsed.TotalSeconds, 1)) s" } }
}

function Enable-HTSharePointWorker {
    <#
        SharePoint (PnP): uruchamia wątek SharePoint z modułem PnP.PowerShell i tworzy pośredników (także
        Connect-PnPOnline) - polecenia PnP istnieją od razu po wczytaniu modułu, więc logowanie też idzie przez wątek.
    #>
    param([Parameter(Mandatory)][string]$ModulePath)
    Start-HTServiceWorker -Service 'SharePoint' -ModulePath $ModulePath
    if (-not (Test-HTServiceProxies -Service 'SharePoint')) { [void](Register-HTServiceProxies -Service 'SharePoint' -Names (Get-HTProgramCommandNames)) }
}
