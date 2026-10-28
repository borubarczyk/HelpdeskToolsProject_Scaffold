BeforeAll {
    . (Join-Path $PSScriptRoot "TestHelpers.ps1")
    Import-HTTestModule -Name "Utils", "Excel"
    Initialize-HTTestEnvironment -Root $TestDrive
    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
    function Read-HTTestZipEntry([string]$Path, [string]$Entry) {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
        try {
            $e = $zip.GetEntry($Entry)
            if (-not $e) { return $null }
            $reader = New-Object System.IO.StreamReader($e.Open())
            try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
        }
        finally { $zip.Dispose() }
    }
}

Describe "Get-HTXlsxColumnName" {
    It "zamienia numer kolumny <N> na <Expected>" -TestCases @(
        @{ N = 1; Expected = "A" }
        @{ N = 26; Expected = "Z" }
        @{ N = 28; Expected = "AB" }
        @{ N = 703; Expected = "AAA" }
    ) {
        param($N, $Expected)
        Get-HTXlsxColumnName $N | Should -Be $Expected
    }
}

Describe "Export-HTXlsx" {
    It "zapisuje skoroszyt z nagłówkiem, wartościami, filtrem i arkuszem informacji" {
        $path = Join-Path $TestDrive "test.xlsx"
        $rows = @(
            [ordered]@{ Nazwa = "Jan <Kowalski> & syn"; Liczba = 42; Aktywne = $true; __flag = "crit" }
            [ordered]@{ Nazwa = "Anna"; Liczba = 3.5; Aktywne = $false; __flag = "" }
        )
        Export-HTXlsx -Path $path -Columns @("Nazwa", "Liczba", "Aktywne") -Rows $rows -SheetName "Raport: test/1" -Meta ([ordered]@{ Moduł = "Test" }) | Out-Null
        Test-Path $path | Should -BeTrue
        $sheet = Read-HTTestZipEntry $path "xl/worksheets/sheet1.xml"
        $sheet | Should -Match "Jan &lt;Kowalski&gt; &amp; syn"
        $sheet | Should -Match "<v>42</v>"
        $sheet | Should -Match 'autoFilter ref="A1:C3"'
        $sheet | Should -Match "Tak"
        $workbook = Read-HTTestZipEntry $path "xl/workbook.xml"
        $workbook | Should -Not -Match "Raport: test/1"
        $workbook | Should -Match "Informacje"
        Read-HTTestZipEntry $path "xl/worksheets/sheet2.xml" | Should -Match "Moduł"
    }
    It "zapisuje pusty raport z samym nagłówkiem" {
        $path = Join-Path $TestDrive "empty.xlsx"
        Export-HTXlsx -Path $path -Columns @("A") -Rows @() | Out-Null
        Read-HTTestZipEntry $path "xl/worksheets/sheet1.xml" | Should -Match "<sheetData>"
    }
}
