function Install-PassedWingetApp {
    param([string]$AppID)

    # 1. Check if we need to run the full system upgrade first
    if ($AppID -eq "Dell.CommandUpdate" -or $AppID -eq "Dell.CommandUpdate.Universal") {
        Write-Host "Dell Command Update detected. Running full system upgrade first..." -ForegroundColor Cyan
        Start-Process winget -ArgumentList "upgrade --all --silent --accept-source-agreements --accept-package-agreements" -Wait -PassThru -NoNewWindow
    }

    # 2. Proceed to install the requested AppID (including Dell apps)
    Write-Host "Installing package: $AppID..." -ForegroundColor Green
    Start-Process winget -ArgumentList "install --id $AppID --silent --accept-source-agreements --accept-package-agreements" -Wait -PassThru -NoNewWindow
    Start-Sleep -Seconds 1
}