function Set-SelectedClient {
    # Ensure something is actually selected
    if ($ClientListBox.SelectedItem -ne $null) {
        $global:SelectedClient = $ClientListBox.SelectedItem.ToString()
        
        # Optional: Visual feedback or logging
        Write-Host "Client Selected: $global:SelectedClient" -ForegroundColor Green
        
        # If you want to show it somewhere in the UI, you could update a label here
        # $LblCurrentClient.Content = "Active: $global:SelectedClient"
    }
}