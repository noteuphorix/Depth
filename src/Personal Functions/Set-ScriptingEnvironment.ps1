function Set-ScriptingEnvironment {
    Write-Host "Configuring User Environment..." -ForegroundColor Cyan

    # 1. Execution Policy Bypass (CurrentUser Scope)
    Write-Host "  [>] Setting User Execution Policy to Bypass..." -ForegroundColor Gray
    Set-ExecutionPolicy Bypass -Scope CurrentUser -Force

    # 2. Show File Extensions (Registry edit)
    Write-Host "  [>] Enabling File Extensions in Explorer..." -ForegroundColor Gray
    $RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $RegPath -Name "HideFileExt" -Value 0

    # 3. Open Admin CMD and CD to User Profile
    Write-Host "  [>] Launching Administrative CMD..." -ForegroundColor Yellow
    $UserDir = $env:USERPROFILE
    # /k keeps window open, /d handles drive changes
    $Args = "/k cd /d `"$UserDir`""
    
    Start-Process "cmd.exe" -ArgumentList $Args -Verb RunAs
    
    Write-Host "[OK] Tasks complete for $env:USERNAME." -ForegroundColor Green
}