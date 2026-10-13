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
        # Repair-WinGetPackageManager installs App Installer through synchronous Add-AppxPackage /
        # Add-AppxProvisionedPackage calls with no cancellation, and the deployment itself runs inside
        # AppXSvc. Killing a separate Start-Job process didn't stop that deployment, so App Installer
        # kept installing while this function reported success and moved on. Instead the repair runs
        # on a second runspace INSIDE this process, and this function blocks on it under a 3-minute
        # timer (relaying verbose output live). If App Installer is stuck behind pending Windows
        # Updates, the repair and the AppX deployment are both cancelled before Windows Update runs.
        $deadline = (Get-Date).AddMinutes(3)

        $handleStuck = {
            Write-Host "WARNING: App Installer is stuck, Windows Updates are required!" -ForegroundColor Red
            # Stopping AppXSvc cancels the in-flight App Installer deployment; it restarts on demand.
            try { Stop-Service -Name AppXSvc -Force -ErrorAction Stop } catch {}
            Write-Host "Running Windows Update now. The device will restart once updates finish installing." -ForegroundColor Red
            Update-Windows -AutoReboot
        }

        $repair = [powershell]::Create()
        $repair.AddScript({
            Import-Module Microsoft.WinGet.Client -ErrorAction Stop
            Repair-WinGetPackageManager -AllUsers -Latest -Force -Verbose -ErrorAction Stop
        }) | Out-Null
        $handle = $repair.BeginInvoke()

        # The repair runspace has no host, so relay its verbose, warning and information output to
        # the terminal (the same streams Receive-Job used to show from the old job).
        $relayed = 0
        $relayedWarnings = 0
        $relayedInfo = 0
        $relayVerbose = {
            while ($relayed -lt $repair.Streams.Verbose.Count) {
                Write-Host $repair.Streams.Verbose[$relayed].Message
                $relayed++
            }
            while ($relayedWarnings -lt $repair.Streams.Warning.Count) {
                Write-Host "WARNING: $($repair.Streams.Warning[$relayedWarnings].Message)" -ForegroundColor Yellow
                $relayedWarnings++
            }
            while ($relayedInfo -lt $repair.Streams.Information.Count) {
                Write-Host $repair.Streams.Information[$relayedInfo].MessageData
                $relayedInfo++
            }
        }

        while (-not $handle.IsCompleted -and (Get-Date) -lt $deadline) {
            . $relayVerbose
            Start-Sleep -Seconds 2
        }
        . $relayVerbose

        if (-not $handle.IsCompleted) {
            # BeginStop rather than Stop/Dispose - Add-AppxPackage may not honour a stop request
            # until AppXSvc is stopped, and a synchronous Stop would hang here.
            $repair.BeginStop($null, $null) | Out-Null
            & $handleStuck
            return
        }

        # Finished in time - a failure inside the repair is rethrown into the catch below.
        try {
            $repair.EndInvoke($handle) | Out-Null
        } finally {
            $repair.Dispose()
        }

        # Don't report success until App Installer has actually settled and winget works, still
        # bound by the same 3-minute timer.
        $step = "Verifying Winget"
        while ($true) {
            $appInstaller = @(Get-AppxPackage -Name Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue)
            $settled = $appInstaller.Count -gt 0 -and -not ($appInstaller | Where-Object { $_.Status -ne 'Ok' })
            if ($settled) {
                try {
                    Assert-WinGetPackageManager -ErrorAction Stop
                    break
                } catch {}
            }

            if ((Get-Date) -ge $deadline) {
                & $handleStuck
                return
            }
            Start-Sleep -Seconds 5
        }

        Write-Host "Winget repair finished. Version: $(Get-WinGetVersion)" -ForegroundColor Green
    }
    catch {
        Write-Host "Winget repair FAILED at: $step" -ForegroundColor Red
        # EndInvoke wraps errors from the repair runspace - show the underlying message.
        $err = $_.Exception
        while ($err.InnerException) { $err = $err.InnerException }
        Write-Host "Error: $($err.Message)" -ForegroundColor Red
        Write-Host "Command: $($_.InvocationInfo.Line.Trim())" -ForegroundColor Red
    }
}