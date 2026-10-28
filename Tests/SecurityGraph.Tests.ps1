BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    Import-HTTestModule -Name "Utils", "GraphAPISecurity", "GraphAPITeams", "GraphAPIIntune", "SharePointAudit"
    Initialize-HTTestEnvironment -Root $TestDrive
}

Describe "Dostęp warunkowy - czy zasada obejmuje konto" {
    BeforeAll {
        function New-HTTestPolicy([hashtable]$Users) { [PSCustomObject]@{ displayName = 'P'; state = 'enabled'; conditions = [PSCustomObject]@{ users = [PSCustomObject]$Users } } }
    }
    It "wszyscy użytkownicy" {
        $r = Test-HTCAPolicyAppliesToUser -Policy (New-HTTestPolicy @{ includeUsers = @('All') }) -UserId 'u1'
        $r.Applies | Should -BeTrue
        $r.Reason | Should -Be 'wszyscy użytkownicy'
    }
    It "wykluczenie przez grupę ma pierwszeństwo" {
        $r = Test-HTCAPolicyAppliesToUser -Policy (New-HTTestPolicy @{ includeUsers = @('All'); excludeGroups = @('g1') }) -UserId 'u1' -GroupIds @('g1')
        $r.Applies | Should -BeFalse
        $r.Reason | Should -Be 'wykluczony przez grupę'
    }
    It "rola administracyjna i goście" {
        (Test-HTCAPolicyAppliesToUser -Policy (New-HTTestPolicy @{ includeRoles = @('r1') }) -UserId 'u1' -RoleTemplateIds @('r1')).Applies | Should -BeTrue
        (Test-HTCAPolicyAppliesToUser -Policy (New-HTTestPolicy @{ includeRoles = @('r1') }) -UserId 'u1').Applies | Should -BeFalse
        (Test-HTCAPolicyAppliesToUser -Policy (New-HTTestPolicy @{ includeUsers = @('GuestsOrExternalUsers') }) -UserId 'g' -IsGuest $true).Applies | Should -BeTrue
        (Test-HTCAPolicyAppliesToUser -Policy (New-HTTestPolicy @{ includeUsers = @('GuestsOrExternalUsers') }) -UserId 'g' -IsGuest $false).Applies | Should -BeFalse
    }
    It "opis zasady: nazwy grup, kontrola i stan" {
        $p = [PSCustomObject]@{ id = 'p1'; displayName = 'MFA dla adminów'; state = 'enabledForReportingButNotEnforced'; modifiedDateTime = $null; createdDateTime = '2026-01-01'
            conditions = [PSCustomObject]@{ users = [PSCustomObject]@{ includeGroups = @('g1'); excludeUsers = @('u9') }; applications = [PSCustomObject]@{ includeApplications = @('All') }; clientAppTypes = @('all') }
            grantControls = [PSCustomObject]@{ operator = 'OR'; builtInControls = @('mfa', 'compliantDevice') }; sessionControls = $null }
        $row = ConvertTo-HTCAPolicyRow -Policy $p -Names @{ g1 = 'Admini'; u9 = 'Konto awaryjne' }
        $row.Stan | Should -Be 'Tylko raport'
        $row.Użytkownicy | Should -Be 'grupy: Admini'
        $row.Wykluczeni | Should -Be 'Konto awaryjne'
        $row.Kontrola | Should -Be 'MFA lub zgodne urządzenie'
        $row.Aplikacje | Should -Be 'wszyscy'
    }
}

Describe "Sekrety i certyfikaty aplikacji" {
    It "oznacza wygasłe i wygasające, pomija ważne dłużej" {
        $now = [datetime]'2026-01-01'
        $app = [PSCustomObject]@{ displayName = 'App'; appId = 'a'; id = 'i'
            passwordCredentials = @([PSCustomObject]@{ displayName = 's1'; endDateTime = [datetime]'2026-01-05'; keyId = 'k1' }, [PSCustomObject]@{ displayName = 's2'; endDateTime = [datetime]'2027-01-05'; keyId = 'k2' }, [PSCustomObject]@{ displayName = 's3'; endDateTime = [datetime]'2026-01-20'; keyId = 'k4' })
            keyCredentials = @([PSCustomObject]@{ displayName = 'c1'; endDateTime = [datetime]'2025-12-01'; keyId = 'k3'; usage = 'Verify' }) }
        $rows = @(ConvertTo-HTCredentialRows -Object $app -Days 30 -Now $now)
        $rows.Count | Should -Be 3
        @($rows | Where-Object { $_.Opis -eq 'c1' })[0].Stan | Should -Be 'Wygasło'
        @($rows | Where-Object { $_.Opis -eq 's1' })[0].__flag | Should -Be 'crit'
        @($rows | Where-Object { $_.Opis -eq 's3' })[0].__flag | Should -Be 'warn'
        @(ConvertTo-HTCredentialRows -Object $app -Days 30 -Now $now -IncludeAll).Count | Should -Be 4
    }
    It "liczy dni do daty" {
        Get-HTDaysUntil -Date ([datetime]'2026-01-11') -Now ([datetime]'2026-01-01') | Should -Be 10
        Get-HTDaysUntil -Date $null | Should -BeNullOrEmpty
    }
}

Describe "Diagnoza logowania" {
    It "wyjaśnia kody błędów logowania" {
        Get-HTSignInErrorHint 50053 | Should -Match "zablokowane"
        Get-HTSignInErrorHint 53003 | Should -Match "dostępu warunkowego"
        Get-HTSignInErrorHint 123456 | Should -Match "123456"
    }
    It "wskazuje zablokowane konto, brak licencji i powtarzające się błędy" {
        $now = [datetime]'2026-01-01'
        $user = [PSCustomObject]@{ accountEnabled = $false; userType = 'Member'; assignedLicenses = @(); lastPasswordChangeDateTime = [datetime]'2025-06-01'; onPremisesSyncEnabled = $false }
        $failed = { param($code, $ip) [PSCustomObject]@{ createdDateTime = [datetime]'2025-12-31T10:00:00'; appDisplayName = 'Outlook'; ipAddress = $ip; location = [PSCustomObject]@{ city = 'Kraków'; countryOrRegion = 'PL' }; status = [PSCustomObject]@{ errorCode = $code; failureReason = 'x' } } }
        $signIns = @((& $failed 50126 '1.1.1.1'), (& $failed 50126 '2.2.2.2'), (& $failed 50057 '1.1.1.1'))
        $rows = @(ConvertTo-HTLoginDiagnosis -User $user -SignIns $signIns -Methods @([PSCustomObject]@{ Type = 'Hasło' }) -Now $now)
        @($rows | Where-Object { $_.Sprawdzenie -eq 'Konto' })[0].Stan | Should -Be 'Problem'
        @($rows | Where-Object { $_.Sprawdzenie -eq 'Licencje' })[0].Stan | Should -Be 'Uwaga'
        @($rows | Where-Object { $_.Sprawdzenie -eq 'Metody MFA' })[0].Wynik | Should -Be 'Tylko hasło'
        @($rows | Where-Object { $_.Sprawdzenie -like 'Błąd 50126*' })[0].Sprawdzenie | Should -Be 'Błąd 50126 (x2)'
    }
    It "bez logowań podaje informację" {
        $user = [PSCustomObject]@{ accountEnabled = $true; userType = 'Member'; assignedLicenses = @(1) }
        @(ConvertTo-HTLoginDiagnosis -User $user | Where-Object { $_.Sprawdzenie -eq 'Logowania' })[0].Stan | Should -Be 'Informacja'
    }
}

Describe "Porównanie kont" {
    It "pokazuje różnice i wspólne elementy" {
        $rows = @(Compare-HTUserSets -A @{ Grupy = @('A', 'B'); Licencje = @('E3') } -B @{ Grupy = @('B', 'C'); Licencje = @('E3') } -NameA 'jan' -NameB 'anna')
        $rows.Count | Should -Be 4
        @($rows | Where-Object { $_.Nazwa -eq 'A' })[0].Różnica | Should -Be 'tylko jan'
        @($rows | Where-Object { $_.Nazwa -eq 'C' })[0].anna | Should -BeTrue
        @(Compare-HTUserSets -A @{ Grupy = @('A', 'B') } -B @{ Grupy = @('B') } -OnlyDifferences).Count | Should -Be 1
    }
}

Describe "Administratorzy: MFA i hasła" {
    It "oznacza administratora bez MFA i ze starym hasłem" {
        $now = [datetime]'2026-01-01'
        $u = [PSCustomObject]@{ id = 'u'; displayName = 'Admin'; userPrincipalName = 'admin@firma.pl'; accountEnabled = $true; lastPasswordChangeDateTime = [datetime]'2024-01-01'; onPremisesSyncEnabled = $true; signInActivity = $null }
        $row = ConvertTo-HTAdminSecurityRow -User $u -Roles @('Global Administrator', 'Global Administrator') -Registration ([PSCustomObject]@{ isMfaRegistered = $false; methodsRegistered = @() }) -PasswordDays 365 -Now $now
        $row.__flag | Should -Be 'crit'
        $row.Role | Should -Be 'Global Administrator'
        $row.Problemy | Should -Match 'brak MFA'
        $row.Problemy | Should -Match 'hasło sprzed 731 dni'
        $row.Problemy | Should -Match 'synchronizowane'
    }
}

Describe "Logowanie Defender for Endpoint (PKCE)" {
    It "wyzwanie to SHA-256 weryfikatora w base64url" {
        $p = New-HTPkcePair
        $p.Verifier | Should -Match '^[A-Za-z0-9\-_]{43}$'
        $hash = [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::ASCII.GetBytes($p.Verifier))
        $p.Challenge | Should -Be ([Convert]::ToBase64String($hash).TrimEnd('=').Replace('+', '-').Replace('/', '_'))
    }
    It "odczytuje parametry przekierowania" {
        $q = ConvertFrom-HTQueryString '?code=abc%2Fd&state=xyz&error_description=a+b'
        $q.code | Should -Be 'abc/d'
        $q.state | Should -Be 'xyz'
        $q.error_description | Should -Be 'a b'
    }
}

Describe "Zespoły Teams" {
    It "zespół bez właściciela jest czerwony, z gośćmi - żółty" {
        $g = [PSCustomObject]@{ id = 't1'; displayName = 'Projekt'; visibility = 'Private'; createdDateTime = '2025-01-01'; mail = 'p@firma.pl' }
        $none = ConvertTo-HTTeamRow -Group $g -Owners @() -Members @([PSCustomObject]@{ userType = 'Member' })
        $none.__flag | Should -Be 'crit'
        $none.Uwagi | Should -Match 'brak właściciela'
        $guests = ConvertTo-HTTeamRow -Group $g -Owners @([PSCustomObject]@{ userPrincipalName = 'a@firma.pl' }, [PSCustomObject]@{ userPrincipalName = 'b@firma.pl' }) -Members @([PSCustomObject]@{ userType = 'Guest'; mail = 'x@ext.com' })
        $guests.Goście | Should -Be 1
        $guests.__flag | Should -Be 'warn'
        $archived = ConvertTo-HTTeamRow -Group $g -Owners @([PSCustomObject]@{ userPrincipalName = 'a@firma.pl' }, [PSCustomObject]@{ userPrincipalName = 'b@firma.pl' }) -Team ([PSCustomObject]@{ isArchived = $true })
        $archived.__flag | Should -Be 'muted'
    }
}

Describe "Intune: wersje Windows, duplikaty, raporty, Autopilot" {
    It "rozpoznaje wydanie i wsparcie Windows" {
        $v = Get-HTWindowsVersionInfo '10.0.22631.4317' -Now ([datetime]'2026-06-01')
        $v.Build | Should -Be 22631
        $v.Ubr | Should -Be 4317
        $v.Name | Should -Be 'Windows 11 23H2'
        $v.Level | Should -Be 1
        (Get-HTWindowsVersionInfo '10.0.19045.5000' -Now ([datetime]'2026-06-01')).Level | Should -Be 0
        (Get-HTWindowsVersionInfo '10.0.26200.100' -Now ([datetime]'2026-06-01')).Level | Should -Be 2
        (Get-HTWindowsVersionInfo '' ).Build | Should -Be 0
    }
    It "porównuje poziom poprawek z najnowszym w firmie" {
        $devices = @(
            [PSCustomObject]@{ Id = '1'; DeviceName = 'A'; OperatingSystem = 'Windows'; OsVersion = '10.0.26100.4000' }
            [PSCustomObject]@{ Id = '2'; DeviceName = 'B'; OperatingSystem = 'Windows'; OsVersion = '10.0.26100.4200' }
            [PSCustomObject]@{ Id = '3'; DeviceName = 'C'; OperatingSystem = 'iOS'; OsVersion = '18.0' }
        )
        $rows = @(Get-HTWindowsUpdateStatus -Devices $devices)
        $rows.Count | Should -Be 2
        @($rows | Where-Object { $_.Urządzenie -eq 'A' })[0].'Najnowszy w firmie' | Should -Be 4200
    }
    It "wskazuje starsze wpisy urządzeń z tym samym numerem seryjnym" {
        $devices = @(
            [PSCustomObject]@{ Id = '1'; DeviceName = 'PC-1'; SerialNumber = 'ABC'; LastSync = [datetime]'2025-01-01' }
            [PSCustomObject]@{ Id = '2'; DeviceName = 'PC-1'; SerialNumber = 'ABC'; LastSync = [datetime]'2026-01-01' }
            [PSCustomObject]@{ Id = '3'; DeviceName = 'PC-2'; SerialNumber = 'XYZ'; LastSync = [datetime]'2026-01-01' }
            [PSCustomObject]@{ Id = '4'; DeviceName = 'VM'; SerialNumber = '0'; LastSync = [datetime]'2026-01-01' }
            [PSCustomObject]@{ Id = '5'; DeviceName = 'VM2'; SerialNumber = '0'; LastSync = [datetime]'2026-01-01' }
        )
        $rows = @(Find-HTDuplicateDevices -Devices $devices)
        $rows.Count | Should -Be 2
        @($rows | Where-Object { $_.__stale })[0].Id | Should -Be '1'
    }
    It "zamienia odpowiedź raportu Intune na obiekty" {
        $report = [PSCustomObject]@{ Schema = @([PSCustomObject]@{ Column = 'DisplayName' }, [PSCustomObject]@{ Column = 'FailedDeviceCount' }); Values = @(, @('Teams', 3)) }
        $rows = @(ConvertFrom-HTIntuneReport -Report $report)
        $rows[0].DisplayName | Should -Be 'Teams'
        $rows[0].FailedDeviceCount | Should -Be 3
    }
    It "wczytuje plik skrótów Autopilot" {
        $path = Join-Path $TestDrive 'ap.csv'
        "Device Serial Number,Windows Product ID,Hardware Hash,Group Tag`r`nSN1,,AAAA,Sprzedaz`r`n,,BBBB,`r`nSN3,,CCCC," | Set-Content -LiteralPath $path -Encoding utf8
        $d = @(Import-HTAutopilotCsv -Path $path)
        $d.Count | Should -Be 2
        $d[0].GroupTag | Should -Be 'Sprzedaz'
        @(Import-HTAutopilotCsv -Path $path -GroupTag 'IT')[1].GroupTag | Should -Be 'IT'
    }
}

Describe "Udostępnienia SharePoint i OneDrive" {
    BeforeAll { $item = [PSCustomObject]@{ id = 'i1'; name = 'umowa.docx'; webUrl = 'https://x'; lastModifiedDateTime = '2026-01-01'; folder = $null } }
    It "link anonimowy do edycji bez wygaśnięcia jest czerwony" {
        $p = [PSCustomObject]@{ id = 'p1'; roles = @('write'); link = [PSCustomObject]@{ scope = 'anonymous'; type = 'edit' }; expirationDateTime = $null }
        $row = ConvertTo-HTSharingRow -Item $item -Permission $p -DriveId 'd1'
        $row.Udostępnienie | Should -Be 'Link anonimowy (każdy)'
        $row.Zewnętrzne | Should -BeTrue
        $row.__flag | Should -Be 'crit'
    }
    It "link dla osób spoza domen tenantu jest zewnętrzny" {
        $p = [PSCustomObject]@{ id = 'p2'; roles = @('read'); link = [PSCustomObject]@{ scope = 'users'; type = 'view' }; grantedToIdentitiesV2 = @([PSCustomObject]@{ user = [PSCustomObject]@{ email = 'jan@obca.pl' } }) }
        (ConvertTo-HTSharingRow -Item $item -Permission $p -InternalDomains @('firma.pl')).Zewnętrzne | Should -BeTrue
        (ConvertTo-HTSharingRow -Item $item -Permission $p -InternalDomains @('obca.pl')).Zewnętrzne | Should -BeFalse
    }
    It "pomija uprawnienia dziedziczone i właściciela" {
        ConvertTo-HTSharingRow -Item $item -Permission ([PSCustomObject]@{ id = 'p3'; roles = @('read'); inheritedFrom = [PSCustomObject]@{ id = 'root' } }) | Should -BeNullOrEmpty
        ConvertTo-HTSharingRow -Item $item -Permission ([PSCustomObject]@{ id = 'p4'; roles = @('owner'); grantedToV2 = [PSCustomObject]@{ user = [PSCustomObject]@{ email = 'a@firma.pl' } } }) | Should -BeNullOrEmpty
    }
}
