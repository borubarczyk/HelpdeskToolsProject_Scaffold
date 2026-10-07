BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    # Atrapy poleceń modułu ActiveDirectory (moduł RSAT nie jest dostępny w środowisku testowym)
    New-HTTestStub -Name "Get-ADGroup" -Parameters "Identity", "Properties", "Filter"
    New-HTTestStub -Name "Set-ADGroup" -Parameters "Identity", "GroupScope", "GroupCategory", "SamAccountName", "DisplayName"
    New-HTTestStub -Name "Set-ADUser" -Parameters "Identity", "ChangePasswordAtLogon", "ProfilePath", "ScriptPath", "HomeDirectory", "HomeDrive", "PasswordNeverExpires"
    New-HTTestStub -Name "Set-ADAccountPassword" -Parameters "Identity", "NewPassword" -Switches "Reset"
    New-HTTestStub -Name "Unlock-ADAccount" -Parameters "Identity"
    Import-HTTestModule -Name "Utils", "LocalActiveDirectory"
    Initialize-HTTestEnvironment -Root $TestDrive
}

Describe "Get-HTNameFromDN" {
    It "zwraca nazwę z DN '<Dn>'" -TestCases @(
        @{ Dn = "CN=Jan Kowalski,OU=Users,DC=firma,DC=local"; Expected = "Jan Kowalski" }
        @{ Dn = "CN=Kowalski\, Jan,OU=Users,DC=firma,DC=local"; Expected = "Kowalski, Jan" }
        @{ Dn = ""; Expected = "" }
    ) {
        param($Dn, $Expected)
        Get-HTNameFromDN $Dn | Should -Be $Expected
    }
}

Describe "ConvertTo-HTADObjectType" {
    It "mapuje nazwy sekcji" {
        ConvertTo-HTADObjectType "Użytkownicy" | Should -Be "User"
        ConvertTo-HTADObjectType "Komputery" | Should -Be "Computer"
        ConvertTo-HTADObjectType "Grupy" | Should -Be "Group"
    }
    It "zgłasza błąd dla nieznanej sekcji" {
        { ConvertTo-HTADObjectType "Drukarki" } | Should -Throw
    }
}

Describe "Set-HTADGroupScope" {
    BeforeEach {
        Mock -ModuleName LocalActiveDirectory Set-ADGroup { }
    }
    It "przechodzi przez Universal przy zmianie Global -> DomainLocal" {
        Mock -ModuleName LocalActiveDirectory Get-ADGroup { [PSCustomObject]@{ GroupScope = "Global"; ObjectGUID = "g1" } }
        Set-HTADGroupScope -Identity "g1" -Scope "DomainLocal"
        Should -Invoke -ModuleName LocalActiveDirectory Set-ADGroup -Times 1 -Exactly -ParameterFilter { $GroupScope -eq "Universal" }
        Should -Invoke -ModuleName LocalActiveDirectory Set-ADGroup -Times 1 -Exactly -ParameterFilter { $GroupScope -eq "DomainLocal" }
    }
    It "zmienia zakres bezpośrednio dla Global -> Universal" {
        Mock -ModuleName LocalActiveDirectory Get-ADGroup { [PSCustomObject]@{ GroupScope = "Global"; ObjectGUID = "g1" } }
        Set-HTADGroupScope -Identity "g1" -Scope "Universal"
        Should -Invoke -ModuleName LocalActiveDirectory Set-ADGroup -Times 1 -Exactly
    }
    It "nic nie robi, gdy zakres jest taki sam" {
        Mock -ModuleName LocalActiveDirectory Get-ADGroup { [PSCustomObject]@{ GroupScope = "Global"; ObjectGUID = "g1" } }
        Set-HTADGroupScope -Identity "g1" -Scope "Global"
        Should -Invoke -ModuleName LocalActiveDirectory Set-ADGroup -Times 0 -Exactly
    }
}

Describe "Reset-HTADUserPassword" {
    It "resetuje hasło, wymusza zmianę i odblokowuje konto" {
        Mock -ModuleName LocalActiveDirectory Set-ADAccountPassword { }
        Mock -ModuleName LocalActiveDirectory Set-ADUser { }
        Mock -ModuleName LocalActiveDirectory Unlock-ADAccount { }
        Reset-HTADUserPassword -Identity "u1" -Password "Abc123!xyz" -ChangeAtLogon $true -Unlock $true
        Should -Invoke -ModuleName LocalActiveDirectory Set-ADAccountPassword -Times 1 -ParameterFilter { $Reset -and $NewPassword -is [securestring] }
        Should -Invoke -ModuleName LocalActiveDirectory Set-ADUser -Times 1 -ParameterFilter { $ChangePasswordAtLogon -eq $true }
        Should -Invoke -ModuleName LocalActiveDirectory Unlock-ADAccount -Times 1
    }
}

Describe "Set-HTADUserProfile / Set-HTADUserAttributes" {
    BeforeEach { Mock -ModuleName LocalActiveDirectory Set-ADUser { } }

    It "puste wartości profilu czyszczą atrybut (null), a niepodane są pomijane" {
        Set-HTADUserProfile -Identity "u1" -ProfilePath "" -HomeDirectory "\\srv\home$\u1"
        Should -Invoke -ModuleName LocalActiveDirectory Set-ADUser -Times 1 -ParameterFilter {
            $null -eq $ProfilePath -and $null -eq $ScriptPath -and $HomeDirectory -eq "\\srv\home$\u1"
        }
    }
    It "odrzuca nieobsługiwane atrybuty" {
        { Set-HTADUserAttributes -Identity "u1" -Attributes @{ SamAccountName = "x" } } | Should -Throw
    }
}

Describe "New-HTADLoginName" {
    It "tworzy login bez polskich znaków i ogranicza długość do 20 znaków" {
        New-HTADLoginName -GivenName "Łukasz" -Surname "Żółć" | Should -Be "lukasz.zolc"
        New-HTADLoginName -GivenName "Anna Maria" -Surname "Kowalska-Nowak" | Should -Be "annamaria.kowalska-n"
    }
}

Describe "Get-HTADUserReport" {
    BeforeAll {
        New-HTTestStub -Name "Get-ADUser" -Parameters "Identity", "Filter", "Properties"
        New-HTTestStub -Name "Search-ADAccount" -Parameters "TimeSpan" -Switches "LockedOut", "UsersOnly", "AccountExpiring"
        $now = Get-Date
        Mock -ModuleName LocalActiveDirectory Get-ADUser {
            @(
                [PSCustomObject]@{ Name = "a"; SamAccountName = "a"; Enabled = $true; LastLogonDate = $now.AddDays(-5); WhenCreated = $now.AddDays(-500); PasswordNeverExpires = $false; "msDS-UserPasswordExpiryTimeComputed" = $now.AddDays(2).ToFileTime(); DistinguishedName = "CN=a,OU=U,DC=x" }
                [PSCustomObject]@{ Name = "b"; SamAccountName = "b"; Enabled = $true; LastLogonDate = $now.AddDays(-120); WhenCreated = $now.AddDays(-500); PasswordNeverExpires = $false; "msDS-UserPasswordExpiryTimeComputed" = $now.AddDays(-1).ToFileTime(); DistinguishedName = "CN=b,OU=U,DC=x" }
                [PSCustomObject]@{ Name = "c"; SamAccountName = "c"; Enabled = $true; LastLogonDate = $null; WhenCreated = $now.AddDays(-10); PasswordNeverExpires = $true; "msDS-UserPasswordExpiryTimeComputed" = 0; DistinguishedName = "CN=c,OU=U,DC=x" }
            )
        }
    }
    It "Inactive - konta bez logowania od N dni (nowe konta pomijane)" {
        @(Get-HTADUserReport -Type Inactive -Days 90).Login | Should -Be @("b")
    }
    It "PasswordExpiring - hasła wygasające w ciągu N dni" {
        $r = @(Get-HTADUserReport -Type PasswordExpiring -Days 7)
        $r.Login | Should -Be @("a")
        $r[0].__flag | Should -Be "crit"
    }
    It "PasswordExpired i NeverLoggedOn" {
        @(Get-HTADUserReport -Type PasswordExpired).Login | Should -Be @("b")
        @(Get-HTADUserReport -Type NeverLoggedOn).Login | Should -Be @("c")
    }
}
