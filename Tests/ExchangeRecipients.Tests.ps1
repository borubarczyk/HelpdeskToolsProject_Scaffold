BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    New-HTTestStub -Name "Get-EXOMailboxFolderPermission" -Parameters "Identity", "User"
    New-HTTestStub -Name "Add-MailboxFolderPermission" -Parameters "Identity", "User", "AccessRights", "Confirm"
    New-HTTestStub -Name "Set-MailboxFolderPermission" -Parameters "Identity", "User", "AccessRights", "Confirm"
    New-HTTestStub -Name "Remove-MailboxFolderPermission" -Parameters "Identity", "User", "Confirm"
    Import-HTTestModule -Name "Utils", "MailboxesExchangeOnline", "ExchangeRecipients"
    Initialize-HTTestEnvironment -Root $TestDrive
}

Describe "Nowe skrzynki - nazwy i adresy" {
    It "tworzy alias z nazwy bez polskich znaków" {
        ConvertTo-HTMailboxAlias 'Biuro Zarządu - Łódź' | Should -Be 'biuro.zarzadu.lodz'
        ConvertTo-HTMailboxAlias '  Faktury (2026) ' | Should -Be 'faktury.2026'
    }
    It "czyta linie «Nazwa; adres» i sprawdza domeny oraz powtórzenia" {
        $text = "# komentarz`r`nBiuro Zarządu`r`nFaktury; FAKTURY@firma.pl`r`nObca; x@obca.pl`r`nBiuro Zarządu`r`n; bez@firma.pl"
        $e = @(ConvertFrom-HTNewMailboxLines -Text $text -Domain 'firma.pl' -Domains @('firma.pl', 'firma.onmicrosoft.com'))
        $e.Count | Should -Be 5
        $e[0].Address | Should -Be 'biuro.zarzadu@firma.pl'
        $e[0].Valid | Should -BeTrue
        $e[1].Address | Should -Be 'faktury@firma.pl'
        $e[1].Alias | Should -Be 'faktury'
        ($e[2].Errors -join ';') | Should -Match 'nie jest domeną akceptowaną'
        ($e[3].Errors -join ';') | Should -Match 'powtarza się'
        ($e[4].Errors -join ';') | Should -Match 'brak nazwy'
    }
    It "bez domeny wymaga adresu" {
        (@(ConvertFrom-HTNewMailboxLines -Text 'Sala A')[0].Errors -join ';') | Should -Match 'brak domeny'
    }
}

Describe "Kontakty z listy" {
    It "czyta nazwę, adres, firmę i telefon (średnik albo tabulator)" {
        $c = @(ConvertFrom-HTContactLines -Text "Jan Kowalski; JAN@partner.pl; Partner sp. z o.o.; +48 600 000 000`r`nAnna Nowak`tanna@x.pl`r`nZły; zly-adres`r`nJan Kowalski; jan@partner.pl")
        $c.Count | Should -Be 4
        $c[0].Email | Should -Be 'jan@partner.pl'
        $c[0].Company | Should -Be 'Partner sp. z o.o.'
        $c[0].Phone | Should -Be '+48 600 000 000'
        $c[1].Valid | Should -BeTrue
        ($c[2].Errors -join ';') | Should -Match 'nieprawidłowy'
        ($c[3].Errors -join ';') | Should -Match 'powtarza'
    }
}

Describe "Filtr grupy dynamicznej" {
    It "łączy warunki, podwaja apostrofy i używa -like dla *" {
        $f = ConvertTo-HTRecipientFilter -Conditions @(@{ Property = 'Dział'; Value = "Sprzedaż O'Neil" }, @{ Property = 'Miasto'; Value = 'Warsz*' }, @{ Property = 'Firma'; Value = '' })
        $f | Should -Match "^\(RecipientTypeDetails -eq 'UserMailbox'\) -and \(Department -eq 'Sprzedaż O''Neil'\) -and \(City -like 'Warsz\*'\)"
        $f | Should -Not -Match 'Company'
        $f | Should -Match "SystemMailbox"
    }
    It "wszyscy odbiorcy - bez filtra rodzaju; nieprawidłowa właściwość - błąd" {
        ConvertTo-HTRecipientFilter -Conditions @(@{ Property = 'CustomAttribute1'; Value = 'X' }) -RecipientType 'Wszyscy odbiorcy' | Should -Match "^\(CustomAttribute1 -eq 'X'\)"
        { ConvertTo-HTRecipientFilter -Conditions @(@{ Property = 'Dział; Remove'; Value = 'X' }) } | Should -Throw
    }
}

Describe "Ścieżki folderów skrzynki" {
    It "foldery nadrzędne i podfoldery" {
        Get-HTFolderAncestors -Path '\Inbox\Faktury\2025' | Should -Be @('\', '\Inbox', '\Inbox\Faktury')
        Get-HTFolderAncestors -Path '\Inbox' | Should -Be @('\')
        @(Get-HTFolderAncestors -Path '\').Count | Should -Be 0
        $all = @('\', '\Inbox', '\Inbox\Faktury', '\Inbox\Faktury\2025', '\Inbox2', '\Kalendarz')
        Get-HTSubfolderPaths -Path '\Inbox' -AllPaths $all | Should -Be @('\Inbox\Faktury', '\Inbox\Faktury\2025')
        @(Get-HTSubfolderPaths -Path '\' -AllPaths $all).Count | Should -Be 5
        Get-HTMailboxFolderIdentity -Mailbox 'a@b.pl' -Path '\' | Should -Be 'a@b.pl:\'
    }
}

Describe "Grant-HTMailboxFolderAccess" {
    BeforeEach {
        Mock -ModuleName ExchangeRecipients Get-EXOMailboxFolderPermission { throw "The user wasn't found" }
        Mock -ModuleName ExchangeRecipients Add-MailboxFolderPermission { }
        Mock -ModuleName ExchangeRecipients Set-MailboxFolderPermission { }
    }
    It "nadaje uprawnienia folderowi i podfolderom oraz widoczność folderom nadrzędnym" {
        $all = @('\', '\Inbox', '\Inbox\Faktury', '\Inbox\Faktury\2025')
        $text = Grant-HTMailboxFolderAccess -Mailbox 'a@b.pl' -Paths @('\Inbox\Faktury') -User 'jan@b.pl' -AccessRights Reviewer -IncludeSubfolders -AllPaths $all -ParentVisibility
        $text | Should -Match 'folderów: 2'
        $text | Should -Match 'widoczność folderów nadrzędnych: 2'
        Should -Invoke -ModuleName ExchangeRecipients Add-MailboxFolderPermission -Times 1 -ParameterFilter { $Identity -eq 'a@b.pl:\Inbox\Faktury\2025' -and $AccessRights -eq 'Reviewer' }
        Should -Invoke -ModuleName ExchangeRecipients Add-MailboxFolderPermission -Times 1 -ParameterFilter { $Identity -eq 'a@b.pl:\' -and $AccessRights -eq 'FolderVisible' }
        Should -Invoke -ModuleName ExchangeRecipients Add-MailboxFolderPermission -Times 1 -ParameterFilter { $Identity -eq 'a@b.pl:\Inbox' -and $AccessRights -eq 'FolderVisible' }
        Should -Invoke -ModuleName ExchangeRecipients Set-MailboxFolderPermission -Times 0
    }
    It "zmienia istniejące uprawnienie zamiast dodawać" {
        Mock -ModuleName ExchangeRecipients Get-EXOMailboxFolderPermission { [PSCustomObject]@{ User = 'jan'; AccessRights = 'Reviewer' } }
        Grant-HTMailboxFolderAccess -Mailbox 'a@b.pl' -Paths @('\Inbox') -User 'jan@b.pl' -AccessRights Editor | Out-Null
        Should -Invoke -ModuleName ExchangeRecipients Set-MailboxFolderPermission -Times 1 -ParameterFilter { $AccessRights -eq 'Editor' }
        Should -Invoke -ModuleName ExchangeRecipients Add-MailboxFolderPermission -Times 0
    }
}
