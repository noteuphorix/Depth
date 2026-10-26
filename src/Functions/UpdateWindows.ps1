function Update-Windows {
    # -AutoReboot restarts the machine once updates install (if they need a reboot) instead of
    # suppressing it. Repair-Winget uses this when App Installer is stuck.
    param([switch]$AutoReboot)

    Show-FunctionBanner "Windows Update"

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

    # Windows Update can fail partway through (e.g. 0x80248007 when an update's data disappears
    # mid-run, or "Value does not fall within the expected range.") and a fresh run usually gets
    # past it. Retry with the same flags up to 5 times.
    $maxAttempts = 5
    $maxRounds = 5

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

            # Updates arrive in layers (servicing stack -> cumulative -> .NET etc.), so keep checking
            # and installing until nothing is left. A pending reboot is checked first because
            # Get-WindowsUpdate can come back empty while one is pending, which isn't "up to date".
            for ($round = 1; $round -le $maxRounds; $round++) {
                if (Get-WURebootStatus -Silent) {
                    Write-Host "Restart required before more updates can be found. Restarting in ten seconds." -ForegroundColor White -BackgroundColor DarkRed
                    shutdown /f /t 10 /r
                    return
                }

                Write-Host "Checking for available updates (round $round/$maxRounds)..." -ForegroundColor Cyan
                # Get-WindowsUpdate outputs its results as one list object, so unroll it to count updates.
                $updates = @(Get-WindowsUpdate -MicrosoftUpdate | ForEach-Object { $_ })
                if ($updates.Count -eq 0) {
                    Write-Host "Windows is up to date." -ForegroundColor Green
                    return
                }
                $updates | Format-Table -AutoSize | Out-String | Write-Host

                Write-Host "Installing $($updates.Count) update(s)..." -ForegroundColor Cyan
                if ($AutoReboot) {
                    Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot | Format-Table -AutoSize | Out-String | Write-Host
                } else {
                    Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot | Format-Table -AutoSize | Out-String | Write-Host
                }

                # Give Windows Update time to settle before the next scan.
                if ($round -lt $maxRounds) {
                    Write-Host "Waiting 30 seconds before checking for more updates..." -ForegroundColor Cyan
                    Start-Sleep -Seconds 30
                }
            }

            Write-Host "Still finding updates after $maxRounds rounds. Run Windows Update again." -ForegroundColor Yellow
            return
        } catch {
            Write-Host "Windows Update attempt $attempt/$maxAttempts failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-ErrorDetails $_

            # Windows Update can get stuck in a state where every scan fails (e.g. after some driver
            # updates). Resetting the Windows Update components clears it, so the next attempt can scan.
            if ($attempt -lt $maxAttempts) {
                Write-Host "Resetting Windows Update components before the next attempt..." -ForegroundColor Yellow
                try {
                    Reset-WUComponents
                } catch {
                    Write-Host "Reset-WUComponents failed:" -ForegroundColor Red
                    Write-ErrorDetails $_
                }
            }
        }
    }

    # Success returns inside the loop, so reaching this point means every attempt failed.
    # A restart often clears whatever is blocking Windows Update.
    Write-Host "`nWindows Update failed $maxAttempts times in a row (see errors above)." -ForegroundColor Red
    Write-Host "Windows Update failing, restarting in ten seconds." -ForegroundColor White -BackgroundColor DarkRed
    shutdown /f /t 10 /r
}