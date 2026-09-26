# Okno generatora haseł
$theme = $Global:HTTheme

$form_PasswordGenerator = New-Object System.Windows.Forms.Form
$form_PasswordGenerator.Text = "Generator haseł"
$form_PasswordGenerator.ClientSize = New-Object System.Drawing.Size(580, 470)
$form_PasswordGenerator.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
$form_PasswordGenerator.Font = $theme.Font
$form_PasswordGenerator.BackColor = $theme.Surface
$form_PasswordGenerator.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form_PasswordGenerator.MaximizeBox = $false
$form_PasswordGenerator.MinimizeBox = $false
$form_PasswordGenerator.ShowInTaskbar = $false
$form_PasswordGenerator.KeyPreview = $true
if (Test-Path $Global:AppIconPath) {
    $form_PasswordGenerator.Icon = New-Object System.Drawing.Icon($Global:AppIconPath)
}

# Pole z wynikiem
$textbox_Password = New-Object System.Windows.Forms.TextBox
$textbox_Password.Location = New-Object System.Drawing.Point(16, 18)
$textbox_Password.Size = New-Object System.Drawing.Size(430, 36)
$textbox_Password.ReadOnly = $true
$textbox_Password.BackColor = $theme.Background
$textbox_Password.Font = New-Object System.Drawing.Font("Consolas", 16)
$textbox_Password.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center

$button_Copy = New-HTButton -Text "Kopiuj" -Icon "Copy.png" -Width 110 -Height 36 -ToolTip "Kopiuj hasło do schowka (Ctrl+C)"
$button_Copy.Location = New-Object System.Drawing.Point(454, 18)

# Wskaźnik siły hasła
$panel_StrengthTrack = New-Object System.Windows.Forms.Panel
$panel_StrengthTrack.Location = New-Object System.Drawing.Point(16, 64)
$panel_StrengthTrack.Size = New-Object System.Drawing.Size(430, 6)
$panel_StrengthTrack.BackColor = $theme.Border

$panel_StrengthBar = New-Object System.Windows.Forms.Panel
$panel_StrengthBar.Location = New-Object System.Drawing.Point(0, 0)
$panel_StrengthBar.Size = New-Object System.Drawing.Size(0, 6)
$panel_StrengthBar.BackColor = $theme.Success
$panel_StrengthTrack.Controls.Add($panel_StrengthBar)

$label_Strength = New-Object System.Windows.Forms.Label
$label_Strength.Location = New-Object System.Drawing.Point(14, 74)
$label_Strength.AutoSize = $true
$label_Strength.ForeColor = $theme.Muted
$label_Strength.Font = $theme.FontSmall

# Tryb hasła
$groupbox_Mode = New-Object System.Windows.Forms.GroupBox
$groupbox_Mode.Text = "Rodzaj hasła"
$groupbox_Mode.Location = New-Object System.Drawing.Point(16, 102)
$groupbox_Mode.Size = New-Object System.Drawing.Size(548, 62)

$modes = [ordered]@{}
$modeX = 14
foreach ($mode in @(
        @{ Name = "Classic"; Text = "Klasyczne"; Tip = "Losowe litery, cyfry i znaki specjalne" }
        @{ Name = "Friendly"; Text = "Przyjazne (sylaby)"; Tip = "Łatwe do przeczytania i podyktowania, np. Bak4Tor7Mil!" }
        @{ Name = "Words"; Text = "Słownikowe"; Tip = "Połączone słowa, np. SzybkiKotDom42!" }
    )) {
    $radio = New-Object System.Windows.Forms.RadioButton
    $radio.Text = $mode.Text
    $radio.AutoSize = $true
    $radio.Location = New-Object System.Drawing.Point($modeX, 26)
    Set-HTToolTip -Control $radio -Text $mode.Tip
    $groupbox_Mode.Controls.Add($radio)
    $modes[$mode.Name] = $radio
    $modeX += 170
}

# Opcje
$groupbox_Settings = New-Object System.Windows.Forms.GroupBox
$groupbox_Settings.Text = "Opcje"
$groupbox_Settings.Location = New-Object System.Drawing.Point(16, 172)
$groupbox_Settings.Size = New-Object System.Drawing.Size(548, 132)

$checkboxDefinitions = @(
    @{ Name = 'UseNumbers'; Text = "Używaj cyfr"; Checked = $true; X = 14; Y = 26 }
    @{ Name = 'UseSymbols'; Text = "Używaj znaków specjalnych"; Checked = $true; X = 14; Y = 54 }
    @{ Name = 'NoSimilar'; Text = "Bez podobnych znaków (l, 1, O, 0)"; Checked = $true; X = 280; Y = 26 }
    @{ Name = 'StartLetter'; Text = "Rozpoczynaj od litery"; Checked = $true; X = 280; Y = 54 }
)

$checkboxes = @{}
foreach ($item in $checkboxDefinitions) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Text = $item.Text
    $cb.AutoSize = $true
    $cb.Checked = $item.Checked
    $cb.Location = New-Object System.Drawing.Point($item.X, $item.Y)
    $groupbox_Settings.Controls.Add($cb)
    $checkboxes[$item.Name] = $cb
}

$label_SpecialChars = New-Object System.Windows.Forms.Label
$label_SpecialChars.Text = "Znaki specjalne:"
$label_SpecialChars.Location = New-Object System.Drawing.Point(14, 92)
$label_SpecialChars.AutoSize = $true

$textbox_SpecialChars = New-Object System.Windows.Forms.TextBox
$textbox_SpecialChars.Text = $Global:PasswordSpecialCharacters
$textbox_SpecialChars.Location = New-Object System.Drawing.Point(130, 89)
$textbox_SpecialChars.Size = New-Object System.Drawing.Size(400, 25)
$textbox_SpecialChars.Font = $theme.FontMono

$groupbox_Settings.Controls.AddRange(@($label_SpecialChars, $textbox_SpecialChars))

# Długość hasła
$label_Length = New-Object System.Windows.Forms.Label
$label_Length.Text = "Długość hasła:"
$label_Length.Location = New-Object System.Drawing.Point(16, 322)
$label_Length.AutoSize = $true

$numericupdown_Length = New-Object System.Windows.Forms.NumericUpDown
$numericupdown_Length.Location = New-Object System.Drawing.Point(120, 319)
$numericupdown_Length.Size = New-Object System.Drawing.Size(60, 25)
$numericupdown_Length.Minimum = 8
$numericupdown_Length.Maximum = 64
$numericupdown_Length.Value = 12

$trackbar_Length = New-Object System.Windows.Forms.TrackBar
$trackbar_Length.Location = New-Object System.Drawing.Point(190, 314)
$trackbar_Length.Size = New-Object System.Drawing.Size(374, 40)
$trackbar_Length.Minimum = 8
$trackbar_Length.Maximum = 64
$trackbar_Length.Value = 12
$trackbar_Length.TickFrequency = 4
$trackbar_Length.SmallChange = 1
$trackbar_Length.LargeChange = 4

# Dolne przyciski
$panel_PasswordButtons = New-Object System.Windows.Forms.FlowLayoutPanel
$panel_PasswordButtons.Dock = [System.Windows.Forms.DockStyle]::Bottom
$panel_PasswordButtons.Height = 60
$panel_PasswordButtons.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
$panel_PasswordButtons.Padding = New-Object System.Windows.Forms.Padding(14, 12, 14, 10)
$panel_PasswordButtons.BackColor = $theme.Background

$buttons = @{
    Generate = New-HTButton -Text "Wygeneruj nowe" -Icon "Password Reset.png" -Style "Primary" -Width 180 -Height 36 -ToolTip "Nowe hasło (F5)"
    Send     = New-HTButton -Text "Wyślij e-mailem (SMS)" -Icon "Email.png" -Width 200 -Height 36 -ToolTip "Otwiera klienta poczty z hasłem w treści"
    Close    = New-HTButton -Text "Zamknij" -Icon "close.png" -Width 130 -Height 36
}
foreach ($key in @("Generate", "Send", "Close")) {
    $buttons[$key].Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 0)
    $panel_PasswordButtons.Controls.Add($buttons[$key])
}

# Dodaj wszystko do formularza
$form_PasswordGenerator.Controls.AddRange(@(
        $textbox_Password,
        $button_Copy,
        $panel_StrengthTrack,
        $label_Strength,
        $groupbox_Mode,
        $groupbox_Settings,
        $label_Length,
        $numericupdown_Length,
        $trackbar_Length,
        $panel_PasswordButtons
    ))

$HT_UI.PasswordGeneratorWindow = [ordered]@{
    Form              = $form_PasswordGenerator
    Modes             = $modes      # Classic, Friendly, Words
    Checkboxes        = $checkboxes # UseNumbers, UseSymbols, NoSimilar, StartLetter
    Actions           = $buttons    # Generate, Send, Close
    CopyButton        = $button_Copy
    SpecialCharacters = $textbox_SpecialChars
    Password          = $textbox_Password
    Length            = $numericupdown_Length
    LengthSlider      = $trackbar_Length
    StrengthBar       = $panel_StrengthBar
    StrengthTrack     = $panel_StrengthTrack
    StrengthLabel     = $label_Strength
    Initialized       = $false
}
