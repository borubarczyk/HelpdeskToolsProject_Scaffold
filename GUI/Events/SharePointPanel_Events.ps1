$HT_UI.SharePointTab.Actions.Refresh.Add_Click({
    Write-Log -Message "Odświeżanie drzewa SharePoint..." -Type "Info"

    try {
        $HT_UI.SharePointTab.TreeView.Nodes.Clear()

        $siteUrl = $HT_UI.SharePointTab.SiteBox.Text.Trim()
        if (-not $siteUrl) {
            Show-Dialog -Message "Proszę podać adres URL witryny SharePoint." -Title "Błąd" -Type "Error"
            return
        }

        $structure = Get-FolderRecursive -SiteUrl $siteUrl -AsTree
        $nodes = Convert-FolderStructureToTreeNodes -Structure $structure
        $HT_UI.SharePointTab.TreeView.Nodes.AddRange($nodes)

        Write-Log -Message "Drzewo SharePoint zostało odświeżone." -Type "Info"
    }
    catch {
        Write-Log -Message "Błąd podczas odświeżania drzewa SharePoint: $_" -Type "Error&Notification"
        Show-Dialog -Message "Błąd podczas odświeżania drzewa SharePoint: $_" -Title "Błąd" -Type "Error"
    }
})
