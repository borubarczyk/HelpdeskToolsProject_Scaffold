BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    New-HTTestStub -Name "Set-MailboxAutoReplyConfiguration" -Parameters "Identity", "AutoReplyState", "InternalMessage", "ExternalMessage", "ExternalAudience", "StartTime", "EndTime"
    New-HTTestStub -Name "Set-Mailbox" -Parameters "Identity", "ForwardingSmtpAddress", "ForwardingAddress", "DeliverToMailboxAndForward", "Confirm"
    Import-HTTestModule -Name "Utils", "MailboxesExchangeOnline"
    Initialize-HTTestEnvironment -Root $TestDrive
}

Describe "Konwersja treści autoodpowiedzi" {
    It "zamienia tekst na HTML z kodowaniem znaków i nowymi liniami" {
        ConvertTo-HTAutoReplyHtml "Jestem na urlopie <do 10.05>`r`nPozdrawiam" | Should -Be "Jestem na urlopie &lt;do 10.05&gt;<br>Pozdrawiam"
    }
    It "nie zmienia treści, która jest już HTML" {
        ConvertTo-HTAutoReplyHtml "<p>Tekst</p>" | Should -Be "<p>Tekst</p>"
    }
    It "zamienia HTML z powrotem na tekst" {
        ConvertFrom-HTAutoReplyHtml "<html><body>Linia 1<br>Linia &amp; 2</body></html>" | Should -Be "Linia 1`r`nLinia & 2"
    }
}

Describe "Set-HTMailboxAutoReply" {
    BeforeEach { Mock -ModuleName MailboxesExchangeOnline Set-MailboxAutoReplyConfiguration { } }

    It "wymaga dat dla trybu Scheduled" {
        { Set-HTMailboxAutoReply -Identity "a@b.pl" -State Scheduled -InternalMessage "x" } | Should -Throw
    }
    It "odrzuca datę końca wcześniejszą niż początek" {
        { Set-HTMailboxAutoReply -Identity "a@b.pl" -State Scheduled -InternalMessage "x" -StartTime (Get-Date) -EndTime (Get-Date).AddDays(-1) } | Should -Throw
    }
    It "używa treści wewnętrznej jako zewnętrznej, gdy brak zewnętrznej" {
        Set-HTMailboxAutoReply -Identity "a@b.pl" -State Enabled -InternalMessage "Urlop"
        Should -Invoke -ModuleName MailboxesExchangeOnline Set-MailboxAutoReplyConfiguration -Times 1 -ParameterFilter { $ExternalMessage -eq "Urlop" -and $AutoReplyState -eq "Enabled" }
    }
    It "wyłącza autoodpowiedź bez wysyłania treści" {
        Set-HTMailboxAutoReply -Identity "a@b.pl" -State Disabled
        Should -Invoke -ModuleName MailboxesExchangeOnline Set-MailboxAutoReplyConfiguration -Times 1 -ParameterFilter { $AutoReplyState -eq "Disabled" -and -not $PSBoundParameters.ContainsKey("InternalMessage") }
    }
}

Describe "Set-HTMailboxForwarding" {
    BeforeEach { Mock -ModuleName MailboxesExchangeOnline Set-Mailbox { } }
    It "ustawia przekierowanie SMTP" {
        Set-HTMailboxForwarding -Identity "a@b.pl" -ForwardTo "c@d.pl" -KeepCopy $true
        Should -Invoke -ModuleName MailboxesExchangeOnline Set-Mailbox -ParameterFilter { $ForwardingSmtpAddress -eq "smtp:c@d.pl" -and $DeliverToMailboxAndForward -eq $true }
    }
    It "czyści przekierowanie dla pustego adresu" {
        Set-HTMailboxForwarding -Identity "a@b.pl" -ForwardTo ""
        Should -Invoke -ModuleName MailboxesExchangeOnline Set-Mailbox -ParameterFilter { $null -eq $ForwardingSmtpAddress -and $DeliverToMailboxAndForward -eq $false }
    }
}

Describe "ConvertFrom-HTExchangeSize" {
    It "odczytuje liczbę bajtów z opisu rozmiaru Exchange" {
        ConvertFrom-HTExchangeSize "1.234 GB (1,325,000,000 bytes)" | Should -Be 1325000000
        ConvertFrom-HTExchangeSize "49.5 GB (53 150 220 288 bytes)" | Should -Be 53150220288
        ConvertFrom-HTExchangeSize "Unlimited" | Should -BeNullOrEmpty
        ConvertFrom-HTExchangeSize $null | Should -BeNullOrEmpty
        ConvertFrom-HTExchangeSize "1024" | Should -Be 1024
    }
}

Describe "Adresy e-mail skrzynki" {
    BeforeAll { New-HTTestStub -Name "Set-Mailbox" -Parameters "Identity", "EmailAddresses", "Confirm" }
    It "nie pozwala usunąć adresu głównego" {
        { Remove-HTMailboxAddress -Identity "a@x.pl" -Value "SMTP:a@x.pl" } | Should -Throw "*głównego*"
    }
    It "odrzuca nieprawidłowy alias" {
        { Add-HTMailboxAddress -Identity "a@x.pl" -Address "zly-adres" } | Should -Throw "*Nieprawidłowy*"
    }
}
