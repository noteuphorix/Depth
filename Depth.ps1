Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Output "Depth needs to be run as Administrator. Attempting to relaunch."

    $script = if ($PSCommandPath) {
        "& { & `'$($PSCommandPath)`' $($argList -join ' ') }"
    } else {
        "&([ScriptBlock]::Create((irm https://depth.narwal.llc))) $($argList -join ' ')"
    }

    $powershellCmd = "powershell"
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
                        -replace 'd:DesignWidth=".*?"',' ' `
                        -replace '�','&#169;'
    [xml]$xml = $Cleaned
    $reader = New-Object System.Xml.XmlNodeReader $xml
    return [Windows.Markup.XamlReader]::Load($reader)
}

# --- SPLASH XAML ---
$splashXML = @"
<Window x:Class="DepthSplashScreen.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:DepthSplashScreen"
        mc:Ignorable="d"
        Title="MainWindow" Height="379" Width="632" Background="Transparent" WindowStartupLocation="CenterScreen" WindowStyle="None" ResizeMode="NoResize" Foreground="Transparent" AllowsTransparency="True">
    <Window.Resources>
        <Storyboard x:Key="Storyboard1"/>
    </Window.Resources>
    <Grid x:Name="GridSplash" Background="#00000000">
        <!-- Blurred background layer -->
        <!-- Glass overlay layer -->
        <Border x:Name="BorderUpper" BorderBrush="Black" BorderThickness="1" Margin="0,231,0,0" Background="White"/>
        <Border x:Name="BorderLower" BorderBrush="Black" BorderThickness="1" Margin="0,0,0,121">
            <Border.Background>
                <LinearGradientBrush EndPoint="0.5,1" StartPoint="0.5,0">
                    <GradientStop Color="Black"/>
                    <GradientStop Color="#FF1B5D9A" Offset="1"/>
                </LinearGradientBrush>
            </Border.Background>
        </Border>
        <Label x:Name="LblSplash" Content="Euphoria LLC" Background="{x:Null}" Foreground="White" Margin="20,20,0,0" HorizontalAlignment="Left" VerticalAlignment="Top" FontSize="20" FontFamily="Segoe UI Light"/>
        <Label x:Name="LblProgramName" Content="Depth" Background="{x:Null}" Foreground="White" Margin="0,80,0,0" HorizontalAlignment="Center" VerticalAlignment="Top" FontSize="48" FontWeight="Bold"/>
        <Label x:Name="LblProgramPurpose" Content="Mass Deployment Tool" Background="{x:Null}" Foreground="White" HorizontalAlignment="Center" VerticalAlignment="Top" FontSize="30" FontFamily="Segoe UI Light" Margin="0,144,0,0"/>
        <Label x:Name="LblCopyrightOne" Content="Copyright � 2025-2026 Brandon Swarek" Background="{x:Null}" Foreground="Black" HorizontalAlignment="Right" VerticalAlignment="Bottom" FontSize="13" FontFamily="Segoe UI Light" Margin="0,0,30,26"/>
        <Label x:Name="LblCopyrightTwo" Content="All rights reserved" Background="{x:Null}" Foreground="Black" HorizontalAlignment="Right" VerticalAlignment="Bottom" FontSize="13" FontFamily="Segoe UI Light" Margin="0,0,30,8"/>
        <ProgressBar x:Name="PBarLoading" Margin="0,302,0,0" RenderTransformOrigin="0.5,0.5" VerticalAlignment="Top" HorizontalAlignment="Center" Width="400" Height="20" IsIndeterminate="True">
            <ProgressBar.RenderTransform>
                <TransformGroup>
                    <ScaleTransform ScaleY="-1"/>
                    <SkewTransform/>
                    <RotateTransform/>
                    <TranslateTransform/>
                </TransformGroup>
            </ProgressBar.RenderTransform>
        </ProgressBar>
        <Label x:Name="LblCopyrightOne_Copy" Content="Loading..." Background="{x:Null}" Foreground="Black" HorizontalAlignment="Left" VerticalAlignment="Bottom" FontFamily="Segoe UI Light" Margin="112,0,0,80"/>
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
        Title="Depth" Height="650" Width="1100" SizeToContent="WidthAndHeight" WindowStartupLocation="CenterScreen" ResizeMode="CanResizeWithGrip" WindowStyle="None" AllowsTransparency="True" Background="#FF262D2F" MinWidth="1100" MinHeight="650">
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
				<Button x:Name="Btn_Deployment" Content="Deployment" Style="{StaticResource CleanButtons}" Height="35" Width="100" Background="#FF454A4C" BorderBrush="White" FontFamily="Leelawadee" FontSize="14" BorderThickness="2,2,2,2" Foreground="White" HorizontalAlignment="Left"/>
				<Button x:Name="Btn_Tools" Content="Tools" Style="{StaticResource CleanButtons}" Height="35" Width="100" Background="#FF454A4C" BorderBrush="White" FontFamily="Leelawadee" FontSize="14" BorderThickness="2,2,2,2" Foreground="White" HorizontalAlignment="Left"/>
				<Button x:Name="Btn_FAQ" Content="FAQ" Style="{StaticResource CleanButtons}" Height="35" Width="100" Background="#FF454A4C" BorderBrush="White" FontFamily="Leelawadee" FontSize="14" BorderThickness="2,2,2,2" Foreground="White" HorizontalAlignment="Left" Margin="5,0,5,0" VerticalAlignment="Center"/>
				<Button x:Name="Btn_RestartPC" Content="Restart PC" Style="{StaticResource CleanButtons}" Height="35" Width="100" Background="#FF454A4C" BorderBrush="White" FontFamily="Leelawadee" FontSize="14" BorderThickness="2,2,2,2" Foreground="White"/>
				<Slider x:Name="Slider_Ken" Width="120" HorizontalAlignment="Left" VerticalAlignment="Center" Margin="5,0,0,0" SmallChange="1" Value="-1" TickPlacement="TopLeft" IsSnapToTickEnabled="True"/>
			</StackPanel>
			<StackPanel x:Name="GUIControl_StackPanel" Margin="0,20,10,0" Height="60" Orientation="Horizontal" FlowDirection="RightToLeft" HorizontalAlignment="Right" VerticalAlignment="Top">
				<Button x:Name="Btn_Close" Content="X" Height="28" Width="35" Background="{x:Null}" FontFamily="MS Reference Sans Serif" FontSize="20" Foreground="White" BorderBrush="Transparent" Padding="0,0,0,0" UseLayoutRounding="False"/>
				<Button x:Name="Btn_Minimize" Content="_" Height="28" Width="35" Background="{x:Null}" FontFamily="MS Reference Sans Serif" Foreground="White" BorderBrush="Transparent" FontWeight="Bold" FontSize="28" Padding="0,-25,0,0" UseLayoutRounding="True" RenderTransformOrigin="0.471,0.35"/>
			</StackPanel>
		</Grid>
		<Grid x:Name="Deployment_Grid" Margin="0,100,0,0">
			<Image x:Name="Img_Ken" Width="1100" Height="550" HorizontalAlignment="Center" VerticalAlignment="Top" Source="https://github.com/noteuphorix/Depth/blob/master/src/imgs/Ken2.png?raw=true" Stretch="Fill" Opacity="0"/>
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
					<ListBox x:Name="ListBox_Clients" Height="275" Margin="0,10,0,0" Width="160" Background="Black" Foreground="White" ScrollViewer.VerticalScrollBarVisibility="Auto"/>
					<Label x:Name="Lbl_SelectedClient" Content="Selected Client:" FontFamily="Leelawadee" FontSize="16" Foreground="White" Margin="0,1,0,0" FontWeight="Bold"/>
					<TextBlock x:Name="TxtBlock_SelectedClient" TextWrapping="Wrap" Text="None" FontFamily="Leelawadee" FontSize="16" Foreground="Red" Margin="4,-5,4,0"/>
				</StackPanel>
			</Border>
			<Border x:Name="Misc_Border" BorderBrush="#FF2B3842" BorderThickness="4,4,4,4" Margin="436,0,0,0" Width="200" Height="490" HorizontalAlignment="Left" VerticalAlignment="Top">
				<StackPanel x:Name="Misc_StackPanel" Margin="6,11,10,6">
					<Label x:Name="Lbl_Misc" Content="Misc" Foreground="#FF3D6EE6" FontFamily="Leelawadee" FontSize="20" Height="35" Width="180" FontWeight="Bold"/>
					<Button x:Name="Btn_ConfigUAC" Content="Set UAC" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FFE4B307" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,10,0,0"/>
					<Button x:Name="Btn_ConfigTaskbar" Content="Configure Taskbar" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FFE4B307" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,10,0,0"/>
					<Button x:Name="Btn_UnlockWinUpdate" Content="Unlock Win Updates" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FFE4B307" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,10,0,0"/>
					<Button x:Name="Btn_OfficeInstallBypass" Content="O365 Install Bypass" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FFE4B307" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,10,0,0"/>
					<Button x:Name="Btn_RepairTakeControl" Content="Repair Take Control" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FFE4B307" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,10,0,0"/>
				</StackPanel>
			</Border>
			<Border x:Name="Apps_Border" BorderBrush="#FF2B3842" BorderThickness="4,4,4,4" Margin="646,0,0,0" Width="200" Height="490" HorizontalAlignment="Left" VerticalAlignment="Top">
				<StackPanel x:Name="Apps_StackPanel" Margin="6,11,10,6">
					<Label x:Name="Lbl_Apps" Content="Apps" Foreground="#FF3D6EE6" FontFamily="Leelawadee" FontSize="20" Height="35" Width="180" FontWeight="Bold"/>
					<Button x:Name="Btn_InstallNVIDIAApp" Content="NVIDIA" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FF1C5971" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,8,0,0"/>
					<Button x:Name="Btn_InstallAMDApp" Content="AMD" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FF1C5971" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,8,0,0"/>
					<Button x:Name="Btn_InstallDellApp" Content="Dell" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FF1C5971" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,8,0,0"/>
					<Button x:Name="Btn_InstallLenovoApp" Content="Lenovo" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FF1C5971" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,8,0,0"/>
					<Button x:Name="Btn_InstallHPApp" Content="HP" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FF1C5971" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,8,0,0"/>
					<Button x:Name="Btn_InstallSnapdragonApp" Content="Snapdragon" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FF1C5971" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,8,0,0"/>
					<Button x:Name="Btn_InstallForticlientApp" Content="Forticlient" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FF1C5971" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,8,0,0"/>
					<Button x:Name="Btn_InstallFrameworkDrivers" Content="Framework Laptops" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FF1C5971" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,8,0,0"/>
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
		<Grid x:Name="Tools_Grid" Margin="0,100,0,0" d:IsHidden="True">
			<Border x:Name="HDActions_Border" BorderBrush="#FF2B3842" BorderThickness="4,4,4,4" Margin="20,0,0,0" Width="196" HorizontalAlignment="Left" Height="490" VerticalAlignment="Top">
				<StackPanel x:Name="HDActions_StackPanel" Margin="6,11,6,6">
					<Label x:Name="Lbl_HD_Actions" Content="HD Actions" Foreground="#FF3D6EE6" FontFamily="Leelawadee" FontSize="20" Height="35" Width="180" FontWeight="Bold"/>
					<Button x:Name="Btn_DISM" Content="DISM" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FF1C5971" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,8,0,0"/>
				</StackPanel>
			</Border>
            <Border x:Name="EuphActions_Border" BorderBrush="#FF2B3842" BorderThickness="4,4,4,4" Margin="226,0,0,0" Width="196" HorizontalAlignment="Left" Height="490" VerticalAlignment="Top">
                <StackPanel x:Name="EuphActions_StackPanel" Margin="6,11,6,6">
                    <Label x:Name="Lbl_Personal" Content="Personal" Foreground="#FF3D6EE6" FontFamily="Leelawadee" FontSize="20" Height="35" Width="180" FontWeight="Bold"/>
                    <Button x:Name="Btn_EnableScripting" Content="Enable Scripting" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FF1C5971" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,8,0,0"/>
					<Button x:Name="Btn_CheckHardware" Content="Check Hardware" Style="{StaticResource CleanButtons}" Height="30" Width="160" Background="#FF196DDE" BorderBrush="White" FontFamily="Leelawadee" FontSize="16" BorderThickness="1,1,1,1" Foreground="White" Padding="0,0,0,0" Margin="0,8,0,0"/>
				</StackPanel>
            </Border>
        </Grid>
		<Grid x:Name="FAQ_Grid" Margin="0,100,0,0" d:IsHidden="True">
			<StackPanel x:Name="FAQ_StackPanel" Margin="27,38,0,0" HorizontalAlignment="Left" Width="1042" VerticalAlignment="Top" Height="454">
				<Label x:Name="Lbl_FAQ" Content="FAQ" Foreground="#FF3D6EE6" FontFamily="Leelawadee" FontSize="40" FontWeight="Bold" HorizontalAlignment="Left" VerticalAlignment="Top"/>
				<Label x:Name="Lbl_FAQ1" Content="What is a hash mismatch?" FontFamily="Leelawadee" FontSize="20" Foreground="#FF73E4CC"/>
				<TextBlock x:Name="TxtBlock_FAQ1" TextWrapping="Wrap" Text="A Hash Mismatch occurs when Winget has not yet validated the hash of the program you are trying to install. You need to install the app manually until winget resolves the issue." Foreground="White" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="10,0,0,0"/>
				<Label x:Name="Lbl_FAQ2" Content="Winget error &quot;failed to update from source msstore&quot;." FontFamily="Leelawadee" FontSize="20" Foreground="#FF73E4CC"/>
				<TextBlock x:Name="TxtBlock_FAQ2" TextWrapping="Wrap" Text="This error is fixed by running the &quot;Repair Winget&quot; button on the Deployment tab." Foreground="White" Margin="10,0,0,0"/>
			</StackPanel>
			<Border x:Name="FAQ_Border" BorderBrush="White" BorderThickness="5,5,5,5" Margin="10,20,10,40"/>
		</Grid>
		<Label x:Name="Lbl_Copyright" Content="Created By: Brandon Swarek" FontFamily="Leelawadee" FontSize="20" VerticalAlignment="Bottom" HorizontalAlignment="Right" Padding="5,5,3,5" Width="266" Foreground="White"/>
	</Grid>
</Window>
"@

# --- SHOW SPASHSCREEN ---
$Splash = Load-VisualStudioXaml -RawXaml $splashXML
$Splash.Show()

$end = (Get-Date).AddSeconds(5)
while ((Get-Date) -lt $end) {
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 16
}

$Splash.Close()

# --- LOAD MAIN GUI OBJECT ---
$Main = Load-VisualStudioXaml -RawXaml $mainXML

# --- SYNC HASHTABLE ---
$sync = [hashtable]::Synchronized(@{
    Main    = $Main
    Running = [hashtable]::Synchronized(@{})
})

# --- FUNCTIONS SECTION ---


# --- Source: src\functions\Connect-NAS.ps1 ---
function Connect-NAS {
    $Ellipse_NASLoginStatusLight.Fill = [System.Windows.Media.Brushes]::Yellow
    [System.Windows.Forms.Application]::DoEvents()

    $User = $TxtBox_Username.Text
    $Pass = $PasswordBox_Password.Password
    $NASPath = "\\10.24.2.5\Clients"

    try {
        # Credential logic here...
        # If it fails, New-SmbMapping will throw an error to the 'catch' block
        New-SmbMapping -RemotePath $NASPath -Password $Pass -UserName $User -Persistent $true -ErrorAction Stop | Out-Null
        net use $NASPath $Pass /user:$User /persistent:yes /y > $null
        
        $global:NAS_Clients_Folder = $NASPath
        $ListBox_Clients.Items.Clear()
        $Folders = Get-ChildItem -Path $global:NAS_Clients_Folder -Directory -ErrorAction SilentlyContinue | Sort-Object Name
        foreach ($Folder in $Folders) {
            $ListBox_Clients.Items.Add($Folder.Name)
        }
        $Ellipse_NASLoginStatusLight.Fill = [System.Windows.Media.Brushes]::LimeGreen
    }
    catch {
        # This handles the failure WITHOUT opening a new window
        $Ellipse_NASLoginStatusLight.Fill = [System.Windows.Media.Brushes]::Red
        Write-Warning "Connection failed: $($_.Exception.Message)"
    }
}

# --- Source: src\functions\Copy-Shortcuts.ps1 ---
function Copy-Shortcuts {
    Show-FunctionBanner "Copy Shortcuts"
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

# --- Source: src\functions\Install-ClientCustomLocalApps.ps1 ---
function Install-ClientCustomLocalApps {
    Show-FunctionBanner "Install Client Local Apps"
    if ([string]::IsNullOrWhiteSpace($global:SelectedClient)) {
        Write-Warning "Choose a client first!"
        return
    }

    if ($global:SelectedClient -match ":" -or $global:SelectedClient -like "\\*") {
        $BasePath = $global:SelectedClient
    } 
    else {
        $BasePath = "\\10.24.2.5\Clients\$global:SelectedClient"
    }

    $FinalPath = Join-Path -Path $BasePath -ChildPath "Apps"

    if (-not (Test-Path $FinalPath)) {
        Write-Host "Apps folder not found at $BasePath" -ForegroundColor Red
        return
    }

    Write-Host "Starting custom app deployment from: $FinalPath" -ForegroundColor Cyan

    $InstalledApps = @(
    Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    Get-ItemProperty "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    ) | Where-Object { $_.DisplayName } | Select-Object -ExpandProperty DisplayName

    $WindowsAgentInstalled  = $InstalledApps -contains "Windows Agent"
    $GlobalProtectInstalled = $InstalledApps -contains "GlobalProtect"

    $AppFiles = Get-ChildItem -Path $FinalPath -File
    
    foreach ($App in $AppFiles) {

        if (($App.Name -like "*WindowsAgentSetup*" -and $WindowsAgentInstalled) -or
            ($App.Name -like "*GlobalProtect*"     -and $GlobalProtectInstalled)) {
            Write-Host "Skipping $($App.Name) - already installed." -ForegroundColor DarkYellow
            continue
        }

        Write-Host "Installing: $($App.Name)..." -ForegroundColor Yellow

        try {
            if ($App.Extension -eq ".msi") {
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

# --- Source: src\functions\Install-ClientCustomWingetApps.ps1 ---
function Install-ClientCustomWingetApps {
    Show-FunctionBanner "Install Client Winget Apps"
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
        # Executes winget for each ID found in the text file, attempts machine scope first
        $result = Start-Process winget -ArgumentList "install --id $App --silent --accept-source-agreements --accept-package-agreements --scope machine" -Wait -PassThru -NoNewWindow

        switch ($result.ExitCode) {
            0            { Write-Host "Successfully installed $App" -ForegroundColor Green }
            -1978335189  { Write-Host "$App is already up to date" -ForegroundColor Cyan }
            -1978335216  {
                            # APPINSTALLER_CLI_ERROR_NO_APPLICABLE_INSTALLER - retries without --scope machine
                            Write-Warning "$App failed with --scope machine (no applicable installer), retrying without --scope..."
                            $retryResult = Start-Process winget -ArgumentList "install --id $App --silent --accept-source-agreements --accept-package-agreements" -Wait -PassThru -NoNewWindow

                            switch ($retryResult.ExitCode) {
                                0            { Write-Host "Successfully installed $App (without --scope machine)" -ForegroundColor Green }
                                -1978335189  { Write-Host "$App is already up to date" -ForegroundColor Cyan }
                                default      { Write-Warning "Failed to install $App on retry (Exit code: $($retryResult.ExitCode))" }
                            }
                         }
            default      { Write-Warning "Failed to install $App (Exit code: $($result.ExitCode))" }
        }
    }

    return "Completed"
}

# --- Source: src\functions\Install-DefaultWingetApps.ps1 ---
function Install-DefaultWingetApps {
    Show-FunctionBanner "Install Default Winget Apps"
    $Apps = @("Google.Chrome", "Adobe.Acrobat.Reader.64-bit", "Intel.IntelDriverAndSupportAssistant", "Microsoft.Teams")

    foreach ($App in $Apps) {
        $result = Start-Process winget -ArgumentList "install --id $App --silent --accept-source-agreements --accept-package-agreements" -Wait -PassThru -NoNewWindow
        
        switch ($result.ExitCode) {
            0            { Write-Host "Successfully installed $App" -ForegroundColor Green }
            -1978335189  { Write-Host "$App is already up to date" -ForegroundColor Cyan }
            default      { Write-Warning "Failed to install $App (Exit code: $($result.ExitCode))" }
        }
    }

    return "Completed"
}

# --- Source: src\functions\Install-O365.ps1 ---
function Install-O365 {
    Show-FunctionBanner "O365 Apps Install"
    $Apps = @("Microsoft.Office")

    foreach ($App in $Apps) {
        $result = Start-Process winget -ArgumentList "install --id $App --silent --accept-source-agreements --accept-package-agreements" -Wait -PassThru -NoNewWindow
        
        switch ($result.ExitCode) {
            0            { Write-Host "Successfully installed $App" -ForegroundColor Green }
            -1978335189  { Write-Host "$App is already up to date" -ForegroundColor Cyan }
            default      { Write-Warning "Failed to install $App (Exit code: $($result.ExitCode))" }
        }
    }
}

# --- Source: src\functions\Install-O365Bypass.ps1 ---
function Install-O365Bypass {
    Write-Host "Starting manual install" -ForegroundColor Cyan
    
    $WorkDir = "$env:TEMP\OfficeInstall"
    if (!(Test-Path $WorkDir)) { New-Item $WorkDir -ItemType Directory | Out-Null }
    
    $SetupExe = "$WorkDir\setup.exe"
    $ConfigFile = "$WorkDir\configuration.xml"

    # 1. Download the official Microsoft Office Bootstrapper
    Write-Host "Downloading Microsoft Setup Tool..." -ForegroundColor Gray
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri "https://officecdn.microsoft.com/pr/wsus/setup.exe" -OutFile $SetupExe

    # 2. Create the Configuration file (Mimics the Winget Enterprise install)
    # This tells the installer to get 64-bit Enterprise silently
    $XmlContent = @"
<Configuration>
  <Add>
    <Product ID="O365ProPlusRetail">
      <Language ID="MatchOS"/>
      <Language ID="MatchPreviousMSI"/>
      <ExcludeApp ID="Groove"/>
      <ExcludeApp ID="Lync"/>
    </Product>
  </Add>
  <RemoveMSI/>
  <Display Level="Full" AcceptEULA="TRUE"/>
</Configuration>
"@
    $XmlContent | Out-File $ConfigFile -Encoding Ascii

    # 3. Run the installation directly as Admin
    Write-Host "Starting Installation..." -ForegroundColor Green
    # We use /configure to tell the setup tool to use our XML
    Start-Process -FilePath $SetupExe -ArgumentList "/configure `"$ConfigFile`"" -Wait

    # Cleanup
    Remove-Item $WorkDir -Recurse -Force
    Write-Host "[OK] Office Installation Completed." -ForegroundColor Green
}

# --- Source: src\functions\Install-PassedWingetApp.ps1 ---
function Install-PassedWingetApp {
    param([string]$AppID)

    # 1. Check if we need to run the full system upgrade first
    if ($AppID -eq "Dell.CommandUpdate" -or $AppID -eq "Dell.CommandUpdate.Universal") {
        Write-Host "Dell Command Update detected. Running full system upgrade first..." -ForegroundColor Cyan
        $upgradeResult = Start-Process winget -ArgumentList "upgrade --all --silent --accept-source-agreements --accept-package-agreements" -Wait -PassThru -NoNewWindow

        switch ($upgradeResult.ExitCode) {
            0            { Write-Host "System upgrade completed successfully" -ForegroundColor Green }
            -1978335189  { Write-Host "All packages already up to date" -ForegroundColor Cyan }
            default      { Write-Warning "System upgrade finished with exit code: $($upgradeResult.ExitCode)" }
        }
    }

    # 2. Proceed to install the requested AppID (including Dell apps)
    Write-Host "Installing package: $AppID..." -ForegroundColor Green
    $result = Start-Process winget -ArgumentList "install --id $AppID --silent --accept-source-agreements --accept-package-agreements" -Wait -PassThru -NoNewWindow

    switch ($result.ExitCode) {
        0            { Write-Host "Successfully installed $AppID" -ForegroundColor Green }
        -1978335189  { Write-Host "$AppID is already up to date" -ForegroundColor Cyan }
        default      { Write-Warning "Failed to install $AppID (Exit code: $($result.ExitCode))" }
    }

    Start-Sleep -Seconds 1
}

# --- Source: src\functions\Refresh-Clients.ps1 ---
function Refresh-Clients {
    # 1. Check if the path is set
    if (-not $global:NAS_Clients_Folder) {
        Write-Warning "Refresh failed: NAS path is not defined. Please connect first."
        return
    }

    try {
        # 2. Clear existing items
        $ListBox_Clients.Items.Clear()
        
        # 3. Re-populate from the global NAS path
        $Folders = Get-ChildItem -Path $global:NAS_Clients_Folder -Directory -ErrorAction Stop | Sort-Object Name
        
        foreach ($Folder in $Folders) {
            $ListBox_Clients.Items.Add($Folder.Name)
        }
    }
    catch {
        Write-Warning "Refresh failed: $($_.Exception.Message)"
    }
}

# --- Source: src\functions\Repair-TakeControl.ps1 ---
function Repair-TakeControl {
# Take Control Recovery Script
# N-able Technologies 2025
# Version: 4.5.2
#
# This script checks for the installation of the Take Control agent, verifies its signature, and re-installs it if necessary.
# The script is designed to be run with administrator privileges and can be forced to re-install the agent using command line arguments.

# Parameters:
# -Force: Forces the re-installation of the Take Control agent without changing it's configuration..
# -CleanInstall: Forces a clean installation of the Take Control agent, removing any existing installations and registry keys.
# -TargetVersion: Install the specified version of the Take Control N-central agent.
# -CheckOnly: Checks the Take Control agent state without re-installing it.
# -CheckAndReInstall: Checks the Take Control agent state and re-installs it if necessary.
# -Silent: Runs the script in silent mode without user interaction.
# -DisableNewTCIntegrationCheck: Disable the new Take Control N-central agent integration check.
# -RestartNcentralAgent: Restarts the N-central agent if necessary to apply the integration change.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Re-installs the Take Control agent without changing it's configuration.")]
    [switch]$Force,    
    [Parameter(Mandatory = $false, HelpMessage = "Performs a clean install of the Take Control agent.")]
    [switch]$CleanInstall,
    [Parameter(Mandatory = $false, HelpMessage = "Checks the Take Control agent state without re-installing it.")]
    [switch]$CheckOnly,
    [Parameter(Mandatory = $false, HelpMessage = "Checks the Take Control agent state and re-installs it if necessary.")]
    [switch]$CheckAndReInstall,
    [Parameter(Mandatory = $false, HelpMessage = "Runs the script in silent mode without user interaction.")]
    [switch]$Silent,
    [Parameter(Mandatory = $false, HelpMessage = "Install the specified version of the Take Control N-central agent.")]
    [string]$TargetVersion,
    [Parameter(Mandatory = $false, HelpMessage = "Disable the new Take Control N-central agent integration check.")]
    [switch]$DisableNewTCIntegrationCheck = $false,
    [Parameter(Mandatory = $false, HelpMessage = "Restarts the N-central agent if necessary to apply the integration change.")]
    [switch]$RestartNcentralAgent = $false
)
Show-FunctionBanner "Take Control Repair"
$ScriptVersion = "4.5.2"

$agentInstallPath = Join-Path -Path ${Env:ProgramFiles(x86)} -ChildPath "Beanywhere Support Express\GetSupportService_N-central"
$agentIniPath = Join-Path -Path ${Env:ProgramData} -ChildPath "GetSupportService_N-Central\BASupSrvc.ini"
$agentRegPath = "HKLM:\SOFTWARE\WOW6432Node\Multiplicar Negocios\BACE_N-Central\Settings"
$ncentralAgentBinaryPath = Join-Path -Path ${Env:ProgramFiles(x86)} -ChildPath "N-able Technologies\Windows Agent\bin"
$ncentralAgentConfigPath = Join-Path -Path ${Env:ProgramFiles(x86)} -ChildPath "N-able Technologies\Windows Agent\config\RCConfig.xml"

if ($env:PROCESSOR_ARCHITECTURE -eq "x86") {
    $agentInstallPath = Join-Path ${Env:ProgramFiles} "Beanywhere Support Express\GetSupportService_N-central"
    $agentRegPath = "HKLM:\SOFTWARE\Multiplicar Negocios\BACE_N-Central\Settings"
    $ncentralAgentBinaryPath = Join-Path ${Env:ProgramFiles} "N-able Technologies\Windows Agent\bin"
    $ncentralAgentConfigPath = Join-Path -Path ${Env:ProgramFiles} -ChildPath "N-able Technologies\Windows Agent\config\RCConfig.xml"
}

$AgentBinaryPath = Join-Path $agentInstallPath "BASupSrvc.exe"
$UpdaterBinaryPath = Join-Path $agentInstallPath "BASupSrvcUpdater.exe"
$AgentUninstallerPath = Join-Path $agentInstallPath "UnInstall.exe" 
$IncorrectServiceName = "BASupportExpressStandaloneService"
$AgentServiceName = "BASupportExpressStandaloneService_N_Central"
$UpdaterServiceName = "BASupportExpressSrvcUpdater_N_Central"
$InstallLockFilePath = Join-Path $agentInstallPath "__installing.lock"
$UnInstallLockFilePath = Join-Path $agentInstallPath "__uninstalling.lock"
$NCentralAgentRemoteControlDLLPath = Join-Path $ncentralAgentBinaryPath "RemoteControl.dll"
$NCentralAgentConfigValueXPath = '/RCConfig/mspa_install_check_intervall'
$NCentralWindowsAgentService = "Windows Agent Service"


$RemoteJsonUrl = "https://swi-rc.cdn-sw.net/n-central/updates/json/TakeControlCheckAndReInstall.json"

if ($TargetVersion -and ($TargetVersion -notmatch '^\d+\.\d+\.[a-zA-Z0-9-_]+$')) {
    Write-Host "Invalid TargetVersion format. Please use X.Y.Z format."
    Return 1
}

if ($TargetVersion -ne "") {
    $RemoteJsonUrl = "https://swi-rc.cdn-sw.net/n-central/updates/json/TakeControlCheckAndReInstall_$TargetVersion.json"
}

$ExpectedSignedSubject = "CN=N-ABLE TECHNOLOGIES LTD, O=N-ABLE TECHNOLOGIES LTD, L=Dundee, C=GB"

$serviceNotRunningGuardInterval = 10
$lockFileAgeThresholdMinutes = 10

$LogFilePath = Join-Path $env:TEMP "TakeControlCheckAndReInstall.log"

function WriteLog {
    param (
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet("", "INFO", "WARN", "ERROR")]
        [string]$Level = "INFO",
        [Parameter(Mandatory = $false)]
        [string]$ForegroundColor = "White",
        [Parameter(Mandatory = $false)]
        [bool]$LogToConsole = !$Silent
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp][$Level] $Message"

    if ($LogToConsole) {
        
        # Write to console
        switch ($Level) {
            "INFO" { Write-Host $logEntry -ForegroundColor $ForegroundColor }
            "WARN" { Write-Host $logEntry -ForegroundColor DarkYellow }
            "ERROR" { Write-Host $logEntry -ForegroundColor DarkRed }
        }

    }

    # Write to log file
    try {
        Add-Content -Path $LogFilePath -Value $logEntry
    }
    catch {
        Write-Host "Failed to write to log file: $LogFilePath"
    }
}

function CheckFileSignature {
    param (
        [string]$FilePath
    )

    $result = $false

    try {

        $signature = Get-AuthenticodeSignature -FilePath $FilePath

        if ($signature.Status -eq "Valid") {

            if ($signature.SignerCertificate.Subject -eq $ExpectedSignedSubject) {
                $result = $true
            }
            else {
                WriteLog -Level "ERROR" -Message  "The file has a valid signature but is not signed by N-able."
            }

        }
        else {
            WriteLog -Level "ERROR" -Message  "The file does not have a valid signature."
        }

    }
    catch {
        WriteLog -Level "ERROR" -Message  "Error: Unable to retrieve signature information for the file."
    }

    return $result

}

function FetchTakeControlAgent {

    $validRequest = $false

    try {

        WriteLog -Message  "Fetching latest Take Control agent information..."
        $ProgressPreference = 'SilentlyContinue'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        $jsonContent = Invoke-RestMethod -Uri $RemoteJsonUrl
        $validRequest = $true

    }
    catch {
        WriteLog -Level "ERROR" -Message  "Exception occurred while retrieving the remote json file. $($_.Exception.Message)"
    }

    if ($validRequest) { 
      
        try {

            $Url = $jsonContent.url;
            $ExpectedHash = $jsonContent.expected_hash
            $ExpectedSize = $jsonContent.expected_size

        }
        catch {
            WriteLog -Level "ERROR" -Message  "Exception occurred while parsing the remote json file. $($_.Exception.Message)"
            $validRequest = $false
        }
 
        if (($Url -ne "") -and ($ExpectedHash -ne "") -and ($validRequest)) {

            $uniqueId = [System.Guid]::NewGuid().ToString()

            $FilePath = Join-Path $env:TEMP "MSPA4NCentralInstaller-$uniqueId.exe"

            Remove-Item -Path $FilePath -ErrorAction SilentlyContinue

            WriteLog -Message  "Fetching Take Control agent binary from '$Url' to '$FilePath'."
            Invoke-WebRequest -Uri $Url -OutFile $FilePath

            WriteLog -Message  "Verifying the hash of the downloaded file."
            $ActualHash = (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash

            $ActualSize = (Get-Item -Path $FilePath).Length

            if ($ExpectedSize -ne $ActualSize) {
                WriteLog -Level "ERROR" -Message  "The file size does not match the expected size. Returning..."
                return $null
            } 
            elseif ($ExpectedHash -ne $ActualHash) {
                WriteLog -Level "ERROR" -Message  "The file hash does not match the expected hash. Returning..."
                return $null
            }
            elseif (-not (CheckFileSignature($FilePath))) {
                WriteLog -Level "ERROR" -Message  "The file signature is not valid. Returning..."   
                return $null
            }
            else {
                WriteLog -Message  "The file size and hash match the expected values and the signature is correct."

                return $FilePath
            }

        }
        else {
            WriteLog -Level "ERROR" -Message  "Empty URL or expected_hash."
        }

    }
    else {
        WriteLog -Level "ERROR" -Message  "Unable to retrieve the remote json file."
    }

    return $null

}

function ExecuteBinary {
    param (
        [string] $FileName,
        [string] $Parameters,
        [bool] $RemoveFile = $true
    )

    $ReturnCode = -1

    try {

        $proc = Start-Process -FilePath $FileName -ArgumentList $Parameters -Wait -PassThru -NoNewWindow -ErrorAction Stop
        $ReturnCode = $proc.ReturnCode

    }
    catch {
        WriteLog -Level "ERROR" -Message  "Error executing file `$FileName: $($_.Exception.Message)"
        $ReturnCode = 1
    }

    if ($RemoveFile) {
       
        try {
            if (Test-Path -Path $FileName) {
                WriteLog -Message  "Deleting file:`t$FileName"
                Remove-Item -Path $FileName
            }
        }
        catch {
            WriteLog -Level "WARN" -Message  "Error deleting file `$FileName`: $($_.Exception.Message)"
        }  
    
    }

    return $ReturnCode

}

function RemoveAgentIniAndRegKeyIfPresent {

    if (Test-Path -Path $agentIniPath) {
        try {
            Remove-Item -Path $agentIniPath -Force -ErrorAction Stop
            WriteLog -Message  "Successfully deleted file:`t$agentIniPath"
        }
        catch {
            WriteLog -Level "WARN" -Message  "Error deleting file `$agentIniPath`: $_"
        }
    }

    if (Test-Path -Path $agentRegPath) {
        try {
            Remove-Item -Path $agentRegPath -Recurse -Force -ErrorAction Stop
            WriteLog -Message  "Successfully deleted registry key:`t$agentRegPath"
        }
        catch {
            WriteLog -Level "WARN" -Message  "Error deleting registry key `t$agentRegPath`: $_"
        }
    }

}

function Get-IniContent {
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path $Path)) {
        return $null
    }

    $ini = @{}
    $currentSection = ''

    foreach ($rawLine in Get-Content $Path) {
        $line = $rawLine.Trim()
        if ($line -match '^\s*;') {
            # skip comments
            continue
        }
        elseif ($line -match '^\[(.+)\]$') {
            # section header
            $currentSection = $Matches[1]
            if (-not $ini.ContainsKey($currentSection)) {
                $ini[$currentSection] = @{}
            }
        }
        elseif ($line -match '^(.*?)=(.*)$') {
            # key = value
            $key = $Matches[1].Trim()
            $value = $Matches[2].Trim()
            if ($currentSection) {
                $ini[$currentSection][$key] = $value
            }
            else {
                # keys before any section go at top level
                $ini[$key] = $value
            }
        }
    }

    return $ini
}

function IsLockFilePresent {
    param (
        [Parameter(Mandatory = $true)]
        [string]$LockFilePath,
        [Parameter(Mandatory = $false)]
        [int]$lockFileAgeThresholdMinutes = 10
    )

    $lockExists = $false

    if (Test-Path -Path $LockFilePath) {
        $installLockFileCreationTime = (Get-Item -Path $LockFilePath).CreationTime
        $ageMinutes = (Get-Date) - $installLockFileCreationTime
        if ($ageMinutes.TotalMinutes -lt $lockFileAgeThresholdMinutes) {
            WriteLog -Message  "The lock file '$LockFilePath' is newer than $lockFileAgeThresholdMinutes minutes. Returning..."
            $lockExists = $true
        }
        else {
            WriteLog -Message  "The lock file '$LockFilePath' is older than $lockFileAgeThresholdMinutes minutes."
        }
    }

    return $lockExists

}

function WaitForLockFile {
    param (
        [Parameter(Mandatory = $true)]
        [string]$LockFilePath,
        [Parameter(Mandatory = $false)]
        [int]$WaitTimeInSeconds = 30
    )

    $endTime = (Get-Date).AddSeconds($WaitTimeInSeconds)

    while ((Get-Date) -lt $endTime) {
        if (IsLockFilePresent -LockFilePath $LockFilePath) {
            return $true
        }

        Start-Sleep -Seconds 5
    }

    return $false
}

function TerminateProcessList {
    param (
        [Parameter(Mandatory = $true)]
        [array]$ProcessList
    )

    foreach ($process in $ProcessList) {
        try {
            Get-Process -Name $process.Name -ErrorAction SilentlyContinue | Where-Object { $_.Path -ieq $process.Path } | Stop-Process -Force -ErrorAction SilentlyContinue
        }
        catch {
            WriteLog -Level "WARN" -Message  "Error terminating process '$($process.Name)': $_"
        }
    }

}

function CheckNCentralRemoteControlDLLVersion {
    param (
        [Parameter(Mandatory = $false)]
        [string]$NCentralAgentRemoteControlDLLPath = $NCentralAgentRemoteControlDLLPath
    )

    if (Test-Path -Path $NCentralAgentRemoteControlDLLPath) {
        $dllVersion = [Version](Get-Item -Path $NCentralAgentRemoteControlDLLPath).VersionInfo.FileVersion
        WriteLog -Message  "N-central Agent Remote Control DLL version: $dllVersion"

        $minAffectedVersion = [Version]"2024.6.0.0"
        $maxAffectedVersion = [Version]"2024.6.0.22"

        if ($dllVersion -ge $minAffectedVersion -and $dllVersion -le $maxAffectedVersion) {
            WriteLog -Level "WARN" -Message  "The detected RemoteControl.DLL of the N-central Agent is known to be affected by a documented issue. Please refer to N-central's documentation to update it to the latest version."
        }

    }
    else {
        WriteLog -Level "WARN" -Message  "N-central Remote Control DLL not found at path: $NCentralAgentRemoteControlDLLPath"
    }

}

# Set TC NC integration version
function ConfigValueToVersion($ConfigValue) {
    return $(if ($ConfigValue -le 0) { 2 } else { 1 })
}

function VersionToConfigValue($Version) {
    return $(if ($Version -eq 2) { 0 } else { 15000 })
}

function GetTCIntegrationVersion() {

    if (-not (Test-Path -Path $ncentralAgentConfigPath)) {
        throw "N-central agent configuration file not found at path: $ncentralAgentConfigPath"
    }

    $xml = [System.Xml.XmlDocument]::new()
    $xml.Load($ncentralAgentConfigPath)

    if ($null -ne $xml.SelectSingleNode($ncentralAgentConfigValueXPath)) {
        WriteLog -Level "INFO" -Message "Found N-central agent Take Control integration configuration."
        return ConfigValueToVersion($xml.SelectSingleNode($ncentralAgentConfigValueXPath).InnerText)
    }
    else {
        throw "N-central agent Take Control integration configuration not found."
    }

}

function SetTCIntegrationVersion($Version) {

    if (-not (Test-Path -Path $ncentralAgentConfigPath)) {
        throw "N-central agent configuration file not found at path: $ncentralAgentConfigPath"
    }

    if (-not (Test-Path -Path $NCentralAgentRemoteControlDLLPath)) {
        WriteLog -Level "ERROR" -Message "N-central Remote Control DLL not found at path: $NCentralAgentRemoteControlDLLPath"
        return
    }

    $remoteControlInfo    = Get-Item -Path $NCentralAgentRemoteControlDLLPath | Select-Object -ExpandProperty VersionInfo
    $remoteControlVersion = [Version]$remoteControlInfo.FileVersion   
    WriteLog -Level "INFO" -Message  "N-central Agent Remote Control DLL version: $remoteControlVersion"

    $RemoteControlMinVersion = [Version]"2025.4.0.0"
    if ($remoteControlVersion -lt $RemoteControlMinVersion) {
        WriteLog -Level "WARN" -Message "N-central agent version $($remoteControlVersion.ProductVersion) is less than the minimum required $RemoteControlMinVersion for enabling the new integration, please upgrade the N-central Windows agent first."
        return
    }

    WriteLog -Level "INFO" -Message "Setting integration version to $Version"
    $xml = [System.Xml.XmlDocument]::new()
    $xml.Load($ncentralAgentConfigPath)
    $xml.SelectSingleNode($ncentralAgentConfigValueXPath).InnerText = VersionToConfigValue($Version)
    $xml.Save($ncentralAgentConfigPath)

}

function CheckAndEnableNewTCIntegration() {

    if (Test-Path -Path $ncentralAgentConfigPath) {

        try {

            $currentIntegrationVersion = GetTCIntegrationVersion

            WriteLog -Level "INFO" -Message "Current Take Control integration version: $currentIntegrationVersion"
            if ($currentIntegrationVersion -ne 2) {

                WriteLog -Level "INFO" -Message "Enabling enhanced Take Control recovery..."
                SetTCIntegrationVersion -Version 2

                if ($RestartNcentralAgent) {
                    if (ServiceExists -ServiceName $NCentralWindowsAgentService) {
                        WriteLog -Level "INFO" -Message "Restarting N-central agent service..."
                        StopService -ServiceName $NCentralWindowsAgentService -WaitTimeInMinutes 3
                        Start-Service -Name $NCentralWindowsAgentService
                        WriteLog -Level "INFO" -Message "N-central agent service restarted."
                    }
                    else {
                        WriteLog -Level "WARN" -Message "N-able N-central Agent service not found, cannot restart."
                    }
                }

            }

        }
        catch {
            WriteLog -Level "ERROR" -Message  "Error : $($_.Exception.Message)"
        }

    }

}

function IsNcentralRCConfigValid {

    if (Test-Path -Path $ncentralAgentConfigPath) {

        try {

            $xmlContent = [xml](Get-Content -Path $ncentralAgentConfigPath)

            if (($null -ne $xmlContent.RCConfig.mspa_server_unique_id) -and ($null -ne $xmlContent.RCConfig.mspa_secret_key) -and ($xmlContent.RCConfig.mspa_server_unique_id -ne "") -and ($xmlContent.RCConfig.mspa_secret_key -ne "") ) {
                return $true
            }
            else {
                WriteLog -Level "WARN" -Message  "N-central Remote Control configuration not found or incomplete."
                return $false
            }

        }
        catch {
            WriteLog -Level "ERROR" -Message  "Error reading N-central Remote Control configuration file: $($_.Exception.Message)"
        }

    }
    else {
        WriteLog -Level "WARN" -Message  "N-central Remote Control configuration file not found at path: $ncentralAgentConfigPath"
    }

    return $false

}


function  TestGatewayTCPConnection {
    param (
        [Parameter(Mandatory = $false)]
        [string]$GwTCPHost = "gw-tcp-test.global.mspa.n-able.com",
        [Parameter(Mandatory = $false)]
        [int]$GwTCPPort = 443,
        [Parameter(Mandatory = $false)]
        [int]$Timeout = 5000  # 5 seconds
    )

    $connectionSuccess = $false
    $command = "PING"

    try {

        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect($GwTCPHost, $GwTCPPort)
        $networkStream = $tcpClient.GetStream()

        $networkStream.ReadTimeout = $Timeout
        $networkStream.WriteTimeout = $Timeout

        $reader = New-Object System.IO.StreamReader($networkStream)
        $writer = New-Object System.IO.StreamWriter($networkStream)
        $writer.AutoFlush = $true

        try {

            $writer.WriteLine($command)

            $response = $reader.ReadLine()

            if ($response -match "200 OK") {
                WriteLog -Message  "Take Control GW_TCP_$GwTCPPort is reachable. `t[200 - OK]" -ForegroundColor DarkGreen
                $connectionSuccess = $true
            }
            else {
                WriteLog -Level "WARN" -Message  "Take Control GW_TCP_$GwTCPPort is reachable with errors. `t[$response - UNEXPECTED RESPONSE]"
            }

        }
        catch {
            WriteLog -Level "WARN" -Message  "Take Control GW_TCP_$GwTCPPort is NOT reachable. `t[ERROR] - $($_.Exception.Message)"            
        }
        finally {
            $reader.Close()
            $writer.Close()
            $tcpClient.Close()
        }

    }
    catch {
        WriteLog -Level "WARN" -Message  "Take Control GW_TCP_$GwTCPPort is NOT reachable. `t[ERROR] - $($_.Exception.Message)"            
    }   

    return $connectionSuccess
    
}

function  TestGatewayTLSConnection {
    param (
        [Parameter(Mandatory = $false)]
        [string]$GwTLSHost = "gw-tls-test.global.mspa.n-able.com",
        [Parameter(Mandatory = $false)]
        [int]$GwTLSPort = 443,
        [Parameter(Mandatory = $false)]
        [int]$Timeout = 5000  # 5 seconds
    )

    $connectionSuccess = $false
    $command = "PING"

    try {

        $tcpClient = New-Object System.Net.Sockets.TcpClient($GwTLSHost, $GwTLSPort)
        $networkStream = $tcpClient.GetStream()

        $sslStream = New-Object System.Net.Security.SslStream($networkStream, $false, { $true })
        $sslStream.AuthenticateAsClient($GwTLSHost, $null, [System.Security.Authentication.SslProtocols]::Tls12, $false)

        $sslStream.ReadTimeout = $Timeout
        $sslStream.WriteTimeout = $Timeout

        $reader = New-Object System.IO.StreamReader($sslStream)
        $writer = New-Object System.IO.StreamWriter($sslStream)
        $writer.AutoFlush = $true

        try {
            
            $writer.WriteLine($command)

            $response = $reader.ReadLine()

            if ($response -match "200 OK") {
                WriteLog -Message  "Take Control GW_TLS_443 is reachable. `t[200 - OK]" -ForegroundColor DarkGreen
                $connectionSuccess = $true
            }
            else {
                WriteLog -Level "WARN" -Message  "Take Control GW_TLS_443 is reachable with errors. `t[$response - UNEXPECTED RESPONSE]"
            }

        }
        catch {
            WriteLog -Level "WARN" -Message  "Take Control GW_TLS_443 is NOT reachable. `t[ERROR] - $($_.Exception.Message)"            
        }
        finally {
            $reader.Close()
            $writer.Close()
            $sslStream.Close()
            $tcpClient.Close()
        }

    }
    catch {
        WriteLog -Level "WARN" -Message  "Take Control GW_TLS is NOT reachable. `t[ERROR] - $($_.Exception.Message)"            
    }

    return $connectionSuccess

}

function TestTakeControlInfrastructureConnection {

    $HTTPQueryList = @(
        @{ Region = "GLB"; URL = "https://comserver.global.mspa.n-able.com/comserver/echo.php?magicid=query_global"; ExpectedValue = "<response><echo>query_global</echo></response>" },
        @{ Region = "US1"; URL = "https://comserver.us1.mspa.n-able.com/comserver/echo.php?magicid=query_us1"; ExpectedValue = "<response><echo>query_us1</echo></response>" },
        @{ Region = "US2"; URL = "https://comserver.us2.mspa.n-able.com/comserver/echo.php?magicid=query_us2"; ExpectedValue = "<response><echo>query_us2</echo></response>" },
        @{ Region = "EU1"; URL = "https://comserver.eu1.mspa.n-able.com/comserver/echo.php?magicid=query_eu1"; ExpectedValue = "<response><echo>query_eu1</echo></response>" },
        @{ Region = "CDN"; URL = "https://swi-rc.cdn-sw.net/n-central/scripts/echo.xml"; ExpectedValue = "<response><echo>query_cdn</echo></response>" }
    )

    $connectionError = $false

    foreach ($httpQuery in $HTTPQueryList) {

        try {

            $ProgressPreference = 'SilentlyContinue'           
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $response = Invoke-WebRequest -Uri $httpQuery.URL -UseBasicParsing -ErrorAction Stop

            if ($response.Content -eq $httpQuery.expectedValue) {
                WriteLog -Message  "Take Control $($httpQuery.Region) is reachable. `t`t[$($response.StatusCode) - OK]" -ForegroundColor DarkGreen
            }
            else {
                WriteLog -Level "WARN" -Message  "Take Control $($httpQuery.Region) is reachable with errors. `t`t[$($response.StatusCode) - UNEXPECTED RESPONSE]"
            }

        }
        catch {
            WriteLog -Level "WARN" -Message  "Take Control $($httpQuery.Region) is NOT reachable. `t`t[ERROR] - $($_.Exception.Message)"            
            $connectionError = $true
        }

    }

    $gwTCPResult = TestGatewayTCPConnection
    $gwTCPResult3377 = TestGatewayTCPConnection -GwTCPPort 3377
    $gwTLSResult = TestGatewayTLSConnection

    if ((-not $gwTCPResult) -and (-not $gwTCPResult3377) -and (-not $gwTLSResult)) {
        $connectionError = $true
    }
    
    if ($connectionError -eq $true) {
        WriteLog -Level "WARN" -Message  "`nTake Control infrastructure may not be reachable. Please check this device's internet connection and firewall settings and make sure connections to the Take Control infrastructure are not being blocked. Please refer to the Take Control documentation for more information.`n"
    }
    
}

function CheckLockFileAndReInstall {
    param (
        [Parameter(Mandatory = $false)]
        [bool]$CleanInstall = $false
    )

    $lockExists = IsLockFilePresent -LockFilePath $InstallLockFilePath -lockFileAgeThresholdMinutes $lockFileAgeThresholdMinutes
    if ($lockExists -eq $true) {
        WriteLog -Message  "Installation lock file is present. Returning..."
        Return
    }

    $lockExists = IsLockFilePresent -LockFilePath $UnInstallLockFilePath -lockFileAgeThresholdMinutes $lockFileAgeThresholdMinutes
    if ($lockExists -eq $true) {
        WriteLog -Message  "Uninstallation lock file is present. Returning..."
        Return
    }

    WriteLog -Message  "Fetching Take Control agent location..."
    $agentFile = FetchTakeControlAgent
    $mspID = $null

    if ($null -ne $agentFile) {

        if ($CleanInstall -eq $true) {

            WriteLog -Message  "Reading ini file content..."
            $iniContent = Get-IniContent -Path $agentIniPath

            if ($null -eq $iniContent) {
                WriteLog -Message  "No ini file found..."
            }
            else {
                if ($iniContent.ContainsKey("Main") -and $iniContent["Main"].ContainsKey("MSPID")) {                 
                    $mspID = $iniContent["Main"]["MSPID"]
                    WriteLog -Message  "MSPID: $mspID"
                }
                else {
                    WriteLog -Level "WARN" -Message  "No MSPID found in ini file..."
                }
            }

            # Remove Take Control service with incorrect name if present
            if (ServiceExists -ServiceName $IncorrectServiceName) {

                if (CheckServiceExecutablePath -ServiceName $IncorrectServiceName -ExpectedPath $AgentBinaryPath) {

                    WriteLog -Message  "Found TC N-central agent with incorrect service name $IncorrectServiceName..."
                    $serviceStopped = StopService -ServiceName $IncorrectServiceName -WaitTimeInMinutes 3

                    if (-not $serviceStopped) {
                        WriteLog -Level "WARN" -Message  "Take Control service $IncorrectServiceName did not stop within the expected time."
                    } else {

                        WriteLog -Message  "Removing incorrect Take Control service $IncorrectServiceName..."
                        if (DeleteService -ServiceName $IncorrectServiceName) {
                            WriteLog -Message  "Successfully removed incorrect Take Control service $IncorrectServiceName."
                        }
                        else {
                            WriteLog -Level "WARN" -Message  "Error removing incorrect Take Control service $IncorrectServiceName."
                        }

                    }

                }
               
            }

            if (Test-Path $AgentUninstallerPath) {

                $lockExists = IsLockFilePresent -LockFilePath $UnInstallLockFilePath -lockFileAgeThresholdMinutes $lockFileAgeThresholdMinutes
                if ($lockExists -eq $true) {
                    WriteLog -Message  "Uninstallation lock file is present. Uninstallation is in progress... Returning..."
                    Return
                }

                WriteLog -Message  "Uninstalling previous agent..."

                $uninstallerArguments = "/S"
                $ReturnCode = ExecuteBinary -FileName $AgentUninstallerPath -Parameters $uninstallerArguments
                WriteLog -Message "Uninstaller finished with Return code $ReturnCode"

            }
            else {
                WriteLog -Level "WARN" -Message  "Take Control agent uninstaller not found..."
            }

            WriteLog -Message  "Making sure the Take Control agent is not running..."
            if (ServiceExists -ServiceName $AgentServiceName) {
                WriteLog -Message  "Stopping Take Control service  $AgentServiceName..."
                StopService -ServiceName $AgentServiceName -WaitTimeInMinutes 3
            }

            if (ServiceExists -ServiceName $UpdaterServiceName) {
                WriteLog -Message  "Stopping Take Control service  $UpdaterServiceName..."
                StopService -ServiceName $UpdaterServiceName -WaitTimeInMinutes 3
            }

            $processList = @(
                @{ Name = "BASupSrvc"; Path = $AgentBinaryPath },
                @{ Name = "BASupSrvcUpdater"; Path = $UpdaterBinaryPath }
            )

            WriteLog -Message  "Terminating any running services..."
            TerminateProcessList -ProcessList $processList

            WriteLog -Message  "Cleaning up previous installation..."
            RemoveAgentIniAndRegKeyIfPresent

        }

        $parameters = "/S /R /L"
        if (($null -ne $mspID) -and ($mspID -ne "")) {
            $parameters += " /MSPID $mspID"
        }

        WriteLog -Message  "Checking for the presence of install lock file..."
        $lockExists = WaitForLockFile -LockFilePath $InstallLockFilePath -WaitTimeInSeconds 45
        if ($lockExists -eq $true) {
            WriteLog -Message  "Installation lock file is present. Installation is already in progress... Returning..."
            Return
        }

        WriteLog -Message  "Starting Take Control agent installer"
        $ReturnCode = ExecuteBinary -FileName $agentFile -Parameters $parameters
        WriteLog -Message "Installer finished with Return code $ReturnCode"

    }
    else {
        WriteLog -Level "ERROR" -Message ("Unable to download Take Control agent file...")  
    }

    Return

}

function ServiceExists {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ServiceName
    )

    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

    if ($null -eq $service) {
        return $false
    } 

    return $true

}

function WaitForServiceState {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ServiceName,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedState,

        [Parameter(Mandatory = $true)]
        [int]$WaitTimeInMinutes,

        [Parameter(Mandatory = $false)]
        [int]$ServicePollIntervalSeconds = 5
    )

    $endTime = (Get-Date).AddMinutes($WaitTimeInMinutes)

    while ((Get-Date) -lt $endTime) {
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

        if (($null -ne $service) -and ($service.Status -eq $ExpectedState)) {
            WriteLog -Message  "Service '$ServiceName' is in the '$ExpectedState' state."
            return $true
        }

        Start-Sleep -Seconds $servicePollIntervalSeconds
    }

    WriteLog -Message  "Service '$ServiceName' did not reach the '$ExpectedState' state within the specified wait time."
    return $false

}

function WaitForServiceToStart {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ServiceName,

        [Parameter(Mandatory = $true)]
        [int]$WaitTimeInMinutes
    )

    WaitForServiceState -ServiceName $ServiceName -ExpectedState "Running" -WaitTimeInMinutes $WaitTimeInMinutes

}

function StopService {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ServiceName,

        [Parameter(Mandatory = $true)]
        [int]$WaitTimeInMinutes
    )

    if (-not (ServiceExists -ServiceName $ServiceName)) {
        WriteLog -Level "WARN" -Message  "Service '$ServiceName' does not exist."
        return $false
    }

    try {

        Stop-Service -Name $ServiceName -ErrorAction Stop

    }
    catch {
        WriteLog -Level "WARN" -Message  "Error stopping service '$ServiceName': $_"
        return $false
    }

    $retVal = WaitForServiceState -ServiceName $ServiceName -ExpectedState "Stopped" -WaitTimeInMinutes $WaitTimeInMinutes

    return $retVal
}

function DeleteService {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ServiceName
    )

    if (-not (ServiceExists -ServiceName $ServiceName)) {
        WriteLog -Level "WARN" -Message  "Service '$ServiceName' does not exist."
        return $false
    }

    try {

        sc.exe delete $ServiceName | Out-Null

    }
    catch {
        WriteLog -Level "WARN" -Message  "Error deleting service '$ServiceName': $($_.Exception.Message)"
        return $false
    }

    return $true

}

function CheckServiceExecutablePath {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ServiceName,
        [Parameter(Mandatory = $true)]
        [string]$ExpectedPath
    )

    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

    if ($null -eq $service) {
        return $false
    }

    try {

        $wmiService = Get-WmiObject -Class Win32_Service -Filter "Name='$ServiceName'" -ErrorAction Stop
        $actualPath = $wmiService.PathName.Trim('"')

        if ($actualPath -ieq $ExpectedPath) {
            WriteLog -Message  "The service '$ServiceName' executable path matches the expected path."
            return $true
        }
        else {
            WriteLog -Level "WARN" -Message  "The service '$ServiceName' executable path does not match the expected path."
            return $false
        }

    }
    catch {
        WriteLog -Level "ERROR" -Message  "Error retrieving service information for '$ServiceName': $_"
        return $false
    }

}

## Perform Take Control agent state checks | return $true if the agent is in a good state, otherwise return $false
function IsTakeControlAgentInGoodState {
    param (
        [Parameter(Mandatory = $false)]
        [bool]$RestartServiceIfStopped = $false
    )

    WriteLog -Message "Checking Take Control agent state..."
    if ((-not (Test-Path -Path $AgentBinaryPath)) -or (-not (Test-Path -Path $UpdaterBinaryPath))) {

        WriteLog -Level ERROR -Message "Take Control agent binaries were not found..."
        return $false

    }
    else {

        WriteLog -Message "Take Control agent binaries were found..." -ForegroundColor DarkGreen

    }

    WriteLog -Message "Checking Take Control agent signatures..."
    if (-not (CheckFileSignature -FilePath $AgentBinaryPath)) {
        WriteLog -Level "ERROR" -Message  "Take Control agent binary signature is invalid."
        return $false
    }
    else {
        WriteLog -Message "Take Control agent binary signature is valid." -ForegroundColor DarkGreen
    }

    if (-not (CheckFileSignature -FilePath $UpdaterBinaryPath)) {
        WriteLog -Level "ERROR" -Message  "Take Control updater binary signature is invalid."
        return $false
    }
    else {
        WriteLog -Message "Take Control updater binary signature is valid." -ForegroundColor DarkGreen
    }

    $agentService = Get-Service -Name $AgentServiceName -ErrorAction SilentlyContinue
    if (-not $agentService) {

        WriteLog -Level ERROR -Message "The service '$AgentServiceName' is not registered..."
        return $false

    }
    else {

        WriteLog -Message "The service '$AgentServiceName' is registered..." -ForegroundColor DarkGreen

    }

    $updaterService = Get-Service -Name $UpdaterServiceName -ErrorAction SilentlyContinue
    if (-not $updaterService) {

        WriteLog -Level ERROR -Message "The service '$UpdaterServiceName' is not registered."
        return $false

    }
    else {

        WriteLog -Message  "The service '$UpdaterServiceName' is registered..." -ForegroundColor DarkGreen

    }

    if ($agentService.Status -ne "Running") {

        if ($RestartServiceIfStopped) {

            WriteLog -Message  "The service '$AgentServiceName' is not running... Waiting..."
            
            Start-Service -Name $AgentServiceName
            $agentServiceStarted = WaitForServiceToStart -ServiceName $AgentServiceName -WaitTimeInMinutes $serviceNotRunningGuardInterval
            if ($agentServiceStarted -eq $false) {
                WriteLog -Level ERROR -Message "The service '$AgentServiceName' is still not running... Re-Installing..."
                return $false
            }
            else {
                WriteLog -Message  "The service '$AgentServiceName' started... Skipping re-installation..."
            }

        }
        else {

            WriteLog -Level ERROR -Message  "The service '$AgentServiceName' is not running..."
            return $false

        }

    }
    else {

        WriteLog -Message  "The service '$AgentServiceName' is running..." -ForegroundColor DarkGreen

    }

    if ($updaterService.Status -ne "Running") {  

        if ($RestartServiceIfStopped) {

            WriteLog -Message  "The service '$UpdaterServiceName' is not running... Waiting..."
            $updaterServiceStarted = WaitForServiceToStart -ServiceName $UpdaterServiceName -WaitTimeInMinutes $serviceNotRunningGuardInterval
            if ($updaterServiceStarted -eq $false) {
                WriteLog -Message  "The service '$UpdaterServiceName' is still not running... Re-Installing..."
                return $false
            }
            else {
                WriteLog -Message  "The service '$UpdaterServiceName' started... Skipping re-installation..."
            }

        }
        else {

            WriteLog -Message  "The service '$UpdaterServiceName' is not running..."
            return $false

        }
 
    }
    else {

        WriteLog -Message  "The service '$UpdaterServiceName' is running..." -ForegroundColor DarkGreen

    }

    return $true

}

## Main Script Execution
WriteLog -Message  "Take Control Check and Re-Install Script v'$ScriptVersion'" -ForegroundColor DarkCyan
WriteLog -Message  "N-able Technologies 2025" -ForegroundColor DarkMagenta
WriteLog -Message  "------------------------------------------------------------"

if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    WriteLog -Message "This script must be run with Administrator privileges."
    Return
} 

WriteLog -Message "Testing Take Control infrastructure connection..."
TestTakeControlInfrastructureConnection

WriteLog -Message "Checking N-Central agent RemoteControl.dll version..."
CheckNCentralRemoteControlDLLVersion

if ($DisableNewTCIntegrationCheck -ne $true) {

    WriteLog -Message "Checking and enabling new Take Control integration if needed..."
    CheckAndEnableNewTCIntegration

}

if ($Force) {

    WriteLog -Message "Forcing re-installation of Take Control..."
    CheckLockFileAndReInstall -CleanInstall $false    

}

if ($CleanInstall) {

    WriteLog -Message "Performing clean installation of Take Control..."  
    CheckLockFileAndReInstall -CleanInstall $true

}

if ($CheckOnly) {

    WriteLog -Message "Checking Take Control agent state without re-installing..."
    $isInGoodState = IsTakeControlAgentInGoodState -RestartServiceIfStopped $false
    if ($isInGoodState) {
        WriteLog -Message "Take Control agent is in a good state."
        $isRCConfigValid = IsNcentralRCConfigValid
        if (-not $isRCConfigValid) {
            WriteLog -Level "WARN" -Message "N-central Remote Control configuration is not found or incomplete. Re-installing..."
            Return 1
        }
        else {
            WriteLog -Message "N-central Remote Control configuration is complete."
            Return 0
        }
    }
    else {
        WriteLog -Level "ERROR" -Message "Take Control agent is not in a good state. Please check the logs for more details."
        Return 1
    }

}

if ($CheckAndReInstall) {

    WriteLog -Message "Checking Take Control agent state and re-installing if necessary..."
    $agentInGoodState = IsTakeControlAgentInGoodState -RestartServiceIfStopped $false
    if (-not $agentInGoodState) {
        WriteLog -Level ERROR -Message "Take Control agent is not in a good state. Re-installing..."
        CheckLockFileAndReInstall -CleanInstall $true
    }
    else {

        $isRCConfigValid = IsNcentralRCConfigValid
        if (-not $isRCConfigValid) {
            WriteLog -Level "ERROR" -Message "N-central Remote Control configuration is not found or incomplete. Re-installing..."
            CheckLockFileAndReInstall -CleanInstall $true
        }
        else {
            WriteLog -Message "N-central Remote Control configuration is found and complete."
        }

        WriteLog -Message "Take Control agent is in a good state. No re-installation needed."
    }

    Return 0

}
else {

    WriteLog -Message "Checking Take Control agent state and installing if necessary..."

    $agentInGoodState = IsTakeControlAgentInGoodState -RestartServiceIfStopped $true
    if (-not $agentInGoodState) {

        WriteLog -Level ERROR -Message "Take Control agent is not in a good state. Installing..."
        CheckLockFileAndReInstall -CleanInstall $false

    }
    else {

        $isRCConfigValid = IsNcentralRCConfigValid
        if (-not $isRCConfigValid) {
            WriteLog -Level "WARN" -Message "N-central Remote Control configuration is not found or incomplete. Re-installing..."
            CheckLockFileAndReInstall -CleanInstall $true
        }
        else {
            WriteLog -Message "N-central Remote Control configuration is found and complete."
        }

        WriteLog -Message "Take Control agent is in a good state. No re-installation needed."

    }
    
}
}

# --- Source: src\functions\Repair-Winget.ps1 ---
function Repair-Winget {
    # 0. Try to let Winget fix its own dependency first
    Show-FunctionBanner "Winget Repair"
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

# --- Source: src\functions\Select-ManualFolder.ps1 ---
function Select-ManualFolder {
    $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderBrowser.Description = "Select the Client Folder"
    $FolderBrowser.ShowNewFolderButton = $true

    $Result = $FolderBrowser.ShowDialog()

    if ($Result -eq [System.Windows.Forms.DialogResult]::OK) {
        # Set the global variable to the FULL PATH immediately
        $global:SelectedClient = $FolderBrowser.SelectedPath
        
        $SelectedFolderName = Split-Path $global:SelectedClient -Leaf

        $ListBox_Clients.Items.Clear()
        $ListBox_Clients.Items.Add($SelectedFolderName)
        $ListBox_Clients.SelectedIndex = 0

        Write-Host "Manual Path Selected: $global:SelectedClient" -ForegroundColor Green
    }
    Sync-ClientLabel
}

# --- Source: src\functions\Set-ComputerTimeZone.ps1 ---
function Set-ComputerTimeZone {
    Show-FunctionBanner "Set Timezone"
    # 1. Minimize GUI
    try {
        if (-not $Main.Dispatcher.HasShutdownStarted) {
            $Main.Dispatcher.Invoke(
                [Action]{ $Main.WindowState = [System.Windows.WindowState]::Minimized },
                [System.Windows.Threading.DispatcherPriority]::Normal,
                [System.Threading.CancellationToken]::None,
                [TimeSpan]::FromSeconds(3)
            )
        }
    } catch {
        Write-Warning "Could not minimize GUI (dispatcher busy or timed out): $_"
    }

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

# --- Source: src\functions\Set-CustomPowerOptions.ps1 ---
function Set-CustomPowerOptions {
    Show-FunctionBanner "Set Power Options"
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
            # Fast execution for individual registry updates
            Invoke-Expression $Command
            Write-Host "  [OK] $Label set." -ForegroundColor Gray
        }
        catch {
            Write-Warning "  [FAIL] Could not set $Label."
        }
    }

    # Apply changes globally - This is the critical point
    # We use Start-Process -Wait to ensure powercfg finishes the broadcast
    Start-Process -FilePath "powercfg.exe" -ArgumentList "/setactive SCHEME_CURRENT" -Wait -NoNewWindow
    
    # This ensures the GUI has processed the OS Power Change notification
    # before the function ends and the next UI action (Minimize) triggers.
    if ($null -ne $Main) {
        $Main.Dispatcher.Invoke([Action]{}, 'ContextIdle')
    }

    Write-Host "`nAll power options have been applied successfully." -ForegroundColor Green
}

# --- Source: src\functions\Set-SelectedClient.ps1 ---
function Set-SelectedClient {
    if ($ListBox_Clients.SelectedItem -ne $null) {
        $SelectedItemText = $ListBox_Clients.SelectedItem.ToString()

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
    Sync-ClientLabel
}

# --- Source: src\functions\Set-Taskbar.ps1 ---
function Set-Taskbar {
    Write-Host "Wiping taskbar pins and configuring layout..." -ForegroundColor Cyan

    # 1. THE WIPE
    try {
        $PinPath = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\Taskbar"
        if (Test-Path $PinPath) { Get-ChildItem -Path $PinPath -File | Remove-Item -Force }

        $RegistryPins = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband"
        Remove-ItemProperty -Path $RegistryPins -Name "Favorites" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $RegistryPins -Name "FavoritesResolve" -ErrorAction SilentlyContinue
        Write-Host "  [OK] Taskbar pins cleared." -ForegroundColor Gray
    } catch {
        Write-Warning "  [!] Could not fully clear pins."
    }

    # 2. THE CONFIG
    $Settings = @(
        @("HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "TaskbarAl", 0, "Alignment: Left"),
        @("HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "TaskbarDa", 0, "Widgets: Disabled"),
        @("HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "ShowTaskViewButton", 0, "Task View: Disabled"),
        @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Search", "SearchboxTaskbarMode", 0, "Search: Disabled")
    )

    foreach ($Row in $Settings) {
        $Path, $Name, $Value, $Label = $Row
        try {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -ErrorAction Stop
            Write-Host "  [OK] ${Label} set." -ForegroundColor Gray
        } 
        catch [System.Management.Automation.ItemNotFoundException] {
            Write-Warning "  [SKIP] ${Label} - Registry path does not exist."
        }
        catch [System.Security.SecurityException] {
            Write-Warning "  [FAIL] ${Label} - Security/Permission exception."
        }
        catch {
            Write-Warning "  [FAIL] ${Label} - Unhandled exception."
            if ($Name -eq "TaskbarDa") {
                Get-Process *Widget* | Stop-Process
                Get-AppxPackage Microsoft.WidgetsPlatformRuntime -AllUsers | Remove-AppxPackage -AllUsers
                Get-AppxPackage MicrosoftWindows.Client.WebExperience -AllUsers | Remove-AppxPackage -AllUsers
            }
        }
    }

    # 3. THE REFRESH
    Write-Host "`nRestarting Explorer..." -ForegroundColor Yellow
    Stop-Process -Name explorer -Force
}

# --- Source: src\functions\Set-UAC.ps1 ---
function Set-UAC {
    $UACPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    
    # 0 = Never Notify
    # 1 = Prompt on Secure Desktop (the dimming effect)
    Set-ItemProperty -Path $UACPath -Name "ConsentPromptBehaviorAdmin" -Value 5
    Set-ItemProperty -Path $UACPath -Name "PromptOnSecureDesktop" -Value 0
    
    Write-Host "UAC configured." -ForegroundColor Green
}

# --- Source: src\functions\TestFunction.ps1 ---
function TestFunction {
	Write-Host "Hello, World!"
	Start-Sleep -Seconds 10
	Write-Host "Sleepy!"
}

# --- Source: src\functions\Uninstall-Bloat.ps1 ---
function Uninstall-Bloat {
    Show-FunctionBanner "Uninstall Bloat"
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
        "Clipchamp.Clipchamp", "Microsoft.XboxGameCallableUI", "Microsoft.MicrosoftJournal", "Microsoft.OutlookForWindows"
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

# --- Source: src\functions\Uninstall-OfficeLanguagePacks.ps1 ---
function Uninstall-OfficeLanguagePacks {
    Show-FunctionBanner "Language Pack Killer"
    Write-Host "Scanning for extra Office Language Packs..." -ForegroundColor Cyan

    # 1. Get all Office ClickToRun entries, excluding English
    $OfficePacks = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue | Where-Object {
        $_.UninstallString -like "*OfficeClickToRun.exe*" -and 
        $_.DisplayName -notlike "*Microsoft 365 Apps for enterprise - en-us*" -and 
        $_.DisplayName -notlike "*Microsoft OneNote - en-us*" -and 
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

    # --- SANDBOX SETUP ---
    $WorkDir = "$env:TEMP\officedeployment"
    if (-not (Test-Path $WorkDir)) { New-Item -Path $WorkDir -ItemType Directory -Force | Out-Null }
    
    $ODTPath = "$WorkDir\setup.exe"
    $XmlPath = "$WorkDir\RemoveLangs.xml"

    # 3. Ensure ODT exists in our private folder
    if (-not (Test-Path $ODTPath)) {
        Invoke-WebRequest -Uri "https://download.microsoft.com/download/2/7/A/27AF1BE6-DD20-4CB4-B154-EBAB8A7D4A7E/officedeploymenttool_17126-20132.exe" -OutFile "$WorkDir\odt.exe"
        Start-Process -FilePath "$WorkDir\odt.exe" -ArgumentList "/extract:`"$WorkDir`" /quiet" -Wait
    }

    # 4. Build XML
    $LangNodes = ($LangsToRemove | ForEach-Object { "      <Language ID=""$_"" />" }) -join "`n"

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

    # 5. Run and Cleanup
    $Process = Start-Process -FilePath $ODTPath -ArgumentList "/configure `"$XmlPath`"" -Wait -PassThru -NoNewWindow

    # Null-check the process to prevent a fatal crash if it failed to launch
    if ($null -ne $Process -and $Process.ExitCode -eq 0) {
        Write-Host "Successfully removed extra language packs." -ForegroundColor Green
        # Wipe the whole subfolder clean
        Remove-Item -Path $WorkDir -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        $ExitCode = if ($null -ne $Process) { $Process.ExitCode } else { "Failed to Start" }
        Write-Host "Uninstall failed. Exit Code: $ExitCode" -ForegroundColor Red
    }
}

# --- Source: src\functions\Unlock-WinUpdates.ps1 ---
function Unlock-WinUpdates {
    Write-Host "Unlocking Windows Update Access..." -ForegroundColor Cyan

    # 1. Define paths and values
    $RegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    $UpdatePolicyKey = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\GPUpdateCache"
    
    $ValuesToSet = @{
        "DisableWindowsUpdateAccess" = 0
        "SetDisableUXWUAccess"       = 0
    }

    # 2. Delete the GPUpdateCache key if it exists
    try {
        if (Test-Path $UpdatePolicyKey) {
            Remove-Item -Path $UpdatePolicyKey -Recurse -Force -ErrorAction Stop
            Write-Host "  [OK] Deleted registry key: GPUpdateCache" -ForegroundColor Gray
        }
    } catch {
        Write-Warning "  [!] Could not delete $UpdatePolicyKey"
    }

    # 3. Set the Policy values
    # Ensure the parent key exists first
    if (-not (Test-Path $RegistryPath)) { 
        New-Item -Path $RegistryPath -Force | Out-Null 
    }

    foreach ($Key in $ValuesToSet.Keys) {
        try {
            Set-ItemProperty -Path $RegistryPath -Name $Key -Value $ValuesToSet[$Key] -Force -ErrorAction Stop
            Write-Host "  [OK] Set $Key to $($ValuesToSet[$Key])" -ForegroundColor Gray
        } catch {
            Write-Warning "  [FAIL] Failed to set $Key in $RegistryPath"
        }
    }

    # 4. Refresh Group Policy
    Write-Host "Applying policy changes (gpupdate)..." -ForegroundColor Yellow
    gpupdate /force
    
    Write-Host "`nWindows Update has been unlocked." -ForegroundColor Green
}

# --- Source: src\hd functions\HD_DISMFix.ps1 ---
function DISMFix {

    Write-Host "--- Starting System Repair Sequence (8 Steps) ---" -ForegroundColor Cyan
 
    # Step 0: Create System Restore Point
    Write-Host "Step 0: Creating System Restore Point..." -ForegroundColor Yellow
    Checkpoint-Computer -Description "BeforeDISMFixScript" -RestorePointType "MODIFY_SETTINGS"

    # Step 1: Initial SFC
    Write-Host "`nStep 1: Initial sfc /scannow" -ForegroundColor Yellow
    Start-Process "sfc.exe" -ArgumentList "/scannow" -Wait -NoNewWindow
 
    # Step 2: CheckHealth
    Write-Host "`nStep 2: DISM CheckHealth" -ForegroundColor Yellow
    Start-Process "DISM.exe" -ArgumentList "/Online /Cleanup-Image /CheckHealth" -Wait -NoNewWindow
 
    # Step 3: ScanHealth
    Write-Host "`nStep 3: DISM ScanHealth" -ForegroundColor Yellow
    Start-Process "DISM.exe" -ArgumentList "/Online /Cleanup-Image /ScanHealth" -Wait -NoNewWindow
 
    # Step 4: RestoreHealth
    Write-Host "`nStep 4: DISM RestoreHealth" -ForegroundColor Yellow
    Start-Process "DISM.exe" -ArgumentList "/Online /Cleanup-Image /RestoreHealth" -Wait -NoNewWindow
 
    # Step 5: Chkdsk (Read-only)
    Write-Host "`nStep 5: Chkdsk (Report Only)" -ForegroundColor Yellow
    Start-Process "chkdsk.exe" -Wait -NoNewWindow
 
    # Step 6: Chkdsk /r /f
    Write-Host "`nStep 6: Chkdsk /r /f (Scheduling Reboot Repair)" -ForegroundColor Yellow
    cmd /c "echo y | chkdsk /f /r"
 
    # Step 7: Final SFC
    Write-Host "`nStep 7: Final sfc /scannow" -ForegroundColor Yellow
    Start-Process "sfc.exe" -ArgumentList "/scannow" -Wait -NoNewWindow
 
    Write-Host "`n--- All Steps Complete ---" -ForegroundColor Green

}

# --- Source: src\gui functions\Get-UserInput.ps1 ---
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

# --- Source: src\gui functions\GUI-Startup.ps1 ---
function GUI-Startup {
    $NASIP = "10.24.2.5"
    $NASPath = "\\$NASIP\Clients"
    Sync-ClientLabel
    
    Write-Host "Checking NAS connectivity..." -ForegroundColor Cyan

    # Step 1: Ping the IP. -Count 1 -Quiet returns True/False instantly.
    if (Test-Connection -ComputerName $NASIP -Count 1 -Quiet) {
        
        # Step 2: Ping succeeded, now check the specific folder path
        if (Test-Path -Path "FileSystem::$NASPath" -PathType Container -ErrorAction SilentlyContinue) {
            $global:NAS_Clients_Folder = $NASPath
            $Ellipse_NASLoginStatusLight.Fill = [System.Windows.Media.Brushes]::LimeGreen
            
            $ListBox_Clients.Items.Clear()
            $Folders = Get-ChildItem -Path $NASPath -Directory -ErrorAction SilentlyContinue | Sort-Object Name
            foreach ($Folder in $Folders) { 
                [void]$ListBox_Clients.Items.Add($Folder.Name) 
            }
            Write-Host "NAS Connected and Clients Loaded." -ForegroundColor Green
        }
        else {
            # IP is up, but the share or folder is missing/perm denied
            $Ellipse_NASLoginStatusLight.Fill = [System.Windows.Media.Brushes]::Red
            Write-Host "NAS IP reachable, but Path not found!" -ForegroundColor Yellow
        }
    }
    else {
        # Step 3: Ping failed - This is the "Fail Fast" exit
        $Ellipse_NASLoginStatusLight.Fill = [System.Windows.Media.Brushes]::Red
        Write-Host "NAS Not Connected! (Ping Failed)" -ForegroundColor Red
    }
}

# --- Source: src\gui functions\Show-FunctionBanner.ps1 ---
function Show-FunctionBanner {
    param(
        [string]$Text
    )
    $len = $Text.Length + 8
    $line = "-" * $len
    Write-Host ""
    Write-Host $line -ForegroundColor Cyan
    Write-Host "--- $Text ---" -ForegroundColor Green
    Write-Host $line -ForegroundColor Cyan
}

# --- Source: src\gui functions\Start-PowerShellLogging.ps1 ---
function Start-PowerShellLogging {
    <#
    .SYNOPSIS
        Starts a transcript in the %TEMP% directory for the current session only.
        Automatically cleans up if a transcript is already running.
    #>
    
    # 1. Target the %TEMP% directory
    $LogFile = Join-Path -Path $env:TEMP -ChildPath "Deployment_Output.txt"

    # 2. Stop any existing transcript to prevent errors
    try { Stop-Transcript | Out-Null } catch { }

    # 3. Start the log for THIS window only
    Start-Transcript -Path $LogFile -Append -Confirm:$false

    Write-Host "--- Deployment logging active: $LogFile ---" -ForegroundColor Yellow
}

# To stop it manually before the window closes:
function Stop-DeploymentLogging {
    try {
        Stop-Transcript
        Write-Host "--- Deployment logging stopped ---" -ForegroundColor Yellow
    } catch {
        Write-Warning "No active transcript found to stop."
    }
}

# --- Source: src\gui functions\Startup-Logo.ps1 ---
function Startup-Logo{
$MagnaLogo = @"                                                                                                    

888b     d888                                     888888888  
8888b   d8888                                     888        
88888b.d88888                                     888        
888Y88888P888  8888b.   .d88b.  88888b.   8888b.  8888888b.  
888 Y888P 888     "88b d88P"88b 888 "88b     "88b      "Y88b 
888  Y8P  888 .d888888 888  888 888  888 .d888888        888 
888   "   888 888  888 Y88b 888 888  888 888  888 Y88b  d88P 
888       888 "Y888888  "Y88888 888  888 "Y888888  "Y8888P"  
                            888                              
                       Y8b d88P                              
                        "Y88P"                               
                                                    
"@

Write-Host $MagnaLogo -ForegroundColor Green
}

# --- Source: src\gui functions\Sync-ClientLabel.ps1 ---
function Sync-ClientLabel {
    if ($global:SelectedClient -and $global:SelectedClient -ne "None") {
        
        # 1. Strip the path to show only the final folder name (the 'Leaf')
        $DisplayName = Split-Path -Path $global:SelectedClient -Leaf
        
        # 2. Update the TextBlock with the shortened name
        $TxtBlock_SelectedClient.Text = $DisplayName
        
        # 3. Update the color to LimeGreen
        $TxtBlock_SelectedClient.Foreground = [System.Windows.Media.Brushes]::LimeGreen
    }
}

# --- Source: src\gui functions\Update-Status.ps1 ---
function Update-Status {
    param(
        [ValidateSet("Busy", "Ready")]
        [string]$State
    )

    # Change the color of the StatusLight Ellipse
    if ($State -eq "Busy") {
        # Use Red for Busy
        $Ellipse_StatusLight.Fill = [System.Windows.Media.Brushes]::Red
    } else {
        # Use LimeGreen for Ready
        $Ellipse_StatusLight.Fill = [System.Windows.Media.Brushes]::LimeGreen
    }

    # Keeps the UI responsive during the color change
    [System.Windows.Forms.Application]::DoEvents()
}

# --- Source: src\personal functions\Check-Hardware.ps1 ---
function Check-Hardware {

    # --- Install Apps ---
    Write-Host "`n=== Installing Diagnostic Tools ===" -ForegroundColor Yellow

    $apps = @(
        "CPUID.CPU-Z",
        "CPUID.HWMonitor",
        "CrystalDewWorld.CrystalDiskInfo",
        "CrystalDewWorld.CrystalDiskMark"
    )

    foreach ($AppID in $apps) {
        Write-Host "Installing package: $AppID..." -ForegroundColor Green
        $result = Start-Process winget -ArgumentList "install --id $AppID --silent --accept-source-agreements --accept-package-agreements --source winget" -Wait -PassThru -NoNewWindow

        switch ($result.ExitCode) {
            0            { Write-Host "Successfully installed $AppID" -ForegroundColor Green }
            -1978335189  { Write-Host "$AppID is already up to date" -ForegroundColor Cyan }
            default      { Write-Warning "Failed to install $AppID (Exit code: $($result.ExitCode))" }
        }

        Start-Sleep -Seconds 1
    }

    # --- Battery Report ---
    Write-Host "`n=== Generating Battery Report ===" -ForegroundColor Yellow
    powercfg /batteryreport /output C:\battery-report.html
    Start-Sleep -Seconds 2
    Start-Process "C:\battery-report.html"

    # --- Open Web Tools ---
    Write-Host "`n=== Opening Web Diagnostic Tools ===" -ForegroundColor Yellow
    Start-Process "https://deadpixelbuddy.com/"
    Start-Process "https://danwlker.github.io/KeyboardTestingPage/"
    Start-Process "https://www.speedtest.net/"

    # --- WinSAT ---
    Write-Host "`n=== Running WinSAT Formal (this may take a few minutes) ===" -ForegroundColor Yellow
    & winsat formal
    Start-Sleep -Seconds 3
    Write-Host "`nWinSAT Results:" -ForegroundColor Cyan
    Get-CimInstance Win32_WinSAT | Format-List *

    Write-Host "`n=== Check-Hardware Complete ===" -ForegroundColor Green
}


# --- Source: src\personal functions\Set-ScriptingEnvironment.ps1 ---
function Set-ScriptingEnvironment {
    Write-Host "Configuring User Environment..." -ForegroundColor Cyan

    # 1. Execution Policy Bypass (CurrentUser Scope)
    Write-Host "  [>] Setting User Execution Policy to Bypass..." -ForegroundColor Gray
    Set-ExecutionPolicy Bypass -Scope CurrentUser -Force

    # 2. Show File Extensions (Registry edit)
    Write-Host "  [>] Enabling File Extensions in Explorer..." -ForegroundColor Gray
    $RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $RegPath -Name "HideFileExt" -Value 0

    # 3. Open Admin CMD and CD to User Profile
    Write-Host "  [>] Launching Administrative CMD..." -ForegroundColor Yellow
    $UserDir = $env:USERPROFILE
    # /k keeps window open, /d handles drive changes
    $Args = "/k cd /d `"$UserDir`""
    
    Start-Process "cmd.exe" -ArgumentList $Args -Verb RunAs
    
    Write-Host "[OK] Tasks complete for $env:USERNAME." -ForegroundColor Green
}


# --- UI ELEMENT MAPPING ---
([xml]$mainXML).SelectNodes("//*[@*[local-name()='Name']]") | ForEach-Object {
    $name = $_.GetAttribute("Name", "http://schemas.microsoft.com/winfx/2006/xaml")
    if (-not $name) { $name = $_.Name }
    Set-Variable -Name $name -Value $Main.FindName($name) -Scope Script
}

# --- SHARED RUNSPACE POOL ---
$sessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$sessionState.Variables.Add((New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry 'sync', $sync, $null))
$sessionState.Variables.Add((New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry 'PSModuleAutoLoadingPreference', 'All', $null))

Get-ChildItem function: | Where-Object { $_.Name -notlike '*:' } | ForEach-Object {
    try {
        $sessionState.Commands.Add((New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry($_.Name, $_.Definition)))
    } catch {}
}

$sync.RunspacePool = [runspacefactory]::CreateRunspacePool(1, [int]$env:NUMBER_OF_PROCESSORS, $sessionState, $Host)
$sync.RunspacePool.Open()

function Invoke-BusyAction {
    param([scriptblock]$Action)
    Update-Status -State "Busy"
    & $Action
    Update-Status -State "Ready"
}

function Invoke-BusyActionAsync {
    param(
        [string]$Name,
        [scriptblock]$Action
    )

    if ($sync.Running.ContainsKey($Name)) {
        Write-Host "`nWait! '$Name' is already running." -ForegroundColor Yellow
        return
    }
    $sync.Running[$Name] = $true

    $ps = [powershell]::Create()
    $ps.RunspacePool = $sync.RunspacePool
    $ps.AddScript({
        param($Action, $Name, $SelectedClient)
        $global:SelectedClient = $SelectedClient
        $sync.Main.Dispatcher.Invoke([action]{ Update-Status -State "Busy" })
        try {
            & ([scriptblock]::Create($Action.ToString()))
        } finally {
            $sync.Running.Remove($Name)
            if ($sync.Running.Count -eq 0) {
                $sync.Main.Dispatcher.Invoke([action]{ Update-Status -State "Ready" })
            }
        }
    }).AddParameter("Action", $Action).AddParameter("Name", $Name).AddParameter("SelectedClient", $global:SelectedClient) | Out-Null

    $ps.BeginInvoke() | Out-Null
}

# --- ACTIONS COLUMN CLICK EVENTS ---
$Btn_RunAll.Add_Click({ Invoke-BusyActionAsync -Name "RunAll" -Action {
    Set-CustomPowerOptions; Copy-Shortcuts; Repair-Winget; Install-ClientCustomLocalApps
    Install-DefaultWingetApps; Install-ClientCustomWingetApps; Uninstall-Bloat
    Uninstall-OfficeLanguagePacks; Install-O365; Set-ComputerTimeZone
}})

$Btn_RepairWinget.Add_Click({ Invoke-BusyActionAsync -Name "RepairWinget" -Action { Repair-Winget } })
$Btn_InstallO365.Add_Click({ Invoke-BusyActionAsync -Name "InstallO365" -Action { Install-O365 } })
$Btn_InstallLocalApps.Add_Click({ Invoke-BusyActionAsync -Name "InstallLocalApps" -Action { Install-ClientCustomLocalApps } })
$Btn_InstallDefaultWinget.Add_Click({ Invoke-BusyActionAsync -Name "InstallDefaultWinget" -Action { Install-DefaultWingetApps } })
$Btn_InstallCustomWinget.Add_Click({ Invoke-BusyActionAsync -Name "InstallCustomWinget" -Action { Install-ClientCustomWingetApps } })
$Btn_UninstallBloat.Add_Click({ Invoke-BusyActionAsync -Name "UninstallBloat" -Action { Uninstall-Bloat } })
$Btn_UninstallLanguagePacks.Add_Click({ Invoke-BusyActionAsync -Name "UninstallLanguagePacks" -Action { Uninstall-OfficeLanguagePacks } })
$Btn_SetPowerOptions.Add_Click({ Invoke-BusyActionAsync -Name "SetPowerOptions" -Action { Set-CustomPowerOptions } })
$Btn_SetTimezone.Add_Click({ Invoke-BusyActionAsync -Name "SetTimezone" -Action { Set-ComputerTimeZone } })
$Btn_CopyShortcuts.Add_Click({ Invoke-BusyActionAsync -Name "CopyShortcuts" -Action { Copy-Shortcuts } })
$Btn_Login.Add_Click({ Invoke-BusyAction { Connect-NAS } })

# --- CLIENT SELECT COLUMN CLICK EVENTS ---
$Btn_ReloadClients.Add_Click({ Invoke-BusyAction { Refresh-Clients } })
$Btn_ManualSelection.Add_Click({ Invoke-BusyAction { Select-ManualFolder } })
$ListBox_Clients.Add_MouseDoubleClick({ Set-SelectedClient })

# --- MISC COLUMN ---
$Btn_ConfigUAC.Add_Click({ Invoke-BusyActionAsync -Name "ConfigUAC" -Action { Set-UAC } })
$Btn_ConfigTaskbar.Add_Click({ Invoke-BusyActionAsync -Name "ConfigTaskbar" -Action { Set-Taskbar } })
$Btn_UnlockWinUpdate.Add_Click({ Invoke-BusyActionAsync -Name "UnlockWinUpdate" -Action { Unlock-WinUpdates } })
$Btn_OfficeInstallBypass.Add_Click({ Invoke-BusyActionAsync -Name "OfficeInstallBypass" -Action { Install-O365Bypass } })
$Btn_RepairTakeControl.Add_Click({ Invoke-BusyActionAsync -Name "RepairTakeControl" -Action { Repair-TakeControl } })

# --- APPS COLUMN (DRIVERS) CLICK EVENTS ---
$Btn_InstallNVIDIAApp.Add_Click({ Invoke-BusyActionAsync -Name "InstallNVIDIA" -Action { Install-PassedWingetApp "TechPowerUp.NVCleanstall" } })
$Btn_InstallAMDApp.Add_Click({ Invoke-BusyActionAsync -Name "InstallAMD" -Action { Start-Process "https://www.amd.com/en/support/download/drivers.html" } })
$Btn_InstallDellApp.Add_Click({ Invoke-BusyActionAsync -Name "InstallDell" -Action { Install-PassedWingetApp "Dell.CommandUpdate" } })
$Btn_InstallLenovoApp.Add_Click({ Invoke-BusyActionAsync -Name "InstallLenovo" -Action { Install-PassedWingetApp "9NR5B8GVVM13" } })
$Btn_InstallHPApp.Add_Click({ Invoke-BusyActionAsync -Name "InstallHP" -Action { Start-Process "https://support.hp.com/us-en/help/hp-support-assistant" } })
$Btn_InstallSnapdragonApp.Add_Click({ Invoke-BusyActionAsync -Name "InstallSnapdragon" -Action { Start-Process "https://softwarecenter.qualcomm.com/api/download/software/tools/SnapdragonControlPanel/Windows/ARM64/2025.3.0.0/Snapdragon_Control_Panel_2025.3.0.0.zip" } })
$Btn_InstallForticlientApp.Add_Click({ Invoke-BusyActionAsync -Name "InstallForticlient" -Action { Start-Process "https://links.fortinet.com/forticlient/win/vpnagent" } })
$Btn_InstallFrameworkDrivers.Add_Click({ Invoke-BusyActionAsync -Name "InstallFrameworkDrivers" -Action { Start-Process "https://knowledgebase.frame.work/bios-and-drivers-downloads-rJ3PaCexh" } })


# --- TAB SWITCHING BUTTON CLICK EVENTS ---
$Btn_Tools.Add_Click({
    $Deployment_Grid.Visibility = "Collapsed"
    $Tools_Grid.Visibility = "Visible"
    $FAQ_Grid.Visibility = "Collapsed"
})

$Btn_Deployment.Add_Click({
    $Deployment_Grid.Visibility = "Visible"
    $Tools_Grid.Visibility = "Collapsed"
    $FAQ_Grid.Visibility = "Collapsed"
})

$Btn_FAQ.Add_Click({
    $Deployment_Grid.Visibility = "Collapsed"
    $Tools_Grid.Visibility = "Collapsed"
    $FAQ_Grid.Visibility = "Visible"
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

$Slider_Ken.Add_ValueChanged({
    param($sender, $e)
    
    # Calculate opacity: 1 becomes 0.1 (10%), 10 becomes 1.0 (100%)
    # Using [Math]::Round to prevent floating point math weirdness
    $NewOpacity = [Math]::Round(($sender.Value / 10), 1)
    
    # Apply to the image
    $Img_Ken.Opacity = $NewOpacity
})

# --- HD Buttons --- #
$Btn_DISM.Add_Click({ Invoke-BusyActionAsync { DISMFix } })

# --- Personal Buttons --- #
$Btn_EnableScripting.Add_Click({ Invoke-BusyActionAsync { Set-ScriptingEnvironment } })
$Btn_CheckHardware.Add_Click({ Invoke-BusyActionAsync { Check-Hardware } })

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
$FAQ_Grid.Visibility = "Collapsed"
Start-PowerShellLogging
$Main.ShowDialog() | Out-Null
Write-Host "Goodbye!!!" -ForegroundColor Cyan
