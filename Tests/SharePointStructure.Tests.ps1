BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    New-HTTestStub -Name "Get-PnPFolder" -Parameters "Url"
    New-HTTestStub -Name "Resolve-PnPFolder" -Parameters "SiteRelativePath"
    Import-HTTestModule -Name "Utils", "Automation", "GraphAPISharePoint", "SharePointStructure"
    Initialize-HTTestEnvironment -Root $TestDrive
    New-Item -ItemType Directory -Path $Global:ConfigDir -Force | Out-Null
    $script:Roles = @(@{ Name = 'Pełna kontrola'; RoleTypeKind = 'Administrator' }, @{ Name = 'Edycja'; RoleTypeKind = 'Editor' }, @{ Name = 'Współtworzenie'; RoleTypeKind = 'Contributor' }, @{ Name = 'Odczyt'; RoleTypeKind = 'Reader' })
    $script:Resolver = @{ Groups = @('Kadry', 'Zarząd'); Associated = @{ Owner = 'Projekty Owners'; Member = 'Projekty Members'; Visitor = 'Projekty Visitors' } }
}

Describe "Nazwy folderów i adresy" {
    It "sprawdza nazwy folderów SharePoint" -TestCases @(
        @{ Name = 'Umowy 2026'; Ok = $true }
        @{ Name = 'Zły:folder'; Ok = $false }
        @{ Name = 'kropka.'; Ok = $false }
        @{ Name = 'con'; Ok = $false }
        @{ Name = 'a_vti_b'; Ok = $false }
        @{ Name = ' spacja'; Ok = $false }
        @{ Name = '#Projekty %'; Ok = $true }
    ) {
        param($Name, $Ok)
        [bool](-not (Test-HTSPItemName $Name)) | Should -Be $Ok
    }
    It "tworzy nazwę do adresu bez polskich znaków" {
        ConvertTo-HTSPUrlName -Title 'Dokumenty Zarządu - 2026' | Should -Be 'DokumentyZarzadu2026'
        ConvertTo-HTSPUrlName -Title 'łódź' | Should -Be 'Lodz'
    }
    It "zamienia adres docelowy na adres względny serwera" {
        ConvertTo-HTSPServerRelativeUrl -Url 'https://firma.sharepoint.com/sites/x/Shared%20Documents/A/' | Should -Be '/sites/x/Shared Documents/A'
        ConvertTo-HTSPServerRelativeUrl -Url '/sites/x/Dokumenty' -WebUrl '/sites/y' | Should -Be '/sites/x/Dokumenty'
        ConvertTo-HTSPServerRelativeUrl -Url 'Dokumenty/B' -WebUrl '/sites/y' | Should -Be '/sites/y/Dokumenty/B'
        ConvertTo-HTSPServerRelativeUrl -Url 'Dokumenty' -WebUrl '' | Should -Be '/Dokumenty'
    }
}

Describe "Poziomy uprawnień i podmioty" {
    It "rozpoznaje nazwę i skróty niezależnie od języka witryny" {
        Resolve-HTSPRoleName -Role 'edycja' -Definitions $Roles | Should -Be 'Edycja'
        Resolve-HTSPRoleName -Role 'Full' -Definitions $Roles | Should -Be 'Pełna kontrola'
        Resolve-HTSPRoleName -Role 'Contribute' -Definitions $Roles | Should -Be 'Współtworzenie'
        Resolve-HTSPRoleName -Role 'read' -Definitions @(@{ Name = 'Read'; RoleTypeKind = 'Reader' }) | Should -Be 'Read'
        { Resolve-HTSPRoleName -Role 'Admin wszystkiego' -Definitions $Roles } | Should -Throw '*Nieznany poziom*'
    }
    It "rozpoznaje grupy witryny, grupy SharePoint i osoby" {
        $o = Resolve-HTSPPrincipal -Principal '@Właściciele' -Resolver $Resolver
        $o.Kind | Should -Be 'Group'
        $o.Name | Should -Be 'Projekty Owners'
        (Resolve-HTSPPrincipal -Principal '@members' -Resolver $Resolver).Name | Should -Be 'Projekty Members'
        (Resolve-HTSPPrincipal -Principal 'kadry' -Resolver $Resolver).Name | Should -Be 'Kadry'
        (Resolve-HTSPPrincipal -Principal 'jan@firma.pl' -Resolver $Resolver).Kind | Should -Be 'User'
        { Resolve-HTSPPrincipal -Principal '@Odwiedzający' -Resolver @{ Groups = @(); Associated = @{} } } | Should -Throw
    }
    It "dopasowuje przypisania do osoby i zapisuje podmiot w składni" {
        $a = @{ Principal = 'Jan Kowalski'; LoginName = 'i:0#.f|membership|jan@firma.pl'; PrincipalType = 'User' }
        Test-HTSPPrincipalMatch -Assignment $a -Principal 'JAN@firma.pl' | Should -BeTrue
        Test-HTSPPrincipalMatch -Assignment $a -Principal 'anna@firma.pl' | Should -BeFalse
        ConvertTo-HTSPPrincipalText -Assignment $a | Should -Be 'jan@firma.pl'
        ConvertTo-HTSPPrincipalText -Assignment @{ Principal = 'Kadry'; LoginName = 'Kadry'; PrincipalType = 'SharePointGroup' } | Should -Be 'Kadry'
    }
}

Describe "Składnia struktury folderów" {
    It "czyta uprawnienia po «|»" {
        $s = ConvertFrom-HTSPPermissionSpec -Text '! Zarząd=Pełna kontrola; jan@firma.pl = Odczyt; -anna@firma.pl'
        $s.Copy | Should -BeFalse
        $s.Grants.Count | Should -Be 2
        $s.Grants[1].Principal | Should -Be 'jan@firma.pl'
        $s.Grants[1].Role | Should -Be 'Odczyt'
        $s.Removes | Should -Be @('anna@firma.pl')
        (ConvertFrom-HTSPPermissionSpec -Text 'jan@firma.pl').Errors.Count | Should -Be 1
        (ConvertFrom-HTSPPermissionSpec -Text 'Kadry=Edycja').Copy | Should -BeTrue
    }
    It "buduje drzewo z wcięć (spacje i tabulatory) i ścieżek a/b/c" {
        $text = "# komentarz`r`nProjekty`r`n    2026`r`n`t`tUmowy | Zarząd=Edycja`r`n        Faktury`r`n    Archiwum |! @Właściciele=Pełna kontrola`r`nKadry/Umowy/2026`r`nKadry/Wnioski`r`n`r`nprojekty/2026 | -anna@firma.pl"
        $r = ConvertFrom-HTSPStructureText -Text $text
        $r.Errors | Should -BeNullOrEmpty
        @($r.Items.Path) | Should -Be @('Projekty', 'Projekty/2026', 'Projekty/2026/Umowy', 'Projekty/2026/Faktury', 'Projekty/Archiwum', 'Kadry', 'Kadry/Umowy', 'Kadry/Umowy/2026', 'Kadry/Wnioski')
        $umowy = @($r.Items | Where-Object Path -eq 'Projekty/2026/Umowy')[0]
        $umowy.Level | Should -Be 2
        $umowy.Break | Should -BeTrue
        $umowy.Copy | Should -BeTrue
        $archiwum = @($r.Items | Where-Object Path -eq 'Projekty/Archiwum')[0]
        $archiwum.Copy | Should -BeFalse
        # Powtórzona ścieżka (bez względu na wielkość liter) uzupełnia uprawnienia
        $y2026 = @($r.Items | Where-Object Path -eq 'Projekty/2026')[0]
        $y2026.Break | Should -BeTrue
        $y2026.Removes | Should -Be @('anna@firma.pl')
    }
    It "zgłasza błędne nazwy i uprawnienia z numerem linii" {
        $r = ConvertFrom-HTSPStructureText -Text "Dobre`r`nZłe:nazwa`r`nA//B`r`nC | jan="
        @($r.Errors).Count | Should -Be 3
        $r.Errors[0] | Should -Match '^linia 2'
        $r.Errors[1] | Should -Match '^linia 3'
        $r.Errors[2] | Should -Match '^linia 4'
    }
    It "zapis linii odczytuje się z powrotem tak samo" {
        $line = ConvertTo-HTSPStructureLine -Name 'Umowy' -Level 1 -Grants @(@{ Principal = 'Zarząd'; Role = 'Edycja' }, @{ Principal = 'jan@firma.pl'; Role = 'Odczyt' }) -Unique
        $line | Should -Be '    Umowy |! Zarząd=Edycja; jan@firma.pl=Odczyt'
        $r = ConvertFrom-HTSPStructureText -Text "Projekt`r`n$line"
        $item = @($r.Items | Where-Object Path -eq 'Projekt/Umowy')[0]
        $item.Copy | Should -BeFalse
        $item.Grants.Count | Should -Be 2
    }
}

Describe "Szablony struktur" {
    It "szablony wbudowane są poprawne" {
        foreach ($t in @(Get-HTSPStructureTemplates)) {
            $r = ConvertFrom-HTSPStructureText -Text $t.Text
            $r.Errors | Should -BeNullOrEmpty -Because $t.Name
            @($r.Items).Count | Should -BeGreaterThan 2 -Because $t.Name
        }
    }
    It "zapisuje, zastępuje i usuwa szablony" {
        $builtIn = @(Get-HTSPStructureTemplates).Count
        Save-HTSPStructureTemplate -Name 'Mój projekt' -Text "A`r`n    B"
        Save-HTSPStructureTemplate -Name 'mój projekt' -Text "C"
        $mine = @(Get-HTSPStructureTemplates | Where-Object { $_.Name -ieq 'Mój projekt' })
        $mine.Count | Should -Be 1
        $mine[0].Text | Should -Be 'C'
        $mine[0].BuiltIn | Should -BeFalse
        Save-HTSPStructureTemplate -Name 'Projekt' -Text 'Zastąpiony'
        (@(Get-HTSPStructureTemplates | Where-Object { $_.Name -eq 'Projekt' })[0]).Text | Should -Be 'Zastąpiony'
        Remove-HTSPStructureTemplate -Name 'mój projekt'
        Remove-HTSPStructureTemplate -Name 'Projekt'
        @(Get-HTSPStructureTemplates).Count | Should -Be $builtIn
    }
}

Describe "Kolumny bibliotek" {
    It "czyta nazwy, typy, opcje i wymagalność" {
        $c = @(ConvertFrom-HTSPColumnSpec -Text "Klient: Tekst *`r`nStatus: Wybór [Nowy, W toku; Zamknięty]`r`nData umowy: data`r`nOpiekun: Osoba`r`nUwagi`r`n2026 kwota: Waluta")
        $c.Count | Should -Be 6
        $c[0].Required | Should -BeTrue
        $c[0].Type | Should -Be 'Text'
        $c[1].Type | Should -Be 'Choice'
        $c[1].Choices | Should -Be @('Nowy', 'W toku', 'Zamknięty')
        $c[2].InternalName | Should -Be 'DataUmowy'
        $c[2].Type | Should -Be 'DateTime'
        $c[3].Type | Should -Be 'User'
        $c[4].Type | Should -Be 'Text'
        $c[5].InternalName | Should -Be 'Pole2026Kwota'
        @($c | Where-Object { -not $_.Valid }).Count | Should -Be 0
    }
    It "zgłasza nieznany typ, brak opcji wyboru i powtórzenia" {
        $c = @(ConvertFrom-HTSPColumnSpec -Text "A: Nieznany`r`nB: Wybór`r`nKlient`r`nklient: Tekst")
        ($c[0].Errors -join ';') | Should -Match 'nieznany typ'
        ($c[1].Errors -join ';') | Should -Match 'opcje wyboru'
        ($c[3].Errors -join ';') | Should -Match 'powtarza'
    }
}

Describe "Ustawienia bibliotek" {
    It "zmiany wobec bieżących ustawień i sprawdzenie limitu wersji" {
        $cur = [ordered]@{ Title = 'Dokumenty'; Description = ''; EnableVersioning = $true; MajorVersions = 500; ForceCheckout = $false }
        $r = Get-HTSPLibrarySettingChanges -Form ([ordered]@{ Title = 'Dokumenty'; Description = 'Opis'; EnableVersioning = 'Tak'; MajorVersions = '500'; ForceCheckout = 'Tak' }) -Current $cur
        @($r.Settings.Keys) | Should -Be @('Description', 'ForceCheckout')
        $r.Settings.ForceCheckout | Should -BeTrue
        (Get-HTSPLibrarySettingChanges -Form ([ordered]@{ MajorVersions = '50' }) -Current $cur).Errors.Count | Should -Be 1
        $multi = Get-HTSPLibrarySettingChanges -Form ([ordered]@{ Description = ''; EnableVersioning = '(bez zmian)'; MajorVersions = '1000'; NoCrawl = 'Nie' })
        @($multi.Settings.Keys) | Should -Be @('MajorVersions', 'NoCrawl')
        @(New-HTSPLibrarySettingsFields).Name | Should -Not -Contain 'Title'
        (@(New-HTSPLibrarySettingsFields -Current $cur) | Where-Object { $_.Name -eq 'EnableVersioning' }).Default | Should -Be 'Tak'
    }
}

Describe "Invoke-HTSPStructure" {
    BeforeEach {
        Mock -ModuleName SharePointStructure Get-HTSPRoleDefinitionList { @(@{ Name = 'Pełna kontrola'; RoleTypeKind = 'Administrator' }, @{ Name = 'Edycja'; RoleTypeKind = 'Editor' }, @{ Name = 'Odczyt'; RoleTypeKind = 'Reader' }) }
        Mock -ModuleName SharePointStructure Get-HTSPPrincipalResolver { @{ Groups = @('Kadry'); Associated = @{ Owner = 'Projekty Owners' } } }
        Mock -ModuleName SharePointStructure Get-HTSPWebUrl { '/sites/projekty' }
        Mock -ModuleName SharePointStructure Get-PnPFolder { if ($Url -like '*Istniejacy') { [PSCustomObject]@{ Name = 'Istniejacy' } } else { throw 'File Not Found' } }
        Mock -ModuleName SharePointStructure Resolve-PnPFolder { }
        Mock -ModuleName SharePointStructure Set-HTSPNodeAccess { 'nadano' }
        $script:Base = [PSCustomObject]@{ Title = 'Dokumenty'; ServerRelativeUrl = '/sites/projekty/Shared Documents'; ListTitle = 'Dokumenty'; IsLibrary = $true }
    }
    It "podgląd nie zmienia SharePoint i pokazuje plan" {
        $items = (ConvertFrom-HTSPStructureText -Text "Istniejacy`r`nNowy | Kadry=Edycja").Items
        $rows = @(Invoke-HTSPStructure -Items $items -BaseNode $Base -WhatIf)
        $rows[0].Akcja | Should -Be 'Istnieje'
        $rows[1].Akcja | Should -Be 'Utworzy folder'
        $rows[1].Status | Should -Be 'Podgląd'
        $rows[1].Szczegóły | Should -Match 'Kadry=Edycja'
        Should -Invoke -ModuleName SharePointStructure Resolve-PnPFolder -Times 0
        Should -Invoke -ModuleName SharePointStructure Set-HTSPNodeAccess -Times 0
    }
    It "tworzy foldery w bibliotece i nadaje uprawnienia" {
        $items = (ConvertFrom-HTSPStructureText -Text "Klient A/Umowy |! @Właściciele=Full").Items
        $rows = @(Invoke-HTSPStructure -Items $items -BaseNode $Base)
        $rows.Count | Should -Be 2
        Should -Invoke -ModuleName SharePointStructure Resolve-PnPFolder -Times 1 -ParameterFilter { $SiteRelativePath -eq 'Shared Documents/Klient A/Umowy' }
        Should -Invoke -ModuleName SharePointStructure Set-HTSPNodeAccess -Times 1 -ParameterFilter { $CopyExisting -eq $false -and $Node.ServerRelativeUrl -eq '/sites/projekty/Shared Documents/Klient A/Umowy' }
        $rows[1].Szczegóły | Should -Be 'nadano'
    }
    It "przed zmianami odrzuca nieznane poziomy uprawnień" {
        $items = (ConvertFrom-HTSPStructureText -Text "Nowy | Kadry=Superadmin").Items
        { Invoke-HTSPStructure -Items $items -BaseNode $Base } | Should -Throw '*Nieznany poziom*'
        Should -Invoke -ModuleName SharePointStructure Resolve-PnPFolder -Times 0
    }
}
