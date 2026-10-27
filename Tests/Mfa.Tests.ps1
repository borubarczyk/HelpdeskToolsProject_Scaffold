BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    Import-HTTestModule -Name "Utils", "Config", "Security", "Mfa"
    Initialize-HTTestEnvironment -Root $TestDrive
    # Klucz z RFC 6238 (dodatek B) dla HMAC-SHA1
    $script:RfcSecret = [System.Text.Encoding]::ASCII.GetBytes("12345678901234567890")
}

Describe "Base32" {
    It "koduje klucz RFC 6238" {
        ConvertTo-HTBase32 $script:RfcSecret | Should -Be "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"
    }
    It "dekoduje bez względu na wielkość liter, spacje i myślniki" {
        $bytes = ConvertFrom-HTBase32 "gezd gnbv-gy3t qojq gezd gnbv gy3t qojq"
        [System.Text.Encoding]::ASCII.GetString($bytes) | Should -Be "12345678901234567890"
    }
    It "odrzuca niedozwolone znaki" {
        { ConvertFrom-HTBase32 "ABC1" } | Should -Throw
    }
    It "zachowuje losowy klucz po zakodowaniu i odkodowaniu" {
        $secret = New-HTMfaSecret
        $secret.Length | Should -Be 20
        (ConvertFrom-HTBase32 (ConvertTo-HTBase32 $secret)) | Should -Be $secret
    }
}

Describe "TOTP (RFC 6238)" {
    It "daje kod <Expected> dla czasu <Seconds> s (8 cyfr)" -TestCases @(
        @{ Seconds = 59; Expected = "94287082" }
        @{ Seconds = 1111111109; Expected = "07081804" }
        @{ Seconds = 1234567890; Expected = "89005924" }
        @{ Seconds = 2000000000; Expected = "69279037" }
    ) {
        param($Seconds, $Expected)
        $step = Get-HTTotpStep -Time ([DateTimeOffset]::FromUnixTimeSeconds($Seconds).UtcDateTime)
        Get-HTTotpCode -Secret $script:RfcSecret -Step $step -Digits 8 | Should -Be $Expected
    }
    It "daje 6 cyfr domyślnie" {
        Get-HTTotpCode -Secret $script:RfcSecret -Step 1 | Should -Be "287082"
    }
    It "akceptuje kod bieżący i z sąsiednich okien 30 s, odrzuca dalsze" {
        $time = [datetime]::new(2026, 1, 1, 12, 0, 0, [DateTimeKind]::Utc)
        $step = Get-HTTotpStep -Time $time
        Test-HTTotpCode -Secret $script:RfcSecret -Code (Get-HTTotpCode -Secret $script:RfcSecret -Step $step) -Time $time | Should -Be $step
        Test-HTTotpCode -Secret $script:RfcSecret -Code (Get-HTTotpCode -Secret $script:RfcSecret -Step ($step - 1)) -Time $time | Should -Be ($step - 1)
        Test-HTTotpCode -Secret $script:RfcSecret -Code (Get-HTTotpCode -Secret $script:RfcSecret -Step ($step + 1)) -Time $time | Should -Be ($step + 1)
        Test-HTTotpCode -Secret $script:RfcSecret -Code (Get-HTTotpCode -Secret $script:RfcSecret -Step ($step - 3)) -Time $time | Should -Be -1
    }
    It "nie przyjmuje drugi raz kodu z wykorzystanego okna" {
        $time = [datetime]::new(2026, 1, 1, 12, 0, 0, [DateTimeKind]::Utc)
        $step = Get-HTTotpStep -Time $time
        $code = Get-HTTotpCode -Secret $script:RfcSecret -Step $step
        Test-HTTotpCode -Secret $script:RfcSecret -Code $code -Time $time -LastStep $step | Should -Be -2
    }
    It "odrzuca kod o złym formacie" {
        Test-HTTotpCode -Secret $script:RfcSecret -Code "12345" | Should -Be -1
        Test-HTTotpCode -Secret $script:RfcSecret -Code "abcdef" | Should -Be -1
        Test-HTTotpCode -Secret $script:RfcSecret -Code "" | Should -Be -1
    }
    It "buduje link otpauth:// z wystawcą i parametrami" {
        $uri = Get-HTMfaUri -Account "Jan Kowalski" -Base32 "GEZDGNBV"
        $uri | Should -BeLike "otpauth://totp/Helpdesk%20Tools%3AJan%20Kowalski?secret=GEZDGNBV&issuer=Helpdesk%20Tools*"
        $uri | Should -Match "digits=6&period=30"
        Format-HTMfaKey "GEZDGNBVGY" | Should -Be "GEZD GNBV GY"
    }
}

Describe "Konta MFA" {
    BeforeEach {
        $Global:ConfigDir = Join-Path $TestDrive ([guid]::NewGuid().ToString("N"))
        $Global:ConfigPath = Join-Path $Global:ConfigDir "config.json"
        Apply-HTConfig -Config (Merge-HTConfig -Config $null).Config
        Set-HTPin -Pin "48213"
        $script:Primary = Add-HTMfaAccount -Name "Konto podstawowe" -Base32 (ConvertTo-HTBase32 $script:RfcSecret) -Primary
    }

    It "zapisuje konta w pliku bez jawnego klucza" {
        Test-HTMfaEnabled | Should -BeTrue
        $raw = Get-Content (Get-HTMfaFile) -Raw
        $raw | Should -Not -Match "GEZDGNBVGY3TQOJQ"
        @((Read-HTMfaStore).Accounts).Count | Should -Be 1
    }

    It "konto podstawowe używa PIN-u programu, dodatkowe - własnego" {
        $extra = Add-HTMfaAccount -Name "Anna" -Base32 (ConvertTo-HTBase32 (New-HTMfaSecret)) -Pin "7391"
        $list = @(Get-HTMfaUnlockAccounts)
        $list[0].Primary | Should -BeTrue
        Test-HTMfaAccountPin -Account $list[0] -Pin "48213" | Should -BeTrue
        Test-HTMfaAccountPin -Account $list[0] -Pin "7391" | Should -BeFalse
        $anna = $list | Where-Object { $_.Id -eq $extra.Id }
        $anna.PinLength | Should -Be 4
        Test-HTMfaAccountPin -Account $anna -Pin "7391" | Should -BeTrue
        Test-HTMfaAccountPin -Account $anna -Pin "48213" | Should -BeFalse
    }

    It "odrzuca drugie konto o tej samej nazwie, drugie podstawowe i konto dodatkowe bez PIN-u" {
        { Add-HTMfaAccount -Name "konto PODSTAWOWE" -Base32 "GEZDGNBV" -Pin "1357" } | Should -Throw
        { Add-HTMfaAccount -Name "Drugie" -Base32 "GEZDGNBV" -Primary } | Should -Throw
        { Add-HTMfaAccount -Name "Bez PIN" -Base32 "GEZDGNBV" } | Should -Throw
    }

    It "kod z aplikacji działa raz w danym oknie czasu" {
        $account = @(Get-HTMfaUnlockAccounts)[0]
        $code = Get-HTTotpCode -Secret $script:RfcSecret -Step (Get-HTTotpStep)
        Test-HTMfaCodeFor -Account $account -Code $code | Should -Be "Ok"
        Test-HTMfaCodeFor -Account @(Get-HTMfaUnlockAccounts)[0] -Code $code | Should -Be "Used"
        Test-HTMfaCodeFor -Account $account -Code "000000" | Should -BeIn @("Invalid", "Used")
        @(Get-HTMfaUnlockAccounts)[0].LastUsed | Should -Not -BeNullOrEmpty
    }

    It "zapisuje uprawnienia, nowy klucz i nowy PIN konta dodatkowego" {
        $extra = Add-HTMfaAccount -Name "Anna" -Base32 "GEZDGNBV" -Pin "7391" -Deny "ws:Exchange"
        Set-HTMfaAccountDeny -Id $extra.Id -Deny "mod:dash.licenses", "app:Settings"
        $saved = (Read-HTMfaStore).Accounts | Where-Object { $_.Id -eq $extra.Id }
        (Get-HTMfaAccountSecret -Account $saved).Deny | Should -Be @("mod:dash.licenses", "app:Settings")
        Set-HTMfaAccountKey -Id $extra.Id -Base32 "MFRGGZDF" -Name "Anna K."
        Set-HTMfaAccountPin -Id $extra.Id -Pin "86420"
        $saved = (Read-HTMfaStore).Accounts | Where-Object { $_.Id -eq $extra.Id }
        $saved.Name | Should -Be "Anna K."
        (Get-HTMfaAccountSecret -Account $saved).Base32 | Should -Be "MFRGGZDF"
        (Get-HTMfaAccountSecret -Account $saved).Deny | Should -Contain "app:Settings"
        Test-HTMfaAccountPin -Account $saved -Pin "86420" | Should -BeTrue
        { Set-HTMfaAccountDeny -Id $script:Primary.Id -Deny "app:Settings" } | Should -Throw
    }

    It "zatwierdza zmiany kodem konta podstawowego" {
        $extra = Add-HTMfaAccount -Name "Anna" -Base32 "GEZDGNBV" -Pin "7391"
        $list = @(Get-HTMfaUnlockAccounts)
        (Get-HTMfaApprover -Accounts $list -Account ($list | Where-Object { $_.Id -eq $extra.Id })).Id | Should -Be $script:Primary.Id
    }

    It "usuwa konto podstawowe dopiero jako ostatnie, a z ostatnim kontem plik" {
        $extra = Add-HTMfaAccount -Name "Anna" -Base32 "GEZDGNBV" -Pin "7391"
        { Remove-HTMfaAccount -Id $script:Primary.Id } | Should -Throw
        Remove-HTMfaAccount -Id $extra.Id
        Remove-HTMfaAccount -Id $script:Primary.Id
        Test-Path (Get-HTMfaFile) | Should -BeFalse
        Test-HTMfaEnabled | Should -BeFalse
        @(Get-HTMfaUnlockAccounts).Count | Should -Be 0
    }
}

Describe "Uprawnienia kont MFA" {
    AfterEach { Set-HTAccessAccount }

    It "ustawia konto i blokady oraz konto w dzienniku" {
        Set-HTAccessAccount -Name "Anna" -Id "abc" -Deny "ws:Exchange", "app:Settings"
        (Get-HTAccess).Account | Should -Be "Anna"
        Test-HTAccessDenied "ws:Exchange" | Should -BeTrue
        Test-HTAppAllowed "Settings" | Should -BeFalse
        $Global:HTActiveAccount | Should -Be "Anna"
    }
    It "bez blokad daje pełny dostęp" {
        Set-HTAccessAccount
        (Get-HTAccess).AccountId | Should -Be "#primary"
        Test-HTAppAllowed "Settings" | Should -BeTrue
        Get-HTAccessDenyText -Deny @() | Should -Be "pełny dostęp"
    }
    It "opisuje blokady nazwami przestrzeni i modułów" {
        $text = Get-HTAccessDenyText -Deny "ws:Exchange", "mod:lic", "mod:mbx", "app:Settings" -Workspaces @{ Exchange = "Exchange" } `
            -Modules @(@{ Key = "lic"; Title = "Licencje"; Workspace = "M365" }, @{ Key = "mbx"; Title = "Skrzynki"; Workspace = "Exchange" })
        $text | Should -Be "bez przestrzeni: Exchange; bez modułów: Licencje; bez Ustawień"
    }
}
