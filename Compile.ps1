# 1. Define Absolute Paths
$CurrentFolder = $PSScriptRoot
$MainFile      = Join-Path -Path $CurrentFolder -ChildPath "main.ps1"
$FunctionsDir  = Join-Path -Path $CurrentFolder -ChildPath "src\functions"
$OutputFile    = Join-Path -Path $CurrentFolder -ChildPath "Depth.ps1"

# 2. Grab the Main script
if (Test-Path $MainFile) {
    $MainContent = Get-Content -Path $MainFile -Raw
} else {
    Write-Error "Could not find main.ps1 at $MainFile"; return
}

# 3. Collect all functions into one string
$CombinedFunctions = "`n"
$AllFiles = Get-ChildItem -Path $FunctionsDir -Filter "*.ps1"

foreach ($File in $AllFiles) {
    # CRITICAL: Skip the output file if it happens to be in the same folder
    if ($File.FullName -eq $OutputFile) { continue }

    Write-Host "Merging: $($File.Name)" -ForegroundColor Cyan
    $CombinedFunctions += "`n# --- Function from $($File.Name) ---`n"
    $CombinedFunctions += Get-Content -Path $File.FullName -Raw
    $CombinedFunctions += "`n" 
}

# 4. Perform the Injection
if ($MainContent.Contains("# COMPILER_INSERT_HERE")) {
    # Using .Replace (Literal) instead of -replace (Regex) to avoid "Odd Behavior"
    $FinalScript = $MainContent.Replace("# COMPILER_INSERT_HERE", $CombinedFunctions)
    
    # 5. Overwrite Depth.ps1
    $FinalScript | Set-Content -Path $OutputFile -Encoding UTF8
    Write-Host "SUCCESS: Depth.ps1 generated." -ForegroundColor Green
} else {
    Write-Warning "Placeholder '# COMPILER_INSERT_HERE' not found in main.ps1."
}