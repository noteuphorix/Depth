function Update-Windows {
    # Talks to the Windows Update Agent COM API directly instead of going through PSWindowsUpdate.
    # Each update is installed on its own: some updates (servicing stack etc.) must be installed
    # alone, and putting one in a batch makes the whole batch fail with nothing installed. Updates
    # whose details can't be read are skipped instead of failing the run (PSWindowsUpdate threw
    # "Value does not fall within the expected range." on those).
    # The monthly Windows cumulative/security update (e.g. "2026-11 Security Update (KB5132061)") is
    # huge and slow, so it's skipped here and left for NinjaOne to patch later. It is only skipped in
    # this function, not hidden or blocked in Windows Update. -IncludeWindowsCumulative installs it too.
    param([switch]$IncludeWindowsCumulative)

    Show-FunctionBanner "Windows Update"

    $ErrorActionPreference = 'Stop'

    $maxPasses   = 3
    # Each update gets its first try plus one retry in a later pass.
    $maxTries    = 2
    $resultText  = @{ 0 = 'not started'; 1 = 'in progress'; 2 = 'succeeded'; 3 = 'succeeded with errors'; 4 = 'FAILED'; 5 = 'aborted' }

    $tries        = @{}
    $skippedList  = New-Object System.Collections.ArrayList
    # Monthly Windows cumulative titles start with the year-month and then "Security Update" or
    # "Cumulative Update" directly (.NET, Defender and driver titles don't). Drivers are never skipped.
    $cumulativePattern = '^\d{4}-\d{2} (Security|Cumulative) Update\b'
    $cumulativeSkipped = 0
    # Title -> $true. An update that fails and then succeeds on its retry is removed again.
    $failedList   = [ordered]@{}
    $okCount      = 0
    $rebootNeeded = $false
    $sanityChecked = $false
    $passesRun    = 0
    $passesFailed = 0

    $writeSummary = {
        Write-Host "`n=== Summary ===" -ForegroundColor Cyan
        Write-Host "Installed: $okCount   Failed: $($failedList.Count)   Skipped: $($skippedList.Count)"
        $failedList.Keys | ForEach-Object { Write-Host "  failed:  $_" -ForegroundColor Red }
        $skippedList | ForEach-Object { Write-Host "  skipped: $_" -ForegroundColor Yellow }
    }

    # Updates arrive in layers (servicing stack -> cumulative -> .NET etc.), so keep scanning and
    # installing until nothing is left. A pass that errors out still counts toward the limit.
    for ($pass = 1; $pass -le $maxPasses; $pass++) {
        $passesRun++
        Write-Host "`n=== Pass $pass of $maxPasses ===" -ForegroundColor Cyan

        try {
            # A pending reboot can make the scan come back empty or installs fail, which isn't
            # "up to date", so restart first.
            if ((New-Object -ComObject Microsoft.Update.SystemInfo).RebootRequired) {
                & $writeSummary
                Write-Host "Restart required before more updates can be found. Restarting in ten seconds." -ForegroundColor White -BackgroundColor DarkRed
                shutdown /f /t 10 /r
                return
            }

            # Read the Microsoft Update (Office, drivers, other Microsoft products) service ID from
            # this machine's registered services. A fresh image may not have it registered yet, so
            # register it with Microsoft's published ID and read it back.
            $serviceManager = New-Object -ComObject Microsoft.Update.ServiceManager
            $serviceManager.ClientApplicationID = 'Depth'
            $msUpdateId = ($serviceManager.Services | Where-Object { $_.Name -eq 'Microsoft Update' } | Select-Object -First 1).ServiceID
            if (-not $msUpdateId) {
                Write-Host "Microsoft Update service not registered, registering it..." -ForegroundColor Cyan
                # 7 = allow pending registration + allow online registration + register with Automatic Updates
                [void]$serviceManager.AddService2('7971f918-a847-4430-9279-4a52d1efe18d', 7, '')
                $msUpdateId = ($serviceManager.Services | Where-Object { $_.Name -eq 'Microsoft Update' } | Select-Object -First 1).ServiceID
                if (-not $msUpdateId) { throw "Microsoft Update service could not be registered." }
            }
            Write-Host "Using Microsoft Update service $msUpdateId" -ForegroundColor DarkGray

            $session = New-Object -ComObject Microsoft.Update.Session
            $session.ClientApplicationID = 'Depth'

            Write-Host "Searching Microsoft Update (can take a minute)..." -ForegroundColor Cyan
            $searcher = $session.CreateUpdateSearcher()
            $searcher.ServerSelection = 3   # ssOthers - search the service in ServiceID
            $searcher.ServiceID = $msUpdateId
            $found = $searcher.Search("IsInstalled=0 and IsHidden=0")
            Write-Host "Found $($found.Updates.Count) update(s)"

            $todo = New-Object System.Collections.ArrayList
            foreach ($u in $found.Updates) {
                try {
                    $id = $u.Identity.UpdateID
                    if ($tries[$id] -ge $maxTries) { continue }
                    # Reading IsDownloaded throws on updates whose data can't be read - skip those.
                    $null = $u.IsDownloaded

                    # Skip the monthly Windows cumulative (software only, type 1 - never a driver).
                    # If its type or title can't be read, it's treated as a normal update.
                    $isCumulative = $false
                    if (-not $IncludeWindowsCumulative) {
                        try { $isCumulative = ([int]$u.Type -eq 1) -and ($u.Title -match $cumulativePattern) } catch { }
                    }
                    if ($isCumulative) {
                        $skipNote = "$($u.Title) (Windows cumulative, left for NinjaOne)"
                        if (-not $skippedList.Contains($skipNote)) {
                            [void]$skippedList.Add($skipNote)
                            $cumulativeSkipped++
                            Write-Host "Skipping (Windows cumulative, left for NinjaOne): $($u.Title)" -ForegroundColor Yellow
                        }
                        continue
                    }

                    if (-not $u.EulaAccepted) { $u.AcceptEula() }
                    [void]$todo.Add($u)
                } catch {
                    if (-not $skippedList.Contains($u.Title)) {
                        [void]$skippedList.Add($u.Title)
                        Write-Host "Skipping (unreadable): $($u.Title)" -ForegroundColor Yellow
                    }
                }
            }

            if ($todo.Count -eq 0) {
                if ($failedList.Count -gt 0) {
                    Write-Host "No updates left to install (failed ones have used their retry)." -ForegroundColor Yellow
                } elseif ($cumulativeSkipped -gt 0) {
                    Write-Host "Windows is up to date (except the skipped Windows cumulative update, left for NinjaOne)." -ForegroundColor Green
                } else {
                    Write-Host "Windows is up to date." -ForegroundColor Green
                }
                # The first "up to date" can be premature, so scan once more. This extra scan
                # doesn't count as a pass, and anything it finds gets installed as normal.
                if (-not $sanityChecked) {
                    $sanityChecked = $true
                    Write-Host "Sanity Check! D:" -ForegroundColor Yellow
                    $pass--
                    $passesRun--
                    continue
                }
                & $writeSummary
                return
            }

            Write-Host "$($todo.Count) update(s) to install" -ForegroundColor Cyan
            # Trim drops the blank lines Format-Table pads around the table.
            $table = $todo | ForEach-Object {
                [pscustomobject]@{ Title = $_.Title; 'Size (MB)' = [math]::Round(([double]$_.MaxDownloadSize) / 1MB, 1) }
            } | Format-Table -AutoSize | Out-String
            Write-Host "`n$($table.Trim())`n"

            # Download every update for this pass before installing, one update per call so each one's
            # progress is printed (a single batched Download() call blocks with no output until all are done).
            # Plain lines rather than Write-Progress: in Windows PowerShell 5.1 the progress bar is drawn
            # over the top of the console and hides the update list.
            # Updates that fail to download are left out of the install.
            $downloadFailed = @{}
            $toDownload = @($todo | Where-Object { -not $_.IsDownloaded })
            if ($toDownload.Count -gt 0) {
                Write-Host "Downloading $($toDownload.Count) update(s)..." -ForegroundColor Cyan
                $downloadErrors = 0
                $n = 0
                foreach ($u in $toDownload) {
                    $n++
                    Write-Host "[$n/$($toDownload.Count)] downloading $($u.Title)..."
                    try {
                        $c = New-Object -ComObject Microsoft.Update.UpdateColl
                        [void]$c.Add($u)
                        $downloader = $session.CreateUpdateDownloader()
                        $downloader.Updates = $c
                        $downloader.Priority = 3   # dpHigh
                        $rc = [int]$downloader.Download().ResultCode
                        if ($rc -eq 2 -or $rc -eq 3) {
                            Write-Host "[$n/$($toDownload.Count)] downloaded - $($u.Title)" -ForegroundColor Green
                        } else {
                            $downloadFailed[$u.Identity.UpdateID] = $resultText[$rc]
                            Write-Host "[$n/$($toDownload.Count)] download $($resultText[$rc]) - $($u.Title)" -ForegroundColor Red
                        }
                    } catch {
                        # If the download call itself blows up, the install loop below downloads it again on its own.
                        $downloadErrors++
                        Write-Host "[$n/$($toDownload.Count)] download error, will retry before installing: $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                }

                $downloadedCount = $toDownload.Count - $downloadFailed.Count - $downloadErrors
                if ($downloadFailed.Count -eq 0 -and $downloadErrors -eq 0) {
                    Write-Host "Downloaded $downloadedCount of $($toDownload.Count) update(s)." -ForegroundColor Green
                } else {
                    Write-Host "Downloaded $downloadedCount of $($toDownload.Count) update(s), $($downloadFailed.Count) failed, $downloadErrors to retry." -ForegroundColor Yellow
                }
            }

            Write-Host ""
            Write-Host " Installing $($todo.Count) update(s) " -ForegroundColor White -BackgroundColor DarkBlue
            $n = 0
            foreach ($u in $todo) {
                $n++
                $tries[$u.Identity.UpdateID] = [int]$tries[$u.Identity.UpdateID] + 1
                $retryNote = if ($tries[$u.Identity.UpdateID] -gt 1) { ' (retry)' } else { '' }
                Write-Host "[$n/$($todo.Count)] $($u.Title)$retryNote"

                try {
                    if ($downloadFailed.ContainsKey($u.Identity.UpdateID)) {
                        Write-Host "    download $($downloadFailed[$u.Identity.UpdateID])" -ForegroundColor Red
                        $failedList[$u.Title] = $true
                        continue
                    }

                    $c = New-Object -ComObject Microsoft.Update.UpdateColl
                    [void]$c.Add($u)

                    if (-not $u.IsDownloaded) {
                        Write-Host "    downloading..."
                        $d = $session.CreateUpdateDownloader()
                        $d.Updates = $c
                        $d.Priority = 3
                        $r = $d.Download()
                        if ([int]$r.ResultCode -ne 2) {
                            Write-Host "    download $($resultText[[int]$r.ResultCode])" -ForegroundColor Red
                            $failedList[$u.Title] = $true
                            continue
                        }
                    }

                    Write-Host "    installing..."
                    $installer = $session.CreateUpdateInstaller()
                    $installer.Updates = $c
                    # This runs in a background runspace with nobody to answer prompts.
                    $installer.ForceQuiet = $true
                    $installer.AllowSourcePrompts = $false
                    $ir = $installer.Install()
                    $rc = [int]$ir.ResultCode
                    if ($ir.RebootRequired) { $rebootNeeded = $true }

                    if ($rc -eq 2 -or $rc -eq 3) {
                        Write-Host "    $($resultText[$rc])" -ForegroundColor Green
                        $okCount++
                        $failedList.Remove($u.Title)
                    } else {
                        Write-Host "    $($resultText[$rc])" -ForegroundColor Red
                        $failedList[$u.Title] = $true
                    }
                } catch {
                    Write-Host "    error: $($_.Exception.Message)" -ForegroundColor Red
                    $failedList[$u.Title] = $true
                }
            }

            if ($rebootNeeded) {
                & $writeSummary
                Write-Host "Restart required to finish installing. Restarting in ten seconds." -ForegroundColor White -BackgroundColor DarkRed
                shutdown /f /t 10 /r
                return
            }
        } catch {
            $passesFailed++
            Write-Host "Windows Update pass $pass/$maxPasses failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-ErrorDetails $_
        }

        # Give Windows Update time to settle before the next scan.
        if ($pass -lt $maxPasses) {
            Write-Host "Waiting 30 seconds before checking for more updates..." -ForegroundColor Cyan
            Start-Sleep -Seconds 30
        }
    }

    & $writeSummary

    # A restart often clears whatever is blocking Windows Update.
    if ($passesFailed -eq $passesRun) {
        Write-Host "`nWindows Update failed $passesFailed times in a row (see errors above)." -ForegroundColor Red
        Write-Host "Windows Update failing, restarting in ten seconds." -ForegroundColor White -BackgroundColor DarkRed
        shutdown /f /t 10 /r
        return
    }

    Write-Host "Still finding updates after $maxPasses passes. Run Windows Update again." -ForegroundColor Yellow
}

<#
================================================================================================
PREVIOUS Update-Windows (PSWindowsUpdate module) - COMMENTED OUT FOR SAFETY, NOT DELETED
================================================================================================
Replaced 2026-11-10 by the COM-based version above, which is faster and doesn't fail on the one
update this version always errored on ("Value does not fall within the expected range." /
0x80248007). To go back: delete the new function above and remove the block-comment markers
that open and close this block.

How this version worked:
  - Param -AutoReboot: passed -AutoReboot to Install-WindowsUpdate instead of -IgnoreReboot.
    Nothing actually called it with that switch.
  - Set TLS 1.2 and a process-scoped Bypass execution policy (needed to pull from PSGallery).
  - Up to 5 ATTEMPTS. Each attempt:
      * Installed the NuGet provider + PSWindowsUpdate from PSGallery if missing, then imported it.
      * Up to 5 ROUNDS of:
          - If Get-WURebootStatus said a reboot was pending: shutdown /f /t 10 /r and stop.
          - Get-WindowsUpdate -MicrosoftUpdate. If nothing was found, did ONE "Sanity Check! D:"
            rescan (resetting the rounds back to 1); if still nothing, "Windows is up to date".
          - Install-WindowsUpdate -MicrosoftUpdate -AcceptAll (all updates in one batch).
          - Waited 30 seconds before the next round.
      * After 5 rounds still finding updates: told you to run it again.
      * If anything threw: logged it with Write-ErrorDetails, ran Reset-WUComponents (stop WU
        services, clear SoftwareDistribution/catroot2) and retried. The reset was dropped from the
        new version because it never actually got past the module's error.
  - If all 5 attempts failed: shutdown /f /t 10 /r.

function Update-Windows {
    # -AutoReboot restarts the machine once updates install (if they need a reboot) instead of
    # suppressing it. Repair-Winget uses this when App Installer is stuck.
    param([switch]$AutoReboot)

    Show-FunctionBanner "Windows Update"

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

    # Windows Update can fail partway through (e.g. 0x80248007 when an update's data disappears
    # mid-run, or "Value does not fall within the expected range.") and a fresh run usually gets
    # past it. Retry with the same flags up to 5 times.
    $maxAttempts = 5
    $maxRounds = 5
    $sanityChecked = $false

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        if ($attempt -gt 1) {
            Write-Host "`nRetrying Windows Update (attempt $attempt/$maxAttempts)..." -ForegroundColor Yellow
        }

        try {
            Write-Host "Preparing PSWindowsUpdate module..." -ForegroundColor Cyan
            if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
                Write-Host "PSWindowsUpdate module not found, installing the NuGet provider and PSWindowsUpdate from PSGallery..." -ForegroundColor Red
                Install-PackageProvider -Name NuGet -Force
                Install-Module -Name PSWindowsUpdate -Force -Repository PSGallery
                Write-Host "PSWindowsUpdate module installed." -ForegroundColor Green
            }
            Import-Module PSWindowsUpdate

            # Updates arrive in layers (servicing stack -> cumulative -> .NET etc.), so keep checking
            # and installing until nothing is left. A pending reboot is checked first because
            # Get-WindowsUpdate can come back empty while one is pending, which isn't "up to date".
            for ($round = 1; $round -le $maxRounds; $round++) {
                if (Get-WURebootStatus -Silent) {
                    Write-Host "Restart required before more updates can be found. Restarting in ten seconds." -ForegroundColor White -BackgroundColor DarkRed
                    shutdown /f /t 10 /r
                    return
                }

                Write-Host "Checking for available updates (round $round/$maxRounds)..." -ForegroundColor Cyan
                # Get-WindowsUpdate outputs its results as one list object, so unroll it to count updates.
                $updates = @(Get-WindowsUpdate -MicrosoftUpdate | ForEach-Object { $_ })
                if ($updates.Count -eq 0) {
                    Write-Host "Windows is up to date." -ForegroundColor Green
                    # The first "up to date" can be premature, so scan once more. Resetting $round
                    # restarts the rounds at 1, so any updates that scan finds go through the full loop.
                    if (-not $sanityChecked) {
                        $sanityChecked = $true
                        Write-Host "Sanity Check! D:" -ForegroundColor Yellow
                        $round = 0
                        continue
                    }
                    return
                }
                $updates | Format-Table -AutoSize | Out-String | Write-Host

                Write-Host "Installing $($updates.Count) update(s)..." -ForegroundColor Cyan
                if ($AutoReboot) {
                    Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot | Format-Table -AutoSize | Out-String | Write-Host
                } else {
                    Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot | Format-Table -AutoSize | Out-String | Write-Host
                }

                # Give Windows Update time to settle before the next scan.
                if ($round -lt $maxRounds) {
                    Write-Host "Waiting 30 seconds before checking for more updates..." -ForegroundColor Cyan
                    Start-Sleep -Seconds 30
                }
            }

            Write-Host "Still finding updates after $maxRounds rounds. Run Windows Update again." -ForegroundColor Yellow
            return
        } catch {
            Write-Host "Windows Update attempt $attempt/$maxAttempts failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-ErrorDetails $_

            # Windows Update can get stuck in a state where every scan fails (e.g. after some driver
            # updates). Resetting the Windows Update components clears it, so the next attempt can scan.
            if ($attempt -lt $maxAttempts) {
                Write-Host "Resetting Windows Update components before the next attempt..." -ForegroundColor Yellow
                try {
                    Reset-WUComponents
                } catch {
                    Write-Host "Reset-WUComponents failed:" -ForegroundColor Red
                    Write-ErrorDetails $_
                }
            }
        }
    }

    # Success returns inside the loop, so reaching this point means every attempt failed.
    # A restart often clears whatever is blocking Windows Update.
    Write-Host "`nWindows Update failed $maxAttempts times in a row (see errors above)." -ForegroundColor Red
    Write-Host "Windows Update failing, restarting in ten seconds." -ForegroundColor White -BackgroundColor DarkRed
    shutdown /f /t 10 /r
}
#>
