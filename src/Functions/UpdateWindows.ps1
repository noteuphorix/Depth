function Update-Windows {
    Show-FunctionBanner "Windows Update"

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

    Write-Host "Preparing PSWindowsUpdate module..." -ForegroundColor Cyan
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Host "PSWindowsUpdate module not found, installing the NuGet provider and PSWindowsUpdate from PSGallery..." -ForegroundColor Red
        Install-PackageProvider -Name NuGet -Force
        Install-Module -Name PSWindowsUpdate -Force -Repository PSGallery
        Write-Host "PSWindowsUpdate module installed." -ForegroundColor Green
    }
    Import-Module PSWindowsUpdate

    Write-Host "Checking for available updates..." -ForegroundColor Cyan
    Get-WindowsUpdate -MicrosoftUpdate

    Write-Host "Installing updates..." -ForegroundColor Cyan
    Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot

    Write-Host "Windows Update finished." -ForegroundColor Green
}