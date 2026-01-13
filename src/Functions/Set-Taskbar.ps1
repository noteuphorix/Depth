function Set-Taskbar {
    Write-Host "Detecting logged-in user..." -ForegroundColor Cyan

    # 1. Get the currently logged-in console user
    $LoggedUser = Get-CimInstance Win32_ComputerSystem | Select-Object -ExpandProperty UserName
    if ($null -eq $LoggedUser) { 
        Write-Warning "Could not detect a logged-in user. Are you running this in an RDP session?"
        return 
    }
    
    $UserName = $LoggedUser.Split('\')[-1]
    $UserSID = (New-Object System.Security.Principal.NTAccount($UserName)).Translate([System.Security.Principal.SecurityIdentifier]).Value
    $ProfilePath = "C:\Users\$UserName"

    Write-Host "Targeting User: $UserName ($UserSID)" -ForegroundColor Gray

    # 2. THE WIPE: Targeting the specific user's AppData folder
    try {
        $PinPath = "$ProfilePath\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\Taskbar"
        if (Test-Path $PinPath) { 
            Get-ChildItem -Path $PinPath -File | Remove-Item -Force 
        }

        # Targeting HKEY_USERS instead of HKCU
        $RegistryPinsPath = "Registry::HKEY_USERS\$UserSID\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband"
        if (Test-Path $RegistryPinsPath) {
            Remove-ItemProperty -Path $RegistryPinsPath -Name "Favorites" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $RegistryPinsPath -Name "FavoritesResolve" -ErrorAction SilentlyContinue
        }
        Write-Host "  [OK] Taskbar pins cleared for $UserName." -ForegroundColor Gray
    } catch {
        Write-Warning "  [!] Could not fully clear pins for $UserName."
    }

    # 3. THE CONFIG: Mapping settings to the User's SID
    $Settings = @(
        @("Registry::HKEY_USERS\$UserSID\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "TaskbarAl", 0, "Alignment: Left"),
        @("Registry::HKEY_USERS\$UserSID\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "TaskbarDa", 0, "Widgets: Disabled"),
        @("Registry::HKEY_USERS\$UserSID\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "ShowTaskViewButton", 0, "Task View: Disabled"),
        @("Registry::HKEY_USERS\$UserSID\Software\Microsoft\Windows\CurrentVersion\Search", "SearchboxTaskbarMode", 0, "Search: Disabled")
    )

    foreach ($Row in $Settings) {
        $Path, $Name, $Value, $Label = $Row
        try {
            # Ensure the key exists in the user's hive
            if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
            
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Force -ErrorAction Stop
            Write-Host "  [OK] ${Label} set." -ForegroundColor Gray
        } 
        catch {
            Write-Warning "  [FAIL] ${Label} - $($_.Exception.Message)"
        }
    }

    # 4. THE REFRESH: Kill ONLY the user's explorer, not the Admin's
    Write-Host "`nRestarting Explorer for $UserName..." -ForegroundColor Yellow
    $UserExplorer = Get-Process explorer -IncludeUserName | Where-Object { $_.UserName -like "*$UserName*" }
    if ($UserExplorer) {
        $UserExplorer | Stop-Process -Force
    } else {
        # Fallback: kill all explorers if IncludeUserName fails (requires PS 5.1+)
        Stop-Process -Name explorer -Force
    }
}