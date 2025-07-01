# Rozszerzony, bezpieczny zestaw przymiotników
$Script:adjectives = @(
	'Szybki', 'Wesoly', 'Maly', 'Duzy', 'Ciekawy', 'Spokojny', 'Glosny', 'Cichy', 'Jasny', 'Ciemny',
	'Zielony', 'Czerwony', 'Niebieski', 'Zolty', 'Bialy', 'Czarny', 'Miekki', 'Twardy', 'Lekki', 'Ciezki',
	'Piekny', 'Brzydki', 'Nowy', 'Stary', 'Dobry', 'Zly', 'Smutny', 'Radosny', 'Czysty', 'Brudny',
	'Wysoki', 'Niski', 'Szeroki', 'Waski', 'Dlugi', 'Krotki', 'Gruby', 'Chudy', 'Slodki', 'Gorzki',
	'Kwasny', 'Ostry', 'Slony', 'Pachnacy', 'Cierpliwy', 'Niespokojny', 'Madry', 'Glupi', 'Zabawny', 'Powazny',
	'Cieply', 'Zimny', 'Wilgotny', 'Suchy', 'Gladki', 'Szorstki', 'Ciezki', 'Lsniacy', 'Matowy', 'Kolorowy',
	'Elastyczny', 'Szklany', 'Drewniany', 'Metalowy', 'Skorzany', 'Twardawy', 'Rowny', 'Krzywy', 'Wklesly',
	'Wypukly', 'Rozmyty', 'Przyjazny', 'Wrogi', 'Senny', 'Zwawy', 'Leniwy', 'Aktywny', 'Blyszczacy', 'Mocny'
)

# Rozszerzony, bezpieczny zestaw rzeczowników
$Script:nouns = @(
	'Dom', 'Pies', 'Kot', 'Las', 'Rzeka', 'Gora', 'Morze', 'Jezioro', 'Pole', 'Dolina',
	'Drzewo', 'Kwiat', 'Trawa', 'Kamien', 'Piasek', 'Snieg', 'Deszcz', 'Slonce', 'Ksiezyc', 'Gwiazda',
	'Chmura', 'Wiatr', 'Ogien', 'Dym', 'Cien', 'Swiatlo', 'Mrok', 'Droga', 'Sciezka', 'Most',
	'Miasto', 'Wies', 'Okno', 'Drzwi', 'Stol', 'Krzeslo', 'Lozko', 'Szafa', 'Lustro', 'Zegar',
	'Ksiazka', 'Pioro', 'Papier', 'Telefon', 'Komputer', 'Samochod', 'Rower', 'Statek', 'Samolot', 'Pociag',
	'Zamek', 'Mostek', 'Zwierze', 'Ptak', 'Ryba', 'Krab', 'Muszla', 'Kula', 'Lampa', 'Puszka',
	'Kubek', 'Szczotka', 'Grzebien', 'Kapelusz', 'Plecak', 'Pudelko', 'Skrzynia', 'Dzwonek', 'Fotel', 'Koc',
	'Plyta', 'Talerz', 'Widelec', 'Noz', 'Lyzka', 'Butelka', 'Lina', 'Cegla', 'Walizka', 'Pojemnik'
)

# Funkcja do generowania losowych znaków
function Get-RandomCharFrom($chars) {
	return $chars | Get-Random
}

# Funkcja do Sprawdzenia, czy tekst zawiera podobne znaki
function Test-SequentialChars($text) {
	$sequences = @(
		'abc', 'bcd', 'cde', 'def', 'efg', 'fgh', 'ghi', 'hij', 'ijk', 'jkl', 'klm', 'mno',
		'nop', 'opq', 'pqr', 'qrs', 'rst', 'stu', 'tuv', 'uvw', 'vwx', 'wxy', 'xyz',
		'ABC', 'BCD', 'CDE', 'DEF', 'EFG', 'FGH', 'GHI', 'HIJ', 'IJK', 'JKL', 'KLM', 'MNO',
		'NOP', 'OPQ', 'PQR', 'QRS', 'RST', 'STU', 'TUV', 'UVW', 'VWX', 'WXY', 'XYZ',
		'123', '234', '345', '456', '567', '678', '789'
	)
	return $null -ne ($sequences | Where-Object { $text -like "*$_*" })
}

# Funkcja generująca hasło
function New-Password {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)][ValidateRange(4, 64)][int]$Length,
		[string]$SpecialCharacters = $Global:PasswordSpecialCharacters,
		[bool]$StartWithLetter = $false,
		[bool]$IncludeNumbers = $true,
		[bool]$IncludeLowercase = $true,
		[bool]$IncludeUppercase = $true,
		[bool]$IncludeSymbols = $true,
		[bool]$NoSimilarChars = $false,
		[bool]$NoDuplicateChars = $false,
		[bool]$NoSequentialChars = $false,
		[bool]$FriendlyMode = $false
	)

	# Funkcja do generowania przyjaznych haseł
	if ($FriendlyMode) {
		$consonants = 'bcdfghjklmnprstwz'.ToCharArray()
		$vowels = 'aeiouy'.ToCharArray()
		$numbers = '123456789'.ToCharArray()
		$symbols = if ($IncludeSymbols -and $SpecialCharacters) {
			$SpecialCharacters.ToCharArray()
		}
		else { @() }

		$syllables = 1..50 | ForEach-Object {
			$syl = (Get-RandomCharFrom $consonants) + (Get-RandomCharFrom $vowels) + (Get-RandomCharFrom $consonants)
			$syl.Substring(0, 1).ToUpper() + $syl.Substring(1)
		}

		$password = ""

		# Ile znaków ma zostać wygenerowane zanim dodamy symbol (lub nie)
		$targetLength = if ($symbols.Count -gt 0) { $Length - 1 } else { $Length }

		while ($password.Length -lt $targetLength) {
			$password += Get-RandomCharFrom $syllables
			if ($IncludeNumbers -and $password.Length -lt $targetLength) {
				$password += Get-RandomCharFrom $numbers
			}
		}

		# Obetnij do targetu
		$password = $password.Substring(0, [Math]::Min($targetLength, $password.Length))

		# Dodaj symbol tylko jeśli checkbox zaznaczony
		if ($symbols.Count -gt 0) {
			$password += Get-RandomCharFrom $symbols
		}

		return $password
	}


	# Tryb klasyczny
	$lower = 'abcdefghjkmnpqrstuvwxyz'
	$upper = 'ABCDEFGHJKMNPQRSTUVWXYZ'
	$nums = '123456789'
	$syms = if ($IncludeSymbols -and $SpecialCharacters) { $SpecialCharacters } else { '' }

	if ($NoSimilarChars) {
		$lower = $lower -replace '[ilo]', ''
		$upper = $upper -replace '[ILO]', ''
		$nums = $nums -replace '[01]', ''
		$syms = $syms -replace '[1lI0Oo]', ''
	}

	$charPool = ''
	if ($IncludeLowercase) { $charPool += $lower }
	if ($IncludeUppercase) { $charPool += $upper }
	if ($IncludeNumbers) { $charPool += $nums }
	if ($IncludeSymbols -and $syms) { $charPool += $syms }

	if (-not $charPool) {
		Write-Log -Message "Brak znaków do generowania hasła." -Type "Error"
		return $null
	}

	$attempts = 100
	for ($i = 0; $i -lt $attempts; $i++) {
		$chars = [System.Collections.ArrayList]::new()
		if ($StartWithLetter) {
			$first = ($lower + $upper).ToCharArray() | Get-Random
			$null = $chars.Add($first)
		}

		$rest = $Length - $chars.Count
		for ($j = 0; $j -lt $rest; $j++) {
			$null = $chars.Add((Get-RandomCharFrom ($charPool.ToCharArray())))
		}

		$password = -join $chars

		$hasLower = !$IncludeLowercase -or $password -cmatch '[a-z]'
		$hasUpper = !$IncludeUppercase -or $password -cmatch '[A-Z]'
		$hasDigit = !$IncludeNumbers -or $password -cmatch '\d'
		$hasSym = !$IncludeSymbols -or $password -match "[$([regex]::Escape($syms))]"
		$hasDup = !$NoDuplicateChars -or (($password.ToCharArray() | Select-Object -Unique).Count -eq $password.Length)
		$noSeq = !$NoSequentialChars -or !(Contains-SequentialChars $password)

		if ($hasLower -and $hasUpper -and $hasDigit -and $hasSym -and $hasDup -and $noSeq) {
			return $password
		}
	}

	Write-Log -Message "Zbyt restrykcyjne warunki - próbuję z uproszczeniem." -Type "Warn"
	return New-Password -Length $Length -SpecialCharacters $SpecialCharacters -StartWithLetter $StartWithLetter `
		-IncludeNumbers $IncludeNumbers -IncludeLowercase $IncludeLowercase -IncludeUppercase $IncludeUppercase `
		-IncludeSymbols $IncludeSymbols -NoSimilarChars:$false -NoDuplicateChars:$false -NoSequentialChars:$false `
		-FriendlyMode:$false
}

# Funkcja do generowania hasła opartego na słowach
function New-WordBasedPassword {
    [CmdletBinding()]
    param (
        [ValidateRange(8, 64)]
        [int]$Length = 12,
        [string]$SpecialCharacters = $Global:PasswordSpecialCharacters,
        [bool]$UseSymbols = $true,
        [bool]$UseNumbers = $true
    )

    # Pomocnicza funkcja
    function Get-RandomCharFrom { param($Array); return $Array | Get-Random }

    $adjectives = @('Szybki','Wesoly','Maly','Duzy','Ciekawy','Spokojny','Glosny','Cichy','Jasny','Ciemny','Zielony','Czerwony','Niebieski','Zolty','Bialy','Czarny','Miekki','Twardy','Lekki','Ciezki','Piekny','Brzydki','Nowy','Stary','Dobre','Zle','Smutny','Radosny','Czysty','Brudny','Wysoki','Niski','Szeroki','Waski','Dlugi','Krotki','Gruby','Chudy','Slodki','Gorzki','Kwasny','Ostry','Slony','Pachnacy','Cierpliwy','Niespokojny','Madry','Glupi','Zabawny','Powazny')
    $nouns = @('Dom','Pies','Kot','Las','Rzeka','Gora','Morze','Jezioro','Pole','Dolina','Drzewo','Kwiat','Trawa','Kamien','Piasek','Snieg','Deszcz','Slonce','Ksiezyc','Gwiazda','Chmura','Wiatr','Ogien','Dym','Cien','Swiatlo','Mrok','Droga','Sciezka','Most')

    # Rezerwacja miejsca na końcowe znaki
    $endPart = ""
    if ($UseNumbers) {
        $endPart += (Get-Random -Min 10 -Max 99).ToString()
    }
    if ($UseSymbols -and $SpecialCharacters) {
        $endPart += (Get-RandomCharFrom $SpecialCharacters.ToCharArray())
    }

    $maxMainLength = $Length - $endPart.Length
    if ($maxMainLength -lt 5) {
        # Jeżeli za mało miejsca – skróć endPart do 1 cyfra i 1 znak specjalny
        $endPart = ""
        if ($UseNumbers) { $endPart += (Get-Random -Min 0 -Max 9).ToString() }
        if ($UseSymbols -and $SpecialCharacters) { $endPart += (Get-RandomCharFrom $SpecialCharacters.ToCharArray()) }
        $maxMainLength = $Length - $endPart.Length
    }

    # Generuj przymiotnik
    $adj = Get-RandomCharFrom $adjectives
    $adj = $adj.Substring(0,1).ToUpper() + $adj.Substring(1).ToLower()
    $password = $adj

    # Dodawaj rzeczowniki aż do osiągnięcia maxMainLength
    $usedNouns = @()
    while ($password.Length -lt $maxMainLength) {
        $noun = ($nouns | Where-Object { $usedNouns -notcontains $_ }) | Get-Random
        $usedNouns += $noun
        $password += $noun
    }

    # Skróć główną część jeśli trzeba i dodaj zakończenie
    $main = $password.Substring(0, $maxMainLength)
    return $main + $endPart
}
