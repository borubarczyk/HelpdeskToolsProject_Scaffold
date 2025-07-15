# Połączenie z Exchange Online
$HT_UI.Buttons.ConnectExchange.Add_Click({
        if (-not $Global:ConnectedToExchange) {
            $response = Show-Dialog -Message "Czy chcesz się połączyć korzystając z konta GDAP?" -Title "GDAP" -Type "Question" -Buttons "YesNo"
            if ($response -eq "Yes") {
                Connect-Module -Name "ExchangeOnlineManagementGDAP" | Out-Null
            }
            elseif ($response -eq "No") {
                Connect-Module -Name "ExchangeOnlineManagement" | Out-Null
            }
        }
        else {
            Set-Connections -Action "Disconnect" -Service "Exchange"
        }
    })
# Połączenie z Graph API
$HT_UI.Buttons.ConnectGraph.Add_Click({
        if (-not $Global:ConnectedToGraphAPI) {
            $response = Show-Dialog -Message "Czy chcesz się połączyć korzystając z konta GDAP?" -Title "GDAP" -Type "Question" -Buttons "YesNo"
            if ($response -eq "Yes") {
                Connect-Module -Name "Microsoft.GraphGDAP" | Out-Null
            }
            elseif ($response -eq "No") {
                Connect-Module -Name "Microsoft.Graph" | Out-Null
            }
        }
        else {
            Set-Connections -Action "Disconnect" -Service "Graph"
        }
    })
# Połączenie z SharePoint
$HT_UI.Buttons.ConnectSharePoint.Add_Click({
        if (-not $Global:ConnectedToSharepointPnP) {
            Connect-Module -Name "PnP.PowerShell" | Out-Null
        }
        else {
            Set-Connections -Action "Disconnect" -Service "SharePoint"
        }
    })
# Generator haseł
$HT_UI.Buttons.PasswordGen.Add_Click({
        Write-Log -Message "Otwieranie generatora haseł..." -Type "Info"
        try {
            $form_PasswordGenerator.ShowDialog()
        }
        catch {
            Write-Log -Message "Błąd podczas otwierania generatora haseł: $_" -Type "Error&Notification"
            Show-Dialog -Message "Błąd podczas otwierania generatora haseł: $_" -Title "Błąd" -Type "Error" 
        }
    })
# Wyjście
$HT_UI.Buttons.Exit.Add_Click({
        Set-ButtonsState -Action "Lock"
        Set-Connections -Action "Disconnect" 
        Write-Log -Message "Zamykanie aplikacji..." -Type "Info"
        Set-ButtonsState -Action "Unlock"
        $HT_UI.Form.Close()
        $HT_UI.Form.Dispose()
    })
# Zmieniono zakładkę
$HT_UI.TabControl.Add_SelectedIndexChanged({
        $selectedTab = $HT_UI.TabControl.SelectedTab
        Write-Log -Message "Zmieniono zakładkę na: $($selectedTab.Text)" -Type "Info"
        $HT_UI.Form.Text = "Helpdesk Tools - $($selectedTab.Text)"
    })

$HT_UI.Form.Add_FormClosing({
        # Oczyść zmienne globalne
        Get-Variable -Scope Global | Where-Object { $_.Options -notmatch 'Constant|ReadOnly' } | Remove-Variable -Force -Scope Global -ErrorAction SilentlyContinue
    })

