# SharePoint i OneDrive: audyt udostępnień (linki anonimowe, organizacyjne, goście) z usuwaniem, dostęp przełożonego
# do OneDrive odchodzącego pracownika, porządkowanie starych wersji plików (PnP) oraz nieaktywne witryny i witryny
# bez właściciela (raport użycia). Moduł nie zależy od interfejsu.

#region Audyt udostępnień (Microsoft Graph)
function ConvertTo-HTSharingRow {
    # Wiersz uprawnienia elementu (link albo bezpośrednie nadanie) - tylko udostępnienia (bez dziedziczonych z witryny)
    param (
        [Parameter(Mandatory)][object]$Item,
        [Parameter(Mandatory)][object]$Permission,
        [string]$DriveId = '',
        [string]$Location = '',
        [AllowEmptyCollection()][string[]]$InternalDomains = @(),
        [datetime]$Now = (Get-Date)
    )
    $p = $Permission
    # Osoba spoza organizacji: konto gościa (#EXT#, urn:spo:guest) albo adres z domeny spoza listy domen tenantu
    $isExternal = {
        param([string]$Email, [string]$Login)
        if ("$Email $Login" -match '#ext#|urn(:|%3a)spo(:|%3a)guest') { return $true }
        if ($Email -and @($InternalDomains).Count) { $domain = ($Email -split '@')[-1]; return (@($InternalDomains | Where-Object { $_ -ieq $domain }).Count -eq 0) }
        return $false
    }
    $roles = @($p.roles) -join ', '
    $kind = ''
    $who = ''
    $external = $false
    if ($p.link) {
        $kind = switch ([string]$p.link.scope) { 'anonymous' { 'Link anonimowy (każdy)' } 'organization' { 'Link w organizacji' } 'users' { 'Link dla wskazanych osób' } default { "Link: $($p.link.scope)" } }
        $identities = @(@($p.grantedToIdentitiesV2) + @($p.grantedToIdentities) | Where-Object { $_ })
        $people = @($identities | ForEach-Object { if ($_.user.email) { $_.user.email } elseif ($_.user.displayName) { $_.user.displayName } elseif ($_.siteUser.loginName) { $_.siteUser.loginName } } | Where-Object { $_ } | Select-Object -Unique)
        $who = $people -join ', '
        $external = ([string]$p.link.scope -eq 'anonymous') -or @($identities | Where-Object { & $isExternal ([string]$_.user.email) ([string]$_.siteUser.loginName) }).Count -gt 0
        if ($p.link.type) { $roles = [string]$p.link.type }
    }
    elseif ($p.inheritedFrom -and $p.inheritedFrom.id) { return $null }
    else {
        $g = if ($p.grantedToV2) { $p.grantedToV2 } else { $p.grantedTo }
        $name = if ($g.user.email) { $g.user.email } elseif ($g.user.displayName) { $g.user.displayName } elseif ($g.siteUser.loginName) { $g.siteUser.loginName } elseif ($g.group.displayName) { $g.group.displayName } elseif ($g.siteGroup.displayName) { $g.siteGroup.displayName } else { '' }
        if ($roles -eq 'owner' -or $g.siteGroup) { return $null }
        $kind = 'Bezpośrednie uprawnienie'
        $who = $name
        $external = & $isExternal ([string]$g.user.email) ([string]$g.siteUser.loginName)
    }
    $expires = $p.expirationDateTime
    $daysLeft = if ($expires) { [int][Math]::Floor(([datetime]$expires - $Now).TotalDays) } else { $null }
    $anonymous = $kind -like 'Link anonimowy*'
    $write = $roles -match 'write|edit'
    return [PSCustomObject]@{
        Element         = $Item.name
        Lokalizacja     = $Location
        Typ             = $(if ($Item.folder) { 'Folder' } else { 'Plik' })
        Udostępnienie   = $kind
        Uprawnienia     = $roles
        Dla             = $who
        Zewnętrzne      = [bool]$external
        Wygasa          = $(if ($expires) { $expires } else { 'nigdy' })
        Hasło           = [bool]$p.hasPassword
        Zmieniono       = $Item.lastModifiedDateTime
        Adres           = $Item.webUrl
        __driveId       = $DriveId
        __itemId        = $Item.id
        __permId        = $p.id
        __flag          = if ($anonymous -and ($write -or -not $expires)) { 'crit' } elseif ($anonymous -or $external) { 'warn' } elseif ($null -ne $daysLeft -and $daysLeft -lt 0) { 'muted' } else { '' }
    }
}

function Get-HTDriveSharing {
    <#
        Udostępnione elementy biblioteki / OneDrive: zmiany drzewa (delta) z nagłówkiem hierarchicalsharing wskazują
        elementy z własnymi uprawnieniami, a ich uprawnienia są pobierane zbiorczo ($batch). -OnlyExternal: tylko linki
        anonimowe i udostępnienia gościom. Uprawnienia Files.Read.All / Sites.Read.All.
    #>
    param ([Parameter(Mandatory)][string]$DriveId, [string]$Location = '', [switch]$OnlyExternal, [int]$MaxItems = 50000, [string[]]$InternalDomains)
    if ($null -eq $InternalDomains) { try { $InternalDomains = @(Get-HTM365Domains) } catch { $InternalDomains = @() } }
    $candidates = New-Object System.Collections.Generic.List[object]
    $uri = "drives/$DriveId/root/delta?`$select=id,name,webUrl,shared,folder,file,parentReference,lastModifiedDateTime,deleted&`$top=1000"
    $response = Invoke-MgGraphRequest -Uri (Resolve-HTGraphUri -Uri $uri) -Method GET -Headers @{ Prefer = 'hierarchicalsharing' } -OutputType PSObject -ErrorAction Stop
    $seen = 0
    while ($response) {
        foreach ($i in @($response.value)) {
            if (-not $i -or $i.deleted) { continue }
            $seen++
            if ($i.shared -or $i.'@microsoft.graph.sharedChanged') { $candidates.Add($i) }
        }
        if ($seen % 5000 -lt 1000) { Write-Progress -Activity 'Udostępnienia' -Status "przejrzano elementów: $seen" -PercentComplete -1 }
        if ($seen -ge $MaxItems -or -not $response.'@odata.nextLink') { break }
        $response = Invoke-MgGraphRequest -Uri $response.'@odata.nextLink' -Method GET -Headers @{ Prefer = 'hierarchicalsharing' } -OutputType PSObject -ErrorAction Stop
    }
    if ($seen -ge $MaxItems) { Write-Log -Message "Udostępnienia ($Location): przejrzano pierwsze $MaxItems elementów (limit)." -Type 'Warn' }
    $batch = Invoke-HTGraphBatch -Requests @($candidates | ForEach-Object { @{ Id = [string]$_.id; Url = "drives/$DriveId/items/$($_.id)/permissions" } }) -All
    foreach ($i in $candidates) {
        $b = $batch[[string]$i.id]
        if (-not $b -or $b.Status -ge 300) { continue }
        $parent = ([string]$i.parentReference.path) -replace '^/drives/[^/]+/root:?', ''
        foreach ($p in @($b.Body.value)) {
            $row = ConvertTo-HTSharingRow -Item $i -Permission $p -DriveId $DriveId -Location ("$Location$parent").TrimEnd('/') -InternalDomains $InternalDomains
            if (-not $row) { continue }
            if ($OnlyExternal -and -not $row.Zewnętrzne) { continue }
            $row
        }
    }
}

function Get-HTSiteSharing {
    # Udostępnienia we wszystkich bibliotekach witryny (Graph)
    param ([Parameter(Mandatory)][string]$SiteId, [string]$SiteName = '', [switch]$OnlyExternal)
    $domains = @()
    try { $domains = @(Get-HTM365Domains) } catch { $domains = @() }
    foreach ($d in @(Invoke-HTGraphRequest -Uri "sites/$SiteId/drives?`$select=id,name" -All)) {
        try { Get-HTDriveSharing -DriveId $d.id -Location "$SiteName/$($d.name)" -OnlyExternal:$OnlyExternal -InternalDomains $domains }
        catch { Write-Log -Message "Udostępnienia biblioteki $($d.name): $($_.Exception.Message)" -Type 'Warn' }
    }
}

function Get-HTOneDriveSharing {
    param ([Parameter(Mandatory)][string]$UserId, [string]$Label = '', [switch]$OnlyExternal)
    $drive = Invoke-HTGraphRequest -Uri "users/$UserId/drive?`$select=id,webUrl"
    Get-HTDriveSharing -DriveId $drive.id -Location "OneDrive $Label" -OnlyExternal:$OnlyExternal
}

function Remove-HTDriveItemPermission {
    # Usunięcie linku udostępniania albo uprawnienia elementu (Files.ReadWrite.All / Sites.ReadWrite.All)
    param ([Parameter(Mandatory)][string]$DriveId, [Parameter(Mandatory)][string]$ItemId, [Parameter(Mandatory)][string]$PermissionId)
    Invoke-HTGraphRequest -Uri "drives/$DriveId/items/$ItemId/permissions/$PermissionId" -Method DELETE | Out-Null
}
#endregion

#region OneDrive odchodzącego pracownika: dostęp przełożonego
function Get-HTSharePointAdminUrl {
    # Adres centrum administracyjnego SharePoint (https://<tenant>-admin.sharepoint.com) z witryny głównej tenantu
    $root = Invoke-HTGraphRequest -Uri 'sites/root?$select=webUrl'
    if ("$($root.webUrl)" -match '^https://([^./]+)\.sharepoint\.(com|us|de|cn)') { return "https://$($Matches[1])-admin.sharepoint.$($Matches[2])" }
    throw "Nie ustalono adresu centrum administracyjnego SharePoint z $($root.webUrl)."
}

function Get-HTOneDriveSiteUrl {
    # Adres witryny OneDrive użytkownika (https://<tenant>-my.sharepoint.com/personal/<login>)
    param ([Parameter(Mandatory)][string]$UserId)
    $drive = Invoke-HTGraphRequest -Uri "users/$UserId/drive?`$select=webUrl"
    $url = [string]$drive.webUrl
    if ($url -match '^(https://[^/]+/personal/[^/]+)') { return $Matches[1] }
    throw "Nie ustalono adresu OneDrive ($url) - użytkownik nie ma OneDrive albo nie zalogował się do niego."
}

function Connect-HTPnPReturn {
    # Dodatkowe połączenie PnP (np. centrum administracyjne) bez zmiany bieżącego połączenia programu
    param ([Parameter(Mandatory)][string]$Url, [string]$ClientId = "$($Global:LastUsedClientID)")
    if (-not $ClientId) { throw 'Brak Client ID aplikacji PnP (SharePoint > Aplikacja PnP).' }
    $connection = $null
    $login = { Connect-PnPOnline -Url $Url -ClientId $ClientId -Interactive -ReturnConnection -ErrorAction Stop }.GetNewClosure()
    $connection = @(Invoke-HTLogin -Title "SharePoint ($Url)" -ScriptBlock $login)[-1]
    if (-not $connection) { throw "Nie połączono z $Url." }
    return $connection
}

function Grant-HTOneDriveAccess {
    <#
        Nadanie dostępu do OneDrive użytkownika (administrator kolekcji witryn) - np. przełożonemu przed usunięciem konta.
        Wymaga roli SharePoint Administrator i aplikacji PnP. Zwraca adres OneDrive.
    #>
    param ([Parameter(Mandatory)][string]$UserId, [Parameter(Mandatory)][string[]]$GrantTo, $AdminConnection = $null)
    $site = Get-HTOneDriveSiteUrl -UserId $UserId
    if (-not $AdminConnection) { $AdminConnection = Connect-HTPnPReturn -Url (Get-HTSharePointAdminUrl) }
    Set-PnPTenantSite -Url $site -Owners @($GrantTo) -Connection $AdminConnection -ErrorAction Stop
    return $site
}

function Revoke-HTOneDriveAccess {
    # Odebranie roli administratora OneDrive (np. po okresie przejęcia plików - zadania zaplanowane)
    param ([Parameter(Mandatory)][string]$SiteUrl, [Parameter(Mandatory)][string[]]$Users, $SiteConnection = $null)
    if (-not $SiteConnection) { $SiteConnection = Connect-HTPnPReturn -Url $SiteUrl }
    Remove-PnPSiteCollectionAdmin -Owners @($Users) -Connection $SiteConnection -ErrorAction Stop
}
#endregion

#region Wersje plików (PnP)
function Get-HTFileVersionUsage {
    <#
        Pliki biblioteki z liczbą wersji większą niż -Keep (połączona witryna PnP): numer wersji, rozmiar bieżący i łączny.
        -FolderServerRelativeUrl ogranicza do folderu.
    #>
    param ([Parameter(Mandatory)][string]$ListTitle, [string]$FolderServerRelativeUrl = '', [int]$Keep = 50, [int]$MaxFiles = 20000)
    $fields = @('FileLeafRef', 'FileRef', 'FSObjType', '_UIVersionString', 'File_x0020_Size', 'SMTotalFileStreamSize', 'SMTotalSize', 'Modified')
    $params = @{ List = $ListTitle; PageSize = 2000; Fields = $fields; ErrorAction = 'Stop' }
    if ($FolderServerRelativeUrl) { $params.FolderServerRelativeUrl = $FolderServerRelativeUrl }
    $count = 0
    foreach ($item in @(Get-PnPListItem @params)) {
        $v = $item.FieldValues
        if ([string]$v.FSObjType -ne '0') { continue }
        $count++
        if ($count -gt $MaxFiles) { break }
        $major = 0
        [void][int]::TryParse(([string]$v._UIVersionString).Split('.')[0], [ref]$major)
        if ($major -le $Keep) { continue }
        $size = [double]$v.File_x0020_Size
        $total = [double]$v.SMTotalSize
        [PSCustomObject]@{
            Plik                 = $v.FileLeafRef
            Ścieżka              = $v.FileRef
            Wersja               = $v._UIVersionString
            'Rozmiar (MB)'       = [Math]::Round($size / 1MB, 2)
            'Z wersjami (MB)'    = $(if ($total -gt 0) { [Math]::Round($total / 1MB, 2) } else { $null })
            'Do odzyskania (MB)' = $(if ($total -gt $size) { [Math]::Round(($total - $size) / 1MB, 2) } else { $null })
            Zmieniono            = $v.Modified
            __flag               = if ($major -gt 4 * $Keep) { 'warn' } else { '' }
        }
    }
}

function Remove-HTOldFileVersions {
    # Usunięcie najstarszych wersji pliku - zostaje -Keep najnowszych; zwraca liczbę usuniętych i zwolnione MB
    param ([Parameter(Mandatory)][string]$FileServerRelativeUrl, [int]$Keep = 50)
    $versions = @(Get-PnPFileVersion -Url $FileServerRelativeUrl -ErrorAction Stop | Sort-Object Created -Descending)
    $remove = @($versions | Select-Object -Skip ([Math]::Max(0, $Keep)))
    $freed = 0
    foreach ($v in $remove) {
        Remove-PnPFileVersion -Url $FileServerRelativeUrl -Identity $v.Id -Force -ErrorAction Stop
        $freed += [double]$v.Size
    }
    return "Usunięto wersji: $($remove.Count), zwolniono: $([Math]::Round($freed / 1MB, 1)) MB"
}

function Test-HTVersionTrimJobAvailable {
    return [bool](Get-Command -Name New-PnPSiteFileVersionBatchDeleteJob -ErrorAction SilentlyContinue)
}

function Start-HTVersionTrimJob {
    # Zadanie SharePoint przycinające wersje w całej witrynie (PnP.PowerShell 2.12+): zostaje -Keep wersji głównych
    param ([int]$Keep = 50)
    New-PnPSiteFileVersionBatchDeleteJob -MajorVersionLimit $Keep -MajorWithMinorVersionsLimit 0 -Force -ErrorAction Stop | Out-Null
}
#endregion

#region Nieaktywne witryny i witryny bez właściciela (raport użycia)
function Get-HTInactiveSites {
    <#
        Witryny SharePoint bez aktywności od -Days dni albo bez właściciela (raport użycia z 180 dni, Reports.Read.All).
        Przy ukrywaniu danych w raportach (centrum administracyjne > Ustawienia > Raporty) adresy są zastąpione skrótami.
    #>
    param ([int]$Days = 180, [switch]$IncludeActive)
    foreach ($r in @(Get-HTGraphReportCsv -Report "getSharePointSiteUsageDetail(period='D180')")) {
        if ("$($r.'Is Deleted')" -eq 'True') { continue }
        $last = if ($r.'Last Activity Date') { [datetime]$r.'Last Activity Date' } else { $null }
        $idle = if ($last) { [int][Math]::Floor(((Get-Date) - $last).TotalDays) } else { $null }
        $noOwner = -not "$($r.'Owner Principal Name')".Trim() -and -not "$($r.'Owner Display Name')".Trim()
        $inactive = ($null -eq $idle) -or $idle -ge $Days
        if (-not $IncludeActive -and -not $inactive -and -not $noOwner) { continue }
        $bytes = 0.0
        [void][double]::TryParse("$($r.'Storage Used (Byte)')", [ref]$bytes)
        [PSCustomObject]@{
            Witryna               = $r.'Site URL'
            Właściciel            = $(if ($r.'Owner Principal Name') { $r.'Owner Principal Name' } else { $r.'Owner Display Name' })
            'Ostatnia aktywność'  = $last
            'Dni bez aktywności'  = $(if ($null -ne $idle) { $idle } else { 'brak w 180 dniach' })
            Pliki                 = $r.'File Count'
            'Aktywne pliki'       = $r.'Active File Count'
            Wyświetlenia          = $r.'Page View Count'
            'Rozmiar (GB)'        = [Math]::Round($bytes / 1GB, 2)
            Szablon               = $r.'Root Web Template'
            Uwagi                 = (@($(if ($inactive) { 'nieaktywna' }), $(if ($noOwner) { 'brak właściciela' })) | Where-Object { $_ }) -join ', '
            Id                    = $r.'Site Id'
            __flag                = if ($noOwner) { 'crit' } elseif ($inactive) { 'warn' } else { '' }
        }
    }
}
#endregion
