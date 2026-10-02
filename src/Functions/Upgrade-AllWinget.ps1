function Upgrade-AllWinget {
    Show-FunctionBanner "Full Upgrade"
    Write-Host "Running winget upgrade for all packages..." -ForegroundColor Yellow

    Stop-BlockingInstallerProcesses

    $result = Invoke-WingetProcess -ArgumentList "upgrade --all --silent --accept-source-agreements --accept-package-agreements"

    switch ($result.ExitCode) {
        0            { Write-Host "All packages upgraded successfully" -ForegroundColor Green }
        -1978335189  { Write-Host "All packages are already up to date" -ForegroundColor Cyan }
        default      { Write-Warning "winget upgrade completed with exit code: $($result.ExitCode)" }
    }

    return "Completed"
}