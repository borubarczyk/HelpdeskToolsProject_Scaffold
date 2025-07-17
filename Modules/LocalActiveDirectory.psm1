# Active Directory functions# === Odśwież dane z AD ===
function Invoke-LocalADRefresh {
    try {
        $section = $HT_UI.LocalADTab.SectionBox.SelectedItem
        if (-not $section) {
            Write-Log -Message "⚠️ Wybierz sekcję (Użytkownicy, Komputery, Grupy)!" -Type "Warn"
            return
        }

        Write-Log -Message "🔄 Odświeżanie: $section ..." -Type "Info"

        switch ($section) {
            "Użytkownicy" {
                $Global:LocalAD_Objects = Get-ADUser -Filter * |
                    Select-Object -ExpandProperty SamAccountName |
                    ForEach-Object { $_.Trim() }
            }
            "Komputery" {
                $Global:LocalAD_Objects = Get-ADComputer -Filter * |
                    Select-Object -ExpandProperty Name |
                    ForEach-Object { $_.Trim() }
            }
            "Grupy" {
                $Global:LocalAD_Objects = Get-ADGroup -Filter * |
                    Select-Object -ExpandProperty Name |
                    ForEach-Object { $_.Trim() }
            }
            default {
                Write-Log -Message "⚠️ Nieobsługiwana sekcja: $section" -Type "Warn"
                return
            }
        }

        $HT_UI.LocalADTab.ObjectBox.Items.Clear()
        $HT_UI.LocalADTab.ObjectBox.Items.AddRange($Global:LocalAD_Objects)

        $HT_UI.LocalADTab.DetailsBox.Clear()

        Write-Log -Message "✅ Załadowano: $($Global:LocalAD_Objects.Count) obiektów." -Type "Info&Notification"
    }
    catch {
        Write-Log -Message "❌ Błąd odświeżania: $_" -Type "Error"
    }
}