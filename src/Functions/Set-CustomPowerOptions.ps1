function Set-CustomPowerOptions {
    Write-Host "Configuring Power Options..." -ForegroundColor Cyan

    $PowerCommands = @(
        'powercfg /SETDCVALUEINDEX SCHEME_CURRENT 238c9fa8-0aad-41ed-83f4-97be242c8f20 29f6c1db-86da-48c5-9fdb-f2b67b1f44da 1200',
        'powercfg /SETACVALUEINDEX SCHEME_CURRENT 238c9fa8-0aad-41ed-83f4-97be242c8f20 29f6c1db-86da-48c5-9fdb-f2b67b1f44da 0',
        'powercfg /SETDCVALUEINDEX SCHEME_CURRENT 7516b95f-f776-4464-8c53-06167f40cc99 3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e 1200',
        'powercfg /SETACVALUEINDEX SCHEME_CURRENT 7516b95f-f776-4464-8c53-06167f40cc99 3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e 0',
        'powercfg /SETACVALUEINDEX SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 7648efa3-dd9c-4e3e-b566-50f929386280 3',
        'powercfg /SETDCVALUEINDEX SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 7648efa3-dd9c-4e3e-b566-50f929386280 3'
    )

    # 1. Run the specific settings fast (using & instead of Start-Process)
    foreach ($Cmd in $PowerCommands) {
        & cmd.exe /c "$Cmd"
    }
    Write-Host "  [OK] Power settings updated in registry." -ForegroundColor Gray

    # 2. Apply changes globally - This is where the "Broadcast" happens
    # We wait here to ensure the OS has finished the heavy lifting
    Start-Process -FilePath "powercfg.exe" -ArgumentList "/setactive SCHEME_CURRENT" -Wait -NoNewWindow
    
    # 3. Final synchronization: Flush the UI message queue
    if ($null -ne $Main) {
        $Main.Dispatcher.Invoke([Action]{}, 'ContextIdle')
    }

    Write-Host "`nAll power options have been applied successfully." -ForegroundColor Green
}