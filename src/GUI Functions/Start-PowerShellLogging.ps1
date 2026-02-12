function Start-PowerShellLogging {
    <#
    .SYNOPSIS
        Starts a transcript on the Desktop for the current session only.
        Automatically cleans up if a transcript is already running.
    #>
    
    # 1. Find the Desktop
    $DesktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
    $LogFile = Join-Path -Path $DesktopPath -ChildPath "Deployment_Output.txt"

    # 2. Stop any existing transcript to prevent errors
    try { Stop-Transcript | Out-Null } catch { }

    # 3. Start the log for THIS window only
    Start-Transcript -Path $LogFile -Append -Confirm:$false

    Write-Host "--- Deployment logging active: $LogFile ---" -ForegroundColor Yellow
}

# To stop it manually before the window closes:
function Stop-DeploymentLogging {
    Stop-Transcript
    Write-Host "--- Deployment logging stopped ---" -ForegroundColor Yellow
}