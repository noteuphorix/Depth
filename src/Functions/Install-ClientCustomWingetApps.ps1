function Install-ClientCustomWingetApps {
    if ([string]::IsNullOrWhiteSpace($global:SelectedClient)) {
        Write-Warning "Choose a client first!"
        return
    }

    $TxtPath = "\\10.24.2.5\Clients\$global:SelectedClient\CustomApps.txt"

    if (-not (Test-Path $TxtPath)) {
        return
    }

    $Apps = Get-Content -Path $TxtPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    if ($null -eq $Apps) {
        return
    }

    foreach ($App in $Apps) {
        # Matches your Install-DefaultWingetApps behavior exactly
        Start-Process winget -ArgumentList "install --id $App --silent --accept-source-agreements" -Wait -PassThru -NoNewWindow
    }

    return "Completed"
}