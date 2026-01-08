function Install-PassedWingetApp {
    param([string]$AppID)
    Start-Process winget -ArgumentList "install --id $AppID --silent --accept-source-agreements" -Wait -PassThru -NoNewWindow
}