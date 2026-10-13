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
        # Run the repair in a background job (its own process) so it can be killed if it hangs when
        # App Installer is stuck behind pending Windows Updates. Verbose output is redirected into
        # the output stream so it can be relayed live below.
        $job = Start-Job -ScriptBlock {
            Import-Module Microsoft.WinGet.Client -ErrorAction Stop
            Repair-WinGetPackageManager -AllUsers -Latest -Force -Verbose -ErrorAction Stop 4>&1 | ForEach-Object { "$_" }
        }

        $deadline = (Get-Date).AddMinutes(3)
        while ($job.State -eq 'Running' -and (Get-Date) -lt $deadline) {
            Receive-Job $job | ForEach-Object { Write-Host $_ }
            Start-Sleep -Seconds 2
        }

        if ($job.State -eq 'Running') {
            Stop-Job $job
            Remove-Job $job -Force

            Write-Host "WARNING: App Installer is stuck, Windows Updates are required!" -ForegroundColor Red
            Write-Host "Running Windows Update now. The device will restart once updates finish installing." -ForegroundColor Red
            Update-Windows -AutoReboot
            return
        }

        # Finished in time - relay remaining output; a failure inside the job is rethrown into the catch below.
        try {
            Receive-Job $job -ErrorAction Stop | ForEach-Object { Write-Host $_ }
        } finally {
            Remove-Job $job -Force
        }

        Write-Host "Winget repair finished." -ForegroundColor Green
    }
    catch {
        Write-Host "Winget repair FAILED at: $step" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Command: $($_.InvocationInfo.Line.Trim())" -ForegroundColor Red
    }
}