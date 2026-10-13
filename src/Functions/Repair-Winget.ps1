function Repair-Winget {
    Show-FunctionBanner "Winget Repair"

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    try {
        $step = "Closing blocking processes"
        Write-Host "Closing processes that can block the App Installer update..." -ForegroundColor Cyan
        Stop-BlockingInstallerProcesses

        $step = "Installing NuGet package provider"
        Write-Host "Step 1/4: Installing NuGet package provider..." -ForegroundColor Cyan
        Install-PackageProvider -Name NuGet -Force -ErrorAction Stop

        $step = "Installing Microsoft.WinGet.Client module"
        Write-Host "Step 2/4: Installing Microsoft.WinGet.Client module from PSGallery..." -ForegroundColor Cyan
        Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery -ErrorAction Stop

        $step = "Importing Microsoft.WinGet.Client module"
        Write-Host "Step 3/4: Importing Microsoft.WinGet.Client module..." -ForegroundColor Cyan
        Import-Module Microsoft.WinGet.Client -ErrorAction Stop

        $step = "Repairing Winget"
        Write-Host "Step 4/4: Repairing Winget and updating App Installer to the latest version..." -ForegroundColor Yellow
        Repair-WinGetPackageManager -AllUsers -Latest -Force -Verbose -ErrorAction Stop

        Write-Host "Winget repair finished." -ForegroundColor Green
    }
    catch {
        Write-Host "Winget repair FAILED at: $step" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Command: $($_.InvocationInfo.Line.Trim())" -ForegroundColor Red
    }
}