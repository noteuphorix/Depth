function Install-ClientCustomLocalApps {
    if ([string]::IsNullOrWhiteSpace($global:SelectedClient)) {
        Write-Warning "Choose a client first!"
        return
    }

    # 1. Determine the Base Path
    # If it contains a ':' (C:\) or starts with '\' (\\Server), use it directly.
    # Otherwise, assume it's a name and build the 10.24.2.5 network path.
    if ($global:SelectedClient -match ":" -or $global:SelectedClient -like "\\*") {
        $BasePath = $global:SelectedClient
    } 
    else {
        $BasePath = "\\10.24.2.5\Clients\$global:SelectedClient"
    }

    # 2. Append the "Apps" folder to the determined path
    $FinalPath = Join-Path -Path $BasePath -ChildPath "Apps"

    if (-not (Test-Path $FinalPath)) {
        Write-Error "Could not find the Apps folder at: $FinalPath"
        return
    }

    Write-Host "Starting custom app deployment from: $FinalPath" -ForegroundColor Cyan

    $AppFiles = Get-ChildItem -Path $FinalPath -File
    
    foreach ($App in $AppFiles) {
        Write-Host "Installing: $($App.Name)..." -ForegroundColor Yellow

        try {
            if ($App.Extension -eq ".msi") {
                # Wrap FullName in quotes to handle spaces correctly
                $Args = "/i `"$($App.FullName)`" /qn /norestart"
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