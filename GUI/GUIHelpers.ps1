# Reusable GUI helper functions

# Funkcja do aktualizacji tekstu przycisków połączenia
function Update-ConnectionButtonText {
    param (
        [ValidateSet("Exchange", "Graph", "SharePoint")]
        [string]$Service,
        [string]$TenantName = $null
    )

    $text = if ($TenantName) { "Rozłącz z $TenantName" } else {
        switch ($Service) {
            "Exchange"   { "Połącz z Exchange" }
            "Graph"      { "Połącz z GraphAPI" }
            "SharePoint" { "Połącz z SharePoint" }
        }
    }

    switch ($Service) {
        "Exchange"   { $HT_UI.Buttons.ConnectExchange.Text = $text
            $HT_UI.Buttons.ConnectExchange.BackColor = if ($TenantName) { "Red" } else { "White" }
        }
        "Graph"      { $HT_UI.Buttons.ConnectGraph.Text = $text
            $HT_UI.Buttons.ConnectGraph.BackColor = if ($TenantName) { "Red" } else { "White" }
        }
        "SharePoint" { $HT_UI.Buttons.ConnectSharePoint.Text = $text
            $HT_UI.Buttons.ConnectSharePoint.BackColor = if ($TenantName) { "Red" } else { "White" }
        }
    }
}
