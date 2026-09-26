# Nawigacja między sekcjami
foreach ($navButton in $HT_UI.NavButtons.Values) {
    $navButton.Add_Click({
            param($src, $evt)
            Show-HTSection -Name $src.Tag
        })
}

# Połączenie z Exchange Online
$HT_UI.Buttons.ConnectExchange.Add_Click({
        if (-not $Global:ConnectedToExchange) {
            $choice = Show-HTChoiceDialog -Title "Połączenie z Exchange Online" -Prompt "Wybierz sposób logowania:" -Choices @(
                @{ Key = "Standard"; Text = "Konto organizacji"; Icon = "microsoft-exchange-2019.png"; Description = "Logowanie interaktywne do własnego tenantu" }
                @{ Key = "GDAP"; Text = "Konto partnera (GDAP)"; Icon = "user-shield.png"; Description = "Zarządzanie tenantem klienta w ramach GDAP" }
            )
            if ($choice -eq "GDAP") { Connect-Module -Name "ExchangeOnlineManagementGDAP" | Out-Null }
            elseif ($choice -eq "Standard") { Connect-Module -Name "ExchangeOnlineManagement" | Out-Null }
        }
        elseif (Show-HTConfirm -Message "Rozłączyć z Exchange Online?" -Title "Exchange Online") {
            Set-Connections -Action "Disconnect" -Service "Exchange"
        }
    })

# Połączenie z Graph API
$HT_UI.Buttons.ConnectGraph.Add_Click({
        if (-not $Global:ConnectedToGraphAPI) {
            $choice = Show-HTChoiceDialog -Title "Połączenie z Microsoft Graph" -Prompt "Wybierz sposób logowania:" -Choices @(
                @{ Key = "Standard"; Text = "Konto organizacji"; Icon = "api.png"; Description = "Logowanie interaktywne do własnego tenantu" }
                @{ Key = "GDAP"; Text = "Tenant klienta (GDAP)"; Icon = "user-shield.png"; Description = "Logowanie do wskazanego tenantu klienta" }
            )
            if ($choice -eq "GDAP") { Connect-Module -Name "Microsoft.GraphGDAP" | Out-Null }
            elseif ($choice -eq "Standard") { Connect-Module -Name "Microsoft.Graph" | Out-Null }
            if ($Global:ConnectedToGraphAPI) { Clear-HTM365Cache }
        }
        elseif (Show-HTConfirm -Message "Rozłączyć z Microsoft Graph?" -Title "Microsoft Graph") {
            Set-Connections -Action "Disconnect" -Service "Graph"
            Clear-HTM365Cache
        }
    })

# Połączenie z SharePoint
$HT_UI.Buttons.ConnectSharePoint.Add_Click({
        if (-not $Global:ConnectedToSharepointPnP) {
            if (Connect-Module -Name "PnP.PowerShell") {
                Show-HTSection -Name "SharePoint"
                Update-HTSharePointTree
            }
        }
        elseif (Show-HTConfirm -Message "Rozłączyć z SharePoint?" -Title "SharePoint") {
            Set-Connections -Action "Disconnect" -Service "SharePoint"
            $HT_UI.SharePointTab.TreeView.Nodes.Clear()
            Set-HTListData -ListView $HT_UI.SharePointTab.List -Data @()
        }
    })

# Generator haseł
$HT_UI.Buttons.PasswordGen.Add_Click({
        Write-Log -Message "Otwieranie generatora haseł..." -Type "Info"
        try {
            [void]$HT_UI.PasswordGeneratorWindow.Form.ShowDialog($HT_UI.Form)
        }
        catch {
            Write-Log -Message "Błąd podczas otwierania generatora haseł: $_" -Type "Error&Notification"
            Show-Dialog -Message "Błąd podczas otwierania generatora haseł: $_" -Title "Błąd" -Type "Error" | Out-Null
        }
    })

# Wyjście (rozłączenie następuje w FormClosing)
$HT_UI.Buttons.Exit.Add_Click({
        $HT_UI.Form.Close()
    })

# Zamykanie aplikacji - rozłączenie usług i sprzątanie
$HT_UI.Form.Add_FormClosing({
        try {
            Write-Log -Message "Zamykanie aplikacji..." -Type "Info"
            if ($Global:ConnectedToExchange -or $Global:ConnectedToGraphAPI -or $Global:ConnectedToSharepointPnP) {
                Set-HTStatus -Text "Rozłączanie usług..."
                [System.Windows.Forms.Application]::DoEvents()
                Set-Connections -Action "DisconnectAll"
            }
        }
        catch {
            Write-Log -Message "Błąd podczas zamykania: $($_.Exception.Message)" -Type "Warn"
        }
        finally {
            Remove-HTNotifyIcon
        }
    })

# Skróty klawiszowe: Ctrl+1..9 - sekcje, F5 - odśwież, Ctrl+G - generator haseł
$HT_UI.Form.Add_KeyDown({
        param($src, $evt)
        if ($evt.Control -and $evt.KeyCode -ge [System.Windows.Forms.Keys]::D1 -and $evt.KeyCode -le [System.Windows.Forms.Keys]::D9) {
            $index = [int]$evt.KeyCode - [int][System.Windows.Forms.Keys]::D1
            $names = @($HT_UI.Tabs.Keys)
            if ($index -lt $names.Count -and $HT_UI.NavButtons[$names[$index]].Enabled) {
                Show-HTSection -Name $names[$index]
                $evt.SuppressKeyPress = $true
            }
        }
        elseif ($evt.Control -and $evt.KeyCode -eq [System.Windows.Forms.Keys]::G) {
            $HT_UI.Buttons.PasswordGen.PerformClick()
            $evt.SuppressKeyPress = $true
        }
        elseif ($evt.KeyCode -eq [System.Windows.Forms.Keys]::F5) {
            $button = $HT_UI.RefreshButtons[$HT_UI.CurrentSection]
            if ($button -and $button.Enabled) { $button.PerformClick() }
            $evt.SuppressKeyPress = $true
        }
    })
