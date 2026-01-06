function Uninstall-Bloat {
    # Suppress the "Deployment operation progress" bar
    $OldProgress = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'

    $Bloatware = @(
        "Microsoft.Xbox.TCUI", "Microsoft.XboxGameOverlay", "Microsoft.XboxGamingOverlay",
        "Microsoft.XboxIdentityProvider", "Microsoft.XboxSpeechToTextOverlay", "Microsoft.GamingApp",
        "Microsoft.549981C3F5F10", "Microsoft.MicrosoftSolitaireCollection", "Microsoft.BingNews",
        "Microsoft.Bingweather", "Microsoft.BingSearch", "Microsoft.Office.OneNote",
        "Microsoft.Microsoft3DViewer", "Microsoft.MicrosoftPeople", "Microsoft.MicrosoftOfficeHub",
        "Microsoft.WindowsAlarms", "Microsoft.WindowsCamera", "Microsoft.WindowsMaps",
        "Microsoft.WindowsFeedbackHub", "Microsoft.WindowsSoundRecorder", "Microsoft.YourPhone",
        "Microsoft.ZuneMusic", "Microsoft.ZuneVideo", "Microsoft.MicrosoftStickyNotes",
        "Microsoft.GetHelp", "Microsoft.Getstarted", "Microsoft.Messaging",
        "Microsoft.OneConnect", "Microsoft.Todos", "Microsoft.People",
        "Microsoft.Edge.GameAssist", "Microsoft.SkypeApp", "SpotifyAB.SpotifyMusic",
        "Microsoft.Copilot", "Microsoft.Teams.Classic", "MicrosoftCorporationII.MicrosoftFamily",
        "Clipchamp.Clipchamp", "Microsoft.XboxGameCallableUI"
    )

    $ProcessedList = @()
    Write-Host "Forcing removal of bloatware via AppxManifest..." -ForegroundColor Cyan

    foreach ($App in $Bloatware) {
        $Package = Get-AppxPackage -Name "*$App*" -ErrorAction SilentlyContinue

        if ($Package) {
            foreach ($Item in $Package) {
                $FullName = $Item.PackageFullName
                
                # Using Write-Progress or custom messages keeps it tidy
                Write-Host "Removing: $App" -ForegroundColor Yellow
                
                try {
                    # Removing -ErrorAction Stop from here so it doesn't break the script, 
                    # we handle the "nastiness" in the catch block
                    $Item | Remove-AppxPackage -ErrorAction SilentlyContinue
                    $ProcessedList += $App
                } catch {
                    # This only triggers if something major breaks
                }
            }
        }
    }

    # Restore the progress bar setting for other scripts
    $ProgressPreference = $OldProgress

    Write-Host "`nFinished processing bloatware." -ForegroundColor Cyan
    Write-Host "Items successfully removed: $($ProcessedList.Count)" -ForegroundColor Gray
}