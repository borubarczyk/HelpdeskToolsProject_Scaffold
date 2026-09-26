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
