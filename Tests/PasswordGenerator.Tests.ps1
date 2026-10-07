BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    Import-HTTestModule -Name "Utils", "PasswordGenerator"
    Initialize-HTTestEnvironment -Root $TestDrive
}

Describe "New-Password (tryb klasyczny)" {
    It "generuje hasło o długości <Length>" -TestCases @(@{ Length = 4 }, @{ Length = 12 }, @{ Length = 64 }) {
        param($Length)
        (New-Password -Length $Length).Length | Should -Be $Length
    }

    It "zawiera wszystkie wymagane klasy znaków" {
        1..30 | ForEach-Object {
            $password = New-Password -Length 8 -SpecialCharacters "!#"
            $password | Should -MatchExactly '[a-z]'
            $password | Should -MatchExactly '[A-Z]'
            $password | Should -Match '\d'
            $password | Should -Match '[!#]'
        }
    }

    It "obsługuje znaki specjalne będące metaznakami regex (]\-^)" {
        1..20 | ForEach-Object {
            $password = New-Password -Length 10 -SpecialCharacters ']\-^'
            $password.IndexOfAny(']\-^'.ToCharArray()) | Should -BeGreaterOrEqual 0
        }
    }

    It "bez podobnych znaków nie używa l, I, O, 0, 1" {
        1..30 | ForEach-Object {
            New-Password -Length 32 -NoSimilarChars $true -SpecialCharacters "!|" | Should -Not -MatchExactly '[lIO01|]'
        }
    }

    It "rozpoczyna się od litery, gdy StartWithLetter" {
        1..30 | ForEach-Object {
            New-Password -Length 12 -StartWithLetter $true | Should -Match '^[a-zA-Z]'
        }
    }

    It "nie zawiera symboli, gdy IncludeSymbols = false" {
        1..20 | ForEach-Object {
            New-Password -Length 16 -IncludeSymbols $false | Should -Match '^[a-zA-Z0-9]+$'
        }
    }

    It "bez sekwencji i powtórzeń, gdy wymagane" {
        1..10 | ForEach-Object {
            $password = New-Password -Length 12 -NoDuplicateChars $true -NoSequentialChars $true
            @($password.ToCharArray() | Select-Object -Unique).Count | Should -Be 12
            Test-SequentialChars $password | Should -BeFalse
        }
    }
}

Describe "New-Password (tryb przyjazny)" {
    It "zachowuje długość <Length> i kończy się znakiem specjalnym" -TestCases @(@{ Length = 8 }, @{ Length = 13 }, @{ Length = 40 }) {
        param($Length)
        $password = New-Password -Length $Length -FriendlyMode $true -SpecialCharacters "!"
        $password.Length | Should -Be $Length
        $password | Should -Match '!$'
    }
}

Describe "New-WordBasedPassword" {
    It "zachowuje długość <Length>" -TestCases @(@{ Length = 8 }, @{ Length = 12 }, @{ Length = 64 }) {
        param($Length)
        (New-WordBasedPassword -Length $Length).Length | Should -Be $Length
    }
    It "kończy się cyframi i symbolem" {
        New-WordBasedPassword -Length 16 -SpecialCharacters "!" | Should -Match '\d\d!$'
    }
    It "bez cyfr i symboli zawiera tylko litery" {
        New-WordBasedPassword -Length 16 -UseNumbers $false -UseSymbols $false | Should -Match '^[a-zA-Z]+$'
    }
}

Describe "Test-SequentialChars" {
    It "wykrywa sekwencje" {
        Test-SequentialChars "xxABCxx" | Should -BeTrue
        Test-SequentialChars "pass789" | Should -BeTrue
        Test-SequentialChars "Kx7!mQ" | Should -BeFalse
    }
}

Describe "Get-HTPasswordStrength" {
    It "ocenia hasła" {
        (Get-HTPasswordStrength -Password "").Score | Should -Be 0
        (Get-HTPasswordStrength -Password "abcdef").Score | Should -Be 1
        (Get-HTPasswordStrength -Password "Kx7!mQ2#pL9@wZ4%").Score | Should -Be 4
    }
}
