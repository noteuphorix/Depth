function Unlock-WinUpdates {
    Write-Host "Unlocking Windows Update Access..." -ForegroundColor Cyan

    # 1. Define paths and values
    $RegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    $UpdatePolicyKey = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\GPUpdateCache"
    
    $ValuesToSet = @{
        "DisableWindowsUpdateAccess" = 0
        "SetDisableUXWUAccess"       = 0
    }

    # 2. Delete the GPUpdateCache key if it exists
    try {
        if (Test-Path $UpdatePolicyKey) {
            Remove-Item -Path $UpdatePolicyKey -Recurse -Force -ErrorAction Stop
            Write-Host "  [OK] Deleted registry key: GPUpdateCache" -ForegroundColor Gray
        }
    } catch {
        Write-Warning "  [!] Could not delete $UpdatePolicyKey"
    }

    # 3. Set the Policy values
    # Ensure the parent key exists first
    if (-not (Test-Path $RegistryPath)) { 
        New-Item -Path $RegistryPath -Force | Out-Null 
    }

    foreach ($Key in $ValuesToSet.Keys) {
        try {
            Set-ItemProperty -Path $RegistryPath -Name $Key -Value $ValuesToSet[$Key] -Force -ErrorAction Stop
            Write-Host "  [OK] Set $Key to $($ValuesToSet[$Key])" -ForegroundColor Gray
        } catch {
            Write-Warning "  [FAIL] Failed to set $Key in $RegistryPath"
        }
    }

    # 4. Refresh Group Policy
    Write-Host "Applying policy changes (gpupdate)..." -ForegroundColor Yellow
    gpupdate /force
    
    Write-Host "`nWindows Update has been unlocked." -ForegroundColor Green
}