BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    Import-HTTestModule -Name "Utils", "Security", "Integrations", "Automation"
    Initialize-HTTestEnvironment -Root $TestDrive
    $Global:HTConfig = [PSCustomObject]@{ TeamsWebhookProtected = ""; TeamsNotify = @() }
}

Describe "Podsumowanie operacji do zgłoszenia" {
    BeforeEach { Clear-HTOperationRecords }

    It "grupuje operacje i liczy błędy" {
        Add-HTOperationRecord -Operation "Blokada logowania" -Object "jan@firma.pl"
        Add-HTOperationRecord -Operation "Blokada logowania" -Object "anna@firma.pl" -Status "Błąd" -Details "brak uprawnień"
        Add-HTOperationRecord -Operation "Usunięcie licencji" -Object "jan@firma.pl" -Details "E3"
        $text = Format-HTOperationSummary -Records @(Get-HTOperationRecords)
        $text | Should -Match "Blokada logowania:"
        $text | Should -Match "anna@firma.pl: błąd - brak uprawnień"
        $text | Should -Match "Razem: 3 operacji, w tym z błędem: 1"
    }
    It "filtruje po obiekcie" {
        Add-HTOperationRecord -Operation "A" -Object "jan@firma.pl"
        Add-HTOperationRecord -Operation "B" -Object "anna@firma.pl"
        @(Get-HTOperationRecords -Object "JAN").Count | Should -Be 1
    }
    It "bez operacji podaje informację" {
        Format-HTOperationSummary -Records @() | Should -Match "brak operacji"
    }
    It "pokazuje sprawdzenia (co, gdzie i wynik) przed zmianami" {
        Add-HTOperationRecord -Kind Check -Operation "Uprawnienia witryny" -Object "https://firma.sharepoint.com/sites/Zarzad" -Details "wyników: 34, ostrzeżenia: 2"
        Add-HTOperationRecord -Kind Check -Operation "Dostęp: jan" -Object "https://firma.sharepoint.com/sites/Zarzad" -Status "Błąd" -Details "Access denied"
        Add-HTOperationRecord -Operation "Nadanie uprawnień" -Object "jan@firma.pl" -Details "Edycja"
        $text = Format-HTOperationSummary -Records @(Get-HTOperationRecords)
        $text | Should -Match "Sprawdzenia:"
        $text | Should -Match "Uprawnienia witryny \(https://firma.sharepoint.com/sites/Zarzad\): wyników: 34, ostrzeżenia: 2"
        $text | Should -Match "Dostęp: jan \(https://firma.sharepoint.com/sites/Zarzad\): błąd - Access denied"
        $text | Should -Match "Zmiany:"
        $text | Should -Match "jan@firma.pl: wykonano - Edycja"
        $text | Should -Match "Razem: zmian: 1, sprawdzeń: 2\."
        $text.IndexOf('Sprawdzenia:') | Should -BeLessThan $text.IndexOf('Nadanie uprawnień:')
    }
    It "powtórzone sprawdzenie zastępuje poprzedni wpis; filtr po rodzaju" {
        Add-HTOperationRecord -Kind Check -Operation "Kosz witryny" -Object "https://x" -Details "wyników: 1"
        Add-HTOperationRecord -Kind Check -Operation "Kosz witryny" -Object "https://x" -Details "wyników: 5"
        Add-HTOperationRecord -Operation "Przywrócenie z kosza" -Object "plik.docx"
        @(Get-HTOperationRecords -Kind Check).Count | Should -Be 1
        @(Get-HTOperationRecords -Kind Check)[0].Details | Should -Be "wyników: 5"
        @(Get-HTOperationRecords -Kind Change).Count | Should -Be 1
        @(Get-HTOperationRecords).Count | Should -Be 2
    }
    It "same sprawdzenia: sekcja zmian z informacją o braku zmian" {
        Add-HTOperationRecord -Kind Check -Operation "Licencje" -Details "wyników: 3"
        $text = Format-HTOperationSummary -Records @(Get-HTOperationRecords)
        $text | Should -Match "brak zmian"
        $text | Should -Match "Razem: zmian: 0, sprawdzeń: 1\."
    }
}

Describe "Zadania zaplanowane" {
    BeforeEach {
        $Global:ConfigDir = Join-Path $TestDrive ("jobs_" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $Global:ConfigDir -Force | Out-Null
        $Global:ConnectedToGraphAPI = $false
        $Global:ConnectedToExchange = $false
    }

    It "zapisuje zadanie i zwraca je jako zaległe po terminie" {
        $job = New-HTScheduledJob -Type "RemoveGroupMember" -RunAt (Get-Date).AddHours(1) -Object "jan → Projekt" -Data @{ GroupId = "g1"; GroupName = "Projekt"; UserId = "u1"; UserLabel = "jan" }
        @(Get-HTJobs -Pending).Count | Should -Be 1
        @(Get-HTDueJobs).Count | Should -Be 0
        @(Get-HTDueJobs -Now (Get-Date).AddHours(2)).Count | Should -Be 1
        @(Get-HTJobs)[0].Data.GroupName | Should -Be "Projekt"
        Update-HTJob -Id $job.Id -Changes @{ Status = "Anulowane" }
        @(Get-HTJobs -Pending).Count | Should -Be 0
        Remove-HTJob -Id $job.Id
        @(Get-HTJobs).Count | Should -Be 0
    }
    It "zadanie bez połączenia czeka (Oczekuje na połączenie)" {
        [void](New-HTScheduledJob -Type "RemoveMailboxPermission" -RunAt (Get-Date).AddMinutes(-5) -Object "anna → biuro" -Data @{ Identity = "biuro@firma.pl"; User = "anna@firma.pl"; Type = @("FullAccess") })
        @(Get-HTJobMissingServices -Job @(Get-HTJobs)[0]) | Should -Contain "Exchange"
        $r = @(Invoke-HTDueJobs)
        $r[0].Status | Should -Be "Oczekuje"
        @(Get-HTJobs)[0].Status | Should -Be "Oczekuje na połączenie"
    }
    It "wykonuje zaległe zadanie i zapisuje wynik" {
        function global:Invoke-HTGraphRequest { param($Uri, $Method, $Body) $Global:HTTestCalls += "$Method $Uri" }
        $Global:HTTestCalls = @()
        $Global:ConnectedToGraphAPI = $true
        [void](New-HTScheduledJob -Type "RemoveGroupMember" -RunAt (Get-Date).AddMinutes(-1) -Object "jan → Projekt" -Data @{ GroupId = "g1"; GroupName = "Projekt"; UserId = "u1"; UserLabel = "jan" })
        $r = @(Invoke-HTDueJobs)
        $r[0].Status | Should -Be "OK"
        $Global:HTTestCalls[0] | Should -Be 'DELETE groups/g1/members/u1/$ref'
        @(Get-HTJobs)[0].Status | Should -Be "Wykonane"
        Remove-Item -LiteralPath Function:Invoke-HTGraphRequest
    }
    It "nie przyjmuje nieznanego typu" {
        { New-HTScheduledJob -Type "Nieznany" -RunAt (Get-Date) } | Should -Throw
    }
}

Describe "Zaplanowany offboarding - kopia ustawień konta" {
    BeforeAll {
        function global:Get-HTM365AccountBackup { param($Id) $Global:HTTestCalls += "backup $Id"; [ordered]@{ User = [ordered]@{ Id = $Id; UserPrincipalName = 'jan@firma.pl' }; Mailbox = $null } }
        function global:Save-HTAccountBackup { param($Backup) if ($Global:HTTestBackupFails) { throw 'brak dostępu do folderu' }; $Global:HTTestCalls += 'save'; 'C:\Kopie kont\Kopia_jan.json' }
        function global:Set-HTM365UserEnabled { param($Id, $Enabled, $RevokeSessions) $Global:HTTestCalls += "block $Id" }
        $Global:HTTestJob = [PSCustomObject]@{ Type = 'Offboarding'; Data = @{ UserId = 'u-1'; Label = 'jan@firma.pl'; Steps = @{ Backup = $true; Block = $true } } }
    }
    AfterAll {
        foreach ($n in 'Get-HTM365AccountBackup', 'Save-HTAccountBackup', 'Set-HTM365UserEnabled') { Remove-Item -LiteralPath "Function:$n" -ErrorAction SilentlyContinue }
        Remove-Variable -Name HTTestBackupFails, HTTestJob -Scope Global -ErrorAction SilentlyContinue
    }
    It "zapisuje kopię przed zmianami" {
        $Global:HTTestCalls = @()
        $Global:HTTestBackupFails = $false
        $Global:ConnectedToExchange = $false
        Invoke-HTJob -Job $Global:HTTestJob | Should -Be 'kopia ustawień (C:\Kopie kont\Kopia_jan.json), blokada i wylogowanie'
        $Global:HTTestCalls | Should -Be @('backup u-1', 'save', 'block u-1')
    }
    It "bez kopii nie zmienia konta (zadanie kończy się błędem)" {
        $Global:HTTestCalls = @()
        $Global:HTTestBackupFails = $true
        { Invoke-HTJob -Job $Global:HTTestJob } | Should -Throw '*konto bez zmian*'
        $Global:HTTestCalls | Should -Not -Contain 'block u-1'
    }
    It "przekierowanie poczty wymaga połączenia z Exchange w terminie" {
        $Global:ConnectedToGraphAPI = $true
        $Global:ConnectedToExchange = $false
        @(Get-HTJobMissingServices -Job ([PSCustomObject]@{ Type = 'Offboarding'; Data = @{ Steps = @{ Forward = 'szef@firma.pl' } } })) | Should -Be @('Exchange')
        @(Get-HTJobMissingServices -Job ([PSCustomObject]@{ Type = 'Offboarding'; Data = @{ Steps = @{ Block = $true } } })).Count | Should -Be 0
    }
}

Describe "Checklisty" {
    BeforeEach {
        $Global:ConfigDir = Join-Path $TestDrive ("cl_" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $Global:ConfigDir -Force | Out-Null
    }

    It "ma domyślne szablony onboardingu i offboardingu" {
        $t = @(Get-HTChecklistTemplates)
        $t.Count | Should -Be 2
        @($t | Where-Object { $_.Kind -eq "Offboarding" })[0].Steps.Count | Should -BeGreaterThan 5
    }
    It "zamienia tekst kroków na szablon i z powrotem" {
        $steps = @(ConvertFrom-HTChecklistText -Text "[auto:Block] Blokada`r`nZwrot laptopa`r`n`r`n[auto:Nieznany] Coś")
        $steps.Count | Should -Be 3
        $steps[0].Auto | Should -Be "Block"
        $steps[1].Auto | Should -Be ""
        $steps[2].Auto | Should -Be ""
        $steps[2].Text | Should -Be "Coś"
        ConvertTo-HTChecklistText -Steps $steps[0..1] | Should -Be "[auto:Block] Blokada`r`nZwrot laptopa"
    }
    It "liczy postęp i zamyka checklistę po ostatnim kroku" {
        $tpl = @{ Name = "Test"; Kind = "Inne"; Steps = @(@{ Text = "A"; Auto = "" }, @{ Text = "B"; Auto = "" }) }
        $c = New-HTChecklist -Template $tpl -Subject "jan@firma.pl"
        Set-HTChecklistStep -Id $c.Id -Index 0 -Done $true | Should -BeFalse
        (Get-HTChecklistProgress -Checklist @(Get-HTChecklists)[0]).Percent | Should -Be 50
        Set-HTChecklistStep -Id $c.Id -Index 1 -Done $true -Note "ok" | Should -BeTrue
        @(Get-HTChecklists -Open).Count | Should -Be 0
        Set-HTChecklistStep -Id $c.Id -Index 1 -Done $false | Should -BeFalse
        @(Get-HTChecklists -Open).Count | Should -Be 1
        Remove-HTChecklist -Id $c.Id
        @(Get-HTChecklists).Count | Should -Be 0
    }
}

Describe "Porównanie migawek" {
    It "wykrywa dodane, usunięte i zmienione rekordy" {
        $old = @(
            [ordered]@{ Key = "GA|jan"; Rola = "Global Administrator"; Czas = "stałe" }
            [ordered]@{ Key = "UA|anna"; Rola = "User Administrator"; Czas = "stałe" }
        )
        $new = @(
            [ordered]@{ Key = "GA|jan"; Rola = "Global Administrator"; Czas = "czasowe" }
            [ordered]@{ Key = "EA|piotr"; Rola = "Exchange Administrator"; Czas = "stałe" }
        )
        $diff = @(Compare-HTSnapshot -Old $old -New $new)
        $diff.Count | Should -Be 3
        @($diff | Where-Object { $_.Zmiana -eq "Dodano" })[0].Obiekt | Should -Be "EA|piotr"
        @($diff | Where-Object { $_.Zmiana -eq "Usunięto" })[0].Obiekt | Should -Be "UA|anna"
        @($diff | Where-Object { $_.Zmiana -eq "Zmieniono" })[0].Szczegóły | Should -Be "Czas: stałe → czasowe"
    }
    It "bez zmian zwraca pustą listę" {
        $r = @([ordered]@{ Key = "a"; X = 1 })
        @(Compare-HTSnapshot -Old $r -New $r).Count | Should -Be 0
    }
}

Describe "Cofanie zmian" {
    BeforeEach {
        $Global:ConfigDir = Join-Path $TestDrive ("undo_" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $Global:ConfigDir -Force | Out-Null
        Clear-HTOperationRecords
    }

    It "rejestruje zmianę i cofa ją raz" {
        function global:Set-HTEntraDeviceEnabled { param($Id, $Enabled) $Global:HTTestUndo = "$Id=$Enabled" }
        Register-HTUndo -Operation "Wyłączenie urządzenia Entra ID" -Object "PC-01" -Kind "EntraDevice" -Data @{ Id = "dev1" }
        $rec = @(Get-HTUndoRecords)[0]
        $rec.Object | Should -Be "PC-01"
        Invoke-HTUndo -Id $rec.Id | Should -Be "Włączono urządzenie"
        $Global:HTTestUndo | Should -Be "dev1=True"
        @(Get-HTUndoRecords)[0].Undone | Should -Not -BeNullOrEmpty
        { Invoke-HTUndo -Id $rec.Id } | Should -Throw
        @(Get-HTOperationRecords -Object "PC-01").Count | Should -Be 1
        Remove-Item -LiteralPath Function:Set-HTEntraDeviceEnabled
    }
    It "nie przyjmuje nieznanego rodzaju" {
        { Register-HTUndo -Operation "x" -Kind "Nieznany" } | Should -Throw
    }
}

Describe "Raporty bez okna" {
    It "katalog raportów ma tytuły i usługi" {
        $reports = Get-HTHeadlessReports
        $reports.Count | Should -BeGreaterThan 5
        foreach ($k in $reports.Keys) { $reports[$k].Service | Should -BeIn @("Graph", "Exchange") }
    }
}
