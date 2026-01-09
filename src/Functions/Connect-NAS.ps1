function Connect-NAS {
    $Ellipse_NASLoginStatusLight.Fill = [System.Windows.Media.Brushes]::Yellow
    [System.Windows.Forms.Application]::DoEvents()

    $User = $TxtBox_Username.Text
    $Pass = $PasswordBox_Password.Password
    $NASPath = "\\10.24.2.5\Clients"

    try {
        # Credential logic here...
        # If it fails, New-SmbMapping will throw an error to the 'catch' block
        New-SmbMapping -RemotePath $NASPath -Password $Pass -UserName $User -Persistent $true -ErrorAction Stop | Out-Null
        net use $NASPath $Pass /user:$User /persistent:yes /y > $null
        
        $global:NAS_Clients_Folder = $NASPath
        $ListBox_Clients.Items.Clear()
        $Folders = Get-ChildItem -Path $global:NAS_Clients_Folder -Directory -ErrorAction SilentlyContinue | Sort-Object Name
        foreach ($Folder in $Folders) {
            $ListBox_Clients.Items.Add($Folder.Name)
        }
        $Ellipse_NASLoginStatusLight.Fill = [System.Windows.Media.Brushes]::LimeGreen
    }
    catch {
        # This handles the failure WITHOUT opening a new window
        $Ellipse_NASLoginStatusLight.Fill = [System.Windows.Media.Brushes]::Red
        Write-Warning "Connection failed: $($_.Exception.Message)"
    }
}