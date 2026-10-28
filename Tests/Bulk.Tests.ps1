BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    Import-HTTestModule -Name "Utils", "GraphAPIM365Users", "MailboxesExchangeOnline"
    Initialize-HTTestEnvironment -Root $TestDrive
}

Describe "Masowe tworzenie kont - plik CSV" {
    It "szablon wczytuje się z powrotem z wieloma wartościami w polu" {
        $path = Join-Path $TestDrive 'nowe.csv'
        [System.IO.File]::WriteAllText($path, (Get-HTBulkUserTemplate), (New-Object System.Text.UTF8Encoding($true)))
        $rows = @(Import-HTBulkUserCsv -Path $path)
        $rows.Count | Should -Be 1
        $rows[0].Imie | Should -Be 'Jan'
        $check = Test-HTBulkUserRow -Row $rows[0] -Domains @('firma.pl')
        $check.Valid | Should -BeTrue
        $check.Upn | Should -Be 'jan.kowalski@firma.pl'
        $check.Groups | Should -Be @('Sprzedaż', 'Wszyscy')
    }
    It "zgłasza błędy: domena, duplikat UPN, nieznana licencja, lokalizacja" {
        $row = [PSCustomObject]@{ Imie = 'Łukasz'; Nazwisko = 'Żółć'; Domena = 'obca.pl'; Licencje = 'NIEZNANA'; LokalizacjaUzycia = 'POL' }
        $check = Test-HTBulkUserRow -Row $row -Domains @('firma.pl') -KnownSkus @('SPE_E3')
        $check.Valid | Should -BeFalse
        $check.Login | Should -Be 'lukasz.zolc'
        ($check.Errors -join '; ') | Should -Match 'nie jest zweryfikowana'
        ($check.Errors -join '; ') | Should -Match 'nieznana licencja'
        ($check.Errors -join '; ') | Should -Match '2 litery'
        $dup = Test-HTBulkUserRow -Row ([PSCustomObject]@{ Imie = 'Jan'; Nazwisko = 'Nowak' }) -Domains @('firma.pl') -ExistingUpns @('Jan.Nowak@firma.pl')
        ($dup.Errors -join '; ') | Should -Match 'już istnieje'
        $seen = Test-HTBulkUserRow -Row ([PSCustomObject]@{ Imie = 'Jan'; Nazwisko = 'Nowak' }) -Domains @('firma.pl') -SeenUpns @('jan.nowak@firma.pl')
        ($seen.Errors -join '; ') | Should -Match 'powtarza się'
    }
    It "login z adresem e-mail ustawia domenę" {
        $check = Test-HTBulkUserRow -Row ([PSCustomObject]@{ Imie = 'A'; Nazwisko = 'B'; Login = 'ab@firma.pl' }) -Domains @('firma.pl', 'firma.onmicrosoft.com')
        $check.Upn | Should -Be 'ab@firma.pl'
    }
}

Describe "Skrzynki współdzielone a licencje" {
    It "zaleca licencję lub jej usunięcie" -TestCases @(
        @{ Size = 10; Licensed = $true; Archive = $false; Hold = $false; Flag = 'warn'; Text = 'zbędna' }
        @{ Size = 60; Licensed = $false; Archive = $false; Hold = $false; Flag = 'crit'; Text = 'ponad 50 GB' }
        @{ Size = 5; Licensed = $false; Archive = $true; Hold = $false; Flag = 'crit'; Text = 'archiwum' }
        @{ Size = 5; Licensed = $false; Archive = $false; Hold = $true; Flag = 'crit'; Text = 'Litigation Hold' }
        @{ Size = 47; Licensed = $false; Archive = $false; Hold = $false; Flag = 'warn'; Text = 'Blisko' }
        @{ Size = 5; Licensed = $false; Archive = $false; Hold = $false; Flag = ''; Text = 'OK' }
        @{ Size = 70; Licensed = $true; Archive = $false; Hold = $false; Flag = ''; Text = 'potrzebna' }
    ) {
        param($Size, $Licensed, $Archive, $Hold, $Flag, $Text)
        $a = Get-HTSharedMailboxAdvice -SizeGB $Size -Licensed $Licensed -Archive $Archive -Hold $Hold
        $a.Flag | Should -Be $Flag
        $a.Advice | Should -Match $Text
    }
}
