function Set-CustomPowerOptions {
    Write-Host "Configuring Power Options..." -ForegroundColor Cyan

    $PowerCommands = @(
        @('powercfg /SETDCVALUEINDEX SCHEME_CURRENT 238c9fa8-0aad-41ed-83f4-97be242c8f20 29f6c1db-86da-48c5-9fdb-f2b67b1f44da 1200', "DC Sleep Timeout"),
        @('powercfg /SETACVALUEINDEX SCHEME_CURRENT 238c9fa8-0aad-41ed-83f4-97be242c8f20 29f6c1db-86da-48c5-9fdb-f2b67b1f44da 0', "AC Sleep Timeout"),
        @('powercfg /SETDCVALUEINDEX SCHEME_CURRENT 7516b95f-f776-4464-8c53-06167f40cc99 3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e 1200', "DC Display Timeout"),
        @('powercfg /SETACVALUEINDEX SCHEME_CURRENT 7516b95f-f776-4464-8c53-06167f40cc99 3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e 0', "AC Display Timeout"),
        @('powercfg /SETACVALUEINDEX SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 7648efa3-dd9c-4e3e-b566-50f929386280 3', "AC Power Button Action"),
        @('powercfg /SETDCVALUEINDEX SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 7648efa3-dd9c-4e3e-b566-50f929386280 3', "DC Power Button Action")
    )

    foreach ($Entry in $PowerCommands) {
        $Command = $Entry[0]
        $Label = $Entry[1]
        try {
            # Running via Start-Process -Wait ensures each individual command is finished
            $Args = $Command -replace 'powercfg ', ''
            Start-Process -FilePath "powercfg.exe" -ArgumentList $Args -Wait -NoNewWindow
            Write-Host "  [OK] $Label set." -ForegroundColor Gray
        }
        catch {
            Write-Warning "  [FAIL] Could not set $Label."
        }
    }

    # Apply changes globally and wait for the process to exit
    Start-Process -FilePath "powercfg.exe" -ArgumentList "/setactive SCHEME_CURRENT" -Wait -NoNewWindow
    
    # This is the "Magic" line: It forces the script to yield until the UI thread 
    # has processed all background OS notifications (like the power change)
    if ($null -ne $Main) {
        $Main.Dispatcher.Invoke([Action]{}, 'ContextIdle')
    }

    Write-Host "`nAll power options have been applied successfully." -ForegroundColor Green
}