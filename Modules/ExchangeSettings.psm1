# Ustawienia skrzynek Exchange Online: katalog atrybutów (Set-Mailbox, Set-CASMailbox, ustawienia regionalne, kalendarz,
# Focused Inbox, wiadomości-śmieci, retencja i audyt), odczyt, porównanie z formularzem, plan zmian i jego wykonanie,
# masowe zmiany z pliku CSV, kopiowanie ustawień ze skrzynki wzorcowej oraz kontrola konfiguracji organizacji.
# Moduł nie zależy od interfejsu - pola formularza są zwykłymi hashtablami dla Show-HTFormDialog.

#region Katalog ustawień
$script:KeepText = '(bez zmian)'
$script:TriStateOptions = @('Ustawienie organizacji', 'Wyłączone', 'Włączone')

$script:MailboxSettingSections = [ordered]@{
    General   = @{ Title = 'Ogólne'; Icon = 'E77B'; Hint = 'Nazwa, alias, biuro, porada pocztowa (MailTip) i widoczność w książce adresowej. Skrzynek synchronizowanych z lokalnym AD nie da się tu zmienić (nazwa, alias, biuro) - zmiana w AD.' }
    Custom    = @{ Title = 'Atrybuty niestandardowe'; Icon = 'E8EC'; Hint = 'CustomAttribute1-15 - np. numer kadrowy, lokalizacja, centrum kosztów; używane w filtrach grup dynamicznych, regułach transportu i listach adresowych.' }
    Quota     = @{ Title = 'Limity i rozmiary'; Icon = 'EDA2'; Hint = 'Rozmiary z jednostką (np. 49 GB, 150 MB) albo Unlimited. Limity skrzynki nie mogą przekroczyć limitu licencji (np. 50 GB albo 100 GB); maks. rozmiar wiadomości - 150 MB.' }
    Delivery  = @{ Title = 'Dostarczanie'; Icon = 'E724'; Hint = 'Kto może pisać do skrzynki i gdzie trafiają kopie wiadomości wysłanych z niej przez delegatów.' }
    Protocols = @{ Title = 'Protokoły i aplikacje'; Icon = 'E8EA'; Hint = 'Dostęp do poczty z aplikacji i protokołów. Wyłączenie IMAP, POP i SMTP AUTH ogranicza ataki na hasła (starsze protokoły nie obsługują MFA).' }
    Regional  = @{ Title = 'Język i region'; Icon = 'E774'; Hint = 'Język skrzynki, strefa czasowa i formaty. Zmiana języka bez formatu daty i godziny ustawia formaty domyślne dla języka.' }
    Calendar  = @{ Title = 'Kalendarz'; Icon = 'E787'; Hint = 'Godziny i dni pracy (widoczne w Asystencie planowania), początek tygodnia i przypomnienia.' }
    Inbox     = @{ Title = 'Skrzynka odbiorcza'; Icon = 'E715'; Hint = 'Focused Inbox i ustawienia wiadomości-śmieci skrzynki (listy zaufanych i zablokowanych nadawców użytkownika).' }
    Retention = @{ Title = 'Retencja i audyt'; Icon = 'E72E'; Hint = 'Zasady przechowywania, odzyskiwanie usuniętych elementów i dziennik inspekcji skrzynki. Litigation Hold - moduł «Litigation Hold i retencja».' }
    # Grupy dystrybucyjne (Set-DistributionGroup)
    GroupGeneral    = @{ Title = 'Grupa'; Icon = 'E902'; Hint = 'Nazwa, adres, właściciele i widoczność grupy. Grupy synchronizowane z lokalnym AD zmienia się w AD.' }
    GroupMembership = @{ Title = 'Członkostwo'; Icon = 'E716'; Hint = 'Czy użytkownicy mogą sami dołączać i opuszczać grupę (Open - swobodnie, Closed - tylko właściciele, ApprovalRequired - za zgodą właściciela). Grupy zabezpieczeń: zawsze Closed.' }
    GroupDelivery   = @{ Title = 'Dostarczanie'; Icon = 'E724'; Hint = 'Kto może pisać do grupy, raporty doręczeń i wysyłanie w imieniu grupy.' }
    GroupModeration = @{ Title = 'Moderowanie'; Icon = 'E8FB'; Hint = 'Wiadomości do grupy czekają na zatwierdzenie moderatora (domyślnie - właściciela).' }
}

$script:MailboxSettingSourceNames = [ordered]@{
    Mailbox  = 'skrzynka'
    CAS      = 'protokoły'
    Regional = 'język i region'
    Calendar = 'kalendarz'
    Focused  = 'Focused Inbox'
    Junk     = 'wiadomości-śmieci'
    Group    = 'grupa'
}
# Parametry dodawane do polecenia zapisu (zmiana grupy przez administratora, który nie jest jej właścicielem)
$script:MailboxSettingWriterParams = @{ Group = @{ BypassSecurityGroupManagerCheck = $true } }
$script:MailboxSettingReaders = @{
    Group    = 'Get-DistributionGroup'
    Mailbox  = 'Get-Mailbox'
    CAS      = 'Get-CASMailbox'
    Regional = 'Get-MailboxRegionalConfiguration'
    Calendar = 'Get-MailboxCalendarConfiguration'
    Focused  = 'Get-FocusedInbox'
    Junk     = 'Get-MailboxJunkEmailConfiguration'
}
$script:MailboxSettingWriters = @{
    Group    = 'Set-DistributionGroup'
    Mailbox  = 'Set-Mailbox'
    CAS      = 'Set-CASMailbox'
    Regional = 'Set-MailboxRegionalConfiguration'
    Calendar = 'Set-MailboxCalendarConfiguration'
    Focused  = 'Set-FocusedInbox'
    Junk     = 'Set-MailboxJunkEmailConfiguration'
}

function New-HTMailboxSettingDef {
    <#
        Definicja ustawienia. -Type: Text, Bool (Tak/Nie), TriState (organizacja/wyłączone/włączone), Choice (-Options,
        -Editable - także inne wartości), Size (49 GB, Unlimited), Count (liczba albo Unlimited), Days, Minutes, Time (GG:MM),
        List (wiele wartości), Flag (jednorazowa akcja). -Param - parametr polecenia Set-*, -Read - właściwość obiektu Get-*.
    #>
    param (
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Section,
        [Parameter(Mandatory)][string]$Label,
        [string]$Source = 'Mailbox',
        [string]$Type = 'Text',
        [string]$Param = '',
        [string]$Read = '',
        [object[]]$Options = @(),
        [string]$OptionsFrom = '',
        [switch]$Editable,
        [string]$Hint = '',
        [string]$Example = '',
        [switch]$NoCopy,
        [switch]$Required,
        [switch]$NoClear,
        [int]$Min = 0,
        [int]$Max = 0,
        [int]$MaxLength = 0,
        [string]$Pattern = '',
        [string]$PatternText = ''
    )
    $p = if ($Param) { $Param } else { $Key }
    return @{
        Key = $Key; Section = $Section; Label = $Label; Source = $Source; Type = $Type; Param = $p
        Read = $(if ($Read) { $Read } else { $p }); Options = @($Options); OptionsFrom = $OptionsFrom; Editable = [bool]$Editable
        Hint = $Hint; Example = $Example; NoCopy = [bool]$NoCopy; Required = [bool]$Required; NoClear = [bool]$NoClear; Min = $Min; Max = $Max
        MaxLength = $MaxLength; Pattern = $Pattern; PatternText = $PatternText
    }
}

$script:LanguageOptions = @('pl-PL', 'en-US', 'en-GB', 'de-DE', 'uk-UA', 'cs-CZ', 'sk-SK', 'fr-FR', 'es-ES', 'it-IT', 'nl-NL', 'ru-RU')
$script:TimeZoneOptions = @('Central European Standard Time', 'W. Europe Standard Time', 'GMT Standard Time', 'FLE Standard Time', 'E. Europe Standard Time', 'UTC', 'Eastern Standard Time', 'Pacific Standard Time')

$script:MailboxSettingDefs = @(
    # Ogólne
    New-HTMailboxSettingDef -Key 'DisplayName' -Section 'General' -Label 'Nazwa wyświetlana' -NoCopy -Required -MaxLength 256
    New-HTMailboxSettingDef -Key 'Alias' -Section 'General' -Label 'Alias' -NoCopy -Required -MaxLength 64 -Pattern '^[A-Za-z0-9._\-]+$' -PatternText 'dozwolone litery bez polskich znaków, cyfry, kropka, myślnik i podkreślenie'
    New-HTMailboxSettingDef -Key 'Office' -Section 'General' -Label 'Biuro' -MaxLength 128 -Example 'Warszawa, ul. Prosta 1'
    New-HTMailboxSettingDef -Key 'MailTip' -Section 'General' -Label 'Porada pocztowa (MailTip)' -MaxLength 175 -Hint 'Komunikat w Outlooku przy pisaniu do skrzynki, np. «Skrzynka nieobsługiwana - pisz na biuro@firma.pl».'
    New-HTMailboxSettingDef -Key 'HiddenFromAddressListsEnabled' -Section 'General' -Label 'Ukryta w książce adresowej (GAL)' -Type 'Bool'
    # Atrybuty niestandardowe
    foreach ($i in 1..15) { New-HTMailboxSettingDef -Key "CustomAttribute$i" -Section 'Custom' -Label "Atrybut niestandardowy $i" -MaxLength 1024 }
    # Limity i rozmiary
    New-HTMailboxSettingDef -Key 'IssueWarningQuota' -Section 'Quota' -Label 'Ostrzeżenie o rozmiarze' -Type 'Size' -Example '48 GB'
    New-HTMailboxSettingDef -Key 'ProhibitSendQuota' -Section 'Quota' -Label 'Zakaz wysyłania od' -Type 'Size' -Example '49 GB'
    New-HTMailboxSettingDef -Key 'ProhibitSendReceiveQuota' -Section 'Quota' -Label 'Zakaz wysyłania i odbierania od' -Type 'Size' -Example '50 GB'
    New-HTMailboxSettingDef -Key 'ArchiveWarningQuota' -Section 'Quota' -Label 'Archiwum - ostrzeżenie' -Type 'Size' -Example '90 GB'
    New-HTMailboxSettingDef -Key 'ArchiveQuota' -Section 'Quota' -Label 'Archiwum - limit' -Type 'Size' -Example '100 GB'
    New-HTMailboxSettingDef -Key 'MaxSendSize' -Section 'Quota' -Label 'Maks. rozmiar wysyłanej wiadomości' -Type 'Size' -Example '35 MB'
    New-HTMailboxSettingDef -Key 'MaxReceiveSize' -Section 'Quota' -Label 'Maks. rozmiar odbieranej wiadomości' -Type 'Size' -Example '36 MB'
    New-HTMailboxSettingDef -Key 'RecipientLimits' -Section 'Quota' -Label 'Maks. liczba odbiorców wiadomości' -Type 'Count' -Max 1000 -Example '500'
    # Dostarczanie
    New-HTMailboxSettingDef -Key 'RequireSenderAuthenticationEnabled' -Section 'Delivery' -Label 'Przyjmuj tylko od nadawców z organizacji' -Type 'Bool'
    New-HTMailboxSettingDef -Key 'AcceptMessagesOnlyFromSendersOrMembers' -Section 'Delivery' -Label 'Przyjmuj tylko od (adresy i grupy)' -Type 'List' -Hint 'Pusta lista - od wszystkich.'
    New-HTMailboxSettingDef -Key 'RejectMessagesFromSendersOrMembers' -Section 'Delivery' -Label 'Odrzucaj wiadomości od (adresy i grupy)' -Type 'List'
    New-HTMailboxSettingDef -Key 'MessageCopyForSentAsEnabled' -Section 'Delivery' -Label 'Kopia wysłanych «jako» w elementach wysłanych tej skrzynki' -Type 'Bool' -Hint 'Dla skrzynek współdzielonych: wiadomość wysłana przez delegata (Wyślij jako) trafia także do «Elementów wysłanych» skrzynki.'
    New-HTMailboxSettingDef -Key 'MessageCopyForSendOnBehalfEnabled' -Section 'Delivery' -Label 'Kopia wysłanych «w imieniu» w elementach wysłanych tej skrzynki' -Type 'Bool'
    # Protokoły i aplikacje
    New-HTMailboxSettingDef -Key 'OWAEnabled' -Section 'Protocols' -Source 'CAS' -Label 'Outlook w przeglądarce (OWA)' -Type 'Bool'
    New-HTMailboxSettingDef -Key 'OWAforDevicesEnabled' -Section 'Protocols' -Source 'CAS' -Label 'OWA na urządzeniach mobilnych' -Type 'Bool'
    New-HTMailboxSettingDef -Key 'OutlookMobileEnabled' -Section 'Protocols' -Source 'CAS' -Label 'Outlook na iOS i Android' -Type 'Bool'
    New-HTMailboxSettingDef -Key 'ActiveSyncEnabled' -Section 'Protocols' -Source 'CAS' -Label 'Exchange ActiveSync (wbudowane aplikacje pocztowe)' -Type 'Bool'
    New-HTMailboxSettingDef -Key 'MAPIEnabled' -Section 'Protocols' -Source 'CAS' -Label 'Outlook klasyczny (MAPI)' -Type 'Bool'
    New-HTMailboxSettingDef -Key 'EwsEnabled' -Section 'Protocols' -Source 'CAS' -Label 'Exchange Web Services (EWS)' -Type 'Bool'
    New-HTMailboxSettingDef -Key 'ImapEnabled' -Section 'Protocols' -Source 'CAS' -Label 'IMAP' -Type 'Bool'
    New-HTMailboxSettingDef -Key 'PopEnabled' -Section 'Protocols' -Source 'CAS' -Label 'POP3' -Type 'Bool'
    New-HTMailboxSettingDef -Key 'SmtpClientAuthenticationDisabled' -Section 'Protocols' -Source 'CAS' -Label 'Uwierzytelnione SMTP (SMTP AUTH - drukarki, skanery, aplikacje)' -Type 'TriState' -Hint '«Ustawienie organizacji» - według Set-TransportConfig (zalecane wyłączenie w organizacji i włączenie tylko dla skrzynek urządzeń).'
    # Język i region
    New-HTMailboxSettingDef -Key 'Language' -Section 'Regional' -Source 'Regional' -Label 'Język skrzynki' -Type 'Choice' -Options $script:LanguageOptions -Editable -NoClear -Example 'pl-PL'
    New-HTMailboxSettingDef -Key 'TimeZone' -Section 'Regional' -Source 'Regional' -Label 'Strefa czasowa' -Type 'Choice' -OptionsFrom 'TimeZones' -Options $script:TimeZoneOptions -Editable -NoClear -Example 'Central European Standard Time'
    New-HTMailboxSettingDef -Key 'DateFormat' -Section 'Regional' -Source 'Regional' -Label 'Format daty' -Example 'dd.MM.yyyy' -Hint 'Musi być dozwolony dla języka (np. pl-PL: dd.MM.yyyy, yyyy-MM-dd).'
    New-HTMailboxSettingDef -Key 'TimeFormat' -Section 'Regional' -Source 'Regional' -Label 'Format godziny' -Example 'HH:mm'
    New-HTMailboxSettingDef -Key 'LocalizeDefaultFolderName' -Section 'Regional' -Source 'Regional' -Label 'Przetłumacz nazwy folderów domyślnych (Skrzynka odbiorcza, Elementy wysłane…) na język skrzynki' -Type 'Flag'
    # Kalendarz
    New-HTMailboxSettingDef -Key 'WorkingHoursStartTime' -Section 'Calendar' -Source 'Calendar' -Label 'Początek dnia pracy (GG:MM)' -Type 'Time' -Example '08:00'
    New-HTMailboxSettingDef -Key 'WorkingHoursEndTime' -Section 'Calendar' -Source 'Calendar' -Label 'Koniec dnia pracy (GG:MM)' -Type 'Time' -Example '16:00'
    New-HTMailboxSettingDef -Key 'WorkingHoursTimeZone' -Section 'Calendar' -Source 'Calendar' -Label 'Strefa czasowa godzin pracy' -Type 'Choice' -OptionsFrom 'TimeZones' -Options $script:TimeZoneOptions -Editable -NoClear
    New-HTMailboxSettingDef -Key 'WorkDays' -Section 'Calendar' -Source 'Calendar' -Label 'Dni pracy' -Type 'Choice' -Options @('Weekdays', 'AllDays', 'Monday, Tuesday, Wednesday, Thursday', 'Tuesday, Wednesday, Thursday, Friday') -Editable -NoClear -Hint 'Weekdays - pon.-pt., AllDays - wszystkie, albo dni po angielsku rozdzielone przecinkiem (Monday … Sunday).'
    New-HTMailboxSettingDef -Key 'WeekStartDay' -Section 'Calendar' -Source 'Calendar' -Label 'Pierwszy dzień tygodnia' -Type 'Choice' -Options @('Monday', 'Sunday', 'Saturday')
    New-HTMailboxSettingDef -Key 'ShowWeekNumbers' -Section 'Calendar' -Source 'Calendar' -Label 'Numery tygodni' -Type 'Bool'
    New-HTMailboxSettingDef -Key 'RemindersEnabled' -Section 'Calendar' -Source 'Calendar' -Label 'Przypomnienia o spotkaniach' -Type 'Bool'
    New-HTMailboxSettingDef -Key 'DefaultReminderTime' -Section 'Calendar' -Source 'Calendar' -Label 'Domyślne przypomnienie (minuty przed)' -Type 'Minutes' -Max 20160 -Example '15'
    # Skrzynka odbiorcza
    New-HTMailboxSettingDef -Key 'FocusedInboxOn' -Section 'Inbox' -Source 'Focused' -Label 'Priorytetowa skrzynka odbiorcza (Focused Inbox)' -Type 'Bool'
    New-HTMailboxSettingDef -Key 'JunkEmailEnabled' -Section 'Inbox' -Source 'Junk' -Param 'Enabled' -Label 'Filtr wiadomości-śmieci skrzynki' -Type 'Bool'
    New-HTMailboxSettingDef -Key 'ContactsTrusted' -Section 'Inbox' -Source 'Junk' -Label 'Ufaj nadawcom z kontaktów' -Type 'Bool'
    New-HTMailboxSettingDef -Key 'TrustedListsOnly' -Section 'Inbox' -Source 'Junk' -Label 'Przyjmuj tylko od zaufanych nadawców' -Type 'Bool'
    New-HTMailboxSettingDef -Key 'TrustedSendersAndDomains' -Section 'Inbox' -Source 'Junk' -Label 'Zaufani nadawcy i domeny' -Type 'List' -Hint 'Adresy (jan@firma.pl) albo domeny (firma.pl).'
    New-HTMailboxSettingDef -Key 'BlockedSendersAndDomains' -Section 'Inbox' -Source 'Junk' -Label 'Zablokowani nadawcy i domeny' -Type 'List'
    # Retencja i audyt
    New-HTMailboxSettingDef -Key 'RetentionPolicy' -Section 'Retention' -Label 'Zasady przechowywania (MRM)' -Type 'Choice' -OptionsFrom 'RetentionPolicies' -Editable -Example 'Default MRM Policy'
    New-HTMailboxSettingDef -Key 'RetainDeletedItemsFor' -Section 'Retention' -Label 'Przechowuj usunięte elementy (dni)' -Type 'Days' -Min 1 -Max 30 -Example '30'
    New-HTMailboxSettingDef -Key 'SingleItemRecoveryEnabled' -Section 'Retention' -Label 'Odzyskiwanie pojedynczych elementów' -Type 'Bool' -Hint 'Elementy usunięte trwale (także z kosza) można odzyskać przez czas przechowywania.'
    New-HTMailboxSettingDef -Key 'RetentionHoldEnabled' -Section 'Retention' -Label 'Wstrzymaj zasady przechowywania (np. na czas długiej nieobecności)' -Type 'Bool'
    New-HTMailboxSettingDef -Key 'AuditEnabled' -Section 'Retention' -Label 'Inspekcja skrzynki (dziennik operacji)' -Type 'Bool'
    New-HTMailboxSettingDef -Key 'AuditLogAgeLimit' -Section 'Retention' -Label 'Przechowuj wpisy inspekcji (dni)' -Type 'Days' -Min 1 -Max 3650 -Example '180'
)

$script:EmailPattern = '^[^@\s]+@[^@\s]+\.[^@\s]+$'
$script:GroupSettingDefs = @(
    New-HTMailboxSettingDef -Key 'DisplayName' -Section 'GroupGeneral' -Source 'Group' -Label 'Nazwa wyświetlana grupy' -NoCopy -Required -MaxLength 256
    New-HTMailboxSettingDef -Key 'PrimarySmtpAddress' -Section 'GroupGeneral' -Source 'Group' -Label 'Adres e-mail grupy' -NoCopy -Required -Pattern $script:EmailPattern -PatternText 'podaj adres e-mail' -Hint 'Poprzedni adres zostaje jako alias.'
    New-HTMailboxSettingDef -Key 'ManagedBy' -Section 'GroupGeneral' -Source 'Group' -Label 'Właściciele' -Type 'List' -Hint 'Grupa musi mieć co najmniej jednego właściciela.'
    New-HTMailboxSettingDef -Key 'MailTip' -Section 'GroupGeneral' -Source 'Group' -Label 'Porada pocztowa grupy (MailTip)' -MaxLength 175
    New-HTMailboxSettingDef -Key 'HiddenFromAddressListsEnabled' -Section 'GroupGeneral' -Source 'Group' -Label 'Grupa ukryta w książce adresowej' -Type 'Bool'
    New-HTMailboxSettingDef -Key 'MemberJoinRestriction' -Section 'GroupMembership' -Source 'Group' -Label 'Dołączanie do grupy' -Type 'Choice' -Options @('Closed', 'Open', 'ApprovalRequired')
    New-HTMailboxSettingDef -Key 'MemberDepartRestriction' -Section 'GroupMembership' -Source 'Group' -Label 'Opuszczanie grupy' -Type 'Choice' -Options @('Closed', 'Open')
    New-HTMailboxSettingDef -Key 'RequireSenderAuthenticationEnabled' -Section 'GroupDelivery' -Source 'Group' -Label 'Przyjmuj wiadomości tylko z organizacji' -Type 'Bool'
    New-HTMailboxSettingDef -Key 'AcceptMessagesOnlyFromSendersOrMembers' -Section 'GroupDelivery' -Source 'Group' -Label 'Do grupy mogą pisać tylko (adresy i grupy)' -Type 'List' -Hint 'Pusta lista - wszyscy (z ograniczeniem powyżej).'
    New-HTMailboxSettingDef -Key 'RejectMessagesFromSendersOrMembers' -Section 'GroupDelivery' -Source 'Group' -Label 'Odrzucaj wiadomości od' -Type 'List'
    New-HTMailboxSettingDef -Key 'GrantSendOnBehalfTo' -Section 'GroupDelivery' -Source 'Group' -Label 'Mogą wysyłać w imieniu grupy' -Type 'List'
    New-HTMailboxSettingDef -Key 'ReportToOriginatorEnabled' -Section 'GroupDelivery' -Source 'Group' -Label 'Raporty o niedoręczeniu do nadawcy' -Type 'Bool'
    New-HTMailboxSettingDef -Key 'SendOofMessageToOriginatorEnabled' -Section 'GroupDelivery' -Source 'Group' -Label 'Autoodpowiedzi członków do nadawcy' -Type 'Bool'
    New-HTMailboxSettingDef -Key 'ModerationEnabled' -Section 'GroupModeration' -Source 'Group' -Label 'Moderowanie wiadomości' -Type 'Bool'
    New-HTMailboxSettingDef -Key 'ModeratedBy' -Section 'GroupModeration' -Source 'Group' -Label 'Moderatorzy' -Type 'List' -Hint 'Puste - moderują właściciele.'
    New-HTMailboxSettingDef -Key 'BypassModerationFromSendersOrMembers' -Section 'GroupModeration' -Source 'Group' -Label 'Bez moderowania od (adresy i grupy)' -Type 'List'
    New-HTMailboxSettingDef -Key 'SendModerationNotifications' -Section 'GroupModeration' -Source 'Group' -Label 'Powiadomienia o odrzuceniu' -Type 'Choice' -Options @('Always', 'Internal', 'Never')
)

function Get-HTMailboxSettingDefinitions {
    param ([string[]]$Sections, [switch]$Group)
    $defs = if ($Group) { $script:GroupSettingDefs } else { $script:MailboxSettingDefs }
    if ($Sections) { return @($defs | Where-Object { $Sections -contains $_.Section }) }
    return @($defs)
}

function Get-HTMailboxSettingSections {
    # Sekcje: klucz -> @{ Title; Icon; Hint }
    return $script:MailboxSettingSections
}

function Get-HTSettingKeepText { return $script:KeepText }

function Get-HTTimeZoneOptions {
    # Strefy czasowe: najczęstsze na początku, potem wszystkie znane systemowi
    $all = @()
    try { $all = @([System.TimeZoneInfo]::GetSystemTimeZones() | ForEach-Object { $_.Id }) } catch { $all = @() }
    return @(@($script:TimeZoneOptions) + @($all | Sort-Object) | Select-Object -Unique)
}

function Get-HTRetentionPolicyNames {
    return @(Get-RetentionPolicy -ErrorAction Stop | ForEach-Object { [string]$_.Name } | Sort-Object)
}
#endregion

#region Wartości: odczyt, tekst formularza, wyświetlanie
function ConvertTo-HTTimeSpanValue {
    param ([AllowNull()][object]$Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [timespan]) { return $Value }
    $text = "$Value".Trim()
    if (-not $text) { return $null }
    $ts = [timespan]::Zero
    if ([timespan]::TryParse($text, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$ts)) { return $ts }
    return $null
}

function ConvertTo-HTMailboxSettingValue {
    # Wartość właściwości obiektu Exchange w postaci porównywalnej z formularzem
    param ([Parameter(Mandatory)][hashtable]$Definition, [AllowNull()][object]$Value)
    switch ($Definition.Type) {
        'Bool' {
            if ($Value -is [string]) { return ($Value -eq 'True') }
            return [bool]$Value
        }
        'TriState' {
            if ($null -eq $Value -or "$Value" -eq '') { return $script:TriStateOptions[0] }
            if ("$Value" -eq 'True') { return $script:TriStateOptions[1] }
            return $script:TriStateOptions[2]
        }
        'List' { return , @(@($Value) | Where-Object { $null -ne $_ } | ForEach-Object { "$_".Trim() } | Where-Object { $_ } | Sort-Object -Unique) }
        'Size' {
            $text = "$Value".Trim()
            if ($text -match '^(.*?)\s*\(') { $text = $Matches[1].Trim() }
            return $text
        }
        'Days' { $ts = ConvertTo-HTTimeSpanValue $Value; if ($ts) { return [string][int][Math]::Round($ts.TotalDays) }; return '' }
        'Minutes' { $ts = ConvertTo-HTTimeSpanValue $Value; if ($ts) { return [string][int][Math]::Round($ts.TotalMinutes) }; return '' }
        'Time' { $ts = ConvertTo-HTTimeSpanValue $Value; if ($ts) { return ('{0:D2}:{1:D2}' -f $ts.Hours, $ts.Minutes) }; return '' }
        default { if ($null -eq $Value) { return '' }; return "$Value".Trim() }
    }
}

function ConvertTo-HTMailboxSettingFormValue {
    # Wartość (z Get-HTMailboxSettings) jako tekst pola formularza
    param ([Parameter(Mandatory)][hashtable]$Definition, [AllowNull()][object]$Value)
    switch ($Definition.Type) {
        'Bool' { if ($Value) { return 'Tak' }; return 'Nie' }
        'List' { return (@($Value) -join "`r`n") }
        'Flag' { return [bool]$Value }
        default { return [string]$Value }
    }
}

function ConvertTo-HTMailboxSettingDisplay {
    # Wartość do raportu (Tak/Nie, lista po przecinku)
    param ([Parameter(Mandatory)][hashtable]$Definition, [AllowNull()][object]$Value)
    switch ($Definition.Type) {
        'Bool' { if ($Value) { return 'Tak' }; return 'Nie' }
        'List' { return (@($Value) -join ', ') }
        default { return [string]$Value }
    }
}

function ConvertFrom-HTMailboxSettingText {
    # Sprawdzenie i normalizacja tekstu wpisanego dla ustawienia: @{ Ok; Value; Error }
    param ([Parameter(Mandatory)][hashtable]$Definition, [AllowEmptyString()][AllowNull()][string]$Text)
    $d = $Definition
    $t = ([string]$Text).Trim()
    switch ($d.Type) {
        'Size' {
            if ($t -match '^(?i)(unlimited|bez limitu)$') { return @{ Ok = $true; Value = 'Unlimited' } }
            if ($t -match '^(?i)(\d+(?:[.,]\d+)?)\s*(B|KB|MB|GB|TB)$') { return @{ Ok = $true; Value = ('{0} {1}' -f ($Matches[1] -replace ',', '.'), $Matches[2].ToUpperInvariant()) } }
            return @{ Ok = $false; Error = 'podaj rozmiar z jednostką (np. 49 GB, 150 MB) albo Unlimited' }
        }
        'Count' {
            if ($t -match '^(?i)(unlimited|bez limitu)$') { return @{ Ok = $true; Value = 'Unlimited' } }
            $n = 0
            if (-not [int]::TryParse($t, [ref]$n) -or $n -lt 1) { return @{ Ok = $false; Error = 'podaj liczbę większą od zera albo Unlimited' } }
            if ($d.Max -gt 0 -and $n -gt $d.Max) { return @{ Ok = $false; Error = "maksymalna wartość to $($d.Max)" } }
            return @{ Ok = $true; Value = [string]$n }
        }
        { $_ -in 'Days', 'Minutes' } {
            $n = 0
            if (-not [int]::TryParse($t, [ref]$n)) { return @{ Ok = $false; Error = 'podaj liczbę całkowitą' } }
            if ($n -lt $d.Min) { return @{ Ok = $false; Error = "minimalna wartość to $($d.Min)" } }
            if ($d.Max -gt 0 -and $n -gt $d.Max) { return @{ Ok = $false; Error = "maksymalna wartość to $($d.Max)" } }
            return @{ Ok = $true; Value = [string]$n }
        }
        'Time' {
            if ($t -notmatch '^(\d{1,2}):(\d{2})$' -or [int]$Matches[1] -gt 23 -or [int]$Matches[2] -gt 59) { return @{ Ok = $false; Error = 'podaj godzinę w formacie GG:MM (np. 08:00)' } }
            return @{ Ok = $true; Value = ('{0:D2}:{1:D2}' -f [int]$Matches[1], [int]$Matches[2]) }
        }
        'Choice' {
            if (-not $d.Editable -and @($d.Options | Where-Object { [string]$_ -ieq $t }).Count -eq 0) { return @{ Ok = $false; Error = "dozwolone wartości: $(@($d.Options) -join ', ')" } }
            return @{ Ok = $true; Value = $t }
        }
        'TriState' {
            $option = @($script:TriStateOptions | Where-Object { $_ -ieq $t })[0]
            if (-not $option) { return @{ Ok = $false; Error = "dozwolone wartości: $($script:TriStateOptions -join ', ')" } }
            return @{ Ok = $true; Value = $option }
        }
        default {
            if ($d.MaxLength -gt 0 -and $t.Length -gt $d.MaxLength) { return @{ Ok = $false; Error = "maksymalnie $($d.MaxLength) znaków" } }
            if ($d.Pattern -and $t -notmatch $d.Pattern) { return @{ Ok = $false; Error = $(if ($d.PatternText) { $d.PatternText } else { 'nieprawidłowy format' }) } }
            return @{ Ok = $true; Value = $t }
        }
    }
}

function ConvertTo-HTTriStateValue {
    # Tekst opcji trójstanowej na wartość parametru: $null (organizacja), $true (wyłączone), $false (włączone)
    param ([string]$Option)
    if ($Option -eq $script:TriStateOptions[1]) { return $true }
    if ($Option -eq $script:TriStateOptions[2]) { return $false }
    return $null
}
#endregion

#region Formularz, zmiany i plan
function New-HTMailboxSettingField {
    # Pole formularza dla ustawienia: z bieżącą wartością (jedna skrzynka) albo «bez zmian» (wiele skrzynek / brak odczytu)
    param (
        [Parameter(Mandatory)][hashtable]$Definition,
        [System.Collections.IDictionary]$Current = $null,
        [hashtable]$Options = @{},
        [System.Collections.IDictionary]$Values = $null
    )
    $d = $Definition
    $keep = $script:KeepText
    $single = ($null -ne $Current) -and $Current.Contains($d.Key)
    $cur = if ($single) { $Current[$d.Key] } else { $null }
    $f = @{ Name = $d.Key; Label = $d.Label }
    $hint = $d.Hint
    switch ($d.Type) {
        'Bool' {
            $f.Type = 'Combo'
            $f.Options = if ($single) { @('Tak', 'Nie') } else { @($keep, 'Tak', 'Nie') }
            $f.Default = if ($single) { ConvertTo-HTMailboxSettingFormValue -Definition $d -Value $cur } else { $keep }
        }
        'TriState' {
            $f.Type = 'Combo'
            $f.Options = if ($single) { @($script:TriStateOptions) } else { @($keep) + @($script:TriStateOptions) }
            $f.Default = if ($single) { [string]$cur } else { $keep }
        }
        'Choice' {
            $opts = @($d.Options)
            if ($d.OptionsFrom -and $Options.ContainsKey($d.OptionsFrom) -and @($Options[$d.OptionsFrom]).Count) { $opts = @($Options[$d.OptionsFrom]) }
            $f.Type = 'Combo'
            $f.Editable = [bool]$d.Editable
            if ($d.Editable) {
                $f.Options = $opts
                $f.Default = if ($single) { [string]$cur } else { '' }
                if (-not $single) { $hint = (@($hint, 'Puste - bez zmian.') | Where-Object { $_ }) -join ' ' }
            }
            else {
                if ($single -and $cur -and @($opts | Where-Object { $_ -eq $cur }).Count -eq 0) { $opts = @($cur) + $opts }
                $f.Options = if ($single) { $opts } else { @($keep) + $opts }
                $f.Default = if ($single) { [string]$cur } else { $keep }
            }
        }
        'Flag' {
            $f.Type = 'Check'
            $f.Default = $false
        }
        'List' {
            $f.Type = 'Multiline'
            $f.Height = 64
            $f.Default = if ($single) { ConvertTo-HTMailboxSettingFormValue -Definition $d -Value $cur } else { '' }
            $mode = if ($single) { 'Jeden wpis w linii; usunięcie linii usuwa wpis.' } else { 'Jeden wpis w linii - dodaje; «-adres» usuwa; sam «-» czyści listę.' }
            $hint = (@($hint, $mode) | Where-Object { $_ }) -join ' '
        }
        default {
            $f.Type = 'Text'
            $f.Default = if ($single) { [string]$cur } else { '' }
            if (-not $single) {
                $f.Placeholder = $keep
                $clear = if ($d.Type -eq 'Text' -and -not $d.Required) { ' «-» czyści wartość.' } else { '' }
                $example = if ($d.Example) { " Np. $($d.Example)." } else { '' }
                $hint = (@($hint, "Puste - bez zmian.$clear$example") | Where-Object { $_ }) -join ' '
            }
            elseif ($d.Example) { $f.Placeholder = $d.Example }
        }
    }
    if ($Values -and $Values.Contains($d.Key)) { $f.Default = $Values[$d.Key] }
    if ($hint) { $f.Hint = $hint }
    return $f
}

function New-HTMailboxSettingsFormFields {
    <#
        Pola formularza (Show-HTFormDialog -Sections): nagłówek sekcji i pola ustawień. -Current - ustawienia jednej skrzynki
        (Get-HTMailboxSettings); bez niego pola mają wartość «bez zmian». -Values - wartości wpisane wcześniej (ponowne
        otwarcie po błędzie). -Options - listy wartości (TimeZones, RetentionPolicies).
    #>
    param (
        [System.Collections.IDictionary]$Current = $null,
        [string[]]$Sections,
        [hashtable]$Options = @{},
        [System.Collections.IDictionary]$Values = $null,
        [object[]]$Definitions = $script:MailboxSettingDefs
    )
    $fields = New-Object System.Collections.Generic.List[object]
    foreach ($key in $script:MailboxSettingSections.Keys) {
        if ($Sections -and $Sections -notcontains $key) { continue }
        $defs = @($Definitions | Where-Object { $_.Section -eq $key })
        if ($defs.Count -eq 0) { continue }
        $s = $script:MailboxSettingSections[$key]
        $fields.Add(@{ Type = 'Header'; Label = $s.Title; Icon = $s.Icon; Hint = $s.Hint })
        foreach ($d in $defs) { $fields.Add((New-HTMailboxSettingField -Definition $d -Current $Current -Options $Options -Values $Values)) }
    }
    return $fields.ToArray()
}

function Get-HTMailboxSettingChanges {
    <#
        Zmiany z formularza (słownik Klucz -> wartość pola). Dla ustawień obecnych w -Current (jedna skrzynka) zmianą jest
        różnica wobec bieżącej wartości (puste pole tekstowe czyści, lista jest zastępowana), dla pozostałych puste pole
        i «(bez zmian)» oznaczają brak zmiany, «-» czyści, a «-wpis» usuwa wpis z listy.
        Zwraca @{ Changes = @(@{ Key; Source; Param; Type; Label; Section; Value; Add; Remove; Display }); Errors = @() }.
    #>
    param (
        [Parameter(Mandatory)][System.Collections.IDictionary]$Form,
        [System.Collections.IDictionary]$Current = $null,
        [object[]]$Definitions = $script:MailboxSettingDefs
    )
    $keep = $script:KeepText
    $changes = New-Object System.Collections.Generic.List[object]
    $errors = New-Object System.Collections.Generic.List[string]
    foreach ($d in $Definitions) {
        if (-not $Form.Contains($d.Key)) { continue }
        $raw = $Form[$d.Key]
        $single = ($null -ne $Current) -and $Current.Contains($d.Key)
        $cur = if ($single) { $Current[$d.Key] } else { $null }
        $change = @{ Key = $d.Key; Source = $d.Source; Param = $d.Param; Type = $d.Type; Label = $d.Label; Section = $d.Section; Value = $null; Add = @(); Remove = @(); Display = '' }
        if ($d.Type -eq 'Flag') {
            if ($raw -ne $true) { continue }
            $change.Value = $true
            $change.Display = 'tak'
        }
        elseif ($d.Type -eq 'Bool') {
            $text = ([string]$raw).Trim()
            if (-not $text -or $text -eq $keep) { continue }
            if ($text -notin 'Tak', 'Nie') { $errors.Add("$($d.Label): dozwolone wartości Tak, Nie"); continue }
            $value = ($text -eq 'Tak')
            if ($single -and [bool]$cur -eq $value) { continue }
            $change.Value = $value
            $change.Display = $text
        }
        elseif ($d.Type -eq 'List') {
            $text = ([string]$raw).Trim()
            $lines = @(Split-HTInputList $text)
            if ($single) {
                $curList = @($cur | Where-Object { $_ })
                $add = @($lines | Where-Object { $x = $_; @($curList | Where-Object { $_ -ieq $x }).Count -eq 0 })
                $remove = @($curList | Where-Object { $x = $_; @($lines | Where-Object { $_ -ieq $x }).Count -eq 0 })
            }
            else {
                if ($text -eq '-') {
                    $change.Display = '(wyczyszczono)'
                    $changes.Add($change)
                    continue
                }
                $add = @($lines | Where-Object { $_ -notlike '-*' } | ForEach-Object { $_.TrimStart('+').Trim() } | Where-Object { $_ })
                $remove = @($lines | Where-Object { $_ -like '-*' } | ForEach-Object { $_.Substring(1).Trim() } | Where-Object { $_ })
            }
            if ($add.Count -eq 0 -and $remove.Count -eq 0) { continue }
            $change.Add = $add
            $change.Remove = $remove
            $change.Display = (@(@($add | ForEach-Object { "+$_" }) + @($remove | ForEach-Object { "-$_" })) -join ', ')
        }
        else {
            $text = ([string]$raw).Trim()
            if ($text -eq $keep) { continue }
            $clearable = ($d.Type -eq 'Text' -or ($d.Type -eq 'Choice' -and $d.Editable)) -and -not $d.Required -and -not $d.NoClear
            if ($text -eq '-' -or (-not $text -and $single)) {
                if (-not $text) {
                    # Puste pole jednej skrzynki czyści tylko wartości, które można wyczyścić; pozostałe - bez zmian
                    if ($d.Required) { if ("$cur") { $errors.Add("$($d.Label): pole wymagane") }; continue }
                    if (-not $clearable) { continue }
                }
                elseif (-not $clearable) { $errors.Add("$($d.Label): tej wartości nie można wyczyścić"); continue }
                if ($single -and -not "$cur") { continue }
                $change.Display = '(wyczyszczono)'
                $changes.Add($change)
                continue
            }
            if (-not $text) { continue }
            $parsed = ConvertFrom-HTMailboxSettingText -Definition $d -Text $text
            if (-not $parsed.Ok) { $errors.Add("$($d.Label): $($parsed.Error)"); continue }
            if ($single) {
                $same = if ($d.Type -eq 'Text') { [string]$cur -ceq [string]$parsed.Value } else { [string]$cur -eq [string]$parsed.Value }
                if ($same) { continue }
            }
            $change.Value = $parsed.Value
            $change.Display = [string]$parsed.Value
        }
        $changes.Add($change)
    }
    return @{ Changes = $changes.ToArray(); Errors = $errors.ToArray() }
}

function ConvertTo-HTMailboxSettingPlan {
    # Zmiany pogrupowane według polecenia: [ordered]@{ Mailbox = @{ Param = wartość }; CAS = …; Regional = … }
    param ([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Changes)
    $plan = [ordered]@{}
    foreach ($c in $Changes) {
        if (-not $plan.Contains($c.Source)) { $plan[$c.Source] = [ordered]@{} }
        $value = $c.Value
        switch ($c.Type) {
            'List' {
                $value = $null
                if (@($c.Add).Count -or @($c.Remove).Count) {
                    $value = @{}
                    if (@($c.Add).Count) { $value.Add = @($c.Add) }
                    if (@($c.Remove).Count) { $value.Remove = @($c.Remove) }
                }
            }
            'Bool' { $value = [bool]$c.Value }
            'TriState' { $value = ConvertTo-HTTriStateValue -Option ([string]$c.Value) }
            'Days' { $value = '{0}.00:00:00' -f [int]$c.Value }
            'Minutes' { $value = [timespan]::FromMinutes([int]$c.Value).ToString() }
            'Time' { $value = "$($c.Value):00" }
            'Flag' { $value = $true }
        }
        $plan[$c.Source][$c.Param] = $value
    }
    # Zmiana języka bez formatów - formaty domyślne dla języka (stary format bywa niedozwolony w nowym języku)
    if ($plan.Contains('Regional') -and $plan['Regional'].Contains('Language')) {
        if (-not $plan['Regional'].Contains('DateFormat')) { $plan['Regional']['DateFormat'] = $null }
        if (-not $plan['Regional'].Contains('TimeFormat')) { $plan['Regional']['TimeFormat'] = $null }
    }
    return $plan
}

function Invoke-HTMailboxSettingPlan {
    <#
        Wykonanie planu dla skrzynki: każde polecenie osobno (błąd jednego nie zatrzymuje pozostałych).
        Zwraca opis zapisanych zmian; gdy któreś polecenie się nie powiedzie - wyjątek z opisem (i tym, co zapisano).
    #>
    param ([Parameter(Mandatory)][string]$Identity, [Parameter(Mandatory)][System.Collections.IDictionary]$Plan)
    $done = New-Object System.Collections.Generic.List[string]
    $failed = New-Object System.Collections.Generic.List[string]
    foreach ($source in $script:MailboxSettingSourceNames.Keys) {
        if (-not $Plan.Contains($source) -or $Plan[$source].Count -eq 0) { continue }
        $params = @{ Identity = $Identity; ErrorAction = 'Stop' }
        foreach ($k in $Plan[$source].Keys) { $params[$k] = $Plan[$source][$k] }
        if ($source -ne 'Focused') { $params.Confirm = $false }
        if ($script:MailboxSettingWriterParams.ContainsKey($source)) { foreach ($k in $script:MailboxSettingWriterParams[$source].Keys) { $params[$k] = $script:MailboxSettingWriterParams[$source][$k] } }
        $name = $script:MailboxSettingSourceNames[$source]
        try {
            & $script:MailboxSettingWriters[$source] @params | Out-Null
            $done.Add("$name ($(@($Plan[$source].Keys) -join ', '))")
        }
        catch { $failed.Add("$($name): $($_.Exception.Message)") }
    }
    if ($failed.Count) {
        $saved = if ($done.Count) { " Zapisano: $($done -join '; ')." } else { '' }
        throw "Nie zapisano: $($failed -join '; ').$saved"
    }
    if ($done.Count -eq 0) { return 'Brak zmian' }
    return "Zmieniono: $($done -join '; ')"
}

function Get-HTMailboxSettings {
    <#
        Bieżące ustawienia skrzynki: Klucz -> wartość (jak w formularzu). Odczytywane są tylko źródła potrzebne dla
        -Sections. Błędy odczytu źródła (np. Focused Inbox skrzynki współdzielonej) - w __Errors; jego ustawienia
        nie pojawiają się w wyniku (formularz pokaże je jako «bez zmian»).
    #>
    param ([Parameter(Mandatory)][string]$Identity, [string[]]$Sections, [object[]]$Definitions = $script:MailboxSettingDefs)
    $defs = @($Definitions | Where-Object { $_.Type -ne 'Flag' -and (-not $Sections -or $Sections -contains $_.Section) })
    $objects = @{}
    $errors = New-Object System.Collections.Generic.List[string]
    foreach ($source in @($defs | ForEach-Object { $_.Source } | Select-Object -Unique)) {
        try { $objects[$source] = @(& $script:MailboxSettingReaders[$source] -Identity $Identity -ErrorAction Stop)[0] }
        catch { $errors.Add("$($script:MailboxSettingSourceNames[$source]): $($_.Exception.Message)") }
    }
    $result = [ordered]@{}
    foreach ($d in $defs) {
        if (-not $objects.ContainsKey($d.Source) -or $null -eq $objects[$d.Source]) { continue }
        $result[$d.Key] = ConvertTo-HTMailboxSettingValue -Definition $d -Value ($objects[$d.Source].($d.Read))
    }
    if ($objects['Mailbox']) {
        $result['__Type'] = "$($objects['Mailbox'].RecipientTypeDetails)"
        $result['__Name'] = "$($objects['Mailbox'].DisplayName)"
        $result['__DirSynced'] = [bool]$objects['Mailbox'].IsDirSynced
    }
    $result['__Errors'] = $errors.ToArray()
    return $result
}

function ConvertTo-HTMailboxSettingsRow {
    # Wiersz raportu ustawień skrzynki (kolumny - etykiety ustawień wybranych sekcji)
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Settings,
        [string[]]$Sections,
        [object[]]$Definitions = $script:MailboxSettingDefs
    )
    $row = [ordered]@{ Skrzynka = $Identity; Typ = [string]$Settings['__Type'] }
    foreach ($d in $Definitions) {
        if ($d.Type -eq 'Flag' -or ($Sections -and $Sections -notcontains $d.Section)) { continue }
        $row[$d.Label] = if ($Settings.Contains($d.Key)) { ConvertTo-HTMailboxSettingDisplay -Definition $d -Value $Settings[$d.Key] } else { '' }
    }
    $errs = @($Settings['__Errors'] | Where-Object { $_ })
    if ($errs.Count) { $row['Błędy odczytu'] = $errs -join '; '; $row['__flag'] = 'warn' }
    return [PSCustomObject]$row
}

function Get-HTMailboxSettingCopyForm {
    # Wartości formularza ze skrzynki wzorcowej - ustawienia kopiowalne (bez nazwy i aliasu) z wybranych sekcji
    param (
        [Parameter(Mandatory)][System.Collections.IDictionary]$Source,
        [string[]]$Sections,
        [object[]]$Definitions = $script:MailboxSettingDefs
    )
    $form = [ordered]@{}
    foreach ($d in $Definitions) {
        if ($d.NoCopy -or $d.Type -eq 'Flag') { continue }
        if ($Sections -and $Sections -notcontains $d.Section) { continue }
        if (-not $Source.Contains($d.Key)) { continue }
        $form[$d.Key] = ConvertTo-HTMailboxSettingFormValue -Definition $d -Value $Source[$d.Key]
    }
    return $form
}
#endregion

#region Masowe zmiany z pliku CSV
$script:CsvIdentityColumns = @('Skrzynka', 'Identity', 'PrimarySmtpAddress', 'Adres', 'Email', 'E-mail', 'Mailbox', 'UserPrincipalName', 'UPN')
$script:CsvTemplateExample = @{ Office = 'Warszawa'; CustomAttribute1 = '12345'; ProhibitSendQuota = '49 GB'; Language = 'pl-PL'; TimeZone = 'Central European Standard Time'; MessageCopyForSentAsEnabled = 'Tak' }

function Get-HTMailboxSettingsCsvTemplate {
    # Nagłówek i przykładowy wiersz szablonu CSV (separator ;); puste pole - bez zmian
    param ([string[]]$Keys)
    $defs = if ($Keys) { @($script:MailboxSettingDefs | Where-Object { $Keys -contains $_.Key }) } else { @($script:MailboxSettingDefs) }
    $row = [ordered]@{ Skrzynka = 'jan.kowalski@firma.pl' }
    foreach ($d in $defs) { $row[$d.Key] = if ($script:CsvTemplateExample.ContainsKey($d.Key)) { $script:CsvTemplateExample[$d.Key] } else { '' } }
    return ((@([PSCustomObject]$row | ConvertTo-Csv -Delimiter ';' -NoTypeInformation)) -join "`r`n")
}

function Get-HTMailboxSettingsCsvColumnHelp {
    # Opis kolumn szablonu CSV
    $types = @{
        Text = 'tekst; «-» czyści'; Bool = 'Tak / Nie'; TriState = ($script:TriStateOptions -join ' / '); Size = 'rozmiar z jednostką (49 GB) albo Unlimited'
        Count = 'liczba albo Unlimited'; Days = 'liczba dni'; Minutes = 'liczba minut'; Time = 'GG:MM'; List = 'wpisy po przecinku; «-wpis» usuwa, «-» czyści'
        Flag = 'Tak - wykonaj'; Choice = 'wartość z listy'
    }
    foreach ($d in $script:MailboxSettingDefs) {
        $values = $types[$d.Type]
        if ($d.Type -eq 'Choice' -and @($d.Options).Count) { $values = "$(if ($d.Editable) { 'np. ' })$(@($d.Options | Select-Object -First 4) -join ', ')" }
        [PSCustomObject]@{ Kolumna = $d.Key; Sekcja = $script:MailboxSettingSections[$d.Section].Title; Ustawienie = $d.Label; Wartości = $values; Przykład = $d.Example }
    }
}

function Get-HTMailboxSettingsCsvUnknownColumns {
    # Kolumny pliku, których program nie zna (literówki)
    param ([string[]]$Columns)
    $known = @($script:MailboxSettingDefs | ForEach-Object { $_.Key }) + $script:CsvIdentityColumns
    return @($Columns | Where-Object { $c = $_; @($known | Where-Object { $_ -ieq $c }).Count -eq 0 })
}

function ConvertFrom-HTYesNo {
    # Tak/Nie, True/False, 1/0 na $true/$false; inna wartość - $null
    param ([AllowEmptyString()][AllowNull()][string]$Text)
    $t = ([string]$Text).Trim().ToLowerInvariant()
    if ($t -in 'tak', 't', 'yes', 'y', 'true', '1', 'prawda', 'on', 'włącz', 'wlacz') { return $true }
    if ($t -in 'nie', 'n', 'no', 'false', '0', 'fałsz', 'falsz', 'off', 'wyłącz', 'wylacz') { return $false }
    return $null
}

function ConvertFrom-HTMailboxSettingsCsvRow {
    # Wiersz CSV -> @{ Identity; Changes; Errors; Valid }; puste pola - bez zmian
    param ([Parameter(Mandatory)][object]$Row, [object[]]$Definitions = $script:MailboxSettingDefs)
    $props = @($Row.PSObject.Properties)
    $idProp = @($props | Where-Object { $n = $_.Name; @($script:CsvIdentityColumns | Where-Object { $_ -ieq $n }).Count -gt 0 })[0]
    $identity = if ($idProp) { ([string]$idProp.Value).Trim() } else { '' }
    $errors = New-Object System.Collections.Generic.List[string]
    if (-not $identity) { $errors.Add('brak adresu skrzynki (kolumna Skrzynka)') }
    $form = [ordered]@{}
    foreach ($p in $props) {
        if ($idProp -and $p.Name -eq $idProp.Name) { continue }
        $name = $p.Name
        $d = @($Definitions | Where-Object { $_.Key -ieq $name })[0]
        if (-not $d) { continue }
        $v = ([string]$p.Value).Trim()
        if (-not $v) { continue }
        if ($d.Type -in 'Bool', 'Flag') {
            $b = ConvertFrom-HTYesNo $v
            if ($null -eq $b) { $errors.Add("$($d.Key): wpisz Tak albo Nie"); continue }
            $form[$d.Key] = if ($d.Type -eq 'Flag') { $b } elseif ($b) { 'Tak' } else { 'Nie' }
        }
        elseif ($d.Type -eq 'TriState') {
            $option = switch -Regex ($v) {
                '^(?i)(organizacja|ustawienie organizacji|domy[sś]lnie|default|null)$' { $script:TriStateOptions[0] }
                '^(?i)(wy[lł][aą]czone|disabled|true)$' { $script:TriStateOptions[1] }
                '^(?i)(w[lł][aą]czone|enabled|false)$' { $script:TriStateOptions[2] }
                default { $v }
            }
            $form[$d.Key] = $option
        }
        elseif ($d.Type -eq 'List') { $form[$d.Key] = if ($v -eq '-') { '-' } else { @(Split-HTInputList $v) -join "`r`n" } }
        else { $form[$d.Key] = $v }
    }
    $r = Get-HTMailboxSettingChanges -Form $form -Definitions $Definitions
    foreach ($e in $r.Errors) { $errors.Add($e) }
    if ($errors.Count -eq 0 -and @($r.Changes).Count -eq 0) { $errors.Add('brak zmian w wierszu') }
    return @{ Identity = $identity; Changes = @($r.Changes); Errors = $errors.ToArray(); Valid = ($errors.Count -eq 0) }
}
#endregion

#region Kontrola konfiguracji organizacji
function Get-HTExchangeConfigData {
    # Dane konfiguracji organizacji do kontroli (każde polecenie osobno - brak uprawnień do jednego nie przerywa)
    $data = @{}
    $commands = [ordered]@{
        Organization       = { Get-OrganizationConfig -ErrorAction Stop }
        Transport          = { Get-TransportConfig -ErrorAction Stop }
        AdminAudit         = { Get-AdminAuditLogConfig -ErrorAction Stop }
        RemoteDomains      = { Get-RemoteDomain -ErrorAction Stop }
        OutboundPolicies   = { Get-HostedOutboundSpamFilterPolicy -ErrorAction Stop }
        ConnectionPolicies = { Get-HostedConnectionFilterPolicy -ErrorAction Stop }
        ContentPolicies    = { Get-HostedContentFilterPolicy -ErrorAction Stop }
        Dkim               = { Get-DkimSigningConfig -ErrorAction Stop }
        AcceptedDomains    = { Get-AcceptedDomain -ErrorAction Stop }
        ExternalInOutlook  = { Get-ExternalInOutlook -ErrorAction Stop }
    }
    foreach ($name in $commands.Keys) {
        try { $data[$name] = @(& $commands[$name]) }
        catch {
            $data["$name.Error"] = $_.Exception.Message
            Write-Log -Message "Kontrola konfiguracji Exchange ($name): $($_.Exception.Message)" -Type 'Warn'
        }
    }
    return $data
}

function Get-HTExchangeConfigFindings {
    <#
        Ocena konfiguracji organizacji Exchange Online (dane z Get-HTExchangeConfigData): nowoczesne uwierzytelnianie,
        inspekcja, SMTP AUTH, automatyczne przekazywanie na zewnątrz, DKIM, oznaczanie nadawców zewnętrznych, porady
        pocztowe, wyjątki filtrowania spamu. Wiersze: Obszar, Kontrola, Wartość, Ocena, Zalecenie.
    #>
    param ([Parameter(Mandatory)][hashtable]$Data)
    $levels = @{ ok = 'OK'; warn = 'Uwaga'; crit = 'Ryzyko'; info = 'Informacja'; skip = 'Nie sprawdzono' }
    $flags = @{ ok = ''; warn = 'warn'; crit = 'crit'; info = ''; skip = 'muted' }
    $rows = New-Object System.Collections.Generic.List[object]
    $add = {
        param([string]$Area, [string]$Check, [object]$Value, [string]$Level, [string]$Advice = '')
        $rows.Add([PSCustomObject]@{ Obszar = $Area; Kontrola = $Check; Wartość = [string]$Value; Ocena = $levels[$Level]; Zalecenie = $Advice; __flag = $flags[$Level] })
    }
    $first = { param($name) if ($Data.ContainsKey($name)) { @($Data[$name])[0] } else { $null } }
    $missing = { param($name, $area, $check) & $add $area $check '' 'skip' $(if ($Data["$name.Error"]) { "Błąd odczytu: $($Data["$name.Error"])" } else { 'Brak danych' }) }

    $org = & $first 'Organization'
    if ($org) {
        if ($org.OAuth2ClientProfileEnabled) { & $add 'Uwierzytelnianie' 'Nowoczesne uwierzytelnianie (OAuth) w Outlooku' 'włączone' 'ok' }
        else { & $add 'Uwierzytelnianie' 'Nowoczesne uwierzytelnianie (OAuth) w Outlooku' 'wyłączone' 'crit' 'Set-OrganizationConfig -OAuth2ClientProfileEnabled $true' }
        if ($org.AuditDisabled) { & $add 'Inspekcja' 'Inspekcja skrzynek (domyślnie dla wszystkich)' 'wyłączona' 'crit' 'Set-OrganizationConfig -AuditDisabled $false' }
        else { & $add 'Inspekcja' 'Inspekcja skrzynek (domyślnie dla wszystkich)' 'włączona' 'ok' }
        if ($org.MailTipsExternalRecipientsTipsEnabled) { & $add 'Bezpieczeństwo poczty' 'Porada pocztowa o odbiorcach zewnętrznych' 'włączona' 'ok' }
        else { & $add 'Bezpieczeństwo poczty' 'Porada pocztowa o odbiorcach zewnętrznych' 'wyłączona' 'warn' 'Set-OrganizationConfig -MailTipsExternalRecipientsTipsEnabled $true - ostrzeżenie przed wysłaniem poza organizację' }
        & $add 'Organizacja' 'Focused Inbox (domyślnie)' $(if ($org.FocusedInboxOn -eq $false) { 'wyłączona' } else { 'włączona' }) 'info'
        & $add 'Organizacja' 'Wysyłanie z aliasów' $(if ($org.SendFromAliasEnabled) { 'włączone' } else { 'wyłączone' }) 'info'
        & $add 'Organizacja' 'Archiwum automatycznie rozszerzane (organizacja)' $(if ($org.AutoExpandingArchiveEnabled) { 'włączone' } else { 'wyłączone' }) 'info'
    }
    else { & $missing 'Organization' 'Organizacja' 'Konfiguracja organizacji' }

    $audit = & $first 'AdminAudit'
    if ($audit) {
        if ($audit.UnifiedAuditLogIngestionEnabled) { & $add 'Inspekcja' 'Ujednolicony dziennik inspekcji (Purview)' 'włączony' 'ok' }
        else { & $add 'Inspekcja' 'Ujednolicony dziennik inspekcji (Purview)' 'wyłączony' 'crit' 'Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true - bez niego nie zbadasz incydentu' }
    }
    else { & $missing 'AdminAudit' 'Inspekcja' 'Ujednolicony dziennik inspekcji' }

    $transport = & $first 'Transport'
    if ($transport) {
        if ($transport.SmtpClientAuthenticationDisabled) { & $add 'Uwierzytelnianie' 'SMTP AUTH w organizacji' 'wyłączone' 'ok' 'Urządzeniom i aplikacjom włączaj SMTP AUTH pojedynczo (Ustawienia skrzynki > Protokoły i aplikacje).' }
        else { & $add 'Uwierzytelnianie' 'SMTP AUTH w organizacji' 'włączone' 'warn' 'Set-TransportConfig -SmtpClientAuthenticationDisabled $true i włączenie tylko dla skrzynek urządzeń - protokół bez MFA' }
        $sendSize = ([string]$transport.MaxSendSize) -replace '\s*\(.*$', ''
        $receiveSize = ([string]$transport.MaxReceiveSize) -replace '\s*\(.*$', ''
        & $add 'Organizacja' 'Maks. rozmiar wiadomości (wysyłanie / odbieranie)' "$sendSize / $receiveSize" 'info'
    }
    else { & $missing 'Transport' 'Uwierzytelnianie' 'SMTP AUTH w organizacji' }

    $outbound = @($Data['OutboundPolicies'] | Where-Object { $_ })
    $forwardOn = $false
    if ($outbound.Count) {
        foreach ($p in $outbound) {
            $mode = [string]$p.AutoForwardingMode
            if ($mode -eq 'On') { $forwardOn = $true; & $add 'Przekazywanie poczty' "Automatyczne przekazywanie na zewnątrz - zasady «$($p.Name)»" 'dozwolone (On)' 'crit' 'Ustaw AutoForwardingMode Off (lub Automatic) i dopuszczaj przekazywanie tylko wybranym skrzynkom osobnymi zasadami' }
            else { & $add 'Przekazywanie poczty' "Automatyczne przekazywanie na zewnątrz - zasady «$($p.Name)»" $(if ($mode) { $mode } else { 'Automatic' }) 'ok' }
        }
    }
    else { & $missing 'OutboundPolicies' 'Przekazywanie poczty' 'Zasady ruchu wychodzącego' }
    $default = @($Data['RemoteDomains'] | Where-Object { $_ -and ([string]$_.DomainName -eq '*' -or [string]$_.Name -eq 'Default') })[0]
    if ($default) {
        $level = if ($default.AutoForwardEnabled -and $forwardOn) { 'warn' } else { 'info' }
        & $add 'Przekazywanie poczty' 'Domena zdalna «Default»: automatyczne przekazywanie' $(if ($default.AutoForwardEnabled) { 'dozwolone' } else { 'zablokowane' }) $level $(if ($level -eq 'warn') { 'Set-RemoteDomain Default -AutoForwardEnabled $false' } else { '' })
        & $add 'Przekazywanie poczty' 'Domena zdalna «Default»: autoodpowiedzi na zewnątrz' $(if ($default.AllowedOOFType) { [string]$default.AllowedOOFType } else { '' }) 'info'
    }

    $domains = @($Data['AcceptedDomains'] | Where-Object { $_ -and [string]$_.DomainType -ne 'ExternalRelay' })
    if ($Data.ContainsKey('Dkim')) {
        foreach ($dom in $domains) {
            $name = [string]$dom.DomainName
            if ($name -match '\.mail\.onmicrosoft\.com$') { continue }
            $cfg = @($Data['Dkim'] | Where-Object { $_ -and [string]$_.Domain -ieq $name })[0]
            if (-not $cfg) { & $add 'DKIM' "Podpis DKIM - $name" 'brak konfiguracji' 'warn' "New-DkimSigningConfig -DomainName $name -Enabled `$true (najpierw rekordy CNAME selector1/selector2 w DNS)" }
            elseif (-not $cfg.Enabled) { & $add 'DKIM' "Podpis DKIM - $name" 'wyłączony' 'warn' "Set-DkimSigningConfig -Identity $name -Enabled `$true (po dodaniu rekordów CNAME w DNS)" }
            else { & $add 'DKIM' "Podpis DKIM - $name" 'włączony' 'ok' }
        }
    }
    else { & $missing 'Dkim' 'DKIM' 'Podpis DKIM domen' }

    $external = & $first 'ExternalInOutlook'
    if ($external) {
        if ($external.Enabled) { & $add 'Bezpieczeństwo poczty' 'Oznaczenie «Zewnętrzny» przy nadawcach spoza organizacji' 'włączone' 'ok' }
        else { & $add 'Bezpieczeństwo poczty' 'Oznaczenie «Zewnętrzny» przy nadawcach spoza organizacji' 'wyłączone' 'warn' 'Set-ExternalInOutlook -Enabled $true - pomaga rozpoznać phishing podszywający się pod współpracowników' }
    }
    else { & $missing 'ExternalInOutlook' 'Bezpieczeństwo poczty' 'Oznaczenie nadawców zewnętrznych' }

    foreach ($p in @($Data['ConnectionPolicies'] | Where-Object { $_ })) {
        $ips = @($p.IPAllowList | Where-Object { $_ })
        if ($ips.Count) { & $add 'Filtrowanie spamu' "Dozwolone adresy IP - zasady «$($p.Name)»" "$($ips.Count): $(@($ips | Select-Object -First 5) -join ', ')" 'warn' 'Poczta z tych adresów omija filtrowanie spamu - zostaw tylko niezbędne' }
        else { & $add 'Filtrowanie spamu' "Dozwolone adresy IP - zasady «$($p.Name)»" 'brak' 'ok' }
    }
    foreach ($p in @($Data['ContentPolicies'] | Where-Object { $_ })) {
        $doms = @($p.AllowedSenderDomains | Where-Object { $_ } | ForEach-Object { [string]$_ })
        $senders = @($p.AllowedSenders | Where-Object { $_ } | ForEach-Object { [string]$_ })
        if ($doms.Count -or $senders.Count) {
            & $add 'Filtrowanie spamu' "Dozwoleni nadawcy i domeny - zasady «$($p.Name)»" "domen: $($doms.Count), nadawców: $($senders.Count) ($(@(@($doms) + @($senders) | Select-Object -First 5) -join ', '))" 'warn' 'Wiadomości od nich omijają filtrowanie (także podszyte) - zamiast tego lista dozwolonych z wygaśnięciem'
        }
        else { & $add 'Filtrowanie spamu' "Dozwoleni nadawcy i domeny - zasady «$($p.Name)»" 'brak' 'ok' }
    }
    if ($domains.Count) {
        $defaultDomain = @($domains | Where-Object { $_.Default })[0]
        & $add 'Organizacja' 'Domeny akceptowane' "$($domains.Count) (domyślna: $(if ($defaultDomain) { $defaultDomain.DomainName } else { '?' }))" 'info'
    }
    return $rows.ToArray()
}
#endregion
