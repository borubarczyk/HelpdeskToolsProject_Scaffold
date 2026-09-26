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
    if ($approve -ne [System.Windows.Forms.DialogResult]::Yes) {
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

# Funkcja do połączenia z modułem
function Connect-Module {
    param (
        [ValidateSet("Microsoft.Graph", "Microsoft.GraphGDAP", "ExchangeOnlineManagement", "ExchangeOnlineManagementGDAP", "PnP.PowerShell")]
        [string]$Name,

        # Adres witryny dla PnP.PowerShell (domyślnie z pola w zakładce SharePoint lub z konfiguracji)
        [string]$SiteUrl
    )

    if (-not (Install-ModuleIfMissing -Name $Name)) { return $false }

    Set-HTBusy -Busy $true -Text "Łączenie: $Name..."

    try {
        switch ($Name) {
            'Microsoft.Graph' {
                Import-Module Microsoft.Graph.Authentication -ErrorAction Stop -Global
                Connect-MgGraph -Scopes $Global:GraphScopes -NoWelcome -ErrorAction Stop
                $tenant = Get-HTGraphTenantName
                $Global:ConnectedToGraphAPI = $true
                Update-ConnectionButtonText -Service "Graph" -TenantName $tenant
                Write-Log "Połączono z Microsoft Graph ($tenant)" "Info&Notification"
            }
            'Microsoft.GraphGDAP' {
                Set-HTBusy -Busy $false
                $tenantId = Show-InputBox -Prompt "Podaj ID lub domenę tenantu klienta (GDAP):" -Title "Tenant GDAP" -ValidationType "Text"
                Set-HTBusy -Busy $true -Text "Łączenie: $Name..."
                if (-not $tenantId) {
                    Write-Log "Anulowano połączenie z GDAP - nie podano ID tenantu." "Warning&Notification"
                    return $false
                }
                Import-Module Microsoft.Graph.Authentication -ErrorAction Stop -Global
                Connect-MgGraph -TenantId $tenantId -Scopes $Global:GraphScopes -NoWelcome -ErrorAction Stop
                $tenant = Get-HTGraphTenantName
                $Global:ConnectedToGraphAPI = $true
                Update-ConnectionButtonText -Service "Graph" -TenantName $tenant
                Write-Log "Połączono z Microsoft Graph ($tenant) korzystając z GDAP." "Info&Notification"
            }
            'ExchangeOnlineManagement' {
                Import-Module ExchangeOnlineManagement -ErrorAction Stop -Global
                Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
                $tenant = (Get-OrganizationConfig).DisplayName
                $Global:ConnectedToExchange = $true
                Update-ConnectionButtonText -Service "Exchange" -TenantName $tenant
                Write-Log "Połączono z Exchange Online ($tenant)" "Info&Notification"
            }
            'ExchangeOnlineManagementGDAP' {
                Set-HTBusy -Busy $false
                $gdapAccount = Show-InputBox -Prompt "Konto administratora GDAP (np. admin@partner.com):" -Title "Konto GDAP" -ValidationType "Email"
                $gdapOrganization = if ($gdapAccount) { Show-InputBox -Prompt "Domena organizacji klienta (np. klient.onmicrosoft.com):" -Title "Organizacja GDAP" -ValidationType "Text" }
                Set-HTBusy -Busy $true -Text "Łączenie: $Name..."
                if (-not $gdapOrganization -or -not $gdapAccount) {
                    Write-Log "Anulowano połączenie z GDAP - nie podano wszystkich wymaganych informacji." "Warning&Notification"
                    return $false
                }
                Import-Module ExchangeOnlineManagement -ErrorAction Stop -Global
                Connect-ExchangeOnline -UserPrincipalName $gdapAccount -DelegatedOrganization $gdapOrganization -ShowBanner:$false -ShowProgress:$false -ErrorAction Stop
                $tenant = (Get-OrganizationConfig).DisplayName
                $Global:ConnectedToExchange = $true
                Update-ConnectionButtonText -Service "Exchange" -TenantName $tenant
                Write-Log "Połączono z Exchange Online ($tenant) korzystając z GDAP." "Info&Notification"
            }
            'PnP.PowerShell' {
                if (-not $SiteUrl -and $Global:HT_UI -and $Global:HT_UI.SharePointTab) { $SiteUrl = $Global:HT_UI.SharePointTab.SiteBox.Text.Trim() }
                if (-not $SiteUrl) { $SiteUrl = $Global:DefaultSharepointSite }

                Set-HTBusy -Busy $false
                $url = Show-InputBox -Prompt "Adres witryny SharePoint:" -Title "Połączenie z SharePoint" -ValidationType "Url" -DefaultText $SiteUrl
                $clientId = if ($url) {
                    Show-InputBox -Prompt "Client ID aplikacji Entra ID (rejestracja aplikacji dla PnP PowerShell):" -Title "Client ID" -ValidationType "Guid" -DefaultText "$($Global:LastUsedClientID)"
                }
                Set-HTBusy -Busy $true -Text "Łączenie: $Name..."

                if (-not $url -or -not $clientId) {
                    Write-Log "Anulowano połączenie z PnP PowerShell." "Warn"
                    return $false
                }

                Import-Module PnP.PowerShell -ErrorAction Stop -Global
                Connect-PnPOnline -Url $url -ClientId $clientId -Interactive -ValidateConnection -ErrorAction Stop
                $connectedUrl = (Get-PnPConnection).Url
                $Global:ConnectedToSharepointPnP = $true
                $Global:ConnectedToSharepoint = $true
                Update-ConnectionButtonText -Service "SharePoint" -TenantName $connectedUrl
                if ($Global:HT_UI -and $Global:HT_UI.SharePointTab) { $Global:HT_UI.SharePointTab.SiteBox.Text = $connectedUrl }

                if ($Global:LogClientIDForPnP -and $clientId -ne $Global:LastUsedClientID) {
                    $Global:LastUsedClientID = $clientId
                    try { Set-HTConfigValue -Name "LastUsedClientID" -Value $clientId } catch { Write-Log "Nie zapisano Client ID w konfiguracji: $_" "Warn" }
                }
                Write-Log "Połączono z PnP PowerShell ($connectedUrl)" "Info&Notification"
            }
        }

        return $true
    }
    catch {
        Write-Log "Błąd połączenia z '$Name': $($_.Exception.Message)" "Error&Notification"
        Set-HTBusy -Busy $false -Text "Błąd połączenia"
        Show-Dialog -Title "Błąd połączenia" -Message "Nie udało się połączyć z '$Name'.`n`n$($_.Exception.Message)" -Type "Error" | Out-Null
        Set-HTBusy -Busy $true
        return $false
    }
    finally {
        Set-HTBusy -Busy $false -Text "Gotowe"
    }
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
