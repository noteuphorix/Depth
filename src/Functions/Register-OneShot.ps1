function Register-OneShot {
    # Reopens Depth once, at this account's next sign-in, through a scheduled task. A task runs right
    # at sign-in (RunOnce entries are delayed until Windows feels idle) and can run elevated, so
    # there's no UAC prompt. It only fires for the account that registered it.
    # It can't run more than once or linger:
    #   - The task's first step deletes the task itself; Depth keeps running after that.
    #   - The trigger expires 60 minutes after it's registered, so a later sign-in doesn't fire it.
    #   - Once expired, Task Scheduler deletes the task on its own if it never ran.
    $name    = 'Depth OneShot'
    $user    = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $expires = (Get-Date).AddMinutes(60)
    $command = "Unregister-ScheduledTask -TaskName '$name' -Confirm:`$false; irm https://depth.narwal.llc | iex"

    # A failure here must never stop the restart that's about to happen.
    try {
        $action    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoExit -NoProfile -ExecutionPolicy Bypass -Command `"$command`""
        $trigger   = New-ScheduledTaskTrigger -AtLogOn -User $user
        $trigger.EndBoundary = $expires.ToString('s')
        $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
        # Tasks default to below-normal priority (7), which would slow Depth and everything it launches.
        $settings  = New-ScheduledTaskSettingsSet -DeleteExpiredTaskAfter (New-TimeSpan -Seconds 0) -Priority 4 -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        [void](Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force)
        Write-Host "Depth will reopen at next sign-in (until $($expires.ToString('t')))." -ForegroundColor Cyan
    } catch {
        Write-Host "Couldn't set Depth to reopen after restart: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
