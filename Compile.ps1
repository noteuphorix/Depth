# 1. Define Absolute Paths
$MainFile      = "C:\users\euphoria\source\repos\depth\main.ps1"
$FunctionsDir  = "C:\users\euphoria\source\repos\depth\src\functions"
$OutputFile    = "C:\users\euphoria\source\repos\depth\Depth.ps1"

# 2. Grab the Main script
if (Test-Path $MainFile) {
    $MainContent = Get-Content -Path $MainFile -Raw
} else {
    Write-Error "Could not find main.ps1 at $MainFile"; return
}

# 3. Collect all functions into one string
$CombinedFunctions = ""
$AllFiles = Get-ChildItem -Path $FunctionsDir -Filter "*.ps1"

foreach ($File in $AllFiles) {
    Write-Host "Merging: $($File.Name)" -ForegroundColor Gray
    $CombinedFunctions += "`n# --- Function from $($File.Name) ---`n"
    $CombinedFunctions += Get-Content -Path $File.FullName -Raw
    $CombinedFunctions += "`n" 
}

# 4. Perform the Injection
# This looks for your # COMPILER_INSERT_HERE tag and swaps it for the functions
if ($MainContent -match "# COMPILER_INSERT_HERE") {
    $FinalScript = $MainContent -replace "# COMPILER_INSERT_HERE", $CombinedFunctions
    
    # 5. Overwrite Depth.ps1
    $FinalScript | Set-Content -Path $OutputFile -Encoding UTF8
    Write-Host "SUCCESS: Depth.ps1 updated at $OutputFile" -ForegroundColor Green
} else {
    Write-Warning "Placeholder '# COMPILER_INSERT_HERE' not found in main.ps1. No injection performed."
}