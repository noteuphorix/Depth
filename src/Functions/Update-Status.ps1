function Update-Status {
    param(
        [string]$Message,
        [ValidateSet("Busy", "Ready")]
        [string]$State
    )

    $LblStatus.Content = $Message

    if ($State -eq "Busy") {
        $LblStatus.Foreground = [System.Windows.Media.Brushes]::Red
    } else {
        $LblStatus.Foreground = [System.Windows.Media.Brushes]::LimeGreen
    }

}