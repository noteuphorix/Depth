# 1. Define Paths relative to where this script is sitting
# $PSScriptRoot ensures this works regardless of the user's local directory structure
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
    # Skip the output file just in case it's in the same directory
    if ($File.FullName -eq $OutputFile) { continue }

    Write-Host "Merging: $($File.Name)" -ForegroundColor Cyan
    $CombinedFunctions += "`n# --- Function from $($File.Name) ---`n"
    $CombinedFunctions += Get-Content -Path $File.FullName -Raw
    $CombinedFunctions += "`n" 
}

# 4. Perform the Injection
if ($MainContent.Contains("# COMPILER_INSERT_HERE")) {
    # Use .Replace for a literal string swap (safer than regex)
    $FinalScript = $MainContent.Replace("# COMPILER_INSERT_HERE", $CombinedFunctions)
    
    # 5. Overwrite Depth.ps1 WITHOUT the hidden BOM character
    # This specifically addresses the "Add-Type not recognized" error for irm | iex
    
    # Create the UTF8 encoding object without a BOM signature
    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    
    # We split the string into an array of lines to use WriteAllLines for a cleaner save
    $FinalScriptLines = $FinalScript -split "`r?`n"
    
    # Write the file using .NET to bypass PowerShell 5.1's default BOM behavior
    [System.IO.File]::WriteAllLines($OutputFile, $FinalScriptLines, $Utf8NoBom)

    Write-Host "SUCCESS: Depth.ps1 generated at $OutputFile" -ForegroundColor Green
    Write-Host "Format: UTF-8 (No BOM) - Web Safe" -ForegroundColor Gray
} else {
    Write-Warning "Placeholder '# COMPILER_INSERT_HERE' not found in main.ps1."
}