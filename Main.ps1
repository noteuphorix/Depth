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

			<Border x:Name="Actions_Border" Style="{StaticResource PanelCard}" Margin="24,60,0,0" Width="216" HorizontalAlignment="Left" Height="530" VerticalAlignment="Top">
				<StackPanel x:Name="Actions_StackPanel" Margin="14,14,14,10">
					<TextBlock x:Name="Lbl_Actions" Text="Actions" Style="{StaticResource SectionHeaderText}"/>
					<Border Height="2" Width="28" Background="{StaticResource AccentBrush}" CornerRadius="1" HorizontalAlignment="Left" Margin="1,6,0,4"/>
					<CheckBox x:Name="Chk_RepairWinget" Content="Repair Winget" Style="{StaticResource ActionCheckBox}"/>
					<CheckBox x:Name="Chk_InstallO365" Content="Install O365 Apps" Style="{StaticResource ActionCheckBox}"/>
					<CheckBox x:Name="Chk_InstallLocalApps" Content="Install Local Apps" Style="{StaticResource ActionCheckBox}"/>
					<CheckBox x:Name="Chk_InstallDefaultWinget" Content="Default Winget" Style="{StaticResource ActionCheckBox}"/>
					<CheckBox x:Name="Chk_InstallCustomWinget" Content="Custom Winget" Style="{StaticResource ActionCheckBox}"/>
					<CheckBox x:Name="Chk_UninstallBloat" Content="Uninstall Bloat" Style="{StaticResource ActionCheckBox}"/>
					<CheckBox x:Name="Chk_UninstallLanguagePacks" Content="Language Pack Killer" Style="{StaticResource ActionCheckBox}"/>
					<CheckBox x:Name="Chk_SetPowerOptions" Content="Set Power Options" Style="{StaticResource ActionCheckBox}"/>
					<CheckBox x:Name="Chk_SetTimezone" Content="Set Timezone" Style="{StaticResource ActionCheckBox}"/>
					<CheckBox x:Name="Chk_CopyShortcuts" Content="Copy Shortcuts" Style="{StaticResource ActionCheckBox}"/>
					<CheckBox x:Name="Chk_CTTWinUtil" Content="CTT WinUtil" Style="{StaticResource ActionCheckBox}"/>
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
# COMPILER_INSERT_HERE

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
    # Actions panel
    'Chk_SetPowerOptions'         = 'Set-CustomPowerOptions'
    'Chk_CopyShortcuts'           = 'Copy-Shortcuts'
    'Chk_InstallLocalApps'        = 'Install-ClientCustomLocalApps'
    'Chk_RepairWinget'            = 'Repair-Winget'
    'Chk_UninstallBloat'          = 'Uninstall-Bloat'
    'Chk_UninstallLanguagePacks'  = 'Uninstall-OfficeLanguagePacks'
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
    'Chk_InstallDellApp'          = 'Install-PassedWingetApp "Dell.CommandUpdate"'
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

# The old "Run All" button also silently ran Upgrade-AllWinget even though no button on the UI
# ever triggered it by itself. There's still no dedicated checkbox for it, so we run it whenever
# ANY winget-related box is checked (see Btn_RunSelected below). Flagging this here in case you'd
# rather give it its own checkbox instead.
$WingetRelatedChecks = @('Chk_RepairWinget', 'Chk_InstallDefaultWinget', 'Chk_InstallCustomWinget')

# Only the Actions panel is affected by "Select All" (Misc and Apps are left untouched - see
# Btn_SelectAll below).
$ActionsPanelChecks = @(
    'Chk_RepairWinget', 'Chk_InstallO365', 'Chk_InstallLocalApps', 'Chk_InstallDefaultWinget',
    'Chk_InstallCustomWinget', 'Chk_UninstallBloat', 'Chk_UninstallLanguagePacks',
    'Chk_SetPowerOptions', 'Chk_SetTimezone', 'Chk_CopyShortcuts', 'Chk_CTTWinUtil'
)

# What "Winget Apps Only" checks (and clears everything else to). Deliberately includes
# Install O365 Apps alongside the three winget-specific actions.
$WingetOnlySelection = @('Chk_RepairWinget', 'Chk_InstallDefaultWinget', 'Chk_InstallCustomWinget', 'Chk_InstallO365')

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
    $commands = foreach ($key in $DeploymentActionMap.Keys) {
        $cb = Get-CheckboxByName $key
        if ($cb -and $cb.IsChecked) { $DeploymentActionMap[$key] }
    }

    # See the $WingetRelatedChecks note above - Upgrade-AllWinget has no checkbox of its own.
    if ($Chk_RepairWinget.IsChecked -or $Chk_InstallDefaultWinget.IsChecked -or $Chk_InstallCustomWinget.IsChecked) {
        $commands = @('Upgrade-AllWinget') + $commands
    }

    if (-not $commands -or $commands.Count -eq 0) {
        Write-Host "`nNo actions selected. Check at least one box before running." -ForegroundColor Yellow
        return
    }

    $actionBlock = [scriptblock]::Create(($commands -join "`n"))
    Invoke-BusyActionAsync -Name "RunSelected" -Action $actionBlock
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
