BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    New-HTTestStub -Name "Invoke-MgGraphRequest" -Parameters "Uri", "Method", "Body", "Headers", "OutputType", "ContentType"
    New-HTTestStub -Name "Get-MgContext"
    Import-HTTestModule -Name "Utils", "ModulesConnection", "GraphAPIM365Users", "GraphAPIIntune"
    Initialize-HTTestEnvironment -Root $TestDrive
}

Describe "Resolve-HTGraphUri" {
    It "buduje adres v1.0 i beta" {
        Resolve-HTGraphUri -Uri "users" | Should -Be "https://graph.microsoft.com/v1.0/users"
        Resolve-HTGraphUri -Uri "/users" -Beta | Should -Be "https://graph.microsoft.com/beta/users"
        Resolve-HTGraphUri -Uri "https://graph.microsoft.com/v1.0/me" | Should -Be "https://graph.microsoft.com/v1.0/me"
    }
}

Describe "Invoke-HTGraphRequest" {
    It "pobiera wszystkie strony wyników (-All)" {
        Mock -ModuleName ModulesConnection Invoke-MgGraphRequest {
            if ($Uri -like "*page2*") {
                [PSCustomObject]@{ value = @([PSCustomObject]@{ id = 3 }) }
            }
            else {
                [PSCustomObject]@{ value = @([PSCustomObject]@{ id = 1 }, [PSCustomObject]@{ id = 2 }); '@odata.nextLink' = "https://graph.microsoft.com/v1.0/users?page2" }
            }
        }
        $result = Invoke-HTGraphRequest -Uri "users" -All
        $result.id | Should -Be @(1, 2, 3)
        Should -Invoke -ModuleName ModulesConnection Invoke-MgGraphRequest -Times 2 -Exactly
    }
    It "zwraca kolekcję 'value' dla pojedynczego zapytania" {
        Mock -ModuleName ModulesConnection Invoke-MgGraphRequest { [PSCustomObject]@{ value = @([PSCustomObject]@{ id = "a" }) } }
        (Invoke-HTGraphRequest -Uri "groups").id | Should -Be "a"
    }
    It "wysyła treść jako JSON i nagłówek ConsistencyLevel" {
        Mock -ModuleName ModulesConnection Invoke-MgGraphRequest { }
        Invoke-HTGraphRequest -Uri "users/1" -Method PATCH -Body @{ accountEnabled = $false } -ConsistencyLevelEventual
        Should -Invoke -ModuleName ModulesConnection Invoke-MgGraphRequest -ParameterFilter {
            $Method -eq "PATCH" -and $Body -eq '{"accountEnabled":false}' -and $ContentType -eq "application/json" -and $Headers.ConsistencyLevel -eq "eventual"
        }
    }
}

Describe "ConvertTo-HTM365GroupObject" {
    It "rozpoznaje typ grupy <Expected>" -TestCases @(
        @{ Group = @{ groupTypes = @("Unified"); securityEnabled = $false; mailEnabled = $true }; Expected = "Microsoft 365" }
        @{ Group = @{ groupTypes = @(); securityEnabled = $true; mailEnabled = $false }; Expected = "Zabezpieczeń" }
        @{ Group = @{ groupTypes = @(); securityEnabled = $true; mailEnabled = $true }; Expected = "Zabezpieczeń (mail)" }
        @{ Group = @{ groupTypes = @(); securityEnabled = $false; mailEnabled = $true }; Expected = "Dystrybucyjna" }
    ) {
        param($Group, $Expected)
        (ConvertTo-HTM365GroupObject -Group ([PSCustomObject]$Group)).Type | Should -Be $Expected
    }
    It "oznacza grupy dynamiczne jako niezarządzalne" {
        $group = ConvertTo-HTM365GroupObject -Group ([PSCustomObject]@{ groupTypes = @("DynamicMembership"); securityEnabled = $true })
        Test-HTM365GroupManageable -Group $group | Should -BeFalse
    }
}

Describe "Add-HTM365PhoneMethod" {
    It "normalizuje numer '<Number>' do '<Expected>'" -TestCases @(
        @{ Number = "600 100 200"; Expected = "+48 600100200" }
        @{ Number = "+48600100200"; Expected = "+48 600100200" }
        @{ Number = "+1 4255551234"; Expected = "+1 4255551234" }
        @{ Number = "+14255551234"; Expected = "+1 4255551234" }
        @{ Number = "+420 601 123 456"; Expected = "+420 601123456" }
        @{ Number = "(600) 100-200"; Expected = "+48 600100200" }
    ) {
        param($Number, $Expected)
        Mock -ModuleName GraphAPIM365Users Invoke-HTGraphRequest { }
        Add-HTM365PhoneMethod -UserId "u1" -PhoneNumber $Number | Should -Be $Expected
        Should -Invoke -ModuleName GraphAPIM365Users Invoke-HTGraphRequest -ParameterFilter { $Body.phoneNumber -eq $Expected -and $Method -eq "POST" }
    }
}

Describe "Set-HTM365UserLicense" {
    It "ustawia lokalizację użycia przed przypisaniem licencji" {
        $Global:DefaultUsageLocation = "PL"
        Mock -ModuleName GraphAPIM365Users Invoke-HTGraphRequest { if ($Method -eq "GET" -or -not $Method) { [PSCustomObject]@{ usageLocation = $null } } }
        Set-HTM365UserLicense -Id "u1" -AddSkuIds @("sku-1")
        Should -Invoke -ModuleName GraphAPIM365Users Invoke-HTGraphRequest -ParameterFilter { $Method -eq "PATCH" -and $Body.usageLocation -eq "PL" }
        Should -Invoke -ModuleName GraphAPIM365Users Invoke-HTGraphRequest -ParameterFilter { $Uri -eq "users/u1/assignLicense" -and $Body.addLicenses[0].skuId -eq "sku-1" }
    }
}

Describe "Get-HTIntuneLapsPassword" {
    It "dekoduje najnowsze hasło z Base64" {
        $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("Tajne!123"))
        Mock -ModuleName GraphAPIIntune Invoke-HTGraphRequest {
            [PSCustomObject]@{
                refreshDateTime = "2024-01-01T00:00:00Z"
                credentials     = @(
                    [PSCustomObject]@{ accountName = "admin"; passwordBase64 = "c3RhcmU="; backupDateTime = "2023-01-01T00:00:00Z" }
                    [PSCustomObject]@{ accountName = "admin"; passwordBase64 = $encoded; backupDateTime = "2024-01-01T00:00:00Z" }
                )
            }
        }
        $result = Get-HTIntuneLapsPassword -AzureADDeviceId "d1"
        $result.Password | Should -Be "Tajne!123"
        Should -Invoke -ModuleName GraphAPIIntune Invoke-HTGraphRequest -ParameterFilter { $Headers["ocp-client-name"] -eq "HelpdeskTools" }
    }
}

Describe "Rename-HTIntuneDevice" {
    It "odrzuca nieprawidłowe nazwy" {
        Mock -ModuleName GraphAPIIntune Invoke-HTGraphRequest { }
        { Rename-HTIntuneDevice -Id "1" -NewName "zła nazwa" } | Should -Throw
        { Rename-HTIntuneDevice -Id "1" -NewName "NAZWA-DLUZSZA-NIZ-15" } | Should -Throw
        Should -Invoke -ModuleName GraphAPIIntune Invoke-HTGraphRequest -Times 0 -Exactly
    }
    It "wysyła akcję setDeviceName do API beta" {
        Mock -ModuleName GraphAPIIntune Invoke-HTGraphRequest { }
        Rename-HTIntuneDevice -Id "1" -NewName "PC-KSIEGOWOSC1"
        Should -Invoke -ModuleName GraphAPIIntune Invoke-HTGraphRequest -ParameterFilter { $Beta -and $Uri -like "*/setDeviceName" -and $Body.deviceName -eq "PC-KSIEGOWOSC1" }
    }
}

Describe "Get-HTSkuFriendlyName" {
    It "zwraca nazwę handlową znanej licencji i SKU dla nieznanej" {
        Get-HTSkuFriendlyName "SPB" | Should -Be "Microsoft 365 Business Premium"
        Get-HTSkuFriendlyName "NIEZNANA_SKU" | Should -Be "NIEZNANA_SKU"
        Get-HTSkuFriendlyName "" | Should -Be ""
    }
}

Describe "Get-HTM365InactiveUsers" {
    BeforeAll {
        $now = Get-Date
        Mock -ModuleName GraphAPIM365Users Get-HTSkuNameMap { @{} }
        Mock -ModuleName GraphAPIM365Users Invoke-HTGraphRequest {
            @(
                [PSCustomObject]@{ id = "1"; displayName = "Aktywny"; userPrincipalName = "a@x.pl"; accountEnabled = $true; userType = "Member"; createdDateTime = $now.AddDays(-400).ToString("o"); assignedLicenses = @(); signInActivity = [PSCustomObject]@{ lastSignInDateTime = $now.AddDays(-5).ToString("o") } }
                [PSCustomObject]@{ id = "2"; displayName = "Stary"; userPrincipalName = "s@x.pl"; accountEnabled = $true; userType = "Member"; createdDateTime = $now.AddDays(-400).ToString("o"); assignedLicenses = @([PSCustomObject]@{ skuId = "abc" }); signInActivity = [PSCustomObject]@{ lastSignInDateTime = $now.AddDays(-200).ToString("o"); lastNonInteractiveSignInDateTime = $now.AddDays(-150).ToString("o") } }
                [PSCustomObject]@{ id = "3"; displayName = "Nigdy"; userPrincipalName = "n@x.pl"; accountEnabled = $true; userType = "Member"; createdDateTime = $now.AddDays(-100).ToString("o"); assignedLicenses = @(); signInActivity = $null }
                [PSCustomObject]@{ id = "4"; displayName = "Nowy"; userPrincipalName = "w@x.pl"; accountEnabled = $true; userType = "Member"; createdDateTime = $now.AddDays(-2).ToString("o"); assignedLicenses = @(); signInActivity = $null }
                [PSCustomObject]@{ id = "5"; displayName = "Wyłączony"; userPrincipalName = "d@x.pl"; accountEnabled = $false; userType = "Member"; createdDateTime = $now.AddDays(-400).ToString("o"); assignedLicenses = @(); signInActivity = $null }
            )
        }
    }
    It "zwraca konta bez logowania od N dni (z uwzględnieniem logowań nieinteraktywnych)" {
        $result = @(Get-HTM365InactiveUsers -Days 90)
        $result.UPN | Should -Be @("s@x.pl", "n@x.pl")
        ($result | Where-Object UPN -eq "s@x.pl").'Dni bez logowania' | Should -Be 150
        ($result | Where-Object UPN -eq "s@x.pl").__flag | Should -Be "warn"
        ($result | Where-Object UPN -eq "n@x.pl").'Dni bez logowania' | Should -Be "nigdy"
    }
    It "uwzględnia wyłączone konta na żądanie" {
        @(Get-HTM365InactiveUsers -Days 90 -IncludeDisabled).UPN | Should -Contain "d@x.pl"
    }
}

Describe "Akcje zdalne Intune" {
    It "wysyła żądanie skanowania Defender z treścią quickScan" {
        Mock -ModuleName GraphAPIIntune Invoke-HTGraphRequest { }
        Invoke-HTIntuneDeviceAction -Id "dev1" -Action QuickScan | Should -Be "Szybkie skanowanie Defender"
        Should -Invoke -ModuleName GraphAPIIntune Invoke-HTGraphRequest -Times 1 -Exactly -ParameterFilter { $Uri -eq "deviceManagement/managedDevices/dev1/windowsDefenderScan" -and $Method -eq "POST" -and $Body.quickScan -eq $true }
    }
    It "rotacja kluczy BitLocker używa API beta" {
        Mock -ModuleName GraphAPIIntune Invoke-HTGraphRequest { }
        Invoke-HTIntuneDeviceAction -Id "dev1" -Action RotateBitLocker | Out-Null
        Should -Invoke -ModuleName GraphAPIIntune Invoke-HTGraphRequest -Times 1 -Exactly -ParameterFilter { $Beta -and $Uri -like "*rotateBitLockerKeys" }
    }
}
