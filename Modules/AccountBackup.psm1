# Kopia ustawień konta Microsoft 365 przed offboardingiem i plan przywrócenia konta z kopii.
# Plik JSON: konto (dane, logowanie), przełożony, licencje, grupy, skrzynka (typ, GAL, przekierowanie, autoodpowiedź)
# i metody MFA (tylko informacja - metod nie da się odtworzyć, użytkownik rejestruje je ponownie). Bez haseł.

function Get-HTAccountBackupDirectory {
    # Folder kopii: <folder eksportu>\Kopie kont
    $base = if (Get-Command -Name Get-HTExportDirectory -ErrorAction Ignore) { Get-HTExportDirectory } else { [System.IO.Path]::GetTempPath() }
    return (Join-Path $base 'Kopie kont')
}

function Get-HTAccountBackupFileName {
    # Nazwa pliku kopii: Kopia_<UPN bez znaków niedozwolonych>_<data i godzina>.json
    param([Parameter(Mandatory)][string]$UserPrincipalName, [datetime]$Date = (Get-Date))
    $safe = ($UserPrincipalName -replace '[\\/:*?"<>|\s]+', '_').Trim('_')
    return "Kopia_$($safe)_$($Date.ToString('yyyyMMdd_HHmmss')).json"
}

function Save-HTAccountBackup {
    # Zapis kopii do pliku (folder kopii albo -Directory); zwraca ścieżkę
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Backup, [string]$Directory = '')
    if (-not $Directory) { $Directory = Get-HTAccountBackupDirectory }
    if (-not (Test-Path -LiteralPath $Directory)) { New-Item -ItemType Directory -Path $Directory -Force | Out-Null }
    $upn = [string]$Backup.User.UserPrincipalName
    if (-not $upn) { throw 'Kopia nie zawiera UPN konta.' }
    $path = Join-Path $Directory (Get-HTAccountBackupFileName -UserPrincipalName $upn)
    $Backup | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $path -Encoding utf8
    return $path
}

function Read-HTAccountBackup {
    # Odczyt kopii z pliku (słownik); błąd, gdy plik nie jest kopią konta
    param([Parameter(Mandatory)][string]$Path)
    $data = Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable -ErrorAction Stop
    if (-not $data -or -not $data.User -or -not $data.User.Id -or -not $data.User.UserPrincipalName) { throw 'To nie jest plik kopii ustawień konta (brak danych konta).' }
    return $data
}

function Get-HTAccountRestorePlan {
    <#
        Kroki przywrócenia konta z kopii: @{ Key; Text; Service (Graph/Exchange); Default }. Kolejność ma znaczenie:
        licencje przed zmianą skrzynki na skrzynkę użytkownika (wymaga licencji). Info - metody MFA do ponownej rejestracji.
    #>
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Backup)
    $user = $Backup.User
    $step = { param($Key, $Text, $Service, $Default = $true) [PSCustomObject]@{ Key = $Key; Text = $Text; Service = $Service; Default = [bool]$Default } }
    if ($user.AccountEnabled) { & $step 'Enable' 'Odblokuj logowanie' 'Graph' }
    & $step 'Password' 'Nowe losowe hasło (zmiana przy pierwszym logowaniu)' 'Graph'
    if ($Backup.Manager -and $Backup.Manager.Id) { & $step 'Manager' "Przełożony: $(if ($Backup.Manager.UserPrincipalName) { $Backup.Manager.UserPrincipalName } else { $Backup.Manager.Id })" 'Graph' }
    $licenses = @($Backup.Licenses | Where-Object { $_ -and $_.Direct })
    if ($licenses.Count) { & $step 'Licenses' "Licencje ($($licenses.Count)): $(@($licenses | ForEach-Object { if ($_.Name) { $_.Name } else { $_.SkuId } }) -join ', ')" 'Graph' }
    $groups = @($Backup.Groups | Where-Object { $_ -and -not $_.Dynamic -and -not $_.Synced })
    if ($groups.Count) { & $step 'Groups' "Grupy ($($groups.Count)): $(@($groups | ForEach-Object { $_.DisplayName }) -join ', ')" 'Graph' }
    $mbx = $Backup.Mailbox
    if ($mbx) {
        if ([string]$mbx.Type -eq 'UserMailbox') { & $step 'MailboxType' 'Skrzynka z powrotem jako skrzynka użytkownika (wymaga licencji)' 'Exchange' }
        if (-not $mbx.HiddenFromGAL) { & $step 'Gal' 'Pokaż w książce adresowej (GAL)' 'Exchange' }
        if ($mbx.ForwardTo) { & $step 'Forwarding' "Przekierowanie jak przed offboardingiem: $($mbx.ForwardTo)$(if ($mbx.KeepCopy) { ' (z kopią)' })" 'Exchange' }
        else { & $step 'Forwarding' 'Usuń przekierowanie poczty' 'Exchange' }
        if ([string]$mbx.AutoReplyState -eq 'Disabled') { & $step 'AutoReply' 'Wyłącz autoodpowiedź' 'Exchange' }
    }
}

function Get-HTAccountBackupSummary {
    # Krótki opis kopii (okno wyboru kroków)
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Backup)
    $created = [datetime]::MinValue
    $when = if ([datetime]::TryParse([string]$Backup.Created, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$created)) { $created.ToLocalTime().ToString('yyyy-MM-dd HH:mm') } else { [string]$Backup.Created }
    $methods = @($Backup.AuthMethods | Where-Object { $_ })
    $parts = @(
        "Konto: $($Backup.User.DisplayName) <$($Backup.User.UserPrincipalName)>"
        "Kopia z: $when$(if ($Backup.CreatedBy) { " ($($Backup.CreatedBy))" })"
        if ($methods.Count) { "Metody MFA w chwili kopii ($($methods.Count)): $(@($methods | ForEach-Object { $_.Type }) -join ', ') - użytkownik zarejestruje je ponownie (np. kodem Temporary Access Pass)." }
        if (-not $Backup.Mailbox) { 'Kopia bez danych skrzynki (brak połączenia z Exchange w chwili kopii).' }
    )
    return ($parts -join "`n")
}
