# Wtyczki Helpdesk Tools

Pliki `*.ps1` z tego folderu oraz z `%APPDATA%\HelpdeskTools\Plugins` są wczytywane przy starcie programu,
po wbudowanych przestrzeniach roboczych (alfabetycznie). Wtyczka działa z uprawnieniami programu -
umieszczaj tu tylko własne, sprawdzone pliki. Błąd wtyczki trafia do dziennika i nie zatrzymuje programu.

Wtyczka może:

- dodać przestrzeń roboczą: `Register-HTWorkspace -Key ... -Title ... -Icon ... -Categories @(...)`,
- dodać moduł do dowolnej przestrzeni: `Register-HTModule -Workspace 'M365' -Category 'Raporty' -Key 'plugin.x' -Title ... -Build { param($m) ... }`,
- dodać polecenie palety (Ctrl+K): `Register-HTPaletteAction -Text ... -Action { param($q) ... }`.

W modułach korzystaj z tych samych pomocników co wbudowane moduły: `Add-HTToolbarRow`, `Add-HTButton`,
`Invoke-HTQuery` (także `-Background` dla zapytań Microsoft Graph), `Invoke-HTTargetAction`, `Add-HTRowAction`,
`Invoke-HTRowAction`, `Invoke-HTGraphRequest`. Uprawnienia kont MFA (przestrzenie, moduły, tryb tylko do odczytu)
działają tak samo jak dla modułów wbudowanych.

Przykład: `Przyklad.ps1.example` - zmień nazwę na `Przyklad.ps1`, aby go włączyć.
