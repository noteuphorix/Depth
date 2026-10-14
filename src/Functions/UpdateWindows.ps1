function Update-Windows {
    # -AutoReboot restarts the machine once updates install (if they need a reboot) instead of
    # suppressing it. Repair-Winget uses this when App Installer is stuck.
    param([switch]$AutoReboot)

    Show-FunctionBanner "Windows Update"

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

    # Windows Update can fail partway through (e.g. 0x80248007 when an update's data disappears
    # mid-run) and a fresh run usually gets past it. Retry with the same flags up to 10 times,
    # then force a restart.
    $maxAttempts = 10
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        if ($attempt -gt 1) {
            Write-Host "`nRetrying Windows Update (attempt $attempt/$maxAttempts)..." -ForegroundColor Yellow
        }

        try {
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
            if ($AutoReboot) {
                Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot
            } else {
                Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot
            }

            Write-Host "Windows Update finished." -ForegroundColor Green
            return
        } catch {
            Write-Host "Windows Update attempt $attempt/$maxAttempts failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    Write-Host "`nWindows Update failed $maxAttempts times in a row. Forcing a restart now." -ForegroundColor Red
    shutdown /f /t 0 /r
}
