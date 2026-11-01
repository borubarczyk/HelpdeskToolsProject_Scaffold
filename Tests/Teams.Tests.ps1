BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    Import-HTTestModule -Name "Utils", "ModulesConnection", "GraphAPITeams"
    Initialize-HTTestEnvironment -Root $TestDrive
}

Describe "Zespół z grupy Microsoft 365" {
    It "ustawienia zespołu: kanały członków, gości i Giphy" {
        $b = Get-HTTeamFromGroupBody -MembersCanCreateChannels $false -MembersCanDeleteChannels $true -AllowGiphy $false
        $b.memberSettings.allowCreateUpdateChannels | Should -BeFalse
        $b.memberSettings.allowCreatePrivateChannels | Should -BeFalse
        $b.memberSettings.allowDeleteChannels | Should -BeTrue
        $b.guestSettings.allowCreateUpdateChannels | Should -BeFalse
        $b.funSettings.allowGiphy | Should -BeFalse
        $b.funSettings.giphyContentRating | Should -Be 'strict'
    }
    It "grupa jeszcze niewidoczna dla Teams (404) - ponawia, inny błąd - od razu" {
        $global:HTTestTeamCalls = 0
        Mock -ModuleName GraphAPITeams Start-Sleep { }
        Mock -ModuleName GraphAPITeams Write-Log { }
        Mock -ModuleName GraphAPITeams Invoke-HTGraphRequest { $global:HTTestTeamCalls++; if ($global:HTTestTeamCalls -lt 3) { throw 'NotFound: 404 group not found' }; [PSCustomObject]@{ id = 'g1' } }
        (New-HTTeamFromGroup -GroupId 'g1' -DelaySeconds 0).id | Should -Be 'g1'
        $global:HTTestTeamCalls | Should -Be 3
        Mock -ModuleName GraphAPITeams Invoke-HTGraphRequest { throw 'Forbidden: no owner' }
        { New-HTTeamFromGroup -GroupId 'g1' -DelaySeconds 0 } | Should -Throw '*Forbidden*'
    }
}

Describe "Kanały zespołu" {
    It "nazwa kanału: długość, niedozwolone znaki, kropki, kanał ogólny" {
        Test-HTTeamChannelName 'Projekt X' | Should -Be ''
        Test-HTTeamChannelName '' | Should -Match 'Podaj'
        Test-HTTeamChannelName ('a' * 51) | Should -Match '50'
        Test-HTTeamChannelName 'Projekt #1' | Should -Match 'znaków'
        Test-HTTeamChannelName 'a..b' | Should -Match 'kropek'
        Test-HTTeamChannelName '_ukryty' | Should -Match 'zaczynać'
        Test-HTTeamChannelName 'koniec.' | Should -Match 'kończyć'
        Test-HTTeamChannelName 'General' | Should -Match 'ogólny'
    }
    It "kanał standardowy bez członków; prywatny wymaga właściciela" {
        $b = Get-HTTeamChannelBody -DisplayName ' Wsparcie ' -Description 'Opis'
        $b.displayName | Should -Be 'Wsparcie'
        $b.membershipType | Should -Be 'standard'
        $b.Contains('members') | Should -BeFalse
        { Get-HTTeamChannelBody -DisplayName 'Zarząd' -MembershipType private } | Should -Throw '*właściciela*'
        $p = Get-HTTeamChannelBody -DisplayName 'Zarząd' -MembershipType private -OwnerIds @('u1')
        $p.members[0].roles | Should -Be @('owner')
        $p.members[0].'user@odata.bind' | Should -Be "https://graph.microsoft.com/v1.0/users('u1')"
        { Get-HTTeamChannelBody -DisplayName 'Zły/kanał' } | Should -Throw
    }
    It "lista kanałów: ogólny pierwszy i oznaczony jako nie do usunięcia" {
        Mock -ModuleName GraphAPITeams Write-Log { }
        Mock -ModuleName GraphAPITeams Invoke-HTGraphRequest {
            if ($Uri -like '*primaryChannel*') { return [PSCustomObject]@{ id = 'c-gen' } }
            @([PSCustomObject]@{ id = 'c-2'; displayName = 'Alfa'; membershipType = 'private' }, [PSCustomObject]@{ id = 'c-gen'; displayName = 'General'; membershipType = 'standard' })
        }
        $rows = @(Get-HTTeamChannels -TeamId 't1' -TeamName 'Zespół')
        $rows[0].IsGeneral | Should -BeTrue
        $rows[0].Rodzaj | Should -Match 'ogólny'
        $rows[1].Rodzaj | Should -Be 'prywatny'
        $rows[1].__team | Should -Be 't1'
    }
}
