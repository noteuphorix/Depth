function Update-Status {
    param(
        [ValidateSet("Busy", "Ready")]
        [string]$State
    )

    # Change the color of the StatusLight Ellipse
    if ($State -eq "Busy") {
        # Use Red for Busy
        $StatusLight.Fill = [System.Windows.Media.Brushes]::Red
    } else {
        # Use LimeGreen for Ready
        $StatusLight.Fill = [System.Windows.Media.Brushes]::LimeGreen
    }

    # Keeps the UI responsive during the color change
    [System.Windows.Forms.Application]::DoEvents()
}