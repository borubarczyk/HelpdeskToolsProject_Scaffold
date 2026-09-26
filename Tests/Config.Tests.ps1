BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    Import-HTTestModule -Name "Utils", "Config"
    Initialize-HTTestEnvironment -Root $TestDrive
    Disable-HTTestToast
}

Describe "Merge-HTConfig" {
    It "uzupełnia brakujące klucze domyślne i zachowuje istniejące" {
        $result = Merge-HTConfig -Config ([PSCustomObject]@{ PasswordEmailTitle = "Własny"; Custom = 1 })
        $result.Config.PasswordEmailTitle | Should -Be "Własny"
        $result.Config.Custom | Should -Be 1
        $result.Config.DefaultUsageLocation | Should -Be "PL"
        $result.AddedKeys | Should -Contain "GraphScopes"
        $result.AddedKeys | Should -Not -Contain "PasswordEmailTitle"
    }
    It "obsługuje słownik" {
        (Merge-HTConfig -Config @{ PasswordDefaultLength = 20 }).Config.PasswordDefaultLength | Should -Be 20
    }
    It "zwraca same wartości domyślne dla null" {
        (Merge-HTConfig -Config $null).Config.LogPasswordGeneration | Should -BeFalse
    }
}

Describe "Ensure-HTConfig / Get-HTConfig" {
    It "tworzy plik z ustawieniami domyślnymi (-Force)" {
        $path = Join-Path $TestDrive "new/config.json"
        $config = Ensure-HTConfig -Path $path -Force
        Test-Path $path | Should -BeTrue
        $config.PasswordEmailTitle | Should -Be "Nowe hasło"
    }
    It "uzupełnia stary plik o nowe klucze i zapisuje go" {
        $path = Join-Path $TestDrive "old.json"
        '{ "PasswordEmailTitle": "Stary" }' | Set-Content $path
        $config = Ensure-HTConfig -Path $path
        $config.PasswordEmailTitle | Should -Be "Stary"
        (Get-Content $path -Raw | ConvertFrom-Json).DefaultUsageLocation | Should -Be "PL"
    }
    It "zwraca ustawienia domyślne, gdy plik zawiera 'null'" {
        $path = Join-Path $TestDrive "null.json"
        "null" | Set-Content $path
        Get-HTConfig -Path $path | Should -BeNullOrEmpty
        (Ensure-HTConfig -Path $path).PasswordDefaultLength | Should -Be 12
    }
}

Describe "Apply-HTConfig" {
    It "ustawia zmienne globalne i koryguje nieprawidłową długość hasła" {
        Apply-HTConfig -Config ([PSCustomObject]@{ PasswordDefaultLength = 200; PasswordUseWordBased = $true; DefaultSharepointSite = "https://x.sharepoint.com/sites/a" })
        $Global:PasswordDefaultLength | Should -Be 12
        $Global:PasswordUseWordBased | Should -BeTrue
        $Global:DefaultSharepointSite | Should -Be "https://x.sharepoint.com/sites/a"
        $Global:GraphScopes | Should -Contain "User.ReadWrite.All"
    }
}

Describe "Set-HTConfigValue" {
    It "zapisuje pojedynczą wartość do pliku" {
        $Global:ConfigPath = Join-Path $TestDrive "value.json"
        Apply-HTConfig -Config (Merge-HTConfig -Config $null).Config
        Set-HTConfigValue -Name "LastUsedClientID" -Value "abc"
        (Get-Content $Global:ConfigPath -Raw | ConvertFrom-Json).LastUsedClientID | Should -Be "abc"
    }
}
