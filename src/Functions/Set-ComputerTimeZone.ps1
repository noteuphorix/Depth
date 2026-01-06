function Set-ComputerTimeZone {
    # 1. Minimize GUI
    $Main.WindowState = [System.Windows.WindowState]::Minimized

    # Map of Windows Time Zone IDs
    $TZ_Map = @{
        "E" = "Eastern Standard Time"
        "C" = "Central Standard Time"
        "M" = "Mountain Standard Time"
        "P" = "Pacific Standard Time"
        "A" = "Alaskan Standard Time"
        "H" = "Hawaiian Standard Time"
    }

    # Comprehensive US State Map
    $State_Map = @{
        # --- EASTERN ---
        "CT"="E"; "DE"="E"; "DC"="E"; "GA"="E"; "MA"="E"; "MD"="E"; "ME"="E"; "NC"="E"
        "NH"="E"; "NJ"="E"; "NY"="E"; "OH"="E"; "PA"="E"; "RI"="E"; "SC"="E"; "VA"="E"
        "VT"="E"; "WV"="E"
        # --- CENTRAL ---
        "AL"="C"; "AR"="C"; "IA"="C"; "IL"="C"; "LA"="C"; "MN"="C"; "MO"="C"; "MS"="C"
        "OK"="C"; "WI"="C"
        # --- MOUNTAIN ---
        "AZ"="M"; "CO"="M"; "MT"="M"; "NM"="M"; "UT"="M"; "WY"="M"
        # --- PACIFIC ---
        "CA"="P"; "NV"="P"; "WA"="P"
        # --- OFFSHORE ---
        "AK"="A"; "HI"="H"
        # --- SPLIT: EASTERN / CENTRAL ---
        "FL"="EC"; "IN"="EC"; "KY"="EC"; "MI"="EC"; "TN"="EC"
        # --- SPLIT: CENTRAL / MOUNTAIN ---
        "KS"="CM"; "NE"="CM"; "ND"="CM"; "SD"="CM"; "TX"="CM"
        # --- SPLIT: MOUNTAIN / PACIFIC ---
        "ID"="MP"; "OR"="MP"
    }

    Write-Host "`n==============================" -ForegroundColor Cyan
    Write-Host "   TIMEZONE CONFIGURATION" -ForegroundColor Cyan
    Write-Host "==============================" -ForegroundColor Cyan
    
    $InputState = Read-Host "Enter State Code (e.g., PA) or [ENTER] to choose by Region"
    $InputState = $InputState.ToUpper().Trim()

    $Selection = ""

    # 2. Logic: Manual Bypass or Shortcut
    if ([string]::IsNullOrWhiteSpace($InputState) -or $TZ_Map.ContainsKey($InputState)) {
        if ($TZ_Map.ContainsKey($InputState)) { 
            $Selection = $InputState 
        } else {
            Write-Host "Regions: [E]astern, [C]entral, [M]ountain, [P]acific, [A]laska, [H]awaii" -ForegroundColor Yellow
            $Selection = (Read-Host "Select Region Letter").ToUpper()
        }
    }
    # 3. State Lookup Logic
    elseif ($State_Map.ContainsKey($InputState)) {
        $MappedValue = $State_Map[$InputState]
        
        switch ($MappedValue) {
            "EC" { 
                Write-Host "$InputState spans Eastern & Central." -ForegroundColor Yellow
                $Selection = (Read-Host "Choose [E]astern or [C]entral").ToUpper() 
            }
            "CM" { 
                Write-Host "$InputState spans Central & Mountain." -ForegroundColor Yellow
                $Selection = (Read-Host "Choose [C]entral or [M]ountain").ToUpper() 
            }
            "MP" { 
                Write-Host "$InputState spans Mountain & Pacific." -ForegroundColor Yellow
                $Selection = (Read-Host "Choose [M]ountain or [P]acific").ToUpper() 
            }
            Default { $Selection = $MappedValue }
        }
    }
    else {
        Write-Warning "State code '$InputState' not recognized."
        $Selection = (Read-Host "Enter Region: [E], [C], [M], [P], [A], [H]").ToUpper()
    }

    # 4. Apply the Timezone
    if ($TZ_Map.ContainsKey($Selection)) {
        $FinalID = $TZ_Map[$Selection]
        try {
            Set-TimeZone -Id $FinalID
            Write-Host "Successfully set timezone to: $FinalID" -ForegroundColor Green
        }
        catch {
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    else {
        Write-Host "Invalid selection. Timezone was not changed." -ForegroundColor Red
    }

    # 5. Restore GUI
    Write-Host "Returning to GUI..." -ForegroundColor Gray
    Start-Sleep -Seconds 1
    $Main.WindowState = [System.Windows.WindowState]::Normal
}