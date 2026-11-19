function Update-Windows {
    # Talks to the Windows Update Agent COM API directly instead of going through PSWindowsUpdate.
    # Each update is installed on its own: some updates (servicing stack etc.) must be installed
    # alone, and putting one in a batch makes the whole batch fail with nothing installed. Updates
    # whose details can't be read are skipped instead of failing the run (PSWindowsUpdate threw
    # "Value does not fall within the expected range." on those).
    # The monthly Windows cumulative/security update (e.g. "2026-11 Security Update (KB5132061)") is
    # huge and slow, so it's skipped here and left for NinjaOne to patch later. The monthly Windows
    # preview update (e.g. "2026-10 Preview Update (KB5127936)") is skipped the same way. They are only
    # skipped in this function, not hidden or blocked in Windows Update. -IncludeWindowsCumulative and
    # -IncludeWindowsPreview install them too.
    param(
        [switch]$IncludeWindowsCumulative,
        [switch]$IncludeWindowsPreview
    )

    Show-FunctionBanner "Windows Update"

    $ErrorActionPreference = 'Stop'

    $maxPasses   = 3
    # Each update gets its first try plus one retry in a later pass.
    $maxTries    = 2
    $resultText  = @{ 0 = 'not started'; 1 = 'in progress'; 2 = 'succeeded'; 3 = 'succeeded with errors'; 4 = 'FAILED'; 5 = 'aborted' }

    $tries        = @{}
    $skippedList  = New-Object System.Collections.ArrayList
    # Updates skipped here and left for NinjaOne. To skip something new, add a row. Titles start with
    # the year-month (any month) and then the kind of update. Only software updates (type 1) are
    # matched - drivers are never skipped. Include = $true lets that kind install after all.
    $skipRules = @(
        @{ Name = 'Windows cumulative'; Pattern = '^\d{4}-\d{2} (Security|Cumulative) Update\b'; Include = $IncludeWindowsCumulative }
        @{ Name = 'Windows preview';    Pattern = '^\d{4}-\d{2} Preview Update\b';               Include = $IncludeWindowsPreview }
    )
    $ruleSkipped = 0
    # Title -> $true. An update that fails and then succeeds on its retry is removed again.
    $failedList   = [ordered]@{}
    $okCount      = 0
    $rebootNeeded = $false
    $sanityChecked = $false
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
        Write-Host "`n=== Pass $pass of $maxPasses ===" -ForegroundColor Cyan

        try {
            # A pending reboot can make the scan come back empty or installs fail, which isn't
            # "up to date", so restart first.
            if ((New-Object -ComObject Microsoft.Update.SystemInfo).RebootRequired) {
                & $writeSummary
                Write-Host "Restart required before more updates can be found. Restarting in ten seconds." -ForegroundColor White -BackgroundColor DarkRed
                Register-OneShot
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

                    # Skip anything matching a skip rule (software only, type 1 - never a driver).
                    # If its type or title can't be read, it's treated as a normal update.
                    $skipRule = $null
                    try {
                        if ([int]$u.Type -eq 1) {
                            $skipRule = $skipRules | Where-Object { -not $_.Include -and $u.Title -match $_.Pattern } | Select-Object -First 1
                        }
                    } catch { }
                    if ($skipRule) {
                        $skipNote = "$($u.Title) ($($skipRule.Name), left for NinjaOne)"
                        if (-not $skippedList.Contains($skipNote)) {
                            [void]$skippedList.Add($skipNote)
                            $ruleSkipped++
                            Write-Host "Skipping ($($skipRule.Name), left for NinjaOne): $($u.Title)" -ForegroundColor Yellow
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
                } elseif ($ruleSkipped -gt 0) {
                    Write-Host "Windows is up to date (except the skipped updates, left for NinjaOne)." -ForegroundColor Green
                } else {
                    Write-Host "Windows is up to date." -ForegroundColor Green
                }
                # The first "up to date" can be premature, so scan once more. $pass-- keeps this
                # extra scan from counting as a pass; anything it finds gets installed as normal.
                if (-not $sanityChecked) {
                    $sanityChecked = $true
                    Write-Host "Sanity Check! D:" -ForegroundColor Yellow
                    $pass--
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

            # Each update is downloaded and then installed before moving to the next, one update per
            # call so each one's progress is printed (a single batched Download() call blocks with no
            # output until all are done). Plain lines rather than Write-Progress: in Windows PowerShell
            # 5.1 the progress bar is drawn over the top of the console and hides the update list.
            # An update that fails to download is marked failed and retried in the next pass.
            Write-Host ""
            Write-Host " Installing $($todo.Count) update(s) " -ForegroundColor White -BackgroundColor DarkBlue
            $n = 0
            foreach ($u in $todo) {
                $n++
                $tries[$u.Identity.UpdateID] = [int]$tries[$u.Identity.UpdateID] + 1
                $retryNote = if ($tries[$u.Identity.UpdateID] -gt 1) { ' (retry)' } else { '' }
                Write-Host "[$n/$($todo.Count)] $($u.Title)$retryNote"

                try {
                    $c = New-Object -ComObject Microsoft.Update.UpdateColl
                    [void]$c.Add($u)

                    if (-not $u.IsDownloaded) {
                        Write-Host "    downloading..."
                        $d = $session.CreateUpdateDownloader()
                        $d.Updates = $c
                        $d.Priority = 3   # dpHigh
                        $rc = [int]$d.Download().ResultCode
                        if ($rc -ne 2 -and $rc -ne 3) {
                            Write-Host "    download $($resultText[$rc])" -ForegroundColor Red
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
                Register-OneShot
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
            Write-Host "Waiting 10 seconds before checking for more updates..." -ForegroundColor Cyan
            Start-Sleep -Seconds 10
        }
    }

    & $writeSummary

    # A restart often clears whatever is blocking Windows Update.
    if ($passesFailed -eq $maxPasses) {
        Write-Host "`nWindows Update failed $passesFailed times in a row (see errors above)." -ForegroundColor Red
        Write-Host "Windows Update failing, restarting in ten seconds." -ForegroundColor White -BackgroundColor DarkRed
        Register-OneShot
        shutdown /f /t 10 /r
        return
    }

    Write-Host "Still finding updates after $maxPasses passes. Run Windows Update again." -ForegroundColor Yellow
}
