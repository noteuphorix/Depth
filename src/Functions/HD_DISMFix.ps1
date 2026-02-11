function DISMFix {
    Write-Host "Starting System Repair Sequence in specified order..." -ForegroundColor Cyan

    # 1. CheckHealth
    Write-Host "Step 1: DISM CheckHealth" -ForegroundColor Yellow
    DISM /Online /Cleanup-Image /CheckHealth

    # 2. ScanHealth
    Write-Host "Step 2: DISM ScanHealth" -ForegroundColor Yellow
    DISM /Online /Cleanup-Image /ScanHealth

    # 3. RestoreHealth
    Write-Host "Step 3: DISM RestoreHealth" -ForegroundColor Yellow
    DISM /Online /Cleanup-Image /RestoreHealth

    # 4. Chkdsk (Read-only mode)
    Write-Host "Step 4: Chkdsk (Status Report)" -ForegroundColor Yellow
    Chkdsk

    # 5. Chkdsk /r /f (Repair and Stage for Reboot)
    Write-Host "Step 5: Chkdsk /r /f (Scheduling for next reboot...)" -ForegroundColor Yellow
    # This automatically sends 'Y' to the prompt to schedule the volume for the next restart
    echo y | Chkdsk /r /f

    # 6. SFC Scannow
    Write-Host "Step 6: sfc /scannow" -ForegroundColor Yellow
    sfc /scannow

    Write-Host "Sequence Complete. If errors were found in Step 5, please restart your computer." -ForegroundColor Green
}