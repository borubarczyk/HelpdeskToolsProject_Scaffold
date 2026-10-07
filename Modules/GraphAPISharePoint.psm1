# SharePoint Online przez PnP.PowerShell (połączenie: Connect-Module -Name PnP.PowerShell)
# Węzeł drzewa (Node) to obiekt: @{ Title; ServerRelativeUrl; ListTitle; IsLibrary }

# Adres względny bieżącej witryny (np. /sites/Dzial)
function Get-HTSPWebUrl {
    $web = Get-PnPWeb -ErrorAction Stop
    return $web.ServerRelativeUrl.TrimEnd("/")
}

# Zamiana adresu względnego serwera na adres względny witryny
function ConvertTo-HTSPSiteRelativeUrl {
    param (
        [Parameter(Mandatory)][string]$ServerRelativeUrl,
        [AllowEmptyString()][string]$WebUrl
    )
    if ($null -eq $WebUrl -or -not $PSBoundParameters.ContainsKey("WebUrl")) { $WebUrl = Get-HTSPWebUrl }
    if ($WebUrl -and $ServerRelativeUrl.StartsWith($WebUrl, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $ServerRelativeUrl.Substring($WebUrl.Length).TrimStart("/")
    }
    return $ServerRelativeUrl.TrimStart("/")
}

# Biblioteki dokumentów witryny
function Get-HTSPLibraries {
    $lists = Get-PnPList -ErrorAction Stop | Where-Object { $_.BaseTemplate -eq 101 -and -not $_.Hidden }
    return @($lists | ForEach-Object {
            $root = Get-PnPProperty -ClientObject $_ -Property RootFolder
            [PSCustomObject]@{
                Title             = $_.Title
                ServerRelativeUrl = $root.ServerRelativeUrl
                ListTitle         = $_.Title
                IsLibrary         = $true
                ItemCount         = $_.ItemCount
            }
        } | Sort-Object Title)
}

# Podfoldery wskazanego folderu
function Get-HTSPSubFolders {
    param (
        [Parameter(Mandatory)][string]$ServerRelativeUrl,
        [Parameter(Mandatory)][string]$ListTitle
    )
    $siteRelative = ConvertTo-HTSPSiteRelativeUrl -ServerRelativeUrl $ServerRelativeUrl
    return @(Get-PnPFolderItem -FolderSiteRelativeUrl $siteRelative -ItemType Folder -ErrorAction Stop |
            Where-Object { $_.Name -ne "Forms" } |
            Sort-Object Name |
            ForEach-Object {
                [PSCustomObject]@{
                    Title             = $_.Name
                    ServerRelativeUrl = $_.ServerRelativeUrl
                    ListTitle         = $ListTitle
                    IsLibrary         = $false
                    ItemCount         = $_.ItemCount
                }
            })
}

# Obiekt zabezpieczalny (lista lub element folderu) dla węzła
function Get-HTSPSecurable {
    param ([Parameter(Mandatory)][object]$Node)
    if ($Node.IsLibrary) {
        return Get-PnPList -Identity $Node.ListTitle -ErrorAction Stop
    }
    $folder = Get-PnPFolder -Url $Node.ServerRelativeUrl -ErrorAction Stop
    return Get-PnPProperty -ClientObject $folder -Property ListItemAllFields
}

# Uprawnienia do biblioteki / folderu
function Get-HTSPPermissions {
    param ([Parameter(Mandatory)][object]$Node)

    $securable = Get-HTSPSecurable -Node $Node
    Get-PnPProperty -ClientObject $securable -Property HasUniqueRoleAssignments, RoleAssignments | Out-Null

    $limitedAccess = @("Limited Access", "Ograniczony dostęp", "Web-Only Limited Access")
    $rows = foreach ($assignment in $securable.RoleAssignments) {
        Get-PnPProperty -ClientObject $assignment -Property Member, RoleDefinitionBindings | Out-Null
        $roles = @($assignment.RoleDefinitionBindings | ForEach-Object { $_.Name } | Where-Object { $limitedAccess -notcontains $_ })
        if ($roles.Count -eq 0) { continue }
        [PSCustomObject]@{
            Principal     = $assignment.Member.Title
            LoginName     = $assignment.Member.LoginName
            PrincipalType = "$($assignment.Member.PrincipalType)"
            Roles         = $roles -join ", "
            Path          = $Node.ServerRelativeUrl
            Unique        = [bool]$securable.HasUniqueRoleAssignments
        }
    }
    return @($rows)
}

# Czy węzeł ma unikalne uprawnienia
function Test-HTSPUniquePermissions {
    param ([Parameter(Mandatory)][object]$Node)
    $securable = Get-HTSPSecurable -Node $Node
    return [bool](Get-PnPProperty -ClientObject $securable -Property HasUniqueRoleAssignments)
}

# Poziomy uprawnień dostępne w witrynie
function Get-HTSPRoleDefinitions {
    return @(Get-PnPRoleDefinition -ErrorAction Stop | Where-Object { -not $_.Hidden -and $_.Name -notmatch 'Limited|Ograniczony' } | ForEach-Object { $_.Name })
}

# Nadanie uprawnień (użytkownik / grupa zabezpieczeń - login lub e-mail; grupa SharePoint - nazwa)
function Grant-HTSPPermission {
    param (
        [Parameter(Mandatory)][object]$Node,
        [Parameter(Mandatory)][string]$Principal,
        [Parameter(Mandatory)][ValidateSet("User", "SharePointGroup")][string]$PrincipalType,
        [Parameter(Mandatory)][string]$Role
    )
    $target = if ($PrincipalType -eq "SharePointGroup") { @{ Group = $Principal } } else { @{ User = $Principal } }
    if ($Node.IsLibrary) {
        Set-PnPListPermission -Identity $Node.ListTitle -AddRole $Role @target -ErrorAction Stop
    }
    else {
        $siteRelative = ConvertTo-HTSPSiteRelativeUrl -ServerRelativeUrl $Node.ServerRelativeUrl
        Set-PnPFolderPermission -List $Node.ListTitle -Identity $siteRelative -AddRole $Role @target -ErrorAction Stop
    }
}

# Odebranie uprawnień
function Revoke-HTSPPermission {
    param (
        [Parameter(Mandatory)][object]$Node,
        [Parameter(Mandatory)][object]$Assignment
    )
    $isGroup = $Assignment.PrincipalType -eq "SharePointGroup"
    $target = if ($isGroup) { @{ Group = $Assignment.Principal } } else { @{ User = $Assignment.LoginName } }
    foreach ($role in ($Assignment.Roles -split ",\s*" | Where-Object { $_ })) {
        if ($Node.IsLibrary) {
            Set-PnPListPermission -Identity $Node.ListTitle -RemoveRole $role @target -ErrorAction Stop
        }
        else {
            $siteRelative = ConvertTo-HTSPSiteRelativeUrl -ServerRelativeUrl $Node.ServerRelativeUrl
            Set-PnPFolderPermission -List $Node.ListTitle -Identity $siteRelative -RemoveRole $role @target -ErrorAction Stop
        }
    }
}

# Przerwanie / przywrócenie dziedziczenia uprawnień
function Set-HTSPInheritance {
    param (
        [Parameter(Mandatory)][object]$Node,
        [Parameter(Mandatory)][bool]$Inherit,
        [bool]$CopyExisting = $true
    )
    if ($Node.IsLibrary) {
        if ($Inherit) {
            Set-PnPList -Identity $Node.ListTitle -ResetRoleInheritance -ErrorAction Stop | Out-Null
        }
        else {
            Set-PnPList -Identity $Node.ListTitle -BreakRoleInheritance -CopyRoleAssignments:$CopyExisting -ErrorAction Stop | Out-Null
        }
        return
    }

    $item = Get-HTSPSecurable -Node $Node
    if ($Inherit) { $item.ResetRoleInheritance() } else { $item.BreakRoleInheritance($CopyExisting, $false) }
    Invoke-PnPQuery -ErrorAction Stop
}

# Grupy SharePoint witryny
function Get-HTSPGroups {
    return @(Get-PnPGroup -ErrorAction Stop | ForEach-Object {
            [PSCustomObject]@{
                Title       = $_.Title
                Owner       = $_.OwnerTitle
                Description = $_.Description
                Id          = $_.Id
            }
        } | Sort-Object Title)
}

# Członkowie grupy SharePoint
function Get-HTSPGroupMembers {
    param ([Parameter(Mandatory)][string]$Group)
    return @(Get-PnPGroupMember -Group $Group -ErrorAction Stop | ForEach-Object {
            [PSCustomObject]@{
                Title         = $_.Title
                Email         = $_.Email
                LoginName     = $_.LoginName
                PrincipalType = "$($_.PrincipalType)"
            }
        } | Sort-Object Title)
}

# Nowa grupa SharePoint (opcjonalnie z członkami)
function New-HTSPGroup {
    param (
        [Parameter(Mandatory)][string]$Title,
        [string]$Description,
        [string[]]$Members = @()
    )
    $params = @{ Title = $Title; ErrorAction = "Stop" }
    if ($Description) { $params.Description = $Description }
    $group = New-PnPGroup @params
    foreach ($member in $Members) {
        Add-HTSPGroupMember -Group $Title -LoginName $member
    }
    return $group
}

function Add-HTSPGroupMember {
    param (
        [Parameter(Mandatory)][string]$Group,
        [Parameter(Mandatory)][string]$LoginName
    )
    Add-PnPGroupMember -Group $Group -LoginName $LoginName -ErrorAction Stop
}

function Remove-HTSPGroupMember {
    param (
        [Parameter(Mandatory)][string]$Group,
        [Parameter(Mandatory)][string]$LoginName
    )
    Remove-PnPGroupMember -Group $Group -LoginName $LoginName -ErrorAction Stop
}

# Nowy folder w bibliotece / folderze
function New-HTSPFolder {
    param (
        [Parameter(Mandatory)][object]$ParentNode,
        [Parameter(Mandatory)][string]$Name
    )
    if ($Name -match '["*:<>?/\\|]') { throw "Nazwa folderu zawiera niedozwolone znaki: "" * : < > ? / \ |" }
    $siteRelative = ConvertTo-HTSPSiteRelativeUrl -ServerRelativeUrl $ParentNode.ServerRelativeUrl
    $folder = Add-PnPFolder -Name $Name -Folder $siteRelative -ErrorAction Stop
    return [PSCustomObject]@{
        Title             = $folder.Name
        ServerRelativeUrl = $folder.ServerRelativeUrl
        ListTitle         = $ParentNode.ListTitle
        IsLibrary         = $false
        ItemCount         = 0
    }
}

# Pełny adres URL węzła (do otwarcia w przeglądarce)
function Get-HTSPAbsoluteUrl {
    param ([Parameter(Mandatory)][string]$ServerRelativeUrl)
    $connection = Get-PnPConnection -ErrorAction Stop
    $uri = [uri]$connection.Url
    return "$($uri.Scheme)://$($uri.Host)$ServerRelativeUrl"
}

#region Kosz witryny
function Get-HTSPRecycleBinItems {
    param (
        [ValidateRange(1, 93)][int]$Days = 93,
        [string]$DeletedBy
    )
    $cutoff = (Get-Date).AddDays(-$Days)
    return @(Get-PnPRecycleBinItem -RowLimit 5000 -ErrorAction Stop | Where-Object { $_.DeletedDate -ge $cutoff } | ForEach-Object {
            $by = if ($_.DeletedByEmail) { $_.DeletedByEmail } else { $_.DeletedByName }
            if ($DeletedBy -and "$by $($_.DeletedByName)" -notlike "*$DeletedBy*") { return }
            [PSCustomObject]@{
                Nazwa      = $_.LeafName
                Typ        = "$($_.ItemType)"
                Lokalizacja = $_.DirName
                Usunął     = $by
                Usunięto   = $_.DeletedDate
                "Rozmiar"  = Format-HTBytes $_.Size
                Etap       = if ("$($_.ItemState)" -eq "SecondStageRecycleBin") { "Kosz zbiorczy (2)" } else { "Kosz witryny (1)" }
                Id         = "$($_.Id)"
            }
        } | Sort-Object Usunięto -Descending)
}

function Restore-HTSPRecycleBinItem {
    param ([Parameter(Mandatory)][string]$Id)
    Restore-PnPRecycleBinItem -Identity $Id -Force -ErrorAction Stop
}

function Clear-HTSPRecycleBinItem {
    param ([Parameter(Mandatory)][string]$Id)
    Clear-PnPRecycleBinItem -Identity $Id -Force -ErrorAction Stop
}
#endregion

#region Zawartość folderów
function Get-HTSPFolderFiles {
    param ([Parameter(Mandatory)][object]$Node)
    $siteRelative = ConvertTo-HTSPSiteRelativeUrl -ServerRelativeUrl $Node.ServerRelativeUrl
    return @(Get-PnPFolderItem -FolderSiteRelativeUrl $siteRelative -ItemType File -ErrorAction Stop | ForEach-Object {
            [PSCustomObject]@{
                Nazwa             = $_.Name
                Rozmiar           = Format-HTBytes $_.Length
                "Rozmiar (B)"     = [long]$_.Length
                Zmodyfikowano     = $_.TimeLastModified
                Utworzono         = $_.TimeCreated
                Folder            = $Node.ServerRelativeUrl
                ServerRelativeUrl = $_.ServerRelativeUrl
            }
        } | Sort-Object Nazwa)
}
#endregion

#region Raport unikalnych uprawnień
# Biblioteki i foldery (do wskazanej głębokości) z przerwanym dziedziczeniem uprawnień.
# OnProgress: { param($Text) }
function Get-HTSPUniquePermissionsReport {
    param (
        [ValidateRange(0, 10)][int]$Depth = 2,
        [object[]]$Nodes,
        [scriptblock]$OnProgress
    )
    $queue = New-Object System.Collections.Queue
    $roots = if ($Nodes) { @($Nodes) } else { @(Get-HTSPLibraries) }
    foreach ($n in $roots) { $queue.Enqueue(@{ Node = $n; Level = 0 }) }
    while ($queue.Count -gt 0) {
        $entry = $queue.Dequeue()
        $node = $entry.Node
        if ($OnProgress) { & $OnProgress $node.ServerRelativeUrl }
        try {
            if (Test-HTSPUniquePermissions -Node $node) {
                foreach ($p in @(Get-HTSPPermissions -Node $node)) {
                    [PSCustomObject]@{
                        Ścieżka       = $node.ServerRelativeUrl
                        Rodzaj        = if ($node.IsLibrary) { "Biblioteka" } else { "Folder" }
                        Podmiot       = $p.Principal
                        "Typ podmiotu" = $p.PrincipalType
                        Uprawnienia   = $p.Roles
                        Login         = $p.LoginName
                        __flag        = if ("$($p.LoginName)" -match 'spo-grid-all-users|Everyone|Wszyscy') { "warn" } else { "" }
                    }
                }
            }
        }
        catch {
            [PSCustomObject]@{ Ścieżka = $node.ServerRelativeUrl; Rodzaj = "Błąd"; Podmiot = ""; "Typ podmiotu" = ""; Uprawnienia = $_.Exception.Message; Login = ""; __flag = "crit" }
        }
        if ($entry.Level -lt $Depth) {
            try {
                foreach ($child in @(Get-HTSPSubFolders -ServerRelativeUrl $node.ServerRelativeUrl -ListTitle $node.ListTitle)) {
                    $queue.Enqueue(@{ Node = $child; Level = $entry.Level + 1 })
                }
            }
            catch { Write-Log -Message "Podfoldery $($node.ServerRelativeUrl): $($_.Exception.Message)" -Type "Warn" }
        }
    }
}
#endregion

#region Witryna
function Get-HTSPSiteInfo {
    $site = Get-PnPSite -Includes Usage, Owner, StorageQuota, Url, ServerRelativeUrl, LockState, SharingCapability -ErrorAction Stop
    $web = Get-PnPWeb -Includes Created, LastItemModifiedDate, Language, WebTemplate, Description -ErrorAction Stop
    $admins = @()
    try { $admins = @(Get-PnPSiteCollectionAdmin -ErrorAction Stop | ForEach-Object { "$($_.Title) <$($_.Email)>" }) } catch { $admins = @("(brak uprawnień do odczytu)") }
    $usage = $site.Usage
    return [ordered]@{
        "Tytuł"                   = $web.Title
        "Adres"                   = $site.Url
        "Opis"                    = $web.Description
        "Szablon"                 = $web.WebTemplate
        "Utworzono"               = $web.Created
        "Ostatnia zmiana"         = $web.LastItemModifiedDate
        "Właściciel"              = if ($site.Owner) { "$($site.Owner.Title) <$($site.Owner.Email)>" } else { "" }
        "Stan blokady"            = "$($site.LockState)"
        "Magazyn"                 = [ordered]@{
            "Wykorzystano"        = if ($usage) { Format-HTBytes $usage.Storage } else { "" }
            "Procent limitu"      = if ($usage) { "{0:N1}%" -f ($usage.StoragePercentageUsed * 100) } else { "" }
            "Limit"               = if ($site.StorageQuota) { Format-HTBytes ($site.StorageQuota * 1MB) } else { "" }
        }
        "Administratorzy kolekcji" = [ordered]@{ "Konta" = $admins }
    }
}

# Wyszukiwanie witryn w tenancie przez Microsoft Graph (Sites.Read.All)
function Find-HTSPSites {
    param ([string]$Search = "*")
    $query = if ([string]::IsNullOrWhiteSpace($Search)) { "*" } else { $Search.Trim() }
    $items = Invoke-HTGraphRequest -Uri "sites?search=$([uri]::EscapeDataString($query))&`$select=id,displayName,webUrl,createdDateTime,lastModifiedDateTime,description" -All
    return @($items | Where-Object { $_.webUrl -notmatch '/personal/' } | ForEach-Object {
            [PSCustomObject]@{
                Nazwa           = $_.displayName
                Adres           = $_.webUrl
                Opis            = $_.description
                Utworzono       = $_.createdDateTime
                "Ostatnia zmiana" = $_.lastModifiedDateTime
            }
        } | Sort-Object Nazwa)
}
#endregion
