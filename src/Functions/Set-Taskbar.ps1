function Set-Taskbar {
    Write-Host "Wiping taskbar pins and configuring layout..." -ForegroundColor Cyan

    # 1. THE WIPE
    try {
        $PinPath = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\Taskbar"
        if (Test-Path $PinPath) { Get-ChildItem -Path $PinPath -File | Remove-Item -Force }

        $RegistryPins = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband"
        Remove-ItemProperty -Path $RegistryPins -Name "Favorites" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $RegistryPins -Name "FavoritesResolve" -ErrorAction SilentlyContinue
        Write-Host "  [OK] Taskbar pins cleared." -ForegroundColor Gray
    } catch {
        Write-Warning "  [!] Could not fully clear pins."
    }

    # 2. THE CONFIG
    $Settings = @(
        @("HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "TaskbarAl", 0, "Alignment: Left"),
        @("HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "TaskbarDa", 0, "Widgets: Disabled"),
        @("HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "ShowTaskViewButton", 0, "Task View: Disabled"),
        @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Search", "SearchboxTaskbarMode", 0, "Search: Disabled")
    )

    foreach ($Row in $Settings) {
        $Path, $Name, $Value, $Label = $Row
        try {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -ErrorAction Stop
            Write-Host "  [OK] ${Label} set." -ForegroundColor Gray
        } 
        catch [System.Management.Automation.ItemNotFoundException] {
            Write-Warning "  [SKIP] ${Label} - Registry path does not exist."
        }
        catch [System.Security.SecurityException] {
            Write-Warning "  [FAIL] ${Label} - Security/Permission exception."
        }
        catch {
            Write-Warning "  [FAIL] ${Label} - Unhandled exception."
        }
    }

    # 3. THE REFRESH
    Write-Host "`nRestarting Explorer..." -ForegroundColor Yellow
    Stop-Process -Name explorer -Force
}