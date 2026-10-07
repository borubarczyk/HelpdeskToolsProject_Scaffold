BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    Import-HTTestModule -Name "Utils", "Config", "Security"
    Initialize-HTTestEnvironment -Root $TestDrive
}

Describe "PIN programu" {
    It "akceptuje tylko 4-8 cyfr" {
        Test-HTPinFormat "1234" | Should -BeTrue
        Test-HTPinFormat "12345678" | Should -BeTrue
        Test-HTPinFormat "123" | Should -BeFalse
        Test-HTPinFormat "123456789" | Should -BeFalse
        Test-HTPinFormat "12a4" | Should -BeFalse
        Test-HTPinFormat "" | Should -BeFalse
    }
    It "zapisuje skrót z solą, a nie sam PIN" {
        $record = New-HTPinRecord -Pin "48213"
        $record.PinLength | Should -Be 5
        $record.PinHash | Should -Not -Match "48213"
        (New-HTPinRecord -Pin "48213").PinSalt | Should -Not -Be $record.PinSalt
    }
    It "sprawdza poprawny i błędny PIN" {
        $config = [PSCustomObject](New-HTPinRecord -Pin "48213")
        Test-HTPinConfigured -Config $config | Should -BeTrue
        Test-HTPin -Pin "48213" -Config $config | Should -BeTrue
        Test-HTPin -Pin "48214" -Config $config | Should -BeFalse
        Test-HTPin -Pin "" -Config $config | Should -BeFalse
    }
    It "traktuje brak PIN-u w konfiguracji jako nieustawiony" {
        $config = (Merge-HTConfig -Config $null).Config
        Test-HTPinConfigured -Config $config | Should -BeFalse
        Test-HTPin -Pin "1234" -Config $config | Should -BeFalse
    }
    It "Set-HTPin zapisuje PIN w pliku konfiguracji" {
        $Global:ConfigPath = Join-Path $TestDrive "pin.json"
        Apply-HTConfig -Config (Merge-HTConfig -Config $null).Config
        Set-HTPin -Pin "73519"
        $saved = Get-Content $Global:ConfigPath -Raw | ConvertFrom-Json
        $saved.PinLength | Should -Be 5
        Test-HTPin -Pin "73519" -Config $saved | Should -BeTrue
    }
}
