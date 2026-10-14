function Write-ErrorDetails {
    # Prints everything an error carries: every wrapped exception (type, message, HResult), the
    # command and line it came from, and the script stack trace.
    param([System.Management.Automation.ErrorRecord]$Record)

    $ex = $Record.Exception
    $depth = 0
    while ($ex) {
        $indent = '  ' * ($depth + 1)
        Write-Host "$indent[$($ex.GetType().FullName)] $($ex.Message)" -ForegroundColor Red
        Write-Host ("$indent  HResult: 0x{0:X8}" -f $ex.HResult) -ForegroundColor Red
        if ($ex -is [System.Management.Automation.IContainsErrorRecord] -and $ex.ErrorRecord.InvocationInfo.MyCommand) {
            Write-Host "$indent  Command: $($ex.ErrorRecord.InvocationInfo.MyCommand)" -ForegroundColor Red
        }
        $ex = $ex.InnerException
        $depth++
    }
    Write-Host "  Category: $($Record.CategoryInfo)" -ForegroundColor Red
    Write-Host "  Error ID: $($Record.FullyQualifiedErrorId)" -ForegroundColor Red
    if ($Record.InvocationInfo.PositionMessage) {
        Write-Host "  Position: $($Record.InvocationInfo.PositionMessage)" -ForegroundColor Red
    }
    if ($Record.ScriptStackTrace) {
        Write-Host "  Stack trace:`n$($Record.ScriptStackTrace)" -ForegroundColor Red
    }
}
