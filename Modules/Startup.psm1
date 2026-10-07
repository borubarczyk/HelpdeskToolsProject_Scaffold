# Inicjalizacja aplikacji po zbudowaniu interfejsu

# Sprawdza dostępność lokalnego Active Directory (moduł RSAT) i aktualizuje stan w nagłówku
function Initialize-HTActiveDirectory {
    if (Test-HTADAvailable) {
        $Global:IsModuleActiveDirectoryLoaded = $true
        $domain = $null
        try { $domain = (Get-ADDomain -ErrorAction Stop).DNSRoot }
        catch {
            Write-Log -Message "Moduł ActiveDirectory jest dostępny, ale nie udało się połączyć z domeną: $($_.Exception.Message)" -Type "Warn"
        }
        $label = if ($domain) { $domain } else { "moduł załadowany" }
        Update-ConnectionButtonText -Service "AD" -TenantName $label
        Write-Log -Message "Active Directory: $label" -Type "Info"
    }
    else {
        $Global:IsModuleActiveDirectoryLoaded = $false
        Update-ConnectionButtonText -Service "AD"
        Write-Log -Message "Moduł ActiveDirectory nie jest dostępny (zainstaluj RSAT) - funkcje AD są niedostępne." -Type "Warn"
    }
}

function Initialize-HelpdeskTools {
    Initialize-HTActiveDirectory

    # Połączenia pozostałe z poprzedniej sesji w tym samym procesie PowerShell
    try { Set-Connections -Action "Check" } catch { Write-Log -Message "Sprawdzanie połączeń: $($_.Exception.Message)" -Type "Warn" }

    Show-HTWorkspace -Key "Dashboard"
    Set-HTStatus -Text "Gotowe"
}
