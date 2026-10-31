# Integracje programu: powiadomienia na kanał Teams (webhook), wysyłka wiadomości przez Microsoft Graph,
# aktualizacja programu z repozytorium GitHub, podpisywanie skryptów certyfikatem i skrót na pulpicie.
# Moduł nie zależy od interfejsu (okna są w GUI/Dialogs.ps1).

#region Teams (webhook kanału)
# Adres webhooka: Teams > kanał > Przepływy pracy «Publikuj w kanale po odebraniu żądania elementu webhook»
# (albo dawny łącznik «Incoming Webhook»). Treść: karta adaptacyjna - format przyjmowany przez oba rozwiązania.
function Get-HTTeamsWebhookUrl {
    if (-not $Global:HTConfig) { return "" }
    return (Unprotect-HTSecretText ([string]$Global:HTConfig.TeamsWebhookProtected))
}

function Test-HTTeamsNotify {
    # Czy powiadamiać o zdarzeniu (Offboarding, Jobs, Checklists, Manual): webhook ustawiony i zdarzenie zaznaczone w Ustawieniach
    param ([Parameter(Mandatory)][Alias('Event')][string]$NotifyEvent)
    if (-not (Get-HTTeamsWebhookUrl)) { return $false }
    if ($NotifyEvent -eq 'Manual') { return $true }
    return (@($Global:HTConfig.TeamsNotify) -contains $NotifyEvent)
}

function New-HTTeamsCard {
    param ([Parameter(Mandatory)][string]$Title, [string]$Text = '', [System.Collections.IDictionary]$Facts, [ValidateSet('', 'ok', 'warn', 'crit')][string]$Tone = '')
    $color = switch ($Tone) { 'ok' { 'Good' } 'warn' { 'Warning' } 'crit' { 'Attention' } default { 'Default' } }
    $body = New-Object System.Collections.Generic.List[object]
    $body.Add([ordered]@{ type = 'TextBlock'; text = $Title; weight = 'Bolder'; size = 'Medium'; color = $color; wrap = $true })
    if ($Text) { $body.Add([ordered]@{ type = 'TextBlock'; text = $Text; wrap = $true }) }
    if ($Facts -and $Facts.Count) {
        $body.Add([ordered]@{ type = 'FactSet'; facts = @(foreach ($k in $Facts.Keys) { [ordered]@{ title = [string]$k; value = [string]$Facts[$k] } }) })
    }
    $meta = "Helpdesk Tools $($Global:AppVersion) • $env:USERNAME$(if ($Global:HTActiveAccount) { " ($($Global:HTActiveAccount))" }) • $((Get-Date).ToString('yyyy-MM-dd HH:mm'))"
    $body.Add([ordered]@{ type = 'TextBlock'; text = $meta; isSubtle = $true; size = 'Small'; wrap = $true })
    $card = [ordered]@{ '$schema' = 'http://adaptivecards.io/schemas/adaptive-card.json'; type = 'AdaptiveCard'; version = '1.4'; body = $body.ToArray(); msteams = @{ width = 'Full' } }
    return [ordered]@{ type = 'message'; attachments = @([ordered]@{ contentType = 'application/vnd.microsoft.card.adaptive'; contentUrl = $null; content = $card }) }
}

function Send-HTTeamsMessage {
    <#
        Wiadomość na kanał Teams. -Event: zdarzenie z Ustawień (bez zaznaczenia - nic nie jest wysyłane).
        Zwraca $true po wysłaniu; błąd sieci nie przerywa operacji, tylko trafia do dziennika.
    #>
    param ([Parameter(Mandatory)][string]$Title, [string]$Text = '', [System.Collections.IDictionary]$Facts, [string]$Tone = '', [Alias('Event')][string]$NotifyEvent = 'Manual', [string]$WebhookUrl = '')
    if (-not $WebhookUrl) {
        if (-not (Test-HTTeamsNotify -NotifyEvent $NotifyEvent)) { return $false }
        $WebhookUrl = Get-HTTeamsWebhookUrl
    }
    $payload = New-HTTeamsCard -Title $Title -Text $Text -Facts $Facts -Tone $Tone
    $json = ConvertTo-Json -InputObject $payload -Depth 12 -Compress
    try {
        Invoke-RestMethod -Uri $WebhookUrl -Method Post -ContentType 'application/json; charset=utf-8' -Body ([System.Text.Encoding]::UTF8.GetBytes($json)) -TimeoutSec 20 -ErrorAction Stop | Out-Null
        Write-Log -Message "Wysłano powiadomienie Teams: $Title" -Type 'Info'
        return $true
    }
    catch {
        Write-Log -Message "Nie wysłano powiadomienia Teams ($Title): $($_.Exception.Message)" -Type 'Warn'
        return $false
    }
}
#endregion

#region Wiadomości e-mail przez Microsoft Graph
function New-HTMailAttachment {
    param ([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][byte[]]$Bytes, [string]$ContentType = 'application/octet-stream')
    return @{ Name = $Name; Bytes = $Bytes; ContentType = $ContentType }
}

function Send-HTGraphMail {
    <#
        Wiadomość HTML z załącznikami. Bez -From: z konta zalogowanego użytkownika (/me, uprawnienie Mail.Send),
        z -From: w imieniu wskazanej skrzynki (zadania automatyczne, uprawnienie aplikacji Mail.Send).
        Załączniki łącznie do ok. 3 MB (limit pojedynczego żądania Graph).
    #>
    param (
        [Parameter(Mandatory)][string[]]$To,
        [Parameter(Mandatory)][string]$Subject,
        [Parameter(Mandatory)][AllowEmptyString()][string]$HtmlBody,
        [object[]]$Attachments = @(),
        [string]$From = ''
    )
    $recipients = @($To | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
    if ($recipients.Count -eq 0) { throw 'Podaj co najmniej jednego odbiorcę.' }
    foreach ($r in $recipients) { if ($r -notmatch '^[^@\s]+@[^@\s]+\.[^@\s]+$') { throw "Nieprawidłowy adres e-mail: $r" } }
    $total = 0
    $files = foreach ($a in @($Attachments | Where-Object { $_ })) {
        $total += $a.Bytes.Length
        @{ '@odata.type' = '#microsoft.graph.fileAttachment'; name = $a.Name; contentType = $a.ContentType; contentBytes = [Convert]::ToBase64String($a.Bytes) }
    }
    if ($total -gt 3MB) { throw "Załączniki są za duże ($([Math]::Round($total / 1MB, 1)) MB, limit ok. 3 MB) - zapisz plik i wyślij go inną drogą." }
    $message = @{
        subject      = $Subject
        body         = @{ contentType = 'HTML'; content = $HtmlBody }
        toRecipients = @($recipients | ForEach-Object { @{ emailAddress = @{ address = $_ } } })
    }
    if (@($files).Count) { $message.attachments = @($files) }
    $uri = if ($From) { "users/$([uri]::EscapeDataString($From))/sendMail" } else { 'me/sendMail' }
    Invoke-HTGraphRequest -Uri $uri -Method POST -Body @{ message = $message; saveToSentItems = $true } | Out-Null
    Write-Log -Message "Wysłano wiadomość «$Subject» do: $($recipients -join ', ')" -Type 'Info'
}
#endregion

#region Aktualizacja programu (GitHub)
function Get-HTUpdateHeaders {
    $headers = @{ 'User-Agent' = 'HelpdeskTools'; 'Accept' = 'application/vnd.github+json' }
    $token = if ($Global:HTConfig) { Unprotect-HTSecretText ([string]$Global:HTConfig.UpdateTokenProtected) } else { '' }
    if ($token) { $headers['Authorization'] = "Bearer $token" }
    return $headers
}

function Get-HTVersionFromScript {
    # Wersja z treści HelpdeskTools.ps1 ($Global:AppVersion = "x.y.z")
    param ([AllowEmptyString()][string]$Content)
    if ($Content -match '\$Global:AppVersion\s*=\s*"(\d+(\.\d+){1,3})"') { return [version]$Matches[1] }
    return $null
}

function Test-HTUpdateAvailable {
    # @{ Available; Current; Latest; Error } - porównanie z HelpdeskTools.ps1 w gałęzi repozytorium
    param ([string]$Repository = $Global:HTConfig.UpdateRepository, [string]$Branch = $Global:HTConfig.UpdateBranch, [string]$Current = $Global:AppVersion)
    $result = @{ Available = $false; Current = $Current; Latest = $null; Error = '' }
    if (-not $Repository) { $result.Error = 'Nie ustawiono repozytorium aktualizacji.'; return $result }
    try {
        $headers = Get-HTUpdateHeaders
        $headers['Accept'] = 'application/vnd.github.raw'
        $uri = "https://api.github.com/repos/$Repository/contents/HelpdeskTools.ps1?ref=$([uri]::EscapeDataString($(if ($Branch) { $Branch } else { 'main' })))"
        $content = Invoke-RestMethod -Uri $uri -Headers $headers -TimeoutSec 15 -ErrorAction Stop
        $latest = Get-HTVersionFromScript ([string]$content)
        if (-not $latest) { $result.Error = 'Nie odczytano wersji z repozytorium.'; return $result }
        $result.Latest = $latest.ToString()
        $result.Available = ($latest -gt [version]$Current)
    }
    catch {
        $result.Error = if ("$($_.Exception.Message)" -match '404|Not Found') { 'Nie znaleziono repozytorium (prywatne repozytorium wymaga tokenu w Ustawieniach > Aktualizacje).' } else { $_.Exception.Message }
    }
    return $result
}

function Install-HTUpdate {
    <#
        Pobiera gałąź repozytorium (zip), zapisuje kopię bieżącej wersji w %LOCALAPPDATA%\HelpdeskTools\Kopie i nadpisuje pliki
        programu. Dane użytkownika (konfiguracja, MFA, dziennik) są poza katalogiem programu i zostają bez zmian.
        Zwraca ścieżkę kopii zapasowej.
    #>
    param ([Parameter(Mandatory)][string]$TargetDirectory, [string]$Repository = $Global:HTConfig.UpdateRepository, [string]$Branch = $Global:HTConfig.UpdateBranch)
    if (-not (Test-Path -LiteralPath (Join-Path $TargetDirectory 'HelpdeskTools.ps1'))) { throw "W katalogu $TargetDirectory nie ma programu Helpdesk Tools." }
    if (Test-Path -LiteralPath (Join-Path $TargetDirectory '.git')) { throw 'Program działa z repozytorium git - zaktualizuj go poleceniem «git pull».' }
    $work = Join-Path ([System.IO.Path]::GetTempPath()) ("HelpdeskToolsUpdate_" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    try {
        $zip = Join-Path $work 'update.zip'
        $uri = "https://api.github.com/repos/$Repository/zipball/$([uri]::EscapeDataString($(if ($Branch) { $Branch } else { 'main' })))"
        Invoke-WebRequest -Uri $uri -Headers (Get-HTUpdateHeaders) -OutFile $zip -TimeoutSec 120 -ErrorAction Stop
        $extract = Join-Path $work 'src'
        Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force
        $root = @(Get-ChildItem -LiteralPath $extract -Directory)[0]
        if (-not $root -or -not (Test-Path -LiteralPath (Join-Path $root.FullName 'HelpdeskTools.ps1'))) { throw 'Pobrane archiwum nie zawiera programu Helpdesk Tools.' }
        $backupDir = Join-Path $env:LOCALAPPDATA 'HelpdeskTools\Kopie'
        if (-not (Test-Path -LiteralPath $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }
        $backup = Join-Path $backupDir ("HelpdeskTools_{0}_{1:yyyyMMdd_HHmmss}.zip" -f $Global:AppVersion, (Get-Date))
        Compress-Archive -Path (Join-Path $TargetDirectory '*') -DestinationPath $backup -Force
        Copy-Item -Path (Join-Path $root.FullName '*') -Destination $TargetDirectory -Recurse -Force
        Write-Log -Message "Zaktualizowano program z $Repository ($Branch). Kopia poprzedniej wersji: $backup" -Type 'Info'
        return $backup
    }
    finally { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue }
}
#endregion

#region Podpisywanie skryptów i skrót na pulpicie
function Get-HTCodeSigningCertificate {
    # Ważne certyfikaty podpisywania kodu bieżącego użytkownika (najdłużej ważny pierwszy)
    return @(Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert -ErrorAction SilentlyContinue |
            Where-Object { $_.NotAfter -gt (Get-Date) -and $_.HasPrivateKey } | Sort-Object NotAfter -Descending)
}

function New-HTCodeSigningCertificate {
    <#
        Certyfikat podpisywania kodu z podpisem własnym (5 lat). -Trust: dodanie do zaufanych wydawców i głównych urzędów
        certyfikacji bieżącego użytkownika (Windows pyta o potwierdzenie) - podpisane skrypty uruchomią się przy zasadzie AllSigned.
        W organizacji lepiej użyć certyfikatu z firmowego urzędu certyfikacji.
    #>
    param ([string]$Subject = 'CN=Helpdesk Tools - podpis skryptów', [switch]$Trust)
    $cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject $Subject -CertStoreLocation Cert:\CurrentUser\My -KeyUsage DigitalSignature -KeyAlgorithm RSA -KeyLength 3072 -NotAfter (Get-Date).AddYears(5) -ErrorAction Stop
    if ($Trust) {
        $cer = Join-Path ([System.IO.Path]::GetTempPath()) ("HelpdeskToolsSigning_" + [guid]::NewGuid().ToString('N') + '.cer')
        try {
            Export-Certificate -Cert $cert -FilePath $cer -ErrorAction Stop | Out-Null
            Import-Certificate -FilePath $cer -CertStoreLocation Cert:\CurrentUser\TrustedPublisher -ErrorAction Stop | Out-Null
            Import-Certificate -FilePath $cer -CertStoreLocation Cert:\CurrentUser\Root -ErrorAction Stop | Out-Null
        }
        finally { Remove-Item -LiteralPath $cer -Force -ErrorAction SilentlyContinue }
    }
    Write-Log -Message "Utworzono certyfikat podpisywania kodu $($cert.Thumbprint) (ważny do $($cert.NotAfter.ToString('yyyy-MM-dd')))." -Type 'Info'
    return $cert
}

function Invoke-HTScriptSigning {
    # Podpisuje wszystkie skrypty programu (*.ps1, *.psm1). Zwraca wiersze: Plik, Stan, Szczegóły.
    param ([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate, [string]$TimestampServer = 'http://timestamp.digicert.com')
    $files = @(Get-ChildItem -LiteralPath $Path -Recurse -File -Include '*.ps1', '*.psm1' | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' })
    foreach ($f in $files) {
        $params = @{ FilePath = $f.FullName; Certificate = $Certificate; HashAlgorithm = 'SHA256'; ErrorAction = 'Stop' }
        if ($TimestampServer) { $params.TimestampServer = $TimestampServer }
        try {
            $sig = Set-AuthenticodeSignature @params
            [PSCustomObject]@{ Plik = $f.FullName.Substring($Path.Length).TrimStart('\', '/'); Stan = "$($sig.Status)"; Szczegóły = $sig.StatusMessage; __flag = $(if ("$($sig.Status)" -ne 'Valid') { 'warn' } else { '' }) }
        }
        catch { [PSCustomObject]@{ Plik = $f.Name; Stan = 'Błąd'; Szczegóły = $_.Exception.Message; __flag = 'crit' } }
    }
}

function New-HTDesktopShortcut {
    <#
        Skrót na pulpicie uruchamiający program jako administrator, w klasycznym oknie konsoli, które program ukrywa
        po starcie (-HideConsole). Zwraca ścieżkę skrótu.
    #>
    param ([Parameter(Mandatory)][string]$ScriptPath, [string]$Name = 'Helpdesk Tools', [string]$IconPath = '')
    $desktop = [Environment]::GetFolderPath('Desktop')
    # Pulpit w OneDrive bez działającego OneDrive nie przyjmuje zapisu - wtedy pulpit publiczny (wszyscy użytkownicy)
    if (-not (Test-HTWritableDirectory -Path $desktop)) {
        $common = [Environment]::GetFolderPath('CommonDesktopDirectory')
        Write-Log -Message "Nie można zapisać skrótu na pulpicie $desktop - użyto pulpitu publicznego $common." -Type 'Warn'
        $desktop = $common
    }
    $link = Join-Path $desktop "$Name.lnk"
    $pwsh = (Get-Process -Id $PID).Path
    $conhost = Join-Path $env:WINDIR 'System32\conhost.exe'
    $arguments = "-NoProfile -STA -File `"$ScriptPath`" -HideConsole"
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($link)
    if (Test-Path -LiteralPath $conhost) {
        # Klasyczna konsola (Windows Terminal nie pozwala ukryć swojego okna)
        $shortcut.TargetPath = $conhost
        $shortcut.Arguments = "`"$pwsh`" $arguments"
    }
    else {
        $shortcut.TargetPath = $pwsh
        $shortcut.Arguments = $arguments
    }
    $shortcut.WorkingDirectory = Split-Path -Parent $ScriptPath
    $shortcut.Description = 'Helpdesk Tools - administracja Microsoft 365'
    if ($IconPath -and (Test-Path -LiteralPath $IconPath)) { $shortcut.IconLocation = "$IconPath,0" }
    $shortcut.Save()
    # «Uruchom jako administrator»: flaga w nagłówku pliku .lnk (bajt 0x15, bit 0x20)
    $bytes = [System.IO.File]::ReadAllBytes($link)
    $bytes[0x15] = $bytes[0x15] -bor 0x20
    [System.IO.File]::WriteAllBytes($link, $bytes)
    Write-Log -Message "Utworzono skrót: $link" -Type 'Info'
    return $link
}
#endregion
