function Get-UserInput {
    # 1. Minimize the GUI so you can see the terminal behind it
    $Main.WindowState = "Minimized"

    # 2. Capture the input (The GUI will stay minimized while this waits)
    Write-Host "`n[INPUT REQUIRED] Please type your input below:" -ForegroundColor Yellow
    $InputtedText = Read-Host "Enter your value"
    
    # 3. Store the value
    $global:UserTermInput = $InputtedText
    
    # 4. Restore the GUI now that the thread is free to draw again
    $Main.WindowState = "Normal"
    
    Write-Host "Input Saved: $global:UserTermInput" -ForegroundColor Green
}