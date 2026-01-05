function Install-DefaultWingetApps {
    # Pre-defined list of IDs
    $Apps = @("Google.Chrome", "Adobe.Acrobat.Reader.64-bit", "Intel.IntelDriverAndSupportAssistant", "Microsoft.Teams", "9WZDNCRD29V9")

    foreach ($App in $Apps) {
        # Process runs and displays output in its own console window area
        Start-Process winget -ArgumentList "install --id $App --silent --accept-source-agreements" -Wait -PassThru -NoNewWindow
    }

    return "Completed"
}
