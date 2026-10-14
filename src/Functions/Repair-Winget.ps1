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
        Write-Host "Step 4/4: Repairing Winget and updating App Installer to the latest version (3 minute limit)..." -ForegroundColor Yellow
        # A blocking cmdlet can't be timed out on its own thread, so the repair runs on a second
        # PowerShell instance and we wait up to 3 minutes for it.
        $repair = [powershell]::Create().AddScript({
            Import-Module Microsoft.WinGet.Client -ErrorAction Stop
            Repair-WinGetPackageManager -AllUsers -Latest -Force -ErrorAction Stop
        })
        $handle = $repair.BeginInvoke()

        $repairFailed = $false
        if ($handle.AsyncWaitHandle.WaitOne([TimeSpan]::FromMinutes(3))) {
            # Finished in time - if the repair errored out, Windows Updates are needed too.
            try {
                $repair.EndInvoke($handle) | Out-Null
            } catch {
                $err = $_.Exception
                while ($err.InnerException) { $err = $err.InnerException }
                Write-Host "Repair-WinGetPackageManager failed: $($err.Message)" -ForegroundColor Red
                $repairFailed = $true
            } finally {
                $repair.Dispose()
            }
        } else {
            $repair.BeginStop($null, $null) | Out-Null
            $repairFailed = $true
        }

        if ($repairFailed) {
            Write-Host "WARNING: App Installer is stuck, Windows Updates are required!" -ForegroundColor Red
            Write-Host "Running Windows Update now. The device will restart once updates finish installing." -ForegroundColor Red
            $step = "Windows Update (after Winget repair failed)"
            Update-Windows -AutoReboot
            throw "Winget repair failed or timed out. Windows Update was run - restart and run Repair Winget again."
        }

        $step = "Verifying Winget"
        Assert-WinGetPackageManager -ErrorAction Stop
        Write-Host "Winget repair finished. Version: $(Get-WinGetVersion)" -ForegroundColor Green
    }
    catch {
        Write-Host "Winget repair FAILED at: $step" -ForegroundColor Red
        $err = $_.Exception
        while ($err.InnerException) { $err = $err.InnerException }
        Write-Host "Error: $($err.Message)" -ForegroundColor Red
        # Rethrow so Run Selected stops instead of moving on to the next selection.
        throw
    }
}
