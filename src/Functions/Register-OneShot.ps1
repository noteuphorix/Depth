function Register-OneShot {
    # Reopens Depth once at this account's next sign-in. Windows deletes a RunOnce value before
    # running it, so it fires a single time and can't repeat. The command expires 30 minutes after
    # it's registered, so a much later sign-in just clears it without opening Depth.
    $key     = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
    $expires = (Get-Date).AddMinutes(30).ToString('s')
    $command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"if ((Get-Date) -lt [datetime]'$expires') { irm https://depth.narwal.llc | iex }`""

    # A failure here must never stop the restart that's about to happen.
    try {
        if (-not (Test-Path $key)) { [void](New-Item -Path $key) }
        [void](New-ItemProperty -Path $key -Name 'Depth' -Value $command -PropertyType String -Force)
        Write-Host "Depth will reopen at next sign-in (until $expires)." -ForegroundColor Cyan
    } catch {
        Write-Host "Couldn't set Depth to reopen after restart: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
