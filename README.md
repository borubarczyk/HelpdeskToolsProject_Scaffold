# Helpdesk Tools

**Helpdesk Tools** to aplikacja PowerShell z interfejsem WPF dla administratorów IT. Pozwala zarządzać lokalnym Active Directory, użytkownikami Microsoft 365 (Microsoft Graph), skrzynkami Exchange Online, urządzeniami Intune i witrynami SharePoint z jednego okna. Wygląd, ikony, czcionka i układ są wspólne z projektami **Domain Ops** (AD-ManagerDiamond) i **ServerReview**.

## Spis treści
1. [Wymagania](#wymagania)
2. [Instalacja i uruchomienie](#instalacja-i-uruchomienie)
3. [Interfejs](#interfejs)
4. [Funkcje](#funkcje)
5. [Konfiguracja](#konfiguracja)
6. [Struktura projektu](#struktura-projektu)
7. [Testy](#testy)
8. [Rozwiązywanie problemów](#rozwiązywanie-problemów)
9. [Licencja](#licencja)

## Wymagania

- **System**: Windows 10/11 lub Windows Server 2016+.
- **PowerShell**: 7.2 lub nowszy (`pwsh`), uruchomiony jako administrator.
- **Moduły PowerShell** (instalowane automatycznie po potwierdzeniu, przy pierwszym połączeniu):
  - `Microsoft.Graph.Authentication` - przestrzenie Microsoft 365, Intune, Pulpit.
  - `ExchangeOnlineManagement` - przestrzeń Exchange.
  - `PnP.PowerShell` - przestrzeń SharePoint (wymaga własnej rejestracji aplikacji w Entra ID i jej Client ID).
  - `ActiveDirectory` (RSAT) - przestrzenie Użytkownicy / Komputery / Grupy AD. Instalacja: `Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0` (Windows 10/11) lub `Install-WindowsFeature RSAT-AD-PowerShell` (Windows Server).
- **Uprawnienia**: odpowiednie role administracyjne (np. User Administrator, Exchange Administrator, Intune Administrator). Przy pierwszym połączeniu z Graph może być wymagana zgoda administratora na uprawnienia z klucza `GraphScopes`.

## Instalacja i uruchomienie

```powershell
git clone <URL-repozytorium>
cd HelpdeskToolsProject_Scaffold
pwsh -File .\HelpdeskTools.ps1
```

Przy pierwszym uruchomieniu program prosi o ustawienie **PIN-u** (4-8 cyfr) - będzie wymagany przy każdym uruchomieniu.

Pliki programu (jak w Domain Ops):

| Co | Gdzie |
|---|---|
| Konfiguracja | `%APPDATA%\HelpdeskTools\config.json` |
| Konta MFA (klucze zaszyfrowane DPAPI) | `%APPDATA%\HelpdeskTools\Mfa.json` |
| Dziennik (plik dzienny, 30 dni) | `%LOCALAPPDATA%\HelpdeskTools\Logs\HelpdeskTools_RRRRMMDD.log` |
| Eksport CSV, pobrane pliki | `Dokumenty\HelpdeskTools\Eksport` (zmiana: Ustawienia > Katalog eksportu) |

## Interfejs

Układ jak w Domain Ops: ciemny motyw, Segoe UI, ikony Segoe Fluent Icons / MDL2.

- **Nagłówek**: logo, przełącznik **przestrzeni roboczych** (Pulpit, Microsoft 365, Exchange, Intune, Witryny, SharePoint, Użytkownicy AD, Komputery AD, Grupy AD) oraz przyciski połączeń z kropką stanu i nazwą tenantu (Exchange, Microsoft 365, SharePoint, Active Directory), generator haseł i ustawienia.
- **Lista obiektów** (lewa kolumna): wyszukiwanie, pola wyboru (wiele obiektów naraz), «Zaznacz widoczne / odwróć / odznacz» oraz **«Zaznacz z listy»** - wklejone identyfikatory lub plik CSV/TXT. Dawne «Akcje masowe» działają teraz w każdym module: zaznacz kilka obiektów i wykonaj akcję. Lista wczytuje się sama po połączeniu z usługą.
- **Nawigacja modułów** (środkowa kolumna) pogrupowana w kategorie.
- **Widok modułu**: parametry, przyciski akcji, kafelki, tabela wyników z filtrem (`Ctrl+F`, słowo z minusem wyklucza), sortowaniem, panelem szczegółów wiersza, kopiowaniem (format Excel) i eksportem. Prawy przycisk na wierszach - akcje na wynikach (np. odebranie uprawnienia, przywrócenie z kosza). Wiersze z błędami i ostrzeżeniami są kolorowane.
- **Filtry kolumn** (jak autofiltr w Excelu, jak w Domain Ops): lejek w nagłówku kolumny otwiera okienko z warunkiem (zawiera, nie zawiera, równa się, różne od, zaczyna się od, kończy się na, większe / mniejsze niż - liczbowo, puste, niepuste) i listą wartości z liczbą wierszy (wyszukiwanie, «Zaznacz wszystkie»). Filtry kilku kolumn działają razem z polem «Filtruj wyniki»; chip «Filtry kolumn: N» pokazuje aktywne filtry (kliknięcie czyści). Prawy przycisk na komórce: «Pokaż tylko …», «Ukryj …», kopiowanie wartości całej kolumny (np. lista UPN do «Zaznacz z listy»).
- **Menu nagłówka kolumny** (prawy przycisk na nagłówku): sortowanie, kopiowanie wartości kolumny (także bez powtórzeń i pustych), filtr, ukrycie kolumny, «Pokaż tylko tę kolumnę», «Wybierz kolumny…» (przycisk z ikoną kolumn nad tabelą). Ukryte kolumny nie trafiają do kopiowania ani eksportu i zostają ukryte po odświeżeniu wyników.
- **Eksport wyników**: CSV (Excel), **raport HTML** (samodzielny plik w ciemnym motywie: wyszukiwarka, sortowanie i filtr pod każdą kolumną, kopiowanie wiersza i widocznych wierszy, otwieranie wiersza w osobnym oknie, druk; w nagłówku raportu użyte filtry) albo JSON.
- **Dane poufne** (hasła, klucze BitLocker, LAPS, TAP) są maskowane - «Pokaż poufne»; skopiowane hasło znika ze schowka po 60 s.
- **Operacje ryzykowne** wymagają potwierdzenia z listą obiektów, a nieodwracalne - przepisania słowa (np. `USUŃ`, `OFFBOARDING`).
- **Dziennik operacji** (`Ctrl+L`) z licznikiem ostrzeżeń: filtr poziomu (wszystkie / ostrzeżenia i błędy / tylko błędy / wykonane), wyszukiwanie w komunikatach i nazwach modułów, kopiowanie zaznaczonych lub widocznych wpisów, dzisiejszy plik dziennika i **historia z poprzednich dni** (Pulpit > «Dziennik programu»). Przy włączonym MFA każdy wpis w pliku ma nazwę konta, które odblokowało program. Powiadomienia w oknie, pasek stanu z postępem.
- **Logowanie w przeglądarce**: Exchange, Microsoft 365 i SharePoint logują się w karcie domyślnej przeglądarki (bez okna Windows WAM, które chowało się za programem). W tym czasie widoczne jest okienko «Trwa logowanie» z przyciskiem **Anuluj logowanie** i limitem czasu - zamknięcie karty przez przypadek nie blokuje programu: anuluj i połącz ponownie.
- **PIN i blokada programu** (jak w Domain Ops): PIN przy uruchomieniu, blokada przyciskiem z kłódką, `Ctrl+Shift+L` albo automatycznie po bezczynności (Ustawienia, domyślnie 15 min; liczy się klawiatura, mysz i ruch kursora nad aktywnym oknem programu). Blokada ukrywa zawartość okna głównego i otwartych okien (np. formularza) i czyści hasła ze schowka; połączenia z usługami trwają. Po 5 błędnych próbach: przy starcie program się zamyka, w trakcie pracy - 30 s przerwy. Z ekranu blokady można zamknąć program bez PIN-u przyciskiem **«Zakończ awaryjnie»** (albo krzyżykiem okna) - z potwierdzeniem drugim kliknięciem w ciągu 10 s. Zmiana PIN-u: Ustawienia > «Zmień PIN». Zapomniany PIN: usuń wartości `PinHash`, `PinSalt`, `PinLength` z `config.json` - program poprosi o nowy (z włączonym MFA nadal wymagany jest kod z aplikacji).
- **MFA przy odblokowaniu** (jak w Domain Ops): po PIN-ie kod z aplikacji uwierzytelniającej (Microsoft / Google Authenticator i podobne, TOTP: 6 cyfr co 30 s, SHA1). Włączenie: Ustawienia > «MFA» > «Włącz MFA dla konta podstawowego» - program pokazuje klucz do wpisania w aplikacji (lub link `otpauth://` do skopiowania) i zapisuje go dopiero po poprawnym kodzie. Ten sam kod nie zadziała drugi raz (np. przy ponownej blokadzie - trzeba poczekać na następny). Klucze są w `Mfa.json` zaszyfrowane DPAPI (odczyta je tylko to konto Windows na tym komputerze). **Utrata telefonu**: usuń `Mfa.json` - program wróci do samego PIN-u.
- **Konta dodatkowe MFA z uprawnieniami**: kolejne osoby mogą mieć własną nazwę, własny PIN i własny klucz - na ekranie blokady wybiera się konto. Dla każdego konta dodatkowego «Uprawnienia…» blokują wybrane przestrzenie robocze, pojedyncze moduły i Ustawienia (znikają z nawigacji). Dodanie konta, nowy klucz, uprawnienia i usunięcie zatwierdza się kodem z aplikacji konta podstawowego. Zmiana konta na ekranie blokady zamyka okna poprzedniego konta. W nagłówku obok konta Windows widać konto MFA. To ograniczenie interfejsu programu: uprawnienia w usługach wynikają z kont, którymi program łączy się z Microsoft 365, Exchange i AD.
- **Weryfikacja pakietów**: przed połączeniem program sprawdza, czy zainstalowany moduł (Graph, Exchange, PnP) pasuje do tej wersji PowerShell i czy nie koliduje z bibliotekami innego modułu załadowanego w sesji. Niezgodna wersja jest pomijana (używana jest najnowsza zgodna), a gdy żadnej nie ma - program proponuje instalację zgodnej wersji z PowerShell Gallery lub aktualizację PowerShell. Przy konflikcie bibliotek proponuje ponowne uruchomienie i połączenie najpierw z tą usługą. Podgląd: Pulpit > «Moduły i środowisko».
- **Skróty**: `Ctrl+1..9` - przestrzenie, `F5` - główna akcja modułu, `Ctrl+F` - filtr wyników, `Ctrl+L` - dziennik, `Ctrl+Shift+L` - blokada, `Ctrl+G` - generator haseł.

## Funkcje

### Pulpit
Kafelki ze wszystkich połączonych usług i lista problemów; **moduły i środowisko** (weryfikacja pakietów, instalacja zgodnych wersji, foldery dziennika i eksportu); **dziennik programu** (wpisy z wybranego dnia: poziom, konto MFA, komunikat - z filtrami kolumn i eksportem do raportu HTML); **licencje** (nazwy handlowe, wolne/wyczerpane, lista użytkowników z licencją), **kondycja usług Microsoft 365** z otwartymi incydentami, **centrum wiadomości** (zapowiedzi zmian z terminami).

### Microsoft 365
- Konto: szczegóły, dane kontaktowe (także hurtowo), **przełożony**, urządzenia użytkownika.
- Bezpieczeństwo: blokada logowania z unieważnieniem sesji, reset hasła (losowe / podane), metody MFA (usuwanie, telefon, Temporary Access Pass), **historia logowań** (IP, lokalizacja, dostęp warunkowy).
- Licencje i grupy: przypisywanie / usuwanie licencji z kontrolą wolnych sztuk, grupy (także pocztowe), **kopiowanie grup od użytkownika wzorcowego**.
- Cykl życia: nowy użytkownik (licencja i grupy z wzorca), **offboarding w jednym kroku** (blokada, hasło, autoodpowiedź, przekierowanie, skrzynka współdzielona, GAL, MFA, grupy, przełożony, licencje), **usunięci użytkownicy** (przywracanie z kosza katalogu).
- Raporty: **nieaktywni użytkownicy**, **goście**, **rejestracja MFA**, bez licencji, **role administracyjne**, **nieudane logowania** w organizacji.

### Exchange
- Skrzynka: szczegóły, **rozmiar i wykorzystanie limitu**, typ (Shared/Regular/Room/Equipment), GAL, archiwum, urządzenia mobilne (usuwanie powiązań).
- Uprawnienia: FullAccess / SendAs / SendOnBehalf, **do których skrzynek ma dostęp użytkownik**, kalendarz.
- Poczta: autoodpowiedź (także zaplanowana), przekierowanie, reguły skrzynki (wyłączanie / usuwanie), śledzenie wiadomości.
- Grupy i adresy: **aliasy**, **grupy dystrybucyjne** (członkowie, dodawanie / usuwanie skrzynek).
- Zgodność: **kwarantanna** (podgląd, zwolnienie, zezwolenie nadawcy, usunięcie), **odzyskiwanie usuniętych elementów**, **Litigation Hold** i retencja usuniętych elementów.
- Raporty: **przekierowania poza organizację** (skrzynki i reguły), **nieaktywne skrzynki**.

### Intune
Szczegóły i sprzęt, aplikacje, grupy, użytkownik podstawowy, zmiana nazwy; akcje zdalne: synchronizacja, restart, **skanowanie i aktualizacja Microsoft Defender**, **zdalna blokada**, **rotacja kluczy BitLocker i hasła LAPS**, lokalizacja; **wycofanie, wipe i usunięcie z Intune**; **stan zasad zgodności i konfiguracji** (dlaczego urządzenie jest niezgodne); BitLocker i LAPS; raporty: niezgodne, **nieaktywne**, **bez szyfrowania**, **mało miejsca**, wersje systemów.

### Witryny (Microsoft Graph)
Przeglądanie wszystkich witryn SharePoint w organizacji bez Client ID PnP: wyszukiwanie, szczegóły, **biblioteki i zajęte miejsce**, **przeglądarka plików** (nawigacja po folderach, pobieranie, kopiowanie linków), listy, podwitryny, otwarcie w przeglądarce i szybkie połączenie PnP.

### SharePoint (PnP)
Drzewo bibliotek i folderów połączonej witryny; uprawnienia (nadawanie, odbieranie, dziedziczenie); pliki w folderze; nowy folder; **kosz witryny** (przywracanie); grupy SharePoint; **informacje o witrynie** (magazyn, administratorzy); **raport unikalnych uprawnień**; **aplikacja PnP**: utworzenie rejestracji aplikacji (Client ID) jednym kliknięciem - przez Microsoft Graph (z opcjonalną zgodą administratora i kluczem tajnym) albo przez PnP PowerShell - oraz nowy klucz tajny (client secret) dla istniejącej aplikacji. Okno połączenia ma przyciski «Wybierz witrynę» i «Utwórz Client ID».

### Active Directory
- Użytkownicy: szczegóły, stan konta, atrybuty i profil (także hurtowo), reset hasła, **blokady: stan na każdym kontrolerze i źródło blokady (zdarzenie 4740 z PDC)**, grupy (kopiowanie z wzorca), nowy użytkownik, **odejście pracownika**, **synchronizacja Entra Connect (delta)**; raporty: nieaktywne, nigdy nie zalogowane, **wygasające / wygasłe hasła**, zablokowane, wyłączone, «hasło nie wygasa», wygasające konta.
- Komputery: szczegóły, dostępność, **informacje systemowe (CIM: czas pracy, model, numer seryjny, dyski)**, **zalogowani użytkownicy**, pulpit zdalny, LAPS i BitLocker, zarządzanie; raporty: nieaktywne, systemy operacyjne, wyłączone.
- Grupy: członkowie (dodawanie z listy loginów), szczegóły, nowa grupa, edycja, usunięcie, **puste grupy**.

### Generator haseł
Tryby przyjazne / klasyczne / ze słów, długość 8-64, wskaźnik siły, kopiowanie (schowek czyszczony po 60 s) i wysyłka e-mailem (opcjonalnie numer telefonu w temacie dla bramki SMS).

## Konfiguracja

Plik `%APPDATA%\HelpdeskTools\config.json` (brakujące klucze są uzupełniane automatycznie):

```json
{
  "PasswordEmailAdress": "",
  "PasswordEmailTitle": "Nowe hasło",
  "PasswordSpecialCharacters": "!@#$%^&*?",
  "PasswordUseWordBased": false,
  "PasswordDefaultLength": 12,
  "LogPasswordGeneration": false,
  "LogClientIDForPnP": false,
  "LastUsedClientID": null,
  "DefaultSharepointSite": "https://contoso.sharepoint.com/sites/DefaultSite",
  "DefaultUsageLocation": "PL",
  "GraphScopes": [ "User.ReadWrite.All", "Directory.AccessAsUser.All", "..." ],
  "ShowNotifications": true,
  "LogFileMaxSizeMB": 5,
  "ExportPath": "",
  "InactiveDays": 90,
  "AadSyncServer": "",
  "LoginTimeoutMinutes": 5,
  "AutoLockMinutes": 15,
  "ConfirmBeforeClose": true
}
```

Ustawienia można edytować w oknie **Ustawienia** (ikona koła zębatego). `InactiveDays` - domyślny próg raportów nieaktywności, `AadSyncServer` - serwer Microsoft Entra Connect, `LoginTimeoutMinutes` - po ilu minutach oczekiwanie na logowanie w przeglądarce jest anulowane, `AutoLockMinutes` - automatyczna blokada po bezczynności (0 = wyłączona). Klucze `PinHash`/`PinSalt`/`PinLength` zawierają skrót PIN-u (PBKDF2), nie sam PIN. Konta MFA są w osobnym pliku `Mfa.json` (klucze, skróty PIN-ów kont dodatkowych i ich uprawnienia zaszyfrowane DPAPI); zarządza się nimi w Ustawieniach > «MFA». Po aktualizacji programu do konfiguracji są automatycznie dopisywane nowe uprawnienia Graph. Pełną listę domyślnych kluczy zawiera plik [`config.example.json`](config.example.json). `LogPasswordGeneration` zapisuje hasła w logu w postaci jawnej - pozostaw tę opcję wyłączoną.

## Struktura projektu

```
HelpdeskTools.ps1              Punkt wejścia: zmienne globalne, moduły, okno główne
Modules/
  Utils.psm1                   Dziennik, eksport, walidacja i formatowanie wartości
  Security.psm1                PIN programu (skrót PBKDF2)
  Mfa.psm1                     MFA: TOTP (RFC 6238), Base32, konta w Mfa.json (DPAPI), uprawnienia kont
  ColumnFilters.psm1           Filtry kolumn tabeli wyników (logika autofiltru)
  Reports.psm1                 Raporty HTML z tabel wyników
  UIComponents.psm1            WPF: motyw Domain Ops, okna dialogowe, przestrzenie, listy obiektów, widok modułu,
                               filtry kolumn, ekran blokady (PIN, MFA), okna MFA i uprawnień
  Config.psm1                  Konfiguracja (domyślne wartości, scalanie, migracja, zapis)
  ModulesConnection.psm1       Instalacja i weryfikacja modułów, połączenia (logowanie w przeglądarce), wywołania Graph
  PasswordGenerator.psm1       Generator haseł i ocena siły hasła
  LocalActiveDirectory.psm1    Active Directory: konta, grupy, komputery, blokady, raporty, CIM
  GraphAPIM365Users.psm1       Użytkownicy, licencje, grupy, MFA, logowania, raporty, kondycja usług
  MailboxesExchangeOnline.psm1 Exchange Online: skrzynki, uprawnienia, kwarantanna, zgodność, raporty
  GraphAPIIntune.psm1          Intune: urządzenia, akcje zdalne, zasady, BitLocker, LAPS
  GraphAPISharePoint.psm1      SharePoint: PnP (uprawnienia, kosz, pliki, raport), witryny przez Graph, rejestracja aplikacji PnP
  Dashboard.psm1               Statystyki Pulpitu
  Startup.psm1                 Inicjalizacja po zbudowaniu okna
GUI/
  MainWindow.ps1               Okno główne (nagłówek, połączenia, dziennik, skróty)
  Dialogs.ps1                  Generator haseł, ustawienia
  Common.ps1                   Wspólne pomocniki przestrzeni roboczych
  Workspaces/*.ps1             Przestrzenie robocze i ich moduły
Resources/Icons/               Ikony
Tests/                         Testy Pester
```

Moduły w `Modules/` zawierają logikę (parametry wejściowe, zwracane dane), a pliki `GUI/Workspaces` opisują moduły interfejsu (parametry, przyciski, akcje na wynikach).

## Testy

Testy jednostkowe (Pester 5) obejmują logikę niezależną od interfejsu WPF (m.in. TOTP z wektorami RFC 6238, konta i uprawnienia MFA, filtry kolumn, raport HTML, odczyt dziennika), z atrapami poleceń AD, Exchange i Graph:

```powershell
Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser
Invoke-Pester -Path .\Tests
```

## Rozwiązywanie problemów

1. **Aplikacja nie uruchamia się** - sprawdź wersję PowerShell (`$PSVersionTable`), uruchomienie jako administrator i dziennik `%LOCALAPPDATA%\HelpdeskTools\Logs`.
2. **Błąd `Could not load file or assembly 'System.Text.Json, Version=10.0.0.0'`** (lub inna biblioteka z wyższą wersją) - zainstalowany moduł jest zbudowany pod nowszy .NET niż Twój PowerShell. Program wykrywa to przed połączeniem i proponuje: instalację zgodnej wersji modułu (automatycznie z PowerShell Gallery) albo aktualizację PowerShell (`winget upgrade --id Microsoft.PowerShell`). Stan: Pulpit > «Moduły i środowisko».
3. **Błąd `Could not load file or assembly Microsoft.Identity.Client`** - konflikt wersji bibliotek między modułami Graph i Exchange w jednej sesji. Program proponuje ponowne uruchomienie i połączenie najpierw z usługą, której moduł wymaga nowszej wersji.
4. **Brak uprawnień (403) w Graph** - sprawdź role konta i zgodę administratora na uprawnienia z `GraphScopes`.
5. **SharePoint: błąd logowania PnP** - od 2024 r. PnP.PowerShell wymaga własnej rejestracji aplikacji w Entra ID. Utworzysz ją przyciskiem «Utwórz Client ID» w oknie połączenia (lub SharePoint > «Aplikacja PnP»). Do samego przeglądania witryn wystarczy przestrzeń «Witryny» (Microsoft Graph).
6. **Funkcje AD zgłaszają brak modułu** - brak modułu ActiveDirectory (RSAT) na tym komputerze; po instalacji kliknij «Active Directory» w nagłówku.
7. **Logowanie Exchange otwiera osobne okno zamiast karty przeglądarki** - zaktualizuj moduł: `Update-Module ExchangeOnlineManagement` (wymagana wersja 3.7.2+). Gdy karta została zamknięta - kliknij «Anuluj logowanie» w okienku logowania (lub poczekaj na limit czasu) i połącz ponownie.
8. **Brak danych w raportach logowań lub MFA** - wymagana licencja Microsoft Entra ID P1 i uprawnienie AuditLog.Read.All; kondycja usług wymaga ServiceHealth.Read.All (połącz ponownie, aby zatwierdzić nowe uprawnienia).
9. **Źródło blokady AD jest puste** - konto musi mieć prawo odczytu dziennika Security na kontrolerze PDC, a zasady audytu muszą rejestrować zdarzenie 4740.
10. **Kod z aplikacji MFA nie pasuje** - sprawdź, czy zegar telefonu i komputera wskazuje ten sam czas (tolerancja ±30 s). Komunikat «kod został już użyty» - poczekaj na następny kod (do 30 s). «Nie można odczytać danych MFA» - plik `Mfa.json` pochodzi z innego komputera lub konta Windows: usuń go i włącz MFA ponownie.

## Licencja

Projekt jest dostępny na licencji [MIT License](LICENSE).
