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
# COMPILER_INSERT_HERE

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