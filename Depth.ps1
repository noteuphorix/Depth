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
   <Button x:Name="BtnRestart_Menu" Content="Restart PC" HorizontalAlignment="Right" Height="26" VerticalAlignment="Top" Width="86" Background="#FF454A4C" Foreground="White" BorderBrush="White" BorderThickness="2" Style="{StaticResource CleanButtons}" Margin="0,10,114,0"/>
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
			<Button x:Name="BtnAMDApp" Content="AMD App" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="493,72,0,0" FontFamily="Leelawadee"/>
			<Button x:Name="BtnNASLogin" Content="Login" HorizontalAlignment="Left" Height="24" Margin="648,131,0,0" VerticalAlignment="Top" Width="60" FontFamily="Leelawadee"/>
			<Button x:Name="BtnCopyShortcuts" Content="Copy Shortcuts" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="20,351,0,0" FontFamily="Leelawadee"/>
			<Button x:Name="BtnInstallDellApp" Content="Dell App" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="493,103,0,0" FontFamily="Leelawadee"/>
			<Button x:Name="BtnInstalLenovoApp" Content="Lenovo App" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="493,134,0,0" FontFamily="Leelawadee"/>
			<Button x:Name="BtnInstallHPApp" Content="HP App" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="493,165,0,0" FontFamily="Leelawadee"/>
			<TextBox x:Name="TxtBoxUsernameNAS" HorizontalAlignment="Left" Margin="648,62,0,0" TextWrapping="Wrap" VerticalAlignment="Top" Width="120"/>
			<PasswordBox x:Name="PswrdBoxNAS" HorizontalAlignment="Left" Margin="648,103,0,0" VerticalAlignment="Top" Width="120"/>
			<Ellipse x:Name="NASLoginStatusLight" HorizontalAlignment="Left" Height="16" Stroke="Black" VerticalAlignment="Top" Width="15" Fill="Red" Margin="739,20,0,0" RenderTransformOrigin="2.212,-0.044">
				<Ellipse.Effect>
					<BlurEffect/>
				</Ellipse.Effect>
			</Ellipse>
		</Grid>
		<Grid x:Name="Tools_Grid" Margin="0,50,0,0" d:IsHidden="True">
			<Image x:Name="Ken" Margin="102,49,102,111" Source="https://github.com/noteuphorix/Depth/blob/master/src/imgs/Ken2.png?raw=true" Width="300" Height="293" HorizontalAlignment="Center" VerticalAlignment="Center" d:IsHidden="True"/>
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
        New-SmbMapping -RemotePath $NASPath -Password $Pass -UserName $User -Persistent $true -ErrorAction Stop | Out-Null
        net use $NASPath $Pass /user:$User /persistent:yes /y > $null
        
        $global:NAS_Clients_Folder = $NASPath
        $ClientListBox.Items.Clear()
        $Folders = Get-ChildItem -Path $global:NAS_Clients_Folder -Directory -ErrorAction SilentlyContinue | Sort-Object Name
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

# --- Function from Copy-Shortcuts.ps1 ---
function Copy-Shortcuts {
    if ([string]::IsNullOrWhiteSpace($global:SelectedClient)) {
        Write-Warning "Choose a client first!"
        return
    }

    # 1. Determine the Base Path (Supports NAS and Manual Selection)
    if ($global:SelectedClient -match ":" -or $global:SelectedClient -like "\\*") {
        $BasePath = $global:SelectedClient
    } 
    else {
        $BasePath = "\\10.24.2.5\Clients\$global:SelectedClient"
    }

    # 2. Target the 'Shortcuts' folder specifically
    $FinalPath = Join-Path -Path $BasePath -ChildPath "Shortcuts"
    $DesktopPath = [System.IO.Path]::Combine($env:USERPROFILE, "Desktop")

    if (-not (Test-Path $FinalPath)) {
        Write-Host "Shortcut source folder not found at: $FinalPath" -ForegroundColor Red
        return
    }

    Write-Host "Copying all items from Shortcuts to Desktop..." -ForegroundColor Cyan

    try {
        # 3. Recursive Copy of all contents
        # Wildcard \* ensures we grab what's INSIDE, not the 'Shortcuts' folder itself
        Copy-Item -Path "$FinalPath\*" -Destination $DesktopPath -Recurse -Force -ErrorAction Stop
        
        Write-Host "Copy complete. Everything from '$($global:SelectedClient)\Shortcuts' is now on your Desktop." -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to copy: $($_.Exception.Message)"
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
    $NASIP = "10.24.2.5"
    $NASPath = "\\$NASIP\Clients"
    
    Write-Host "Checking NAS connectivity..." -ForegroundColor Cyan

    # Step 1: Ping the IP. -Count 1 -Quiet returns True/False instantly.
    if (Test-Connection -ComputerName $NASIP -Count 1 -Quiet) {
        
        # Step 2: Ping succeeded, now check the specific folder path
        if (Test-Path -Path "FileSystem::$NASPath" -PathType Container -ErrorAction SilentlyContinue) {
            $global:NAS_Clients_Folder = $NASPath
            $NASLoginStatusLight.Fill = [System.Windows.Media.Brushes]::LimeGreen
            
            $ClientListBox.Items.Clear()
            $Folders = Get-ChildItem -Path $NASPath -Directory -ErrorAction SilentlyContinue
            foreach ($Folder in $Folders) { 
                [void]$ClientListBox.Items.Add($Folder.Name) 
            }
            Write-Host "NAS Connected and Clients Loaded." -ForegroundColor Green
        }
        else {
            # IP is up, but the share or folder is missing/perm denied
            $NASLoginStatusLight.Fill = [System.Windows.Media.Brushes]::Red
            Write-Host "NAS IP reachable, but Path not found!" -ForegroundColor Yellow
        }
    }
    else {
        # Step 3: Ping failed - This is the "Fail Fast" exit
        $NASLoginStatusLight.Fill = [System.Windows.Media.Brushes]::Red
        Write-Host "NAS Not Connected! (Ping Failed)" -ForegroundColor Red
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
        Write-Host "Apps folder not found at $BasePath" -ForegroundColor Red
        return
    }

    Write-Host "Starting custom app deployment from: $FinalPath" -ForegroundColor Cyan

    $AppFiles = Get-ChildItem -Path $FinalPath -File
    
    foreach ($App in $AppFiles) {
        Write-Host "Installing: $($App.Name)..." -ForegroundColor Yellow

        try {
            if ($App.Extension -eq ".msi") {
                # Wrap FullName in quotes to handle spaces correctly
                $Args = "/i `"$($App.FullName)`" /norestart"
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
        Write-Warning "CustomApps.txt not found at $BasePath"
        return
    }

    $Apps = Get-Content -Path $TxtPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    if ($null -eq $Apps) {
        return
    }

    foreach ($App in $Apps) {
        # Executes winget for each ID found in the text file
        Start-Process winget -ArgumentList "install --id $App --silent --accept-source-agreements --scope machine" -Wait -PassThru -NoNewWindow
    }

    return "Completed"
}

# --- Function from Install-DefaultWingetApps.ps1 ---
function Install-DefaultWingetApps {
    # Pre-defined list of IDs
    $Apps = @("Google.Chrome", "Adobe.Acrobat.Reader.64-bit", "Intel.IntelDriverAndSupportAssistant", "Microsoft.Teams")

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

# --- Function from Install-PassedWingetApp.ps1 ---
function Install-PassedWingetApp {
    param([string]$AppID)
    Start-Process winget -ArgumentList "install --id $AppID --silent --accept-source-agreements" -Wait -PassThru -NoNewWindow
}

# --- Function from Refresh-Clients.ps1 ---
function Refresh-Clients {
    # 1. Check if the path is set
    if (-not $global:NAS_Clients_Folder) {
        Write-Warning "Refresh failed: NAS path is not defined. Please connect first."
        return
    }

    try {
        # 2. Clear existing items
        $ClientListBox.Items.Clear()
        
        # 3. Re-populate from the global NAS path
        $Folders = Get-ChildItem -Path $global:NAS_Clients_Folder -Directory -ErrorAction Stop | Sort-Object Name
        
        foreach ($Folder in $Folders) {
            $ClientListBox.Items.Add($Folder.Name)
        }
    }
    catch {
        Write-Warning "Refresh failed: $($_.Exception.Message)"
    }
}

# --- Function from Repair-Winget.ps1 ---
function Repair-Winget {
    # 0. Try to let Winget fix its own dependency first
    Write-Host "Attempting to install WindowsAppRuntime 1.8 via Winget..." -ForegroundColor Yellow
    Start-Process winget -ArgumentList "install Microsoft.WindowsAppRuntime.1.8 --source winget --silent --accept-package-agreements --accept-source-agreements" -Wait -PassThru -NoNewWindow

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

# --- Function from Set-ComputerTimeZone.ps1 ---
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

# --- Function from Set-CustomPowerOptions.ps1 ---
function Set-CustomPowerOptions {
    Write-Host "Configuring Power Options..." -ForegroundColor Cyan

    $PowerCommands = @(
        # GUIDs: Sleep timeout (AC/DC), Display timeout (AC/DC), and Power Button Action
        @('powercfg /SETDCVALUEINDEX SCHEME_CURRENT 238c9fa8-0aad-41ed-83f4-97be242c8f20 29f6c1db-86da-48c5-9fdb-f2b67b1f44da 1200', "DC Sleep Timeout"),
        @('powercfg /SETACVALUEINDEX SCHEME_CURRENT 238c9fa8-0aad-41ed-83f4-97be242c8f20 29f6c1db-86da-48c5-9fdb-f2b67b1f44da 0', "AC Sleep Timeout"),
        @('powercfg /SETDCVALUEINDEX SCHEME_CURRENT 7516b95f-f776-4464-8c53-06167f40cc99 3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e 1200', "DC Display Timeout"),
        @('powercfg /SETACVALUEINDEX SCHEME_CURRENT 7516b95f-f776-4464-8c53-06167f40cc99 3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e 0', "AC Display Timeout"),
        @('powercfg /SETACVALUEINDEX SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 7648efa3-dd9c-4e3e-b566-50f929386280 3', "AC Power Button Action"),
        @('powercfg /SETDCVALUEINDEX SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 7648efa3-dd9c-4e3e-b566-50f929386280 3', "DC Power Button Action")
    )

    foreach ($Entry in $PowerCommands) {
        $Command = $Entry[0]
        $Label = $Entry[1]

        try {
            # Invoke-Expression is used here to run the raw string command
            Invoke-Expression $Command
            Write-Host "  [OK] $Label set." -ForegroundColor Gray
        }
        catch {
            Write-Warning "  [FAIL] Could not set $Label."
        }
    }

    # Apply changes globally
    powercfg /setactive SCHEME_CURRENT
    Write-Host "`nAll power options have been applied successfully." -ForegroundColor Green
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

# --- Function from Uninstall-OfficeLanguagePacks.ps1 ---
function Uninstall-OfficeLanguagePacks {
    Write-Host "Scanning for extra Office Language Packs..." -ForegroundColor Cyan

    # 1. Get all Office ClickToRun entries, excluding English
    $OfficePacks = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | Where-Object {
        $_.UninstallString -like "*OfficeClickToRun.exe*" -and 
        $_.DisplayName -notlike "*en-us*" -and 
        $_.DisplayName -notlike "*English*" -and 
        $_.DisplayName -ne $null
    }

    if (-not $OfficePacks) {
        Write-Host "No extra Office language packs found." -ForegroundColor Green
        return
    }

    # 2. Extract Language IDs (xx-xx)
    $LangsToRemove = $(foreach ($Pack in $OfficePacks) {
        if ($Pack.DisplayName -match '([a-z]{2}-[a-z]{2})') { $Matches[1] }
    }) | Select-Object -Unique

    Write-Host "Uninstalling: $($LangsToRemove -join ', ')" -ForegroundColor Yellow

    # 3. Ensure ODT exists
    $ODTPath = "$env:TEMP\setup.exe"
    if (-not (Test-Path $ODTPath)) {
        Invoke-WebRequest -Uri "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_17126-20132.exe" -OutFile "$env:TEMP\odt.exe"
        Start-Process -FilePath "$env:TEMP\odt.exe" -ArgumentList "/extract:$env:TEMP /quiet" -Wait
    }

    # 4. Build and Run XML with all 3 Product IDs
    $XmlPath = "$env:TEMP\RemoveLangs.xml"
    $LangNodes = ($LangsToRemove | ForEach-Object { "      <Language ID=""$_"" />" }) -join "`n"

    # We repeat the LangNodes for each potential Product ID
    @"
<Configuration>
  <Remove>
    <Product ID="O365ProPlusRetail">
$LangNodes
    </Product>
    <Product ID="O365HomePremRetail">
$LangNodes
    </Product>
    <Product ID="OneNoteFreeRetail">
$LangNodes
    </Product>
  </Remove>
  <Display Level="None" AcceptEULA="TRUE" />
  <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
</Configuration>
"@ | Out-File -FilePath $XmlPath -Encoding utf8 -Force

    $Process = Start-Process -FilePath $ODTPath -ArgumentList "/configure `"$XmlPath`"" -Wait -PassThru -NoNewWindow

    # 5. Final Status & Cleanup
    if ($Process.ExitCode -eq 0) {
        Write-Host "Successfully removed extra language packs." -ForegroundColor Green
        Remove-Item $XmlPath, $ODTPath -ErrorAction SilentlyContinue
    } else {
        Write-Host "Uninstall failed with Exit Code: $($Process.ExitCode)" -ForegroundColor Red
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

# Menu Bar
$BtnTools_Menu      = $Main.FindName("BtnTools_Menu")
$BtnDeployment_Menu = $Main.FindName("BtnDeployment_Menu")
$BtnRestart_Menu    = $Main.FindName("BtnRestart_Menu")
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
$BtnCopyShortcuts               = $Main.FindName("BtnCopyShortcuts") 

# Client Selection Column
$ClientListBox          = $Main.FindName("ClientListBox")
$BtnClientChooser       = $Main.FindName("BtnClientChooser")
$BtnManualClientSelect  = $Main.FindName("BtnManualClientSelect")

# Apps Column
$BtnNVIDIAApp        = $Main.FindName("BtnNVIDIAApp")
$BtnAMDApp           = $Main.FindName("BtnAMDApp")
$BtnInstallDellApp   = $Main.FindName("BtnInstallDellApp")
$BtnInstalLenovoApp  = $Main.FindName("BtnInstalLenovoApp")
$BtnInstallHPApp     = $Main.FindName("BtnInstallHPApp")

# NAS Login Section
$BtnNASLogin        = $Main.FindName("BtnNASLogin")
$TxtBoxUsernameNAS  = $Main.FindName("TxtBoxUsernameNAS")
$PswrdBoxNAS        = $Main.FindName("PswrdBoxNAS")


# --- ACTIONS COLUMN CLICK EVENTS ---
$BtnRunAll.Add_Click({
    Update-Status -State "Busy"
    Copy-Shortcuts
    Repair-Winget
    Install-ClientCustomLocalApps
    Install-O365
    Install-DefaultWingetApps
    Install-ClientCustomWingetApps
    Uninstall-Bloat
    Uninstall-OfficeLanguagePacks
    Set-CustomPowerOptions
    Set-ComputerTimeZone
    Update-Status -State "Ready"
})

$BtnRepairWinget.Add_Click({
    Update-Status -State "Busy"
    Repair-Winget
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

$BtnInstallDefaultWingetApps.Add_Click({
    Update-Status -State "Busy"
    Install-DefaultWingetApps
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

$BtnUninstallLanguagePacks.Add_Click({
    Update-Status -State "Busy"
    Uninstall-OfficeLanguagePacks
    Update-Status -State "Ready"
})

$BtnSetPowerOptions.Add_Click({
    Update-Status -State "Busy"
    Set-CustomPowerOptions
    Update-Status -State "Ready"
})

$BtnSetTimeZone.Add_Click({
    Update-Status -State "Busy"
    Set-ComputerTimeZone
    Update-Status -State "Ready"
})

$BtnCopyShortcuts.Add_Click({
    Update-Status -State "Busy"
    Copy-Shortcuts
    Update-Status -State "Ready"
})

$BtnNASLogin.Add_Click({
    Update-Status -State "Busy"
    Connect-NAS
    Update-Status -State "Ready"
})

# --- CLIENT SELECT COLUMN CLICK EVENTS ---
$BtnClientChooser.Add_Click({
    Update-Status -State "Busy"
    Refresh-Clients
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

# --- APPS COLUMN CLICK EVENTS ---
$BtnNVIDIAApp.Add_Click({
    Update-Status -State "Busy"
    Start-Process "https://www.nvidia.com/en-us/software/nvidia-app-enterprise/"
    Update-Status -State "Ready"
})

$BtnAMDApp.Add_Click({
    Update-Status -State "Busy"
    Start-Process "https://www.amd.com/en/support/download/drivers.html"
    Update-Status -State "Ready"
})

$BtnInstallDellApp.Add_Click({
    Update-Status -State "Busy"
    Install-PassedWingetApp "Dell.CommandUpdate"
    Update-Status -State "Ready"
})

$BtnInstalLenovoApp.Add_Click({
    Update-Status -State "Busy"
    Install-PassedWingetApp "9NR5B8GVVM13"
    Update-Status -State "Ready"
})

$BtnInstallHPApp.Add_Click({
    Update-Status -State "Busy"
    Start-Process "https://support.hp.com/us-en/help/hp-support-assistant"
    Update-Status -State "Ready"
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

$BtnRestart_Menu.Add_Click({
    shutdown.exe /r /f /t 0
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
