# Narzędzia programu: aktualizacja z GitHub, podpisywanie skryptów, skrót na pulpicie, profile tenantów,
# test webhooka Teams oraz polecenia palety (Ctrl+K) wspólne dla całego programu.

#region Aktualizacja programu
function Start-HTUpdateCheck {
    # Sprawdzenie w tle (przy starcie) - komunikat tylko, gdy jest nowsza wersja
    if (-not $Global:HTConfig.CheckUpdatesOnStart -or -not $Global:HTConfig.UpdateRepository) { return }
    try {
        Start-HTBackgroundTask -Modules @('Utils', 'Security', 'Integrations') -Arguments @{ Repository = [string]$Global:HTConfig.UpdateRepository; Branch = [string]$Global:HTConfig.UpdateBranch; Current = [string]$Global:AppVersion } -ScriptBlock {
            param($a)
            Test-HTUpdateAvailable -Repository $a.Repository -Branch $a.Branch -Current $a.Current
        } -OnComplete {
            param($Result, $ErrorMessage)
            $check = @($Result)[0]
            if ($ErrorMessage -or -not $check) { Write-Log -Message "Sprawdzanie aktualizacji: $ErrorMessage" -Type 'Warn'; return }
            if ($check.Error) { Write-Log -Message "Sprawdzanie aktualizacji: $($check.Error)" -Type 'Warn'; return }
            if ($check.Available) {
                Write-Log -Message "Dostępna nowa wersja programu: $($check.Latest) (obecna $($check.Current)) - Ustawienia > Aktualizacje albo Ctrl+K > «Aktualizuj program»." -Type 'Info&Notification'
                Show-HTToast "Dostępna wersja $($check.Latest) - Ctrl+K > «Aktualizuj program»." 'info' 8
            }
        }
    }
    catch { Write-Log -Message "Sprawdzanie aktualizacji: $($_.Exception.Message)" -Type 'Warn' }
}

function Invoke-HTUpdateInteractive {
    # Sprawdzenie i instalacja nowej wersji jednym kliknięciem (kopia bieżącej wersji przed nadpisaniem plików)
    if (-not (Assert-HTWriteAllowed -Operation 'Aktualizacja programu')) { return }
    Set-HTBusy -Busy $true -Text 'Sprawdzanie aktualizacji…'
    try { $check = Test-HTUpdateAvailable }
    finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
    if ($check.Error) { Show-HTWarning -Title 'Aktualizacja' -Text $check.Error; return }
    $appDir = Split-Path -Parent $Global:HTScriptPath
    if (-not $check.Available) {
        Show-HTMessage -Title 'Aktualizacja' -Tone 'ok' -Text "Masz najnowszą wersję ($($check.Current)).`nRepozytorium: $($Global:HTConfig.UpdateRepository) ($($Global:HTConfig.UpdateBranch))"
        return
    }
    if (Test-Path -LiteralPath (Join-Path $appDir '.git')) {
        Show-HTMessage -Title 'Aktualizacja' -Text "Dostępna wersja $($check.Latest) (obecna $($check.Current)).`n`nProgram działa z repozytorium git - zaktualizuj go poleceniem:`ngit -C `"$appDir`" pull"
        return
    }
    if (-not (Show-HTConfirm -Title 'Aktualizacja programu' -ConfirmText 'Aktualizuj' -Message "Zainstalować wersję $($check.Latest) (obecna $($check.Current))?`n`nPliki programu w $appDir zostaną nadpisane (kopia bieżącej wersji trafi do %LOCALAPPDATA%\HelpdeskTools\Kopie). Konfiguracja, MFA i dziennik pozostaną bez zmian.")) { return }
    Set-HTBusy -Busy $true -Text 'Pobieranie aktualizacji…'
    try {
        $backup = Install-HTUpdate -TargetDirectory $appDir
        Add-HTOperationRecord -Operation 'Aktualizacja programu' -Object "$($check.Current) → $($check.Latest)" -Details "Kopia: $backup"
    }
    catch {
        Write-Log -Message "Aktualizacja programu: $($_.Exception.Message)" -Type 'Error'
        Show-HTError 'Nie zaktualizowano programu.' $_
        return
    }
    finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
    if (Show-HTConfirm -Title 'Aktualizacja zakończona' -ConfirmText 'Uruchom ponownie' -Message "Zainstalowano wersję $($check.Latest). Uruchomić program ponownie?") { Restart-HTApplication }
}
#endregion

#region Podpisywanie skryptów i skrót na pulpicie
function Invoke-HTSigningInteractive {
    # Podpis wszystkich skryptów programu certyfikatem podpisywania kodu (zasada wykonywania AllSigned / RemoteSigned)
    $appDir = Split-Path -Parent $Global:HTScriptPath
    $certs = @(Get-HTCodeSigningCertificate)
    $cert = $null
    if ($certs.Count -eq 0) {
        $choice = Show-HTChoiceDialog -Title 'Podpisywanie skryptów' -Prompt 'Nie znaleziono certyfikatu podpisywania kodu w magazynie bieżącego użytkownika.' -Icon 'EB95' -Choices @(
            @{ Key = 'New'; Text = 'Utwórz certyfikat z podpisem własnym'; Icon = 'E8D7'; Description = 'Ważny 5 lat, dodany do zaufanych wydawców tego komputera (Windows zapyta o potwierdzenie). W firmie lepiej użyć certyfikatu z firmowego urzędu (PKI).' }
            @{ Key = 'Cancel'; Text = 'Anuluj'; Icon = 'E711' }
        )
        if ($choice -ne 'New') { return }
        try { $cert = New-HTCodeSigningCertificate -Trust }
        catch { Show-HTError 'Nie utworzono certyfikatu.' $_; return }
    }
    elseif ($certs.Count -eq 1) { $cert = $certs[0] }
    else {
        $cert = Show-HTSelectionDialog -Title 'Certyfikat podpisywania kodu' -Icon 'EB95' -Items $certs -Columns @(
            @{ Text = 'Podmiot'; Property = 'Subject' }
            @{ Text = 'Wystawca'; Property = 'Issuer' }
            @{ Text = 'Ważny do'; Expression = { param($c) $c.NotAfter.ToString('yyyy-MM-dd') } }
            @{ Text = 'Odcisk'; Property = 'Thumbprint' }
        )
        $cert = @($cert)[0]
        if (-not $cert) { return }
    }
    Set-HTBusy -Busy $true -Text 'Podpisywanie skryptów…'
    try { $rows = @(Invoke-HTScriptSigning -Path $appDir -Certificate $cert) }
    finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
    $bad = @($rows | Where-Object { $_.Stan -ne 'Valid' }).Count
    Write-Log -Message "Podpisano skrypty programu: $($rows.Count - $bad) z $($rows.Count) (certyfikat $($cert.Thumbprint))." -Type $(if ($bad) { 'Warn' } else { 'Info' })
    Show-HTDataViewer -Title 'Podpisywanie skryptów' -Data $rows -Description "Certyfikat: $($cert.Subject) • podpisane poprawnie: $($rows.Count - $bad) z $($rows.Count). Po każdej aktualizacji podpisz skrypty ponownie." -ExportName 'podpisy' -Icon 'EB95'
}

function New-HTShortcutInteractive {
    try {
        $link = New-HTDesktopShortcut -ScriptPath $Global:HTScriptPath -IconPath $Global:AppIconPath
        Show-HTMessage -Title 'Skrót na pulpicie' -Tone 'ok' -Text "Utworzono skrót: $link`n`nSkrót uruchamia program jako administrator, a okno konsoli jest ukrywane zaraz po starcie."
    }
    catch { Show-HTError 'Nie utworzono skrótu.' $_ }
}
#endregion

#region Profile tenantów i webhook Teams
function Show-HTTenantProfilesEditor {
    # Okno z poziomu Ustawień (okno modalne): dodawanie, edycja, usuwanie, import i eksport. Pełna lista - Pulpit > «Profile tenantów».
    while ($true) {
        $profiles = @(Get-HTTenantProfiles)
        $recent = @(Find-HTTenantProfiles -Profiles $profiles | Select-Object -First 8 | ForEach-Object { "• $($_.Name) - $(Get-HTTenantProfileTarget -TenantProfile $_)" })
        $list = if ($profiles.Count) { "Profili: $($profiles.Count)$(if ($profiles.Count -gt 8) { ' (ostatnio używane)' }):`n$($recent -join "`n")" } else { 'Brak zapisanych profili.' }
        $choices = @(
            @{ Key = 'Add'; Text = 'Dodaj profil…'; Icon = 'E710'; Description = 'Tenant klienta (GDAP) albo drugi własny tenant' }
            if ($profiles.Count) { @{ Key = 'Edit'; Text = 'Edytuj profil…'; Icon = 'E70F'; Description = 'Wyszukaj profil i zmień jego ustawienia' } }
            @{ Key = 'Import'; Text = 'Import z pliku CSV…'; Icon = 'E8B5'; Description = 'Wiele profili naraz (szablon: Pulpit > Profile tenantów > «Szablon CSV»)' }
            if ($profiles.Count) { @{ Key = 'Export'; Text = 'Eksport do pliku CSV…'; Icon = 'EDE1'; Description = 'Kopia profili albo przeniesienie na inny komputer' } }
            if ($profiles.Count) { @{ Key = 'Remove'; Text = 'Usuń profile…'; Icon = 'E74D'; Style = 'Danger' } }
        )
        $choice = Show-HTChoiceDialog -Title 'Profile tenantów' -Prompt $list -Icon 'E716' -Choices $choices
        switch ($choice) {
            'Add' { $edited = Edit-HTTenantProfile -New; if ($edited) { Save-HTTenantProfile -TenantProfile $edited } }
            'Edit' {
                $tp = Select-HTTenantProfile -Title 'Edytuj profil'
                if ($tp) { $edited = Edit-HTTenantProfile -TenantProfile $tp; if ($edited) { Save-HTTenantProfile -TenantProfile $edited -OriginalName $tp.Name } }
            }
            'Import' { Import-HTTenantProfilesInteractive | Out-Null }
            'Export' { Export-HTTenantProfilesInteractive }
            'Remove' {
                $rows = @($profiles | ForEach-Object { ConvertTo-HTTenantProfileRow -TenantProfile $_ })
                $sel = @(Show-HTSelectionDialog -Title 'Usuń profile' -Items $rows -Columns @(@{ Text = 'Nazwa'; Property = 'Nazwa' }, @{ Text = 'Tenant'; Property = 'Tenant' }, @{ Text = 'Notatki'; Property = 'Notatki' }) -MultiSelect -OkText 'Usuń' -Icon 'E74D')
                $names = @($sel | Where-Object { $_ } | ForEach-Object { $_.Nazwa })
                if ($names.Count -and (Show-HTConfirm -Title 'Usuń profile' -Message 'Usunąć zaznaczone profile tenantów?' -Items $names -Danger -ConfirmText 'Usuń')) {
                    Set-HTTenantProfiles -Profiles @($profiles | Where-Object { $names -notcontains $_.Name })
                }
            }
            default { return }
        }
    }
}

function Edit-HTTenantProfile {
    <#
        Formularz profilu. Zwraca znormalizowany profil albo $null. Błędy (Test-HTTenantProfile) - komunikat i formularz
        ponownie z wpisanymi wartościami. -New: nowy profil (nazwa nie może się powtarzać).
    #>
    param($TenantProfile = $null, [string]$Title = '', [switch]$New)
    $current = if ($TenantProfile) { ConvertTo-HTTenantProfile $TenantProfile } else { ConvertTo-HTTenantProfile ([PSCustomObject]@{ Gdap = $true; Services = @('Graph', 'Exchange') }) }
    $original = if ($New) { '' } else { [string]$current.Name }
    if (-not $Title) { $Title = if ($New -or -not $TenantProfile) { 'Nowy profil tenantu' } else { "Profil: $($current.Name)" } }
    while ($true) {
        $form = Show-HTFormDialog -Title $Title -Icon 'E716' -OkText 'Zapisz' -Width 660 -Description 'Ustawienia połączeń z tenantem. Bez haseł - logowanie zawsze w przeglądarce. Połączenie: przyciski w nagłówku, Ctrl+K > «Przełącz tenant» albo Pulpit > «Profile tenantów».' -Fields @(
            @{ Name = 'Name'; Label = 'Nazwa'; Required = $true; Default = $current.Name; Placeholder = 'np. Klient ABC' }
            @{ Type = 'Header'; Label = 'Microsoft 365 (Graph)' }
            @{ Name = 'TenantId'; Label = 'Tenant - domena albo ID'; Default = $current.TenantId; Placeholder = 'abc.onmicrosoft.com albo GUID' }
            @{ Name = 'Gdap'; Label = 'Tenant klienta zarządzany przez partnera (GDAP)'; Type = 'Check'; Default = [bool]$current.Gdap }
            @{ Type = 'Header'; Label = 'Exchange Online' }
            @{ Name = 'Organization'; Label = 'Organizacja Exchange (domena)'; Default = $current.Organization; Placeholder = 'abc.onmicrosoft.com' }
            @{ Name = 'PartnerAccount'; Label = 'Konto administratora partnera (GDAP)'; Default = $current.PartnerAccount; Placeholder = 'admin@partner.pl' }
            @{ Type = 'Header'; Label = 'SharePoint (PnP PowerShell)' }
            @{ Name = 'SharePointUrl'; Label = 'Adres witryny'; Default = $current.SharePointUrl; Placeholder = 'https://abc.sharepoint.com' }
            @{ Name = 'PnPClientId'; Label = 'Client ID aplikacji PnP w tym tenancie (puste - z ustawień)'; Default = $current.PnPClientId; Placeholder = '00000000-0000-0000-0000-000000000000' }
            @{ Type = 'Buttons'; Buttons = @(
                    @{ Text = 'Uzupełnij z domeny tenantu'; Icon = 'E8FB'; ToolTip = 'Organizacja Exchange i adres SharePoint z domeny klient.onmicrosoft.com'; OnClick = {
                            param($w)
                            $c = $w.Tag.Controls
                            $domain = $c['TenantId'].Control.Text.Trim()
                            if ($domain -notmatch '\.') { $domain = $c['Organization'].Control.Text.Trim() }
                            if ($domain -notmatch '\.') { Show-HTWarning 'Wpisz domenę tenantu (np. klient.onmicrosoft.com).'; return }
                            if (-not $c['Organization'].Control.Text.Trim()) { $c['Organization'].Control.Text = $domain }
                            $sp = Get-HTTenantSharePointSuggestion -Domain $domain
                            if ($sp -and -not $c['SharePointUrl'].Control.Text.Trim()) { $c['SharePointUrl'].Control.Text = $sp }
                        }
                    }
                )
            }
            @{ Type = 'Header'; Label = 'Połączenie z profilem' }
            @{ Name = 'SvcGraph'; Label = 'Microsoft 365 (Graph)'; Type = 'Check'; Default = ($current.Services -contains 'Graph') }
            @{ Name = 'SvcExchange'; Label = 'Exchange Online'; Type = 'Check'; Default = ($current.Services -contains 'Exchange') }
            @{ Name = 'SvcSharePoint'; Label = 'SharePoint'; Type = 'Check'; Default = ($current.Services -contains 'SharePoint') }
            @{ Name = 'Notes'; Label = 'Notatki'; Type = 'Multiline'; Height = 50; Default = $current.Notes; Placeholder = 'np. osoba kontaktowa, umowa' }
        )
        if (-not $form) { return $null }
        $candidate = ConvertTo-HTTenantProfile ([PSCustomObject]@{
                Name = $form.Name; TenantId = $form.TenantId; Organization = $form.Organization; PartnerAccount = $form.PartnerAccount; Gdap = [bool]$form.Gdap
                SharePointUrl = $form.SharePointUrl; PnPClientId = $form.PnPClientId; Notes = $form.Notes; LastUsed = $current.LastUsed
                Services = @(if ($form.SvcGraph) { 'Graph' }; if ($form.SvcExchange) { 'Exchange' }; if ($form.SvcSharePoint) { 'SharePoint' })
            })
        if ($candidate.Services.Count -eq 0) { $candidate.Services = @((ConvertTo-HTTenantProfile ([PSCustomObject]@{ TenantId = $candidate.TenantId; Organization = $candidate.Organization; PartnerAccount = $candidate.PartnerAccount; SharePointUrl = $candidate.SharePointUrl })).Services) }
        $problems = @(Test-HTTenantProfile -TenantProfile $candidate -Existing @(Get-HTTenantProfiles) -OriginalName $original)
        if ($problems.Count -eq 0) { return $candidate }
        Show-HTWarning ("Popraw profil:`n• " + ($problems -join "`n• "))
        $current = $candidate
    }
}

function Import-HTTenantProfilesInteractive {
    # Import profili z CSV: podgląd błędów, wybór - zastąpić czy pominąć profile o tych samych nazwach. Zwraca $true po zapisie.
    $path = Select-HTOpenFile -Title 'Import profili tenantów' -Filter 'CSV (*.csv)|*.csv|Wszystkie pliki (*.*)|*.*'
    if (-not $path) { return $false }
    try { $import = Import-HTTenantProfilesCsv -Path $path }
    catch { Show-HTError 'Nie odczytano pliku CSV.' $_; return $false }
    if ($import.Profiles.Count -eq 0) {
        Show-HTWarning ("W pliku nie ma poprawnych profili.$(if ($import.Errors.Count) { "`n`n" + (@($import.Errors | Select-Object -First 15) -join "`n") })")
        return $false
    }
    $existing = @(Get-HTTenantProfiles)
    $same = @($import.Profiles | Where-Object { $n = $_.Name; @($existing | Where-Object { $_.Name -ieq $n }).Count })
    $message = "Profile w pliku: $($import.Profiles.Count)$(if ($same.Count) { ", w tym o istniejących nazwach: $($same.Count)" })$(if ($import.Errors.Count) { ".`nPominięte wiersze z błędami: $($import.Errors.Count):`n" + (@($import.Errors | Select-Object -First 10) -join "`n") })"
    $mode = if ($same.Count) {
        Show-HTChoiceDialog -Title 'Import profili tenantów' -Prompt $message -Icon 'E8B5' -Choices @(
            @{ Key = 'Replace'; Text = 'Zastąp istniejące profile'; Icon = 'E72C'; Description = 'Profile o tych samych nazwach zostaną zastąpione danymi z pliku' }
            @{ Key = 'Skip'; Text = 'Pomiń istniejące profile'; Icon = 'E8FB'; Description = 'Zostaną dodane tylko nowe profile' }
        )
    }
    elseif (Show-HTConfirm -Title 'Import profili tenantów' -Message $message -ConfirmText 'Importuj') { 'Replace' }
    else { $null }
    if (-not $mode) { return $false }
    $merge = Merge-HTTenantProfiles -Existing $existing -Incoming $import.Profiles -Mode $mode
    Set-HTTenantProfiles -Profiles $merge.Profiles
    Write-Log -Message "Profile tenantów z pliku $(Split-Path $path -Leaf): dodane $($merge.Added), zastąpione $($merge.Replaced), pominięte $($merge.Skipped + $import.Errors.Count)." -Type 'Info&Notification'
    return $true
}

function Export-HTTenantProfilesInteractive {
    $profiles = @(Get-HTTenantProfiles)
    if ($profiles.Count -eq 0) { Show-HTWarning 'Brak profili do eksportu.'; return }
    $path = Select-HTSaveFile -Title 'Eksport profili tenantów' -Filter 'CSV (*.csv)|*.csv' -FileName ("Profile_tenantow_{0:yyyyMMdd}.csv" -f (Get-Date)) -DefaultExt '.csv'
    if (-not $path) { return }
    try { Export-HTTenantProfilesCsv -Profiles $profiles -Path $path; Show-HTToast "Zapisano profile ($($profiles.Count)): $path" 'ok' 6 }
    catch { Show-HTError 'Nie zapisano pliku.' $_ }
}

function Test-HTTeamsWebhookInteractive {
    if (-not (Get-HTTeamsWebhookUrl)) { Show-HTWarning 'Najpierw ustaw adres webhooka w Ustawieniach (sekcja «Teams i e-mail») i zapisz ustawienia.'; return }
    if (Send-HTTeamsMessage -Title 'Helpdesk Tools - test powiadomień' -Text 'Powiadomienia z programu będą publikowane na tym kanale.' -Tone 'ok' -Event 'Manual') { Show-HTToast 'Wysłano wiadomość testową na kanał Teams.' 'ok' }
    else { Show-HTWarning 'Nie wysłano wiadomości - szczegóły w dzienniku.' }
}
#endregion

function Show-HTToolsMenu {
    $choice = Show-HTChoiceDialog -Title 'Narzędzia' -Icon 'E90F' -Choices @(
        @{ Key = 'Tenants'; Text = 'Profile tenantów'; Icon = 'E716'; Description = 'Zapisane tenanty klientów (GDAP): Graph, Exchange, SharePoint - lista, import i eksport CSV' }
        @{ Key = 'Update'; Text = 'Sprawdź i zainstaluj aktualizację'; Icon = 'E895'; Description = "Repozytorium: $($Global:HTConfig.UpdateRepository) ($($Global:HTConfig.UpdateBranch))" }
        @{ Key = 'Sign'; Text = 'Podpisz skrypty programu'; Icon = 'EB95'; Description = 'Certyfikat podpisywania kodu (zasada wykonywania AllSigned)' }
        @{ Key = 'Shortcut'; Text = 'Skrót na pulpicie'; Icon = 'E8E5'; Description = 'Uruchamianie jako administrator, bez widocznego okna konsoli' }
        @{ Key = 'Teams'; Text = 'Test webhooka Teams'; Icon = 'E8F2'; Description = 'Wiadomość testowa na skonfigurowany kanał' }
    )
    switch ($choice) {
        'Tenants' { Show-HTModule -Key 'dash.tenants' }
        'Update' { Invoke-HTUpdateInteractive }
        'Sign' { Invoke-HTSigningInteractive }
        'Shortcut' { New-HTShortcutInteractive }
        'Teams' { Test-HTTeamsWebhookInteractive }
    }
}

#region Polecenia palety (Ctrl+K)
Register-HTPaletteAction -Text 'Podsumowanie do zgłoszenia' -Icon 'E8A5' -Description 'Operacje wykonane w tej sesji - tekst do ticketu' -Keywords 'ticket zgłoszenie podsumowanie raport' -Action { param($q) Show-HTOperationSummaryDialog }
Register-HTPaletteAction -Text 'Podsumowanie do zgłoszenia' -Icon 'E8A5' -Description 'Operacje dotyczące wpisanego obiektu' -NeedsQuery -Action { param($q) Show-HTOperationSummaryDialog -Object $q }
Register-HTPaletteAction -Text 'Przełącz tenant' -Icon 'E8AB' -Description 'Microsoft 365, Exchange i SharePoint z innym zapisanym tenantem (GDAP)' -Keywords 'gdap klient tenant profil' -Action { param($q) Show-HTTenantSwitch }
Register-HTPaletteAction -Text 'Połącz z tenantem' -Icon 'E716' -Description 'Profil tenantu pasujący do wpisanego tekstu (nazwa, domena, notatki)' -NeedsQuery -Action { param($q) Show-HTTenantSwitch -Query $q }
Register-HTPaletteAction -Text 'Profile tenantów' -Icon 'E716' -Description 'Lista zapisanych tenantów, import i eksport CSV' -Keywords 'gdap klient tenant profil csv' -Action { param($q) Show-HTModule -Key 'dash.tenants' }
Register-HTPaletteAction -Text 'Zablokuj program' -Icon 'E72E' -Description 'Ctrl+Shift+L' -Keywords 'blokada pin lock' -Action { param($q) Lock-HTApplication }
Register-HTPaletteAction -Text 'Generator haseł' -Icon 'E8D7' -Description 'Ctrl+G' -Keywords 'hasło password' -Action { param($q) Show-HTPasswordGenerator }
Register-HTPaletteAction -Text 'Ustawienia' -Icon 'E713' -Keywords 'konfiguracja opcje settings' -Action { param($q) if (Show-HTSettingsDialog) { Show-HTToast 'Zapisano ustawienia.' 'ok' } }
Register-HTPaletteAction -Text 'Aktualizuj program' -Icon 'E895' -Description 'Sprawdzenie nowej wersji w repozytorium' -Keywords 'aktualizacja update wersja' -Action { param($q) Invoke-HTUpdateInteractive }
Register-HTPaletteAction -Text 'Narzędzia' -Icon 'E90F' -Description 'Profile tenantów, aktualizacja, podpisywanie skryptów, skrót' -Keywords 'podpis skrót certyfikat' -Action { param($q) Show-HTToolsMenu }
Register-HTPaletteAction -Text 'Używaj modułów z OneDrive' -Icon 'E753' -Description 'Przestań pomijać folder modułów PowerShell w OneDrive (po naprawie OneDrive)' -Keywords 'onedrive moduły psmodulepath' -Action {
    param($q)
    $paths = @(@($global:HTSkippedModulePaths) + @(Get-HTSavedSkippedModulePaths) | Where-Object { $_ } | Select-Object -Unique)
    if ($paths.Count -eq 0) { Show-HTToast 'Program nie pomija żadnego folderu modułów.' 'info'; return }
    if (-not (Show-HTConfirm -Title 'Moduły PowerShell w OneDrive' -ConfirmText 'Używaj' -Message "Program przestanie pomijać folder modułów w OneDrive od następnego uruchomienia:`n$($paths -join "`n")`n`nZrób to dopiero, gdy OneDrive działa, a folder jest dostępny na tym urządzeniu.")) { return }
    Clear-HTSkippedModulePaths
    Show-HTToast 'Zapisano - folder będzie używany po ponownym uruchomieniu programu.' 'ok' 6
}
Register-HTPaletteAction -Text 'Szczegółowy dziennik (debug)' -Icon 'EBE8' -Description 'Włącz lub wyłącz wpisy diagnostyczne (zapisywane w ustawieniach)' -Keywords 'debug diagnostyka log dziennik szczegółowy' -Action {
    param($q)
    $enable = -not $Global:DebugLogging
    Set-HTConfigValue -Name 'DebugLogging' -Value $enable
    $Global:DebugLogging = $enable
    if ($enable) { Write-HTEnvironmentDebug }
    Write-Log -Message "Szczegółowy dziennik (debug): $(if ($enable) { 'włączony' } else { 'wyłączony' })." -Type 'Info&Notification'
}
Register-HTPaletteAction -Text 'Dziennik programu' -Icon 'E81C' -Description 'Ctrl+L' -Keywords 'log logi dziennik' -Action { param($q) Set-HTLogVisible $true }
Register-HTPaletteAction -Text 'Szukaj w dzienniku' -Icon 'E81C' -Description 'Wpisy dziennika z wpisanym tekstem (bieżąca sesja)' -NeedsQuery -Action {
    param($q)
    Set-HTLogVisible $true
    $HT_UI.Controls.logSearch.Text = $q
}
#endregion
