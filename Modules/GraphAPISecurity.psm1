# Bezpieczeństwo Microsoft 365 przez Microsoft Graph: sekrety i certyfikaty aplikacji, dostęp warunkowy, ryzykowni
# użytkownicy, dziennik inspekcji Entra, zgody aplikacji, role PIM, administratorzy bez MFA, diagnoza logowania,
# porównanie użytkowników, alerty i incydenty Microsoft Defender oraz izolacja urządzeń (API Defender for Endpoint).
# Moduł nie zależy od interfejsu; funkcje Convert*/Test*/Compare* są czyste (testy jednostkowe).

function Get-HTDaysUntil {
    # Liczba dni do daty (ujemna - data minęła); null, gdy brak daty
    param ([AllowNull()][object]$Date, [datetime]$Now = (Get-Date))
    if ($null -eq $Date -or "$Date" -eq '') { return $null }
    $value = $null
    if ($Date -is [datetime]) { $value = $Date }
    elseif ($Date -is [datetimeoffset]) { $value = $Date.LocalDateTime }
    else {
        $parsed = [datetimeoffset]::MinValue
        if (-not [datetimeoffset]::TryParse("$Date", [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) { return $null }
        $value = $parsed.LocalDateTime
    }
    return [int][Math]::Floor(($value - $Now).TotalDays)
}

function Resolve-HTDirectoryObjectNames {
    # Nazwy obiektów katalogu (użytkownicy, grupy, aplikacje) dla identyfikatorów - słownik Id -> nazwa
    param ([AllowEmptyCollection()][string[]]$Ids = @())
    $map = @{}
    $unique = @($Ids | Where-Object { $_ -match '^[0-9a-fA-F-]{36}$' } | Select-Object -Unique)
    for ($i = 0; $i -lt $unique.Count; $i += 1000) {
        $chunk = @($unique[$i..([Math]::Min($unique.Count, $i + 1000) - 1)])
        try {
            foreach ($o in @(Invoke-HTGraphRequest -Uri 'directoryObjects/getByIds' -Method POST -Body @{ ids = $chunk })) {
                $name = if ($o.userPrincipalName) { "$($o.displayName) ($($o.userPrincipalName))" } elseif ($o.displayName) { $o.displayName } else { $o.id }
                $map[[string]$o.id] = $name
            }
        }
        catch { Write-Log -Message "Nazwy obiektów katalogu: $($_.Exception.Message)" -Type 'Warn' }
    }
    return $map
}

function Get-HTRoleDefinitionNames {
    # Szablony ról katalogu (id szablonu -> nazwa roli)
    $map = @{}
    foreach ($r in @(Invoke-HTGraphRequest -Uri 'roleManagement/directory/roleDefinitions?$select=id,displayName,templateId' -All)) {
        $map[[string]$r.id] = $r.displayName
        if ($r.templateId) { $map[[string]$r.templateId] = $r.displayName }
    }
    return $map
}

#region Sekrety i certyfikaty aplikacji
function ConvertTo-HTCredentialRows {
    # Wiersze poświadczeń jednej aplikacji (sekrety i certyfikaty); -Days: próg ostrzeżenia
    param ([Parameter(Mandatory)][object]$Object, [string]$Kind = 'Aplikacja', [int]$Days = 30, [switch]$IncludeAll, [datetime]$Now = (Get-Date))
    $creds = @(
        foreach ($p in @($Object.passwordCredentials)) { if ($p) { @{ Type = 'Sekret'; C = $p } } }
        foreach ($k in @($Object.keyCredentials)) { if ($k) { @{ Type = 'Certyfikat'; C = $k } } }
    )
    foreach ($entry in $creds) {
        $c = $entry.C
        $left = Get-HTDaysUntil -Date $c.endDateTime -Now $Now
        if (-not $IncludeAll -and $null -ne $left -and $left -gt $Days) { continue }
        $state = if ($null -eq $left) { 'Brak daty' } elseif ($left -lt 0) { 'Wygasło' } elseif ($left -le 7) { 'Wygasa wkrótce' } elseif ($left -le $Days) { 'Wygasa' } else { 'Ważne' }
        $usage = if ($entry.Type -eq 'Certyfikat') { [string]$c.usage } else { '' }
        [PSCustomObject]@{
            Aplikacja       = $Object.displayName
            Typ             = $Kind
            Poświadczenie   = $entry.Type
            Opis            = $c.displayName
            'Ważne od'      = $c.startDateTime
            'Wygasa'        = $c.endDateTime
            'Dni do końca'  = $left
            Stan            = $state
            Użycie          = $usage
            AppId           = $Object.appId
            Id              = $Object.id
            KeyId           = $c.keyId
            __kind          = $Kind
            __type          = $entry.Type
            __flag          = if ($null -ne $left -and $left -lt 0) { 'crit' } elseif ($null -ne $left -and $left -le 7) { 'crit' } elseif ($null -ne $left -and $left -le $Days) { 'warn' } else { '' }
        }
    }
}

function Get-HTAppCredentialExpiry {
    <#
        Sekrety i certyfikaty rejestracji aplikacji oraz aplikacji firmowych (np. certyfikaty SAML) wygasające w ciągu
        -Days dni (z wygasłymi). Uprawnienie Application.Read.All.
    #>
    param ([int]$Days = 30, [switch]$IncludeAll, [switch]$NoServicePrincipals)
    $apps = @(Invoke-HTGraphRequest -Uri 'applications?$select=id,appId,displayName,passwordCredentials,keyCredentials&$top=999' -All)
    foreach ($a in $apps) { ConvertTo-HTCredentialRows -Object $a -Kind 'Rejestracja aplikacji' -Days $Days -IncludeAll:$IncludeAll }
    if ($NoServicePrincipals) { return }
    $own = @{}
    foreach ($a in $apps) { $own[[string]$a.appId] = $true }
    $sps = @(Invoke-HTGraphRequest -Uri 'servicePrincipals?$select=id,appId,displayName,passwordCredentials,keyCredentials,servicePrincipalType&$top=999' -All)
    foreach ($sp in $sps) {
        # Poświadczenia własnych aplikacji są już w rejestracjach - tu tylko te przypisane do aplikacji firmowych
        if (@($sp.passwordCredentials).Count -eq 0 -and @($sp.keyCredentials).Count -eq 0) { continue }
        ConvertTo-HTCredentialRows -Object $sp -Kind $(if ($own.ContainsKey([string]$sp.appId)) { 'Aplikacja firmowa (własna)' } else { 'Aplikacja firmowa' }) -Days $Days -IncludeAll:$IncludeAll
    }
}

function Remove-HTAppPassword {
    # Usunięcie sekretu klienta (np. wygasłego) z rejestracji aplikacji lub aplikacji firmowej
    param ([Parameter(Mandatory)][string]$ObjectId, [Parameter(Mandatory)][string]$KeyId, [switch]$ServicePrincipal)
    $path = if ($ServicePrincipal) { 'servicePrincipals' } else { 'applications' }
    Invoke-HTGraphRequest -Uri "$path/$ObjectId/removePassword" -Method POST -Body @{ keyId = $KeyId } | Out-Null
}
#endregion

#region Dostęp warunkowy
function Format-HTCAList {
    # Opis listy identyfikatorów (z nazwami) w zasadzie dostępu warunkowego
    param ([AllowEmptyCollection()][object[]]$Ids = @(), [hashtable]$Names = @{})
    $labels = @{ All = 'wszyscy'; None = 'nikt'; GuestsOrExternalUsers = 'goście i użytkownicy zewnętrzni'; AllApps = 'wszystkie aplikacje'; Office365 = 'Office 365'; MicrosoftAdminPortals = 'portale administracyjne Microsoft' }
    return (@($Ids | Where-Object { $_ } | ForEach-Object { $k = [string]$_; if ($labels.ContainsKey($k)) { $labels[$k] } elseif ($Names.ContainsKey($k)) { $Names[$k] } else { $k } }) -join ', ')
}

function ConvertTo-HTCAPolicyRow {
    param ([Parameter(Mandatory)][object]$Policy, [hashtable]$Names = @{})
    $c = $Policy.conditions
    $u = $c.users
    $include = @()
    if (@($u.includeUsers | Where-Object { $_ }).Count) { $include += Format-HTCAList $u.includeUsers $Names }
    if (@($u.includeGroups | Where-Object { $_ }).Count) { $include += 'grupy: ' + (Format-HTCAList $u.includeGroups $Names) }
    if (@($u.includeRoles | Where-Object { $_ }).Count) { $include += 'role: ' + (Format-HTCAList $u.includeRoles $Names) }
    if ($u.includeGuestsOrExternalUsers) { $include += 'goście i użytkownicy zewnętrzni' }
    $exclude = @()
    if (@($u.excludeUsers | Where-Object { $_ }).Count) { $exclude += Format-HTCAList $u.excludeUsers $Names }
    if (@($u.excludeGroups | Where-Object { $_ }).Count) { $exclude += 'grupy: ' + (Format-HTCAList $u.excludeGroups $Names) }
    if (@($u.excludeRoles | Where-Object { $_ }).Count) { $exclude += 'role: ' + (Format-HTCAList $u.excludeRoles $Names) }
    if ($u.excludeGuestsOrExternalUsers) { $exclude += 'goście i użytkownicy zewnętrzni' }
    $apps = Format-HTCAList $c.applications.includeApplications $Names
    if (@($c.applications.includeUserActions | Where-Object { $_ }).Count) { $apps = 'działania: ' + (@($c.applications.includeUserActions) -join ', ') }
    $conditions = @()
    if (@($c.platforms.includePlatforms | Where-Object { $_ }).Count) { $conditions += 'platformy: ' + (@($c.platforms.includePlatforms) -join ', ') }
    if (@($c.locations.includeLocations | Where-Object { $_ }).Count) { $conditions += 'lokalizacje: ' + (@($c.locations.includeLocations) -join ', ') + $(if (@($c.locations.excludeLocations | Where-Object { $_ }).Count) { ' (bez: ' + (@($c.locations.excludeLocations) -join ', ') + ')' }) }
    if (@($c.clientAppTypes | Where-Object { $_ -and $_ -ne 'all' }).Count) { $conditions += 'klienci: ' + (@($c.clientAppTypes) -join ', ') }
    if (@($c.signInRiskLevels | Where-Object { $_ }).Count) { $conditions += 'ryzyko logowania: ' + (@($c.signInRiskLevels) -join ', ') }
    if (@($c.userRiskLevels | Where-Object { $_ }).Count) { $conditions += 'ryzyko użytkownika: ' + (@($c.userRiskLevels) -join ', ') }
    $g = $Policy.grantControls
    $grant = @(@($g.builtInControls | Where-Object { $_ }) | ForEach-Object {
            switch ([string]$_) { 'mfa' { 'MFA' } 'block' { 'BLOKADA' } 'compliantDevice' { 'zgodne urządzenie' } 'domainJoinedDevice' { 'urządzenie hybrydowe' } 'approvedApplication' { 'zatwierdzona aplikacja' } 'compliantApplication' { 'chroniona aplikacja' } 'passwordChange' { 'zmiana hasła' } default { [string]$_ } }
        })
    if ($g.authenticationStrength.displayName) { $grant += "siła uwierzytelniania: $($g.authenticationStrength.displayName)" }
    $grantText = $grant -join $(if ($g.operator -eq 'OR') { ' lub ' } else { ' i ' })
    $s = $Policy.sessionControls
    $session = @()
    if ($s.signInFrequency.isEnabled) { $session += "częstotliwość logowania: $($s.signInFrequency.value) $($s.signInFrequency.type)" }
    if ($s.persistentBrowser.isEnabled) { $session += "trwała sesja: $($s.persistentBrowser.mode)" }
    if ($s.applicationEnforcedRestrictions.isEnabled) { $session += 'ograniczenia aplikacji' }
    if ($s.cloudAppSecurity.isEnabled) { $session += 'Defender for Cloud Apps' }
    $state = switch ([string]$Policy.state) { 'enabled' { 'Włączona' } 'disabled' { 'Wyłączona' } 'enabledForReportingButNotEnforced' { 'Tylko raport' } default { [string]$Policy.state } }
    return [PSCustomObject]@{
        Zasada      = $Policy.displayName
        Stan        = $state
        Użytkownicy = ($include -join '; ')
        Wykluczeni  = ($exclude -join '; ')
        Aplikacje   = $apps
        Warunki     = ($conditions -join '; ')
        Kontrola    = $grantText
        Sesja       = ($session -join '; ')
        Zmieniono   = $(if ($Policy.modifiedDateTime) { $Policy.modifiedDateTime } else { $Policy.createdDateTime })
        Id          = $Policy.id
        __policy    = $Policy
        __flag      = if ($Policy.state -eq 'disabled') { 'muted' } elseif ($grant -contains 'BLOKADA') { 'warn' } else { '' }
    }
}

function Get-HTConditionalAccessPolicies {
    # Zasady dostępu warunkowego z nazwami użytkowników, grup i ról (Policy.Read.All)
    param ([switch]$Raw)
    $policies = @(Invoke-HTGraphRequest -Uri 'identity/conditionalAccess/policies' -All)
    if ($Raw) { return $policies }
    $ids = New-Object System.Collections.Generic.List[string]
    foreach ($p in $policies) {
        $u = $p.conditions.users
        foreach ($list in @($u.includeUsers, $u.excludeUsers, $u.includeGroups, $u.excludeGroups, $p.conditions.applications.includeApplications, $p.conditions.applications.excludeApplications)) { foreach ($id in @($list)) { if ($id) { $ids.Add([string]$id) } } }
    }
    $names = Resolve-HTDirectoryObjectNames -Ids $ids.ToArray()
    try { $roles = Get-HTRoleDefinitionNames; foreach ($k in $roles.Keys) { $names[$k] = $roles[$k] } } catch { Write-Log -Message "Nazwy ról: $($_.Exception.Message)" -Type 'Warn' }
    foreach ($p in @($policies | Sort-Object displayName)) { ConvertTo-HTCAPolicyRow -Policy $p -Names $names }
}

function Test-HTCAPolicyAppliesToUser {
    <#
        Uproszczona ocena, czy zasada obejmuje użytkownika (tylko warunek «Użytkownicy»: osoby, grupy, role, goście).
        Zwraca @{ Applies = $true/$false; Reason }. Pozostałe warunki (aplikacje, lokalizacje, platformy) - w kolumnie zasady.
    #>
    param (
        [Parameter(Mandatory)][object]$Policy,
        [Parameter(Mandatory)][string]$UserId,
        [AllowEmptyCollection()][string[]]$GroupIds = @(),
        [AllowEmptyCollection()][string[]]$RoleTemplateIds = @(),
        [bool]$IsGuest = $false
    )
    $u = $Policy.conditions.users
    $has = { param($list, [string[]]$values) foreach ($v in @($list)) { if ($values -contains [string]$v) { return [string]$v } }; return $null }
    $excludedBy = $null
    if (@($u.excludeUsers) -contains $UserId) { $excludedBy = 'wykluczony bezpośrednio' }
    elseif ($IsGuest -and (@($u.excludeUsers) -contains 'GuestsOrExternalUsers' -or $u.excludeGuestsOrExternalUsers)) { $excludedBy = 'wykluczeni goście' }
    elseif (& $has $u.excludeGroups $GroupIds) { $excludedBy = 'wykluczony przez grupę' }
    elseif (& $has $u.excludeRoles $RoleTemplateIds) { $excludedBy = 'wykluczony przez rolę' }
    $includedBy = $null
    if (@($u.includeUsers) -contains 'All') { $includedBy = 'wszyscy użytkownicy' }
    elseif (@($u.includeUsers) -contains $UserId) { $includedBy = 'wskazany bezpośrednio' }
    elseif ($IsGuest -and (@($u.includeUsers) -contains 'GuestsOrExternalUsers' -or $u.includeGuestsOrExternalUsers)) { $includedBy = 'goście' }
    elseif (& $has $u.includeGroups $GroupIds) { $includedBy = 'członek grupy' }
    elseif (& $has $u.includeRoles $RoleTemplateIds) { $includedBy = 'rola administracyjna' }
    if (-not $includedBy) { return @{ Applies = $false; Reason = 'nie obejmuje' } }
    if ($excludedBy) { return @{ Applies = $false; Reason = $excludedBy } }
    return @{ Applies = $true; Reason = $includedBy }
}

function Get-HTUserMembershipIds {
    # Grupy (przechodnio) i szablony ról katalogu użytkownika - do oceny zasad dostępu warunkowego
    param ([Parameter(Mandatory)][string]$UserId)
    $groups = New-Object System.Collections.Generic.List[string]
    $roles = New-Object System.Collections.Generic.List[string]
    foreach ($o in @(Invoke-HTGraphRequest -Uri "users/$UserId/transitiveMemberOf?`$select=id,roleTemplateId&`$top=999" -All)) {
        $type = [string]$o.'@odata.type'
        if ($type -match 'directoryRole') { if ($o.roleTemplateId) { $roles.Add([string]$o.roleTemplateId) } }
        else { $groups.Add([string]$o.id) }
    }
    return @{ Groups = $groups.ToArray(); Roles = $roles.ToArray() }
}

function Get-HTConditionalAccessForUser {
    # Zasady dostępu warunkowego, które obejmują użytkownika (ocena warunku «Użytkownicy»)
    param ([Parameter(Mandatory)][string]$UserId, [switch]$IncludeNotApplied)
    $user = Invoke-HTGraphRequest -Uri "users/$UserId`?`$select=id,userType"
    $m = Get-HTUserMembershipIds -UserId $UserId
    foreach ($row in @(Get-HTConditionalAccessPolicies)) {
        $r = Test-HTCAPolicyAppliesToUser -Policy $row.__policy -UserId $UserId -GroupIds $m.Groups -RoleTemplateIds $m.Roles -IsGuest ($user.userType -eq 'Guest')
        if (-not $r.Applies -and -not $IncludeNotApplied) { continue }
        $out = [ordered]@{ Zasada = $row.Zasada; Obejmuje = $(if ($r.Applies) { 'Tak' } else { 'Nie' }); Powód = $r.Reason; Stan = $row.Stan; Kontrola = $row.Kontrola; Aplikacje = $row.Aplikacje; Warunki = $row.Warunki; Sesja = $row.Sesja; Id = $row.Id }
        $out.__flag = if (-not $r.Applies) { 'muted' } elseif ($row.Stan -ne 'Włączona') { 'muted' } elseif ($row.Kontrola -match 'BLOKADA') { 'warn' } else { '' }
        [PSCustomObject]$out
    }
}
#endregion

#region Ryzykowni użytkownicy (Entra ID Protection, licencja P2)
function Get-HTRiskyUsers {
    param ([switch]$IncludeRemediated)
    $filter = if ($IncludeRemediated) { '' } else { "&`$filter=riskState eq 'atRisk' or riskState eq 'confirmedCompromised'" }
    $items = @(Invoke-HTGraphRequest -Uri "identityProtection/riskyUsers?`$top=500$filter" -All)
    foreach ($r in @($items | Sort-Object riskLastUpdatedDateTime -Descending)) {
        [PSCustomObject]@{
            Użytkownik         = $r.userDisplayName
            UPN                = $r.userPrincipalName
            'Poziom ryzyka'    = $r.riskLevel
            Stan               = $r.riskState
            Szczegóły          = $r.riskDetail
            Zmieniono          = $r.riskLastUpdatedDateTime
            Usunięty           = [bool]$r.isDeleted
            Id                 = $r.id
            __flag             = if ($r.riskState -eq 'confirmedCompromised' -or $r.riskLevel -eq 'high') { 'crit' } elseif ($r.riskLevel -eq 'medium') { 'warn' } elseif ($r.riskState -in 'remediated', 'dismissed') { 'muted' } else { '' }
        }
    }
}

function Get-HTRiskDetections {
    param ([string]$UserId = '', [int]$Days = 30)
    $since = (Get-Date).ToUniversalTime().AddDays(-$Days).ToString('yyyy-MM-ddTHH:mm:ssZ')
    $filter = "detectedDateTime ge $since"
    if ($UserId) { $filter += " and userId eq '$UserId'" }
    foreach ($d in @(Invoke-HTGraphRequest -Uri "identityProtection/riskDetections?`$filter=$([uri]::EscapeDataString($filter))&`$top=500" -All | Sort-Object detectedDateTime -Descending)) {
        [PSCustomObject]@{
            Wykryto        = $d.detectedDateTime
            Użytkownik     = $d.userPrincipalName
            Zdarzenie      = $d.riskEventType
            Poziom         = $d.riskLevel
            Stan           = $d.riskState
            'Adres IP'     = $d.ipAddress
            Lokalizacja    = (@($d.location.city, $d.location.countryOrRegion) | Where-Object { $_ }) -join ', '
            Źródło         = $d.source
            Aktywność      = $d.activity
            Id             = $d.id
            __flag         = if ($d.riskLevel -eq 'high') { 'crit' } elseif ($d.riskLevel -eq 'medium') { 'warn' } else { '' }
        }
    }
}

function Set-HTRiskyUserState {
    # Potwierdzenie przejęcia konta (ryzyko wysokie) albo odrzucenie ryzyka; IdentityRiskyUser.ReadWrite.All
    param ([Parameter(Mandatory)][string[]]$UserIds, [Parameter(Mandatory)][ValidateSet('ConfirmCompromised', 'Dismiss')][string]$Action)
    $path = if ($Action -eq 'ConfirmCompromised') { 'confirmCompromised' } else { 'dismiss' }
    Invoke-HTGraphRequest -Uri "identityProtection/riskyUsers/$path" -Method POST -Body @{ userIds = @($UserIds) } | Out-Null
}
#endregion

#region Dziennik inspekcji Entra ID
function ConvertTo-HTDirectoryAuditRow {
    param ([Parameter(Mandatory)][object]$Audit)
    $by = $Audit.initiatedBy
    $actor = if ($by.user.userPrincipalName) { $by.user.userPrincipalName } elseif ($by.app.displayName) { "aplikacja: $($by.app.displayName)" } else { '' }
    $targets = @($Audit.targetResources | ForEach-Object { if ($_.userPrincipalName) { $_.userPrincipalName } elseif ($_.displayName) { $_.displayName } else { $_.id } })
    $changes = @(foreach ($t in @($Audit.targetResources)) {
            foreach ($p in @($t.modifiedProperties | Select-Object -First 6)) {
                if (-not $p.displayName -or $p.displayName -match '^Included Updated Properties$') { continue }
                $old = ([string]$p.oldValue).Trim('"[]')
                $new = ([string]$p.newValue).Trim('"[]')
                if ($old.Length -gt 80) { $old = $old.Substring(0, 80) + '…' }
                if ($new.Length -gt 80) { $new = $new.Substring(0, 80) + '…' }
                "$($p.displayName): $old → $new"
            }
        })
    return [PSCustomObject]@{
        Czas       = $Audit.activityDateTime
        Kategoria  = $Audit.category
        Działanie  = $Audit.activityDisplayName
        Wynik      = $Audit.result
        Wykonał    = $actor
        Cel        = ($targets -join ', ')
        Zmiany     = ($changes -join '; ')
        Usługa     = $Audit.loggedByService
        Powód      = $Audit.resultReason
        Id         = $Audit.id
        __flag     = if ($Audit.result -ne 'success') { 'warn' } else { '' }
    }
}

function Get-HTDirectoryAudits {
    # Dziennik inspekcji Entra ID z ostatnich -Days dni; -Actor: UPN wykonującego, -Target: fragment UPN/nazwy celu
    param ([int]$Days = 7, [string]$Actor = '', [string]$Target = '', [string]$Category = '', [int]$Max = 2000)
    $since = (Get-Date).ToUniversalTime().AddDays(-$Days).ToString('yyyy-MM-ddTHH:mm:ssZ')
    $filter = "activityDateTime ge $since"
    if ($Actor) { $filter += " and initiatedBy/user/userPrincipalName eq '$($Actor.Replace("'", "''"))'" }
    if ($Category) { $filter += " and category eq '$($Category.Replace("'", "''"))'" }
    $uri = "auditLogs/directoryAudits?`$filter=$([uri]::EscapeDataString($filter))&`$top=500"
    $count = 0
    $response = Invoke-MgGraphRequest -Uri (Resolve-HTGraphUri -Uri $uri) -Method GET -OutputType PSObject -ErrorAction Stop
    while ($response) {
        foreach ($a in @($response.value)) {
            if (-not $a) { continue }
            $row = ConvertTo-HTDirectoryAuditRow -Audit $a
            if ($Target -and "$($row.Cel)".IndexOf($Target, [StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
            $row
            $count++
        }
        if ($count -ge $Max -or -not $response.'@odata.nextLink') { break }
        $response = Invoke-MgGraphRequest -Uri $response.'@odata.nextLink' -Method GET -OutputType PSObject -ErrorAction Stop
    }
}
#endregion

#region Zgody aplikacji (OAuth2)
$script:RiskyScopes = @('Mail.Read', 'Mail.ReadWrite', 'Mail.Send', 'Files.Read.All', 'Files.ReadWrite.All', 'Sites.Read.All', 'Sites.ReadWrite.All', 'Directory.ReadWrite.All',
    'User.ReadWrite.All', 'Contacts.Read', 'Calendars.ReadWrite', 'MailboxSettings.ReadWrite', 'Notes.ReadWrite.All', 'full_access_as_user', 'EWS.AccessAsUser.All', 'Directory.AccessAsUser.All')

function Get-HTOAuthGrants {
    <#
        Zgody delegowane aplikacji: -UserId - zgody udzielone przez użytkownika (i zgody administratora dla wszystkich),
        bez -UserId - wszystkie zgody w tenancie. Wyróżnione - szerokie uprawnienia (poczta, pliki, katalog).
    #>
    param ([string]$UserId = '', [switch]$OnlyRisky)
    $uri = if ($UserId) { "oauth2PermissionGrants?`$filter=principalId eq '$UserId' or consentType eq 'AllPrincipals'&`$top=999" } else { 'oauth2PermissionGrants?$top=999' }
    $grants = @()
    try { $grants = @(Invoke-HTGraphRequest -Uri $uri -All) }
    catch {
        # Część tenantów nie obsługuje filtra z «or» - zgody użytkownika i administratora osobno
        if (-not $UserId) { throw }
        $grants = @(Invoke-HTGraphRequest -Uri "oauth2PermissionGrants?`$filter=principalId eq '$UserId'" -All) + @(Invoke-HTGraphRequest -Uri "oauth2PermissionGrants?`$filter=consentType eq 'AllPrincipals'" -All)
    }
    $spIds = @($grants | ForEach-Object { [string]$_.clientId } | Select-Object -Unique)
    $sps = @{}
    $batch = Invoke-HTGraphBatch -Requests @($spIds | ForEach-Object { @{ Id = $_; Url = "servicePrincipals/$_`?`$select=id,appId,displayName,publisherName,verifiedPublisher,appOwnerOrganizationId" } })
    foreach ($k in $batch.Keys) { if ($batch[$k].Status -lt 300) { $sps[$k] = $batch[$k].Body } }
    $principals = if (-not $UserId) { Resolve-HTDirectoryObjectNames -Ids @($grants | Where-Object { $_.principalId } | ForEach-Object { [string]$_.principalId }) } else { @{} }
    foreach ($g in $grants) {
        $sp = $sps[[string]$g.clientId]
        $scopes = @("$($g.scope)".Trim() -split '\s+' | Where-Object { $_ })
        $risky = @($scopes | Where-Object { $script:RiskyScopes -contains $_ })
        if ($OnlyRisky -and -not $risky.Count) { continue }
        $publisher = if ($sp.verifiedPublisher.displayName) { "$($sp.verifiedPublisher.displayName) (zweryfikowany)" } elseif ($sp.publisherName) { $sp.publisherName } else { '' }
        [PSCustomObject]@{
            Aplikacja           = $(if ($sp.displayName) { $sp.displayName } else { $g.clientId })
            Wydawca             = $publisher
            Zgoda               = $(if ($g.consentType -eq 'AllPrincipals') { 'Administrator (wszyscy)' } else { 'Użytkownik' })
            Użytkownik          = $(if ($g.principalId) { if ($principals.ContainsKey([string]$g.principalId)) { $principals[[string]$g.principalId] } else { $g.principalId } } else { '' })
            Uprawnienia         = ($scopes -join ' ')
            'Szerokie uprawnienia' = ($risky -join ' ')
            AppId               = $sp.appId
            Id                  = $g.id
            __flag              = if ($risky.Count -and $g.consentType -ne 'AllPrincipals' -and -not $sp.verifiedPublisher.displayName) { 'crit' } elseif ($risky.Count) { 'warn' } else { '' }
        }
    }
}

function Remove-HTOAuthGrant {
    # Cofnięcie zgody delegowanej (DelegatedPermissionGrant.ReadWrite.All)
    param ([Parameter(Mandatory)][string]$GrantId)
    Invoke-HTGraphRequest -Uri "oauth2PermissionGrants/$GrantId" -Method DELETE | Out-Null
}
#endregion

#region Role uprzywilejowane (PIM)
function Get-HTPrivilegedRoleAssignments {
    # Przypisania ról katalogu: aktywne (stałe i czasowe) oraz uprawnione w PIM (licencja Entra ID P2)
    param ([switch]$NoEligible)
    $rows = New-Object System.Collections.Generic.List[object]
    $active = @(Invoke-HTGraphRequest -Uri 'roleManagement/directory/roleAssignmentScheduleInstances?$expand=principal,roleDefinition&$top=999' -All)
    foreach ($a in $active) {
        $rows.Add([PSCustomObject]@{
                Rola         = $a.roleDefinition.displayName
                Członek      = $a.principal.displayName
                UPN          = $a.principal.userPrincipalName
                'Typ członka' = ("$($a.principal.'@odata.type')" -replace '#microsoft.graph.', '')
                Przypisanie  = 'Aktywne'
                Czas         = $(if ($a.endDateTime) { 'czasowe' } else { 'stałe' })
                Od           = $a.startDateTime
                Do           = $a.endDateTime
                Sposób       = $(if ($a.assignmentType -eq 'Activated') { 'aktywowane z PIM' } else { 'przypisane' })
                Zakres       = $a.directoryScopeId
                Id           = $a.principalId
                __flag       = if (-not $a.endDateTime -and $a.roleDefinition.displayName -in @('Global Administrator', 'Privileged Role Administrator')) { 'warn' } else { '' }
            })
    }
    if (-not $NoEligible) {
        try {
            foreach ($e in @(Invoke-HTGraphRequest -Uri 'roleManagement/directory/roleEligibilitySchedules?$expand=principal,roleDefinition&$top=999' -All)) {
                $rows.Add([PSCustomObject]@{
                        Rola         = $e.roleDefinition.displayName
                        Członek      = $e.principal.displayName
                        UPN          = $e.principal.userPrincipalName
                        'Typ członka' = ("$($e.principal.'@odata.type')" -replace '#microsoft.graph.', '')
                        Przypisanie  = 'Uprawnione (PIM)'
                        Czas         = $(if ($e.scheduleInfo.expiration.endDateTime) { 'czasowe' } else { 'stałe' })
                        Od           = $e.scheduleInfo.startDateTime
                        Do           = $e.scheduleInfo.expiration.endDateTime
                        Sposób       = 'wymaga aktywacji'
                        Zakres       = $e.directoryScopeId
                        Id           = $e.principalId
                        __flag       = ''
                    })
            }
        }
        catch { Write-Log -Message "Role uprawnione PIM niedostępne (licencja Entra ID P2): $($_.Exception.Message)" -Type 'Warn' }
    }
    return @($rows | Sort-Object Rola, Członek)
}
#endregion

#region Administratorzy: MFA i wiek hasła
function ConvertTo-HTAdminSecurityRow {
    param ([Parameter(Mandatory)][object]$User, [string[]]$Roles = @(), $Registration = $null, [int]$PasswordDays = 365, [datetime]$Now = (Get-Date))
    $pwdDays = $null
    if ($User.lastPasswordChangeDateTime) { $pwdDays = [int][Math]::Floor(($Now - [datetime]$User.lastPasswordChangeDateTime).TotalDays) }
    $mfa = if ($null -eq $Registration) { $null } else { [bool]$Registration.isMfaRegistered }
    $issues = @()
    if ($mfa -eq $false) { $issues += 'brak MFA' }
    if ($null -ne $pwdDays -and $pwdDays -gt $PasswordDays) { $issues += "hasło sprzed $pwdDays dni" }
    if ($User.onPremisesSyncEnabled) { $issues += 'konto synchronizowane z AD (zalecane konto tylko w chmurze)' }
    if (-not $User.accountEnabled) { $issues += 'konto zablokowane' }
    return [PSCustomObject]@{
        Nazwa               = $User.displayName
        UPN                 = $User.userPrincipalName
        Role                = (@($Roles | Select-Object -Unique) -join ', ')
        'MFA zarejestrowane' = $(if ($null -eq $mfa) { 'brak danych' } elseif ($mfa) { 'Tak' } else { 'Nie' })
        Metody              = $(if ($Registration) { @($Registration.methodsRegistered) -join ', ' } else { '' })
        'Zmiana hasła'      = $User.lastPasswordChangeDateTime
        'Dni od zmiany hasła' = $pwdDays
        'Ostatnie logowanie' = $(if ($User.signInActivity) { $User.signInActivity.lastSignInDateTime } else { $null })
        Włączone            = [bool]$User.accountEnabled
        Problemy            = ($issues -join '; ')
        Id                  = $User.id
        __flag              = if ($mfa -eq $false) { 'crit' } elseif ($issues.Count) { 'warn' } else { '' }
    }
}

function Get-HTAdminSecurityReport {
    # Członkowie ról administracyjnych (aktywnych i uprawnionych PIM): MFA, wiek hasła, synchronizacja z AD
    param ([int]$PasswordDays = 365)
    $members = @{}
    foreach ($a in @(Get-HTPrivilegedRoleAssignments)) {
        if ($a.'Typ członka' -ne 'user' -or -not $a.Id) { continue }
        if (-not $members.ContainsKey($a.Id)) { $members[$a.Id] = New-Object System.Collections.Generic.List[string] }
        $members[$a.Id].Add($(if ($a.Przypisanie -like 'Uprawnione*') { "$($a.Rola) (PIM)" } else { $a.Rola }))
    }
    $registrations = @{}
    try { foreach ($r in @(Invoke-HTGraphRequest -Uri 'reports/authenticationMethods/userRegistrationDetails?$top=999' -All)) { $registrations[[string]$r.id] = $r } }
    catch { Write-Log -Message "Rejestracja MFA niedostępna (Entra ID P1, AuditLog.Read.All): $($_.Exception.Message)" -Type 'Warn' }
    $select = 'id,displayName,userPrincipalName,accountEnabled,lastPasswordChangeDateTime,onPremisesSyncEnabled,signInActivity'
    $batch = Invoke-HTGraphBatch -Requests @($members.Keys | ForEach-Object { @{ Id = $_; Url = "users/$_`?`$select=$select" } })
    foreach ($id in $members.Keys) {
        $b = $batch[$id]
        if (-not $b -or $b.Status -ge 300) { continue }
        ConvertTo-HTAdminSecurityRow -User $b.Body -Roles $members[$id].ToArray() -Registration $registrations[$id] -PasswordDays $PasswordDays
    }
}
#endregion

#region Diagnoza logowania
$script:SignInErrorHints = @{
    0       = 'Logowanie udane.'
    16000   = 'Wybór konta - użytkownik ma kilka zalogowanych kont (zwykle bez znaczenia).'
    50034   = 'Konto nie istnieje w tym tenancie - sprawdź UPN (literówka, zmiana nazwiska, inna domena).'
    50053   = 'Konto zablokowane (Smart Lockout) po zbyt wielu nieudanych próbach albo logowanie z adresu IP uznanego za złośliwy. Odczekaj lub zresetuj hasło.'
    50055   = 'Hasło wygasło - użytkownik musi je zmienić (albo zresetuj hasło).'
    50056   = 'Brak hasła w katalogu (np. konto bez hasła, nieudana synchronizacja skrótu hasła).'
    50057   = 'Konto jest zablokowane (logowanie wyłączone przez administratora).'
    50058   = 'Brak informacji o sesji - zwykle logowanie w tle bez pliku cookie (bez znaczenia).'
    50059   = 'Nie znaleziono tenantu dla podanej domeny.'
    50072   = 'Użytkownik musi zarejestrować MFA (proof-up).'
    50074   = 'Wymagane MFA - użytkownik nie dokończył drugiego etapu.'
    50076   = 'Wymagane MFA (zmiana lokalizacji lub zasada dostępu) - użytkownik musi potwierdzić logowanie.'
    50079   = 'Wymagana rejestracja metod MFA.'
    50097   = 'Wymagane uwierzytelnienie urządzenia (urządzenie niezarejestrowane w Entra ID).'
    50105   = 'Użytkownik nie jest przypisany do aplikacji (wymagane przypisanie w aplikacji firmowej).'
    50126   = 'Nieprawidłowy login lub hasło.'
    50132   = 'Sesja unieważniona (zmiana lub reset hasła) - zaloguj się ponownie.'
    50133   = 'Sesja nieważna po zmianie hasła.'
    50140   = 'Pytanie «Nie wylogowuj mnie» (przerwanie - bez znaczenia).'
    50158   = 'Wymagane zewnętrzne zabezpieczenie (np. dostawca MFA spoza Microsoft).'
    50173   = 'Token unieważniony (zmiana hasła lub unieważnienie sesji) - zaloguj się ponownie.'
    53000   = 'Dostęp warunkowy wymaga urządzenia zgodnego (Intune) - urządzenie niezgodne albo niezarządzane.'
    53001   = 'Dostęp warunkowy wymaga urządzenia dołączonego do domeny (hybrydowe Entra ID).'
    53002   = 'Aplikacja niezatwierdzona - wymagana zatwierdzona aplikacja kliencka.'
    53003   = 'Logowanie zablokowane przez zasadę dostępu warunkowego (zob. szczegóły logowania - «Dostęp warunkowy»).'
    53004   = 'Wymagana rejestracja MFA, ale zasada blokuje rejestrację z tej lokalizacji.'
    53011   = 'Zablokowane z powodu ryzyka użytkownika (Identity Protection).'
    65001   = 'Brak zgody na aplikację - wymagana zgoda użytkownika lub administratora.'
    70044   = 'Sesja wygasła - zaloguj się ponownie.'
    81010   = 'Bezproblemowe logowanie jednokrotne (Seamless SSO) nie powiodło się - zwykle zegar lub bilet Kerberos.'
    90072   = 'Konto z innego tenantu nie jest gościem w tym tenancie.'
    500121  = 'Uwierzytelnianie MFA nie powiodło się (odrzucone, przekroczony czas albo zła odpowiedź).'
    530032  = 'Zablokowane przez zasady zabezpieczeń (np. domyślne ustawienia zabezpieczeń).'
    700016  = 'Aplikacja nie istnieje w tym tenancie (zły Client ID albo brak zgody administratora).'
    7000218 = 'Wymagany sekret lub certyfikat klienta (aplikacja nie jest klientem publicznym).'
}

function Get-HTSignInErrorHint {
    param ([int]$Code)
    if ($script:SignInErrorHints.ContainsKey($Code)) { return $script:SignInErrorHints[$Code] }
    return "Kod błędu $Code - opis: https://login.microsoftonline.com/error?code=$Code"
}

function ConvertTo-HTLoginDiagnosis {
    <#
        Wiersze diagnozy problemów z logowaniem (Sprawdzenie, Wynik, Stan, Zalecenie) z danych użytkownika, ostatnich
        logowań, ryzyka, metod MFA i zasad dostępu warunkowego. Funkcja czysta - dane pobiera Get-HTLoginDiagnosis.
    #>
    param (
        [Parameter(Mandatory)][object]$User,
        [AllowEmptyCollection()][object[]]$SignIns = @(),
        $Risk = $null,
        [AllowEmptyCollection()][object[]]$Methods = @(),
        [AllowEmptyCollection()][object[]]$Policies = @(),
        [datetime]$Now = (Get-Date)
    )
    $row = { param($Check, $Result, $State, $Advice = '') [PSCustomObject]@{ Sprawdzenie = $Check; Wynik = $Result; Stan = $State; Zalecenie = $Advice; __flag = $(switch ($State) { 'Problem' { 'crit' } 'Uwaga' { 'warn' } 'Informacja' { 'muted' } default { '' } }) } }
    if (-not $User.accountEnabled) { & $row 'Konto' 'Logowanie zablokowane' 'Problem' 'Odblokuj konto (Blokada i sesje > Odblokuj), jeśli blokada nie jest zamierzona.' }
    else { & $row 'Konto' 'Włączone' 'OK' }
    if ($User.onPremisesSyncEnabled) {
        $sync = Get-HTDaysSince $User.onPremisesLastSyncDateTime
        & $row 'Synchronizacja z AD' "Konto synchronizowane, ostatnia synchronizacja: $($User.onPremisesLastSyncDateTime)" $(if ($null -ne $sync -and $sync -gt 1) { 'Uwaga' } else { 'OK' }) 'Hasło i blokadę zmieniaj w lokalnym AD; sprawdź działanie Entra Connect, gdy synchronizacja jest stara.'
    }
    if ($User.lastPasswordChangeDateTime) {
        $days = [int][Math]::Floor(($Now - [datetime]$User.lastPasswordChangeDateTime).TotalDays)
        & $row 'Hasło' "Zmienione $days dni temu ($($User.lastPasswordChangeDateTime))" $(if ($days -le 1) { 'Informacja' } else { 'OK' }) $(if ($days -le 1) { 'Niedawna zmiana hasła unieważnia sesje - urządzenia mobilne i Outlook poproszą o nowe hasło.' } else { '' })
    }
    if (-not @($User.assignedLicenses | Where-Object { $_ }).Count -and $User.userType -ne 'Guest') { & $row 'Licencje' 'Brak licencji' 'Uwaga' 'Bez licencji logowanie działa, ale aplikacje (Outlook, Teams) nie będą dostępne.' }
    $mfaMethods = @($Methods | Where-Object { $_.Type -notmatch 'Hasło|password' })
    if ($Methods.Count) { & $row 'Metody MFA' $(if ($mfaMethods.Count) { (@($mfaMethods | ForEach-Object { $_.Type }) -join ', ') } else { 'Tylko hasło' }) $(if ($mfaMethods.Count) { 'OK' } else { 'Uwaga' }) $(if (-not $mfaMethods.Count) { 'Użytkownik nie ma metod MFA - przy wymaganym MFA rejestracja (proof-up) przy logowaniu albo Tymczasowy kod dostępu (TAP).' } else { '' }) }
    if ($Risk) {
        $riskState = [string]$Risk.riskState
        & $row 'Ryzyko (Identity Protection)' "$($Risk.riskLevel) / $riskState" $(if ($riskState -in 'atRisk', 'confirmedCompromised') { 'Problem' } else { 'OK' }) $(if ($riskState -in 'atRisk', 'confirmedCompromised') { 'Zasady ryzyka mogą blokować logowanie - po weryfikacji odrzuć ryzyko lub wymuś zmianę hasła (Bezpieczeństwo > Ryzykowni użytkownicy).' } else { '' })
    }
    $applied = @($Policies | Where-Object { $_.Obejmuje -eq 'Tak' -and $_.Stan -eq 'Włączona' })
    if ($Policies.Count) {
        $blocking = @($applied | Where-Object { $_.Kontrola -match 'BLOKADA' })
        & $row 'Dostęp warunkowy' "Obejmuje zasad: $($applied.Count)$(if ($blocking.Count) { ", blokujących: $($blocking.Count) ($(@($blocking | ForEach-Object { $_.Zasada }) -join ', '))" })" $(if ($blocking.Count) { 'Uwaga' } else { 'OK' }) $(if ($blocking.Count) { 'Zasady blokujące działają dla określonych warunków (lokalizacja, platforma, aplikacja) - porównaj z nieudanym logowaniem.' } else { '' })
    }
    $sorted = @($SignIns | Sort-Object { $_.createdDateTime } -Descending)
    if ($sorted.Count -eq 0) { & $row 'Logowania' 'Brak logowań w okresie (albo brak licencji Entra ID P1 dla dziennika)' 'Informacja' 'Jeśli użytkownik próbuje się logować - sprawdź UPN i domenę (błąd 50034).' }
    else {
        $failed = @($sorted | Where-Object { [int]$_.status.errorCode -ne 0 })
        $last = $sorted[0]
        $lastOk = @($sorted | Where-Object { [int]$_.status.errorCode -eq 0 })[0]
        & $row 'Ostatnie logowanie' "$($last.createdDateTime) - $($last.appDisplayName), $($last.ipAddress) ($((@($last.location.city, $last.location.countryOrRegion) | Where-Object { $_ }) -join ', '))" $(if ([int]$last.status.errorCode -eq 0) { 'OK' } else { 'Problem' }) $(if ([int]$last.status.errorCode -ne 0) { Get-HTSignInErrorHint ([int]$last.status.errorCode) } else { '' })
        if ($lastOk) { & $row 'Ostatnie udane logowanie' "$($lastOk.createdDateTime) - $($lastOk.appDisplayName)" 'OK' }
        foreach ($g in @($failed | Group-Object { [int]$_.status.errorCode } | Sort-Object Count -Descending | Select-Object -First 6)) {
            $code = [int]$g.Name
            $first = $g.Group[0]
            $state = if ($code -in 50140, 50058, 16000) { 'Informacja' } else { 'Problem' }
            & $row "Błąd $code (x$($g.Count))" "$($first.status.failureReason) - ostatnio $($first.createdDateTime), $($first.appDisplayName), $($first.ipAddress)" $state (Get-HTSignInErrorHint $code)
        }
        $ips = @($sorted | Where-Object { [int]$_.status.errorCode -eq 50126 -or [int]$_.status.errorCode -eq 50053 } | ForEach-Object { $_.ipAddress } | Select-Object -Unique)
        if ($ips.Count -ge 5) { & $row 'Wiele adresów IP z błędnym hasłem' "$($ips.Count) adresów: $(@($ips | Select-Object -First 8) -join ', ')" 'Problem' 'Możliwy atak (password spray) - rozważ reset hasła, unieważnienie sesji i sprawdź ryzyko konta.' }
    }
}

function Get-HTLoginDiagnosis {
    # Zbiera dane o koncie i logowaniach z ostatnich -Days dni i zwraca wiersze diagnozy
    param ([Parameter(Mandatory)][string]$UserId, [int]$Days = 7)
    $select = 'id,displayName,userPrincipalName,accountEnabled,userType,assignedLicenses,lastPasswordChangeDateTime,onPremisesSyncEnabled,onPremisesLastSyncDateTime'
    $user = Invoke-HTGraphRequest -Uri "users/$UserId`?`$select=$select"
    $since = (Get-Date).ToUniversalTime().AddDays(-$Days).ToString('yyyy-MM-ddTHH:mm:ssZ')
    $signIns = @()
    try { $signIns = @(Invoke-HTGraphRequest -Uri "auditLogs/signIns?`$filter=$([uri]::EscapeDataString("userId eq '$UserId' and createdDateTime ge $since"))&`$top=200") }
    catch { Write-Log -Message "Diagnoza logowania - dziennik logowań: $($_.Exception.Message)" -Type 'Warn' }
    $risk = $null
    try { $risk = Invoke-HTGraphRequest -Uri "identityProtection/riskyUsers/$UserId" } catch { $risk = $null }
    $methods = @()
    try { $methods = @(Get-HTM365AuthMethods -Id $UserId) } catch { Write-Log -Message "Diagnoza logowania - metody MFA: $($_.Exception.Message)" -Type 'Warn' }
    $policies = @()
    try { $policies = @(Get-HTConditionalAccessForUser -UserId $UserId -IncludeNotApplied) } catch { Write-Log -Message "Diagnoza logowania - dostęp warunkowy (Policy.Read.All): $($_.Exception.Message)" -Type 'Warn' }
    ConvertTo-HTLoginDiagnosis -User $user -SignIns $signIns -Risk $risk -Methods $methods -Policies $policies
}
#endregion

#region Porównanie użytkowników
function Compare-HTUserSets {
    <#
        Porównanie dwóch użytkowników: -A / -B to słowniki kategoria -> lista nazw (np. Grupy, Licencje, Role).
        Zwraca wiersze Kategoria, Nazwa, <NameA>, <NameB>, Różnica; -OnlyDifferences pomija wspólne.
    #>
    param ([Parameter(Mandatory)][System.Collections.IDictionary]$A, [Parameter(Mandatory)][System.Collections.IDictionary]$B, [string]$NameA = 'Użytkownik A', [string]$NameB = 'Użytkownik B', [switch]$OnlyDifferences)
    $categories = @(@($A.Keys) + @($B.Keys) | Select-Object -Unique)
    foreach ($cat in $categories) {
        $listA = @($A[$cat] | Where-Object { $_ } | ForEach-Object { [string]$_ })
        $listB = @($B[$cat] | Where-Object { $_ } | ForEach-Object { [string]$_ })
        foreach ($name in @(@($listA) + @($listB) | Select-Object -Unique | Sort-Object)) {
            $inA = $listA -contains $name
            $inB = $listB -contains $name
            if ($OnlyDifferences -and $inA -and $inB) { continue }
            $diff = if ($inA -and $inB) { 'wspólne' } elseif ($inA) { "tylko $NameA" } else { "tylko $NameB" }
            $o = [ordered]@{ Kategoria = [string]$cat; Nazwa = $name }
            $o[$NameA] = $inA
            $o[$NameB] = $inB
            $o['Różnica'] = $diff
            $o['__inA'] = $inA
            $o['__inB'] = $inB
            $o['__flag'] = if ($inA -and $inB) { '' } else { 'warn' }
            [PSCustomObject]$o
        }
    }
}

function Get-HTUserAccessSummary {
    # Grupy, licencje, role i aplikacje (przypisania ról aplikacji) użytkownika - do porównania
    param ([Parameter(Mandatory)][string]$UserId)
    $groups = @(Get-HTM365UserGroups -Id $UserId)
    $roles = @()
    try { $roles = @(Invoke-HTGraphRequest -Uri "users/$UserId/memberOf/microsoft.graph.directoryRole?`$select=displayName" -All | ForEach-Object { $_.displayName }) } catch { $roles = @() }
    $skuNames = Get-HTSkuNameMap
    $user = Invoke-HTGraphRequest -Uri "users/$UserId`?`$select=assignedLicenses"
    $apps = @()
    try { $apps = @(Invoke-HTGraphRequest -Uri "users/$UserId/appRoleAssignments?`$top=999" -All | ForEach-Object { $_.resourceDisplayName } | Select-Object -Unique) } catch { $apps = @() }
    return [ordered]@{
        Grupy     = @($groups | ForEach-Object { $_.DisplayName })
        Role      = $roles
        Licencje  = @($user.assignedLicenses | ForEach-Object { Get-HTSkuFriendlyName ($skuNames["$($_.skuId)"] ?? "$($_.skuId)") })
        Aplikacje = $apps
        __groups  = $groups
    }
}
#endregion

#region Microsoft Defender XDR: alerty i incydenty (Graph security)
function Get-HTDefenderAlerts {
    param ([int]$Days = 7, [switch]$IncludeResolved, [int]$Max = 500)
    $since = (Get-Date).ToUniversalTime().AddDays(-$Days).ToString('yyyy-MM-ddTHH:mm:ssZ')
    $filter = "createdDateTime ge $since"
    if (-not $IncludeResolved) { $filter += " and status ne 'resolved'" }
    $items = @(Invoke-HTGraphRequest -Uri "security/alerts_v2?`$filter=$([uri]::EscapeDataString($filter))&`$top=$([Math]::Min(2000, $Max))")
    foreach ($a in @($items | Sort-Object createdDateTime -Descending)) {
        $devices = @($a.evidence | Where-Object { "$($_.'@odata.type')" -match 'deviceEvidence' })
        $users = @($a.evidence | Where-Object { "$($_.'@odata.type')" -match 'userEvidence' } | ForEach-Object { $_.userAccount.userPrincipalName } | Where-Object { $_ } | Select-Object -Unique)
        [PSCustomObject]@{
            Utworzono      = $a.createdDateTime
            Alert          = $a.title
            Ważność        = $a.severity
            Stan           = $a.status
            Kategoria      = $a.category
            Urządzenia     = (@($devices | ForEach-Object { $_.deviceDnsName } | Where-Object { $_ } | Select-Object -Unique) -join ', ')
            Użytkownicy    = ($users -join ', ')
            Źródło         = $a.serviceSource
            Przypisano     = $a.assignedTo
            Incydent       = $a.incidentId
            Link           = $a.alertWebUrl
            Id             = $a.id
            __devices      = @($devices | ForEach-Object { @{ Name = $_.deviceDnsName; MdeId = $_.mdeDeviceId } } | Where-Object { $_.MdeId })
            __flag         = if ($a.severity -eq 'high') { 'crit' } elseif ($a.severity -eq 'medium') { 'warn' } elseif ($a.status -eq 'resolved') { 'muted' } else { '' }
        }
    }
}

function Get-HTDefenderIncidents {
    param ([int]$Days = 30, [switch]$IncludeResolved)
    $since = (Get-Date).ToUniversalTime().AddDays(-$Days).ToString('yyyy-MM-ddTHH:mm:ssZ')
    $filter = "createdDateTime ge $since"
    if (-not $IncludeResolved) { $filter += " and status ne 'resolved'" }
    foreach ($i in @(Invoke-HTGraphRequest -Uri "security/incidents?`$filter=$([uri]::EscapeDataString($filter))&`$top=200" | Sort-Object createdDateTime -Descending)) {
        [PSCustomObject]@{
            Utworzono   = $i.createdDateTime
            Incydent    = $i.displayName
            Ważność     = $i.severity
            Stan        = $i.status
            Klasyfikacja = $i.classification
            Przypisano  = $i.assignedTo
            Zmieniono   = $i.lastUpdateDateTime
            Tagi        = (@($i.tags) -join ', ')
            Link        = $i.incidentWebUrl
            Id          = $i.id
            __flag      = if ($i.severity -eq 'high') { 'crit' } elseif ($i.severity -eq 'medium') { 'warn' } else { '' }
        }
    }
}

function Set-HTDefenderAlertStatus {
    # Zmiana stanu alertu (SecurityAlert.ReadWrite.All): new, inProgress, resolved; przy zamknięciu klasyfikacja
    param ([Parameter(Mandatory)][string]$AlertId, [ValidateSet('new', 'inProgress', 'resolved')][string]$Status, [string]$Classification = '', [string]$Comment = '')
    $body = @{ status = $Status }
    if ($Classification) { $body.classification = $Classification }
    Invoke-HTGraphRequest -Uri "security/alerts_v2/$AlertId" -Method PATCH -Body $body | Out-Null
    if ($Comment) { Invoke-HTGraphRequest -Uri "security/alerts_v2/$AlertId/comments" -Method POST -Body @{ '@odata.type' = 'microsoft.graph.security.alertComment'; comment = $Comment } | Out-Null }
}

function Set-HTDefenderIncidentStatus {
    param ([Parameter(Mandatory)][string]$IncidentId, [ValidateSet('active', 'inProgress', 'resolved')][string]$Status, [string]$Classification = '')
    $body = @{ status = $Status }
    if ($Classification) { $body.classification = $Classification }
    Invoke-HTGraphRequest -Uri "security/incidents/$IncidentId" -Method PATCH -Body $body | Out-Null
}
#endregion

#region Microsoft Defender for Endpoint: izolacja urządzeń (api.securitycenter.microsoft.com)
<#
    Izolacja wymaga tokenu dla API Defender for Endpoint (nie Microsoft Graph). Token pobiera logowanie w przeglądarce
    (kod autoryzacyjny z PKCE, nasłuch na localhost) dla aplikacji z Ustawień (DefenderClientId) z uprawnieniami
    delegowanymi WindowsDefenderATP: Machine.Read, Machine.Isolate. Token i token odświeżania są tylko w pamięci.
#>
$script:DefenderApi = 'https://api.securitycenter.microsoft.com'
$script:DefenderToken = @{ Access = ''; Refresh = ''; Expires = [datetime]::MinValue; Tenant = ''; ClientId = '' }

function New-HTPkcePair {
    $bytes = New-Object byte[] 32
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    $verifier = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    $hash = [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::ASCII.GetBytes($verifier))
    $challenge = [Convert]::ToBase64String($hash).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    return @{ Verifier = $verifier; Challenge = $challenge }
}

function ConvertFrom-HTQueryString {
    param ([AllowEmptyString()][string]$Query)
    $result = @{}
    foreach ($pair in @($Query.TrimStart('?') -split '&' | Where-Object { $_ })) {
        $kv = $pair -split '=', 2
        $result[[uri]::UnescapeDataString($kv[0])] = if ($kv.Count -gt 1) { [uri]::UnescapeDataString($kv[1].Replace('+', ' ')) } else { '' }
    }
    return $result
}

function Receive-HTAuthorizationCode {
    # Oczekiwanie na przekierowanie z przeglądarki (http://localhost:<port>/?code=...); anulowanie - żądanie z error=
    param ([Parameter(Mandatory)][System.Net.Sockets.TcpListener]$Listener)
    $client = $Listener.AcceptTcpClient()
    try {
        $stream = $client.GetStream()
        $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII, $false, 4096, $true)
        $requestLine = $reader.ReadLine()
        $query = ''
        if ($requestLine -match '^GET\s+(\S+)') { $path = $Matches[1]; $q = $path.IndexOf('?'); if ($q -ge 0) { $query = $path.Substring($q + 1) } }
        $params = ConvertFrom-HTQueryString $query
        $ok = [bool]$params['code']
        $html = '<html><head><meta charset="utf-8"><title>Helpdesk Tools</title></head><body style="font-family:Segoe UI,sans-serif;background:#0F1318;color:#E4E8EF;padding:40px"><h2>' +
        $(if ($ok) { 'Zalogowano - możesz zamknąć tę kartę i wrócić do programu.' } else { 'Logowanie nie powiodło się lub zostało anulowane.' }) + '</h2></body></html>'
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($html)
        $header = [System.Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`nContent-Type: text/html; charset=utf-8`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n")
        $stream.Write($header, 0, $header.Length)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush()
        return $params
    }
    finally { $client.Close() }
}

function Request-HTOAuthToken {
    param ([Parameter(Mandatory)][string]$TenantId, [Parameter(Mandatory)][string]$ClientId, [Parameter(Mandatory)][hashtable]$Form)
    $Form.client_id = $ClientId
    $response = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Body $Form -ContentType 'application/x-www-form-urlencoded' -TimeoutSec 30 -ErrorAction Stop
    $script:DefenderToken = @{ Access = $response.access_token; Refresh = [string]$response.refresh_token; Expires = (Get-Date).AddSeconds([int]$response.expires_in - 120); Tenant = $TenantId; ClientId = $ClientId }
    return $response.access_token
}

function Get-HTDefenderToken {
    # Token API Defender for Endpoint: z pamięci, odświeżony albo z logowania w przeglądarce
    param ([string]$ClientId = $Global:HTConfig.DefenderClientId, [string]$TenantId = '')
    if (-not $ClientId) { throw 'Ustaw Client ID aplikacji Defender for Endpoint w Ustawieniach (Automatyzacja i Defender).' }
    if (-not $TenantId) { $ctx = Get-MgContext; $TenantId = if ($ctx.TenantId) { [string]$ctx.TenantId } else { 'organizations' } }
    $t = $script:DefenderToken
    if ($t.Access -and $t.Expires -gt (Get-Date) -and $t.Tenant -eq $TenantId -and $t.ClientId -eq $ClientId) { return $t.Access }
    $scope = "$script:DefenderApi/Machine.Read $script:DefenderApi/Machine.Isolate offline_access"
    if ($t.Refresh -and $t.Tenant -eq $TenantId -and $t.ClientId -eq $ClientId) {
        try { return Request-HTOAuthToken -TenantId $TenantId -ClientId $ClientId -Form @{ grant_type = 'refresh_token'; refresh_token = $t.Refresh; scope = $scope } }
        catch { Write-Log -Message "Odświeżenie tokenu Defender: $($_.Exception.Message)" -Type 'Warn' }
    }
    $pkce = New-HTPkcePair
    $state = [guid]::NewGuid().ToString('N')
    # Nasłuch uruchamiany wewnątrz bloku logowania - okno «Trwa logowanie» rozpoznaje nowy port i może anulować oczekiwanie
    $login = {
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $listener.Start()
        try {
            $redirect = "http://localhost:$(([System.Net.IPEndPoint]$listener.LocalEndpoint).Port)/"
            $url = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/authorize?client_id=$([uri]::EscapeDataString($ClientId))&response_type=code&redirect_uri=$([uri]::EscapeDataString($redirect))" +
            "&scope=$([uri]::EscapeDataString($scope))&state=$state&code_challenge=$($pkce.Challenge)&code_challenge_method=S256&prompt=select_account"
            Start-Process $url
            @{ Params = (Receive-HTAuthorizationCode -Listener $listener); Redirect = $redirect }
        }
        finally { $listener.Stop() }
    }.GetNewClosure()
    $result = @(Invoke-HTLogin -Title 'Microsoft Defender for Endpoint' -ScriptBlock $login)[-1]
    $params = $result.Params
    if (-not $params -or $params['error'] -or -not $params['code']) { throw "Logowanie do Defender for Endpoint nie powiodło się: $($params['error']) $($params['error_description'])".Trim() }
    if ($params['state'] -ne $state) { throw 'Nieprawidłowa odpowiedź logowania (state).' }
    return Request-HTOAuthToken -TenantId $TenantId -ClientId $ClientId -Form @{ grant_type = 'authorization_code'; code = $params['code']; redirect_uri = $result.Redirect; code_verifier = $pkce.Verifier; scope = $scope }
}

function Invoke-HTDefenderRequest {
    param ([Parameter(Mandatory)][string]$Path, [string]$Method = 'GET', $Body = $null)
    $headers = @{ Authorization = "Bearer $(Get-HTDefenderToken)" }
    $params = @{ Uri = "$script:DefenderApi/api/$($Path.TrimStart('/'))"; Method = $Method; Headers = $headers; TimeoutSec = 60; ErrorAction = 'Stop' }
    if ($null -ne $Body) { $params.Body = ($Body | ConvertTo-Json -Depth 6 -Compress); $params.ContentType = 'application/json' }
    $response = Invoke-RestMethod @params
    if ($response.PSObject.Properties.Name -contains 'value') { return @($response.value) }
    return $response
}

function Find-HTDefenderMachine {
    # Urządzenia Defender for Endpoint po nazwie (początek nazwy DNS)
    param ([Parameter(Mandatory)][string]$Name)
    $n = $Name.Trim().ToLowerInvariant().Replace("'", "''")
    foreach ($m in @(Invoke-HTDefenderRequest -Path "machines?`$filter=startswith(computerDnsName,'$n')")) {
        [PSCustomObject]@{
            Urządzenie        = $m.computerDnsName
            System            = "$($m.osPlatform) $($m.version)"
            Kondycja          = $m.healthStatus
            Ryzyko            = $m.riskScore
            Narażenie         = $m.exposureLevel
            'Ostatnio widziane' = $m.lastSeen
            'Adres IP'        = $m.lastIpAddress
            Izolacja          = ''
            Id                = $m.id
            __flag            = if ($m.riskScore -eq 'High') { 'crit' } elseif ($m.riskScore -eq 'Medium') { 'warn' } else { '' }
        }
    }
}

function Set-HTDefenderIsolation {
    # Izolacja (Full / Selective - z dostępem do Outlook, Teams) albo zwolnienie z izolacji
    param ([Parameter(Mandatory)][string]$MachineId, [Parameter(Mandatory)][bool]$Isolate, [string]$Comment = 'Helpdesk Tools', [ValidateSet('Full', 'Selective')][string]$Type = 'Full')
    $body = @{ Comment = $(if ($Comment) { $Comment } else { 'Helpdesk Tools' }) }
    if ($Isolate) { $body.IsolationType = $Type }
    $action = Invoke-HTDefenderRequest -Path "machines/$MachineId/$(if ($Isolate) { 'isolate' } else { 'unisolate' })" -Method POST -Body $body
    return "Zlecono $(if ($Isolate) { "izolację ($Type)" } else { 'zwolnienie z izolacji' }) - akcja $($action.id), stan: $($action.status)"
}

function Get-HTDefenderMachineActions {
    param ([Parameter(Mandatory)][string]$MachineId)
    foreach ($a in @(Invoke-HTDefenderRequest -Path "machineactions?`$filter=machineId eq '$MachineId'" | Sort-Object creationDateTimeUtc -Descending | Select-Object -First 20)) {
        [PSCustomObject]@{ Akcja = $a.type; Stan = $a.status; Zlecił = $a.requestor; Komentarz = $a.requestorComment; Utworzono = $a.creationDateTimeUtc; Zmieniono = $a.lastUpdateDateTimeUtc; Id = $a.id }
    }
}
#endregion
