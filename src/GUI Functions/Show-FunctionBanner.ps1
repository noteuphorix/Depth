function Show-FunctionBanner {
    param(
        [string]$Text
    )
    $len = $Text.Length + 8
    $line = "-" * $len
    Write-Host ""
    Write-Host $line -ForegroundColor Cyan
    Write-Host "--- $Text ---" -ForegroundColor Green
    Write-Host $line -ForegroundColor Cyan
}