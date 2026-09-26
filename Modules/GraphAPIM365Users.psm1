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
