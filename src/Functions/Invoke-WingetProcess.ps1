function Invoke-WingetProcess {
    <#
    .SYNOPSIS
        Runs a single winget command via Start-Process, automatically retrying
        transient failures up to 3 total attempts.

    .DESCRIPTION
        Winget intermittently fails with things like "Failed to open internal
        URL" or an unrecognized/unknown error, and simply running the exact
        same command again succeeds. This wraps Start-Process winget so every
        call site gets that retry for free, without retrying failures a retry
        can never fix:
          - APPINSTALLER_CLI_ERROR_NO_APPLICABLE_INSTALLER (-1978335216) -
            the --scope machine mismatch callers already handle by retrying
            without --scope.
          - APPINSTALLER_CLI_ERROR_INSTALLER_HASH_MISMATCH (-1978335215) -
            the downloaded installer doesn't match the manifest hash; running
            it again just downloads the same mismatched bits.
        Success (0) and "already up to date"/"no applicable update"
        (-1978335189) also return immediately since there's nothing to retry.

    .NOTES
        Shared helper for Install-ClientCustomWingetApps, Install-DefaultWingetApps,
        Install-O365 and Install-PassedWingetApp.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ArgumentList,

        [int]$MaxAttempts = 3
    )

    # Exit codes a retry cannot fix - fail fast on these instead of burning attempts.
    $NoRetryExitCodes = @(
        -1978335216, # APPINSTALLER_CLI_ERROR_NO_APPLICABLE_INSTALLER (--scope machine issue)
        -1978335215  # APPINSTALLER_CLI_ERROR_INSTALLER_HASH_MISMATCH
    )

    $Attempt = 0
    do {
        $Attempt++
        $result = Start-Process winget -ArgumentList $ArgumentList -Wait -PassThru -NoNewWindow

        if ($result.ExitCode -eq 0 -or $result.ExitCode -eq -1978335189 -or $NoRetryExitCodes -contains $result.ExitCode) {
            return $result
        }

        if ($Attempt -lt $MaxAttempts) {
            Write-Warning "winget $ArgumentList failed (Exit code: $($result.ExitCode)), retrying ($($Attempt + 1) of $MaxAttempts)..."
            Stop-BlockingInstallerProcesses
        }
    } while ($Attempt -lt $MaxAttempts)

    return $result
}
