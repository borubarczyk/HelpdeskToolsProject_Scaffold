# Generator haseł: hasła klasyczne, "przyjazne" (sylabowe) i słownikowe.
# Losowanie oparte o kryptograficzny generator liczb losowych (RandomNumberGenerator).

# Rozszerzony, bezpieczny zestaw przymiotników
$Script:adjectives = @(
	'Szybki', 'Wesoly', 'Maly', 'Duzy', 'Ciekawy', 'Spokojny', 'Glosny', 'Cichy', 'Jasny', 'Ciemny',
	'Zielony', 'Czerwony', 'Niebieski', 'Zolty', 'Bialy', 'Czarny', 'Miekki', 'Twardy', 'Lekki', 'Ciezki',
	'Piekny', 'Nowy', 'Stary', 'Dobry', 'Radosny', 'Czysty', 'Wysoki', 'Niski', 'Szeroki', 'Waski',
	'Dlugi', 'Krotki', 'Gruby', 'Chudy', 'Slodki', 'Gorzki', 'Kwasny', 'Ostry', 'Slony', 'Pachnacy',
	'Cierpliwy', 'Madry', 'Zabawny', 'Powazny', 'Cieply', 'Zimny', 'Wilgotny', 'Suchy', 'Gladki', 'Szorstki',
	'Lsniacy', 'Matowy', 'Kolorowy', 'Elastyczny', 'Szklany', 'Drewniany', 'Metalowy', 'Skorzany', 'Rowny', 'Krzywy',
	'Wklesly', 'Wypukly', 'Rozmyty', 'Przyjazny', 'Senny', 'Zwawy', 'Leniwy', 'Aktywny', 'Blyszczacy', 'Mocny'
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

# Kryptograficznie bezpieczna liczba losowa z zakresu [0, Max)
function Get-HTRandomInt {
	param ([Parameter(Mandatory)][int]$Max)
	if ($Max -le 1) { return 0 }
	return [System.Security.Cryptography.RandomNumberGenerator]::GetInt32($Max)
}

# Funkcja do losowania elementu (znaku) z kolekcji
function Get-RandomCharFrom($chars) {
	$array = @($chars)
	if ($array.Count -eq 0) { return $null }
	return $array[(Get-HTRandomInt -Max $array.Count)]
}

# Losowe przemieszanie tablicy (Fisher-Yates)
function Get-HTShuffled {
	param ([object[]]$Items)
	$array = @($Items)
	for ($i = $array.Count - 1; $i -gt 0; $i--) {
		$j = Get-HTRandomInt -Max ($i + 1)
		$tmp = $array[$i]; $array[$i] = $array[$j]; $array[$j] = $tmp
	}
	return , $array
}

# Funkcja do sprawdzenia, czy tekst zawiera sekwencje (abc, 123 ...)
function Test-SequentialChars($text) {
	$sequences = @(
		'abc', 'bcd', 'cde', 'def', 'efg', 'fgh', 'ghi', 'hij', 'ijk', 'jkl', 'klm', 'lmn', 'mno',
		'nop', 'opq', 'pqr', 'qrs', 'rst', 'stu', 'tuv', 'uvw', 'vwx', 'wxy', 'xyz',
		'012', '123', '234', '345', '456', '567', '678', '789'
	)
	$lower = "$text".ToLowerInvariant()
	foreach ($sequence in $sequences) {
		if ($lower.Contains($sequence)) { return $true }
	}
	return $false
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

	if (-not $SpecialCharacters) { $SpecialCharacters = "!@#$%^&*?" }

	# Tryb "przyjazny" - sylaby spółgłoska-samogłoska-spółgłoska, cyfry i jeden znak specjalny na końcu
	if ($FriendlyMode) {
		$consonants = 'bcdfghjkmnprstwz'.ToCharArray()
		$vowels = 'aeiuy'.ToCharArray()
		$numbers = '23456789'.ToCharArray()
		$symbols = if ($IncludeSymbols) { $SpecialCharacters.ToCharArray() } else { @() }

		$targetLength = if ($symbols.Count -gt 0) { $Length - 1 } else { $Length }
		$password = ""

		while ($password.Length -lt $targetLength) {
			$syllable = "$(Get-RandomCharFrom $consonants)$(Get-RandomCharFrom $vowels)$(Get-RandomCharFrom $consonants)"
			$password += $syllable.Substring(0, 1).ToUpper() + $syllable.Substring(1)
			if ($IncludeNumbers -and $password.Length -lt $targetLength) {
				$password += Get-RandomCharFrom $numbers
			}
		}

		$password = $password.Substring(0, $targetLength)
		if ($symbols.Count -gt 0) {
			$password += Get-RandomCharFrom $symbols
		}
		return $password
	}

	# Tryb klasyczny (bez znaków łatwych do pomylenia: i, l, o, I, L, O, 0, 1)
	$lower = 'abcdefghjkmnpqrstuvwxyz'
	$upper = 'ABCDEFGHJKMNPQRSTUVWXYZ'
	$nums = '23456789'
	$syms = if ($IncludeSymbols) { $SpecialCharacters } else { '' }

	if (-not $NoSimilarChars) {
		$lower = 'abcdefghijkmnopqrstuvwxyz'
		$upper = 'ABCDEFGHIJKLMNPQRSTUVWXYZ'
		$nums = '0123456789'
	}
	else {
		$syms = $syms -replace '[|lI10Oo]', ''
	}

	$classes = @()
	if ($IncludeLowercase) { $classes += , $lower }
	if ($IncludeUppercase) { $classes += , $upper }
	if ($IncludeNumbers) { $classes += , $nums }
	if ($IncludeSymbols -and $syms) { $classes += , $syms }

	if ($classes.Count -eq 0) {
		Write-Log -Message "Brak znaków do generowania hasła." -Type "Error"
		return $null
	}

	$charPool = ($classes -join '').ToCharArray()
	$letters = ($lower + $upper).ToCharArray()

	for ($attempt = 0; $attempt -lt 200; $attempt++) {
		# Po jednym znaku z każdej wymaganej klasy + dopełnienie z całej puli
		$chars = New-Object System.Collections.Generic.List[char]
		foreach ($class in $classes) { $chars.Add((Get-RandomCharFrom $class.ToCharArray())) }
		while ($chars.Count -lt $Length) { $chars.Add((Get-RandomCharFrom $charPool)) }

		$shuffled = Get-HTShuffled -Items $chars.ToArray()
		if ($shuffled.Count -gt $Length) { $shuffled = $shuffled[0..($Length - 1)] }

		if ($StartWithLetter -and $letters -notcontains $shuffled[0]) {
			$letterIndex = -1
			for ($k = 1; $k -lt $shuffled.Count; $k++) {
				if ($letters -ccontains $shuffled[$k]) { $letterIndex = $k; break }
			}
			if ($letterIndex -gt 0) {
				$tmp = $shuffled[0]; $shuffled[0] = $shuffled[$letterIndex]; $shuffled[$letterIndex] = $tmp
			}
			else {
				$shuffled[0] = Get-RandomCharFrom $letters
			}
		}

		$password = -join $shuffled

		$okDuplicates = -not $NoDuplicateChars -or (@($password.ToCharArray() | Select-Object -Unique).Count -eq $password.Length)
		$okSequence = -not $NoSequentialChars -or -not (Test-SequentialChars $password)
		$okClasses = $true
		foreach ($class in $classes) {
			if ($password.IndexOfAny($class.ToCharArray()) -lt 0) { $okClasses = $false; break }
		}

		if ($okDuplicates -and $okSequence -and $okClasses) {
			return $password
		}
	}

	Write-Log -Message "Zbyt restrykcyjne warunki - generuję hasło bez ograniczeń duplikatów i sekwencji." -Type "Warn"
	return New-Password -Length $Length -SpecialCharacters $SpecialCharacters -StartWithLetter $StartWithLetter `
		-IncludeNumbers $IncludeNumbers -IncludeLowercase $IncludeLowercase -IncludeUppercase $IncludeUppercase `
		-IncludeSymbols $IncludeSymbols -NoSimilarChars $NoSimilarChars -NoDuplicateChars $false -NoSequentialChars $false
}

# Funkcja do generowania hasła opartego na słowach (np. SzybkiKotDom42!)
function New-WordBasedPassword {
	[CmdletBinding()]
	param (
		[ValidateRange(8, 64)]
		[int]$Length = 12,
		[string]$SpecialCharacters = $Global:PasswordSpecialCharacters,
		[bool]$UseSymbols = $true,
		[bool]$UseNumbers = $true
	)

	if (-not $SpecialCharacters) { $SpecialCharacters = "!@#$%^&*?" }

	# Rezerwacja miejsca na końcowe znaki
	$endPart = ""
	if ($UseNumbers) { $endPart += (10 + (Get-HTRandomInt -Max 90)).ToString() }
	if ($UseSymbols) { $endPart += Get-RandomCharFrom $SpecialCharacters.ToCharArray() }

	$maxMainLength = $Length - $endPart.Length

	$password = Get-RandomCharFrom $Script:adjectives
	$usedNouns = New-Object System.Collections.Generic.List[string]
	while ($password.Length -lt $maxMainLength) {
		$available = @($Script:nouns | Where-Object { -not $usedNouns.Contains($_) })
		if ($available.Count -eq 0) { $available = $Script:nouns }
		$noun = Get-RandomCharFrom $available
		$usedNouns.Add($noun)
		$password += $noun
	}

	return $password.Substring(0, $maxMainLength) + $endPart
}

# Szacowanie siły hasła (entropia w bitach i ocena opisowa)
function Get-HTPasswordStrength {
	param ([AllowEmptyString()][AllowNull()][string]$Password)

	if (-not $Password) {
		return [PSCustomObject]@{ Score = 0; Entropy = 0; Label = "Brak hasła" }
	}

	$pool = 0
	if ($Password -cmatch '[a-z]') { $pool += 26 }
	if ($Password -cmatch '[A-Z]') { $pool += 26 }
	if ($Password -match '\d') { $pool += 10 }
	if ($Password -match '[^a-zA-Z0-9]') { $pool += 32 }

	$entropy = [Math]::Round($Password.Length * [Math]::Log([Math]::Max(2, $pool), 2), 1)
	$score = if ($entropy -lt 40) { 1 } elseif ($entropy -lt 60) { 2 } elseif ($entropy -lt 80) { 3 } else { 4 }
	$label = @("Brak hasła", "Słabe", "Średnie", "Silne", "Bardzo silne")[$score]

	return [PSCustomObject]@{
		Score   = $score
		Entropy = $entropy
		Label   = $label
	}
}
