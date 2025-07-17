# Helpdesk Tools

**Helpdesk Tools** to aplikacja PowerShell oparta na Windows Forms, przeznaczona dla administratorów IT do zarządzania zasobami w środowiskach Active Directory, Exchange Online, Microsoft 365 (Graph API), SharePoint i Intune. Aplikacja oferuje graficzny interfejs użytkownika (GUI) z zakładkami dla różnych usług oraz funkcje takie jak generator haseł, zarządzanie konfiguracją i logowanie.

## Spis treści
1. [Wprowadzenie](#wprowadzenie)
2. [Wymagania](#wymagania)
3. [Instalacja](#instalacja)
4. [Użytkowanie](#użytkowanie)
5. [Struktura projektu](#struktura-projektu)
6. [Funkcjonalności](#funkcjonalności)
7. [Konfiguracja](#konfiguracja)
8. [Rozwiązywanie problemów](#rozwiązywanie-problemów)
9. [Plan rozwoju](#plan-rozwoju)
10. [Licencja](#licencja)

## Wprowadzenie

**Helpdesk Tools** to narzędzie wspierające administratorów IT w codziennych zadaniach, takich jak zarządzanie użytkownikami, skrzynkami pocztowymi, urządzeniami Intune, witrynami SharePoint oraz lokalnym Active Directory. Aplikacja integruje się z usługami Microsoft 365 (Exchange Online, Graph API, SharePoint) i oferuje intuicyjny interfejs z zakładkami dla każdej usługi.

### Główne cechy:
- **GUI**: Interfejs oparty na Windows Forms z zakładkami dla różnych usług.
- **Integracje**: Połączenia z Exchange Online, Microsoft Graph, SharePoint (PnP) i Active Directory.
- **Generator haseł**: Generowanie haseł klasycznych lub słownych z opcjami wysyłki e-mail i kopiowania do schowka.
- **Logowanie**: Rejestracja działań w zakładce "Logi" z możliwością filtrowania i zapisu do pliku.
- **Konfiguracja**: Edytor JSON w zakładce "Ustawienia" z podświetlaniem składni i walidacją.

## Wymagania

- **System operacyjny**: Windows 10 lub nowszy.
- **PowerShell**: Wersja 7.0 lub nowsza.
- **Uprawnienia**: Uruchomienie jako administrator (`#Requires -RunAsAdministrator`).
- **Moduły PowerShell**:
  - `ActiveDirectory` (dla zakładki "Lokalne AD").
  - `ExchangeOnlineManagement` (dla zakładki "Skrzynki").
  - `Microsoft.Graph` (dla zakładki "Użytkownicy" i "SharePoint").
  - `PnP.PowerShell` (dla zakładki "SharePoint").
- **Zależności .NET**:
  - `System.Windows.Forms`
  - `System.Drawing`
- **Pliki konfiguracyjne**: Folder `Resources/Icons` z ikonami dla przycisków.

## Instalacja

1. **Pobierz projekt**:
   - Sklonuj repozytorium lub pobierz archiwum ZIP:
     ```bash
     git clone <URL-repozytorium>
     ```
   - Rozpakuj projekt do wybranego katalogu.

2. **Utwórz folder konfiguracyjny**:
   - Aplikacja automatycznie tworzy folder `$env:APPDATA\HelpdeskTools` i plik `config.json` przy pierwszym uruchomieniu.

3. **Zainstaluj wymagane moduły**:
   - Uruchom PowerShell jako administrator i zainstaluj moduły:
     ```powershell
     Install-Module -Name ExchangeOnlineManagement -Scope AllUsers -Force
     Install-Module -Name Microsoft.Graph -Scope AllUsers -Force
     Install-Module -Name PnP.PowerShell -Scope AllUsers -Force
     Install-Module -Name ActiveDirectory -Scope AllUsers -Force
     ```

4. **Uruchom aplikację**:
   - Przejdź do katalogu projektu i uruchom główny skrypt:
     ```powershell
     .\HelpdeskTools.ps1
     ```

## Użytkowanie

1. **Uruchomienie aplikacji**:
   - Wykonaj skrypt `HelpdeskTools.ps1` w PowerShell 7 jako administrator.
   - Aplikacja otworzy okno GUI z zakładkami: Dashboard, Użytkownicy, Skrzynki, Intune, SharePoint, Lokalne AD, Ustawienia, Akcje masowe, Logi.

2. **Połączenie z usługami**:
   - W dolnym panelu kliknij przyciski:
     - **Połącz z Exchange**: Łączy z Exchange Online (z opcją GDAP).
     - **Połącz z MS GraphAPI**: Łączy z Microsoft Graph (z opcją GDAP).
     - **Połącz z SharePoint**: Łączy z SharePoint via PnP PowerShell.
   - Po nawiązaniu połączenia przyciski zmienią tekst na nazwę tenantu.

3. **Zakładki**:
   - **Dashboard**: Wyświetla kafelki z informacjami o stanie połączeń i statystykach.
   - **Użytkownicy**: Lista użytkowników Microsoft 365 z opcjami resetu hasła, zmiany licencji, MFA, itp. (niezaimplementowane).
   - **Skrzynki**: Lista skrzynek pocztowych z opcjami nadawania uprawnień, autorespondera, itp. (niezaimplementowane).
   - **Intune**: Lista urządzeń z opcjami zmiany nazwy, klucza odzyskiwania, itp. (niezaimplementowane).
   - **SharePoint**: Drzewo folderów witryny SharePoint z opcjami uprawnień i tworzenia folderów (niezaimplementowane).
   - **Lokalne AD**: Lista użytkowników, komputerów i grup z opcjami resetu hasła, zmiany OU, itp.
   - **Ustawienia**: Edytor JSON do konfiguracji aplikacji (np. e-mail do wysyłki haseł).
   - **Akcje masowe**: Masowe operacje na użytkownikach/skrzynkach (niezaimplementowane).
   - **Logi**: Przeglądanie, filtrowanie i zapisywanie logów aplikacji.

4. **Generator haseł**:
   - Kliknij "Generator haseł" w dolnym panelu.
   - Wybierz opcje (długość, znaki specjalne, tryb słowny) i kliknij "Generuj".
   - Skopiuj hasło do schowka lub wyślij e-mailem.

## Struktura projektu

Projekt składa się z następujących folderów i plików:

- **Główny skrypt**:
  - `HelpdeskTools.ps1`: Inicjalizuje zmienne globalne, importuje moduły i uruchamia GUI.

- **GUI**:
  - `MainForm.ps1`: Główny formularz z zakładkami i dolnym panelem przycisków.
  - `UsersPanel.ps1`, `MailBoxPanel.ps1`, `IntunePanel.ps1`, `SharePointPanel.ps1`, `LocalADPanel.ps1`, `SettingsPanel.ps1`, `LogsPanel.ps1`, `DashboardPanel.ps1`, `MassActionPanel.ps1`: Definicje zakładek.
  - `PasswordGenerator.ps1`: Formularz generatora haseł.
  - `GUIHelpers.ps1`: Funkcje pomocnicze dla UI (np. aktualizacja tekstu przycisków).
  - `Icons.ps1`: Ładowanie ikon dla przycisków.

- **Zdarzenia**:
  - `MainForm_Events.ps1`: Obsługa połączeń i zamknięcia aplikacji.
  - `LocalADPanel_Events.ps1`: Obsługa akcji w zakładce "Lokalne AD".
  - `SettingsPanel_Events.ps1`: Obsługa edytora JSON.
  - `LogsPanel_Events.ps1`: Obsługa filtrowania i zapisu logów.
  - `PasswordGeneratorForm_Events.ps1`: Obsługa generatora haseł.
  - `IntunePanel_Events.ps1`, `MailBoxPanel_Events.ps1`, `UsersPanel_Events.ps1`, `MassAction_Events.ps1`, `SharePointPanel_Events.ps1`: Puste (do zaimplementowania).

- **Moduły**:
  - `Utils.psm1`: Funkcje pomocnicze (logowanie, powiadomienia, dialogi, walidacja JSON, generowanie haseł).
  - `LocalActiveDirectory.psm1`: Funkcje dla Active Directory (np. `Invoke-LocalADRefresh`).
  - `Config.psm1`: Zarządzanie konfiguracją JSON.
  - `ModulesConnection.psm1`: Połączenia z modułami PowerShell.
  - `PasswordGenerator.psm1`: Generowanie haseł klasycznych i słownych.
  - `MailboxesExchangeOnline.psm1`, `GraphAPIM365Users.psm1`, `GraphAPISharePoint.psm1`: Puste (do zaimplementowania).

- **Zasoby**:
  - `Resources/Icons`: Folder z ikonami dla przycisków.

## Funkcjonalności

### Dashboard
- Wyświetla kafelki z informacjami o stanie połączeń i statystykach (np. liczba użytkowników, skrzynek).
- **Status**: Częściowo zaimplementowany (brak dynamicznych danych).

### Użytkownicy
- Lista użytkowników Microsoft 365 w `ComboBox`.
- Akcje: Reset hasła, zmiana licencji, MFA, dodawanie do grup, itp.
- **Status**: Brak implementacji zdarzeń i funkcji w `GraphAPIM365Users.psm1`.

### Skrzynki
- Lista skrzynek pocztowych w `ComboBox`.
- Akcje: Sprawdzenie uprawnień, nadawanie/odbieranie uprawnień, autoresponder, ukrywanie w GAL.
- **Status**: Brak implementacji zdarzeń i funkcji w `MailboxesExchangeOnline.psm1`.

### Intune
- Lista urządzeń w `ComboBox`.
- Akcje: Zmiana nazwy, zmiana primary user, klucz odzyskiwania, LAPS.
- **Status**: Brak implementacji zdarzeń.

### SharePoint
- Pole tekstowe na adres witryny i drzewo folderów w `TreeView`.
- Akcje: Sprawdzenie uprawnień, nadawanie/odbieranie uprawnień, tworzenie grup/folderów.
- **Status**: Brak implementacji zdarzeń i funkcji w `GraphAPISharePoint.psm1`.

### Lokalne AD
- Lista użytkowników, komputerów i grup w `ComboBox`.
- Akcje: Reset hasła, zmiana grup, przenoszenie OU, wyłączanie konta, itp.
- **Status**: Częściowo zaimplementowany (`Invoke-LocalADRefresh` działa, brak innych funkcji).

### Ustawienia
- Edytor JSON z podświetlaniem składni i walidacją.
- Akcje: Zapis konfiguracji, ponowne ładowanie.
- **Status**: W pełni zaimplementowany.

### Akcje masowe
- Planowana funkcjonalność masowych operacji.
- **Status**: Brak implementacji.

### Logi
- Wyświetlanie, filtrowanie, kopiowanie i zapisywanie logów.
- **Status**: W pełni zaimplementowany.

### Generator haseł
- Generowanie haseł klasycznych lub słownych.
- Opcje: Długość, znaki specjalne, unikanie podobnych znaków, wysyłka e-mail.
- **Status**: W pełni zaimplementowany.

## Konfiguracja

Aplikacja używa pliku `config.json` w folderze `$env:APPDATA\HelpdeskTools`. Domyślna konfiguracja:

```json
{
  "PasswordEmailAdress": "",
  "PasswordEmailTitle": "Nowe hasło",
  "PasswordSpecialCharacters": "!@#$%^&*()-_=+[]{}|;:,.<>?/",
  "PasswordUseWordBased": false,
  "LogPasswordGeneration": false
}
```

- **Edycja**: W zakładce "Ustawienia" edytuj JSON i zapisz zmiany (Ctrl+S lub przycisk "Zapisz konfigurację").
- **Uwaga**: Logowanie haseł (`LogPasswordGeneration`) może stanowić zagrożenie bezpieczeństwa i powinno być wyłączone.

## Rozwiązywanie problemów

1. **Aplikacja nie uruchamia się**:
   - Sprawdź, czy PowerShell jest w wersji 7.0+.
   - Upewnij się, że skrypt jest uruchomiony jako administrator.
   - Sprawdź logi w `$env:APPDATA\HelpdeskTools\logs.txt`.

2. **Brak połączenia z usługami**:
   - Upewnij się, że moduły `ExchangeOnlineManagement`, `Microsoft.Graph`, `PnP.PowerShell` są zainstalowane.
   - Sprawdź uprawnienia konta (np. GDAP dla Exchange/Graph).
   - Zobacz szczegóły błędów w zakładce "Logi".

3. **Puste listy w ComboBox**:
   - Kliknij "Odśwież" w odpowiedniej zakładce.
   - Upewnij się, że odpowiednie połączenie (Exchange, Graph, SharePoint) jest aktywne.

4. **Błędy JSON w zakładce Ustawienia**:
   - Sprawdź poprawność składni JSON w edytorze.
   - Użyj przycisku "Załaduj ponownie" do przywrócenia domyślnej konfiguracji.

## Plan rozwoju

1. **Uzupełnienie brakujących funkcji**:
   - Implementacja zdarzeń dla zakładek `Użytkownicy`, `Skrzynki`, `Intune`, `Akcje masowe`, `SharePoint`.
   - Dodanie funkcji do modułów `MailboxesExchangeOnline.psm1`, `GraphAPIM365Users.psm1`, `GraphAPISharePoint.psm1`.
   - Uzupełnienie funkcji dla `Lokalne AD` (np. `Invoke-LocalADResetPassword`).

2. **Poprawa wydajności**:
   - Dodanie filtrowania/stronicowania dla dużych list w `ComboBox`.
   - Optymalizacja ładowania ikon (`Icons.ps1`).

3. **Bezpieczeństwo**:
   - Wyłączenie logowania haseł w `PasswordGenerator.psm1`.
   - Rozszerzenie słownika słów dla haseł słownych.

4. **Lokalizacja**:
   - Dodanie wsparcia dla innych języków w UI (np. angielskiego).

5. **Testy**:
   - Przeprowadzenie testów w środowisku z dużą liczbą obiektów AD.
   - Dodanie automatycznych testów jednostkowych dla funkcji w modułach.

## Licencja

Projekt jest dostępny na licencji [MIT License](LICENSE). Szczegóły w pliku `LICENSE`.