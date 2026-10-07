# Użytkownicy Microsoft 365 (Entra ID) przez Microsoft Graph REST (Invoke-HTGraphRequest)
# Wymaga modułu Microsoft.Graph.Authentication i połączenia (Connect-Module -Name Microsoft.Graph)

$script:UserListSelect = "id,displayName,userPrincipalName,mail,accountEnabled,jobTitle,department,userType,assignedLicenses,createdDateTime,usageLocation"
$script:SkuCache = $null

# Lista użytkowników
function Get-HTM365Users {
    $users = Invoke-HTGraphRequest -Uri "users?`$select=$script:UserListSelect&`$top=999" -All
    $skuNames = Get-HTSkuNameMap
    return @($users | ForEach-Object {
            [PSCustomObject]@{
                Id                = $_.id
                DisplayName       = $_.displayName
                UserPrincipalName = $_.userPrincipalName
                Mail              = $_.mail
                AccountEnabled    = [bool]$_.accountEnabled
                JobTitle          = $_.jobTitle
                Department        = $_.department
                UserType          = $_.userType
                UsageLocation     = $_.usageLocation
                Licenses          = (@($_.assignedLicenses | ForEach-Object { $skuNames["$($_.skuId)"] ?? "$($_.skuId)" }) -join ", ")
                Created           = $_.createdDateTime
            }
        })
}

# Mapa skuId -> nazwa (SkuPartNumber)
function Get-HTSkuNameMap {
    $map = @{}
    try {
        foreach ($sku in (Get-HTSubscribedSkus)) { $map["$($sku.SkuId)"] = $sku.SkuPartNumber }
    }
    catch {
        Write-Log -Message "Nie udało się pobrać listy licencji: $($_.Exception.Message)" -Type "Warn"
    }
    return $map
}

# Subskrypcje (licencje) w tenancie
function Get-HTSubscribedSkus {
    param ([switch]$Force)
    if ($script:SkuCache -and -not $Force) { return $script:SkuCache }
    $skus = Invoke-HTGraphRequest -Uri "subscribedSkus"
    $script:SkuCache = @($skus | ForEach-Object {
            $enabled = [int]$_.prepaidUnits.enabled
            [PSCustomObject]@{
                SkuId         = $_.skuId
                SkuPartNumber = $_.skuPartNumber
                Enabled       = $enabled
                Consumed      = [int]$_.consumedUnits
                Available     = $enabled - [int]$_.consumedUnits
                Status        = $_.capabilityStatus
            }
        })
    return $script:SkuCache
}

# Czyści pamięć podręczną licencji (np. po zmianie tenantu)
function Clear-HTM365Cache {
    $script:SkuCache = $null
}

# Szczegóły użytkownika
function Get-HTM365UserDetail {
    param ([Parameter(Mandatory)][string]$Id)

    $select = "id,displayName,givenName,surname,userPrincipalName,mail,otherMails,proxyAddresses,accountEnabled,jobTitle,department,companyName,officeLocation,mobilePhone,businessPhones,streetAddress,city,postalCode,country,usageLocation,employeeId,userType,createdDateTime,lastPasswordChangeDateTime,onPremisesSyncEnabled,onPremisesSamAccountName,assignedLicenses"
    $user = Invoke-HTGraphRequest -Uri "users/$Id`?`$select=$select"

    $manager = $null
    try { $manager = Invoke-HTGraphRequest -Uri "users/$Id/manager?`$select=displayName,userPrincipalName" } catch { }

    $groups = @()
    try {
        $groups = @(Invoke-HTGraphRequest -Uri "users/$Id/memberOf/microsoft.graph.group?`$select=displayName&`$top=999" -All | ForEach-Object { $_.displayName } | Sort-Object)
    }
    catch { $groups = @("(brak uprawnień do odczytu)") }

    $licenses = @()
    try {
        $licenses = @(Invoke-HTGraphRequest -Uri "users/$Id/licenseDetails" | ForEach-Object { $_.skuPartNumber } | Sort-Object)
    }
    catch { }

    $methods = @()
    try {
        $methods = @(Get-HTM365AuthMethods -Id $Id | ForEach-Object { "$($_.Type): $($_.Detail)" })
    }
    catch { $methods = @("(brak uprawnień do odczytu metod)") }

    $signIn = $null
    try {
        $activity = Invoke-HTGraphRequest -Uri "users/$Id`?`$select=signInActivity"
        $signIn = $activity.signInActivity.lastSignInDateTime
    }
    catch { }

    return [ordered]@{
        "Nazwa wyświetlana" = $user.displayName
        "UPN"               = $user.userPrincipalName
        "E-mail"            = $user.mail
        "Konto włączone"    = [bool]$user.accountEnabled
        "Typ"               = $user.userType
        "Stanowisko"        = $user.jobTitle
        "Dział"             = $user.department
        "Przełożony"        = if ($manager) { "$($manager.displayName) <$($manager.userPrincipalName)>" } else { "" }
        "Kontakt"           = [ordered]@{
            "Imię"           = $user.givenName
            "Nazwisko"       = $user.surname
            "Firma"          = $user.companyName
            "Biuro"          = $user.officeLocation
            "Telefon komórkowy" = $user.mobilePhone
            "Telefon służbowy"  = @($user.businessPhones)
            "Adres"          = (@($user.streetAddress, $user.postalCode, $user.city, $user.country) | Where-Object { $_ }) -join ", "
            "Lokalizacja użycia" = $user.usageLocation
            "ID pracownika"  = $user.employeeId
        }
        "Konto"             = [ordered]@{
            "Utworzono"             = $user.createdDateTime
            "Ostatnia zmiana hasła" = $user.lastPasswordChangeDateTime
            "Ostatnie logowanie"    = $signIn
            "Synchronizacja z AD"   = [bool]$user.onPremisesSyncEnabled
            "Login AD"              = $user.onPremisesSamAccountName
            "Aliasy"                = @($user.proxyAddresses)
            "ID obiektu"            = $user.id
        }
        "Licencje ($($licenses.Count))"    = [ordered]@{ "Licencje" = $licenses }
        "Metody MFA ($($methods.Count))"   = [ordered]@{ "Metody" = $methods }
        "Grupy ($($groups.Count))"         = [ordered]@{ "Członkostwo" = $groups }
    }
}

# Wyszukanie użytkownika po UPN / ID
function Resolve-HTM365User {
    param ([Parameter(Mandatory)][string]$Identity)
    $escaped = [uri]::EscapeDataString($Identity)
    return Invoke-HTGraphRequest -Uri "users/$escaped`?`$select=id,displayName,userPrincipalName,mail"
}

# Reset hasła
function Reset-HTM365UserPassword {
    param (
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Password,
        [bool]$ForceChange = $true
    )
    $body = @{
        passwordProfile = @{
            password                      = $Password
            forceChangePasswordNextSignIn = $ForceChange
        }
    }
    Invoke-HTGraphRequest -Uri "users/$Id" -Method PATCH -Body $body | Out-Null
}

# Blokada / odblokowanie logowania
function Set-HTM365UserEnabled {
    param (
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][bool]$Enabled,
        [bool]$RevokeSessions = $false
    )
    Invoke-HTGraphRequest -Uri "users/$Id" -Method PATCH -Body @{ accountEnabled = $Enabled } | Out-Null
    if ($RevokeSessions) { Revoke-HTM365UserSessions -Id $Id }
}

# Unieważnienie sesji (tokenów odświeżania)
function Revoke-HTM365UserSessions {
    param ([Parameter(Mandatory)][string]$Id)
    Invoke-HTGraphRequest -Uri "users/$Id/revokeSignInSessions" -Method POST -Body @{} | Out-Null
}

# Licencje przypisane bezpośrednio do użytkownika
function Get-HTM365UserLicenses {
    param ([Parameter(Mandatory)][string]$Id)
    return @(Invoke-HTGraphRequest -Uri "users/$Id/licenseDetails" | ForEach-Object {
            [PSCustomObject]@{
                SkuId         = $_.skuId
                SkuPartNumber = $_.skuPartNumber
            }
        })
}

# Przypisanie / usunięcie licencji
function Set-HTM365UserLicense {
    param (
        [Parameter(Mandatory)][string]$Id,
        [string[]]$AddSkuIds = @(),
        [string[]]$RemoveSkuIds = @(),
        [string]$UsageLocation
    )

    if ($AddSkuIds.Count -gt 0) {
        $user = Invoke-HTGraphRequest -Uri "users/$Id`?`$select=usageLocation"
        if (-not $user.usageLocation) {
            $location = if ($UsageLocation) { $UsageLocation } elseif ($Global:DefaultUsageLocation) { $Global:DefaultUsageLocation } else { "PL" }
            Invoke-HTGraphRequest -Uri "users/$Id" -Method PATCH -Body @{ usageLocation = $location } | Out-Null
            Write-Log -Message "Ustawiono lokalizację użycia '$location' (wymagana do przypisania licencji)." -Type "Info"
        }
    }

    $body = @{
        addLicenses    = @($AddSkuIds | ForEach-Object { @{ skuId = $_; disabledPlans = @() } })
        removeLicenses = @($RemoveSkuIds)
    }
    Invoke-HTGraphRequest -Uri "users/$Id/assignLicense" -Method POST -Body $body | Out-Null
}

# Ujednolicony obiekt grupy
function ConvertTo-HTM365GroupObject {
    param ([Parameter(Mandatory)][object]$Group)
    $types = @($Group.groupTypes)
    $kind = if ($types -contains "Unified") { "Microsoft 365" }
    elseif ($Group.securityEnabled -and $Group.mailEnabled) { "Zabezpieczeń (mail)" }
    elseif ($Group.securityEnabled) { "Zabezpieczeń" }
    else { "Dystrybucyjna" }
    return [PSCustomObject]@{
        Id          = $Group.id
        DisplayName = $Group.displayName
        Type        = $kind
        Mail        = $Group.mail
        Dynamic     = ($types -contains "DynamicMembership")
        Synced      = [bool]$Group.onPremisesSyncEnabled
        Description = $Group.description
    }
}

$script:GroupSelect = "id,displayName,description,groupTypes,securityEnabled,mailEnabled,mail,onPremisesSyncEnabled"

# Grupy w tenancie
function Get-HTM365Groups {
    $groups = Invoke-HTGraphRequest -Uri "groups?`$select=$script:GroupSelect&`$top=999" -All
    return @($groups | ForEach-Object { ConvertTo-HTM365GroupObject -Group $_ } | Sort-Object DisplayName)
}

# Grupy, do których należy użytkownik (bezpośrednio)
function Get-HTM365UserGroups {
    param ([Parameter(Mandatory)][string]$Id)
    $groups = Invoke-HTGraphRequest -Uri "users/$Id/memberOf/microsoft.graph.group?`$select=$script:GroupSelect&`$top=999" -All
    return @($groups | ForEach-Object { ConvertTo-HTM365GroupObject -Group $_ } | Sort-Object DisplayName)
}

# Czy członkostwem grupy można zarządzać z tej aplikacji
function Test-HTM365GroupManageable {
    param ([Parameter(Mandatory)][object]$Group)
    return (-not $Group.Dynamic -and -not $Group.Synced)
}

# Dodanie użytkownika do grupy - grupy pocztowe (dystrybucyjne, zabezpieczeń z pocztą) przez Exchange Online
function Add-HTM365UserToGroup {
    param (
        [Parameter(Mandatory)][object]$Group,
        [Parameter(Mandatory)][object]$User
    )
    if ($Group.Type -in "Dystrybucyjna", "Zabezpieczeń (mail)") {
        if (-not $Global:ConnectedToExchange) { throw "Grupa '$($Group.DisplayName)' jest grupą pocztową - wymaga połączenia z Exchange Online." }
        Add-DistributionGroupMember -Identity $Group.Mail -Member $User.UserPrincipalName -BypassSecurityGroupManagerCheck -Confirm:$false -ErrorAction Stop
    }
    else {
        Add-HTM365GroupMember -GroupId $Group.Id -MemberId $User.Id
    }
}

# Usunięcie użytkownika z grupy
function Remove-HTM365UserFromGroup {
    param (
        [Parameter(Mandatory)][object]$Group,
        [Parameter(Mandatory)][object]$User
    )
    if ($Group.Type -in "Dystrybucyjna", "Zabezpieczeń (mail)") {
        if (-not $Global:ConnectedToExchange) { throw "Grupa '$($Group.DisplayName)' jest grupą pocztową - wymaga połączenia z Exchange Online." }
        Remove-DistributionGroupMember -Identity $Group.Mail -Member $User.UserPrincipalName -BypassSecurityGroupManagerCheck -Confirm:$false -ErrorAction Stop
    }
    else {
        Remove-HTM365GroupMember -GroupId $Group.Id -MemberId $User.Id
    }
}

# Wyszukanie grupy po nazwie lub ID
function Resolve-HTM365Group {
    param ([Parameter(Mandatory)][string]$Identity)
    if ($Identity -match '^[0-9a-fA-F-]{36}$') {
        return Invoke-HTGraphRequest -Uri "groups/$Identity`?`$select=id,displayName"
    }
    $name = $Identity.Replace("'", "''")
    $found = @(Invoke-HTGraphRequest -Uri "groups?`$filter=displayName eq '$([uri]::EscapeDataString($name))'&`$select=id,displayName")
    if ($found.Count -eq 0) { throw "Nie znaleziono grupy: $Identity" }
    if ($found.Count -gt 1) { throw "Znaleziono więcej niż jedną grupę o nazwie: $Identity" }
    return $found[0]
}

function Add-HTM365GroupMember {
    param (
        [Parameter(Mandatory)][string]$GroupId,
        [Parameter(Mandatory)][string]$MemberId
    )
    $body = @{ "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$MemberId" }
    Invoke-HTGraphRequest -Uri "groups/$GroupId/members/`$ref" -Method POST -Body $body | Out-Null
}

function Remove-HTM365GroupMember {
    param (
        [Parameter(Mandatory)][string]$GroupId,
        [Parameter(Mandatory)][string]$MemberId
    )
    Invoke-HTGraphRequest -Uri "groups/$GroupId/members/$MemberId/`$ref" -Method DELETE | Out-Null
}

# Mapowanie typów metod uwierzytelniania na ścieżki API
$script:AuthMethodMap = @{
    "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod" = @{ Name = "Microsoft Authenticator"; Path = "microsoftAuthenticatorMethods" }
    "#microsoft.graph.phoneAuthenticationMethod"                  = @{ Name = "Telefon (SMS/połączenie)"; Path = "phoneMethods" }
    "#microsoft.graph.fido2AuthenticationMethod"                  = @{ Name = "Klucz FIDO2"; Path = "fido2Methods" }
    "#microsoft.graph.softwareOathAuthenticationMethod"           = @{ Name = "Token OATH (aplikacja)"; Path = "softwareOathMethods" }
    "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod" = @{ Name = "Windows Hello"; Path = "windowsHelloForBusinessMethods" }
    "#microsoft.graph.emailAuthenticationMethod"                  = @{ Name = "E-mail (SSPR)"; Path = "emailMethods" }
    "#microsoft.graph.temporaryAccessPassAuthenticationMethod"    = @{ Name = "Temporary Access Pass"; Path = "temporaryAccessPassMethods" }
    "#microsoft.graph.passwordAuthenticationMethod"               = @{ Name = "Hasło"; Path = $null }
}

# Metody uwierzytelniania użytkownika
function Get-HTM365AuthMethods {
    param ([Parameter(Mandatory)][string]$Id)
    return @(Invoke-HTGraphRequest -Uri "users/$Id/authentication/methods" | ForEach-Object {
            $type = $_.'@odata.type'
            $info = $script:AuthMethodMap[$type]
            $detail = @($_.displayName, $_.phoneNumber, $_.emailAddress, $_.model, $_.deviceTag) | Where-Object { $_ } | Select-Object -First 1
            [PSCustomObject]@{
                Id        = $_.id
                Type      = if ($info) { $info.Name } else { $type -replace '#microsoft.graph.', '' }
                Detail    = $detail
                ApiPath   = if ($info) { $info.Path } else { $null }
                Removable = [bool]($info -and $info.Path)
                Created   = $_.createdDateTime
            }
        })
}

# Usunięcie metody uwierzytelniania
function Remove-HTM365AuthMethod {
    param (
        [Parameter(Mandatory)][string]$UserId,
        [Parameter(Mandatory)][object]$Method
    )
    if (-not $Method.Removable) { throw "Metody '$($Method.Type)' nie można usunąć." }
    Invoke-HTGraphRequest -Uri "users/$UserId/authentication/$($Method.ApiPath)/$($Method.Id)" -Method DELETE | Out-Null
}

# Normalizacja numeru do formatu wymaganego przez API metod uwierzytelniania: "+48 600100200"
# Numer bez prefiksu traktowany jest jako polski. Kod kraju oddzielony spacją jest zachowywany.
function ConvertTo-HTGraphPhoneNumber {
    param ([Parameter(Mandatory)][string]$PhoneNumber)
    $clean = (($PhoneNumber -replace '[^\d\+\s]', '').Trim() -replace '\s+', ' ')
    if ($clean -notmatch '^\+') { return "+48 " + ($clean -replace '\s', '') }
    if ($clean -match '^\+(\d{1,3})\s+(.+)$') { return "+$($matches[1]) " + ($matches[2] -replace '\s', '') }
    $digits = $clean.Substring(1)
    # Kody jednocyfrowe: 1 (NANP), 7 (RU/KZ); pozostałe przyjmujemy jako dwucyfrowe (np. 48, 49, 44)
    $codeLength = if ($digits -match '^[17]') { 1 } else { 2 }
    return "+$($digits.Substring(0, $codeLength)) $($digits.Substring($codeLength))"
}

# Dodanie numeru telefonu jako metody MFA
function Add-HTM365PhoneMethod {
    param (
        [Parameter(Mandatory)][string]$UserId,
        [Parameter(Mandatory)][string]$PhoneNumber,
        [ValidateSet("mobile", "alternateMobile", "office")][string]$PhoneType = "mobile"
    )
    $number = ConvertTo-HTGraphPhoneNumber -PhoneNumber $PhoneNumber
    Invoke-HTGraphRequest -Uri "users/$UserId/authentication/phoneMethods" -Method POST -Body @{ phoneNumber = $number; phoneType = $PhoneType } | Out-Null
    return $number
}

# Wygenerowanie Temporary Access Pass
function New-HTM365TemporaryAccessPass {
    param (
        [Parameter(Mandatory)][string]$UserId,
        [ValidateRange(10, 43200)][int]$LifetimeInMinutes = 60,
        [bool]$IsUsableOnce = $true
    )
    $tap = Invoke-HTGraphRequest -Uri "users/$UserId/authentication/temporaryAccessPassMethods" -Method POST -Body @{
        lifetimeInMinutes = $LifetimeInMinutes
        isUsableOnce      = $IsUsableOnce
    }
    return $tap
}

# Aktualizacja danych kontaktowych (tylko przekazane pola)
function Set-HTM365UserContact {
    param (
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][hashtable]$Properties
    )
    $allowed = "displayName", "givenName", "surname", "jobTitle", "department", "companyName", "officeLocation", "mobilePhone", "businessPhones", "streetAddress", "city", "postalCode", "country", "usageLocation", "employeeId"
    $body = @{}
    foreach ($key in $Properties.Keys) {
        if ($allowed -notcontains $key) { throw "Nieobsługiwana właściwość: $key" }
        $value = $Properties[$key]
        if ($key -eq "businessPhones") {
            $body[$key] = @($value | Where-Object { $_ })
        }
        else {
            $body[$key] = if ([string]::IsNullOrWhiteSpace("$value")) { $null } else { "$value" }
        }
    }
    if ($body.Count -eq 0) { return }
    Invoke-HTGraphRequest -Uri "users/$Id" -Method PATCH -Body $body | Out-Null
}

# Urządzenia użytkownika (Intune + zarejestrowane w Entra ID)
function Get-HTM365UserDevices {
    param ([Parameter(Mandatory)][string]$Id)

    $result = New-Object System.Collections.Generic.List[object]
    try {
        foreach ($d in (Invoke-HTGraphRequest -Uri "users/$Id/managedDevices?`$select=deviceName,operatingSystem,osVersion,complianceState,lastSyncDateTime,serialNumber,model" -All)) {
            $result.Add([PSCustomObject]@{
                    Źródło        = "Intune"
                    Nazwa         = $d.deviceName
                    System        = "$($d.operatingSystem) $($d.osVersion)"
                    Zgodność      = $d.complianceState
                    Model         = $d.model
                    NumerSeryjny  = $d.serialNumber
                    OstatniaAktywność = $d.lastSyncDateTime
                })
        }
    }
    catch { Write-Log -Message "Nie udało się pobrać urządzeń Intune: $($_.Exception.Message)" -Type "Warn" }

    try {
        foreach ($d in (Invoke-HTGraphRequest -Uri "users/$Id/registeredDevices" -All)) {
            $result.Add([PSCustomObject]@{
                    Źródło        = "Entra ID"
                    Nazwa         = $d.displayName
                    System        = "$($d.operatingSystem) $($d.operatingSystemVersion)"
                    Zgodność      = if ($null -ne $d.isCompliant) { if ($d.isCompliant) { "compliant" } else { "noncompliant" } } else { "" }
                    Model         = $d.model
                    NumerSeryjny  = ""
                    OstatniaAktywność = $d.approximateLastSignInDateTime
                })
        }
    }
    catch { Write-Log -Message "Nie udało się pobrać urządzeń Entra ID: $($_.Exception.Message)" -Type "Warn" }

    return $result.ToArray()
}

# Nowy użytkownik
function New-HTM365User {
    param (
        [Parameter(Mandatory)][string]$DisplayName,
        [Parameter(Mandatory)][string]$UserPrincipalName,
        [Parameter(Mandatory)][string]$Password,
        [string]$GivenName,
        [string]$Surname,
        [string]$JobTitle,
        [string]$Department,
        [string]$UsageLocation,
        [bool]$ForceChange = $true,
        [bool]$AccountEnabled = $true
    )
    $body = @{
        accountEnabled    = $AccountEnabled
        displayName       = $DisplayName
        userPrincipalName = $UserPrincipalName
        mailNickname      = ($UserPrincipalName.Split("@")[0] -replace '[^a-zA-Z0-9\.\-_]', '')
        passwordProfile   = @{ password = $Password; forceChangePasswordNextSignIn = $ForceChange }
    }
    if ($GivenName) { $body.givenName = $GivenName }
    if ($Surname) { $body.surname = $Surname }
    if ($JobTitle) { $body.jobTitle = $JobTitle }
    if ($Department) { $body.department = $Department }
    $location = if ($UsageLocation) { $UsageLocation } else { $Global:DefaultUsageLocation }
    if ($location) { $body.usageLocation = $location }
    return Invoke-HTGraphRequest -Uri "users" -Method POST -Body $body
}

# Domeny zweryfikowane w tenancie (do tworzenia UPN)
function Get-HTM365Domains {
    return @(Invoke-HTGraphRequest -Uri "domains" | Where-Object { $_.isVerified } | Sort-Object { -not $_.isDefault }, id | ForEach-Object { $_.id })
}

#region Przełożony
function Get-HTM365UserManager {
    param ([Parameter(Mandatory)][string]$Id)
    try { return Invoke-HTGraphRequest -Uri "users/$Id/manager?`$select=id,displayName,userPrincipalName,jobTitle" }
    catch {
        if ("$($_.Exception.Message)" -match 'Request_ResourceNotFound|NotFound|404') { return $null }
        throw
    }
}

function Set-HTM365UserManager {
    param (
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$ManagerId
    )
    if ($Id -eq $ManagerId) { throw "Użytkownik nie może być swoim przełożonym." }
    $body = @{ "@odata.id" = "https://graph.microsoft.com/v1.0/users/$ManagerId" }
    Invoke-HTGraphRequest -Uri "users/$Id/manager/`$ref" -Method PUT -Body $body | Out-Null
}

function Remove-HTM365UserManager {
    param ([Parameter(Mandatory)][string]$Id)
    Invoke-HTGraphRequest -Uri "users/$Id/manager/`$ref" -Method DELETE | Out-Null
}
#endregion

#region Logowania (wymaga AuditLog.Read.All i licencji Entra ID P1)
function ConvertTo-HTSignInRow {
    param ([Parameter(Mandatory)][object]$SignIn)
    $code = [int]$SignIn.status.errorCode
    $location = @($SignIn.location.city, $SignIn.location.countryOrRegion) | Where-Object { $_ }
    return [PSCustomObject]@{
        Czas                = $SignIn.createdDateTime
        Użytkownik          = $SignIn.userPrincipalName
        Aplikacja           = $SignIn.appDisplayName
        "Adres IP"          = $SignIn.ipAddress
        Lokalizacja         = ($location -join ", ")
        Wynik               = if ($code -eq 0) { "Sukces" } else { "Błąd $code" }
        Powód               = $SignIn.status.failureReason
        "Wymagane MFA"      = ("$($SignIn.authenticationRequirement)" -eq "multiFactorAuthentication")
        "Dostęp warunkowy"  = $SignIn.conditionalAccessStatus
        Klient              = $SignIn.clientAppUsed
        System              = $SignIn.deviceDetail.operatingSystem
        Przeglądarka        = $SignIn.deviceDetail.browser
        Urządzenie          = $SignIn.deviceDetail.displayName
        Ryzyko              = $SignIn.riskLevelDuringSignIn
        __flag              = if ($code -ne 0) { "crit" } elseif ("$($SignIn.riskLevelDuringSignIn)" -in "medium", "high") { "warn" } else { "" }
    }
}

# Ostatnie logowania użytkownika
function Get-HTM365SignIns {
    param (
        [Parameter(Mandatory)][string]$UserId,
        [ValidateRange(1, 1000)][int]$Top = 50,
        [switch]$FailedOnly
    )
    $filter = "userId eq '$UserId'"
    if ($FailedOnly) { $filter += " and status/errorCode ne 0" }
    $items = Invoke-HTGraphRequest -Uri "auditLogs/signIns?`$filter=$([uri]::EscapeDataString($filter))&`$top=$Top"
    return @($items | ForEach-Object { ConvertTo-HTSignInRow -SignIn $_ })
}

# Nieudane logowania w organizacji z ostatnich godzin
function Get-HTM365FailedSignIns {
    param ([ValidateRange(1, 720)][int]$Hours = 24, [ValidateRange(1, 5000)][int]$Max = 1000)
    $since = (Get-Date).ToUniversalTime().AddHours(-$Hours).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $filter = "createdDateTime ge $since and status/errorCode ne 0"
    $uri = "auditLogs/signIns?`$filter=$([uri]::EscapeDataString($filter))&`$top=500"
    $result = New-Object System.Collections.Generic.List[object]
    $response = Invoke-MgGraphRequest -Uri (Resolve-HTGraphUri -Uri $uri) -Method GET -OutputType PSObject -ErrorAction Stop
    while ($response) {
        foreach ($item in @($response.value)) { if ($item) { $result.Add((ConvertTo-HTSignInRow -SignIn $item)) } }
        if ($result.Count -ge $Max -or -not $response.'@odata.nextLink') { break }
        $response = Invoke-MgGraphRequest -Uri $response.'@odata.nextLink' -Method GET -OutputType PSObject -ErrorAction Stop
    }
    return $result.ToArray()
}
#endregion

#region Raporty użytkowników
# Ostatnie logowanie (interaktywne lub nieinteraktywne - nowsze z dwóch)
function Get-HTM365LastSignIn {
    param ([AllowNull()][object]$SignInActivity)
    if (-not $SignInActivity) { return $null }
    $dates = @($SignInActivity.lastSignInDateTime, $SignInActivity.lastNonInteractiveSignInDateTime) | Where-Object { $_ } | ForEach-Object {
        $parsed = [datetimeoffset]::MinValue
        if ([datetimeoffset]::TryParse("$_", [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) { $parsed.LocalDateTime }
    }
    return @($dates | Sort-Object -Descending)[0]
}

# Użytkownicy bez logowania od wskazanej liczby dni (wymaga AuditLog.Read.All i Entra ID P1)
function Get-HTM365InactiveUsers {
    param (
        [ValidateRange(1, 3650)][int]$Days = 90,
        [switch]$IncludeDisabled,
        [switch]$IncludeGuests
    )
    $select = "id,displayName,userPrincipalName,accountEnabled,userType,createdDateTime,assignedLicenses,department,signInActivity"
    $users = Invoke-HTGraphRequest -Uri "users?`$select=$select&`$top=999" -All
    $skuNames = Get-HTSkuNameMap
    foreach ($u in $users) {
        if (-not $IncludeDisabled -and -not $u.accountEnabled) { continue }
        if (-not $IncludeGuests -and $u.userType -eq "Guest") { continue }
        $last = Get-HTM365LastSignIn -SignInActivity $u.signInActivity
        $idle = Get-HTDaysSince $last
        $createdDays = Get-HTDaysSince $u.createdDateTime
        $inactive = if ($null -eq $idle) { $null -eq $createdDays -or $createdDays -ge $Days } else { $idle -ge $Days }
        if (-not $inactive) { continue }
        [PSCustomObject]@{
            Nazwa                 = $u.displayName
            UPN                   = $u.userPrincipalName
            Typ                   = $u.userType
            Włączone              = [bool]$u.accountEnabled
            Dział                 = $u.department
            "Ostatnie logowanie"  = $last
            "Dni bez logowania"   = if ($null -ne $idle) { $idle } else { "nigdy" }
            Licencje              = (@($u.assignedLicenses | ForEach-Object { $skuNames["$($_.skuId)"] ?? "$($_.skuId)" }) -join ", ")
            Utworzono             = $u.createdDateTime
            Id                    = $u.id
            __flag                = if (@($u.assignedLicenses).Count -gt 0) { "warn" } else { "" }
        }
    }
}

# Konta gości
function Get-HTM365GuestUsers {
    $select = "id,displayName,userPrincipalName,mail,accountEnabled,createdDateTime,externalUserState,externalUserStateChangeDateTime,signInActivity"
    $users = Invoke-HTGraphRequest -Uri "users?`$filter=userType eq 'Guest'&`$select=$select&`$top=999" -All
    foreach ($u in $users) {
        $last = Get-HTM365LastSignIn -SignInActivity $u.signInActivity
        $days = Get-HTDaysSince $last
        [PSCustomObject]@{
            Nazwa                = $u.displayName
            "E-mail"             = $u.mail
            Włączone             = [bool]$u.accountEnabled
            "Stan zaproszenia"   = $u.externalUserState
            "Zmiana stanu"       = $u.externalUserStateChangeDateTime
            Utworzono            = $u.createdDateTime
            "Ostatnie logowanie" = $last
            "Dni bez logowania"  = if ($null -ne $days) { $days } else { "nigdy" }
            UPN                  = $u.userPrincipalName
            Id                   = $u.id
            __flag               = if ("$($u.externalUserState)" -eq "PendingAcceptance") { "muted" } elseif ($null -eq $days -or $days -ge 90) { "warn" } else { "" }
        }
    }
}

# Stan rejestracji metod uwierzytelniania (MFA, SSPR, passwordless)
function Get-HTM365MfaRegistration {
    $items = Invoke-HTGraphRequest -Uri "reports/authenticationMethods/userRegistrationDetails?`$top=999" -All
    foreach ($r in $items) {
        [PSCustomObject]@{
            Nazwa               = $r.userDisplayName
            UPN                 = $r.userPrincipalName
            Administrator       = [bool]$r.isAdmin
            "MFA zarejestrowane" = [bool]$r.isMfaRegistered
            "MFA możliwe"       = [bool]$r.isMfaCapable
            SSPR                = [bool]$r.isSsprRegistered
            "Bez hasła"         = [bool]$r.isPasswordlessCapable
            "Domyślna metoda"   = $r.userPreferredMethodForSecondaryAuthentication
            Metody              = (@($r.methodsRegistered) -join ", ")
            Typ                 = $r.userType
            __flag              = if (-not $r.isMfaRegistered -and $r.isAdmin) { "crit" } elseif (-not $r.isMfaRegistered) { "warn" } else { "" }
        }
    }
}

# Aktywni użytkownicy (członkowie) bez licencji
function Get-HTM365UnlicensedUsers {
    $users = Invoke-HTGraphRequest -Uri "users?`$select=id,displayName,userPrincipalName,accountEnabled,userType,department,createdDateTime,assignedLicenses,onPremisesSyncEnabled&`$top=999" -All
    foreach ($u in $users) {
        if ($u.userType -eq "Guest" -or @($u.assignedLicenses).Count -gt 0) { continue }
        [PSCustomObject]@{
            Nazwa              = $u.displayName
            UPN                = $u.userPrincipalName
            Włączone           = [bool]$u.accountEnabled
            Dział              = $u.department
            "Synchronizacja AD" = [bool]$u.onPremisesSyncEnabled
            Utworzono          = $u.createdDateTime
            Id                 = $u.id
        }
    }
}

# Członkowie aktywnych ról katalogu (administratorzy)
function Get-HTM365AdminRoles {
    $roles = Invoke-HTGraphRequest -Uri "directoryRoles?`$expand=members(`$select=id,displayName,userPrincipalName)"
    foreach ($role in @($roles | Sort-Object displayName)) {
        foreach ($member in @($role.members)) {
            $type = "$($member.'@odata.type')" -replace '#microsoft.graph.', ''
            [PSCustomObject]@{
                Rola       = $role.displayName
                Członek    = $member.displayName
                UPN        = $member.userPrincipalName
                Typ        = $type
                "Opis roli" = $role.description
                Id         = $member.id
                __flag     = if ($role.displayName -eq "Global Administrator") { "warn" } else { "" }
            }
        }
    }
}

# Usunięci użytkownicy (kosz katalogu - 30 dni)
function Get-HTM365DeletedUsers {
    $items = Invoke-HTGraphRequest -Uri "directory/deletedItems/microsoft.graph.user?`$select=id,displayName,userPrincipalName,mail,deletedDateTime,jobTitle,department&`$top=999" -All
    foreach ($u in @($items | Sort-Object deletedDateTime -Descending)) {
        $deleted = Get-HTDaysSince $u.deletedDateTime
        [PSCustomObject]@{
            Nazwa             = $u.displayName
            UPN               = $u.userPrincipalName
            "E-mail"          = $u.mail
            Usunięto          = $u.deletedDateTime
            "Usunięcie trwałe za (dni)" = if ($null -ne $deleted) { [Math]::Max(0, 30 - $deleted) } else { "" }
            Dział             = $u.department
            Id                = $u.id
        }
    }
}

function Restore-HTM365DeletedUser {
    param ([Parameter(Mandatory)][string]$Id)
    return Invoke-HTGraphRequest -Uri "directory/deletedItems/$Id/restore" -Method POST -Body @{}
}

function Remove-HTM365DeletedUser {
    param ([Parameter(Mandatory)][string]$Id)
    Invoke-HTGraphRequest -Uri "directory/deletedItems/$Id" -Method DELETE | Out-Null
}

# Trwałe usunięcie konta użytkownika (trafia do kosza katalogu na 30 dni)
function Remove-HTM365User {
    param ([Parameter(Mandatory)][string]$Id)
    Invoke-HTGraphRequest -Uri "users/$Id" -Method DELETE | Out-Null
}
#endregion

#region Kondycja usług i centrum wiadomości (ServiceHealth.Read.All, ServiceMessage.Read.All)
function Get-HTM365ServiceHealth {
    $overviews = @(Invoke-HTGraphRequest -Uri "admin/serviceAnnouncement/healthOverviews?`$select=service,status")
    $issues = @()
    try { $issues = @(Invoke-HTGraphRequest -Uri "admin/serviceAnnouncement/issues?`$filter=isResolved eq false" -All) }
    catch { Write-Log -Message "Nie udało się pobrać listy incydentów: $($_.Exception.Message)" -Type "Warn" }
    $statusNames = @{
        serviceOperational = "Działa"; investigating = "Badanie problemu"; restoringService = "Przywracanie"; verifyingService = "Weryfikacja"
        serviceRestored = "Przywrócono"; postIncidentReviewPublished = "Raport po incydencie"; serviceDegradation = "Obniżona wydajność"
        serviceInterruption = "Przerwa w działaniu"; extendedRecovery = "Wydłużone przywracanie"; falsePositive = "Fałszywy alarm"
    }
    foreach ($o in @($overviews | Sort-Object service)) {
        $serviceIssues = @($issues | Where-Object { $_.service -eq $o.service })
        $status = "$($o.status)"
        [PSCustomObject]@{
            Usługa      = $o.service
            Stan        = $statusNames[$status] ?? $status
            Incydenty   = $serviceIssues.Count
            Szczegóły   = (@($serviceIssues | ForEach-Object { "[$($_.id)] $($_.title)" }) -join "`n")
            __flag      = if ($status -in "serviceInterruption", "extendedRecovery") { "crit" } elseif ($status -ne "serviceOperational" -or $serviceIssues.Count -gt 0) { "warn" } else { "" }
        }
    }
}

function Get-HTM365MessageCenter {
    param ([ValidateRange(1, 365)][int]$Days = 30)
    $since = (Get-Date).ToUniversalTime().AddDays(-$Days).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $items = Invoke-HTGraphRequest -Uri "admin/serviceAnnouncement/messages?`$filter=lastModifiedDateTime ge $since&`$top=100" -All
    foreach ($m in @($items | Sort-Object lastModifiedDateTime -Descending)) {
        $body = "$($m.body.content)" -replace '(?i)<br\s*/?>', "`n" -replace '(?i)</p>', "`n" -replace '<[^>]+>', ''
        $body = [System.Net.WebUtility]::HtmlDecode($body).Trim()
        [PSCustomObject]@{
            Data                 = $m.lastModifiedDateTime
            Tytuł                = $m.title
            Kategoria            = $m.category
            Usługi               = (@($m.services) -join ", ")
            Ważność              = $m.severity
            "Wymaga działania do" = $m.actionRequiredByDateTime
            Treść                = if ($body.Length -gt 4000) { $body.Substring(0, 4000) + "…" } else { $body }
            Id                   = $m.id
            __flag               = if ($m.actionRequiredByDateTime) { "warn" } elseif ("$($m.severity)" -eq "critical") { "crit" } else { "" }
        }
    }
}
#endregion

#region Nazwy licencji
$script:SkuFriendlyNames = @{
    "ENTERPRISEPACK" = "Office 365 E3"; "ENTERPRISEPREMIUM" = "Office 365 E5"; "STANDARDPACK" = "Office 365 E1"; "DESKLESSPACK" = "Office 365 F3"
    "SPE_E3" = "Microsoft 365 E3"; "SPE_E5" = "Microsoft 365 E5"; "SPE_F1" = "Microsoft 365 F3"; "SPB" = "Microsoft 365 Business Premium"
    "O365_BUSINESS_PREMIUM" = "Microsoft 365 Business Standard"; "O365_BUSINESS_ESSENTIALS" = "Microsoft 365 Business Basic"
    "O365_BUSINESS" = "Microsoft 365 Apps for business"; "OFFICESUBSCRIPTION" = "Microsoft 365 Apps for enterprise"
    "EXCHANGESTANDARD" = "Exchange Online (Plan 1)"; "EXCHANGEENTERPRISE" = "Exchange Online (Plan 2)"; "EXCHANGEDESKLESS" = "Exchange Online Kiosk"
    "EMS" = "Enterprise Mobility + Security E3"; "EMSPREMIUM" = "Enterprise Mobility + Security E5"; "AAD_PREMIUM" = "Microsoft Entra ID P1"
    "AAD_PREMIUM_P2" = "Microsoft Entra ID P2"; "INTUNE_A" = "Microsoft Intune Plan 1"; "POWER_BI_PRO" = "Power BI Pro"; "POWER_BI_STANDARD" = "Power BI (bezpłatna)"
    "FLOW_FREE" = "Power Automate (bezpłatna)"; "TEAMS_EXPLORATORY" = "Teams Exploratory"; "MCOEV" = "Teams Phone Standard"; "MCOMEETADV" = "Audio Conferencing"
    "VISIOCLIENT" = "Visio Plan 2"; "PROJECTPROFESSIONAL" = "Project Plan 3"; "WINDOWS_STORE" = "Windows Store for Business"; "ATP_ENTERPRISE" = "Defender for Office 365 (Plan 1)"
    "Microsoft_Teams_Rooms_Pro" = "Teams Rooms Pro"; "Microsoft_365_Copilot" = "Microsoft 365 Copilot"; "Microsoft_Teams_Premium" = "Teams Premium"
}

function Get-HTSkuFriendlyName {
    param ([AllowEmptyString()][string]$SkuPartNumber)
    if (-not $SkuPartNumber) { return "" }
    $name = $script:SkuFriendlyNames[$SkuPartNumber]
    if ($name) { return $name }
    return $SkuPartNumber
}

# Użytkownicy z przypisaną licencją
function Get-HTSkuUsers {
    param ([Parameter(Mandatory)][string]$SkuId)
    $filter = [uri]::EscapeDataString("assignedLicenses/any(x:x/skuId eq $SkuId)")
    $users = Invoke-HTGraphRequest -Uri "users?`$filter=$filter&`$count=true&`$select=id,displayName,userPrincipalName,accountEnabled,department&`$top=999" -All -ConsistencyLevelEventual
    return @($users | ForEach-Object {
            [PSCustomObject]@{ Nazwa = $_.displayName; UPN = $_.userPrincipalName; Włączone = [bool]$_.accountEnabled; Dział = $_.department }
        } | Sort-Object Nazwa)
}
#endregion
