# Panel "Lokalne AD"
$panel_LocalAD = New-Object System.Windows.Forms.Panel
$panel_LocalAD.Dock = 'Fill'

# ComboBox do wyboru sekcji (Użytkownicy, Komputery, Grupy)
$combobox_LocalAD_Section = New-Object System.Windows.Forms.ComboBox
$combobox_LocalAD_Section.Location = '10,10'
$combobox_LocalAD_Section.Width = 200
$combobox_LocalAD_Section.DropDownStyle = 'DropDownList'
$combobox_LocalAD_Section.Items.AddRange(@("Użytkownicy", "Komputery", "Grupy"))
$combobox_LocalAD_Section.SelectedIndex = 0

# Panel główny dla dynamicznych sekcji
$panel_LocalAD_Content = New-Object System.Windows.Forms.Panel
$panel_LocalAD_Content.Location = '10,50'
$panel_LocalAD_Content.Size = '860,600'
$panel_LocalAD_Content.BorderStyle = 'FixedSingle'

# ========== Funkcja do tworzenia widoku sekcji ==========
function New-LocalADSection {
    param (
        [string]$type
    )

    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = 'Fill'

    $combo = New-Object System.Windows.Forms.ComboBox
    $combo.Location = '10,10'
    $combo.Width = 650
    $combo.DropDownStyle = 'DropDownList'
    $combo.Items.Add("Lista niezaładowana - kliknij Odśwież")
    $combo.SelectedIndex = 0

    $rich = New-Object System.Windows.Forms.RichTextBox
    $rich.Location = '10,50'
    $rich.Size = '650,540'
    $rich.ReadOnly = $true

    $buttonPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttonPanel.Location = '680,50'
    $buttonPanel.Size = '170,680'
    $buttonPanel.FlowDirection = 'TopDown'
    $buttonPanel.WrapContents = $false
    $buttonPanel.AutoScroll = $true

    function New-ActionBtn($label) {
        $btn = New-Object System.Windows.Forms.Button
        $btn.Size = '160,45'
        $btn.Text = $label
        $btn.Font = New-Object System.Drawing.Font("Segoe UI", 10)
        return $btn
    }

    $actions = switch ($type) {
        "Użytkownicy" {
            @(
                "Odśwież", "Resetuj hasło", "Zablokuj/Odblokuj", "Zmień grupy",
                "Przypisz profil", "Wyeksportuj dane", "Przenieś OU", "Usuń konto"
            )
        }
        "Komputery" {
            @(
                "Odśwież", "Zrestartuj", "Zablokuj", "Zmień OU", "Wyłącz konto",
                "Wyczyść SID", "Usuń konto"
            )
        }
        "Grupy" {
            @(
                "Odśwież", "Dodaj członków", "Usuń członków", "Zmień nazwę",
                "Zmień typ grupy", "Zmień zakres", "Usuń grupę"
            )
        }
    }

    foreach ($label in $actions) {
        $buttonPanel.Controls.Add((New-ActionBtn $label))
    } 

    $panel.Controls.AddRange(@($combo, $rich, $buttonPanel))
    return [ordered]@{
        Panel    = $panel
        ComboBox = $combo
        RichBox  = $rich
        Buttons  = $buttonPanel
    }
}

# ========== Sekcje ==========
$LocalAD_Views = @{
    "Użytkownicy" = New-LocalADSection "Użytkownicy"
    "Komputery"   = New-LocalADSection "Komputery"
    "Grupy"       = New-LocalADSection "Grupy"
}

# ========== Zmiana widoku ==========
$combobox_LocalAD_Section.add_SelectedIndexChanged({
        $panel_LocalAD_Content.Controls.Clear()
        $section = $combobox_LocalAD_Section.SelectedItem
        $panel_LocalAD_Content.Controls.Add($LocalAD_Views[$section].Panel)
    })

# Wyświetl domyślny widok
$panel_LocalAD_Content.Controls.Add($LocalAD_Views["Użytkownicy"].Panel)

# Dodanie kontrolek do głównego panelu
$panel_LocalAD.Controls.AddRange(@(
        $combobox_LocalAD_Section,
        $panel_LocalAD_Content
    ))

# Podłączenie do zakładki
$HT_UI.Tabs["Lokalne AD"].Controls.Clear()
$HT_UI.Tabs["Lokalne AD"].Controls.Add($panel_LocalAD)

# Eksport referencji
$global:HT_UI.LocalADTab = [ordered]@{
    Panel    = $panel_LocalAD
    ComboBox = $combobox_LocalAD_Section
    Views    = $LocalAD_Views
} 
