function Repair-Winget {
    Show-FunctionBanner "Winget Repair"

    # `winget source update --name msstore` always reports success (msstore is queried live, so
    # there's nothing to update), so instead look up App Installer's own Store ID on msstore. This
    # fails exactly when installs without --source fail on msstore. Prints winget's output on failure.
    function Test-MsStoreSource {
        # If winget.exe can't launch at all, PowerShell throws instead of setting an exit code.
        # Treat that as a failed check so the repair still runs.
        try {
            $output = winget show --id 9NBLGGH4NNS1 --source msstore --exact --accept-source-agreements --disable-interactivity 2>&1
        } catch {
            Write-Host "msstore source check failed (winget couldn't be launched):" -ForegroundColor White -BackgroundColor DarkRed
            Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
        if ($LASTEXITCODE -eq 0) { return $true }

        Write-Host ("msstore source check failed (winget exit code 0x{0:X8}):" -f $LASTEXITCODE) -ForegroundColor White -BackgroundColor DarkRed
        $output | ForEach-Object { "$_".Trim() } | Where-Object { $_ } | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        return $false
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    $repairFailed = $false
    try {
        # Only repair when it's actually needed: winget missing, or the msstore source failing.
        $step = "Checking Winget"
        $wingetInstalled = [bool](Get-Command winget -ErrorAction SilentlyContinue)
        if ($wingetInstalled) {
            Write-Host "Winget is installed. Checking the msstore source..." -ForegroundColor Cyan
            if (Test-MsStoreSource) {
                Write-Host "Winget and the msstore source are working, no repair needed. Version: $(winget --version)" -ForegroundColor Green
                return
            }
        } else {
            Write-Host "Winget is not installed." -ForegroundColor White -BackgroundColor DarkRed
        }

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

        if (-not $wingetInstalled) {
            # A plain repair (no -Latest) installs winget when it's missing.
            $step = "Installing Winget"
            Write-Host "Step 4/4: Installing Winget..." -ForegroundColor Yellow
            Repair-WinGetPackageManager -AllUsers -ErrorAction Stop
            Write-Host "Winget installed. Version: $(Get-WinGetVersion)" -ForegroundColor Green
            return
        }

        $step = "Repairing Winget"
        Write-Host "Step 4/4: Repairing Winget and updating App Installer to the latest version (5 minute limit)..." -ForegroundColor Yellow
        # A blocking cmdlet can't be timed out on its own thread, so the repair runs on a second
        # PowerShell instance and we wait up to 5 minutes for it.
        $repair = [powershell]::Create().AddScript({
            Import-Module Microsoft.WinGet.Client -ErrorAction Stop
            Repair-WinGetPackageManager -Force -Latest -ErrorAction Stop
        })
        $handle = $repair.BeginInvoke()

        if ($handle.AsyncWaitHandle.WaitOne([TimeSpan]::FromMinutes(5))) {
            # Finished in time. An error here (e.g. a version mismatch) doesn't mean winget is broken,
            # so it's only printed - the re-check below decides whether Windows Updates are needed.
            try {
                $repair.EndInvoke($handle) | Out-Null
            } catch {
                Write-Host "Repair-WinGetPackageManager failed:" -ForegroundColor White -BackgroundColor DarkRed
                Write-ErrorDetails $_
            } finally {
                # The repair can report its error here instead of throwing.
                foreach ($record in $repair.Streams.Error) {
                    Write-Host "Repair-WinGetPackageManager reported an error:" -ForegroundColor White -BackgroundColor DarkRed
                    Write-ErrorDetails $record
                }
                $repair.Dispose()
            }
        } else {
            Write-Host "Repair-WinGetPackageManager was still running after 3 minutes, stopping it." -ForegroundColor White -BackgroundColor DarkRed
            $repair.BeginStop($null, $null) | Out-Null
            # Don't mark the repair as failed yet. Fall through to the msstore re-check below. If that
            # check also fails, the Windows Update and restart path runs.
        }

        # Re-run the same check as the start: if winget or msstore still doesn't work after the
        # repair, Windows Updates are needed.
        if (-not $repairFailed) {
            $step = "Verifying Winget"
            Write-Host "Re-checking Winget and the msstore source..." -ForegroundColor Cyan
            if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
                Write-Host "Winget still isn't installed after the repair." -ForegroundColor White -BackgroundColor DarkRed
                $repairFailed = $true
            }
        }
        if (-not $repairFailed) {
            $step = "Verifying the msstore source"
            if (-not (Test-MsStoreSource)) {
                Write-Host "The msstore source still isn't working after the repair." -ForegroundColor White -BackgroundColor DarkRed
                $repairFailed = $true
            }
        }

        if (-not $repairFailed) {
            Write-Host "Winget repair finished. Version: $(Get-WinGetVersion)" -ForegroundColor Green
            return
        }
    }
    catch {
        Write-Host "Winget repair FAILED at: $step" -ForegroundColor White -BackgroundColor DarkRed
        Write-ErrorDetails $_
        # Rethrow so Run Selected stops instead of moving on to the next selection.
        throw
    }

    # Outside the try above so Update-Windows reports its own messages and errors.
    Write-Host "WARNING: App Installer is stuck, Windows Updates are required!" -ForegroundColor White -BackgroundColor DarkRed
    Write-Host "Running Windows Update now. The device will restart once updates finish installing." -ForegroundColor White -BackgroundColor DarkRed
    Update-Windows -AutoReboot
    # -AutoReboot only restarts when an update asks for it, but App Installer needs a restart either way.
    Write-Host "Restarting now to finish the App Installer update." -ForegroundColor White -BackgroundColor DarkRed
    shutdown /f /t 0 /r
    # Still a failed repair - stop Run Selected from moving on to the next selection.
    throw "Winget repair failed."
}
