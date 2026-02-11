function Sync-ClientLabel {
    if ($global:SelectedClient -and $global:SelectedClient -ne "None") {
        
        # 1. Update the .Text property (Required for TextBlocks)
        $TxtBlock_SelectedClient.Text = $global:SelectedClient
        
        # 2. Update the color to LimeGreen
        $TxtBlock_SelectedClient.Foreground = [System.Windows.Media.Brushes]::LimeGreen
    }
}