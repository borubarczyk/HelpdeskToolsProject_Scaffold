# Instalacja/import modułów PowerShell oraz zarządzanie połączeniami z usługami Microsoft 365

# Mapa nazw połączeń na nazwy modułów w PowerShell Gallery
$script:ModuleNameMap = @{
    "Microsoft.Graph"              = "Microsoft.Graph.Authentication"
    "Microsoft.GraphGDAP"          = "Microsoft.Graph.Authentication"
    "ExchangeOnlineManagement"     = "ExchangeOnlineManagement"
    "ExchangeOnlineManagementGDAP" = "ExchangeOnlineManagement"
    "PnP.PowerShell"               = "PnP.PowerShell"
}

# Sprawdzanie czy moduł jest zainstalowany
function Test-ModulePresence {
    param ([string]$Name)
    return [bool](Get-Module -ListAvailable -Name $Name)
}

# Sprawdza, czy sesja działa z uprawnieniami administratora
function Test-HTIsAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

#region Moduły w OneDrive (pliki tylko w chmurze)
<#
    Gdy folder Dokumenty jest przeniesiony do OneDrive, moduły instalowane «dla bieżącego użytkownika» trafiają do
    ...\OneDrive\Documents\PowerShell\Modules. Przy plikach na żądanie (Files On-Demand) część z nich jest tylko
    w chmurze - bez działającego klienta OneDrive nie da się ich otworzyć («Dostawca plików w chmurze nie jest
    uruchomiony» przy imporcie modułu). Program pomija wtedy taki folder w tej sesji (PSModulePath procesu), a brakujące
    moduły proponuje zainstalować dla wszystkich użytkowników (C:\Program Files\PowerShell\Modules).
#>
# FILE_ATTRIBUTE_OFFLINE, FILE_ATTRIBUTE_RECALL_ON_OPEN, FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS
$script:CloudOnlyAttributeMask = 0x1000 -bor 0x40000 -bor 0x400000
$global:HTSkippedModulePaths = @()

function Test-HTCloudOnlyAttributes {
    # Czy atrybuty pliku / folderu oznaczają dane tylko w chmurze (odnośnik OneDrive bez lokalnej kopii)
    param ([Parameter(Mandatory)][object]$Attributes)
    return (([long]$Attributes) -band $script:CloudOnlyAttributeMask) -ne 0
}

function Test-HTCloudFileError {
    # Czy błąd (ErrorRecord, wyjątek albo tekst) to brak dostępu do pliku tylko w chmurze (OneDrive nie działa)
    param ([AllowNull()][object]$ErrorObject)
    $text = ''
    $e = if ($ErrorObject -is [System.Management.Automation.ErrorRecord]) { $ErrorObject.Exception } elseif ($ErrorObject -is [System.Exception]) { $ErrorObject } else { $null }
    if ($e) {
        while ($e) {
            # Kody Windows ERROR_CLOUD_FILE_* (362-409) - w HResult (0x8007016A…) albo w NativeErrorCode (Win32Exception)
            $native = if ($e -is [System.ComponentModel.Win32Exception]) { $e.NativeErrorCode } else { 0 }
            if ($native -ge 362 -and $native -le 409) { return $true }
            $text += " $($e.Message) 0x$('{0:X8}' -f $e.HResult)"
            $e = $e.InnerException
        }
    }
    else { $text = [string]$ErrorObject }
    return $text -match '(?i)cloud file provider|cloud operation|dostawca plików w chmurze|operacja w chmurze|0x8007016A|0x8007017C|0x80070185|0x8007018[0-9A-F]'
}

function Get-HTErrorFilePath {
    # Pierwsza ścieżka pliku (C:\…) w komunikacie błędu albo pusty tekst
    param ([AllowNull()][object]$ErrorObject)
    $text = if ($ErrorObject -is [System.Management.Automation.ErrorRecord]) { [string]$ErrorObject.Exception.Message } else { [string]$ErrorObject }
    if ($text -match "'?([A-Za-z]:\\[^'`"\r\n]+?)'?(?:\.\s*$|'|$)") { return $Matches[1].Trim() }
    return ''
}

function Test-HTOneDrivePath {
    # Czy ścieżka leży w folderze OneDrive (osobistym albo firmowym)
    param ([AllowEmptyString()][string]$Path)
    if (-not $Path) { return $false }
    $p = $Path.TrimEnd('\', '/')
    foreach ($root in @($env:OneDrive, $env:OneDriveCommercial, $env:OneDriveConsumer) | Where-Object { $_ }) {
        if ($p.StartsWith($root.TrimEnd('\'), [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $p -match '(?i)[\\/]OneDrive( - [^\\/]+)?([\\/]|$)'
}

function Get-HTModulePathOfFile {
    # Folder z PSModulePath, w którym leży plik (np. z komunikatu błędu); pusty tekst, gdy żaden
    param ([AllowEmptyString()][string]$File, [string[]]$Paths = @($env:PSModulePath -split [System.IO.Path]::PathSeparator))
    if (-not $File) { return '' }
    $f = $File.Replace('/', '\')
    foreach ($p in @($Paths | Where-Object { $_ } | Sort-Object Length -Descending)) {
        $root = $p.Replace('/', '\').TrimEnd('\') + '\'
        if ($f.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) { return $p }
    }
    return ''
}

function Get-HTUnavailableModulePaths {
    <#
        Foldery modułów z PSModulePath w OneDrive, w których są pliki tylko w chmurze, gdy klient OneDrive nie działa
        (pliki nie dadzą się otworzyć). Zwraca @{ Path; Example } - przykładowy niedostępny plik.
    #>
    param ([string[]]$Paths = @($env:PSModulePath -split [System.IO.Path]::PathSeparator))
    $candidates = @($Paths | Where-Object { $_ -and (Test-HTOneDrivePath $_) -and (Test-Path -LiteralPath $_) })
    if ($candidates.Count -eq 0) { return }
    if (Get-Process -Name OneDrive -ErrorAction SilentlyContinue) { return }
    foreach ($p in $candidates) {
        $errs = $null
        $hit = Get-ChildItem -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable errs | Where-Object { Test-HTCloudOnlyAttributes $_.Attributes } | Select-Object -First 1
        if ($hit) { [PSCustomObject]@{ Path = $p; Example = $hit.FullName }; continue }
        $cloudError = @($errs | Where-Object { Test-HTCloudFileError $_ })[0]
        if ($cloudError) { [PSCustomObject]@{ Path = $p; Example = (Get-HTErrorFilePath $cloudError) } }
    }
}

function Repair-HTModulePath {
    <#
        Pomija w tej sesji (PSModulePath procesu) foldery modułów niedostępne z OneDrive: wykryte automatycznie oraz
        -File (plik z komunikatu błędu) i -Path. Zwraca pominięte foldery. Pliki na dysku nie są zmieniane.
    #>
    param ([string]$File = '', [string[]]$Path = @(), [switch]$NoDetection)
    $paths = @($env:PSModulePath -split [System.IO.Path]::PathSeparator | Where-Object { $_ })
    $bad = New-Object System.Collections.Generic.List[string]
    foreach ($p in $Path) { if ($p) { $bad.Add($p) } }
    $fromFile = Get-HTModulePathOfFile -File $File -Paths $paths
    if ($fromFile) { $bad.Add($fromFile) }
    if (-not $NoDetection) { foreach ($u in @(Get-HTUnavailableModulePaths -Paths $paths)) { $bad.Add([string]$u.Path) } }
    $norm = { param($x) ([string]$x).TrimEnd('\', '/').ToLowerInvariant() }
    $badSet = @($bad | ForEach-Object { & $norm $_ } | Select-Object -Unique)
    if ($badSet.Count -eq 0) { return @() }
    $removed = @($paths | Where-Object { $badSet -contains (& $norm $_) })
    if ($removed.Count -eq 0) { return @() }
    $env:PSModulePath = (@($paths | Where-Object { $badSet -notcontains (& $norm $_) }) -join [System.IO.Path]::PathSeparator)
    $global:HTSkippedModulePaths = @(@($global:HTSkippedModulePaths) + $removed | Select-Object -Unique)
    Write-Log -Message "Pominięto moduły PowerShell z OneDrive ($($removed -join '; ')): pliki są tylko w chmurze, a OneDrive nie działa. Brakujące moduły program zaproponuje zainstalować dla wszystkich użytkowników (C:\Program Files\PowerShell\Modules)." -Type 'Warn'
    return $removed
}
#endregion

# Funkcja do instalacji modułu, jeśli nie jest zainstalowany
function Install-ModuleIfMissing {
    param (
        [Parameter(Mandatory)]
        [ValidateSet("Microsoft.Graph", "Microsoft.GraphGDAP", "ExchangeOnlineManagement", "PnP.PowerShell", "ExchangeOnlineManagementGDAP")]
        [string]$Name
    )

    $actualName = $script:ModuleNameMap[$Name]

    if (Test-ModulePresence -Name $actualName) {
        Write-Log "Moduł '$actualName' jest zainstalowany." "Info"
        return $true
    }

    Write-Log "Moduł '$actualName' nie jest zainstalowany." "Warn"
    $approve = Show-Dialog -Title "Instalacja modułu" -Message "Moduł '$actualName' nie jest zainstalowany. Czy chcesz go zainstalować z PowerShell Gallery?" -Buttons "YesNo" -Type "Question"
    if ($approve -ne "Yes") {
        Write-Log "Użytkownik anulował instalację modułu '$actualName'." "Warn"
        return $false
    }

    $scope = if (Test-HTIsAdministrator) { "AllUsers" } else { "CurrentUser" }
    try {
        Set-HTBusy -Busy $true -Text "Instalowanie modułu $actualName..."
        Install-Module -Name $actualName -Scope $scope -AcceptLicense -Force -AllowClobber -Repository PSGallery -ErrorAction Stop
        Write-Log "Moduł '$actualName' został pomyślnie zainstalowany ($scope)." "Info&Notification"
        return $true
    }
    catch {
        Write-Log "Błąd podczas instalacji modułu '$actualName': $($_.Exception.Message)" "Error&Notification"
        return $false
    }
    finally {
        Set-HTBusy -Busy $false -Text "Gotowe"
    }
}

# Funkcja do importowania modułu, jeśli jest zainstalowany
function Import-InstalledModule {
    param ([string]$Name)

    try {
        Import-Module -Name $Name -ErrorAction Stop -Global
        Write-Log "Moduł '$Name' zaimportowany." "Info"
        return $true
    }
    catch {
        Write-Log "Nie udało się zaimportować modułu '$Name': $($_.Exception.Message)" "Error"
        return $false
    }
}

#region Microsoft Graph - wspólne wywołania REST

# Buduje pełny adres zasobu Graph
function Resolve-HTGraphUri {
    param (
        [Parameter(Mandatory)][string]$Uri,
        [switch]$Beta
    )
    if ($Uri -match '^https://') { return $Uri }
    $version = if ($Beta) { "beta" } else { "v1.0" }
    return "https://graph.microsoft.com/$version/$($Uri.TrimStart('/'))"
}

# Wywołanie Microsoft Graph z obsługą stronicowania (-All) i treści JSON
function Invoke-HTGraphRequest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][string]$Uri,
        [ValidateSet("GET", "POST", "PATCH", "PUT", "DELETE")]
        [string]$Method = "GET",
        [AllowNull()][object]$Body,
        [switch]$All,
        [switch]$Beta,
        [switch]$ConsistencyLevelEventual,
        [hashtable]$Headers = @{}
    )

    $requestHeaders = @{}
    foreach ($key in $Headers.Keys) { $requestHeaders[$key] = $Headers[$key] }
    if ($ConsistencyLevelEventual) { $requestHeaders["ConsistencyLevel"] = "eventual" }

    $params = @{
        Uri         = Resolve-HTGraphUri -Uri $Uri -Beta:$Beta
        Method      = $Method
        OutputType  = "PSObject"
        ErrorAction = "Stop"
    }
    if ($requestHeaders.Count -gt 0) { $params.Headers = $requestHeaders }
    if ($null -ne $Body) {
        $params.Body = if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json -Depth 10 -Compress }
        $params.ContentType = "application/json"
    }

    $response = Invoke-MgGraphRequest @params

    if (-not $All) {
        if ($null -ne $response -and $response.PSObject.Properties.Name -contains "value" -and $response.PSObject.Properties.Name -notcontains "id") {
            return @($response.value)
        }
        return $response
    }

    $results = New-Object System.Collections.Generic.List[object]
    while ($null -ne $response) {
        foreach ($item in @($response.value)) {
            if ($null -ne $item) { $results.Add($item) }
        }
        $next = $response.'@odata.nextLink'
        if (-not $next) { break }
        $params.Uri = $next
        $params.Remove("Body")
        $params.Method = "GET"
        $response = Invoke-MgGraphRequest @params
    }
    return $results.ToArray()
}

# Wiele zapytań GET w jednym żądaniu $batch (po 20). -Requests: @{ Id; Url } (adres względny, np. "groups/<id>/owners").
# Zwraca słownik Id -> @{ Status; Body }; odpowiedzi 429 (ograniczenie) są ponawiane, -All dopisuje kolejne strony wyników.
function Invoke-HTGraphBatch {
    param (
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Requests,
        [switch]$Beta,
        [switch]$All,
        [int]$MaxRetries = 4
    )
    $results = @{}
    $pending = New-Object System.Collections.Generic.List[object]
    foreach ($r in $Requests) { if ($r) { $pending.Add($r) } }
    $attempt = 0
    while ($pending.Count -gt 0) {
        $retry = New-Object System.Collections.Generic.List[object]
        $delay = 0
        for ($i = 0; $i -lt $pending.Count; $i += 20) {
            $chunk = @($pending.GetRange($i, [Math]::Min(20, $pending.Count - $i)))
            $body = @{ requests = @($chunk | ForEach-Object { @{ id = [string]$_.Id; method = 'GET'; url = '/' + ([string]$_.Url).TrimStart('/') } }) }
            $response = Invoke-HTGraphRequest -Uri '$batch' -Method POST -Body $body -Beta:$Beta
            foreach ($item in @($response.responses)) {
                $status = [int]$item.status
                $request = @($chunk | Where-Object { [string]$_.Id -eq [string]$item.id })[0]
                if ($status -eq 429 -and $attempt -lt $MaxRetries) {
                    $retry.Add($request)
                    $after = 0
                    if ($item.headers -and [int]::TryParse("$($item.headers.'Retry-After')", [ref]$after)) { $delay = [Math]::Max($delay, $after) }
                    continue
                }
                $itemBody = $item.body
                if ($All -and $status -lt 300 -and $itemBody.'@odata.nextLink') {
                    $values = New-Object System.Collections.Generic.List[object]
                    foreach ($v in @($itemBody.value)) { if ($null -ne $v) { $values.Add($v) } }
                    foreach ($v in @(Invoke-HTGraphRequest -Uri $itemBody.'@odata.nextLink' -All)) { $values.Add($v) }
                    $itemBody = [PSCustomObject]@{ value = $values.ToArray() }
                }
                $results[[string]$item.id] = @{ Status = $status; Body = $itemBody }
            }
        }
        $pending = $retry
        if ($pending.Count -gt 0) {
            $attempt++
            Start-Sleep -Seconds ([Math]::Min(30, [Math]::Max(2, $delay)))
        }
    }
    return $results
}

# Raport użycia Microsoft 365 (CSV), np. "getTeamsTeamActivityDetail(period='D90')" - wiersze z nagłówków CSV.
# Wymaga Reports.Read.All; przy ukrywaniu nazw w raportach (centrum administracyjne) nazwy są zastąpione skrótami.
function Get-HTGraphReportCsv {
    param ([Parameter(Mandatory)][string]$Report, [switch]$Beta)
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("HelpdeskTools_report_" + [guid]::NewGuid().ToString('N') + '.csv')
    try {
        Invoke-MgGraphRequest -Uri (Resolve-HTGraphUri -Uri "reports/$Report" -Beta:$Beta) -Method GET -OutputFilePath $tmp -ErrorAction Stop
        if (-not (Test-Path -LiteralPath $tmp)) { return @() }
        return @(Import-Csv -LiteralPath $tmp -Encoding utf8)
    }
    finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
}

# Nazwa organizacji (tenant) z Microsoft Graph
function Get-HTGraphTenantName {
    try {
        $org = Invoke-HTGraphRequest -Uri "organization?`$select=displayName,id"
        $first = @($org)[0]
        if ($first.displayName) { return $first.displayName }
    }
    catch {
        Write-Log "Nie udało się pobrać nazwy organizacji: $($_.Exception.Message)" "Warn"
    }
    $context = Get-MgContext
    if ($context -and $context.TenantId) { return $context.TenantId }
    return "Microsoft Graph"
}

#endregion

# Logowanie interaktywne w przeglądarce z oknem «Trwa logowanie» (Anuluj, limit czasu) - zob. Invoke-HTInteractiveLogin.
# Bez interfejsu (np. testy) blok jest wykonywany bezpośrednio.
function Invoke-HTLogin {
    param ([Parameter(Mandatory)][scriptblock]$ScriptBlock, [string]$Title = "Microsoft 365")
    if (Get-Command -Name Invoke-HTInteractiveLogin -ErrorAction SilentlyContinue) {
        Invoke-HTInteractiveLogin -ScriptBlock $ScriptBlock -Title $Title
    }
    else {
        & $ScriptBlock
    }
}

# Microsoft Graph: logowanie w przeglądarce zamiast okna Windows (WAM), które potrafi otworzyć się za oknem programu lub poza ekranem
function Disable-HTGraphWam {
    $command = Get-Command -Name Set-MgGraphOption -ErrorAction SilentlyContinue
    if ($command -and $command.Parameters.ContainsKey("DisableLoginByWAM")) {
        try { Set-MgGraphOption -DisableLoginByWAM $true -ErrorAction Stop } catch { Write-Log "Nie udało się wyłączyć logowania WAM w Microsoft Graph: $($_.Exception.Message)" "Warn" }
    }
}

# Funkcja do połączenia z modułem
function Connect-Module {
    param (
        [ValidateSet("Microsoft.Graph", "Microsoft.GraphGDAP", "ExchangeOnlineManagement", "ExchangeOnlineManagementGDAP", "PnP.PowerShell")]
        [string]$Name,

        # Adres witryny dla PnP.PowerShell (domyślnie ostatnio używana lub z konfiguracji)
        [string]$SiteUrl,

        # PnP: bez pytania o adres witryny (np. przełączenie na witrynę wybraną z listy)
        [switch]$NoPrompt,

        # Graph: dodatkowe uprawnienia (np. rejestracja aplikacji PnP)
        [string[]]$ExtraScopes = @(),

        # Pominięcie weryfikacji zgodności modułu (użytkownik wybrał «Spróbuj mimo to»)
        [switch]$SkipCompatibilityCheck,

        # Graph: tenant (ID lub domena) bez pytania - zapamiętany profil tenantu, ponowne połączenie z dodatkowymi uprawnieniami
        [string]$TenantId = '',

        # Exchange GDAP: organizacja klienta i konto partnera bez formularza (zapamiętany profil tenantu)
        [string]$Organization = '',
        [string]$PartnerAccount = ''
    )

    if (-not (Install-ModuleIfMissing -Name $Name)) { return $false }
    $moduleName = $script:ModuleNameMap[$Name]

    Set-HTBusy -Busy $true -Text "Łączenie: $Name..."

    try {
        if ($SkipCompatibilityCheck) { Import-Module -Name $moduleName -ErrorAction Stop -Global }
        else { Import-HTRequiredModule -Name $moduleName | Out-Null }

        switch ($Name) {
            { $_ -in 'Microsoft.Graph', 'Microsoft.GraphGDAP' } {
                $tenantId = if ($TenantId) { $TenantId } else { $null }
                if ($Name -eq 'Microsoft.GraphGDAP' -and -not $tenantId) {
                    Set-HTBusy -Busy $false
                    $tenantId = Show-InputBox -Prompt "Podaj ID lub domenę tenantu klienta (GDAP):" -Title "Tenant GDAP" -ValidationType "Text" -Icon "E716"
                    Set-HTBusy -Busy $true -Text "Łączenie: $Name..."
                    if (-not $tenantId) {
                        Write-Log "Anulowano połączenie z GDAP - nie podano ID tenantu." "Warn"
                        return $false
                    }
                }
                Disable-HTGraphWam
                $scopes = @(@($Global:GraphScopes) + @($ExtraScopes) | Where-Object { $_ } | Select-Object -Unique)
                $connectParams = @{ Scopes = $scopes; NoWelcome = $true; ErrorAction = "Stop" }
                if ($tenantId) { $connectParams.TenantId = $tenantId }
                Invoke-HTLogin -Title $(if ($tenantId) { "Microsoft 365 (GDAP)" } else { "Microsoft 365" }) -ScriptBlock { Connect-MgGraph @connectParams }.GetNewClosure()
                $tenant = Get-HTGraphTenantName
                $Global:ConnectedToGraphAPI = $true
                Update-ConnectionButtonText -Service "Graph" -TenantName $tenant
                Write-Log "Połączono z Microsoft Graph ($tenant)$(if ($Name -eq 'Microsoft.GraphGDAP') { ' korzystając z GDAP' })." "Info&Notification"
                # Operacje w tle: przygotowanie wątku z modułem Graph (bez czekania)
                if (Get-Command -Name Start-HTBackgroundWarmup -ErrorAction SilentlyContinue) { Start-HTBackgroundWarmup }
            }
            'ExchangeOnlineManagement' {
                $params = Get-HTExchangeConnectParams
                Invoke-HTLogin -Title "Exchange Online" -ScriptBlock { Connect-ExchangeOnline @params }.GetNewClosure()
                $tenant = (Get-OrganizationConfig).DisplayName
                $Global:ConnectedToExchange = $true
                Update-ConnectionButtonText -Service "Exchange" -TenantName $tenant
                Write-Log "Połączono z Exchange Online ($tenant)" "Info&Notification"
            }
            'ExchangeOnlineManagementGDAP' {
                $gdap = $null
                if ($Organization -and $PartnerAccount) { $gdap = @{ Account = $PartnerAccount; Organization = $Organization } }
                else {
                    Set-HTBusy -Busy $false
                    $gdap = Show-HTFormDialog -Title "Exchange Online (GDAP)" -Description "Zarządzanie tenantem klienta w ramach GDAP." -OkText "Połącz" -Icon "E716" -Fields @(
                        @{ Name = "Account"; Label = "Konto administratora partnera"; Required = $true; Validation = "Email"; Placeholder = "admin@partner.com"; Default = $PartnerAccount }
                        @{ Name = "Organization"; Label = "Domena organizacji klienta"; Required = $true; Placeholder = "klient.onmicrosoft.com"; Default = $Organization }
                    )
                    Set-HTBusy -Busy $true -Text "Łączenie: $Name..."
                }
                if (-not $gdap) {
                    Write-Log "Anulowano połączenie z GDAP - nie podano wszystkich wymaganych informacji." "Warn"
                    return $false
                }
                $params = Get-HTExchangeConnectParams
                $params.UserPrincipalName = $gdap.Account
                $params.DelegatedOrganization = $gdap.Organization
                Invoke-HTLogin -Title "Exchange Online (GDAP)" -ScriptBlock { Connect-ExchangeOnline @params }.GetNewClosure()
                $tenant = (Get-OrganizationConfig).DisplayName
                $Global:ConnectedToExchange = $true
                Update-ConnectionButtonText -Service "Exchange" -TenantName $tenant
                Write-Log "Połączono z Exchange Online ($tenant) korzystając z GDAP." "Info&Notification"
            }
            'PnP.PowerShell' {
                if (-not $SiteUrl -and $Global:ConnectedToSharepointPnP) {
                    try { $SiteUrl = (Get-PnPConnection -ErrorAction Stop).Url } catch { $SiteUrl = $null }
                }
                if (-not $SiteUrl) { $SiteUrl = $Global:DefaultSharepointSite }

                $url = $SiteUrl
                $clientId = "$($Global:LastUsedClientID)"
                if (-not $NoPrompt -or -not $url -or -not $clientId) {
                    Set-HTBusy -Busy $false
                    $form = Show-HTSharePointConnectDialog -Url $url -ClientId $clientId
                    Set-HTBusy -Busy $true -Text "Łączenie: $Name..."
                    if (-not $form) {
                        Write-Log "Anulowano połączenie z PnP PowerShell." "Warn"
                        return $false
                    }
                    $url = $form.Url
                    $clientId = $form.ClientId
                }

                Invoke-HTLogin -Title "SharePoint" -ScriptBlock { Connect-PnPOnline -Url $url -ClientId $clientId -Interactive -ValidateConnection -ErrorAction Stop }.GetNewClosure()
                $connectedUrl = (Get-PnPConnection).Url
                $Global:ConnectedToSharepointPnP = $true
                $Global:ConnectedToSharepoint = $true
                Update-ConnectionButtonText -Service "SharePoint" -TenantName $connectedUrl

                if ($Global:LogClientIDForPnP -and $clientId -ne $Global:LastUsedClientID) {
                    try { Set-HTConfigValue -Name "LastUsedClientID" -Value $clientId } catch { Write-Log "Nie zapisano Client ID w konfiguracji: $_" "Warn" }
                }
                $Global:LastUsedClientID = $clientId
                Write-Log "Połączono z PnP PowerShell ($connectedUrl)" "Info&Notification"
            }
        }

        return $true
    }
    catch [System.OperationCanceledException] {
        # Anulowano logowanie lub upłynął limit czasu - bez okna błędu, połączenie można ponowić
        Write-Log "$($_.Exception.Message)" "Warn&Notification"
        Set-HTBusy -Busy $false -Text "Logowanie anulowane"
        Set-HTBusy -Busy $true
        return $false
    }
    catch {
        $problem = if ($_.Exception.Data["HTKind"]) { $_.Exception } else { ConvertFrom-HTAssemblyLoadError -ErrorRecord $_ -Module $moduleName }
        Set-HTBusy -Busy $false -Text "Błąd połączenia"
        if ($problem) {
            Write-Log "Problem z modułem $($moduleName): $($problem.Message -replace "`n+", ' | ')" "Error"
            $action = Show-HTModuleProblemDialog -Problem $problem -ConnectName $Name
            Set-HTBusy -Busy $true
            if ($action -eq "Retry") {
                Set-HTBusy -Busy $false
                return (Connect-Module -Name $Name -SiteUrl $SiteUrl -NoPrompt:$NoPrompt -ExtraScopes $ExtraScopes -TenantId $TenantId -Organization $Organization -PartnerAccount $PartnerAccount)
            }
            if ($action -eq "Force") {
                Set-HTBusy -Busy $false
                return (Connect-Module -Name $Name -SiteUrl $SiteUrl -NoPrompt:$NoPrompt -ExtraScopes $ExtraScopes -TenantId $TenantId -Organization $Organization -PartnerAccount $PartnerAccount -SkipCompatibilityCheck)
            }
            return $false
        }
        if (Test-HTCloudFileError $_) {
            # Moduł (albo moduł pomocniczy, np. PackageManagement) w OneDrive bez lokalnej kopii plików
            $file = Get-HTErrorFilePath $_
            Write-Log "Błąd połączenia z '$Name': moduł w OneDrive niedostępny - $($_.Exception.Message)" "Error"
            $removed = @(Repair-HTModulePath -File $file)
            if ($removed.Count -gt 0) {
                $answer = Show-Dialog -Title "Moduły PowerShell w OneDrive" -Type "Question" -Buttons "YesNo" -Message ("Moduły PowerShell w folderze OneDrive są niedostępne - pliki są tylko w chmurze, a OneDrive nie działa (albo nie jest zainstalowany):`n$($removed -join "`n")`n`nProgram pomija ten folder. Połączyć ponownie? Gdy modułu zabraknie, program zaproponuje instalację dla wszystkich użytkowników (C:\Program Files\PowerShell\Modules) - poza OneDrive.")
                if ($answer -eq "Yes") {
                    Set-HTBusy -Busy $false
                    return (Connect-Module -Name $Name -SiteUrl $SiteUrl -NoPrompt:$NoPrompt -ExtraScopes $ExtraScopes -TenantId $TenantId -Organization $Organization -PartnerAccount $PartnerAccount)
                }
                Set-HTBusy -Busy $true
                return $false
            }
            Show-HTError -Text "Nie udało się połączyć z '$Name': plik modułu jest tylko w chmurze OneDrive$(if ($file) { " ($file)" }), a OneDrive nie działa. Uruchom OneDrive albo oznacz folder Dokumenty\PowerShell «Zawsze przechowuj na tym urządzeniu»." -ErrorObject $_
            Set-HTBusy -Busy $true
            return $false
        }
        Write-Log "Błąd połączenia z '$Name': $($_.Exception.Message)" "Error&Notification"
        Show-HTError -Text "Nie udało się połączyć z '$Name'." -ErrorObject $_
        Set-HTBusy -Busy $true
        return $false
    }
    finally {
        Set-HTBusy -Busy $false -Text "Gotowe"
    }
}

<#
    Okno z opisem problemu modułu i rozwiązaniami. Zwraca: Retry (zainstalowano zgodną wersję - połącz ponownie),
    Force (spróbuj mimo to), Restart (program uruchamia się ponownie) albo $null.
#>
function Show-HTModuleProblemDialog {
    param ([Parameter(Mandatory)][System.Exception]$Problem, [Parameter(Mandatory)][string]$ConnectName)
    $module = [string]$Problem.Data["HTModule"]
    $kind = [string]$Problem.Data["HTKind"]
    $service = Get-HTModuleService -Name $module
    $choices = @()
    if ($kind -eq "Runtime") {
        $choices += @{ Key = "Install"; Text = "Zainstaluj wersję modułu zgodną z tym PowerShell"; Icon = "E896"; Description = "Program pobierze starsze wersje $module z PowerShell Gallery, sprawdzi je i zainstaluje najnowszą zgodną." }
        $choices += @{ Key = "Pwsh"; Text = "Zaktualizuj PowerShell"; Icon = "E777"; Description = "Najnowszy PowerShell (aka.ms/powershell) obsługuje najnowsze moduły. Zamknij program przed instalacją." }
    }
    else {
        $choices += @{ Key = "Restart"; Text = "Uruchom program ponownie i połącz najpierw z tą usługą"; Icon = "E72C"; Description = "W nowej sesji moduł $module załaduje swoje biblioteki jako pierwszy. Potem połącz pozostałe usługi." }
    }
    $choices += @{ Key = "Force"; Text = "Spróbuj mimo to"; Icon = "E768"; Description = "Połączenie z pominięciem weryfikacji (może zakończyć się tym samym błędem)." }
    $choice = Show-HTChoiceDialog -Title $(if ($kind -eq "Runtime") { "Moduł niezgodny z PowerShell" } else { "Konflikt bibliotek" }) -Prompt $Problem.Message -Icon "E7BA" -Choices $choices
    switch ($choice) {
        "Install" {
            Set-HTBusy -Busy $true -Text "Szukanie zgodnej wersji $module…"
            try {
                $version = Install-HTCompatibleModule -Name $module -OnProgress { param($text) Set-HTStatus -Text $text; Update-HTUi }
            }
            catch { $version = $null; Write-Log "Instalacja zgodnej wersji $($module): $($_.Exception.Message)" "Error" }
            finally { Set-HTBusy -Busy $false -Text "Gotowe" }
            if (-not $version) {
                Show-HTWarning -Title $module -Text "Nie znaleziono zgodnej wersji wśród ostatnich wydań $module. Zaktualizuj PowerShell: https://aka.ms/powershell"
                return $null
            }
            if (Get-Module -Name $module) {
                Show-HTMessage -Title $module -Tone ok -Text "Zainstalowano $module $version. W tej sesji jest już załadowana inna wersja - program uruchomi się ponownie."
                Restart-HTApplication -Connect $service
                return "Restart"
            }
            return "Retry"
        }
        "Pwsh" {
            Start-Process "https://aka.ms/powershell-release?tag=stable"
            Show-HTMessage -Title "Aktualizacja PowerShell" -Text "Zainstaluj najnowszy PowerShell (strona otworzyła się w przeglądarce) albo w wierszu poleceń:`n`nwinget upgrade --id Microsoft.PowerShell`n`nNastępnie uruchom Helpdesk Tools ponownie."
            return $null
        }
        "Restart" { Restart-HTApplication -Connect $service; return "Restart" }
        "Force" { return "Force" }
    }
    return $null
}

<#
    Funkcja wymaga dodatkowych uprawnień Microsoft Graph (np. Policy.Read.All dla dostępu warunkowego): gdy połączenie ich
    nie ma, pytanie o ponowne połączenie z nimi (ten sam tenant). Uprawnienia są dopisywane na stałe do GraphScopes, więc
    kolejne logowania już je obejmują. Połączenie aplikacji (certyfikat) ma uprawnienia aplikacji - bez sprawdzania.
    Zwraca $true, gdy można kontynuować.
#>
function Assert-HTGraphScopes {
    param ([Parameter(Mandatory)][string[]]$Scopes, [string]$Feature = 'Ta funkcja')
    if (-not $Global:ConnectedToGraphAPI) { return (Assert-HTConnection -Service 'Graph') }
    $context = Get-MgContext
    if (-not $context) { return (Assert-HTConnection -Service 'Graph') }
    if ("$($context.AuthType)" -eq 'AppOnly') { return $true }
    $granted = @($context.Scopes)
    $missing = @($Scopes | Where-Object { $granted -notcontains $_ })
    if ($missing.Count -eq 0) { return $true }
    $ok = Show-HTConfirm -Title 'Dodatkowe uprawnienia Microsoft Graph' -ConfirmText 'Połącz ponownie' -Message "$Feature wymaga uprawnień: $($missing -join ', ').`n`nPołączyć ponownie z Microsoft 365 z tymi uprawnieniami? Otworzy się logowanie w przeglądarce; część uprawnień wymaga zgody administratora. Uprawnienia zostaną zapamiętane w ustawieniach."
    if (-not $ok) { return $false }
    $all = @(@($Global:GraphScopes) + $missing | Where-Object { $_ } | Select-Object -Unique)
    try {
        Set-HTConfigValue -Name "GraphScopes" -Value $all
        $Global:GraphScopes = $all
    }
    catch { Write-Log "Nie zapisano uprawnień Graph w konfiguracji: $($_.Exception.Message)" "Warn" }
    if (-not (Connect-Module -Name "Microsoft.Graph" -TenantId "$($context.TenantId)" -ExtraScopes $missing)) { return $false }
    if (-not (Test-HTGraphScopes -Scopes $Scopes)) {
        Show-HTWarning -Title 'Uprawnienia Microsoft Graph' -Text "Połączenie nadal nie ma uprawnień: $(@($Scopes | Where-Object { @((Get-MgContext).Scopes) -notcontains $_ }) -join ', '). Sprawdź role konta i zgodę administratora (Entra ID > Aplikacje dla przedsiębiorstw > Microsoft Graph Command Line Tools)."
        return $false
    }
    return $true
}

# Okno połączenia z SharePoint: adres witryny (z listą witryn) i Client ID (z możliwością utworzenia aplikacji)
function Show-HTSharePointConnectDialog {
    param ([string]$Url, [string]$ClientId)
    return Show-HTFormDialog -Title "Połączenie z SharePoint" -Description "PnP PowerShell wymaga własnej rejestracji aplikacji w Entra ID (Client ID). Nie masz jej? Kliknij «Utwórz Client ID»." -OkText "Połącz" -Icon "E8F1" -Width 620 -Fields @(
        @{ Name = "Url"; Label = "Adres witryny"; Required = $true; Validation = "Url"; Default = $Url; Placeholder = "https://firma.sharepoint.com/sites/Dzial" }
        @{ Name = "ClientId"; Label = "Client ID aplikacji"; Required = $true; Validation = "Guid"; Default = $ClientId }
    ) -ExtraButtons @(
        @{ Text = "Wybierz witrynę"; Icon = "E721"; OnClick = {
                param($w)
                $site = Select-HTSharePointSite
                if ($site) { $w.Tag.Controls["Url"].Control.Text = $site.Adres }
            }
        }
        @{ Text = "Utwórz Client ID"; Icon = "E710"; OnClick = {
                param($w)
                $current = $w.Tag.Controls["Url"].Control.Text.Trim()
                $result = Show-HTPnPAppRegistrationDialog -SiteUrl $current
                if ($result -and $result.ClientId) { $w.Tag.Controls["ClientId"].Control.Text = $result.ClientId }
            }
        }
    )
}

# Parametry Connect-ExchangeOnline: logowanie w przeglądarce zamiast okna Windows (WAM) - -DisableWAM, EXO 3.7.2+
function Get-HTExchangeConnectParams {
    $params = @{ ShowBanner = $false; ErrorAction = "Stop" }
    $command = Get-Command -Name Connect-ExchangeOnline -ErrorAction SilentlyContinue
    if ($command -and $command.Parameters.ContainsKey("ShowProgress")) { $params.ShowProgress = $false }
    if ($command -and $command.Parameters.ContainsKey("DisableWAM")) { $params.DisableWAM = $true }
    elseif ($command) { Write-Log "Zaktualizuj moduł ExchangeOnlineManagement do 3.7.2 lub nowszego (Update-Module ExchangeOnlineManagement) - starsze wersje logują się w osobnym oknie zamiast w przeglądarce." "Warn" }
    return $params
}

# Funkcja do sprawdzania i zarządzania połączeniami
function Set-Connections {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Check", "Disconnect" , "DisconnectAll")]
        [string]$Action,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Exchange", "Graph", "SharePoint")]
        [string]$Service
    )

    switch ($Action) {
        "Check" {
            Write-Log "Sprawdzanie połączeń..." -Type "Info"

            # Exchange Online
            $exo = $null
            if (Get-Module -Name ExchangeOnlineManagement) {
                $exo = Get-ConnectionInformation -ErrorAction SilentlyContinue | Where-Object { $_.State -eq "Connected" } | Select-Object -First 1
            }
            $Global:ConnectedToExchange = [bool]$exo
            if ($exo) { Update-ConnectionButtonText -Service "Exchange" -TenantName $exo.Organization }
            else { Update-ConnectionButtonText -Service "Exchange" }

            # Microsoft Graph
            $context = $null
            if (Get-Module -Name Microsoft.Graph.Authentication) { $context = Get-MgContext }
            $Global:ConnectedToGraphAPI = [bool]$context
            if ($context) { Update-ConnectionButtonText -Service "Graph" -TenantName (Get-HTGraphTenantName) }
            else { Update-ConnectionButtonText -Service "Graph" }

            # SharePoint PnP
            $pnp = $null
            if (Get-Module -Name PnP.PowerShell) {
                try { $pnp = Get-PnPConnection -ErrorAction Stop } catch { $pnp = $null }
            }
            $Global:ConnectedToSharepointPnP = [bool]$pnp
            $Global:ConnectedToSharepoint = [bool]$pnp
            if ($pnp) { Update-ConnectionButtonText -Service "SharePoint" -TenantName $pnp.Url }
            else { Update-ConnectionButtonText -Service "SharePoint" }
        }
        "Disconnect" {
            if (-not $Service) {
                Write-Log "Brak określonej usługi do rozłączenia. Użyj 'DisconnectAll' lub podaj konkretną usługę." -Type "Error"
                return
            }
            switch ($Service) {
                "Exchange" {
                    try {
                        if (Get-Module -Name ExchangeOnlineManagement) {
                            Disconnect-ExchangeOnline -Confirm:$false -ErrorAction Stop
                        }
                        Write-Log "Rozłączono Exchange Online" -Type "Info"
                    }
                    catch {
                        Write-Log "Błąd rozłączania Exchange Online: $($_.Exception.Message)" -Type "Warn"
                    }
                    $Global:ConnectedToExchange = $false
                    Update-ConnectionButtonText -Service "Exchange"
                }
                "Graph" {
                    try {
                        if (Get-Module -Name Microsoft.Graph.Authentication) {
                            Disconnect-MgGraph -ErrorAction Stop | Out-Null
                        }
                        Write-Log "Rozłączono Microsoft Graph" -Type "Info"
                    }
                    catch {
                        Write-Log "Błąd rozłączania Microsoft Graph: $($_.Exception.Message)" -Type "Warn"
                    }
                    $Global:ConnectedToGraphAPI = $false
                    Update-ConnectionButtonText -Service "Graph"
                }
                "SharePoint" {
                    try {
                        if (Get-Module -Name PnP.PowerShell) {
                            Disconnect-PnPOnline -ErrorAction Stop
                        }
                        Write-Log "Rozłączono SharePoint (PnP)" -Type "Info"
                    }
                    catch {
                        Write-Log "Błąd rozłączania SharePoint: $($_.Exception.Message)" -Type "Warn"
                    }
                    $Global:ConnectedToSharepoint = $false
                    $Global:ConnectedToSharepointPnP = $false
                    Update-ConnectionButtonText -Service "SharePoint"
                }
            }
        }
        "DisconnectAll" {
            Write-Log "Rozłączanie wszystkich usług..." -Type "Info"
            if ($Global:ConnectedToExchange) { Set-Connections -Action "Disconnect" -Service "Exchange" }
            if ($Global:ConnectedToGraphAPI) { Set-Connections -Action "Disconnect" -Service "Graph" }
            if ($Global:ConnectedToSharepointPnP) { Set-Connections -Action "Disconnect" -Service "SharePoint" }
        }
    }
}

#region Weryfikacja pakietów: zgodność modułów z PowerShell i konflikty bibliotek
<#
    Typowe błędy połączeń wynikają z bibliotek .NET, a nie z samych usług:
    - moduł zbudowany pod nowszy .NET niż ten, na którym działa PowerShell (np. «Could not load file or assembly
      'System.Text.Json, Version=10.0.0.0'» w PowerShell 7.4/7.5) - pomaga starsza wersja modułu albo nowszy PowerShell,
    - dwa moduły z różnymi wersjami wspólnej biblioteki (np. Microsoft.Identity.Client w Graph i Exchange) - w jednym
      procesie może być załadowana tylko jedna wersja; pomaga ponowne uruchomienie i połączenie najpierw z modułem,
      który wymaga nowszej wersji.
    Analiza czyta metadane plików DLL (System.Reflection.Metadata) bez ładowania ich do procesu.
#>
$script:CompatCache = @{}
# Biblioteki współdzielone przez moduły Microsoft 365 - najczęstsze źródło konfliktów w jednej sesji
$script:SharedAssemblyPattern = '^(Microsoft\.Identity\.|Microsoft\.IdentityModel\.|System\.IdentityModel\.Tokens\.Jwt$|Azure\.Core$|Azure\.Identity$|Newtonsoft\.Json$|System\.Text\.Json$|System\.Text\.Encodings\.Web$|Microsoft\.Bcl\.AsyncInterfaces$|System\.Memory\.Data$|System\.ClientModel$)'
# Foldery z bibliotekami dla Windows PowerShell 5.1 (.NET Framework) - nie są ładowane w PowerShell 7
$script:FrameworkFolderPattern = '[\\/](Framework|netFramework|Desktop|net4\d*|netfx|net45|net461|net462|net472|net48)[\\/]'

# Nazwa, wersja i odwołania pliku DLL .NET (bez ładowania do procesu); $null dla bibliotek natywnych
function Get-HTAssemblyInfo {
    param ([Parameter(Mandatory)][string]$Path)
    $stream = $null
    $pe = $null
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        $pe = [System.Reflection.PortableExecutable.PEReader]::new($stream)
        if (-not $pe.HasMetadata) { return $null }
        $md = [System.Reflection.Metadata.PEReaderExtensions]::GetMetadataReader($pe)
        if (-not $md.IsAssembly) { return $null }
        $definition = $md.GetAssemblyDefinition()
        $references = foreach ($handle in $md.AssemblyReferences) {
            $reference = $md.GetAssemblyReference($handle)
            [PSCustomObject]@{ Name = $md.GetString($reference.Name); Version = $reference.Version }
        }
        return [PSCustomObject]@{
            Name       = $md.GetString($definition.Name)
            Version    = $definition.Version
            Path       = $Path
            References = @($references)
        }
    }
    catch { return $null }
    finally {
        if ($pe) { $pe.Dispose() }
        if ($stream) { $stream.Dispose() }
    }
}

# Wersja biblioteki dostarczanej z PowerShell ($PSHOME) albo $null
function Get-HTRuntimeAssemblyVersion {
    param ([Parameter(Mandatory)][string]$Name, [string]$RuntimeDirectory = $PSHOME)
    $file = Join-Path $RuntimeDirectory "$Name.dll"
    if (-not (Test-Path -LiteralPath $file)) { return $null }
    try { return [System.Reflection.AssemblyName]::GetAssemblyName($file).Version } catch { return $null }
}

<#
    Zgodność modułu z bieżącym PowerShell. Wynik:
      Compatible     - $false, gdy moduł wymaga nowszych bibliotek .NET niż dostarczone z PowerShell
      RuntimeIssues  - biblioteki wymagające nowszego PowerShell (.NET)
      LoadedIssues   - konflikty z bibliotekami już załadowanymi przez inny moduł (pomaga ponowne uruchomienie)
#>
function Test-HTModuleCompatibility {
    param (
        [Parameter(Mandatory)][string]$ModuleBase,
        [string]$RuntimeDirectory = $PSHOME,
        [object[]]$LoadedAssemblies,
        [switch]$SkipLoadedCheck
    )
    $key = "$ModuleBase|$RuntimeDirectory"
    $infos = $script:CompatCache[$key]
    if (-not $infos) {
        $runtimeMajor = [System.Environment]::Version.Major
        $infos = @(Get-ChildItem -LiteralPath $ModuleBase -Filter *.dll -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch $script:FrameworkFolderPattern -and $_.FullName -notmatch '[\\/]runtimes[\\/]' } |
                # Moduły z bibliotekami dla kilku wersji .NET (np. net8.0 i net10.0): wersje nowsze niż bieżący .NET nie są ładowane
                Where-Object { -not ($_.FullName -match '[\\/]net(\d+)\.\d+[\\/]' -and [int]$matches[1] -gt $runtimeMajor) } |
                ForEach-Object { Get-HTAssemblyInfo -Path $_.FullName } | Where-Object { $_ })
        $script:CompatCache[$key] = $infos
    }
    $shipped = @{}
    foreach ($i in $infos) { $shipped[$i.Name] = $i.Version }

    if (-not $SkipLoadedCheck -and -not $LoadedAssemblies) {
        $LoadedAssemblies = @([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { -not $_.IsDynamic } | ForEach-Object {
                $n = $_.GetName()
                [PSCustomObject]@{ Name = $n.Name; Version = $n.Version; Location = $_.Location }
            })
    }
    $loaded = @{}
    foreach ($a in @($LoadedAssemblies)) { if ($a -and $a.Name) { $loaded[$a.Name] = $a } }

    $runtimeIssues = @{}
    $loadedIssues = @{}
    $baseFull = [System.IO.Path]::GetFullPath($ModuleBase)
    $runtimeFull = [System.IO.Path]::GetFullPath($RuntimeDirectory)
    foreach ($info in $infos) {
        foreach ($ref in $info.References) {
            $name = $ref.Name
            if (-not $shipped.ContainsKey($name)) {
                $available = Get-HTRuntimeAssemblyVersion -Name $name -RuntimeDirectory $RuntimeDirectory
                if ($available -and $ref.Version -gt $available) {
                    if (-not $runtimeIssues.ContainsKey($name) -or $runtimeIssues[$name].Required -lt $ref.Version) {
                        $runtimeIssues[$name] = [PSCustomObject]@{ Assembly = $name; Required = $ref.Version; Available = $available; Source = 'PowerShell' }
                    }
                    continue
                }
            }
            if ($SkipLoadedCheck -or -not $loaded.ContainsKey($name)) { continue }
            $current = $loaded[$name]
            if (-not ($current.Version -lt $ref.Version)) { continue }
            $location = [string]$current.Location
            if ($location -and $location.StartsWith($baseFull, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
            $fromRuntime = $location -and $location.StartsWith($runtimeFull, [System.StringComparison]::OrdinalIgnoreCase)
            if ($fromRuntime -and $shipped.ContainsKey($name)) {
                # Moduł dostarcza nowszą bibliotekę, ale PowerShell ma już załadowaną swoją - wymaga nowszego PowerShell
                $runtimeIssues[$name] = [PSCustomObject]@{ Assembly = $name; Required = $ref.Version; Available = $current.Version; Source = 'PowerShell' }
            }
            elseif (-not $fromRuntime -and $name -match $script:SharedAssemblyPattern) {
                $loadedIssues[$name] = [PSCustomObject]@{ Assembly = $name; Required = $ref.Version; Available = $current.Version; Source = $location }
            }
        }
    }
    return [PSCustomObject]@{
        ModuleBase    = $ModuleBase
        Compatible    = ($runtimeIssues.Count -eq 0)
        RuntimeIssues = @($runtimeIssues.Values)
        LoadedIssues  = @($loadedIssues.Values)
    }
}

<#
    Wybór wersji modułu do zaimportowania: już załadowana albo najnowsza zainstalowana zgodna z PowerShell.
    Status: Loaded | Compatible | Incompatible | Missing
#>
function Resolve-HTModuleVersion {
    param ([Parameter(Mandatory)][string]$Name)
    $current = Get-Module -Name $Name | Sort-Object Version -Descending | Select-Object -First 1
    if ($current) { return [PSCustomObject]@{ Name = $Name; Status = 'Loaded'; Module = $current; Skipped = @(); Check = $null } }
    $installed = @(Get-Module -ListAvailable -Name $Name | Sort-Object Version -Descending)
    if ($installed.Count -eq 0) { return [PSCustomObject]@{ Name = $Name; Status = 'Missing'; Module = $null; Skipped = @(); Check = $null } }
    $skipped = New-Object System.Collections.Generic.List[object]
    $firstCheck = $null
    foreach ($m in $installed) {
        $check = Test-HTModuleCompatibility -ModuleBase $m.ModuleBase
        if (-not $firstCheck) { $firstCheck = $check }
        if ($check.Compatible) {
            return [PSCustomObject]@{ Name = $Name; Status = 'Compatible'; Module = $m; Skipped = $skipped.ToArray(); Check = $check }
        }
        $skipped.Add([PSCustomObject]@{ Version = $m.Version; Issues = $check.RuntimeIssues })
    }
    return [PSCustomObject]@{ Name = $Name; Status = 'Incompatible'; Module = $installed[0]; Skipped = $skipped.ToArray(); Check = $firstCheck }
}

# Usługa (przycisk połączenia), której dotyczy moduł
function Get-HTModuleService {
    param ([string]$Name)
    switch -Wildcard ($Name) {
        "Microsoft.Graph*" { return "Graph" }
        "ExchangeOnline*" { return "Exchange" }
        "PnP*" { return "SharePoint" }
        default { return "" }
    }
}

# Wyjątek z opisem problemu modułu (rodzaj: Runtime | Conflict) - obsługiwany w Connect-Module
function New-HTModuleProblem {
    param (
        [Parameter(Mandatory)][ValidateSet("Runtime", "Conflict")][string]$Kind,
        [Parameter(Mandatory)][string]$Module,
        [object[]]$Issues = @(),
        [string]$Message
    )
    $lines = @($Issues | ForEach-Object { "$($_.Assembly): wymagana $($_.Required), dostępna $($_.Available)$(if ($_.Source -and $_.Source -ne 'PowerShell') { " ($(Split-Path $_.Source -Parent))" })" })
    if (-not $Message) {
        $Message = if ($Kind -eq "Runtime") {
            "Zainstalowana wersja modułu $Module wymaga nowszej wersji PowerShell (.NET) niż $($PSVersionTable.PSVersion)."
        }
        else {
            "W tej sesji jest już załadowana starsza wersja biblioteki wymaganej przez $Module (prawdopodobnie przez inny moduł Microsoft 365)."
        }
    }
    $ex = [System.InvalidOperationException]::new($Message + $(if ($lines) { "`n`n" + ($lines -join "`n") } else { "" }))
    $ex.Data["HTKind"] = $Kind
    $ex.Data["HTModule"] = $Module
    $ex.Data["HTIssues"] = $Issues
    return $ex
}

# Analiza błędu ładowania biblioteki («Could not load file or assembly 'X, Version=V'») - zwraca wyjątek z opisem albo $null
function ConvertFrom-HTAssemblyLoadError {
    param ([Parameter(Mandatory)][object]$ErrorRecord, [Parameter(Mandatory)][string]$Module)
    $exception = if ($ErrorRecord -is [System.Management.Automation.ErrorRecord]) { $ErrorRecord.Exception } else { $ErrorRecord }
    $text = ""
    $e = $exception
    while ($e) { $text += " " + $e.Message; $e = $e.InnerException }
    if ($text -notmatch "(?:Could not load file or assembly|Nie można załadować pliku lub zestawu|Nie można odnaleźć|could not be loaded)\s*'([^,']+),\s*Version=([\d\.]+)") { return $null }
    $name = $matches[1]
    $required = [version]$matches[2]
    $runtime = Get-HTRuntimeAssemblyVersion -Name $name
    $loadedAssembly = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { -not $_.IsDynamic -and $_.GetName().Name -eq $name } | Select-Object -First 1
    if ($runtime -and $required -gt $runtime) {
        return New-HTModuleProblem -Kind Runtime -Module $Module -Issues @([PSCustomObject]@{ Assembly = $name; Required = $required; Available = $runtime; Source = "PowerShell" })
    }
    if ($loadedAssembly -and $loadedAssembly.GetName().Version -lt $required) {
        return New-HTModuleProblem -Kind Conflict -Module $Module -Issues @([PSCustomObject]@{ Assembly = $name; Required = $required; Available = $loadedAssembly.GetName().Version; Source = $loadedAssembly.Location })
    }
    return $null
}

# Import modułu w wersji zgodnej z PowerShell (z pominięciem wersji wymagających nowszego .NET)
function Import-HTRequiredModule {
    param ([Parameter(Mandatory)][string]$Name)
    $resolved = Resolve-HTModuleVersion -Name $Name
    switch ($resolved.Status) {
        "Loaded" { return $resolved.Module }
        "Missing" { throw "Moduł $Name nie jest zainstalowany." }
        "Incompatible" { throw (New-HTModuleProblem -Kind Runtime -Module $Name -Issues $resolved.Check.RuntimeIssues) }
    }
    if ($resolved.Check.LoadedIssues.Count -gt 0) {
        throw (New-HTModuleProblem -Kind Conflict -Module $Name -Issues $resolved.Check.LoadedIssues)
    }
    if ($resolved.Skipped.Count -gt 0) {
        Write-Log "Pominięto wersje modułu $Name wymagające nowszego PowerShell: $(@($resolved.Skipped | ForEach-Object { $_.Version }) -join ', '). Używana wersja: $($resolved.Module.Version)." "Warn"
    }
    Import-Module -Name $resolved.Module.Path -Global -ErrorAction Stop -WarningAction SilentlyContinue
    Write-Log "Zaimportowano moduł $Name $($resolved.Module.Version)." "Info"
    return $resolved.Module
}

<#
    Instalacja najnowszej wersji modułu zgodnej z bieżącym PowerShell: kolejne wersje z PowerShell Gallery są pobierane
    do folderu tymczasowego (Save-Module) i sprawdzane, pierwsza zgodna jest instalowana. Zwraca zainstalowaną wersję albo $null.
    OnProgress: { param($Text) }
#>
function Install-HTCompatibleModule {
    param (
        [Parameter(Mandatory)][string]$Name,
        [int]$MaxCandidates = 10,
        [scriptblock]$OnProgress
    )
    $newestInstalled = (Get-Module -ListAvailable -Name $Name | Sort-Object Version -Descending | Select-Object -First 1).Version
    $candidates = @(Find-Module -Name $Name -AllVersions -Repository PSGallery -ErrorAction Stop | ForEach-Object {
            $v = $null
            if ([version]::TryParse([string]$_.Version, [ref]$v)) { [PSCustomObject]@{ Version = $v } }
        } | Sort-Object Version -Descending)
    if ($newestInstalled) { $candidates = @($candidates | Where-Object { $_.Version -le $newestInstalled }) }
    $scope = if (Test-HTIsAdministrator) { "AllUsers" } else { "CurrentUser" }
    $tested = 0
    foreach ($candidate in $candidates) {
        if ($tested -ge $MaxCandidates) { break }
        $tested++
        $version = $candidate.Version
        $installedCopy = Get-Module -ListAvailable -Name $Name | Where-Object { $_.Version -eq $version } | Select-Object -First 1
        if ($installedCopy) {
            if ((Test-HTModuleCompatibility -ModuleBase $installedCopy.ModuleBase -SkipLoadedCheck).Compatible) { return $version }
            continue
        }
        if ($OnProgress) { & $OnProgress "Sprawdzanie $Name $version ($tested/$MaxCandidates)…" }
        $temp = Join-Path ([System.IO.Path]::GetTempPath()) ("HT_{0}_{1}" -f $Name, [guid]::NewGuid().ToString("N").Substring(0, 8))
        try {
            Save-Module -Name $Name -RequiredVersion $version -Path $temp -Repository PSGallery -Force -AcceptLicense -ErrorAction Stop
            $base = Get-ChildItem -LiteralPath (Join-Path $temp $Name) -Directory | Select-Object -First 1
            if (-not $base) { continue }
            if ((Test-HTModuleCompatibility -ModuleBase $base.FullName -SkipLoadedCheck).Compatible) {
                if ($OnProgress) { & $OnProgress "Instalowanie $Name $version…" }
                Install-Module -Name $Name -RequiredVersion $version -Scope $scope -Repository PSGallery -Force -AllowClobber -AcceptLicense -ErrorAction Stop
                Write-Log "Zainstalowano zgodną wersję modułu $Name $version ($scope)." "Info&Notification"
                return $version
            }
        }
        finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
    }
    return $null
}

# Raport środowiska i modułów (Pulpit - «Moduły i środowisko»)
function Get-HTEnvironmentReport {
    $rows = New-Object System.Collections.Generic.List[object]
    $apartment = [System.Threading.Thread]::CurrentThread.GetApartmentState()
    $rows.Add([PSCustomObject]@{ Składnik = "PowerShell"; Wersja = "$($PSVersionTable.PSVersion)"; Stan = $(if ($PSVersionTable.PSVersion -ge [version]"7.4") { "OK" } else { "Uwaga" }); Szczegóły = "Zalecany PowerShell 7.4 lub nowszy. Folder: $PSHOME"; __flag = $(if ($PSVersionTable.PSVersion -lt [version]"7.4") { "warn" } else { "" }) })
    $rows.Add([PSCustomObject]@{ Składnik = ".NET"; Wersja = "$([System.Environment]::Version)"; Stan = "OK"; Szczegóły = [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription; __flag = "" })
    $rows.Add([PSCustomObject]@{ Składnik = "System"; Wersja = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription; Stan = "OK"; Szczegóły = "Wątek: $apartment, administrator: $(if (Test-HTIsAdministrator) { 'tak' } else { 'nie' })"; __flag = "" })
    foreach ($p in @($global:HTSkippedModulePaths | Where-Object { $_ })) {
        $rows.Add([PSCustomObject]@{ Składnik = "Folder modułów (OneDrive)"; Wersja = ""; Stan = "Pominięty"; Szczegóły = "$p - pliki tylko w chmurze, a OneDrive nie działa. Brakujące moduły są instalowane w C:\Program Files\PowerShell\Modules. Na stałe: usuń ten folder albo uruchom OneDrive i oznacz go «Zawsze przechowuj na tym urządzeniu»."; __flag = "warn" })
    }
    foreach ($name in "Microsoft.Graph.Authentication", "ExchangeOnlineManagement", "PnP.PowerShell") {
        $installed = @(Get-Module -ListAvailable -Name $name | Sort-Object Version -Descending)
        $loaded = Get-Module -Name $name | Select-Object -First 1
        if ($installed.Count -eq 0) {
            $rows.Add([PSCustomObject]@{ Składnik = $name; Wersja = ""; Stan = "Brak"; Szczegóły = "Zostanie zainstalowany przy pierwszym połączeniu."; Moduł = $name; __flag = "muted" })
            continue
        }
        $compatible = $null
        $issues = @()
        foreach ($m in $installed) {
            $check = Test-HTModuleCompatibility -ModuleBase $m.ModuleBase
            if ($check.Compatible) { $compatible = $m; if (-not $loaded) { $issues = $check.LoadedIssues }; break }
            if (-not $issues) { $issues = $check.RuntimeIssues }
        }
        $state = if ($loaded) { "Załadowany" } elseif (-not $compatible) { "Wymaga nowszego PowerShell" } elseif ($compatible.Version -ne $installed[0].Version) { "Używana starsza wersja" } elseif ($issues) { "Konflikt bibliotek" } else { "OK" }
        $detail = if (-not $compatible) { "Brak zainstalowanej zgodnej wersji. " + (@($issues | ForEach-Object { "$($_.Assembly) $($_.Required) (PowerShell ma $($_.Available))" }) -join "; ") }
        elseif ($compatible.Version -ne $installed[0].Version) { "Najnowsza zainstalowana $($installed[0].Version) wymaga nowszego PowerShell - używana będzie $($compatible.Version)." }
        elseif ($issues -and -not $loaded) { "Inny załadowany moduł ma starsze biblioteki: " + (@($issues | ForEach-Object { "$($_.Assembly) $($_.Available) < $($_.Required)" }) -join "; ") + ". Uruchom program ponownie i połącz najpierw z tą usługą." }
        else { "" }
        $rows.Add([PSCustomObject]@{
                Składnik       = $name
                Wersja         = "$($installed[0].Version)"
                Załadowana     = $(if ($loaded) { "$($loaded.Version)" } else { "" })
                "Wersja zgodna" = $(if ($compatible) { "$($compatible.Version)" } else { "" })
                Zainstalowane  = (@($installed | ForEach-Object { "$($_.Version)" } | Select-Object -Unique) -join ", ")
                Stan           = $state
                Szczegóły      = $detail
                Moduł          = $name
                __flag         = $(switch ($state) { "Wymaga nowszego PowerShell" { "crit" } "Konflikt bibliotek" { "warn" } "Używana starsza wersja" { "warn" } default { "" } })
            })
    }
    $ad = Get-Module -ListAvailable -Name ActiveDirectory | Select-Object -First 1
    $rows.Add([PSCustomObject]@{ Składnik = "ActiveDirectory (RSAT)"; Wersja = $(if ($ad) { "$($ad.Version)" } else { "" }); Stan = $(if ($ad) { "OK" } else { "Brak" }); Szczegóły = $(if ($ad) { "" } else { "Ustawienia > Aplikacje > Funkcje opcjonalne > RSAT: Active Directory Domain Services" }); __flag = $(if ($ad) { "" } else { "muted" }) })
    return $rows.ToArray()
}
#endregion
