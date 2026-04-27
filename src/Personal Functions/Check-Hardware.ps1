function Check-Hardware {

    # --- Battery Report ---
    Write-Host "`n=== Generating Battery Report ===" -ForegroundColor Yellow
    powercfg /batteryreport /output C:\battery-report.html
    Start-Sleep -Seconds 2
    Start-Process "C:\battery-report.html"

    # --- WinSAT ---
    Write-Host "`n=== Running WinSAT Formal (this may take a few minutes) ===" -ForegroundColor Yellow
    Start-Process winsat -ArgumentList "formal" -Wait -NoNewWindow
    Write-Host "`nWinSAT Results:" -ForegroundColor Cyan
    Get-CimInstance Win32_WinSAT | Format-List *

    # --- Install Apps ---
    Write-Host "`n=== Installing Diagnostic Tools ===" -ForegroundColor Yellow

    $apps = @(
        "CPUID.CPU-Z",
        "CPUID.HWMonitor",
        "CrystalDewWorld.CrystalDiskInfo",
        "CrystalDewWorld.CrystalDiskMark"
    )

    foreach ($AppID in $apps) {
        Write-Host "Installing package: $AppID..." -ForegroundColor Green
        $result = Start-Process winget -ArgumentList "install --id $AppID --silent --accept-source-agreements --accept-package-agreements --source winget" -Wait -PassThru -NoNewWindow

        switch ($result.ExitCode) {
            0            { Write-Host "Successfully installed $AppID" -ForegroundColor Green }
            -1978335189  { Write-Host "$AppID is already up to date" -ForegroundColor Cyan }
            default      { Write-Warning "Failed to install $AppID (Exit code: $($result.ExitCode))" }
        }

        Start-Sleep -Seconds 1
    }

    # --- Open Web Tools ---
    Write-Host "`n=== Opening Web Diagnostic Tools ===" -ForegroundColor Yellow
    Start-Process "https://deadpixelbuddy.com/"
    Start-Process "https://danwlker.github.io/KeyboardTestingPage/"
    Start-Process "https://www.speedtest.net/"

    Write-Host "`n=== Check-Hardware Complete ===" -ForegroundColor Green
}