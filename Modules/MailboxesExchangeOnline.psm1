# Skrzynki pocztowe Exchange Online (moduł ExchangeOnlineManagement v3)

# Lista skrzynek
function Get-HTMailboxes {
    param ([string[]]$RecipientTypeDetails)
    $params = @{
        ResultSize  = "Unlimited"
        Properties  = @("HiddenFromAddressListsEnabled", "ArchiveStatus", "ForwardingSmtpAddress", "ForwardingAddress", "WhenCreated")
        ErrorAction = "Stop"
    }
    if ($RecipientTypeDetails) { $params.RecipientTypeDetails = $RecipientTypeDetails }

    return @(Get-EXOMailbox @params | ForEach-Object {
            [PSCustomObject]@{
                Identity             = "$($_.PrimarySmtpAddress)"
                ObjectId             = $_.ExternalDirectoryObjectId
                DisplayName          = $_.DisplayName
                PrimarySmtpAddress   = "$($_.PrimarySmtpAddress)"
                UserPrincipalName    = $_.UserPrincipalName
                RecipientTypeDetails = "$($_.RecipientTypeDetails)"
                HiddenFromGAL        = [bool]$_.HiddenFromAddressListsEnabled
                Archive              = ("$($_.ArchiveStatus)" -eq "Active")
                Forwarding           = if ($_.ForwardingSmtpAddress) { "$($_.ForwardingSmtpAddress)" -replace '^smtp:', '' } elseif ($_.ForwardingAddress) { "$($_.ForwardingAddress)" } else { "" }
                WhenCreated          = $_.WhenCreated
            }
        } | Sort-Object DisplayName)
}

# Szczegóły skrzynki
function Get-HTMailboxDetail {
    param ([Parameter(Mandatory)][string]$Identity)

    $mbx = Get-EXOMailbox -Identity $Identity -PropertySets All -ErrorAction Stop
    $stats = $null
    try { $stats = Get-EXOMailboxStatistics -Identity $Identity -Properties LastLogonTime -ErrorAction Stop } catch { }
    $archiveStats = $null
    if ("$($mbx.ArchiveStatus)" -eq "Active") {
        try { $archiveStats = Get-EXOMailboxStatistics -Identity $Identity -Archive -ErrorAction Stop } catch { }
    }
    $autoReply = $null
    try { $autoReply = Get-MailboxAutoReplyConfiguration -Identity $Identity -ErrorAction Stop } catch { }

    $forward = if ($mbx.ForwardingSmtpAddress) { "$($mbx.ForwardingSmtpAddress)" -replace '^smtp:', '' } elseif ($mbx.ForwardingAddress) { "$($mbx.ForwardingAddress)" } else { "(brak)" }

    return [ordered]@{
        "Nazwa wyświetlana"   = $mbx.DisplayName
        "Adres główny"        = "$($mbx.PrimarySmtpAddress)"
        "UPN"                 = $mbx.UserPrincipalName
        "Typ skrzynki"        = "$($mbx.RecipientTypeDetails)"
        "Ukryta w GAL"        = [bool]$mbx.HiddenFromAddressListsEnabled
        "Utworzono"           = $mbx.WhenCreated
        "Rozmiar i limity"    = [ordered]@{
            "Rozmiar"                    = if ($stats) { "$($stats.TotalItemSize)" } else { "" }
            "Liczba elementów"           = if ($stats) { $stats.ItemCount } else { "" }
            "Ostatnie logowanie"         = if ($stats) { $stats.LastLogonTime } else { "" }
            "Limit (zakaz wysyłania)"    = "$($mbx.ProhibitSendQuota)"
            "Limit (ostrzeżenie)"        = "$($mbx.IssueWarningQuota)"
            "Archiwum"                   = "$($mbx.ArchiveStatus)"
            "Rozmiar archiwum"           = if ($archiveStats) { "$($archiveStats.TotalItemSize)" } else { "" }
            "Litigation Hold"            = [bool]$mbx.LitigationHoldEnabled
            "Retencja elementów usuniętych" = "$($mbx.RetainDeletedItemsFor)"
        }
        "Przekierowanie"      = [ordered]@{
            "Przekieruj do"          = $forward
            "Zachowaj kopię"         = [bool]$mbx.DeliverToMailboxAndForward
        }
        "Autoodpowiedź"       = [ordered]@{
            "Stan"          = if ($autoReply) { "$($autoReply.AutoReplyState)" } else { "" }
            "Od"            = if ($autoReply -and "$($autoReply.AutoReplyState)" -eq "Scheduled") { $autoReply.StartTime } else { "" }
            "Do"            = if ($autoReply -and "$($autoReply.AutoReplyState)" -eq "Scheduled") { $autoReply.EndTime } else { "" }
            "Odbiorcy zewn." = if ($autoReply) { "$($autoReply.ExternalAudience)" } else { "" }
        }
        "Adresy ($(@($mbx.EmailAddresses).Count))" = [ordered]@{
            "Aliasy" = @($mbx.EmailAddresses | ForEach-Object { "$_" } | Sort-Object)
        }
        "Wysyłanie w imieniu" = [ordered]@{
            "Użytkownicy" = @($mbx.GrantSendOnBehalfTo | ForEach-Object { "$_" })
        }
    }
}

# Uprawnienia do skrzynki (FullAccess, SendAs, SendOnBehalf)
function Get-HTMailboxPermissions {
    param ([Parameter(Mandatory)][string]$Identity)

    $rows = New-Object System.Collections.Generic.List[object]

    foreach ($p in (Get-EXOMailboxPermission -Identity $Identity -ErrorAction Stop)) {
        if ($p.IsInherited -or "$($p.User)" -match '^NT AUTHORITY\\|^S-1-5-') { continue }
        $rows.Add([PSCustomObject]@{
                Type        = "FullAccess"
                User        = "$($p.User)"
                AccessRights = ($p.AccessRights -join ", ")
            })
    }

    foreach ($p in (Get-EXORecipientPermission -Identity $Identity -ErrorAction Stop)) {
        if ($p.IsInherited -or "$($p.Trustee)" -match '^NT AUTHORITY\\|^S-1-5-') { continue }
        $rows.Add([PSCustomObject]@{
                Type        = "SendAs"
                User        = "$($p.Trustee)"
                AccessRights = ($p.AccessRights -join ", ")
            })
    }

    $mbx = Get-EXOMailbox -Identity $Identity -Properties GrantSendOnBehalfTo -ErrorAction Stop
    foreach ($user in @($mbx.GrantSendOnBehalfTo)) {
        if (-not $user) { continue }
        $rows.Add([PSCustomObject]@{
                Type        = "SendOnBehalf"
                User        = "$user"
                AccessRights = "SendOnBehalf"
            })
    }

    return $rows.ToArray()
}

# Nadanie uprawnień
function Add-HTMailboxPermission {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][string]$User,
        [Parameter(Mandatory)][ValidateSet("FullAccess", "SendAs", "SendOnBehalf")][string[]]$Type,
        [bool]$AutoMapping = $true
    )
    foreach ($t in $Type) {
        switch ($t) {
            "FullAccess" { Add-MailboxPermission -Identity $Identity -User $User -AccessRights FullAccess -InheritanceType All -AutoMapping $AutoMapping -Confirm:$false -ErrorAction Stop | Out-Null }
            "SendAs" { Add-RecipientPermission -Identity $Identity -Trustee $User -AccessRights SendAs -Confirm:$false -ErrorAction Stop | Out-Null }
            "SendOnBehalf" { Set-Mailbox -Identity $Identity -GrantSendOnBehalfTo @{ Add = $User } -Confirm:$false -ErrorAction Stop }
        }
    }
}

# Odebranie uprawnień
function Remove-HTMailboxPermission {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][string]$User,
        [Parameter(Mandatory)][ValidateSet("FullAccess", "SendAs", "SendOnBehalf")][string]$Type
    )
    switch ($Type) {
        "FullAccess" { Remove-MailboxPermission -Identity $Identity -User $User -AccessRights FullAccess -InheritanceType All -Confirm:$false -ErrorAction Stop }
        "SendAs" { Remove-RecipientPermission -Identity $Identity -Trustee $User -AccessRights SendAs -Confirm:$false -ErrorAction Stop }
        "SendOnBehalf" { Set-Mailbox -Identity $Identity -GrantSendOnBehalfTo @{ Remove = $User } -Confirm:$false -ErrorAction Stop }
    }
}

# Konwersja typu skrzynki
function Convert-HTMailboxType {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][ValidateSet("Regular", "Shared", "Room", "Equipment")][string]$Type
    )
    Set-Mailbox -Identity $Identity -Type $Type -Confirm:$false -ErrorAction Stop
}

# Aktualna konfiguracja autoodpowiedzi
function Get-HTMailboxAutoReply {
    param ([Parameter(Mandatory)][string]$Identity)
    return Get-MailboxAutoReplyConfiguration -Identity $Identity -ErrorAction Stop
}

# Ustawienie autoodpowiedzi
function Set-HTMailboxAutoReply {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][ValidateSet("Disabled", "Enabled", "Scheduled")][string]$State,
        [string]$InternalMessage,
        [string]$ExternalMessage,
        [ValidateSet("None", "Known", "All")][string]$ExternalAudience = "All",
        [Nullable[datetime]]$StartTime,
        [Nullable[datetime]]$EndTime
    )

    $params = @{
        Identity       = $Identity
        AutoReplyState = $State
        ErrorAction    = "Stop"
    }
    if ($State -ne "Disabled") {
        $params.InternalMessage = ConvertTo-HTAutoReplyHtml $InternalMessage
        $params.ExternalMessage = ConvertTo-HTAutoReplyHtml $(if ($ExternalMessage) { $ExternalMessage } else { $InternalMessage })
        $params.ExternalAudience = $ExternalAudience
    }
    if ($State -eq "Scheduled") {
        if (-not $StartTime -or -not $EndTime) { throw "Dla trybu zaplanowanego wymagane są daty rozpoczęcia i zakończenia." }
        if ($EndTime -le $StartTime) { throw "Data zakończenia musi być późniejsza niż data rozpoczęcia." }
        $params.StartTime = $StartTime
        $params.EndTime = $EndTime
    }
    Set-MailboxAutoReplyConfiguration @params
}

# Zamiana zwykłego tekstu na prosty HTML (zachowanie nowych linii)
function ConvertTo-HTAutoReplyHtml {
    param ([AllowEmptyString()][AllowNull()][string]$Text)
    if (-not $Text) { return "" }
    if ($Text -match '<(html|body|p|br|div)\b') { return $Text }
    $encoded = [System.Net.WebUtility]::HtmlEncode($Text)
    return ($encoded -replace "`r?`n", "<br>")
}

# Zamiana HTML autoodpowiedzi na zwykły tekst (do edycji)
function ConvertFrom-HTAutoReplyHtml {
    param ([AllowEmptyString()][AllowNull()][string]$Html)
    if (-not $Html) { return "" }
    $text = $Html -replace '(?i)<br\s*/?>', "`r`n" -replace '(?i)</(p|div)>', "`r`n" -replace '<[^>]+>', ''
    return ([System.Net.WebUtility]::HtmlDecode($text)).Trim()
}

# Ukrycie / pokazanie w globalnej liście adresów
function Set-HTMailboxHiddenFromGAL {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][bool]$Hidden
    )
    Set-Mailbox -Identity $Identity -HiddenFromAddressListsEnabled $Hidden -Confirm:$false -ErrorAction Stop
}

# Włączenie archiwum (opcjonalnie auto-rozszerzalnego)
function Enable-HTMailboxArchive {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [switch]$AutoExpanding
    )
    $mbx = Get-EXOMailbox -Identity $Identity -Properties ArchiveStatus -ErrorAction Stop
    if ("$($mbx.ArchiveStatus)" -ne "Active") {
        Enable-Mailbox -Identity $Identity -Archive -Confirm:$false -ErrorAction Stop | Out-Null
    }
    if ($AutoExpanding) {
        Enable-Mailbox -Identity $Identity -AutoExpandingArchive -Confirm:$false -ErrorAction Stop | Out-Null
    }
}

# Ustawienie / usunięcie przekierowania
function Set-HTMailboxForwarding {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [AllowEmptyString()][string]$ForwardTo,
        [bool]$KeepCopy = $true
    )
    if ([string]::IsNullOrWhiteSpace($ForwardTo)) {
        Set-Mailbox -Identity $Identity -ForwardingSmtpAddress $null -ForwardingAddress $null -DeliverToMailboxAndForward $false -Confirm:$false -ErrorAction Stop
    }
    else {
        Set-Mailbox -Identity $Identity -ForwardingSmtpAddress "smtp:$ForwardTo" -DeliverToMailboxAndForward $KeepCopy -Confirm:$false -ErrorAction Stop
    }
}

# Nazwa folderu kalendarza (zależna od języka skrzynki)
function Get-HTCalendarFolderIdentity {
    param ([Parameter(Mandatory)][string]$Identity)
    $folder = Get-EXOMailboxFolderStatistics -Identity $Identity -FolderScope Calendar -ErrorAction Stop |
        Where-Object { $_.FolderType -eq "Calendar" } | Select-Object -First 1
    $name = if ($folder) { $folder.Name } else { "Calendar" }
    return "$($Identity):\$name"
}

# Uprawnienia do kalendarza
function Get-HTCalendarPermissions {
    param ([Parameter(Mandatory)][string]$Identity)
    $folderId = Get-HTCalendarFolderIdentity -Identity $Identity
    return @(Get-EXOMailboxFolderPermission -Identity $folderId -ErrorAction Stop | ForEach-Object {
            [PSCustomObject]@{
                Folder       = $folderId
                User         = "$($_.User)"
                AccessRights = ($_.AccessRights -join ", ")
                SharingPermissionFlags = "$($_.SharingPermissionFlags)"
            }
        })
}

# Nadanie / zmiana uprawnień do kalendarza
function Set-HTCalendarPermission {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][string]$User,
        [Parameter(Mandatory)][ValidateSet("Reviewer", "LimitedDetails", "AvailabilityOnly", "Author", "Editor", "PublishingEditor", "Owner", "None")][string]$AccessRights
    )
    $folderId = Get-HTCalendarFolderIdentity -Identity $Identity
    $existing = Get-EXOMailboxFolderPermission -Identity $folderId -User $User -ErrorAction SilentlyContinue
    if ($existing) {
        Set-MailboxFolderPermission -Identity $folderId -User $User -AccessRights $AccessRights -Confirm:$false -ErrorAction Stop | Out-Null
    }
    else {
        Add-MailboxFolderPermission -Identity $folderId -User $User -AccessRights $AccessRights -Confirm:$false -ErrorAction Stop | Out-Null
    }
}

# Usunięcie uprawnień do kalendarza
function Remove-HTCalendarPermission {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][string]$User
    )
    $folderId = Get-HTCalendarFolderIdentity -Identity $Identity
    Remove-MailboxFolderPermission -Identity $folderId -User $User -Confirm:$false -ErrorAction Stop
}

# Reguły skrzynki odbiorczej
function Get-HTInboxRules {
    param ([Parameter(Mandatory)][string]$Identity)
    return @(Get-InboxRule -Mailbox $Identity -ErrorAction Stop | ForEach-Object {
            $forwards = @($_.ForwardTo) + @($_.RedirectTo) + @($_.ForwardAsAttachmentTo) | Where-Object { $_ }
            [PSCustomObject]@{
                Name           = $_.Name
                Enabled        = [bool]$_.Enabled
                Priority       = $_.Priority
                ForwardTo      = ($_.ForwardTo -join ", ")
                RedirectTo     = ($_.RedirectTo -join ", ")
                MoveToFolder   = "$($_.MoveToFolder)"
                DeleteMessage  = [bool]$_.DeleteMessage
                Description    = ("$($_.Description)" -replace "`r?`n", " ")
                RuleIdentity   = "$($_.Identity)"
                __flag         = if ($forwards.Count -gt 0 -or $_.DeleteMessage) { "warn" } elseif (-not $_.Enabled) { "muted" } else { "" }
            }
        })
}

# Śledzenie wiadomości (ostatnie dni)
function Get-HTMessageTrace {
    param (
        [Parameter(Mandatory)][string]$Address,
        [ValidateSet("Received", "Sent")][string]$Direction = "Received",
        [ValidateRange(1, 10)][int]$Days = 2
    )

    $params = @{
        StartDate   = (Get-Date).AddDays(-$Days)
        EndDate     = Get-Date
        ErrorAction = "Stop"
    }
    if ($Direction -eq "Received") { $params.RecipientAddress = $Address } else { $params.SenderAddress = $Address }

    $command = if (Get-Command Get-MessageTraceV2 -ErrorAction SilentlyContinue) { "Get-MessageTraceV2" } else { "Get-MessageTrace" }
    if ($command -eq "Get-MessageTraceV2") { $params.ResultSize = 1000 } else { $params.PageSize = 1000 }

    return @(& $command @params | ForEach-Object {
            [PSCustomObject]@{
                Received  = $_.Received
                Sender    = $_.SenderAddress
                Recipient = $_.RecipientAddress
                Subject   = $_.Subject
                Status    = "$($_.Status)"
                Size      = $_.Size
            }
        })
}

# Urządzenia mobilne powiązane ze skrzynką
function Get-HTMailboxMobileDevices {
    param ([Parameter(Mandatory)][string]$Identity)
    return @(Get-EXOMobileDeviceStatistics -Mailbox $Identity -ErrorAction Stop | ForEach-Object {
            [PSCustomObject]@{
                Device        = $_.DeviceFriendlyName
                Model         = $_.DeviceModel
                OS            = $_.DeviceOS
                ClientType    = "$($_.ClientType)"
                AccessState   = "$($_.DeviceAccessState)"
                LastSync      = $_.LastSuccessSync
                DeviceId      = $_.DeviceId
                DeviceIdentity = "$($_.Identity)"
            }
        })
}

# Liczba skrzynek wg typu (Dashboard)
function Get-HTMailboxSummary {
    $all = @(Get-EXOMailbox -ResultSize Unlimited -ErrorAction Stop)
    $byType = $all | Group-Object RecipientTypeDetails
    return [PSCustomObject]@{
        Total  = $all.Count
        User   = [int](($byType | Where-Object Name -eq "UserMailbox").Count)
        Shared = [int](($byType | Where-Object Name -eq "SharedMailbox").Count)
        Other  = $all.Count - [int](($byType | Where-Object Name -eq "UserMailbox").Count) - [int](($byType | Where-Object Name -eq "SharedMailbox").Count)
    }
}

#region Reguły skrzynki i urządzenia mobilne
function Disable-HTInboxRule {
    param ([Parameter(Mandatory)][string]$Mailbox, [Parameter(Mandatory)][string]$Identity)
    Disable-InboxRule -Mailbox $Mailbox -Identity $Identity -Confirm:$false -ErrorAction Stop
}

function Remove-HTInboxRule {
    param ([Parameter(Mandatory)][string]$Mailbox, [Parameter(Mandatory)][string]$Identity)
    Remove-InboxRule -Mailbox $Mailbox -Identity $Identity -Confirm:$false -ErrorAction Stop
}

# Usunięcie powiązania urządzenia mobilnego ze skrzynką (urządzenie musi ponownie się zsynchronizować)
function Remove-HTMailboxMobileDevice {
    param ([Parameter(Mandatory)][string]$Identity)
    Remove-MobileDevice -Identity $Identity -Confirm:$false -ErrorAction Stop
}
#endregion

#region Rozmiary i statystyki
# Rozmiar z Exchange ("1.2 GB (1,288,490,188 bytes)") na liczbę bajtów; $null dla "Unlimited" i pustych
function ConvertFrom-HTExchangeSize {
    param ([AllowNull()][object]$Value)
    if ($null -eq $Value) { return $null }
    $text = "$Value"
    if ($text -match '\(([\d,\.\s ]+)\s*bytes\)') { return [long](($matches[1]) -replace '[^\d]', '') }
    if ($text -match '^\d+$') { return [long]$text }
    return $null
}

# Statystyki skrzynki: rozmiar, liczba elementów, wykorzystanie limitu, aktywność
function Get-HTMailboxUsage {
    param ([Parameter(Mandatory)][string]$Identity)
    $mbx = Get-EXOMailbox -Identity $Identity -Properties ProhibitSendQuota, ArchiveStatus, LitigationHoldEnabled, RetainDeletedItemsFor -ErrorAction Stop
    $stats = Get-EXOMailboxStatistics -Identity $Identity -Properties LastLogonTime, LastUserActionTime -ErrorAction Stop
    $size = ConvertFrom-HTExchangeSize $stats.TotalItemSize
    $deleted = ConvertFrom-HTExchangeSize $stats.TotalDeletedItemSize
    $quota = ConvertFrom-HTExchangeSize $mbx.ProhibitSendQuota
    $archive = $null
    if ("$($mbx.ArchiveStatus)" -eq "Active") {
        try { $archive = ConvertFrom-HTExchangeSize (Get-EXOMailboxStatistics -Identity $Identity -Archive -ErrorAction Stop).TotalItemSize } catch { $archive = $null }
    }
    $percent = if ($size -and $quota) { [Math]::Round(100 * $size / $quota, 1) } else { $null }
    $lastActivity = @($stats.LastUserActionTime, $stats.LastLogonTime) | Where-Object { $_ } | Sort-Object -Descending | Select-Object -First 1
    return [PSCustomObject]@{
        Skrzynka              = $mbx.DisplayName
        Adres                 = "$($mbx.PrimarySmtpAddress)"
        Typ                   = "$($mbx.RecipientTypeDetails)"
        "Rozmiar (MB)"        = if ($null -ne $size) { [Math]::Round($size / 1MB, 1) } else { $null }
        Elementy              = $stats.ItemCount
        "Usunięte (MB)"       = if ($null -ne $deleted) { [Math]::Round($deleted / 1MB, 1) } else { $null }
        "Limit (GB)"          = if ($quota) { [Math]::Round($quota / 1GB, 1) } else { "bez limitu" }
        "Wykorzystanie %"     = $percent
        "Archiwum (MB)"       = if ($null -ne $archive) { [Math]::Round($archive / 1MB, 1) } else { $null }
        "Ostatnia aktywność"  = $lastActivity
        "Dni bez aktywności"  = Get-HTDaysSince $lastActivity
        "Litigation Hold"     = [bool]$mbx.LitigationHoldEnabled
        __flag                = if ($percent -ge 95) { "crit" } elseif ($percent -ge 85) { "warn" } else { "" }
    }
}
#endregion

#region Dostęp użytkownika do skrzynek
# Skrzynki, do których użytkownik ma FullAccess / SendAs / SendOnBehalf.
# OnProgress: { param($Index, $Total, $Name) } - przegląd wszystkich skrzynek może potrwać.
function Get-HTUserMailboxAccess {
    param (
        [Parameter(Mandatory)][string]$User,
        [scriptblock]$OnProgress
    )
    $recipient = Get-EXORecipient -Identity $User -ErrorAction Stop
    $ids = @("$($recipient.PrimarySmtpAddress)", "$($recipient.Name)", "$($recipient.DisplayName)", "$($recipient.Alias)", "$($recipient.ExternalDirectoryObjectId)") +
        @($recipient.EmailAddresses | ForEach-Object { "$_" -replace '^smtp:', '' }) | Where-Object { $_ } | ForEach-Object { $_.ToLowerInvariant() }
    $upn = (Get-EXOMailbox -Identity $User -ErrorAction SilentlyContinue).UserPrincipalName
    if ($upn) { $ids += $upn.ToLowerInvariant() }
    $ids = @($ids | Select-Object -Unique)
    $result = New-Object System.Collections.Generic.List[object]

    $mailboxes = @(Get-EXOMailbox -ResultSize Unlimited -Properties GrantSendOnBehalfTo -ErrorAction Stop)
    $i = 0
    foreach ($mbx in $mailboxes) {
        $i++
        if ($OnProgress) { & $OnProgress $i $mailboxes.Count $mbx.DisplayName }
        $address = "$($mbx.PrimarySmtpAddress)"
        try {
            foreach ($p in @(Get-EXOMailboxPermission -Identity $address -ErrorAction Stop)) {
                if ($p.IsInherited) { continue }
                if ($ids -contains "$($p.User)".ToLowerInvariant()) {
                    $result.Add([PSCustomObject]@{ Skrzynka = $mbx.DisplayName; Adres = $address; Typ = "$($mbx.RecipientTypeDetails)"; Uprawnienie = "FullAccess" })
                }
            }
        }
        catch { Write-Log -Message "Uprawnienia skrzynki $($address): $($_.Exception.Message)" -Type "Warn" }
        foreach ($delegate in @($mbx.GrantSendOnBehalfTo)) {
            if ($delegate -and $ids -contains "$delegate".ToLowerInvariant()) {
                $result.Add([PSCustomObject]@{ Skrzynka = $mbx.DisplayName; Adres = $address; Typ = "$($mbx.RecipientTypeDetails)"; Uprawnienie = "SendOnBehalf" })
            }
        }
    }

    $sendAs = @()
    try { $sendAs = @(Get-EXORecipientPermission -Trustee $User -ResultSize Unlimited -ErrorAction Stop) }
    catch { $sendAs = @(Get-RecipientPermission -Trustee $User -ResultSize Unlimited -ErrorAction Stop) }
    foreach ($p in $sendAs) {
        if ($p.IsInherited -or @($p.AccessRights) -notcontains "SendAs") { continue }
        $result.Add([PSCustomObject]@{ Skrzynka = "$($p.Identity)"; Adres = "$($p.Identity)"; Typ = ""; Uprawnienie = "SendAs" })
    }
    return $result.ToArray()
}
#endregion

#region Adresy e-mail (aliasy)
function Get-HTMailboxAddresses {
    param ([Parameter(Mandatory)][string]$Identity)
    $mbx = Get-EXOMailbox -Identity $Identity -Properties EmailAddresses -ErrorAction Stop
    return @($mbx.EmailAddresses | ForEach-Object {
            $value = "$_"
            $prefix = ($value -split ':', 2)[0]
            [PSCustomObject]@{
                Adres     = ($value -split ':', 2)[1]
                Typ       = $prefix.ToUpperInvariant()
                Główny    = ($prefix -ceq "SMTP")
                Wartość   = $value
                __flag    = if ($prefix -ceq "SMTP") { "" } elseif ($prefix -notmatch '^smtp$') { "muted" } else { "" }
            }
        } | Sort-Object @{ Expression = { -not $_.Główny } }, Typ, Adres)
}

function Add-HTMailboxAddress {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][string]$Address
    )
    if (-not (Test-HTInputValue -Value $Address -ValidationType Email)) { throw "Nieprawidłowy adres e-mail: $Address" }
    Set-Mailbox -Identity $Identity -EmailAddresses @{ Add = "smtp:$Address" } -Confirm:$false -ErrorAction Stop
}

function Remove-HTMailboxAddress {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][string]$Value
    )
    if ($Value -cmatch '^SMTP:') { throw "Nie można usunąć adresu głównego ($Value)." }
    Set-Mailbox -Identity $Identity -EmailAddresses @{ Remove = $Value } -Confirm:$false -ErrorAction Stop
}
#endregion

#region Zgodność: Litigation Hold, retencja, kwarantanna, odzyskiwanie elementów
function Set-HTMailboxLitigationHold {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][bool]$Enabled,
        [int]$DurationDays = 0
    )
    $params = @{ Identity = $Identity; LitigationHoldEnabled = $Enabled; Confirm = $false; ErrorAction = "Stop" }
    if ($Enabled) { $params.LitigationHoldDuration = if ($DurationDays -gt 0) { $DurationDays } else { "Unlimited" } }
    Set-Mailbox @params
}

function Set-HTMailboxRetainDeletedItems {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [Parameter(Mandatory)][ValidateRange(1, 30)][int]$Days
    )
    Set-Mailbox -Identity $Identity -RetainDeletedItemsFor $Days -Confirm:$false -ErrorAction Stop
}

# Wiadomości w kwarantannie (opcjonalnie dla wskazanych odbiorców)
function Get-HTQuarantineMessages {
    param (
        [string[]]$Recipients = @(),
        [ValidateRange(1, 30)][int]$Days = 7,
        [string]$SenderAddress
    )
    $params = @{
        StartReceivedDate = (Get-Date).AddDays(-$Days)
        EndReceivedDate   = Get-Date
        PageSize          = 1000
        ErrorAction       = "Stop"
    }
    if ($Recipients.Count -gt 0) { $params.RecipientAddress = $Recipients }
    if ($SenderAddress) { $params.SenderAddress = $SenderAddress }
    return @(Get-QuarantineMessage @params | ForEach-Object {
            [PSCustomObject]@{
                Odebrano       = $_.ReceivedTime
                Nadawca        = $_.SenderAddress
                Odbiorca       = (@($_.RecipientAddress) -join ", ")
                Temat          = $_.Subject
                Powód          = "$($_.QuarantineTypes)"
                Kierunek       = "$($_.Direction)"
                Zwolniona      = "$($_.ReleaseStatus)"
                Wygasa         = $_.Expires
                Identity       = "$($_.Identity)"
                __flag         = if ("$($_.QuarantineTypes)" -match 'Malware|HighConfPhish') { "crit" } elseif ("$($_.ReleaseStatus)" -eq "Released") { "muted" } else { "" }
            }
        } | Sort-Object Odebrano -Descending)
}

function Invoke-HTQuarantineRelease {
    param ([Parameter(Mandatory)][string]$Identity, [switch]$AllowSender)
    $params = @{ Identity = $Identity; ReleaseToAll = $true; ErrorAction = "Stop" }
    if ($AllowSender) { $params.AllowSender = $true }
    Release-QuarantineMessage @params
}

function Remove-HTQuarantineMessage {
    param ([Parameter(Mandatory)][string]$Identity)
    Delete-QuarantineMessage -Identity $Identity -Confirm:$false -ErrorAction Stop
}

# Treść wiadomości z kwarantanny (zwykły tekst)
function Get-HTQuarantinePreview {
    param ([Parameter(Mandatory)][string]$Identity)
    $preview = Preview-QuarantineMessage -Identity $Identity -ErrorAction Stop
    $body = "$($preview.Body)" -replace '(?i)<br\s*/?>', "`n" -replace '(?i)</(p|div|tr)>', "`n" -replace '<[^>]+>', ''
    $text = [System.Net.WebUtility]::HtmlDecode($body) -replace "(`r?`n\s*){3,}", "`n`n"
    return "Od: $($preview.Sender)`nDo: $(@($preview.To) -join ', ')`nTemat: $($preview.Subject)`nData: $($preview.ReceivedTime)`n`n$($text.Trim())"
}

# Elementy możliwe do odzyskania (Recoverable Items) - wymaga roli Mailbox Import Export
function Get-HTRecoverableItems {
    param (
        [Parameter(Mandatory)][string]$Identity,
        [ValidateRange(1, 90)][int]$Days = 14,
        [string]$SubjectContains
    )
    $params = @{
        Identity        = $Identity
        FilterStartTime = (Get-Date).AddDays(-$Days)
        FilterEndTime   = (Get-Date).AddDays(1)
        ResultSize      = 1000
        ErrorAction     = "Stop"
    }
    if ($SubjectContains) { $params.SubjectContains = $SubjectContains }
    return @(Get-RecoverableItems @params | ForEach-Object {
            [PSCustomObject]@{
                Temat     = $_.Subject
                Typ       = $_.ItemClass
                Usunięto  = $_.LastModifiedTime
                Folder    = $_.LastParentPath
                EntryID   = $_.EntryID
                Skrzynka  = $Identity
            }
        } | Sort-Object Usunięto -Descending)
}

function Restore-HTRecoverableItem {
    param ([Parameter(Mandatory)][string]$Identity, [Parameter(Mandatory)][string]$EntryID)
    Restore-RecoverableItems -Identity $Identity -EntryID $EntryID -ErrorAction Stop | Out-Null
}
#endregion

#region Grupy dystrybucyjne
function Get-HTDistributionGroups {
    return @(Get-DistributionGroup -ResultSize Unlimited -ErrorAction Stop | ForEach-Object {
            [PSCustomObject]@{
                Nazwa                 = $_.DisplayName
                Adres                 = "$($_.PrimarySmtpAddress)"
                Typ                   = "$($_.RecipientTypeDetails)"
                Właściciele           = (@($_.ManagedBy) -join ", ")
                "Tylko wewnętrzni nadawcy" = [bool]$_.RequireSenderAuthenticationEnabled
                "Ukryta w GAL"        = [bool]$_.HiddenFromAddressListsEnabled
                "Synchronizowana z AD" = [bool]$_.IsDirSynced
                Identity              = "$($_.PrimarySmtpAddress)"
            }
        } | Sort-Object Nazwa)
}

function Get-HTDistributionGroupMembers {
    param ([Parameter(Mandatory)][string]$Identity)
    return @(Get-DistributionGroupMember -Identity $Identity -ResultSize Unlimited -ErrorAction Stop | ForEach-Object {
            [PSCustomObject]@{
                Nazwa = $_.DisplayName
                Adres = "$($_.PrimarySmtpAddress)"
                Typ   = "$($_.RecipientTypeDetails)"
            }
        } | Sort-Object Nazwa)
}

# Grupy dystrybucyjne i zabezpieczeń z pocztą, do których należy odbiorca
function Get-HTRecipientGroups {
    param ([Parameter(Mandatory)][string]$Identity)
    $dn = (Get-Recipient -Identity $Identity -ErrorAction Stop).DistinguishedName
    $escaped = $dn.Replace("'", "''")
    return @(Get-Recipient -Filter "Members -eq '$escaped'" -ResultSize Unlimited -ErrorAction Stop | ForEach-Object {
            [PSCustomObject]@{
                Grupa = $_.DisplayName
                Adres = "$($_.PrimarySmtpAddress)"
                Typ   = "$($_.RecipientTypeDetails)"
            }
        } | Sort-Object Grupa)
}

function Add-HTDistributionGroupMember {
    param ([Parameter(Mandatory)][string]$Group, [Parameter(Mandatory)][string]$Member)
    Add-DistributionGroupMember -Identity $Group -Member $Member -BypassSecurityGroupManagerCheck -Confirm:$false -ErrorAction Stop
}

function Remove-HTDistributionGroupMember {
    param ([Parameter(Mandatory)][string]$Group, [Parameter(Mandatory)][string]$Member)
    Remove-DistributionGroupMember -Identity $Group -Member $Member -BypassSecurityGroupManagerCheck -Confirm:$false -ErrorAction Stop
}
#endregion

#region Raport przekierowań poza organizację
# Przekierowania skrzynek (ForwardingSmtpAddress) i reguł skrzynek do adresów spoza domen akceptowanych.
function Get-HTExternalForwardingReport {
    param (
        [switch]$IncludeInboxRules,
        [scriptblock]$OnProgress
    )
    $domains = @(Get-AcceptedDomain -ErrorAction Stop | ForEach-Object { "$($_.DomainName)".ToLowerInvariant() })
    $isExternal = {
        param($Address)
        $clean = ("$Address" -replace '^(smtp|SMTP):', '').Trim().Trim('"')
        if ($clean -notmatch '@([^@\]\s>]+)') { return $false }
        return $domains -notcontains $matches[1].ToLowerInvariant()
    }
    $mailboxes = @(Get-EXOMailbox -ResultSize Unlimited -Properties ForwardingSmtpAddress, ForwardingAddress, DeliverToMailboxAndForward -ErrorAction Stop)
    $i = 0
    foreach ($mbx in $mailboxes) {
        $i++
        $address = "$($mbx.PrimarySmtpAddress)"
        if ($mbx.ForwardingSmtpAddress) {
            $target = "$($mbx.ForwardingSmtpAddress)" -replace '^smtp:', ''
            $external = & $isExternal $target
            [PSCustomObject]@{
                Skrzynka       = $mbx.DisplayName
                Adres          = $address
                Źródło         = "Przekierowanie skrzynki"
                "Przekierowuje do" = $target
                Zewnętrzne     = $external
                "Kopia w skrzynce" = [bool]$mbx.DeliverToMailboxAndForward
                __flag         = if ($external) { "crit" } else { "" }
            }
        }
        elseif ($mbx.ForwardingAddress) {
            [PSCustomObject]@{
                Skrzynka       = $mbx.DisplayName
                Adres          = $address
                Źródło         = "Przekierowanie skrzynki (kontakt/odbiorca)"
                "Przekierowuje do" = "$($mbx.ForwardingAddress)"
                Zewnętrzne     = $false
                "Kopia w skrzynce" = [bool]$mbx.DeliverToMailboxAndForward
                __flag         = "warn"
            }
        }
        if (-not $IncludeInboxRules) { continue }
        if ($OnProgress) { & $OnProgress $i $mailboxes.Count $mbx.DisplayName }
        try {
            foreach ($rule in @(Get-InboxRule -Mailbox $address -ErrorAction Stop)) {
                $targets = @($rule.ForwardTo) + @($rule.RedirectTo) + @($rule.ForwardAsAttachmentTo) | Where-Object { $_ }
                if ($targets.Count -eq 0) { continue }
                $text = @($targets | ForEach-Object { "$_" })
                $external = @($text | Where-Object { & $isExternal $_ }).Count -gt 0
                [PSCustomObject]@{
                    Skrzynka       = $mbx.DisplayName
                    Adres          = $address
                    Źródło         = "Reguła: $($rule.Name)$(if (-not $rule.Enabled) { ' (wyłączona)' })"
                    "Przekierowuje do" = ($text -join "; ")
                    Zewnętrzne     = $external
                    "Kopia w skrzynce" = -not [bool]$rule.RedirectTo
                    __flag         = if ($external -and $rule.Enabled) { "crit" } elseif ($external) { "warn" } else { "" }
                }
            }
        }
        catch { Write-Log -Message "Reguły skrzynki $($address): $($_.Exception.Message)" -Type "Warn" }
    }
}
#endregion
