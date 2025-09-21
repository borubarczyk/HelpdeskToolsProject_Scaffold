function Initialize-HelpdeskTools {

    if (Test-ModulePresence -Name "ActiveDirectory") {
        $Global:IsModuleActiveDirectoryLoaded = $true
    }else {
            Write-Log -Message "Moduł ActiveDirectory nie jest załadowany! | Zakładka zablokowana" -Type "Warn"
            $HT_UI.Tabs["Lokalne AD"].Enabled = $false
     }
     
}
