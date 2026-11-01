# Okno główne Helpdesk Tools (WPF) - układ wspólny z Domain Ops / ServerReview:
# nagłówek (logo, przestrzenie robocze, połączenia), lista obiektów | nawigacja modułów | widok modułu,
# dziennik operacji (Ctrl+L) i pasek stanu.

$script:MainXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Helpdesk Tools" Width="1680" Height="960" MinWidth="1100" MinHeight="680"
        WindowStartupLocation="CenterScreen" Background="#0F1318" Foreground="#E4E8EF"
        FontFamily="Segoe UI" FontSize="13" UseLayoutRounding="True" SnapsToDevicePixels="True"
        TextOptions.TextFormattingMode="Display">
  <Grid Background="#0F1318">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*" MinHeight="300"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition x:Name="logRow" Height="0"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <Border Background="#12171D" BorderBrush="#1E242E" BorderThickness="0,0,0,1" Padding="16,10">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <Border Width="36" Height="36" CornerRadius="10">
            <Border.Background>
              <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                <GradientStop Color="#4C7DF0" Offset="0"/>
                <GradientStop Color="#8A5CF0" Offset="1"/>
              </LinearGradientBrush>
            </Border.Background>
            <TextBlock Style="{StaticResource Glyph}" Text="&#xE90F;" FontSize="17" Foreground="White" HorizontalAlignment="Center"/>
          </Border>
          <StackPanel Margin="11,0,0,0" VerticalAlignment="Center">
            <StackPanel Orientation="Horizontal">
              <TextBlock Text="Helpdesk Tools" FontSize="15" FontWeight="SemiBold" Foreground="White"/>
              <TextBlock x:Name="txtVersion" Foreground="#5E6779" FontSize="11" Margin="7,3,0,0"/>
            </StackPanel>
            <TextBlock x:Name="txtUser" Foreground="#7B8496" FontSize="11.5"/>
          </StackPanel>
        </StackPanel>
        <Border Grid.Column="1" Style="{StaticResource SegmentHost}" Margin="30,0,0,0" VerticalAlignment="Center">
          <StackPanel x:Name="wsSwitcher" Orientation="Horizontal"/>
        </Border>
        <TextBlock x:Name="txtSubtitle" Grid.Column="2" Foreground="#5E6779" FontSize="12" VerticalAlignment="Center" Margin="18,0,12,0" TextTrimming="CharacterEllipsis"/>
        <StackPanel Grid.Column="3" Orientation="Horizontal" VerticalAlignment="Center">
          <StackPanel x:Name="connHost" Orientation="Horizontal"/>
          <Border Width="1" Height="26" Background="#242B36" Margin="8,0,6,0"/>
          <Button x:Name="btnSearch" Style="{StaticResource GhostButton}" ToolTip="Szukaj modułów i poleceń (Ctrl+K)" Margin="0,0,4,0" Padding="10,7">
            <TextBlock Style="{StaticResource Glyph}" Text="&#xE721;" FontSize="15"/>
          </Button>
          <Button x:Name="btnLock" Style="{StaticResource GhostButton}" ToolTip="Zablokuj program - odblokowanie PIN-em (Ctrl+Shift+L)" Padding="10,7">
            <TextBlock Style="{StaticResource Glyph}" Text="&#xE72E;" FontSize="15"/>
          </Button>
          <Button x:Name="btnPassword" Style="{StaticResource GhostButton}" ToolTip="Generator haseł (Ctrl+G)" Margin="4,0,0,0" Padding="10,7">
            <TextBlock Style="{StaticResource Glyph}" Text="&#xE8D7;" FontSize="15"/>
          </Button>
          <Button x:Name="btnSettings" Style="{StaticResource GhostButton}" ToolTip="Ustawienia" Margin="4,0,0,0" Padding="10,7">
            <TextBlock Style="{StaticResource Glyph}" Text="&#xE713;" FontSize="15"/>
          </Button>
        </StackPanel>
      </Grid>
    </Border>

    <Grid Grid.Row="1">
      <Grid.ColumnDefinitions>
        <ColumnDefinition x:Name="targetColumn" Width="320"/>
        <ColumnDefinition Width="248"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>
      <Grid x:Name="targetHost"/>
      <Border Grid.Column="1" BorderBrush="#1E242E" BorderThickness="0,0,1,0">
        <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
          <Grid x:Name="navHost" Margin="10,4,10,14"/>
        </ScrollViewer>
      </Border>
      <Grid Grid.Column="2">
        <Grid x:Name="contentHost" Margin="26,20,26,16"/>
        <StackPanel x:Name="toastHost" HorizontalAlignment="Right" VerticalAlignment="Bottom" Margin="0,0,26,22"/>
      </Grid>
    </Grid>

    <GridSplitter x:Name="logSplitter" Grid.Row="2" Height="5" HorizontalAlignment="Stretch" ResizeDirection="Rows"
                  ResizeBehavior="PreviousAndNext" Visibility="Collapsed"/>
    <Border x:Name="logPanel" Grid.Row="3" Background="#12171D" BorderBrush="#1E242E" BorderThickness="0,1,0,0" Visibility="Collapsed">
      <Grid>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        <Grid Margin="18,6,10,2">
          <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
            <TextBlock Text="DZIENNIK OPERACJI" Foreground="#5E6779" FontSize="11" FontWeight="SemiBold" VerticalAlignment="Center" Margin="0,0,14,0"/>
            <ComboBox x:Name="logLevel" Width="170" MinHeight="26" Padding="8,2" ToolTip="Pokaż wpisy o wybranym poziomie"/>
            <TextBox x:Name="logSearch" Width="220" MinHeight="26" Padding="8,2" Margin="8,0,0,0" Tag="Szukaj w dzienniku…" ToolTip="Fragment komunikatu lub nazwy modułu"/>
            <TextBlock x:Name="logCount" Foreground="#5E6779" FontSize="11.5" VerticalAlignment="Center" Margin="10,0,0,0"/>
          </StackPanel>
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="btnLogSummary" Style="{StaticResource GhostButton}" ToolTip="Podsumowanie do zgłoszenia - operacje wykonane w tej sesji" MinHeight="26" Padding="8,2"/>
            <Button x:Name="btnLogCopy" Style="{StaticResource GhostButton}" ToolTip="Kopiuj dziennik (zaznaczone wpisy lub wszystkie widoczne)" MinHeight="26" Padding="8,2"/>
            <Button x:Name="btnLogHistory" Style="{StaticResource GhostButton}" ToolTip="Dziennik z poprzednich dni (Pulpit > Dziennik programu)" MinHeight="26" Padding="8,2"/>
            <Button x:Name="btnLogFile" Style="{StaticResource GhostButton}" ToolTip="Otwórz dzisiejszy plik dziennika" MinHeight="26" Padding="8,2"/>
            <Button x:Name="btnLogClear" Style="{StaticResource GhostButton}" ToolTip="Wyczyść okno dziennika" MinHeight="26" Padding="8,2"/>
            <Button x:Name="btnLogHide" Style="{StaticResource GhostButton}" ToolTip="Ukryj dziennik (Ctrl+L)" MinHeight="26" Padding="8,2"/>
          </StackPanel>
        </Grid>
        <ListBox x:Name="logList" Grid.Row="1" Margin="8,0,8,6" SelectionMode="Extended" FontSize="12.5">
          <ListBox.ItemContainerStyle>
            <Style TargetType="ListBoxItem" BasedOn="{StaticResource ItemCard}">
              <Setter Property="Padding" Value="8,2"/>
              <Setter Property="Margin" Value="0"/>
            </Style>
          </ListBox.ItemContainerStyle>
          <ListBox.ItemTemplate>
            <DataTemplate>
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="62"/>
                  <ColumnDefinition Width="70"/>
                  <ColumnDefinition Width="Auto" MaxWidth="230"/>
                  <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <TextBlock Text="{Binding Time}" Foreground="#5E6779" FontFamily="Consolas" VerticalAlignment="Center"/>
                <Border x:Name="pill" Grid.Column="1" CornerRadius="8" Padding="7,0" HorizontalAlignment="Left" Background="#1E252F" VerticalAlignment="Center">
                  <TextBlock x:Name="lvl" Text="{Binding Level}" FontSize="10.5" FontWeight="SemiBold" Foreground="#AEB6C4"/>
                </Border>
                <TextBlock Grid.Column="2" Text="{Binding Module}" Foreground="#8CB0FF" Margin="0,0,12,0" TextTrimming="CharacterEllipsis" VerticalAlignment="Center"/>
                <TextBlock Grid.Column="3" Text="{Binding Message}" TextWrapping="Wrap" VerticalAlignment="Center"/>
              </Grid>
              <DataTemplate.Triggers>
                <DataTrigger Binding="{Binding Level}" Value="OK">
                  <Setter TargetName="pill" Property="Background" Value="#15291F"/>
                  <Setter TargetName="lvl" Property="Foreground" Value="#5EE3AE"/>
                </DataTrigger>
                <DataTrigger Binding="{Binding Level}" Value="WARN">
                  <Setter TargetName="pill" Property="Background" Value="#2E2616"/>
                  <Setter TargetName="lvl" Property="Foreground" Value="#FFC46B"/>
                </DataTrigger>
                <DataTrigger Binding="{Binding Level}" Value="ERROR">
                  <Setter TargetName="pill" Property="Background" Value="#2E1A1E"/>
                  <Setter TargetName="lvl" Property="Foreground" Value="#FF7A86"/>
                </DataTrigger>
              </DataTemplate.Triggers>
            </DataTemplate>
          </ListBox.ItemTemplate>
        </ListBox>
      </Grid>
    </Border>

    <Border Grid.Row="4" Background="#12171D" BorderBrush="#1E242E" BorderThickness="0,1,0,0" Padding="16,4,10,4">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <Ellipse x:Name="statusDot" Width="8" Height="8" Fill="#5EE3AE" VerticalAlignment="Center"/>
        <TextBlock x:Name="txtStatus" Grid.Column="1" Text="Gotowe" Margin="10,0,0,0" Foreground="#AEB6C4" FontSize="12" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
        <ProgressBar x:Name="prgStatus" Grid.Column="2" Width="200" Margin="12,0" VerticalAlignment="Center" Visibility="Collapsed"/>
        <Button x:Name="btnCancelOps" Grid.Column="3" Style="{StaticResource DangerButton}" MinHeight="26" Padding="10,2" Visibility="Collapsed"
                ToolTip="Przerwij (Esc): zapytanie w tle od razu, operację na wielu obiektach - po bieżącym obiekcie. Wyniki zostaną w tabeli.">
          <StackPanel Orientation="Horizontal">
            <TextBlock Style="{StaticResource Glyph}" Text="&#xE71A;" FontSize="11" Margin="0,0,7,0"/>
            <TextBlock Text="Przerwij" FontSize="12" VerticalAlignment="Center"/>
          </StackPanel>
        </Button>
        <Button x:Name="btnLogToggle" Grid.Column="4" Style="{StaticResource GhostButton}" MinHeight="26" Padding="8,2" Margin="8,0,0,0" ToolTip="Dziennik operacji (Ctrl+L)">
          <StackPanel Orientation="Horizontal">
            <TextBlock Style="{StaticResource Glyph}" Text="&#xE81C;" FontSize="12" Margin="0,0,7,0"/>
            <TextBlock Text="Dziennik" FontSize="12" VerticalAlignment="Center"/>
            <Border x:Name="logBadge" Background="#D9475A" CornerRadius="8" Padding="6,0" Margin="7,0,0,0" Visibility="Collapsed" VerticalAlignment="Center">
              <TextBlock x:Name="logBadgeText" Foreground="White" FontSize="10.5" FontWeight="SemiBold"/>
            </Border>
          </StackPanel>
        </Button>
      </Grid>
    </Border>
  </Grid>
</Window>
'@

# Przyciski połączeń w nagłówku: klucz usługi, etykieta, ikona (OnPremises - tylko przy włączonych funkcjach lokalnych)
$script:ConnectionDefs = @(
    @{ Service = 'Exchange'; Text = 'Exchange'; Icon = 'E715' }
    @{ Service = 'Graph'; Text = 'Microsoft 365'; Icon = 'E753' }
    @{ Service = 'SharePoint'; Text = 'SharePoint'; Icon = 'E8F1' }
    @{ Service = 'AD'; Text = 'Active Directory'; Icon = 'E968'; OnPremises = $true }
)

function New-HTConnectionButton {
    param([hashtable]$Definition)
    $b = New-Object System.Windows.Controls.Button
    $b.Style = Get-HTThemeResource 'GhostButton'
    $b.Padding = '9,4'
    $b.Margin = '2,0,0,0'
    $b.Tag = $Definition.Service
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = 'Horizontal'
    $dot = New-Object System.Windows.Shapes.Ellipse
    $dot.Width = 8
    $dot.Height = 8
    $dot.Margin = '0,0,9,0'
    $dot.VerticalAlignment = 'Center'
    $dot.Fill = Get-HTBrush '#5E6779'
    [void]$sp.Children.Add($dot)
    $texts = New-Object System.Windows.Controls.StackPanel
    $texts.VerticalAlignment = 'Center'
    $name = New-Object System.Windows.Controls.TextBlock
    $name.Text = $Definition.Text
    $name.FontSize = 12.5
    $name.Foreground = Get-HTBrush '#E4E8EF'
    [void]$texts.Children.Add($name)
    $sub = New-Object System.Windows.Controls.TextBlock
    $sub.Text = 'niepołączono'
    $sub.FontSize = 11
    $sub.MaxWidth = 150
    $sub.TextTrimming = 'CharacterEllipsis'
    $sub.Foreground = Get-HTBrush '#5E6779'
    [void]$texts.Children.Add($sub)
    [void]$sp.Children.Add($texts)
    $b.Content = $sp
    $b.add_Click($script:ShellEvents.ConnectionClick)
    $c = $HT_UI.Controls
    $c["dot$($Definition.Service)"] = $dot
    $c["sub$($Definition.Service)"] = $sub
    $HT_UI.ConnectButtons[$Definition.Service] = $b
    return $b
}

$script:ShellEvents = @{
    ConnectionClick = {
        param($s, $e)
        try { Invoke-HTConnectionClick -Service ([string]$s.Tag) }
        catch {
            Write-Log -Message "Błąd połączenia: $($_.Exception.Message)" -Type 'Error'
            Show-HTError 'Operacja nie powiodła się.' $_
        }
    }
    PreviewKeyDown  = {
        param($s, $e)
        try {
            # Porównania z typami wyliczeniowymi wprost: ModifierKeys ma własny konwerter tekstu
            $mods = [System.Windows.Input.Keyboard]::Modifiers
            $none = [System.Windows.Input.ModifierKeys]::None
            $ctrl = [System.Windows.Input.ModifierKeys]::Control
            $key = $e.Key
            $m = $HT_UI.ActiveModule
            if ($key -eq [System.Windows.Input.Key]::F5 -and $mods -eq $none) {
                if ($m -and $m.PrimaryButton -and $m.PrimaryButton.IsEnabled) {
                    $b = $m.PrimaryButton
                    $b.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, $b)))
                }
                $e.Handled = $true
            }
            elseif ($key -eq [System.Windows.Input.Key]::F -and $mods -eq $ctrl) {
                if ($m -and $m.FilterBox) { [void]$m.FilterBox.Focus(); $m.FilterBox.SelectAll() }
                $e.Handled = $true
            }
            elseif ($key -eq [System.Windows.Input.Key]::L -and $mods -eq ($ctrl -bor [System.Windows.Input.ModifierKeys]::Shift)) {
                $e.Handled = $true
                Lock-HTApplication
            }
            elseif ($key -eq [System.Windows.Input.Key]::L -and $mods -eq $ctrl) {
                Set-HTLogVisible (-not $HT_UI.LogVisible)
                $e.Handled = $true
            }
            elseif ($key -eq [System.Windows.Input.Key]::G -and $mods -eq $ctrl) {
                $e.Handled = $true
                Show-HTPasswordGenerator
            }
            elseif ($key -eq [System.Windows.Input.Key]::K -and $mods -eq $ctrl) {
                $e.Handled = $true
                Show-HTCommandPalette
            }
            elseif ($key -eq [System.Windows.Input.Key]::Escape -and $mods -eq $none -and $HT_UI.BusyDepth -gt 0) {
                # Esc w czasie operacji - przerwanie (jak przycisk «Przerwij»): zapytanie w tle albo pętla po obiektach
                Stop-HTBackground
            }
            elseif ($mods -eq $ctrl -and [int]$key -ge [int][System.Windows.Input.Key]::D1 -and [int]$key -le [int][System.Windows.Input.Key]::D9) {
                $index = [int]$key - [int][System.Windows.Input.Key]::D1
                $keys = @($HT_UI.Workspaces.Keys)
                if ($index -lt $keys.Count) {
                    if (Test-HTWorkspaceAllowed $keys[$index]) { Show-HTWorkspace -Key $keys[$index] }
                    else { Show-HTAccessDenied ('przestrzeń «{0}»' -f $HT_UI.Workspaces[$keys[$index]].Title) }
                }
                $e.Handled = $true
            }
        }
        catch { Write-Log -Message "Błąd skrótu klawiszowego: $($_.Exception.Message)" -Type 'Error' }
    }
    Closing         = {
        param($s, $e)
        try {
            if ($Global:HTRestarting) { return }
            # Zamknięcie awaryjne z ekranu blokady: bez pytań, połączenia z usługami są kończone
            $emergency = Test-HTEmergencyExit
            if ($HT_UI.BusyDepth -gt 0 -and -not $emergency) {
                $e.Cancel = $true
                Show-HTToast 'Trwa operacja - zaczekaj na jej zakończenie.' 'warn'
                return
            }
            $connected = @($Global:ConnectedToExchange, $Global:ConnectedToGraphAPI, $Global:ConnectedToSharepointPnP) | Where-Object { $_ }
            if ((Test-HTLocked) -and -not $emergency) { $e.Cancel = $true; return }
            if ($Global:ConfirmBeforeClose -and @($connected).Count -gt 0 -and -not $emergency) {
                if (-not (Show-HTConfirm -Message 'Zamknąć Helpdesk Tools? Aktywne połączenia z usługami zostaną zakończone.' -Title 'Zamknięcie programu' -ConfirmText 'Zamknij')) {
                    $e.Cancel = $true
                    return
                }
            }
            Write-Log -Message 'Zamykanie aplikacji...' -Type 'Info'
            Save-HTWindowPlacement -Window $s
            Remove-HTWindowsNotification
            if (@($connected).Count -gt 0) {
                Set-HTStatus -Text 'Rozłączanie usług...'
                Update-HTUi
                Set-Connections -Action 'DisconnectAll'
            }
        }
        catch { Write-Log -Message "Błąd podczas zamykania: $($_.Exception.Message)" -Type 'Warn' }
    }
}

# Filtr poziomu w panelu dziennika (Level: wartości jak w kolumnie poziomu - INFO / OK / WARN / ERROR)
$script:LogLevelFilters = @(
    @{ Text = 'Wszystkie wpisy'; Levels = @() }
    @{ Text = 'Ostrzeżenia i błędy'; Levels = @('WARN', 'ERROR') }
    @{ Text = 'Tylko błędy'; Levels = @('ERROR') }
    @{ Text = 'Wykonane (OK)'; Levels = @('OK') }
)

function Update-HTLogPanelFilter {
    $c = $HT_UI.Controls
    $index = [Math]::Max(0, $c.logLevel.SelectedIndex)
    Set-HTLogFilter -Levels $script:LogLevelFilters[$index].Levels -Text $c.logSearch.Text
}

function New-HTMainWindow {
    $w = New-HTUiElement $script:MainXaml
    $HT_UI.Window = $w
    $c = $HT_UI.Controls
    foreach ($n in 'txtVersion', 'txtUser', 'wsSwitcher', 'txtSubtitle', 'connHost', 'btnLock', 'btnPassword', 'btnSettings', 'btnSearch',
        'targetColumn', 'targetHost', 'navHost', 'contentHost', 'toastHost', 'logRow', 'logSplitter', 'logPanel', 'logList',
        'btnLogCopy', 'btnLogFile', 'btnLogClear', 'btnLogHide', 'statusDot', 'txtStatus', 'prgStatus', 'btnLogToggle',
        'logBadge', 'logBadgeText', 'logLevel', 'logSearch', 'logCount', 'btnLogHistory', 'btnLogSummary', 'btnCancelOps') {
        $c[$n] = $w.FindName($n)
    }
    $w.Title = "Helpdesk Tools $($Global:AppVersion)"
    $c.txtVersion.Text = "v$($Global:AppVersion)"
    $c.txtUser.Text = if ($env:USERDOMAIN) { "$env:USERDOMAIN\$env:USERNAME" } else { [string]$env:USERNAME }
    if ($Global:AppIconPath -and (Test-Path $Global:AppIconPath)) {
        try { $w.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create((New-Object System.Uri $Global:AppIconPath)) } catch { Write-Verbose $_ }
    }
    foreach ($def in $script:ConnectionDefs) {
        if ($def.OnPremises -and -not $Global:ShowOnPremises) { continue }
        [void]$c.connHost.Children.Add((New-HTConnectionButton -Definition $def))
    }
    $c.btnLogCopy.Content = New-HTIconContent -Text '' -Icon 'E8C8' -IconSize 12
    $c.btnLogFile.Content = New-HTIconContent -Text '' -Icon 'E8E5' -IconSize 12
    $c.btnLogClear.Content = New-HTIconContent -Text '' -Icon 'E894' -IconSize 12
    $c.btnLogHide.Content = New-HTIconContent -Text '' -Icon 'E70D' -IconSize 12
    $c.btnLogHistory.Content = New-HTIconContent -Text '' -Icon 'E81C' -IconSize 12
    $c.btnLogSummary.Content = New-HTIconContent -Text 'Do zgłoszenia' -Icon 'E8A5' -IconSize 12
    $c.logList.ItemsSource = $HT_UI.LogItems
    foreach ($level in $script:LogLevelFilters) { [void]$c.logLevel.Items.Add($level.Text) }
    $c.logLevel.SelectedIndex = 0
    $c.logLevel.add_SelectionChanged({ Update-HTLogPanelFilter })
    $c.logSearch.add_TextChanged({ Update-HTLogPanelFilter })

    # Rozmiar okna nie większy niż obszar roboczy ekranu (np. laptop 1366x768)
    $work = [System.Windows.SystemParameters]::WorkArea
    if ($work.Width -gt 0 -and $work.Height -gt 0) {
        $w.MinWidth = [Math]::Min($w.MinWidth, $work.Width)
        $w.MinHeight = [Math]::Min($w.MinHeight, $work.Height)
        $w.Width = [Math]::Min($w.Width, $work.Width)
        $w.Height = [Math]::Min($w.Height, $work.Height)
        if ($work.Width -lt 1500) { $w.WindowState = 'Maximized' }
    }

    $c.btnSearch.add_Click({ Invoke-HTUiAction -Module $null -Action { Show-HTCommandPalette } })
    $c.btnCancelOps.add_Click({ Stop-HTBackground })
    $c.btnLogSummary.add_Click({ Invoke-HTUiAction -Module $null -Action { Show-HTOperationSummaryDialog } })
    $c.btnLock.add_Click({ Invoke-HTUiAction -Module $null -Action { Lock-HTApplication } })
    $c.btnPassword.add_Click({ Invoke-HTUiAction -Module $null -Action { Show-HTPasswordGenerator } })
    $c.btnSettings.add_Click({ Invoke-HTUiAction -Module $null -Action { if (Show-HTSettingsDialog) { Show-HTToast 'Zapisano ustawienia.' 'ok' } } })
    $c.btnLogToggle.add_Click({ Set-HTLogVisible (-not $HT_UI.LogVisible) })
    $c.btnLogHide.add_Click({ Set-HTLogVisible $false })
    $c.btnLogClear.add_Click({ $HT_UI.LogItems.Clear() })
    $c.btnLogFile.add_Click({
            # Dzisiejszy plik dziennika (%LOCALAPPDATA%\HelpdeskTools\Logs), a gdy go jeszcze nie ma - folder dziennika
            $file = Get-HTLogFile
            $dir = Get-HTLogDirectory
            if ($file -and (Test-Path -LiteralPath $file)) { Start-Process -FilePath 'notepad.exe' -ArgumentList ('"{0}"' -f $file) }
            elseif ($dir -and (Test-Path -LiteralPath $dir)) { Start-Process -FilePath 'explorer.exe' -ArgumentList ('"{0}"' -f $dir) }
        })
    $c.btnLogHistory.add_Click({ Invoke-HTUiAction -Module $null -Action { Show-HTModule -Key 'dash.log' } })
    $c.btnLogCopy.add_Click({
            # Zaznaczone wpisy albo wszystkie widoczne po filtrze dziennika
            $items = @($HT_UI.Controls.logList.SelectedItems)
            if ($items.Count -le 1) { $items = @($HT_UI.Controls.logList.Items) }
            $text = (@($items | ForEach-Object { '{0} [{1}] {2}{3}' -f $_.Time, $_.Level, $(if ($_.Module) { "[$($_.Module)] " } else { '' }), $_.Message }) -join [Environment]::NewLine)
            if ($text) { Set-HTClipboard $text; Show-HTToast "Skopiowano wpisów: $($items.Count)" 'ok' }
        })
    $w.add_PreviewKeyDown($script:ShellEvents.PreviewKeyDown)
    # Aktywność użytkownika (automatyczna blokada po bezczynności; ruch kursora sprawdza licznik bezczynności)
    Register-HTIdleActivity -Window $w
    $w.add_Closing($script:ShellEvents.Closing)
    $w.add_SourceInitialized({ param($s, $e) Set-HTDarkTitleBar $s })
    Restore-HTWindowPlacement -Window $w
    $w.add_SizeChanged({ param($s, $e) try { Update-HTHeaderLayout } catch { Write-Verbose $_ } })
    $HT_UI.HeaderChanged = { Update-HTHeaderLayout }
    return $w
}

function Restore-HTWindowPlacement {
    # Położenie i rozmiar okna z poprzedniego uruchomienia (o ile mieszczą się na którymś z ekranów)
    param([Parameter(Mandatory)]$Window)
    try {
        $p = (Get-HTUiState).Window
        if (-not $p -or -not $p.Width -or -not $p.Height) { return }
        $left = [double]$p.Left; $top = [double]$p.Top; $width = [double]$p.Width; $height = [double]$p.Height
        $vLeft = [System.Windows.SystemParameters]::VirtualScreenLeft
        $vTop = [System.Windows.SystemParameters]::VirtualScreenTop
        $vRight = $vLeft + [System.Windows.SystemParameters]::VirtualScreenWidth
        $vBottom = $vTop + [System.Windows.SystemParameters]::VirtualScreenHeight
        if ($width -lt $Window.MinWidth -or $height -lt $Window.MinHeight) { return }
        # Co najmniej pasek tytułu musi być widoczny na pulpicie
        if ($left + 200 -gt $vRight -or $left + $width -lt $vLeft + 200 -or $top -lt $vTop - 10 -or $top + 60 -gt $vBottom) { return }
        $Window.WindowStartupLocation = 'Manual'
        $Window.Left = $left
        $Window.Top = $top
        $Window.Width = $width
        $Window.Height = $height
        $Window.WindowState = if ($p.State -eq 'Maximized') { 'Maximized' } else { 'Normal' }
    }
    catch { Write-Verbose "Położenie okna: $_" }
}

function Save-HTWindowPlacement {
    param([Parameter(Mandatory)]$Window)
    try {
        $bounds = $Window.RestoreBounds
        if ($bounds.IsEmpty -or $bounds.Width -le 0) { return }
        $state = Get-HTUiState
        $state.Window = @{ Left = [Math]::Round($bounds.Left); Top = [Math]::Round($bounds.Top); Width = [Math]::Round($bounds.Width); Height = [Math]::Round($bounds.Height); State = "$($Window.WindowState)" }
        if ($HT_UI.LogVisible -and $HT_UI.Controls.logRow.ActualHeight -gt 60) { $state.LogHeight = [Math]::Round($HT_UI.Controls.logRow.ActualHeight) }
        Save-HTUiState
    }
    catch { Write-Verbose "Zapis położenia okna: $_" }
}

function Set-HTHeaderMode {
    # Przestrzenie robocze z nazwą albo tylko z ikoną (pełna nazwa w podpowiedzi); podpisy tenantów przy połączeniach
    param([bool]$CompactTabs, [bool]$ShowTenants)
    foreach ($ws in $HT_UI.Workspaces.Values) {
        $content = if ($ws.Tab) { $ws.Tab.Content } else { $null }
        if ($content -is [System.Windows.Controls.Panel] -and $content.Children.Count -gt 1) {
            $content.Children[1].Visibility = if ($CompactTabs) { 'Collapsed' } else { 'Visible' }
            $content.Children[0].Margin = if ($CompactTabs) { '2,0,2,0' } else { '0,0,8,0' }
        }
    }
    foreach ($service in @($HT_UI.ConnectButtons.Keys)) {
        $sub = $HT_UI.Controls["sub$service"]
        if ($sub) { $sub.Visibility = if ($ShowTenants) { 'Visible' } else { 'Collapsed' } }
    }
}

function Measure-HTHeaderWidth {
    # Szerokość nagłówka w danym trybie (pomiar elementów, bez stałych progów)
    param([bool]$CompactTabs, [bool]$ShowTenants)
    Set-HTHeaderMode -CompactTabs $CompactTabs -ShowTenants $ShowTenants
    $inf = New-Object System.Windows.Size([double]::PositiveInfinity, [double]::PositiveInfinity)
    $c = $HT_UI.Controls
    $c.wsSwitcher.Measure($inf)
    $c.connHost.Measure($inf)
    # Logo i nazwa programu, odstępy, wyszukiwanie, kłódka, generator haseł i ustawienia
    return $c.wsSwitcher.DesiredSize.Width + $c.connHost.DesiredSize.Width + 444
}

function Update-HTHeaderLayout {
    $w = $HT_UI.Window
    if (-not $w -or $w.ActualWidth -le 0) { return }
    if (-not $HT_UI['HeaderWidths']) {
        $HT_UI.HeaderWidths = @{
            Full    = Measure-HTHeaderWidth -CompactTabs $false -ShowTenants $true
            Tabs    = Measure-HTHeaderWidth -CompactTabs $true -ShowTenants $true
            Minimal = Measure-HTHeaderWidth -CompactTabs $true -ShowTenants $false
        }
    }
    $widths = $HT_UI.HeaderWidths
    $width = $w.ActualWidth
    if ($width -ge $widths.Full) { Set-HTHeaderMode -CompactTabs $false -ShowTenants $true }
    elseif ($width -ge $widths.Tabs) { Set-HTHeaderMode -CompactTabs $true -ShowTenants $true }
    else { Set-HTHeaderMode -CompactTabs $true -ShowTenants $false }
    $HT_UI.Controls.txtSubtitle.Visibility = if ($width -ge $widths.Full + 320) { 'Visible' } else { 'Collapsed' }
}

#region Profile tenantów (szybkie połączenie z zapamiętanym tenantem, przełączanie klientów GDAP)
# Logika profili (normalizacja, walidacja, CSV) - Modules/TenantProfiles.psm1; lista i edycja - Pulpit > «Profile tenantów»
function Get-HTTenantProfiles {
    return @($Global:HTConfig.TenantProfiles | Where-Object { $_ } | ForEach-Object { ConvertTo-HTTenantProfile $_ } | Where-Object { $_.Name })
}

function Set-HTTenantProfiles {
    param([AllowEmptyCollection()][object[]]$Profiles = @())
    Set-HTConfigValue -Name 'TenantProfiles' -Value @($Profiles | Where-Object { $_ } | ForEach-Object { ConvertTo-HTTenantProfile $_ } | Sort-Object Name)
}

function Get-HTTenantProfileTarget {
    # Krótki opis profilu do list wyboru
    param($TenantProfile, [string]$Service = '')
    $p = $TenantProfile
    $target = switch ($Service) {
        'Exchange' { if ($p.Organization) { $p.Organization } else { $p.TenantId } }
        'SharePoint' { $p.SharePointUrl }
        default { if ($p.TenantId) { $p.TenantId } else { $p.Organization } }
    }
    return "$target$(if ($p.Gdap) { ' • GDAP' })$(if ($p.Notes) { " • $($p.Notes)" })"
}

function Get-HTTenantProfileChoices {
    # Ostatnio używane profile (do 5) z danymi dla usługi i «Inny profil…» (wyszukiwanie wśród wszystkich)
    param([string]$Service)
    $all = @(Get-HTTenantProfiles | Where-Object { -not $Service -or (Get-HTTenantProfileServiceStatus -TenantProfile $_ -DefaultClientId "$($Global:LastUsedClientID)")[$Service].Ready })
    $recent = @(Find-HTTenantProfiles -Profiles $all | Select-Object -First 5)
    $choices = @(foreach ($tp in $recent) {
            @{ Key = "profile:$($tp.Name)"; Text = "Profil: $($tp.Name)"; Icon = $(if ($tp.Gdap) { 'E716' } else { 'E77B' }); Description = (Get-HTTenantProfileTarget -TenantProfile $tp -Service $Service) }
        })
    if ($all.Count -gt $recent.Count) { $choices += @{ Key = 'profile:*'; Text = 'Inny profil…'; Icon = 'E721'; Description = "Wyszukaj wśród $($all.Count) profili" } }
    return $choices
}

function Resolve-HTTenantProfileChoice {
    # Profil z wyboru w oknie połączenia (profile:<nazwa> albo profile:* - wyszukiwanie); $null - to nie wybór profilu
    param([string]$Choice, [string]$Service = '')
    if ("$Choice" -eq 'profile:*') { return (Select-HTTenantProfile -Service $Service) }
    if ("$Choice" -match '^profile:(.+)$') { $name = $Matches[1]; return @(Get-HTTenantProfiles | Where-Object { $_.Name -eq $name })[0] }
    return $null
}

function Select-HTTenantProfile {
    # Wybór profilu z listy z wyszukiwaniem (-Query: gdy pasuje dokładnie jeden profil - bez okna)
    param([string]$Title = 'Wybierz profil tenantu', [string]$Query = '', [string]$Service = '')
    $profiles = @(Find-HTTenantProfiles -Profiles (Get-HTTenantProfiles) -Query $Query)
    if ($Service) { $profiles = @($profiles | Where-Object { (Get-HTTenantProfileServiceStatus -TenantProfile $_ -DefaultClientId "$($Global:LastUsedClientID)")[$Service].Ready }) }
    if ($profiles.Count -eq 0) {
        Show-HTMessage -Title 'Profile tenantów' -Text $(if ($Query) { "Brak profilu pasującego do «$Query»." } else { "Brak zapisanych profili tenantów$(if ($Service) { " z danymi dla usługi $(Get-HTTenantServiceName $Service)" }).`n`nProfile dodasz w Pulpit > «Profile tenantów» (także import z CSV)." })
        return $null
    }
    if ($Query -and $profiles.Count -eq 1) { return $profiles[0] }
    $items = @($profiles | ForEach-Object { ConvertTo-HTTenantProfileRow -TenantProfile $_ -DefaultClientId "$($Global:LastUsedClientID)" })
    $columns = @(
        @{ Text = 'Nazwa'; Property = 'Nazwa' }, @{ Text = 'Tenant'; Property = 'Tenant' }, @{ Text = 'Usługi'; Property = 'Usługi' }
        @{ Text = 'Ostatnio użyty'; Property = 'Ostatnio użyty' }, @{ Text = 'Notatki'; Property = 'Notatki' }
    )
    $selected = Show-HTSelectionDialog -Title $Title -Items $items -Columns $columns -Icon 'E716' -Prompt 'Ostatnio używane na początku.'
    if (-not $selected) { return $null }
    return @($selected)[0].__profile
}

function Select-HTTenantServices {
    # Usługi do połączenia z profilem (domyślnie zapisane w profilu); zwraca listę albo $null
    param([Parameter(Mandatory)]$TenantProfile)
    $status = Get-HTTenantProfileServiceStatus -TenantProfile $TenantProfile -DefaultClientId "$($Global:LastUsedClientID)"
    $fields = @(foreach ($service in 'Graph', 'Exchange', 'SharePoint') {
            $ready = $status[$service].Ready
            @{ Name = $service; Label = "$(Get-HTTenantServiceName $service)$(if (-not $ready) { " - $($status[$service].Reason)" } elseif ($status[$service].Reason) { " ($($status[$service].Reason))" })"; Type = 'Check'; Default = ($ready -and $TenantProfile.Services -contains $service) }
        })
    $form = Show-HTFormDialog -Title "Połącz: $($TenantProfile.Name)" -Description 'Bieżące połączenia z wybranymi usługami zostaną zakończone.' -Icon 'E716' -OkText 'Połącz' -Fields $fields
    if (-not $form) { return $null }
    $chosen = @('Graph', 'Exchange', 'SharePoint' | Where-Object { $form[$_] })
    $notReady = @($chosen | Where-Object { -not $status[$_].Ready })
    if ($notReady.Count) { Show-HTWarning "Profil nie ma danych dla: $(@($notReady | ForEach-Object { "$(Get-HTTenantServiceName $_) ($($status[$_].Reason))" }) -join ', '). Uzupełnij profil."; return $null }
    if ($chosen.Count -eq 0) { return $null }
    return $chosen
}

function Update-HTTenantProfileUsage {
    # Data ostatniego użycia profilu (sortowanie list - ostatnio używane na początku)
    param([Parameter(Mandatory)][string]$Name)
    $profiles = @(Get-HTTenantProfiles)
    foreach ($p in $profiles) { if ($p.Name -eq $Name) { $p.LastUsed = (Get-Date).ToUniversalTime().ToString('o') } }
    try { Set-HTTenantProfiles -Profiles $profiles } catch { Write-Log -Message "Nie zapisano użycia profilu: $($_.Exception.Message)" -Type 'Warn' }
}

function Connect-HTTenantProfile {
    # Połączenie z tenantem z profilu; -Services: usługi do połączenia (bieżące połączenia z innym tenantem są kończone)
    param([Parameter(Mandatory)]$TenantProfile, [string[]]$Services = @())
    $tp = ConvertTo-HTTenantProfile $TenantProfile
    if (-not $Services -or $Services.Count -eq 0) { $Services = @($tp.Services) }
    $results = [ordered]@{}
    if ('Graph' -in $Services) {
        if ($Global:ConnectedToGraphAPI) {
            Set-Connections -Action 'Disconnect' -Service 'Graph'
            Clear-HTM365Cache
            Clear-HTPanelItems -Service 'Graph'
        }
        $tenant = if ($tp.TenantId) { [string]$tp.TenantId } else { [string]$tp.Organization }
        $results.Graph = Connect-Module -Name $(if ($tp.Gdap) { 'Microsoft.GraphGDAP' } else { 'Microsoft.Graph' }) -TenantId $tenant
        if ($results.Graph) { Clear-HTM365Cache; Invoke-HTPanelAutoLoad -Service 'Graph' }
    }
    if ('Exchange' -in $Services -and ($tp.Organization -or -not $tp.Gdap)) {
        if ($Global:ConnectedToExchange) {
            Set-Connections -Action 'Disconnect' -Service 'Exchange'
            Clear-HTPanelItems -Service 'Exchange'
        }
        $results.Exchange = if ($tp.Gdap) {
            Connect-Module -Name 'ExchangeOnlineManagementGDAP' -Organization ([string]$tp.Organization) -PartnerAccount ([string]$tp.PartnerAccount)
        }
        else { Connect-Module -Name 'ExchangeOnlineManagement' }
        if ($results.Exchange) { Invoke-HTPanelAutoLoad -Service 'Exchange' }
    }
    if ('SharePoint' -in $Services -and $tp.SharePointUrl) {
        if ($Global:ConnectedToSharepointPnP) { Set-Connections -Action 'Disconnect' -Service 'SharePoint' }
        $results.SharePoint = Connect-Module -Name 'PnP.PowerShell' -SiteUrl $tp.SharePointUrl -AppClientId $tp.PnPClientId -NoPrompt
        Clear-HTPanelItems -Service 'SharePoint'
        if ($results.SharePoint) { Invoke-HTPanelAutoLoad -Service 'SharePoint' }
    }
    if ($results.Values -contains $true) {
        Update-HTTenantProfileUsage -Name $tp.Name
        Write-Log -Message "Profil tenantu «$($tp.Name)»: $(@($results.Keys | ForEach-Object { "$(Get-HTTenantServiceName $_) $(if ($results[$_]) { 'połączono' } else { 'bez połączenia' })" }) -join ', ')" -Type 'Info'
    }
    return ($results.Values -contains $true)
}

function Save-HTTenantProfile {
    # Zapis profilu w konfiguracji (ta sama nazwa albo -OriginalName - zastąpienie)
    param([Parameter(Mandatory)]$TenantProfile, [string]$OriginalName = '')
    $p = ConvertTo-HTTenantProfile $TenantProfile
    $old = if ($OriginalName) { $OriginalName } else { $p.Name }
    $previous = @(Get-HTTenantProfiles | Where-Object { $_.Name -eq $old })[0]
    if ($previous -and -not $p.LastUsed) { $p.LastUsed = $previous.LastUsed }
    $list = @(Get-HTTenantProfiles | Where-Object { $_.Name -ne $old -and $_.Name -ne $p.Name })
    Set-HTTenantProfiles -Profiles @($list + $p)
}

function Request-HTSaveTenantProfile {
    # Po połączeniu z tenantem klienta (GDAP) - propozycja zapisania profilu do szybkiego łączenia
    param([string]$TenantId = '', [string]$Organization = '', [string]$PartnerAccount = '', [string]$DefaultName = '')
    $known = @(Get-HTTenantProfiles | Where-Object { ($TenantId -and $_.TenantId -eq $TenantId) -or ($Organization -and $_.Organization -eq $Organization) })
    if ($known.Count) { return }
    $edited = Edit-HTTenantProfile -TenantProfile ([PSCustomObject]@{ Name = $DefaultName; TenantId = $TenantId; Organization = $Organization; PartnerAccount = $PartnerAccount; Gdap = $true }) -Title 'Zapisać profil tenantu?' -New
    if (-not $edited) { return }
    Save-HTTenantProfile -TenantProfile $edited
    Show-HTToast "Zapisano profil «$($edited.Name)»." 'ok'
}

function Show-HTTenantSwitch {
    # Przełączenie usług na inny zapamiętany tenant: wybór profilu (wyszukiwanie) i usług
    param([string]$Query = '')
    $tp = Select-HTTenantProfile -Title 'Przełącz tenant' -Query $Query
    if (-not $tp) { return }
    $services = Select-HTTenantServices -TenantProfile $tp
    if (-not $services) { return }
    [void](Connect-HTTenantProfile -TenantProfile $tp -Services $services)
}
#endregion

function Invoke-HTConnectionClick {
    param([Parameter(Mandatory)][string]$Service)
    switch ($Service) {
        'Exchange' {
            if (-not $Global:ConnectedToExchange) {
                $choice = Show-HTChoiceDialog -Title 'Połączenie z Exchange Online' -Prompt 'Wybierz sposób logowania. Okno logowania pojawi się na wierzchu.' -Icon 'E715' -Choices @(
                    @{ Key = 'Standard'; Text = 'Konto organizacji'; Icon = 'E77B'; Description = 'Logowanie interaktywne do własnego tenantu' }
                    @{ Key = 'GDAP'; Text = 'Konto partnera (GDAP)'; Icon = 'E716'; Description = 'Zarządzanie tenantem klienta w ramach GDAP' }
                    @(Get-HTTenantProfileChoices -Service 'Exchange')
                )
                if ("$choice" -like 'profile:*') { $tp = Resolve-HTTenantProfileChoice -Choice $choice -Service 'Exchange'; if ($tp) { [void](Connect-HTTenantProfile -TenantProfile $tp -Services @('Exchange')) }; return }
                $ok = if ($choice -eq 'GDAP') { Connect-Module -Name 'ExchangeOnlineManagementGDAP' } elseif ($choice -eq 'Standard') { Connect-Module -Name 'ExchangeOnlineManagement' } else { $false }
                if ($ok) { Invoke-HTPanelAutoLoad -Service 'Exchange' }
            }
            elseif (Show-HTConfirm -Message 'Rozłączyć z Exchange Online?' -Title 'Exchange Online' -ConfirmText 'Rozłącz') {
                Set-Connections -Action 'Disconnect' -Service 'Exchange'
                Clear-HTPanelItems -Service 'Exchange'
            }
        }
        'Graph' {
            if (-not $Global:ConnectedToGraphAPI) {
                $choice = Show-HTChoiceDialog -Title 'Połączenie z Microsoft 365 (Graph)' -Prompt 'Wybierz sposób logowania. Okno logowania pojawi się na wierzchu.' -Icon 'E753' -Choices @(
                    @{ Key = 'Standard'; Text = 'Konto organizacji'; Icon = 'E77B'; Description = 'Logowanie interaktywne do własnego tenantu' }
                    @{ Key = 'GDAP'; Text = 'Tenant klienta (GDAP)'; Icon = 'E716'; Description = 'Logowanie do wskazanego tenantu klienta' }
                    @(Get-HTTenantProfileChoices -Service 'Graph')
                )
                if ("$choice" -like 'profile:*') { $tp = Resolve-HTTenantProfileChoice -Choice $choice -Service 'Graph'; if ($tp) { [void](Connect-HTTenantProfile -TenantProfile $tp -Services @('Graph')) }; return }
                $ok = if ($choice -eq 'GDAP') { Connect-Module -Name 'Microsoft.GraphGDAP' } elseif ($choice -eq 'Standard') { Connect-Module -Name 'Microsoft.Graph' } else { $false }
                if ($ok) {
                    Clear-HTM365Cache
                    Invoke-HTPanelAutoLoad -Service 'Graph'
                    if ($choice -eq 'GDAP') {
                        $ctx = Get-MgContext
                        Request-HTSaveTenantProfile -TenantId "$($ctx.TenantId)" -DefaultName "$($HT_UI.Controls.subGraph.Text)"
                    }
                }
            }
            else {
                $choice = Show-HTChoiceDialog -Title 'Microsoft 365' -Prompt "Połączono: $($HT_UI.Controls.subGraph.Text)" -Icon 'E753' -Choices @(
                    @{ Key = 'Switch'; Text = 'Przełącz tenant…'; Icon = 'E8AB'; Description = 'Połącz Microsoft 365 i Exchange z innym zapisanym tenantem (profile GDAP)' }
                    @{ Key = 'Disconnect'; Text = 'Rozłącz'; Icon = 'E7E8'; Description = 'Zakończ połączenie z Microsoft Graph'; Style = 'Danger' }
                )
                if ($choice -eq 'Switch') { Show-HTTenantSwitch }
                elseif ($choice -eq 'Disconnect') {
                    Set-Connections -Action 'Disconnect' -Service 'Graph'
                    Clear-HTM365Cache
                    Clear-HTPanelItems -Service 'Graph'
                }
            }
        }
        'SharePoint' {
            if (-not $Global:ConnectedToSharepointPnP) {
                # Profile tenantów z adresem SharePoint - wybór profilu albo zwykłe okno połączenia
                $profileChoices = @(Get-HTTenantProfileChoices -Service 'SharePoint')
                if ($profileChoices.Count) {
                    $choice = Show-HTChoiceDialog -Title 'Połączenie z SharePoint' -Prompt 'Wybierz witrynę i aplikację PnP albo profil tenantu.' -Icon 'E8F1' -Choices @(
                        @{ Key = 'Standard'; Text = 'Adres witryny i Client ID…'; Icon = 'E8F1'; Description = 'Okno połączenia PnP PowerShell' }
                        $profileChoices
                    )
                    if ("$choice" -like 'profile:*') { $tp = Resolve-HTTenantProfileChoice -Choice $choice -Service 'SharePoint'; if ($tp) { [void](Connect-HTTenantProfile -TenantProfile $tp -Services @('SharePoint')) }; return }
                    if ($choice -ne 'Standard') { return }
                }
                if (Connect-Module -Name 'PnP.PowerShell') {
                    Clear-HTPanelItems -Service 'SharePoint'
                    Invoke-HTPanelAutoLoad -Service 'SharePoint'
                }
                return
            }
            $choice = Show-HTChoiceDialog -Title 'SharePoint' -Prompt "Połączono: $((Get-PnPConnection).Url)" -Icon 'E8F1' -Choices @(
                @{ Key = 'Switch'; Text = 'Przełącz witrynę…'; Icon = 'E8AB'; Description = 'Połącz z inną witryną (ten sam Client ID)' }
                @{ Key = 'Disconnect'; Text = 'Rozłącz'; Icon = 'E7E8'; Description = 'Zakończ połączenie PnP PowerShell'; Style = 'Danger' }
            )
            if ($choice -eq 'Switch') {
                if (Connect-Module -Name 'PnP.PowerShell') {
                    Clear-HTPanelItems -Service 'SharePoint'
                    Invoke-HTPanelAutoLoad -Service 'SharePoint'
                }
            }
            elseif ($choice -eq 'Disconnect') {
                Set-Connections -Action 'Disconnect' -Service 'SharePoint'
                Clear-HTPanelItems -Service 'SharePoint'
            }
        }
        'AD' {
            Initialize-HTActiveDirectory
            if ($Global:IsModuleActiveDirectoryLoaded) {
                Show-HTToast "Active Directory: $($HT_UI.Controls.subAD.Text)" 'ok'
                Invoke-HTPanelAutoLoad -Service 'AD'
            }
            else { Show-HTWarning -Title 'Active Directory' -Text "Moduł ActiveDirectory (RSAT) nie jest dostępny na tym komputerze.`n`nZainstaluj: Ustawienia > Aplikacje > Funkcje opcjonalne > RSAT: Active Directory Domain Services." }
        }
    }
}
