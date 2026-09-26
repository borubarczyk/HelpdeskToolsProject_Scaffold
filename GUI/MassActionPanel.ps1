# Panel dla zakładki "Akcje masowe"
$theme = $Global:HTTheme

$panel_MassActions = New-Object System.Windows.Forms.Panel
$panel_MassActions.Dock = [System.Windows.Forms.DockStyle]::Fill
$panel_MassActions.BackColor = $theme.Background
$panel_MassActions.Padding = New-Object System.Windows.Forms.Padding(12, 10, 12, 12)

# Górna karta: dane wejściowe i wybór akcji
$table_MassInput = New-Object System.Windows.Forms.TableLayoutPanel
$table_MassInput.Dock = [System.Windows.Forms.DockStyle]::Top
$table_MassInput.Height = 262
$table_MassInput.ColumnCount = 2
$table_MassInput.BackColor = $theme.Surface
$table_MassInput.Padding = New-Object System.Windows.Forms.Padding(12, 10, 12, 10)
$table_MassInput.RowCount = 1
[void]$table_MassInput.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
[void]$table_MassInput.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
[void]$table_MassInput.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))

# Lewa kolumna: identyfikatory
$panel_MassLeft = New-Object System.Windows.Forms.Panel
$panel_MassLeft.Dock = [System.Windows.Forms.DockStyle]::Fill
$panel_MassLeft.Padding = New-Object System.Windows.Forms.Padding(0, 0, 10, 0)

$label_MassIds = New-Object System.Windows.Forms.Label
$label_MassIds.Text = "Identyfikatory (jeden w linii: UPN, e-mail lub login)"
$label_MassIds.Dock = [System.Windows.Forms.DockStyle]::Top
$label_MassIds.Height = 22
$label_MassIds.Font = $theme.FontBold

$textbox_MassIds = New-Object System.Windows.Forms.TextBox
$textbox_MassIds.Multiline = $true
$textbox_MassIds.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
$textbox_MassIds.AcceptsReturn = $true
$textbox_MassIds.Dock = [System.Windows.Forms.DockStyle]::Fill
$textbox_MassIds.Font = $theme.FontMono

$flow_MassLeftButtons = New-Object System.Windows.Forms.FlowLayoutPanel
$flow_MassLeftButtons.Dock = [System.Windows.Forms.DockStyle]::Bottom
$flow_MassLeftButtons.Height = 42
$flow_MassLeftButtons.Padding = New-Object System.Windows.Forms.Padding(0, 6, 0, 0)

$button_MassImport = New-HTButton -Text "Importuj z pliku" -Icon "CSV.png" -Width 160 -Height 32 -ToolTip "CSV (kolumna UserPrincipalName / Mail / SamAccountName) lub TXT"
$button_MassClear = New-HTButton -Text "Wyczyść" -Icon "Clear Symbol.png" -Width 110 -Height 32
$label_MassIdCount = New-Object System.Windows.Forms.Label
$label_MassIdCount.AutoSize = $true
$label_MassIdCount.ForeColor = $theme.Muted
$label_MassIdCount.Margin = New-Object System.Windows.Forms.Padding(6, 8, 0, 0)
$label_MassIdCount.Text = "0 identyfikatorów"
$flow_MassLeftButtons.Controls.AddRange(@($button_MassImport, $button_MassClear, $label_MassIdCount))

$panel_MassLeft.Controls.Add($textbox_MassIds)
$panel_MassLeft.Controls.Add($flow_MassLeftButtons)
$panel_MassLeft.Controls.Add($label_MassIds)
$textbox_MassIds.BringToFront()

# Prawa kolumna: akcja i parametry
$flow_MassRight = New-Object System.Windows.Forms.FlowLayoutPanel
$flow_MassRight.Dock = [System.Windows.Forms.DockStyle]::Fill
$flow_MassRight.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
$flow_MassRight.WrapContents = $false
$flow_MassRight.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)

$label_MassAction = New-Object System.Windows.Forms.Label
$label_MassAction.Text = "Akcja"
$label_MassAction.AutoSize = $true
$label_MassAction.Font = $theme.FontBold

$combobox_MassAction = New-Object System.Windows.Forms.ComboBox
$combobox_MassAction.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$combobox_MassAction.Width = 470
$combobox_MassAction.DropDownHeight = 420
$massActionList = @(Get-HTMassActions)
foreach ($action in $massActionList) { [void]$combobox_MassAction.Items.Add($action.Text) }

$label_MassParameter = New-Object System.Windows.Forms.Label
$label_MassParameter.Text = "Parametr"
$label_MassParameter.AutoSize = $true
$label_MassParameter.Margin = New-Object System.Windows.Forms.Padding(3, 10, 3, 0)

$textbox_MassParameter = New-Object System.Windows.Forms.TextBox
$textbox_MassParameter.Width = 470

$checkbox_MassTest = New-Object System.Windows.Forms.CheckBox
$checkbox_MassTest.Text = "Tryb testowy - tylko sprawdź, czy obiekty istnieją (bez zmian)"
$checkbox_MassTest.AutoSize = $true
$checkbox_MassTest.Checked = $true
$checkbox_MassTest.Margin = New-Object System.Windows.Forms.Padding(3, 12, 3, 6)

$flow_MassRun = New-Object System.Windows.Forms.FlowLayoutPanel
$flow_MassRun.AutoSize = $true
$flow_MassRun.WrapContents = $false
$button_MassRun = New-HTButton -Text "Wykonaj" -Icon "resume.png" -Style "Primary" -Width 140 -Height 36
$button_MassExport = New-HTButton -Text "Eksport wyników" -Icon "Save.png" -Width 170 -Height 36
$flow_MassRun.Controls.AddRange(@($button_MassRun, $button_MassExport))

$flow_MassRight.Controls.AddRange(@($label_MassAction, $combobox_MassAction, $label_MassParameter, $textbox_MassParameter, $checkbox_MassTest, $flow_MassRun))

$table_MassInput.Controls.Add($panel_MassLeft, 0, 0)
$table_MassInput.Controls.Add($flow_MassRight, 1, 0)

# Wyniki
$label_MassResults = New-Object System.Windows.Forms.Label
$label_MassResults.Dock = [System.Windows.Forms.DockStyle]::Top
$label_MassResults.Height = 32
$label_MassResults.Text = "WYNIKI"
$label_MassResults.Font = $theme.FontSmallBold
$label_MassResults.ForeColor = $theme.Muted
$label_MassResults.TextAlign = [System.Drawing.ContentAlignment]::BottomLeft

$list_MassResults = New-HTListView -Columns @(
    @{ Text = "Identyfikator"; Property = "Identity"; Width = 260 }
    @{ Text = "Status"; Property = "Status"; Width = 80 }
    @{ Text = "Szczegóły"; Property = "Detail"; Width = 560 }
    @{ Text = "Czas"; Property = "Time"; Width = 130 }
) -MultiSelect
$list_MassResults.Tag.CountLabel = $label_MassResults

$panel_MassResultsHost = New-Object System.Windows.Forms.Panel
$panel_MassResultsHost.Dock = [System.Windows.Forms.DockStyle]::Fill
$panel_MassResultsHost.BackColor = $theme.Surface
$panel_MassResultsHost.Controls.Add($list_MassResults)

$panel_MassActions.Controls.Add($panel_MassResultsHost)
$panel_MassActions.Controls.Add($label_MassResults)
$panel_MassActions.Controls.Add($table_MassInput)
$panel_MassResultsHost.BringToFront()

$HT_UI.Tabs["Akcje masowe"].Controls.Clear()
$HT_UI.Tabs["Akcje masowe"].Controls.Add($panel_MassActions)

$global:HT_UI.MassActionsTab = @{
    Panel          = $panel_MassActions
    Identities     = $textbox_MassIds
    IdentityCount  = $label_MassIdCount
    ActionBox      = $combobox_MassAction
    ActionList     = $massActionList
    ParameterLabel = $label_MassParameter
    ParameterBox   = $textbox_MassParameter
    TestMode       = $checkbox_MassTest
    Results        = $list_MassResults
    Buttons        = @{
        Import = $button_MassImport
        Clear  = $button_MassClear
        Run    = $button_MassRun
        Export = $button_MassExport
    }
}
if ($combobox_MassAction.Items.Count -gt 0) { $combobox_MassAction.SelectedIndex = 0 }
