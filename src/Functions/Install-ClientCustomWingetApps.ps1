function Install-ClientCustomWingetApps {
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
        # Silent return to match your requested behavior
        return
    }

    $Apps = Get-Content -Path $TxtPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    if ($null -eq $Apps) {
        return
    }

    foreach ($App in $Apps) {
        # Executes winget for each ID found in the text file
        Start-Process winget -ArgumentList "install --id $App --silent --accept-source-agreements" -Wait -PassThru -NoNewWindow
    }

    return "Completed"
}