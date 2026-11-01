# Zespoły Microsoft Teams przez Microsoft Graph: przegląd zespołów (właściciele, goście, aktywność), zespoły bez
# właściciela, archiwizacja i dodawanie właścicieli. Moduł nie zależy od interfejsu.

function Get-HTTeamsActivityMap {
    # Ostatnia aktywność zespołów z raportu użycia (Reports.Read.All) - słownik Id zespołu -> data; pusty przy braku uprawnień
    param ([ValidateSet('D7', 'D30', 'D90', 'D180')][string]$Period = 'D90')
    $map = @{}
    try {
        foreach ($r in @(Get-HTGraphReportCsv -Report "getTeamsTeamActivityDetail(period='$Period')")) {
            $id = [string]$r.'Team Id'
            if ($id) { $map[$id] = [string]$r.'Last Activity Date' }
        }
    }
    catch { Write-Log -Message "Aktywność zespołów (raport użycia, Reports.Read.All): $($_.Exception.Message)" -Type 'Warn' }
    return $map
}

function ConvertTo-HTTeamRow {
    param ([Parameter(Mandatory)][object]$Group, [object[]]$Owners = @(), [object[]]$Members = @(), $Team = $null, [string]$LastActivity = '')
    $guests = @($Members | Where-Object { $_.userType -eq 'Guest' })
    $ownerCount = @($Owners).Count
    $issues = @()
    if ($ownerCount -eq 0) { $issues += 'brak właściciela' } elseif ($ownerCount -eq 1) { $issues += 'jeden właściciel' }
    if ($guests.Count) { $issues += "goście: $($guests.Count)" }
    return [PSCustomObject]@{
        Zespół              = $Group.displayName
        Widoczność          = $Group.visibility
        Właściciele         = $ownerCount
        'Lista właścicieli' = (@($Owners | ForEach-Object { if ($_.userPrincipalName) { $_.userPrincipalName } else { $_.displayName } }) -join ', ')
        Członkowie          = @($Members).Count
        Goście              = $guests.Count
        'Lista gości'       = (@($guests | ForEach-Object { if ($_.mail) { $_.mail } else { $_.displayName } }) -join ', ')
        Zarchiwizowany      = $(if ($Team) { [bool]$Team.isArchived } else { $null })
        'Ostatnia aktywność' = $LastActivity
        Utworzono           = $Group.createdDateTime
        Uwagi               = ($issues -join '; ')
        'E-mail'            = $Group.mail
        Id                  = $Group.id
        __flag              = if ($ownerCount -eq 0) { 'crit' } elseif ($Team -and $Team.isArchived) { 'muted' } elseif ($issues.Count) { 'warn' } else { '' }
    }
}

function Get-HTTeamsOverview {
    <#
        Zespoły Teams z właścicielami, liczbą członków i gości, stanem archiwizacji i ostatnią aktywnością.
        -OnlyIssues: tylko zespoły bez właściciela, z jednym właścicielem albo z gośćmi.
    #>
    param ([switch]$OnlyIssues, [switch]$NoActivity)
    $groups = @(Invoke-HTGraphRequest -Uri "groups?`$filter=resourceProvisioningOptions/Any(x:x eq 'Team')&`$select=id,displayName,mail,visibility,createdDateTime,description&`$top=999&`$count=true" -All -ConsistencyLevelEventual)
    $requests = foreach ($g in $groups) {
        @{ Id = "o_$($g.id)"; Url = "groups/$($g.id)/owners?`$select=id,displayName,userPrincipalName&`$top=999" }
        @{ Id = "m_$($g.id)"; Url = "groups/$($g.id)/members?`$select=id,displayName,userType,mail&`$top=999" }
        @{ Id = "t_$($g.id)"; Url = "teams/$($g.id)?`$select=id,isArchived" }
    }
    $batch = Invoke-HTGraphBatch -Requests @($requests) -All
    $activity = if ($NoActivity) { @{} } else { Get-HTTeamsActivityMap }
    $i = 0
    foreach ($g in @($groups | Sort-Object displayName)) {
        $i++
        if ($groups.Count -gt 20) { Write-Progress -Activity 'Zespoły' -Status "$i / $($groups.Count)" -PercentComplete ([int](100 * $i / $groups.Count)) }
        $owners = if ($batch["o_$($g.id)"].Status -lt 300) { @($batch["o_$($g.id)"].Body.value) } else { @() }
        $members = if ($batch["m_$($g.id)"].Status -lt 300) { @($batch["m_$($g.id)"].Body.value) } else { @() }
        $team = if ($batch["t_$($g.id)"].Status -lt 300) { $batch["t_$($g.id)"].Body } else { $null }
        $row = ConvertTo-HTTeamRow -Group $g -Owners $owners -Members $members -Team $team -LastActivity ([string]$activity[[string]$g.id])
        if ($OnlyIssues -and -not $row.Uwagi) { continue }
        $row
    }
}

function Set-HTTeamArchived {
    # Archiwizacja (tylko do odczytu) albo przywrócenie zespołu (TeamSettings.ReadWrite.All)
    param ([Parameter(Mandatory)][string]$TeamId, [Parameter(Mandatory)][bool]$Archived, [bool]$SiteReadOnly = $false)
    if ($Archived) { Invoke-HTGraphRequest -Uri "teams/$TeamId/archive" -Method POST -Body @{ shouldSetSpoSiteReadOnlyForMembers = $SiteReadOnly } | Out-Null }
    else { Invoke-HTGraphRequest -Uri "teams/$TeamId/unarchive" -Method POST -Body @{} | Out-Null }
}

function Add-HTTeamOwner {
    # Dodanie właściciela (najpierw członkostwo - właściciel zespołu musi być też członkiem)
    param ([Parameter(Mandatory)][string]$GroupId, [Parameter(Mandatory)][string]$UserId)
    $ref = @{ '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$UserId" }
    try { Invoke-HTGraphRequest -Uri "groups/$GroupId/members/`$ref" -Method POST -Body $ref | Out-Null }
    catch { if ("$($_.Exception.Message)" -notmatch 'already exist|One or more added object references already exist') { throw } }
    try { Invoke-HTGraphRequest -Uri "groups/$GroupId/owners/`$ref" -Method POST -Body $ref | Out-Null }
    catch { if ("$($_.Exception.Message)" -notmatch 'already exist|One or more added object references already exist') { throw } }
}

function Remove-HTTeamGuest {
    # Usunięcie gościa z zespołu (członkostwo w grupie Microsoft 365)
    param ([Parameter(Mandatory)][string]$GroupId, [Parameter(Mandatory)][string]$UserId)
    Invoke-HTGraphRequest -Uri "groups/$GroupId/members/$UserId/`$ref" -Method DELETE | Out-Null
}

function Get-HTTeamGuests {
    param ([Parameter(Mandatory)][string]$GroupId, [string]$TeamName = '')
    foreach ($m in @(Invoke-HTGraphRequest -Uri "groups/$GroupId/members?`$select=id,displayName,userType,mail,userPrincipalName,createdDateTime,externalUserState&`$top=999" -All | Where-Object { $_.userType -eq 'Guest' })) {
        [PSCustomObject]@{ Zespół = $TeamName; Gość = $m.displayName; 'E-mail' = $m.mail; 'Stan zaproszenia' = $m.externalUserState; Utworzono = $m.createdDateTime; Id = $m.id; __group = $GroupId }
    }
}

#region Zespół z grupy Microsoft 365 i kanały
function Get-HTTeamFromGroupBody {
    # Ustawienia nowego zespołu: członkowie mogą tworzyć / usuwać kanały, Giphy (filtr treści - ścisły)
    param([bool]$MembersCanCreateChannels = $true, [bool]$MembersCanDeleteChannels = $false, [bool]$AllowGiphy = $true, [bool]$GuestsCanCreateChannels = $false)
    return [ordered]@{
        memberSettings    = [ordered]@{ allowCreateUpdateChannels = $MembersCanCreateChannels; allowCreatePrivateChannels = $MembersCanCreateChannels; allowDeleteChannels = $MembersCanDeleteChannels; allowAddRemoveApps = $true }
        guestSettings     = [ordered]@{ allowCreateUpdateChannels = $GuestsCanCreateChannels; allowDeleteChannels = $false }
        messagingSettings = [ordered]@{ allowUserEditMessages = $true; allowUserDeleteMessages = $true }
        funSettings       = [ordered]@{ allowGiphy = $AllowGiphy; giphyContentRating = 'strict' }
    }
}

function New-HTTeamFromGroup {
    <#
        Zespół Teams z istniejącej grupy Microsoft 365 (grupa musi mieć właściciela). Grupa utworzona przed chwilą może
        jeszcze nie być widoczna dla Teams (replikacja do 15 min) - Microsoft zaleca 3 próby co 10 s.
    #>
    param([Parameter(Mandatory)][string]$GroupId, [hashtable]$Settings = @{}, [int]$Retries = 3, [int]$DelaySeconds = 10)
    $body = Get-HTTeamFromGroupBody @Settings
    for ($i = 1; ; $i++) {
        try { return Invoke-HTGraphRequest -Uri "groups/$GroupId/team" -Method PUT -Body $body }
        catch {
            if ($i -ge $Retries -or "$($_.Exception.Message)" -notmatch '404|NotFound|not found|replicat') { throw }
            Write-Log -Message "Zespół z grupy $($GroupId): grupa jeszcze niewidoczna dla Teams - próba $($i + 1) za $DelaySeconds s." -Type 'Info'
            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

$script:ChannelTypeNames = [ordered]@{ standard = 'standardowy'; private = 'prywatny'; shared = 'udostępniony' }

function ConvertTo-HTTeamChannelRow {
    param([Parameter(Mandatory)][object]$Channel, [string]$TeamName = '', [string]$TeamId = '', [string]$GeneralId = '')
    $type = [string]$Channel.membershipType
    $general = ($GeneralId -and [string]$Channel.id -eq $GeneralId)
    return [PSCustomObject]@{
        Zespół    = $TeamName
        Kanał     = [string]$Channel.displayName
        Rodzaj    = $(if ($general) { 'ogólny (nie do usunięcia)' } elseif ($script:ChannelTypeNames.Contains($type)) { $script:ChannelTypeNames[$type] } else { $type })
        Opis      = [string]$Channel.description
        Utworzono = $Channel.createdDateTime
        'E-mail'  = [string]$Channel.email
        Link      = [string]$Channel.webUrl
        Id        = [string]$Channel.id
        IsGeneral = [bool]$general
        __team    = $TeamId
        __flag    = $(if ($general) { 'muted' } else { '' })
    }
}

function Get-HTTeamChannels {
    # Kanały zespołu (kanał ogólny pierwszy - nie można go usunąć)
    param([Parameter(Mandatory)][string]$TeamId, [string]$TeamName = '')
    $generalId = ''
    try { $generalId = [string](Invoke-HTGraphRequest -Uri "teams/$TeamId/primaryChannel?`$select=id").id } catch { Write-Log -Message "Kanał ogólny zespołu $($TeamName): $($_.Exception.Message)" -Type 'Warn' }
    $channels = @(Invoke-HTGraphRequest -Uri "teams/$TeamId/channels?`$select=id,displayName,description,membershipType,createdDateTime,email,webUrl")
    return @($channels | ForEach-Object { ConvertTo-HTTeamChannelRow -Channel $_ -TeamName $TeamName -TeamId $TeamId -GeneralId $generalId } | Sort-Object @{ Expression = { -not $_.IsGeneral } }, Kanał)
}

function Test-HTTeamChannelName {
    # Nazwa kanału: do 50 znaków, bez ~ # % & * { } + / \ : < > ? | ' " , i «..», nie zaczyna się od _ ani kropki, nie kończy kropką
    param([AllowEmptyString()][string]$Name)
    $n = ([string]$Name).Trim()
    if (-not $n) { return 'Podaj nazwę kanału.' }
    if ($n.Length -gt 50) { return 'Nazwa kanału może mieć najwyżej 50 znaków.' }
    if ($n -match '[~#%&\*\{\}\+/\\:<>\?\|''",]' -or $n.Contains('..')) { return 'Nazwa kanału nie może zawierać znaków ~ # % & * { } + / \ : < > ? | '' " , ani dwóch kropek.' }
    if ($n -match '^[_\.]' -or $n.EndsWith('.')) { return 'Nazwa kanału nie może zaczynać się od _ ani kropki i kończyć kropką.' }
    if ($n -in 'General', 'Ogólny') { return 'Kanał ogólny już istnieje w każdym zespole.' }
    return ''
}

function Get-HTTeamChannelBody {
    # Kanał: standardowy (wszyscy członkowie), prywatny albo udostępniony (wymagany właściciel - członek zespołu)
    param([Parameter(Mandatory)][string]$DisplayName, [string]$Description = '', [ValidateSet('standard', 'private', 'shared')][string]$MembershipType = 'standard', [string[]]$OwnerIds = @())
    $problem = Test-HTTeamChannelName $DisplayName
    if ($problem) { throw $problem }
    $body = [ordered]@{ displayName = $DisplayName.Trim(); membershipType = $MembershipType }
    if ($Description.Trim()) { $body.description = $Description.Trim() }
    if ($MembershipType -ne 'standard') {
        $owners = @($OwnerIds | Where-Object { $_ } | Select-Object -Unique)
        if (-not $owners.Count) { throw 'Kanał prywatny i udostępniony wymaga właściciela (członka zespołu).' }
        $body.members = @($owners | ForEach-Object { [ordered]@{ '@odata.type' = '#microsoft.graph.aadUserConversationMember'; 'user@odata.bind' = "https://graph.microsoft.com/v1.0/users('$_')"; roles = @('owner') } })
    }
    return $body
}

function New-HTTeamChannel {
    param([Parameter(Mandatory)][string]$TeamId, [Parameter(Mandatory)][string]$DisplayName, [string]$Description = '', [ValidateSet('standard', 'private', 'shared')][string]$MembershipType = 'standard', [string[]]$OwnerIds = @())
    $body = Get-HTTeamChannelBody -DisplayName $DisplayName -Description $Description -MembershipType $MembershipType -OwnerIds $OwnerIds
    return Invoke-HTGraphRequest -Uri "teams/$TeamId/channels" -Method POST -Body $body
}

function Remove-HTTeamChannel {
    # Usunięcie kanału (pliki kanału zostają w witrynie zespołu; kanał można przywrócić w Teams przez 30 dni)
    param([Parameter(Mandatory)][string]$TeamId, [Parameter(Mandatory)][string]$ChannelId)
    Invoke-HTGraphRequest -Uri "teams/$TeamId/channels/$ChannelId" -Method DELETE | Out-Null
}
#endregion
