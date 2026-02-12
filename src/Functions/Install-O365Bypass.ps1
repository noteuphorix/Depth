function Install-O365Bypass {
    Write-Host "Starting manual install" -ForegroundColor Cyan
    
    $WorkDir = "$env:TEMP\OfficeInstall"
    if (!(Test-Path $WorkDir)) { New-Item $WorkDir -ItemType Directory | Out-Null }
    
    $SetupExe = "$WorkDir\setup.exe"
    $ConfigFile = "$WorkDir\configuration.xml"

    # 1. Download the official Microsoft Office Bootstrapper
    Write-Host "Downloading Microsoft Setup Tool..." -ForegroundColor Gray
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri "https://officecdn.microsoft.com/pr/wsus/setup.exe" -OutFile $SetupExe

    # 2. Create the Configuration file (Mimics the Winget Enterprise install)
    # This tells the installer to get 64-bit Enterprise silently
    $XmlContent = @"
<Configuration>
  <Add>
    <Product ID="O365ProPlusRetail">
      <Language ID="MatchOS"/>
      <Language ID="MatchPreviousMSI"/>
      <ExcludeApp ID="Groove"/>
      <ExcludeApp ID="Lync"/>
    </Product>
  </Add>
  <RemoveMSI/>
  <Display Level="Full" AcceptEULA="TRUE"/>
</Configuration>
"@
    $XmlContent | Out-File $ConfigFile -Encoding Ascii

    # 3. Run the installation directly as Admin
    Write-Host "Starting Installation..." -ForegroundColor Green
    # We use /configure to tell the setup tool to use our XML
    Start-Process -FilePath $SetupExe -ArgumentList "/configure `"$ConfigFile`"" -Wait

    # Cleanup
    Remove-Item $WorkDir -Recurse -Force
    Write-Host "[OK] Office Installation Completed." -ForegroundColor Green
}