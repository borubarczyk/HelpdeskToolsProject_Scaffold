BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    Import-HTTestModule -Name "Utils", "ColumnFilters", "Reports"

    function New-TestModule {
        # Tabela jak w widoku modułu: kolumny pomocnicze (w tym __cf) i dane
        $t = New-Object System.Data.DataTable
        foreach ($c in "__search", "__flag", "__cf") { [void]$t.Columns.Add($c, [string]) }
        foreach ($c in "Nazwa", "Rozmiar", "Typ") { [void]$t.Columns.Add($c, [object]) }
        foreach ($d in @(@("Anna", 10, "Shared"), @("Bartek", 2, "User"), @("Celina", 100, "User"), @("Darek", [DBNull]::Value, "Room"), @("Ewa", 25, "Shared"))) {
            $r = $t.NewRow(); $r["Nazwa"] = $d[0]; $r["Rozmiar"] = $d[1]; $r["Typ"] = $d[2]; $t.Rows.Add($r)
        }
        return @{ Table = $t; ColumnFilters = [ordered]@{}; View = [System.Data.DataView]::new($t) }
    }

    function Get-Visible([hashtable]$Module) {
        Update-HTColumnFilterFlags -Module $Module
        $Module.View.RowFilter = $(if ($Module.ColumnFilters.Count) { "[__cf] = '1'" } else { "" })
        return @($Module.View | ForEach-Object { $_["Nazwa"] })
    }
}

Describe "Warunki filtra kolumny" {
    It "<Op> «<Arg>» dla «<Text>» = <Expected>" -TestCases @(
        @{ Text = "Łódź"; Op = "contains"; Arg = "łó"; Expected = $true }
        @{ Text = "Łódź"; Op = "notcontains"; Arg = "x"; Expected = $true }
        @{ Text = " abc "; Op = "eq"; Arg = "ABC"; Expected = $true }
        @{ Text = "abc"; Op = "ne"; Arg = "abc"; Expected = $false }
        @{ Text = "jan.kowalski@firma.pl"; Op = "starts"; Arg = "JAN"; Expected = $true }
        @{ Text = "jan.kowalski@firma.pl"; Op = "ends"; Arg = "@firma.pl"; Expected = $true }
        @{ Text = "100"; Op = "gt"; Arg = "9,5"; Expected = $true }
        @{ Text = "2026-01-05"; Op = "lt"; Arg = "2026-02-01"; Expected = $true }
        @{ Text = ""; Op = "gt"; Arg = "0"; Expected = $false }
        @{ Text = "  "; Op = "empty"; Arg = ""; Expected = $true }
        @{ Text = "x"; Op = "notempty"; Arg = ""; Expected = $true }
        @{ Text = "x"; Op = "contains"; Arg = ""; Expected = $true }
    ) {
        param($Text, $Op, $Arg, $Expected)
        Test-HTFilterCondition -Text $Text -Op $Op -Arg $Arg | Should -Be $Expected
    }
    It "zna polskie nazwy warunków" {
        (Get-HTFilterOps)["większe niż"] | Should -Be "gt"
        Get-HTFilterOpLabel "notempty" | Should -Be "niepuste"
    }
}

Describe "Filtry kolumn tabeli" {
    It "filtruje po wybranych wartościach i warunku w kilku kolumnach" {
        $m = New-TestModule
        Set-HTColumnFilterEntry -Module $m -Column "Typ" -Values @("User", "Shared") | Should -BeTrue
        Get-Visible $m | Should -Be @("Anna", "Bartek", "Celina", "Ewa")
        Set-HTColumnFilterEntry -Module $m -Column "Rozmiar" -Op "gt" -Text "9,5" | Should -BeTrue
        Get-Visible $m | Should -Be @("Anna", "Celina", "Ewa")
        Test-HTRowColumnFilters -Module $m -Row $m.Table.Rows[1] | Should -BeFalse
    }
    It "pusta lista wartości ukrywa wszystkie wiersze, brak wartości i warunku usuwa filtr" {
        $m = New-TestModule
        Set-HTColumnFilterEntry -Module $m -Column "Typ" -Values @() | Should -BeTrue
        @(Get-Visible $m).Count | Should -Be 0
        Set-HTColumnFilterEntry -Module $m -Column "Typ" | Should -BeFalse
        $m.ColumnFilters.Count | Should -Be 0
        Set-HTColumnFilterEntry -Module $m -Column "Typ" -Op "contains" -Text "" | Should -BeFalse
    }
    It "warunek «puste» znajduje komórki bez wartości" {
        $m = New-TestModule
        [void](Set-HTColumnFilterEntry -Module $m -Column "Rozmiar" -Op "empty")
        Get-Visible $m | Should -Be @("Darek")
    }
    It "liczy wartości kolumny z uwzględnieniem filtrów innych kolumn (liczby rosnąco, puste na końcu)" {
        $m = New-TestModule
        @(Get-HTColumnValueCounts -Module $m -Column "Rozmiar" | ForEach-Object { $_.Text }) | Should -Be @("2", "10", "25", "100", "")
        [void](Set-HTColumnFilterEntry -Module $m -Column "Typ" -Values @("Shared"))
        $counts = @(Get-HTColumnValueCounts -Module $m -Column "Rozmiar")
        @($counts | ForEach-Object { $_.Text }) | Should -Be @("10", "25")
        $typ = @(Get-HTColumnValueCounts -Module $m -Column "Typ")
        ($typ | Where-Object { $_.Text -eq "User" }).Count | Should -Be 2
    }
    It "opisuje filtry kolumn" {
        $m = New-TestModule
        [void](Set-HTColumnFilterEntry -Module $m -Column "Typ" -Values @("User", "Shared"))
        [void](Set-HTColumnFilterEntry -Module $m -Column "Rozmiar" -Op "gt" -Text "9,5")
        Get-HTColumnFiltersText -Module $m | Should -Be "Typ: Shared, User • Rozmiar: większe niż «9,5»"
    }
    It "ustawia flagę nowego wiersza" {
        $m = New-TestModule
        [void](Set-HTColumnFilterEntry -Module $m -Column "Typ" -Values @("User"))
        $r = $m.Table.NewRow(); $r["Nazwa"] = "Filip"; $r["Typ"] = "User"; $m.Table.Rows.Add($r)
        Set-HTRowFilterFlag -Module $m -Row $r
        $r["__cf"] | Should -Be "1"
    }
}

Describe "Raport HTML" {
    It "koduje znaki specjalne i koloruje wiersze" {
        $html = ConvertTo-HTHtmlReport -Title "Raport <test>" -Columns "Nazwa", "Typ" -Rows @(@{ Nazwa = "A&B"; Typ = "x"; __flag = "crit" }, [ordered]@{ Nazwa = "C" }) -Meta "Meta" -Tiles @(@{ Label = "Wiersze"; Value = 2; Tone = "ok" })
        $html | Should -Match "<title>Raport &lt;test&gt;</title>"
        $html | Should -Match '<tr class="crit"><td>A&amp;B</td><td>x</td></tr>'
        $html | Should -Match '<tr><td>C</td><td></td></tr>'
        $html | Should -Match '<div class="tile ok"><b>2</b><span>Wiersze</span></div>'
        $html | Should -Match 'data-count-for="t1">2<'
        $html | Should -Match "</script></body></html>$"
    }
    It "ConvertTo-HTHtmlText zostawia polskie litery" {
        ConvertTo-HTHtmlText 'Zażółć "gęślą" <jaźń>' | Should -Be 'Zażółć &quot;gęślą&quot; &lt;jaźń&gt;'
        ConvertTo-HTHtmlText $null | Should -Be ''
    }
}
