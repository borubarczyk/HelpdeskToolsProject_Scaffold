# Exchange Online w osobnym wątku (runspace)
<#
    Połączenie z Exchange Online i wszystkie polecenia Exchange wykonują się w osobnym wątku, a nie w wątku okna.
    W wątku okna działają funkcje-pośrednicy o nazwach poleceń Exchange używanych przez program (Get-EXOMailbox,
    Set-Mailbox…): przekazują parametry do wątku Exchange i czekają na wynik, odświeżając w tym czasie okno - istniejący
    kod programu działa bez zmian, a okno nie zamarza w czasie długich poleceń. Ostrzeżenia i błędy polecenia wracają
    do wywołującego (z jego -ErrorAction). «Przerwij» zatrzymuje bieżące polecenie.
    Wyłączenie (powrót do łączenia w wątku okna): Ustawienia > Microsoft 365 i Exchange > «Exchange w osobnym wątku».
#>

$script:Worker = @{ Runspace = $null; ModulePath = ''; Current = $null; Proxies = @() }
# Parametry wspólne obsługiwane przez pośrednika (w wątku okna), nieprzekazywane do polecenia w wątku Exchange
$script:LocalOnlyParameters = @('ErrorAction', 'WarningAction', 'InformationAction', 'ErrorVariable', 'WarningVariable', 'InformationVariable',
    'OutVariable', 'OutBuffer', 'PipelineVariable', 'Verbose', 'Debug', 'ProgressAction')
# Polecenia zawsze przekazywane do wątku Exchange (stan połączenia, nazwa organizacji, rozłączenie)
$script:AlwaysProxied = @('Get-ConnectionInformation', 'Disconnect-ExchangeOnline', 'Get-OrganizationConfig')
$script:NeverProxied = @('Connect-ExchangeOnline')
$script:ProgramCommandNames = $null

function Test-HTExchangeWorker {
    # Czy wątek Exchange działa
    $rs = $script:Worker.Runspace
    return [bool]($rs -and "$($rs.RunspaceStateInfo.State)" -eq 'Opened')
}

function Test-HTExchangeProxies { return (@($script:Worker.Proxies).Count -gt 0) }

function Start-HTExchangeWorker {
    <#
        Uruchamia wątek Exchange z modułem -ModulePath (manifest ExchangeOnlineManagement; w testach - dowolny moduł).
        Działający wątek z tym samym modułem jest używany ponownie.
    #>
    param([Parameter(Mandatory)][string]$ModulePath)
    if ((Test-HTExchangeWorker) -and $script:Worker.ModulePath -eq $ModulePath) { return }
    Stop-HTExchangeWorker
    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault2()
    if ($IsWindows) { $iss.ExecutionPolicy = [Microsoft.PowerShell.ExecutionPolicy]::Bypass }
    $rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($iss)
    # Logowanie (okno WAM w starszych modułach) wymaga wątku STA - tylko Windows
    if ($IsWindows) { $rs.ApartmentState = [System.Threading.ApartmentState]::STA }
    $rs.ThreadOptions = [System.Management.Automation.Runspaces.PSThreadOptions]::ReuseThread
    $rs.Open()
    $script:Worker.Runspace = $rs
    $script:Worker.ModulePath = ''
    try {
        $r = Invoke-HTExchangeWorker -Script 'param($Path) Import-Module -Name $Path -ErrorAction Stop -WarningAction SilentlyContinue -DisableNameChecking | Out-Null' -Arguments @{ Path = $ModulePath }
        if (@($r.Errors).Count) { throw $r.Errors[0].Exception }
    }
    catch {
        Stop-HTExchangeWorker
        throw (New-Object System.InvalidOperationException("Nie wczytano modułu w wątku Exchange: $($_.Exception.Message)"))
    }
    $script:Worker.ModulePath = $ModulePath
    if (Get-Command -Name Write-HTDebug -ErrorAction Ignore) { Write-HTDebug { "Wątek Exchange: uruchomiony, moduł $ModulePath" } }
}

function Stop-HTExchangeWorker {
    # Zamyka wątek Exchange (przy zamykaniu programu i przed ponownym uruchomieniem)
    $rs = $script:Worker.Runspace
    $script:Worker.Runspace = $null
    $script:Worker.ModulePath = ''
    if ($rs) { try { $rs.Dispose() } catch { Write-Verbose "Wątek Exchange: $_" } }
}

function Stop-HTExchangeWorkerCommand {
    # «Przerwij»: zatrzymuje bieżące polecenie w wątku Exchange. Zwraca $true, gdy coś było uruchomione.
    $ps = $script:Worker.Current
    if (-not $ps) { return $false }
    try { [void]$ps.BeginStop($null, $null) } catch { Write-Verbose $_ }
    return $true
}

function Invoke-HTExchangeWorker {
    <#
        Wykonuje polecenie (-Command z -Parameters) albo skrypt (-Script z -Arguments) w wątku Exchange i czeka na wynik,
        odświeżając okno programu (Update-HTUi). Zwraca @{ Output; Errors; Warnings }. Błąd kończący - wyjątek,
        przerwanie («Przerwij») - OperationCanceledException.
    #>
    param(
        [string]$Command = '',
        [System.Collections.IDictionary]$Parameters = @{},
        [string]$Script = '',
        [System.Collections.IDictionary]$Arguments = @{}
    )
    if (-not (Test-HTExchangeWorker)) { throw (New-Object System.InvalidOperationException('Wątek Exchange nie działa - połącz się ponownie z Exchange Online.')) }
    $rs = $script:Worker.Runspace
    $pump = Get-Command -Name Update-HTUi -ErrorAction Ignore
    # Wywołanie zagnieżdżone (zdarzenie okna w czasie oczekiwania na inne polecenie) - czeka, aż wątek będzie wolny
    while ("$($rs.RunspaceAvailability)" -ne 'Available') {
        if ($pump) { & $pump }
        Start-Sleep -Milliseconds 20
        if (-not (Test-HTExchangeWorker)) { throw (New-Object System.InvalidOperationException('Wątek Exchange został zamknięty.')) }
    }
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $rs
    if ($Script) {
        [void]$ps.AddScript($Script)
        if ($Arguments.Count) { [void]$ps.AddParameters($Arguments) }
    }
    else {
        [void]$ps.AddCommand($Command)
        foreach ($k in @($Parameters.Keys)) { [void]$ps.AddParameter([string]$k, $Parameters[$k]) }
    }
    $inputData = New-Object 'System.Management.Automation.PSDataCollection[psobject]'
    $inputData.Complete()
    $output = New-Object 'System.Management.Automation.PSDataCollection[psobject]'
    $previous = $script:Worker.Current
    $script:Worker.Current = $ps
    $started = [datetime]::Now
    $longWait = $false
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
        catch [System.Management.Automation.PipelineStoppedException] { throw (New-Object System.OperationCanceledException("Przerwano: $(if ($Command) { $Command } else { 'polecenie Exchange' })")) }
        catch {
            $inner = if ($_.Exception.InnerException) { $_.Exception.InnerException } else { $_.Exception }
            throw $inner
        }
        if ("$($ps.InvocationStateInfo.State)" -eq 'Stopped') { throw (New-Object System.OperationCanceledException("Przerwano: $(if ($Command) { $Command } else { 'polecenie Exchange' })")) }
        return [PSCustomObject]@{
            Output   = @($output | ForEach-Object { $_ })
            Errors   = @($ps.Streams.Error | ForEach-Object { $_ })
            Warnings = @($ps.Streams.Warning | ForEach-Object { $_ })
        }
    }
    finally {
        $script:Worker.Current = $previous
        $ps.Dispose()
        if ($longWait) {
            $hide = Get-Command -Name Hide-HTCancelIfIdle -ErrorAction Ignore
            if ($hide) { & $hide }
        }
    }
}

function Invoke-HTExchangeProxyCall {
    <#
        Wywołanie pośrednika: parametry do wątku Exchange, wynik do wywołującego. Ostrzeżenia i błędy polecenia są
        zgłaszane przez pośrednika (-Caller = $PSCmdlet), więc działa -ErrorAction / -WarningAction wywołującego.
    #>
    param([Parameter(Mandatory)][string]$Name, [System.Collections.IDictionary]$Bound = @{}, $Caller = $null)
    $params = [ordered]@{}
    foreach ($k in @($Bound.Keys)) { if ($script:LocalOnlyParameters -notcontains [string]$k) { $params[[string]$k] = $Bound[$k] } }
    $r = Invoke-HTExchangeWorker -Command $Name -Parameters $params
    foreach ($w in @($r.Warnings)) { if ($Caller) { $Caller.WriteWarning([string]$w.Message) } else { Write-Warning ([string]$w.Message) } }
    foreach ($e in @($r.Errors)) { if ($Caller) { $Caller.WriteError($e) } else { Write-Error -ErrorRecord $e } }
    foreach ($o in @($r.Output)) { $o }
}

function ConvertTo-HTExchangeProxyScript {
    <#
        Treść funkcji-pośrednika dla opisu polecenia @{ Name; Parameters = @(@{ Name; Switch; Aliases }) }:
        parametry bez typów (konwersję robi polecenie w wątku Exchange), przełączniki jako [switch].
    #>
    param([Parameter(Mandatory)]$Descriptor)
    $lines = foreach ($p in @($Descriptor.Parameters)) {
        $name = [string]$p.Name
        if ($name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') { continue }
        $aliases = @($p.Aliases | Where-Object { "$_" -match '^[A-Za-z0-9_\-]+$' })
        $alias = if ($aliases.Count) { "[Alias($(@($aliases | ForEach-Object { "'$_'" }) -join ', '))]" } else { '' }
        $type = if ($p.Switch) { '[switch]' } else { '' }
        "    [Parameter()]$alias$type`$$name"
    }
    $commandName = ([string]$Descriptor.Name) -replace "'", "''"
    return @"
[CmdletBinding(SupportsShouldProcess = `$true, ConfirmImpact = 'None')]
param(
$(@($lines) -join ",`n")
)
Invoke-HTExchangeProxyCall -Name '$commandName' -Bound `$PSBoundParameters -Caller `$PSCmdlet
"@
}

function Get-HTProgramCommandNames {
    # Nazwy poleceń używanych w plikach programu (moduły, interfejs) - do wyboru poleceń Exchange do pośredników
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
    }
    $result = @($names | Sort-Object)
    if (-not $PSBoundParameters.ContainsKey('Root')) { $script:ProgramCommandNames = $result }
    return $result
}

function Register-HTExchangeProxies {
    <#
        Tworzy w wątku okna funkcje-pośredników dla poleceń z -Names (i stałej listy), które w wątku Exchange pochodzą
        z modułów -Modules (ExchangeOnlineManagement i tymczasowy moduł poleceń tmpEXO_…). Zwraca liczbę pośredników.
    #>
    param([string[]]$Names = @(), [string[]]$Modules = @('ExchangeOnlineManagement', 'tmp*'))
    $all = @(@($Names) + $script:AlwaysProxied | Where-Object { $_ -and $script:NeverProxied -notcontains $_ } | Select-Object -Unique)
    $describe = @'
param($Names, $Modules)
$common = @([System.Management.Automation.Cmdlet]::CommonParameters) + @([System.Management.Automation.Cmdlet]::OptionalCommonParameters)
foreach ($c in @(Get-Command -Name $Names -CommandType Function, Cmdlet -ErrorAction SilentlyContinue)) {
    $module = [string]$c.ModuleName
    if (-not @($Modules | Where-Object { $module -like $_ }).Count) { continue }
    $params = foreach ($p in @($c.Parameters.Values)) {
        if ($common -contains $p.Name) { continue }
        [PSCustomObject]@{ Name = $p.Name; Switch = [bool]$p.SwitchParameter; Aliases = @($p.Aliases) }
    }
    [PSCustomObject]@{ Name = $c.Name; Module = $module; Parameters = @($params) }
}
'@
    $r = Invoke-HTExchangeWorker -Script $describe -Arguments @{ Names = [string[]]$all; Modules = [string[]]$Modules }
    $created = New-Object System.Collections.Generic.List[string]
    foreach ($d in @($r.Output)) {
        $text = ConvertTo-HTExchangeProxyScript -Descriptor $d
        Set-Item -Path "function:global:$($d.Name)" -Value ([scriptblock]::Create($text))
        $created.Add([string]$d.Name)
    }
    # Pośrednicy z poprzedniego połączenia, których już nie ma - usunięci
    foreach ($old in @($script:Worker.Proxies | Where-Object { $created -notcontains $_ })) { Remove-Item -Path "function:global:$old" -ErrorAction SilentlyContinue }
    $script:Worker.Proxies = $created.ToArray()
    if (Get-Command -Name Write-HTDebug -ErrorAction Ignore) { Write-HTDebug { "Wątek Exchange: pośrednicy poleceń: $($created.Count) ($($created -join ', '))" } }
    return $created.Count
}

function Remove-HTExchangeProxies {
    # Usuwa pośredników - np. przed połączeniem w wątku okna (polecenia Exchange wracają do zwykłego działania)
    foreach ($name in @($script:Worker.Proxies)) { Remove-Item -Path "function:global:$name" -ErrorAction SilentlyContinue }
    $script:Worker.Proxies = @()
}

function Connect-HTExchangeWorker {
    <#
        Łączy z Exchange Online w wątku Exchange (Connect-ExchangeOnline z -Parameters) i tworzy pośredników poleceń
        używanych przez program. Uruchamia wątek, jeśli nie działa.
    #>
    param([Parameter(Mandatory)][string]$ModulePath, [System.Collections.IDictionary]$Parameters = @{})
    Start-HTExchangeWorker -ModulePath $ModulePath
    $params = [ordered]@{}
    foreach ($k in @($Parameters.Keys)) { if ($script:LocalOnlyParameters -notcontains [string]$k) { $params[[string]$k] = $Parameters[$k] } }
    $r = Invoke-HTExchangeWorker -Command 'Connect-ExchangeOnline' -Parameters $params
    if (@($r.Errors).Count) { throw $r.Errors[0].Exception }
    foreach ($w in @($r.Warnings)) { Write-Warning ([string]$w.Message) }
    [void](Register-HTExchangeProxies -Names (Get-HTProgramCommandNames))
}
