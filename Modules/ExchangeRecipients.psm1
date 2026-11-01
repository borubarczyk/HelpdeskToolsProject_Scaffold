# Obiekty Exchange Online: nowe skrzynki współdzielone, sale i zasoby (z uprawnieniami i miejscem), listy sal,
# grupy dystrybucyjne (tworzenie, usuwanie), grupy dynamiczne z podglądem członków, kontakty pocztowe, uprawnienia
# do dowolnych folderów skrzynki (z podfolderami i widocznością folderów nadrzędnych), kopiowanie dostępu użytkownika
# (np. dla następcy) i adres główny skrzynki. Moduł nie zależy od interfejsu.

#region Pomocnicze
function Invoke-HTWithRetry {
    # Ponawia operację, gdy świeżo utworzony obiekt nie jest jeszcze widoczny (replikacja Exchange trwa do minuty)
    param ([Parameter(Mandatory)][scriptblock]$Action, [int]$Attempts = 6, [int]$DelaySeconds = 5)
    $i = 0
    while ($true) {
        $i++
        try { return (& $Action) }
        catch {
            $text = $_.Exception.Message
            if ($i -ge $Attempts -or $text -notmatch "couldn't be found|could not be found|wasn't found|isn't found|not found|nie można odnaleźć|nie znaleziono|ManagementObjectNotFound") { throw }
            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

function ConvertTo-HTMailboxAlias {
    # Alias z nazwy: bez polskich znaków, małe litery, odstępy i znaki specjalne -> kropka («Biuro Zarządu - Łódź» -> biuro.zarzadu.lodz)
    param ([AllowEmptyString()][AllowNull()][string]$Name)
    $ascii = (ConvertTo-HTAsciiName ([string]$Name)).ToLowerInvariant()
    return (($ascii -replace '[^a-z0-9]+', '.').Trim('.'))
}

function ConvertFrom-HTNewMailboxLines {
    <#
        Linie «Nazwa wyświetlana; adres e-mail» (adres opcjonalny - z nazwy i -Domain). Zwraca wpisy
        @{ DisplayName; Address; Alias; Errors; Valid }. -Domains - domeny akceptowane (sprawdzenie domeny adresu).
    #>
    param ([AllowEmptyString()][AllowNull()][string]$Text, [string]$Domain = '', [AllowEmptyCollection()][string[]]$Domains = @())
    $seen = New-Object System.Collections.Generic.List[string]
    foreach ($line in @(([string]$Text) -split "`r?`n")) {
        $line = $line.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        $parts = @($line -split '[;\t]' | ForEach-Object { $_.Trim() })
        $name = $parts[0]
        $address = if ($parts.Count -gt 1) { $parts[1] } else { '' }
        $errors = New-Object System.Collections.Generic.List[string]
        if (-not $name) { $errors.Add('brak nazwy') }
        if (-not $address) {
            $alias = ConvertTo-HTMailboxAlias $name
            if (-not $alias) { $errors.Add('nie można utworzyć adresu z nazwy - podaj adres') }
            elseif (-not $Domain) { $errors.Add('brak domeny - podaj adres albo wybierz domenę') }
            else { $address = "$alias@$Domain" }
        }
        $address = $address.ToLowerInvariant()
        if ($address -and -not (Test-HTInputValue -Value $address -ValidationType Email)) { $errors.Add("nieprawidłowy adres $address") }
        elseif ($address -and @($Domains).Count -and @($Domains | Where-Object { $_ -ieq (($address -split '@')[-1]) }).Count -eq 0) { $errors.Add("domena $(($address -split '@')[-1]) nie jest domeną akceptowaną") }
        if ($address -and $seen.Contains($address)) { $errors.Add('adres powtarza się na liście') }
        if ($address) { $seen.Add($address) }
        @{ DisplayName = $name; Address = $address; Alias = $(if ($address) { ($address -split '@')[0] } else { '' }); Errors = $errors.ToArray(); Valid = ($errors.Count -eq 0) }
    }
}

function Get-HTAcceptedDomainNames {
    # Domeny akceptowane (domyślna pierwsza)
    return @(Get-AcceptedDomain -ErrorAction Stop | Sort-Object @{ Expression = { -not $_.Default } }, DomainName | ForEach-Object { [string]$_.DomainName })
}
#endregion

#region Nowe skrzynki współdzielone, sale i zasoby
function New-HTResourceMailbox {
    # Nowa skrzynka współdzielona (Shared), sala (Room) albo zasób (Equipment); zwraca adres główny
    param (
        [Parameter(Mandatory)][ValidateSet('Shared', 'Room', 'Equipment')][string]$Type,
        [Parameter(Mandatory)][string]$DisplayName,
        [Parameter(Mandatory)][string]$Address,
        [string]$Alias = '',
        [int]$Capacity = 0
    )
    $name = if ($DisplayName.Length -gt 64) { $DisplayName.Substring(0, 64) } else { $DisplayName }
    $params = @{ Name = $name; DisplayName = $DisplayName; Alias = $(if ($Alias) { $Alias } else { ($Address -split '@')[0] }); PrimarySmtpAddress = $Address; ErrorAction = 'Stop' }
    switch ($Type) {
        'Shared' { $params.Shared = $true }
        'Room' { $params.Room = $true; if ($Capacity -gt 0) { $params.ResourceCapacity = $Capacity } }
        'Equipment' { $params.Equipment = $true }
    }
    $mbx = New-Mailbox @params
    return [string]$mbx.PrimarySmtpAddress
}

function Set-HTNewMailboxSetup {
    <#
        Konfiguracja świeżo utworzonej skrzynki: pełny dostęp i «Wyślij jako» dla osób, kopie wiadomości wysłanych przez
        delegatów, ukrycie w GAL, dane miejsca sali (Set-Place: Capacity, Building, Floor, City…) i lista sal.
        Zwraca listę opisów (z błędami poszczególnych kroków - skrzynka już istnieje, więc kroki nie przerywają całości).
    #>
    param (
        [Parameter(Mandatory)][string]$Identity,
        [AllowEmptyCollection()][string[]]$FullAccess = @(),
        [AllowEmptyCollection()][string[]]$SendAs = @(),
        [bool]$AutoMapping = $true,
        [bool]$CopySent = $false,
        [bool]$Hidden = $false,
        [hashtable]$Place = @{},
        [string]$RoomList = ''
    )
    $notes = New-Object System.Collections.Generic.List[string]
    foreach ($u in @($FullAccess | Where-Object { $_ })) {
        try { Invoke-HTWithRetry { Add-MailboxPermission -Identity $Identity -User $u -AccessRights FullAccess -InheritanceType All -AutoMapping $AutoMapping -Confirm:$false -ErrorAction Stop | Out-Null }; $notes.Add("pełny dostęp: $u") }
        catch { $notes.Add("pełny dostęp $u - błąd: $($_.Exception.Message)") }
    }
    foreach ($u in @($SendAs | Where-Object { $_ })) {
        try { Invoke-HTWithRetry { Add-RecipientPermission -Identity $Identity -Trustee $u -AccessRights SendAs -Confirm:$false -ErrorAction Stop | Out-Null }; $notes.Add("wyślij jako: $u") }
        catch { $notes.Add("wyślij jako $u - błąd: $($_.Exception.Message)") }
    }
    $set = @{}
    if ($CopySent) { $set.MessageCopyForSentAsEnabled = $true; $set.MessageCopyForSendOnBehalfEnabled = $true }
    if ($Hidden) { $set.HiddenFromAddressListsEnabled = $true }
    if ($set.Count) {
        try { Invoke-HTWithRetry { Set-Mailbox -Identity $Identity @set -Confirm:$false -ErrorAction Stop }; $notes.Add("ustawienia: $(@($set.Keys) -join ', ')") }
        catch { $notes.Add("ustawienia - błąd: $($_.Exception.Message)") }
    }
    $placeParams = @{}
    foreach ($k in @($Place.Keys)) { if ($null -ne $Place[$k] -and "$($Place[$k])" -ne '') { $placeParams[$k] = $Place[$k] } }
    if ($placeParams.Count) {
        try { Invoke-HTWithRetry { Set-Place -Identity $Identity @placeParams -ErrorAction Stop }; $notes.Add("miejsce: $(@($placeParams.Keys) -join ', ')") }
        catch { $notes.Add("miejsce - błąd: $($_.Exception.Message)") }
    }
    if ($RoomList) {
        try { Invoke-HTWithRetry { Add-DistributionGroupMember -Identity $RoomList -Member $Identity -BypassSecurityGroupManagerCheck -Confirm:$false -ErrorAction Stop }; $notes.Add("lista sal: $RoomList") }
        catch { $notes.Add("lista sal - błąd: $($_.Exception.Message)") }
    }
    return $notes.ToArray()
}

function Get-HTRoomLists {
    return @(Get-DistributionGroup -RecipientTypeDetails RoomList -ResultSize Unlimited -ErrorAction Stop | ForEach-Object {
            [PSCustomObject]@{ Nazwa = $_.DisplayName; Adres = "$($_.PrimarySmtpAddress)"; Identity = "$($_.PrimarySmtpAddress)" }
        } | Sort-Object Nazwa)
}

function New-HTRoomList {
    param ([Parameter(Mandatory)][string]$DisplayName, [Parameter(Mandatory)][string]$Address)
    $g = New-DistributionGroup -RoomList -Name $DisplayName -DisplayName $DisplayName -Alias (($Address -split '@')[0]) -PrimarySmtpAddress $Address -ErrorAction Stop
    return [string]$g.PrimarySmtpAddress
}

function Set-HTMailboxPrimaryAddress {
    # Nowy adres główny skrzynki (poprzedni zostaje aliasem); skrzynki synchronizowane z AD - zmiana w AD
    param ([Parameter(Mandatory)][string]$Identity, [Parameter(Mandatory)][string]$Address)
    if (-not (Test-HTInputValue -Value $Address -ValidationType Email)) { throw "Nieprawidłowy adres e-mail: $Address" }
    Set-Mailbox -Identity $Identity -WindowsEmailAddress $Address -Confirm:$false -ErrorAction Stop
}
#endregion

#region Grupy dystrybucyjne
function New-HTMailDistributionGroup {
    <#
        Nowa grupa dystrybucyjna albo grupa zabezpieczeń z pocztą: właściciele, członkowie, tylko nadawcy wewnętrzni,
        dołączanie (Open / Closed / ApprovalRequired - grupy zabezpieczeń zawsze Closed), ukrycie w GAL. Zwraca adres.
    #>
    param (
        [Parameter(Mandatory)][string]$DisplayName,
        [Parameter(Mandatory)][string]$Address,
        [ValidateSet('Distribution', 'Security')][string]$Type = 'Distribution',
        [AllowEmptyCollection()][string[]]$Owners = @(),
        [AllowEmptyCollection()][string[]]$Members = @(),
        [bool]$InternalOnly = $true,
        [ValidateSet('Open', 'Closed', 'ApprovalRequired')][string]$JoinRestriction = 'Closed',
        [bool]$Hidden = $false
    )
    $name = if ($DisplayName.Length -gt 64) { $DisplayName.Substring(0, 64) } else { $DisplayName }
    $params = @{
        Name = $name; DisplayName = $DisplayName; Alias = ($Address -split '@')[0]; PrimarySmtpAddress = $Address; Type = $Type
        RequireSenderAuthenticationEnabled = $InternalOnly; ErrorAction = 'Stop'
    }
    if ($Type -eq 'Security') { $params.MemberJoinRestriction = 'Closed'; $params.MemberDepartRestriction = 'Closed' }
    else { $params.MemberJoinRestriction = $JoinRestriction }
    $owners = @($Owners | Where-Object { $_ })
    $members = @($Members | Where-Object { $_ })
    if ($owners.Count) { $params.ManagedBy = $owners }
    if ($members.Count) { $params.Members = $members }
    $g = New-DistributionGroup @params
    $address = [string]$g.PrimarySmtpAddress
    if ($Hidden) { Invoke-HTWithRetry { Set-DistributionGroup -Identity $address -HiddenFromAddressListsEnabled $true -BypassSecurityGroupManagerCheck -Confirm:$false -ErrorAction Stop } }
    return $address
}

function Remove-HTMailDistributionGroup {
    param ([Parameter(Mandatory)][string]$Identity)
    Remove-DistributionGroup -Identity $Identity -BypassSecurityGroupManagerCheck -Confirm:$false -ErrorAction Stop
}

function Add-HTDistributionGroupMembers {
    # Dodanie wielu członków (adresy); zwraca @{ Added; Errors }
    param ([Parameter(Mandatory)][string]$Group, [Parameter(Mandatory)][string[]]$Members)
    $added = 0
    $errors = New-Object System.Collections.Generic.List[string]
    foreach ($m in @($Members | Where-Object { $_ })) {
        try { Add-DistributionGroupMember -Identity $Group -Member $m -BypassSecurityGroupManagerCheck -Confirm:$false -ErrorAction Stop; $added++ }
        catch {
            if ($_.Exception.Message -match 'already a member|jest już członkiem|MemberAlreadyExists') { continue }
            $errors.Add("$($m): $($_.Exception.Message)")
        }
    }
    return @{ Added = $added; Errors = $errors.ToArray() }
}
#endregion

#region Grupy dynamiczne
function Get-HTDynamicGroups {
    return @(Get-DynamicDistributionGroup -ResultSize Unlimited -ErrorAction Stop | ForEach-Object {
            [PSCustomObject]@{
                Nazwa          = $_.DisplayName
                Adres          = "$($_.PrimarySmtpAddress)"
                Filtr          = [string]$_.RecipientFilter
                Właściciel     = [string]$_.ManagedBy
                'Ukryta w GAL' = [bool]$_.HiddenFromAddressListsEnabled
                Identity       = "$($_.PrimarySmtpAddress)"
            }
        } | Sort-Object Nazwa)
}

function Get-HTDynamicGroupMembers {
    # Członkowie grupy dynamicznej (Get-DynamicDistributionGroupMember, a w starszym module - podgląd filtra)
    param ([Parameter(Mandatory)][string]$Identity)
    $items = if (Get-Command -Name Get-DynamicDistributionGroupMember -ErrorAction SilentlyContinue) {
        @(Get-DynamicDistributionGroupMember -Identity $Identity -ResultSize Unlimited -ErrorAction Stop)
    }
    else {
        $g = Get-DynamicDistributionGroup -Identity $Identity -ErrorAction Stop
        @(Get-Recipient -RecipientPreviewFilter $g.RecipientFilter -ResultSize Unlimited -ErrorAction Stop)
    }
    return @($items | ForEach-Object { [PSCustomObject]@{ Nazwa = $_.DisplayName; Adres = "$($_.PrimarySmtpAddress)"; Typ = "$($_.RecipientTypeDetails)" } } | Sort-Object Nazwa)
}

$script:DynamicFilterProperties = [ordered]@{
    'Dział'                    = 'Department'
    'Firma'                    = 'Company'
    'Biuro'                    = 'Office'
    'Miasto'                   = 'City'
    'Stanowisko'               = 'Title'
    'Kraj'                     = 'CountryOrRegion'
    'Atrybut niestandardowy 1' = 'CustomAttribute1'
    'Atrybut niestandardowy 2' = 'CustomAttribute2'
    'Atrybut niestandardowy 3' = 'CustomAttribute3'
    'Województwo'              = 'StateOrProvince'
    'Kod pocztowy'             = 'PostalCode'
    'Ulica'                    = 'StreetAddress'
    'Telefon'                  = 'Phone'
    'Nazwa wyświetlana'        = 'DisplayName'
    'Alias'                    = 'Alias'
    'Adres e-mail'             = 'PrimarySmtpAddress'
    'Typ odbiorcy (szczegóły)' = 'RecipientTypeDetails'
}
foreach ($n in 4..15) { $script:DynamicFilterProperties["Atrybut niestandardowy $n"] = "CustomAttribute$n" }
$script:DynamicRecipientTypes = [ordered]@{
    'Skrzynki użytkowników'                                 = "RecipientTypeDetails -eq 'UserMailbox'"
    'Użytkownicy i kontakty'                                = "(RecipientTypeDetails -eq 'UserMailbox') -or (RecipientTypeDetails -eq 'MailContact') -or (RecipientTypeDetails -eq 'MailUser')"
    'Skrzynki współdzielone'                                = "RecipientTypeDetails -eq 'SharedMailbox'"
    'Wszystkie skrzynki (użytkowników, współdzielone, sale)' = "RecipientType -eq 'UserMailbox'"
    'Wszyscy odbiorcy'                                      = ''
}
# Operatory kreatora: klucz -> opis
$script:DynamicFilterOperators = [ordered]@{
    eq         = 'równa się'
    ne         = 'różne od'
    startswith = 'zaczyna się od'
    contains   = 'zawiera'
    endswith   = 'kończy się na'
    like       = 'pasuje do wzorca (*)'
    notlike    = 'nie pasuje do wzorca (*)'
    empty      = 'jest puste'
    notempty   = 'nie jest puste'
}

function Get-HTDynamicFilterOptions {
    return @{ Properties = @($script:DynamicFilterProperties.Keys); Types = @($script:DynamicRecipientTypes.Keys); Operators = $script:DynamicFilterOperators }
}

function ConvertTo-HTRecipientFilterCondition {
    # Jeden warunek OPATH: @{ Property (opis albo nazwa atrybutu); Operator (klucz); Value } -> «(Atrybut -op 'wartość')» albo ''
    param([Parameter(Mandatory)]$Condition)
    $prop = ([string]$Condition.Property).Trim()
    if ($script:DynamicFilterProperties.Contains($prop)) { $prop = $script:DynamicFilterProperties[$prop] }
    if (-not $prop) { return '' }
    if ($prop -notmatch '^[A-Za-z0-9]+$') { throw "Nieprawidłowa właściwość filtra: $prop" }
    $op = ([string]$Condition.Operator).Trim().ToLowerInvariant()
    $value = ([string]$Condition.Value).Trim()
    if ($op -eq 'empty') { return "($prop -eq `$null)" }
    if ($op -eq 'notempty') { return "($prop -ne `$null)" }
    if (-not $value) { return '' }
    $quote = { param($v) "'$($v.Replace("'", "''"))'" }
    switch ($op) {
        'ne' { return "($prop -ne $(& $quote $value))" }
        'startswith' { return "($prop -like $(& $quote "$($value.TrimEnd('*'))*"))" }
        'contains' { return "($prop -like $(& $quote "*$($value.Trim('*'))*"))" }
        'endswith' { return "($prop -like $(& $quote "*$($value.TrimStart('*'))"))" }
        'like' { return "($prop -like $(& $quote $value))" }
        'notlike' { return "($prop -notlike $(& $quote $value))" }
        default { if ($value.Contains('*')) { return "($prop -like $(& $quote $value))" } else { return "($prop -eq $(& $quote $value))" } }
    }
}

function ConvertTo-HTRecipientFilter {
    <#
        Filtr OPATH grupy dynamicznej z warunków: -Conditions @(@{ Property = 'Dział' albo 'Department'; Operator; Value })
        łączonych przez -Join and (wszystkie) albo or (dowolny), oraz rodzaju odbiorców (-RecipientType - klucz
        z Get-HTDynamicFilterOptions). Apostrofy w wartościach są podwajane. Bez operatora: wartość z * - -like, inaczej -eq.
    #>
    param ([AllowEmptyCollection()][object[]]$Conditions = @(), [string]$RecipientType = 'Skrzynki użytkowników', [ValidateSet('and', 'or')][string]$Join = 'and')
    $parts = New-Object System.Collections.Generic.List[string]
    $typeFilter = if ($script:DynamicRecipientTypes.Contains($RecipientType)) { $script:DynamicRecipientTypes[$RecipientType] } else { '' }
    if ($typeFilter) { $parts.Add("($typeFilter)") }
    $items = @(foreach ($c in @($Conditions | Where-Object { $_ })) { $x = ConvertTo-HTRecipientFilterCondition -Condition $c; if ($x) { $x } })
    if ($Join -eq 'or' -and $items.Count -gt 1) { $parts.Add("($($items -join ' -or '))") }
    else { foreach ($x in $items) { $parts.Add($x) } }
    # Bez skrzynek systemowych i ukrytych odbiorców grup (jak w filtrach domyślnych Exchange)
    $parts.Add("(-not(Name -like 'SystemMailbox{*'))")
    $parts.Add("(-not(Name -like 'CAS_{*'))")
    return ($parts -join ' -and ')
}

function ConvertFrom-HTRecipientFilter {
    <#
        Rozkład filtra OPATH na warunki kreatora: @{ Parsed; RecipientType; Join; Conditions = @(@{ Property; Operator; Value }) }.
        Pomija wykluczenia systemowe dodawane przez Exchange i program. Filtr złożony inaczej (np. zagnieżdżone -and / -or)
        - Parsed = $false (do edycji ręcznej).
    #>
    param([AllowEmptyString()][AllowNull()][string]$Filter)
    $result = [PSCustomObject]@{ Parsed = $false; RecipientType = 'Wszyscy odbiorcy'; Join = 'and'; Conditions = @() }
    $f = ([string]$Filter).Trim()
    $exclusion = "\(-not\((Name -like 'SystemMailbox\{\*'|Name -like 'CAS_\{\*'|RecipientTypeDetailsValue -eq '[A-Za-z]+')\)\)"
    $f = $f -replace "\s*-and\s*$exclusion", '' -replace "^$exclusion\s*-and\s*", '' -replace "^$exclusion$", ''
    $strip = {
        param([string]$t)
        while ($t.StartsWith('(') -and $t.EndsWith(')')) {
            $depth = 0; $closesAtEnd = $true
            for ($i = 0; $i -lt $t.Length; $i++) {
                if ($t[$i] -eq '(') { $depth++ } elseif ($t[$i] -eq ')') { $depth--; if ($depth -eq 0 -and $i -lt $t.Length - 1) { $closesAtEnd = $false; break } }
            }
            if (-not $closesAtEnd) { break }
            $t = $t.Substring(1, $t.Length - 2).Trim()
        }
        return $t
    }
    $f = & $strip $f
    foreach ($k in @($script:DynamicRecipientTypes.Keys | Sort-Object { $script:DynamicRecipientTypes[$_].Length } -Descending)) {
        $t = $script:DynamicRecipientTypes[$k]
        if (-not $t) { continue }
        if ($f -eq $t -or $f -eq "($t)") { $result.RecipientType = $k; $f = ''; break }
        if ($f.StartsWith("($t) -and ")) { $result.RecipientType = $k; $f = $f.Substring("($t) -and ".Length).Trim(); break }
    }
    $f = & $strip $f
    if (-not $f) { $result.Parsed = $true; return $result }
    $atom = "\((?<p>[A-Za-z0-9]+) (?<op>-eq|-ne|-like|-notlike) (?<v>'(?:[^']|'')*'|\`$null)\)"
    $tokens = [regex]::Matches($f, "$atom|\s+-(?<j>and|or)\s+")
    $rebuilt = -join @($tokens | ForEach-Object { $_.Value })
    if ($rebuilt -ne $f) { return $result }
    $joins = @($tokens | Where-Object { $_.Groups['j'].Success } | ForEach-Object { $_.Groups['j'].Value } | Select-Object -Unique)
    if ($joins.Count -gt 1) { return $result }
    if ($joins.Count -eq 1) { $result.Join = $joins[0] }
    $labels = @{}
    foreach ($k in $script:DynamicFilterProperties.Keys) { $labels[$script:DynamicFilterProperties[$k]] = $k }
    $result.Conditions = @(foreach ($m in @($tokens | Where-Object { $_.Groups['p'].Success })) {
            $prop = $m.Groups['p'].Value
            $rawValue = $m.Groups['v'].Value
            $isNull = $rawValue -eq '$null'
            $value = if ($isNull) { '' } else { $rawValue.Substring(1, $rawValue.Length - 2).Replace("''", "'") }
            $op = switch ($m.Groups['op'].Value) {
                '-eq' { if ($isNull) { 'empty' } else { 'eq' } }
                '-ne' { if ($isNull) { 'notempty' } else { 'ne' } }
                '-notlike' { 'notlike' }
                default {
                    $inner = $value.Trim('*')
                    if ($inner.Contains('*')) { 'like' }
                    elseif ($value.StartsWith('*') -and $value.EndsWith('*') -and $value.Length -gt 1) { $value = $inner; 'contains' }
                    elseif ($value.EndsWith('*')) { $value = $inner; 'startswith' }
                    elseif ($value.StartsWith('*')) { $value = $inner; 'endswith' }
                    else { 'like' }
                }
            }
            [PSCustomObject]@{ Property = $(if ($labels.ContainsKey($prop)) { $labels[$prop] } else { $prop }); Operator = $op; Value = $value }
        })
    $result.Parsed = $true
    return $result
}

function Get-HTRecipientFilterPreview {
    # Test filtra przed zapisem: odbiorcy, którzy trafią do grupy (najwyżej -Max; More - jest ich więcej)
    param([Parameter(Mandatory)][string]$Filter, [int]$Max = 200)
    $items = @(Get-Recipient -RecipientPreviewFilter $Filter -ResultSize ($Max + 1) -ErrorAction Stop)
    return [PSCustomObject]@{
        Items = @($items | Select-Object -First $Max | ForEach-Object { [PSCustomObject]@{ Nazwa = $_.DisplayName; Adres = "$($_.PrimarySmtpAddress)"; Typ = "$($_.RecipientTypeDetails)" } } | Sort-Object Nazwa)
        More  = ($items.Count -gt $Max)
    }
}

function New-HTDynamicGroup {
    param ([Parameter(Mandatory)][string]$DisplayName, [Parameter(Mandatory)][string]$Address, [Parameter(Mandatory)][string]$Filter, [string]$Owner = '')
    $name = if ($DisplayName.Length -gt 64) { $DisplayName.Substring(0, 64) } else { $DisplayName }
    $params = @{ Name = $name; DisplayName = $DisplayName; Alias = ($Address -split '@')[0]; PrimarySmtpAddress = $Address; RecipientFilter = $Filter; ErrorAction = 'Stop' }
    $g = New-DynamicDistributionGroup @params
    if ($Owner) { Invoke-HTWithRetry { Set-DynamicDistributionGroup -Identity ([string]$g.PrimarySmtpAddress) -ManagedBy $Owner -Confirm:$false -ErrorAction Stop } }
    return [string]$g.PrimarySmtpAddress
}

function Set-HTDynamicGroupFilter {
    param ([Parameter(Mandatory)][string]$Identity, [Parameter(Mandatory)][string]$Filter)
    Set-DynamicDistributionGroup -Identity $Identity -RecipientFilter $Filter -Confirm:$false -ErrorAction Stop
}

function Remove-HTDynamicGroup {
    param ([Parameter(Mandatory)][string]$Identity)
    Remove-DynamicDistributionGroup -Identity $Identity -Confirm:$false -ErrorAction Stop
}
#endregion

#region Kontakty pocztowe (zewnętrzni odbiorcy w książce adresowej)
function Get-HTMailContacts {
    $details = @{}
    try { foreach ($c in @(Get-Contact -RecipientTypeDetails MailContact -ResultSize Unlimited -ErrorAction Stop)) { $details[[string]$c.Guid] = $c } }
    catch { Write-Log -Message "Dane kontaktów (firma, telefon): $($_.Exception.Message)" -Type 'Warn' }
    return @(Get-MailContact -ResultSize Unlimited -ErrorAction Stop | ForEach-Object {
            $d = $details[[string]$_.Guid]
            [PSCustomObject]@{
                Nazwa          = $_.DisplayName
                'Adres e-mail' = ([string]$_.ExternalEmailAddress -replace '^(?i)smtp:', '')
                Firma          = $(if ($d) { $d.Company } else { '' })
                Stanowisko     = $(if ($d) { $d.Title } else { '' })
                Telefon        = $(if ($d) { $d.Phone } else { '' })
                'Ukryty w GAL' = [bool]$_.HiddenFromAddressListsEnabled
                Synchronizowany = [bool]$_.IsDirSynced
                Identity       = [string]$_.Guid
                __flag         = $(if ($_.HiddenFromAddressListsEnabled) { 'muted' } else { '' })
            }
        } | Sort-Object Nazwa)
}

function ConvertFrom-HTContactLines {
    # Linie «Nazwa; e-mail; firma; telefon» (pola po nazwie i adresie opcjonalne) -> @{ DisplayName; Email; Company; Phone; Errors; Valid }
    param ([AllowEmptyString()][AllowNull()][string]$Text)
    $seen = New-Object System.Collections.Generic.List[string]
    foreach ($line in @(([string]$Text) -split "`r?`n")) {
        $line = $line.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        $p = @($line -split '[;\t]' | ForEach-Object { $_.Trim() })
        $errors = New-Object System.Collections.Generic.List[string]
        $name = $p[0]
        $email = if ($p.Count -gt 1) { $p[1].ToLowerInvariant() } else { '' }
        if (-not $name) { $errors.Add('brak nazwy') }
        if (-not $email) { $errors.Add('brak adresu e-mail') }
        elseif (-not (Test-HTInputValue -Value $email -ValidationType Email)) { $errors.Add("nieprawidłowy adres $email") }
        elseif ($seen.Contains($email)) { $errors.Add('adres powtarza się na liście') }
        if ($email) { $seen.Add($email) }
        @{ DisplayName = $name; Email = $email; Company = $(if ($p.Count -gt 2) { $p[2] } else { '' }); Phone = $(if ($p.Count -gt 3) { $p[3] } else { '' }); Errors = $errors.ToArray(); Valid = ($errors.Count -eq 0) }
    }
}

function New-HTMailContact {
    # Nowy kontakt pocztowy; imię i nazwisko z nazwy wyświetlanej (pierwszy wyraz - imię). Zwraca identyfikator (Guid).
    param (
        [Parameter(Mandatory)][string]$DisplayName,
        [Parameter(Mandatory)][string]$Email,
        [string]$Company = '',
        [string]$Phone = '',
        [string]$Title = '',
        [bool]$Hidden = $false
    )
    $words = @($DisplayName.Trim() -split '\s+')
    $params = @{ Name = $(if ($DisplayName.Length -gt 64) { $DisplayName.Substring(0, 64) } else { $DisplayName }); DisplayName = $DisplayName; ExternalEmailAddress = $Email; ErrorAction = 'Stop' }
    if ($words.Count -gt 1) { $params.FirstName = $words[0]; $params.LastName = ($words | Select-Object -Skip 1) -join ' ' }
    $contact = New-MailContact @params
    $id = [string]$contact.Guid
    $extra = @{}
    if ($Company) { $extra.Company = $Company }
    if ($Phone) { $extra.Phone = $Phone }
    if ($Title) { $extra.Title = $Title }
    if ($extra.Count) { Invoke-HTWithRetry { Set-Contact -Identity $id @extra -Confirm:$false -ErrorAction Stop } }
    if ($Hidden) { Invoke-HTWithRetry { Set-MailContact -Identity $id -HiddenFromAddressListsEnabled $true -Confirm:$false -ErrorAction Stop } }
    return $id
}

function Set-HTMailContactDetails {
    # Zmiana danych kontaktu - tylko podane (niepuste) wartości; «-» czyści firmę, stanowisko i telefon
    param ([Parameter(Mandatory)][string]$Identity, [string]$DisplayName = '', [string]$Email = '', [string]$Company = '', [string]$Phone = '', [string]$Title = '')
    $mail = @{}
    if ($DisplayName) { $mail.DisplayName = $DisplayName }
    if ($Email) {
        if (-not (Test-HTInputValue -Value $Email -ValidationType Email)) { throw "Nieprawidłowy adres e-mail: $Email" }
        $mail.ExternalEmailAddress = $Email
    }
    if ($mail.Count) { Set-MailContact -Identity $Identity @mail -Confirm:$false -ErrorAction Stop }
    $contact = @{}
    foreach ($pair in @(@('Company', $Company), @('Phone', $Phone), @('Title', $Title))) {
        if (-not $pair[1]) { continue }
        $contact[$pair[0]] = if ($pair[1] -eq '-') { $null } else { $pair[1] }
    }
    if ($contact.Count) { Set-Contact -Identity $Identity @contact -Confirm:$false -ErrorAction Stop }
}

function Set-HTMailContactHidden {
    param ([Parameter(Mandatory)][string]$Identity, [Parameter(Mandatory)][bool]$Hidden)
    Set-MailContact -Identity $Identity -HiddenFromAddressListsEnabled $Hidden -Confirm:$false -ErrorAction Stop
}

function Remove-HTMailContact {
    param ([Parameter(Mandatory)][string]$Identity)
    Remove-MailContact -Identity $Identity -Confirm:$false -ErrorAction Stop
}
#endregion

#region Uprawnienia do folderów skrzynki
$script:FolderAccessRights = @('Reviewer', 'Author', 'NonEditingAuthor', 'Editor', 'PublishingEditor', 'PublishingAuthor', 'Contributor', 'Owner', 'FolderVisible', 'None')
$script:SystemFolderTypes = @('RecoverableItemsRoot', 'RecoverableItemsDeletions', 'RecoverableItemsPurges', 'RecoverableItemsVersions', 'Audits', 'CalendarLogging', 'SyncIssues', 'Conflicts', 'LocalFailures', 'ServerFailures', 'RecoverableItemsSubstrateHolds', 'RecoverableItemsDiscoveryHolds', 'RecoverableItemsMigratedMessages')

function Get-HTFolderAccessRights { return $script:FolderAccessRights }

function Get-HTFolderAncestors {
    # Foldery nadrzędne ścieżki (od głównego «\»): \Inbox\Faktury\2025 -> \, \Inbox, \Inbox\Faktury
    param ([Parameter(Mandatory)][string]$Path)
    $parts = @($Path.Trim('\') -split '\\' | Where-Object { $_ })
    $result = New-Object System.Collections.Generic.List[string]
    $result.Add('\')
    for ($i = 1; $i -lt $parts.Count; $i++) { $result.Add('\' + (($parts | Select-Object -First $i) -join '\')) }
    if ($parts.Count -eq 0) { return @() }
    return $result.ToArray()
}

function Get-HTSubfolderPaths {
    # Podfoldery (na każdym poziomie) ścieżki spośród -AllPaths
    param ([Parameter(Mandatory)][string]$Path, [AllowEmptyCollection()][string[]]$AllPaths = @())
    $prefix = if ($Path -eq '\') { '\' } else { $Path.TrimEnd('\') + '\' }
    return @($AllPaths | Where-Object { $_ -ne $Path -and $_.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) })
}

function Get-HTMailboxFolders {
    # Foldery skrzynki (bez systemowych): ścieżka «\Inbox\Faktury», typ, liczba elementów, rozmiar
    param ([Parameter(Mandatory)][string]$Identity)
    foreach ($f in @(Get-EXOMailboxFolderStatistics -Identity $Identity -ErrorAction Stop)) {
        $type = [string]$f.FolderType
        if ($type -in $script:SystemFolderTypes) { continue }
        $path = if ($type -eq 'Root') { '\' } else { ([string]$f.FolderPath).Replace('/', '\') }
        if (-not $path) { continue }
        $size = [string]$f.FolderSize
        if ($size -match '^(.*?)\s*\(') { $size = $Matches[1].Trim() }
        [PSCustomObject]@{
            Folder       = $(if ($path -eq '\') { '\ (główny folder skrzynki)' } else { $path })
            Typ          = $type
            Elementy     = $f.ItemsInFolder
            Rozmiar      = $size
            Skrzynka     = $Identity
            __path       = $path
            __flag       = $(if ($type -eq 'User Created') { '' } else { 'muted' })
        }
    }
}

function Get-HTMailboxFolderIdentity {
    param ([Parameter(Mandatory)][string]$Mailbox, [Parameter(Mandatory)][string]$Path)
    if ($Path -eq '\') { return "$($Mailbox):\" }
    return "$($Mailbox):$Path"
}

function Get-HTMailboxFolderPermissionRows {
    param ([Parameter(Mandatory)][string]$Mailbox, [Parameter(Mandatory)][string]$Path)
    $id = Get-HTMailboxFolderIdentity -Mailbox $Mailbox -Path $Path
    return @(Get-EXOMailboxFolderPermission -Identity $id -ErrorAction Stop | ForEach-Object {
            [PSCustomObject]@{ Folder = $Path; Użytkownik = [string]$_.User; Prawa = (@($_.AccessRights) -join ', '); Delegat = [string]$_.SharingPermissionFlags }
        })
}

function Set-HTMailboxFolderAccess {
    # Nadanie albo zmiana uprawnień użytkownika do folderu (Add- albo Set-MailboxFolderPermission)
    param ([Parameter(Mandatory)][string]$FolderIdentity, [Parameter(Mandatory)][string]$User, [Parameter(Mandatory)][string]$AccessRights)
    $existing = $null
    try { $existing = @(Get-EXOMailboxFolderPermission -Identity $FolderIdentity -User $User -ErrorAction Stop)[0] } catch { $existing = $null }
    if ($existing) { Set-MailboxFolderPermission -Identity $FolderIdentity -User $User -AccessRights $AccessRights -Confirm:$false -ErrorAction Stop | Out-Null }
    else { Add-MailboxFolderPermission -Identity $FolderIdentity -User $User -AccessRights $AccessRights -Confirm:$false -ErrorAction Stop | Out-Null }
}

function Grant-HTMailboxFolderAccess {
    <#
        Uprawnienia użytkownika do folderów skrzynki. -IncludeSubfolders - także podfoldery (z -AllPaths),
        -ParentVisibility - «FolderVisible» na folderach nadrzędnych, na których użytkownik nie ma uprawnień
        (bez tego Outlook nie pokaże podfolderu). Zwraca listę opisów.
    #>
    param (
        [Parameter(Mandatory)][string]$Mailbox,
        [Parameter(Mandatory)][string[]]$Paths,
        [Parameter(Mandatory)][string]$User,
        [Parameter(Mandatory)][string]$AccessRights,
        [switch]$IncludeSubfolders,
        [AllowEmptyCollection()][string[]]$AllPaths = @(),
        [switch]$ParentVisibility
    )
    $targets = New-Object System.Collections.Generic.List[string]
    foreach ($p in $Paths) {
        if (-not $targets.Contains($p)) { $targets.Add($p) }
        if ($IncludeSubfolders) { foreach ($s in @(Get-HTSubfolderPaths -Path $p -AllPaths $AllPaths)) { if (-not $targets.Contains($s)) { $targets.Add($s) } } }
    }
    $notes = New-Object System.Collections.Generic.List[string]
    $failed = New-Object System.Collections.Generic.List[string]
    foreach ($t in $targets) {
        try { Set-HTMailboxFolderAccess -FolderIdentity (Get-HTMailboxFolderIdentity -Mailbox $Mailbox -Path $t) -User $User -AccessRights $AccessRights; $notes.Add("$t") }
        catch { $failed.Add("$($t): $($_.Exception.Message)") }
    }
    $visible = 0
    if ($ParentVisibility) {
        $parents = @($targets | ForEach-Object { Get-HTFolderAncestors -Path $_ } | Select-Object -Unique | Where-Object { -not $targets.Contains($_) })
        foreach ($p in $parents) {
            $id = Get-HTMailboxFolderIdentity -Mailbox $Mailbox -Path $p
            try {
                $existing = $null
                try { $existing = @(Get-EXOMailboxFolderPermission -Identity $id -User $User -ErrorAction Stop)[0] } catch { $existing = $null }
                if (-not $existing) { Add-MailboxFolderPermission -Identity $id -User $User -AccessRights FolderVisible -Confirm:$false -ErrorAction Stop | Out-Null; $visible++ }
            }
            catch { $failed.Add("widoczność $($p): $($_.Exception.Message)") }
        }
    }
    $text = "$AccessRights dla $User - folderów: $($notes.Count)$(if ($visible) { ", widoczność folderów nadrzędnych: $visible" })"
    if ($failed.Count) { throw "$text; błędy: $($failed -join '; ')" }
    return $text
}

function Revoke-HTMailboxFolderAccess {
    # Usunięcie uprawnień użytkownika do folderów (opcjonalnie z podfolderami); brak uprawnienia nie jest błędem
    param (
        [Parameter(Mandatory)][string]$Mailbox,
        [Parameter(Mandatory)][string[]]$Paths,
        [Parameter(Mandatory)][string]$User,
        [switch]$IncludeSubfolders,
        [AllowEmptyCollection()][string[]]$AllPaths = @()
    )
    $targets = New-Object System.Collections.Generic.List[string]
    foreach ($p in $Paths) {
        if (-not $targets.Contains($p)) { $targets.Add($p) }
        if ($IncludeSubfolders) { foreach ($s in @(Get-HTSubfolderPaths -Path $p -AllPaths $AllPaths)) { if (-not $targets.Contains($s)) { $targets.Add($s) } } }
    }
    $removed = 0
    $failed = New-Object System.Collections.Generic.List[string]
    foreach ($t in $targets) {
        $id = Get-HTMailboxFolderIdentity -Mailbox $Mailbox -Path $t
        try { Remove-MailboxFolderPermission -Identity $id -User $User -Confirm:$false -ErrorAction Stop; $removed++ }
        catch { if ($_.Exception.Message -notmatch "no existing permission|couldn't be found|not found|nie istnieje|UserNotFoundInPermissionEntry") { $failed.Add("$($t): $($_.Exception.Message)") } }
    }
    $text = "Odebrano uprawnienia $User - folderów: $removed"
    if ($failed.Count) { throw "$text; błędy: $($failed -join '; ')" }
    return $text
}
#endregion

#region Kopiowanie dostępu użytkownika (np. dla następcy) i odbieranie dostępu
function Get-HTUserAccessForCopy {
    <#
        Dostęp użytkownika do przeniesienia na inne osoby: pełny dostęp, wyślij jako, wyślij w imieniu, grupy (z -IncludeGroups)
        i kalendarze innych skrzynek (z -IncludeCalendars - przegląd wszystkich skrzynek, wolno).
        Wiersze: Rodzaj, Obiekt, Prawa, __kind (FullAccess|SendAs|SendOnBehalf|Group|M365Group|Calendar), __identity, __folder.
        OnProgress: { param($Index, $Total, $Name) }.
    #>
    param ([Parameter(Mandatory)][string]$User, [switch]$IncludeGroups, [switch]$IncludeCalendars, [scriptblock]$OnProgress)
    $names = @{ FullAccess = 'Pełny dostęp'; SendAs = 'Wyślij jako'; SendOnBehalf = 'Wyślij w imieniu' }
    foreach ($a in @(Get-HTUserMailboxAccess -User $User -OnProgress $OnProgress)) {
        [PSCustomObject]@{ Rodzaj = $names[[string]$a.Uprawnienie]; Obiekt = $(if ($a.Adres) { $a.Adres } else { $a.Skrzynka }); Nazwa = $a.Skrzynka; Prawa = $a.Uprawnienie; __kind = [string]$a.Uprawnienie; __identity = $(if ($a.Adres) { $a.Adres } else { $a.Skrzynka }); __folder = '' }
    }
    if ($IncludeGroups) {
        foreach ($g in @(Get-HTRecipientGroups -Identity $User)) {
            if ($g.Typ -eq 'RoomList') { continue }
            $kind = if ($g.Typ -eq 'GroupMailbox') { 'M365Group' } else { 'Group' }
            [PSCustomObject]@{ Rodzaj = $(if ($kind -eq 'M365Group') { 'Grupa Microsoft 365' } else { 'Grupa dystrybucyjna' }); Obiekt = $g.Adres; Nazwa = $g.Grupa; Prawa = 'członek'; __kind = $kind; __identity = $g.Adres; __folder = '' }
        }
    }
    if ($IncludeCalendars) {
        $mailboxes = @(Get-EXOMailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox, SharedMailbox, RoomMailbox, EquipmentMailbox -ErrorAction Stop)
        $i = 0
        foreach ($mbx in $mailboxes) {
            $i++
            if ($OnProgress) { & $OnProgress $i $mailboxes.Count "kalendarz: $($mbx.DisplayName)" }
            $address = [string]$mbx.PrimarySmtpAddress
            try {
                $folder = Get-HTCalendarFolderIdentity -Identity $address
                $perm = $null
                try { $perm = @(Get-EXOMailboxFolderPermission -Identity $folder -User $User -ErrorAction Stop)[0] } catch { $perm = $null }
                if ($perm) {
                    $rights = @($perm.AccessRights) -join ', '
                    [PSCustomObject]@{ Rodzaj = 'Kalendarz'; Obiekt = $address; Nazwa = $mbx.DisplayName; Prawa = $rights; __kind = 'Calendar'; __identity = $address; __folder = $folder }
                }
            }
            catch { Write-Log -Message "Kalendarz $($address): $($_.Exception.Message)" -Type 'Warn' }
        }
    }
}

function Copy-HTUserAccessItem {
    # Nadanie osobie -TargetUser dostępu z wiersza Get-HTUserAccessForCopy
    param ([Parameter(Mandatory)][object]$Item, [Parameter(Mandatory)][string]$TargetUser, [bool]$AutoMapping = $true)
    switch ([string]$Item.__kind) {
        'FullAccess' { Add-HTMailboxPermission -Identity $Item.__identity -User $TargetUser -Type FullAccess -AutoMapping $AutoMapping }
        'SendAs' { Add-HTMailboxPermission -Identity $Item.__identity -User $TargetUser -Type SendAs }
        'SendOnBehalf' { Add-HTMailboxPermission -Identity $Item.__identity -User $TargetUser -Type SendOnBehalf }
        'Group' {
            try { Add-DistributionGroupMember -Identity $Item.__identity -Member $TargetUser -BypassSecurityGroupManagerCheck -Confirm:$false -ErrorAction Stop }
            catch { if ($_.Exception.Message -notmatch 'already a member|jest już członkiem|MemberAlreadyExists') { throw } }
        }
        'M365Group' { Add-UnifiedGroupLinks -Identity $Item.__identity -LinkType Members -Links $TargetUser -Confirm:$false -ErrorAction Stop }
        'Calendar' { Set-HTMailboxFolderAccess -FolderIdentity $Item.__folder -User $TargetUser -AccessRights ((([string]$Item.Prawa) -split ',\s*')[0]) }
        default { throw "Nieznany rodzaj dostępu: $($Item.__kind)" }
    }
    return "$($Item.Rodzaj) $($Item.Obiekt) -> $TargetUser"
}

function Remove-HTUserAccessItem {
    # Odebranie użytkownikowi dostępu z wiersza Get-HTUserAccessForCopy (np. przy odejściu z firmy)
    param ([Parameter(Mandatory)][object]$Item, [Parameter(Mandatory)][string]$User)
    switch ([string]$Item.__kind) {
        { $_ -in 'FullAccess', 'SendAs', 'SendOnBehalf' } { Remove-HTMailboxPermission -Identity $Item.__identity -User $User -Type $Item.__kind }
        'Group' { Remove-DistributionGroupMember -Identity $Item.__identity -Member $User -BypassSecurityGroupManagerCheck -Confirm:$false -ErrorAction Stop }
        'M365Group' { Remove-UnifiedGroupLinks -Identity $Item.__identity -LinkType Members -Links $User -Confirm:$false -ErrorAction Stop }
        'Calendar' { Remove-MailboxFolderPermission -Identity $Item.__folder -User $User -Confirm:$false -ErrorAction Stop }
        default { throw "Nieznany rodzaj dostępu: $($Item.__kind)" }
    }
    return "Odebrano: $($Item.Rodzaj) $($Item.Obiekt)"
}
#endregion
