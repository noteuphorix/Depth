function DISMFix {
    Write-Host "--- Starting System Repair Sequence (7 Steps) ---" -ForegroundColor Cyan

    # Step 1: Initial SFC
    Write-Host "`nStep 1: Initial sfc /scannow" -ForegroundColor Yellow
    Start-Process "sfc.exe" -ArgumentList "/scannow" -Wait -NoNewWindow

    # Step 2: CheckHealth
    Write-Host "`nStep 2: DISM CheckHealth" -ForegroundColor Yellow
    Start-Process "DISM.exe" -ArgumentList "/Online /Cleanup-Image /CheckHealth" -Wait -NoNewWindow

    # Step 3: ScanHealth
    Write-Host "`nStep 3: DISM ScanHealth" -ForegroundColor Yellow
    Start-Process "DISM.exe" -ArgumentList "/Online /Cleanup-Image /ScanHealth" -Wait -NoNewWindow

    # Step 4: RestoreHealth
    Write-Host "`nStep 4: DISM RestoreHealth" -ForegroundColor Yellow
    Start-Process "DISM.exe" -ArgumentList "/Online /Cleanup-Image /RestoreHealth" -Wait -NoNewWindow

    # Step 5: Chkdsk (Read-only)
    Write-Host "`nStep 5: Chkdsk (Report Only)" -ForegroundColor Yellow
    Start-Process "chkdsk.exe" -Wait -NoNewWindow

    # Step 6: Chkdsk /r /f
    Write-Host "`nStep 6: Chkdsk /r /f (Scheduling Reboot Repair)" -ForegroundColor Yellow
    # We use cmd /c here because 'echo y' is a shell feature to bypass the prompt
    cmd /c "echo y | chkdsk /f /r"

    # Step 7: Final SFC
    Write-Host "`nStep 7: Final sfc /scannow" -ForegroundColor Yellow
    Start-Process "sfc.exe" -ArgumentList "/scannow" -Wait -NoNewWindow

    Write-Host "`n--- All Steps Complete ---" -ForegroundColor Green
}