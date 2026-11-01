# Przestrzeń «Organizacja»: rzeczy, które nie dotyczą zaznaczonego konta ani skrzynki - tworzenie nowych obiektów
# (konta, skrzynki współdzielone i sale, grupy, kontakty), przepływ poczty, licencje i raporty organizacji.
# Moduły z innych plików są tu rejestrowane parametrem -Workspace 'Organization' (klucze bez zmian - ulubione działają).

Register-HTWorkspace -Key 'Organization' -Title 'Organizacja' -Icon 'E821' `
    -Description 'Tworzenie kont, skrzynek, grup i kontaktów, przepływ poczty, licencje i raporty całej organizacji - bez wybierania obiektu z listy' `
    -Categories @('Tworzenie', 'Poczta (Exchange)', 'Licencje', 'Raporty')

Register-HTModule -Workspace 'Organization' -Category 'Tworzenie' -Key 'org.newgroup' -Title 'Nowa grupa' -Icon 'E902' `
    -Description 'Nowa grupa dowolnego rodzaju: zabezpieczeń albo Microsoft 365 (Entra ID - uprawnienia, Teams, licencje grupowe), dystrybucyjna, dynamiczna (członkowie z atrybutów, kreator z testem) albo grupa SharePoint połączonej witryny.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Microsoft 365'
    Add-HTButton -Parent $row -Module $m -Text 'Zabezpieczeń / Microsoft 365…' -Icon 'E902' -Create -NoRowMenu -ToolTip 'Grupa Entra ID: zabezpieczeń (uprawnienia, aplikacje, licencje grupowe) albo Microsoft 365 (poczta, kalendarz, Teams, witryna)' -OnClick {
        param($m)
        $g = New-HTM365GroupInteractive
        if ($g) {
            Add-HTResultRows -Module $m -Objects @([PSCustomObject]@{ Grupa = $g.DisplayName; Rodzaj = $g.Type; 'E-mail' = $g.Mail; Status = 'OK'; Szczegóły = 'Utworzono - lista: Grupy i zespoły' })
            $panel = Get-HTPanel 'm365groups'
            if ($panel -and $panel.Objects.Count) { Invoke-HTPanelLoad -Panel $panel -Quiet }
        }
    } | Out-Null
    Add-HTLabel -Parent $row -Hint -Text 'Członkowie, właściciele, edycja i usuwanie grup: przestrzeń «Grupy i zespoły».' | Out-Null
    $row2 = Add-HTToolbarRow -Module $m -Title 'Exchange'
    Add-HTButton -Parent $row2 -Module $m -Text 'Dystrybucyjna…' -Icon 'E716' -Create -NoRowMenu -ToolTip 'Lista dystrybucyjna (adres e-mail grupy, członkowie, kto może pisać)' -OnClick { param($m) New-HTDistributionGroupInteractive -Module $m } | Out-Null
    Add-HTButton -Parent $row2 -Module $m -Text 'Dynamiczna…' -Icon 'E71C' -Create -NoRowMenu -ToolTip 'Członkowie wyliczani z atrybutów (np. wszyscy z działu Sprzedaż) - kreator reguł z testem' -OnClick { param($m) New-HTDynamicGroupInteractive -Module $m } | Out-Null
    $row3 = Add-HTToolbarRow -Module $m -Title 'SharePoint'
    Add-HTButton -Parent $row3 -Module $m -Text 'Grupa SharePoint witryny…' -Icon 'E8F1' -Create -NoRowMenu -ToolTip 'Grupa w połączonej witrynie SharePoint (np. do uprawnień folderów)' -OnClick {
        param($m)
        $title = New-HTSPGroupInteractive
        if ($title) { Add-HTResultRows -Module $m -Objects @([PSCustomObject]@{ Grupa = $title; Rodzaj = 'SharePoint'; 'E-mail' = ''; Status = 'OK'; Szczegóły = 'Utworzono w połączonej witrynie' }) }
    } | Out-Null
}
