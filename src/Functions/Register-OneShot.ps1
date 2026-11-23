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
    # schtasks.exe rather than Unregister-ScheduledTask: that cmdlet would load the ScheduledTasks module
    # into this window, Depth would copy its functions into its runspaces without the module, and the
    # next Register-OneShot would fail ("Cannot retrieve the dynamic parameters for the cmdlet").
    $command = "schtasks.exe /Delete /TN '$name' /F | Out-Null; irm https://depth.narwal.llc | iex"

    # A failure here must never stop the restart that's about to happen.
    try {
        $action    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -Command `"$command`""
        $trigger   = New-ScheduledTaskTrigger -AtLogOn -User $user
        $trigger.EndBoundary = $expires.ToString('s')
        # Launching right at sign-in can fail with Access denied (0x80070005) before the session is ready.
        # Wait 10 seconds, and if the launch still fails, try once more a minute later (Windows' minimum).
        $trigger.Delay = 'PT10S'
        $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
        # Tasks default to below-normal priority (7), which would slow Depth and everything it launches.
        $settings  = New-ScheduledTaskSettingsSet -DeleteExpiredTaskAfter (New-TimeSpan -Seconds 0) -Priority 4 -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 1 -RestartInterval (New-TimeSpan -Minutes 1)
        [void](Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force)
        Write-Host "Depth will reopen at next sign-in (until $($expires.ToString('t')))." -ForegroundColor Cyan
    } catch {
        Write-Host "Couldn't set Depth to reopen after restart: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
