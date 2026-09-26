BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    New-HTTestStub -Name "Get-ADUser" -Parameters "Identity", "Filter", "Properties"
    New-HTTestStub -Name "Disable-ADAccount" -Parameters "Identity"
    Import-HTTestModule -Name "Utils", "PasswordGenerator", "LocalActiveDirectory", "MassActions"
    Initialize-HTTestEnvironment -Root $TestDrive
    Disable-HTTestToast
}

Describe "Get-HTMassActions" {
    It "zwraca akcje dla AD, Graph i Exchange" {
        $actions = Get-HTMassActions
        $actions.Service | Select-Object -Unique | Sort-Object | Should -Be @("AD", "Exchange", "Graph")
        ($actions | Where-Object Key -eq "AD-AddGroup").ParameterLabel | Should -Not -BeNullOrEmpty
    }
}

Describe "Invoke-HTMassAction" {
    BeforeEach {
        Mock -ModuleName MassActions Get-ADUser {
            if ($Filter -like "*brak*") { return @() }
            [PSCustomObject]@{ ObjectGUID = "guid-1"; SamAccountName = "jan" }
        }
        Mock -ModuleName MassActions Disable-ADAccount { }
    }

    It "w trybie testowym tylko sprawdza obiekty" {
        $results = Invoke-HTMassAction -ActionKey "AD-Disable" -Identities @("jan", "brak") -TestOnly
        $results[0].Status | Should -Be "Test"
        $results[1].Status | Should -Be "Błąd"
        Should -Invoke -ModuleName MassActions Disable-ADAccount -Times 0 -Exactly
    }

    It "wykonuje akcję i raportuje postęp" {
        $script:progress = @()
        $results = Invoke-HTMassAction -ActionKey "AD-Disable" -Identities @("jan", "anna") -OnProgress { param($i, $t, $id) $script:progress += "$i/$t" }
        @($results | Where-Object Status -eq "OK").Count | Should -Be 2
        $script:progress | Should -Be @("1/2", "2/2")
        Should -Invoke -ModuleName MassActions Disable-ADAccount -Times 2 -Exactly
    }

    It "wymaga parametru dla akcji z parametrem" {
        { Invoke-HTMassAction -ActionKey "AD-AddGroup" -Identities @("jan") } | Should -Throw
    }

    It "zgłasza błąd dla nieznanej akcji" {
        { Invoke-HTMassAction -ActionKey "Nieznana" -Identities @("x") } | Should -Throw
    }
}

Describe "Import-HTIdentityFile" {
    It "czyta kolumnę UserPrincipalName z CSV rozdzielanego średnikiem" {
        $path = Join-Path $TestDrive "users.csv"
        "Name;UserPrincipalName`nJan;jan@firma.pl`nAnna;anna@firma.pl`nJan;jan@firma.pl" | Set-Content $path -Encoding utf8
        Import-HTIdentityFile -Path $path | Should -Be @("jan@firma.pl", "anna@firma.pl")
    }
    It "czyta plik tekstowy (jeden identyfikator w linii)" {
        $path = Join-Path $TestDrive "users.txt"
        "a@x.pl`r`nb@x.pl`r`n`r`n" | Set-Content $path -Encoding utf8
        Import-HTIdentityFile -Path $path | Should -Be @("a@x.pl", "b@x.pl")
    }
}
