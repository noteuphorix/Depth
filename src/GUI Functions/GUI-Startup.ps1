function GUI-Startup {
    $NASIP = "10.24.2.5"
    $NASPath = "\\$NASIP\Clients"
    Sync-ClientLabel
    
    Write-Host "Checking NAS connectivity..." -ForegroundColor Cyan

    # Step 1: Ping the IP. -Count 1 -Quiet returns True/False instantly.
    if (Test-Connection -ComputerName $NASIP -Count 1 -Quiet) {
        
        # Step 2: Ping succeeded, now check the specific folder path
        if (Test-Path -Path "FileSystem::$NASPath" -PathType Container -ErrorAction SilentlyContinue) {
            $global:NAS_Clients_Folder = $NASPath
            $Ellipse_NASLoginStatusLight.Fill = [System.Windows.Media.Brushes]::LimeGreen
            
            $ListBox_Clients.Items.Clear()
            $Folders = Get-ChildItem -Path $NASPath -Directory -ErrorAction SilentlyContinue | Sort-Object Name
            foreach ($Folder in $Folders) { 
                [void]$ListBox_Clients.Items.Add($Folder.Name) 
            }
            Write-Host "NAS Connected and Clients Loaded." -ForegroundColor Green
        }
        else {
            # IP is up, but the share or folder is missing/perm denied
            $Ellipse_NASLoginStatusLight.Fill = [System.Windows.Media.Brushes]::Red
            Write-Host "NAS IP reachable, but Path not found!" -ForegroundColor Yellow
        }
    }
    else {
        # Step 3: Ping failed - This is the "Fail Fast" exit
        $Ellipse_NASLoginStatusLight.Fill = [System.Windows.Media.Brushes]::Red
        Write-Host "NAS Not Connected! (Ping Failed)" -ForegroundColor Red
    }
}