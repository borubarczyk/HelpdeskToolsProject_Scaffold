function Get-AllIcons {

    try {
        # Dolne przyciski
        $HT_UI.Buttons.ConnectExchange.Image = [System.Drawing.Image]::FromFile((Join-Path $BasePath "microsoft-exchange-2019.png"))
        $HT_UI.Buttons.ConnectSharePoint.Image = [System.Drawing.Image]::FromFile((Join-Path $BasePath "microsoft-sharepoint-2019.png"))
        $HT_UI.Buttons.ConnectGraph.Image = [System.Drawing.Image]::FromFile((Join-Path $BasePath "api.png"))
        $HT_UI.Buttons.PasswordGen.Image = [System.Drawing.Image]::FromFile((Join-Path $BasePath "password.png"))
        $HT_UI.Buttons.Exit.Image = [System.Drawing.Image]::FromFile((Join-Path $BasePath "close.png"))

        foreach ($btn in $HT_UI.Buttons.Values) {
            $btn.ImageAlign = 'MiddleCenter'
            $btn.TextImageRelation = 'ImageBeforeText'
            $btn.TextAlign = 'MiddleCenter'
        }

        # Ikony użytkownika (jeśli zakładka wczytana)
        if ($HT_UI.UsersTab -and $HT_UI.UsersTab.Actions) {
            $iconsMap = @{
                Refresh         = "Refresh.png"
                ResetPassword   = "Password.png"
                ToggleBlock     = "Denied.png"
                ChangeLicense   = "Software License.png"
                AddToGroup      = "Add Male User Group.png"
                RemoveFromGroup = "Minus.png"
                ChangeMFA       = "Microsoft Authenticator.png"
                EditContact     = "Info.png"
                Mailbox         = "Email.png"
                Devices         = "Multiple Devices.png"
            }

            foreach ($key in $iconsMap.Keys) {
                $HT_UI.UsersTab.Actions[$key].Image = [System.Drawing.Image]::FromFile((Join-Path $BasePath $iconsMap[$key]))
                $HT_UI.UsersTab.Actions[$key].ImageAlign = 'MiddleLeft'
                $HT_UI.UsersTab.Actions[$key].TextImageRelation = 'ImageBeforeText'
                $HT_UI.UsersTab.Actions[$key].TextAlign = 'MiddleCenter'
            }
        }

        # Ikony SharePoint (jeśli zakładka wczytana)
        if ($HT_UI.SharePointTab -and $HT_UI.SharePointTab.Actions) {
            $iconsMap_SP = @{
                Refresh             = "Refresh.png"
                CheckPermissions    = "Eye open.png"
                GrantPermissions    = "Add Male User Group.png"
                RemovePermissions   = "Minus.png"
                ToggleInheritance   = "Process.png"
                CreateSecurityGroup = "User Groups.png"
                CheckGroup          = "Info.png"
                AddFolder           = "Add Folder.png"
            }

            foreach ($key in $iconsMap_SP.Keys) {
                $HT_UI.SharePointTab.Actions[$key].Image = [System.Drawing.Image]::FromFile((Join-Path $BasePath $iconsMap_SP[$key]))
                $HT_UI.SharePointTab.Actions[$key].ImageAlign = 'MiddleLeft'
                $HT_UI.SharePointTab.Actions[$key].TextImageRelation = 'ImageBeforeText'
                $HT_UI.SharePointTab.Actions[$key].TextAlign = 'MiddleCenter'
            }
        }

        # Skrzynki (Mailboxes)
        if ($HT_UI.MailboxesTab -and $HT_UI.MailboxesTab.Actions) {
            $iconsMap_MB = @{
                Refresh       = "Refresh.png"
                CheckPerms    = "Eye open.png"
                GrantPerms    = "Add Male User Group.png"
                RemovePerms   = "Minus.png"
                Convert       = "Process.png"
                Autoresponder = "Reply.png"
                HideFromGAL   = "eye.png"
                EnableArchive = "shared-mail.png"
                Forwards      = "forward-message.png"
                Advanced      = "administrative-tools.png"
            }

            foreach ($key in $iconsMap_MB.Keys) {
                $HT_UI.MailboxesTab.Actions[$key].Image = [System.Drawing.Image]::FromFile((Join-Path $BasePath $iconsMap_MB[$key]))
                $HT_UI.MailboxesTab.Actions[$key].ImageAlign = 'MiddleLeft'
                $HT_UI.MailboxesTab.Actions[$key].TextImageRelation = 'ImageBeforeText'
                $HT_UI.MailboxesTab.Actions[$key].TextAlign = 'MiddleCenter'
            }
        }

        # Intune
        if ($HT_UI.IntuneTab -and $HT_UI.IntuneTab.Actions) {
            $iconsMap_Intune = @{
                Refresh        = "Refresh.png"
                RenameDevice   = "Rename.png"
                SetPrimaryUser = "Change User.png"
                DeviceInfo     = "Info.png"
                AppList        = "Software.png"
                Memberships    = "User Groups.png"
                RecoveryKey    = "Secure.png"
                LAPS           = "Key Security.png"
            }

            foreach ($key in $iconsMap_Intune.Keys) {
                $HT_UI.IntuneTab.Actions[$key].Image = [System.Drawing.Image]::FromFile((Join-Path $BasePath $iconsMap_Intune[$key]))
                $HT_UI.IntuneTab.Actions[$key].ImageAlign = 'MiddleLeft'
                $HT_UI.IntuneTab.Actions[$key].TextImageRelation = 'ImageBeforeText'
                $HT_UI.IntuneTab.Actions[$key].TextAlign = 'MiddleCenter'
            }
        }

        # Ikony dla Lokalnego AD
        if ($HT_UI.LocalADTab -and $HT_UI.LocalADTab.Views) {
            $icons_LocalAD = @{
                "Użytkownicy" = @{
                    "Odśwież"           = "Refresh.png"
                    "Resetuj hasło"     = "Password.png"
                    "Zablokuj/Odblokuj" = "Denied.png"
                    "Zmień grupy"       = "Add Male User Group.png"
                    "Przypisz profil"   = "Organization.png"
                    "Wyeksportuj dane"  = "CSV.png"
                    "Przenieś OU"       = "Organization.png"
                    "Usuń konto"        = "Remove.png"
                    "Akcje specjalne"   = "Screwdriver.png"
                }
                "Komputery"   = @{
                    "Odśwież"      = "Refresh.png"
                    "Zrestartuj"   = "Restart.png"
                    "Zablokuj"     = "Denied.png"
                    "Zmień OU"     = "Organization.png"
                    "Wyłącz konto" = "Denied.png"
                    "Wyczyść SID"  = "Refresh.png"
                    "Usuń konto"   = "Remove.png"
                    "Akcje specjalne" = "Screwdriver.png"
                }
                "Grupy"       = @{
                    "Odśwież"         = "Refresh.png"
                    "Dodaj członków"  = "Add Male User Group.png"
                    "Usuń członków"   = "Minus.png"
                    "Zmień nazwę"     = "Rename.png"
                    "Zmień typ grupy" = "Admin Settings Male.png"
                    "Zmień zakres"    = "Group Objects.png"
                    "Usuń grupę"      = "Remove.png"
                    "Akcje specjalne" = "Screwdriver.png"
                }
            }

            foreach ($section in $HT_UI.LocalADTab.Views.Keys) {
                foreach ($label in $HT_UI.LocalADTab.Views[$section].Buttons.Keys) {
                    $btn = $HT_UI.LocalADTab.Views[$section].Buttons[$label]
                    $iconFile = $icons_LocalAD[$section][$label]
                    $iconPath = Join-Path $BasePath $iconFile
                    if (Test-Path $iconPath) {
                        $btn.Image = [System.Drawing.Image]::FromFile($iconPath)
                        $btn.ImageAlign = 'MiddleLeft'
                        $btn.TextImageRelation = 'ImageBeforeText'
                        $btn.TextAlign = 'MiddleCenter'
                    }
                }
            }

        }

        # Ikony dla zakładki Logi
        if ($HT_UI.LogsTab -and $HT_UI.LogsTab.Buttons) {
            $icons_Logs = @{
                ClearLog       = "Clear Symbol.png"
                SaveLog        = "Save.png"
                CopyLog        = "Copy.png"
                ConfigLocation = "Opened Folder.png"
            }

            foreach ($key in $icons_Logs.Keys) {
                $btn = $HT_UI.LogsTab.Buttons[$key]
                if ($btn) {
                    $btn.Image = [System.Drawing.Image]::FromFile((Join-Path $BasePath $icons_Logs[$key]))
                    $btn.ImageAlign = 'MiddleLeft'
                    $btn.TextImageRelation = 'ImageBeforeText'
                    $btn.TextAlign = 'MiddleCenter'
                }
            }
        }

        # Ikony dla zakładki Settings
        if ($HT_UI.SettingsTab -and $HT_UI.SettingsTab.Buttons) {
            $icons_Settings = @{
                SaveConfig   = "Save.png"
                LoadConfig   = "Refresh.png"
            }

            foreach ($key in $icons_Settings.Keys) {
                $btn = $HT_UI.SettingsTab.Buttons[$key]
                if ($btn) {
                    $btn.Image = [System.Drawing.Image]::FromFile((Join-Path $BasePath $icons_Settings[$key]))
                    $btn.ImageAlign = 'MiddleLeft'
                    $btn.TextImageRelation = 'ImageBeforeText'
                    $btn.TextAlign = 'MiddleCenter'
                }
            }
        }

        Write-Log -Message "Ikony do GUI zostały załadowane pomyślnie." -Type "Info"
    }
    catch {
        Write-Log -Message "Nie udało się załadować ikon: $($_.Exception.Message)" -Type "Error"
    }
}

function Set-PasswordGeneratorIcons {
    try {
        # Ikony dla Generatora Haseł
        if ($HT_UI.PasswordGeneratorWindow -and $HT_UI.PasswordGeneratorWindow.Actions -and $HT_UI.PasswordGeneratorWindow.CopyButton) {
            $iconsMap_PassGen = @{
                Generate = "Password reset.png"
                Send     = "Email.png"
                Close    = "close.png"
                Copy     = "Copy.png"
            }
    
            foreach ($key in $iconsMap_PassGen.Keys) {
                $btn = $HT_UI.PasswordGeneratorWindow.Actions[$key]
                if ($btn) {
                    $btn.Image = [System.Drawing.Image]::FromFile((Join-Path $BasePath $iconsMap_PassGen[$key]))
                    $btn.ImageAlign = 'MiddleLeft'
                    $btn.TextImageRelation = 'ImageBeforeText'
                    $btn.TextAlign = 'MiddleCenter'
                }
            }
            # Osobno kopiuj
            if ($HT_UI.PasswordGeneratorWindow.CopyButton -and (Test-Path (Join-Path $BasePath $iconsMap_PassGen['Copy']))) {
                $btn = $HT_UI.PasswordGeneratorWindow.CopyButton
                $btn.Image = [System.Drawing.Image]::FromFile((Join-Path $BasePath $iconsMap_PassGen['Copy']))
                $btn.ImageAlign = 'MiddleLeft'
                $btn.TextImageRelation = 'ImageBeforeText'
                $btn.TextAlign = 'MiddleCenter'
            }
        }
        Write-Log -Message "Ikony dla Generatora Haseł zostały załadowane pomyślnie." -Type "Info"
    }
    catch {
        Write-Log -Message "Nie udało się załadować ikon dla Generatora Haseł: $($_.Exception.Message)" -Type "Error"
    }
    
}