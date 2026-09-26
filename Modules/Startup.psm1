# Inicjalizacja aplikacji po zbudowaniu interfejsu
function Initialize-HelpdeskTools {

    # Lokalne Active Directory
    if (Test-HTADAvailable) {
        $Global:IsModuleActiveDirectoryLoaded = $true
        $domain = $null
        try { $domain = (Get-ADDomain -ErrorAction Stop).DNSRoot } catch {
            Write-Log -Message "Moduł ActiveDirectory jest dostępny, ale nie udało się połączyć z domeną: $($_.Exception.Message)" -Type "Warn"
        }
        $label = if ($domain) { $domain } else { "moduł załadowany" }
        Update-ConnectionButtonText -Service "AD" -TenantName $label
        Write-Log -Message "Active Directory: $label" -Type "Info"
    }
    else {
        $Global:IsModuleActiveDirectoryLoaded = $false
        Update-ConnectionButtonText -Service "AD"
        Write-Log -Message "Moduł ActiveDirectory nie jest dostępny (zainstaluj RSAT) | Zakładka zablokowana" -Type "Warn"
        Set-HTSectionEnabled -Name "Lokalne AD" -Enabled $false -Reason "Wymaga modułu ActiveDirectory (RSAT)."
    }

    # Połączenia pozostałe z poprzedniej sesji w tym samym procesie PowerShell
    try { Set-Connections -Action "Check" } catch { Write-Log -Message "Sprawdzanie połączeń: $($_.Exception.Message)" -Type "Warn" }

    Show-HTSection -Name "Dashboard"
    Set-HTStatus -Text "Gotowe"
}
