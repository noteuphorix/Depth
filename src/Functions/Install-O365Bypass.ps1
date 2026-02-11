function Install-O365Bypass {
    Write-Host "Enabling Installer Hash Override (Admin)..." -ForegroundColor Cyan
    winget settings --enable InstallerHashOverride

    Write-Host "Spawning Non-Admin CMD..." -ForegroundColor Yellow

    # We use a simpler command string to avoid nested quote hell
    $WingetCmd = 'winget install --id Microsoft.Office --silent --accept-source-agreements --accept-package-agreements --ignore-security-hash'
    
    # 0x20000 is the standard 'Medium' (Non-Admin) trust level
    # We wrap the entire command in double quotes for runas
    $ArgList = "/trustlevel:0x20000 ""cmd.exe /k $WingetCmd"""

    try {
        Start-Process runas.exe -ArgumentList $ArgList
        Write-Host "  [OK] Non-Admin window spawned." -ForegroundColor Gray
    } catch {
        Write-Warning "Failed to spawn process: $($_.Exception.Message)"
    }

    Write-Host "`nHanded off to Standard User context." -ForegroundColor Green
}