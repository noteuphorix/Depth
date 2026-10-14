function Repair-Winget {
    Show-FunctionBanner "Winget Repair"

    # Prints everything an error carries: every wrapped exception (type, message, HResult), the
    # command and line it came from, and the script stack trace.
    function Write-ErrorDetails {
        param([System.Management.Automation.ErrorRecord]$Record)

        $ex = $Record.Exception
        $depth = 0
        while ($ex) {
            $indent = '  ' * ($depth + 1)
            Write-Host "$indent[$($ex.GetType().FullName)] $($ex.Message)" -ForegroundColor Red
            Write-Host ("$indent  HResult: 0x{0:X8}" -f $ex.HResult) -ForegroundColor Red
            if ($ex -is [System.Management.Automation.IContainsErrorRecord] -and $ex.ErrorRecord.InvocationInfo.MyCommand) {
                Write-Host "$indent  Command: $($ex.ErrorRecord.InvocationInfo.MyCommand)" -ForegroundColor Red
            }
            $ex = $ex.InnerException
            $depth++
        }
        Write-Host "  Category: $($Record.CategoryInfo)" -ForegroundColor Red
        Write-Host "  Error ID: $($Record.FullyQualifiedErrorId)" -ForegroundColor Red
        if ($Record.InvocationInfo.PositionMessage) {
            Write-Host "  Position: $($Record.InvocationInfo.PositionMessage)" -ForegroundColor Red
        }
        if ($Record.ScriptStackTrace) {
            Write-Host "  Stack trace:`n$($Record.ScriptStackTrace)" -ForegroundColor Red
        }
    }

    # `winget source update --name msstore` always reports success (msstore is queried live, so
    # there's nothing to update), so instead look up App Installer's own Store ID on msstore. This
    # fails exactly when installs without --source fail on msstore. Prints winget's output on failure.
    function Test-MsStoreSource {
        $output = winget show --id 9NBLGGH4NNS1 --source msstore --exact --accept-source-agreements --disable-interactivity 2>&1
        if ($LASTEXITCODE -eq 0) { return $true }

        Write-Host ("msstore source check failed (winget exit code 0x{0:X8}):" -f $LASTEXITCODE) -ForegroundColor Red
        $output | ForEach-Object { "$_".Trim() } | Where-Object { $_ } | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        return $false
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

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
            Write-Host "Winget is not installed." -ForegroundColor Red
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
                Write-Host "Repair-WinGetPackageManager failed:" -ForegroundColor Red
                Write-ErrorDetails $_
                $repairFailed = $true
            } finally {
                # The repair can report its error here instead of throwing - that counts as a failure too.
                foreach ($record in $repair.Streams.Error) {
                    Write-Host "Repair-WinGetPackageManager reported an error:" -ForegroundColor Red
                    Write-ErrorDetails $record
                    $repairFailed = $true
                }
                $repair.Dispose()
            }
        } else {
            Write-Host "Repair-WinGetPackageManager was still running after 3 minutes, stopping it." -ForegroundColor Red
            foreach ($record in $repair.Streams.Error) {
                Write-Host "Repair-WinGetPackageManager reported an error:" -ForegroundColor Red
                Write-ErrorDetails $record
            }
            $repair.BeginStop($null, $null) | Out-Null
            $repairFailed = $true
        }

        # The repair can finish without errors and winget or msstore still not work - that needs
        # Windows Updates too.
        if (-not $repairFailed) {
            $step = "Verifying Winget"
            try {
                Assert-WinGetPackageManager -ErrorAction Stop
            } catch {
                Write-Host "Winget still isn't working after the repair:" -ForegroundColor Red
                Write-ErrorDetails $_
                $repairFailed = $true
            }
        }
        if (-not $repairFailed) {
            $step = "Verifying the msstore source"
            if (-not (Test-MsStoreSource)) {
                Write-Host "The msstore source still isn't working after the repair." -ForegroundColor Red
                $repairFailed = $true
            }
        }

        if ($repairFailed) {
            Write-Host "WARNING: App Installer is stuck, Windows Updates are required!" -ForegroundColor Red
            Write-Host "Running Windows Update now. The device will restart once updates finish installing." -ForegroundColor Red
            $step = "Windows Update (after Winget repair failed)"
            Update-Windows -AutoReboot
            throw "Winget repair failed or timed out. Windows Update was run - restart and run Repair Winget again."
        }

        Write-Host "Winget repair finished. Version: $(Get-WinGetVersion)" -ForegroundColor Green
    }
    catch {
        Write-Host "Winget repair FAILED at: $step" -ForegroundColor Red
        Write-ErrorDetails $_
        # Rethrow so Run Selected stops instead of moving on to the next selection.
        throw
    }
}
