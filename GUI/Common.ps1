# Wspólne pomocniki przestrzeni roboczych (wybór obiektów z list, kolumny okien wyboru)

# Obiekty listy (panelu); gdy lista jest pusta, próbuje ją wczytać
function Get-HTPanelObjects {
    param([Parameter(Mandatory)][string]$Key)
    $p = Get-HTPanel $Key
    if (-not $p) { return @() }
    if ($p.Objects.Count -eq 0 -and $p.Loader) { Invoke-HTPanelLoad -Panel $p }
    return @($p.Objects.Values)
}

# Wybór użytkownika Microsoft 365 (z listy przestrzeni Microsoft 365)
function Select-HTM365User {
    param([string]$Title = 'Wybierz użytkownika', [string]$Prompt = '', [switch]$Multi)
    $users = @(Get-HTPanelObjects -Key 'm365users')
    if ($users.Count -eq 0) { return $null }
    $columns = @(
        @{ Text = 'Nazwa'; Property = 'DisplayName' }
        @{ Text = 'UPN'; Property = 'UserPrincipalName' }
        @{ Text = 'Dział'; Property = 'Department' }
        @{ Text = 'Stanowisko'; Property = 'JobTitle' }
        @{ Text = 'Włączone'; Property = 'AccountEnabled' }
    )
    $selected = Show-HTSelectionDialog -Title $Title -Prompt $Prompt -Items ($users | Sort-Object DisplayName) -Columns $columns -MultiSelect:$Multi -Icon 'E77B'
    if (-not $selected) { return $null }
    if ($Multi) { return @($selected) }
    return @($selected)[0]
}

# Adres e-mail z tenanta (konta Microsoft 365 i skrzynki Exchange) - np. dokąd przekierować pocztę.
# Listy wczytują się z połączonych usług; adres można też po prostu wpisać lub wkleić w pole.
function Select-HTRecipientAddress {
    # Adres z tenanta (skrzynki Exchange i konta Microsoft 365); -Multiple: kilka adresów (tablica)
    param([string]$Title = 'Wybierz adres z tenanta', [string]$Prompt = 'Osoby i skrzynki z tenanta - wyszukaj po nazwie lub adresie.', [switch]$Multiple)
    $items = New-Object System.Collections.Generic.List[object]
    $seen = @{}
    $add = {
        param([string]$Name, [string]$Address, [string]$Kind, [string]$Detail)
        if (-not $Address -or $seen.ContainsKey($Address.ToLowerInvariant())) { return }
        $seen[$Address.ToLowerInvariant()] = $true
        $items.Add([PSCustomObject]@{ Nazwa = $Name; Adres = $Address; Rodzaj = $Kind; Szczegóły = $Detail })
    }
    if ($Global:ConnectedToExchange) {
        foreach ($x in @(Get-HTPanelObjects -Key 'mailboxes')) { & $add ([string]$x.DisplayName) ([string]$x.PrimarySmtpAddress) $(switch ([string]$x.RecipientTypeDetails) { 'SharedMailbox' { 'skrzynka współdzielona' } 'RoomMailbox' { 'sala' } 'EquipmentMailbox' { 'zasób' } default { 'skrzynka użytkownika' } }) '' }
    }
    if ($Global:ConnectedToGraphAPI) {
        foreach ($u in @(Get-HTPanelObjects -Key 'm365users')) {
            if (-not $u.AccountEnabled) { continue }
            & $add ([string]$u.DisplayName) $(if ($u.Mail) { [string]$u.Mail } else { [string]$u.UserPrincipalName }) 'konto Microsoft 365' (@($u.JobTitle, $u.Department) | Where-Object { $_ }) -join ', '
        }
    }
    if ($items.Count -eq 0) { Show-HTWarning 'Połącz się z Exchange Online albo Microsoft 365, żeby wybrać adres z tenanta - albo wpisz / wklej adres w pole.' -Title $Title; return $null }
    $columns = @(@{ Text = 'Nazwa'; Property = 'Nazwa' }, @{ Text = 'Adres'; Property = 'Adres' }, @{ Text = 'Rodzaj'; Property = 'Rodzaj' }, @{ Text = 'Szczegóły'; Property = 'Szczegóły' })
    $picked = @(Show-HTSelectionDialog -Title $Title -Prompt $Prompt -Items @($items | Sort-Object Nazwa) -Columns $columns -Icon 'E716' -MultiSelect:$Multiple | Where-Object { $_ })
    if (-not $picked.Count) { return $null }
    if ($Multiple) { return @($picked | ForEach-Object { [string]$_.Adres }) }
    return [string]$picked[0].Adres
}

function Get-HTKnownAddresses {
    # Adresy już pobranych list (skrzynki Exchange, konta Microsoft 365) - bez pobierania; do podpowiadania podczas pisania
    $set = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($key in 'mailboxes', 'm365users') {
        $p = Get-HTPanel $key
        if (-not $p -or -not $p.Objects) { continue }
        foreach ($o in @($p.Objects.Values)) { foreach ($a in @($o.PrimarySmtpAddress, $o.Mail, $o.UserPrincipalName)) { if ($a) { [void]$set.Add([string]$a) } } }
    }
    return @($set)
}

$script:AddressBoxes = New-Object 'System.Collections.Generic.Dictionary[object,hashtable]'
$script:AddressBoxEvents = @{
    GotFocus         = { param($s, $e) $st = $null; if ($script:AddressBoxes.TryGetValue($s, [ref]$st)) { $st.Addresses = @(Get-HTKnownAddresses) } }
    # Backspace / Delete - bez podpowiedzi (inaczej usuniętej końcówki nie dałoby się skasować)
    PreviewKeyDown   = { param($s, $e) $st = $null; if ($script:AddressBoxes.TryGetValue($s, [ref]$st) -and ($e.Key -eq 'Back' -or $e.Key -eq 'Delete')) { $st.Skip = $true } }
    # Przecinek / średnik po podpowiedzi przyjmuje ją (zamiast zastąpić zaznaczoną końcówkę)
    PreviewTextInput = { param($s, $e) if ($e.Text -match '^[,;]$' -and $s.SelectionLength -gt 0 -and ($s.SelectionStart + $s.SelectionLength) -eq $s.Text.Length) { $s.Select($s.Text.Length, 0) } }
    TextChanged      = {
        param($s, $e)
        $st = $null
        if (-not $script:AddressBoxes.TryGetValue($s, [ref]$st) -or $st.Busy) { return }
        if ($st.Skip) { $st.Skip = $false; return }
        $text = [string]$s.Text
        if ($s.CaretIndex -ne $text.Length) { return }
        $cut = [Math]::Max($text.LastIndexOf(','), $text.LastIndexOf(';'))
        $token = $text.Substring($cut + 1).TrimStart()
        if (-not $st.Addresses) { $st.Addresses = @(Get-HTKnownAddresses) }
        $full = Get-HTAddressCompletion -Token $token -Addresses $st.Addresses
        if (-not $full) { return }
        $rest = $full.Substring($token.Length)
        $st.Busy = $true
        try { $s.Text = $text + $rest; $s.Select($text.Length, $rest.Length) } finally { $st.Busy = $false }
    }
}

function Enable-HTAddressCompletion {
    <#
        Podpowiadanie adresu w polu tekstowym: końcówka adresu z pobranych list (skrzynki, konta) pojawia się zaznaczona -
        Tab / Enter / przecinek przyjmuje, dalsze pisanie zastępuje. Kilka adresów - przecinek albo średnik.
    #>
    param([Parameter(Mandatory)]$TextBox)
    if ($script:AddressBoxes.ContainsKey($TextBox)) { return }
    $script:AddressBoxes[$TextBox] = @{ Addresses = $null; Skip = $false; Busy = $false }
    $TextBox.add_GotFocus($script:AddressBoxEvents.GotFocus)
    $TextBox.add_PreviewKeyDown($script:AddressBoxEvents.PreviewKeyDown)
    $TextBox.add_PreviewTextInput($script:AddressBoxEvents.PreviewTextInput)
    $TextBox.add_TextChanged($script:AddressBoxEvents.TextChanged)
}

# Przycisk «Wybierz…» obok pola adresu: adres z tenanta trafia do pola (można też wpisać lub wkleić własny, z podpowiadaniem
# końcówki adresu). -Multiple: kilka adresów - wybrane dopisywane po przecinku.
function Add-HTAddressPicker {
    param([Parameter(Mandatory)]$Parent, [Parameter(Mandatory)][hashtable]$Module, [Parameter(Mandatory)]$TextBox, [switch]$Multiple)
    Enable-HTAddressCompletion -TextBox $TextBox
    $b = Add-HTButton -Parent $Parent -Module $Module -Text 'Wybierz…' -Icon 'E716' -ToolTip $(if ($Multiple) { 'Wybierz osoby lub skrzynki z tenanta - dopisane po przecinku (albo wpisz adres - program podpowie końcówkę)' } else { 'Wybierz osobę lub skrzynkę z tenanta (albo wpisz adres - program podpowie końcówkę)' }) -OnClick {
        param($m, $s)
        $box = $s.Tag.TextBox
        if ($s.Tag.Multiple) {
            $picked = @(Select-HTRecipientAddress -Multiple)
            if ($picked.Count) { $box.Text = (@(Split-HTInputList $box.Text) + $picked | Select-Object -Unique) -join ', ' }
        }
        else {
            $address = Select-HTRecipientAddress
            if ($address) { $box.Text = $address }
        }
    }
    $b.Tag = @{ TextBox = $TextBox; Multiple = [bool]$Multiple }
    return $b
}

# Wybór użytkownika AD (z listy przestrzeni Użytkownicy AD)
function Select-HTADUser {
    param([string]$Title = 'Wybierz użytkownika AD', [string]$Prompt = '')
    $users = @(Get-HTPanelObjects -Key 'adusers')
    if ($users.Count -eq 0) { return $null }
    $columns = @(
        @{ Text = 'Nazwa'; Property = 'DisplayName' }
        @{ Text = 'Login'; Property = 'SamAccountName' }
        @{ Text = 'UPN'; Property = 'UserPrincipalName' }
        @{ Text = 'Dział'; Property = 'Department' }
        @{ Text = 'Włączone'; Property = 'Enabled' }
    )
    return Select-HTOne -Title $Title -Prompt $Prompt -Items ($users | Sort-Object Name) -Columns $columns
}

# Wybór grup AD (wielokrotny)
function Select-HTADGroups {
    param([string]$Title = 'Wybierz grupy AD', [string]$Prompt = '')
    $groups = @(Get-HTADGroupList)
    $columns = @(
        @{ Text = 'Nazwa'; Property = 'Name' }
        @{ Text = 'Typ'; Property = 'GroupCategory' }
        @{ Text = 'Zakres'; Property = 'GroupScope' }
        @{ Text = 'Opis'; Property = 'Description' }
    )
    return Show-HTSelectionDialog -Title $Title -Prompt $Prompt -Items $groups -Columns $columns -MultiSelect -Icon 'E902'
}

# Wybór jednostki organizacyjnej
function Select-HTADOrganizationalUnit {
    param([string]$Title = 'Wybierz jednostkę organizacyjną')
    $columns = @(
        @{ Text = 'Ścieżka'; Property = 'CanonicalName' }
        @{ Text = 'Opis'; Property = 'Description' }
    )
    return Select-HTOne -Title $Title -Items @(Get-HTADOrganizationalUnits) -Columns $columns
}

# Liczba dni z pola modułu (z domyślną wartością z ustawień)
function Get-HTInactiveDaysDefault {
    if ($Global:InactiveDays -gt 0) { return [int]$Global:InactiveDays }
    return 90
}

# Kropka stanu na liście obiektów
function Get-HTStateDot {
    param([bool]$Enabled, [bool]$Problem = $false)
    if ($Problem) { return 'crit' }
    if ($Enabled) { return 'ok' }
    return 'off'
}

function Invoke-HTModulePrimary {
    # Ponowne wykonanie głównej akcji modułu (odświeżenie wyników po zmianie)
    param([hashtable]$Module)
    $b = $Module.PrimaryButton
    if ($b) { $b.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, $b))) }
}
