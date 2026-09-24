function Install-O365 {
    Show-FunctionBanner "O365 Apps Install"
    $Apps = @("Microsoft.Office")

    foreach ($App in $Apps) {
        Stop-BlockingInstallerProcesses

        $result = Invoke-WingetProcess -ArgumentList "install --id $App --silent --accept-source-agreements --accept-package-agreements"
        
        switch ($result.ExitCode) {
            0            { Write-Host "Successfully installed $App" -ForegroundColor Green }
            -1978335189  { Write-Host "$App is already up to date" -ForegroundColor Cyan }
            default      { Write-Warning "Failed to install $App (Exit code: $($result.ExitCode))" }
        }
    }
}