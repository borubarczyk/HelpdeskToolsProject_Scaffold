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
