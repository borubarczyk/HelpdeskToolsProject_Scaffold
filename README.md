# Helpdesk Tools

**Helpdesk Tools** to aplikacja PowerShell z interfejsem WPF dla administratorów IT. Pozwala zarządzać użytkownikami Microsoft 365 (Microsoft Graph), bezpieczeństwem Entra ID i Microsoft Defender, skrzynkami Exchange Online, urządzeniami Intune, witrynami SharePoint i OneDrive z jednego okna, a także planować zadania, prowadzić checklisty on/offboardingu i wysyłać raporty bez otwierania programu. Funkcje lokalnego Active Directory są domyślnie ukryte (Ustawienia > Funkcje lokalne). Wygląd, ikony, czcionka i układ są wspólne z projektami **Domain Ops** (AD-ManagerDiamond) i **ServerReview**.

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
  - `ActiveDirectory` (RSAT) - tylko po włączeniu funkcji lokalnych: przestrzenie Użytkownicy / Komputery / Grupy AD. Instalacja: `Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0` (Windows 10/11) lub `Install-WindowsFeature RSAT-AD-PowerShell` (Windows Server).
- **Uprawnienia**: odpowiednie role administracyjne (np. User Administrator, Exchange Administrator, Intune Administrator). Przy pierwszym połączeniu z Graph może być wymagana zgoda administratora na uprawnienia z klucza `GraphScopes`.

## Instalacja i uruchomienie

```powershell
git clone <URL-repozytorium>
cd HelpdeskToolsProject_Scaffold
pwsh -File .\HelpdeskTools.ps1
```

Przy pierwszym uruchomieniu program prosi o ustawienie **PIN-u** (4-8 cyfr) - będzie wymagany przy każdym uruchomieniu.

**Skrót na pulpicie bez okna konsoli**: Ustawienia > Aplikacja > «Skrót na pulpicie» (uruchamia program jako administrator z parametrem `-HideConsole`). **Podpisywanie skryptów** (zasada `AllSigned`): Ustawienia > Aplikacja > «Podpisz skrypty» - certyfikatem z magazynu użytkownika albo nowym certyfikatem z podpisem własnym. **Aktualizacja**: program sprawdza przy starcie nową wersję w repozytorium GitHub (Ustawienia > Aktualizacje) i instaluje ją jednym kliknięciem (Ctrl+K > «Aktualizuj program»), z kopią poprzedniej wersji w `%LOCALAPPDATA%\HelpdeskTools\Kopie`.

Pliki programu (jak w Domain Ops):

| Co | Gdzie |
|---|---|
| Konfiguracja | `%APPDATA%\HelpdeskTools\config.json` |
| Konta MFA (klucze zaszyfrowane DPAPI) | `%APPDATA%\HelpdeskTools\Mfa.json` |
| Dziennik (plik dzienny, 30 dni) | `%LOCALAPPDATA%\HelpdeskTools\Logs\HelpdeskTools_RRRRMMDD.log` |
| Eksport (Excel, CSV, HTML), wizytówki, pobrane pliki | `Dokumenty\HelpdeskTools\Eksport` (zmiana: Ustawienia > Katalog eksportu) |
| Zapamiętany układ (ulubione, ostatnie moduły, kolumny, widoki filtrów, okno) | `%APPDATA%\HelpdeskTools\UiState.json` |
| Zadania zaplanowane, checklisty, rejestr cofania zmian | `%APPDATA%\HelpdeskTools\Jobs.json`, `Checklists.json`, `ChecklistTemplates.json`, `Undo.json` |
| Migawki konfiguracji | `%APPDATA%\HelpdeskTools\Snapshots\<rodzaj>\*.json` |
| Wtyczki | `Plugins\*.ps1` w folderze programu i `%APPDATA%\HelpdeskTools\Plugins\*.ps1` (zob. [Plugins/README.md](Plugins/README.md)) |

## Interfejs

Układ jak w Domain Ops: ciemny motyw, Segoe UI, ikony Segoe Fluent Icons / MDL2.

- **Nagłówek**: logo, przełącznik **przestrzeni roboczych** (Pulpit, Microsoft 365, Bezpieczeństwo, Exchange, Intune, Witryny, SharePoint, Zadania; po włączeniu funkcji lokalnych także Użytkownicy / Komputery / Grupy AD) oraz przyciski połączeń z kropką stanu i nazwą tenantu, wyszukiwanie (Ctrl+K), blokada, generator haseł i ustawienia.
- **Paleta poleceń (`Ctrl+K`)**: szybkie przejście do dowolnego modułu po nazwie lub opisie, ulubione i ostatnio otwierane moduły, polecenia z wpisanym tekstem (np. «Wizytówka użytkownika: jan», «Diagnoza logowania: jan@firma.pl», «Historia obiektu: …», «Szukaj w dzienniku: …»), przełączenie tenantu, podsumowanie do zgłoszenia, aktualizacja. Gwiazdka przy module (prawy przycisk w nawigacji) - ulubione.
- **Trzy etapy przy zmianach** (we wszystkich modułach): (1) zakres - obiekty zaznaczone na liście po lewej, (2) **sprawdzenie stanu** - niebieski przycisk na początku modułu («Sprawdź stan», «Pobierz informacje», «Pokaż…»; to także akcja `F5`), (3) **zmiana** - czerwone przyciski, wykonywane na **wierszach zaznaczonych w wynikach**, a bez zaznaczenia w wynikach - na obiektach z listy po lewej. Okno potwierdzenia pokazuje, skąd wzięto obiekty. `F5` nigdy nie uruchamia zmiany. Czerwone przyciski są też w menu prawego przycisku na wierszach («… - zaznaczone (N)»).
- **Akcje pod prawym przyciskiem w każdych wynikach**: dla zaznaczonych wierszy z kontami (UPN) podmenu «Konto Microsoft 365 (N)» - szczegóły, stan konta, blokada, odblokowanie, unieważnienie sesji; w Exchange «Skrzynka (N)» - szczegóły, ukrycie / pokazanie w GAL; w Intune «Urządzenie Intune (N)» - synchronizacja, restart. Czerwone przyciski zmian modułu są też w menu wierszy («… - zaznaczone (N)»).
- **Nawigacja**: kliknięcie nagłówka kategorii zwija ją i rozwija (zapamiętane); **ulubione moduły** (prawy przycisk na module > «Dodaj do ulubionych») są przyciskami na Pulpicie > Przegląd i na początku palety Ctrl+K.
- **Zapamiętany układ**: ulubione i ostatnie moduły, ostatni moduł w każdej przestrzeni, ukryte kolumny, położenie i rozmiar okna, wysokość dziennika. **Zapisane widoki** (przycisk nad tabelą): filtr tekstowy, filtry kolumn i ukryte kolumny pod nazwą, do przywrócenia jednym kliknięciem.
- **Operacje w tle**: zapytania Microsoft 365 wykonują się w osobnym wątku - okno reaguje, wiersze pojawiają się na bieżąco, a **«Przerwij»** na pasku stanu i obok wskaźnika pracy w nagłówku modułu (albo `Esc`) kończy zapytanie z zachowaniem pobranych wyników. Odczyty Microsoft 365 i Intune na wielu obiektach (np. «Sprawdź stan», szczegóły kont, urządzeń) też idą w tle automatycznie, gdy korzystają tylko z funkcji modułów - okno reaguje, a wiersze dochodzą na bieżąco. Exchange i SharePoint (PnP) działają w wątku okna (ich połączenie istnieje tylko tam), ale okno odświeża się między obiektami. Operacje na wielu obiektach w wątku okna (sprawdzenie stanu, zmiany, akcje pod prawym przyciskiem) zatrzymują się po bieżącym obiekcie - pozostałe obiekty trafiają do wyników jako «Pominięto», a do dziennika wpis, czego nie wykonano. Po długiej operacji (domyślnie 20 s), gdy okno nie jest aktywne - **powiadomienie Windows** i miganie paska zadań.
- **Profile tenantów (GDAP)**: zapisane tenanty klientów i własne (dziesiątki firm) - Pulpit > **«Profile tenantów»**: lista z wyszukiwaniem i filtrami, dwuklik łączy wybrane usługi (Microsoft 365 / Graph, Exchange, SharePoint), edycja, duplikat, usunięcie, **import i eksport CSV** (szablon w module). Profil zawiera: tenant (domena lub ID), GDAP, organizację Exchange i konto partnera, adres SharePoint i **Client ID aplikacji PnP w tenancie klienta**, usługi domyślne i notatki - bez haseł. Szybkie łączenie: przyciski w nagłówku (ostatnio używane profile + «Inny profil…» z wyszukiwaniem), Ctrl+K > «Przełącz tenant» albo «Połącz z tenantem: <tekst>». Profil proponowany po połączeniu z tenantem klienta.
- **Podsumowanie do zgłoszenia**: przycisk «Do zgłoszenia» w dzienniku - tekst do ticketu z operacji zmieniających wykonanych w tej sesji (filtr po obiekcie), kopiowanie albo wysyłka na kanał Teams.
- **Lista obiektów** (lewa kolumna): wyszukiwanie, pola wyboru (wiele obiektów naraz), «Zaznacz widoczne / odwróć / odznacz» oraz **«Zaznacz z listy»** - wklejone identyfikatory lub plik CSV/TXT. Dawne «Akcje masowe» działają teraz w każdym module: zaznacz kilka obiektów i wykonaj akcję. Lista wczytuje się sama po połączeniu z usługą.
- **Nawigacja modułów** (środkowa kolumna) pogrupowana w kategorie.
- **Widok modułu**: parametry, przyciski akcji, kafelki, tabela wyników z filtrem (`Ctrl+F`, słowo z minusem wyklucza), sortowaniem, panelem szczegółów wiersza, kopiowaniem (format Excel) i eksportem. Prawy przycisk na wierszach - akcje na wynikach (np. odebranie uprawnienia, przywrócenie z kosza). Wiersze z błędami i ostrzeżeniami są kolorowane.
- **Filtry kolumn** (jak autofiltr w Excelu, jak w Domain Ops): lejek w nagłówku kolumny otwiera okienko z warunkiem (zawiera, nie zawiera, równa się, różne od, zaczyna się od, kończy się na, większe / mniejsze niż - liczbowo, puste, niepuste) i listą wartości z liczbą wierszy (wyszukiwanie, «Zaznacz wszystkie»). Filtry kilku kolumn działają razem z polem «Filtruj wyniki»; chip «Filtry kolumn: N» pokazuje aktywne filtry (kliknięcie czyści). Prawy przycisk na komórce: «Pokaż tylko …», «Ukryj …», kopiowanie wartości całej kolumny (np. lista UPN do «Zaznacz z listy»).
- **Menu nagłówka kolumny** (prawy przycisk na nagłówku): sortowanie, kopiowanie wartości kolumny (także bez powtórzeń i pustych), filtr, ukrycie kolumny, «Pokaż tylko tę kolumnę», «Wybierz kolumny…» (przycisk z ikoną kolumn nad tabelą). Ukryte kolumny nie trafiają do kopiowania ani eksportu i zostają ukryte po odświeżeniu wyników. **«Ukryj kolumny bez wartości»** (przycisk z przekreślonym okiem nad tabelą) - jednym kliknięciem chowa puste kolumny (np. nieużywane atrybuty niestandardowe), ponowne kliknięcie je pokazuje.
- **Eksport wyników**: **Excel (.xlsx** z formatowaniem: pogrubiony nagłówek, zamrożony wiersz, autofiltr, kolory wierszy z błędami i ostrzeżeniami, arkusz «Informacje» z filtrami), CSV (Excel), **raport HTML** (samodzielny plik w ciemnym motywie: wyszukiwarka, sortowanie i filtr pod każdą kolumną, kopiowanie wiersza i widocznych wierszy, otwieranie wiersza w osobnym oknie, druk; w nagłówku raportu użyte filtry) albo JSON. **Wyślij e-mailem** (przycisk z kopertą): wyniki jako załącznik Excel / HTML / CSV albo tabela w treści, z Twojej skrzynki (Microsoft Graph, Mail.Send).
- **Dane poufne** (hasła, klucze BitLocker, LAPS, TAP) są maskowane - «Pokaż poufne»; skopiowane hasło znika ze schowka po 60 s.
- **Potwierdzenie przed każdą zmianą**: zanim program cokolwiek zmieni, pokazuje okno «co zostanie zrobione» (wartości z formularza albo parametry z paska, np. «Tryb: Scheduled, Od…, Do…, Odbiorcy zewnętrzni: All») i **listę obiektów, których to dotyczy** (z liczbą i źródłem: zaznaczone na liście / wiersze zaznaczone w wynikach); przycisk pokazuje liczbę obiektów («Wykonaj (6)»). Hasła i klucze są maskowane. Decyzja (zatwierdzenie albo anulowanie) trafia do dziennika razem z ustawieniami. Operacje nieodwracalne wymagają przepisania słowa (np. `USUŃ`, `OFFBOARDING`). Bez pytania działają tylko operacje bez zmian (np. pobieranie plików, sprawdzenie dostępności).
- **Dziennik operacji** (`Ctrl+L`) z licznikiem ostrzeżeń: filtr poziomu (wszystkie / ostrzeżenia i błędy / tylko błędy / wykonane), wyszukiwanie w komunikatach i nazwach modułów, kopiowanie zaznaczonych lub widocznych wpisów, dzisiejszy plik dziennika i **historia z poprzednich dni** (Pulpit > «Dziennik programu»). Przy włączonym MFA każdy wpis w pliku ma nazwę konta, które odblokowało program. Powiadomienia w oknie (większe, z kolorowym paskiem), pasek stanu z postępem. **Ostrzeżenia poleceń** Exchange / Graph / PnP (np. «Events from Email parameters … are deprecated», «The object … has been corrupted») trafiają do dziennika jako wpisy «Ostrzeżenie (moduł): …» - powtórzenia łączone z liczbą («(×6)»). **Szczegółowy dziennik (debug)**: Ustawienia > Aplikacja albo Ctrl+K > «Szczegółowy dziennik (debug)» - zapytania Microsoft Graph z czasem odpowiedzi, kroki łączenia i logowania, wersje i ścieżki modułów, stos błędów (do diagnozy problemów).
- **Logowanie w przeglądarce**: Exchange, Microsoft 365 i SharePoint logują się w karcie domyślnej przeglądarki (bez okna Windows WAM, które chowało się za programem). W tym czasie widoczne jest okienko «Trwa logowanie» z przyciskiem **Anuluj logowanie** i limitem czasu - zamknięcie karty przez przypadek nie blokuje programu: anuluj i połącz ponownie.
- **PIN i blokada programu** (jak w Domain Ops): PIN przy uruchomieniu, blokada przyciskiem z kłódką, `Ctrl+Shift+L` albo automatycznie po bezczynności (Ustawienia, domyślnie 15 min; liczy się klawiatura, mysz i ruch kursora nad aktywnym oknem programu). Blokada ukrywa zawartość okna głównego i otwartych okien (np. formularza) i czyści hasła ze schowka; połączenia z usługami trwają. Po 5 błędnych próbach: przy starcie program się zamyka, w trakcie pracy - 30 s przerwy. Z ekranu blokady można zamknąć program bez PIN-u przyciskiem **«Zakończ awaryjnie»** (albo krzyżykiem okna) - z potwierdzeniem drugim kliknięciem w ciągu 10 s. Zmiana PIN-u: Ustawienia > «Zmień PIN». Zapomniany PIN: usuń wartości `PinHash`, `PinSalt`, `PinLength` z `config.json` - program poprosi o nowy (z włączonym MFA nadal wymagany jest kod z aplikacji).
- **MFA przy odblokowaniu** (jak w Domain Ops): po PIN-ie kod z aplikacji uwierzytelniającej (Microsoft / Google Authenticator i podobne, TOTP: 6 cyfr co 30 s, SHA1). Włączenie: Ustawienia > Bezpieczeństwo > «MFA - konta i klucze» > «Włącz MFA dla konta podstawowego» - program pokazuje **kod QR do zeskanowania** w aplikacji, klucz do wpisania ręcznie (lub link `otpauth://` do skopiowania) i zapisuje go dopiero po poprawnym kodzie. Ten sam kod nie zadziała drugi raz (np. przy ponownej blokadzie - trzeba poczekać na następny). Klucze są w `Mfa.json` zaszyfrowane DPAPI (odczyta je tylko to konto Windows na tym komputerze). **Utrata telefonu**: usuń `Mfa.json` - program wróci do samego PIN-u.
- **Konta dodatkowe MFA z uprawnieniami**: kolejne osoby mogą mieć własną nazwę, własny PIN i własny klucz - na ekranie blokady wybiera się konto. Dla każdego konta dodatkowego «Uprawnienia…» blokują wybrane przestrzenie robocze, pojedyncze moduły i Ustawienia (znikają z nawigacji). Dodanie konta, nowy klucz, uprawnienia i usunięcie zatwierdza się kodem z aplikacji konta podstawowego. Zmiana konta na ekranie blokady zamyka okna poprzedniego konta. W nagłówku obok konta Windows widać konto MFA. To ograniczenie interfejsu programu: uprawnienia w usługach wynikają z kont, którymi program łączy się z Microsoft 365, Exchange i AD.
- **Weryfikacja pakietów**: przed połączeniem program sprawdza, czy zainstalowany moduł (Graph, Exchange, PnP) pasuje do tej wersji PowerShell i czy nie koliduje z bibliotekami innego modułu załadowanego w sesji. Niezgodna wersja jest pomijana (używana jest najnowsza zgodna), a gdy żadnej nie ma - program proponuje instalację zgodnej wersji z PowerShell Gallery lub aktualizację PowerShell. Przy konflikcie bibliotek proponuje ponowne uruchomienie i połączenie najpierw z tą usługą. Podgląd: Pulpit > «Moduły i środowisko».
- **Tryb tylko do odczytu** dla kont MFA: w «Uprawnienia…» konta dodatkowego odznacz «Wprowadzanie zmian» - konto widzi raporty i szczegóły, ale nie wykona akcji zmieniających (blokady, licencje, grupy, zadania, cofanie zmian).
- **Integracje**: powiadomienia na kanale Teams (webhook - Przepływy pracy albo Incoming Webhook) o offboardingu, zadaniach zaplanowanych i ukończonych checklistach; wysyłka wyników i raportów e-mailem przez Microsoft Graph.
- **Skróty**: `Ctrl+K` - paleta poleceń, `Ctrl+1..9` - przestrzenie, `F5` - główna akcja modułu, `Ctrl+F` - filtr wyników, `Ctrl+L` - dziennik, `Ctrl+Shift+L` - blokada, `Ctrl+G` - generator haseł, `Esc` - przerwanie zapytania w tle.

## Funkcje

### Pulpit
Kafelki ze wszystkich połączonych usług i lista problemów; **moduły i środowisko** (weryfikacja pakietów, instalacja zgodnych wersji, foldery dziennika i eksportu); **dziennik programu** (wpisy z wybranego dnia: poziom, konto MFA, komunikat - z filtrami kolumn i eksportem do raportu HTML); **licencje** (nazwy «po ludzku»: najpopularniejsze po polsku, pozostałe z **oficjalnej listy Microsoft** - pobieranej z download.microsoft.com raz na 30 dni do `%LOCALAPPDATA%\HelpdeskTools\LicenseNames.json`, przycisk «Odśwież nazwy licencji»; kolumna **«Co zawiera»** - np. «poczta Exchange, SharePoint i OneDrive, Teams, aplikacje Office na komputer» - i pełna lista planów usług; wolne/wyczerpane, lista użytkowników z licencją), **kondycja usług Microsoft 365** z otwartymi incydentami, **centrum wiadomości** (zapowiedzi zmian z terminami).

### Microsoft 365
- Konto: szczegóły, dane kontaktowe (także hurtowo), **przełożony**, urządzenia użytkownika, **wizytówka (raport HTML: konto, MFA, grupy, skrzynka, urządzenia, logowania)**, **porównanie dwóch kont** (grupy, licencje, role, aplikacje - z uzupełnieniem brakujących grup).
- Bezpieczeństwo: blokada logowania z unieważnieniem sesji, reset hasła (losowe / podane), metody MFA (usuwanie, telefon, Temporary Access Pass), **historia logowań** (IP, lokalizacja, dostęp warunkowy), **diagnoza logowania** («nie mogę się zalogować»: konto, hasło, MFA, ryzyko, dostęp warunkowy, wyjaśnienie kodów błędów 50053, 50074, 53003…), **zasady dostępu warunkowego obejmujące konto**, **zgody aplikacji konta** (z cofaniem).
- Licencje i grupy: przypisywanie / usuwanie licencji z kontrolą wolnych sztuk, grupy (także pocztowe), **kopiowanie grup od użytkownika wzorcowego**, **błędy licencji grupowych** (z ponowieniem przypisania), **licencje do odzyskania** (konta zablokowane i nieaktywne).
- Teams: **zespoły** z właścicielami, gośćmi, archiwizacją i ostatnią aktywnością - zespoły bez właściciela, dodanie właściciela, archiwizacja i przywrócenie.
- Cykl życia: nowy użytkownik (licencja i grupy z wzorca), **masowe tworzenie kont z pliku CSV** (szablon, sprawdzenie pliku, licencje, grupy, przełożony), **offboarding w jednym kroku** (blokada, hasło, autoodpowiedź, przekierowanie, skrzynka współdzielona, GAL, MFA, **dostęp przełożonego do OneDrive**, grupy, przełożony, licencje; powiadomienie Teams), **OneDrive odchodzącego** (dostęp przełożonego z automatycznym odebraniem po N dniach, udostępnione pliki), **usunięci użytkownicy** (przywracanie z kosza katalogu).
- Raporty: **nieaktywni użytkownicy**, **goście**, **rejestracja MFA**, bez licencji, **role administracyjne**, **nieudane logowania** w organizacji.

### Bezpieczeństwo
- Entra ID: **zasady dostępu warunkowego** (z nazwami grup i ról, definicja JSON), **ryzykowni użytkownicy** (potwierdzenie przejęcia, odrzucenie ryzyka, wykrycia, blokada), **wykrycia ryzyka**, **dziennik inspekcji** (kto co zmienił, wartości przed i po), **role uprzywilejowane (PIM)** - aktywne i uprawnione.
- Aplikacje: **wygasające sekrety i certyfikaty** rejestracji aplikacji i aplikacji firmowych (SAML) z usuwaniem wygasłych sekretów, **zgody aplikacji** w tenancie (szerokie uprawnienia, niezweryfikowani wydawcy) z cofaniem.
- Defender: **alerty** i **incydenty** Microsoft Defender XDR (zmiana stanu, klasyfikacja, portal), **izolacja urządzeń** Defender for Endpoint (pełna / selektywna, zwolnienie, historia akcji) - wymaga aplikacji z uprawnieniami Machine.Read i Machine.Isolate (Ustawienia > Defender).
- Raporty: **administratorzy bez MFA, ze starym hasłem, synchronizowani z AD**.

### Exchange
- Skrzynka: szczegóły (widok «Pola» albo **«Skrzynki» - jedna skrzynka w wierszu**, dwuklik otwiera jej wszystkie szczegóły), **rozmiar i wykorzystanie limitu**, typ (Shared/Regular/Room/Equipment), GAL, archiwum, urządzenia mobilne (usuwanie powiązań). Skrzynki systemowe (eDiscovery - DiscoverySearchMailbox, skrzynki usług) i konto synchronizacji Entra Connect («On-Premises Directory Synchronization Service Account», `Sync_…`) są domyślnie ukryte na listach skrzynek i kont oraz w raportach - dziennik pokazuje, co ukryto (Ustawienia > Microsoft 365 i Exchange > «Pokazuj konta i skrzynki systemowe», klucz `ShowSystemMailboxes`).
- **Ustawienia skrzynki** - 65 ustawień w 9 sekcjach (okno z listą sekcji): nazwa, alias, biuro, porada pocztowa (MailTip), widoczność w GAL, **atrybuty niestandardowe 1-15**; **limity** (ostrzeżenie, zakaz wysyłania / odbierania, maks. rozmiar wiadomości, liczba odbiorców); **dostarczanie** (tylko nadawcy wewnętrzni, kto może pisać, kogo odrzucać, **kopie wysłanych «jako» / «w imieniu» w skrzynce współdzielonej**); **protokoły** (OWA, Outlook mobile, ActiveSync, MAPI, EWS, IMAP, POP, **SMTP AUTH**); **język, strefa czasowa i formaty** (z tłumaczeniem nazw folderów); **kalendarz** (godziny i dni pracy, początek tygodnia, przypomnienia); **Focused Inbox i wiadomości-śmieci** (listy zaufanych i zablokowanych); **retencja i inspekcja** (zasady MRM, odzyskiwanie elementów, wstrzymanie, dziennik inspekcji). Jedna skrzynka - bieżące wartości i zapis tylko różnic; wiele skrzynek - zmieniane są tylko wypełnione pola («-» czyści, «-wpis» usuwa z listy). Podgląd ustawień (jedna skrzynka - lista, wiele - tabela do porównania i eksportu), **kopiowanie ustawień ze skrzynki wzorcowej** (wybrane sekcje) i **masowa zmiana z pliku CSV** (szablon, opis kolumn, sprawdzenie pliku z podglądem zmian, zapis poprawnych wierszy).
- **Nowe skrzynki współdzielone, sale i zasoby** - pojedynczo albo wiele naraz («Nazwa; adres», adres z nazwy bez polskich znaków): pełny dostęp i «Wyślij jako» dla osób, AutoMapping, kopie wysłanych, ukrycie w GAL, pojemność, budynek, piętro, miasto i **lista sal** (także nowa lista sal).
- Uprawnienia: FullAccess / SendAs / SendOnBehalf, **do których skrzynek ma dostęp użytkownik**, kalendarz, **kto ma dostęp do skrzynki** (pełny raport z uprawnieniami do folderów) i **wyłączenie automapowania** w Outlooku. **Uprawnienia do folderów** skrzynki (np. Skrzynka odbiorcza\Faktury) z podfolderami i automatyczną widocznością folderów nadrzędnych (FolderVisible). **Kopiowanie dostępu (następca)**: cały dostęp pracownika do cudzych skrzynek, grup i kalendarzy jedną listą - nadanie zaznaczonych uprawnień następcy albo odebranie ich odchodzącemu.
- Sale i zasoby: **ustawienia rezerwacji** (automatyczne przyjmowanie, konflikty, okno rezerwacji, maks. czas, kto może rezerwować, delegaci, prywatność).
- Przepływ poczty: **reguły transportu** (włączanie / wyłączanie), **lista dozwolonych i zablokowanych** (nadawcy, domeny, adresy URL, pliki).
- Poczta: autoodpowiedź (także zaplanowana), przekierowanie, reguły skrzynki (wyłączanie / usuwanie), śledzenie wiadomości.
- Grupy i adresy: **aliasy** i **zmiana adresu głównego** (poprzedni zostaje aliasem); **grupy dystrybucyjne** - tworzenie (dystrybucyjne i zabezpieczeń z pocztą), **ustawienia grupy** w sekcjach (właściciele, dołączanie i opuszczanie, kto może pisać, wysyłanie w imieniu, raporty doręczeń, **moderowanie**), członkowie (także z wklejonej listy adresów), usuwanie grup; **grupy dynamiczne** (lista z filtrem, podgląd członków, nowa grupa z warunków - dział, firma, biuro, miasto, stanowisko, atrybuty; zmiana filtra OPATH); **kontakty zewnętrzne** (lista z firmą i telefonem, wiele naraz z wklejonej listy, edycja, ukrywanie w GAL, usuwanie).
- Zgodność: **kwarantanna** (podgląd, zwolnienie, zezwolenie nadawcy, usunięcie), **odzyskiwanie usuniętych elementów**, **Litigation Hold** i retencja usuniętych elementów.
- Raporty: **przekierowania poza organizację** (skrzynki i reguły), **nieaktywne skrzynki**, **skrzynki współdzielone a licencje** (zbędne licencje do 50 GB, brak wymaganej licencji powyżej 50 GB, archiwum, Litigation Hold), **kontrola konfiguracji organizacji** z oceną i poleceniem naprawy (nowoczesne uwierzytelnianie, inspekcja skrzynek i dziennik Purview, SMTP AUTH, automatyczne przekazywanie na zewnątrz, DKIM domen, oznaczenie «Zewnętrzny», porada o odbiorcach zewnętrznych, wyjątki filtrowania spamu).

### Intune
Szczegóły i sprzęt, aplikacje, grupy, użytkownik podstawowy, zmiana nazwy; akcje zdalne: synchronizacja, restart, **skanowanie i aktualizacja Microsoft Defender**, **zdalna blokada**, **rotacja kluczy BitLocker i hasła LAPS**, lokalizacja; **wycofanie, wipe i usunięcie z Intune**; **stan zasad zgodności i konfiguracji** (dlaczego urządzenie jest niezgodne); BitLocker i LAPS; raporty: niezgodne, **nieaktywne**, **bez szyfrowania**, **mało miejsca**, wersje systemów. **Autopilot**: urządzenia (group tag, usunięcie), profile, **import skrótów sprzętowych z CSV**. **Aplikacje i aktualizacje**: **błędy instalacji aplikacji** (urządzenia, kody błędów), **stan aktualizacji Windows** (wydanie, poziom poprawek na tle firmy, wsparcie) i pierścienie aktualizacji, **skrypty naprawcze na żądanie** z wynikami. **Porządki**: **duplikaty urządzeń** (ten sam numer seryjny) i **nieaktywne urządzenia Entra ID** (wyłączanie, usuwanie).

### Witryny (Microsoft Graph)
Przeglądanie wszystkich witryn SharePoint w organizacji bez Client ID PnP: wyszukiwanie, szczegóły, **biblioteki i zajęte miejsce**, **przeglądarka plików** (nawigacja po folderach, pobieranie, kopiowanie linków), listy, podwitryny, otwarcie w przeglądarce i szybkie połączenie PnP. **Udostępnienia i linki**: audyt linków anonimowych, organizacyjnych i udostępnień gościom w bibliotekach witryn (z usuwaniem). **Nieaktywne witryny i bez właściciela** (raport użycia).

### SharePoint (PnP)
Drzewo bibliotek i folderów połączonej witryny; uprawnienia (nadawanie wielu osobom naraz, **zmiana poziomu**, odbieranie, dziedziczenie); **uprawnienia całej witryny i administratorzy kolekcji** (nadawanie, odbieranie); **dostęp użytkownika** - gdzie w witrynie osoba ma dostęp (administrator, grupy SharePoint, witryna, biblioteki i foldery z unikalnymi uprawnieniami; bezpośrednio albo przez grupę) z odebraniem dostępu lub usunięciem z grupy; pliki w folderze (kopiowanie i przenoszenie); nowy folder; **kosz witryny** (przywracanie); grupy SharePoint (członkowie, **poziom uprawnień grupy do witryny**, ustawienia grupy - właściciel, widoczność członków, prośby o dołączenie - i usuwanie); **informacje o witrynie** (magazyn, administratorzy); **raport unikalnych uprawnień**; **stare wersje plików** (pliki z wieloma wersjami, miejsce zajęte przez wersje, usuwanie najstarszych, przycinanie w całej witrynie); **aplikacja PnP**: utworzenie rejestracji aplikacji (Client ID) jednym kliknięciem - przez Microsoft Graph (z opcjonalną zgodą administratora i kluczem tajnym) albo przez PnP PowerShell - oraz nowy klucz tajny (client secret) dla istniejącej aplikacji. Okno połączenia ma przyciski «Wybierz witrynę» i «Utwórz Client ID».

- **Struktura folderów (masowo)**: wiele folderów naraz z tekstu z wcięciami (Tab albo 4 spacje = folder podrzędny, `a/b/c` - kilka poziomów w jednej linii) - w każdej zaznaczonej bibliotece / folderze (np. ta sama struktura dla każdego klienta) albo w całej witrynie (pierwszy poziom - biblioteki, tworzone, gdy ich brak). **Uprawnienia w tej samej linii**: `Umowy | Zarząd=Pełna kontrola; jan@firma.pl=Odczyt` (przerwanie dziedziczenia z kopią), `Kadry |! @Właściciele=Pełna kontrola; kadry@firma.pl=Edycja` (bez kopii - tylko podane osoby), `-anna@firma.pl` (odebranie); grupy witryny `@Właściciele`, `@Członkowie`, `@Odwiedzający`, poziomy po nazwie albo skrócie (Full / Edit / Contribute / Read) - niezależnie od języka witryny. Istniejące foldery są pomijane, a uprawnienia z ich linii uzupełniane (masowe nadawanie uprawnień do istniejących folderów). **Odczyt struktury folderu wzorcowego** (z unikalnymi uprawnieniami), **podgląd** przed utworzeniem, **szablony** (wbudowane: projekt, klient, dział, miesiące roku, poufne, witryna działu; własne - zapis, import i eksport do pliku tekstowego).
- **Nowe biblioteki** (i listy) - wiele naraz: adres bez polskich znaków, menu witryny, historia wersji z limitem, wersje robocze, wymagane wyewidencjonowanie, zatwierdzanie, **kolumny** (`Klient: Tekst *`, `Status: Wybór [Nowy, W toku, Zamknięty]`, `Termin: Data`, `Opiekun: Osoba`…) i własne uprawnienia. **Ustawienia bibliotek** (także wielu naraz) i usuwanie do kosza; **kolumny bibliotek** (lista, dodawanie do wielu bibliotek, usuwanie).
- **Pliki**: **wyewidencjonowane pliki** («zablokowany do edycji przez…» - zaewidencjonowanie, odrzucenie, przejęcie plików bez wersji), **wyszukiwanie plików** po nazwie (także w dużych bibliotekach), **kopiowanie i przenoszenie** folderów i plików (także do innej witryny), **wysłanie folderu z dysku** z podfolderami (sprawdzenie nazw, pomijanie istniejących plików).
- **Nowa witryna**: zespołu (z grupą Microsoft 365), zespołu bez grupy albo komunikacyjna - nazwa, adres, właściciele, język, prywatność; od razu połączenie i zastosowanie szablonu struktury.

### Zadania
- **Zadania zaplanowane**: lista z terminami i wynikami, wykonanie teraz, zmiana terminu, anulowanie. Program wykonuje zaległe zadania co minutę, gdy jest uruchomiony i połączony z usługą.
- **Uprawnienia tymczasowe**: członkostwo w grupie albo dostęp do skrzynki (pełny dostęp, wyślij jako) do wskazanej daty - odebranie trafia do zadań zaplanowanych.
- **Zaplanowany offboarding** w wybranym terminie (np. ostatni dzień pracy o 17:00).
- **Checklisty on/offboardingu** z postępem i terminem: kroki ręczne i automatyczne (blokada, sesje, hasło, grupy, licencje, skrzynka, GAL), edytowalne szablony, powiadomienie Teams po ukończeniu.
- **Migawki i porównanie**: role administracyjne, dostęp warunkowy, członkowie grup, licencje, przekierowania skrzynek, sekrety aplikacji - co dodano, usunięto i zmieniono od migawki (albo między dwiema migawkami).
- **Cofanie zmian**: blokada konta, usunięcie licencji lub z grupy, przełożony, uprawnienia do skrzynek, reguły transportu, archiwizacja zespołu, urządzenia Entra ID, izolacja - jednym kliknięciem.
- **Historia obiektu**: wszystko, co program zrobił z kontem, skrzynką lub urządzeniem (dziennik z ostatnich dni, operacje sesji, rejestr zmian).
- **Raporty zaplanowane bez okna**: aplikacja automatyzacji z certyfikatem (tworzona jednym kliknięciem), `HelpdeskToolsRunner.ps1` i zadanie Harmonogramu Windows - raporty e-mailem (Excel), wykonywanie zadań zaplanowanych i migawki ze zmianami:

```powershell
pwsh -File .\HelpdeskToolsRunner.ps1 -ListReports
pwsh -File .\HelpdeskToolsRunner.ps1 -Report nieaktywni,sekrety-aplikacji,administratorzy -To helpdesk@firma.pl
pwsh -File .\HelpdeskToolsRunner.ps1 -RunJobs -Snapshot AdminRoles,ConditionalAccess -To bezpieczenstwo@firma.pl
```

### Active Directory (funkcje lokalne - domyślnie ukryte)
Włączenie: Ustawienia > Funkcje lokalne > «Pokazuj funkcje lokalne» i ponowne uruchomienie.
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
  "ConfirmBeforeClose": true,
  "ShowOnPremises": false,
  "BackgroundQueries": true,
  "NotifyLongOperationsSeconds": 20,
  "TeamsWebhookProtected": "",
  "TeamsNotify": [ "Offboarding", "Jobs", "Checklists" ],
  "TenantProfiles": [ { "Name": "Klient ABC", "TenantId": "abc.onmicrosoft.com", "Organization": "abc.onmicrosoft.com", "PartnerAccount": "admin@partner.pl", "Gdap": true, "SharePointUrl": "https://abc.sharepoint.com", "PnPClientId": "", "Services": [ "Graph", "Exchange" ], "Notes": "", "LastUsed": "" } ],
  "UpdateRepository": "borubarczyk/HelpdeskToolsProject_Scaffold",
  "UpdateBranch": "main",
  "UpdateTokenProtected": "",
  "CheckUpdatesOnStart": true,
  "AutomationClientId": "",
  "AutomationTenantId": "",
  "AutomationCertificateThumbprint": "",
  "AutomationOrganization": "",
  "ReportSender": "",
  "DefenderClientId": ""
}
```

Ustawienia można edytować w oknie **Ustawienia** (ikona koła zębatego) - sekcje po lewej stronie (Aplikacja, Bezpieczeństwo, Hasła, Microsoft 365 i Exchange, SharePoint, Teams i e-mail, Automatyzacja i Defender, Aktualizacje, Funkcje lokalne); przyciski akcji (zmiana PIN-u, MFA, profile tenantów, test webhooka, aktualizacja, skrót, podpisywanie skryptów) są w swoich sekcjach. Błąd w polu przełącza na sekcję z tym polem. `InactiveDays` - domyślny próg raportów nieaktywności, `AadSyncServer` - serwer Microsoft Entra Connect, `LoginTimeoutMinutes` - po ilu minutach oczekiwanie na logowanie w przeglądarce jest anulowane, `AutoLockMinutes` - automatyczna blokada po bezczynności (0 = wyłączona). Klucze `PinHash`/`PinSalt`/`PinLength` zawierają skrót PIN-u (PBKDF2), nie sam PIN. Konta MFA są w osobnym pliku `Mfa.json` (klucze, skróty PIN-ów kont dodatkowych i ich uprawnienia zaszyfrowane DPAPI); zarządza się nimi w Ustawieniach > «MFA». Po aktualizacji programu do konfiguracji są automatycznie dopisywane nowe uprawnienia Graph. Pełną listę domyślnych kluczy zawiera plik [`config.example.json`](config.example.json). `LogPasswordGeneration` zapisuje hasła w logu w postaci jawnej - pozostaw tę opcję wyłączoną. `ShowOnPremises` - przestrzenie i przycisk Active Directory; `BackgroundQueries` - zapytania Microsoft 365 w tle; `TeamsWebhookProtected` i `UpdateTokenProtected` - adres webhooka i token GitHub zaszyfrowane DPAPI (ustawiane w oknie Ustawienia); `Automation*` i `ReportSender` - aplikacja automatyzacji i skrzynka nadawcy raportów zaplanowanych; `DefenderClientId` - aplikacja do izolacji urządzeń. Uprawnienia Graph potrzebne nowym funkcjom (np. Policy.Read.All, Application.Read.All, SecurityAlert.ReadWrite.All) program proponuje dodać przy pierwszym użyciu funkcji.

## Struktura projektu

```
HelpdeskTools.ps1              Punkt wejścia: zmienne globalne, moduły, okno główne
Modules/
  Utils.psm1                   Dziennik, eksport, walidacja i formatowanie wartości
  Security.psm1                PIN programu (skrót PBKDF2)
  Mfa.psm1                     MFA: TOTP (RFC 6238), Base32, konta w Mfa.json (DPAPI), uprawnienia kont
  QrCode.psm1                  Kod QR (ISO/IEC 18004) bez zewnętrznych bibliotek - link otpauth:// przy włączaniu MFA
  TenantProfiles.psm1          Profile tenantów: normalizacja, walidacja, wyszukiwanie, scalanie, import i eksport CSV
  UiState.psm1                 Zapamiętany układ: ulubione, ostatnie moduły, kolumny, widoki filtrów, okno
  ColumnFilters.psm1           Filtry kolumn tabeli wyników (logika autofiltru)
  Reports.psm1                 Raporty HTML z tabel wyników, wizytówka użytkownika
  Excel.psm1                   Eksport do Excela (.xlsx, OpenXML bez Excela)
  Integrations.psm1            Teams (webhook), poczta przez Graph, aktualizacja z GitHub, podpisywanie skryptów, skrót
  Automation.psm1              Dziennik operacji sesji, zadania zaplanowane, checklisty, migawki, cofanie zmian,
                               raporty bez okna, aplikacja automatyzacji
  UIComponents.psm1            WPF: motyw Domain Ops, okna dialogowe, przestrzenie, listy obiektów, widok modułu,
                               filtry kolumn, ekran blokady (PIN, MFA), okna MFA i uprawnień
  Config.psm1                  Konfiguracja (domyślne wartości, scalanie, migracja, zapis)
  ModulesConnection.psm1       Instalacja i weryfikacja modułów, połączenia (logowanie w przeglądarce), wywołania Graph
  PasswordGenerator.psm1       Generator haseł i ocena siły hasła
  LocalActiveDirectory.psm1    Active Directory: konta, grupy, komputery, blokady, raporty, CIM
  GraphAPIM365Users.psm1       Użytkownicy, licencje, grupy, MFA, logowania, raporty, kondycja usług, masowe konta (CSV)
  GraphAPISecurity.psm1        Dostęp warunkowy, ryzyko, inspekcja, zgody, PIM, sekrety aplikacji, diagnoza logowania,
                               porównanie kont, Defender (alerty, incydenty, izolacja)
  GraphAPITeams.psm1           Zespoły Teams: właściciele, goście, archiwizacja, aktywność
  MailboxesExchangeOnline.psm1 Exchange Online: skrzynki, uprawnienia, kwarantanna, zgodność, raporty
  ExchangeSettings.psm1        Ustawienia skrzynek i grup (katalog atrybutów, różnice, plan zmian, CSV, wzorzec),
                               kontrola konfiguracji organizacji
  ExchangeRecipients.psm1      Nowe skrzynki współdzielone i sale, grupy dystrybucyjne i dynamiczne, kontakty,
                               uprawnienia do folderów, kopiowanie dostępu
  GraphAPIIntune.psm1          Intune: urządzenia, akcje zdalne, zasady, BitLocker, LAPS
  GraphAPISharePoint.psm1      SharePoint: PnP (uprawnienia, kosz, pliki, raport), witryny przez Graph, rejestracja aplikacji PnP
  SharePointAudit.psm1         Udostępnienia i linki, OneDrive odchodzącego, wersje plików, nieaktywne witryny
  SharePointStructure.psm1     Struktura folderów z uprawnieniami (składnia, szablony), biblioteki, kolumny, uprawnienia
                               witryny, dostęp użytkownika, wyewidencjonowane pliki, kopiowanie, wysyłanie, nowe witryny
  Dashboard.psm1               Statystyki Pulpitu
  Startup.psm1                 Inicjalizacja po zbudowaniu okna
GUI/
  MainWindow.ps1               Okno główne (nagłówek, połączenia, profile tenantów, dziennik, skróty)
  Dialogs.ps1                  Generator haseł, ustawienia
  Tools.ps1                    Aktualizacja, podpisywanie, skrót, profile tenantów, polecenia palety
  Common.ps1                   Wspólne pomocniki przestrzeni roboczych
  Workspaces/*.ps1             Przestrzenie robocze i ich moduły
HelpdeskToolsRunner.ps1        Raporty, zadania i migawki bez okna (Harmonogram Windows)
Plugins/                       Wtyczki (*.ps1) - przykład i opis
Resources/Icons/               Ikony
Tests/                         Testy Pester i test interfejsu (UiSmoke.ps1)
.github/workflows/tests.yml    CI: Pester, PSScriptAnalyzer i test interfejsu na Windows
```

Moduły w `Modules/` zawierają logikę (parametry wejściowe, zwracane dane), a pliki `GUI/Workspaces` opisują moduły interfejsu (parametry, przyciski, akcje na wynikach).

## Testy

Testy jednostkowe (Pester 5) obejmują logikę niezależną od interfejsu WPF (m.in. TOTP z wektorami RFC 6238, konta i uprawnienia MFA, filtry kolumn, raport HTML, eksport do Excela, odczyt dziennika, zadania zaplanowane, checklisty, porównanie migawek, cofanie zmian, ocenę zasad dostępu warunkowego, diagnozę logowania, audyt udostępnień, wersje Windows, masowe konta z CSV, ustawienia skrzynek - różnice, plan zmian i CSV, kontrolę konfiguracji Exchange, uprawnienia do folderów, składnię struktury folderów SharePoint, kolumny, poziomy uprawnień i szablony), z atrapami poleceń AD, Exchange i Graph. Test interfejsu (`Tests/UiSmoke.ps1`) buduje okno główne, wszystkie przestrzenie i moduły oraz paletę poleceń bez połączeń z usługami. GitHub Actions uruchamia oba na Windows przy każdym wypchnięciu, razem z PSScriptAnalyzer (`PSScriptAnalyzerSettings.psd1`):

```powershell
Install-Module Pester -MinimumVersion 5.5 -Scope CurrentUser
Invoke-Pester -Path .\Tests
pwsh -STA -File .\Tests\UiSmoke.ps1
Invoke-ScriptAnalyzer -Path . -Recurse -Settings .\PSScriptAnalyzerSettings.psd1
```

## Rozwiązywanie problemów

1. **Aplikacja nie uruchamia się** - sprawdź wersję PowerShell (`$PSVersionTable`), uruchomienie jako administrator i dziennik `%LOCALAPPDATA%\HelpdeskTools\Logs`.
2. **Błąd `Could not load file or assembly 'System.Text.Json, Version=10.0.0.0'`** (lub inna biblioteka z wyższą wersją) - zainstalowany moduł jest zbudowany pod nowszy .NET niż Twój PowerShell. Program wykrywa to przed połączeniem i proponuje: instalację zgodnej wersji modułu (automatycznie z PowerShell Gallery) albo aktualizację PowerShell (`winget upgrade --id Microsoft.PowerShell`). Stan: Pulpit > «Moduły i środowisko».
3. **Błąd `Could not load file or assembly Microsoft.Identity.Client`** - konflikt wersji bibliotek między modułami Graph i Exchange w jednej sesji. Program proponuje ponowne uruchomienie i połączenie najpierw z usługą, której moduł wymaga nowszej wersji. Sprawdzane są tylko biblioteki w domyślnym kontekście .NET - kopie ładowane przez moduły we własnym, izolowanym kontekście (np. MSAL modułu Exchange) nie są zgłaszane jako konflikt.
4. **Brak uprawnień (403) w Graph** - sprawdź role konta i zgodę administratora na uprawnienia z `GraphScopes`.
5. **SharePoint: błąd logowania PnP** - od 2024 r. PnP.PowerShell wymaga własnej rejestracji aplikacji w Entra ID. Utworzysz ją przyciskiem «Utwórz Client ID» w oknie połączenia (lub SharePoint > «Aplikacja PnP»). Do samego przeglądania witryn wystarczy przestrzeń «Witryny» (Microsoft Graph).
6. **Funkcje AD zgłaszają brak modułu** - brak modułu ActiveDirectory (RSAT) na tym komputerze; po instalacji kliknij «Active Directory» w nagłówku. Przestrzenie AD są domyślnie ukryte - Ustawienia > Funkcje lokalne.
7. **Logowanie Exchange otwiera osobne okno zamiast karty przeglądarki** - zaktualizuj moduł: `Update-Module ExchangeOnlineManagement` (wymagana wersja 3.7.2+). Gdy karta została zamknięta - kliknij «Anuluj logowanie» w okienku logowania (lub poczekaj na limit czasu) i połącz ponownie. Gdy anulowanie nie przerwie logowania (moduł Microsoft nadal czeka na odpowiedź przeglądarki), okienko pozwala spróbować ponownie albo zamknąć program - okno programu jest zablokowane do końca logowania.
8. **Brak danych w raportach logowań lub MFA** - wymagana licencja Microsoft Entra ID P1 i uprawnienie AuditLog.Read.All; kondycja usług wymaga ServiceHealth.Read.All (połącz ponownie, aby zatwierdzić nowe uprawnienia).
9. **Źródło blokady AD jest puste** - konto musi mieć prawo odczytu dziennika Security na kontrolerze PDC, a zasady audytu muszą rejestrować zdarzenie 4740.
10. **Kod z aplikacji MFA nie pasuje** - sprawdź, czy zegar telefonu i komputera wskazuje ten sam czas (tolerancja ±30 s). Komunikat «kod został już użyty» - poczekaj na następny kod (do 30 s). «Nie można odczytać danych MFA» - plik `Mfa.json` pochodzi z innego komputera lub konta Windows: usuń go i włącz MFA ponownie.
11. **Zapytania w tle zgłaszają brak połączenia** - program automatycznie wraca do wykonywania zapytań w wątku okna (wpis w dzienniku). Można to ustawić na stałe: Ustawienia > «Zapytania Microsoft 365 w tle».
12. **Izolacja urządzeń: błąd logowania Defender** - aplikacja z `DefenderClientId` musi mieć uprawnienia delegowane WindowsDefenderATP (Machine.Read, Machine.Isolate) ze zgodą administratora i platformę «Aplikacje mobilne i klasyczne» z adresem `http://localhost`.
13. **Raporty zaplanowane nie wychodzą** - sprawdź Zadania > Raporty zaplanowane > «Stan konfiguracji» (certyfikat w CurrentUser\My, skrzynka nadawcy) i dziennik `%LOCALAPPDATA%\HelpdeskTools\Logs`. Zadanie Harmonogramu działa, gdy użytkownik jest zalogowany (certyfikat i ustawienia są w jego profilu).
14. **«Dostawca plików w chmurze nie jest uruchomiony» przy łączeniu** - folder Dokumenty jest w OneDrive, a moduły PowerShell zainstalowane dla bieżącego użytkownika (`...\OneDrive\Documents\PowerShell\Modules`) są tylko w chmurze, gdy OneDrive nie działa albo nie jest zainstalowany. Program wykrywa to przy starcie i przy łączeniu: pomija ten folder i proponuje zainstalować brakujące moduły dla wszystkich użytkowników (`C:\Program Files\PowerShell\Modules`). Decyzja jest zapamiętana w ustawieniach (`SkippedModulePaths`) i stosowana ponownie po każdej instalacji modułu i przy kolejnych uruchomieniach (Install-Module i nowy proces PowerShell dopisują ten folder z powrotem). Po naprawie OneDrive: Ctrl+K > «Używaj modułów z OneDrive». Na stałe: usuń folder `Documents\PowerShell\Modules` w OneDrive albo uruchom OneDrive i oznacz go «Zawsze przechowuj na tym urządzeniu». Stan: Pulpit > «Moduły i środowisko». Eksporty, gdy folder Dokumenty w OneDrive nie przyjmuje zapisu, trafiają do `%LOCALAPPDATA%\HelpdeskTools\Eksport`, a skrót programu - na pulpit publiczny.
15. **SharePoint: «Host not reachable»** - adres witryny musi mieć postać `https://firma.sharepoint.com/sites/Dzial`. Domena tenantu (`firma.onmicrosoft.com`) nie jest adresem SharePoint - program zamienia ją automatycznie na `https://firma.sharepoint.com` (także w Ustawieniach).
16. **Błąd Microsoft Graph «BadRequest»** - komunikat zawiera teraz kod i opis błędu z odpowiedzi Graph (np. `invalidRequest: …`). Lista witryn korzysta z Microsoft Search API: zapytanie `sites?search=` nie działa przez `Invoke-MgGraphRequest`, bo moduł Microsoft Graph zamienia parametr `search` na `$search`.
17. **SharePoint: przeglądarka pokazuje «You are signed in now and can close this page», a program dalej czeka na logowanie** - moduł PnP czekał synchronicznie na kod, którego dalszy ciąg trafiał do zablokowanego wątku okna (zakleszczenie). Od wersji 3.7.0 logowanie i akcje modułów działają bez kontekstu synchronizacji okna, więc to się nie powtarza. W starszej wersji pomaga tylko «Zamknij program» w okienku logowania.

## Licencja

Copyright (c) 2025-2026 Borys Kaleta. **Wszelkie prawa zastrzeżone** - [licencja zastrzeżona](LICENSE).

Używanie, kopiowanie, modyfikowanie i rozpowszechnianie programu (w całości lub w części) wymaga uprzedniej zgody autora. Publiczna dostępność kodu nie oznacza zgody na korzystanie z niego.
