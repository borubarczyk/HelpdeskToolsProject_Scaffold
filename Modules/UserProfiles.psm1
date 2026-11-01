# Profile tworzenia kont Microsoft 365 - np. osobny profil dla każdego klienta: format loginu, domena, dane firmy,
# lokalizacja użycia, licencje, grupy i konto wzorcowe. Zapis: %APPDATA%\HelpdeskTools\UserProfiles.json (bez haseł).

$script:LoginFormats = [ordered]@{
    '{imie}.{nazwisko}' = 'jan.kowalski'
    '{i}.{nazwisko}'    = 'j.kowalski'
    '{i}{nazwisko}'     = 'jkowalski'
    '{nazwisko}.{imie}' = 'kowalski.jan'
    '{imie}{nazwisko}'  = 'jankowalski'
    '{nazwisko}{i}'     = 'kowalskij'
    '{imie}'            = 'jan'
}
$script:DefaultLoginFormat = '{imie}.{nazwisko}'

function Get-HTLoginFormats {
    # Gotowe formaty loginu (część UPN przed @) z przykładem dla «Jan Kowalski»
    foreach ($k in $script:LoginFormats.Keys) { [PSCustomObject]@{ Format = $k; Example = $script:LoginFormats[$k] } }
}

function ConvertTo-HTLoginFromFormat {
    <#
        Login z formatu: {imie}, {nazwisko}, {i} (pierwsza litera imienia), {n} (pierwsza litera nazwiska).
        Bez polskich znaków i spacji, małymi literami; dozwolone litery, cyfry, kropka, myślnik i podkreślenie.
    #>
    param([string]$Format = $script:DefaultLoginFormat, [Parameter(Mandatory)][string]$GivenName, [Parameter(Mandatory)][string]$Surname)
    if (-not $Format) { $Format = $script:DefaultLoginFormat }
    $clean = { param($t) ((ConvertTo-HTAsciiName $t).ToLowerInvariant() -replace '[^a-z0-9\-]', '') }
    $given = & $clean $GivenName
    $sur = & $clean $Surname
    $login = $Format.ToLowerInvariant().Replace('{imie}', $given).Replace('{imię}', $given).Replace('{nazwisko}', $sur).
        Replace('{i}', $(if ($given) { $given.Substring(0, 1) } else { '' })).Replace('{n}', $(if ($sur) { $sur.Substring(0, 1) } else { '' }))
    $login = ($login -replace '[^a-z0-9\.\-_]', '') -replace '\.{2,}', '.'
    if ($login.Length -gt 64) { $login = $login.Substring(0, 64) }
    return $login.Trim('.')
}

function ConvertTo-HTStringList {
    # Lista z tekstu (wiersze, przecinki, średniki) albo tablicy - bez pustych i powtórzeń (bez rozróżniania wielkości liter)
    param($Value)
    # Zagnieżdżone listy (np. @($pole.Text, @(wybrane nazwy))) - rozwijane, a nie zamieniane na tekst ze spacjami
    $items = foreach ($v in @($Value)) { foreach ($x in @($v)) { if ($null -ne $x) { [string]$x -split '[\r\n,;]+' } } }
    $seen = @{}
    foreach ($i in $items) {
        $t = $i.Trim()
        if (-not $t -or $seen.ContainsKey($t.ToLowerInvariant())) { continue }
        $seen[$t.ToLowerInvariant()] = $true
        $t
    }
}

function ConvertTo-HTUserProfile {
    # Ujednolicony profil (z pliku, formularza albo starszej wersji) - brakujące pola dostają wartości domyślne
    param([Parameter(Mandatory)]$InputObject)
    $get = { param($n) if ($InputObject -is [System.Collections.IDictionary]) { $InputObject[$n] } else { $p = $InputObject.PSObject.Properties[$n]; if ($p) { $p.Value } } }
    $format = [string](& $get 'LoginFormat')
    $location = ([string](& $get 'UsageLocation')).Trim().ToUpperInvariant()
    $force = & $get 'ForceChange'
    return [PSCustomObject][ordered]@{
        Name           = ([string](& $get 'Name')).Trim()
        Domain         = ([string](& $get 'Domain')).Trim().TrimStart('@').ToLowerInvariant()
        LoginFormat    = $(if ($format.Trim()) { $format.Trim() } else { $script:DefaultLoginFormat })
        UsageLocation  = $location
        JobTitle       = ([string](& $get 'JobTitle')).Trim()
        Department     = ([string](& $get 'Department')).Trim()
        CompanyName    = ([string](& $get 'CompanyName')).Trim()
        OfficeLocation = ([string](& $get 'OfficeLocation')).Trim()
        Licenses       = @(ConvertTo-HTStringList (& $get 'Licenses'))
        Groups         = @(ConvertTo-HTStringList (& $get 'Groups'))
        TemplateUser   = ([string](& $get 'TemplateUser')).Trim()
        ForceChange    = $(if ($null -eq $force) { $true } else { [bool]$force })
        Notes          = ([string](& $get 'Notes')).Trim()
        LastUsed       = [string](& $get 'LastUsed')
    }
}

function Test-HTUserProfile {
    # Błędy profilu (puste - poprawny). -Existing: zapisane profile (nazwa nie może się powtórzyć poza -OriginalName).
    param([Parameter(Mandatory)]$UserProfile, [object[]]$Existing = @(), [string]$OriginalName = '')
    $p = ConvertTo-HTUserProfile $UserProfile
    if (-not $p.Name) { 'Podaj nazwę profilu (np. nazwę klienta).' }
    elseif (@($Existing | Where-Object { $_ -and $_.Name -ieq $p.Name -and $_.Name -ine $OriginalName }).Count) { "Profil o nazwie «$($p.Name)» już istnieje." }
    if ($p.Domain -and $p.Domain -notmatch '^[a-z0-9]([a-z0-9\-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9\-]*[a-z0-9])?)+$') { "Domena «$($p.Domain)» ma nieprawidłowy format (np. firma.pl)." }
    if ($p.UsageLocation -and $p.UsageLocation -notmatch '^[A-Z]{2}$') { 'Lokalizacja użycia to dwuliterowy kod kraju (np. PL).' }
    if ($p.LoginFormat -notmatch '\{(imie|imię|nazwisko|i|n)\}') { 'Format loginu musi zawierać {imie}, {nazwisko}, {i} albo {n} (np. {imie}.{nazwisko}).' }
    if ($p.TemplateUser -and $p.TemplateUser -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') { 'Konto wzorcowe podaj jako adres UPN (np. jan.wzor@firma.pl).' }
}

function Get-HTUserProfilesPath {
    $dir = if ($Global:ConfigDir) { $Global:ConfigDir } else { Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'HelpdeskTools' }
    return (Join-Path $dir 'UserProfiles.json')
}

function Get-HTUserProfiles {
    # Zapisane profile (posortowane po nazwie); brak pliku - pusta lista
    $path = Get-HTUserProfilesPath
    if (-not (Test-Path -LiteralPath $path)) { return @() }
    try { $data = Get-Content -LiteralPath $path -Raw -Encoding utf8 | ConvertFrom-Json -ErrorAction Stop }
    catch { Write-Log -Message "Profile kont: nie odczytano pliku $path - $($_.Exception.Message)" -Type 'Warn'; return @() }
    return @(@($data) | Where-Object { $_ } | ForEach-Object { ConvertTo-HTUserProfile $_ } | Where-Object { $_.Name } | Sort-Object Name)
}

function Save-HTUserProfiles {
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Profiles, [string]$Path = '')
    if (-not $Path) { $Path = Get-HTUserProfilesPath }
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $list = @($Profiles | Where-Object { $_ } | ForEach-Object { ConvertTo-HTUserProfile $_ } | Sort-Object Name)
    ConvertTo-Json -InputObject @($list) -Depth 4 | Set-Content -LiteralPath $Path -Encoding utf8
}

function Find-HTUserProfilesForDomains {
    <#
        Profile pasujące do tenanta: domena profilu jest wśród domen tenanta (albo profil nie ma domeny).
        Ostatnio używane na początku. -All: wszystkie profile, pasujące na początku.
    #>
    param([AllowEmptyCollection()][object[]]$Profiles = @(), [string[]]$Domains = @(), [switch]$All)
    $lower = @($Domains | Where-Object { $_ } | ForEach-Object { $_.ToLowerInvariant() })
    $sorted = @($Profiles | Where-Object { $_ } | Sort-Object @{ Expression = { [string]$_.LastUsed }; Descending = $true }, Name)
    $match = @($sorted | Where-Object { -not $_.Domain -or $lower -contains $_.Domain })
    if (-not $All) { return $match }
    return @($match) + @($sorted | Where-Object { $match -notcontains $_ })
}

function Get-HTUserProfileDescription {
    # Krótki opis profilu do listy wyboru
    param([Parameter(Mandatory)]$UserProfile)
    $p = ConvertTo-HTUserProfile $UserProfile
    $parts = @(
        "login: $(ConvertTo-HTLoginFromFormat -Format $p.LoginFormat -GivenName 'Jan' -Surname 'Kowalski')@$(if ($p.Domain) { $p.Domain } else { '…' })"
        if ($p.Licenses.Count) { "licencje: $($p.Licenses.Count)" }
        if ($p.Groups.Count) { "grupy: $($p.Groups.Count)" }
        if ($p.TemplateUser) { "wzorzec: $($p.TemplateUser)" }
        if ($p.CompanyName) { $p.CompanyName }
    )
    return ($parts -join ' • ')
}

function Merge-HTUserProfiles {
    # Import: profile z pliku zastępują zapisane o tej samej nazwie albo są pomijane (-Skip). Zwraca @{ Profiles; Added; Replaced; Skipped }
    param([AllowEmptyCollection()][object[]]$Existing = @(), [AllowEmptyCollection()][object[]]$Incoming = @(), [switch]$Skip)
    $result = New-Object System.Collections.Generic.List[object]
    foreach ($e in @($Existing | Where-Object { $_ })) { $result.Add((ConvertTo-HTUserProfile $e)) }
    $added = 0; $replaced = 0; $skipped = 0
    foreach ($i in @($Incoming | Where-Object { $_ })) {
        $p = ConvertTo-HTUserProfile $i
        if (-not $p.Name) { continue }
        $index = -1
        for ($k = 0; $k -lt $result.Count; $k++) { if ($result[$k].Name -ieq $p.Name) { $index = $k; break } }
        if ($index -lt 0) { $result.Add($p); $added++ }
        elseif ($Skip) { $skipped++ }
        else { $p.LastUsed = $result[$index].LastUsed; $result[$index] = $p; $replaced++ }
    }
    return [PSCustomObject]@{ Profiles = $result.ToArray(); Added = $added; Replaced = $replaced; Skipped = $skipped }
}
