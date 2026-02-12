function Select-ManualFolder {
    $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderBrowser.Description = "Select the Client Folder"
    $FolderBrowser.ShowNewFolderButton = $true

    $Result = $FolderBrowser.ShowDialog()

    if ($Result -eq [System.Windows.Forms.DialogResult]::OK) {
        # Set the global variable to the FULL PATH immediately
        $global:SelectedClient = $FolderBrowser.SelectedPath
        
        $SelectedFolderName = Split-Path $global:SelectedClient -Leaf

        $ListBox_Clients.Items.Clear()
        $ListBox_Clients.Items.Add($SelectedFolderName)
        $ListBox_Clients.SelectedIndex = 0

        Write-Host "Manual Path Selected: $global:SelectedClient" -ForegroundColor Green
    }
    Sync-ClientLabel
}