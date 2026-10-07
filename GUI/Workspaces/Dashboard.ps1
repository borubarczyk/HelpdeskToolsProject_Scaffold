# Przestrzeń robocza: Pulpit - stan usług, licencje, kondycja Microsoft 365

Register-HTWorkspace -Key 'Dashboard' -Title 'Pulpit' -Icon 'E80F' -Description 'Stan połączonych usług, licencje, kondycja Microsoft 365 i komunikaty' -Categories @('Przegląd', 'Microsoft 365', 'Program')

$script:DashboardTiles = @(
    @{ Key = 'Users'; Label = 'Użytkownicy M365'; Icon = 'E716' }
    @{ Key = 'Licenses'; Label = 'Licencje'; Icon = 'E8EC' }
    @{ Key = 'Intune'; Label = 'Urządzenia Intune'; Icon = 'E7F8' }
    @{ Key = 'Mailboxes'; Label = 'Skrzynki'; Icon = 'E715' }
    @{ Key = 'SharePoint'; Label = 'SharePoint'; Icon = 'E8F1' }
    @{ Key = 'AD'; Label = 'Zablokowane konta AD'; Icon = 'E72E' }
)

function Update-HTDashboard {
    param([Parameter(Mandatory)][hashtable]$Module)
    Invoke-HTQuery -Module $Module -Name 'Odświeżanie pulpitu' -Service '' -ScriptBlock {
        $stats = Get-HTDashboardStats
        $states = @{ Ok = @{ Tone = ''; Text = 'OK'; Flag = '' }; Warn = @{ Tone = 'warn'; Text = 'Uwaga'; Flag = 'warn' }; Error = @{ Tone = 'crit'; Text = 'Błąd'; Flag = 'crit' }; Off = @{ Tone = 'off'; Text = 'Niepołączono'; Flag = 'muted' } }
        foreach ($tile in $script:DashboardTiles) {
            $value = $stats[$tile.Key]
            if (-not $value) { continue }
            $state = $states[[string]$value.State]
            Set-HTStatTile -Module $Module -Key $tile.Key -Value $value.Value -Tone $state.Tone -Label $(if ($value.Note) { "$($tile.Label) • $($value.Note)" } else { $tile.Label })
            [PSCustomObject]@{ Obszar = $tile.Label; Wartość = $value.Value; Szczegóły = $value.Note; Stan = $state.Text; __flag = $state.Flag }
        }
        foreach ($alert in @($stats.AlertList)) {
            [PSCustomObject]@{ Obszar = 'Alert'; Wartość = ''; Szczegóły = $alert; Stan = 'Uwaga'; __flag = 'warn' }
        }
        $Module.Data.Updated = $stats.Updated
        $Module.View_.resultHint.Text = "Aktualizacja: $($stats.Updated.ToString('HH:mm:ss'))"
    }
}

Register-HTModule -Workspace 'Dashboard' -Category 'Przegląd' -Key 'dash.overview' -Title 'Przegląd' -Icon 'E80F' `
    -Description 'Najważniejsze liczby ze wszystkich połączonych usług oraz wykryte problemy (brak licencji, niezgodne urządzenia, zablokowane konta).' -Build {
    param($m)
    foreach ($t in $script:DashboardTiles) { Add-HTStatTile -Module $m -Key $t.Key -Label $t.Label -Icon $t.Icon | Out-Null }
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Odśwież' -Icon 'E72C' -Primary -OnClick { param($m) Update-HTDashboard -Module $m } | Out-Null
    Add-HTLabel -Parent $row -Hint -Text 'Połącz usługi przyciskami w prawym górnym rogu - pulpit pokaże dane z każdej połączonej usługi.' | Out-Null
    $m.EmptyText = 'Brak danych'
    $m.OnShow = { param($m) if (-not $m.Data.Updated) { Update-HTDashboard -Module $m } }
}

Register-HTModule -Workspace 'Dashboard' -Category 'Microsoft 365' -Key 'dash.licenses' -Title 'Licencje' -Icon 'E8EC' -Service 'Graph' `
    -Description 'Subskrypcje w tenancie: przypisane, dostępne i wyczerpane licencje. Prawy przycisk - lista użytkowników z licencją.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Pobierz licencje' -Icon 'E72C' -Primary -OnClick {
        param($m)
        Invoke-HTQuery -Module $m -Name 'Licencje' -ScriptBlock {
            foreach ($sku in @(Get-HTSubscribedSkus -Force | Sort-Object SkuPartNumber)) {
                [PSCustomObject]@{
                    Licencja    = Get-HTSkuFriendlyName $sku.SkuPartNumber
                    SKU         = $sku.SkuPartNumber
                    Zakupione   = $sku.Enabled
                    Przypisane  = $sku.Consumed
                    Dostępne    = $sku.Available
                    Stan        = $sku.Status
                    SkuId       = "$($sku.SkuId)"
                    __flag      = if ($sku.Status -ne 'Enabled') { 'muted' } elseif ($sku.Enabled -gt 0 -and $sku.Available -le 0) { 'warn' } else { '' }
                }
            }
        }
    } | Out-Null
    Add-HTRowAction -Module $m -Text 'Pokaż użytkowników z licencją' -Icon 'E716' -Action {
        param($m, $rows)
        $sku = @($rows)[0]
        Set-HTBusy -Busy $true -Text "Użytkownicy z licencją $($sku.SKU)…"
        try { $users = @(Get-HTSkuUsers -SkuId $sku.SkuId) } finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
        Show-HTDataViewer -Title "Licencja: $($sku.Licencja)" -Description "$($users.Count) użytkowników" -Data $users -ExportName "licencja_$($sku.SKU)"
    }
}

Register-HTModule -Workspace 'Dashboard' -Category 'Microsoft 365' -Key 'dash.health' -Title 'Kondycja usług' -Icon 'E95E' -Service 'Graph' `
    -Description 'Stan usług Microsoft 365 i otwarte incydenty (wymaga uprawnienia ServiceHealth.Read.All).' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Sprawdź' -Icon 'E72C' -Primary -OnClick { param($m) Invoke-HTQuery -Module $m -Name 'Kondycja usług' -ScriptBlock { Get-HTM365ServiceHealth } } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Centrum administracyjne' -Icon 'E8A7' -OnClick { param($m) Start-Process 'https://admin.microsoft.com/Adminportal/Home#/servicehealth' } | Out-Null
}

Register-HTModule -Workspace 'Dashboard' -Category 'Microsoft 365' -Key 'dash.messages' -Title 'Centrum wiadomości' -Icon 'E789' -Service 'Graph' `
    -Description 'Zapowiedzi zmian i komunikaty Microsoft (Message Center). Wiersze z terminem działania są wyróżnione.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m -Title 'Okres'
    Add-HTLabel -Parent $row -Text 'Ostatnie dni:' | Out-Null
    $m.C.Days = Add-HTNumeric -Parent $row -Value 30 -Minimum 1 -Maximum 365
    Add-HTButton -Parent $row -Module $m -Text 'Pobierz' -Icon 'E72C' -Primary -OnClick {
        param($m)
        $days = Get-HTNum $m.C.Days
        Invoke-HTQuery -Module $m -Name 'Centrum wiadomości' -ScriptBlock { Get-HTM365MessageCenter -Days $days }
    } | Out-Null
}

Register-HTModule -Workspace 'Dashboard' -Category 'Program' -Key 'dash.env' -Title 'Moduły i środowisko' -Icon 'E90F' -Service '' `
    -Description 'Weryfikacja pakietów: wersje PowerShell, .NET i modułów, zgodność modułów z tym PowerShell oraz konflikty bibliotek. Prawy przycisk - instalacja zgodnej lub najnowszej wersji.' -Build {
    param($m)
    $row = Add-HTToolbarRow -Module $m
    Add-HTButton -Parent $row -Module $m -Text 'Sprawdź' -Icon 'E9D9' -Primary -OnClick { param($m) Invoke-HTQuery -Module $m -Name 'Weryfikacja modułów' -ScriptBlock { Get-HTEnvironmentReport } } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Uruchom ponownie' -Icon 'E72C' -ToolTip 'Nowa sesja PowerShell - rozwiązuje konflikty bibliotek między modułami' -OnClick {
        param($m)
        if (Show-HTConfirm -Title 'Ponowne uruchomienie' -ConfirmText 'Uruchom ponownie' -Message 'Uruchomić program ponownie? Połączenia z usługami zostaną zakończone (po starcie trzeba wpisać PIN).') { Restart-HTApplication }
    } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Folder dziennika' -Icon 'E838' -OnClick { param($m) $d = Get-HTLogDirectory; if ($d -and (Test-Path $d)) { Start-Process -FilePath 'explorer.exe' -ArgumentList ('"{0}"' -f $d) } } | Out-Null
    Add-HTButton -Parent $row -Module $m -Text 'Folder eksportu' -Icon 'E838' -OnClick { param($m) Start-Process -FilePath 'explorer.exe' -ArgumentList ('"{0}"' -f (Get-HTExportDirectory)) } | Out-Null
    $m.OnShow = { param($m) if ($m.Table.Rows.Count -eq 0) { Invoke-HTQuery -Module $m -Name 'Weryfikacja modułów' -ScriptBlock { Get-HTEnvironmentReport } } }
    Add-HTRowAction -Module $m -Text 'Zainstaluj wersję zgodną z tym PowerShell' -Icon 'E896' -Action {
        param($m, $rows)
        foreach ($r in @($rows | Where-Object { $_.Moduł })) {
            Set-HTBusy -Busy $true -Text "Szukanie zgodnej wersji $($r.Moduł)…"
            try { $v = Install-HTCompatibleModule -Name $r.Moduł -OnProgress { param($text) Set-HTStatus -Text $text; Update-HTUi } }
            catch { $v = $null; Write-Log -Message "Instalacja $($r.Moduł): $($_.Exception.Message)" -Type 'Error' }
            finally { Set-HTBusy -Busy $false -Text 'Gotowe' }
            if ($v) { Show-HTToast "Zainstalowano $($r.Moduł) $v." 'ok' } else { Show-HTWarning -Title $r.Moduł -Text 'Nie znaleziono zgodnej wersji wśród ostatnich wydań - zaktualizuj PowerShell (https://aka.ms/powershell).' }
        }
        Invoke-HTModulePrimary $m
    }
    Add-HTRowAction -Module $m -Text 'Zainstaluj / zaktualizuj najnowszą wersję' -Icon 'E777' -Action {
        param($m, $rows)
        $scope = if (Test-HTIsAdministrator) { 'AllUsers' } else { 'CurrentUser' }
        Invoke-HTRowAction -Module $m -Name 'Instalacja modułu' -Service '' -Rows @($rows | Where-Object { $_.Moduł }) -Confirm "Zainstalować najnowsze wersje z PowerShell Gallery ($scope)? Najnowsza wersja może wymagać nowszego PowerShell - program wtedy użyje starszej zgodnej." `
            -Label { param($r) $r.Moduł } -Action { param($r) Install-Module -Name $r.Moduł -Scope $scope -Repository PSGallery -Force -AllowClobber -AcceptLicense -ErrorAction Stop } -Refresh { param($m) Invoke-HTModulePrimary $m }
    }
}
