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
<Window x:Name="Main_Window" x:Class="DepthWPFFramework_Revamped.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:DepthWPFFramework_Revamped"
        mc:Ignorable="d"
        Title="Depth" Height="650" Width="1100" SizeToContent="WidthAndHeight" WindowStartupLocation="CenterScreen" ResizeMode="CanResizeWithGrip" WindowStyle="None" AllowsTransparency="True" Background="#FF262D2F" MinWidth="1100" MinHeight="650" Topmost="True">
    <Window.Resources>
        <Style x:Key="CleanButtons" TargetType="Button">
            <Setter Property="Margin" Value="5,0,5,0"/>
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
                            <Trigger Property="IsPressed" Value="true">
                                <Setter TargetName="border" Property="Opacity" Value="0.7"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Grid x:Name="Main_Grid" Background="Transparent">
        <Border x:Name="Main_Border" BorderBrush="#FF2B3842" BorderThickness="5,5,5,5"/>
        <Grid x:Name="Title_Grid" Margin="0,0,0,426" VerticalAlignment="Top" Height="100">
            <Ellipse x:Name="Ellipse_StatusLight" Height="22" Stroke="Black" Width="22" HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,35,96,0" Fill="#FF0FFF1E">
                <Ellipse.Effect>
                    <BlurEffect/>
                </Ellipse.Effect>
            </Ellipse>
            <StackPanel x:Name="Tabs_StackPanel" HorizontalAlignment="Left" Height="60" Margin="20,0,0,0" VerticalAlignment="Center" Width="945" Orientation="Horizontal">
                <Button x:Name="Btn_Deployment" Content="Deployment" Style="{StaticResource CleanButtons}" Height="35" Width="100" Background="#FF454A4C" BorderBrush="White" FontFamily="Leelawadee" FontSize="14" BorderThickness="2,2,2,2" Foreground="White"/>
                <Button x:Name="Btn_Tools" Content="Tools" Style="{StaticResource CleanButtons}" Height="35" Width="100" Background="#FF454A4C" BorderBrush="White" FontFamily="Leelawadee" FontSize="14" BorderThickness="2,2,2,2" Foreground="White"/>
                <Button x:Name="Btn_RestartPC" Content="Restart PC" Style="{StaticResource CleanButtons}" Height="35" Width="100" Background="#FF454A4C" BorderBrush="White" FontFamily="Leelawadee" FontSize="14" BorderThickness="2,2,2,2" Foreground="White" HorizontalAlignment="Left" Margin="5,0,5,0"/>
            </StackPanel>
            <StackPanel x:Name="GUIControl_StackPanel" Margin="0,20,10,0" Height="60" Orientation="Horizontal" FlowDirection="RightToLeft" HorizontalAlignment="Right" VerticalAlignment="Top">
                <Button x:Name="Btn_Close" Content="X" Height="28" Width="35" Background="{x:Null}" FontFamily="MS Reference Sans Serif" FontSize="20" Foreground="White" BorderBrush="Transparent" Padding="0,0,0,0" UseLayoutRounding="False"/>
                <Button x:Name="Btn_Minimize" Content="_" Height="28" Width="35" Background="{x:Null}" FontFamily="MS Reference Sans Serif" Foreground="White" BorderBrush="Transparent" FontWeight="Bold" FontSize="28" Padding="0,-25,0,0" UseLayoutRounding="True" RenderTransformOrigin="0.471,0.35"/>
            </StackPanel>
        </Grid>
        <Grid x:Name="Deployment_Grid" Margin="0,100,0,0">
            <Border x:Name="Actions_Border" BorderBrush="#FF2B3842" BorderThickness="4,4,4,4" Margin="20,0,0,0" Width="196" HorizontalAlignment="Left" Height="490" VerticalAlignment="Top">
                <StackPanel x:Name="Actions_StackPanel" Margin="6,11,6,6">
                    <Label x:Name="Lbl_Actions" Content="Actions" Foreground="#FF3D6EE6" FontFamily="Leelawadee" FontSize="20" Height="35" Width="180" FontWeight="Bold"/>
                    <Button x:Name="Btn_RunAll" Content="Run All" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FF269832" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,8,0,0"/>
                    <Button x:Name="Btn_RepairWinget" Content="Repair Winget" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FF1C5971" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,8,0,0"/>
                    <Button x:Name="Btn_InstallO365" Content="Install O365 Apps" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FF1C5971" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,8,0,0"/>
                    <Button x:Name="Btn_InstallLocalApps" Content="Install Local Apps" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FF1C5971" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,8,0,0"/>
                    <Button x:Name="Btn_InstallDefaultWinget" Content="Default Winget" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FF1C5971" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,8,0,0"/>
                    <Button x:Name="Btn_InstallCustomWinget" Content="Custom Winget" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FF1C5971" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,8,0,0"/>
                    <Button x:Name="Btn_UninstallBloat" Content="Uninstall Bloat" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FF1C5971" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,8,0,0"/>
                    <Button x:Name="Btn_UninstallLanguagePacks" Content="Language Pack Killer" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FF1C5971" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,8,0,0"/>
                    <Button x:Name="Btn_SetPowerOptions" Content="Set Power Options" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FF1C5971" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,8,0,0"/>
                    <Button x:Name="Btn_SetTimezone" Content="Set Timezone" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FF1C5971" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,8,0,0"/>
                    <Button x:Name="Btn_CopyShortcuts" Content="Copy Shortcuts" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FF1C5971" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,8,0,0"/>
                </StackPanel>
            </Border>
            <Border x:Name="ClientSelect_Border" BorderBrush="#FF2B3842" BorderThickness="4,4,4,4" Margin="226,0,0,0" Width="200" Height="490" HorizontalAlignment="Left" VerticalAlignment="Top">
                <StackPanel x:Name="ClientSelect_StackPanel" Margin="6,11,10,6">
                    <Label x:Name="Lbl_ClientSelect" Content="Client Select" Foreground="#FF3D6EE6" FontFamily="Leelawadee" FontSize="20" Height="35" Width="180" FontWeight="Bold"/>
                    <Button x:Name="Btn_ReloadClients" Content="Reload Client List" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FF1C5971" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,10,0,0"/>
                    <Button x:Name="Btn_ManualSelection" Content="Manual Client Select" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FF1C5971" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,10,0,0"/>
                    <ListBox x:Name="ListBox_Clients" Height="334" d:ItemsSource="{d:SampleData ItemCount=5}" Margin="0,10,0,0" Width="160" Background="Black" Foreground="White" ScrollViewer.VerticalScrollBarVisibility="Auto"/>
                </StackPanel>
            </Border>
            <Border x:Name="Misc_Border" BorderBrush="#FF2B3842" BorderThickness="4,4,4,4" Margin="436,0,0,0" Width="200" Height="490" HorizontalAlignment="Left" VerticalAlignment="Top">
                <StackPanel x:Name="Misc_StackPanel" Margin="6,11,10,6">
                    <Label x:Name="Lbl_Misc" Content="Misc" Foreground="#FF3D6EE6" FontFamily="Leelawadee" FontSize="20" Height="35" Width="180" FontWeight="Bold"/>
					<Button x:Name="Btn_ConfigUAC" Content="Set UAC" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FFE4B307" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,10,0,0"/>
					<Button x:Name="Btn_ConfigTaskbar" Content="Configure Taskbar" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FFE4B307" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,10,0,0"/>
					<Button x:Name="Btn_UnlockWinUpdate" Content="Unlock Win Updates" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FFE4B307" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,10,0,0"/>
				</StackPanel>
            </Border>
            <Border x:Name="Apps_Border" BorderBrush="#FF2B3842" BorderThickness="4,4,4,4" Margin="646,0,0,0" Width="200" Height="490" HorizontalAlignment="Left" VerticalAlignment="Top">
                <StackPanel x:Name="Apps_StackPanel" Margin="6,11,10,6">
                    <Label x:Name="Lbl_Apps" Content="Apps" Foreground="#FF3D6EE6" FontFamily="Leelawadee" FontSize="20" Height="35" Width="180" FontWeight="Bold"/>
                    <Button x:Name="Btn_InstallNVIDIAApp" Content="NVIDIA App" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FF1C5971" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,8,0,0"/>
                    <Button x:Name="Btn_InstallAMDApp" Content="AMD App" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FF1C5971" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,8,0,0"/>
                    <Button x:Name="Btn_InstallDellApp" Content="Dell App" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FF1C5971" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,8,0,0"/>
                    <Button x:Name="Btn_InstallLenovoApp" Content="Lenovo App" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FF1C5971" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,8,0,0"/>
                    <Button x:Name="Btn_InstallHPApp" Content="HP App" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FF1C5971" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,8,0,0"/>
					<Button x:Name="Btn_InstallSnapdragonApp" Content="Snapdragon App" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FF1C5971" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,8,0,0"/>
				</StackPanel>
            </Border>
            <Border x:Name="NAS_Border" BorderBrush="#FF2B3842" BorderThickness="4,4,4,4" Margin="856,0,0,0" Width="200" Height="197" HorizontalAlignment="Left" VerticalAlignment="Top">
                <StackPanel x:Name="NAS_StackPanel" Margin="6,11,10,6">
                    <Label x:Name="Lbl_NASLogin" Content="NAS Login" Foreground="#FF3D6EE6" FontFamily="Leelawadee" FontSize="20" Height="35" Width="112" FontWeight="Bold" HorizontalAlignment="Left"/>
                    <Label x:Name="LblUsername" Content="Username" FontFamily="Leelawadee" Foreground="White" FontWeight="Bold" HorizontalAlignment="Left" Margin="3,0,0,0"/>
                    <TextBox x:Name="TxtBox_Username" TextWrapping="Wrap" Width="150" HorizontalAlignment="Left" Margin="2,0,0,0" Height="22" FontSize="14"/>
                    <Label x:Name="LblPassword" Content="Password" FontFamily="Leelawadee" Foreground="White" FontWeight="Bold" HorizontalAlignment="Left" Margin="3,0,0,0"/>
                    <PasswordBox x:Name="PasswordBox_Password" Width="150" Height="22" HorizontalAlignment="Left" Margin="2,0,0,0"/>
                    <Button x:Name="Btn_Login" Content="Login" Margin="2,10,0,0" HorizontalAlignment="Left" Width="100" Height="30" FontFamily="Leelawadee" FontSize="16"/>
                </StackPanel>
            </Border>
            <Ellipse x:Name="Ellipse_NASLoginStatusLight" Stroke="Black" Margin="985,20,0,0" Width="20" Height="20" Fill="#FFF90909" VerticalAlignment="Top" HorizontalAlignment="Left">
                <Ellipse.Effect>
                    <BlurEffect/>
                </Ellipse.Effect>
            </Ellipse>
        </Grid>
        <Grid x:Name="Tools_Grid" Margin="0,100,0,0" Visibility="Collapsed">
            <Image x:Name="Img_Ken" Width="500" Height="500" HorizontalAlignment="Center" VerticalAlignment="Top" Source="https://github.com/noteuphorix/Depth/blob/master/src/imgs/Ken2.png?raw=true"/>
        </Grid>
        <Label x:Name="Lbl_Copyright" Content="Created By: Brandon Swarek" FontFamily="Leelawadee" FontSize="20" VerticalAlignment="Bottom" HorizontalAlignment="Right" Padding="5,5,3,5" Width="266" Foreground="White"/>
    </Grid>
</Window>
"@

# --- GLOBAL VARIABLES ---


# 1. Show Splashscreen
$Splash = Load-VisualStudioXaml -RawXaml $splashXML
$Splash.Show()
Start-Sleep -Seconds 3
$Splash.Close()

# 2. Load main GUI object
$Main = Load-VisualStudioXaml -RawXaml $mainXML

# --- FUNCTIONS SECTION ---
# COMPILER_INSERT_HERE

# --- UI ELEMENT MAPPING ---


# Grids
$Main_Grid       = $Main.FindName("Main_Grid")
$Tools_Grid      = $Main.FindName("Tools_Grid")
$Deployment_Grid = $Main.FindName("Deployment_Grid")

# Menu Bar
$Btn_Tools      = $Main.FindName("Btn_Tools")
$Btn_Deployment = $Main.FindName("Btn_Deployment")
$Btn_RestartPC  = $Main.FindName("Btn_RestartPC")
$Btn_Close      = $Main.FindName("Btn_Close")
$Btn_Minimize   = $Main.FindName("Btn_Minimize")

# Status Indicators
$Ellipse_StatusLight         = $Main.FindName("Ellipse_StatusLight")
$Ellipse_NASLoginStatusLight = $Main.FindName("Ellipse_NASLoginStatusLight")

# Actions Column
$Btn_RunAll                   = $Main.FindName("Btn_RunAll")
$Btn_RepairWinget             = $Main.FindName("Btn_RepairWinget")
$Btn_InstallO365              = $Main.FindName("Btn_InstallO365")
$Btn_InstallLocalApps         = $Main.FindName("Btn_InstallLocalApps")
$Btn_InstallDefaultWinget     = $Main.FindName("Btn_InstallDefaultWinget")
$Btn_InstallCustomWinget      = $Main.FindName("Btn_InstallCustomWinget")
$Btn_UninstallBloat           = $Main.FindName("Btn_UninstallBloat")
$Btn_UninstallLanguagePacks   = $Main.FindName("Btn_UninstallLanguagePacks")
$Btn_SetPowerOptions          = $Main.FindName("Btn_SetPowerOptions")
$Btn_SetTimezone              = $Main.FindName("Btn_SetTimezone")
$Btn_CopyShortcuts            = $Main.FindName("Btn_CopyShortcuts") 

# Client Selection Column
$ListBox_Clients      = $Main.FindName("ListBox_Clients")
$Btn_ReloadClients    = $Main.FindName("Btn_ReloadClients")
$Btn_ManualSelection  = $Main.FindName("Btn_ManualSelection")

# Misc Column
$Btn_ConfigUAC     = $Main.FindName("Btn_ConfigUAC")
$Btn_ConfigTaskbar = $Main.FindName("Btn_ConfigTaskbar")

# Apps Column (Drivers)
$Btn_InstallNVIDIAApp     = $Main.FindName("Btn_InstallNVIDIAApp")
$Btn_InstallAMDApp        = $Main.FindName("Btn_InstallAMDApp")
$Btn_InstallDellApp       = $Main.FindName("Btn_InstallDellApp")
$Btn_InstallLenovoApp     = $Main.FindName("Btn_InstallLenovoApp")
$Btn_InstallHPApp         = $Main.FindName("Btn_InstallHPApp")
$Btn_InstallSnapdragonApp = $Main.FindName("Btn_InstallSnapdragonApp")

# NAS Login Section
$Btn_Login             = $Main.FindName("Btn_Login")
$TxtBox_Username       = $Main.FindName("TxtBox_Username")
$PasswordBox_Password  = $Main.FindName("PasswordBox_Password")
$Btn_UnlockWinUpdate   = $Main.FindName("Btn_UnlockWinUpdate")


# --- ACTIONS COLUMN CLICK EVENTS ---
$Btn_RunAll.Add_Click({
    Update-Status -State "Busy"
    Copy-Shortcuts; Repair-Winget; Install-ClientCustomLocalApps; Install-O365
    Install-DefaultWingetApps; Install-ClientCustomWingetApps; Uninstall-Bloat
    Uninstall-OfficeLanguagePacks; Set-CustomPowerOptions; Set-ComputerTimeZone
    Update-Status -State "Ready"
})

$Btn_RepairWinget.Add_Click({
    Update-Status -State "Busy"
    Repair-Winget
    Update-Status -State "Ready"
})

$Btn_InstallO365.Add_Click({
    Update-Status -State "Busy"
    Install-O365
    Update-Status -State "Ready"
})

$Btn_InstallLocalApps.Add_Click({
    Update-Status -State "Busy"
    Install-ClientCustomLocalApps
    Update-Status -State "Ready"
})

$Btn_InstallDefaultWinget.Add_Click({
    Update-Status -State "Busy"
    Install-DefaultWingetApps
    Update-Status -State "Ready"
})

$Btn_InstallCustomWinget.Add_Click({
    Update-Status -State "Busy"
    Install-ClientCustomWingetApps
    Update-Status -State "Ready"
})

$Btn_UninstallBloat.Add_Click({
    Update-Status -State "Busy"
    Uninstall-Bloat
    Update-Status -State "Ready"
})

$Btn_UninstallLanguagePacks.Add_Click({
    Update-Status -State "Busy"
    Uninstall-OfficeLanguagePacks
    Update-Status -State "Ready"
})

$Btn_SetPowerOptions.Add_Click({
    Update-Status -State "Busy"
    Set-CustomPowerOptions
    Update-Status -State "Ready"
})

$Btn_SetTimezone.Add_Click({
    Update-Status -State "Busy"
    Set-ComputerTimeZone
    Update-Status -State "Ready"
})

$Btn_CopyShortcuts.Add_Click({
    Update-Status -State "Busy"
    Copy-Shortcuts
    Update-Status -State "Ready"
})

$Btn_Login.Add_Click({
    Update-Status -State "Busy"
    Connect-NAS
    Update-Status -State "Ready"
})

# --- CLIENT SELECT COLUMN CLICK EVENTS ---
$Btn_ReloadClients.Add_Click({
    Update-Status -State "Busy"
    Refresh-Clients
    Update-Status -State "Ready"
})

$Btn_ManualSelection.Add_Click({
    Update-Status -State "Busy"
    Select-ManualFolder
    Update-Status -State "Ready"
})

$ListBox_Clients.Add_MouseDoubleClick({
    Set-SelectedClient
})

# --- MISC COLUMN ---
$Btn_ConfigUAC.Add_Click({
    Update-Status -State "Busy"
    Set-UAC
    Update-Status -State "Ready"
})

$Btn_ConfigTaskbar.Add_Click({
    Update-Status -State "Busy"
    Set-Taskbar
    Update-Status -State "Ready"
})

$Btn_UnlockWinUpdate.Add_Click({
    Update-Status -State "Busy"
    Unlock-WinUpdates
    Update-Status -State "Ready"
})

# --- APPS COLUMN (DRIVERS) CLICK EVENTS ---
$Btn_InstallNVIDIAApp.Add_Click({
    Update-Status -State "Busy"
    Install-PassedWingetApp "TechPowerUp.NVCleanstall"
    Update-Status -State "Ready"
})

$Btn_InstallAMDApp.Add_Click({
    Update-Status -State "Busy"
    Start-Process "https://www.amd.com/en/support/download/drivers.html"
    Update-Status -State "Ready"
})

$Btn_InstallDellApp.Add_Click({
    Update-Status -State "Busy"
    Install-PassedWingetApp "Dell.CommandUpdate"
    Update-Status -State "Ready"
})

$Btn_InstallLenovoApp.Add_Click({
    Update-Status -State "Busy"
    Install-PassedWingetApp "9NR5B8GVVM13"
    Update-Status -State "Ready"
})

$Btn_InstallHPApp.Add_Click({
    Update-Status -State "Busy"
    Start-Process "https://support.hp.com/us-en/help/hp-support-assistant"
    Update-Status -State "Ready"
})

$Btn_InstallSnapdragonApp.Add_Click({
    Update-Status -State "Busy"
    Start-Process "https://softwarecenter.qualcomm.com/api/download/software/tools/SnapdragonControlPanel/Windows/ARM64/2025.3.0.0/Snapdragon_Control_Panel_2025.3.0.0.zip"
    Update-Status -State "Ready"
})

# --- TAB SWITCHING BUTTON CLICK EVENTS ---
$Btn_Tools.Add_Click({
    $Deployment_Grid.Visibility = "Collapsed"
    $Tools_Grid.Visibility = "Visible"
})

$Btn_Deployment.Add_Click({
    $Tools_Grid.Visibility = "Collapsed"
    $Deployment_Grid.Visibility = "Visible"
})

# --- TITLE BAR BUTTON CLICK EVENTS ---
$Btn_Close.Add_Click({
    $Main.Close()
})

$Btn_Minimize.Add_Click({
    $Main.WindowState = [System.Windows.WindowState]::Minimized
})

$Btn_RestartPC.Add_Click({
    shutdown.exe /r /f /t 0
})

# --- GRID EVENTS ---
$Main_Grid.Add_MouseLeftButtonDown({
    $Main.DragMove()
})

# 3. OPEN THE WINDOW (Last Step)
$Main_Grid.Add_Loaded({
    Startup-Logo
    GUI-Startup
})

$Tools_Grid.Visibility = "Collapsed"
$Main.ShowDialog() | Out-Null
Write-Host "Goodbye!!!" -ForegroundColor Cyan