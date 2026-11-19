function Start-PowerShellLogging {
    <#
    .SYNOPSIS
        Logs this window's output to Deployment_Output.txt in %TEMP%, each line timestamped.
    .DESCRIPTION
        Start-Transcript only records the runspace that started it, and every Run action executes on a
        background runspace, so their output never reached the log. The PowerShellLogging module
        instead hooks the host itself, which those runspaces all print through, and timestamps each
        line. Output that native programs (winget etc.) write straight to the console isn't caught.
        If the module can't be installed or loaded, it falls back to Start-Transcript (main thread only).
    #>

    # 1. Target the %TEMP% directory
    $LogFile = Join-Path -Path $env:TEMP -ChildPath "Deployment_Output.txt"

    # 2. Stop any existing transcript or log file to prevent errors
    try { Stop-Transcript | Out-Null } catch { }
    if ($global:DepthLogFile) {
        try { Disable-LogFile -InputObject $global:DepthLogFile } catch { }
        $global:DepthLogFile = $null
    }

    # 3. Start the log for THIS window, background runspaces included
    try {
        $module = Get-Module -ListAvailable -Name PowerShellLogging | Sort-Object Version -Descending | Select-Object -First 1
        if (-not $module) {
            Write-Host "Installing PowerShellLogging module..." -ForegroundColor Cyan
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
            if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) {
                Install-PackageProvider -Name NuGet -Scope CurrentUser -Force -ErrorAction Stop | Out-Null
            }
            # Windows PowerShell's built-in PowerShellGet 1.0.0.1 prints a pile of harmless warnings here.
            Install-Module -Name PowerShellLogging -Scope CurrentUser -Repository PSGallery -Force -ErrorAction Stop -WarningAction SilentlyContinue
            $module = Get-Module -ListAvailable -Name PowerShellLogging | Sort-Object Version -Descending | Select-Object -First 1
        }
        # Load the module's DLL directly: its .psm1 wrapper only loads this DLL, and as a script file it
        # is refused where the execution policy blocks scripts. A DLL isn't subject to that policy.
        Import-Module (Join-Path $module.ModuleBase 'PowerShellLoggingModule.dll') -ErrorAction Stop
        # Kept in a global: the module detaches the log once nothing references it. Its timestamps are UTC.
        $global:DepthLogFile = Enable-LogFile -Path $LogFile -DateTimeFormat "yyyy-MM-dd HH:mm:ss 'UTC'" -ErrorAction Stop
        # Read by the Enable PowerShell Logging button to pick its color.
        $global:DepthLoggingActive = $true
        Write-Host "PowerShell logging ON: $LogFile" -ForegroundColor Green
    } catch {
        Write-Host "PowerShellLogging unavailable ($($_.Exception.Message)). Logging the main thread only." -ForegroundColor Yellow
        try {
            Start-Transcript -Path $LogFile -Append -Confirm:$false -ErrorAction Stop
            $global:DepthLoggingActive = $true
            Write-Host "PowerShell logging ON (main thread only): $LogFile" -ForegroundColor Green
        } catch {
            $global:DepthLoggingActive = $false
            Write-Host "PowerShell logging could not be started: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    Update-LoggingButton
}

# To stop it manually before the window closes:
function Stop-DeploymentLogging {
    $stopped = $false
    if ($global:DepthLogFile) {
        try { Disable-LogFile -InputObject $global:DepthLogFile; $stopped = $true } catch { }
        $global:DepthLogFile = $null
    }
    try { Stop-Transcript | Out-Null; $stopped = $true } catch { }
    $global:DepthLoggingActive = $false

    if ($stopped) {
        Write-Host "PowerShell logging OFF" -ForegroundColor Red
    } else {
        Write-Warning "No active log found to stop."
    }
    Update-LoggingButton
}

# Shows the logging state on the toolbar button: green "Disable..." when on, red "Enable..." when off.
function Update-LoggingButton {
    if (-not $Btn_PowerShellLogging) { return }
    if ($global:DepthLoggingActive) {
        $brush = $Btn_PowerShellLogging.FindResource('SuccessBrush')
        $Btn_PowerShellLogging.Content = 'Disable PowerShell Logging'
    } else {
        $brush = $Btn_PowerShellLogging.FindResource('DangerBrush')
        $Btn_PowerShellLogging.Content = 'Enable PowerShell Logging'
    }
    $Btn_PowerShellLogging.Foreground = $brush
    $Btn_PowerShellLogging.BorderBrush = $brush
}
