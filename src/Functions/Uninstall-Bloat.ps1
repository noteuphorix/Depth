function Uninstall-Bloat {
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
        # 1. Get the real identity
        $Package = Get-AppxPackage -Name "*$App*" -ErrorAction SilentlyContinue

        if ($Package) {
            foreach ($Item in $Package) {
                $FullName = $Item.PackageFullName
                Write-Host "Removing: $FullName" -ForegroundColor Yellow
                
                # 2. Use the native PowerShell removal tool instead of winget
                # This is much faster and doesn't rely on winget's "source agreements" or "input criteria"
                try {
                    $Item | Remove-AppxPackage -ErrorAction Stop
                    $ProcessedList += $FullName
                } catch {
                    Write-Host "Failed to remove $App. It may be system-protected." -ForegroundColor Red
                }
            }
        }
    }

    Write-Host "`nFinished. Processed items:" -ForegroundColor Cyan
    Write-Host "Test"
    $ProcessedList | ForEach-Object { Write-Host " - $_" -ForegroundColor Yellow }
}