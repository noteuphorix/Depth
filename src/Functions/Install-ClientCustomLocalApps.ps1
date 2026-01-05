function Install-ClientCustomLocalApps {
    if ([string]::IsNullOrWhiteSpace($global:SelectedClient)) {
        Write-Warning "Choose a client first!"
        return
    }

    $NetworkPath = "\\10.24.2.5\Clients\$global:SelectedClient\Apps"

    if (-not (Test-Path $NetworkPath)) {
        Write-Error "Could not find the apps folder at: $NetworkPath"
        return
    }

    Write-Host "Starting custom app deployment for: $global:SelectedClient" -ForegroundColor Cyan

    $AppFiles = Get-ChildItem -Path $NetworkPath -File
    
    foreach ($App in $AppFiles) {
        Write-Host "Installing: $($App.Name)..." -ForegroundColor Yellow

        try {
            if ($App.Extension -eq ".msi") {
                # MSIs must be run via msiexec
                # /i = install, /qn = quiet no UI, /norestart = self-explanatory
                $Args = "/i `"$($App.FullName)`""
                Start-Process -FilePath "msiexec.exe" -ArgumentList $Args -Wait -NoNewWindow -ErrorAction Stop
            } 
            else {
                # EXEs run directly
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