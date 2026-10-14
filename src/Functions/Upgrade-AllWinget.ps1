function Upgrade-AllWinget {
    Show-FunctionBanner "Full Upgrade"

    # App Installer's upgrade won't finish until the device restarts, which hangs upgrade --all.
    # Pin it so upgrade --all skips it, then unpin it once the upgrade is done.
    Write-Host "Pinning App Installer so the upgrade skips it..." -ForegroundColor Cyan
    winget pin add --id Microsoft.AppInstaller --exact --force --accept-source-agreements --disable-interactivity | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning ("Couldn't pin App Installer (exit code 0x{0:X8}), it may be included in the upgrade." -f $LASTEXITCODE)
    }

    try {
        Write-Host "Running winget upgrade for all packages..." -ForegroundColor Yellow

        Stop-BlockingInstallerProcesses

        $result = Invoke-WingetProcess -ArgumentList "upgrade --all --silent --accept-source-agreements --accept-package-agreements"

        switch ($result.ExitCode) {
            0            { Write-Host "All packages upgraded successfully" -ForegroundColor Green }
            -1978335189  { Write-Host "All packages are already up to date" -ForegroundColor Cyan }
            default      { Write-Warning "winget upgrade completed with exit code: $($result.ExitCode)" }
        }
    } finally {
        Write-Host "Unpinning App Installer..." -ForegroundColor Cyan
        winget pin remove --id Microsoft.AppInstaller --exact --disable-interactivity | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning ("Couldn't unpin App Installer (exit code 0x{0:X8}). Remove it with: winget pin remove --id Microsoft.AppInstaller" -f $LASTEXITCODE)
        }
    }

    return "Completed"
}
