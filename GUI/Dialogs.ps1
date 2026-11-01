# Okna: generator haseł i ustawienia aplikacji

#region Generator haseł
$script:PasswordGeneratorBody = @'
<StackPanel>
  <TextBox x:Name="pgPassword" FontFamily="Consolas" FontSize="20" MinHeight="46" Padding="10,6"/>
  <Grid Margin="0,10,0,0">
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="*"/>
      <ColumnDefinition Width="Auto"/>
    </Grid.ColumnDefinitions>
    <Border x:Name="pgTrack" Height="6" CornerRadius="3" Background="#262D39" VerticalAlignment="Center">
      <Border x:Name="pgBar" Height="6" CornerRadius="3" Background="#5E6779" HorizontalAlignment="Left" Width="0"/>
    </Border>
    <TextBlock x:Name="pgStrength" Grid.Column="1" Foreground="#8791A5" FontSize="12" Margin="12,0,0,0" VerticalAlignment="Center"/>
  </Grid>
  <TextBlock Text="TRYB" Foreground="#5E6779" FontSize="11" FontWeight="SemiBold" Margin="0,18,0,6"/>
  <StackPanel x:Name="pgModeHost" Orientation="Horizontal"/>
  <Grid Margin="0,16,0,0">
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="Auto"/>
      <ColumnDefinition Width="*"/>
      <ColumnDefinition Width="Auto"/>
    </Grid.ColumnDefinitions>
    <TextBlock Text="Długość" Foreground="#8791A5" VerticalAlignment="Center" Margin="0,0,14,0"/>
    <Slider x:Name="pgLength" Grid.Column="1" Minimum="8" Maximum="64" IsSnapToTickEnabled="True" TickFrequency="1" VerticalAlignment="Center"/>
    <TextBlock x:Name="pgLengthText" Grid.Column="2" Width="34" TextAlignment="Right" FontWeight="SemiBold" VerticalAlignment="Center"/>
  </Grid>
  <WrapPanel Margin="0,14,0,0">
    <CheckBox x:Name="pgNumbers" Content="Cyfry" IsChecked="True" Margin="0,0,18,6"/>
    <CheckBox x:Name="pgSymbols" Content="Znaki specjalne" IsChecked="True" Margin="0,0,18,6"/>
    <CheckBox x:Name="pgStartLetter" Content="Zaczyna się od litery" IsChecked="True" Margin="0,0,18,6"/>
    <CheckBox x:Name="pgNoSimilar" Content="Bez podobnych znaków (l, 1, O, 0)" IsChecked="True" Margin="0,0,18,6"/>
  </WrapPanel>
  <Grid Margin="0,8,0,0">
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="Auto"/>
      <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>
    <TextBlock Text="Znaki specjalne" Foreground="#8791A5" VerticalAlignment="Center" Margin="0,0,14,0"/>
    <TextBox x:Name="pgSpecial" Grid.Column="1" FontFamily="Consolas"/>
  </Grid>
</StackPanel>
'@

$script:PasswordGeneratorEvents = @{
    Changed = {
        param($s, $e)
        $w = [System.Windows.Window]::GetWindow($s)
        if ($w -and $w.Tag.Ready) { Update-HTGeneratedPassword -Window $w }
    }
    Typed   = {
        param($s, $e)
        $w = [System.Windows.Window]::GetWindow($s)
        if ($w -and $w.Tag.Ready) { Update-HTPasswordStrength -Window $w }
    }
}

function Show-HTPasswordGenerator {
    $w = New-HTDialog -Title 'Generator haseł' -Subtitle 'Hasło jest generowane kryptograficznie bezpiecznym generatorem liczb losowych.' -Body $script:PasswordGeneratorBody -Icon 'E8D7' -OkText 'Zamknij' -NoCancel -Width 600
    $w.Tag.Ready = $false
    $modes = Add-HTSegmented -Parent $w.FindName('pgModeHost') -Items @('Przyjazne', 'Klasyczne', 'Ze słów') -Selected $(if ($Global:PasswordUseWordBased) { 2 } else { 0 })
    $w.Tag.Modes = $modes
    foreach ($rb in $modes.Child.Children) { $rb.add_Checked($script:PasswordGeneratorEvents.Changed) }
    $length = $w.FindName('pgLength')
    $length.Value = [Math]::Max(8, [Math]::Min(64, [int]$Global:PasswordDefaultLength))
    $length.add_ValueChanged($script:PasswordGeneratorEvents.Changed)
    foreach ($n in 'pgNumbers', 'pgSymbols', 'pgStartLetter', 'pgNoSimilar') {
        $cb = $w.FindName($n)
        $cb.add_Checked($script:PasswordGeneratorEvents.Changed)
        $cb.add_Unchecked($script:PasswordGeneratorEvents.Changed)
    }
    $special = $w.FindName('pgSpecial')
    $special.Text = $Global:PasswordSpecialCharacters
    $special.add_LostFocus($script:PasswordGeneratorEvents.Changed)
    $w.FindName('pgPassword').add_TextChanged($script:PasswordGeneratorEvents.Typed)

    $extra = $w.FindName('dlgExtra')
    $generate = New-HTButton -Text 'Generuj' -Icon 'E72C' -Primary
    $generate.add_Click({ param($s, $e) Update-HTGeneratedPassword -Window ([System.Windows.Window]::GetWindow($s)) })
    $copy = New-HTButton -Text 'Kopiuj' -Icon 'E8C8'
    $copy.Margin = '8,0,0,0'
    $copy.add_Click({
            param($s, $e)
            $text = [System.Windows.Window]::GetWindow($s).FindName('pgPassword').Text
            if ($text) {
                Set-HTClipboard -Text $text -Secret
                Show-HTToast 'Hasło skopiowane (schowek zostanie wyczyszczony po 60 s).' 'ok'
            }
        })
    $mail = New-HTButton -Text 'Wyślij e-mailem' -Icon 'E715' -ToolTip 'Nowa wiadomość w domyślnym kliencie poczty (adres i temat z ustawień)'
    $mail.Margin = '8,0,0,0'
    $mail.add_Click({
            param($s, $e)
            try { Send-HTPasswordMail -Password ([System.Windows.Window]::GetWindow($s).FindName('pgPassword').Text) }
            catch { Show-HTError 'Nie udało się przygotować wiadomości.' $_ }
        })
    foreach ($b in $generate, $copy, $mail) { [void]$extra.Children.Add($b) }

    $w.Tag.Ready = $true
    Update-HTGeneratedPassword -Window $w
    Write-Log -Message 'Otwarto generator haseł' -Type 'Info'
    [void](Invoke-HTDialog $w)
}

function Update-HTGeneratedPassword {
    param([Parameter(Mandatory)]$Window)
    $length = [int]$Window.FindName('pgLength').Value
    $Window.FindName('pgLengthText').Text = [string]$length
    $mode = Get-HTSegmentIndex $Window.Tag.Modes
    $numbers = Test-HTChecked $Window.FindName('pgNumbers')
    $symbols = Test-HTChecked $Window.FindName('pgSymbols')
    $special = $Window.FindName('pgSpecial').Text
    $classic = ($mode -eq 1)
    $Window.FindName('pgStartLetter').IsEnabled = $classic
    $Window.FindName('pgNoSimilar').IsEnabled = $classic
    $Window.FindName('pgSpecial').IsEnabled = $symbols
    $password = switch ($mode) {
        2 { New-WordBasedPassword -Length $length -UseNumbers $numbers -UseSymbols $symbols -SpecialCharacters $special }
        1 {
            New-Password -Length $length -SpecialCharacters $special -IncludeNumbers $numbers -IncludeSymbols $symbols `
                -StartWithLetter (Test-HTChecked $Window.FindName('pgStartLetter')) -NoSimilarChars (Test-HTChecked $Window.FindName('pgNoSimilar'))
        }
        default { New-Password -Length $length -SpecialCharacters $special -IncludeNumbers $numbers -IncludeSymbols $symbols -FriendlyMode $true }
    }
    $Window.FindName('pgPassword').Text = $password
    if ($Global:LogPasswordGeneration) { Write-Log -Message "Wygenerowano hasło: $password" -Type 'Info' }
}

function Update-HTPasswordStrength {
    param([Parameter(Mandatory)]$Window)
    $text = $Window.FindName('pgPassword').Text
    $strength = Get-HTPasswordStrength -Password $text
    $color = switch ($strength.Score) { 1 { '#FF7A86' } 2 { '#FFC46B' } 3 { '#5EE3AE' } 4 { '#5EE3AE' } default { '#5E6779' } }
    $track = $Window.FindName('pgTrack')
    $bar = $Window.FindName('pgBar')
    $bar.Background = Get-HTBrush $color
    $width = if ($track.ActualWidth -gt 0) { $track.ActualWidth } else { 380 }
    $bar.Width = [Math]::Max(0, $width * $strength.Score / 4)
    $Window.FindName('pgStrength').Text = "$($strength.Label) • ~$($strength.Entropy) bit • $($text.Length) znaków"
}

# Wiadomość z hasłem w domyślnym kliencie poczty (mailto); opcjonalnie numer telefonu w temacie (bramka SMS)
function Send-HTPasswordMail {
    param([AllowEmptyString()][string]$Password)
    if (-not $Password) { return }
    $phone = Show-InputBox -Title 'Wyślij hasło' -Prompt 'Numer telefonu do wysłania SMS z hasłem (opcjonalnie - pozostaw puste):' -ValidationType 'Phone' -AllowEmpty -Icon 'E717'
    if ($null -eq $phone) { return }
    $cleanPhone = if ($phone) { Remove-InnerWhitespace -InputString $phone -TrimEnds } else { '' }
    $subject = ("$($Global:PasswordEmailTitle) $cleanPhone").Trim()
    $query = @()
    if ($subject) { $query += "subject=$([uri]::EscapeDataString($subject))" }
    $query += "body=$([uri]::EscapeDataString($Password))"
    Start-Process ("mailto:$($Global:PasswordEmailAdress)?" + ($query -join '&'))
    Write-Log -Message "Przygotowano e-mail z hasłem do: $($Global:PasswordEmailAdress) $(if ($cleanPhone) { "(SMS: $cleanPhone)" })" -Type 'Info'
}

# Losowe hasło wg ustawień aplikacji (reset haseł, nowe konta)
function New-HTRandomPassword {
    param([int]$Length = $Global:PasswordDefaultLength)
    if ($Length -lt 8) { $Length = 12 }
    if ($Global:PasswordUseWordBased) { return New-WordBasedPassword -Length $Length }
    return New-Password -Length $Length -StartWithLetter $true -NoSimilarChars $true
}
#endregion

#region Ustawienia
function Show-HTSettingsDialog {
    # Konto dodatkowe MFA może mieć zablokowane Ustawienia (Uprawnienia… w oknie MFA)
    if (-not (Test-HTAppAllowed 'Settings')) { Show-HTAccessDenied 'Ustawienia programu'; return $false }
    $cfg = (Merge-HTConfig -Config $Global:HTConfig).Config
    $notify = @($cfg.TeamsNotify)
    $webhookSet = [bool]$cfg.TeamsWebhookProtected
    $tokenSet = [bool]$cfg.UpdateTokenProtected
    $fields = @(
        @{ Type = 'Header'; Label = 'Aplikacja'; Icon = 'E713'; Hint = "Działanie okna, powiadomienia, eksport i dziennik. Plik konfiguracji: $Global:ConfigPath" }
        @{ Name = 'ShowNotifications'; Label = 'Pokazuj powiadomienia w oknie'; Type = 'Check'; Default = [bool]$cfg.ShowNotifications }
        @{ Name = 'ConfirmBeforeClose'; Label = 'Pytaj przed zamknięciem, gdy są aktywne połączenia'; Type = 'Check'; Default = [bool]$cfg.ConfirmBeforeClose }
        @{ Name = 'BackgroundQueries'; Label = 'Zapytania Microsoft 365 w tle (okno reaguje, przycisk «Przerwij»)'; Type = 'Check'; Default = [bool]$cfg.BackgroundQueries }
        @{ Name = 'NotifyLongOperationsSeconds'; Label = 'Powiadomienie Windows po operacji dłuższej niż (sekundy, 0 = wyłączone)'; Type = 'Number'; Default = [int]$cfg.NotifyLongOperationsSeconds; Min = 0; Max = 3600; Hint = 'Gdy okno programu nie jest aktywne: dymek w obszarze powiadomień i miganie przycisku na pasku zadań.' }
        @{ Name = 'ExportPath'; Label = 'Katalog eksportu'; Default = $cfg.ExportPath; Hint = 'Puste = Dokumenty\HelpdeskTools\Eksport' }
        @{ Name = 'LogFileMaxSizeMB'; Label = 'Maks. rozmiar pliku dziennika (MB)'; Type = 'Number'; Default = [int]$cfg.LogFileMaxSizeMB; Min = 1; Max = 100 }
        @{ Name = 'DebugLogging'; Label = 'Szczegółowy dziennik (debug) - do diagnozy problemów'; Type = 'Check'; Default = [bool]$cfg.DebugLogging; Hint = "Zapisuje m.in. zapytania Microsoft Graph z czasem odpowiedzi, kroki łączenia i logowania, wersje i ścieżki modułów oraz stos błędów. Włącz na czas diagnozy - dziennik rośnie szybciej. Plik: $Global:LogDir" }
        @{ Type = 'Buttons'; Label = 'Pliki i skróty'; Buttons = @(
                @{ Text = 'Otwórz plik konfiguracji'; Icon = 'E8E5'; OnClick = { param($w) if (Test-Path $Global:ConfigPath) { Start-Process -FilePath 'notepad.exe' -ArgumentList ('"{0}"' -f $Global:ConfigPath) } } }
                @{ Text = 'Folder konfiguracji'; Icon = 'E838'; OnClick = { param($w) if (Test-Path $Global:ConfigDir) { Start-Process -FilePath 'explorer.exe' -ArgumentList ('"{0}"' -f $Global:ConfigDir) } } }
                @{ Text = 'Skrót na pulpicie'; Icon = 'E8E5'; ToolTip = 'Uruchamianie jako administrator, bez widocznego okna konsoli'; OnClick = { param($w) New-HTShortcutInteractive } }
                @{ Text = 'Podpisz skrypty'; Icon = 'EB95'; ToolTip = 'Certyfikat podpisywania kodu (zasada wykonywania AllSigned)'; OnClick = { param($w) Invoke-HTSigningInteractive } }
            )
        }
        @{ Type = 'Header'; Label = 'Bezpieczeństwo'; Icon = 'E72E'; Hint = 'PIN, automatyczna blokada i konta MFA.' }
        @{ Name = 'AutoLockMinutes'; Label = 'Automatyczna blokada po bezczynności (minuty, 0 = wyłączona)'; Type = 'Number'; Default = [int]$cfg.AutoLockMinutes; Min = 0; Max = 480; Hint = 'Odblokowanie PIN-em (z MFA także kodem z aplikacji). Ręcznie: kłódka w nagłówku lub Ctrl+Shift+L.' }
        @{ Type = 'Info'; Label = (Get-HTMfaStatusText) }
        @{ Type = 'Buttons'; Buttons = @(
                @{ Text = 'Zmień PIN'; Icon = 'E72E'; OnClick = { param($w) Update-HTPinInteractive } }
                @{ Text = 'MFA - konta i klucze'; Icon = 'E8D7'; ToolTip = 'Włączenie MFA, konta dodatkowe, klucze i uprawnienia kont'; OnClick = { param($w) Show-HTMfaManager } }
            )
        }
        @{ Type = 'Header'; Label = 'Hasła'; Icon = 'E8D7'; Hint = 'Generator haseł, reset haseł i nowe konta.' }
        @{ Name = 'PasswordDefaultLength'; Label = 'Domyślna długość hasła'; Type = 'Number'; Default = [int]$cfg.PasswordDefaultLength; Min = 8; Max = 64 }
        @{ Name = 'PasswordSpecialCharacters'; Label = 'Znaki specjalne'; Default = $cfg.PasswordSpecialCharacters }
        @{ Name = 'PasswordUseWordBased'; Label = 'Domyślnie hasła ze słów (np. SzybkiKot42!)'; Type = 'Check'; Default = [bool]$cfg.PasswordUseWordBased }
        @{ Name = 'LogPasswordGeneration'; Label = 'Zapisuj wygenerowane hasła w dzienniku (niezalecane)'; Type = 'Check'; Default = [bool]$cfg.LogPasswordGeneration }
        @{ Name = 'PasswordEmailAdress'; Label = 'Adres e-mail do wysyłki haseł'; Default = $cfg.PasswordEmailAdress; Validation = 'Email'; Hint = 'Np. adres bramki SMS lub skrzynki zespołu.' }
        @{ Name = 'PasswordEmailTitle'; Label = 'Temat wiadomości z hasłem'; Default = $cfg.PasswordEmailTitle }
        @{ Type = 'Header'; Label = 'Microsoft 365 i Exchange'; Icon = 'E753'; Hint = 'Licencje, raporty, logowanie i uprawnienia Microsoft Graph.' }
        @{ Name = 'DefaultUsageLocation'; Label = 'Domyślna lokalizacja użycia (licencje)'; Default = $cfg.DefaultUsageLocation; Hint = 'Dwuliterowy kod kraju, np. PL.' }
        @{ Name = 'InactiveDays'; Label = 'Próg nieaktywności kont (dni)'; Type = 'Number'; Default = [int]$cfg.InactiveDays; Min = 1; Max = 3650; Hint = 'Domyślna wartość w raportach nieaktywnych kont i urządzeń.' }
        @{ Name = 'ShowSystemMailboxes'; Label = 'Pokazuj skrzynki systemowe Exchange (DiscoverySearchMailbox)'; Type = 'Check'; Default = [bool]$cfg.ShowSystemMailboxes; Hint = 'Skrzynka eDiscovery tworzona przez Microsoft - domyślnie ukryta na liście skrzynek i w raportach. Po zmianie wczytaj listę skrzynek ponownie.' }
        @{ Name = 'LoginTimeoutMinutes'; Label = 'Limit czasu logowania w przeglądarce (minuty)'; Type = 'Number'; Default = [int]$cfg.LoginTimeoutMinutes; Min = 1; Max = 60; Hint = 'Po tym czasie oczekiwanie na logowanie jest anulowane (np. gdy karta przeglądarki została zamknięta).' }
        @{ Name = 'GraphScopes'; Label = 'Uprawnienia Microsoft Graph (jedno w linii)'; Type = 'Multiline'; Default = (@($cfg.GraphScopes) -join "`r`n"); Height = 120 }
        @{ Type = 'Buttons'; Label = 'Tenanty klientów (GDAP)'; Buttons = @(
                @{ Text = 'Profile tenantów…'; Icon = 'E716'; ToolTip = 'Zapisane tenanty do szybkiego łączenia i przełączania'; OnClick = { param($w) Show-HTTenantProfilesEditor } }
            )
        }
        @{ Type = 'Header'; Label = 'SharePoint'; Icon = 'E8F1'; Hint = 'Połączenie PnP PowerShell.' }
        @{ Name = 'DefaultSharepointSite'; Label = 'Domyślna witryna'; Default = $cfg.DefaultSharepointSite; Validation = 'Url'; Hint = 'Adres witryny, np. https://firma.sharepoint.com/sites/Dzial (nie domena firma.onmicrosoft.com).' }
        @{ Name = 'LastUsedClientID'; Label = 'Client ID aplikacji PnP'; Default = "$($cfg.LastUsedClientID)"; Validation = 'Guid' }
        @{ Name = 'LogClientIDForPnP'; Label = 'Zapamiętuj ostatnio użyty Client ID'; Type = 'Check'; Default = [bool]$cfg.LogClientIDForPnP }
        @{ Type = 'Header'; Label = 'Teams i e-mail'; Icon = 'E8F2'; Hint = 'Powiadomienia na kanale Teams i skrzynka nadawcy raportów.' }
        @{ Name = 'TeamsWebhook'; Label = 'Adres webhooka kanału Teams'; Type = 'Password'; Hint = $(if ($webhookSet) { 'Zapisany (zaszyfrowany). Pozostaw puste - bez zmian.' } else { 'Teams > kanał > Przepływy pracy > «Publikuj w kanale po odebraniu żądania elementu webhook» (albo łącznik Incoming Webhook).' }) }
        if ($webhookSet) { @{ Name = 'TeamsWebhookClear'; Label = 'Usuń zapisany adres webhooka'; Type = 'Check'; Default = $false } }
        @{ Name = 'TeamsNotifyOffboarding'; Label = 'Powiadamiaj kanał o offboardingu'; Type = 'Check'; Default = ($notify -contains 'Offboarding') }
        @{ Name = 'TeamsNotifyJobs'; Label = 'Powiadamiaj o zadaniach zaplanowanych (uprawnienia tymczasowe, zaplanowany offboarding)'; Type = 'Check'; Default = ($notify -contains 'Jobs') }
        @{ Name = 'TeamsNotifyChecklists'; Label = 'Powiadamiaj o ukończonych checklistach on/offboardingu'; Type = 'Check'; Default = ($notify -contains 'Checklists') }
        @{ Type = 'Buttons'; Buttons = @(
                @{ Text = 'Wyślij wiadomość testową'; Icon = 'E8F2'; ToolTip = 'Na zapisany adres webhooka - nowy adres najpierw zapisz'; OnClick = { param($w) Test-HTTeamsWebhookInteractive } }
            )
        }
        @{ Name = 'ReportSender'; Label = 'Skrzynka nadawcy raportów zaplanowanych'; Default = $cfg.ReportSender; Validation = 'Email'; Hint = 'Raporty bez zalogowanego użytkownika (HelpdeskToolsRunner.ps1) są wysyłane z tej skrzynki. Wyniki z okna programu - z Twojej skrzynki.' }
        @{ Type = 'Header'; Label = 'Automatyzacja i Defender'; Icon = 'E823'; Hint = 'Aplikacja do pracy bez użytkownika (raporty zaplanowane, zadania) i izolacja urządzeń.' }
        @{ Name = 'AutomationClientId'; Label = 'Aplikacja automatyzacji: Client ID'; Default = $cfg.AutomationClientId; Validation = 'Guid'; Hint = 'Utworzysz ją w przestrzeni «Zadania» > Raporty zaplanowane > «Utwórz aplikację automatyzacji».' }
        @{ Name = 'AutomationTenantId'; Label = 'Aplikacja automatyzacji: Tenant ID'; Default = $cfg.AutomationTenantId }
        @{ Name = 'AutomationCertificateThumbprint'; Label = 'Odcisk certyfikatu aplikacji (magazyn CurrentUser\My)'; Default = $cfg.AutomationCertificateThumbprint }
        @{ Name = 'AutomationOrganization'; Label = 'Domena organizacji Exchange (np. firma.onmicrosoft.com)'; Default = $cfg.AutomationOrganization }
        @{ Name = 'DefenderClientId'; Label = 'Client ID aplikacji Microsoft Defender for Endpoint'; Default = $cfg.DefenderClientId; Validation = 'Guid'; Hint = 'Izolacja urządzeń: aplikacja z uprawnieniem delegowanym Machine.Isolate (WindowsDefenderATP) i adresem przekierowania http://localhost.' }
        @{ Type = 'Header'; Label = 'Aktualizacje'; Icon = 'E895'; Hint = 'Nowa wersja programu z repozytorium GitHub.' }
        @{ Name = 'CheckUpdatesOnStart'; Label = 'Sprawdzaj aktualizacje przy uruchomieniu'; Type = 'Check'; Default = [bool]$cfg.CheckUpdatesOnStart }
        @{ Name = 'UpdateRepository'; Label = 'Repozytorium GitHub (właściciel/nazwa)'; Default = $cfg.UpdateRepository }
        @{ Name = 'UpdateBranch'; Label = 'Gałąź'; Default = $cfg.UpdateBranch }
        @{ Name = 'UpdateToken'; Label = 'Token GitHub (tylko repozytorium prywatne, uprawnienie Contents: read)'; Type = 'Password'; Hint = $(if ($tokenSet) { 'Zapisany (zaszyfrowany). Pozostaw puste - bez zmian.' } else { 'Puste dla repozytorium publicznego.' }) }
        if ($tokenSet) { @{ Name = 'UpdateTokenClear'; Label = 'Usuń zapisany token'; Type = 'Check'; Default = $false } }
        @{ Type = 'Buttons'; Buttons = @(
                @{ Text = 'Sprawdź i zainstaluj aktualizację'; Icon = 'E895'; ToolTip = 'Według zapisanych ustawień repozytorium'; OnClick = { param($w) Invoke-HTUpdateInteractive } }
            )
        }
        @{ Type = 'Header'; Label = 'Funkcje lokalne'; Icon = 'E968'; Hint = 'Active Directory i inne funkcje sieci lokalnej - domyślnie ukryte.' }
        @{ Name = 'ShowOnPremises'; Label = 'Pokazuj funkcje lokalne: Active Directory (po ponownym uruchomieniu)'; Type = 'Check'; Default = [bool]$cfg.ShowOnPremises }
        if ($cfg.ShowOnPremises) { @{ Name = 'AadSyncServer'; Label = 'Serwer Microsoft Entra Connect'; Default = $cfg.AadSyncServer; Hint = 'Do uruchamiania synchronizacji delta (wymaga WinRM).' } }
    )
    $result = Show-HTFormDialog -Title 'Ustawienia' -Fields $fields -Icon 'E713' -Width 900 -MaxHeight 520 -Sections
    if (-not $result) { return $false }
    $onPremBefore = [bool]$cfg.ShowOnPremises
    # PIN mógł zostać zmieniony w trakcie (przycisk «Zmień PIN») - zachowaj aktualny zapis
    foreach ($key in 'PinHash', 'PinSalt', 'PinLength') { $cfg.$key = $Global:HTConfig.$key }
    # Profile tenantów mogły zostać zmienione w trakcie (przycisk «Profile tenantów…» w sekcji Microsoft 365 i Exchange)
    $cfg.TenantProfiles = @($Global:HTConfig.TenantProfiles)
    # Pola pomocnicze: dane poufne zapisywane w postaci zaszyfrowanej (DPAPI), zdarzenia Teams jako lista
    if ($result['TeamsWebhookClear']) { $cfg.TeamsWebhookProtected = '' }
    if ($result['TeamsWebhook']) {
        if ("$($result.TeamsWebhook)" -match '^https://') { $cfg.TeamsWebhookProtected = Protect-HTSecretText $result.TeamsWebhook }
        else { Show-HTWarning 'Adres webhooka Teams musi zaczynać się od https:// - nie zapisano adresu.' }
    }
    if ($result['UpdateTokenClear']) { $cfg.UpdateTokenProtected = '' }
    if ($result['UpdateToken']) { $cfg.UpdateTokenProtected = Protect-HTSecretText $result.UpdateToken }
    $cfg.TeamsNotify = @(foreach ($n in 'Offboarding', 'Jobs', 'Checklists') { if ($result["TeamsNotify$n"]) { $n } })
    foreach ($key in $result.Keys) {
        if ($key -match '^(TeamsWebhook|TeamsWebhookClear|UpdateToken|UpdateTokenClear|TeamsNotify(Offboarding|Jobs|Checklists))$') { continue }
        $value = $result[$key]
        if ($key -eq 'GraphScopes') { $value = @(Split-HTInputList -Text $value) }
        if ($key -eq 'LastUsedClientID' -and -not $value) { $value = $null }
        if ($key -eq 'DefaultSharepointSite' -and $value) { $value = (Resolve-HTSharePointUrl -Url $value).Url }
        $cfg.$key = $value
    }
    Set-HTConfig -Config $cfg -Path $Global:ConfigPath
    Apply-HTConfig -Config $cfg
    Write-Log -Message 'Zapisano ustawienia aplikacji.' -Type 'Info'
    if ($Global:ConnectedToGraphAPI) { Write-Log -Message 'Zmiana uprawnień Graph zacznie obowiązywać po ponownym połączeniu.' -Type 'Info' }
    if ([bool]$cfg.ShowOnPremises -ne $onPremBefore) {
        if (Show-HTConfirm -Title 'Funkcje lokalne' -ConfirmText 'Uruchom ponownie' -Message 'Zmiana widoczności funkcji lokalnych (Active Directory) wymaga ponownego uruchomienia programu. Uruchomić ponownie teraz?') { Restart-HTApplication }
    }
    return $true
}
#endregion

# Zmiana PIN-u: najpierw obecny PIN, potem nowy (dwukrotnie). Konto dodatkowe MFA zmienia własny PIN.
function Update-HTPinInteractive {
    $access = Get-HTAccess
    if ($access.AccountId -ne '#primary') {
        $account = @(Get-HTMfaUnlockAccounts | Where-Object { $_.Id -eq $access.AccountId })[0]
        if (-not $account) { Show-HTWarning 'Nie znaleziono konta MFA, które odblokowało program.'; return }
        $current = Show-InputBox -Title "Zmiana PIN-u - $($account.Name)" -Prompt 'Obecny PIN tego konta:' -Password -Icon 'E72E'
        if ($null -eq $current) { return }
        if (-not (Test-HTMfaAccountPin -Account $account -Pin $current)) {
            Write-Log -Message "Zmiana PIN-u konta «$($account.Name)»: nieprawidłowy obecny PIN." -Type 'Warn'
            Show-HTWarning 'Nieprawidłowy obecny PIN.'
            return
        }
        $pin = Show-HTPinSetupDialog -Title "Nowy PIN - $($account.Name)" -Subtitle 'PIN tego konta MFA (na ekranie blokady po wybraniu konta, razem z kodem z aplikacji).'
        if (-not $pin) { return }
        if (Test-HTPin -Pin $pin) { Show-HTWarning 'PIN konta dodatkowego musi różnić się od PIN-u programu.'; return }
        Set-HTMfaAccountPin -Id $account.Id -Pin $pin
        Write-Log -Message "Zmieniono PIN konta MFA «$($account.Name)»." -Type 'Info'
        Show-HTToast 'Zmieniono PIN.' 'ok'
        return
    }
    if (Test-HTPinConfigured) {
        $current = Show-InputBox -Title 'Zmiana PIN-u' -Prompt 'Obecny PIN:' -Password -Icon 'E72E'
        if ($null -eq $current) { return }
        if (-not (Test-HTPin -Pin $current)) {
            Write-Log -Message 'Zmiana PIN-u: nieprawidłowy obecny PIN.' -Type 'Warn'
            Show-HTWarning 'Nieprawidłowy obecny PIN.'
            return
        }
    }
    $pin = Show-HTPinSetupDialog -Title 'Nowy PIN programu'
    if (-not $pin) { return }
    Set-HTPin -Pin $pin
    Show-HTToast 'Zmieniono PIN.' 'ok'
}
