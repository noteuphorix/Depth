function Stop-BlockingInstallerProcesses {
    <#
    .SYNOPSIS
        Kills known installer/updater processes and resets the Windows Installer
        service so a queued winget/MSI install doesn't fail because of a
        background installer this script never launched.

    .DESCRIPTION
        Winget and MSI installs frequently die with "another installation is
        already in progress" (ERROR_INSTALL_ALREADY_RUNNING / Win32 1618)
        because something else on the machine - Windows Update servicing,
        OneDrive, Office Click-to-Run, a leftover vendor bootstrapper, etc. -
        is holding the global MSI mutex or its own installer lock. Call this
        immediately before every single app install attempt to clear the
        field first.

    .NOTES
        Shared helper, called once per app right before the install is
        attempted from Install-ClientCustomLocalApps, Install-ClientCustomWingetApps,
        Install-DefaultWingetApps, Install-O365 and Install-PassedWingetApp.
    #>
    [CmdletBinding()]
    param()

    # Processes known to hold the MSI/installer lock or otherwise collide
    # with a fresh silent install.
    $KnownInstallerProcesses = @(
        "msiexec",             # Windows Installer engine
        "TiWorker",            # Windows Modules Installer Worker
        "TrustedInstaller",    # Windows Modules Installer service host
        "wuauclt",             # Legacy Windows Update client
        "UsoClient",           # Update Session Orchestrator
        "MoUsoCoreWorker",     # Update Orchestrator worker
        "OneDriveSetup",
        "OfficeClickToRun",    # Office C2R service host - notorious for blocking Office/MSI installs
        "OfficeC2RClient",
        "AppInstallerCLI",
        "winget",              # Leftover/hung winget from a previous attempt
        "GoogleUpdate",
        "MicrosoftEdgeUpdate"
    )

    $Killed = @()

    Get-Process -Name $KnownInstallerProcesses -ErrorAction SilentlyContinue | ForEach-Object {
        $Killed += $_.ProcessName
        $_ | Stop-Process -Force -ErrorAction SilentlyContinue
    }

    # Catch anything else that looks like a vendor bootstrapper (*setup*,
    # *install*, *update*) but wasn't launched by this script - excluding
    # our own process and its parent so we can never self-terminate.
    $ProtectedPids = @($PID)
    try {
        $ProtectedPids += (Get-CimInstance Win32_Process -Filter "ProcessId=$PID" -ErrorAction Stop).ParentProcessId
    } catch {}

    Get-Process | Where-Object {
        $_.Id -notin $ProtectedPids -and
        $KnownInstallerProcesses -notcontains $_.ProcessName -and
        $_.ProcessName -match '(setup|install|updater?)'
    } | ForEach-Object {
        $Killed += $_.ProcessName
        $_ | Stop-Process -Force -ErrorAction SilentlyContinue
    }

    # Reset the Windows Installer service - this clears a stuck
    # Global\_MSIExecute mutex (ERROR_INSTALL_ALREADY_RUNNING) even when no
    # msiexec.exe process is visibly running. It restarts on-demand the next
    # time anything calls into MSI, so it's safe to do before every install.
    try { Restart-Service -Name msiserver -Force -ErrorAction SilentlyContinue } catch {}

    if ($Killed.Count -gt 0) {
        $Unique = $Killed | Select-Object -Unique
        Write-Host "Cleared possible blocking installers: $($Unique -join ', ')" -ForegroundColor DarkYellow
    }
}
