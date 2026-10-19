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
    # Exception: "Value does not fall within the expected range." is a persistent error that
    # retrying doesn't fix, so it skips the remaining retries and goes straight to the restart.
    $maxAttempts = 5
    $skipToRestart = $false

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
            $msg = $_.Exception.Message
            Write-Host "Windows Update attempt $attempt/$maxAttempts failed: $msg" -ForegroundColor Red

            # -like with wildcards so a trailing period or extra text around the message still matches.
            if ($msg -like "*Value does not fall within the expected range*") {
                Write-Host "Detected 'Value does not fall within the expected range'. Skipping remaining retries." -ForegroundColor Yellow
                $skipToRestart = $true
                break
            }
        }
    }

    # Success returns inside the loop, so reaching this point means every attempt failed
    # or we bailed out early on the non-retryable error.
    if ($skipToRestart) {
        Write-Host "`nRestarting now to clear the Windows Update error." -ForegroundColor Red
    } else {
        Write-Host "`nWindows Update failed $maxAttempts times in a row. Forcing a restart now." -ForegroundColor Red
    }
    shutdown /f /t 0 /r
}