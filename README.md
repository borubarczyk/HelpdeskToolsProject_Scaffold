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

Przy pierwszym uruchomieniu aplikacja tworzy katalog `%APPDATA%\HelpdeskTools` z plikiem `config.json` oraz logiem `logs.txt`.

## Interfejs

Układ jak w Domain Ops: ciemny motyw, Segoe UI, ikony Segoe Fluent Icons / MDL2.

- **Nagłówek**: logo, przełącznik **przestrzeni roboczych** (Pulpit, Microsoft 365, Exchange, Intune, SharePoint, Użytkownicy AD, Komputery AD, Grupy AD) oraz przyciski połączeń z kropką stanu i nazwą tenantu (Exchange, Microsoft 365, SharePoint, Active Directory), generator haseł i ustawienia.
- **Lista obiektów** (lewa kolumna): wyszukiwanie, pola wyboru (wiele obiektów naraz), «Zaznacz widoczne / odwróć / odznacz» oraz **«Zaznacz z listy»** - wklejone identyfikatory lub plik CSV/TXT. Dawne «Akcje masowe» działają teraz w każdym module: zaznacz kilka obiektów i wykonaj akcję. Lista wczytuje się sama po połączeniu z usługą.
- **Nawigacja modułów** (środkowa kolumna) pogrupowana w kategorie.
- **Widok modułu**: parametry, przyciski akcji, kafelki, tabela wyników z filtrem (`Ctrl+F`, słowo z minusem wyklucza), sortowaniem, panelem szczegółów wiersza, kopiowaniem (format Excel) i eksportem CSV. Prawy przycisk na wierszach - akcje na wynikach (np. odebranie uprawnienia, przywrócenie z kosza). Wiersze z błędami i ostrzeżeniami są kolorowane.
- **Dane poufne** (hasła, klucze BitLocker, LAPS, TAP) są maskowane - «Pokaż poufne»; skopiowane hasło znika ze schowka po 60 s.
- **Operacje ryzykowne** wymagają potwierdzenia z listą obiektów, a nieodwracalne - przepisania słowa (np. `USUŃ`, `OFFBOARDING`).
- **Dziennik operacji** (`Ctrl+L`) z licznikiem ostrzeżeń, powiadomienia w oknie, pasek stanu z postępem.
- **Okno logowania na wierzchu**: na czas logowania do Exchange / Graph / SharePoint okno programu jest minimalizowane, a potem przywracane - okno logowania Microsoft nie chowa się już za aplikacją. Alternatywnie można włączyć logowanie Exchange w przeglądarce (Ustawienia).
- **Skróty**: `Ctrl+1..8` - przestrzenie, `F5` - główna akcja modułu, `Ctrl+F` - filtr wyników, `Ctrl+L` - dziennik, `Ctrl+G` - generator haseł.

## Funkcje

### Pulpit
Kafelki ze wszystkich połączonych usług i lista problemów; **licencje** (nazwy handlowe, wolne/wyczerpane, lista użytkowników z licencją), **kondycja usług Microsoft 365** z otwartymi incydentami, **centrum wiadomości** (zapowiedzi zmian z terminami).

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

### SharePoint
Drzewo bibliotek i folderów; uprawnienia (nadawanie, odbieranie, dziedziczenie); pliki w folderze; nowy folder; **kosz witryny** (przywracanie); grupy SharePoint; **informacje o witrynie** (magazyn, administratorzy); **wyszukiwanie witryn w organizacji** i szybkie przełączanie; **raport unikalnych uprawnień**.

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
  "ExchangeUseBrowserLogin": false,
  "ConfirmBeforeClose": true
}
```

Ustawienia można edytować w oknie **Ustawienia** (ikona koła zębatego). `InactiveDays` - domyślny próg raportów nieaktywności, `AadSyncServer` - serwer Microsoft Entra Connect, `ExchangeUseBrowserLogin` - logowanie Exchange w przeglądarce zamiast okna WAM. Po aktualizacji programu do konfiguracji są automatycznie dopisywane nowe uprawnienia Graph. Pełną listę domyślnych kluczy zawiera plik [`config.example.json`](config.example.json). `LogPasswordGeneration` zapisuje hasła w logu w postaci jawnej - pozostaw tę opcję wyłączoną.

## Struktura projektu

```
HelpdeskTools.ps1              Punkt wejścia: zmienne globalne, moduły, okno główne
Modules/
  Utils.psm1                   Dziennik, eksport, walidacja i formatowanie wartości
  UIComponents.psm1            WPF: motyw Domain Ops, okna dialogowe, przestrzenie, listy obiektów, widok modułu
  Config.psm1                  Konfiguracja (domyślne wartości, scalanie, migracja, zapis)
  ModulesConnection.psm1       Instalacja modułów, połączenia (logowanie na wierzchu), wywołania Graph
  PasswordGenerator.psm1       Generator haseł i ocena siły hasła
  LocalActiveDirectory.psm1    Active Directory: konta, grupy, komputery, blokady, raporty, CIM
  GraphAPIM365Users.psm1       Użytkownicy, licencje, grupy, MFA, logowania, raporty, kondycja usług
  MailboxesExchangeOnline.psm1 Exchange Online: skrzynki, uprawnienia, kwarantanna, zgodność, raporty
  GraphAPIIntune.psm1          Intune: urządzenia, akcje zdalne, zasady, BitLocker, LAPS
  GraphAPISharePoint.psm1      SharePoint (PnP): uprawnienia, kosz, pliki, raport, witryny
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

Testy jednostkowe (Pester 5) obejmują logikę niezależną od interfejsu WPF, z atrapami poleceń AD, Exchange i Graph:

```powershell
Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser
Invoke-Pester -Path .\Tests
```

## Rozwiązywanie problemów

1. **Aplikacja nie uruchamia się** - sprawdź wersję PowerShell (`$PSVersionTable`), uruchomienie jako administrator i log `%APPDATA%\HelpdeskTools\logs.txt`.
2. **Błąd `Could not load file or assembly Microsoft.Identity.Client`** - konflikt wersji bibliotek między modułami Graph i Exchange w jednej sesji. Zaktualizuj oba moduły (`Update-Module Microsoft.Graph.Authentication, ExchangeOnlineManagement`) albo połącz się najpierw z Exchange, a potem z Graph.
3. **Brak uprawnień (403) w Graph** - sprawdź role konta i zgodę administratora na uprawnienia z `GraphScopes`.
4. **SharePoint: błąd logowania PnP** - od 2024 r. PnP.PowerShell wymaga własnej rejestracji aplikacji w Entra ID; podaj jej Client ID (można go zapamiętać: `LogClientIDForPnP = true`).
5. **Funkcje AD zgłaszają brak modułu** - brak modułu ActiveDirectory (RSAT) na tym komputerze; po instalacji kliknij «Active Directory» w nagłówku.
6. **Okno logowania Exchange się nie pojawia / zawiesza** - włącz w Ustawieniach «logowanie w przeglądarce zamiast okna Windows (WAM)».
7. **Brak danych w raportach logowań lub MFA** - wymagana licencja Microsoft Entra ID P1 i uprawnienie AuditLog.Read.All; kondycja usług wymaga ServiceHealth.Read.All (połącz ponownie, aby zatwierdzić nowe uprawnienia).
8. **Źródło blokady AD jest puste** - konto musi mieć prawo odczytu dziennika Security na kontrolerze PDC, a zasady audytu muszą rejestrować zdarzenie 4740.

## Licencja

Projekt jest dostępny na licencji [MIT License](LICENSE).
