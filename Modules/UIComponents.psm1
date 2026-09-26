# Wspólne komponenty interfejsu (Windows Forms) aplikacji Helpdesk Tools
# Moduł jest importowany globalnie, dzięki czemu wszystkie pozostałe moduły mogą korzystać z tych funkcji.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:IconCache = @{}
$script:MissingIcons = @{}
$script:BusyDepth = 0
$script:ToolTip = New-Object System.Windows.Forms.ToolTip
$script:ToolTip.InitialDelay = 400
$script:ToolTip.ReshowDelay = 200

function New-HTColor([int]$R, [int]$G, [int]$B) { return [System.Drawing.Color]::FromArgb($R, $G, $B) }

# Motyw kolorystyczny aplikacji
$Global:HTTheme = @{
    Font         = New-Object System.Drawing.Font("Segoe UI", 9.75)
    FontBold     = New-Object System.Drawing.Font("Segoe UI Semibold", 9.75)
    FontSmall    = New-Object System.Drawing.Font("Segoe UI", 8.25)
    FontSmallBold = New-Object System.Drawing.Font("Segoe UI Semibold", 8.25)
    FontTitle    = New-Object System.Drawing.Font("Segoe UI Semibold", 15)
    FontLarge    = New-Object System.Drawing.Font("Segoe UI Semibold", 20)
    FontMono     = New-Object System.Drawing.Font("Consolas", 10)
    NavBack      = New-HTColor 30 41 59
    NavHover     = New-HTColor 51 65 85
    NavActive    = New-HTColor 37 99 235
    NavText      = New-HTColor 226 232 240
    NavMuted     = New-HTColor 148 163 184
    Background   = New-HTColor 241 245 249
    Surface      = [System.Drawing.Color]::White
    Border       = New-HTColor 203 213 225
    Text         = New-HTColor 15 23 42
    Muted        = New-HTColor 100 116 139
    Accent       = New-HTColor 37 99 235
    AccentDark   = New-HTColor 29 78 216
    AccentLight  = New-HTColor 219 234 254
    Success      = New-HTColor 22 163 74
    SuccessLight = New-HTColor 220 252 231
    Warning      = New-HTColor 217 119 6
    WarningLight = New-HTColor 254 243 199
    Danger       = New-HTColor 220 38 38
    DangerLight  = New-HTColor 254 226 226
}

#region Ikony i przyciski

# Ładuje ikonę z katalogu Resources/Icons (z pamięcią podręczną, bez blokowania pliku)
function Get-HTIcon {
    param (
        [string]$Name,
        [int]$Size = 20
    )

    if (-not $Name) { return $null }
    $key = "$Name|$Size"
    if ($script:IconCache.ContainsKey($key)) { return $script:IconCache[$key] }

    $base = if ($Global:IconsPath) { $Global:IconsPath } else { Join-Path $PSScriptRoot "../Resources/Icons" }
    $path = Join-Path $base $Name

    if (-not (Test-Path -LiteralPath $path)) {
        if (-not $script:MissingIcons.ContainsKey($Name)) {
            $script:MissingIcons[$Name] = $true
            Write-Log -Message "Brak pliku ikony: $path" -Type "Warn"
        }
        return $null
    }

    try {
        $bytes = [System.IO.File]::ReadAllBytes($path)
        $stream = New-Object System.IO.MemoryStream(, $bytes)
        $source = [System.Drawing.Image]::FromStream($stream)
        $bitmap = New-Object System.Drawing.Bitmap($Size, $Size)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.DrawImage($source, 0, 0, $Size, $Size)
        $graphics.Dispose()
        $source.Dispose()
        $stream.Dispose()
        $script:IconCache[$key] = $bitmap
        return $bitmap
    }
    catch {
        Write-Log -Message "Nie udało się załadować ikony '$Name': $($_.Exception.Message)" -Type "Warn"
        return $null
    }
}

# Ustawia podpowiedź (tooltip) dla kontrolki
function Set-HTToolTip {
    param (
        [Parameter(Mandatory)][System.Windows.Forms.Control]$Control,
        [AllowEmptyString()][string]$Text
    )
    $script:ToolTip.SetToolTip($Control, $Text)
}

# Ustawia styl przycisku
function Set-HTButtonStyle {
    param (
        [Parameter(Mandatory)][System.Windows.Forms.Button]$Button,
        [ValidateSet("Default", "Primary", "Danger", "Nav", "NavActive", "Connected", "Subtle")]
        [string]$Style = "Default"
    )

    $t = $Global:HTTheme
    $Button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $Button.UseVisualStyleBackColor = $false
    $Button.FlatAppearance.BorderSize = 1

    switch ($Style) {
        "Default" {
            $Button.BackColor = $t.Surface
            $Button.ForeColor = $t.Text
            $Button.FlatAppearance.BorderColor = $t.Border
            $Button.FlatAppearance.MouseOverBackColor = $t.AccentLight
            $Button.FlatAppearance.MouseDownBackColor = $t.AccentLight
        }
        "Primary" {
            $Button.BackColor = $t.Accent
            $Button.ForeColor = [System.Drawing.Color]::White
            $Button.FlatAppearance.BorderColor = $t.Accent
            $Button.FlatAppearance.MouseOverBackColor = $t.AccentDark
            $Button.FlatAppearance.MouseDownBackColor = $t.AccentDark
        }
        "Danger" {
            $Button.BackColor = $t.Surface
            $Button.ForeColor = $t.Danger
            $Button.FlatAppearance.BorderColor = New-HTColor 252 165 165
            $Button.FlatAppearance.MouseOverBackColor = $t.DangerLight
            $Button.FlatAppearance.MouseDownBackColor = $t.DangerLight
        }
        "Subtle" {
            $Button.BackColor = $t.Background
            $Button.ForeColor = $t.Text
            $Button.FlatAppearance.BorderColor = $t.Border
            $Button.FlatAppearance.MouseOverBackColor = $t.AccentLight
            $Button.FlatAppearance.MouseDownBackColor = $t.AccentLight
        }
        "Connected" {
            $Button.BackColor = $t.SuccessLight
            $Button.ForeColor = New-HTColor 21 128 61
            $Button.FlatAppearance.BorderColor = $t.Success
            $Button.FlatAppearance.MouseOverBackColor = $t.DangerLight
            $Button.FlatAppearance.MouseDownBackColor = $t.DangerLight
        }
        "Nav" {
            $Button.BackColor = $t.NavBack
            $Button.ForeColor = $t.NavText
            $Button.FlatAppearance.BorderSize = 0
            $Button.FlatAppearance.MouseOverBackColor = $t.NavHover
            $Button.FlatAppearance.MouseDownBackColor = $t.NavHover
        }
        "NavActive" {
            $Button.BackColor = $t.NavActive
            $Button.ForeColor = [System.Drawing.Color]::White
            $Button.FlatAppearance.BorderSize = 0
            $Button.FlatAppearance.MouseOverBackColor = $t.NavActive
            $Button.FlatAppearance.MouseDownBackColor = $t.NavActive
        }
    }
}

# Tworzy przycisk w stylu aplikacji
function New-HTButton {
    param (
        [string]$Text,
        [string]$Icon,
        [ValidateSet("Default", "Primary", "Danger", "Nav", "NavActive", "Connected", "Subtle")]
        [string]$Style = "Default",
        [int]$Width = 180,
        [int]$Height = 36,
        [string]$ToolTip,
        [int]$IconSize = 20
    )

    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Size = New-Object System.Drawing.Size($Width, $Height)
    $button.Font = $Global:HTTheme.Font
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    $button.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $button.ImageAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $button.TextImageRelation = [System.Windows.Forms.TextImageRelation]::ImageBeforeText
    $button.Padding = New-Object System.Windows.Forms.Padding(8, 0, 4, 0)
    Set-HTButtonStyle -Button $button -Style $Style

    if ($Icon) {
        $image = Get-HTIcon -Name $Icon -Size $IconSize
        if ($image) { $button.Image = $image }
    }
    if (-not $button.Image) {
        $button.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    }
    if ($ToolTip) { Set-HTToolTip -Control $button -Text $ToolTip }

    return $button
}

# Panel z przyciskami akcji (prawa kolumna sekcji)
# Actions: tablica hashtabel @{ Group = 'Nagłówek' } lub @{ Key; Text; Icon; Style; ToolTip }
function New-HTActionPanel {
    param (
        [object[]]$Actions,
        [int]$Width = 220
    )

    $panel = New-Object System.Windows.Forms.FlowLayoutPanel
    $panel.Dock = [System.Windows.Forms.DockStyle]::Right
    $panel.Width = $Width
    $panel.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
    $panel.WrapContents = $false
    $panel.AutoScroll = $true
    $panel.Padding = New-Object System.Windows.Forms.Padding(10, 6, 10, 6)
    $panel.BackColor = $Global:HTTheme.Surface

    $buttons = [ordered]@{}
    $innerWidth = $Width - 38

    foreach ($action in $Actions) {
        if ($action.Group) {
            $header = New-Object System.Windows.Forms.Label
            $header.Text = $action.Group.ToUpper()
            $header.Font = $Global:HTTheme.FontSmallBold
            $header.ForeColor = $Global:HTTheme.Muted
            $header.AutoSize = $false
            $header.Size = New-Object System.Drawing.Size($innerWidth, 26)
            $header.TextAlign = [System.Drawing.ContentAlignment]::BottomLeft
            $header.Margin = New-Object System.Windows.Forms.Padding(0, 6, 0, 2)
            $panel.Controls.Add($header)
            if (-not $action.Key) { continue }
        }

        $style = if ($action.Style) { $action.Style } else { "Default" }
        $button = New-HTButton -Text $action.Text -Icon $action.Icon -Style $style -Width $innerWidth -Height 34 -ToolTip $action.ToolTip
        $button.Margin = New-Object System.Windows.Forms.Padding(0, 2, 0, 2)
        $button.Name = "Action_$($action.Key)"
        $panel.Controls.Add($button)
        $buttons[$action.Key] = $button
    }

    return @{
        Panel   = $panel
        Buttons = $buttons
    }
}

#endregion

#region Lista obiektów (ListView w trybie wirtualnym)

# Zwraca wartość kolumny dla obiektu (Property lub Expression)
function Get-HTColumnValue {
    param (
        [AllowNull()][object]$Object,
        [Parameter(Mandatory)][object]$Column
    )
    if ($null -eq $Object) { return "" }
    try {
        $value = if ($Column.Expression) { & $Column.Expression $Object } else { $Object.($Column.Property) }
        return (ConvertTo-HTDisplayValue $value)
    }
    catch {
        return ""
    }
}

# Tworzy listę (ListView) w trybie wirtualnym z sortowaniem i filtrowaniem
# Columns: tablica @{ Text = 'Nagłówek'; Property = 'NazwaWłaściwości' (lub Expression = { param($o) ... }); Width = 150 }
function New-HTListView {
    param (
        [Parameter(Mandatory)][object[]]$Columns,
        [switch]$MultiSelect
    )

    $list = New-Object System.Windows.Forms.ListView
    $list.View = [System.Windows.Forms.View]::Details
    $list.FullRowSelect = $true
    $list.HideSelection = $false
    $list.MultiSelect = [bool]$MultiSelect
    $list.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $list.Font = $Global:HTTheme.Font
    $list.Dock = [System.Windows.Forms.DockStyle]::Fill
    $list.VirtualMode = $true
    $list.VirtualListSize = 0

    # Podwójne buforowanie - brak migotania przy przewijaniu
    $prop = $list.GetType().GetProperty("DoubleBuffered", [System.Reflection.BindingFlags]"NonPublic,Instance")
    if ($prop) { $prop.SetValue($list, $true, $null) }

    foreach ($column in $Columns) {
        $width = if ($column.Width) { [int]$column.Width } else { 150 }
        [void]$list.Columns.Add($column.Text, $width)
    }

    $list.Tag = @{
        Columns        = $Columns
        Data           = @()
        Index          = @()
        View           = @()
        FilterText     = ""
        SortColumn     = -1
        SortDescending = $false
        CountLabel     = $null
    }

    $list.Add_RetrieveVirtualItem({
            param($src, $evt)
            $state = $src.Tag
            $item = New-Object System.Windows.Forms.ListViewItem
            try {
                if ($evt.ItemIndex -lt $state.View.Count) {
                    $object = $state.View[$evt.ItemIndex]
                    $first = $true
                    foreach ($column in $state.Columns) {
                        $text = Get-HTColumnValue -Object $object -Column $column
                        if ($first) { $item.Text = $text; $first = $false } else { [void]$item.SubItems.Add($text) }
                    }
                }
            }
            catch { }
            while ($item.SubItems.Count -lt $state.Columns.Count) { [void]$item.SubItems.Add("") }
            $evt.Item = $item
        })

    $list.Add_ColumnClick({
            param($src, $evt)
            $state = $src.Tag
            if ($state.SortColumn -eq $evt.Column) {
                $state.SortDescending = -not $state.SortDescending
            }
            else {
                $state.SortColumn = $evt.Column
                $state.SortDescending = $false
            }
            Update-HTListFilter -ListView $src -Text $state.FilterText
        })

    return $list
}

# Zmienia kolumny listy (np. przy przełączaniu typu obiektów)
function Set-HTListColumns {
    param (
        [Parameter(Mandatory)][System.Windows.Forms.ListView]$ListView,
        [Parameter(Mandatory)][object[]]$Columns
    )
    $state = $ListView.Tag
    $ListView.BeginUpdate()
    try {
        $ListView.SelectedIndices.Clear()
        $ListView.VirtualListSize = 0
        $ListView.Columns.Clear()
        foreach ($column in $Columns) {
            $width = if ($column.Width) { [int]$column.Width } else { 150 }
            [void]$ListView.Columns.Add($column.Text, $width)
        }
        $state.Columns = $Columns
        $state.SortColumn = -1
        $state.SortDescending = $false
        $state.Data = @()
        $state.Index = @()
        $state.View = @()
    }
    finally {
        $ListView.EndUpdate()
    }
}

# Ustawia dane listy i buduje indeks wyszukiwania
function Set-HTListData {
    param (
        [Parameter(Mandatory)][System.Windows.Forms.ListView]$ListView,
        [AllowNull()][AllowEmptyCollection()][object[]]$Data
    )

    $state = $ListView.Tag
    $items = @($Data | Where-Object { $null -ne $_ })
    $index = New-Object string[] $items.Count

    for ($i = 0; $i -lt $items.Count; $i++) {
        $parts = foreach ($column in $state.Columns) { Get-HTColumnValue -Object $items[$i] -Column $column }
        $index[$i] = ($parts -join " ").ToLowerInvariant()
    }

    $state.Data = $items
    $state.Index = $index
    Update-HTListFilter -ListView $ListView -Text $state.FilterText
}

# Filtruje listę (wszystkie słowa muszą wystąpić w którejś z kolumn) i sortuje
function Update-HTListFilter {
    param (
        [Parameter(Mandatory)][System.Windows.Forms.ListView]$ListView,
        [AllowEmptyString()][AllowNull()][string]$Text
    )

    $state = $ListView.Tag
    $state.FilterText = "$Text"
    $terms = @("$Text".ToLowerInvariant().Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries))

    $result = New-Object System.Collections.Generic.List[object]
    for ($i = 0; $i -lt $state.Data.Count; $i++) {
        $matchAll = $true
        foreach ($term in $terms) {
            if ($state.Index[$i].IndexOf($term, [System.StringComparison]::Ordinal) -lt 0) { $matchAll = $false; break }
        }
        if ($matchAll) { $result.Add($state.Data[$i]) }
    }

    $view = $result.ToArray()
    if ($state.SortColumn -ge 0 -and $state.SortColumn -lt $state.Columns.Count) {
        $column = $state.Columns[$state.SortColumn]
        $sortKey = if ($column.SortExpression) { $column.SortExpression }
        elseif ($column.Expression) { $column.Expression }
        else { [scriptblock]::Create("`$_.'$($column.Property)'") }
        $sortBlock = if ($column.SortExpression -or $column.Expression) { { & $sortKey $_ }.GetNewClosure() } else { $sortKey }
        $view = @($view | Sort-Object -Property $sortBlock -Descending:$state.SortDescending)
    }

    $ListView.BeginUpdate()
    try {
        $ListView.SelectedIndices.Clear()
        $state.View = @($view)
        $ListView.VirtualListSize = $state.View.Count
        $ListView.Invalidate()
    }
    finally {
        $ListView.EndUpdate()
    }

    if ($state.CountLabel) {
        $state.CountLabel.Text = if ($state.Data.Count -eq $state.View.Count) {
            "Obiektów: $($state.Data.Count)"
        }
        else {
            "Wyświetlono $($state.View.Count) z $($state.Data.Count)"
        }
    }
}

# Zwraca zaznaczone obiekty
function Get-HTListSelection {
    param ([Parameter(Mandatory)][System.Windows.Forms.ListView]$ListView)
    $state = $ListView.Tag
    $selected = foreach ($i in $ListView.SelectedIndices) {
        if ($i -lt $state.View.Count) { $state.View[$i] }
    }
    return @($selected)
}

# Zwraca dane listy (wszystkie lub tylko przefiltrowane)
function Get-HTListData {
    param (
        [Parameter(Mandatory)][System.Windows.Forms.ListView]$ListView,
        [switch]$Filtered
    )
    if ($Filtered) { return @($ListView.Tag.View) }
    return @($ListView.Tag.Data)
}

# Zaznacza pierwszy obiekt spełniający warunek
function Select-HTListObject {
    param (
        [Parameter(Mandatory)][System.Windows.Forms.ListView]$ListView,
        [Parameter(Mandatory)][scriptblock]$Predicate
    )
    $state = $ListView.Tag
    for ($i = 0; $i -lt $state.View.Count; $i++) {
        $candidate = $state.View[$i]
        if (& $Predicate $candidate) {
            $ListView.SelectedIndices.Clear()
            [void]$ListView.SelectedIndices.Add($i)
            $ListView.EnsureVisible($i)
            return $true
        }
    }
    return $false
}

# Zamienia dane listy na obiekty z kolumnami (np. do eksportu CSV)
function ConvertTo-HTExportObject {
    param (
        [AllowEmptyCollection()][object[]]$Data,
        [Parameter(Mandatory)][object[]]$Columns
    )
    foreach ($object in $Data) {
        $row = [ordered]@{}
        foreach ($column in $Columns) { $row[$column.Text] = Get-HTColumnValue -Object $object -Column $column }
        [PSCustomObject]$row
    }
}

# Zwraca pierwszy zaznaczony obiekt widoku lub wyświetla komunikat
function Get-HTSelectedObject {
    param (
        [Parameter(Mandatory)][System.Collections.IDictionary]$View,
        [string]$What = "obiekt"
    )
    $selected = @(Get-HTListSelection -ListView $View.List)
    if ($selected.Count -eq 0) {
        Show-Dialog -Message "Najpierw wybierz $What z listy." -Title "Brak zaznaczenia" -Type "Warning" | Out-Null
        return $null
    }
    return $selected[0]
}

# Eksport (przefiltrowanej) listy do CSV
function Export-HTListView {
    param (
        [Parameter(Mandatory)][System.Windows.Forms.ListView]$ListView,
        [string]$Name = "eksport"
    )
    $data = Get-HTListData -ListView $ListView -Filtered
    if ($data.Count -eq 0) {
        Show-Dialog -Message "Lista jest pusta - najpierw ją odśwież." -Title "Eksport" -Type "Info" | Out-Null
        return
    }
    $rows = @(ConvertTo-HTExportObject -Data $data -Columns $ListView.Tag.Columns)
    Save-ContentToFile -Data $rows -Format "csv" -Title "Eksport listy" -DefaultName $Name | Out-Null
}

# Ładowanie szczegółów zaznaczonego obiektu z opóźnieniem (bez zapytań przy szybkim przewijaniu listy)
# Loader: { param($Object) ... return słownik }
function Register-HTDetailsLoader {
    param (
        [Parameter(Mandatory)][System.Collections.IDictionary]$View,
        [Parameter(Mandatory)][scriptblock]$Loader,
        [int]$Delay = 300
    )

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = $Delay
    $timer.Tag = @{ View = $View; Loader = $Loader }
    $timer.Add_Tick({
            param($src, $evt)
            $src.Stop()
            $state = $src.Tag
            $selected = @(Get-HTListSelection -ListView $state.View.List)
            if ($selected.Count -ne 1) { return }

            Set-HTDetails -ListView $state.View.Details -Data $null -Message "Ładowanie szczegółów..."
            Set-HTBusy -Busy $true -Text "Ładowanie szczegółów..."
            try {
                $data = & $state.Loader $selected[0]
                Set-HTDetails -ListView $state.View.Details -Data $data
            }
            catch {
                Set-HTDetails -ListView $state.View.Details -Data $null -Message "Błąd: $($_.Exception.Message)"
                Write-Log -Message "Błąd ładowania szczegółów: $($_.Exception.Message)" -Type "Error"
            }
            finally {
                Set-HTBusy -Busy $false -Text "Gotowe"
            }
        })

    $View.List.Tag.DetailsTimer = $timer
    $View.DetailsTimer = $timer
    $View.List.Add_SelectedIndexChanged({
            param($src, $evt)
            $t = $src.Tag.DetailsTimer
            $t.Stop()
            $t.Start()
        })
}

# Ponowne wczytanie szczegółów zaznaczonego obiektu (np. po zmianie)
function Invoke-HTDetailsReload {
    param ([Parameter(Mandatory)][System.Collections.IDictionary]$View)
    $View.List.Invalidate()
    if ($View.DetailsTimer) {
        $View.DetailsTimer.Stop()
        $View.DetailsTimer.Start()
    }
}

#endregion

#region Panel szczegółów

# Lista "Właściwość / Wartość" z grupami i kopiowaniem
function New-HTDetailsView {
    $list = New-Object System.Windows.Forms.ListView
    $list.View = [System.Windows.Forms.View]::Details
    $list.FullRowSelect = $true
    $list.HideSelection = $false
    $list.MultiSelect = $true
    $list.HeaderStyle = [System.Windows.Forms.ColumnHeaderStyle]::Nonclickable
    $list.BorderStyle = [System.Windows.Forms.BorderStyle]::None
    $list.Font = $Global:HTTheme.Font
    $list.Dock = [System.Windows.Forms.DockStyle]::Fill
    $list.ShowGroups = $true
    [void]$list.Columns.Add("Właściwość", 190)
    [void]$list.Columns.Add("Wartość", 300)

    $list.Add_Resize({
            param($src, $evt)
            $width = $src.ClientSize.Width - $src.Columns[0].Width - 4
            if ($width -gt 80) { $src.Columns[1].Width = $width }
        })

    $menu = New-Object System.Windows.Forms.ContextMenuStrip
    $copyValue = $menu.Items.Add("Kopiuj wartość")
    $copyAll = $menu.Items.Add("Kopiuj wszystko")
    $copyValue.Tag = $list
    $copyAll.Tag = $list
    $copyValue.Add_Click({
            param($src, $evt)
            $values = foreach ($item in $src.Tag.SelectedItems) { $item.SubItems[1].Text }
            Set-HTClipboard -Text ($values -join [Environment]::NewLine)
        })
    $copyAll.Add_Click({
            param($src, $evt)
            $lines = foreach ($item in $src.Tag.Items) { "{0}: {1}" -f $item.Text, $item.SubItems[1].Text }
            Set-HTClipboard -Text ($lines -join [Environment]::NewLine)
        })
    $list.ContextMenuStrip = $menu

    $list.Add_DoubleClick({
            param($src, $evt)
            if ($src.SelectedItems.Count -gt 0) {
                Set-HTClipboard -Text $src.SelectedItems[0].SubItems[1].Text
                Set-HTStatus -Text "Skopiowano wartość: $($src.SelectedItems[0].Text)"
            }
        })

    return $list
}

# Wypełnia panel szczegółów. Data: słownik (klucz -> wartość). Wartość będąca słownikiem tworzy grupę.
function Set-HTDetails {
    param (
        [Parameter(Mandatory)][System.Windows.Forms.ListView]$ListView,
        [AllowNull()][object]$Data,
        [string]$Message
    )

    $ListView.BeginUpdate()
    try {
        $ListView.Items.Clear()
        $ListView.Groups.Clear()

        if ($null -eq $Data) {
            if ($Message) {
                $item = New-Object System.Windows.Forms.ListViewItem("")
                [void]$item.SubItems.Add($Message)
                $item.ForeColor = $Global:HTTheme.Muted
                [void]$ListView.Items.Add($item)
            }
            return
        }

        if ($Data -isnot [System.Collections.IDictionary]) {
            $dict = [ordered]@{}
            foreach ($p in $Data.PSObject.Properties) { $dict[$p.Name] = $p.Value }
            $Data = $dict
        }

        $hasGroups = @($Data.Values | Where-Object { $_ -is [System.Collections.IDictionary] }).Count -gt 0
        $generalGroup = $null
        if ($hasGroups) {
            $generalGroup = New-Object System.Windows.Forms.ListViewGroup("Ogólne", "Ogólne")
            [void]$ListView.Groups.Add($generalGroup)
        }

        foreach ($key in $Data.Keys) {
            $value = $Data[$key]
            if ($value -is [System.Collections.IDictionary]) {
                $group = New-Object System.Windows.Forms.ListViewGroup("$key", "$key")
                [void]$ListView.Groups.Add($group)
                if ($value.Count -eq 0) {
                    Add-HTDetailRow -ListView $ListView -Name "" -Value "(brak)" -Group $group
                }
                foreach ($innerKey in $value.Keys) {
                    Add-HTDetailRow -ListView $ListView -Name $innerKey -Value $value[$innerKey] -Group $group
                }
            }
            else {
                Add-HTDetailRow -ListView $ListView -Name $key -Value $value -Group $generalGroup
            }
        }
    }
    finally {
        $ListView.EndUpdate()
    }
}

function Add-HTDetailRow {
    param (
        [System.Windows.Forms.ListView]$ListView,
        [string]$Name,
        [AllowNull()][object]$Value,
        [AllowNull()][System.Windows.Forms.ListViewGroup]$Group
    )

    $values = if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string] -and $Value -isnot [System.Collections.IDictionary]) {
        @($Value)
    }
    else { , $Value }

    if ($values.Count -eq 0) { $values = @("") }

    $first = $true
    foreach ($v in $values) {
        $item = New-Object System.Windows.Forms.ListViewItem($(if ($first) { $Name } else { "" }))
        [void]$item.SubItems.Add((ConvertTo-HTDisplayValue $v))
        if ($Group) { $item.Group = $Group }
        [void]$ListView.Items.Add($item)
        $first = $false
    }
}

#endregion

#region Widok sekcji (lista + szczegóły + akcje)

# Tworzy standardowy układ sekcji: pasek narzędzi (wyszukiwanie), lista, szczegóły, panel akcji
function New-HTSectionView {
    param (
        [Parameter(Mandatory)][object[]]$Columns,
        [Parameter(Mandatory)][object[]]$Actions,
        [string]$SearchPlaceholder = "Szukaj... (Esc - wyczyść)",
        [switch]$MultiSelect,
        [System.Windows.Forms.Control[]]$ToolbarControls,
        [double]$ListRatio = 0.55
    )

    $t = $Global:HTTheme

    $root = New-Object System.Windows.Forms.Panel
    $root.Dock = [System.Windows.Forms.DockStyle]::Fill
    $root.BackColor = $t.Background
    $root.Padding = New-Object System.Windows.Forms.Padding(12, 10, 12, 12)

    # Pasek narzędzi
    $toolbarHost = New-Object System.Windows.Forms.Panel
    $toolbarHost.Dock = [System.Windows.Forms.DockStyle]::Top
    $toolbarHost.Height = 46

    $toolbar = New-Object System.Windows.Forms.FlowLayoutPanel
    $toolbar.Dock = [System.Windows.Forms.DockStyle]::Fill
    $toolbar.WrapContents = $false
    $toolbar.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
    $toolbarHost.Controls.Add($toolbar)

    foreach ($control in $ToolbarControls) {
        $control.Margin = New-Object System.Windows.Forms.Padding(0, 4, 8, 0)
        $toolbar.Controls.Add($control)
    }

    $search = New-Object System.Windows.Forms.TextBox
    $search.Width = 340
    $search.Font = $t.Font
    $search.PlaceholderText = $SearchPlaceholder
    $search.Margin = New-Object System.Windows.Forms.Padding(0, 6, 8, 0)
    $toolbar.Controls.Add($search)

    $refresh = New-HTButton -Text "Odśwież" -Icon "Refresh.png" -Style "Primary" -Width 120 -Height 32 -ToolTip "Pobierz aktualną listę (F5)"
    $refresh.Margin = New-Object System.Windows.Forms.Padding(0, 3, 8, 0)
    $toolbar.Controls.Add($refresh)

    $count = New-Object System.Windows.Forms.Label
    $count.AutoSize = $true
    $count.ForeColor = $t.Muted
    $count.Margin = New-Object System.Windows.Forms.Padding(4, 10, 0, 0)
    $count.Text = "Lista niezaładowana - kliknij 'Odśwież'"
    $toolbar.Controls.Add($count)

    # Panel akcji
    $actionPanel = New-HTActionPanel -Actions $Actions
    $spacer = New-Object System.Windows.Forms.Panel
    $spacer.Dock = [System.Windows.Forms.DockStyle]::Right
    $spacer.Width = 10

    # Lista i szczegóły
    $split = New-Object System.Windows.Forms.SplitContainer
    $split.Dock = [System.Windows.Forms.DockStyle]::Fill
    $split.Orientation = [System.Windows.Forms.Orientation]::Vertical
    $split.SplitterWidth = 8
    $split.BackColor = $t.Background
    $split.Panel1.BackColor = $t.Surface
    $split.Panel2.BackColor = $t.Surface
    $split.Tag = @{ Ratio = $ListRatio; Initialized = $false }
    # Proporcje listy/szczegółów ustawiane przy pierwszym wyświetleniu (gdy znany jest docelowy rozmiar)
    $initSplit = {
        param($src, $evt)
        if (-not $src.Tag.Initialized -and $src.Visible -and $src.Width -gt 500) {
            try {
                $src.SplitterDistance = [int]($src.Width * $src.Tag.Ratio)
                $src.Tag.Initialized = $true
                # Minimalne rozmiary paneli ustawiane dopiero przy znanej szerokości (inaczej WinForms zgłasza wyjątek)
                $src.Panel1MinSize = 150
                $src.Panel2MinSize = 150
            }
            catch { Write-Verbose "SplitterDistance: $_" }
        }
    }
    $split.Add_SizeChanged($initSplit)
    $split.Add_VisibleChanged($initSplit)

    $list = New-HTListView -Columns $Columns -MultiSelect:$MultiSelect
    $list.Tag.CountLabel = $count
    $split.Panel1.Controls.Add($list)

    $details = New-HTDetailsView
    $split.Panel2.Controls.Add($details)
    Set-HTDetails -ListView $details -Data $null -Message "Wybierz obiekt z listy, aby zobaczyć szczegóły."

    # Kolejność dodawania ma znaczenie dla dokowania
    $root.Controls.Add($split)
    $root.Controls.Add($spacer)
    $root.Controls.Add($actionPanel.Panel)
    $root.Controls.Add($toolbarHost)
    $split.BringToFront()

    # Wyszukiwanie z opóźnieniem (debounce)
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 250
    $timer.Tag = @{ List = $list; Search = $search }
    $timer.Add_Tick({
            param($src, $evt)
            $src.Stop()
            Update-HTListFilter -ListView $src.Tag.List -Text $src.Tag.Search.Text
        })
    $search.Tag = $timer
    $search.Add_TextChanged({
            param($src, $evt)
            $src.Tag.Stop()
            $src.Tag.Start()
        })
    $search.Add_KeyDown({
            param($src, $evt)
            if ($evt.KeyCode -eq [System.Windows.Forms.Keys]::Escape) {
                $src.Clear()
                $evt.SuppressKeyPress = $true
            }
            elseif ($evt.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
                $src.Tag.Stop()
                Update-HTListFilter -ListView $src.Tag.Tag.List -Text $src.Text
                $evt.SuppressKeyPress = $true
            }
        })

    return [ordered]@{
        Panel         = $root
        Toolbar       = $toolbar
        ToolbarHost   = $toolbarHost
        SearchBox     = $search
        RefreshButton = $refresh
        CountLabel    = $count
        List          = $list
        Details       = $details
        Actions       = $actionPanel.Buttons
        ActionPanel   = $actionPanel.Panel
        Split         = $split
    }
}

#endregion

#region Okna dialogowe

# Tworzy bazowe okno dialogowe
function New-HTDialogForm {
    param (
        [string]$Title,
        [int]$Width = 520,
        [int]$Height = 400,
        [switch]$Sizable
    )

    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.ClientSize = New-Object System.Drawing.Size($Width, $Height)
    $form.Font = $Global:HTTheme.Font
    $form.BackColor = $Global:HTTheme.Surface
    $form.ShowInTaskbar = $false
    $form.MinimizeBox = $false
    $form.MaximizeBox = [bool]$Sizable
    $form.FormBorderStyle = if ($Sizable) { [System.Windows.Forms.FormBorderStyle]::Sizable } else { [System.Windows.Forms.FormBorderStyle]::FixedDialog }
    $form.KeyPreview = $true

    if ($Global:HT_UI -and $Global:HT_UI.Form -and $Global:HT_UI.Form.Visible) {
        $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
        if ($Global:HT_UI.Form.Icon) { $form.Icon = $Global:HT_UI.Form.Icon }
    }
    else {
        $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    }
    return $form
}

# Pasek przycisków na dole okna dialogowego
function New-HTDialogButtonBar {
    param ([System.Windows.Forms.Control[]]$Buttons)
    $bar = New-Object System.Windows.Forms.FlowLayoutPanel
    $bar.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $bar.FlowDirection = [System.Windows.Forms.FlowDirection]::RightToLeft
    $bar.Height = 52
    $bar.Padding = New-Object System.Windows.Forms.Padding(10, 8, 10, 8)
    $bar.BackColor = $Global:HTTheme.Background
    foreach ($b in $Buttons) {
        $b.Margin = New-Object System.Windows.Forms.Padding(6, 0, 0, 0)
        $bar.Controls.Add($b)
    }
    return $bar
}

# Formularz z wieloma polami. Fields: tablica hashtabel:
#   @{ Name; Label; Type = Text|Password|Multiline|Combo|Check|Date|Number|Info; Default; Options; Required; Validation; Editable; Optional; Min; Max }
# Zwraca słownik Name -> wartość lub $null (anulowano).
function Show-HTFormDialog {
    param (
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][object[]]$Fields,
        [string]$Description,
        [string]$OkText = "Zapisz",
        [int]$Width = 560
    )

    $t = $Global:HTTheme
    $form = New-HTDialogForm -Title $Title -Width $Width -Height 200
    $form.AutoScroll = $true

    $table = New-Object System.Windows.Forms.TableLayoutPanel
    $table.ColumnCount = 2
    $table.AutoSize = $true
    $table.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    $table.Dock = [System.Windows.Forms.DockStyle]::Top
    $table.Padding = New-Object System.Windows.Forms.Padding(14, 12, 14, 6)
    [void]$table.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 170)))
    [void]$table.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))

    $inputWidth = $Width - 170 - 40
    $row = 0

    if ($Description) {
        $desc = New-Object System.Windows.Forms.Label
        $desc.Text = $Description
        $desc.AutoSize = $true
        $desc.MaximumSize = New-Object System.Drawing.Size(($Width - 40), 0)
        $desc.ForeColor = $t.Muted
        $desc.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 10)
        $table.Controls.Add($desc, 0, $row)
        $table.SetColumnSpan($desc, 2)
        $row++
    }

    $controls = [ordered]@{}
    foreach ($field in $Fields) {
        $type = if ($field.Type) { $field.Type } else { "Text" }

        if ($type -eq "Info") {
            $info = New-Object System.Windows.Forms.Label
            $info.Text = $field.Label
            $info.AutoSize = $true
            $info.MaximumSize = New-Object System.Drawing.Size(($Width - 40), 0)
            $info.ForeColor = $t.Muted
            $info.Margin = New-Object System.Windows.Forms.Padding(0, 4, 0, 6)
            $table.Controls.Add($info, 0, $row)
            $table.SetColumnSpan($info, 2)
            $row++
            continue
        }

        $label = New-Object System.Windows.Forms.Label
        $label.Text = if ($type -eq "Check") { "" } else { $field.Label + $(if ($field.Required) { " *" } else { "" }) }
        $label.AutoSize = $true
        $label.Margin = New-Object System.Windows.Forms.Padding(0, 7, 8, 0)

        switch ($type) {
            { $_ -in "Text", "Password" } {
                $control = New-Object System.Windows.Forms.TextBox
                $control.Width = $inputWidth
                $control.Text = "$($field.Default)"
                $control.UseSystemPasswordChar = ($type -eq "Password")
                if ($field.Placeholder) { $control.PlaceholderText = $field.Placeholder }
            }
            "Multiline" {
                $control = New-Object System.Windows.Forms.TextBox
                $control.Multiline = $true
                $control.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
                $control.AcceptsReturn = $true
                $control.Size = New-Object System.Drawing.Size($inputWidth, 90)
                $control.Text = "$($field.Default)"
            }
            "Combo" {
                $control = New-Object System.Windows.Forms.ComboBox
                $control.Width = $inputWidth
                $control.DropDownStyle = if ($field.Editable) { [System.Windows.Forms.ComboBoxStyle]::DropDown } else { [System.Windows.Forms.ComboBoxStyle]::DropDownList }
                foreach ($option in @($field.Options)) { [void]$control.Items.Add($option) }
                if ($null -ne $field.Default -and $control.Items.Contains($field.Default)) {
                    $control.SelectedItem = $field.Default
                }
                elseif ($field.Editable -and $field.Default) {
                    $control.Text = "$($field.Default)"
                }
                elseif ($control.Items.Count -gt 0) {
                    $control.SelectedIndex = 0
                }
            }
            "Check" {
                $control = New-Object System.Windows.Forms.CheckBox
                $control.Text = $field.Label
                $control.AutoSize = $true
                $control.Checked = [bool]$field.Default
            }
            "Date" {
                $control = New-Object System.Windows.Forms.DateTimePicker
                $control.Width = 220
                $control.Format = [System.Windows.Forms.DateTimePickerFormat]::Custom
                $control.CustomFormat = if ($field.DateOnly) { "yyyy-MM-dd" } else { "yyyy-MM-dd HH:mm" }
                $control.ShowCheckBox = [bool]$field.Optional
                if ($field.Default -is [datetime]) {
                    $control.Value = $field.Default
                    $control.Checked = $true
                }
                elseif ($field.Optional) {
                    $control.Checked = $false
                }
            }
            "Number" {
                $control = New-Object System.Windows.Forms.NumericUpDown
                $control.Width = 120
                $control.Minimum = if ($null -ne $field.Min) { $field.Min } else { 0 }
                $control.Maximum = if ($null -ne $field.Max) { $field.Max } else { 100000 }
                $control.Value = if ($null -ne $field.Default) { $field.Default } else { $control.Minimum }
            }
            default { throw "Nieobsługiwany typ pola: $type" }
        }

        $control.Margin = New-Object System.Windows.Forms.Padding(0, 3, 0, 3)
        if ($field.ToolTip) { Set-HTToolTip -Control $control -Text $field.ToolTip }
        $table.Controls.Add($label, 0, $row)
        $table.Controls.Add($control, 1, $row)
        $controls[$field.Name] = $control
        $row++
    }

    $errorLabel = New-Object System.Windows.Forms.Label
    $errorLabel.AutoSize = $true
    $errorLabel.ForeColor = $t.Danger
    $errorLabel.Margin = New-Object System.Windows.Forms.Padding(0, 6, 0, 0)
    $table.Controls.Add($errorLabel, 0, $row)
    $table.SetColumnSpan($errorLabel, 2)

    $ok = New-HTButton -Text $OkText -Style "Primary" -Width 120 -Height 34
    $cancel = New-HTButton -Text "Anuluj" -Width 100 -Height 34
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $bar = New-HTDialogButtonBar -Buttons @($ok, $cancel)

    $form.Controls.Add($table)
    $form.Controls.Add($bar)
    $form.CancelButton = $cancel

    $ok.Add_Click({
            foreach ($field in $Fields) {
                $control = $controls[$field.Name]
                if (-not $control) { continue }
                if ($control -is [System.Windows.Forms.TextBox] -or ($control -is [System.Windows.Forms.ComboBox])) {
                    $value = $control.Text.Trim()
                    if ($field.Required -and -not $value) {
                        $errorLabel.Text = "Pole '$($field.Label)' jest wymagane."
                        $control.Focus()
                        return
                    }
                    if ($value -and $field.Validation -and -not (Test-HTInputValue -Value $value -ValidationType $field.Validation)) {
                        $errorLabel.Text = "Pole '$($field.Label)' ma nieprawidłowy format."
                        $control.Focus()
                        return
                    }
                }
            }
            $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        })

    # Dopasowanie wysokości okna do zawartości
    $form.Add_Shown({
            $preferred = $table.PreferredSize.Height + $bar.Height + 10
            $form.ClientSize = New-Object System.Drawing.Size($form.ClientSize.Width, [Math]::Min(760, $preferred))
            $first = @($controls.Values | Where-Object { $_ -is [System.Windows.Forms.TextBox] -or $_ -is [System.Windows.Forms.ComboBox] }) | Select-Object -First 1
            if ($first) { $first.Focus() | Out-Null }
        })

    try {
        if ($form.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return $null }

        $result = [ordered]@{}
        foreach ($field in $Fields) {
            $control = $controls[$field.Name]
            if (-not $control) { continue }
            $result[$field.Name] = switch ($control.GetType().Name) {
                "TextBox" { $control.Text.Trim() }
                "ComboBox" { if ($field.Editable) { $control.Text.Trim() } else { $control.SelectedItem } }
                "CheckBox" { $control.Checked }
                "DateTimePicker" { if ($control.ShowCheckBox -and -not $control.Checked) { $null } else { $control.Value } }
                "NumericUpDown" { [int]$control.Value }
            }
        }
        return $result
    }
    finally {
        $form.Dispose()
    }
}

# Okno wyboru obiektów z listy (z wyszukiwaniem). Zwraca wybrane obiekty lub $null.
function Show-HTSelectionDialog {
    param (
        [Parameter(Mandatory)][string]$Title,
        [AllowEmptyCollection()][object[]]$Items,
        [object[]]$Columns,
        [string]$Prompt,
        [switch]$MultiSelect,
        [string]$OkText = "Wybierz"
    )

    $Items = @($Items | Where-Object { $null -ne $_ })
    if ($Items.Count -eq 0) {
        Show-Dialog -Message "Brak elementów do wyboru." -Title $Title -Type "Info" | Out-Null
        return $null
    }

    $isString = $Items[0] -is [string]
    if ($isString) {
        $Items = @($Items | ForEach-Object { [PSCustomObject]@{ Name = $_ } })
        $Columns = @(@{ Text = "Nazwa"; Property = "Name"; Width = 600 })
    }
    if (-not $Columns) {
        $Columns = @($Items[0].PSObject.Properties | Select-Object -First 6 | ForEach-Object { @{ Text = $_.Name; Property = $_.Name; Width = 180 } })
    }

    $form = New-HTDialogForm -Title $Title -Width 760 -Height 520 -Sizable
    $form.MinimumSize = New-Object System.Drawing.Size(500, 360)

    $top = New-Object System.Windows.Forms.Panel
    $top.Dock = [System.Windows.Forms.DockStyle]::Top
    $top.Height = if ($Prompt) { 70 } else { 44 }
    $top.Padding = New-Object System.Windows.Forms.Padding(12, 8, 12, 4)

    $search = New-Object System.Windows.Forms.TextBox
    $search.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $search.PlaceholderText = if ($MultiSelect) { "Szukaj... (Ctrl/Shift - zaznaczanie wielu)" } else { "Szukaj..." }
    $top.Controls.Add($search)

    if ($Prompt) {
        $label = New-Object System.Windows.Forms.Label
        $label.Text = $Prompt
        $label.Dock = [System.Windows.Forms.DockStyle]::Top
        $label.Height = 24
        $top.Controls.Add($label)
    }

    $listHost = New-Object System.Windows.Forms.Panel
    $listHost.Dock = [System.Windows.Forms.DockStyle]::Fill
    $listHost.Padding = New-Object System.Windows.Forms.Padding(12, 4, 12, 4)
    $list = New-HTListView -Columns $Columns -MultiSelect:$MultiSelect
    $list.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $listHost.Controls.Add($list)

    $count = New-Object System.Windows.Forms.Label
    $count.AutoSize = $true
    $count.ForeColor = $Global:HTTheme.Muted
    $count.Margin = New-Object System.Windows.Forms.Padding(0, 8, 0, 0)
    $list.Tag.CountLabel = $count

    $ok = New-HTButton -Text $OkText -Style "Primary" -Width 120 -Height 34
    $cancel = New-HTButton -Text "Anuluj" -Width 100 -Height 34
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $bar = New-HTDialogButtonBar -Buttons @($ok, $cancel, $count)

    $form.Controls.Add($listHost)
    $form.Controls.Add($top)
    $form.Controls.Add($bar)
    $listHost.BringToFront()
    $form.CancelButton = $cancel

    Set-HTListData -ListView $list -Data $Items

    $search.Add_TextChanged({ Update-HTListFilter -ListView $list -Text $search.Text })
    $ok.Add_Click({
            if ($list.SelectedIndices.Count -eq 0) {
                Show-Dialog -Message "Zaznacz co najmniej jeden element." -Title $Title -Type "Warning" | Out-Null
                return
            }
            $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
        })
    $list.Add_DoubleClick({
            if ($list.SelectedIndices.Count -gt 0) { $form.DialogResult = [System.Windows.Forms.DialogResult]::OK }
        })
    $form.Add_Shown({ $search.Focus() | Out-Null })

    try {
        if ($form.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
        $selected = Get-HTListSelection -ListView $list
        if ($isString) { return @($selected | ForEach-Object { $_.Name }) }
        return $selected
    }
    finally {
        $form.Dispose()
    }
}

# Podgląd danych tabelarycznych z wyszukiwaniem, kopiowaniem i eksportem CSV
function Show-HTDataViewer {
    param (
        [Parameter(Mandatory)][string]$Title,
        [AllowEmptyCollection()][AllowNull()][object[]]$Data,
        [object[]]$Columns,
        [string]$Description,
        [string]$ExportName = "eksport"
    )

    $Data = @($Data | Where-Object { $null -ne $_ })
    if ($Data.Count -eq 0) {
        Show-Dialog -Message "Brak danych do wyświetlenia." -Title $Title -Type "Info" | Out-Null
        return
    }
    if (-not $Columns) {
        $Columns = @($Data[0].PSObject.Properties | ForEach-Object { @{ Text = $_.Name; Property = $_.Name; Width = 170 } })
    }

    $form = New-HTDialogForm -Title $Title -Width 980 -Height 600 -Sizable
    $form.MinimumSize = New-Object System.Drawing.Size(600, 400)

    $top = New-Object System.Windows.Forms.Panel
    $top.Dock = [System.Windows.Forms.DockStyle]::Top
    $top.Height = if ($Description) { 72 } else { 44 }
    $top.Padding = New-Object System.Windows.Forms.Padding(12, 8, 12, 4)

    $search = New-Object System.Windows.Forms.TextBox
    $search.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $search.PlaceholderText = "Szukaj..."
    $top.Controls.Add($search)

    if ($Description) {
        $label = New-Object System.Windows.Forms.Label
        $label.Text = $Description
        $label.Dock = [System.Windows.Forms.DockStyle]::Top
        $label.Height = 28
        $label.ForeColor = $Global:HTTheme.Muted
        $top.Controls.Add($label)
    }

    $listHost = New-Object System.Windows.Forms.Panel
    $listHost.Dock = [System.Windows.Forms.DockStyle]::Fill
    $listHost.Padding = New-Object System.Windows.Forms.Padding(12, 4, 12, 4)
    $list = New-HTListView -Columns $Columns -MultiSelect
    $list.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $listHost.Controls.Add($list)

    $count = New-Object System.Windows.Forms.Label
    $count.AutoSize = $true
    $count.ForeColor = $Global:HTTheme.Muted
    $count.Margin = New-Object System.Windows.Forms.Padding(0, 8, 12, 0)
    $list.Tag.CountLabel = $count

    $close = New-HTButton -Text "Zamknij" -Width 100 -Height 34
    $close.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $export = New-HTButton -Text "Eksport CSV" -Icon "CSV.png" -Width 140 -Height 34
    $copy = New-HTButton -Text "Kopiuj" -Icon "Copy.png" -Width 110 -Height 34 -ToolTip "Kopiuje zaznaczone wiersze (lub wszystkie) do schowka"
    $bar = New-HTDialogButtonBar -Buttons @($close, $export, $copy, $count)

    $form.Controls.Add($listHost)
    $form.Controls.Add($top)
    $form.Controls.Add($bar)
    $listHost.BringToFront()
    $form.CancelButton = $close

    Set-HTListData -ListView $list -Data $Data

    $search.Add_TextChanged({ Update-HTListFilter -ListView $list -Text $search.Text })
    $copy.Add_Click({
            $rows = Get-HTListSelection -ListView $list
            if ($rows.Count -eq 0) { $rows = Get-HTListData -ListView $list -Filtered }
            $lines = @(($Columns | ForEach-Object { $_.Text }) -join "`t")
            foreach ($r in $rows) { $lines += (($Columns | ForEach-Object { Get-HTColumnValue -Object $r -Column $_ }) -join "`t") }
            Set-HTClipboard -Text ($lines -join [Environment]::NewLine)
        })
    $export.Add_Click({
            $rows = @(ConvertTo-HTExportObject -Data (Get-HTListData -ListView $list -Filtered) -Columns $Columns)
            Save-ContentToFile -Data $rows -Format "csv" -Title "Eksport danych" -DefaultName $ExportName | Out-Null
        })

    try { [void]$form.ShowDialog() } finally { $form.Dispose() }
}

# Wybór jednej z opcji (menu). Choices: tablica tekstów lub @{ Key; Text; Description; Icon; Style }
function Show-HTChoiceDialog {
    param (
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][object[]]$Choices,
        [string]$Prompt
    )

    $form = New-HTDialogForm -Title $Title -Width 460 -Height 200

    $flow = New-Object System.Windows.Forms.FlowLayoutPanel
    $flow.Dock = [System.Windows.Forms.DockStyle]::Fill
    $flow.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
    $flow.WrapContents = $false
    $flow.AutoScroll = $true
    $flow.Padding = New-Object System.Windows.Forms.Padding(14, 12, 14, 6)

    if ($Prompt) {
        $label = New-Object System.Windows.Forms.Label
        $label.Text = $Prompt
        $label.AutoSize = $true
        $label.MaximumSize = New-Object System.Drawing.Size(420, 0)
        $label.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 8)
        $flow.Controls.Add($label)
    }

    foreach ($choice in $Choices) {
        $c = if ($choice -is [string]) { @{ Key = $choice; Text = $choice } } else { $choice }
        $style = if ($c.Style) { $c.Style } else { "Default" }
        $button = New-HTButton -Text $c.Text -Icon $c.Icon -Style $style -Width 420 -Height 38 -ToolTip $c.Description
        $button.Margin = New-Object System.Windows.Forms.Padding(0, 2, 0, 2)
        $button.Tag = if ($c.Key) { $c.Key } else { $c.Text }
        $button.Add_Click({
                param($src, $evt)
                $owner = $src.FindForm()
                $owner.Tag = $src.Tag
                $owner.DialogResult = [System.Windows.Forms.DialogResult]::OK
            })
        $flow.Controls.Add($button)
    }

    $cancel = New-HTButton -Text "Anuluj" -Width 100 -Height 34
    $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $bar = New-HTDialogButtonBar -Buttons @($cancel)
    $form.Controls.Add($flow)
    $form.Controls.Add($bar)
    $form.CancelButton = $cancel

    $height = ($Choices.Count * 42) + $bar.Height + 40 + $(if ($Prompt) { 40 } else { 0 })
    $form.ClientSize = New-Object System.Drawing.Size(460, [Math]::Min(700, $height))

    try {
        if ($form.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $form.Tag }
        return $null
    }
    finally {
        $form.Dispose()
    }
}

# Okno z danymi wrażliwymi (hasła, klucze) z przyciskami kopiowania. Items: @{ Label; Value }
function Show-HTSecretDialog {
    param (
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][object[]]$Items,
        [string]$Description
    )

    $form = New-HTDialogForm -Title $Title -Width 620 -Height 200

    $table = New-Object System.Windows.Forms.TableLayoutPanel
    $table.Dock = [System.Windows.Forms.DockStyle]::Top
    $table.AutoSize = $true
    $table.ColumnCount = 3
    $table.Padding = New-Object System.Windows.Forms.Padding(14, 12, 14, 6)
    [void]$table.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 150)))
    [void]$table.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    [void]$table.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 100)))

    $row = 0
    $descText = if ($Description) { $Description } else { "Uwaga: poniższe dane są poufne. Nie przekazuj ich niezabezpieczonym kanałem." }
    $desc = New-Object System.Windows.Forms.Label
    $desc.Text = $descText
    $desc.AutoSize = $true
    $desc.MaximumSize = New-Object System.Drawing.Size(580, 0)
    $desc.ForeColor = $Global:HTTheme.Muted
    $desc.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 10)
    $table.Controls.Add($desc, 0, $row)
    $table.SetColumnSpan($desc, 3)
    $row++

    foreach ($item in $Items) {
        $label = New-Object System.Windows.Forms.Label
        $label.Text = $item.Label
        $label.AutoSize = $true
        $label.Margin = New-Object System.Windows.Forms.Padding(0, 8, 6, 0)

        $box = New-Object System.Windows.Forms.TextBox
        $box.ReadOnly = $true
        $box.Text = "$($item.Value)"
        $box.Font = $Global:HTTheme.FontMono
        $box.Dock = [System.Windows.Forms.DockStyle]::Fill
        $box.BackColor = $Global:HTTheme.Background

        $copy = New-HTButton -Text "Kopiuj" -Icon "Copy.png" -Width 92 -Height 30
        $copy.Tag = $box
        $copy.Add_Click({
                param($src, $evt)
                Set-HTClipboard -Text $src.Tag.Text
                Set-HTStatus -Text "Skopiowano do schowka."
            })

        $table.Controls.Add($label, 0, $row)
        $table.Controls.Add($box, 1, $row)
        $table.Controls.Add($copy, 2, $row)
        $row++
    }

    $close = New-HTButton -Text "Zamknij" -Width 100 -Height 34
    $close.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $bar = New-HTDialogButtonBar -Buttons @($close)
    $form.Controls.Add($table)
    $form.Controls.Add($bar)
    $form.CancelButton = $close
    $form.Add_Shown({
            $form.ClientSize = New-Object System.Drawing.Size($form.ClientSize.Width, [Math]::Min(700, $table.PreferredSize.Height + $bar.Height + 10))
        })

    try { [void]$form.ShowDialog() } finally { $form.Dispose() }
}

#endregion

#region Stan aplikacji: status, zajętość, połączenia, nawigacja

# Kopiuje tekst do schowka
function Set-HTClipboard {
    param ([AllowEmptyString()][AllowNull()][string]$Text)
    if ([string]::IsNullOrEmpty($Text)) {
        Write-Log -Message "Brak treści do skopiowania." -Type "Warn"
        return
    }
    try {
        [System.Windows.Forms.Clipboard]::SetText($Text)
    }
    catch {
        Write-Log -Message "Nie udało się skopiować do schowka: $($_.Exception.Message)" -Type "Error"
    }
}

# Tekst na pasku statusu
function Set-HTStatus {
    param ([AllowEmptyString()][string]$Text)
    if ($Global:HT_UI -and $Global:HT_UI.Status -and $Global:HT_UI.Status.Label) {
        $Global:HT_UI.Status.Label.Text = $Text
    }
}

# Włącza / wyłącza tryb "zajęty" (kursor, pasek postępu, blokada przycisków)
function Set-HTBusy {
    param (
        [bool]$Busy,
        [string]$Text
    )

    if ($Busy) { $script:BusyDepth++ } else { $script:BusyDepth = [Math]::Max(0, $script:BusyDepth - 1) }
    $ui = $Global:HT_UI
    if (-not $ui -or -not $ui.Form) { return }

    $isBusy = $script:BusyDepth -gt 0
    if ($Text) { Set-HTStatus -Text $Text }

    if ($ui.Status -and $ui.Status.Progress) {
        $ui.Status.Progress.Visible = $isBusy
        $ui.Status.Progress.Style = [System.Windows.Forms.ProgressBarStyle]::Marquee
    }
    $ui.Form.UseWaitCursor = $isBusy
    $ui.Form.Cursor = if ($isBusy) { [System.Windows.Forms.Cursors]::WaitCursor } else { [System.Windows.Forms.Cursors]::Default }

    if ($Busy -and $script:BusyDepth -eq 1) { Set-ButtonsState -Action "Lock" }
    if (-not $isBusy) { Set-ButtonsState -Action "Unlock" }

    [System.Windows.Forms.Application]::DoEvents()
}

# Postęp operacji (np. akcje masowe)
function Set-HTProgress {
    param (
        [int]$Value,
        [int]$Maximum,
        [string]$Text
    )
    $ui = $Global:HT_UI
    if (-not $ui -or -not $ui.Status) { return }
    $bar = $ui.Status.Progress
    if ($bar) {
        $bar.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
        $bar.Maximum = [Math]::Max(1, $Maximum)
        $bar.Value = [Math]::Min($bar.Maximum, [Math]::Max(0, $Value))
        $bar.Visible = $true
    }
    if ($Text) { Set-HTStatus -Text $Text }
    [System.Windows.Forms.Application]::DoEvents()
}

# Wykonuje akcję z obsługą błędów, logowaniem i wskaźnikiem zajętości
function Invoke-HTAction {
    param (
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$ScriptBlock,
        [ValidateSet("Exchange", "Graph", "SharePoint", "AD")]
        [string[]]$RequiredService,
        [switch]$NoBusy
    )

    foreach ($service in $RequiredService) {
        if (-not (Assert-HTConnection -Service $service)) { return }
    }

    if (-not $NoBusy) { Set-HTBusy -Busy $true -Text "$Name..." }
    try {
        & $ScriptBlock
    }
    catch {
        $message = $_.Exception.Message
        Write-Log -Message "$Name - błąd: $message" -Type "Error"
        if (-not $NoBusy) { Set-HTBusy -Busy $false -Text "Błąd: $Name" }
        $NoBusy = $true
        Show-Dialog -Message "$Name`n`n$message" -Title "Błąd" -Type "Error" | Out-Null
    }
    finally {
        if (-not $NoBusy) { Set-HTBusy -Busy $false -Text "Gotowe" }
    }
}

# Wykonuje operację dla wielu elementów i zbiera błędy
function Invoke-HTForEach {
    param (
        [Parameter(Mandatory)][object[]]$Items,
        [Parameter(Mandatory)][scriptblock]$Action,
        [Parameter(Mandatory)][scriptblock]$Describe
    )
    $errors = @()
    $ok = 0
    foreach ($item in $Items) {
        try {
            & $Action $item | Out-Null
            $ok++
        }
        catch {
            $errors += "$(& $Describe $item): $($_.Exception.Message)"
        }
    }
    if ($errors.Count -gt 0) {
        Write-Log -Message "Część operacji zakończyła się błędem: $($errors -join ' | ')" -Type "Warn"
        Show-Dialog -Message "Wykonano: $ok, błędy: $($errors.Count)`n`n$($errors -join "`n")" -Title "Wynik operacji" -Type "Warning" | Out-Null
    }
    return $ok
}

# Sprawdza stan połączenia z usługą
function Test-HTConnection {
    param ([ValidateSet("Exchange", "Graph", "SharePoint", "AD")][string]$Service)
    switch ($Service) {
        "Exchange" { return [bool]$Global:ConnectedToExchange }
        "Graph" { return [bool]$Global:ConnectedToGraphAPI }
        "SharePoint" { return [bool]$Global:ConnectedToSharepointPnP }
        "AD" { return [bool]$Global:IsModuleActiveDirectoryLoaded }
    }
}

# Wymaga połączenia z usługą - w przeciwnym razie wyświetla komunikat
function Assert-HTConnection {
    param ([ValidateSet("Exchange", "Graph", "SharePoint", "AD")][string]$Service)

    if (Test-HTConnection -Service $Service) { return $true }

    $message = switch ($Service) {
        "Exchange" { "Ta operacja wymaga połączenia z Exchange Online.`nUżyj przycisku 'Exchange' w nagłówku aplikacji." }
        "Graph" { "Ta operacja wymaga połączenia z Microsoft Graph.`nUżyj przycisku 'Graph' w nagłówku aplikacji." }
        "SharePoint" { "Ta operacja wymaga połączenia z witryną SharePoint (PnP).`nUżyj przycisku 'SharePoint' w nagłówku aplikacji." }
        "AD" { "Moduł ActiveDirectory (RSAT) nie jest dostępny na tym komputerze." }
    }
    Write-Log -Message "Brak połączenia: $Service" -Type "Warn"
    Show-Dialog -Message $message -Title "Brak połączenia" -Type "Warning" | Out-Null
    return $false
}

# Funkcja do aktualizacji tekstu przycisków połączenia i wskaźników na pasku statusu
function Update-ConnectionButtonText {
    param (
        [ValidateSet("Exchange", "Graph", "SharePoint", "AD")]
        [string]$Service,
        [string]$TenantName = $null
    )

    $ui = $Global:HT_UI
    if (-not $ui) { return }

    $names = @{
        Exchange   = "Exchange"
        Graph      = "Graph"
        SharePoint = "SharePoint"
        AD         = "AD"
    }
    $name = $names[$Service]

    $button = if ($ui.Buttons) { $ui.Buttons["Connect$Service"] } else { $null }
    if ($button) {
        if ($TenantName) {
            $short = if ($TenantName.Length -gt 26) { $TenantName.Substring(0, 24) + "…" } else { $TenantName }
            $button.Text = "$name`: $short"
            Set-HTButtonStyle -Button $button -Style "Connected"
            Set-HTToolTip -Control $button -Text "Połączono: $TenantName`nKliknij, aby rozłączyć."
        }
        else {
            $button.Text = "Połącz: $name"
            Set-HTButtonStyle -Button $button -Style "Default"
            Set-HTToolTip -Control $button -Text "Kliknij, aby połączyć z usługą $name."
        }
    }

    if ($ui.Status -and $ui.Status.Connections -and $ui.Status.Connections[$Service]) {
        $indicator = $ui.Status.Connections[$Service]
        $indicator.Text = "● $name"
        $indicator.ForeColor = if ($TenantName) { $Global:HTTheme.Success } else { $Global:HTTheme.Muted }
        $indicator.ToolTipText = if ($TenantName) { "$name - połączono ($TenantName)" } else { "$name - brak połączenia" }
    }
}

# Funkcja do ustawiania stanu przycisków w GUI
function Set-ButtonsState {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Lock", "Unlock")]
        [string]$Action,

        [Parameter(Mandatory = $false)]
        [string]$PanelName,

        [Parameter(Mandatory = $false)]
        [bool]$LockMainButtons = $true
    )

    $ui = $Global:HT_UI
    if (-not $ui) { return }
    if (-not $PanelName) { $PanelName = $ui.CurrentSection }
    $enabled = ($Action -eq "Unlock")

    if ($LockMainButtons -and $ui.Buttons) {
        foreach ($btn in $ui.Buttons.Values) {
            if ($btn -is [System.Windows.Forms.Button]) { $btn.Enabled = $enabled }
        }
    }

    if (-not $PanelName -or -not $ui.Tabs -or -not $ui.Tabs.Contains($PanelName)) { return }

    $stack = New-Object System.Collections.Stack
    $stack.Push($ui.Tabs[$PanelName])
    while ($stack.Count -gt 0) {
        $parent = $stack.Pop()
        foreach ($ctrl in $parent.Controls) {
            if ($ctrl -is [System.Windows.Forms.Button]) { $ctrl.Enabled = $enabled }
            if ($ctrl.HasChildren) { $stack.Push($ctrl) }
        }
    }
}

# Przełącza widoczną sekcję aplikacji
function Show-HTSection {
    param ([Parameter(Mandatory)][string]$Name)

    $ui = $Global:HT_UI
    if (-not $ui -or -not $ui.Tabs.Contains($Name)) { return }
    if ($ui.NavButtons[$Name] -and -not $ui.NavButtons[$Name].Enabled) {
        Show-Dialog -Message "Sekcja '$Name' jest niedostępna.`n$($script:ToolTip.GetToolTip($ui.NavButtons[$Name]))" -Title $Name -Type "Info" | Out-Null
        return
    }

    $ui.ContentHost.SuspendLayout()
    foreach ($key in @($ui.Tabs.Keys)) {
        $ui.Tabs[$key].Visible = ($key -eq $Name)
    }
    $ui.ContentHost.ResumeLayout()

    foreach ($key in @($ui.NavButtons.Keys)) {
        $style = if ($key -eq $Name) { "NavActive" } else { "Nav" }
        Set-HTButtonStyle -Button $ui.NavButtons[$key] -Style $style
    }

    $ui.Header.Title.Text = $Name
    $ui.Header.Subtitle.Text = if ($ui.SectionInfo -and $ui.SectionInfo[$Name]) { $ui.SectionInfo[$Name] } else { "" }
    $ui.Form.Text = "Helpdesk Tools - $Name"

    $previous = $ui.CurrentSection
    $ui.CurrentSection = $Name
    if ($previous -and $previous -ne $Name) {
        Write-Log -Message "Zmieniono zakładkę na: $Name" -Type "Info"
    }

    if ($ui.SectionShown -and $ui.SectionShown[$Name]) {
        try { & $ui.SectionShown[$Name] } catch { Write-Log -Message "Błąd inicjalizacji sekcji $Name`: $($_.Exception.Message)" -Type "Error" }
    }
}

# Włącza lub wyłącza sekcję w nawigacji
function Set-HTSectionEnabled {
    param (
        [Parameter(Mandatory)][string]$Name,
        [bool]$Enabled,
        [string]$Reason
    )
    $ui = $Global:HT_UI
    if (-not $ui -or -not $ui.NavButtons -or -not $ui.NavButtons[$Name]) { return }
    $ui.NavButtons[$Name].Enabled = $Enabled
    if ($Reason) { Set-HTToolTip -Control $ui.NavButtons[$Name] -Text $Reason }
}

#endregion
