function Copy-Shortcuts {
    if ([string]::IsNullOrWhiteSpace($global:SelectedClient)) {
        Write-Warning "Choose a client first!"
        return
    }

    # 1. Determine the Base Path (Supports NAS and Manual Selection)
    if ($global:SelectedClient -match ":" -or $global:SelectedClient -like "\\*") {
        $BasePath = $global:SelectedClient
    } 
    else {
        $BasePath = "\\10.24.2.5\Clients\$global:SelectedClient"
    }

    # 2. Target the 'Shortcuts' folder specifically
    $FinalPath = Join-Path -Path $BasePath -ChildPath "Shortcuts"
    $DesktopPath = [System.IO.Path]::Combine($env:USERPROFILE, "Desktop")

    if (-not (Test-Path $FinalPath)) {
        Write-Host "Shortcut source folder not found at: $FinalPath" -ForegroundColor Red
        return
    }

    Write-Host "Copying all items from Shortcuts to Desktop..." -ForegroundColor Cyan

    try {
        # 3. Recursive Copy of all contents
        # Wildcard \* ensures we grab what's INSIDE, not the 'Shortcuts' folder itself
        Copy-Item -Path "$FinalPath\*" -Destination $DesktopPath -Recurse -Force -ErrorAction Stop
        
        Write-Host "Copy complete. Everything from '$($global:SelectedClient)\Shortcuts' is now on your Desktop." -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to copy: $($_.Exception.Message)"
    }
}