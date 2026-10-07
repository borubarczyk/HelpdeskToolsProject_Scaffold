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
    $cfg = (Merge-HTConfig -Config $Global:HTConfig).Config
    $fields = @(
        @{ Type = 'Header'; Label = 'Hasła' }
        @{ Name = 'PasswordDefaultLength'; Label = 'Domyślna długość hasła'; Type = 'Number'; Default = [int]$cfg.PasswordDefaultLength; Min = 8; Max = 64 }
        @{ Name = 'PasswordSpecialCharacters'; Label = 'Znaki specjalne'; Default = $cfg.PasswordSpecialCharacters }
        @{ Name = 'PasswordUseWordBased'; Label = 'Domyślnie hasła ze słów (np. SzybkiKot42!)'; Type = 'Check'; Default = [bool]$cfg.PasswordUseWordBased }
        @{ Name = 'LogPasswordGeneration'; Label = 'Zapisuj wygenerowane hasła w dzienniku (niezalecane)'; Type = 'Check'; Default = [bool]$cfg.LogPasswordGeneration }
        @{ Name = 'PasswordEmailAdress'; Label = 'Adres e-mail do wysyłki haseł'; Default = $cfg.PasswordEmailAdress; Validation = 'Email'; Hint = 'Np. adres bramki SMS lub skrzynki zespołu.' }
        @{ Name = 'PasswordEmailTitle'; Label = 'Temat wiadomości z hasłem'; Default = $cfg.PasswordEmailTitle }
        @{ Type = 'Header'; Label = 'Microsoft 365 i Exchange' }
        @{ Name = 'DefaultUsageLocation'; Label = 'Domyślna lokalizacja użycia (licencje)'; Default = $cfg.DefaultUsageLocation; Hint = 'Dwuliterowy kod kraju, np. PL.' }
        @{ Name = 'InactiveDays'; Label = 'Próg nieaktywności kont (dni)'; Type = 'Number'; Default = [int]$cfg.InactiveDays; Min = 1; Max = 3650; Hint = 'Domyślna wartość w raportach nieaktywnych kont i urządzeń.' }
        @{ Name = 'LoginTimeoutMinutes'; Label = 'Limit czasu logowania w przeglądarce (minuty)'; Type = 'Number'; Default = [int]$cfg.LoginTimeoutMinutes; Min = 1; Max = 60; Hint = 'Po tym czasie oczekiwanie na logowanie jest anulowane (np. gdy karta przeglądarki została zamknięta).' }
        @{ Name = 'GraphScopes'; Label = 'Uprawnienia Microsoft Graph (jedno w linii)'; Type = 'Multiline'; Default = (@($cfg.GraphScopes) -join "`r`n"); Height = 120 }
        @{ Type = 'Header'; Label = 'SharePoint' }
        @{ Name = 'DefaultSharepointSite'; Label = 'Domyślna witryna'; Default = $cfg.DefaultSharepointSite; Validation = 'Url' }
        @{ Name = 'LastUsedClientID'; Label = 'Client ID aplikacji PnP'; Default = "$($cfg.LastUsedClientID)"; Validation = 'Guid' }
        @{ Name = 'LogClientIDForPnP'; Label = 'Zapamiętuj ostatnio użyty Client ID'; Type = 'Check'; Default = [bool]$cfg.LogClientIDForPnP }
        @{ Type = 'Header'; Label = 'Active Directory' }
        @{ Name = 'AadSyncServer'; Label = 'Serwer Microsoft Entra Connect'; Default = $cfg.AadSyncServer; Hint = 'Do uruchamiania synchronizacji delta (wymaga WinRM).' }
        @{ Type = 'Header'; Label = 'Aplikacja' }
        @{ Name = 'ShowNotifications'; Label = 'Pokazuj powiadomienia w oknie'; Type = 'Check'; Default = [bool]$cfg.ShowNotifications }
        @{ Name = 'ConfirmBeforeClose'; Label = 'Pytaj przed zamknięciem, gdy są aktywne połączenia'; Type = 'Check'; Default = [bool]$cfg.ConfirmBeforeClose }
        @{ Name = 'ExportPath'; Label = 'Katalog eksportu'; Default = $cfg.ExportPath; Hint = "Puste = $(Join-Path $Global:ConfigDir 'Exports')" }
        @{ Name = 'LogFileMaxSizeMB'; Label = 'Maks. rozmiar pliku dziennika (MB)'; Type = 'Number'; Default = [int]$cfg.LogFileMaxSizeMB; Min = 1; Max = 100 }
    )
    $result = Show-HTFormDialog -Title 'Ustawienia' -Description "Plik konfiguracji: $Global:ConfigPath" -Fields $fields -Icon 'E713' -Width 640 -MaxHeight 600 -ExtraButtons @(
        @{ Text = 'Otwórz plik'; Icon = 'E8E5'; OnClick = { param($w) if (Test-Path $Global:ConfigPath) { Start-Process -FilePath 'notepad.exe' -ArgumentList ('"{0}"' -f $Global:ConfigPath) } } }
        @{ Text = 'Folder'; Icon = 'E838'; OnClick = { param($w) if (Test-Path $Global:ConfigDir) { Start-Process -FilePath 'explorer.exe' -ArgumentList ('"{0}"' -f $Global:ConfigDir) } } }
    )
    if (-not $result) { return $false }
    foreach ($key in $result.Keys) {
        $value = $result[$key]
        if ($key -eq 'GraphScopes') { $value = @(Split-HTInputList -Text $value) }
        if ($key -eq 'LastUsedClientID' -and -not $value) { $value = $null }
        $cfg.$key = $value
    }
    Set-HTConfig -Config $cfg -Path $Global:ConfigPath
    Apply-HTConfig -Config $cfg
    Write-Log -Message 'Zapisano ustawienia aplikacji.' -Type 'Info'
    if ($Global:ConnectedToGraphAPI) { Write-Log -Message 'Zmiana uprawnień Graph zacznie obowiązywać po ponownym połączeniu.' -Type 'Info' }
    return $true
}
#endregion
