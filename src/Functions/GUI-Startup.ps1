function GUI-Startup {
    $NASPath = "\\10.24.2.5\Clients"
    
    # Use -PathType Container for the fastest possible 'touch' test
    if (Test-Path -Path $NASPath -PathType Container -ErrorAction SilentlyContinue) {
        $global:NAS_Clients_Folder = $NASPath
        $NASLoginStatusLight.Fill = [System.Windows.Media.Brushes]::LimeGreen
        
        $ClientListBox.Items.Clear()
        $Folders = Get-ChildItem -Path $NASPath -Directory -ErrorAction SilentlyContinue
        foreach ($Folder in $Folders) { [void]$ClientListBox.Items.Add($Folder.Name) }
    }
    else {
        $NASLoginStatusLight.Fill = [System.Windows.Media.Brushes]::Red
        Write-Host ("NAS Not Connected!")
    }
}