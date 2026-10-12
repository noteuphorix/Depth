function Repair-Winget {
    Show-FunctionBanner "Winget Repair"

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    Stop-BlockingInstallerProcesses

    Write-Host "Repairing/updating Winget (App Installer + dependencies)..." -ForegroundColor Yellow
    Install-PackageProvider -Name NuGet -Force
    Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery
    Import-Module Microsoft.WinGet.Client
    Repair-WinGetPackageManager -AllUsers -Latest -Force

    Write-Host "Winget repair finished." -ForegroundColor Green
}