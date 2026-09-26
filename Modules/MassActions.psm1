# Akcje masowe: wykonywanie tej samej operacji na liście identyfikatorów (AD, Microsoft 365, Exchange Online)
# Każda akcja definiuje:
#   Resolve { param($Id) } -> obiekt docelowy (walidacja istnienia, używana także w trybie testowym)
#   Prepare { param($Parameter) } -> przygotowany parametr (np. grupa, licencja) - wywoływane raz
#   Run { param($Target, $Prepared, $Parameter) } -> opis wyniku

# Wyszukanie użytkownika AD po UPN, e-mailu lub loginie
function Resolve-HTADUser {
    param ([Parameter(Mandatory)][string]$Identity)
    $value = $Identity.Replace("'", "''")
    $users = @(Get-ADUser -Filter "UserPrincipalName -eq '$value' -or SamAccountName -eq '$value' -or mail -eq '$value'" -ErrorAction Stop)
    if ($users.Count -eq 0) { throw "Nie znaleziono użytkownika AD: $Identity" }
    if ($users.Count -gt 1) { throw "Niejednoznaczny identyfikator (znaleziono $($users.Count) konta): $Identity" }
    return $users[0]
}

$script:ResolveAD = { param($Id) Resolve-HTADUser -Identity $Id }
$script:ResolveM365 = { param($Id) Resolve-HTM365User -Identity $Id }
$script:ResolveEXO = { param($Id) Get-EXOMailbox -Identity $Id -ErrorAction Stop }
$script:RequireParameter = { param($Parameter) if (-not $Parameter) { throw "Ta akcja wymaga parametru." }; $Parameter }

$script:MassActionDefinitions = [ordered]@{
    "AD-Disable"        = @{ Text = "AD: Wyłącz konto"; Service = "AD"; Resolve = $script:ResolveAD
        Run = { param($t) Disable-ADAccount -Identity $t.ObjectGUID -ErrorAction Stop; "Konto wyłączone" } }
    "AD-Enable"         = @{ Text = "AD: Włącz konto"; Service = "AD"; Resolve = $script:ResolveAD
        Run = { param($t) Enable-ADAccount -Identity $t.ObjectGUID -ErrorAction Stop; "Konto włączone" } }
    "AD-Unlock"         = @{ Text = "AD: Odblokuj konto"; Service = "AD"; Resolve = $script:ResolveAD
        Run = { param($t) Unlock-ADAccount -Identity $t.ObjectGUID -ErrorAction Stop; "Konto odblokowane" } }
    "AD-ResetPassword"  = @{ Text = "AD: Reset hasła (losowe, zmiana przy logowaniu)"; Service = "AD"; Resolve = $script:ResolveAD; ReturnsSecret = $true
        Run = { param($t)
            $password = New-Password -Length $Global:PasswordDefaultLength -StartWithLetter $true -NoSimilarChars $true
            Reset-HTADUserPassword -Identity $t.ObjectGUID -Password $password -ChangeAtLogon $true -Unlock $true
            "Nowe hasło: $password" } }
    "AD-AddGroup"       = @{ Text = "AD: Dodaj do grupy"; Service = "AD"; Resolve = $script:ResolveAD; ParameterLabel = "Nazwa grupy AD"
        Prepare = { param($p) Get-ADGroup -Identity (& $script:RequireParameter $p) -ErrorAction Stop }
        Run = { param($t, $g) Add-ADGroupMember -Identity $g.ObjectGUID -Members $t.ObjectGUID -ErrorAction Stop; "Dodano do grupy $($g.Name)" } }
    "AD-RemoveGroup"    = @{ Text = "AD: Usuń z grupy"; Service = "AD"; Resolve = $script:ResolveAD; ParameterLabel = "Nazwa grupy AD"
        Prepare = { param($p) Get-ADGroup -Identity (& $script:RequireParameter $p) -ErrorAction Stop }
        Run = { param($t, $g) Remove-ADGroupMember -Identity $g.ObjectGUID -Members $t.ObjectGUID -Confirm:$false -ErrorAction Stop; "Usunięto z grupy $($g.Name)" } }
    "AD-MoveOU"         = @{ Text = "AD: Przenieś do OU"; Service = "AD"; Resolve = $script:ResolveAD; ParameterLabel = "DN docelowej OU"
        Prepare = { param($p) Get-ADOrganizationalUnit -Identity (& $script:RequireParameter $p) -ErrorAction Stop }
        Run = { param($t, $ou) Move-ADObject -Identity $t.ObjectGUID -TargetPath $ou.DistinguishedName -ErrorAction Stop; "Przeniesiono do $($ou.Name)" } }

    "M365-Block"        = @{ Text = "M365: Zablokuj logowanie i unieważnij sesje"; Service = "Graph"; Resolve = $script:ResolveM365
        Run = { param($t) Set-HTM365UserEnabled -Id $t.id -Enabled $false -RevokeSessions $true; "Logowanie zablokowane" } }
    "M365-Unblock"      = @{ Text = "M365: Odblokuj logowanie"; Service = "Graph"; Resolve = $script:ResolveM365
        Run = { param($t) Set-HTM365UserEnabled -Id $t.id -Enabled $true; "Logowanie odblokowane" } }
    "M365-Revoke"       = @{ Text = "M365: Unieważnij sesje"; Service = "Graph"; Resolve = $script:ResolveM365
        Run = { param($t) Revoke-HTM365UserSessions -Id $t.id; "Sesje unieważnione" } }
    "M365-ResetPassword" = @{ Text = "M365: Reset hasła (losowe, zmiana przy logowaniu)"; Service = "Graph"; Resolve = $script:ResolveM365; ReturnsSecret = $true
        Run = { param($t)
            $password = New-Password -Length $Global:PasswordDefaultLength -StartWithLetter $true -NoSimilarChars $true
            Reset-HTM365UserPassword -Id $t.id -Password $password -ForceChange $true
            "Nowe hasło: $password" } }
    "M365-AddGroup"     = @{ Text = "M365: Dodaj do grupy"; Service = "Graph"; Resolve = $script:ResolveM365; ParameterLabel = "Nazwa lub ID grupy"
        Prepare = { param($p) Resolve-HTM365Group -Identity (& $script:RequireParameter $p) }
        Run = { param($t, $g) Add-HTM365GroupMember -GroupId $g.id -MemberId $t.id; "Dodano do grupy $($g.displayName)" } }
    "M365-RemoveGroup"  = @{ Text = "M365: Usuń z grupy"; Service = "Graph"; Resolve = $script:ResolveM365; ParameterLabel = "Nazwa lub ID grupy"
        Prepare = { param($p) Resolve-HTM365Group -Identity (& $script:RequireParameter $p) }
        Run = { param($t, $g) Remove-HTM365GroupMember -GroupId $g.id -MemberId $t.id; "Usunięto z grupy $($g.displayName)" } }
    "M365-AddLicense"   = @{ Text = "M365: Przypisz licencję"; Service = "Graph"; Resolve = $script:ResolveM365; ParameterLabel = "SkuPartNumber (np. ENTERPRISEPACK)"
        Prepare = { param($p) Resolve-HTSku -Name (& $script:RequireParameter $p) }
        Run = { param($t, $sku) Set-HTM365UserLicense -Id $t.id -AddSkuIds @($sku.SkuId); "Przypisano $($sku.SkuPartNumber)" } }
    "M365-RemoveLicense" = @{ Text = "M365: Usuń licencję"; Service = "Graph"; Resolve = $script:ResolveM365; ParameterLabel = "SkuPartNumber (np. ENTERPRISEPACK)"
        Prepare = { param($p) Resolve-HTSku -Name (& $script:RequireParameter $p) }
        Run = { param($t, $sku) Set-HTM365UserLicense -Id $t.id -RemoveSkuIds @($sku.SkuId); "Usunięto $($sku.SkuPartNumber)" } }

    "EXO-ConvertShared" = @{ Text = "Exchange: Konwertuj na skrzynkę współdzieloną"; Service = "Exchange"; Resolve = $script:ResolveEXO
        Run = { param($t) Convert-HTMailboxType -Identity "$($t.PrimarySmtpAddress)" -Type Shared; "Skonwertowano na Shared" } }
    "EXO-ConvertRegular" = @{ Text = "Exchange: Konwertuj na skrzynkę użytkownika"; Service = "Exchange"; Resolve = $script:ResolveEXO
        Run = { param($t) Convert-HTMailboxType -Identity "$($t.PrimarySmtpAddress)" -Type Regular; "Skonwertowano na Regular" } }
    "EXO-HideGAL"       = @{ Text = "Exchange: Ukryj w GAL"; Service = "Exchange"; Resolve = $script:ResolveEXO
        Run = { param($t) Set-HTMailboxHiddenFromGAL -Identity "$($t.PrimarySmtpAddress)" -Hidden $true; "Ukryto w GAL" } }
    "EXO-ShowGAL"       = @{ Text = "Exchange: Pokaż w GAL"; Service = "Exchange"; Resolve = $script:ResolveEXO
        Run = { param($t) Set-HTMailboxHiddenFromGAL -Identity "$($t.PrimarySmtpAddress)" -Hidden $false; "Widoczna w GAL" } }
    "EXO-EnableArchive" = @{ Text = "Exchange: Włącz archiwum"; Service = "Exchange"; Resolve = $script:ResolveEXO
        Run = { param($t) Enable-HTMailboxArchive -Identity "$($t.PrimarySmtpAddress)"; "Archiwum włączone" } }
    "EXO-DisableForwarding" = @{ Text = "Exchange: Wyłącz przekierowanie"; Service = "Exchange"; Resolve = $script:ResolveEXO
        Run = { param($t) Set-HTMailboxForwarding -Identity "$($t.PrimarySmtpAddress)" -ForwardTo ""; "Przekierowanie usunięte" } }
    "EXO-GrantFullAccess" = @{ Text = "Exchange: Nadaj FullAccess do skrzynek (dla użytkownika)"; Service = "Exchange"; Resolve = $script:ResolveEXO; ParameterLabel = "Użytkownik otrzymujący dostęp (e-mail)"
        Prepare = { param($p) (Get-EXORecipient -Identity (& $script:RequireParameter $p) -ErrorAction Stop).PrimarySmtpAddress }
        Run = { param($t, $user) Add-HTMailboxPermission -Identity "$($t.PrimarySmtpAddress)" -User "$user" -Type FullAccess; "Nadano FullAccess dla $user" } }
}

# Wyszukanie licencji po SkuPartNumber lub SkuId
function Resolve-HTSku {
    param ([Parameter(Mandatory)][string]$Name)
    $sku = Get-HTSubscribedSkus | Where-Object { $_.SkuPartNumber -eq $Name -or "$($_.SkuId)" -eq $Name } | Select-Object -First 1
    if (-not $sku) { throw "Nie znaleziono licencji: $Name" }
    return $sku
}

# Lista dostępnych akcji masowych
function Get-HTMassActions {
    return @($script:MassActionDefinitions.Keys | ForEach-Object {
            $d = $script:MassActionDefinitions[$_]
            [PSCustomObject]@{
                Key            = $_
                Text           = $d.Text
                Service        = $d.Service
                ParameterLabel = $d.ParameterLabel
                ReturnsSecret  = [bool]$d.ReturnsSecret
            }
        })
}

# Wykonanie akcji masowej. OnProgress: { param($Index, $Total, $Identity) }
function Invoke-HTMassAction {
    param (
        [Parameter(Mandatory)][string]$ActionKey,
        [Parameter(Mandatory)][string[]]$Identities,
        [string]$Parameter,
        [switch]$TestOnly,
        [scriptblock]$OnProgress
    )

    $definition = $script:MassActionDefinitions[$ActionKey]
    if (-not $definition) { throw "Nieznana akcja: $ActionKey" }

    $prepared = $null
    if ($definition.Prepare) { $prepared = & $definition.Prepare $Parameter }

    $results = New-Object System.Collections.Generic.List[object]
    $total = $Identities.Count
    $index = 0

    foreach ($identity in $Identities) {
        $index++
        if ($OnProgress) { & $OnProgress $index $total $identity }

        $status = "OK"
        $detail = ""
        try {
            $target = & $definition.Resolve $identity
            if ($TestOnly) {
                $status = "Test"
                $detail = "Znaleziono - akcja zostanie wykonana: $($definition.Text)"
            }
            else {
                $detail = "$(& $definition.Run $target $prepared $Parameter)"
            }
        }
        catch {
            $status = "Błąd"
            $detail = $_.Exception.Message
        }

        $logDetail = if ($definition.ReturnsSecret -and $status -eq "OK") { "Hasło zresetowane" } else { $detail }
        Write-Log -Message "Akcja masowa [$($definition.Text)] $identity -> $status $logDetail" -Type $(if ($status -eq "Błąd") { "Warn" } else { "Info" })

        $results.Add([PSCustomObject]@{
                Identity = $identity
                Status   = $status
                Detail   = $detail
                Time     = Get-Date
            })
    }

    return $results.ToArray()
}

# Odczyt identyfikatorów z pliku CSV (wskazana kolumna) lub TXT (jeden na linię)
function Import-HTIdentityFile {
    param (
        [Parameter(Mandatory)][string]$Path,
        [string]$Column
    )
    if ($Path -match '\.csv$') {
        $firstLine = Get-Content -Path $Path -TotalCount 1 -Encoding utf8
        $delimiter = if ($firstLine -match ';') { ';' } else { ',' }
        $rows = @(Import-Csv -Path $Path -Delimiter $delimiter -Encoding utf8)
        if ($rows.Count -eq 0) { return @() }
        $columns = @($rows[0].PSObject.Properties.Name)
        if (-not $Column) {
            $Column = $columns | Where-Object { $_ -match '^(UserPrincipalName|UPN|Mail|Email|E-mail|SamAccountName|Identity|Login)$' } | Select-Object -First 1
            if (-not $Column) { $Column = $columns[0] }
        }
        return @($rows | ForEach-Object { "$($_.$Column)".Trim() } | Where-Object { $_ } | Select-Object -Unique)
    }
    return Split-HTInputList -Text (Get-Content -Path $Path -Raw -Encoding utf8)
}
