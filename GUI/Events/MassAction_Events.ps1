# Zakładka "Akcje masowe" - obsługa zdarzeń

# Aktualnie wybrana akcja
function Get-HTSelectedMassAction {
    $tab = $HT_UI.MassActionsTab
    $index = $tab.ActionBox.SelectedIndex
    if ($index -lt 0) { return $null }
    return $tab.ActionList[$index]
}

# Licznik identyfikatorów
function Update-HTMassIdentityCount {
    $count = @(Split-HTInputList -Text $HT_UI.MassActionsTab.Identities.Text).Count
    $HT_UI.MassActionsTab.IdentityCount.Text = "$count identyfikatorów"
}

# Zmiana akcji - etykieta parametru
$HT_UI.MassActionsTab.ActionBox.Add_SelectedIndexChanged({
        $action = Get-HTSelectedMassAction
        $tab = $HT_UI.MassActionsTab
        if ($action -and $action.ParameterLabel) {
            $tab.ParameterLabel.Text = "Parametr: $($action.ParameterLabel)"
            $tab.ParameterBox.Enabled = $true
        }
        else {
            $tab.ParameterLabel.Text = "Parametr: (niewymagany)"
            $tab.ParameterBox.Enabled = $false
        }
    })
if ($HT_UI.MassActionsTab.ActionBox.SelectedIndex -ge 0) {
    $index = $HT_UI.MassActionsTab.ActionBox.SelectedIndex
    $HT_UI.MassActionsTab.ActionBox.SelectedIndex = -1
    $HT_UI.MassActionsTab.ActionBox.SelectedIndex = $index
}

$HT_UI.MassActionsTab.Identities.Add_TextChanged({ Update-HTMassIdentityCount })

# Import identyfikatorów z pliku
$HT_UI.MassActionsTab.Buttons.Import.Add_Click({
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Title = "Importuj identyfikatory"
        $dialog.Filter = "CSV lub TXT (*.csv;*.txt)|*.csv;*.txt|Wszystkie pliki (*.*)|*.*"
        try {
            if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
            $identities = @(Import-HTIdentityFile -Path $dialog.FileName)
            if ($identities.Count -eq 0) {
                Show-Dialog -Message "Nie znaleziono identyfikatorów w pliku." -Title "Import" -Type "Warning" | Out-Null
                return
            }
            $existing = @(Split-HTInputList -Text $HT_UI.MassActionsTab.Identities.Text)
            $all = @($existing + $identities | Select-Object -Unique)
            $HT_UI.MassActionsTab.Identities.Text = $all -join [Environment]::NewLine
            Write-Log -Message "Zaimportowano $($identities.Count) identyfikatorów z pliku $($dialog.FileName)" -Type "Info"
        }
        catch {
            Write-Log -Message "Błąd importu: $($_.Exception.Message)" -Type "Error&Notification"
        }
        finally {
            $dialog.Dispose()
        }
    })

$HT_UI.MassActionsTab.Buttons.Clear.Add_Click({
        $HT_UI.MassActionsTab.Identities.Clear()
        Set-HTListData -ListView $HT_UI.MassActionsTab.Results -Data @()
    })

# Wykonanie akcji
$HT_UI.MassActionsTab.Buttons.Run.Add_Click({
        $tab = $HT_UI.MassActionsTab
        $action = Get-HTSelectedMassAction
        if (-not $action) { return }

        $identities = @(Split-HTInputList -Text $tab.Identities.Text)
        if ($identities.Count -eq 0) {
            Show-Dialog -Message "Wpisz lub zaimportuj co najmniej jeden identyfikator." -Title "Akcje masowe" -Type "Warning" | Out-Null
            return
        }
        if (-not (Assert-HTConnection -Service $action.Service)) { return }

        $parameter = $tab.ParameterBox.Text.Trim()
        if ($action.ParameterLabel -and -not $parameter) {
            Show-Dialog -Message "Ta akcja wymaga parametru: $($action.ParameterLabel)" -Title "Akcje masowe" -Type "Warning" | Out-Null
            return
        }

        $testOnly = $tab.TestMode.Checked
        if (-not $testOnly) {
            $question = "Wykonać akcję:`n$($action.Text)`n$(if ($parameter) { "Parametr: $parameter`n" })`ndla $($identities.Count) obiektów?"
            if (-not (Show-HTConfirm -Message $question -Title "Akcje masowe" -Warning)) { return }
        }

        $mode = if ($testOnly) { "TEST" } else { "WYKONANIE" }
        Write-Log -Message "Akcja masowa [$mode]: $($action.Text), obiektów: $($identities.Count)" -Type "Info"

        Invoke-HTAction -Name "Akcja masowa: $($action.Text)" -RequiredService $action.Service -ScriptBlock {
            $results = Invoke-HTMassAction -ActionKey $action.Key -Identities $identities -Parameter $parameter -TestOnly:$testOnly -OnProgress {
                param($index, $total, $identity)
                Set-HTProgress -Value $index -Maximum $total -Text "[$index/$total] $identity"
            }
            Set-HTListData -ListView $tab.Results -Data $results
            $errors = @($results | Where-Object { $_.Status -eq "Błąd" }).Count
            $summary = "Zakończono ($mode): $($results.Count) obiektów, błędów: $errors"
            Write-Log -Message $summary -Type $(if ($errors -gt 0) { "Warning&Notification" } else { "Info&Notification" })
            if ($action.ReturnsSecret -and -not $testOnly) {
                Show-Dialog -Message "$summary`n`nNowe hasła znajdują się w kolumnie 'Szczegóły'. Wyeksportuj wyniki i przekaż je bezpiecznym kanałem." -Title "Akcje masowe" -Type "Warning" | Out-Null
            }
        }
    })

# Eksport wyników
$HT_UI.MassActionsTab.Buttons.Export.Add_Click({
        Export-HTListView -ListView $HT_UI.MassActionsTab.Results -Name "AkcjeMasowe_Wyniki"
    })
