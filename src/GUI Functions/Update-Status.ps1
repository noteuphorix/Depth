function Update-Status {
    param(
        [ValidateSet("Busy", "Ready")]
        [string]$State
    )

    $ellipse = $sync.Main.FindName("Ellipse_StatusLight")

    if ($State -eq "Busy") {
        $ellipse.Fill = [System.Windows.Media.Brushes]::Red
    } else {
        $ellipse.Fill = [System.Windows.Media.Brushes]::LimeGreen
    }

    [System.Windows.Forms.Application]::DoEvents()
}