# Eksport tabel do Excela (.xlsx) bez dodatkowych modułów: arkusz OpenXML zapisany w archiwum ZIP.
# Nagłówek pogrubiony na niebieskim tle, autofiltr, zamrożony pierwszy wiersz, szerokości kolumn według zawartości,
# liczby jako liczby, kolorowanie wierszy (__flag: crit / warn / muted) i opcjonalny arkusz «Informacje».

Add-Type -AssemblyName System.IO.Compression

function Get-HTXlsxColumnName {
    # 1 -> A, 26 -> Z, 27 -> AA
    param ([Parameter(Mandatory)][int]$Index)
    $name = ''
    $n = $Index
    while ($n -gt 0) {
        $r = ($n - 1) % 26
        $name = [char](65 + $r) + $name
        $n = [int][Math]::Floor(($n - 1) / 26)
    }
    return $name
}

function ConvertTo-HTXmlCellText {
    # Tekst do XML: bez znaków sterujących niedozwolonych w XML 1.0, z encjami
    param ([AllowNull()][object]$Value)
    if ($null -eq $Value -or $Value -is [System.DBNull]) { return '' }
    $text = [string]$Value
    $text = [regex]::Replace($text, '[\x00-\x08\x0B\x0C\x0E-\x1F]', '')
    if ($text.Length -gt 32767) { $text = $text.Substring(0, 32767) }
    return [System.Security.SecurityElement]::Escape($text)
}

function Get-HTXlsxSheetName {
    param ([AllowEmptyString()][string]$Name)
    $clean = ($Name -replace '[\[\]\:\*\?\/\\]', ' ').Trim()
    if (-not $clean) { $clean = 'Dane' }
    if ($clean.Length -gt 31) { $clean = $clean.Substring(0, 31) }
    return $clean
}

function Test-HTXlsxNumber {
    param ($Value)
    return ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal] -or $Value -is [single] -or $Value -is [int16] -or $Value -is [byte])
}

function New-HTXlsxSheetXml {
    param ([string[]]$Columns, [object[]]$Rows, [switch]$Info)
    $sb = New-Object System.Text.StringBuilder
    $widths = @{}
    for ($c = 0; $c -lt $Columns.Count; $c++) { $widths[$c] = [Math]::Max(8, $Columns[$c].Length + 4) }
    foreach ($r in $Rows) {
        for ($c = 0; $c -lt $Columns.Count; $c++) {
            $len = ([string]$r[$Columns[$c]]).Length
            if ($len + 2 -gt $widths[$c]) { $widths[$c] = [Math]::Min(70, $len + 2) }
        }
    }
    $last = Get-HTXlsxColumnName $Columns.Count
    [void]$sb.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    [void]$sb.Append('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">')
    if (-not $Info) {
        [void]$sb.Append('<sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>')
    }
    [void]$sb.Append('<cols>')
    for ($c = 0; $c -lt $Columns.Count; $c++) {
        $w = [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:0.##}', [double]$widths[$c])
        [void]$sb.Append("<col min=`"$($c + 1)`" max=`"$($c + 1)`" width=`"$w`" customWidth=`"1`"/>")
    }
    [void]$sb.Append('</cols><sheetData>')
    # Nagłówek
    [void]$sb.Append('<row r="1">')
    for ($c = 0; $c -lt $Columns.Count; $c++) {
        $ref = (Get-HTXlsxColumnName ($c + 1)) + '1'
        [void]$sb.Append("<c r=`"$ref`" t=`"inlineStr`" s=`"1`"><is><t xml:space=`"preserve`">$(ConvertTo-HTXmlCellText $Columns[$c])</t></is></c>")
    }
    [void]$sb.Append('</row>')
    $rowIndex = 1
    foreach ($r in $Rows) {
        $rowIndex++
        $flag = [string]$r['__flag']
        $style = switch ($flag) { 'crit' { 3 } 'warn' { 4 } 'muted' { 5 } default { 2 } }
        [void]$sb.Append("<row r=`"$rowIndex`">")
        for ($c = 0; $c -lt $Columns.Count; $c++) {
            $ref = (Get-HTXlsxColumnName ($c + 1)) + $rowIndex
            $v = $r[$Columns[$c]]
            if ($v -is [System.Management.Automation.PSObject]) { $v = $v.PSObject.BaseObject }
            if (Test-HTXlsxNumber $v) {
                $num = ([double]$v).ToString('R', [System.Globalization.CultureInfo]::InvariantCulture)
                [void]$sb.Append("<c r=`"$ref`" s=`"$style`"><v>$num</v></c>")
            }
            elseif ($v -is [bool]) {
                [void]$sb.Append("<c r=`"$ref`" t=`"inlineStr`" s=`"$style`"><is><t>$(if ($v) { 'Tak' } else { 'Nie' })</t></is></c>")
            }
            else {
                $text = ConvertTo-HTXmlCellText $v
                if ($text -eq '') { [void]$sb.Append("<c r=`"$ref`" s=`"$style`"/>") }
                else { [void]$sb.Append("<c r=`"$ref`" t=`"inlineStr`" s=`"$style`"><is><t xml:space=`"preserve`">$text</t></is></c>") }
            }
        }
        [void]$sb.Append('</row>')
    }
    [void]$sb.Append('</sheetData>')
    if (-not $Info -and $Rows.Count -gt 0) { [void]$sb.Append("<autoFilter ref=`"A1:$last$rowIndex`"/>") }
    [void]$sb.Append('<pageMargins left="0.5" right="0.5" top="0.75" bottom="0.75" header="0.3" footer="0.3"/></worksheet>')
    return $sb.ToString()
}

$script:XlsxStyles = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<fonts count="3"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font><font><sz val="11"/><color rgb="FF7B8496"/><name val="Calibri"/></font></fonts>
<fills count="5"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FF3E6FE0"/><bgColor indexed="64"/></patternFill></fill><fill><patternFill patternType="solid"><fgColor rgb="FFFDE2E4"/><bgColor indexed="64"/></patternFill></fill><fill><patternFill patternType="solid"><fgColor rgb="FFFFF4D6"/><bgColor indexed="64"/></patternFill></fill></fills>
<borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border><border><left style="thin"><color rgb="FFD9DEE7"/></left><right style="thin"><color rgb="FFD9DEE7"/></right><top style="thin"><color rgb="FFD9DEE7"/></top><bottom style="thin"><color rgb="FFD9DEE7"/></bottom><diagonal/></border></borders>
<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
<cellXfs count="6"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/><xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1" applyAlignment="1"><alignment vertical="top" wrapText="0"/></xf><xf numFmtId="0" fontId="0" fillId="3" borderId="1" xfId="0" applyFill="1" applyBorder="1"/><xf numFmtId="0" fontId="0" fillId="4" borderId="1" xfId="0" applyFill="1" applyBorder="1"/><xf numFmtId="0" fontId="2" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1"/></cellXfs>
<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
</styleSheet>
'@

function Export-HTXlsx {
    <#
        Zapisuje wiersze (słowniki kolumna -> wartość, opcjonalnie __flag) do pliku .xlsx.
        -Meta: dodatkowy arkusz «Informacje» (np. moduł, data, filtry) - @{ Nazwa = Wartość }.
    #>
    param (
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string[]]$Columns,
        [AllowEmptyCollection()][object[]]$Rows = @(),
        [string]$SheetName = 'Dane',
        [System.Collections.IDictionary]$Meta
    )
    $sheets = New-Object System.Collections.Generic.List[object]
    $sheets.Add(@{ Name = (Get-HTXlsxSheetName $SheetName); Xml = (New-HTXlsxSheetXml -Columns $Columns -Rows @($Rows)) })
    if ($Meta -and $Meta.Count) {
        $infoRows = foreach ($k in $Meta.Keys) { @{ Pole = [string]$k; Wartość = [string]$Meta[$k] } }
        $sheets.Add(@{ Name = 'Informacje'; Xml = (New-HTXlsxSheetXml -Columns @('Pole', 'Wartość') -Rows @($infoRows) -Info) })
    }
    $files = [ordered]@{}
    $overrides = New-Object System.Text.StringBuilder
    $sheetEntries = New-Object System.Text.StringBuilder
    $rels = New-Object System.Text.StringBuilder
    for ($i = 0; $i -lt $sheets.Count; $i++) {
        $n = $i + 1
        $files["xl/worksheets/sheet$n.xml"] = $sheets[$i].Xml
        [void]$overrides.Append("<Override PartName=`"/xl/worksheets/sheet$n.xml`" ContentType=`"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml`"/>")
        [void]$sheetEntries.Append("<sheet name=`"$(ConvertTo-HTXmlCellText $sheets[$i].Name)`" sheetId=`"$n`" r:id=`"rId$n`"/>")
        [void]$rels.Append("<Relationship Id=`"rId$n`" Type=`"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet`" Target=`"worksheets/sheet$n.xml`"/>")
    }
    $styleId = $sheets.Count + 1
    [void]$rels.Append("<Relationship Id=`"rId$styleId`" Type=`"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles`" Target=`"styles.xml`"/>")
    $definedName = ''
    if (@($Rows).Count -gt 0) {
        $last = Get-HTXlsxColumnName $Columns.Count
        $sheetRef = "'" + $sheets[0].Name.Replace("'", "''") + "'"
        $definedName = "<definedNames><definedName name=`"_xlnm._FilterDatabase`" localSheetId=`"0`" hidden=`"1`">$(ConvertTo-HTXmlCellText $sheetRef)!`$A`$1:`$$last`$$(@($Rows).Count + 1)</definedName></definedNames>"
    }
    $files['[Content_Types].xml'] = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>' + $overrides.ToString() + '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/><Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/></Types>'
    $files['_rels/.rels'] = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/></Relationships>'
    $files['xl/workbook.xml'] = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><bookViews><workbookView/></bookViews><sheets>' + $sheetEntries.ToString() + '</sheets>' + $definedName + '</workbook>'
    $files['xl/_rels/workbook.xml.rels'] = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' + $rels.ToString() + '</Relationships>'
    $files['xl/styles.xml'] = $script:XlsxStyles.Trim()
    $created = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $files['docProps/core.xml'] = "<?xml version=`"1.0`" encoding=`"UTF-8`" standalone=`"yes`"?><cp:coreProperties xmlns:cp=`"http://schemas.openxmlformats.org/package/2006/metadata/core-properties`" xmlns:dc=`"http://purl.org/dc/elements/1.1/`" xmlns:dcterms=`"http://purl.org/dc/terms/`" xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`"><dc:title>$(ConvertTo-HTXmlCellText $SheetName)</dc:title><dc:creator>Helpdesk Tools</dc:creator><dcterms:created xsi:type=`"dcterms:W3CDTF`">$created</dcterms:created></cp:coreProperties>"
    $files['docProps/app.xml'] = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"><Application>Helpdesk Tools</Application></Properties>'

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Force }
    $encoding = New-Object System.Text.UTF8Encoding($false)
    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::CreateNew)
    try {
        $zip = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Create, $false)
        try {
            foreach ($name in $files.Keys) {
                $entry = $zip.CreateEntry($name, [System.IO.Compression.CompressionLevel]::Optimal)
                $writer = New-Object System.IO.StreamWriter($entry.Open(), $encoding)
                try { $writer.Write($files[$name]) } finally { $writer.Dispose() }
            }
        }
        finally { $zip.Dispose() }
    }
    finally { $stream.Dispose() }
    return $Path
}
