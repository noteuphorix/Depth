function Install-ClientCustomWingetApps {
    Show-FunctionBanner "Install Client Winget Apps"
    if ([string]::IsNullOrWhiteSpace($global:SelectedClient)) {
        Write-Warning "Choose a client first!"
        return
    }

    # 1. Determine the Base Path
    # Checks for ":" (C:\) or starts with "\" (\\Server)
    if ($global:SelectedClient -match ":" -or $global:SelectedClient -like "\\*") {
        $BasePath = $global:SelectedClient
    } 
    else {
        $BasePath = "\\10.24.2.5\Clients\$global:SelectedClient"
    }

    # 2. Map directly to the .txt file in the root of that path
    $TxtPath = Join-Path -Path $BasePath -ChildPath "CustomApps.txt"

    if (-not (Test-Path $TxtPath)) {
        Write-Warning "CustomApps.txt not found at $BasePath"
        return
    }

    $Apps = Get-Content -Path $TxtPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    if ($null -eq $Apps) {
        return
    }

    foreach ($App in $Apps) {
        # Executes winget for each ID found in the text file, attempts machine scope first
        $result = Start-Process winget -ArgumentList "install --id $App --silent --accept-source-agreements --accept-package-agreements --scope machine" -Wait -PassThru -NoNewWindow

        switch ($result.ExitCode) {
            0            { Write-Host "Successfully installed $App" -ForegroundColor Green }
            -1978335189  { Write-Host "$App is already up to date" -ForegroundColor Cyan }
            { $_ -in -1978335216, -1978334957 } {
                            # APPINSTALLER_CLI_ERROR_NO_APPLICABLE_INSTALLER or UPDATE_NOT_APPLICABLE - retries without --scope machine
                            Write-Warning "$App failed with --scope machine (exit code: $_), retrying without --scope..."
                            $retryResult = Start-Process winget -ArgumentList "install --id $App --silent --accept-source-agreements --accept-package-agreements" -Wait -PassThru -NoNewWindow

                            switch ($retryResult.ExitCode) {
                                0            { Write-Host "Successfully installed $App (without --scope machine)" -ForegroundColor Green }
                                -1978335189  { Write-Host "$App is already up to date" -ForegroundColor Cyan }
                                default      { Write-Warning "Failed to install $App on retry (Exit code: $($retryResult.ExitCode))" }
                            }
                         }
            default      { Write-Warning "Failed to install $App (Exit code: $($result.ExitCode))" }
        }
    }

    return "Completed"
}