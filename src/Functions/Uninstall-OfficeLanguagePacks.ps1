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

    # 3. Ensure ODT exists
    $ODTPath = "$env:TEMP\setup.exe"
    if (-not (Test-Path $ODTPath)) {
        Invoke-WebRequest -Uri "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_17126-20132.exe" -OutFile "$env:TEMP\odt.exe"
        Start-Process -FilePath "$env:TEMP\odt.exe" -ArgumentList "/extract:$env:TEMP /quiet" -Wait
    }

    # 4. Build and Run XML with all 3 Product IDs
    $XmlPath = "$env:TEMP\RemoveLangs.xml"
    $LangNodes = ($LangsToRemove | ForEach-Object { "      <Language ID=""$_"" />" }) -join "`n"

    # We repeat the LangNodes for each potential Product ID
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

    $Process = Start-Process -FilePath $ODTPath -ArgumentList "/configure `"$XmlPath`"" -Wait -PassThru -NoNewWindow

    # 5. Final Status & Cleanup
    if ($Process.ExitCode -eq 0) {
        Write-Host "Successfully removed extra language packs." -ForegroundColor Green
        Remove-Item $XmlPath, $ODTPath -ErrorAction SilentlyContinue
    } else {
        Write-Host "Uninstall failed with Exit Code: $($Process.ExitCode)" -ForegroundColor Red
    }
}