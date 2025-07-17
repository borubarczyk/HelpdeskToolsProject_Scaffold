# Panel "Lokalne AD"
$panel_LocalAD = New-Object System.Windows.Forms.Panel
$panel_LocalAD.Dock = 'Fill'

# ComboBox z listą obiektów (dynamicznie ładowana)
$combobox_LocalAD_List = New-Object System.Windows.Forms.ComboBox
$combobox_LocalAD_List.Location = '10,10'
$combobox_LocalAD_List.Width = 660
$combobox_LocalAD_List.DropDownStyle = 'DropDownList'
$combobox_LocalAD_List.Items.Add('Lista niezaładowana - kliknij "Odśwież" / Wybierz obiekt z sekcji')
$combobox_LocalAD_List.SelectedIndex = 0

# ComboBox do wyboru sekcji (Użytkownicy, Komputery, Grupy)
$combobox_LocalAD_Section = New-Object System.Windows.Forms.ComboBox
$combobox_LocalAD_Section.Location = '680,10'
$combobox_LocalAD_Section.Width = 190
$combobox_LocalAD_Section.DropDownStyle = 'DropDownList'
$combobox_LocalAD_Section.Items.AddRange(@("Użytkownicy", "Komputery", "Grupy"))

# RichTextBox z informacjami
$richtextbox_LocalAD_Info = New-Object System.Windows.Forms.RichTextBox
$richtextbox_LocalAD_Info.Location = '10,50'
$richtextbox_LocalAD_Info.Size = '660,600'
$richtextbox_LocalAD_Info.ReadOnly = $true
$richtextbox_LocalAD_Info.Font = New-Object System.Drawing.Font("Segoe UI", 10)

# Panel boczny z przyciskami
$panel_LocalAD_Actions = New-Object System.Windows.Forms.FlowLayoutPanel
$panel_LocalAD_Actions.Location = '680,50'
$panel_LocalAD_Actions.Size = '190,700'
$panel_LocalAD_Actions.FlowDirection = 'TopDown'
$panel_LocalAD_Actions.WrapContents = $false
$panel_LocalAD_Actions.AutoScroll = $true

# Funkcja pomocnicza tworząca przycisk
function New-LocalADActionButton($text) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Size = '170,45'
    $btn.Text = $text
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    return $btn
}

# Zestaw przycisków dla każdej sekcji
$LocalAD_ActionSets = @{
    "Użytkownicy" = @(
        "Odśwież", "Resetuj hasło", "Zablokuj/Odblokuj", "Zmień grupy",
        "Przypisz profil", "Wyeksportuj dane", "Przenieś OU", "Usuń konto", "Akcje specjalne"
    )
    "Komputery"   = @(
        "Odśwież", "Zrestartuj", "Zablokuj", "Zmień OU", "Wyłącz konto",
        "Wyczyść SID", "Usuń konto", "Akcje specjalne"
    )
    "Grupy"       = @(
        "Odśwież", "Dodaj członków", "Usuń członków", "Zmień nazwę",
        "Zmień typ grupy", "Zmień zakres", "Usuń grupę", "Akcje specjalne"
    )
}

# Globalna struktura UI — DOPIERO TERAZ ją inicjalizujemy
$buttons_LocalAD = @{ }
$HT_UI.LocalADTab = [ordered]@{
    Panel      = $panel_LocalAD
    SectionBox = $combobox_LocalAD_Section
    ObjectBox  = $combobox_LocalAD_List
    DetailsBox = $richtextbox_LocalAD_Info
    Views      = @{}
}

# Tworzenie i dodanie przycisków (razowo, potem ukrywane/pokazywane)
foreach ($section in $LocalAD_ActionSets.Keys) {
    $btnSet = @{}

    foreach ($label in $LocalAD_ActionSets[$section]) {
        $btn = New-LocalADActionButton $label
        $btn.Visible = $false
        $btn.Tag = $section
        $panel_LocalAD_Actions.Controls.Add($btn)
        $buttons_LocalAD[$label] = $btn
        $btnSet[$label] = $btn
    }

    $HT_UI.LocalADTab.Views[$section] = @{ Buttons = $btnSet }
}

# Funkcja pokazująca tylko przyciski dla wybranej sekcji
function Show-LocalADButtons {
    $selected = $combobox_LocalAD_Section.SelectedItem
    if (-not $selected -or -not $LocalAD_ActionSets.ContainsKey($selected)) {
            return
    }

    foreach ($btn in $panel_LocalAD_Actions.Controls) {
        $btn.Visible = $false
    }

    foreach ($label in $LocalAD_ActionSets[$selected]) {
        if ($buttons_LocalAD.ContainsKey($label)) {
            $buttons_LocalAD[$label].Visible = $true
        }
    }
}

# Dodanie kontrolek do panelu głównego
$panel_LocalAD.Controls.AddRange(@(
        $combobox_LocalAD_List,
        $combobox_LocalAD_Section,
        $richtextbox_LocalAD_Info,
        $panel_LocalAD_Actions
    ))

# Podłączenie do zakładki (upewnij się, że $HT_UI.Tabs["Lokalne AD"] istnieje wcześniej)
$HT_UI.Tabs["Lokalne AD"].Controls.Clear()
$HT_UI.Tabs["Lokalne AD"].Controls.Add($panel_LocalAD)

# Ustawienie domyślnej sekcji i pokazanie jej przycisków
$combobox_LocalAD_Section.SelectedIndex = 0
Show-LocalADButtons
