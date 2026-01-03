# --- Function from SwitchTabs.ps1 ---
function Switch-Tabs {
    param([string]$Target)

    # 1. Exit if already on the target to prevent flickering
    if ($Target -eq "Deployment" -and $Deployment_Grid.Visibility -eq "Visible") { return }
    if ($Target -eq "Tools" -and $Tools_Grid.Visibility -eq "Visible") { return }

    # This ensures only one grid is active at a time
    $Deployment_Grid.Visibility = "Collapsed"
    $Tools_Grid.Visibility      = "Collapsed"

    # 3. Show only the target grid
    switch ($Target) {
        "Deployment" { $Deployment_Grid.Visibility = "Visible" }
        "Tools"      { $Tools_Grid.Visibility      = "Visible" }
    }
}