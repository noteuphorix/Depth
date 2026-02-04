function Install-PassedWingetApp {
    param([string]$AppID)

    if ($AppID -eq "Dell.CommandUpdate" -or $AppID -eq "Dell.CommandUpdate.Universal") {
        # Trigger full upgrade instead of specific install
        Write-Host "Dell Command Update detected. Running full system upgrade..." -ForegroundColor Cyan
        Start-Process winget -ArgumentList "upgrade --all --silent --accept-source-agreements --accept-package-agreements" -Wait -PassThru -NoNewWindow
    }
    else {
        # Run the standard install for everything else
        Start-Process winget -ArgumentList "install --id $AppID --silent --accept-source-agreements --accept-package-agreements" -Wait -PassThru -NoNewWindow
    }
}