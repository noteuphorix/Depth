Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Output "Depth needs to be run as Administrator. Attempting to relaunch."

    $script = if ($PSCommandPath) {
        "& { & `'$($PSCommandPath)`' $($argList -join ' ') }"
    } else {
        "&([ScriptBlock]::Create((irm https://depth.narwal.llc))) $($argList -join ' ')"
    }

    $powershellCmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
    $processCmd = if (Get-Command wt.exe -ErrorAction SilentlyContinue) { "wt.exe" } else { "$powershellCmd" }

    if ($processCmd -eq "wt.exe") {
        Start-Process $processCmd -ArgumentList "$powershellCmd -ExecutionPolicy Bypass -NoProfile -Command `"$script`"" -Verb RunAs
    } else {
        Start-Process $processCmd -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"$script`"" -Verb RunAs
    }

    break
}

# --- THE CLEANING FUNCTION ---
# This makes it easy to load any XAML from Visual Studio
function Load-VisualStudioXaml {
    param([string]$RawXaml)
    $Cleaned = $RawXaml -replace 'mc:Ignorable="d"','' `
                        -replace "x:Class.*?[^\x20]*",' ' `
                        -replace "xmlns:local.*?[^\x20]*",' ' `
                        -replace '\s+d:[a-zA-Z]+=".*?"',' ' `
                        -replace 'd:ItemsSource=".*?"',' ' `
                        -replace 'd:SampleData=".*?"',' ' `
                        -replace 'd:DesignHeight=".*?"',' ' `
                        -replace 'd:DesignWidth=".*?"',' '
    [xml]$xml = $Cleaned
    $reader = New-Object System.Xml.XmlNodeReader $xml
    return [Windows.Markup.XamlReader]::Load($reader)
}

# --- SPLASH XAML ---
$splashXML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Splash" Height="200" Width="800" Background="Black" ResizeMode="NoResize" SizeToContent="WidthAndHeight" WindowStartupLocation="CenterScreen" WindowStyle="None">
    <Grid>
        <TextBlock x:Name="Creator_Name" HorizontalAlignment="Center" TextWrapping="Wrap" Text="Created By: Brandon Swarek" VerticalAlignment="Center" Height="72" Width="770" FontSize="48" TextAlignment="Center" Foreground="White"/>
        <Border x:Name="Border" BorderThickness="5" HorizontalAlignment="Center" Height="200" VerticalAlignment="Center" Width="800">
            <Border.BorderBrush>
                <LinearGradientBrush EndPoint="0.5,1" StartPoint="0.5,0">
                    <GradientStop Color="Black"/>
                    <GradientStop Color="#FF22AEB1" Offset="1"/>
                </LinearGradientBrush>
            </Border.BorderBrush>
        </Border>
    </Grid>
</Window>
"@

# --- MAIN XAML ---
$mainXML = @"
<Window x:Name="Main_GUI" x:Class="DepthWPFFramework.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:DepthWPFFramework"
        mc:Ignorable="d"
        Title="Depth" Height="500" Width="800" WindowStartupLocation="CenterScreen" Background="#FF262D2F" SizeToContent="WidthAndHeight" MinHeight="500" MinWidth="850" WindowStyle="None" AllowsTransparency="True" ResizeMode="CanResizeWithGrip">
    <Window.Resources>
        <Style x:Key="CleanButtons" TargetType="Button">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" 
                            Background="{TemplateBinding Background}" 
                            BorderBrush="{TemplateBinding BorderBrush}" 
                            BorderThickness="{TemplateBinding BorderThickness}" 
                            SnapsToDevicePixels="true">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="true">
                                <Setter TargetName="border" Property="Background" Value="#FF1FA5DE"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Grid x:Name="Main_GUI_Grid" MinWidth="800" Background="Transparent">
        <Border x:Name="Main_GUI_Border" BorderThickness="5,5,5,5" BorderBrush="#FF2B3842">
            <Border.Effect>
                <BlurEffect/>
            </Border.Effect>
        </Border>
        <Grid x:Name="Title_Bar_Grid" VerticalAlignment="Top" Height="34" MinHeight="50">
            <Button x:Name="BtnTools_Menu" Content="Tools" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="87" Background="#FF454A4C" Foreground="White" BorderBrush="White" BorderThickness="2" Style="{StaticResource CleanButtons}" Margin="117,10,0,0"/>
            <Button x:Name="BtnDeployment_Menu" Content="Deployment" HorizontalAlignment="Left" Height="26" Margin="25,10,0,0" VerticalAlignment="Top" Width="87" Background="#FF454A4C" Foreground="White" BorderThickness="2" Style="{StaticResource CleanButtons}" BorderBrush="White"/>
            <Button x:Name="BtnClose" Content="X" HorizontalAlignment="Right" Height="28" Margin="0,10,5,0" VerticalAlignment="Top" Width="27" FontFamily="Segoe UI Variable Display Semibold" Background="{x:Null}" FontSize="18" Foreground="White" BorderBrush="{x:Null}"/>
            <Button x:Name="BtnMin" Content="-" HorizontalAlignment="Right" Height="28" Margin="0,10,32,0" VerticalAlignment="Top" Width="27" FontFamily="Segoe UI Variable Display Semibold" Background="{x:Null}" FontSize="24" Foreground="White" BorderBrush="{x:Null}"/>
            <Ellipse x:Name="StatusLight" HorizontalAlignment="Right" Height="22" Stroke="Black" VerticalAlignment="Top" Width="22" Fill="#FF0FFF1E" Margin="0,16,75,0">
                <Ellipse.Effect>
                    <BlurEffect/>
                </Ellipse.Effect>
            </Ellipse>
        </Grid>
        <Grid x:Name="Deployment_Grid" Margin="0,50,0,0">
            <Border x:Name="Border_Clients" BorderBrush="#FF2B3842" BorderThickness="2,2,2,2" Margin="168,0,0,10" HorizontalAlignment="Left" Width="142"/>
            <Border x:Name="Border_Actions" BorderBrush="#FF2B3842" BorderThickness="2,2,2,2" Margin="10,0,0,10" HorizontalAlignment="Left" Width="142"/>
            <Border x:Name="Border_OOBE" BorderBrush="#FF2B3842" BorderThickness="2,2,2,2" Margin="326,0,0,10" HorizontalAlignment="Left" Width="142"/>
            <Border x:Name="Border_Apps" BorderBrush="#FF2B3842" BorderThickness="2,2,2,2" Margin="483,0,0,10" HorizontalAlignment="Left" Width="142"/>
            <Border x:Name="Border_NAS" BorderBrush="#FF2B3842" BorderThickness="2,2,2,2" Margin="640,1,0,0" Height="167" Width="140" VerticalAlignment="Top" HorizontalAlignment="Left"/>
            <Label x:Name="LblClients_Copy" Content="OOBE" HorizontalAlignment="Left" Height="26" Margin="334,15,0,0" VerticalAlignment="Top" Width="126" FontWeight="Bold" Foreground="#FF3D6EE6" FontSize="14" FontFamily="Leelawadee"/>
            <Label x:Name="LblDeploymentActions" Content="Actions" HorizontalAlignment="Left" Height="26" Margin="20,15,0,0" VerticalAlignment="Top" Width="126" FontWeight="Bold" Foreground="#FF3D6EE6" FontSize="14" FontFamily="Leelawadee"/>
            <Label x:Name="LblClients" Content="Client Select" HorizontalAlignment="Left" Height="26" Margin="176,15,0,0" VerticalAlignment="Top" Width="126" FontWeight="Bold" Foreground="#FF3D6EE6" FontSize="14" FontFamily="Leelawadee"/>
            <Label x:Name="LblApps" Content="Apps" HorizontalAlignment="Left" Height="26" Margin="493,15,0,0" VerticalAlignment="Top" Width="126" FontWeight="Bold" Foreground="#FF3D6EE6" FontSize="14" FontFamily="Leelawadee"/>
            <Label x:Name="LblNASLogin" Content="NAS Login" HorizontalAlignment="Left" Height="26" Margin="648,15,0,0" VerticalAlignment="Top" Width="126" FontWeight="Bold" Foreground="#FF3D6EE6" FontSize="14" FontFamily="Leelawadee"/>
            <Label x:Name="LblUsername" Content="Username" HorizontalAlignment="Left" Height="24" Margin="648,42,0,0" VerticalAlignment="Top" Width="82" FontWeight="Bold" Foreground="White" FontSize="10" FontFamily="Leelawadee"/>
            <Label x:Name="LblPassword" Content="Password" HorizontalAlignment="Left" Height="24" Margin="648,83,0,0" VerticalAlignment="Top" Width="82" FontWeight="Bold" Foreground="White" FontSize="10" FontFamily="Leelawadee"/>
            <ListBox x:Name="ClientListBox" HorizontalAlignment="Left" Margin="178,119,0,0" d:ItemsSource="{d:SampleData ItemCount=5}" Background="Black" Foreground="White" Width="122" ScrollViewer.VerticalScrollBarVisibility="Auto" FontFamily="Leelawadee" VerticalAlignment="Top" Height="314"/>
            <Button x:Name="BtnRunAll" Content="Run All" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="20,41,0,0" FontFamily="Leelawadee"/>
            <Button x:Name="BtnRepairWinget" Content="Repair Winget" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="20,72,0,0" FontFamily="Leelawadee"/>
            <Button x:Name="BtnInstallOffice" Content="Install O365" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="20,103,0,0" FontFamily="Leelawadee"/>
            <Button x:Name="BtnInstallLocalApps" Content="Install Local Apps" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="20,134,0,0" FontFamily="Leelawadee"/>
            <Button x:Name="BtnInstallDefaultWingetApps" Content="Install Default Winget" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="20,165,0,0" FontFamily="Leelawadee"/>
            <Button x:Name="BtnInstallCustomWingetApps" Content="Install Custom Winget" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="20,196,0,0" FontFamily="Leelawadee"/>
            <Button x:Name="BtnUninstallBloat" Content="Uninstall Bloat" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="20,227,0,0" FontFamily="Leelawadee"/>
            <Button x:Name="BtnUninstallLanguagePacks" Content="Uninstall Lng Packs" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="20,258,0,0" FontFamily="Leelawadee"/>
            <Button x:Name="BtnSetPowerOptions" Content="Set Power Options" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="20,289,0,0" FontFamily="Leelawadee"/>
            <Button x:Name="BtnSetTimeZone" Content="Set Timezone" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="20,320,0,0" FontFamily="Leelawadee"/>
            <Button x:Name="BtnClientChooser" Content="Re-Load Clients" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="178,41,0,0" FontFamily="Leelawadee"/>
            <Button x:Name="BtnManualClientSelect" Content="Manual Selection" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="178,81,0,0" FontFamily="Leelawadee"/>
            <Button x:Name="BtnNVIDIAApp" Content="NVIDIA App" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="493,41,0,0" FontFamily="Leelawadee"/>
            <Button x:Name="BtnAMDApp" Content="AMD App" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="493,81,0,0" FontFamily="Leelawadee"/>
            <Button x:Name="BtnNASLogin" Content="Login" HorizontalAlignment="Left" Height="24" Margin="648,131,0,0" VerticalAlignment="Top" Width="60" FontFamily="Leelawadee"/>
            <TextBox x:Name="TxtBoxUsernameNAS" HorizontalAlignment="Left" Margin="648,62,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="120"/>
            <PasswordBox x:Name="PswrdBoxNAS" HorizontalAlignment="Left" Margin="648,103,0,0" VerticalAlignment="Top" Width="120"/>
            <CheckBox Content="NAS Connected?" HorizontalAlignment="Left" Margin="640,217,0,0" VerticalAlignment="Top" Width="140" IsEnabled="False" Foreground="White" IsChecked="False" FontFamily="Leelawadee"/>
            <Ellipse x:Name="NASLoginStatusLight" HorizontalAlignment="Left" Height="16" Stroke="Black" VerticalAlignment="Top" Width="15" Fill="Red" Margin="739,20,0,0" RenderTransformOrigin="2.212,-0.044">
                <Ellipse.Effect>
                    <BlurEffect/>
                </Ellipse.Effect>
            </Ellipse>
            <Button x:Name="BtnTest" Content="Testing" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="20,407,0,0" FontFamily="Leelawadee"/>
        </Grid>
        <Grid x:Name="Tools_Grid" Margin="0,50,0,0" d:IsHidden="True">
            <Image x:Name="Ken" Margin="102,49,102,111" Source="https://github.com/noteuphorix/Depth/blob/master/src/imgs/Ken.png?raw=true" Width="300" Height="293" HorizontalAlignment="Center" VerticalAlignment="Center"/>
        </Grid>
        <Label x:Name="LblCopyright" Content="Created By: Brandon Swarek" Height="36" VerticalAlignment="Bottom" Width="210" FontFamily="Leelawadee" FontSize="16" Foreground="White" HorizontalAlignment="Right" Margin="0,0,10,4"/>
    </Grid>
</Window>
"@

# --- GLOBAL VARIABLES ---


# 1. Show Splashscreen
$Splash = Load-VisualStudioXaml -RawXaml $splashXML
$Splash.Show()
Start-Sleep -Seconds 1
$Splash.Close()

# 2. Load main GUI object
$Main = Load-VisualStudioXaml -RawXaml $mainXML

# --- FUNCTIONS SECTION ---


# --- Function from Connect-NAS.ps1 ---
function Connect-NAS {
    $NASLoginStatusLight.Fill = [System.Windows.Media.Brushes]::Yellow
    [System.Windows.Forms.Application]::DoEvents()

    $User = $TxtBoxUsernameNAS.Text
    $Pass = $PswrdBoxNAS.Password
    $NASPath = "\\10.24.2.5\Clients"

    try {
        # Credential logic here...
        # If it fails, New-SmbMapping will throw an error to the 'catch' block
        New-SmbMapping -RemotePath $NASPath -Password $Pass -UserName $User -ErrorAction Stop | Out-Null
        
        $global:NAS_Clients_Folder = $NASPath
        $ClientListBox.Items.Clear()
        $Folders = Get-ChildItem -Path $global:NAS_Clients_Folder -Directory -ErrorAction SilentlyContinue
        foreach ($Folder in $Folders) {
            $ClientListBox.Items.Add($Folder.Name)
        }
        $NASLoginStatusLight.Fill = [System.Windows.Media.Brushes]::LimeGreen
    }
    catch {
        # This handles the failure WITHOUT opening a new window
        $NASLoginStatusLight.Fill = [System.Windows.Media.Brushes]::Red
        Write-Warning "Connection failed: $($_.Exception.Message)"
    }
}

# --- Function from Get-UserInput.ps1 ---
function Get-UserInput {
    # 1. Minimize the GUI so you can see the terminal behind it
    $Main.WindowState = "Minimized"

    # 2. Capture the input (The GUI will stay minimized while this waits)
    Write-Host "`n[INPUT REQUIRED] Please type your input below:" -ForegroundColor Yellow
    $InputtedText = Read-Host "Enter your value"
    
    # 3. Store the value
    $global:UserTermInput = $InputtedText
    
    # 4. Restore the GUI now that the thread is free to draw again
    $Main.WindowState = "Normal"
    
    Write-Host "Input Saved: $global:UserTermInput" -ForegroundColor Green
}

# --- Function from GUI-Startup.ps1 ---
function GUI-Startup {
    $IP = "10.24.2.5"
    $NASPath = "\\$IP\Clients"
    
    # 1. LOCAL CHECK: Look for an existing authenticated session to that IP
    # This does NOT touch the network; it only looks at your local PC's session table.
    $ActiveSession = Get-SmbSession | Where-Object { $_.Dialect -and $_.RemoteTarget -like "*$IP*" }

    if ($null -ne $ActiveSession) {
        # 2. Session exists, so we can safely hit the network to get folders
        $global:NAS_Clients_Folder = $NASPath
        $NASLoginStatusLight.Fill = [System.Windows.Media.Brushes]::LimeGreen
        
        $ClientListBox.Items.Clear()
        # Note: If the session exists but the NAS just got unplugged, 
        # this part might still hang, but the GUI startup itself will be instant.
        $Folders = Get-ChildItem -Path $NASPath -Directory -ErrorAction SilentlyContinue
        foreach ($Folder in $Folders) { 
            [void]$ClientListBox.Items.Add($Folder.Name) 
        }
    }
    else {
        # 3. No local record of a login to that IP
        $NASLoginStatusLight.Fill = [System.Windows.Media.Brushes]::Red
        Write-Host "No active credentials/session found for $IP" -ForegroundColor Gray
    }
}

# --- Function from Install-ClientCustomLocalApps.ps1 ---
function Install-ClientCustomLocalApps {
    if ([string]::IsNullOrWhiteSpace($global:SelectedClient)) {
        Write-Warning "Choose a client first!"
        return
    }

    # 1. Determine the Base Path
    # If it contains a ':' (C:\) or starts with '\' (\\Server), use it directly.
    # Otherwise, assume it's a name and build the 10.24.2.5 network path.
    if ($global:SelectedClient -match ":" -or $global:SelectedClient -like "\\*") {
        $BasePath = $global:SelectedClient
    } 
    else {
        $BasePath = "\\10.24.2.5\Clients\$global:SelectedClient"
    }

    # 2. Append the "Apps" folder to the determined path
    $FinalPath = Join-Path -Path $BasePath -ChildPath "Apps"

    if (-not (Test-Path $FinalPath)) {
        Write-Error "Could not find the Apps folder at: $FinalPath"
        return
    }

    Write-Host "Starting custom app deployment from: $FinalPath" -ForegroundColor Cyan

    $AppFiles = Get-ChildItem -Path $FinalPath -File
    
    foreach ($App in $AppFiles) {
        Write-Host "Installing: $($App.Name)..." -ForegroundColor Yellow

        try {
            if ($App.Extension -eq ".msi") {
                # Wrap FullName in quotes to handle spaces correctly
                $Args = "/i `"$($App.FullName)`" /qn /norestart"
                Start-Process -FilePath "msiexec.exe" -ArgumentList $Args -Wait -NoNewWindow -ErrorAction Stop
            } 
            else {
                Start-Process -FilePath $App.FullName -Wait -NoNewWindow -ErrorAction Stop
            }
            
            Write-Host "Successfully finished $($App.Name)" -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to install $($App.Name): $($_.Exception.Message)"
        }
    }

    Write-Host "All local custom apps have been processed." -ForegroundColor Green
}

# --- Function from Install-ClientCustomWingetApps.ps1 ---
function Install-ClientCustomWingetApps {
    if ([string]::IsNullOrWhiteSpace($global:SelectedClient)) {
        Write-Warning "Choose a client first!"
        return
    }

    # 1. Determine the Base Path
    # Checks for ":" (C:\) or starts with "\" (\\Server)
    if ($global:SelectedClient -match ":" -or $global:SelectedClient -like "\\*") {
        $BasePath = $global:SelectedClient
    } 
    else {
        $BasePath = "\\10.24.2.5\Clients\$global:SelectedClient"
    }

    # 2. Map directly to the .txt file in the root of that path
    $TxtPath = Join-Path -Path $BasePath -ChildPath "CustomApps.txt"

    if (-not (Test-Path $TxtPath)) {
        # Silent return to match your requested behavior
        return
    }

    $Apps = Get-Content -Path $TxtPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    if ($null -eq $Apps) {
        return
    }

    foreach ($App in $Apps) {
        # Executes winget for each ID found in the text file
        Start-Process winget -ArgumentList "install --id $App --silent --accept-source-agreements" -Wait -PassThru -NoNewWindow
    }

    return "Completed"
}

# --- Function from Install-DefaultWingetApps.ps1 ---
function Install-DefaultWingetApps {
    # Pre-defined list of IDs
    $Apps = @("Google.Chrome", "Adobe.Acrobat.Reader.64-bit", "Intel.IntelDriverAndSupportAssistant", "Microsoft.Teams", "9WZDNCRD29V9")

    foreach ($App in $Apps) {
        # Process runs and displays output in its own console window area
        Start-Process winget -ArgumentList "install --id $App --silent --accept-source-agreements" -Wait -PassThru -NoNewWindow
    }

    return "Completed"
}


# --- Function from Install-O365.ps1 ---
function Install-O365 {
    # Pre-defined list of IDs
    $Apps = @("Microsoft.Office")

    foreach ($App in $Apps) {
        # Process runs and displays output in its own console window area
        Start-Process winget -ArgumentList "install --id $App --silent --accept-source-agreements" -Wait -PassThru -NoNewWindow
    }
}

# --- Function from Repair-Winget.ps1 ---
function Repair-Winget {
    # 0. Try to let Winget fix its own dependency first
    Write-Host "Attempting to install WindowsAppRuntime 1.8 via Winget..." -ForegroundColor Yellow
    winget install Microsoft.WindowsAppRuntime.1.8 --source winget --accept-package-agreements --accept-source-agreements --nowarn

    Write-Host "Checking for AppInstaller updates..." -ForegroundColor Cyan
    
    $Url = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
    $Path = "$env:TEMP\WingetUpdate.msixbundle"

    try {
        # 1. Kill processes using the package to avoid HRESULT: 0x80073D02
        Write-Host "Closing active AppInstaller processes..." -ForegroundColor Yellow
        $AppInstallerPackage = Get-AppxPackage -Name "Microsoft.DesktopAppInstaller"
        if ($AppInstallerPackage) {
            # Find and stop processes associated with this package
            Get-Process | Where-Object { $_.Path -like "*$($AppInstallerPackage.Name)*" } | Stop-Process -Force -ErrorAction SilentlyContinue
            # Also kill winget.exe specifically just in case
            Stop-Process -Name "winget" -Force -ErrorAction SilentlyContinue
        }

        # 2. Download the latest bundle
        Write-Host "Downloading latest AppInstaller bundle..." -ForegroundColor Yellow
        $oldPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $Path -UseBasicParsing
        

        # 3. Force install the package
        Write-Host "Installing latest Winget..." -ForegroundColor Yellow
        # We use -ForceApplicationShutdown as an extra safety measure
        Add-AppxPackage -Path $Path -ForceApplicationShutdown -ErrorAction Stop
        $ProgressPreference = $oldPreference
        
        Write-Host "Winget is now updated and ready." -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to update Winget: $($_.Exception.Message)"
    }
    finally {
        if (Test-Path $Path) { Remove-Item $Path -Force }
    }
}

# --- Function from Select-ManualFolder.ps1 ---
function Select-ManualFolder {
    $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderBrowser.Description = "Select the Client Folder"
    $FolderBrowser.ShowNewFolderButton = $true

    $Result = $FolderBrowser.ShowDialog()

    if ($Result -eq [System.Windows.Forms.DialogResult]::OK) {
        # Set the global variable to the FULL PATH immediately
        $global:SelectedClient = $FolderBrowser.SelectedPath
        
        $SelectedFolderName = Split-Path $global:SelectedClient -Leaf

        $ClientListBox.Items.Clear()
        $ClientListBox.Items.Add($SelectedFolderName)
        $ClientListBox.SelectedIndex = 0

        Write-Host "Manual Path Selected: $global:SelectedClient" -ForegroundColor Green
    }
}

# --- Function from Set-SelectedClient.ps1 ---
function Set-SelectedClient {
    if ($ClientListBox.SelectedItem -ne $null) {
        $SelectedItemText = $ClientListBox.SelectedItem.ToString()

        # If the current global path already ends with the selected name, 
        # it means we did a manual select. DON'T overwrite the full path.
        if ($global:SelectedClient -like "*\$SelectedItemText") {
            Write-Host "Manual path preserved: $global:SelectedClient" -ForegroundColor Green
        }
        else {
            # Otherwise, it's a standard NAS selection
            $global:SelectedClient = $SelectedItemText
            Write-Host "NAS Client Selected: $global:SelectedClient" -ForegroundColor Green
        }
    }
}

# --- Function from Switch-Tabs.ps1 ---
# --- Function from SwitchTabs.ps1 ---
function Switch-Tabs {
    param([string]$Target)

    # 1. Exit if already on the target to prevent flickering
    if ($Target -eq "Deployment" -and $Deployment_Grid.Visibility -eq "Visible") { return }
    if ($Target -eq "Tools" -and $Tools_Grid.Visibility -eq "Visible") { return }

    # This ensures only one grid is active at a time
    $Deployment_Grid.Visibility = "Collapsed"
    $Tools_Grid.Visibility      = "Collapsed"

    # 3. Show only the target grid
    switch ($Target) {
        "Deployment" { $Deployment_Grid.Visibility = "Visible" }
        "Tools"      { $Tools_Grid.Visibility      = "Visible" }
    }
}

# --- Function from TestFunction.ps1 ---
function TestFunction {
	Write-Host "Hello, World!"
	Start-Sleep -Seconds 10
	Write-Host "Sleepy!"
}

# --- Function from Uninstall-Bloat.ps1 ---
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

# --- Function from Update-Status.ps1 ---
function Update-Status {
    param(
        [ValidateSet("Busy", "Ready")]
        [string]$State
    )

    # Change the color of the StatusLight Ellipse
    if ($State -eq "Busy") {
        # Use Red for Busy
        $StatusLight.Fill = [System.Windows.Media.Brushes]::Red
    } else {
        # Use LimeGreen for Ready
        $StatusLight.Fill = [System.Windows.Media.Brushes]::LimeGreen
    }

    # Keeps the UI responsive during the color change
    [System.Windows.Forms.Application]::DoEvents()
}


# --- UI ELEMENT MAPPING ---

# Grids
$Main_GUI_Grid = $Main.FindName("Main_GUI_Grid")
$Tools_Grid      = $Main.FindName("Tools_Grid")
$Deployment_Grid = $Main.FindName("Deployment_Grid")

# Navigation Buttons
$BtnTools_Menu      = $Main.FindName("BtnTools_Menu")
$BtnDeployment_Menu = $Main.FindName("BtnDeployment_Menu")
$BtnClose           = $Main.FindName("BtnClose")
$BtnMin             = $Main.FindName("BtnMin")

# Status Indicators
$StatusLight         = $Main.FindName("StatusLight")
$NASLoginStatusLight = $Main.FindName("NASLoginStatusLight")

# Actions Column
$BtnRunAll                      = $Main.FindName("BtnRunAll")
$BtnRepairWinget                = $Main.FindName("BtnRepairWinget")
$BtnInstallOffice               = $Main.FindName("BtnInstallOffice")
$BtnInstallLocalApps            = $Main.FindName("BtnInstallLocalApps")
$BtnInstallDefaultWingetApps    = $Main.FindName("BtnInstallDefaultWingetApps")
$BtnInstallCustomWingetApps     = $Main.FindName("BtnInstallCustomWingetApps")
$BtnUninstallBloat              = $Main.FindName("BtnUninstallBloat")
$BtnUninstallLanguagePacks      = $Main.FindName("BtnUninstallLanguagePacks")
$BtnSetPowerOptions             = $Main.FindName("BtnSetPowerOptions")
$BtnSetTimeZone                 = $Main.FindName("BtnSetTimeZone")
$BtnTest                        = $Main.FindName("BtnTest") 

# Client Selection Column
$ClientListBox          = $Main.FindName("ClientListBox")
$BtnClientChooser       = $Main.FindName("BtnClientChooser")
$BtnManualClientSelect  = $Main.FindName("BtnManualClientSelect")

# Apps Column
$BtnNVIDIAApp = $Main.FindName("BtnNVIDIAApp")
$BtnAMDApp    = $Main.FindName("BtnAMDApp")

# NAS Login Section
$BtnNASLogin        = $Main.FindName("BtnNASLogin")
$TxtBoxUsernameNAS  = $Main.FindName("TxtBoxUsernameNAS")
$PswrdBoxNAS        = $Main.FindName("PswrdBoxNAS")


# --- ACTION BUTTON CLICK EVENTS ---
$BtnRepairWinget.Add_Click({
    Update-Status -State "Busy"
    Repair-Winget
    Update-Status -State "Ready"
})

$BtnInstallDefaultWingetApps.Add_Click({
    Update-Status -State "Busy"
    Install-DefaultWingetApps
    Update-Status -State "Ready"
})

$BtnNASLogin.Add_Click({
    Update-Status -State "Busy"
    Connect-NAS
    Update-Status -State "Ready"
})

$BtnInstallOffice.Add_Click({
    Update-Status -State "Busy"
    Install-O365
    Update-Status -State "Ready"
})

$BtnInstallLocalApps.Add_Click({
    Update-Status -State "Busy"
    Install-ClientCustomLocalApps
    Update-Status -State "Ready"
})

$BtnInstallCustomWingetApps.Add_Click({
    Update-Status -State "Busy"
    Install-ClientCustomWingetApps
    Update-Status -State "Ready"
})

$BtnUninstallBloat.Add_Click({
    Update-Status -State "Busy"
    Uninstall-Bloat
    Update-Status -State "Ready"
})

$BtnManualClientSelect.Add_Click({
    Update-Status -State "Busy"
    Select-ManualFolder
    Update-Status -State "Ready"
})

$ClientListBox.Add_MouseDoubleClick({
    Set-SelectedClient
})

# --- TAB SWITCHING BUTTON CLICK EVENTS ---
$BtnTools_Menu.Add_Click({
    Switch-Tabs -Target "Tools"
})

$BtnDeployment_Menu.Add_Click({
    Switch-Tabs -Target "Deployment"
})

# --- TITLE BAR BUTTON CLICK EVENTS ---
$BtnClose.Add_Click({
    $Main.Close()
})

$BtnMin.Add_Click({
    $Main.WindowState = [System.Windows.WindowState]::Minimized
})

# --- GRID EVENTS ---
$Main_GUI_Grid.Add_MouseLeftButtonDown({
    $Main.DragMove()
})

# 3. OPEN THE WINDOW (Last Step)
$Main_GUI_Grid.Add_Loaded({
    GUI-Startup
})

$Tools_Grid.Visibility = "Collapsed"
$Main.ShowDialog() | Out-Null
Write-Host "Goodbye!" -ForegroundColor Cyan
