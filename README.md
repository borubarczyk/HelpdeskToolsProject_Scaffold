# Helpdesk Tools

**Helpdesk Tools** to aplikacja PowerShell z interfejsem Windows Forms dla administratorów IT. Pozwala zarządzać lokalnym Active Directory, użytkownikami Microsoft 365 (Microsoft Graph), skrzynkami Exchange Online, urządzeniami Intune i uprawnieniami SharePoint z jednego okna.

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
  - `Microsoft.Graph.Authentication` - zakładki Użytkownicy, Intune, Dashboard.
  - `ExchangeOnlineManagement` - zakładka Skrzynki.
  - `PnP.PowerShell` - zakładka SharePoint (wymaga własnej rejestracji aplikacji w Entra ID i jej Client ID).
  - `ActiveDirectory` (RSAT) - zakładka Lokalne AD. Instalacja: `Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0` (Windows 10/11) lub `Install-WindowsFeature RSAT-AD-PowerShell` (Windows Server).
- **Uprawnienia**: odpowiednie role administracyjne (np. User Administrator, Exchange Administrator, Intune Administrator). Przy pierwszym połączeniu z Graph może być wymagana zgoda administratora na uprawnienia z klucza `GraphScopes`.

## Instalacja i uruchomienie

```powershell
git clone <URL-repozytorium>
cd HelpdeskToolsProject_Scaffold
pwsh -STA -File .\HelpdeskTools.ps1
```

Przy pierwszym uruchomieniu aplikacja tworzy katalog `%APPDATA%\HelpdeskTools` z plikiem `config.json` oraz logiem `logs.txt`.

## Interfejs

- **Nawigacja** (lewa kolumna): Dashboard, Użytkownicy, Skrzynki, Intune, SharePoint, Lokalne AD, Akcje masowe, Logi, Ustawienia oraz Generator haseł i wyjście.
- **Nagłówek**: nazwa sekcji i przyciski połączeń **Exchange / Graph / SharePoint**. Po połączeniu przycisk zmienia kolor na zielony i pokazuje nazwę tenantu, a kolejne kliknięcie rozłącza. Obsługiwane jest logowanie przez konto organizacji lub GDAP (tenant klienta).
- **Sekcje z listą**: wyszukiwarka filtrująca wszystkie kolumny, sortowanie po kliknięciu nagłówka, szybka lista (tryb wirtualny, tysiące obiektów), panel szczegółów z grupami (dwuklik kopiuje wartość) i panel akcji po prawej.
- **Pasek statusu**: bieżąca operacja, wskaźnik postępu i stan połączeń (AD, Exchange, Graph, SharePoint).
- **Okno jest skalowalne** (wcześniej miało stały rozmiar).
- **Skróty klawiszowe**: `Ctrl+1..9` - sekcje, `F5` - odśwież bieżącą sekcję, `Ctrl+G` - generator haseł, `Esc` - wyczyść wyszukiwanie, `Ctrl+S` - zapisz ustawienia.

## Funkcje

### Dashboard
Kafelki z danymi pobieranymi na żądanie: liczba użytkowników (aktywni), skrzynki wg typu, SharePoint, urządzenia Intune (niezgodne), licencje (przypisane/dostępne), zablokowane konta AD, stan połączeń i alerty (brak wolnych licencji, niezgodne urządzenia, zablokowane konta). Kliknięcie kafelka przechodzi do sekcji. Poniżej lista ostatnich zdarzeń.

### Użytkownicy (Microsoft 365)
Reset hasła (z generatora), blokada/odblokowanie logowania, unieważnienie sesji, metody MFA (podgląd, usuwanie, reset rejestracji MFA, dodanie telefonu, Temporary Access Pass), dane kontaktowe, licencje (przypisz/usuń/przegląd), dodawanie i usuwanie z grup (również grup pocztowych przez Exchange), przejście do skrzynki, urządzenia użytkownika, nowy użytkownik, eksport CSV.

### Skrzynki (Exchange Online)
Filtr typu skrzynki, szczegóły (rozmiar, limity, archiwum, przekierowanie, autoodpowiedź, aliasy), sprawdzanie/nadawanie/odbieranie uprawnień (FullAccess, SendAs, SendOnBehalf), uprawnienia kalendarza, konwersja typu (Shared/Regular/Room/Equipment), autoodpowiedź (w tym zaplanowana), przekierowanie, ukrywanie w GAL, archiwum (także auto-rozszerzalne), reguły skrzynki (z ostrzeżeniem o regułach przekierowujących), śledzenie wiadomości, urządzenia mobilne, eksport CSV.

### Intune
Filtr systemu, szczegóły urządzenia, zmiana nazwy, zmiana Primary User, synchronizacja, zdalny restart, informacje o sprzęcie, zainstalowane aplikacje, członkostwa grup, klucze BitLocker, hasło LAPS (Windows LAPS w Entra ID), eksport CSV.

### SharePoint (PnP)
Połączenie z dowolną witryną, drzewo bibliotek i folderów (ładowane przy rozwijaniu), uprawnienia zaznaczonego elementu (automatycznie), nadawanie uprawnień (także dla wielu elementów zaznaczonych checkboxami), odbieranie, przerywanie/przywracanie dziedziczenia, tworzenie grup SharePoint, zarządzanie członkami grup, nowe foldery, otwieranie w przeglądarce, eksport uprawnień.

### Lokalne AD
- **Użytkownicy**: reset hasła, włącz/wyłącz/odblokuj, edycja danych, profil i katalog domowy, akcje specjalne (wymuszenie zmiany hasła, "hasło nigdy nie wygasa", data wygaśnięcia konta, kopiowanie DN/UPN), grupy, przeniesienie do OU, nowy użytkownik, eksport, usunięcie.
- **Komputery**: test połączenia (DNS + ping), restart, włącz/wyłącz konto, opis, grupy, przeniesienie do OU, hasło LAPS (Windows LAPS i starszy Microsoft LAPS), klucze BitLocker, eksport, usunięcie.
- **Grupy**: dodawanie/usuwanie członków, eksport członków, zmiana nazwy, typu i zakresu, przeniesienie do OU, nowa grupa, eksport, usunięcie.

### Akcje masowe
Lista identyfikatorów (wklejona lub z pliku CSV/TXT) i jedna akcja dla wszystkich: AD (wyłącz/włącz/odblokuj, reset hasła, grupy, przeniesienie do OU), Microsoft 365 (blokada, odblokowanie, unieważnienie sesji, reset hasła, grupy, licencje), Exchange (konwersja, GAL, archiwum, przekierowanie, FullAccess). **Tryb testowy** (domyślnie włączony) tylko sprawdza, czy obiekty istnieją. Wyniki można wyeksportować do CSV.

### Logi
Kolorowanie wg typu, filtr tekstowy i typu, automatyczne przewijanie, kopiowanie, zapis do pliku, otwarcie pliku logu i folderu konfiguracji. Plik logu jest archiwizowany po przekroczeniu `LogFileMaxSizeMB`.

### Ustawienia
Edytor `config.json` z podświetlaniem składni, walidacją w trakcie pisania, formatowaniem, przywracaniem ustawień domyślnych i opisem wszystkich kluczy.

### Generator haseł
Tryby: klasyczne, przyjazne (sylaby) i słownikowe; długość 8-64, cyfry, znaki specjalne, bez podobnych znaków, pierwsza litera; wskaźnik siły hasła; kopiowanie i wysyłka e-mailem (opcjonalnie z numerem telefonu w temacie dla bramki SMS). Losowanie korzysta z kryptograficznego generatora liczb losowych.

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
  "ExportPath": ""
}
```

Pełną listę domyślnych kluczy zawiera plik [`config.example.json`](config.example.json). `LogPasswordGeneration` zapisuje hasła w logu w postaci jawnej - pozostaw tę opcję wyłączoną.

## Struktura projektu

```
HelpdeskTools.ps1              Punkt wejścia: zmienne globalne, import modułów, konfiguracja, GUI
Modules/
  Utils.psm1                   Logowanie, powiadomienia, dialogi, eksport, walidacja, JSON
  UIComponents.psm1            Motyw, przyciski, listy, panel szczegółów, okna dialogowe, status, nawigacja
  Config.psm1                  Konfiguracja (domyślne wartości, scalanie, zapis)
  ModulesConnection.psm1       Instalacja modułów, połączenia, wywołania Microsoft Graph
  PasswordGenerator.psm1       Generator haseł i ocena siły hasła
  LocalActiveDirectory.psm1    Operacje Active Directory
  GraphAPIM365Users.psm1       Użytkownicy, licencje, grupy, MFA (Graph)
  MailboxesExchangeOnline.psm1 Skrzynki Exchange Online
  GraphAPIIntune.psm1          Urządzenia Intune, BitLocker, LAPS
  GraphAPISharePoint.psm1      SharePoint (PnP)
  MassActions.psm1             Akcje masowe
  Dashboard.psm1               Statystyki Dashboardu
  Startup.psm1                 Inicjalizacja po zbudowaniu GUI
GUI/                           Widoki sekcji (budowa kontrolek)
GUI/Events/                    Obsługa zdarzeń sekcji
Resources/Icons/               Ikony
Tests/                         Testy Pester
```

Moduły zawierają logikę (parametry wejściowe, zwracane dane), a pliki w `GUI/Events` łączą ją z interfejsem.

## Testy

Testy jednostkowe (Pester 5) obejmują logikę niezależną od Windows Forms, z atrapami poleceń AD, Exchange i Graph:

```powershell
Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser
Invoke-Pester -Path .\Tests
```

## Rozwiązywanie problemów

1. **Aplikacja nie uruchamia się** - sprawdź wersję PowerShell (`$PSVersionTable`), uruchomienie jako administrator i log `%APPDATA%\HelpdeskTools\logs.txt`.
2. **Błąd `Could not load file or assembly Microsoft.Identity.Client`** - konflikt wersji bibliotek między modułami Graph i Exchange w jednej sesji. Zaktualizuj oba moduły (`Update-Module Microsoft.Graph.Authentication, ExchangeOnlineManagement`) albo połącz się najpierw z Exchange, a potem z Graph.
3. **Brak uprawnień (403) w Graph** - sprawdź role konta i zgodę administratora na uprawnienia z `GraphScopes`.
4. **SharePoint: błąd logowania PnP** - od 2024 r. PnP.PowerShell wymaga własnej rejestracji aplikacji w Entra ID; podaj jej Client ID (można go zapamiętać: `LogClientIDForPnP = true`).
5. **Zakładka Lokalne AD jest nieaktywna** - brak modułu ActiveDirectory (RSAT) na tym komputerze.
6. **Błędy JSON w Ustawieniach** - najedź na edytor, aby zobaczyć opis błędu, lub użyj "Przywróć domyślne".

## Licencja

Projekt jest dostępny na licencji [MIT License](LICENSE).
