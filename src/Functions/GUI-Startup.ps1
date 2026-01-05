function GUI-Startup {
    $IP = "10.24.2.5"
    $NASPath = "\\$IP\Clients"
    
    # 1. LOCAL CHECK: Look for an existing authenticated session to that IP
    # This does NOT touch the network; it only looks at your local PC's session table.
    $ActiveSession = Get-SmbSession | Where-Object { $_.Dialect -and $_.RemoteTarget -like "*$IP*" }

    if ($null -ne $ActiveSession) {
        # 2. Session exists, so we can safely hit the network to get folders
        $global:NAS_Clients_Folder = $NASPath
        $NASLoginStatusLight.Fill = [System.Windows.Media.Brushes]::LimeGreen
        
        $ClientListBox.Items.Clear()
        # Note: If the session exists but the NAS just got unplugged, 
        # this part might still hang, but the GUI startup itself will be instant.
        $Folders = Get-ChildItem -Path $NASPath -Directory -ErrorAction SilentlyContinue
        foreach ($Folder in $Folders) { 
            [void]$ClientListBox.Items.Add($Folder.Name) 
        }
    }
    else {
        # 3. No local record of a login to that IP
        $NASLoginStatusLight.Fill = [System.Windows.Media.Brushes]::Red
        Write-Host "No active credentials/session found for $IP" -ForegroundColor Gray
    }
}