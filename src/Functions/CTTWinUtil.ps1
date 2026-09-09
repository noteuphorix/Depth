<#
.SYNOPSIS
    Runs Chris Titus Tech's WinUtil unattended with a custom tweak selection.

.DESCRIPTION
    Writes out a WinUtil-compatible config JSON containing the specified tweak
    keys, then launches WinUtil with -Config <file> -Run so it applies them
    automatically (no manual "Run Tweaks" click required).

    NOTE: This still opens the WinUtil GUI window while it runs — WinUtil has
    no true headless/CLI-only mode as of this writing (see upstream issue
    https://github.com/ChrisTitusTech/winutil/issues/3138). If you need a
    fully invisible, no-window run, the tweaks would need to be reimplemented
    as plain registry/PowerShell commands instead of driven through WinUtil.

.NOTES
    Must be run as Administrator.

.EXAMPLE
    RunCTTWinUtilCustom
#>
function RunCTTWinUtilCustom {
    [CmdletBinding()]
    param()

    $ErrorActionPreference = 'Stop'

    # --- 1. Define the tweak selection -----------------------------------------
    $tweaks = @(
        "WPFTweaksConsumerFeatures",
        "WPFTweaksDisableExplorerAutoDiscovery",
        "WPFTweaksLocation",
        "WPFTweaksServices",
        "WPFTweaksTelemetry",
        "WPFTweaksDeliveryOptimization",
        "WPFTweaksDeleteTempFiles",
        "WPFTweaksEndTaskOnTaskbar",
        "WPFTweaksDisableStoreSearch",
        "WPFTweaksRevertStartMenu",
        "WPFTweaksWindowsAI",
        "WPFTweaksRightClickMenu",
        "WPFTweaksEdgeDebloat",
        "WPFTweaksDisableWarningForUnsignedRdp"
    )

    # --- 2. Write the config file WinUtil expects -------------------------------
    # Current WinUtil config format is a flat JSON array of selection keys.
    $configPath = Join-Path -Path $env:TEMP -ChildPath "winutil-custom-config.json"
    $tweaks | ConvertTo-Json | Set-Content -Path $configPath -Encoding UTF8

    Write-Host "Wrote WinUtil config to: $configPath" -ForegroundColor Cyan
    Write-Host "Selected tweaks:" -ForegroundColor Cyan
    $tweaks | ForEach-Object { Write-Host "  - $_" }

    # --- 3. Launch WinUtil unattended, in its own console --------------------
    # WinUtil calls Clear-Host on startup. Running it inline shares the current
    # console/host, which would wipe out everything printed by the calling
    # script/GUI. Spawning it as a separate powershell.exe process isolates
    # its console so it can't touch the parent window's buffer.
    Write-Host "`nLaunching WinUtil in a separate window with -Config -Run ..." -ForegroundColor Yellow

    $winutilCommand = "& ([ScriptBlock]::Create((irm https://christitus.com/win))) -Config `"$configPath`" -Run"

    Start-Process -FilePath "powershell.exe" `
        -ArgumentList @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-Command", $winutilCommand
        ) `
        -Verb RunAs `
        -Wait

    Write-Host "`nDone. Check the WinUtil window/log for per-tweak results." -ForegroundColor Green
}