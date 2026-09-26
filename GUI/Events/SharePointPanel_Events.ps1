# Zakładka "SharePoint" - obsługa zdarzeń (drzewo bibliotek/folderów i uprawnienia)

$script:SPPlaceholder = "__placeholder__"

# Węzeł drzewa dla biblioteki / folderu (z leniwym ładowaniem podfolderów)
function New-HTSPTreeNode {
    param ([Parameter(Mandatory)][object]$Item)
    $node = New-Object System.Windows.Forms.TreeNode($Item.Title)
    $node.Tag = $Item
    $icon = if ($Item.IsLibrary) { "filing-cabinet.png" } else { "Opened Folder.png" }
    $node.ImageKey = $icon
    $node.SelectedImageKey = $icon
    $node.ToolTipText = $Item.ServerRelativeUrl
    $placeholder = New-Object System.Windows.Forms.TreeNode("Ładowanie...")
    $placeholder.Tag = $script:SPPlaceholder
    [void]$node.Nodes.Add($placeholder)
    return $node
}

# Wczytanie bibliotek dokumentów połączonej witryny
function Update-HTSharePointTree {
    Invoke-HTAction -Name "Wczytywanie bibliotek SharePoint" -RequiredService "SharePoint" -ScriptBlock {
        $tree = $HT_UI.SharePointTab.TreeView
        $libraries = @(Get-HTSPLibraries)
        $tree.BeginUpdate()
        try {
            $tree.Nodes.Clear()
            foreach ($library in $libraries) { [void]$tree.Nodes.Add((New-HTSPTreeNode -Item $library)) }
        }
        finally { $tree.EndUpdate() }

        Set-HTListData -ListView $HT_UI.SharePointTab.List -Data @()
        $HT_UI.SharePointTab.CurrentNode = $null
        $HT_UI.SharePointTab.PermissionHeader.Text = "Zaznacz bibliotekę lub folder, aby zobaczyć uprawnienia."
        $HT_UI.SharePointTab.CountLabel.Text = "Bibliotek: $($libraries.Count)"
        Write-Log -Message "Wczytano biblioteki SharePoint: $($libraries.Count)" -Type "Info"
    }
}

# Uprawnienia zaznaczonego elementu
function Update-HTSPPermissionView {
    param ([Parameter(Mandatory)][object]$Item)
    Invoke-HTAction -Name "Pobieranie uprawnień SharePoint" -RequiredService "SharePoint" -ScriptBlock {
        $permissions = @(Get-HTSPPermissions -Node $Item)
        Set-HTListData -ListView $HT_UI.SharePointTab.List -Data $permissions
        $unique = if ($permissions.Count -gt 0) { $permissions[0].Unique } else { Test-HTSPUniquePermissions -Node $Item }
        $HT_UI.SharePointTab.CurrentUnique = $unique
        $state = if ($unique) { "Uprawnienia UNIKALNE (dziedziczenie przerwane)" } else { "Uprawnienia dziedziczone z elementu nadrzędnego" }
        $HT_UI.SharePointTab.PermissionHeader.Text = "$($Item.ServerRelativeUrl)`n$state"
        $HT_UI.SharePointTab.PermissionHeader.ForeColor = if ($unique) { $Global:HTTheme.Warning } else { $Global:HTTheme.Muted }
    }
}

# Zaznaczony element drzewa
function Get-HTSPSelectedItem {
    if (-not (Assert-HTConnection -Service "SharePoint")) { return $null }
    $node = $HT_UI.SharePointTab.TreeView.SelectedNode
    if (-not $node -or $node.Tag -eq $script:SPPlaceholder) {
        Show-Dialog -Message "Najpierw zaznacz bibliotekę lub folder w drzewie." -Title "SharePoint" -Type "Warning" | Out-Null
        return $null
    }
    return $node.Tag
}

# Elementy docelowe: zaznaczone checkboxami lub (gdy brak) zaznaczony element
function Get-HTSPTargetItems {
    $checked = New-Object System.Collections.Generic.List[object]
    $stack = New-Object System.Collections.Stack
    foreach ($root in $HT_UI.SharePointTab.TreeView.Nodes) { $stack.Push($root) }
    while ($stack.Count -gt 0) {
        $node = $stack.Pop()
        if ($node.Tag -eq $script:SPPlaceholder) { continue }
        if ($node.Checked) { $checked.Add($node.Tag) }
        foreach ($child in $node.Nodes) { $stack.Push($child) }
    }
    if ($checked.Count -gt 0) { return $checked.ToArray() }
    $item = Get-HTSPSelectedItem
    if ($item) { return @($item) }
    return @()
}

# Wczytanie / odświeżenie
$HT_UI.SharePointTab.RefreshButton.Add_Click({ Update-HTSharePointTree })

# Połączenie z witryną wpisaną w polu adresu
$HT_UI.SharePointTab.ConnectSiteButton.Add_Click({
        $url = $HT_UI.SharePointTab.SiteBox.Text.Trim()
        if (-not (Test-HTInputValue -Value $url -ValidationType "Url")) {
            Show-Dialog -Message "Podaj poprawny adres witryny, np. https://firma.sharepoint.com/sites/Dzial" -Title "SharePoint" -Type "Warning" | Out-Null
            return
        }
        if ($Global:ConnectedToSharepointPnP) {
            Set-Connections -Action "Disconnect" -Service "SharePoint"
        }
        if (Connect-Module -Name "PnP.PowerShell" -SiteUrl $url) {
            Update-HTSharePointTree
        }
    })

$HT_UI.SharePointTab.SiteBox.Add_KeyDown({
        param($src, $evt)
        if ($evt.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
            $HT_UI.SharePointTab.ConnectSiteButton.PerformClick()
            $evt.SuppressKeyPress = $true
        }
    })

# Leniwe ładowanie podfolderów
$HT_UI.SharePointTab.TreeView.Add_BeforeExpand({
        param($src, $evt)
        $node = $evt.Node
        if ($node.Nodes.Count -ne 1 -or $node.Nodes[0].Tag -ne $script:SPPlaceholder) { return }
        $item = $node.Tag
        Invoke-HTAction -Name "Wczytywanie folderów" -RequiredService "SharePoint" -ScriptBlock {
            $children = @(Get-HTSPSubFolders -ServerRelativeUrl $item.ServerRelativeUrl -ListTitle $item.ListTitle)
            $src.BeginUpdate()
            try {
                $node.Nodes.Clear()
                foreach ($child in $children) { [void]$node.Nodes.Add((New-HTSPTreeNode -Item $child)) }
            }
            finally { $src.EndUpdate() }
        }
    })

# Zaznaczenie elementu - wczytanie uprawnień
$HT_UI.SharePointTab.TreeView.Add_AfterSelect({
        param($src, $evt)
        if ($evt.Node.Tag -eq $script:SPPlaceholder) { return }
        $HT_UI.SharePointTab.CurrentNode = $evt.Node.Tag
        Update-HTSPPermissionView -Item $evt.Node.Tag
    })

# Sprawdzenie uprawnień
$HT_UI.SharePointTab.Actions.CheckPermissions.Add_Click({
        $item = Get-HTSPSelectedItem
        if ($item) { Update-HTSPPermissionView -Item $item }
    })

# Nadanie uprawnień
$HT_UI.SharePointTab.Actions.GrantPermissions.Add_Click({
        $targets = @(Get-HTSPTargetItems)
        if ($targets.Count -eq 0) { return }

        $options = Invoke-HTAction -Name "Pobieranie poziomów uprawnień" -RequiredService "SharePoint" -ScriptBlock {
            @{ Roles = @(Get-HTSPRoleDefinitions); Groups = @(Get-HTSPGroups | ForEach-Object { $_.Title }) }
        }
        if (-not $options) { return }

        $targetText = ($targets | Select-Object -First 5 | ForEach-Object { $_.ServerRelativeUrl }) -join "`n"
        if ($targets.Count -gt 5) { $targetText += "`n... i $($targets.Count - 5) więcej" }

        $form = Show-HTFormDialog -Title "Nadaj uprawnienia" -Width 620 -OkText "Nadaj" -Description "Elementy ($($targets.Count)):`n$targetText" -Fields @(
            @{ Name = "Kind"; Label = "Komu"; Type = "Combo"; Options = @("Użytkownik / grupa zabezpieczeń (e-mail)", "Grupa SharePoint") }
            @{ Name = "Principal"; Label = "E-mail lub nazwa grupy"; Type = "Combo"; Editable = $true; Options = $options.Groups; Required = $true }
            @{ Name = "Role"; Label = "Poziom uprawnień"; Type = "Combo"; Options = $options.Roles; Default = $(if ($options.Roles -contains "Edit") { "Edit" } elseif ($options.Roles -contains "Edycja") { "Edycja" } else { $null }) }
            @{ Type = "Info"; Label = "Nadanie uprawnień do elementu dziedziczącego automatycznie przerywa dziedziczenie (kopiując obecne uprawnienia)." }
        )
        if (-not $form) { return }
        $principalType = if ($form.Kind -eq "Grupa SharePoint") { "SharePointGroup" } else { "User" }

        Invoke-HTAction -Name "Nadawanie uprawnień" -RequiredService "SharePoint" -ScriptBlock {
            $ok = Invoke-HTForEach -Items $targets -Action { param($t) Grant-HTSPPermission -Node $t -Principal $form.Principal -PrincipalType $principalType -Role $form.Role } -Describe { param($t) $t.ServerRelativeUrl }
            Write-Log -Message "Nadano '$($form.Role)' dla $($form.Principal) na $ok element(ach)." -Type "Info&Notification"
            if ($HT_UI.SharePointTab.CurrentNode) { Update-HTSPPermissionView -Item $HT_UI.SharePointTab.CurrentNode }
        }
    })

# Odebranie uprawnień (zaznaczonych na liście)
$HT_UI.SharePointTab.Actions.RemovePermissions.Add_Click({
        $item = Get-HTSPSelectedItem
        if (-not $item) { return }
        $selected = @(Get-HTListSelection -ListView $HT_UI.SharePointTab.List)
        if ($selected.Count -eq 0) {
            Show-Dialog -Message "Zaznacz na liście po prawej uprawnienia do odebrania." -Title "Odbierz uprawnienia" -Type "Warning" | Out-Null
            return
        }
        $who = ($selected | ForEach-Object { "• $($_.Principal) ($($_.Roles))" }) -join "`n"
        $warning = if (-not $HT_UI.SharePointTab.CurrentUnique) { "`n`nElement dziedziczy uprawnienia - zmiana przerwie dziedziczenie." } else { "" }
        if (-not (Show-HTConfirm -Message "Odebrać uprawnienia do $($item.ServerRelativeUrl)?`n$who$warning" -Title "Odbierz uprawnienia" -Warning)) { return }

        Invoke-HTAction -Name "Odbieranie uprawnień" -RequiredService "SharePoint" -ScriptBlock {
            $ok = Invoke-HTForEach -Items $selected -Action { param($a) Revoke-HTSPPermission -Node $item -Assignment $a } -Describe { param($a) $a.Principal }
            Write-Log -Message "Odebrano uprawnienia ($ok) do $($item.ServerRelativeUrl)" -Type "Info&Notification"
            Update-HTSPPermissionView -Item $item
        }
    })

# Dziedziczenie uprawnień
$HT_UI.SharePointTab.Actions.ToggleInheritance.Add_Click({
        $item = Get-HTSPSelectedItem
        if (-not $item) { return }
        $unique = Invoke-HTAction -Name "Sprawdzanie dziedziczenia" -RequiredService "SharePoint" -ScriptBlock { Test-HTSPUniquePermissions -Node $item }

        if ($unique) {
            if (-not (Show-HTConfirm -Message "Przywrócić dziedziczenie uprawnień dla $($item.ServerRelativeUrl)?`nWszystkie unikalne uprawnienia tego elementu zostaną usunięte." -Title "Dziedziczenie" -Warning)) { return }
            Invoke-HTAction -Name "Przywracanie dziedziczenia" -RequiredService "SharePoint" -ScriptBlock {
                Set-HTSPInheritance -Node $item -Inherit $true
                Write-Log -Message "Przywrócono dziedziczenie: $($item.ServerRelativeUrl)" -Type "Info&Notification"
                Update-HTSPPermissionView -Item $item
            }
        }
        else {
            $choice = Show-HTChoiceDialog -Title "Przerwij dziedziczenie" -Prompt "$($item.ServerRelativeUrl) dziedziczy uprawnienia." -Choices @(
                @{ Key = "Copy"; Text = "Przerwij i skopiuj obecne uprawnienia"; Icon = "Copy.png" }
                @{ Key = "Clear"; Text = "Przerwij i wyczyść uprawnienia"; Icon = "Clear Symbol.png"; Style = "Danger"; Description = "Dostęp zachowają tylko administratorzy witryny" }
            )
            if (-not $choice) { return }
            Invoke-HTAction -Name "Przerywanie dziedziczenia" -RequiredService "SharePoint" -ScriptBlock {
                Set-HTSPInheritance -Node $item -Inherit $false -CopyExisting ($choice -eq "Copy")
                Write-Log -Message "Przerwano dziedziczenie ($choice): $($item.ServerRelativeUrl)" -Type "Info&Notification"
                Update-HTSPPermissionView -Item $item
            }
        }
    })

# Utworzenie grupy SharePoint
$HT_UI.SharePointTab.Actions.CreateSecurityGroup.Add_Click({
        if (-not (Assert-HTConnection -Service "SharePoint")) { return }
        $roles = @(Invoke-HTAction -Name "Pobieranie poziomów uprawnień" -RequiredService "SharePoint" -ScriptBlock { Get-HTSPRoleDefinitions })

        $form = Show-HTFormDialog -Title "Nowa grupa SharePoint" -Width 620 -OkText "Utwórz" -Fields @(
            @{ Name = "Title"; Label = "Nazwa grupy"; Required = $true }
            @{ Name = "Description"; Label = "Opis" }
            @{ Name = "Members"; Label = "Członkowie (e-maile, jeden w linii)"; Type = "Multiline" }
            @{ Name = "Grant"; Label = "Nadaj grupie uprawnienia do zaznaczonych elementów"; Type = "Check"; Default = $false }
            @{ Name = "Role"; Label = "Poziom uprawnień"; Type = "Combo"; Options = $roles }
        )
        if (-not $form) { return }
        $members = @(Split-HTInputList -Text $form.Members)
        $targets = if ($form.Grant) { @(Get-HTSPTargetItems) } else { @() }

        Invoke-HTAction -Name "Tworzenie grupy SharePoint" -RequiredService "SharePoint" -ScriptBlock {
            New-HTSPGroup -Title $form.Title -Description $form.Description -Members $members | Out-Null
            Write-Log -Message "Utworzono grupę SharePoint '$($form.Title)' (członków: $($members.Count))" -Type "Info&Notification"
            if ($targets.Count -gt 0 -and $form.Role) {
                $ok = Invoke-HTForEach -Items $targets -Action { param($t) Grant-HTSPPermission -Node $t -Principal $form.Title -PrincipalType "SharePointGroup" -Role $form.Role } -Describe { param($t) $t.ServerRelativeUrl }
                Write-Log -Message "Nadano grupie '$($form.Title)' uprawnienia '$($form.Role)' do $ok element(ów)." -Type "Info"
                if ($HT_UI.SharePointTab.CurrentNode) { Update-HTSPPermissionView -Item $HT_UI.SharePointTab.CurrentNode }
            }
        }
    })

# Członkowie grupy SharePoint
$HT_UI.SharePointTab.Actions.CheckGroup.Add_Click({
        if (-not (Assert-HTConnection -Service "SharePoint")) { return }
        $groups = @(Invoke-HTAction -Name "Pobieranie grup" -RequiredService "SharePoint" -ScriptBlock { Get-HTSPGroups })
        $group = Show-HTSelectionDialog -Title "Wybierz grupę SharePoint" -Items $groups -Columns @(
            @{ Text = "Grupa"; Property = "Title"; Width = 300 }
            @{ Text = "Właściciel"; Property = "Owner"; Width = 200 }
            @{ Text = "Opis"; Property = "Description"; Width = 220 }
        )
        if (-not $group) { return }
        $group = @($group)[0]

        $choice = Show-HTChoiceDialog -Title "Grupa: $($group.Title)" -Choices @(
            @{ Key = "View"; Text = "Pokaż członków"; Icon = "Eye open.png" }
            @{ Key = "Add"; Text = "Dodaj członków"; Icon = "Add Male User Group.png" }
            @{ Key = "Remove"; Text = "Usuń członków"; Icon = "Minus.png" }
        )
        switch ($choice) {
            "View" {
                $members = @(Invoke-HTAction -Name "Pobieranie członków" -RequiredService "SharePoint" -ScriptBlock { Get-HTSPGroupMembers -Group $group.Title })
                Show-HTDataViewer -Title "Członkowie - $($group.Title)" -Data $members -ExportName "Grupa_$($group.Title)"
            }
            "Add" {
                $text = Show-HTFormDialog -Title "Dodaj członków - $($group.Title)" -OkText "Dodaj" -Fields @(
                    @{ Name = "Members"; Label = "E-maile (jeden w linii)"; Type = "Multiline"; Required = $true }
                )
                if (-not $text) { return }
                $logins = @(Split-HTInputList -Text $text.Members)
                Invoke-HTAction -Name "Dodawanie członków" -RequiredService "SharePoint" -ScriptBlock {
                    $ok = Invoke-HTForEach -Items $logins -Action { param($l) Add-HTSPGroupMember -Group $group.Title -LoginName $l } -Describe { param($l) $l }
                    Write-Log -Message "Dodano $ok członków do grupy '$($group.Title)'" -Type "Info&Notification"
                }
            }
            "Remove" {
                $members = @(Invoke-HTAction -Name "Pobieranie członków" -RequiredService "SharePoint" -ScriptBlock { Get-HTSPGroupMembers -Group $group.Title })
                $selected = Show-HTSelectionDialog -Title "Usuń członków - $($group.Title)" -MultiSelect -OkText "Usuń" -Items $members -Columns @(
                    @{ Text = "Nazwa"; Property = "Title"; Width = 240 }
                    @{ Text = "E-mail"; Property = "Email"; Width = 260 }
                )
                if (-not $selected) { return }
                Invoke-HTAction -Name "Usuwanie członków" -RequiredService "SharePoint" -ScriptBlock {
                    $ok = Invoke-HTForEach -Items @($selected) -Action { param($m) Remove-HTSPGroupMember -Group $group.Title -LoginName $m.LoginName } -Describe { param($m) $m.Title }
                    Write-Log -Message "Usunięto $ok członków z grupy '$($group.Title)'" -Type "Info&Notification"
                }
            }
        }
    })

# Nowy folder
$HT_UI.SharePointTab.Actions.AddFolder.Add_Click({
        $item = Get-HTSPSelectedItem
        if (-not $item) { return }
        $name = Show-InputBox -Prompt "Nazwa nowego folderu w:`n$($item.ServerRelativeUrl)" -Title "Dodaj folder"
        if (-not $name) { return }

        Invoke-HTAction -Name "Tworzenie folderu" -RequiredService "SharePoint" -ScriptBlock {
            $folder = New-HTSPFolder -ParentNode $item -Name $name
            $node = $HT_UI.SharePointTab.TreeView.SelectedNode
            $loaded = -not ($node.Nodes.Count -eq 1 -and $node.Nodes[0].Tag -eq $script:SPPlaceholder)
            if ($loaded) { [void]$node.Nodes.Add((New-HTSPTreeNode -Item $folder)) }
            $node.Expand()
            Write-Log -Message "Utworzono folder $($folder.ServerRelativeUrl)" -Type "Info&Notification"
        }
    })

# Otwarcie w przeglądarce
$HT_UI.SharePointTab.Actions.OpenInBrowser.Add_Click({
        $item = Get-HTSPSelectedItem
        if (-not $item) { return }
        try {
            Start-Process (Get-HTSPAbsoluteUrl -ServerRelativeUrl $item.ServerRelativeUrl)
        }
        catch {
            Write-Log -Message "Nie udało się otworzyć adresu: $($_.Exception.Message)" -Type "Error"
        }
    })

# Eksport uprawnień
$HT_UI.SharePointTab.Actions.Export.Add_Click({
        Export-HTListView -ListView $HT_UI.SharePointTab.List -Name "Uprawnienia_SharePoint"
    })
