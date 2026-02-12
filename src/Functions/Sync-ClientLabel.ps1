function Sync-ClientLabel {
    if ($global:SelectedClient -and $global:SelectedClient -ne "None") {
        
        # 1. Strip the path to show only the final folder name (the 'Leaf')
        # This turns "C:\Users\Euphoria\Pictures\Cyberpunk 2077" into "Cyberpunk 2077"
        $DisplayName = Split-Path -Path $global:SelectedClient -Leaf
        
        # 2. Update the TextBlock with the shortened name
        $TxtBlock_SelectedClient.Text = $DisplayName
        
        # 3. Update the color to LimeGreen
        $TxtBlock_SelectedClient.Foreground = [System.Windows.Media.Brushes]::LimeGreen
    }
}