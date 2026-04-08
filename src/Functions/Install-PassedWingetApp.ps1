function Install-PassedWingetApp {
    param([string]$AppID)

    # 1. Check if we need to run the full system upgrade first
    if ($AppID -eq "Dell.CommandUpdate" -or $AppID -eq "Dell.CommandUpdate.Universal") {
        Write-Host "Dell Command Update detected. Running full system upgrade first..." -ForegroundColor Cyan
        $upgradeResult = Start-Process winget -ArgumentList "upgrade --all --silent --accept-source-agreements --accept-package-agreements" -Wait -PassThru -NoNewWindow

        switch ($upgradeResult.ExitCode) {
            0            { Write-Host "System upgrade completed successfully" -ForegroundColor Green }
            -1978335189  { Write-Host "All packages already up to date" -ForegroundColor Cyan }
            default      { Write-Warning "System upgrade finished with exit code: $($upgradeResult.ExitCode)" }
        }
    }

    # 2. Proceed to install the requested AppID (including Dell apps)
    Write-Host "Installing package: $AppID..." -ForegroundColor Green
    $result = Start-Process winget -ArgumentList "install --id $AppID --silent --accept-source-agreements --accept-package-agreements" -Wait -PassThru -NoNewWindow

    switch ($result.ExitCode) {
        0            { Write-Host "Successfully installed $AppID" -ForegroundColor Green }
        -1978335189  { Write-Host "$AppID is already up to date" -ForegroundColor Cyan }
        default      { Write-Warning "Failed to install $AppID (Exit code: $($result.ExitCode))" }
    }

    Start-Sleep -Seconds 1
}