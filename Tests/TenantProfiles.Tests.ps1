BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    Import-HTTestModule -Name "Utils", "TenantProfiles"
    Initialize-HTTestEnvironment -Root $TestDrive
}

Describe "Profile tenantów - normalizacja i walidacja" {
    It "uzupełnia profil ze starszej konfiguracji (Name, TenantId, Organization, PartnerAccount, Gdap)" {
        $p = ConvertTo-HTTenantProfile ([PSCustomObject]@{ Name = ' Klient ABC '; TenantId = 'abc.onmicrosoft.com'; Organization = 'abc.onmicrosoft.com'; PartnerAccount = 'admin@partner.pl'; Gdap = $true })
        $p.Name | Should -Be 'Klient ABC'
        $p.Gdap | Should -BeTrue
        $p.Services | Should -Be @('Graph', 'Exchange')
        $p.SharePointUrl | Should -Be ''
        $p.LastUsed | Should -Be ''
    }
    It "zamienia domenę tenantu w adresie SharePoint i dopisuje https://" {
        (ConvertTo-HTTenantProfile @{ Name = 'A'; TenantId = 'a.onmicrosoft.com'; SharePointUrl = 'a.onmicrosoft.com/sites/IT/' }).SharePointUrl | Should -Be 'https://a.sharepoint.com/sites/IT'
        Get-HTTenantSharePointSuggestion -Domain 'Klient.onmicrosoft.com' | Should -Be 'https://klient.sharepoint.com'
        Get-HTTenantSharePointSuggestion -Domain 'klient.pl' | Should -Be ''
    }
    It "rozpoznaje nazwy usług <Text>" -TestCases @(
        @{ Text = 'Microsoft 365, Exchange, SharePoint'; Expected = @('Graph', 'Exchange', 'SharePoint') }
        @{ Text = 'pnp;graph'; Expected = @('Graph', 'SharePoint') }
        @{ Text = 'EXO'; Expected = @('Exchange') }
    ) {
        param($Text, $Expected)
        ConvertTo-HTTenantServiceList $Text | Should -Be $Expected
    }
    It "zgłasza błędy profilu" {
        $existing = @([PSCustomObject]@{ Name = 'Klient ABC'; TenantId = 'abc.onmicrosoft.com' })
        @(Test-HTTenantProfile -TenantProfile @{ Name = 'klient abc'; TenantId = 'x.onmicrosoft.com' } -Existing $existing) | Should -Match 'już istnieje'
        @(Test-HTTenantProfile -TenantProfile @{ Name = 'Klient ABC'; TenantId = 'abc.onmicrosoft.com' } -Existing $existing -OriginalName 'Klient ABC').Count | Should -Be 0
        @(Test-HTTenantProfile -TenantProfile @{ Name = 'B' }) | Should -Match 'podaj tenant'
        @(Test-HTTenantProfile -TenantProfile @{ Name = 'B'; TenantId = 'zły tenant' }) | Should -Match 'domenę'
        @(Test-HTTenantProfile -TenantProfile @{ Name = 'B'; TenantId = 'b.onmicrosoft.com'; PnPClientId = 'abc' }) | Should -Match 'GUID'
        @(Test-HTTenantProfile -TenantProfile @{ Name = 'B'; TenantId = 'b.onmicrosoft.com'; Organization = 'b.onmicrosoft.com'; Gdap = $true; Services = 'Exchange' }) | Should -Match 'konta partnera'
    }
    It "ocenia gotowość usług (Client ID PnP z profilu albo z ustawień)" {
        $p = @{ Name = 'C'; TenantId = 'c.onmicrosoft.com'; Organization = 'c.onmicrosoft.com'; Gdap = $true; SharePointUrl = 'https://c.sharepoint.com' }
        $status = Get-HTTenantProfileServiceStatus -TenantProfile $p
        $status.Graph.Ready | Should -BeTrue
        $status.Exchange.Ready | Should -BeFalse
        $status.SharePoint.Ready | Should -BeFalse
        (Get-HTTenantProfileServiceStatus -TenantProfile $p -DefaultClientId '11111111-1111-1111-1111-111111111111').SharePoint.Ready | Should -BeTrue
    }
}

Describe "Profile tenantów - wyszukiwanie, scalanie i CSV" {
    It "szuka po nazwie, domenie i notatkach; ostatnio używane na początku" {
        $profiles = @(
            @{ Name = 'Alfa'; TenantId = 'alfa.onmicrosoft.com'; Notes = 'serwis' }
            @{ Name = 'Beta'; TenantId = 'beta.onmicrosoft.com'; LastUsed = '2026-10-30T10:00:00.0000000Z' }
            @{ Name = 'Gamma'; TenantId = 'gamma.onmicrosoft.com'; LastUsed = '2026-11-01T10:00:00.0000000Z' }
        )
        @(Find-HTTenantProfiles -Profiles $profiles).Name | Should -Be @('Gamma', 'Beta', 'Alfa')
        @(Find-HTTenantProfiles -Profiles $profiles -Query 'serwis').Name | Should -Be @('Alfa')
        @(Find-HTTenantProfiles -Profiles $profiles -Query 'beta.onm').Name | Should -Be @('Beta')
    }
    It "scala profile: zastępuje albo pomija te same nazwy i zachowuje datę użycia" {
        $existing = @(@{ Name = 'Alfa'; TenantId = 'alfa.onmicrosoft.com'; LastUsed = '2026-10-30T10:00:00Z' })
        $incoming = @(@{ Name = 'alfa'; TenantId = 'alfa2.onmicrosoft.com' }, @{ Name = 'Nowy'; TenantId = 'nowy.onmicrosoft.com' })
        $replace = Merge-HTTenantProfiles -Existing $existing -Incoming $incoming -Mode Replace
        $replace.Added | Should -Be 1
        $replace.Replaced | Should -Be 1
        @($replace.Profiles | Where-Object Name -eq 'alfa')[0].TenantId | Should -Be 'alfa2.onmicrosoft.com'
        @($replace.Profiles | Where-Object Name -eq 'alfa')[0].LastUsed | Should -Be '2026-10-30T10:00:00Z'
        $skip = Merge-HTTenantProfiles -Existing $existing -Incoming $incoming -Mode Skip
        $skip.Skipped | Should -Be 1
        @($skip.Profiles | Where-Object Name -eq 'Alfa')[0].TenantId | Should -Be 'alfa.onmicrosoft.com'
    }
    It "eksportuje i importuje profile przez CSV (polskie znaki, średniki w notatkach)" {
        $path = Join-Path $TestDrive 'profile.csv'
        $profiles = @(
            @{ Name = 'Łódź Sp. z o.o.'; TenantId = 'lodz.onmicrosoft.com'; Organization = 'lodz.onmicrosoft.com'; PartnerAccount = 'admin@partner.pl'; Gdap = $true; SharePointUrl = 'https://lodz.sharepoint.com'; PnPClientId = '22222222-2222-2222-2222-222222222222'; Services = 'Graph,Exchange,SharePoint'; Notes = 'umowa; kontakt: Jan' }
            @{ Name = 'Własny'; TenantId = 'firma.onmicrosoft.com'; Gdap = $false; Services = 'Graph' }
        )
        Export-HTTenantProfilesCsv -Profiles $profiles -Path $path
        $result = Import-HTTenantProfilesCsv -Path $path
        $result.Errors.Count | Should -Be 0
        $result.Profiles.Count | Should -Be 2
        $first = $result.Profiles[0]
        $first.Name | Should -Be 'Łódź Sp. z o.o.'
        $first.Notes | Should -Be 'umowa; kontakt: Jan'
        $first.Services | Should -Be @('Graph', 'Exchange', 'SharePoint')
        $first.Gdap | Should -BeTrue
        $result.Profiles[1].Gdap | Should -BeFalse
    }
    It "importuje plik z angielskimi nagłówkami i przecinkiem, pomijając wiersze z błędami" {
        $path = Join-Path $TestDrive 'en.csv'
        Set-Content -Path $path -Encoding utf8 -Value @(
            'Name,TenantId,PartnerAccount,SharePointUrl'
            'Client A,a.onmicrosoft.com,admin@partner.pl,a.onmicrosoft.com'
            ',b.onmicrosoft.com,,'
            'Client C,bad tenant,,'
        )
        $result = Import-HTTenantProfilesCsv -Path $path
        $result.Profiles.Count | Should -Be 1
        $result.Profiles[0].SharePointUrl | Should -Be 'https://a.sharepoint.com'
        $result.Profiles[0].Gdap | Should -BeTrue
        $result.Errors.Count | Should -Be 2
        $result.Errors[0] | Should -Match 'wiersz 3'
    }
    It "zapisuje szablon CSV z nagłówkiem w kolejności pól" {
        $template = Get-HTTenantProfilesCsvTemplate
        ($template -split "`r`n")[0] | Should -Be 'Nazwa;Tenant;Organizacja Exchange;Konto partnera;GDAP;SharePoint;Client ID PnP;Usługi;Notatki'
    }
    It "buduje wiersz tabeli z brakami danych dla wybranych usług" {
        $row = ConvertTo-HTTenantProfileRow -TenantProfile @{ Name = 'D'; TenantId = 'd.onmicrosoft.com'; SharePointUrl = 'https://d.sharepoint.com'; Services = 'Graph, SharePoint'; Gdap = $false; LastUsed = '2026-11-01T10:00:00Z' }
        $row.Braki | Should -Match 'SharePoint: brak Client ID PnP'
        $row.__flag | Should -Be 'warn'
        $row.'Ostatnio użyty' | Should -Match '^2026-11-01'
        $row.__profile.Name | Should -Be 'D'
    }
}
