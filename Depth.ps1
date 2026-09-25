####################################################################################################
# DEPTH - Mass Deployment Tool
# Main.ps1 is the SOURCE TEMPLATE. Compile.ps1 stitches the functions under src\functions into the
# insertion marker in the FUNCTIONS SECTION further down this file (search for INSERT HERE, split
# up here on purpose so this comment doesn't itself get matched by the compiler) to produce the
# distributable Depth.ps1 - never hand-edit Depth.ps1 directly, edit this file and rebuild.
#
# File layout:
#   1. Elevation check / relaunch as Administrator
#   2. XAML loader helper (Load-VisualStudioXaml)
#   3. Splash screen XAML
#   4. Main window XAML (this is the block you paste MainWindow.xaml into after editing it in
#      the DepthWPFFramework_Revamped WPF project - everything between $mainXML = @" and "@)
#   5. Splash screen display
#   6. Main window load + sync hashtable + background runspace pool (async action engine)
#   7. UI element auto-binding (every x:Name in the XAML becomes a $ScriptScope variable)
#   8. Busy-state helper functions (Invoke-BusyAction / Invoke-BusyActionAsync)
#   9. Action maps - checkbox name -> command text, used by the selection toolbar
#  10. Selection toolbar wiring (Select All / Winget Apps Only / Clear Selection / Run Selected)
#  11. Client select column wiring
#  12. Tab switching, title bar, and misc window chrome wiring
#  13. Startup sequence
####################################################################################################

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# ============================================================
# 1. ELEVATION CHECK
# Depth performs system-level changes, so it must run elevated. If it isn't, relaunch itself
# (via Windows Terminal if available, otherwise a plain elevated PowerShell) and bail out of
# this non-elevated instance.
# ============================================================
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

# ============================================================
# 2. XAML LOADER HELPER
# Visual Studio's XAML designer writes attributes (x:Class, mc:Ignorable="d", d:DesignWidth, etc.)
# that only mean something inside Visual Studio and that [Windows.Markup.XamlReader] chokes on at
# runtime. This strips them out so you can copy/paste straight out of the designer.
# ============================================================
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
        <Label x:Name="LblSplash" Content="Narwal LLC" Background="{x:Null}" Foreground="White" Margin="20,20,0,0" HorizontalAlignment="Left" VerticalAlignment="Top" FontSize="20" FontFamily="Segoe UI Light"/>
        <Label x:Name="LblProgramName" Content="Depth" Background="{x:Null}" Foreground="White" Margin="0,80,0,0" HorizontalAlignment="Center" VerticalAlignment="Top" FontSize="48" FontWeight="Bold"/>
        <Label x:Name="LblProgramPurpose" Content="Mass Deployment Tool" Background="{x:Null}" Foreground="White" HorizontalAlignment="Center" VerticalAlignment="Top" FontSize="30" FontFamily="Segoe UI Light" Margin="0,144,0,0"/>
        <Label x:Name="LblCopyrightOne" Content="Copyright (c) 2025-2026 Brandon Swarek" Background="{x:Null}" Foreground="Black" HorizontalAlignment="Right" VerticalAlignment="Bottom" FontSize="13" FontFamily="Segoe UI Light" Margin="0,0,30,26"/>
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

# ============================================================
# 4. MAIN XAML
# This is a straight copy of DepthWPFFramework_Revamped\MainWindow.xaml. Action buttons were
# replaced with card-style CheckBoxes (x:Name="Chk_*") so the user can select several actions and
# fire them together, instead of one button = one immediate action. See section 9/10 below for how
# those checkboxes get executed.
# ============================================================
$mainXML = @"
<Window x:Name="Main_Window" x:Class="DepthWPFFramework_Revamped.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        xmlns:local="clr-namespace:DepthWPFFramework_Revamped"
        mc:Ignorable="d"
        Title="Depth" Height="740" Width="1160" SizeToContent="WidthAndHeight" WindowStartupLocation="CenterScreen" ResizeMode="CanResizeWithGrip" WindowStyle="None" AllowsTransparency="True" Background="Transparent" MinWidth="1160" MinHeight="740">
	<Window.Resources>

		<!-- ===================== PALETTE ===================== -->
		<SolidColorBrush x:Key="AccentBrush" Color="#FF3D6EE6"/>
		<SolidColorBrush x:Key="AccentBrush2" Color="#FF29B6F6"/>
		<SolidColorBrush x:Key="SuccessBrush" Color="#FF2FBF71"/>
		<SolidColorBrush x:Key="WarningBrush" Color="#FFE4B307"/>
		<SolidColorBrush x:Key="DangerBrush" Color="#FFE0483A"/>
		<SolidColorBrush x:Key="WindowSurfaceBrush" Color="#FF23292D"/>
		<SolidColorBrush x:Key="WindowBorderBrush" Color="#FF39434A"/>
		<SolidColorBrush x:Key="PanelBrush" Color="#FF262D31"/>
		<SolidColorBrush x:Key="PanelBorderBrush" Color="#FF39434A"/>
		<SolidColorBrush x:Key="InputBrush" Color="#FF1E2427"/>
		<SolidColorBrush x:Key="TextPrimaryBrush" Color="#FFF3F5F6"/>
		<SolidColorBrush x:Key="TextMutedBrush" Color="#FF8D979C"/>

		<!-- ===================== SHARED CARD BORDER ===================== -->
		<Style x:Key="PanelCard" TargetType="Border">
			<Setter Property="Background" Value="{StaticResource PanelBrush}"/>
			<Setter Property="BorderBrush" Value="{StaticResource PanelBorderBrush}"/>
			<Setter Property="BorderThickness" Value="1"/>
			<Setter Property="CornerRadius" Value="10"/>
			<Setter Property="Effect">
				<Setter.Value>
					<DropShadowEffect BlurRadius="16" ShadowDepth="2" Opacity="0.35" Color="Black" Direction="270"/>
				</Setter.Value>
			</Setter>
		</Style>

		<!-- ===================== SECTION HEADER TEXT ===================== -->
		<Style x:Key="SectionHeaderText" TargetType="TextBlock">
			<Setter Property="Foreground" Value="{StaticResource TextPrimaryBrush}"/>
			<Setter Property="FontFamily" Value="Segoe UI Semibold"/>
			<Setter Property="FontSize" Value="17"/>
		</Style>

		<!-- ===================== STANDARD BUTTON ===================== -->
		<Style x:Key="AppButton" TargetType="Button">
			<Setter Property="Foreground" Value="White"/>
			<Setter Property="FontFamily" Value="Segoe UI Semibold"/>
			<Setter Property="FontSize" Value="13"/>
			<Setter Property="Cursor" Value="Hand"/>
			<Setter Property="BorderThickness" Value="0"/>
			<Setter Property="Height" Value="32"/>
			<Setter Property="Template">
				<Setter.Value>
					<ControlTemplate TargetType="Button">
						<Border x:Name="border" Background="{TemplateBinding Background}" CornerRadius="7" SnapsToDevicePixels="True">
							<Grid>
								<Border x:Name="overlay" CornerRadius="7" Background="White" Opacity="0"/>
								<ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
							</Grid>
						</Border>
						<ControlTemplate.Triggers>
							<Trigger Property="IsMouseOver" Value="True">
								<Setter TargetName="overlay" Property="Opacity" Value="0.12"/>
							</Trigger>
							<Trigger Property="IsPressed" Value="True">
								<Setter TargetName="overlay" Property="Opacity" Value="0.24"/>
							</Trigger>
							<Trigger Property="IsEnabled" Value="False">
								<Setter TargetName="border" Property="Opacity" Value="0.45"/>
							</Trigger>
						</ControlTemplate.Triggers>
					</ControlTemplate>
				</Setter.Value>
			</Setter>
		</Style>

		<!-- ===================== NAV TAB BUTTON ===================== -->
		<Style x:Key="NavTabButton" TargetType="Button" BasedOn="{StaticResource AppButton}">
			<Setter Property="Background" Value="#FF31373A"/>
			<Setter Property="Foreground" Value="#FFD3D8DB"/>
			<Setter Property="FontSize" Value="13"/>
			<Setter Property="Padding" Value="18,0"/>
			<Setter Property="Height" Value="34"/>
		</Style>

		<!-- ===================== RUN BUTTON (PROMINENT) ===================== -->
		<Style x:Key="RunButton" TargetType="Button" BasedOn="{StaticResource AppButton}">
			<Setter Property="Background" Value="{StaticResource SuccessBrush}"/>
			<Setter Property="FontSize" Value="14"/>
			<Setter Property="Padding" Value="20,0"/>
			<Setter Property="Height" Value="34"/>
		</Style>

		<!-- ===================== OUTLINE TOOLBAR BUTTON (Select All / Clear / Winget Only) ===================== -->
		<Style x:Key="ToolbarButton" TargetType="Button">
			<Setter Property="Foreground" Value="{StaticResource AccentBrush2}"/>
			<Setter Property="Background" Value="Transparent"/>
			<Setter Property="FontFamily" Value="Segoe UI Semibold"/>
			<Setter Property="FontSize" Value="12"/>
			<Setter Property="Cursor" Value="Hand"/>
			<Setter Property="Height" Value="34"/>
			<Setter Property="Padding" Value="14,0"/>
			<Setter Property="Template">
				<Setter.Value>
					<ControlTemplate TargetType="Button">
						<Border x:Name="border" Background="{TemplateBinding Background}" BorderBrush="{StaticResource AccentBrush2}" BorderThickness="1" CornerRadius="17">
							<ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
						</Border>
						<ControlTemplate.Triggers>
							<Trigger Property="IsMouseOver" Value="True">
								<Setter TargetName="border" Property="Background" Value="#2229B6F6"/>
							</Trigger>
							<Trigger Property="IsPressed" Value="True">
								<Setter TargetName="border" Property="Background" Value="#3829B6F6"/>
							</Trigger>
						</ControlTemplate.Triggers>
					</ControlTemplate>
				</Setter.Value>
			</Setter>
		</Style>

		<!-- ===================== TITLE-BAR ICON BUTTON (Minimize) ===================== -->
		<Style x:Key="IconButton" TargetType="Button">
			<Setter Property="Foreground" Value="#FFC7CDD1"/>
			<Setter Property="Background" Value="Transparent"/>
			<Setter Property="FontFamily" Value="Segoe UI"/>
			<Setter Property="FontSize" Value="15"/>
			<Setter Property="Cursor" Value="Hand"/>
			<Setter Property="Width" Value="32"/>
			<Setter Property="Height" Value="32"/>
			<Setter Property="Template">
				<Setter.Value>
					<ControlTemplate TargetType="Button">
						<Border x:Name="border" Background="{TemplateBinding Background}" CornerRadius="16">
							<ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
						</Border>
						<ControlTemplate.Triggers>
							<Trigger Property="IsMouseOver" Value="True">
								<Setter TargetName="border" Property="Background" Value="#22FFFFFF"/>
							</Trigger>
							<Trigger Property="IsPressed" Value="True">
								<Setter TargetName="border" Property="Background" Value="#33FFFFFF"/>
							</Trigger>
						</ControlTemplate.Triggers>
					</ControlTemplate>
				</Setter.Value>
			</Setter>
		</Style>

		<!-- ===================== TITLE-BAR CLOSE BUTTON (red hover) ===================== -->
		<Style x:Key="CloseIconButton" TargetType="Button" BasedOn="{StaticResource IconButton}">
			<Setter Property="Template">
				<Setter.Value>
					<ControlTemplate TargetType="Button">
						<Border x:Name="border" Background="{TemplateBinding Background}" CornerRadius="16">
							<ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
						</Border>
						<ControlTemplate.Triggers>
							<Trigger Property="IsMouseOver" Value="True">
								<Setter TargetName="border" Property="Background" Value="{StaticResource DangerBrush}"/>
							</Trigger>
							<Trigger Property="IsPressed" Value="True">
								<Setter TargetName="border" Property="Background" Value="#FFB23A2E"/>
							</Trigger>
						</ControlTemplate.Triggers>
					</ControlTemplate>
				</Setter.Value>
			</Setter>
		</Style>

		<!-- ===================== ACTION CHECKBOX (card / chip style) =====================
		     Set the Tag property on each CheckBox to the accent brush for that group. -->
		<Style x:Key="ActionCheckBox" TargetType="CheckBox">
			<Setter Property="Foreground" Value="{StaticResource TextPrimaryBrush}"/>
			<Setter Property="FontFamily" Value="Segoe UI"/>
			<Setter Property="FontSize" Value="13"/>
			<Setter Property="Cursor" Value="Hand"/>
			<Setter Property="Height" Value="34"/>
			<Setter Property="Margin" Value="0,6,0,0"/>
			<Setter Property="Tag" Value="{StaticResource AccentBrush}"/>
			<Setter Property="Template">
				<Setter.Value>
					<ControlTemplate TargetType="CheckBox">
						<Border x:Name="border" Background="#FF2C3438" BorderBrush="#FF3C474D" BorderThickness="1" CornerRadius="7">
							<Grid Margin="10,0,10,0">
								<Grid.ColumnDefinitions>
									<ColumnDefinition Width="16"/>
									<ColumnDefinition Width="*"/>
								</Grid.ColumnDefinitions>
								<Border x:Name="checkBox" Grid.Column="0" Width="15" Height="15" CornerRadius="4" BorderBrush="#FF6E777C" BorderThickness="1.4" Background="Transparent" HorizontalAlignment="Left"/>
								<ContentPresenter Grid.Column="1" VerticalAlignment="Center" Margin="9,0,0,0"/>
							</Grid>
						</Border>
						<ControlTemplate.Triggers>
							<Trigger Property="IsMouseOver" Value="True">
								<Setter TargetName="border" Property="BorderBrush" Value="{Binding RelativeSource={RelativeSource TemplatedParent}, Path=Tag}"/>
							</Trigger>
							<Trigger Property="IsChecked" Value="True">
								<Setter TargetName="border" Property="Background" Value="{Binding RelativeSource={RelativeSource TemplatedParent}, Path=Tag}"/>
								<Setter TargetName="border" Property="BorderBrush" Value="{Binding RelativeSource={RelativeSource TemplatedParent}, Path=Tag}"/>
								<Setter TargetName="checkBox" Property="Background" Value="White"/>
								<Setter TargetName="checkBox" Property="BorderBrush" Value="White"/>
							</Trigger>
						</ControlTemplate.Triggers>
					</ControlTemplate>
				</Setter.Value>
			</Setter>
		</Style>

		<!-- ===================== TEXT INPUT ===================== -->
		<Style x:Key="InputBox" TargetType="TextBox">
			<Setter Property="Background" Value="{StaticResource InputBrush}"/>
			<Setter Property="Foreground" Value="White"/>
			<Setter Property="CaretBrush" Value="White"/>
			<Setter Property="BorderBrush" Value="#FF3C474D"/>
			<Setter Property="BorderThickness" Value="1"/>
			<Setter Property="Padding" Value="8,4"/>
			<Setter Property="FontFamily" Value="Segoe UI"/>
			<Setter Property="FontSize" Value="13"/>
			<Setter Property="Template">
				<Setter.Value>
					<ControlTemplate TargetType="TextBox">
						<Border x:Name="border" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6">
							<ScrollViewer x:Name="PART_ContentHost" Margin="{TemplateBinding Padding}" VerticalAlignment="Center"/>
						</Border>
						<ControlTemplate.Triggers>
							<Trigger Property="IsFocused" Value="True">
								<Setter TargetName="border" Property="BorderBrush" Value="{StaticResource AccentBrush2}"/>
							</Trigger>
						</ControlTemplate.Triggers>
					</ControlTemplate>
				</Setter.Value>
			</Setter>
		</Style>

		<!-- ===================== PASSWORD INPUT ===================== -->
		<Style x:Key="InputPasswordBox" TargetType="PasswordBox">
			<Setter Property="Background" Value="{StaticResource InputBrush}"/>
			<Setter Property="Foreground" Value="White"/>
			<Setter Property="CaretBrush" Value="White"/>
			<Setter Property="BorderBrush" Value="#FF3C474D"/>
			<Setter Property="BorderThickness" Value="1"/>
			<Setter Property="Padding" Value="8,4"/>
			<Setter Property="FontFamily" Value="Segoe UI"/>
			<Setter Property="FontSize" Value="13"/>
			<Setter Property="Template">
				<Setter.Value>
					<ControlTemplate TargetType="PasswordBox">
						<Border x:Name="border" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6">
							<ScrollViewer x:Name="PART_ContentHost" Margin="{TemplateBinding Padding}" VerticalAlignment="Center"/>
						</Border>
						<ControlTemplate.Triggers>
							<Trigger Property="IsFocused" Value="True">
								<Setter TargetName="border" Property="BorderBrush" Value="{StaticResource AccentBrush2}"/>
							</Trigger>
						</ControlTemplate.Triggers>
					</ControlTemplate>
				</Setter.Value>
			</Setter>
		</Style>

		<!-- ===================== CLIENT LIST BOX ===================== -->
		<Style x:Key="InputListBox" TargetType="ListBox">
			<Setter Property="Background" Value="{StaticResource InputBrush}"/>
			<Setter Property="BorderBrush" Value="#FF3C474D"/>
			<Setter Property="BorderThickness" Value="1"/>
			<Setter Property="Foreground" Value="White"/>
			<Setter Property="FontFamily" Value="Segoe UI"/>
			<Setter Property="FontSize" Value="13"/>
			<Setter Property="Template">
				<Setter.Value>
					<ControlTemplate TargetType="ListBox">
						<Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="6">
							<ScrollViewer Padding="4" VerticalScrollBarVisibility="Auto">
								<ItemsPresenter/>
							</ScrollViewer>
						</Border>
					</ControlTemplate>
				</Setter.Value>
			</Setter>
			<Setter Property="ItemContainerStyle">
				<Setter.Value>
					<Style TargetType="ListBoxItem">
						<Setter Property="Padding" Value="6,5"/>
						<Setter Property="Foreground" Value="White"/>
						<Setter Property="Template">
							<Setter.Value>
								<ControlTemplate TargetType="ListBoxItem">
									<Border x:Name="itemBorder" Background="Transparent" CornerRadius="4" Padding="{TemplateBinding Padding}" Margin="0,1,0,1">
										<ContentPresenter/>
									</Border>
									<ControlTemplate.Triggers>
										<Trigger Property="IsMouseOver" Value="True">
											<Setter TargetName="itemBorder" Property="Background" Value="#FF333C40"/>
										</Trigger>
										<Trigger Property="IsSelected" Value="True">
											<Setter TargetName="itemBorder" Property="Background" Value="{StaticResource AccentBrush}"/>
										</Trigger>
									</ControlTemplate.Triggers>
								</ControlTemplate>
							</Setter.Value>
						</Setter>
					</Style>
				</Setter.Value>
			</Setter>
		</Style>

	</Window.Resources>

	<Grid x:Name="Main_Grid" Background="Transparent">
		<Border x:Name="Main_Border" CornerRadius="16" Background="{StaticResource WindowSurfaceBrush}" BorderBrush="{StaticResource WindowBorderBrush}" BorderThickness="1.5">
			<Border.Effect>
				<DropShadowEffect BlurRadius="35" ShadowDepth="8" Opacity="0.45" Color="Black" Direction="270"/>
			</Border.Effect>
		</Border>

		<!-- ===================== TITLE BAR ===================== -->
		<Grid x:Name="Title_Grid" VerticalAlignment="Top" Height="88">
			<StackPanel Orientation="Horizontal" VerticalAlignment="Center" HorizontalAlignment="Left" Margin="26,0,0,0">
				<TextBlock Text="DEPTH" FontFamily="Segoe UI Semibold" FontSize="19" Foreground="{StaticResource AccentBrush}"/>
				<TextBlock Text="Mass Deployment Tool" FontFamily="Segoe UI" FontSize="11" Foreground="{StaticResource TextMutedBrush}" VerticalAlignment="Bottom" Margin="8,0,0,3"/>
			</StackPanel>

			<StackPanel x:Name="Tabs_StackPanel" HorizontalAlignment="Left" Margin="220,0,0,0" VerticalAlignment="Center" Orientation="Horizontal">
				<Button x:Name="Btn_Deployment" Content="Deployment" Style="{StaticResource NavTabButton}" Width="120" Margin="0,0,6,0"/>
				<Button x:Name="Btn_Tools" Content="Tools" Style="{StaticResource NavTabButton}" Width="90" Margin="0,0,6,0"/>
				<Button x:Name="Btn_FAQ" Content="FAQ" Style="{StaticResource NavTabButton}" Width="80" Margin="0,0,18,0"/>
				<Border Width="1" Height="24" Background="#FF3C474D" Margin="0,0,18,0"/>
				<Button x:Name="Btn_RestartPC" Content="Restart PC" Style="{StaticResource NavTabButton}" Width="104" Background="{StaticResource DangerBrush}" Foreground="White" Margin="0,0,10,0"/>
				<Slider x:Name="Slider_Ken" Width="90" VerticalAlignment="Center" Margin="6,0,0,0" SmallChange="1" Value="-1" TickPlacement="TopLeft" IsSnapToTickEnabled="True" ToolTip="Ken"/>
			</StackPanel>

			<StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,150,0">
				<Ellipse x:Name="Ellipse_StatusLight" Height="12" Width="12" Stroke="Black" StrokeThickness="0.6" Fill="#FF0FFF1E" VerticalAlignment="Center" ToolTip="System Status" HorizontalAlignment="Center" Margin="0,0,-100,0">
					<Ellipse.Effect>
						<BlurEffect Radius="4"/>
					</Ellipse.Effect>
				</Ellipse>
			</StackPanel>

			<StackPanel x:Name="GUIControl_StackPanel" Margin="0,0,14,0" Orientation="Horizontal" FlowDirection="RightToLeft" HorizontalAlignment="Right" VerticalAlignment="Center">
				<Button x:Name="Btn_Close" Content="&#xE711;" FontFamily="Segoe MDL2 Assets" FontSize="11" Style="{StaticResource CloseIconButton}"/>
				<Button x:Name="Btn_Minimize" Content="&#xE921;" FontFamily="Segoe MDL2 Assets" FontSize="11" Style="{StaticResource IconButton}" Margin="0,0,4,0"/>
			</StackPanel>
		</Grid>

		<!-- ===================== DEPLOYMENT TAB ===================== -->
		<Grid x:Name="Deployment_Grid" Margin="0,88,0,0">
			<Image x:Name="Img_Ken" Width="1140" Height="600" HorizontalAlignment="Center" VerticalAlignment="Top" Source="https://github.com/noteuphorix/Depth/blob/master/src/imgs/Ken2.png?raw=true" Stretch="Fill" Opacity="0"/>

			<!-- Selection toolbar -->
			<Grid Margin="24,14,24,0" Height="36" VerticalAlignment="Top">
				<Grid.ColumnDefinitions>
					<ColumnDefinition Width="*"/>
					<ColumnDefinition Width="Auto"/>
				</Grid.ColumnDefinitions>
				<StackPanel Orientation="Horizontal" HorizontalAlignment="Left">
					<Button x:Name="Btn_SelectAll" Content="Select All" Style="{StaticResource ToolbarButton}" Margin="0,0,8,0"/>
					<Button x:Name="Btn_SelectWingetOnly" Content="Winget Apps Only" Style="{StaticResource ToolbarButton}" Margin="0,0,8,0"/>
					<Button x:Name="Btn_ClearSelection" Content="Clear Selection" Style="{StaticResource ToolbarButton}"/>
				</StackPanel>
				<Button x:Name="Btn_RunSelected" Content="Run Selected" Style="{StaticResource RunButton}" Width="150" Height="36" Grid.Column="1" Margin="0,0,12,0"/>
			</Grid>

			<Border x:Name="Actions_Border" Style="{StaticResource PanelCard}" Margin="24,60,0,0" Width="216" HorizontalAlignment="Left" Height="570" VerticalAlignment="Top">
				<StackPanel x:Name="Actions_StackPanel" Margin="14,14,14,10">
					<TextBlock x:Name="Lbl_Actions" Text="Actions" Style="{StaticResource SectionHeaderText}"/>
					<Border Height="2" Width="28" Background="{StaticResource AccentBrush}" CornerRadius="1" HorizontalAlignment="Left" Margin="1,6,0,4"/>
					<CheckBox x:Name="Chk_SetPowerOptions" Content="Set Power Options" Style="{StaticResource ActionCheckBox}"/>
					<CheckBox x:Name="Chk_CopyShortcuts" Content="Copy Shortcuts" Style="{StaticResource ActionCheckBox}"/>
					<CheckBox x:Name="Chk_InstallLocalApps" Content="Install Local Apps" Style="{StaticResource ActionCheckBox}"/>
					<CheckBox x:Name="Chk_RepairWinget" Content="Repair Winget" Style="{StaticResource ActionCheckBox}"/>
					<CheckBox x:Name="Chk_UninstallBloat" Content="Uninstall Bloat" Style="{StaticResource ActionCheckBox}"/>
					<CheckBox x:Name="Chk_UninstallLanguagePacks" Content="Language Pack Killer" Style="{StaticResource ActionCheckBox}"/>
					<CheckBox x:Name="Chk_UpgradeWinget" Content="Upgrade Winget" Style="{StaticResource ActionCheckBox}"/>
					<CheckBox x:Name="Chk_InstallDefaultWinget" Content="Default Winget" Style="{StaticResource ActionCheckBox}"/>
					<CheckBox x:Name="Chk_InstallCustomWinget" Content="Custom Winget" Style="{StaticResource ActionCheckBox}"/>
					<CheckBox x:Name="Chk_InstallO365" Content="Install O365 Apps" Style="{StaticResource ActionCheckBox}"/>
					<CheckBox x:Name="Chk_CTTWinUtil" Content="CTT WinUtil" Style="{StaticResource ActionCheckBox}"/>
					<CheckBox x:Name="Chk_SetTimezone" Content="Set Timezone" Style="{StaticResource ActionCheckBox}"/>
				</StackPanel>
			</Border>

			<Border x:Name="ClientSelect_Border" Style="{StaticResource PanelCard}" Margin="248,60,0,0" Width="216" Height="530" HorizontalAlignment="Left" VerticalAlignment="Top">
				<StackPanel x:Name="ClientSelect_StackPanel" Margin="14,14,14,10">
					<TextBlock x:Name="Lbl_ClientSelect" Text="Client Select" Style="{StaticResource SectionHeaderText}"/>
					<Border Height="2" Width="28" Background="{StaticResource AccentBrush}" CornerRadius="1" HorizontalAlignment="Left" Margin="1,6,0,10"/>
					<Button x:Name="Btn_ReloadClients" Content="Reload Client List" Style="{StaticResource AppButton}" Background="#FF1C5971" Margin="0,0,0,8"/>
					<Button x:Name="Btn_ManualSelection" Content="Manual Client Select" Style="{StaticResource AppButton}" Background="#FF1C5971" Margin="0,0,0,10"/>
					<ListBox x:Name="ListBox_Clients" Height="292" Style="{StaticResource InputListBox}"/>
					<TextBlock Text="SELECTED CLIENT" FontFamily="Segoe UI Semibold" FontSize="10" Foreground="{StaticResource TextMutedBrush}" Margin="2,12,0,2"/>
					<TextBlock x:Name="TxtBlock_SelectedClient" TextWrapping="Wrap" Text="None" FontFamily="Segoe UI Semibold" FontSize="14" Foreground="{StaticResource DangerBrush}" Margin="2,0,0,0"/>
				</StackPanel>
			</Border>

			<Border x:Name="Misc_Border" Style="{StaticResource PanelCard}" Margin="472,60,0,0" Width="216" Height="300" HorizontalAlignment="Left" VerticalAlignment="Top">
				<StackPanel x:Name="Misc_StackPanel" Margin="14,14,14,10">
					<TextBlock x:Name="Lbl_Misc" Text="Misc" Style="{StaticResource SectionHeaderText}"/>
					<Border Height="2" Width="28" Background="{StaticResource WarningBrush}" CornerRadius="1" HorizontalAlignment="Left" Margin="1,6,0,4"/>
					<CheckBox x:Name="Chk_ConfigUAC" Content="Set UAC" Style="{StaticResource ActionCheckBox}" Tag="{StaticResource WarningBrush}"/>
					<CheckBox x:Name="Chk_ConfigTaskbar" Content="Configure Taskbar" Style="{StaticResource ActionCheckBox}" Tag="{StaticResource WarningBrush}"/>
					<CheckBox x:Name="Chk_UnlockWinUpdate" Content="Unlock Win Updates" Style="{StaticResource ActionCheckBox}" Tag="{StaticResource WarningBrush}"/>
					<CheckBox x:Name="Chk_OfficeInstallBypass" Content="O365 Install Bypass" Style="{StaticResource ActionCheckBox}" Tag="{StaticResource WarningBrush}"/>
					<CheckBox x:Name="Chk_RepairTakeControl" Content="Repair Take Control" Style="{StaticResource ActionCheckBox}" Tag="{StaticResource WarningBrush}"/>
				</StackPanel>
			</Border>

			<Border x:Name="Apps_Border" Style="{StaticResource PanelCard}" Margin="696,60,0,0" Width="216" Height="420" HorizontalAlignment="Left" VerticalAlignment="Top">
				<StackPanel x:Name="Apps_StackPanel" Margin="14,14,14,10">
					<TextBlock x:Name="Lbl_Apps" Text="Apps" Style="{StaticResource SectionHeaderText}"/>
					<Border Height="2" Width="28" Background="{StaticResource AccentBrush}" CornerRadius="1" HorizontalAlignment="Left" Margin="1,6,0,4"/>
					<CheckBox x:Name="Chk_InstallNVIDIAApp" Content="NVIDIA" Style="{StaticResource ActionCheckBox}"/>
					<CheckBox x:Name="Chk_InstallAMDApp" Content="AMD" Style="{StaticResource ActionCheckBox}"/>
					<CheckBox x:Name="Chk_InstallDellApp" Content="Dell" Style="{StaticResource ActionCheckBox}"/>
					<CheckBox x:Name="Chk_InstallLenovoApp" Content="Lenovo" Style="{StaticResource ActionCheckBox}"/>
					<CheckBox x:Name="Chk_InstallHPApp" Content="HP" Style="{StaticResource ActionCheckBox}"/>
					<CheckBox x:Name="Chk_InstallSnapdragonApp" Content="Snapdragon" Style="{StaticResource ActionCheckBox}"/>
					<CheckBox x:Name="Chk_InstallForticlientApp" Content="Forticlient" Style="{StaticResource ActionCheckBox}"/>
					<CheckBox x:Name="Chk_InstallFrameworkDrivers" Content="Framework Laptops" Style="{StaticResource ActionCheckBox}"/>
				</StackPanel>
			</Border>

			<Border x:Name="NAS_Border" Style="{StaticResource PanelCard}" Margin="920,60,0,0" Width="204" Height="270" HorizontalAlignment="Left" VerticalAlignment="Top">
				<StackPanel x:Name="NAS_StackPanel" Margin="14,14,14,10">
					<Grid>
						<TextBlock x:Name="Lbl_NASLogin" Text="NAS Login" Style="{StaticResource SectionHeaderText}" HorizontalAlignment="Left"/>
						<Ellipse x:Name="Ellipse_NASLoginStatusLight" Stroke="Black" StrokeThickness="0.6" Width="11" Height="11" Fill="#FFF90909" HorizontalAlignment="Right" VerticalAlignment="Center" ToolTip="NAS Connection Status">
							<Ellipse.Effect>
								<BlurEffect Radius="4"/>
							</Ellipse.Effect>
						</Ellipse>
					</Grid>
					<Border Height="2" Width="28" Background="{StaticResource AccentBrush}" CornerRadius="1" HorizontalAlignment="Left" Margin="1,6,0,10"/>
					<TextBlock x:Name="LblUsername" Text="Username" FontFamily="Segoe UI Semibold" FontSize="11" Foreground="{StaticResource TextMutedBrush}" Margin="1,0,0,3"/>
					<TextBox x:Name="TxtBox_Username" Style="{StaticResource InputBox}" Height="35"/>
					<TextBlock x:Name="LblPassword" Text="Password" FontFamily="Segoe UI Semibold" FontSize="11" Foreground="{StaticResource TextMutedBrush}" Margin="1,10,0,3"/>
					<PasswordBox x:Name="PasswordBox_Password" Style="{StaticResource InputPasswordBox}" Height="35"/>
					<Button x:Name="Btn_Login" Content="Login" Style="{StaticResource AppButton}" Background="{StaticResource AccentBrush}" Margin="0,14,0,0"/>
				</StackPanel>
			</Border>
		</Grid>

		<!-- ===================== TOOLS TAB ===================== -->
		<Grid x:Name="Tools_Grid" Margin="0,88,0,0" d:IsHidden="True">
			<Grid Margin="24,14,24,0" Height="36" VerticalAlignment="Top">
				<Grid.ColumnDefinitions>
					<ColumnDefinition Width="*"/>
					<ColumnDefinition Width="Auto"/>
				</Grid.ColumnDefinitions>
				<StackPanel Orientation="Horizontal" HorizontalAlignment="Left">
					<Button x:Name="Btn_SelectAllTools" Content="Select All" Style="{StaticResource ToolbarButton}" Margin="0,0,8,0"/>
					<Button x:Name="Btn_ClearSelectionTools" Content="Clear Selection" Style="{StaticResource ToolbarButton}"/>
				</StackPanel>
				<Button x:Name="Btn_RunSelectedTools" Content="Run Selected" Style="{StaticResource RunButton}" Width="150" Height="36" Grid.Column="1"/>
			</Grid>

			<Border x:Name="HDActions_Border" Style="{StaticResource PanelCard}" Margin="24,60,0,0" Width="216" HorizontalAlignment="Left" Height="120" VerticalAlignment="Top">
				<StackPanel x:Name="HDActions_StackPanel" Margin="14,14,14,10">
					<TextBlock x:Name="Lbl_HD_Actions" Text="HD Actions" Style="{StaticResource SectionHeaderText}"/>
					<Border Height="2" Width="28" Background="{StaticResource AccentBrush2}" CornerRadius="1" HorizontalAlignment="Left" Margin="1,6,0,4"/>
					<CheckBox x:Name="Chk_DISM" Content="DISM" Style="{StaticResource ActionCheckBox}" Tag="{StaticResource AccentBrush2}"/>
				</StackPanel>
			</Border>

			<Border x:Name="EuphActions_Border" Style="{StaticResource PanelCard}" Margin="248,60,0,0" Width="216" HorizontalAlignment="Left" Height="160" VerticalAlignment="Top">
				<StackPanel x:Name="EuphActions_StackPanel" Margin="14,14,14,10">
					<TextBlock x:Name="Lbl_Personal" Text="Personal" Style="{StaticResource SectionHeaderText}"/>
					<Border Height="2" Width="28" Background="{StaticResource AccentBrush2}" CornerRadius="1" HorizontalAlignment="Left" Margin="1,6,0,4"/>
					<CheckBox x:Name="Chk_EnableScripting" Content="Enable Scripting" Style="{StaticResource ActionCheckBox}" Tag="{StaticResource AccentBrush2}"/>
					<CheckBox x:Name="Chk_CheckHardware" Content="Check Hardware" Style="{StaticResource ActionCheckBox}" Tag="{StaticResource AccentBrush2}"/>
				</StackPanel>
			</Border>
		</Grid>

		<!-- ===================== FAQ TAB ===================== -->
		<Grid x:Name="FAQ_Grid" Margin="0,88,0,0" d:IsHidden="True">
			<StackPanel x:Name="FAQ_StackPanel" Margin="30,30,30,0" VerticalAlignment="Top">
				<TextBlock x:Name="Lbl_FAQ" Text="FAQ" Foreground="{StaticResource AccentBrush}" FontFamily="Segoe UI Semibold" FontSize="32" Margin="0,0,0,18"/>

				<Border Style="{StaticResource PanelCard}" Padding="18,14" Margin="0,0,0,12">
					<StackPanel>
						<TextBlock x:Name="Lbl_FAQ1" Text="What is a hash mismatch?" FontFamily="Segoe UI Semibold" FontSize="16" Foreground="{StaticResource AccentBrush2}"/>
						<TextBlock x:Name="TxtBlock_FAQ1" TextWrapping="Wrap" Text="A Hash Mismatch occurs when Winget has not yet validated the hash of the program you are trying to install. You need to install the app manually until winget resolves the issue." FontFamily="Segoe UI" FontSize="13" Foreground="{StaticResource TextPrimaryBrush}" Margin="0,6,0,0"/>
					</StackPanel>
				</Border>

				<Border Style="{StaticResource PanelCard}" Padding="18,14">
					<StackPanel>
						<TextBlock x:Name="Lbl_FAQ2" Text="Winget error &quot;failed to update from source msstore&quot;." FontFamily="Segoe UI Semibold" FontSize="16" Foreground="{StaticResource AccentBrush2}" TextWrapping="Wrap"/>
						<TextBlock x:Name="TxtBlock_FAQ2" TextWrapping="Wrap" Text="This error is fixed by running the &quot;Repair Winget&quot; button on the Deployment tab." FontFamily="Segoe UI" FontSize="13" Foreground="{StaticResource TextPrimaryBrush}" Margin="0,6,0,0"/>
					</StackPanel>
				</Border>
			</StackPanel>
			<Border x:Name="FAQ_Border" BorderBrush="{StaticResource WindowBorderBrush}" BorderThickness="1" CornerRadius="10" Margin="14,14,14,14"/>
		</Grid>

		<TextBlock x:Name="Lbl_Copyright" Text="Created By: Brandon Swarek" FontFamily="Segoe UI" FontSize="11" Foreground="{StaticResource TextMutedBrush}" VerticalAlignment="Bottom" HorizontalAlignment="Right" Margin="0,0,14,8"/>
	</Grid>
</Window>
"@

# ============================================================
# 5. SHOW SPLASH SCREEN
# ============================================================
$Splash = Load-VisualStudioXaml -RawXaml $splashXML
$Splash.Show()

$end = (Get-Date).AddSeconds(5)
while ((Get-Date) -lt $end) {
    [System.Windows.Forms.Application]::DoEvents()
    Start-Sleep -Milliseconds 16
}

$Splash.Close()

# ============================================================
# 6. LOAD MAIN GUI OBJECT
# ============================================================
$Main = Load-VisualStudioXaml -RawXaml $mainXML

# --- SYNC HASHTABLE ---
# Shared, thread-safe state passed into every background runspace: a handle back to the Window
# (so background threads can marshal UI updates via the Dispatcher) and a table of what's
# currently running (so we can't double-fire the same job).
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

# --- Source: src\functions\CTTWinUtil.ps1 ---
<#
.SYNOPSIS
    Runs Chris Titus Tech's WinUtil unattended with a custom tweak selection.

.DESCRIPTION
    Writes out a WinUtil-compatible config JSON containing the specified tweak
    keys, then launches WinUtil with -Config <file> -Run so it applies them
    automatically (no manual "Run Tweaks" click required).

    NOTE: This still opens the WinUtil GUI window while it runs â€” WinUtil has
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

        if ($App.Name -match "WindowsAgentSetup" -and $App.Name -cnotmatch "VALID") {
            Write-Host "Generic installer blocked - please update NAS with correct n-able installer" -ForegroundColor Red
            continue
        }

        if (($App.Name -like "*WindowsAgentSetup*" -and $WindowsAgentInstalled) -or
            ($App.Name -like "*GlobalProtect*"     -and $GlobalProtectInstalled)) {
            Write-Host "Skipping $($App.Name) - already installed." -ForegroundColor DarkYellow
            continue
        }

        Stop-BlockingInstallerProcesses

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
        Stop-BlockingInstallerProcesses

        # Executes winget for each ID found in the text file, attempts machine scope first
        $result = Invoke-WingetProcess -ArgumentList "install --id $App --silent --accept-source-agreements --accept-package-agreements --scope machine"

        switch ($result.ExitCode) {
            0            { Write-Host "Successfully installed $App" -ForegroundColor Green }
            -1978335189  { Write-Host "$App is already up to date" -ForegroundColor Cyan }
            -1978335216  {
                            # APPINSTALLER_CLI_ERROR_NO_APPLICABLE_INSTALLER - retries without --scope machine
                            Write-Warning "$App failed with --scope machine (no applicable installer), retrying without --scope..."
                            Stop-BlockingInstallerProcesses
                            $retryResult = Invoke-WingetProcess -ArgumentList "install --id $App --silent --accept-source-agreements --accept-package-agreements"

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
        Stop-BlockingInstallerProcesses

        $result = Invoke-WingetProcess -ArgumentList "install --id $App --silent --accept-source-agreements --accept-package-agreements"
        
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
        Stop-BlockingInstallerProcesses

        $result = Invoke-WingetProcess -ArgumentList "install --id $App --silent --accept-source-agreements --accept-package-agreements"
        
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
        Stop-BlockingInstallerProcesses
        $upgradeResult = Invoke-WingetProcess -ArgumentList "upgrade --all --silent --accept-source-agreements --accept-package-agreements"

        switch ($upgradeResult.ExitCode) {
            0            { Write-Host "System upgrade completed successfully" -ForegroundColor Green }
            -1978335189  { Write-Host "All packages already up to date" -ForegroundColor Cyan }
            default      { Write-Warning "System upgrade finished with exit code: $($upgradeResult.ExitCode)" }
        }
    }

    # 2. Proceed to install the requested AppID (including Dell apps)
    Stop-BlockingInstallerProcesses
    Write-Host "Installing package: $AppID..." -ForegroundColor Green
    $result = Invoke-WingetProcess -ArgumentList "install --id $AppID --silent --accept-source-agreements --accept-package-agreements"

    switch ($result.ExitCode) {
        0            { Write-Host "Successfully installed $AppID" -ForegroundColor Green }
        -1978335189  { Write-Host "$AppID is already up to date" -ForegroundColor Cyan }
        default      { Write-Warning "Failed to install $AppID (Exit code: $($result.ExitCode))" }
    }

    Start-Sleep -Seconds 1
}

# --- Source: src\functions\Invoke-WingetProcess.ps1 ---
function Invoke-WingetProcess {
    <#
    .SYNOPSIS
        Runs a single winget command via Start-Process, automatically retrying
        transient failures up to 3 total attempts.

    .DESCRIPTION
        Winget intermittently fails with things like "Failed to open internal
        URL" or an unrecognized/unknown error, and simply running the exact
        same command again succeeds. This wraps Start-Process winget so every
        call site gets that retry for free, without retrying failures a retry
        can never fix:
          - APPINSTALLER_CLI_ERROR_NO_APPLICABLE_INSTALLER (-1978335216) -
            the --scope machine mismatch callers already handle by retrying
            without --scope.
          - APPINSTALLER_CLI_ERROR_INSTALLER_HASH_MISMATCH (-1978335215) -
            the downloaded installer doesn't match the manifest hash; running
            it again just downloads the same mismatched bits.
        Success (0) and "already up to date"/"no applicable update"
        (-1978335189) also return immediately since there's nothing to retry.

    .NOTES
        Shared helper for Install-ClientCustomWingetApps, Install-DefaultWingetApps,
        Install-O365 and Install-PassedWingetApp.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ArgumentList,

        [int]$MaxAttempts = 3
    )

    # Exit codes a retry cannot fix - fail fast on these instead of burning attempts.
    $NoRetryExitCodes = @(
        -1978335216, # APPINSTALLER_CLI_ERROR_NO_APPLICABLE_INSTALLER (--scope machine issue)
        -1978335215  # APPINSTALLER_CLI_ERROR_INSTALLER_HASH_MISMATCH
    )

    $Attempt = 0
    do {
        $Attempt++
        $result = Start-Process winget -ArgumentList $ArgumentList -Wait -PassThru -NoNewWindow

        if ($result.ExitCode -eq 0 -or $result.ExitCode -eq -1978335189 -or $NoRetryExitCodes -contains $result.ExitCode) {
            return $result
        }

        if ($Attempt -lt $MaxAttempts) {
            Write-Warning "winget $ArgumentList failed (Exit code: $($result.ExitCode)), retrying ($($Attempt + 1) of $MaxAttempts)..."
            Stop-BlockingInstallerProcesses
        }
    } while ($Attempt -lt $MaxAttempts)

    return $result
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
    exit 1
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
                WriteLog -Level "ERROR" -Message  "The file size does not match the expected size. Exiting..."
                return $null
            } 
            elseif ($ExpectedHash -ne $ActualHash) {
                WriteLog -Level "ERROR" -Message  "The file hash does not match the expected hash. Exiting..."
                return $null
            }
            elseif (-not (CheckFileSignature($FilePath))) {
                WriteLog -Level "ERROR" -Message  "The file signature is not valid. Exiting..."   
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

    $exitCode = -1

    try {

        $proc = Start-Process -FilePath $FileName -ArgumentList $Parameters -Wait -PassThru -NoNewWindow -ErrorAction Stop
        $exitCode = $proc.ExitCode

    }
    catch {
        WriteLog -Level "ERROR" -Message  "Error executing file `$FileName: $($_.Exception.Message)"
        $exitCode = 1
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

    return $exitCode

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
            WriteLog -Message  "The lock file '$LockFilePath' is newer than $lockFileAgeThresholdMinutes minutes. Exiting..."
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
        WriteLog -Message  "Installation lock file is present. Exiting..."
        Exit
    }

    $lockExists = IsLockFilePresent -LockFilePath $UnInstallLockFilePath -lockFileAgeThresholdMinutes $lockFileAgeThresholdMinutes
    if ($lockExists -eq $true) {
        WriteLog -Message  "Uninstallation lock file is present. Exiting..."
        Exit
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
                    WriteLog -Message  "Uninstallation lock file is present. Uninstallation is in progress... Exiting..."
                    Exit
                }

                WriteLog -Message  "Uninstalling previous agent..."

                $uninstallerArguments = "/S"
                $exitCode = ExecuteBinary -FileName $AgentUninstallerPath -Parameters $uninstallerArguments
                WriteLog -Message "Uninstaller finished with exit code $exitCode"

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
            WriteLog -Message  "Installation lock file is present. Installation is already in progress... Exiting..."
            Exit
        }

        WriteLog -Message  "Starting Take Control agent installer"
        $exitCode = ExecuteBinary -FileName $agentFile -Parameters $parameters
        WriteLog -Message "Installer finished with exit code $exitCode"

    }
    else {
        WriteLog -Level "ERROR" -Message ("Unable to download Take Control agent file...")  
    }

    Exit

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
    Exit
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
            Exit 1
        }
        else {
            WriteLog -Message "N-central Remote Control configuration is complete."
            Exit 0
        }
    }
    else {
        WriteLog -Level "ERROR" -Message "Take Control agent is not in a good state. Please check the logs for more details."
        Exit 1
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

    Exit 0

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
    Start-Process winget -ArgumentList "install Microsoft.VCLibs.Desktop.14 --source winget --silent --accept-package-agreements --accept-source-agreements" -Wait -PassThru -NoNewWindow

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

# --- Source: src\functions\Stop-BlockingInstallerProcesses.ps1 ---
function Stop-BlockingInstallerProcesses {
    <#
    .SYNOPSIS
        Kills known installer/updater processes and resets the Windows Installer
        service so a queued winget/MSI install doesn't fail because of a
        background installer this script never launched.

    .DESCRIPTION
        Winget and MSI installs frequently die with "another installation is
        already in progress" (ERROR_INSTALL_ALREADY_RUNNING / Win32 1618)
        because something else on the machine - Windows Update servicing,
        OneDrive, Office Click-to-Run, a leftover vendor bootstrapper, etc. -
        is holding the global MSI mutex or its own installer lock. Call this
        immediately before every single app install attempt to clear the
        field first.

    .NOTES
        Shared helper, called once per app right before the install is
        attempted from Install-ClientCustomLocalApps, Install-ClientCustomWingetApps,
        Install-DefaultWingetApps, Install-O365 and Install-PassedWingetApp.
    #>
    [CmdletBinding()]
    param()

    # Processes known to hold the MSI/installer lock or otherwise collide
    # with a fresh silent install.
    $KnownInstallerProcesses = @(
        "msiexec",             # Windows Installer engine
        "TiWorker",            # Windows Modules Installer Worker
        "TrustedInstaller",    # Windows Modules Installer service host
        "wuauclt",             # Legacy Windows Update client
        "UsoClient",           # Update Session Orchestrator
        "MoUsoCoreWorker",     # Update Orchestrator worker
        "OneDriveSetup",
        "OfficeClickToRun",    # Office C2R service host - notorious for blocking Office/MSI installs
        "OfficeC2RClient",
        "AppInstallerCLI",
        "winget",              # Leftover/hung winget from a previous attempt
        "GoogleUpdate",
        "MicrosoftEdgeUpdate"
    )

    $Killed = @()

    Get-Process -Name $KnownInstallerProcesses -ErrorAction SilentlyContinue | ForEach-Object {
        $Killed += $_.ProcessName
        $_ | Stop-Process -Force -ErrorAction SilentlyContinue
    }

    # Catch anything else that looks like a vendor bootstrapper (*setup*,
    # *install*, *update*) but wasn't launched by this script - excluding
    # our own process and its parent so we can never self-terminate.
    $ProtectedPids = @($PID)
    try {
        $ProtectedPids += (Get-CimInstance Win32_Process -Filter "ProcessId=$PID" -ErrorAction Stop).ParentProcessId
    } catch {}

    Get-Process | Where-Object {
        $_.Id -notin $ProtectedPids -and
        $KnownInstallerProcesses -notcontains $_.ProcessName -and
        $_.ProcessName -match '(setup|install|updater?)'
    } | ForEach-Object {
        $Killed += $_.ProcessName
        $_ | Stop-Process -Force -ErrorAction SilentlyContinue
    }

    # Reset the Windows Installer service - this clears a stuck
    # Global\_MSIExecute mutex (ERROR_INSTALL_ALREADY_RUNNING) even when no
    # msiexec.exe process is visibly running. It restarts on-demand the next
    # time anything calls into MSI, so it's safe to do before every install.
    try { Restart-Service -Name msiserver -Force -ErrorAction SilentlyContinue } catch {}

    if ($Killed.Count -gt 0) {
        $Unique = $Killed | Select-Object -Unique
        Write-Host "Cleared possible blocking installers: $($Unique -join ', ')" -ForegroundColor DarkYellow
    }
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

# --- Source: src\functions\Upgrade-AllWinget.ps1 ---
function Upgrade-AllWinget {
    Show-FunctionBanner "Full Upgrade"
    Write-Host "Running winget upgrade for all packages..." -ForegroundColor Yellow
    $upgradeResult = Start-Process winget -ArgumentList "upgrade --all --silent --accept-source-agreements --accept-package-agreements" -Wait -PassThru -NoNewWindow

    switch ($upgradeResult.ExitCode) {
        0       { Write-Host "All packages upgraded successfully" -ForegroundColor Green }
        default { Write-Warning "winget upgrade completed with exit code: $($upgradeResult.ExitCode)" }
    }

    return "Completed"
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

    $ellipse = $sync.Main.FindName("Ellipse_StatusLight")

    if ($State -eq "Busy") {
        $ellipse.Fill = [System.Windows.Media.Brushes]::Red
    } else {
        $ellipse.Fill = [System.Windows.Media.Brushes]::LimeGreen
    }

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


# ============================================================
# 7. UI ELEMENT AUTO-BINDING
# Every element in the XAML that has an x:Name becomes a script-scope PowerShell variable of the
# same name (e.g. x:Name="Chk_RepairWinget" -> $Chk_RepairWinget). Anything you add a new x:Name
# for in MainWindow.xaml is automatically usable here with zero extra wiring.
# ============================================================
([xml]$mainXML).SelectNodes("//*[@*[local-name()='Name']]") | ForEach-Object {
    $name = $_.GetAttribute("Name", "http://schemas.microsoft.com/winfx/2006/xaml")
    if (-not $name) { $name = $_.Name }
    Set-Variable -Name $name -Value $Main.FindName($name) -Scope Script
}

# --- SHARED RUNSPACE POOL ---
# Every "Run" action executes on a background runspace (not the UI thread) so the window never
# freezes. Functions defined in this session get copied into the pool's session state so they're
# callable from those background runspaces too.
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

# ============================================================
# 8. BUSY-STATE HELPERS
# ============================================================

# Runs synchronously on the UI thread. Only used for quick, blocking actions (NAS login, client
# list refresh) where we want the window to visibly wait.
function Invoke-BusyAction {
    param([scriptblock]$Action)
    Update-Status -State "Busy"
    & $Action
    Update-Status -State "Ready"
}

# Runs asynchronously on the shared runspace pool, tracked by $Name so the same job can't stack
# on top of itself if the user double-clicks. NOTE: $Action is converted to plain text
# (.ToString()) and re-parsed inside the background runspace, so it must be a SELF-CONTAINED
# scriptblock of literal function calls only - it cannot close over outer PowerShell variables.
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

# Runs several NAMED actions in strict sequence on a single background runspace - the next one
# does not start until the previous one finishes (unlike firing several Invoke-BusyActionAsync
# calls, which would let the runspace pool run them at the same time). Each action is still
# locked individually in $sync.Running as it runs, and unlocked the moment IT finishes rather
# than waiting for the whole queue - so a second, unrelated "Run Selected" click can start
# immediately on anything in this queue that hasn't reached the front yet, while correctly
# skipping whatever's currently mid-run.
#
# $Actions is an [ordered] Name -> command-text hashtable. Callers MUST reserve every key in
# $sync.Running (on the UI thread, before calling this) so two rapid clicks can't both grab the
# same action - see Btn_RunSelected below.
function Invoke-BusyActionQueueAsync {
    param([System.Collections.Specialized.OrderedDictionary]$Actions)

    if ($Actions.Count -eq 0) { return }

    $ps = [powershell]::Create()
    $ps.RunspacePool = $sync.RunspacePool
    $ps.AddScript({
        param($Actions, $SelectedClient)
        $global:SelectedClient = $SelectedClient
        $sync.Main.Dispatcher.Invoke([action]{ Update-Status -State "Busy" })
        foreach ($name in $Actions.Keys) {
            try {
                & ([scriptblock]::Create($Actions[$name]))
            } finally {
                $sync.Running.Remove($name)
                if ($sync.Running.Count -eq 0) {
                    $sync.Main.Dispatcher.Invoke([action]{ Update-Status -State "Ready" })
                }
            }
        }
    }).AddParameter("Actions", $Actions).AddParameter("SelectedClient", $global:SelectedClient) | Out-Null

    $ps.BeginInvoke() | Out-Null
}

# ============================================================
# 9. ACTION MAPS
# Maps each selection CheckBox's x:Name to the literal command it should run. These are strings
# (not scriptblocks) so they can be joined together and compiled into ONE scriptblock at click
# time - see Invoke-BusyActionAsync's note above about why closures don't survive the trip into
# the background runspace.
#
# Order here is the order actions run in when several are selected together (roughly mirrors the
# old "Run All" button's sequence: system settings first, then cleanup, then installs).
# ============================================================
$DeploymentActionMap = [ordered]@{
    # Actions panel - order matches the old "Run All" button's sequence exactly (system settings
    # first, then cleanup, then winget upgrade, then installs). Run Selected dispatches checked
    # actions in this order (see Btn_RunSelected below).
    'Chk_SetPowerOptions'         = 'Set-CustomPowerOptions'
    'Chk_CopyShortcuts'           = 'Copy-Shortcuts'
    'Chk_InstallLocalApps'        = 'Install-ClientCustomLocalApps'
    'Chk_RepairWinget'            = 'Repair-Winget'
    'Chk_UninstallBloat'          = 'Uninstall-Bloat'
    'Chk_UninstallLanguagePacks'  = 'Uninstall-OfficeLanguagePacks'
    'Chk_UpgradeWinget'           = 'Upgrade-AllWinget'
    'Chk_InstallDefaultWinget'    = 'Install-DefaultWingetApps'
    'Chk_InstallCustomWinget'     = 'Install-ClientCustomWingetApps'
    'Chk_InstallO365'             = 'Install-O365'
    'Chk_CTTWinUtil'              = 'RunCTTWinUtilCustom'
    'Chk_SetTimezone'             = 'Set-ComputerTimeZone'
    # Misc panel
    'Chk_ConfigUAC'               = 'Set-UAC'
    'Chk_ConfigTaskbar'           = 'Set-Taskbar'
    'Chk_UnlockWinUpdate'         = 'Unlock-WinUpdates'
    'Chk_OfficeInstallBypass'     = 'Install-O365Bypass'
    'Chk_RepairTakeControl'       = 'Repair-TakeControl'
    # Apps panel (driver / vendor utilities)
    'Chk_InstallNVIDIAApp'        = 'Install-PassedWingetApp "TechPowerUp.NVCleanstall"'
    'Chk_InstallAMDApp'           = 'Start-Process "https://www.amd.com/en/support/download/drivers.html"'
    # Dell's updater needs a current winget before it'll install cleanly, so this is the one app
    # entry that upgrades winget first - it's bundled into this single action (and its own lock)
    # rather than depending on the separate "Upgrade Winget" checkbox being checked too.
    'Chk_InstallDellApp'          = "Upgrade-AllWinget`nInstall-PassedWingetApp `"Dell.CommandUpdate`""
    'Chk_InstallLenovoApp'        = 'Install-PassedWingetApp "9NR5B8GVVM13"'
    'Chk_InstallHPApp'            = 'Start-Process "https://support.hp.com/us-en/help/hp-support-assistant"'
    'Chk_InstallSnapdragonApp'    = 'Start-Process "https://softwarecenter.qualcomm.com/api/download/software/tools/SnapdragonControlPanel/Windows/ARM64/2025.3.0.0/Snapdragon_Control_Panel_2025.3.0.0.zip"'
    'Chk_InstallForticlientApp'   = 'Start-Process "https://links.fortinet.com/forticlient/win/vpnagent"'
    'Chk_InstallFrameworkDrivers' = 'Start-Process "https://knowledgebase.frame.work/bios-and-drivers-downloads-rJ3PaCexh"'
}

$ToolsActionMap = [ordered]@{
    'Chk_DISM'            = 'DISMFix'
    'Chk_EnableScripting' = 'Set-ScriptingEnvironment'
    'Chk_CheckHardware'   = 'Check-Hardware'
}

# Only the Actions panel is affected by "Select All" (Misc and Apps are left untouched - see
# Btn_SelectAll below).
$ActionsPanelChecks = @(
    'Chk_RepairWinget', 'Chk_InstallO365', 'Chk_InstallLocalApps', 'Chk_InstallDefaultWinget',
    'Chk_InstallCustomWinget', 'Chk_UninstallBloat', 'Chk_UninstallLanguagePacks', 'Chk_UpgradeWinget',
    'Chk_SetPowerOptions', 'Chk_SetTimezone', 'Chk_CopyShortcuts', 'Chk_CTTWinUtil'
)

# What "Winget Apps Only" checks (and clears everything else to). Deliberately includes
# Install O365 Apps alongside the winget-specific actions.
$WingetOnlySelection = @('Chk_RepairWinget', 'Chk_UpgradeWinget', 'Chk_InstallDefaultWinget', 'Chk_InstallCustomWinget', 'Chk_InstallO365')

# Helper: fetch a checkbox by its x:Name string from script scope (used because we only have the
# name as a string key while iterating the maps above).
function Get-CheckboxByName {
    param([string]$Name)
    (Get-Variable -Name $Name -Scope Script -ErrorAction SilentlyContinue).Value
}

# ============================================================
# 10. SELECTION TOOLBAR - DEPLOYMENT TAB
# ============================================================
$Btn_SelectAll.Add_Click({
    # Actions panel only - Misc and Apps are left exactly as the user set them.
    foreach ($key in $ActionsPanelChecks) {
        $cb = Get-CheckboxByName $key
        if ($cb) { $cb.IsChecked = $true }
    }
})

$Btn_ClearSelection.Add_Click({
    foreach ($key in $DeploymentActionMap.Keys) {
        $cb = Get-CheckboxByName $key
        if ($cb) { $cb.IsChecked = $false }
    }
})

$Btn_SelectWingetOnly.Add_Click({
    foreach ($key in $DeploymentActionMap.Keys) {
        $cb = Get-CheckboxByName $key
        if ($cb) { $cb.IsChecked = ($WingetOnlySelection -contains $key) }
    }
})

$Btn_RunSelected.Add_Click({
    $selectedKeys = foreach ($key in $DeploymentActionMap.Keys) {
        $cb = Get-CheckboxByName $key
        if ($cb -and $cb.IsChecked) { $key }
    }

    if (-not $selectedKeys -or $selectedKeys.Count -eq 0) {
        Write-Host "`nNo actions selected. Check at least one box before running." -ForegroundColor Yellow
        return
    }

    # Reserve a lock for every selected action that ISN'T already running elsewhere, right here on
    # the UI thread, so two rapid clicks can never both grab the same action. Anything already
    # running gets skipped with its own warning instead of blocking the rest of the batch.
    $queued = [ordered]@{}
    foreach ($key in $selectedKeys) {
        if ($sync.Running.ContainsKey($key)) {
            Write-Host "`nWait! '$key' is already running." -ForegroundColor Yellow
            continue
        }
        $sync.Running[$key] = $true
        $queued[$key] = $DeploymentActionMap[$key]
    }

    if ($queued.Count -eq 0) { return }

    # The accepted actions run ONE AFTER ANOTHER on a single background runspace, in the order
    # they appear in $DeploymentActionMap (top-to-bottom in the Actions/Misc/Apps panels) - the
    # next one does not start until the previous one finishes. Each is still unlocked in
    # $sync.Running the moment IT completes, so a later "Run Selected" click can start on it again
    # right away without waiting for the rest of this queue.
    Invoke-BusyActionQueueAsync -Actions $queued
})

$Btn_Login.Add_Click({ Invoke-BusyAction { Connect-NAS } })

# ============================================================
# 11. CLIENT SELECT COLUMN
# ============================================================
$Btn_ReloadClients.Add_Click({ Invoke-BusyAction { Refresh-Clients } })
$Btn_ManualSelection.Add_Click({ Invoke-BusyAction { Select-ManualFolder } })
$ListBox_Clients.Add_MouseDoubleClick({ Set-SelectedClient })

# ============================================================
# 12. SELECTION TOOLBAR - TOOLS TAB
# ============================================================
$Btn_SelectAllTools.Add_Click({
    foreach ($key in $ToolsActionMap.Keys) {
        $cb = Get-CheckboxByName $key
        if ($cb) { $cb.IsChecked = $true }
    }
})

$Btn_ClearSelectionTools.Add_Click({
    foreach ($key in $ToolsActionMap.Keys) {
        $cb = Get-CheckboxByName $key
        if ($cb) { $cb.IsChecked = $false }
    }
})

$Btn_RunSelectedTools.Add_Click({
    $commands = foreach ($key in $ToolsActionMap.Keys) {
        $cb = Get-CheckboxByName $key
        if ($cb -and $cb.IsChecked) { $ToolsActionMap[$key] }
    }

    if (-not $commands -or $commands.Count -eq 0) {
        Write-Host "`nNo actions selected. Check at least one box before running." -ForegroundColor Yellow
        return
    }

    $actionBlock = [scriptblock]::Create(($commands -join "`n"))
    Invoke-BusyActionAsync -Name "RunSelectedTools" -Action $actionBlock
})

# ============================================================
# 13. TAB SWITCHING
# ============================================================
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

# ============================================================
# TITLE BAR / WINDOW CHROME
# ============================================================
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

# WindowStyle="None" means there's no OS title bar to drag by, so the whole (otherwise-empty)
# title area doubles as a drag handle.
$Main_Grid.Add_MouseLeftButtonDown({
    $Main.DragMove()
})

# 3. OPEN THE WINDOW (Last Step)
$Main_Grid.Add_Loaded({
    Startup-Logo
    GUI-Startup
})

# ============================================================
# 14. STARTUP SEQUENCE
# ============================================================
$Tools_Grid.Visibility = "Collapsed"
$FAQ_Grid.Visibility = "Collapsed"
Start-PowerShellLogging
$Main.ShowDialog() | Out-Null
Write-Host "Goodbye!!!" -ForegroundColor Cyan

