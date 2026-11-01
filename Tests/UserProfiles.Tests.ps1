BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    Import-HTTestModule -Name "Utils", "UserProfiles"
    Initialize-HTTestEnvironment -Root $TestDrive
}

Describe "Profile tworzenia kont - login i normalizacja" {
    It "tworzy login z formatu <Format> (polskie znaki, spacje, myślniki)" -TestCases @(
        @{ Format = '{imie}.{nazwisko}'; Expected = 'lukasz.zolc-nowak' }
        @{ Format = '{i}.{nazwisko}'; Expected = 'l.zolc-nowak' }
        @{ Format = '{i}{nazwisko}'; Expected = 'lzolc-nowak' }
        @{ Format = '{nazwisko}.{imie}'; Expected = 'zolc-nowak.lukasz' }
        @{ Format = '{nazwisko}{i}'; Expected = 'zolc-nowakl' }
        @{ Format = ''; Expected = 'lukasz.zolc-nowak' }
    ) {
        param($Format, $Expected)
        ConvertTo-HTLoginFromFormat -Format $Format -GivenName 'Łukasz' -Surname 'Żółć-Nowak ' | Should -Be $Expected
    }
    It "uzupełnia profil wartościami domyślnymi i dzieli listy licencji i grup" {
        $p = ConvertTo-HTUserProfile @{ Name = ' Klient A '; Domain = '@Klient.PL'; UsageLocation = 'pl'; Licenses = "SPB`nSPB, EXCHANGESTANDARD"; Groups = 'Wszyscy; Biuro' }
        $p.Name | Should -Be 'Klient A'
        $p.Domain | Should -Be 'klient.pl'
        $p.UsageLocation | Should -Be 'PL'
        $p.LoginFormat | Should -Be '{imie}.{nazwisko}'
        $p.ForceChange | Should -BeTrue
        $p.Licenses | Should -Be @('SPB', 'EXCHANGESTANDARD')
        $p.Groups | Should -Be @('Wszyscy', 'Biuro')
    }
    It "zgłasza błędy profilu" {
        $existing = @(ConvertTo-HTUserProfile @{ Name = 'Klient A' })
        @(Test-HTUserProfile -UserProfile @{ Name = '' }) | Should -Match 'nazwę profilu'
        @(Test-HTUserProfile -UserProfile @{ Name = 'klient a' } -Existing $existing) | Should -Match 'już istnieje'
        @(Test-HTUserProfile -UserProfile @{ Name = 'Klient A' } -Existing $existing -OriginalName 'Klient A').Count | Should -Be 0
        @(Test-HTUserProfile -UserProfile @{ Name = 'B'; Domain = 'zła domena' }) | Should -Match 'Domena'
        @(Test-HTUserProfile -UserProfile @{ Name = 'B'; UsageLocation = 'POL' }) | Should -Match 'dwuliterowy'
        @(Test-HTUserProfile -UserProfile @{ Name = 'B'; LoginFormat = 'login' }) | Should -Match 'Format loginu'
        @(Test-HTUserProfile -UserProfile @{ Name = 'B'; TemplateUser = 'jan' }) | Should -Match 'UPN'
    }
}

Describe "Profile tworzenia kont - zapis, wybór i import" {
    It "zapisuje i odczytuje profile (plik w folderze konfiguracji)" {
        Save-HTUserProfiles -Profiles @(@{ Name = 'Beta'; Domain = 'beta.pl'; Licenses = @('SPB') }, @{ Name = 'Alfa'; Groups = @('Wszyscy') })
        Test-Path -LiteralPath (Get-HTUserProfilesPath) | Should -BeTrue
        $loaded = @(Get-HTUserProfiles)
        $loaded.Name | Should -Be @('Alfa', 'Beta')
        $loaded[1].Licenses | Should -Be @('SPB')
    }
    It "wybiera profile pasujące do domen tenanta, ostatnio używane na początku" {
        $profiles = @(
            ConvertTo-HTUserProfile @{ Name = 'Inny'; Domain = 'inny.pl' }
            ConvertTo-HTUserProfile @{ Name = 'Ogólny' }
            ConvertTo-HTUserProfile @{ Name = 'Klient'; Domain = 'klient.pl'; LastUsed = '2026-11-01T10:00:00Z' }
        )
        @(Find-HTUserProfilesForDomains -Profiles $profiles -Domains @('Klient.pl', 'klient.onmicrosoft.com')).Name | Should -Be @('Klient', 'Ogólny')
        @(Find-HTUserProfilesForDomains -Profiles $profiles -Domains @('klient.pl') -All).Name | Should -Be @('Klient', 'Ogólny', 'Inny')
    }
    It "opisuje profil przykładowym loginem" {
        Get-HTUserProfileDescription (@{ Name = 'K'; Domain = 'klient.pl'; LoginFormat = '{i}.{nazwisko}'; Licenses = @('SPB'); Groups = @('A', 'B') }) | Should -Be 'login: j.kowalski@klient.pl • licencje: 1 • grupy: 2'
    }
    It "scala import: zastępuje profile o tej samej nazwie albo je pomija" {
        $existing = @(@{ Name = 'Alfa'; Domain = 'a.pl'; LastUsed = '2026-10-01' })
        $incoming = @(@{ Name = 'alfa'; Domain = 'a2.pl' }, @{ Name = 'Nowy' })
        $r = Merge-HTUserProfiles -Existing $existing -Incoming $incoming
        $r.Added | Should -Be 1
        $r.Replaced | Should -Be 1
        @($r.Profiles | Where-Object Name -eq 'alfa')[0].Domain | Should -Be 'a2.pl'
        @($r.Profiles | Where-Object Name -eq 'alfa')[0].LastUsed | Should -Be '2026-10-01'
        (Merge-HTUserProfiles -Existing $existing -Incoming $incoming -Skip).Skipped | Should -Be 1
    }
}
