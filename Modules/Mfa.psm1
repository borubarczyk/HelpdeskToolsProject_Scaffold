# MFA przy odblokowaniu programu (kod z aplikacji uwierzytelniającej, TOTP) - jak w Domain Ops.
# Drugi składnik odblokowania: kod z aplikacji (Microsoft / Google Authenticator i podobne; TOTP wg RFC 6238:
# HMAC-SHA1, 30 s, 6 cyfr). Klucze generuje program na tym komputerze i zapisuje w pliku Mfa.json (katalog konfiguracji)
# zaszyfrowane DPAPI - odczyta je tylko to konto Windows na tym komputerze.
# Konto podstawowe: PIN programu + kod; konta dodatkowe: własna nazwa, własny PIN (PBKDF2), własny klucz i uprawnienia.
# Usunięcie pliku Mfa.json wyłącza MFA (zostaje sam PIN) - tak odzyskuje się dostęp po utracie telefonu.
# Moduł nie zależy od interfejsu (ekran blokady i okna MFA są w UIComponents.psm1).

$script:MfaIssuer = 'Helpdesk Tools'
$script:MfaDigits = 6
$script:MfaPeriod = 30
$script:Base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'

# Uprawnienia konta, które odblokowało program. Klucze blokad: 'ws:<przestrzeń>', 'mod:<moduł>', 'app:Settings',
# 'app:Write' (tryb tylko do odczytu - bez operacji zmieniających).
# AccountId: '#primary' (konto podstawowe albo program bez MFA) lub Id konta dodatkowego.
$script:Access = @{ Account = ''; AccountId = '#primary'; Deny = New-Object 'System.Collections.Generic.HashSet[string]' }

#region Base32 i TOTP
function ConvertTo-HTBase32 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    $sb = New-Object System.Text.StringBuilder
    $buffer = 0
    $bits = 0
    foreach ($b in $Bytes) {
        $buffer = (($buffer -shl 8) -bor $b) -band 0xFFFF
        $bits += 8
        while ($bits -ge 5) {
            $bits -= 5
            [void]$sb.Append($script:Base32Alphabet[($buffer -shr $bits) -band 31])
        }
    }
    if ($bits -gt 0) { [void]$sb.Append($script:Base32Alphabet[($buffer -shl (5 - $bits)) -band 31]) }
    return $sb.ToString()
}

function ConvertFrom-HTBase32 {
    # Spacje, myślniki i '=' są pomijane, wielkość liter bez znaczenia; niedozwolony znak - wyjątek
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    $clean = ($Text -replace '[\s\-=]', '').ToUpperInvariant()
    $out = New-Object System.Collections.Generic.List[byte]
    $buffer = 0
    $bits = 0
    foreach ($ch in $clean.ToCharArray()) {
        $v = $script:Base32Alphabet.IndexOf($ch)
        if ($v -lt 0) { throw "Niedozwolony znak w kluczu: $ch" }
        $buffer = (($buffer -shl 5) -bor $v) -band 0xFFFF
        $bits += 5
        if ($bits -ge 8) {
            $bits -= 8
            $out.Add([byte](($buffer -shr $bits) -band 0xFF))
        }
    }
    return , $out.ToArray()
}

function Get-HTTotpStep {
    param([datetime]$Time = [datetime]::UtcNow)
    $unix = ([DateTimeOffset]$Time.ToUniversalTime()).ToUnixTimeSeconds()
    return [long][Math]::Floor($unix / $script:MfaPeriod)
}

function Get-HTTotpCode {
    # Kod dla kroku czasu (RFC 4226: HMAC-SHA1 licznika big-endian, dynamiczne obcięcie)
    param([Parameter(Mandatory)][byte[]]$Secret, [Parameter(Mandatory)][long]$Step, [int]$Digits = $script:MfaDigits)
    $counter = [BitConverter]::GetBytes([long]$Step)
    if ([BitConverter]::IsLittleEndian) { [array]::Reverse($counter) }
    $hmac = New-Object System.Security.Cryptography.HMACSHA1 (, $Secret)
    try { $hash = $hmac.ComputeHash($counter) } finally { $hmac.Dispose() }
    $offset = $hash[$hash.Length - 1] -band 0x0F
    $bin = (([int]($hash[$offset] -band 0x7F)) -shl 24) -bor (([int]$hash[$offset + 1]) -shl 16) -bor (([int]$hash[$offset + 2]) -shl 8) -bor ([int]$hash[$offset + 3])
    $mod = [long][Math]::Pow(10, $Digits)
    return ([long]$bin % $mod).ToString().PadLeft($Digits, '0')
}

function Test-HTTotpCode {
    <#
        Krok czasu, dla którego kod jest poprawny (bieżący ±1, czyli tolerancja 30 s zegara), -1 (zły kod) albo -2 (kod
        z kroku nie późniejszego niż -LastStep - już użyty; ten sam kod nie odblokuje drugi raz).
    #>
    param([Parameter(Mandatory)][byte[]]$Secret, [AllowEmptyString()][AllowNull()][string]$Code, [long]$LastStep = -1, [datetime]$Time = [datetime]::UtcNow)
    $c = ([string]$Code) -replace '\s', ''
    if ($c -notmatch "^\d{$($script:MfaDigits)}$") { return -1 }
    $now = Get-HTTotpStep -Time $Time
    $used = $false
    foreach ($s in @($now, ($now - 1), ($now + 1))) {
        $expected = Get-HTTotpCode -Secret $Secret -Step $s
        # Porównanie w stałym czasie
        $diff = 0
        for ($i = 0; $i -lt $expected.Length; $i++) { $diff = $diff -bor ([int][char]$expected[$i] -bxor [int][char]$c[$i]) }
        if ($diff -ne 0) { continue }
        if ($s -le $LastStep) { $used = $true; continue }
        return $s
    }
    return $(if ($used) { -2 } else { -1 })
}

function New-HTMfaSecret {
    # 160 bitów z generatora kryptograficznego (zalecana długość dla HMAC-SHA1)
    $bytes = New-Object byte[] 20
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    return , $bytes
}

function Format-HTMfaKey([string]$Base32) {
    # Klucz do wpisania ręcznie: grupy po 4 znaki
    return ((@([regex]::Matches($Base32, '.{1,4}') | ForEach-Object { $_.Value })) -join ' ')
}

function Get-HTMfaUri {
    # Link otpauth:// (aplikacje, które przyjmują go wklejony, np. menedżery haseł)
    param([Parameter(Mandatory)][string]$Account, [Parameter(Mandatory)][string]$Base32)
    $label = [uri]::EscapeDataString("$($script:MfaIssuer):$Account")
    return ('otpauth://totp/{0}?secret={1}&issuer={2}&algorithm=SHA1&digits={3}&period={4}' -f $label, $Base32, [uri]::EscapeDataString($script:MfaIssuer), $script:MfaDigits, $script:MfaPeriod)
}

function Get-HTMfaSettings {
    # Parametry kodów do opisu w oknach (wystawca, cyfry, okres)
    return @{ Issuer = $script:MfaIssuer; Digits = $script:MfaDigits; Period = $script:MfaPeriod }
}
#endregion

#region Plik kont MFA (DPAPI)
function Protect-HTMfaData([string]$Text) {
    # DPAPI bieżącego użytkownika: odczyta tylko to konto Windows na tym komputerze
    $ss = New-Object System.Security.SecureString
    foreach ($ch in $Text.ToCharArray()) { $ss.AppendChar($ch) }
    $ss.MakeReadOnly()
    try { return (ConvertFrom-SecureString -SecureString $ss) } finally { $ss.Dispose() }
}

function Unprotect-HTMfaData([string]$Blob) {
    $ss = ConvertTo-SecureString -String $Blob
    $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ss)
    try { return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
    finally { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr); $ss.Dispose() }
}

function Get-HTMfaFile {
    if (-not $Global:ConfigDir) { return $null }
    return (Join-Path $Global:ConfigDir 'Mfa.json')
}

function Read-HTMfaStore {
    # Konta MFA: @{ Accounts = @(@{ Id; Name; Primary; PinLength; Data; LastStep; Created; LastUsed }) }
    $empty = @{ Accounts = @() }
    $path = Get-HTMfaFile
    if (-not $path -or -not (Test-Path -LiteralPath $path)) { return $empty }
    $raw = [System.IO.File]::ReadAllText($path)
    if (-not $raw.Trim()) { return $empty }
    $obj = ConvertFrom-Json -InputObject $raw
    $accounts = foreach ($a in @($obj.Accounts)) {
        if ($null -eq $a) { continue }
        @{ Id = [string]$a.Id; Name = [string]$a.Name; Primary = [bool]$a.Primary; PinLength = [int]$a.PinLength; Data = [string]$a.Data
            LastStep = [long]$a.LastStep; Created = [string]$a.Created; LastUsed = [string]$a.LastUsed }
    }
    return @{ Accounts = @($accounts) }
}

function Save-HTMfaStore {
    # Zapis przez plik tymczasowy (przerwany zapis nie zostawi uszkodzonego pliku)
    param([Parameter(Mandatory)][hashtable]$Store)
    $path = Get-HTMfaFile
    if (-not $path) { throw 'Brak katalogu konfiguracji - nie można zapisać kont MFA.' }
    $dir = Split-Path -Parent $path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $doc = [ordered]@{
        Version  = 1
        Note     = 'Konta MFA programu Helpdesk Tools na tym komputerze. Klucze zaszyfrowane DPAPI (tylko to konto Windows). Usunięcie pliku wyłącza MFA.'
        Accounts = @($Store.Accounts | ForEach-Object { [ordered]@{ Id = $_.Id; Name = $_.Name; Primary = [bool]$_.Primary; PinLength = [int]$_.PinLength; Data = $_.Data; LastStep = [long]$_.LastStep; Created = $_.Created; LastUsed = $_.LastUsed } })
    }
    $tmp = $path + '.tmp'
    [System.IO.File]::WriteAllText($tmp, (ConvertTo-Json -InputObject $doc -Depth 5), (New-Object System.Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $tmp -Destination $path -Force
}

function Test-HTMfaEnabled {
    # Czy na tym komputerze są konta MFA (plik nieczytelny - $false, odblokowanie samym PIN-em)
    try { return (@((Read-HTMfaStore).Accounts).Count -gt 0) } catch { return $false }
}

function Get-HTMfaAccountSecret {
    # Klucz konta (bajty), dane PIN-u i blokady dostępu (Deny) z części zaszyfrowanej; wyjątek, gdy DPAPI nie odczyta
    # (inny komputer albo konto Windows)
    param([Parameter(Mandatory)][hashtable]$Account)
    $d = ConvertFrom-Json -InputObject (Unprotect-HTMfaData $Account.Data)
    $deny = @()
    if ($d.PSObject.Properties['Deny']) { $deny = @($d.Deny | Where-Object { $_ } | ForEach-Object { [string]$_ }) }
    return @{ Secret = (ConvertFrom-HTBase32 ([string]$d.Secret)); Base32 = [string]$d.Secret; PinSalt = [string]$d.PinSalt; PinHash = [string]$d.PinHash; Deny = $deny }
}

function Set-HTMfaAccountData {
    # Część poufna konta (klucz, skrót PIN-u, blokady dostępu) zaszyfrowana DPAPI
    param([Parameter(Mandatory)][hashtable]$Account, [Parameter(Mandatory)][string]$Base32, [string]$PinSalt = '', [string]$PinHash = '', [string[]]$Deny = @())
    $Account.Data = Protect-HTMfaData (ConvertTo-Json -InputObject ([ordered]@{ Secret = $Base32; PinSalt = $PinSalt; PinHash = $PinHash; Deny = @($Deny | Where-Object { $_ }) }) -Compress)
}

function New-HTMfaAccount {
    # Konto do zapisu: klucz Base32, PIN (konta dodatkowe; PBKDF2 jak PIN programu), część poufna zaszyfrowana DPAPI
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Base32, [switch]$Primary, [string]$Pin = '', [long]$LastStep = -1, [string[]]$Deny = @())
    $salt = ''
    $hash = ''
    $length = 0
    if ($Pin) {
        $record = New-HTPinRecord -Pin $Pin
        $salt = $record.PinSalt
        $hash = $record.PinHash
        $length = $record.PinLength
    }
    $a = @{ Id = [guid]::NewGuid().ToString('N'); Name = $Name; Primary = [bool]$Primary; PinLength = $length; Data = ''; LastStep = $LastStep
        Created = (Get-Date).ToString('yyyy-MM-dd HH:mm'); LastUsed = '' }
    Set-HTMfaAccountData -Account $a -Base32 $Base32 -PinSalt $salt -PinHash $hash -Deny $Deny
    return $a
}

function Add-HTMfaAccount {
    # Nowe konto w pliku (nazwa unikalna); konto podstawowe może być tylko jedno. Zwraca zapisane konto.
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Base32, [switch]$Primary, [string]$Pin = '', [long]$LastStep = -1, [string[]]$Deny = @())
    $store = Read-HTMfaStore
    if (@($store.Accounts | Where-Object { $_.Name -ieq $Name }).Count) { throw "Konto «$Name» już istnieje." }
    if ($Primary -and @($store.Accounts | Where-Object { $_.Primary }).Count) { throw 'Konto podstawowe MFA już istnieje.' }
    if (-not $Primary -and -not (Test-HTPinFormat $Pin)) { throw 'Konto dodatkowe wymaga własnego PIN-u (4-8 cyfr).' }
    $account = New-HTMfaAccount -Name $Name -Base32 $Base32 -Primary:$Primary -Pin $(if ($Primary) { '' } else { $Pin }) -LastStep $LastStep -Deny $Deny
    $store.Accounts = @($store.Accounts) + @($account)
    Save-HTMfaStore -Store $store
    return $account
}

function Set-HTMfaAccountKey {
    # Nowy klucz (i ewentualnie nazwa) istniejącego konta; PIN i blokady dostępu bez zmian
    param([Parameter(Mandatory)][string]$Id, [Parameter(Mandatory)][string]$Base32, [string]$Name = '', [long]$LastStep = -1)
    $store = Read-HTMfaStore
    $acc = @($store.Accounts | Where-Object { $_.Id -eq $Id })[0]
    if (-not $acc) { throw 'Tego konta nie ma już w pliku MFA.' }
    if ($Name -and @($store.Accounts | Where-Object { $_.Name -ieq $Name -and $_.Id -ne $Id }).Count) { throw "Konto «$Name» już istnieje." }
    $prev = Get-HTMfaAccountSecret -Account $acc
    Set-HTMfaAccountData -Account $acc -Base32 $Base32 -PinSalt $prev.PinSalt -PinHash $prev.PinHash -Deny $prev.Deny
    if ($Name) { $acc.Name = $Name }
    $acc.LastStep = $LastStep
    Save-HTMfaStore -Store $store
}

function Set-HTMfaAccountDeny {
    # Blokady dostępu konta dodatkowego (konto podstawowe ma zawsze pełny dostęp)
    param([Parameter(Mandatory)][string]$Id, [string[]]$Deny = @())
    $store = Read-HTMfaStore
    $acc = @($store.Accounts | Where-Object { $_.Id -eq $Id })[0]
    if (-not $acc) { throw 'Tego konta nie ma już w pliku MFA.' }
    if ($acc.Primary) { throw 'Konto podstawowe ma zawsze pełny dostęp.' }
    $cur = Get-HTMfaAccountSecret -Account $acc
    Set-HTMfaAccountData -Account $acc -Base32 $cur.Base32 -PinSalt $cur.PinSalt -PinHash $cur.PinHash -Deny $Deny
    Save-HTMfaStore -Store $store
}

function Set-HTMfaAccountPin {
    # Nowy PIN konta dodatkowego (konto podstawowe używa PIN-u programu - Set-HTPin)
    param([Parameter(Mandatory)][string]$Id, [Parameter(Mandatory)][string]$Pin)
    $store = Read-HTMfaStore
    $acc = @($store.Accounts | Where-Object { $_.Id -eq $Id })[0]
    if (-not $acc) { throw 'Tego konta nie ma już w pliku MFA.' }
    if ($acc.Primary) { throw 'Konto podstawowe używa PIN-u programu.' }
    $record = New-HTPinRecord -Pin $Pin
    $cur = Get-HTMfaAccountSecret -Account $acc
    Set-HTMfaAccountData -Account $acc -Base32 $cur.Base32 -PinSalt $record.PinSalt -PinHash $record.PinHash -Deny $cur.Deny
    $acc.PinLength = $record.PinLength
    Save-HTMfaStore -Store $store
}

function Remove-HTMfaAccount {
    # Usunięcie konta (podstawowego tylko jako ostatniego); bez kont plik jest usuwany (MFA wyłączone)
    param([Parameter(Mandatory)][string]$Id)
    $store = Read-HTMfaStore
    $acc = @($store.Accounts | Where-Object { $_.Id -eq $Id })[0]
    if (-not $acc) { return }
    if ($acc.Primary -and @($store.Accounts).Count -gt 1) { throw 'Najpierw usuń konta dodatkowe - działają tylko razem z MFA konta podstawowego.' }
    $store.Accounts = @($store.Accounts | Where-Object { $_.Id -ne $Id })
    if ($store.Accounts.Count) { Save-HTMfaStore -Store $store }
    else { Remove-Item -LiteralPath (Get-HTMfaFile) -Force -ErrorAction SilentlyContinue }
}

function Test-HTMfaAccountPin {
    # PIN konta: podstawowe - PIN programu (config.json); dodatkowe - skrót z części zaszyfrowanej
    param([Parameter(Mandatory)][hashtable]$Account, [AllowEmptyString()][AllowNull()][string]$Pin)
    if (-not $Pin) { return $false }
    if ($Account.Primary) { return (Test-HTPin -Pin $Pin) }
    $s = Get-HTMfaAccountSecret -Account $Account
    if (-not $s.PinHash) { return $false }
    return (Test-HTPin -Pin $Pin -Config ([pscustomobject]@{ PinHash = $s.PinHash; PinSalt = $s.PinSalt; PinLength = [int]$Account.PinLength }))
}

function Get-HTMfaUnlockAccounts {
    # Konta do ekranu blokady (podstawowe pierwsze, potem ostatnio używane); pusta lista = MFA wyłączone (sam PIN).
    # Plik nieczytelny: MFA wyłączone z ostrzeżeniem w dzienniku (tak samo jak po usunięciu pliku).
    $store = $null
    try { $store = Read-HTMfaStore }
    catch {
        Write-Log -Message ('Nie odczytano pliku MFA ({0}): {1} - odblokowanie samym PIN-em.' -f (Get-HTMfaFile), $_.Exception.Message) -Type 'Warn'
        return @()
    }
    $list = @($store.Accounts)
    if (-not $list.Count) { return @() }
    $primary = @($list | Where-Object { $_.Primary })
    $others = @($list | Where-Object { -not $_.Primary } | Sort-Object -Property @{ Expression = { [string]$_.LastUsed }; Descending = $true }, @{ Expression = { $_.Name } })
    # Bez konta podstawowego (plik zmieniony ręcznie): PIN programu bez kodu
    if (-not $primary.Count) { $primary = @(@{ Id = ''; Name = 'Konto podstawowe'; Primary = $true; PinLength = 0; Data = ''; LastStep = -1; Created = ''; LastUsed = ''; NoMfa = $true }) }
    return @($primary + $others)
}

function Save-HTMfaUse {
    # Po poprawnym kodzie: krok czasu (ten kod nie zadziała drugi raz) i data użycia - zapis od razu
    param([Parameter(Mandatory)][hashtable]$Account, [long]$Step)
    $Account.LastStep = [Math]::Max([long]$Account.LastStep, $Step)
    $Account.LastUsed = (Get-Date).ToString('yyyy-MM-dd HH:mm')
    try {
        $store = Read-HTMfaStore
        foreach ($a in @($store.Accounts)) {
            if ($a.Id -eq $Account.Id) { $a.LastStep = [Math]::Max([long]$a.LastStep, $Step); $a.LastUsed = $Account.LastUsed }
        }
        Save-HTMfaStore -Store $store
    }
    catch { Write-Log -Message "Nie zapisano użycia kodu MFA: $($_.Exception.Message)" -Type 'Warn' }
}

function Test-HTMfaCodeFor {
    # Kod z aplikacji dla konta: 'Ok' (poprawny, krok zapisany), 'Used' (ten kod już użyto - trzeba poczekać na następny)
    # albo 'Invalid'
    param([Parameter(Mandatory)][hashtable]$Account, [AllowEmptyString()][AllowNull()][string]$Code)
    $secret = (Get-HTMfaAccountSecret -Account $Account).Secret
    $step = Test-HTTotpCode -Secret $secret -Code $Code -LastStep ([long]$Account.LastStep)
    if ($step -eq -2) { return 'Used' }
    if ($step -lt 0) { return 'Invalid' }
    Save-HTMfaUse -Account $Account -Step $step
    return 'Ok'
}

function Get-HTMfaApprover {
    # Konto, którego kod zatwierdza zmiany kont MFA: podstawowe - kto ma tylko odblokowany program, nie dopisze sobie
    # własnego konta; bez konta podstawowego (plik zmieniony ręcznie) samo zmieniane konto
    param([object[]]$Accounts, [hashtable]$Account = $null)
    $p = @($Accounts | Where-Object { $_ -and $_.Primary -and -not $_['NoMfa'] })
    if ($p.Count) { return $p[0] }
    return $Account
}
#endregion

#region Uprawnienia kont MFA (dostęp do przestrzeni roboczych, modułów i Ustawień)
# To ograniczenie interfejsu programu: uprawnienia w usługach (Entra ID, Exchange, AD) wynikają z kont, którymi
# program łączy się z usługami, i z konta Windows, na którym działa.
function Set-HTAccessAccount {
    # Uprawnienia konta, które odblokowało program (bez listy blokad - pełny dostęp)
    param([string]$Name = '', [string]$Id = '#primary', [string[]]$Deny = @())
    $set = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($d in @($Deny)) { if ($d) { [void]$set.Add([string]$d) } }
    $script:Access.Account = $Name
    $script:Access.AccountId = $(if ($Id) { $Id } else { '#primary' })
    $script:Access.Deny = $set
    # Konto MFA w wierszach pliku dziennika (kto wykonał operację)
    $Global:HTActiveAccount = $Name
}

function Get-HTAccess { return $script:Access }

function Test-HTAccessDenied([string]$Key) { return $script:Access.Deny.Contains($Key) }

function Test-HTAppAllowed([string]$Key) { return -not $script:Access.Deny.Contains("app:$Key") }

# Tryb tylko do odczytu konta MFA: bez operacji zmieniających (akcje na obiektach i wierszach, zadania, cofanie)
function Test-HTWriteAllowed { return -not $script:Access.Deny.Contains('app:Write') }

function Get-HTAccessDenyText {
    <#
        Opis blokad do listy kont i dziennika. -Workspaces: klucz -> tytuł przestrzeni; -Modules: definicje modułów
        (Key, Title, Workspace) - nazwy zamiast kluczy; moduły w zablokowanej przestrzeni nie są wymieniane osobno.
    #>
    param([string[]]$Deny = @(), [System.Collections.IDictionary]$Workspaces = @{}, [object[]]$Modules = @())
    $list = @($Deny | Where-Object { $_ })
    $parts = New-Object System.Collections.Generic.List[string]
    $ws = @(foreach ($k in $list) {
            if ($k -like 'ws:*') { $key = $k.Substring(3); if ($Workspaces.Contains($key)) { [string]$Workspaces[$key] } else { $key } }
        })
    if ($ws.Count) { $parts.Add('bez przestrzeni: ' + ($ws -join ', ')) }
    $mods = @(foreach ($k in $list) {
            if ($k -like 'mod:*') {
                $key = $k.Substring(4)
                $d = @($Modules | Where-Object { $_ -and $_.Key -eq $key })[0]
                if (-not $d) { $key }
                elseif ($list -notcontains "ws:$($d.Workspace)") { $d.Title }
            }
        })
    if ($mods.Count) { $parts.Add($(if ($mods.Count -le 3) { 'bez modułów: ' + ($mods -join ', ') } else { "zablokowane moduły: $($mods.Count)" })) }
    if ($list -contains 'app:Settings') { $parts.Add('bez Ustawień') }
    if ($list -contains 'app:Write') { $parts.Add('tylko odczyt') }
    if (-not $parts.Count) { return 'pełny dostęp' }
    return ($parts -join '; ')
}
#endregion
