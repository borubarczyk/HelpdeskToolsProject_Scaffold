# Filtry kolumn tabeli wyników (jak autofiltr w Excelu) - logika bez interfejsu, jak w Domain Ops.
# $Module.ColumnFilters: kolumna -> @{ Values = HashSet[string] (wybrane wartości) albo $null; Op = warunek; Text = argument }.
# Wynik oceny wszystkich filtrów kolumn trafia do ukrytej kolumny __cf ('1' = wiersz pasuje), a filtr widoku
# (DataView.RowFilter) dokłada warunek [__cf] = '1' - porównania liczb, pustych komórek i tekstu działają więc tak,
# jak widać je w tabeli, a filtr działa razem z polem «Filtruj wyniki». Okienko filtra jest w UIComponents.psm1.

$script:FilterOps = [ordered]@{
    'zawiera'        = 'contains'
    'nie zawiera'    = 'notcontains'
    'równa się'      = 'eq'
    'różne od'       = 'ne'
    'zaczyna się od' = 'starts'
    'kończy się na'  = 'ends'
    'większe niż'    = 'gt'
    'mniejsze niż'   = 'lt'
    'puste'          = 'empty'
    'niepuste'       = 'notempty'
}

function Get-HTFilterOps { return $script:FilterOps }

function Get-HTFilterText($Value) {
    # Tekst wartości komórki do porównań (jak w tabeli: liczby bez formatowania regionalnego, puste = '')
    if ($null -eq $Value -or $Value -is [System.DBNull]) { return '' }
    return [string]$Value
}

function Get-HTFilterOpLabel([string]$Op) {
    foreach ($k in $script:FilterOps.Keys) { if ($script:FilterOps[$k] -eq $Op) { return $k } }
    return $Op
}

function ConvertTo-HTFilterNumber([string]$Text, [ref]$Number) {
    $t = $Text.Trim().Replace(' ', '').Replace(',', '.')
    if ($t -eq '') { return $false }
    $n = 0.0
    if ([double]::TryParse($t, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$n)) { $Number.Value = $n; return $true }
    return $false
}

function Test-HTFilterCondition {
    # Warunek tekstowy filtra kolumny (bez rozróżniania wielkości liter; większe/mniejsze - liczbowo, gdy obie strony są liczbami)
    param([AllowEmptyString()][string]$Text, [string]$Op, [AllowEmptyString()][string]$Arg)
    if ($Op -eq 'empty') { return ($Text.Trim() -eq '') }
    if ($Op -eq 'notempty') { return ($Text.Trim() -ne '') }
    if ($Arg -eq '') { return $true }
    $ci = [System.Globalization.CultureInfo]::CurrentCulture.CompareInfo
    $ic = [System.Globalization.CompareOptions]::IgnoreCase
    switch ($Op) {
        'contains' { return ($ci.IndexOf($Text, $Arg, $ic) -ge 0) }
        'notcontains' { return ($ci.IndexOf($Text, $Arg, $ic) -lt 0) }
        'eq' { return ($ci.Compare($Text.Trim(), $Arg.Trim(), $ic) -eq 0) }
        'ne' { return ($ci.Compare($Text.Trim(), $Arg.Trim(), $ic) -ne 0) }
        'starts' { return $ci.IsPrefix($Text, $Arg, $ic) }
        'ends' { return $ci.IsSuffix($Text.TrimEnd(), $Arg, $ic) }
    }
    if ($Op -eq 'gt' -or $Op -eq 'lt') {
        if ($Text.Trim() -eq '') { return $false }
        $a = 0.0
        $b = 0.0
        if ((ConvertTo-HTFilterNumber $Text ([ref]$a)) -and (ConvertTo-HTFilterNumber $Arg ([ref]$b))) { $c = $a.CompareTo($b) }
        else { $c = [string]::Compare($Text.Trim(), $Arg.Trim(), [StringComparison]::OrdinalIgnoreCase) }
        if ($Op -eq 'gt') { return ($c -gt 0) }
        return ($c -lt 0)
    }
    return $true
}

function Get-HTFilterPassSet {
    # Teksty spełniające warunek - liczone raz dla każdej różnej wartości kolumny (a nie dla każdego wiersza)
    param($Texts, [string]$Op, [AllowEmptyString()][string]$Arg)
    $pass = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($x in $Texts) { if (Test-HTFilterCondition -Text $x -Op $Op -Arg $Arg) { [void]$pass.Add($x) } }
    return , $pass
}

function Get-HTCompiledColumnFilters {
    # Filtry kolumn do szybkiej oceny wielu wierszy: dla każdej kolumny jeden zbiór dozwolonych tekstów
    # (wybrane wartości ∩ wartości spełniające warunek) - w pętli po wierszach zostaje tylko sprawdzenie zbioru
    param([hashtable]$Module, $Table, [string]$Skip = '')
    $cols = $Table.Columns
    $deleted = [System.Data.DataRowState]::Deleted
    return @(foreach ($col in @($Module.ColumnFilters.Keys)) {
            if ($col -eq $Skip) { continue }
            $f = $Module.ColumnFilters[$col]
            $dc = if ($cols.Contains($col)) { $cols[$col] } else { $null }
            $set = $f.Values
            if ($f.Op) {
                $texts = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
                if ($null -ne $dc) {
                    foreach ($r in $Table.Rows) {
                        if ($r.RowState -eq $deleted) { continue }
                        [void]$texts.Add((Get-HTFilterText $r[$dc]))
                    }
                }
                else { [void]$texts.Add('') }
                $pass = Get-HTFilterPassSet -Texts $texts -Op $f.Op -Arg $f.Text
                if ($null -ne $set) { $pass.IntersectWith($set) }
                $set = $pass
            }
            @{ Column = $dc; Values = $set }
        })
}

function Test-HTRowColumnFilters {
    # Czy wiersz (DataRow) spełnia filtry kolumn; -Skip pomija filtr jednej kolumny
    param([hashtable]$Module, $Row, [string]$Skip = '')
    if ($Row -is [System.Data.DataRowView]) { $Row = $Row.Row }
    $cols = $Row.Table.Columns
    foreach ($col in @($Module.ColumnFilters.Keys)) {
        if ($col -eq $Skip) { continue }
        $f = $Module.ColumnFilters[$col]
        $text = if ($cols.Contains($col)) { Get-HTFilterText $Row[$col] } else { '' }
        if ($null -ne $f.Values -and -not $f.Values.Contains($text)) { return $false }
        if ($f.Op -and -not (Test-HTFilterCondition -Text $text -Op $f.Op -Arg $f.Text)) { return $false }
    }
    return $true
}

function Set-HTRowFilterFlag {
    # Ocena filtrów kolumn dla jednego wiersza (po dodaniu albo zmianie wartości)
    param([hashtable]$Module, $Row)
    if ($Module.ColumnFilters.Count -eq 0) { return }
    if ($Row -is [System.Data.DataRowView]) { $Row = $Row.Row }
    $v = if (Test-HTRowColumnFilters -Module $Module -Row $Row) { '1' } else { '0' }
    if ([string]$Row['__cf'] -ne $v) { $Row['__cf'] = $v }
}

function Update-HTColumnFilterFlags {
    # Ponowna ocena wszystkich wierszy po zmianie filtrów (pętla bez wywołań funkcji - szybko także przy tysiącach wierszy)
    param([hashtable]$Module)
    $t = $Module.Table
    if ($null -eq $t -or $Module.ColumnFilters.Count -eq 0 -or -not $t.Columns.Contains('__cf')) { return }
    $filters = @(Get-HTCompiledColumnFilters -Module $Module -Table $t)
    $cf = $t.Columns['__cf']
    $deleted = [System.Data.DataRowState]::Deleted
    $t.BeginLoadData()
    try {
        foreach ($r in $t.Rows) {
            if ($r.RowState -eq $deleted) { continue }
            $ok = $true
            foreach ($f in $filters) {
                $v = if ($null -ne $f.Column) { $r[$f.Column] } else { $null }
                if (-not $f.Values.Contains($(if ($null -eq $v -or $v -is [System.DBNull]) { '' } else { [string]$v }))) { $ok = $false; break }
            }
            $flag = if ($ok) { '1' } else { '0' }
            if ([string]$r[$cf] -ne $flag) { $r[$cf] = $flag }
        }
    }
    finally { $t.EndLoadData() }
}

function Set-HTColumnFilterEntry {
    # Ustawia (albo usuwa, gdy brak wartości i warunku) filtr kolumny w $Module.ColumnFilters; $true - filtr jest ustawiony
    param([Parameter(Mandatory)][hashtable]$Module, [Parameter(Mandatory)][string]$Column, $Values = $null, [string]$Op = '', [string]$Text = '')
    if ($Op -and $Op -ne 'empty' -and $Op -ne 'notempty' -and $Text -eq '') { $Op = '' }
    $set = $null
    if ($null -ne $Values) {
        $set = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        foreach ($v in @($Values)) { [void]$set.Add([string]$v) }
    }
    if ($null -eq $set -and -not $Op) { [void]$Module.ColumnFilters.Remove($Column); return $false }
    $Module.ColumnFilters[$Column] = @{ Values = $set; Op = $Op; Text = $Text }
    return $true
}

function Get-HTColumnFilterText {
    # Opis filtra kolumny do podpowiedzi, raportu HTML i dziennika
    param([hashtable]$Module, [string]$Column)
    $f = $Module.ColumnFilters[$Column]
    if (-not $f) { return '' }
    $parts = @()
    if ($null -ne $f.Values) {
        $vals = @($f.Values | Sort-Object | ForEach-Object { if ($_ -eq '') { '(puste)' } else { $_ } })
        $shown = @($vals | Select-Object -First 6) -join ', '
        if ($vals.Count -gt 6) { $shown += " … (+$($vals.Count - 6))" }
        $parts += $(if ($vals.Count -eq 0) { 'żadna wartość' } else { $shown })
    }
    if ($f.Op) {
        $label = Get-HTFilterOpLabel $f.Op
        $parts += $(if ($f.Op -eq 'empty' -or $f.Op -eq 'notempty') { $label } else { "$label «$($f.Text)»" })
    }
    return ('{0}: {1}' -f $Column, ($parts -join '; '))
}

function Get-HTColumnFiltersText {
    param([hashtable]$Module)
    return (@($Module.ColumnFilters.Keys | ForEach-Object { Get-HTColumnFilterText -Module $Module -Column $_ }) -join ' • ')
}

function Get-HTColumnValueCounts {
    # Wartości kolumny z liczbą wierszy - z wierszy spełniających filtry pozostałych kolumn.
    # Puste na końcu; liczby rosnąco liczbowo, tekst alfabetycznie (polska kolejność).
    param([hashtable]$Module, [string]$Column)
    $counts = New-Object 'System.Collections.Generic.Dictionary[string,int]' ([StringComparer]::Ordinal)
    $t = $Module.Table
    if ($null -eq $t -or -not $t.Columns.Contains($Column)) { return @() }
    $numeric = $true
    $filters = @(Get-HTCompiledColumnFilters -Module $Module -Table $t -Skip $Column)
    $dc = $t.Columns[$Column]
    $deleted = [System.Data.DataRowState]::Deleted
    foreach ($r in $t.Rows) {
        if ($r.RowState -eq $deleted) { continue }
        if ($filters.Count -gt 0) {
            $ok = $true
            foreach ($f in $filters) {
                $fv = if ($null -ne $f.Column) { $r[$f.Column] } else { $null }
                if (-not $f.Values.Contains($(if ($null -eq $fv -or $fv -is [System.DBNull]) { '' } else { [string]$fv }))) { $ok = $false; break }
            }
            if (-not $ok) { continue }
        }
        $v = $r[$dc]
        if ($null -eq $v -or $v -is [System.DBNull]) { $text = '' }
        else {
            $text = [string]$v
            if ($numeric -and -not ($v -is [System.ValueType])) { $numeric = $false }
        }
        $n = 0
        [void]$counts.TryGetValue($text, [ref]$n)
        $counts[$text] = $n + 1
    }
    $keys = New-Object 'System.Collections.Generic.List[string]'
    foreach ($k in $counts.Keys) { if ($k -ne '') { $keys.Add($k) } }
    $arr = $keys.ToArray()
    if ($numeric) {
        $nums = New-Object 'double[]' $arr.Count
        for ($i = 0; $i -lt $arr.Count; $i++) { $x = 0.0; [void](ConvertTo-HTFilterNumber $arr[$i] ([ref]$x)); $nums[$i] = $x }
        [Array]::Sort($nums, $arr)
    }
    else {
        [Array]::Sort($arr, [StringComparer]::Create([System.Globalization.CultureInfo]::GetCultureInfo('pl-PL'), $true))
    }
    $result = New-Object System.Collections.ArrayList
    foreach ($k in $arr) { [void]$result.Add([pscustomobject]@{ Text = $k; Count = $counts[$k] }) }
    if ($counts.ContainsKey('')) { [void]$result.Add([pscustomobject]@{ Text = ''; Count = $counts[''] }) }
    return $result.ToArray()
}
