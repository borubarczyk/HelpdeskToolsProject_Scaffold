# Profile tenantów: zapamiętane ustawienia połączeń z tenantami klientów (GDAP) i własnymi - Microsoft Graph (tenant),
# Exchange Online (organizacja, konto partnera), SharePoint (adres witryny, Client ID aplikacji PnP w tenancie klienta).
# Moduł bez interfejsu: normalizacja, walidacja, import i eksport CSV, scalanie i wyszukiwanie. Profile są w konfiguracji
# (TenantProfiles) - bez haseł i kluczy.

$script:TenantServices = @('Graph', 'Exchange', 'SharePoint')
$script:TenantServiceNames = [ordered]@{ Graph = 'Microsoft 365'; Exchange = 'Exchange'; SharePoint = 'SharePoint' }
$script:GuidPattern = '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$'
$script:DomainPattern = '^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+$'

# Kolumny CSV: nagłówek (jak w programie) i akceptowane inne nazwy
$script:TenantCsvColumns = [ordered]@{
    Name           = @('Nazwa', 'Name', 'Profil', 'Klient', 'Firma')
    TenantId       = @('Tenant', 'TenantId', 'Tenant ID', 'ID tenantu', 'Domena', 'Domain')
    Organization   = @('Organizacja Exchange', 'Organization', 'Organizacja', 'Exchange', 'DelegatedOrganization')
    PartnerAccount = @('Konto partnera', 'PartnerAccount', 'Konto', 'UserPrincipalName', 'UPN')
    Gdap           = @('GDAP', 'Gdap', 'Partner')
    SharePointUrl  = @('SharePoint', 'SharePointUrl', 'Witryna', 'Adres SharePoint', 'Url')
    PnPClientId    = @('Client ID PnP', 'PnPClientId', 'ClientId', 'Client ID', 'Aplikacja PnP')
    Services       = @('Usługi', 'Uslugi', 'Services')
    Notes          = @('Notatki', 'Notes', 'Opis', 'Uwagi')
}

function Get-HTTenantServiceName {
    # Nazwa usługi w interfejsie (Graph -> Microsoft 365)
    param([string]$Service)
    if ($script:TenantServiceNames.Contains($Service)) { return $script:TenantServiceNames[$Service] }
    return $Service
}

function ConvertTo-HTTenantServiceList {
    # Lista usług z tekstu albo tablicy («Microsoft 365, Exchange», «Graph;PnP») - w kolejności Graph, Exchange, SharePoint
    param([AllowNull()][object]$Value)
    $items = @(foreach ($v in @($Value)) { [string]$v -split '[,;/|+\r\n]+' } )
    $found = @{}
    foreach ($item in $items) {
        $t = $item.Trim()
        if (-not $t) { continue }
        switch -Regex ($t) {
            '^(graph|microsoft ?365|m365|ms ?graph|entra|azure ?ad)$' { $found.Graph = $true; break }
            '^(exchange|exo|exchange ?online|poczta)$' { $found.Exchange = $true; break }
            '^(sharepoint|spo|pnp|pnp\.powershell|witryny)$' { $found.SharePoint = $true; break }
        }
    }
    return @($script:TenantServices | Where-Object { $found[$_] })
}

function ConvertTo-HTTenantBool {
    param([AllowNull()][object]$Value, [bool]$Default = $true)
    if ($Value -is [bool]) { return $Value }
    $t = ([string]$Value).Trim()
    if (-not $t) { return $Default }
    return ($t -match '^(tak|t|yes|y|true|1|prawda|gdap)$')
}

function Get-HTTenantSharePointSuggestion {
    # Adres SharePoint z domeny tenantu (klient.onmicrosoft.com -> https://klient.sharepoint.com); pusty, gdy nie da się ustalić
    param([AllowEmptyString()][string]$Domain)
    if (([string]$Domain).Trim() -match '^([A-Za-z0-9-]+)\.onmicrosoft\.com$') { return "https://$($matches[1].ToLowerInvariant()).sharepoint.com" }
    return ''
}

function ConvertTo-HTTenantSharePointUrl {
    # Adres witryny: dopisane https://, domena tenantu zamieniona na adres SharePoint, bez końcowego /
    param([AllowEmptyString()][string]$Url)
    $u = ([string]$Url).Trim()
    if (-not $u) { return '' }
    if ($u -notmatch '^[a-zA-Z][a-zA-Z0-9+.-]*://') { $u = "https://$u" }
    if ($u -match '^https?://([^./:]+)\.onmicrosoft\.com(/.*)?$') { $u = "https://$($matches[1]).sharepoint.com$($matches[2])" }
    return $u.TrimEnd('/')
}

function ConvertTo-HTTenantProfile {
    <#
        Profil w jednolitej postaci (także ze starszej konfiguracji: Name, TenantId, Organization, PartnerAccount, Gdap).
        Usługi domyślne, gdy nie podano: te, dla których profil ma dane.
    #>
    param([Parameter(Mandatory)][AllowNull()][object]$InputObject)
    if ($null -eq $InputObject) { return $null }
    $get = {
        param($name)
        if ($InputObject -is [System.Collections.IDictionary]) { if ($InputObject.Contains($name)) { return $InputObject[$name] } return $null }
        $p = $InputObject.PSObject.Properties[$name]
        if ($p) { return $p.Value }
        return $null
    }
    $tenant = ([string](& $get 'TenantId')).Trim()
    $org = ([string](& $get 'Organization')).Trim()
    $partner = ([string](& $get 'PartnerAccount')).Trim()
    $sp = ConvertTo-HTTenantSharePointUrl -Url ([string](& $get 'SharePointUrl'))
    $clientId = ([string](& $get 'PnPClientId')).Trim()
    $services = @(ConvertTo-HTTenantServiceList (& $get 'Services'))
    if ($services.Count -eq 0) {
        $services = @(
            if ($tenant -or $org) { 'Graph' }
            if ($org -or ($tenant -and -not $partner)) { 'Exchange' }
            if ($sp) { 'SharePoint' }
        )
    }
    $lastUsed = & $get 'LastUsed'
    return [PSCustomObject]@{
        Name           = ([string](& $get 'Name')).Trim()
        TenantId       = $tenant
        Organization   = $org
        PartnerAccount = $partner
        Gdap           = ConvertTo-HTTenantBool (& $get 'Gdap') -Default ([bool]$partner -or -not ($null -ne (& $get 'Gdap')))
        SharePointUrl  = $sp
        PnPClientId    = $clientId
        Services       = @($services)
        Notes          = ([string](& $get 'Notes')).Trim()
        LastUsed       = $(if ($lastUsed) { [string]$lastUsed } else { '' })
    }
}

function Test-HTTenantProfile {
    <#
        Błędy profilu (pusta lista - poprawny). -Existing: pozostałe profile (unikalna nazwa), -OriginalName: nazwa
        edytowanego profilu (może zostać ta sama).
    #>
    param([Parameter(Mandatory)]$TenantProfile, [object[]]$Existing = @(), [string]$OriginalName = '')
    $p = ConvertTo-HTTenantProfile $TenantProfile
    $errors = New-Object System.Collections.Generic.List[string]
    if (-not $p.Name) { $errors.Add('podaj nazwę profilu') }
    elseif (@($Existing | Where-Object { $_ -and ([string]$_.Name) -ieq $p.Name -and ([string]$_.Name) -ine $OriginalName }).Count) { $errors.Add("profil «$($p.Name)» już istnieje") }
    if (-not $p.TenantId -and -not $p.Organization -and -not $p.SharePointUrl) { $errors.Add('podaj tenant, organizację Exchange albo adres SharePoint') }
    if ($p.TenantId -and $p.TenantId -notmatch $script:GuidPattern -and $p.TenantId -notmatch $script:DomainPattern) { $errors.Add("tenant «$($p.TenantId)» - podaj domenę (klient.onmicrosoft.com) albo ID (GUID)") }
    if ($p.Organization -and $p.Organization -notmatch $script:DomainPattern) { $errors.Add("organizacja Exchange «$($p.Organization)» - podaj domenę, np. klient.onmicrosoft.com") }
    if ($p.PartnerAccount -and $p.PartnerAccount -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') { $errors.Add("konto partnera «$($p.PartnerAccount)» - podaj adres (UPN)") }
    if ($p.SharePointUrl -and $p.SharePointUrl -notmatch '^https://[A-Za-z0-9.-]+\.[A-Za-z]{2,}(/.*)?$') { $errors.Add("adres SharePoint «$($p.SharePointUrl)» - np. https://klient.sharepoint.com") }
    if ($p.PnPClientId -and $p.PnPClientId -notmatch $script:GuidPattern) { $errors.Add("Client ID PnP «$($p.PnPClientId)» - podaj GUID aplikacji") }
    if ($p.Gdap -and 'Exchange' -in $p.Services -and $p.Organization -and -not $p.PartnerAccount) { $errors.Add('Exchange w ramach GDAP wymaga konta partnera') }
    return @($errors)
}

function Get-HTTenantProfileServiceStatus {
    <#
        Czy profil ma dane do połączenia z usługą: [ordered]@{ Graph = @{ Ready; Reason }; Exchange; SharePoint }.
        -DefaultClientId: Client ID PnP z ustawień, gdy profil nie ma własnego.
    #>
    param([Parameter(Mandatory)]$TenantProfile, [string]$DefaultClientId = '')
    $p = ConvertTo-HTTenantProfile $TenantProfile
    $status = [ordered]@{}
    $status.Graph = if ($p.TenantId -or $p.Organization) { @{ Ready = $true; Reason = '' } } else { @{ Ready = $false; Reason = 'brak tenantu' } }
    $status.Exchange = if ($p.Gdap) {
        if ($p.Organization -and $p.PartnerAccount) { @{ Ready = $true; Reason = '' } } else { @{ Ready = $false; Reason = 'GDAP: organizacja i konto partnera' } }
    }
    else { @{ Ready = $true; Reason = '' } }
    $status.SharePoint = if (-not $p.SharePointUrl) { @{ Ready = $false; Reason = 'brak adresu SharePoint' } }
    elseif (-not $p.PnPClientId -and -not $DefaultClientId) { @{ Ready = $false; Reason = 'brak Client ID PnP' } }
    else { @{ Ready = $true; Reason = $(if ($p.PnPClientId) { '' } else { 'Client ID z ustawień' }) } }
    return $status
}

function Find-HTTenantProfiles {
    # Profile pasujące do tekstu (nazwa, tenant, organizacja, SharePoint, notatki); ostatnio używane na początku
    param([object[]]$Profiles = @(), [string]$Query = '')
    $q = ([string]$Query).Trim()
    $list = @($Profiles | Where-Object { $_ } | ForEach-Object { ConvertTo-HTTenantProfile $_ } | Where-Object { $_.Name })
    if ($q) {
        $words = @($q -split '\s+' | Where-Object { $_ })
        $list = @($list | Where-Object {
                $text = "$($_.Name) $($_.TenantId) $($_.Organization) $($_.PartnerAccount) $($_.SharePointUrl) $($_.Notes)"
                -not @($words | Where-Object { $text.IndexOf($_, [System.StringComparison]::OrdinalIgnoreCase) -lt 0 }).Count
            })
    }
    return @($list | Sort-Object @{ Expression = { [string]$_.LastUsed }; Descending = $true }, @{ Expression = { $_.Name }; Descending = $false })
}

function ConvertTo-HTTenantProfileRow {
    # Wiersz tabeli profili (moduł «Profile tenantów»); profil w __profile
    param([Parameter(Mandatory)]$TenantProfile, [string]$DefaultClientId = '')
    $p = ConvertTo-HTTenantProfile $TenantProfile
    $status = Get-HTTenantProfileServiceStatus -TenantProfile $p -DefaultClientId $DefaultClientId
    $missing = @($p.Services | Where-Object { -not $status[$_].Ready } | ForEach-Object { "$(Get-HTTenantServiceName $_): $($status[$_].Reason)" })
    $last = ''
    if ($p.LastUsed) { $d = [datetime]::MinValue; if ([datetime]::TryParse($p.LastUsed, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$d)) { $last = $d.ToLocalTime().ToString('yyyy-MM-dd HH:mm') } }
    return [PSCustomObject]@{
        Nazwa             = $p.Name
        Tenant            = $p.TenantId
        'Organizacja Exchange' = $p.Organization
        'Konto partnera'  = $p.PartnerAccount
        GDAP              = $p.Gdap
        SharePoint        = $p.SharePointUrl
        'Client ID PnP'   = $p.PnPClientId
        'Usługi'          = (@($p.Services | ForEach-Object { Get-HTTenantServiceName $_ }) -join ', ')
        Braki             = ($missing -join '; ')
        'Ostatnio użyty'  = $last
        Notatki           = $p.Notes
        __profile         = $p
        __flag            = $(if ($missing.Count) { 'warn' } else { '' })
    }
}

function Merge-HTTenantProfiles {
    <#
        Dołączenie profili (np. z CSV) do istniejących według nazwy. -Mode Replace - zastępuje profil o tej samej nazwie
        (zachowując datę ostatniego użycia), Skip - pomija. Zwraca @{ Profiles; Added; Replaced; Skipped }.
    #>
    param([object[]]$Existing = @(), [object[]]$Incoming = @(), [ValidateSet('Replace', 'Skip')][string]$Mode = 'Replace')
    $result = New-Object System.Collections.Generic.List[object]
    foreach ($e in @($Existing | Where-Object { $_ })) { $result.Add((ConvertTo-HTTenantProfile $e)) }
    $added = 0; $replaced = 0; $skipped = 0
    foreach ($i in @($Incoming | Where-Object { $_ })) {
        $p = ConvertTo-HTTenantProfile $i
        if (-not $p.Name) { $skipped++; continue }
        $index = -1
        for ($k = 0; $k -lt $result.Count; $k++) { if ($result[$k].Name -ieq $p.Name) { $index = $k; break } }
        if ($index -lt 0) { $result.Add($p); $added++ }
        elseif ($Mode -eq 'Replace') {
            if (-not $p.LastUsed) { $p.LastUsed = $result[$index].LastUsed }
            $result[$index] = $p
            $replaced++
        }
        else { $skipped++ }
    }
    return [PSCustomObject]@{ Profiles = $result.ToArray(); Added = $added; Replaced = $replaced; Skipped = $skipped }
}

function Get-HTTenantProfilesCsvTemplate {
    # Szablon pliku CSV (separator ;) z przykładowymi wierszami
    $header = @($script:TenantCsvColumns.Values | ForEach-Object { $_[0] }) -join ';'
    return @(
        $header
        'Klient ABC;abc.onmicrosoft.com;abc.onmicrosoft.com;admin@partner.pl;Tak;https://abc.sharepoint.com;;Microsoft 365, Exchange, SharePoint;umowa serwisowa'
        'Własny tenant;firma.onmicrosoft.com;;;Nie;https://firma.sharepoint.com/sites/IT;00000000-0000-0000-0000-000000000000;Microsoft 365, Exchange;'
    ) -join "`r`n"
}

function Import-HTTenantProfilesCsv {
    <#
        Profile z pliku CSV (separator ; albo ,; nagłówki jak w szablonie lub angielskie nazwy pól). Zwraca
        @{ Profiles; Errors } - wiersze z błędami są pomijane (Errors: «wiersz N: opis»).
    #>
    param([Parameter(Mandatory)][string]$Path)
    $rows = @(Import-HTCsvFile -Path $Path)
    $profiles = New-Object System.Collections.Generic.List[object]
    $errors = New-Object System.Collections.Generic.List[string]
    $line = 1
    foreach ($row in $rows) {
        $line++
        $data = @{}
        foreach ($field in $script:TenantCsvColumns.Keys) {
            foreach ($alias in $script:TenantCsvColumns[$field]) {
                $prop = $row.PSObject.Properties | Where-Object { $_.Name.Trim() -ieq $alias } | Select-Object -First 1
                if ($prop) { $data[$field] = [string]$prop.Value; break }
            }
        }
        if (-not $data.ContainsKey('Gdap')) { $data.Gdap = $(if ($data['PartnerAccount']) { 'Tak' } else { 'Nie' }) }
        $p = ConvertTo-HTTenantProfile $data
        $problems = @(Test-HTTenantProfile -TenantProfile $p -Existing $profiles.ToArray())
        if ($problems.Count) { $errors.Add("wiersz $($line) ($(if ($p.Name) { $p.Name } else { 'bez nazwy' })): $($problems -join '; ')"); continue }
        $profiles.Add($p)
    }
    return [PSCustomObject]@{ Profiles = $profiles.ToArray(); Errors = $errors.ToArray() }
}

function Export-HTTenantProfilesCsv {
    # Zapis profili do CSV (separator ;, UTF-8 z BOM - poprawne polskie znaki w Excelu)
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Profiles, [Parameter(Mandatory)][string]$Path)
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add((@($script:TenantCsvColumns.Values | ForEach-Object { $_[0] }) -join ';'))
    $quote = { param($v) $t = [string]$v; if ($t -match '[;"\r\n]') { '"' + $t.Replace('"', '""') + '"' } else { $t } }
    foreach ($item in @($Profiles | Where-Object { $_ })) {
        $p = ConvertTo-HTTenantProfile $item
        $values = @($p.Name, $p.TenantId, $p.Organization, $p.PartnerAccount, $(if ($p.Gdap) { 'Tak' } else { 'Nie' }), $p.SharePointUrl, $p.PnPClientId,
            (@($p.Services | ForEach-Object { Get-HTTenantServiceName $_ }) -join ', '), $p.Notes)
        $lines.Add((@($values | ForEach-Object { & $quote $_ }) -join ';'))
    }
    [System.IO.File]::WriteAllText($Path, ($lines -join "`r`n") + "`r`n", [System.Text.UTF8Encoding]::new($true))
}
