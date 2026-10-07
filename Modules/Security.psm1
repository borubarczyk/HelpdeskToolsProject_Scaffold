# PIN odblokowujący program (ekran startowy i blokada w trakcie pracy, jak w Domain Ops).
# W konfiguracji zapisywany jest tylko skrót PBKDF2-SHA256 z losową solą - nie sam PIN.
# PIN chroni przed przypadkowym użyciem programu przez osobę postronną, nie przed administratorem komputera:
# usunięcie kluczy Pin* z config.json wyłącza blokadę (przy następnym uruchomieniu program poprosi o nowy PIN).

$script:PinIterations = 100000

function Get-HTPinHash {
    param (
        [Parameter(Mandatory)][string]$Pin,
        [Parameter(Mandatory)][string]$Salt,
        [int]$Iterations = $script:PinIterations
    )
    $saltBytes = [Convert]::FromBase64String($Salt)
    $pinBytes = [System.Text.Encoding]::UTF8.GetBytes("HelpdeskTools|$Pin")
    $hash = [System.Security.Cryptography.Rfc2898DeriveBytes]::Pbkdf2($pinBytes, $saltBytes, $Iterations, [System.Security.Cryptography.HashAlgorithmName]::SHA256, 32)
    return [Convert]::ToBase64String($hash)
}

# Poprawny format PIN-u: same cyfry, długość 4-8
function Test-HTPinFormat {
    param ([AllowEmptyString()][AllowNull()][string]$Pin)
    return ($Pin -match '^\d{4,8}$')
}

# Nowy wpis PIN-u do konfiguracji: @{ PinHash; PinSalt; PinLength }
function New-HTPinRecord {
    param ([Parameter(Mandatory)][string]$Pin)
    if (-not (Test-HTPinFormat $Pin)) { throw "PIN musi składać się z 4-8 cyfr." }
    $salt = New-Object byte[] 16
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($salt)
    $saltText = [Convert]::ToBase64String($salt)
    return [ordered]@{
        PinHash   = Get-HTPinHash -Pin $Pin -Salt $saltText
        PinSalt   = $saltText
        PinLength = $Pin.Length
    }
}

# Czy w konfiguracji jest ustawiony PIN
function Test-HTPinConfigured {
    param ([object]$Config = $Global:HTConfig)
    return [bool]($Config -and $Config.PinHash -and $Config.PinSalt -and [int]$Config.PinLength -ge 4)
}

# Sprawdzenie PIN-u (porównanie w stałym czasie)
function Test-HTPin {
    param (
        [AllowEmptyString()][AllowNull()][string]$Pin,
        [object]$Config = $Global:HTConfig
    )
    if (-not (Test-HTPinConfigured -Config $Config) -or -not (Test-HTPinFormat $Pin)) { return $false }
    try {
        $expected = [Convert]::FromBase64String([string]$Config.PinHash)
        $actual = [Convert]::FromBase64String((Get-HTPinHash -Pin $Pin -Salt ([string]$Config.PinSalt)))
        return [System.Security.Cryptography.CryptographicOperations]::FixedTimeEquals($expected, $actual)
    }
    catch { return $false }
}

# Zapis nowego PIN-u w konfiguracji (pamięć i plik)
function Set-HTPin {
    param ([Parameter(Mandatory)][string]$Pin)
    $record = New-HTPinRecord -Pin $Pin
    foreach ($key in $record.Keys) { Set-HTConfigValue -Name $key -Value $record[$key] }
    Write-Log -Message "Ustawiono nowy PIN programu." -Type "Info"
}
