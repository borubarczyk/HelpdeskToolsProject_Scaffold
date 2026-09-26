# Funkcje dla lokalnego Active Directory (wymaga modułu ActiveDirectory z RSAT)
# Funkcje przyjmują parametry i zwracają dane - obsługa GUI znajduje się w GUI/Events/LocalADPanel_Events.ps1

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
            Get-ADUser -Filter * -Properties DisplayName, Enabled, LockedOut, Department, Title, LastLogonDate, EmailAddress |
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
            Get-ADGroup -Filter * -Properties Description, ManagedBy, WhenCreated |
                ForEach-Object {
                    [PSCustomObject]@{
                        Name              = $_.Name
                        SamAccountName    = $_.SamAccountName
                        GroupCategory     = "$($_.GroupCategory)"
                        GroupScope        = "$($_.GroupScope)"
                        Description       = $_.Description
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
