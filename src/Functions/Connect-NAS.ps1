function Connect-NAS {
    $NASLoginStatusLight.Fill = [System.Windows.Media.Brushes]::Yellow
    [System.Windows.Forms.Application]::DoEvents()

    $User = $TxtBoxUsernameNAS.Text
    $Pass = $PswrdBoxNAS.Password
    $NASPath = "\\10.24.2.5\Clients"

    try {
        # Credential logic here...
        # If it fails, New-SmbMapping will throw an error to the 'catch' block
        New-SmbMapping -RemotePath $NASPath -Password $Pass -UserName $User -Persistent $true -ErrorAction Stop | Out-Null
        net use $NASPath $Pass /user:$User /persistent:yes /y > $null
        
        $global:NAS_Clients_Folder = $NASPath
        $ClientListBox.Items.Clear()
        $Folders = Get-ChildItem -Path $global:NAS_Clients_Folder -Directory -ErrorAction SilentlyContinue | Sort-Object Name
        foreach ($Folder in $Folders) {
            $ClientListBox.Items.Add($Folder.Name)
        }
        $NASLoginStatusLight.Fill = [System.Windows.Media.Brushes]::LimeGreen
    }
    catch {
        # This handles the failure WITHOUT opening a new window
        $NASLoginStatusLight.Fill = [System.Windows.Media.Brushes]::Red
        Write-Warning "Connection failed: $($_.Exception.Message)"
    }
}