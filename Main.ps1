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
# COMPILER_INSERT_HERE

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

$BtnClientChooser.Add_Click({
    Update-Status -State "Busy"
    Refresh-Clients
    Update-Status -State "Ready"
})

$ClientListBox.Add_MouseDoubleClick({
    Set-SelectedClient
})

$BtnTest.Add_Click({
    Update-Status -State "Busy"
    Copy-Shortcuts
    Update-Status -State "Ready"
})

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