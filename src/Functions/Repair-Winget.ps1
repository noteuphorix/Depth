function Repair-Winget {
    # 0. Try to let Winget fix its own dependency first
    Write-Host "Attempting to install WindowsAppRuntime 1.8 via Winget..." -ForegroundColor Yellow
    winget install Microsoft.WindowsAppRuntime.1.8 --source winget --accept-package-agreements --accept-source-agreements --nowarn

    Write-Host "Checking for AppInstaller updates..." -ForegroundColor Cyan
    
    $Url = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
    $Path = "$env:TEMP\WingetUpdate.msixbundle"

    try {
        # 1. Kill processes using the package to avoid HRESULT: 0x80073D02
        Write-Host "Closing active AppInstaller processes..." -ForegroundColor Yellow
        $AppInstallerPackage = Get-AppxPackage -Name "Microsoft.DesktopAppInstaller"
        if ($AppInstallerPackage) {
            # Find and stop processes associated with this package
            Get-Process | Where-Object { $_.Path -like "*$($AppInstallerPackage.Name)*" } | Stop-Process -Force -ErrorAction SilentlyContinue
            # Also kill winget.exe specifically just in case
            Stop-Process -Name "winget" -Force -ErrorAction SilentlyContinue
        }

        # 2. Download the latest bundle
        Write-Host "Downloading latest AppInstaller bundle..." -ForegroundColor Yellow
        $oldPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $Path -UseBasicParsing
        

        # 3. Force install the package
        Write-Host "Installing latest Winget..." -ForegroundColor Yellow
        # We use -ForceApplicationShutdown as an extra safety measure
        Add-AppxPackage -Path $Path -ForceApplicationShutdown -ErrorAction Stop
        $ProgressPreference = $oldPreference
        
        Write-Host "Winget is now updated and ready." -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to update Winget: $($_.Exception.Message)"
    }
    finally {
        if (Test-Path $Path) { Remove-Item $Path -Force }
    }
}