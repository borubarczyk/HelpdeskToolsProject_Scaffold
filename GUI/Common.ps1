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
