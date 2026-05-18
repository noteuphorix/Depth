function Upgrade-AllWinget {
    Show-FunctionBanner "Full Upgrade"
    Write-Host "Running winget upgrade for all packages..." -ForegroundColor Yellow
    $upgradeResult = Start-Process winget -ArgumentList "upgrade --all --silent --accept-source-agreements --accept-package-agreements" -Wait -PassThru -NoNewWindow

    switch ($upgradeResult.ExitCode) {
        0       { Write-Host "All packages upgraded successfully" -ForegroundColor Green }
        default { Write-Warning "winget upgrade completed with exit code: $($upgradeResult.ExitCode)" }
    }

    return "Completed"
}