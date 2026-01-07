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
    Write-Host "Forcing removal of bloatware for ALL users..." -ForegroundColor Cyan

    foreach ($App in $Bloatware) {
        # 1. Added -AllUsers here to find the app in every profile (including the standard user)
        $Package = Get-AppxPackage -Name "*$App*" -AllUsers -ErrorAction SilentlyContinue

        if ($Package) {
            foreach ($Item in $Package) {
                $FullName = $Item.PackageFullName
                
                Write-Host "Removing: $App (System-wide)" -ForegroundColor Yellow
                
                try {
                    # 2. Added -AllUsers here to execute the removal across all profiles
                    $Item | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                    $ProcessedList += $App
                } catch {
                    # Errors handled silently for cleaner output
                }
            }
        }
    }

    # Restore the progress bar setting
    $ProgressPreference = $OldProgress

    Write-Host "`nFinished processing bloatware." -ForegroundColor Cyan
    Write-Host "Items successfully removed: $($ProcessedList.Count)" -ForegroundColor Gray
}