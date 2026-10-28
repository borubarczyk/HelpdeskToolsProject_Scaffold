BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    Import-HTTestModule -Name "Utils", "Security", "Integrations"
    Initialize-HTTestEnvironment -Root $TestDrive
}

Describe "Karta Teams" {
    It "buduje kartę adaptacyjną z tytułem, tekstem i faktami" {
        $Global:AppVersion = "9.9.9"
        $card = New-HTTeamsCard -Title "Offboarding" -Text "Zakończono" -Facts ([ordered]@{ Konto = "jan@firma.pl"; Błędy = "0" }) -Tone "ok"
        $card.type | Should -Be "message"
        $content = $card.attachments[0].content
        $card.attachments[0].contentType | Should -Be "application/vnd.microsoft.card.adaptive"
        $content.type | Should -Be "AdaptiveCard"
        $content.body[0].text | Should -Be "Offboarding"
        $content.body[0].color | Should -Be "Good"
        @($content.body | Where-Object { $_.type -eq "FactSet" })[0].facts[0].value | Should -Be "jan@firma.pl"
        (ConvertTo-Json -InputObject $card -Depth 12) | Should -Match "9.9.9"
    }
    It "bez adresu webhooka nie powiadamia o zdarzeniach" {
        $Global:HTConfig = [PSCustomObject]@{ TeamsWebhookProtected = ""; TeamsNotify = @("Jobs") }
        Test-HTTeamsNotify -Event "Jobs" | Should -BeFalse
        Send-HTTeamsMessage -Title "x" -Event "Jobs" | Should -BeFalse
    }
}

Describe "Wersja programu z repozytorium" {
    It "odczytuje wersję z treści skryptu" {
        Get-HTVersionFromScript '$Global:AppVersion = "3.12.1"' | Should -Be ([version]"3.12.1")
        Get-HTVersionFromScript 'brak wersji' | Should -BeNullOrEmpty
    }
    It "bez repozytorium zwraca błąd zamiast wyjątku" {
        $r = Test-HTUpdateAvailable -Repository "" -Branch "main" -Current "1.0.0"
        $r.Available | Should -BeFalse
        $r.Error | Should -Match "repozytorium"
    }
}

Describe "Send-HTGraphMail - sprawdzenie danych" {
    It "odrzuca nieprawidłowy adres przed wysłaniem" {
        { Send-HTGraphMail -To @("nie-adres") -Subject "t" -HtmlBody "x" } | Should -Throw
    }
    It "odrzuca zbyt duże załączniki" {
        $big = New-HTMailAttachment -Name "a.bin" -Bytes (New-Object byte[] (4MB))
        { Send-HTGraphMail -To @("jan@firma.pl") -Subject "t" -HtmlBody "x" -Attachments @($big) } | Should -Throw
    }
}
