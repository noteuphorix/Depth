function Install-ClientCustomLocalApps {
    Show-FunctionBanner "Install Client Local Apps"
    if ([string]::IsNullOrWhiteSpace($global:SelectedClient)) {
        Write-Warning "Choose a client first!"
        return
    }

    if ($global:SelectedClient -match ":" -or $global:SelectedClient -like "\\*") {
        $BasePath = $global:SelectedClient
    } 
    else {
        $BasePath = "\\10.24.2.5\Clients\$global:SelectedClient"
    }

    $FinalPath = Join-Path -Path $BasePath -ChildPath "Apps"

    if (-not (Test-Path $FinalPath)) {
        Write-Host "Apps folder not found at $BasePath" -ForegroundColor Red
        return
    }

    Write-Host "Starting custom app deployment from: $FinalPath" -ForegroundColor Cyan

    # Check if Windows Agent is already installed
    $InstalledApps = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
                     Select-Object -ExpandProperty DisplayName
    $WindowsAgentInstalled = $InstalledApps -contains "Windows Agent"

    $AppFiles = Get-ChildItem -Path $FinalPath -File
    
    foreach ($App in $AppFiles) {

        # Skip WindowsAgentSetup if already installed
        if ($App.Name -like "*WindowsAgentSetup*" -and $WindowsAgentInstalled) {
            Write-Host "Skipping $($App.Name) — Windows Agent is already installed." -ForegroundColor DarkYellow
            continue
        }

        Write-Host "Installing: $($App.Name)..." -ForegroundColor Yellow

        try {
            if ($App.Extension -eq ".msi") {
                $Args = "/i `"$($App.FullName)`" /norestart"
                Start-Process -FilePath "msiexec.exe" -ArgumentList $Args -Wait -NoNewWindow -ErrorAction Stop
            } 
            else {
                Start-Process -FilePath $App.FullName -Wait -NoNewWindow -ErrorAction Stop
            }
            
            Write-Host "Successfully finished $($App.Name)" -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to install $($App.Name): $($_.Exception.Message)"
        }
    }

    Write-Host "All local custom apps have been processed." -ForegroundColor Green
}