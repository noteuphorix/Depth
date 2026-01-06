function Refresh-Clients {
    # 1. Check if the path is set
    if (-not $global:NAS_Clients_Folder) {
        Write-Warning "Refresh failed: NAS path is not defined. Please connect first."
        return
    }

    try {
        # 2. Clear existing items
        $ClientListBox.Items.Clear()
        
        # 3. Re-populate from the global NAS path
        $Folders = Get-ChildItem -Path $global:NAS_Clients_Folder -Directory -ErrorAction Stop | Sort-Object Name
        
        foreach ($Folder in $Folders) {
            $ClientListBox.Items.Add($Folder.Name)
        }
    }
    catch {
        Write-Warning "Refresh failed: $($_.Exception.Message)"
    }
}