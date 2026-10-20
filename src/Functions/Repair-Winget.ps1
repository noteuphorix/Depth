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

    # Only runs once winget is missing or msstore is failing.
    function Install-WinGetClientModule {
        Write-Host "Closing processes that can block the App Installer update..." -ForegroundColor Cyan
        Stop-BlockingInstallerProcesses
        Write-Host "Installing NuGet provider and Microsoft.WinGet.Client module..." -ForegroundColor Cyan
        Install-PackageProvider -Name NuGet -Force -ErrorAction Stop
        Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery -ErrorAction Stop
    }

    # Runs Repair-WinGetPackageManager in a child PowerShell sharing this console, so its output and
    # progress bar show the same as running it bare, and kills it after $Minutes (-AllUsers can hang).
    # Returns $true if it finished in time, else $false.
    function Invoke-WinGetRepair {
        param([string]$Arguments, [int]$Minutes)
        Write-Host "Running: Repair-WinGetPackageManager $Arguments ($Minutes minute limit)" -ForegroundColor Cyan
        $command = "Import-Module Microsoft.WinGet.Client -ErrorAction Stop; Repair-WinGetPackageManager $Arguments -ErrorAction Stop"
        $proc = Start-Process (Get-Process -Id $PID).Path -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $command -NoNewWindow -PassThru
        $null = $proc.Handle # Without this, ExitCode is empty after the process exits.
        if (-not $proc.WaitForExit($Minutes * 60000)) {
            Write-Host "Repair-WinGetPackageManager was still running after $Minutes minutes, stopping it." -ForegroundColor White -BackgroundColor DarkRed
            $proc.Kill()
            return $false
        }
        if ($proc.ExitCode -ne 0) {
            # An error here (e.g. a version mismatch) doesn't mean winget is broken - the msstore
            # check afterwards decides that.
            Write-Host "Repair-WinGetPackageManager exited with code $($proc.ExitCode)." -ForegroundColor White -BackgroundColor DarkRed
        }
        return $true
    }

    function Restart-ForRepair {
        param([string]$Reason, [int]$Delay)
        Write-Host "RESTART NEEDED: $Reason" -ForegroundColor White -BackgroundColor DarkRed
        shutdown /f /t $Delay /r
        # Stop Run Selected from moving on to the next selection.
        throw "Winget repair needs a restart: $Reason"
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    # 1) Staged updates (e.g. an App Installer update waiting on other users) only apply after a restart.
    $pendingKeys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )
    if ($pendingKeys | Where-Object { Test-Path $_ }) {
        Restart-ForRepair "updates are pending a restart." 10
    }

    try {
        $moduleReady = $false

        # 2) Winget missing: install it.
        $step = "Installing Winget"
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Host "Winget is not installed. Installing..." -ForegroundColor Yellow
            Install-WinGetClientModule
            $moduleReady = $true
            if (-not (Invoke-WinGetRepair "-AllUsers -Force" 5)) {
                Restart-ForRepair "the Winget install timed out." 0
            }
        }

        # 3) Winget installed but msstore failing (App Installer out of date).
        $step = "Checking the msstore source"
        Write-Host "Checking the msstore source..." -ForegroundColor Cyan
        if (Test-MsStoreSource) {
            Write-Host "Winget and the msstore source are working. Version: $(winget --version)" -ForegroundColor Green
            return
        }

        $step = "Repairing Winget"
        if (-not $moduleReady) { Install-WinGetClientModule }
        Write-Host "Updating App Installer to the latest version..." -ForegroundColor Yellow
        # -AllUsers provisions the update but ignores -Force, so it can't close processes holding
        # App Installer. The second run (current user, -Force) closes them and registers it now.
        Invoke-WinGetRepair "-AllUsers -Latest" 5 | Out-Null
        Invoke-WinGetRepair "-Latest -Force" 5 | Out-Null

        $step = "Resetting winget sources"
        Write-Host "Running: winget source reset --force" -ForegroundColor Cyan
        winget source reset --force

        $step = "Verifying the msstore source"
        Write-Host "Re-checking the msstore source..." -ForegroundColor Cyan
        if (Test-MsStoreSource) {
            Write-Host "Winget repair finished. Version: $(winget --version)" -ForegroundColor Green
            return
        }
    }
    catch {
        Write-Host "Winget repair FAILED at: $step" -ForegroundColor White -BackgroundColor DarkRed
        Write-ErrorDetails $_
        # Rethrow so Run Selected stops instead of moving on to the next selection.
        throw
    }

    # Outside the try so this throw isn't reported as a failed step.
    Write-Host "Repair failed, restart may be needed." -ForegroundColor White -BackgroundColor DarkRed
    # Stop Run Selected from moving on to the next selection.
    throw "Winget repair failed."
}
