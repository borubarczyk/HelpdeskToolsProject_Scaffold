BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    New-HTTestStub -Name "Set-Mailbox" -Parameters "Identity", "Office", "HiddenFromAddressListsEnabled", "Confirm"
    New-HTTestStub -Name "Set-CASMailbox" -Parameters "Identity", "ImapEnabled", "Confirm"
    New-HTTestStub -Name "Set-FocusedInbox" -Parameters "Identity", "FocusedInboxOn"
    New-HTTestStub -Name "Set-DistributionGroup" -Parameters "Identity", "MailTip", "Confirm", "BypassSecurityGroupManagerCheck"
    Import-HTTestModule -Name "Utils", "ExchangeSettings"
    Initialize-HTTestEnvironment -Root $TestDrive
    $script:Def = { param($key) @(Get-HTMailboxSettingDefinitions | Where-Object { $_.Key -eq $key })[0] }
}

Describe "Katalog ustawień skrzynek" {
    It "ma unikalne klucze i etykiety oraz znane sekcje" {
        foreach ($group in @($false, $true)) {
            $defs = @(Get-HTMailboxSettingDefinitions -Group:$group)
            $defs.Count | Should -BeGreaterThan 10
            @($defs.Key | Select-Object -Unique).Count | Should -Be $defs.Count
            @($defs.Label | Select-Object -Unique).Count | Should -Be $defs.Count
            $sections = Get-HTMailboxSettingSections
            foreach ($d in $defs) { $sections.Contains($d.Section) | Should -BeTrue -Because $d.Key }
        }
    }
    It "obejmuje kilkadziesiąt ustawień w 9 sekcjach skrzynek" {
        $defs = @(Get-HTMailboxSettingDefinitions)
        $defs.Count | Should -BeGreaterOrEqual 60
        @($defs.Section | Select-Object -Unique).Count | Should -Be 9
    }
}

Describe "Wartości ustawień" {
    It "normalizuje rozmiary, czasy i wartości logiczne z Exchange" {
        ConvertTo-HTMailboxSettingValue -Definition (& $Def 'ProhibitSendQuota') -Value '49.5 GB (53,150,220,288 bytes)' | Should -Be '49.5 GB'
        ConvertTo-HTMailboxSettingValue -Definition (& $Def 'RetainDeletedItemsFor') -Value '14.00:00:00' | Should -Be '14'
        ConvertTo-HTMailboxSettingValue -Definition (& $Def 'DefaultReminderTime') -Value ([timespan]::FromMinutes(15)) | Should -Be '15'
        ConvertTo-HTMailboxSettingValue -Definition (& $Def 'WorkingHoursStartTime') -Value '08:00:00' | Should -Be '08:00'
        ConvertTo-HTMailboxSettingValue -Definition (& $Def 'ImapEnabled') -Value 'False' | Should -BeFalse
        ConvertTo-HTMailboxSettingValue -Definition (& $Def 'SmtpClientAuthenticationDisabled') -Value $null | Should -Be 'Ustawienie organizacji'
        ConvertTo-HTMailboxSettingValue -Definition (& $Def 'SmtpClientAuthenticationDisabled') -Value $true | Should -Be 'Wyłączone'
        $list = ConvertTo-HTMailboxSettingValue -Definition (& $Def 'TrustedSendersAndDomains') -Value @('b.pl', 'a.pl', 'b.pl')
        $list | Should -Be @('a.pl', 'b.pl')
    }
    It "sprawdza i normalizuje wpisy" -TestCases @(
        @{ Key = 'ProhibitSendQuota'; Text = '49,5gb'; Ok = $true; Value = '49.5 GB' }
        @{ Key = 'ProhibitSendQuota'; Text = 'unlimited'; Ok = $true; Value = 'Unlimited' }
        @{ Key = 'ProhibitSendQuota'; Text = '12'; Ok = $false; Value = $null }
        @{ Key = 'RecipientLimits'; Text = '2000'; Ok = $false; Value = $null }
        @{ Key = 'RecipientLimits'; Text = '500'; Ok = $true; Value = '500' }
        @{ Key = 'WorkingHoursStartTime'; Text = '7:30'; Ok = $true; Value = '07:30' }
        @{ Key = 'WorkingHoursStartTime'; Text = '24:00'; Ok = $false; Value = $null }
        @{ Key = 'RetainDeletedItemsFor'; Text = '31'; Ok = $false; Value = $null }
        @{ Key = 'WeekStartDay'; Text = 'Środa'; Ok = $false; Value = $null }
        @{ Key = 'Alias'; Text = 'jan kowalski'; Ok = $false; Value = $null }
        @{ Key = 'MailTip'; Text = ('x' * 176); Ok = $false; Value = $null }
    ) {
        param($Key, $Text, $Ok, $Value)
        $r = ConvertFrom-HTMailboxSettingText -Definition (& $Def $Key) -Text $Text
        $r.Ok | Should -Be $Ok
        if ($Ok) { $r.Value | Should -Be $Value }
    }
}

Describe "Zmiany z formularza" {
    BeforeAll {
        $script:Current = [ordered]@{
            DisplayName = 'Jan Kowalski'; Office = 'Warszawa'; HiddenFromAddressListsEnabled = $false; ProhibitSendQuota = '49 GB'
            TrustedSendersAndDomains = @('a.pl', 'b.pl'); SmtpClientAuthenticationDisabled = 'Ustawienie organizacji'; Language = 'pl-PL'
        }
    }
    It "jedna skrzynka: tylko różnice wobec bieżących wartości" {
        $form = [ordered]@{ DisplayName = 'Jan Kowalski'; Office = 'Warszawa'; HiddenFromAddressListsEnabled = 'Tak'; ProhibitSendQuota = '49GB'; TrustedSendersAndDomains = "b.pl`r`nc.pl"; SmtpClientAuthenticationDisabled = 'Włączone'; Language = 'pl-PL' }
        $r = Get-HTMailboxSettingChanges -Form $form -Current $Current
        $r.Errors | Should -BeNullOrEmpty
        @($r.Changes.Key) | Should -Be @('HiddenFromAddressListsEnabled', 'SmtpClientAuthenticationDisabled', 'TrustedSendersAndDomains')
        $list = @($r.Changes | Where-Object Key -eq 'TrustedSendersAndDomains')[0]
        $list.Add | Should -Be @('c.pl')
        $list.Remove | Should -Be @('a.pl')
    }
    It "jedna skrzynka: puste pole tekstowe czyści, wymagane zgłasza błąd, zmiana wielkości liter jest zmianą" {
        $r = Get-HTMailboxSettingChanges -Form ([ordered]@{ Office = ''; DisplayName = '' }) -Current $Current
        @($r.Changes.Key) | Should -Be @('Office')
        $r.Changes[0].Value | Should -BeNullOrEmpty
        ($r.Errors -join ';') | Should -Match 'wymagane'
        $case = Get-HTMailboxSettingChanges -Form ([ordered]@{ DisplayName = 'Jan KOWALSKI' }) -Current $Current
        @($case.Changes).Count | Should -Be 1
    }
    It "wiele skrzynek: «(bez zmian)» i puste pola pomijane, «-» czyści, «-wpis» usuwa z listy" {
        $form = [ordered]@{ HiddenFromAddressListsEnabled = (Get-HTSettingKeepText); Office = '-'; ProhibitSendQuota = ''; TrustedSendersAndDomains = "x.pl`r`n-y.pl"; Language = '' }
        $r = Get-HTMailboxSettingChanges -Form $form
        @($r.Changes.Key) | Should -Be @('Office', 'TrustedSendersAndDomains')
        $r.Changes[1].Add | Should -Be @('x.pl')
        $r.Changes[1].Remove | Should -Be @('y.pl')
        $bad = Get-HTMailboxSettingChanges -Form ([ordered]@{ ProhibitSendQuota = '-'; Language = '-'; DisplayName = '-' })
        @($bad.Errors).Count | Should -Be 3
    }
    It "operacja jednorazowa (tłumaczenie folderów) tylko po zaznaczeniu" {
        (Get-HTMailboxSettingChanges -Form ([ordered]@{ LocalizeDefaultFolderName = $false })).Changes | Should -BeNullOrEmpty
        @((Get-HTMailboxSettingChanges -Form ([ordered]@{ LocalizeDefaultFolderName = $true })).Changes).Count | Should -Be 1
    }
}

Describe "Plan zmian" {
    It "grupuje parametry według poleceń i zamienia wartości na parametry Exchange" {
        $r = Get-HTMailboxSettingChanges -Form ([ordered]@{ Office = 'Kraków'; ImapEnabled = 'Nie'; SmtpClientAuthenticationDisabled = 'Wyłączone'; Language = 'en-US'; RetainDeletedItemsFor = '30'; DefaultReminderTime = '15'; WorkingHoursStartTime = '7:30'; TrustedSendersAndDomains = 'a.pl' })
        $plan = ConvertTo-HTMailboxSettingPlan -Changes $r.Changes
        $plan.Mailbox.Office | Should -Be 'Kraków'
        $plan.Mailbox.RetainDeletedItemsFor | Should -Be '30.00:00:00'
        $plan.CAS.ImapEnabled | Should -BeFalse
        $plan.CAS.SmtpClientAuthenticationDisabled | Should -BeTrue
        $plan.Regional.Language | Should -Be 'en-US'
        $plan.Regional.Contains('DateFormat') | Should -BeTrue
        $plan.Regional.DateFormat | Should -BeNullOrEmpty
        $plan.Calendar.DefaultReminderTime | Should -Be '00:15:00'
        $plan.Calendar.WorkingHoursStartTime | Should -Be '07:30:00'
        $plan.Junk.TrustedSendersAndDomains.Add | Should -Be @('a.pl')
        $plan.Junk.TrustedSendersAndDomains.ContainsKey('Remove') | Should -BeFalse
    }
    It "ustawienie organizacji (SMTP AUTH) to parametr pusty" {
        $r = Get-HTMailboxSettingChanges -Form ([ordered]@{ SmtpClientAuthenticationDisabled = 'Ustawienie organizacji' })
        $plan = ConvertTo-HTMailboxSettingPlan -Changes $r.Changes
        $plan.CAS.Contains('SmtpClientAuthenticationDisabled') | Should -BeTrue
        $plan.CAS.SmtpClientAuthenticationDisabled | Should -BeNullOrEmpty
    }
}

Describe "Invoke-HTMailboxSettingPlan" {
    BeforeEach {
        Mock -ModuleName ExchangeSettings Set-Mailbox { }
        Mock -ModuleName ExchangeSettings Set-FocusedInbox { }
        Mock -ModuleName ExchangeSettings Set-DistributionGroup { }
    }
    It "wykonuje polecenia każdego źródła" {
        Mock -ModuleName ExchangeSettings Set-CASMailbox { }
        $plan = ConvertTo-HTMailboxSettingPlan -Changes (Get-HTMailboxSettingChanges -Form ([ordered]@{ Office = 'X'; ImapEnabled = 'Nie'; FocusedInboxOn = 'Tak' })).Changes
        $text = Invoke-HTMailboxSettingPlan -Identity 'a@b.pl' -Plan $plan
        $text | Should -Match 'skrzynka'
        Should -Invoke -ModuleName ExchangeSettings Set-Mailbox -Times 1 -ParameterFilter { $Identity -eq 'a@b.pl' -and $Office -eq 'X' -and $Confirm -eq $false }
        Should -Invoke -ModuleName ExchangeSettings Set-CASMailbox -Times 1 -ParameterFilter { $ImapEnabled -eq $false }
        Should -Invoke -ModuleName ExchangeSettings Set-FocusedInbox -Times 1 -ParameterFilter { $FocusedInboxOn -eq $true }
    }
    It "błąd jednego polecenia nie zatrzymuje pozostałych i jest zgłaszany z informacją o zapisanych" {
        Mock -ModuleName ExchangeSettings Set-CASMailbox { throw 'brak licencji' }
        $plan = ConvertTo-HTMailboxSettingPlan -Changes (Get-HTMailboxSettingChanges -Form ([ordered]@{ Office = 'X'; ImapEnabled = 'Nie' })).Changes
        { Invoke-HTMailboxSettingPlan -Identity 'a@b.pl' -Plan $plan } | Should -Throw '*protokoły: brak licencji*Zapisano: skrzynka*'
        Should -Invoke -ModuleName ExchangeSettings Set-Mailbox -Times 1
    }
    It "grupy: zmiana z pominięciem sprawdzania właściciela" {
        $defs = @(Get-HTMailboxSettingDefinitions -Group)
        $plan = ConvertTo-HTMailboxSettingPlan -Changes (Get-HTMailboxSettingChanges -Form ([ordered]@{ MailTip = 'Tylko sprawy pilne' }) -Definitions $defs).Changes
        Invoke-HTMailboxSettingPlan -Identity 'dl@b.pl' -Plan $plan | Out-Null
        Should -Invoke -ModuleName ExchangeSettings Set-DistributionGroup -Times 1 -ParameterFilter { $MailTip -eq 'Tylko sprawy pilne' -and $BypassSecurityGroupManagerCheck -eq $true }
    }
}

Describe "Pola formularza" {
    It "jedna skrzynka - bieżące wartości, wiele - «(bez zmian)», wartości wpisane wcześniej mają pierwszeństwo" {
        $single = @(New-HTMailboxSettingsFormFields -Current ([ordered]@{ HiddenFromAddressListsEnabled = $true; Office = 'A' }))
        $hidden = @($single | Where-Object { $_.Name -eq 'HiddenFromAddressListsEnabled' })[0]
        $hidden.Default | Should -Be 'Tak'
        $hidden.Options | Should -Be @('Tak', 'Nie')
        @($single | Where-Object { $_.Type -eq 'Header' }).Count | Should -Be 9
        $multi = @(New-HTMailboxSettingsFormFields -Values ([ordered]@{ Office = 'B' }))
        (@($multi | Where-Object { $_.Name -eq 'HiddenFromAddressListsEnabled' })[0]).Default | Should -Be (Get-HTSettingKeepText)
        (@($multi | Where-Object { $_.Name -eq 'Office' })[0]).Default | Should -Be 'B'
        (@($multi | Where-Object { $_.Name -eq 'RetentionPolicy' })[0]).Type | Should -Be 'Combo'
    }
    It "listy wartości z -Options (np. zasady przechowywania)" {
        $f = @(New-HTMailboxSettingsFormFields -Sections Retention -Options @{ RetentionPolicies = @('Polityka A', 'Polityka B') })
        (@($f | Where-Object { $_.Name -eq 'RetentionPolicy' })[0]).Options | Should -Be @('Polityka A', 'Polityka B')
    }
}

Describe "Kopiowanie ze skrzynki wzorcowej" {
    It "pomija nazwę i alias oraz sekcje niewybrane; zastępuje listy skrzynki docelowej" {
        $source = [ordered]@{ DisplayName = 'Wzorzec'; Alias = 'wzorzec'; Office = 'Kraków'; TrustedSendersAndDomains = @('a.pl'); Language = 'pl-PL'; __Errors = @() }
        $form = Get-HTMailboxSettingCopyForm -Source $source -Sections General, Inbox
        $form.Contains('DisplayName') | Should -BeFalse
        $form.Contains('Language') | Should -BeFalse
        $form.Office | Should -Be 'Kraków'
        $target = [ordered]@{ Office = 'Warszawa'; TrustedSendersAndDomains = @('b.pl') }
        $r = Get-HTMailboxSettingChanges -Form $form -Current $target
        @($r.Changes.Key) | Should -Be @('Office', 'TrustedSendersAndDomains')
        (@($r.Changes)[1]).Remove | Should -Be @('b.pl')
    }
}

Describe "Masowa zmiana z pliku CSV" {
    It "szablon ma kolumnę Skrzynka i wszystkie ustawienia" {
        $header = (Get-HTMailboxSettingsCsvTemplate).Split("`n")[0]
        $header | Should -Match '^"Skrzynka";"DisplayName"'
        $header | Should -Match '"ProhibitSendQuota"'
        @(Get-HTMailboxSettingsCsvColumnHelp).Count | Should -Be @(Get-HTMailboxSettingDefinitions).Count
    }
    It "zamienia wiersz na zmiany i zgłasza błędy" {
        $row = [PSCustomObject]@{ Email = 'a@b.pl'; Office = 'X'; MessageCopyForSentAsEnabled = 'tak'; TrustedSendersAndDomains = 'a.pl, -b.pl'; SmtpClientAuthenticationDisabled = 'disabled'; ImapEnabled = '' }
        $r = ConvertFrom-HTMailboxSettingsCsvRow -Row $row
        $r.Identity | Should -Be 'a@b.pl'
        $r.Valid | Should -BeTrue
        @($r.Changes.Key) | Should -Be @('Office', 'MessageCopyForSentAsEnabled', 'SmtpClientAuthenticationDisabled', 'TrustedSendersAndDomains')
        $bad = ConvertFrom-HTMailboxSettingsCsvRow -Row ([PSCustomObject]@{ Skrzynka = ''; ImapEnabled = 'może' })
        $bad.Valid | Should -BeFalse
        ($bad.Errors -join ';') | Should -Match 'brak adresu'
        ($bad.Errors -join ';') | Should -Match 'Tak albo Nie'
        (ConvertFrom-HTMailboxSettingsCsvRow -Row ([PSCustomObject]@{ Skrzynka = 'a@b.pl'; Office = '' })).Errors | Should -Be @('brak zmian w wierszu')
    }
    It "wykrywa nieznane kolumny" {
        Get-HTMailboxSettingsCsvUnknownColumns -Columns @('Skrzynka', 'office', 'Ofice') | Should -Be @('Ofice')
    }
    It "rozpoznaje Tak / Nie w różnych zapisach" {
        ConvertFrom-HTYesNo 'TAK' | Should -BeTrue
        ConvertFrom-HTYesNo '0' | Should -BeFalse
        ConvertFrom-HTYesNo 'może' | Should -BeNullOrEmpty
    }
}

Describe "Kontrola konfiguracji Exchange" {
    It "ocenia uwierzytelnianie, przekazywanie, DKIM i brakujące dane" {
        $data = @{
            Organization      = @([PSCustomObject]@{ OAuth2ClientProfileEnabled = $false; AuditDisabled = $false; MailTipsExternalRecipientsTipsEnabled = $true })
            Transport         = @([PSCustomObject]@{ SmtpClientAuthenticationDisabled = $true; MaxSendSize = '35 MB (36,700,160 bytes)'; MaxReceiveSize = '36 MB (37,748,736 bytes)' })
            OutboundPolicies  = @([PSCustomObject]@{ Name = 'Default'; AutoForwardingMode = 'On' })
            RemoteDomains     = @([PSCustomObject]@{ Name = 'Default'; DomainName = '*'; AutoForwardEnabled = $true; AllowedOOFType = 'External' })
            AcceptedDomains   = @([PSCustomObject]@{ DomainName = 'firma.pl'; DomainType = 'Authoritative'; Default = $true }, [PSCustomObject]@{ DomainName = 'firma.onmicrosoft.com'; DomainType = 'Authoritative'; Default = $false })
            Dkim              = @([PSCustomObject]@{ Domain = 'firma.onmicrosoft.com'; Enabled = $true })
            ConnectionPolicies = @([PSCustomObject]@{ Name = 'Default'; IPAllowList = @('1.2.3.4') })
            'AdminAudit.Error' = 'Brak uprawnień'
        }
        $rows = @(Get-HTExchangeConfigFindings -Data $data)
        (@($rows | Where-Object { $_.Kontrola -like 'Nowoczesne*' })[0]).Ocena | Should -Be 'Ryzyko'
        (@($rows | Where-Object { $_.Kontrola -like 'Automatyczne przekazywanie*' })[0]).__flag | Should -Be 'crit'
        (@($rows | Where-Object { $_.Kontrola -like '*automatyczne przekazywanie' })[0]).Ocena | Should -Be 'Uwaga'
        (@($rows | Where-Object { $_.Kontrola -eq 'Podpis DKIM - firma.pl' })[0]).Wartość | Should -Be 'brak konfiguracji'
        (@($rows | Where-Object { $_.Kontrola -like 'Ujednolicony*' })[0]).Ocena | Should -Be 'Nie sprawdzono'
        (@($rows | Where-Object { $_.Kontrola -like 'Dozwolone adresy IP*' })[0]).Ocena | Should -Be 'Uwaga'
        (@($rows | Where-Object { $_.Kontrola -like 'Maks. rozmiar*' })[0]).Wartość | Should -Be '35 MB / 36 MB'
    }
}
