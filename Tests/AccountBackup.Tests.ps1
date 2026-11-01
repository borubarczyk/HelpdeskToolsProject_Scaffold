BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    Import-HTTestModule -Name "Utils", "AccountBackup"
    Initialize-HTTestEnvironment -Root $TestDrive
    function global:New-HTTestBackup {
        param([bool]$Enabled = $true, $Mailbox = $null)
        [ordered]@{
            Version     = 1
            Created     = '2026-11-01T15:30:00.0000000Z'
            CreatedBy   = 'admin'
            User        = [ordered]@{ Id = 'u-1'; UserPrincipalName = 'jan.kowalski@firma.pl'; DisplayName = 'Jan Kowalski'; AccountEnabled = $Enabled; UsageLocation = 'PL' }
            Manager     = [ordered]@{ Id = 'm-1'; UserPrincipalName = 'szef@firma.pl' }
            Licenses    = @([ordered]@{ SkuId = 's-1'; Name = 'Microsoft 365 Business Premium'; Direct = $true }, [ordered]@{ SkuId = 's-2'; Name = 'Exchange Online (Plan 1)'; Direct = $false })
            Groups      = @([ordered]@{ Id = 'g-1'; DisplayName = 'Wszyscy'; Type = 'Microsoft 365'; Dynamic = $false; Synced = $false }, [ordered]@{ Id = 'g-2'; DisplayName = 'Dynamiczna'; Dynamic = $true; Synced = $false })
            AuthMethods = @([ordered]@{ Type = 'Microsoft Authenticator'; Detail = 'iPhone' })
            Mailbox     = $Mailbox
        }
    }
}

AfterAll { Remove-Item -LiteralPath Function:New-HTTestBackup -ErrorAction SilentlyContinue }

Describe "Kopia ustawień konta przed offboardingiem" {
    It "nazywa plik kopii UPN-em i datą bez znaków niedozwolonych" {
        Get-HTAccountBackupFileName -UserPrincipalName 'jan kowalski@firma.pl' -Date ([datetime]'2026-11-01 17:05:09') | Should -Be 'Kopia_jan_kowalski@firma.pl_20261101_170509.json'
    }
    It "zapisuje kopię do pliku i odczytuje ją z powrotem" {
        $dir = Join-Path $TestDrive 'kopie'
        $path = Save-HTAccountBackup -Backup (New-HTTestBackup) -Directory $dir
        Test-Path -LiteralPath $path | Should -BeTrue
        $read = Read-HTAccountBackup -Path $path
        $read.User.UserPrincipalName | Should -Be 'jan.kowalski@firma.pl'
        @($read.Licenses).Count | Should -Be 2
        $read.Manager.Id | Should -Be 'm-1'
    }
    It "odrzuca plik, który nie jest kopią konta" {
        $path = Join-Path $TestDrive 'inny.json'
        '{ "Name": "x" }' | Set-Content -LiteralPath $path -Encoding utf8
        { Read-HTAccountBackup -Path $path } | Should -Throw '*nie jest plik kopii*'
    }
}

Describe "Plan przywrócenia konta z kopii" {
    It "przywraca logowanie, hasło, przełożonego, licencje bezpośrednie i grupy (bez dynamicznych) w tej kolejności" {
        $plan = @(Get-HTAccountRestorePlan -Backup (New-HTTestBackup))
        $plan.Key | Should -Be @('Enable', 'Password', 'Manager', 'Licenses', 'Groups')
        ($plan | Where-Object Key -eq 'Licenses').Text | Should -Be 'Licencje (1): Microsoft 365 Business Premium'
        ($plan | Where-Object Key -eq 'Groups').Text | Should -Be 'Grupy (1): Wszyscy'
        ($plan | Where-Object Key -eq 'Manager').Text | Should -Be 'Przełożony: szef@firma.pl'
    }
    It "nie włącza logowania kontu, które było zablokowane przed offboardingiem" {
        @(Get-HTAccountRestorePlan -Backup (New-HTTestBackup -Enabled $false)).Key | Should -Not -Contain 'Enable'
    }
    It "dodaje kroki skrzynki: typ, GAL, przekierowanie i autoodpowiedź" {
        $plan = @(Get-HTAccountRestorePlan -Backup (New-HTTestBackup -Mailbox ([ordered]@{ Type = 'UserMailbox'; HiddenFromGAL = $false; ForwardTo = ''; KeepCopy = $false; AutoReplyState = 'Disabled' })))
        @($plan | Where-Object Service -eq 'Exchange').Key | Should -Be @('MailboxType', 'Gal', 'Forwarding', 'AutoReply')
        ($plan | Where-Object Key -eq 'Forwarding').Text | Should -Be 'Usuń przekierowanie poczty'
        $shared = @(Get-HTAccountRestorePlan -Backup (New-HTTestBackup -Mailbox ([ordered]@{ Type = 'SharedMailbox'; HiddenFromGAL = $true; ForwardTo = 'szef@firma.pl'; KeepCopy = $true; AutoReplyState = 'Enabled' })))
        @($shared | Where-Object Service -eq 'Exchange').Key | Should -Be @('Forwarding')
        ($shared | Where-Object Key -eq 'Forwarding').Text | Should -Be 'Przekierowanie jak przed offboardingiem: szef@firma.pl (z kopią)'
    }
    It "opisuje kopię: konto, datę i metody MFA do ponownej rejestracji" {
        $text = Get-HTAccountBackupSummary -Backup (New-HTTestBackup)
        $text | Should -Match 'Jan Kowalski <jan.kowalski@firma.pl>'
        $text | Should -Match 'Metody MFA w chwili kopii \(1\): Microsoft Authenticator'
        $text | Should -Match 'bez danych skrzynki'
    }
}
