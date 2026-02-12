# 1. Define Paths relative to where this script is sitting
$CurrentFolder = $PSScriptRoot
$MainFile      = Join-Path -Path $CurrentFolder -ChildPath "main.ps1"
$OutputFile    = Join-Path -Path $CurrentFolder -ChildPath "Depth.ps1"

# --- NEW: Explicitly define which subfolders in 'src' to include ---
$TargetFolders = @("functions", "hd functions", "gui functions", "personal functions") 
# -------------------------------------------------------------------

# 2. Grab the Main script
if (Test-Path $MainFile) {
    $MainContent = Get-Content -Path $MainFile -Raw
} else {
    Write-Error "Could not find main.ps1 at $MainFile"; return
}

# 3. Collect all functions from specified directories
$CombinedFunctions = "`n"

foreach ($SubFolder in $TargetFolders) {
    $PathToScan = Join-Path -Path $CurrentFolder -ChildPath "src\$SubFolder"

    if (Test-Path $PathToScan) {
        Write-Host "Processing Folder: src\$SubFolder" -ForegroundColor Magenta
        $AllFiles = Get-ChildItem -Path $PathToScan -Filter "*.ps1"

        foreach ($File in $AllFiles) {
            # Skip the output file just in case it's in the same directory
            if ($File.FullName -eq $OutputFile) { continue }

            Write-Host "  Merging: $($File.Name)" -ForegroundColor Cyan
            $CombinedFunctions += "`n# --- Source: src\$SubFolder\$($File.Name) ---`n"
            $CombinedFunctions += Get-Content -Path $File.FullName -Raw
            $CombinedFunctions += "`n" 
        }
    } else {
        Write-Warning "Directory not found and skipped: $PathToScan"
    }
}

# 4. Perform the Injection
if ($MainContent.Contains("# COMPILER_INSERT_HERE")) {
    $FinalScript = $MainContent.Replace("# COMPILER_INSERT_HERE", $CombinedFunctions)
    
    # 5. Overwrite Depth.ps1 WITHOUT the hidden BOM character
    $Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $FinalScriptLines = $FinalScript -split "`r?`n"
    
    [System.IO.File]::WriteAllLines($OutputFile, $FinalScriptLines, $Utf8NoBom)

    Write-Host "`nSUCCESS: Depth.ps1 generated at $OutputFile" -ForegroundColor Green
    Write-Host "Format: UTF-8 (No BOM) - Web Safe" -ForegroundColor Gray
} else {
    Write-Warning "Placeholder '# COMPILER_INSERT_HERE' not found in main.ps1."
}