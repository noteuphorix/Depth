function Uninstall-Bloat {
    $Bloatware = @(
        "Microsoft.Xbox.TCUI_8wekyb3d8bbwe",
        "Microsoft.XboxGameOverlay_8wekyb3d8bbwe",
        "Microsoft.XboxGamingOverlay_8wekyb3d8bbwe",
        "Microsoft.XboxIdentityProvider_8wekyb3d8bbwe",
        "Microsoft.XboxSpeechToTextOverlay_8wekyb3d8bbwe",
        "Microsoft.GamingApp_8wekyb3d8bbwe",
        "Microsoft.549981C3F5F10_8wekyb3d8bbwe", # Cortana
        "Microsoft.MicrosoftSolitaireCollection_8wekyb3d8bbwe",
        "Microsoft.BingNews_8wekyb3d8bbwe",
        "Microsoft.Bingweather_8wekyb3d8bbwe",
        "Microsoft.BingSearch_8wekyb3d8bbwe",
        "Microsoft.Office.OneNote",
        "Microsoft.Microsoft3DViewer_8wekyb3d8bbwe",
        "Microsoft.MicrosoftPeople_8wekyb3d8bbwe",
        "Microsoft.MicrosoftOfficeHub_8wekyb3d8bbwe",
        "Microsoft.WindowsAlarms_8wekyb3d8bbwe",
        "Microsoft.WindowsCamera_8wekyb3d8bbwe",
        "Microsoft.WindowsMaps_8wekyb3d8bbwe",
        "Microsoft.WindowsFeedbackHub_8wekyb3d8bbwe",
        "Microsoft.WindowsSoundRecorder_8wekyb3d8bbwe",
        "Microsoft.YourPhone_8wekyb3d8bbwe",
        "Microsoft.ZuneMusic_8wekyb3d8bbwe",
        "Microsoft.ZuneVideo_8wekyb3d8bbwe",
        "Microsoft.MicrosoftStickyNotes_8wekyb3d8bbwe",
        "Microsoft.GetHelp_8wekyb3d8bbwe",
        "Microsoft.Getstarted_8wekyb3d8bbwe", # Microsoft Tips
        "Microsoft.Messaging_8wekyb3d8bbwe",
        "Microsoft.OneConnect_8wekyb3d8bbwe",
        "Microsoft.Todos_8wekyb3d8bbwe",
        "Microsoft.People_8wekyb3d8bbwe",
        "Microsoft.Edge.GameAssist_8wekyb3d8bbwe",
        "Microsoft.SkypeApp",
        "SpotifyAB.SpotifyMusic_zpdnekdrzrea0",
        "Microsoft.Copilot_8wekyb3d8bbwe",
        "Microsoft.Teams.Classic",
        "MicrosoftCorporationII.MicrosoftFamily_8wekyb3d8bbwe",
        "Clipchamp.Clipchamp_yxz26nhyzhsrt",
        "Xbox Game Bar Plugin",
        "Xbox Game Bar",
        "Xbox Game Speech Window"
        "Copilot"
    )

    $ProcessedList = @()
    
    # Get the raw list once to check against
    $CurrentApps = winget list --accept-source-agreements

    foreach ($App in $Bloatware) {
        # Check if YOUR exact string exists anywhere in the winget list output
        if ($CurrentApps -match [regex]::Escape($App)) {
            
            # Execute uninstall using ONLY your string from the array
            Start-Process winget -ArgumentList "uninstall `"$App`" --silent --force --purge --accept-source-agreements" -Wait -NoNewWindow
            
            $ProcessedList += $App
        }
    }

    Write-Host "`nFinished processing bloatware list. The following items were processed:" -ForegroundColor Cyan
    foreach ($Entry in $ProcessedList) {
        Write-Host $Entry -ForegroundColor Yellow
    }
}