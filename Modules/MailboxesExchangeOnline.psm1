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
            [PSCustomObject]@{
                Name           = $_.Name
                Enabled        = [bool]$_.Enabled
                Priority       = $_.Priority
                ForwardTo      = ($_.ForwardTo -join ", ")
                RedirectTo     = ($_.RedirectTo -join ", ")
                MoveToFolder   = "$($_.MoveToFolder)"
                DeleteMessage  = [bool]$_.DeleteMessage
                Description    = ("$($_.Description)" -replace "`r?`n", " ")
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
