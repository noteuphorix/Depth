function Select-ManualFolder {
    $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderBrowser.Description = "Select the Client Folder"
    $FolderBrowser.ShowNewFolderButton = $true

    $Result = $FolderBrowser.ShowDialog()

    if ($Result -eq [System.Windows.Forms.DialogResult]::OK) {
        $global:SelectedClientPath = $FolderBrowser.SelectedPath
        
        # 1. Clear the ListBox so we don't just keep adding to old results
        $ClientListBox.Items.Clear()

        # 2. Get only the top-level folders within the selected path
        $SubFolders = Get-ChildItem -Path $global:SelectedClientPath -Directory

        # 3. Loop through and add each folder name to the ListBox
        foreach ($Folder in $SubFolders) {
            $ClientListBox.Items.Add($Folder.Name)
        }

        Write-Host "Populated ListBox with $($SubFolders.Count) folders from: $global:SelectedClientPath" -ForegroundColor Green
    }
}