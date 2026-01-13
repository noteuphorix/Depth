function Set-Taskbar {
    Write-Host "Configuring Taskbar (Alignment: Left | Search: Disabled | Widgets: Disabled)..." -ForegroundColor Cyan

    $AdvancedPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $SearchPath   = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"

    # Define our targets: [Path, Name, Value, Label]
    $Settings = @(
        @($AdvancedPath, "TaskbarAl", 0, "Alignment: Left"),
        @($AdvancedPath, "TaskbarDa", 0, "Widgets: Disabled"),
        @($SearchPath, "SearchboxTaskbarMode", 0, "Search: Disabled")
    )

    foreach ($Row in $Settings) {
        $Path  = $Row[0]
        $Name  = $Row[1]
        $Value = $Row[2]
        $Label = $Row[3]

        try {
            # Create path if it doesn't exist (mostly for the Search key on fresh profiles)
            if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }

            Set-ItemProperty -Path $Path -Name $Name -Value $Value -ErrorAction Stop
            Write-Host "  [OK] $Label" -ForegroundColor Gray
        }
        catch {
            Write-Warning "  [FAIL] Could not set $Label. Error: $($_.Exception.Message)"
        }
    }

    Write-Host "`nTaskbar settings applied. A restart of Explorer may be required." -ForegroundColor Green
}