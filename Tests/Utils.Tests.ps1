BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    Import-HTTestModule -Name "Utils"
    Initialize-HTTestEnvironment -Root $TestDrive
}

Describe "Write-Log" {
    BeforeEach { Clear-HTLogHistory }

    It "zapisuje wpis w historii z poziomem <Expected> dla typu <Type>" -TestCases @(
        @{ Type = "Info"; Expected = "Info" }
        @{ Type = "Warn"; Expected = "Warn" }
        @{ Type = "Warning"; Expected = "Warn" }
        @{ Type = "Warning&Notification"; Expected = "Warn" }
        @{ Type = "Error&Notification"; Expected = "Error" }
    ) {
        param($Type, $Expected)
        Write-Log -Message "test" -Type $Type
        $entry = @(Get-HTLogHistory)[-1]
        $entry.Type | Should -Be $Expected
        $entry.Message | Should -BeLike "*test"
    }

    It "przyjmuje parametry pozycyjne" {
        Write-Log "pozycyjny" "Error"
        (@(Get-HTLogHistory)[-1]).Type | Should -Be "Error"
    }

    It "dopisuje wpis do pliku logu" {
        Write-Log -Message "do pliku" -Type "Info"
        $content = Get-Content (Get-HTLogFile) -Raw
        $content | Should -Match "\[Info\].*do pliku"
    }

    It "powiadamia zarejestrowanych odbiorców" {
        $script:received = @()
        Register-HTLogSink -ScriptBlock { param($entry) $script:received += $entry.Message }
        Write-Log -Message "odbiorca" -Type "Info"
        $script:received | Should -Contain (@(Get-HTLogHistory)[-1].Message)
    }

    It "tworzy archiwum, gdy plik logu przekroczy limit" {
        $Global:LogFileMaxSizeMB = 0.0001
        try {
            Write-Log -Message ("x" * 500) -Type "Info"
            Write-Log -Message "po rotacji" -Type "Info"
            @(Get-ChildItem (Get-HTLogDirectory) -Filter "HelpdeskTools_*_*.log").Count | Should -BeGreaterThan 0
        }
        finally { $Global:LogFileMaxSizeMB = 5 }
    }
}

Describe "Test-HTLogEntryMatch" {
    BeforeAll { $entry = [PSCustomObject]@{ Time = Get-Date; Type = "Warn"; Message = "⚠️ Brak połączenia z Exchange" } }
    It "filtruje po typie" {
        Test-HTLogEntryMatch -Entry $entry -FilterType "Warn" | Should -BeTrue
        Test-HTLogEntryMatch -Entry $entry -FilterType "Error" | Should -BeFalse
        Test-HTLogEntryMatch -Entry $entry -FilterType "Wszystkie" | Should -BeTrue
    }
    It "filtruje po tekście bez rozróżniania wielkości liter" {
        Test-HTLogEntryMatch -Entry $entry -FilterText "exchange" | Should -BeTrue
        Test-HTLogEntryMatch -Entry $entry -FilterText "graph" | Should -BeFalse
    }
}

Describe "Test-HTInputValue" {
    It "waliduje <Type> '<Value>' jako <Expected>" -TestCases @(
        @{ Type = "Email"; Value = "jan.kowalski@firma.pl"; Expected = $true }
        @{ Type = "Email"; Value = "o'brien@firma.co.uk"; Expected = $true }
        @{ Type = "Email"; Value = "brak-malpy.pl"; Expected = $false }
        @{ Type = "Phone"; Value = "+48 600 100 200"; Expected = $true }
        @{ Type = "Phone"; Value = "12345"; Expected = $false }
        @{ Type = "Url"; Value = "https://firma.sharepoint.com/sites/IT"; Expected = $true }
        @{ Type = "Url"; Value = "firma.sharepoint.com"; Expected = $false }
        @{ Type = "Guid"; Value = "3f2504e0-4f89-11d3-9a0c-0305e82c3301"; Expected = $true }
        @{ Type = "Guid"; Value = "nie-guid"; Expected = $false }
        @{ Type = "Text"; Value = "   "; Expected = $false }
        @{ Type = "Text"; Value = "abc"; Expected = $true }
    ) {
        param($Type, $Value, $Expected)
        Test-HTInputValue -Value $Value -ValidationType $Type | Should -Be $Expected
    }
}

Describe "ConvertTo-HTDisplayValue" {
    It "zamienia wartości logiczne na Tak/Nie" {
        ConvertTo-HTDisplayValue $true | Should -Be "Tak"
        ConvertTo-HTDisplayValue $false | Should -Be "Nie"
    }
    It "formatuje daty" {
        ConvertTo-HTDisplayValue ([datetime]"2024-05-01 13:45:00") | Should -Be "2024-05-01 13:45"
    }
    It "formatuje daty ISO 8601 zapisane jako tekst" {
        ConvertTo-HTDisplayValue "2024-05-01T13:45:00" | Should -Be "2024-05-01 13:45"
    }
    It "łączy tablice" {
        ConvertTo-HTDisplayValue @("a", "b", $true) | Should -Be "a, b, Tak"
    }
    It "zwraca pusty tekst dla null" {
        ConvertTo-HTDisplayValue $null | Should -Be ""
    }
    It "nie zmienia zwykłego tekstu" {
        ConvertTo-HTDisplayValue "Dział IT" | Should -Be "Dział IT"
    }
}

Describe "Split-HTInputList" {
    It "dzieli po nowych liniach, przecinkach i średnikach oraz usuwa duplikaty" {
        $result = Split-HTInputList -Text "a@x.pl`r`nb@x.pl, c@x.pl;a@x.pl`n`n  "
        $result | Should -Be @("a@x.pl", "b@x.pl", "c@x.pl")
    }
    It "zwraca pustą tablicę dla pustego tekstu" {
        @(Split-HTInputList -Text "").Count | Should -Be 0
    }
}

Describe "Pozostałe funkcje pomocnicze" {
    It "Format-HTBytes formatuje rozmiary" {
        Format-HTBytes 1536 | Should -Match "^1[\.,]5 KB$"
        Format-HTBytes $null | Should -Be ""
    }
    It "ConvertTo-HTAsciiName usuwa polskie znaki" {
        ConvertTo-HTAsciiName "Łukasz Żółć-Gęślą" | Should -Be "Lukasz Zolc-Gesla"
    }
    It "Remove-InnerWhitespace usuwa wszystkie spacje" {
        Remove-InnerWhitespace -InputString " +48 600 100 200 " -TrimEnds | Should -Be "+48600100200"
    }
    It "Format-HTLogEntry zwraca linię z czasem i typem" {
        $line = Format-HTLogEntry -Entry ([PSCustomObject]@{ Time = [datetime]"2024-01-02 03:04:05"; Type = "Info"; Message = "x" })
        $line | Should -Be "2024-01-02 03:04:05 [Info] x"
    }
}

Describe "Write-Log - powiadomienia" {
    BeforeEach { Clear-HTLogHistory }
    It "oznacza wpis jako powiadomienie dla typu *&Notification" {
        $Global:ShowNotifications = $true
        Write-Log -Message "z powiadomieniem" -Type "Info&Notification"
        (@(Get-HTLogHistory)[-1]).Notify | Should -BeTrue
        Write-Log -Message "bez" -Type "Info"
        (@(Get-HTLogHistory)[-1]).Notify | Should -BeFalse
    }
    It "nie oznacza powiadomienia, gdy powiadomienia są wyłączone" {
        $Global:ShowNotifications = $false
        try {
            Write-Log -Message "wyłączone" -Type "Error&Notification"
            (@(Get-HTLogHistory)[-1]).Notify | Should -BeFalse
        }
        finally { $Global:ShowNotifications = $true }
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

Describe "ConvertTo-HTDetailRows" {
    It "spłaszcza zagnieżdżone sekcje i łączy tablice nowymi liniami" {
        $rows = @(ConvertTo-HTDetailRows -Data ([ordered]@{ Nazwa = "Jan"; Włączone = $true; Konto = [ordered]@{ Grupy = @("A", "B") } }))
        $rows.Count | Should -Be 3
        $rows[0].Sekcja | Should -Be "Ogólne"
        $rows[1].Wartość | Should -Be "Tak"
        $rows[2].Sekcja | Should -Be "Konto"
        $rows[2].Wartość | Should -Be "A`nB"
    }
}

Describe "Get-HTDaysSince" {
    It "liczy dni od daty, tekstu ISO i zwraca null dla braku daty" {
        Get-HTDaysSince ((Get-Date).AddDays(-10)) | Should -Be 10
        Get-HTDaysSince ((Get-Date).ToUniversalTime().AddDays(-3).ToString("yyyy-MM-ddTHH:mm:ssZ")) | Should -Be 3
        Get-HTDaysSince $null | Should -BeNullOrEmpty
        Get-HTDaysSince "nie-data" | Should -BeNullOrEmpty
        Get-HTDaysSince ([datetime]::MinValue) | Should -BeNullOrEmpty
    }
}

Describe "Dziennik z kontem MFA i odczyt pliku dziennika" {
    BeforeEach {
        $Global:LogDir = Join-Path $TestDrive ([guid]::NewGuid().ToString("N"))
        Clear-HTLogHistory
    }
    AfterEach {
        $Global:HTActiveAccount = $null
        $Global:LogDir = $null
    }

    It "dopisuje konto MFA do wpisu w pliku" {
        $Global:HTActiveAccount = "Anna"
        Write-Log -Message "operacja konta" -Type "Warn"
        (@(Get-HTLogHistory)[-1]).Account | Should -Be "Anna"
        Get-Content (Get-HTLogFile) -Raw | Should -Match "\[Warn\] \[konto: Anna\] .*operacja konta"
    }

    It "czyta wpisy z poziomem, kontem i wieloliniowym komunikatem" {
        Write-Log -Message "start" -Type "Info"
        $Global:HTActiveAccount = "Anna"
        Write-Log -Message "błąd`ndruga linia" -Type "Error"
        Write-Log -Message "uwaga" -Type "Warn"
        $rows = @(Read-HTLogFile -Path (Get-HTLogFile))
        $rows.Count | Should -Be 3
        $rows[0].Poziom | Should -Be "Info"
        $rows[0].Komunikat | Should -Be "start"
        $rows[1].Konto | Should -Be "Anna"
        $rows[1].Komunikat | Should -Be "błąd`ndruga linia"
        $rows[1].__flag | Should -Be "crit"
        @(Read-HTLogFile -Path (Get-HTLogFile) -Level Problems).Count | Should -Be 2
        @(Read-HTLogFile -Path (Get-HTLogFile) -Level Error).Count | Should -Be 1
        @(Read-HTLogFile -Path (Get-HTLogFile) -Text "UWAGA").Count | Should -Be 1
        @(Read-HTLogFile -Path (Get-HTLogFile) -Text "anna").Count | Should -Be 2
    }

    It "listuje pliki dziennika od najnowszego" {
        New-Item -ItemType Directory -Path $Global:LogDir -Force | Out-Null
        foreach ($name in "HelpdeskTools_20260101.log", "HelpdeskTools_20260315.log", "inny.log") { Set-Content -Path (Join-Path $Global:LogDir $name) -Value "x" }
        $files = @(Get-HTLogFiles)
        $files.Count | Should -Be 2
        $files[0].Name | Should -Be "HelpdeskTools_20260315.log"
        $files[0].Date | Should -Be ([datetime]"2026-03-15")
    }
}

Describe "Katalog eksportu i zapis w folderze" {
    BeforeAll {
        $script:blocker = Join-Path $TestDrive "plik.txt"
        Set-Content -Path $script:blocker -Value "x"
        $script:savedExport = $Global:ExportPath
        $script:savedLocal = $env:LOCALAPPDATA
    }
    AfterEach {
        $Global:ExportPath = $script:savedExport
        $env:LOCALAPPDATA = $script:savedLocal
    }

    It "tworzy brakujący folder i zgłasza możliwość zapisu" {
        $dir = Join-Path $TestDrive "nowy\podfolder"
        Test-HTWritableDirectory -Path $dir | Should -BeTrue
        Test-Path -LiteralPath $dir | Should -BeTrue
        @(Get-ChildItem -LiteralPath $dir -Force).Count | Should -Be 0
    }

    It "zwraca false, gdy folderu nie da się utworzyć albo ścieżka jest pusta" {
        Test-HTWritableDirectory -Path (Join-Path $script:blocker "pod") | Should -BeFalse
        Test-HTWritableDirectory -Path "" | Should -BeFalse
    }

    It "używa ustawionego folderu eksportu, gdy da się w nim zapisać" {
        $Global:ExportPath = Join-Path $TestDrive "eksport-ok"
        Get-HTExportDirectory | Should -Be $Global:ExportPath
    }

    It "przechodzi na folder lokalny, gdy w folderze eksportu nie da się zapisać" {
        $Global:ExportPath = Join-Path $script:blocker "eksport"
        $env:LOCALAPPDATA = Join-Path $TestDrive "local"
        $dir = Get-HTExportDirectory
        $dir | Should -Be (Join-Path $env:LOCALAPPDATA "HelpdeskTools\Eksport")
        Test-Path -LiteralPath $dir | Should -BeTrue
        @(Get-HTLogHistory | Where-Object { $_.Type -eq "Warn" -and $_.Message -like "*eksport do folderu lokalnego*" }).Count | Should -BeGreaterThan 0
    }

    It "odtwarza folder eksportu usunięty w trakcie pracy" {
        $Global:ExportPath = Join-Path $TestDrive "eksport-usuniety"
        Get-HTExportDirectory | Out-Null
        Remove-Item -LiteralPath $Global:ExportPath -Recurse -Force
        Get-HTExportDirectory | Should -Be $Global:ExportPath
        Test-Path -LiteralPath $Global:ExportPath | Should -BeTrue
    }
}

Describe "Szczegółowy dziennik (debug)" {
    AfterEach { $Global:DebugLogging = $null }
    It "pomija wpisy Debug, gdy szczegółowy dziennik jest wyłączony" {
        $Global:DebugLogging = $false
        $before = @(Get-HTLogHistory).Count
        Write-Log -Message "ukryty" -Type "Debug"
        Write-HTDebug "też ukryty"
        Write-HTDebug { throw "nie powinno się wykonać" }
        @(Get-HTLogHistory).Count | Should -Be $before
    }
    It "zapisuje wpisy Debug w historii i pliku, gdy jest włączony" {
        $Global:DebugLogging = $true
        Write-HTDebug { "Graph GET users - OK ($(1 + 1) ms)" }
        $entry = @(Get-HTLogHistory)[-1]
        $entry.Type | Should -Be "Debug"
        $entry.Message | Should -BeLike "*Graph GET users - OK (2 ms)"
        Get-Content (Get-HTLogFile) -Raw | Should -Match "\[Debug\].*Graph GET users"
        @(Read-HTLogFile -Path (Get-HTLogFile) -Text "Graph GET users")[-1].Poziom | Should -Be "Debug"
    }
}
