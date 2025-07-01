Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form_PasswordGenerator = New-Object System.Windows.Forms.Form
$form_PasswordGenerator.Text = "Generator haseł"
$form_PasswordGenerator.Size = '600,450'
$form_PasswordGenerator.StartPosition = "CenterParent"
$form_PasswordGenerator.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form_PasswordGenerator.FormBorderStyle = 'FixedDialog'
$form_PasswordGenerator.MaximizeBox = $false

# GroupBox - ustawienia
$groupbox_Settings = New-Object System.Windows.Forms.GroupBox
$groupbox_Settings.Text = "Ustawienia hasła"
$groupbox_Settings.Location = '10,10'
$groupbox_Settings.Size = '560,220'

# TableLayoutPanel dla checkboxów
$tableLayoutPanel = New-Object System.Windows.Forms.TableLayoutPanel
$tableLayoutPanel.Location = '10,20'
$tableLayoutPanel.Size = '540,140'
$tableLayoutPanel.ColumnCount = 2
$tableLayoutPanel.RowCount = 3
$tableLayoutPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$tableLayoutPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
for ($i = 0; $i -lt 3; $i++) {
    $tableLayoutPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 50)))
}

# CheckBoxy - dane wejściowe
$checkboxDefinitions = @(
    @{ Name = 'UseSymbols'; Text = "Używaj znaków specjalnych:"; Checked = $true },
    @{ Name = 'NoSimilar'; Text = "Nie używaj podobnych znaków"; Checked = $true },
    @{ Name = 'StartLetter'; Text = "Rozpoczynaj od litery"; Checked = $true },
    @{ Name = 'Friendly'; Text = "Przyjazne hasła"; Checked = $false },
    @{ Name = 'Words'; Text = "Słownikowe hasła"; Checked = $false },
    @{ Name = 'UseNumbers'; Text = "Używaj liczb"; Checked = $true }
)

$checkboxes = @{}
$index = 0
foreach ($item in $checkboxDefinitions) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $item.Text
    $cb.AutoSize = $true
    $cb.Checked = $item.Checked
    $cb.Margin = New-Object System.Windows.Forms.Padding(5)
    $tableLayoutPanel.Controls.Add($cb, [math]::Floor($index / 3), $index % 3)
    $checkboxes[$item.Name] = $cb
    $index++
}
$checkboxes['Friendly'].Checked = $true # Domyślnie ustawiamy Friendly na true

if ($Global:PasswordUseWordBased -eq "True") {
    $checkboxes['Words'].Checked = $true
    $checkboxes['Friendly'].Checked = $false
}

# TextBox dla znaków specjalnych
$label_SpecialChars = New-Object System.Windows.Forms.Label
$label_SpecialChars.Text = "Znaki specjalne:"
$label_SpecialChars.Location = '10,170'
$label_SpecialChars.Size = '100,20'

$textbox_SpecialChars = New-Object System.Windows.Forms.TextBox
$textbox_SpecialChars.Text = $Global:PasswordSpecialCharacters
$textbox_SpecialChars.Location = '120,170' 
$textbox_SpecialChars.Size = '420,25'

$groupbox_Settings.Controls.AddRange(@($tableLayoutPanel, $label_SpecialChars, $textbox_SpecialChars))

# Label, TrackBar i NumericUpDown
$label_Length = New-Object System.Windows.Forms.Label
$label_Length.Text = "Długość hasła:"
$label_Length.Location = '10,240'
$label_Length.Size = '100,20'

$numericupdown_Length = New-Object System.Windows.Forms.NumericUpDown
$numericupdown_Length.Location = '120,240'
$numericupdown_Length.Size = '60,25'
$numericupdown_Length.Minimum = 8
$numericupdown_Length.Maximum = 64
$numericupdown_Length.Value = 8

$trackbar_Length = New-Object System.Windows.Forms.TrackBar
$trackbar_Length.Location = '190,235'
$trackbar_Length.Size = '380,40'
$trackbar_Length.Minimum = 8
$trackbar_Length.Maximum = 64
$trackbar_Length.Value = 8
$trackbar_Length.TickFrequency = 5
$trackbar_Length.SmallChange = 1
$trackbar_Length.LargeChange = 4

$trackbar_Length.add_Scroll({
        $numericupdown_Length.Value = $trackbar_Length.Value
    })
    
$numericupdown_Length.add_ValueChanged({
        $trackbar_Length.Value = $numericupdown_Length.Value
    })

# Pole z wynikiem
$richtextbox_Password = New-Object System.Windows.Forms.RichTextBox
$richtextbox_Password.Location = '10,290'
$richtextbox_Password.Size = '450,40'
$richtextbox_Password.ReadOnly = $true
$richtextbox_Password.BackColor = 'White'
$richtextbox_Password.ForeColor = 'Black'
$richtextbox_Password.Multiline = $false
$richtextbox_Password.Font = New-Object System.Drawing.Font("Segoe UI", 14)

$button_Copy = New-Object System.Windows.Forms.Button
$button_Copy.Text = "Kopiuj"
$button_Copy.Location = '470,290'
$button_Copy.Size = '100,40'

# Dolne przyciski
$bottomButtons = @(
    @{ Name = 'Generate'; Text = "Wygeneruj nowe"; X = 10 },
    @{ Name = 'Send'; Text = "Wyślij e-mailem"; X = 200 },
    @{ Name = 'Close'; Text = "Zamknij"; X = 390 }
)

$buttons = @{}
foreach ($btn in $bottomButtons) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $btn.Text
    $b.Size = '180,40'
    $b.Location = "$($btn.X),350"
    $b.FlatStyle = 'Standard'
    $form_PasswordGenerator.Controls.Add($b)
    $buttons[$btn.Name] = $b
}

# Dodaj wszystko do formularza
$form_PasswordGenerator.Controls.AddRange(@(
        $groupbox_Settings,
        $label_Length,
        $numericupdown_Length,
        $trackbar_Length,
        $richtextbox_Password,
        $button_Copy
    ))

$HT_UI.PasswordGeneratorWindow = [ordered]@{
    Form    = $form_PasswordGenerator
    CheckBoxes = $checkboxes  # ten hashtable z UseSymbols, NoSimilar, StartLetter, Friendly, Words, UseNumbers
    Actions = $buttons  # ten hashtable z Generate, Send, Close
    CopyButton = $button_Copy
    SpecialCharacters = $textbox_SpecialChars
    Password = $richtextbox_Password
    Length = $numericupdown_Length
}

if (-not $HT_UI.PasswordGeneratorWindow.Initialized) {
    Set-PasswordGeneratorIcons
    $HT_UI.PasswordGeneratorWindow.Initialized = $true
}

# Wyświetl ontop
$form_PasswordGenerator.Topmost = $true
$form_PasswordGenerator.KeyPreview = $true

# Funkcja do ustawiania konfiguracji w GUI
