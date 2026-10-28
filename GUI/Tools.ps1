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
                Write-Log -Message "Dostępna nowa wersja programu: $($check.Latest) (obecna $($check.Current)) - Ustawienia > Narzędzia > Aktualizuj program." -Type 'Info&Notification'
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
    # Lista zapisanych tenantów: dodawanie, edycja, usuwanie (zapis od razu w konfiguracji)
    while ($true) {
        $profiles = @(Get-HTTenantProfiles)
        $list = if ($profiles.Count) { (@($profiles | ForEach-Object { "• $($_.Name) - $(if ($_.TenantId) { $_.TenantId } else { $_.Organization })$(if ($_.Gdap) { ' (GDAP)' })" }) -join "`n") } else { 'Brak zapisanych profili.' }
        $choices = @(
            @{ Key = 'Add'; Text = 'Dodaj profil…'; Icon = 'E710'; Description = 'Tenant klienta (GDAP) albo drugi własny tenant' }
            if ($profiles.Count) { @{ Key = 'Edit'; Text = 'Edytuj profil…'; Icon = 'E70F' } }
            if ($profiles.Count) { @{ Key = 'Remove'; Text = 'Usuń profile…'; Icon = 'E74D'; Style = 'Danger' } }
        )
        $choice = Show-HTChoiceDialog -Title 'Profile tenantów' -Prompt $list -Icon 'E716' -Choices $choices
        switch ($choice) {
            'Add' { $edited = Edit-HTTenantProfile; if ($edited) { Save-HTTenantProfile -TenantProfile $edited } }
            'Edit' {
                $sel = @(Show-HTSelectionDialog -Title 'Edytuj profil' -Items @($profiles | ForEach-Object { [string]$_.Name }) -Icon 'E70F')[0]
                $tp = @($profiles | Where-Object { $_.Name -eq $sel })[0]
                if ($tp) {
                    $edited = Edit-HTTenantProfile -TenantProfile $tp
                    if ($edited) {
                        Set-HTConfigValue -Name 'TenantProfiles' -Value @(@($profiles | Where-Object { $_.Name -ne $tp.Name }) + [PSCustomObject]$edited)
                    }
                }
            }
            'Remove' {
                $names = @(Show-HTSelectionDialog -Title 'Usuń profile' -Items @($profiles | ForEach-Object { [string]$_.Name }) -MultiSelect -OkText 'Usuń' -Icon 'E74D')
                if ($names.Count) { Set-HTConfigValue -Name 'TenantProfiles' -Value @($profiles | Where-Object { $names -notcontains $_.Name }) }
            }
            default { return }
        }
    }
}

function Edit-HTTenantProfile {
    param($TenantProfile = $null)
    $form = Show-HTFormDialog -Title $(if ($TenantProfile) { "Profil: $($TenantProfile.Name)" } else { 'Nowy profil tenantu' }) -Icon 'E716' -OkText 'Zapisz' -Description 'Połączenie z profilem: przyciski Microsoft 365 / Exchange w nagłówku albo Ctrl+K > «Przełącz tenant».' -Fields @(
        @{ Name = 'Name'; Label = 'Nazwa'; Required = $true; Default = [string]$TenantProfile.Name; Placeholder = 'np. Klient ABC' }
        @{ Name = 'TenantId'; Label = 'ID lub domena tenantu (Microsoft 365)'; Default = [string]$TenantProfile.TenantId; Placeholder = 'abc.onmicrosoft.com albo GUID' }
        @{ Name = 'Organization'; Label = 'Domena organizacji (Exchange Online)'; Default = [string]$TenantProfile.Organization; Placeholder = 'abc.onmicrosoft.com' }
        @{ Name = 'Gdap'; Label = 'Tenant klienta zarządzany przez partnera (GDAP)'; Type = 'Check'; Default = $(if ($TenantProfile) { [bool]$TenantProfile.Gdap } else { $true }) }
        @{ Name = 'PartnerAccount'; Label = 'Konto administratora partnera (Exchange GDAP)'; Default = [string]$TenantProfile.PartnerAccount; Validation = 'Email' }
    )
    if (-not $form) { return $null }
    if (-not $form.TenantId -and -not $form.Organization) { Show-HTWarning 'Podaj ID tenantu albo domenę organizacji.'; return $null }
    return @{ Name = $form.Name; TenantId = $form.TenantId; Organization = $form.Organization; PartnerAccount = $form.PartnerAccount; Gdap = [bool]$form.Gdap }
}

function Test-HTTeamsWebhookInteractive {
    if (-not (Get-HTTeamsWebhookUrl)) { Show-HTWarning 'Najpierw ustaw adres webhooka w Ustawieniach (Integracje) i zapisz ustawienia.'; return }
    if (Send-HTTeamsMessage -Title 'Helpdesk Tools - test powiadomień' -Text 'Powiadomienia z programu będą publikowane na tym kanale.' -Tone 'ok' -Event 'Manual') { Show-HTToast 'Wysłano wiadomość testową na kanał Teams.' 'ok' }
    else { Show-HTWarning 'Nie wysłano wiadomości - szczegóły w dzienniku.' }
}
#endregion

function Show-HTToolsMenu {
    $choice = Show-HTChoiceDialog -Title 'Narzędzia' -Icon 'E90F' -Choices @(
        @{ Key = 'Tenants'; Text = 'Profile tenantów…'; Icon = 'E716'; Description = 'Zapisane tenanty klientów (GDAP) do szybkiego łączenia i przełączania' }
        @{ Key = 'Update'; Text = 'Sprawdź i zainstaluj aktualizację'; Icon = 'E895'; Description = "Repozytorium: $($Global:HTConfig.UpdateRepository) ($($Global:HTConfig.UpdateBranch))" }
        @{ Key = 'Sign'; Text = 'Podpisz skrypty programu'; Icon = 'EB95'; Description = 'Certyfikat podpisywania kodu (zasada wykonywania AllSigned)' }
        @{ Key = 'Shortcut'; Text = 'Skrót na pulpicie'; Icon = 'E8E5'; Description = 'Uruchamianie jako administrator, bez widocznego okna konsoli' }
        @{ Key = 'Teams'; Text = 'Test webhooka Teams'; Icon = 'E8F2'; Description = 'Wiadomość testowa na skonfigurowany kanał' }
    )
    switch ($choice) {
        'Tenants' { Show-HTTenantProfilesEditor }
        'Update' { Invoke-HTUpdateInteractive }
        'Sign' { Invoke-HTSigningInteractive }
        'Shortcut' { New-HTShortcutInteractive }
        'Teams' { Test-HTTeamsWebhookInteractive }
    }
}

#region Polecenia palety (Ctrl+K)
Register-HTPaletteAction -Text 'Podsumowanie do zgłoszenia' -Icon 'E8A5' -Description 'Operacje wykonane w tej sesji - tekst do ticketu' -Keywords 'ticket zgłoszenie podsumowanie raport' -Action { param($q) Show-HTOperationSummaryDialog }
Register-HTPaletteAction -Text 'Podsumowanie do zgłoszenia' -Icon 'E8A5' -Description 'Operacje dotyczące wpisanego obiektu' -NeedsQuery -Action { param($q) Show-HTOperationSummaryDialog -Object $q }
Register-HTPaletteAction -Text 'Przełącz tenant' -Icon 'E8AB' -Description 'Microsoft 365 i Exchange z innym zapisanym tenantem (GDAP)' -Keywords 'gdap klient tenant profil' -Action { param($q) Show-HTTenantSwitch }
Register-HTPaletteAction -Text 'Zablokuj program' -Icon 'E72E' -Description 'Ctrl+Shift+L' -Keywords 'blokada pin lock' -Action { param($q) Lock-HTApplication }
Register-HTPaletteAction -Text 'Generator haseł' -Icon 'E8D7' -Description 'Ctrl+G' -Keywords 'hasło password' -Action { param($q) Show-HTPasswordGenerator }
Register-HTPaletteAction -Text 'Ustawienia' -Icon 'E713' -Keywords 'konfiguracja opcje settings' -Action { param($q) if (Show-HTSettingsDialog) { Show-HTToast 'Zapisano ustawienia.' 'ok' } }
Register-HTPaletteAction -Text 'Aktualizuj program' -Icon 'E895' -Description 'Sprawdzenie nowej wersji w repozytorium' -Keywords 'aktualizacja update wersja' -Action { param($q) Invoke-HTUpdateInteractive }
Register-HTPaletteAction -Text 'Narzędzia' -Icon 'E90F' -Description 'Profile tenantów, aktualizacja, podpisywanie skryptów, skrót' -Keywords 'podpis skrót certyfikat' -Action { param($q) Show-HTToolsMenu }
Register-HTPaletteAction -Text 'Dziennik programu' -Icon 'E81C' -Description 'Ctrl+L' -Keywords 'log logi dziennik' -Action { param($q) Set-HTLogVisible $true }
Register-HTPaletteAction -Text 'Szukaj w dzienniku' -Icon 'E81C' -Description 'Wpisy dziennika z wpisanym tekstem (bieżąca sesja)' -NeedsQuery -Action {
    param($q)
    Set-HTLogVisible $true
    $HT_UI.Controls.logSearch.Text = $q
}
#endregion
