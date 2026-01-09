function Uninstall-OfficeLanguagePacks {
    Write-Host "Scanning for extra Office Language Packs..." -ForegroundColor Cyan

    # 1. Get all Office ClickToRun entries, excluding English
    $OfficePacks = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | Where-Object {
        $_.UninstallString -like "*OfficeClickToRun.exe*" -and 
        $_.DisplayName -notlike "*en-us*" -and 
        $_.DisplayName -notlike "*English*" -and 
        $_.DisplayName -ne $null
    }

    if (-not $OfficePacks) {
        Write-Host "No extra Office language packs found." -ForegroundColor Green
        return
    }

    # 2. Extract Language IDs (xx-xx)
    $LangsToRemove = $(foreach ($Pack in $OfficePacks) {
        if ($Pack.DisplayName -match '([a-z]{2}-[a-z]{2})') { $Matches[1] }
    }) | Select-Object -Unique

    Write-Host "Uninstalling: $($LangsToRemove -join ', ')" -ForegroundColor Yellow

    # --- SANDBOX SETUP ---
    $WorkDir = "$env:TEMP\officedeployment"
    if (-not (Test-Path $WorkDir)) { New-Item -Path $WorkDir -ItemType Directory -Force | Out-Null }
    
    $ODTPath = "$WorkDir\setup.exe"
    $XmlPath = "$WorkDir\RemoveLangs.xml"

    # 3. Ensure ODT exists in our private folder
    if (-not (Test-Path $ODTPath)) {
        Invoke-WebRequest -Uri "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_17126-20132.exe" -OutFile "$WorkDir\odt.exe"
        Start-Process -FilePath "$WorkDir\odt.exe" -ArgumentList "/extract:`"$WorkDir`" /quiet" -Wait
    }

    # 4. Build XML
    $LangNodes = ($LangsToRemove | ForEach-Object { "      <Language ID=""$_"" />" }) -join "`n"

    @"
<Configuration>
  <Remove>
    <Product ID="O365ProPlusRetail">
$LangNodes
    </Product>
    <Product ID="O365HomePremRetail">
$LangNodes
    </Product>
    <Product ID="OneNoteFreeRetail">
$LangNodes
    </Product>
  </Remove>
  <Display Level="None" AcceptEULA="TRUE" />
  <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
</Configuration>
"@ | Out-File -FilePath $XmlPath -Encoding utf8 -Force

    # 5. Run and Cleanup
    $Process = Start-Process -FilePath $ODTPath -ArgumentList "/configure `"$XmlPath`"" -Wait -PassThru -NoNewWindow

    # Null-check the process to prevent a fatal crash if it failed to launch
    if ($null -ne $Process -and $Process.ExitCode -eq 0) {
        Write-Host "Successfully removed extra language packs." -ForegroundColor Green
        # Wipe the whole subfolder clean
        Remove-Item -Path $WorkDir -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        $ExitCode = if ($null -ne $Process) { $Process.ExitCode } else { "Failed to Start" }
        Write-Host "Uninstall failed. Exit Code: $ExitCode" -ForegroundColor Red
    }
}