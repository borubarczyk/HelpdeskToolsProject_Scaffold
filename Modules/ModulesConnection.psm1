# Sprawdzanie czy moduły są zainstalowane i ich importowanie
function Test-ModulePresence {
    param ([string]$Name)
    return [bool](Get-Module -ListAvailable -Name $Name)
}

# Funkcja do instalacji modułu, jeśli nie jest zainstalowany
function Install-ModuleIfMissing {
    param (
        [Parameter(Mandatory)]
        [ValidateSet("Microsoft.Graph","Microsoft.GraphGDAP", "ExchangeOnlineManagement", "SharePointOnline", "PnP.PowerShell", "ExchangeOnlineManagementGDAP")]
        [string]$Name
    )

    $moduleNameMap = @{
        "Microsoft.Graph"          = "Microsoft.Graph"
        "ExchangeOnlineManagement" = "ExchangeOnlineManagement"
        "SharePointOnline"         = "Microsoft.Online.SharePoint.PowerShell"
        "PnP.PowerShell"           = "PnP.PowerShell"
        "ExchangeOnlineManagementGDAP" = "ExchangeOnlineManagement"
        "Microsoft.GraphGDAP" = "Microsoft.Graph"
    }
    $actualName = $moduleNameMap[$Name]

    if (Test-ModulePresence -Name $actualName) {
        Write-Log "Moduł '$actualName' już zainstalowany." "Info"
        return $true
    }

    Write-Log "Moduł '$actualName' nie jest zainstalowany." "Warn"
    $approve = Show-Dialog -Title "Instalacja modułu" -Message "Moduł '$actualName' nie jest zainstalowany. Czy chcesz go zainstalować?" -Buttons "YesNo" -Type "Question"
    if ($approve -ne "Yes") {
        Write-Log "Użytkownik anulował instalację modułu '$actualName'." "Warn"
        return $false
    }

    try {
        Install-Module -Name $actualName -Scope AllUsers -AcceptLicense -Force -AllowClobber -Repository PSGallery -ErrorAction Stop 
        Write-Log "Moduł '$actualName' został pomyślnie zainstalowany." "Info"
        return $true
    }
    catch {
        Write-Log "Błąd podczas instalacji modułu '$actualName': $($_.Exception.Message)" "Error&Notification"
        return $false
    }
}

# Funkcja do importowania modułu, jeśli jest zainstalowany
function Import-InstalledModule {
    param ([string]$Name)

    try {
        Import-Module -Name $Name -Force -ErrorAction Stop
        Write-Log "Moduł '$Name' zaimportowany." "Info"
        return $true
    }
    catch {
        Write-Log "Nie udało się zaimportować modułu '$Name': $($_.Exception.Message)" "Error"
        return $false
    }
}

# Funkcja do połączenia z modułem
function Connect-Module {
    param (
        [ValidateSet("Microsoft.Graph", "Microsoft.GraphGDAP", "ExchangeOnlineManagement", "ExchangeOnlineManagementGDAP", "SharePointOnline", "PnP.PowerShell")]
        [string]$Name
    )

    if (-not (Install-ModuleIfMissing -Name $Name)) { return $false }

    Set-ButtonsState -Action "Lock"

    try {
        switch ($Name) {
            'Microsoft.Graph' {
                Connect-MgGraph -Scopes "Directory.Read.All" -NoWelcome -ErrorAction Stop
                $tenant = (Get-MgOrganization).DisplayName
                $Global:ConnectedToGraphAPI = $true
                Update-ConnectionButtonText -Service "Graph" -TenantName $tenant
                Write-Log "Połączono z Microsoft Graph ($tenant)" "Info"
            }
            'Microsoft.GraphGDAP' {
                $TenantID = Show-InputBox -Prompt "ID tenantu GDAP" -Title "ID Tenantu GDAP" -ValidationType "text"
                if (-not $TenantID) {
                    Write-Log "Anulowano połączenie z GDAP - nie podano ID tenantu." "Warning&Notification"
                    Set-ButtonsState -Action "Unlock"
                    return $false
                }else {
                    Connect-MgGraph -TenantId $TenantID -Scopes "Directory.Read.All" -NoWelcome -ErrorAction Stop    
                    $tenant = (Get-MgOrganization).DisplayName
                    $Global:ConnectedToGraphAPI = $true
                    Update-ConnectionButtonText -Service "Graph" -TenantName $tenant
                    Write-Log "Połączono z Microsoft Graph ($tenant) korzystając z GDAP." "Info"
                }
            }
            'ExchangeOnlineManagement' {
                Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
                $tenant = (Get-OrganizationConfig).DisplayName
                $Global:ConnectedToExchange = $true
                Update-ConnectionButtonText -Service "Exchange" -TenantName $tenant
                Write-Log "Połączono z Exchange Online ($tenant)" "Info"
            }
            'ExchangeOnlineManagementGDAP' {
                $GDAPAccount = Show-InputBox -Prompt "Wprowadź konto GDAP example@mydomain.com" -Title "Konto GDAP" -ValidationType "email"
                $GDAPDomainOrganization = Show-InputBox -Prompt "Wprowadź domenę organizacji GDAP" -Title "Nazwa Organizacji GDAP" -ValidationType "text"
                if (-not $GDAPDomainOrganization -or -not $GDAPAccount) {
                    Write-Log "Anulowano połączenie z GDAP - nie podano wszystkich wymaganych informacji." "Warning&Notification"
                    Set-ButtonsState -Action "Unlock"
                    return $false
                }
                Connect-ExchangeOnline -UserPrincipalName:$GDAPAccount -DelegatedOrganization:$GDAPDomainOrganization -ShowBanner:$false -ShowProgress:$false -ErrorAction Stop
                $tenant = (Get-OrganizationConfig).DisplayName
                $Global:ConnectedToExchange = $true
                Update-ConnectionButtonText -Service "Exchange" -TenantName $tenant
                Write-Log "Połączono z Exchange Online ($tenant) korzystając z GDAP." "Info"
            }
            'SharePointOnline' {
                Connect-MgGraph -Scopes "Sites.Read.All" -NoWelcome -ErrorAction Stop
                $tenant = (Get-MgOrganization).DisplayName
                $Global:ConnectedToSharepoint = $true
                Update-ConnectionButtonText -Service "SharePoint" -TenantName $tenant
                Write-Log "Połączono z SharePoint Online ($tenant)" "Info"
            }
            'PnP.PowerShell' {
                $url = Show-InputBox -Prompt "SharePoint URL" -Title "Podaj adres URL" -ValidationType "url"
                if (-not $url) {
                    Write-Log "Anulowano połączenie z PnP PowerShell." "Warn"
                    Set-ButtonsState -Action "Unlock"
                    return $false
                }
                $clientId = Show-InputBox -Prompt "Client ID" -Title "Client ID" -ValidationType "text"
                if (-not $clientId) {
                    Write-Log "Brak Client ID" -Type "Warn"
                    Set-ButtonsState -Action "Unlock"
                    return $false
                }
                Connect-PnPOnline -Url $url -ClientId $clientId -Interactive -ValidateConnection -ErrorAction Stop
                $title = (Get-PnPConnection).Url
                $Global:ConnectedToSharepointPnP = $true
                Update-ConnectionButtonText -Service "SharePoint" -TenantName $title
                Write-Log "Połączono z PnP PowerShell ($title)" "Info"
            }
        }

        Set-ButtonsState -Action "Unlock"
        return $true
    }
    catch {
        Write-Log "Błąd połączenia z '$Name': $($_.Exception.Message)" "Error&Notification"
        Show-Dialog -Title "Błąd połączenia" -Message "Nie udało się połączyć z '$Name'. Sprawdź logi dla szczegółów." -Type "Error"
        Set-ButtonsState -Action "Unlock"
        return $false
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
            try {
                $session = Get-ConnectionInformation -ErrorAction Stop
                if ($session.State -eq "Connected") {
                    $tenant = (Get-OrganizationConfig).DisplayName
                    Write-Log "Połączono z Exchange Online ($tenant)" -Type "Info"
                    $Global:ConnectedToExchange = $true
                }
                else {
                    throw "Niepołączony"

                }
            }
            catch {
                Write-Log "Brak połączenia z Exchange Online" -Type "Warn"
                $Global:ConnectedToExchange = $false
                Update-ConnectionButtonText -Service "Exchange"
            }

            # Microsoft Graph
            try {
                if (Get-MgContext -ErrorAction Stop) {
                    $tenant = (Get-MgOrganization).DisplayName
                    Write-Log "Połączono z Microsoft Graph ($tenant)" -Type "Info"
                    $Global:ConnectedToGraphAPI = $true
                }
                else {
                    throw "Niepołączony"
                }
            }
            catch {
                Write-Log "Brak połączenia z Microsoft Graph" -Type "Warn"
                $Global:ConnectedToGraphAPI = $false
                Update-ConnectionButtonText -Service "Graph"
            }

            # SharePoint Online via Graph
            try {
                Get-MgSite -SiteId "root" -ErrorAction Stop | Out-Null
                Write-Log "SharePoint Online działa" -Type "Info"
                $Global:ConnectedToSharepoint = $true
            }
            catch {
                Write-Log "Brak połączenia z SharePoint Online" -Type "Warn"
                $Global:ConnectedToSharepoint = $false
                Update-ConnectionButtonText -Service "SharePoint"
            }

            # SharePoint PnP
            try {
                $context = Get-PnPContext -ErrorAction Stop
                if ($context) {
                    Write-Log "Połączono z PnP PowerShell" -Type "Info"
                    $Global:ConnectedToSharepointPnP = $true
                }
                else {
                    throw "Niepołączony"
                }
            }
            catch {
                Write-Log "Brak połączenia z PnP PowerShell" -Type "Warn"
                $Global:ConnectedToSharepointPnP = $false
                Update-ConnectionButtonText -Service "SharePoint"
            }
        }
        "Disconnect" {
            if ($Service -eq $null) {
                Write-Log "Brak określonej usługi do rozłączenia. Użyj 'DisconnectAll' lub podaj konkretną usługę." -Type "Error"
                return
            }
            else {
                switch ($Service) {
                    "Exchange" {
                        try {
                            Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
                            $Global:ConnectedToExchange = $false
                            Update-ConnectionButtonText -Service "Exchange"
                            Write-Log "Rozłączono Exchange Online" -Type "Info"
                        }
                        catch {
                            Write-Log "Błąd rozłączania Exchange Online: $_" -Type "Error"
                        }
                    }
                    "Graph" {
                        try {
                            Disconnect-MgGraph -ErrorAction SilentlyContinue
                            $Global:ConnectedToGraphAPI = $false
                            Update-ConnectionButtonText -Service "Graph"
                            Write-Log "Rozłączono Microsoft Graph" -Type "Info"
                        }
                        catch {
                            Write-Log "Błąd rozłączania Microsoft Graph: $_" -Type "Error"
                        }
                    }
                    "SharePoint" {
                        try {
                            Disconnect-PnPOnline -ErrorAction SilentlyContinue
                            $Global:ConnectedToSharepoint = $false
                            Update-ConnectionButtonText -Service "SharePoint"
                            Write-Log "Rozłączono SharePoint Online" -Type "Info"
                        }
                        catch {
                            Write-Log "Błąd rozłączania SharePoint Online: $_" -Type "Error"
                        }
                    }
                }
            }
        }

        "DisconnectAll" {
            Write-Log "Rozłączanie wszystkich usług..." -Type "Info"

            try {
                Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
                Update-ConnectionButtonText -Service "Exchange"
                Write-Log "Rozłączono Exchange Online" -Type "Info"
            }
            catch {
                Write-Log "Błąd rozłączania Exchange: $_" -Type "Warn"
            }

            try {
                Disconnect-MgGraph -ErrorAction SilentlyContinue
                Update-ConnectionButtonText -Service "Graph"
                Write-Log "Rozłączono Microsoft Graph (w tym SharePoint)" -Type "Info"
            }
            catch {
                Write-Log "Błąd rozłączania Graph: $_" -Type "Warn"
            }

            try {
                Disconnect-PnPOnline -ErrorAction SilentlyContinue
                Update-ConnectionButtonText -Service "SharePoint"
                Write-Log "Rozłączono PnP PowerShell" -Type "Info"
            }
            catch {
                Write-Log "Błąd rozłączania PnP: $_" -Type "Warn"
            }

            $Global:ConnectedToGraphAPI = $false
            $Global:ConnectedToExchange = $false
            $Global:ConnectedToSharepoint = $false
        }
    }
}
