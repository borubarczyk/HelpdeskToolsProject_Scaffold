# Funkcje dla lokalnego Active Directory (wymaga modułu ActiveDirectory z RSAT)
# Funkcje przyjmują parametry i zwracają dane - obsługa GUI znajduje się w GUI/Workspaces/AD*.ps1

# Mapowanie nazw sekcji w GUI na wewnętrzne typy obiektów
$script:SectionMap = @{
    "Użytkownicy" = "User"
    "Komputery"   = "Computer"
    "Grupy"       = "Group"
    "User"        = "User"
    "Computer"    = "Computer"
    "Group"       = "Group"
}

function ConvertTo-HTADObjectType {
    param ([Parameter(Mandatory)][string]$Section)
    $type = $script:SectionMap[$Section]
    if (-not $type) { throw "Nieobsługiwana sekcja: $Section" }
    return $type
}

# Sprawdza dostępność i ładuje moduł ActiveDirectory
function Test-HTADAvailable {
    if (Get-Module -Name ActiveDirectory) { return $true }
    if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) { return $false }
    try {
        Import-Module ActiveDirectory -ErrorAction Stop -Global -WarningAction SilentlyContinue
        return $true
    }
    catch {
        Write-Log -Message "Nie udało się zaimportować modułu ActiveDirectory: $($_.Exception.Message)" -Type "Warn"
        return $false
    }
}

# Lista obiektów dla sekcji
function Get-HTADObjectList {
    param ([Parameter(Mandatory)][string]$Section)

    switch (ConvertTo-HTADObjectType $Section) {
        "User" {
            Get-ADUser -Filter * -Properties DisplayName, Enabled, LockedOut, Department, Title, LastLogonDate, EmailAddress, PasswordNeverExpires, PasswordExpired |
                ForEach-Object {
                    [PSCustomObject]@{
                        Name              = $_.Name
                        DisplayName       = $_.DisplayName
                        SamAccountName    = $_.SamAccountName
                        UserPrincipalName = $_.UserPrincipalName
                        EmailAddress      = $_.EmailAddress
                        Enabled           = [bool]$_.Enabled
                        LockedOut         = [bool]$_.LockedOut
                        Department        = $_.Department
                        Title             = $_.Title
                        LastLogonDate     = $_.LastLogonDate
                        PasswordExpired   = [bool]$_.PasswordExpired
                        PasswordNeverExpires = [bool]$_.PasswordNeverExpires
                        DistinguishedName = $_.DistinguishedName
                        ObjectGUID        = $_.ObjectGUID
                    }
                }
        }
        "Computer" {
            Get-ADComputer -Filter * -Properties OperatingSystem, OperatingSystemVersion, LastLogonDate, Description, DNSHostName |
                ForEach-Object {
                    [PSCustomObject]@{
                        Name              = $_.Name
                        SamAccountName    = $_.SamAccountName
                        DNSHostName       = $_.DNSHostName
                        OperatingSystem   = $_.OperatingSystem
                        Enabled           = [bool]$_.Enabled
                        LastLogonDate     = $_.LastLogonDate
                        Description       = $_.Description
                        DistinguishedName = $_.DistinguishedName
                        ObjectGUID        = $_.ObjectGUID
                    }
                }
        }
        "Group" {
            Get-ADGroup -Filter * -Properties Description, ManagedBy, WhenCreated, mail |
                ForEach-Object {
                    [PSCustomObject]@{
                        Name              = $_.Name
                        SamAccountName    = $_.SamAccountName
                        GroupCategory     = "$($_.GroupCategory)"
                        GroupScope        = "$($_.GroupScope)"
                        Description       = $_.Description
                        Mail              = $_.mail
                        DistinguishedName = $_.DistinguishedName
                        ObjectGUID        = $_.ObjectGUID
                    }
                }
        }
    }
}

# Czytelna nazwa z DN (CN=Jan Kowalski,OU=... -> Jan Kowalski)
function Get-HTNameFromDN {
    param ([AllowNull()][string]$DistinguishedName)
    if (-not $DistinguishedName) { return "" }
    if ($DistinguishedName -match '^CN=((?:[^,\\]|\\.)+)') { return ($matches[1] -replace '\\(.)', '$1') }
    return $DistinguishedName
}

# Szczegóły obiektu (słownik do wyświetlenia w panelu szczegółów)
function Get-HTADObjectDetail {
    param (
        [Parameter(Mandatory)][string]$Section,
        [Parameter(Mandatory)][string]$Identity
    )

    switch (ConvertTo-HTADObjectType $Section) {
        "User" {
            $u = Get-ADUser -Identity $Identity -Properties *
            $groups = @($u.MemberOf | ForEach-Object { Get-HTNameFromDN $_ } | Sort-Object)
            return [ordered]@{
                "Nazwa"                    = $u.Name
                "Nazwa wyświetlana"        = $u.DisplayName
                "Login (SAM)"              = $u.SamAccountName
                "UPN"                      = $u.UserPrincipalName
                "E-mail"                   = $u.EmailAddress
                "Włączone"                 = [bool]$u.Enabled
                "Zablokowane"              = [bool]$u.LockedOut
                "Stanowisko"               = $u.Title
                "Dział"                    = $u.Department
                "Firma"                    = $u.Company
                "Biuro"                    = $u.Office
                "Telefon"                  = $u.OfficePhone
                "Komórka"                  = $u.MobilePhone
                "Przełożony"               = Get-HTNameFromDN $u.Manager
                "Opis"                     = $u.Description
                "Konto i hasło"            = [ordered]@{
                    "Hasło ustawione"            = $u.PasswordLastSet
                    "Hasło nigdy nie wygasa"     = [bool]$u.PasswordNeverExpires
                    "Zmiana hasła przy logowaniu" = ($u.pwdLastSet -eq 0)
                    "Wygaśnięcie konta"          = $u.AccountExpirationDate
                    "Ostatnie logowanie"         = $u.LastLogonDate
                    "Błędne logowania"           = $u.BadLogonCount
                    "Utworzono"                  = $u.WhenCreated
                    "Zmieniono"                  = $u.WhenChanged
                }
                "Profil"                   = [ordered]@{
                    "Ścieżka profilu"   = $u.ProfilePath
                    "Skrypt logowania"  = $u.ScriptPath
                    "Katalog domowy"    = $u.HomeDirectory
                    "Dysk domowy"       = $u.HomeDrive
                }
                "Lokalizacja"              = [ordered]@{
                    "DN"   = $u.DistinguishedName
                    "GUID" = $u.ObjectGUID
                    "SID"  = $u.SID
                }
                "Grupy ($($groups.Count))" = [ordered]@{ "Członkostwo" = $groups }
            }
        }
        "Computer" {
            $c = Get-ADComputer -Identity $Identity -Properties *
            $groups = @($c.MemberOf | ForEach-Object { Get-HTNameFromDN $_ } | Sort-Object)
            return [ordered]@{
                "Nazwa"                    = $c.Name
                "DNS"                      = $c.DNSHostName
                "Adres IPv4"               = $c.IPv4Address
                "System"                   = $c.OperatingSystem
                "Wersja systemu"           = $c.OperatingSystemVersion
                "Włączone"                 = [bool]$c.Enabled
                "Opis"                     = $c.Description
                "Lokalizacja"              = $c.Location
                "Zarządzany przez"         = Get-HTNameFromDN $c.ManagedBy
                "Ostatnie logowanie"       = $c.LastLogonDate
                "Hasło konta ustawione"    = $c.PasswordLastSet
                "Utworzono"                = $c.WhenCreated
                "DN"                       = $c.DistinguishedName
                "GUID"                     = $c.ObjectGUID
                "SID"                      = $c.SID
                "Grupy ($($groups.Count))" = [ordered]@{ "Członkostwo" = $groups }
            }
        }
        "Group" {
            $g = Get-ADGroup -Identity $Identity -Properties *
            $members = @(Get-HTADGroupMembers -Identity $Identity | ForEach-Object { "$($_.Name) ($($_.ObjectClass))" } | Sort-Object)
            return [ordered]@{
                "Nazwa"                         = $g.Name
                "Login (SAM)"                   = $g.SamAccountName
                "Typ"                           = "$($g.GroupCategory)"
                "Zakres"                        = "$($g.GroupScope)"
                "E-mail"                        = $g.mail
                "Opis"                          = $g.Description
                "Zarządzana przez"              = Get-HTNameFromDN $g.ManagedBy
                "Utworzono"                     = $g.WhenCreated
                "DN"                            = $g.DistinguishedName
                "GUID"                          = $g.ObjectGUID
                "Członkowie ($($members.Count))" = [ordered]@{ "Członkowie" = $members }
            }
        }
    }
}

# Członkowie grupy (odporne na obiekty spoza domeny, dla których Get-ADGroupMember zgłasza błąd)
function Get-HTADGroupMembers {
    param ([Parameter(Mandatory)][string]$Identity)
    try {
        return @(Get-ADGroupMember -Identity $Identity -ErrorAction Stop | ForEach-Object {
                [PSCustomObject]@{
                    Name              = $_.Name
                    SamAccountName    = $_.SamAccountName
                    ObjectClass       = $_.objectClass
                    DistinguishedName = $_.distinguishedName
                }
            })
    }
    catch {
        $group = Get-ADGroup -Identity $Identity -Properties Member
        return @($group.Member | ForEach-Object {
                [PSCustomObject]@{
                    Name              = Get-HTNameFromDN $_
                    SamAccountName    = ""
                    ObjectClass       = ""
                    DistinguishedName = $_
                }
            })
    }
}

# Grupy, do których należy obiekt
function Get-HTADObjectGroups {
    param ([Parameter(Mandatory)][string]$DistinguishedName)
    $object = Get-ADObject -Identity $DistinguishedName -Properties MemberOf
    return @($object.MemberOf | ForEach-Object {
            [PSCustomObject]@{
                Name              = Get-HTNameFromDN $_
                DistinguishedName = $_
            }
        } | Sort-Object Name)
}

# Lista grup do wyboru
function Get-HTADGroupList {
    return @(Get-ADGroup -Filter * -Properties Description | Sort-Object Name | ForEach-Object {
            [PSCustomObject]@{
                Name              = $_.Name
                GroupCategory     = "$($_.GroupCategory)"
                GroupScope        = "$($_.GroupScope)"
                Description       = $_.Description
                DistinguishedName = $_.DistinguishedName
            }
        })
}

# Lista jednostek organizacyjnych do wyboru
function Get-HTADOrganizationalUnits {
    $ous = @(Get-ADOrganizationalUnit -Filter * -Properties CanonicalName, Description | ForEach-Object {
            [PSCustomObject]@{
                Name              = $_.Name
                CanonicalName     = $_.CanonicalName
                Description       = $_.Description
                DistinguishedName = $_.DistinguishedName
            }
        })
    # Kontenery domyślne (Users, Computers)
    $domain = Get-ADDomain
    $ous += [PSCustomObject]@{ Name = "Users"; CanonicalName = "$($domain.DNSRoot)/Users"; Description = "Kontener domyślny"; DistinguishedName = $domain.UsersContainer }
    $ous += [PSCustomObject]@{ Name = "Computers"; CanonicalName = "$($domain.DNSRoot)/Computers"; Description = "Kontener domyślny"; DistinguishedName = $domain.ComputersContainer }
    return @($ous | Sort-Object CanonicalName)
}

# Reset hasła użytkownika
function Reset-HTADUserPassword {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][string]$Password,
        [bool]$ChangeAtLogon = $true,
        [bool]$Unlock = $true
    )
    $secure = ConvertTo-SecureString -String $Password -AsPlainText -Force
    Set-ADAccountPassword -Identity $Identity -Reset -NewPassword $secure -ErrorAction Stop
    Set-ADUser -Identity $Identity -ChangePasswordAtLogon $ChangeAtLogon -ErrorAction Stop
    if ($Unlock) { Unlock-ADAccount -Identity $Identity -ErrorAction SilentlyContinue }
}

# Włączenie / wyłączenie / odblokowanie konta (użytkownik lub komputer)
function Set-HTADAccountState {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][ValidateSet("Enable", "Disable", "Unlock")][string]$State
    )
    switch ($State) {
        "Enable" { Enable-ADAccount -Identity $Identity -ErrorAction Stop }
        "Disable" { Disable-ADAccount -Identity $Identity -ErrorAction Stop }
        "Unlock" { Unlock-ADAccount -Identity $Identity -ErrorAction Stop }
    }
}

# Dodanie obiektów do grup
function Add-HTADGroupMember {
    param (
        [Parameter(Mandatory)][string]$Group,
        [Parameter(Mandatory)][string[]]$Members
    )
    Add-ADGroupMember -Identity $Group -Members $Members -ErrorAction Stop
}

# Usunięcie obiektów z grupy
function Remove-HTADGroupMember {
    param (
        [Parameter(Mandatory)][string]$Group,
        [Parameter(Mandatory)][string[]]$Members
    )
    Remove-ADGroupMember -Identity $Group -Members $Members -Confirm:$false -ErrorAction Stop
}

# Ustawienia profilu użytkownika (puste wartości czyszczą atrybut)
function Set-HTADUserProfile {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [AllowEmptyString()][string]$ProfilePath,
        [AllowEmptyString()][string]$ScriptPath,
        [AllowEmptyString()][string]$HomeDirectory,
        [AllowEmptyString()][string]$HomeDrive
    )
    $params = @{ Identity = $Identity; ErrorAction = "Stop" }
    foreach ($name in "ProfilePath", "ScriptPath", "HomeDirectory", "HomeDrive") {
        if ($PSBoundParameters.ContainsKey($name)) {
            $value = $PSBoundParameters[$name]
            $params[$name] = if ([string]::IsNullOrWhiteSpace($value)) { $null } else { $value }
        }
    }
    Set-ADUser @params
}

# Edycja podstawowych atrybutów użytkownika (tylko przekazane klucze)
function Set-HTADUserAttributes {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][hashtable]$Attributes
    )
    $allowed = "DisplayName", "Title", "Department", "Company", "Office", "OfficePhone", "MobilePhone", "EmailAddress", "Description", "Manager"
    $params = @{ Identity = $Identity; ErrorAction = "Stop" }
    foreach ($key in $Attributes.Keys) {
        if ($allowed -notcontains $key) { throw "Nieobsługiwany atrybut: $key" }
        $value = $Attributes[$key]
        $params[$key] = if ([string]::IsNullOrWhiteSpace("$value")) { $null } else { $value }
    }
    Set-ADUser @params
}

# Nowy użytkownik
function New-HTADUser {
    param (
        [Parameter(Mandatory)][string]$GivenName,
        [Parameter(Mandatory)][string]$Surname,
        [Parameter(Mandatory)][string]$SamAccountName,
        [Parameter(Mandatory)][string]$UserPrincipalName,
        [Parameter(Mandatory)][string]$Password,
        [string]$Path,
        [string]$Title,
        [string]$Department,
        [bool]$Enabled = $true,
        [bool]$ChangeAtLogon = $true
    )
    $params = @{
        Name                  = "$GivenName $Surname"
        DisplayName           = "$GivenName $Surname"
        GivenName             = $GivenName
        Surname               = $Surname
        SamAccountName        = $SamAccountName
        UserPrincipalName     = $UserPrincipalName
        AccountPassword       = ConvertTo-SecureString -String $Password -AsPlainText -Force
        Enabled               = $Enabled
        ChangePasswordAtLogon = $ChangeAtLogon
        ErrorAction           = "Stop"
        PassThru              = $true
    }
    if ($Path) { $params.Path = $Path }
    if ($Title) { $params.Title = $Title }
    if ($Department) { $params.Department = $Department }
    return New-ADUser @params
}

# Nowa grupa
function New-HTADGroup {
    param (
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet("Security", "Distribution")][string]$Category,
        [Parameter(Mandatory)][ValidateSet("DomainLocal", "Global", "Universal")][string]$Scope,
        [string]$Path,
        [string]$Description
    )
    $params = @{
        Name           = $Name
        SamAccountName = $Name
        GroupCategory  = $Category
        GroupScope     = $Scope
        ErrorAction    = "Stop"
        PassThru       = $true
    }
    if ($Path) { $params.Path = $Path }
    if ($Description) { $params.Description = $Description }
    return New-ADGroup @params
}

# Przeniesienie obiektu do innej OU
function Move-HTADObject {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][string]$TargetPath
    )
    Move-ADObject -Identity $Identity -TargetPath $TargetPath -ErrorAction Stop
}

# Usunięcie obiektu (użytkownik, komputer, grupa)
function Remove-HTADObject {
    param (
        [Parameter(Mandatory)][string]$Section,
        [Parameter(Mandatory)][string]$Identity
    )
    switch (ConvertTo-HTADObjectType $Section) {
        "User" { Remove-ADUser -Identity $Identity -Confirm:$false -ErrorAction Stop }
        # Komputer może mieć obiekty podrzędne (np. klucze BitLocker) - usuwamy rekurencyjnie
        "Computer" {
            $computer = Get-ADComputer -Identity $Identity
            Remove-ADObject -Identity $computer.DistinguishedName -Recursive -Confirm:$false -ErrorAction Stop
        }
        "Group" { Remove-ADGroup -Identity $Identity -Confirm:$false -ErrorAction Stop }
    }
}

# Przełączenie "hasło nigdy nie wygasa"
function Set-HTADPasswordNeverExpires {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][bool]$Value
    )
    Set-ADUser -Identity $Identity -PasswordNeverExpires $Value -ErrorAction Stop
}

# Wymuszenie zmiany hasła przy następnym logowaniu
function Set-HTADChangePasswordAtLogon {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][bool]$Value
    )
    Set-ADUser -Identity $Identity -ChangePasswordAtLogon $Value -ErrorAction Stop
}

# Data wygaśnięcia konta ($null = nigdy)
function Set-HTADAccountExpiration {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [AllowNull()][Nullable[datetime]]$Date
    )
    if ($Date) {
        Set-ADAccountExpiration -Identity $Identity -DateTime $Date -ErrorAction Stop
    }
    else {
        Clear-ADAccountExpiration -Identity $Identity -ErrorAction Stop
    }
}

# Zmiana nazwy grupy (CN i sAMAccountName)
function Rename-HTADGroup {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][string]$NewName
    )
    $group = Get-ADGroup -Identity $Identity
    Set-ADGroup -Identity $group.ObjectGUID -SamAccountName $NewName -DisplayName $NewName -ErrorAction Stop
    Rename-ADObject -Identity $group.DistinguishedName -NewName $NewName -ErrorAction Stop
}

# Zmiana typu grupy (Security / Distribution)
function Set-HTADGroupCategory {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][ValidateSet("Security", "Distribution")][string]$Category
    )
    Set-ADGroup -Identity $Identity -GroupCategory $Category -ErrorAction Stop
}

# Zmiana zakresu grupy. Przejście Global <-> DomainLocal wymaga etapu pośredniego (Universal).
function Set-HTADGroupScope {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][ValidateSet("DomainLocal", "Global", "Universal")][string]$Scope
    )
    $group = Get-ADGroup -Identity $Identity
    $current = "$($group.GroupScope)"
    if ($current -eq $Scope) { return }
    if (($current -eq "Global" -and $Scope -eq "DomainLocal") -or ($current -eq "DomainLocal" -and $Scope -eq "Global")) {
        Set-ADGroup -Identity $group.ObjectGUID -GroupScope Universal -ErrorAction Stop
    }
    Set-ADGroup -Identity $group.ObjectGUID -GroupScope $Scope -ErrorAction Stop
}

# Test dostępności komputera (DNS + ping)
function Test-HTComputerReachable {
    param ([Parameter(Mandatory)][string]$ComputerName)

    $addresses = @()
    try {
        $addresses = @([System.Net.Dns]::GetHostAddresses($ComputerName) | ForEach-Object { $_.IPAddressToString })
    }
    catch { }

    $ping = $false
    $latency = $null
    try {
        $reply = Test-Connection -TargetName $ComputerName -Count 2 -ErrorAction Stop | Where-Object { $_.Status -eq "Success" } | Select-Object -First 1
        if ($reply) { $ping = $true; $latency = $reply.Latency }
    }
    catch { }

    return [ordered]@{
        "Komputer"       = $ComputerName
        "Adresy IP (DNS)" = if ($addresses) { $addresses -join ", " } else { "nie rozwiązano" }
        "Odpowiada na ping" = $ping
        "Opóźnienie (ms)" = $latency
        "Sprawdzono"     = Get-Date
    }
}

# Restart zdalnego komputera
function Restart-HTComputer {
    param ([Parameter(Mandatory)][string]$ComputerName)
    Restart-Computer -ComputerName $ComputerName -Force -ErrorAction Stop
}

# Hasło LAPS (Windows LAPS lub starszy Microsoft LAPS)
function Get-HTADLapsPassword {
    param ([Parameter(Mandatory)][string]$ComputerName)

    if (Get-Command Get-LapsADPassword -ErrorAction SilentlyContinue) {
        try {
            $laps = Get-LapsADPassword -Identity $ComputerName -AsPlainText -ErrorAction Stop
            if ($laps -and $laps.Password) {
                return [PSCustomObject]@{
                    Account    = $laps.Account
                    Password   = "$($laps.Password)"
                    Updated    = $laps.PasswordUpdateTime
                    Expiration = $laps.ExpirationTimestamp
                    Source     = "Windows LAPS"
                }
            }
        }
        catch {
            Write-Log -Message "Windows LAPS: $($_.Exception.Message)" -Type "Warn"
        }
    }

    $computer = Get-ADComputer -Identity $ComputerName -Properties "ms-Mcs-AdmPwd", "ms-Mcs-AdmPwdExpirationTime"
    $legacy = $computer."ms-Mcs-AdmPwd"
    if ($legacy) {
        $expiration = $computer."ms-Mcs-AdmPwdExpirationTime"
        return [PSCustomObject]@{
            Account    = "Administrator"
            Password   = $legacy
            Updated    = $null
            Expiration = if ($expiration) { [datetime]::FromFileTime([int64]$expiration) } else { $null }
            Source     = "Microsoft LAPS (legacy)"
        }
    }
    return $null
}

# Klucze odzyskiwania BitLocker zapisane w AD
function Get-HTADBitLockerKeys {
    param ([Parameter(Mandatory)][string]$ComputerName)
    $computer = Get-ADComputer -Identity $ComputerName
    return @(Get-ADObject -Filter "objectClass -eq 'msFVE-RecoveryInformation'" -SearchBase $computer.DistinguishedName -Properties "msFVE-RecoveryPassword", whenCreated |
            Sort-Object whenCreated -Descending |
            ForEach-Object {
                [PSCustomObject]@{
                    Created          = $_.whenCreated
                    KeyId            = if ($_.Name -match '\{(.+)\}') { $matches[1] } else { $_.Name }
                    RecoveryPassword = $_."msFVE-RecoveryPassword"
                }
            })
}

# Ustawienie opisu komputera
function Set-HTADComputerDescription {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [AllowEmptyString()][string]$Description
    )
    $value = if ([string]::IsNullOrWhiteSpace($Description)) { $null } else { $Description }
    Set-ADComputer -Identity $Identity -Description $value -ErrorAction Stop
}

# Zablokowane konta (do Dashboardu)
function Get-HTADLockedAccounts {
    return @(Search-ADAccount -LockedOut -UsersOnly -ErrorAction Stop)
}

#region Wyszukiwanie obiektów
# Wyszukanie użytkownika AD po UPN, e-mailu lub loginie
function Resolve-HTADUser {
    param ([Parameter(Mandatory)][string]$Identity)
    $value = $Identity.Replace("'", "''")
    $users = @(Get-ADUser -Filter "UserPrincipalName -eq '$value' -or SamAccountName -eq '$value' -or mail -eq '$value'" -ErrorAction Stop)
    if ($users.Count -eq 0) { throw "Nie znaleziono użytkownika AD: $Identity" }
    if ($users.Count -gt 1) { throw "Niejednoznaczny identyfikator (znaleziono $($users.Count) konta): $Identity" }
    return $users[0]
}

# Wyszukanie dowolnego obiektu (użytkownik, komputer, grupa) po loginie, UPN, nazwie lub DN
function Resolve-HTADObject {
    param ([Parameter(Mandatory)][string]$Identity)
    $value = $Identity.Trim()
    if ($value -match '^(CN|OU)=') { return Get-ADObject -Identity $value -ErrorAction Stop }
    $escaped = $value.Replace("'", "''")
    # Komputer można podać bez znaku $ na końcu nazwy konta
    $found = @(Get-ADObject -Filter "sAMAccountName -eq '$escaped' -or sAMAccountName -eq '$escaped`$' -or userPrincipalName -eq '$escaped' -or name -eq '$escaped' -or mail -eq '$escaped'" -ErrorAction Stop)
    if ($found.Count -eq 0) { throw "Nie znaleziono obiektu AD: $Identity" }
    if ($found.Count -gt 1) { throw "Niejednoznaczny identyfikator (znaleziono $($found.Count) obiekty): $Identity" }
    return $found[0]
}

# Sufiksy UPN dostępne w lesie (domena + alternatywne)
function Get-HTADUpnSuffixes {
    $suffixes = @((Get-ADDomain -ErrorAction Stop).DNSRoot)
    try { $suffixes += @((Get-ADForest -ErrorAction Stop).UPNSuffixes) } catch { Write-Verbose $_ }
    return @($suffixes | Where-Object { $_ } | Select-Object -Unique)
}

# Proponowany login: imie.nazwisko bez polskich znaków (max 20 znaków - limit sAMAccountName)
function New-HTADLoginName {
    param ([Parameter(Mandatory)][string]$GivenName, [Parameter(Mandatory)][string]$Surname, [string]$Format = "{0}.{1}")
    $given = (ConvertTo-HTAsciiName $GivenName).ToLowerInvariant() -replace '[^a-z0-9\-]', ''
    $sur = (ConvertTo-HTAsciiName $Surname).ToLowerInvariant() -replace '[^a-z0-9\-]', ''
    $login = $Format -f $given, $sur
    if ($login.Length -gt 20) { $login = $login.Substring(0, 20) }
    return $login.Trim('.')
}
#endregion

#region Grupy użytkownika
# Kopiuje członkostwo w grupach z konta wzorcowego (pomija grupy, do których użytkownik już należy)
function Copy-HTADGroupMembership {
    param (
        [Parameter(Mandatory)][string]$SourceIdentity,
        [Parameter(Mandatory)][string]$TargetIdentity
    )
    $source = Get-ADUser -Identity $SourceIdentity -Properties MemberOf -ErrorAction Stop
    $target = Get-ADUser -Identity $TargetIdentity -Properties MemberOf -ErrorAction Stop
    $result = New-Object System.Collections.Generic.List[object]
    foreach ($group in @($source.MemberOf)) {
        $name = Get-HTNameFromDN $group
        if (@($target.MemberOf) -contains $group) {
            $result.Add([PSCustomObject]@{ Grupa = $name; Status = "Pominięto"; Szczegóły = "Już jest członkiem" })
            continue
        }
        try {
            Add-ADGroupMember -Identity $group -Members $target.ObjectGUID -ErrorAction Stop
            $result.Add([PSCustomObject]@{ Grupa = $name; Status = "OK"; Szczegóły = "Dodano" })
        }
        catch { $result.Add([PSCustomObject]@{ Grupa = $name; Status = "Błąd"; Szczegóły = $_.Exception.Message }) }
    }
    return $result.ToArray()
}

# Usuwa użytkownika ze wszystkich grup (poza grupą podstawową, np. Domain Users)
function Remove-HTADAllGroupMembership {
    param ([Parameter(Mandatory)][string]$Identity)
    $user = Get-ADUser -Identity $Identity -Properties MemberOf -ErrorAction Stop
    $removed = @()
    foreach ($group in @($user.MemberOf)) {
        Remove-ADGroupMember -Identity $group -Members $user.ObjectGUID -Confirm:$false -ErrorAction Stop
        $removed += Get-HTNameFromDN $group
    }
    return $removed
}

# Opis i właściciel grupy
function Set-HTADGroupProperties {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [AllowEmptyString()][string]$Description,
        [AllowEmptyString()][string]$ManagedBy
    )
    $params = @{ Identity = $Identity; ErrorAction = "Stop" }
    if ($PSBoundParameters.ContainsKey("Description")) { $params.Description = if ([string]::IsNullOrWhiteSpace($Description)) { $null } else { $Description } }
    if ($PSBoundParameters.ContainsKey("ManagedBy")) { $params.ManagedBy = if ([string]::IsNullOrWhiteSpace($ManagedBy)) { $null } else { (Resolve-HTADObject -Identity $ManagedBy).DistinguishedName } }
    Set-ADGroup @params
}
#endregion

#region Blokady kont
# Stan konta na każdym kontrolerze domeny (atrybuty badPwdCount / lockoutTime nie są replikowane)
function Get-HTADLockoutStatus {
    param ([Parameter(Mandatory)][string]$Identity)
    $controllers = @(Get-ADDomainController -Filter * -ErrorAction Stop)
    foreach ($dc in $controllers) {
        try {
            $u = Get-ADUser -Identity $Identity -Server $dc.HostName -Properties LockedOut, badPwdCount, LastBadPasswordAttempt, lockoutTime, PasswordLastSet, LastLogonDate -ErrorAction Stop
            $lockout = if ($u.lockoutTime -gt 0) { [datetime]::FromFileTime([int64]$u.lockoutTime) } else { $null }
            [PSCustomObject]@{
                Kontroler               = $dc.HostName
                Lokacja                 = $dc.Site
                Zablokowane             = [bool]$u.LockedOut
                "Błędne hasła"          = $u.badPwdCount
                "Ostatnie błędne hasło" = $u.LastBadPasswordAttempt
                "Zablokowano"           = $lockout
                "Hasło ustawione"       = $u.PasswordLastSet
                PDC                     = ($dc.OperationMasterRoles -contains "PDCEmulator")
                __flag                  = if ($u.LockedOut) { "crit" } elseif ($u.badPwdCount -gt 0) { "warn" } else { "" }
            }
        }
        catch {
            [PSCustomObject]@{ Kontroler = $dc.HostName; Lokacja = $dc.Site; Zablokowane = $null; "Błędne hasła" = $null; Status = "Błąd"; Szczegóły = $_.Exception.Message; __flag = "muted" }
        }
    }
}

# Źródło blokad konta: zdarzenia 4740 z dziennika Security emulatora PDC (wymaga uprawnień do odczytu dziennika)
function Get-HTADLockoutEvents {
    param (
        [string[]]$SamAccountName = @(),
        [ValidateRange(1, 720)][int]$Hours = 24
    )
    $pdc = (Get-ADDomain -ErrorAction Stop).PDCEmulator
    $filter = @{ LogName = "Security"; Id = 4740; StartTime = (Get-Date).AddHours(-$Hours) }
    $events = @()
    try { $events = @(Get-WinEvent -ComputerName $pdc -FilterHashtable $filter -ErrorAction Stop) }
    catch {
        if ("$($_.Exception.Message)" -match 'No events were found|Nie znaleziono') { return @() }
        throw
    }
    $names = @($SamAccountName | ForEach-Object { $_.ToLowerInvariant() })
    foreach ($e in $events) {
        $user = "$($e.Properties[0].Value)"
        if ($names.Count -gt 0 -and $names -notcontains $user.ToLowerInvariant()) { continue }
        [PSCustomObject]@{
            Czas                 = $e.TimeCreated
            Użytkownik           = $user
            "Komputer źródłowy"  = "$($e.Properties[1].Value)"
            Kontroler            = $pdc
            __flag               = "warn"
        }
    }
}
#endregion

#region Raporty
# Raporty kont użytkowników
function Get-HTADUserReport {
    param (
        [Parameter(Mandatory)][ValidateSet("Inactive", "NeverLoggedOn", "PasswordExpiring", "PasswordExpired", "Locked", "Disabled", "PasswordNeverExpires", "AccountExpiring")][string]$Type,
        [ValidateRange(1, 3650)][int]$Days = 90
    )
    $properties = "DisplayName", "Enabled", "LockedOut", "LastLogonDate", "WhenCreated", "Department", "Title", "EmailAddress", "PasswordLastSet", "PasswordNeverExpires", "PasswordExpired", "AccountExpirationDate", "msDS-UserPasswordExpiryTimeComputed", "LastBadPasswordAttempt"
    $users = switch ($Type) {
        "Locked" { @(Search-ADAccount -LockedOut -UsersOnly -ErrorAction Stop | ForEach-Object { Get-ADUser -Identity $_.ObjectGUID -Properties $properties }) }
        "Disabled" { @(Get-ADUser -Filter "Enabled -eq `$false" -Properties $properties -ErrorAction Stop) }
        "PasswordNeverExpires" { @(Get-ADUser -Filter "PasswordNeverExpires -eq `$true" -Properties $properties -ErrorAction Stop) }
        "AccountExpiring" { @(Search-ADAccount -AccountExpiring -TimeSpan (New-TimeSpan -Days $Days) -UsersOnly -ErrorAction Stop | ForEach-Object { Get-ADUser -Identity $_.ObjectGUID -Properties $properties }) }
        default { @(Get-ADUser -Filter "Enabled -eq `$true" -Properties $properties -ErrorAction Stop) }
    }
    $now = Get-Date
    foreach ($u in $users) {
        $lastLogonDays = Get-HTDaysSince $u.LastLogonDate
        $expiry = $null
        $raw = $u."msDS-UserPasswordExpiryTimeComputed"
        if ($raw -and $raw -gt 0 -and $raw -lt [int64]::MaxValue) { try { $expiry = [datetime]::FromFileTime([int64]$raw) } catch { $expiry = $null } }
        $include = switch ($Type) {
            "Inactive" { ($null -ne $lastLogonDays -and $lastLogonDays -ge $Days) -or ($null -eq $lastLogonDays -and (Get-HTDaysSince $u.WhenCreated) -ge $Days) }
            "NeverLoggedOn" { $null -eq $u.LastLogonDate }
            "PasswordExpiring" { -not $u.PasswordNeverExpires -and $expiry -and $expiry -gt $now -and $expiry -le $now.AddDays($Days) }
            "PasswordExpired" { -not $u.PasswordNeverExpires -and (($expiry -and $expiry -le $now) -or $u.PasswordExpired) }
            default { $true }
        }
        if (-not $include) { continue }
        $flag = switch ($Type) {
            "PasswordExpiring" { if ($expiry -le $now.AddDays(3)) { "crit" } else { "warn" } }
            "Locked" { "crit" }
            "Disabled" { "muted" }
            default { "" }
        }
        [PSCustomObject]@{
            Nazwa                  = if ($u.DisplayName) { $u.DisplayName } else { $u.Name }
            Login                  = $u.SamAccountName
            UPN                    = $u.UserPrincipalName
            Włączone               = [bool]$u.Enabled
            Dział                  = $u.Department
            "Ostatnie logowanie"   = $u.LastLogonDate
            "Dni bez logowania"    = if ($null -ne $lastLogonDays) { $lastLogonDays } else { "nigdy" }
            "Hasło ustawione"      = $u.PasswordLastSet
            "Hasło wygasa"         = if ($u.PasswordNeverExpires) { "nigdy" } else { $expiry }
            "Konto wygasa"         = $u.AccountExpirationDate
            "Ostatnie błędne hasło" = $u.LastBadPasswordAttempt
            Utworzono              = $u.WhenCreated
            OU                     = ($u.DistinguishedName -replace '^CN=(?:[^,\\]|\\.)+,', '')
            "E-mail"               = $u.EmailAddress
            ObjectGUID             = $u.ObjectGUID
            __flag                 = $flag
        }
    }
}

# Raporty komputerów
function Get-HTADComputerReport {
    param (
        [Parameter(Mandatory)][ValidateSet("Inactive", "Disabled", "OperatingSystems", "All")][string]$Type,
        [ValidateRange(1, 3650)][int]$Days = 90
    )
    $computers = @(Get-ADComputer -Filter * -Properties OperatingSystem, OperatingSystemVersion, LastLogonDate, WhenCreated, Description, Enabled, IPv4Address -ErrorAction Stop)
    if ($Type -eq "OperatingSystems") {
        return @($computers | Where-Object { $_.Enabled } | Group-Object { "$($_.OperatingSystem) $($_.OperatingSystemVersion)".Trim() } | Sort-Object Count -Descending | ForEach-Object {
                $active = @($_.Group | Where-Object { (Get-HTDaysSince $_.LastLogonDate) -lt $Days -and $null -ne $_.LastLogonDate }).Count
                [PSCustomObject]@{
                    System               = if ($_.Name) { $_.Name } else { "(nieznany)" }
                    Komputery            = $_.Count
                    "Aktywne ($Days dni)" = $active
                    __flag               = if ($_.Name -match 'Windows (7|8|XP|Vista)|Server 20(03|08|12)') { "crit" } else { "" }
                }
            })
    }
    foreach ($c in $computers) {
        $daysSince = Get-HTDaysSince $c.LastLogonDate
        $include = switch ($Type) {
            "Inactive" { $c.Enabled -and (($null -ne $daysSince -and $daysSince -ge $Days) -or ($null -eq $daysSince -and (Get-HTDaysSince $c.WhenCreated) -ge $Days)) }
            "Disabled" { -not $c.Enabled }
            default { $true }
        }
        if (-not $include) { continue }
        [PSCustomObject]@{
            Nazwa                = $c.Name
            System               = $c.OperatingSystem
            Wersja               = $c.OperatingSystemVersion
            Włączone             = [bool]$c.Enabled
            "Ostatnie logowanie" = $c.LastLogonDate
            "Dni bez logowania"  = if ($null -ne $daysSince) { $daysSince } else { "nigdy" }
            "Adres IPv4"         = $c.IPv4Address
            Opis                 = $c.Description
            Utworzono            = $c.WhenCreated
            OU                   = ($c.DistinguishedName -replace '^CN=(?:[^,\\]|\\.)+,', '')
            ObjectGUID           = $c.ObjectGUID
            __flag               = if (-not $c.Enabled) { "muted" } elseif ($Type -eq "Inactive") { "warn" } else { "" }
        }
    }
}

# Grupy bez członków
function Get-HTADEmptyGroups {
    foreach ($g in @(Get-ADGroup -Filter * -Properties Members, Description, WhenCreated, WhenChanged, isCriticalSystemObject -ErrorAction Stop)) {
        if (@($g.Members).Count -gt 0) { continue }
        [PSCustomObject]@{
            Nazwa       = $g.Name
            Typ         = "$($g.GroupCategory)"
            Zakres      = "$($g.GroupScope)"
            Opis        = $g.Description
            Utworzono   = $g.WhenCreated
            Zmieniono   = $g.WhenChanged
            Systemowa   = [bool]$g.isCriticalSystemObject
            OU          = ($g.DistinguishedName -replace '^CN=(?:[^,\\]|\\.)+,', '')
            ObjectGUID  = $g.ObjectGUID
            __flag      = if ($g.isCriticalSystemObject) { "muted" } else { "" }
        }
    }
}
#endregion

#region Komputery zdalne (CIM / WinRM)
function New-HTCimSession {
    param ([Parameter(Mandatory)][string]$ComputerName)
    try { return New-CimSession -ComputerName $ComputerName -OperationTimeoutSec 15 -ErrorAction Stop }
    catch {
        $options = New-CimSessionOption -Protocol Dcom
        return New-CimSession -ComputerName $ComputerName -SessionOption $options -OperationTimeoutSec 15 -ErrorAction Stop
    }
}

# Informacje o systemie, sprzęcie i dyskach komputera zdalnego
function Get-HTComputerSystemInfo {
    param ([Parameter(Mandatory)][string]$ComputerName)
    $session = New-HTCimSession -ComputerName $ComputerName
    try {
        $os = Get-CimInstance -CimSession $session -ClassName Win32_OperatingSystem -ErrorAction Stop
        $cs = Get-CimInstance -CimSession $session -ClassName Win32_ComputerSystem -ErrorAction Stop
        $bios = Get-CimInstance -CimSession $session -ClassName Win32_BIOS -ErrorAction SilentlyContinue
        $disks = @(Get-CimInstance -CimSession $session -ClassName Win32_LogicalDisk -Filter "DriveType = 3" -ErrorAction SilentlyContinue)
        $uptime = (Get-Date) - $os.LastBootUpTime
        return [ordered]@{
            "Komputer"            = $cs.Name
            "System"              = "$($os.Caption) ($($os.Version), kompilacja $($os.BuildNumber))"
            "Zalogowany użytkownik" = $cs.UserName
            "Ostatni rozruch"     = $os.LastBootUpTime
            "Czas pracy"          = "{0} d {1} h {2} min" -f $uptime.Days, $uptime.Hours, $uptime.Minutes
            "Sprzęt"              = [ordered]@{
                "Producent"       = $cs.Manufacturer
                "Model"           = $cs.Model
                "Numer seryjny"   = $bios.SerialNumber
                "BIOS"            = $bios.SMBIOSBIOSVersion
                "Pamięć RAM"      = Format-HTBytes $cs.TotalPhysicalMemory
                "Wolna pamięć"    = Format-HTBytes ([int64]$os.FreePhysicalMemory * 1KB)
                "Domena"          = $cs.Domain
            }
            "Dyski"               = [ordered]@{
                "Woluminy"        = @($disks | ForEach-Object {
                        $free = if ($_.Size) { [Math]::Round(100 * $_.FreeSpace / $_.Size) } else { 0 }
                        "$($_.DeviceID) wolne $(Format-HTBytes $_.FreeSpace) z $(Format-HTBytes $_.Size) ($free%)"
                    })
            }
        }
    }
    finally { Remove-CimSession -CimSession $session -ErrorAction SilentlyContinue }
}

# Użytkownicy zalogowani na komputerze (konsola + sesje zdalne - właściciele procesów explorer.exe)
function Get-HTLoggedOnUsers {
    param ([Parameter(Mandatory)][string]$ComputerName)
    $session = New-HTCimSession -ComputerName $ComputerName
    try {
        $console = (Get-CimInstance -CimSession $session -ClassName Win32_ComputerSystem -ErrorAction Stop).UserName
        $users = New-Object System.Collections.Generic.List[string]
        if ($console) { $users.Add("$console (konsola)") }
        foreach ($process in @(Get-CimInstance -CimSession $session -ClassName Win32_Process -Filter "Name = 'explorer.exe'" -ErrorAction SilentlyContinue)) {
            $owner = Invoke-CimMethod -InputObject $process -MethodName GetOwner -ErrorAction SilentlyContinue
            if ($owner -and $owner.User) {
                $name = "$($owner.Domain)\$($owner.User)"
                if (-not ($users | Where-Object { $_ -like "$name*" })) { $users.Add($name) }
            }
        }
        return $users.ToArray()
    }
    finally { Remove-CimSession -CimSession $session -ErrorAction SilentlyContinue }
}
#endregion

#region Synchronizacja Microsoft Entra Connect
# Uruchamia cykl synchronizacji na serwerze Entra Connect (wymaga WinRM i uprawnień administratora na serwerze)
function Start-HTEntraConnectSync {
    param (
        [Parameter(Mandatory)][string]$Server,
        [ValidateSet("Delta", "Initial")][string]$PolicyType = "Delta"
    )
    $result = Invoke-Command -ComputerName $Server -ErrorAction Stop -ScriptBlock {
        param($Policy)
        Import-Module ADSync -ErrorAction Stop
        $scheduler = Get-ADSyncScheduler
        if ($scheduler.SyncCycleInProgress) { return "Synchronizacja jest już w toku." }
        $r = Start-ADSyncSyncCycle -PolicyType $Policy
        return "$($r.Result)"
    } -ArgumentList $PolicyType
    return "$result"
}
#endregion
