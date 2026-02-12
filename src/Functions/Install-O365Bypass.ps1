function Install-O365Bypass {
    Write-Host "Enabling Installer Hash Override..." -ForegroundColor Cyan
    winget settings --enable InstallerHashOverride

    # Get the current logged-in username
    $CurrentUser = $env:USERNAME
    
    Write-Host "Spawning Winget as $CurrentUser (Non-Admin context)..." -ForegroundColor Yellow

    $WingetCmd = "winget install Microsoft.Office --silent --ignore-security-hash --accept-source-agreements --accept-package-agreements"
    
    # We use 'cmd /c' to run the command and then close
    $ArgList = "/user:$CurrentUser `"cmd.exe /c $WingetCmd`""

    try {
        # This will likely ask for your password or pin in the console
        # but it will result in a User-level process that Winget won't block.
        Start-Process "runas.exe" -ArgumentList $ArgList
        Write-Host "  [OK] Process started. If a password was required, enter it in the new window." -ForegroundColor Green
    } catch {
        Write-Warning "Failed to spawn: $($_.Exception.Message)"
    }
}