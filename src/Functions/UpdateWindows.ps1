function Update-Windows {
    Show-FunctionBanner "Windows Update"

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

    Write-Host "Preparing PSWindowsUpdate module..." -ForegroundColor Cyan
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Install-PackageProvider -Name NuGet -Force
        Install-Module -Name PSWindowsUpdate -Force -Repository PSGallery
    }
    Import-Module PSWindowsUpdate

    Write-Host "Checking for available updates..." -ForegroundColor Cyan
    Get-WindowsUpdate -MicrosoftUpdate

    Write-Host "Installing updates..." -ForegroundColor Cyan
    Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot

    Write-Host "Windows Update finished." -ForegroundColor Green
}