function Install-O365 {
    Show-FunctionBanner "O365 Apps Install"
    # Pre-defined list of IDs
    $Apps = @("Microsoft.Office")

    foreach ($App in $Apps) {
        # Process runs and displays output in its own console window area
        Start-Process winget -ArgumentList "install --id $App --silent --accept-source-agreements" -Wait -PassThru -NoNewWindow
    }
}