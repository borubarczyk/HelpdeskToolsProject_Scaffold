# Kod QR (ISO/IEC 18004) bez zewnętrznych bibliotek: tryb bajtowy (UTF-8), korekcja błędów L lub M, wersje 1-15
# (do ~400 znaków), automatyczny wybór maski. Używany do linku otpauth:// przy włączaniu MFA - aplikacja
# uwierzytelniająca skanuje kod zamiast przepisywania klucza.

#region Tabele
# Bloki korekcji błędów: wersja -> @(kodów korekcji na blok, bloki grupy 1, danych w bloku grupy 1, bloki grupy 2, danych w bloku grupy 2)
$script:QrBlocks = @{
    L = @{
        1 = @(7, 1, 19, 0, 0); 2 = @(10, 1, 34, 0, 0); 3 = @(15, 1, 55, 0, 0); 4 = @(20, 1, 80, 0, 0); 5 = @(26, 1, 108, 0, 0)
        6 = @(18, 2, 68, 0, 0); 7 = @(20, 2, 78, 0, 0); 8 = @(24, 2, 97, 0, 0); 9 = @(30, 2, 116, 0, 0); 10 = @(18, 2, 68, 2, 69)
        11 = @(20, 4, 81, 0, 0); 12 = @(24, 2, 92, 2, 93); 13 = @(26, 4, 107, 0, 0); 14 = @(30, 3, 115, 1, 116); 15 = @(22, 5, 87, 1, 88)
    }
    M = @{
        1 = @(10, 1, 16, 0, 0); 2 = @(16, 1, 28, 0, 0); 3 = @(26, 1, 44, 0, 0); 4 = @(18, 2, 32, 0, 0); 5 = @(24, 2, 43, 0, 0)
        6 = @(16, 4, 27, 0, 0); 7 = @(18, 4, 31, 0, 0); 8 = @(22, 2, 38, 2, 39); 9 = @(22, 3, 36, 2, 37); 10 = @(26, 4, 43, 1, 44)
        11 = @(30, 1, 50, 4, 51); 12 = @(22, 6, 36, 2, 37); 13 = @(22, 8, 37, 1, 38); 14 = @(24, 4, 40, 5, 41); 15 = @(24, 5, 41, 5, 42)
    }
}
# Środki wzorców wyrównania
$script:QrAlignment = @{
    1 = @(); 2 = @(6, 18); 3 = @(6, 22); 4 = @(6, 26); 5 = @(6, 30); 6 = @(6, 34); 7 = @(6, 22, 38); 8 = @(6, 24, 42); 9 = @(6, 26, 46)
    10 = @(6, 28, 50); 11 = @(6, 30, 54); 12 = @(6, 32, 58); 13 = @(6, 34, 62); 14 = @(6, 26, 46, 66); 15 = @(6, 26, 48, 70)
}
$script:QrEccFormatBits = @{ L = 1; M = 0 }
$script:QrMaxVersion = 15

# Logarytmy i potęgi w GF(256) (wielomian 0x11D)
$script:QrExp = New-Object int[] 512
$script:QrLog = New-Object int[] 256
$qrX = 1
for ($qrI = 0; $qrI -lt 255; $qrI++) {
    $script:QrExp[$qrI] = $qrX
    $script:QrLog[$qrX] = $qrI
    $qrX = $qrX -shl 1
    if ($qrX -band 0x100) { $qrX = $qrX -bxor 0x11D }
}
for ($qrI = 255; $qrI -lt 512; $qrI++) { $script:QrExp[$qrI] = $script:QrExp[$qrI - 255] }
Remove-Variable -Name qrX, qrI
#endregion

#region Kodowanie danych
function Get-HTQrCapacity {
    # Liczba bajtów danych (tryb bajtowy) mieszczących się w wersji przy danym poziomie korekcji
    param([Parameter(Mandatory)][int]$Version, [ValidateSet('L', 'M')][string]$Ecc = 'M')
    $b = $script:QrBlocks[$Ecc][$Version]
    $dataCodewords = $b[1] * $b[2] + $b[3] * $b[4]
    $countBits = if ($Version -le 9) { 8 } else { 16 }
    return [Math]::Floor(($dataCodewords * 8 - 4 - $countBits) / 8)
}

function Get-HTQrRsRemainder {
    # Kody korekcji Reed-Solomona dla bloku danych
    param([int[]]$Data, [int]$Degree)
    # Wielomian generatora: iloczyn (x - α^i), i = 0..Degree-1 (współczynniki od najwyższej potęgi, bez wiodącej 1)
    $gen = New-Object int[] $Degree
    $gen[$Degree - 1] = 1
    $root = 1
    for ($i = 0; $i -lt $Degree; $i++) {
        for ($j = 0; $j -lt $Degree; $j++) {
            $gen[$j] = Get-HTQrMultiply $gen[$j] $root
            if ($j + 1 -lt $Degree) { $gen[$j] = $gen[$j] -bxor $gen[$j + 1] }
        }
        $root = Get-HTQrMultiply $root 2
    }
    $result = New-Object int[] $Degree
    foreach ($byte in $Data) {
        $factor = $byte -bxor $result[0]
        for ($k = 0; $k -lt $Degree - 1; $k++) { $result[$k] = $result[$k + 1] }
        $result[$Degree - 1] = 0
        for ($k = 0; $k -lt $Degree; $k++) { $result[$k] = $result[$k] -bxor (Get-HTQrMultiply $gen[$k] $factor) }
    }
    return , $result
}

function Get-HTQrMultiply([int]$A, [int]$B) {
    if ($A -eq 0 -or $B -eq 0) { return 0 }
    return $script:QrExp[$script:QrLog[$A] + $script:QrLog[$B]]
}

function Get-HTQrCodewords {
    # Ciąg kodów (dane + korekcja, przeplecione blokami) dla tekstu w trybie bajtowym
    param([Parameter(Mandatory)][byte[]]$Bytes, [int]$Version, [string]$Ecc)
    $b = $script:QrBlocks[$Ecc][$Version]
    $dataCount = $b[1] * $b[2] + $b[3] * $b[4]
    $bits = New-Object System.Collections.Generic.List[int]
    $append = { param($value, $length) for ($i = $length - 1; $i -ge 0; $i--) { $bits.Add((($value -shr $i) -band 1)) } }
    & $append 4 4
    & $append $Bytes.Length $(if ($Version -le 9) { 8 } else { 16 })
    foreach ($byte in $Bytes) { & $append ([int]$byte) 8 }
    $capacityBits = $dataCount * 8
    & $append 0 ([Math]::Min(4, $capacityBits - $bits.Count))
    while ($bits.Count % 8) { $bits.Add(0) }
    $data = New-Object System.Collections.Generic.List[int]
    for ($i = 0; $i -lt $bits.Count; $i += 8) {
        $v = 0
        for ($j = 0; $j -lt 8; $j++) { $v = ($v -shl 1) -bor $bits[$i + $j] }
        $data.Add($v)
    }
    $pad = 0xEC
    while ($data.Count -lt $dataCount) { $data.Add($pad); $pad = if ($pad -eq 0xEC) { 0x11 } else { 0xEC } }

    # Podział na bloki i korekcja błędów
    $blocks = New-Object System.Collections.Generic.List[object]
    $offset = 0
    foreach ($group in @(@($b[1], $b[2]), @($b[3], $b[4]))) {
        for ($n = 0; $n -lt $group[0]; $n++) {
            $chunk = [int[]]$data.GetRange($offset, $group[1]).ToArray()
            $offset += $group[1]
            $blocks.Add(@{ Data = $chunk; Ecc = (Get-HTQrRsRemainder -Data $chunk -Degree $b[0]) })
        }
    }
    $result = New-Object System.Collections.Generic.List[int]
    $maxData = [Math]::Max($b[2], $b[4])
    for ($i = 0; $i -lt $maxData; $i++) { foreach ($block in $blocks) { if ($i -lt $block.Data.Length) { $result.Add($block.Data[$i]) } } }
    for ($i = 0; $i -lt $b[0]; $i++) { foreach ($block in $blocks) { $result.Add($block.Ecc[$i]) } }
    return , $result.ToArray()
}
#endregion

#region Macierz
function Get-HTQrBchBits([int]$Data, [int]$Width, [int]$Poly) {
    # Bity kontrolne BCH (informacja o formacie i wersji)
    $rem = $Data
    $degree = 0
    $p = $Poly
    while ($p -gt 1) { $p = $p -shr 1; $degree++ }
    for ($i = 0; $i -lt $degree; $i++) { $rem = ($rem -shl 1) -bxor ((($rem -shr ($degree - 1)) -band 1) * $Poly) }
    return (($Data -shl $degree) -bor ($rem -band ((1 -shl $degree) - 1)))
}

function Test-HTQrMask([int]$Mask, [int]$X, [int]$Y) {
    switch ($Mask) {
        0 { return (($X + $Y) % 2 -eq 0) }
        1 { return ($Y % 2 -eq 0) }
        2 { return ($X % 3 -eq 0) }
        3 { return (($X + $Y) % 3 -eq 0) }
        4 { return ((([Math]::Floor($X / 3) + [Math]::Floor($Y / 2)) % 2) -eq 0) }
        5 { return ((($X * $Y) % 2 + ($X * $Y) % 3) -eq 0) }
        6 { return (((($X * $Y) % 2 + ($X * $Y) % 3) % 2) -eq 0) }
        7 { return (((($X + $Y) % 2 + ($X * $Y) % 3) % 2) -eq 0) }
    }
}

function Get-HTQrPenalty {
    <#
        Ocena maski na macierzy zapisanej jako bajty «0»/«1» (wiersze i kolumny - macierz transponowana): serie
        tego samego koloru, wzorce podobne do znaczników położenia i proporcja ciemnych modułów. Reguła bloków 2x2
        jest pominięta (szybkość) - wybór maski wpływa tylko na łatwość skanowania, każdy wybór daje poprawny kod.
    #>
    param([byte[]]$Rows, [byte[]]$Columns, [int]$Size)
    $penalty = 0
    $ascii = [System.Text.Encoding]::ASCII
    foreach ($matrix in $Rows, $Columns) {
        for ($i = 0; $i -lt $Size; $i++) {
            $line = $ascii.GetString($matrix, $i * $Size, $Size)
            foreach ($run in [regex]::Matches($line, '0{5,}|1{5,}')) { $penalty += 3 + ($run.Length - 5) }
            $padded = "0000$($line)0000"
            $penalty += 40 * ([regex]::Matches($padded, '(?=00001011101)').Count + [regex]::Matches($padded, '(?=10111010000)').Count)
        }
    }
    $total = $Size * $Size
    $dark = [regex]::Matches($ascii.GetString($Rows), '1').Count
    $k = [Math]::Floor(([Math]::Abs($dark * 20 - $total * 10) + $total - 1) / $total) - 1
    $penalty += [Math]::Max(0, $k) * 10
    return $penalty
}

function New-HTQrCode {
    <#
        Kod QR dla tekstu (UTF-8). Zwraca @{ Version; Ecc; Mask; Size; Modules } - Modules[wiersz, kolumna] = $true dla
        ciemnego modułu (bez marginesu). -Ecc M (domyślnie, 15% odporności), przy dłuższym tekście L; -Mask - wymuszenie maski.
    #>
    param([Parameter(Mandatory)][string]$Text, [ValidateSet('L', 'M')][string]$Ecc = 'M', [ValidateRange(-1, 7)][int]$Mask = -1)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $version = 0
    $level = $Ecc
    foreach ($candidate in @($Ecc, 'L' | Select-Object -Unique)) {
        for ($v = 1; $v -le $script:QrMaxVersion; $v++) {
            if ($bytes.Length -le (Get-HTQrCapacity -Version $v -Ecc $candidate)) { $version = $v; $level = $candidate; break }
        }
        if ($version) { break }
    }
    if (-not $version) { throw "Tekst jest za długi na kod QR ($($bytes.Length) bajtów, maks. $(Get-HTQrCapacity -Version $script:QrMaxVersion -Ecc 'L'))." }
    $codewords = Get-HTQrCodewords -Bytes $bytes -Version $version -Ecc $level
    $size = 17 + 4 * $version
    $modules = New-Object 'bool[,]' $size, $size
    $isFunction = New-Object 'bool[,]' $size, $size
    $set = { param($x, $y, $dark) $modules[$y, $x] = [bool]$dark; $isFunction[$y, $x] = $true }

    # Wzorce stałe: synchronizacja, znaczniki położenia (z separatorami), wyrównanie
    for ($i = 0; $i -lt $size; $i++) { & $set 6 $i ($i % 2 -eq 0); & $set $i 6 ($i % 2 -eq 0) }
    foreach ($center in @(@(3, 3), @(($size - 4), 3), @(3, ($size - 4)))) {
        for ($dy = -4; $dy -le 4; $dy++) {
            for ($dx = -4; $dx -le 4; $dx++) {
                $xx = $center[0] + $dx; $yy = $center[1] + $dy
                if ($xx -lt 0 -or $yy -lt 0 -or $xx -ge $size -or $yy -ge $size) { continue }
                $dist = [Math]::Max([Math]::Abs($dx), [Math]::Abs($dy))
                & $set $xx $yy ($dist -ne 2 -and $dist -ne 4)
            }
        }
    }
    $align = @($script:QrAlignment[$version])
    $last = $align.Count - 1
    for ($i = 0; $i -lt $align.Count; $i++) {
        for ($j = 0; $j -lt $align.Count; $j++) {
            if (($i -eq 0 -and $j -eq 0) -or ($i -eq 0 -and $j -eq $last) -or ($i -eq $last -and $j -eq 0)) { continue }
            for ($dy = -2; $dy -le 2; $dy++) {
                for ($dx = -2; $dx -le 2; $dx++) { & $set ($align[$i] + $dx) ($align[$j] + $dy) ([Math]::Max([Math]::Abs($dx), [Math]::Abs($dy)) -ne 1) }
            }
        }
    }
    # Informacja o formacie (zarezerwowana; wpisywana po wyborze maski) i o wersji (od wersji 7)
    $drawFormat = {
        param($maskId)
        $bits = (Get-HTQrBchBits -Data (($script:QrEccFormatBits[$level] -shl 3) -bor $maskId) -Width 15 -Poly 0x537) -bxor 0x5412
        $bit = { param($n) ((($bits -shr $n) -band 1) -eq 1) }
        for ($i = 0; $i -le 5; $i++) { & $set 8 $i (& $bit $i) }
        & $set 8 7 (& $bit 6)
        & $set 8 8 (& $bit 7)
        & $set 7 8 (& $bit 8)
        for ($i = 9; $i -lt 15; $i++) { & $set (14 - $i) 8 (& $bit $i) }
        for ($i = 0; $i -lt 8; $i++) { & $set ($size - 1 - $i) 8 (& $bit $i) }
        for ($i = 8; $i -lt 15; $i++) { & $set 8 ($size - 15 + $i) (& $bit $i) }
        & $set 8 ($size - 8) $true
    }
    & $drawFormat 0
    if ($version -ge 7) {
        $vbits = Get-HTQrBchBits -Data $version -Width 18 -Poly 0x1F25
        for ($i = 0; $i -lt 18; $i++) {
            $dark = ((($vbits -shr $i) -band 1) -eq 1)
            $a = $size - 11 + ($i % 3)
            $b = [Math]::Floor($i / 3)
            & $set $a $b $dark
            & $set $b $a $dark
        }
    }

    # Dane: zygzakiem od prawego dolnego rogu, pary kolumn, z pominięciem kolumny synchronizacji
    $bitIndex = 0
    $totalBits = $codewords.Length * 8
    for ($right = $size - 1; $right -ge 1; $right -= 2) {
        if ($right -eq 6) { $right = 5 }
        $upward = ((($right + 1) -band 2) -eq 0)
        for ($vert = 0; $vert -lt $size; $vert++) {
            $y = if ($upward) { $size - 1 - $vert } else { $vert }
            for ($j = 0; $j -lt 2; $j++) {
                $x = $right - $j
                if ($isFunction[$y, $x]) { continue }
                if ($bitIndex -lt $totalBits) {
                    $modules[$y, $x] = ((($codewords[$bitIndex -shr 3] -shr (7 - ($bitIndex -band 7))) -band 1) -eq 1)
                    $bitIndex++
                }
            }
        }
    }

    # Maska: najmniejsza kara (albo wskazana). Ocena na płaskich tablicach bajtów - szybciej niż na macierzy w pętlach PowerShell.
    $best = $Mask
    if ($best -lt 0) {
        $n = $size
        $baseRows = New-Object byte[] ($n * $n)
        $baseCols = New-Object byte[] ($n * $n)
        $dataRows = New-Object System.Collections.Generic.List[int]
        $dataCols = New-Object System.Collections.Generic.List[int]
        $dataX = New-Object System.Collections.Generic.List[int]
        $dataY = New-Object System.Collections.Generic.List[int]
        for ($y = 0; $y -lt $n; $y++) {
            for ($x = 0; $x -lt $n; $x++) {
                $v = if ($modules[$y, $x]) { 49 } else { 48 }
                $baseRows[$y * $n + $x] = $v
                $baseCols[$x * $n + $y] = $v
                if (-not $isFunction[$y, $x]) { $dataRows.Add($y * $n + $x); $dataCols.Add($x * $n + $y); $dataX.Add($x); $dataY.Add($y) }
            }
        }
        # Pola informacji o formacie (x, y, numer bitu; -1 - zawsze ciemny)
        $formatCells = New-Object System.Collections.Generic.List[int[]]
        for ($i = 0; $i -le 5; $i++) { $formatCells.Add(@(8, $i, $i)) }
        $formatCells.Add(@(8, 7, 6)); $formatCells.Add(@(8, 8, 7)); $formatCells.Add(@(7, 8, 8))
        for ($i = 9; $i -lt 15; $i++) { $formatCells.Add(@((14 - $i), 8, $i)) }
        for ($i = 0; $i -lt 8; $i++) { $formatCells.Add(@(($n - 1 - $i), 8, $i)) }
        for ($i = 8; $i -lt 15; $i++) { $formatCells.Add(@(8, ($n - 15 + $i), $i)) }
        $count = $dataRows.Count
        $bestPenalty = [int]::MaxValue
        for ($m = 0; $m -lt 8; $m++) {
            $rows = $baseRows.Clone()
            $cols = $baseCols.Clone()
            for ($k = 0; $k -lt $count; $k++) {
                $x = $dataX[$k]; $y = $dataY[$k]
                $flip = switch ($m) {
                    0 { (($x + $y) % 2) -eq 0 }
                    1 { ($y % 2) -eq 0 }
                    2 { ($x % 3) -eq 0 }
                    3 { (($x + $y) % 3) -eq 0 }
                    4 { (([Math]::Floor($x / 3) + [Math]::Floor($y / 2)) % 2) -eq 0 }
                    5 { (($x * $y) % 2 + ($x * $y) % 3) -eq 0 }
                    6 { ((($x * $y) % 2 + ($x * $y) % 3) % 2) -eq 0 }
                    7 { ((($x + $y) % 2 + ($x * $y) % 3) % 2) -eq 0 }
                }
                if ($flip) {
                    $ri = $dataRows[$k]; $ci = $dataCols[$k]
                    $rows[$ri] = 97 - $rows[$ri]
                    $cols[$ci] = 97 - $cols[$ci]
                }
            }
            $fbits = (Get-HTQrBchBits -Data (($script:QrEccFormatBits[$level] -shl 3) -bor $m) -Width 15 -Poly 0x537) -bxor 0x5412
            foreach ($cell in $formatCells) {
                $v = if ((($fbits -shr $cell[2]) -band 1) -eq 1) { 49 } else { 48 }
                $rows[$cell[1] * $n + $cell[0]] = $v
                $cols[$cell[0] * $n + $cell[1]] = $v
            }
            $penalty = Get-HTQrPenalty -Rows $rows -Columns $cols -Size $n
            if ($penalty -lt $bestPenalty) { $bestPenalty = $penalty; $best = $m }
        }
    }
    for ($y = 0; $y -lt $size; $y++) {
        for ($x = 0; $x -lt $size; $x++) {
            if (-not $isFunction[$y, $x] -and (Test-HTQrMask -Mask $best -X $x -Y $y)) { $modules[$y, $x] = -not $modules[$y, $x] }
        }
    }
    & $drawFormat $best
    return [PSCustomObject]@{ Version = $version; Ecc = $level; Mask = $best; Size = $size; Modules = $modules }
}

function ConvertTo-HTQrText {
    # Kod QR jako tekst (wiersze z 0 i 1, bez marginesu) - testy i porównania
    param([Parameter(Mandatory)]$QrCode)
    return @(for ($y = 0; $y -lt $QrCode.Size; $y++) { -join @(for ($x = 0; $x -lt $QrCode.Size; $x++) { if ($QrCode.Modules[$y, $x]) { '1' } else { '0' } }) })
}

function New-HTQrBitmap {
    <#
        Obraz kodu QR dla WPF (BitmapSource, 1 piksel = 1 moduł, margines 4 moduły). W oknie wyświetlaj z
        RenderOptions.BitmapScalingMode = NearestNeighbor, aby moduły pozostały ostre.
    #>
    param([Parameter(Mandatory)]$QrCode, [int]$QuietZone = 4)
    $n = $QrCode.Size + 2 * $QuietZone
    $pixels = New-Object byte[] ($n * $n)
    for ($i = 0; $i -lt $pixels.Length; $i++) { $pixels[$i] = 255 }
    for ($y = 0; $y -lt $QrCode.Size; $y++) {
        for ($x = 0; $x -lt $QrCode.Size; $x++) {
            if ($QrCode.Modules[$y, $x]) { $pixels[($y + $QuietZone) * $n + $x + $QuietZone] = 0 }
        }
    }
    $bitmap = [System.Windows.Media.Imaging.BitmapSource]::Create($n, $n, 96, 96, [System.Windows.Media.PixelFormats]::Gray8, $null, $pixels, $n)
    $bitmap.Freeze()
    return $bitmap
}
#endregion
