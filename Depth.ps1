Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms
# --- THE CLEANING FUNCTION ---
# This makes it easy to load any XAML you copy from Visual Studio
function Load-VisualStudioXaml {
    param([string]$RawXaml)
    $Cleaned = $RawXaml -replace 'mc:Ignorable="d"','' `
                        -replace "x:Class.*?[^\x20]*",' ' `
                        -replace "xmlns:local.*?[^\x20]*",' ' `
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
        Title="Depth" Height="500" Width="800" WindowStartupLocation="CenterScreen" Background="#FF262D2F" SizeToContent="WidthAndHeight" MinHeight="500" MinWidth="850" WindowStyle="ToolWindow">
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
    <Grid x:Name="Main_GUI_Grid" MinWidth="800">
        <Border x:Name="Main_GUI_Border" BorderThickness="5,5,5,5" BorderBrush="#FF2B3842"/>
        <Grid x:Name="Title_Bar_Grid" VerticalAlignment="Top" Height="34" MinHeight="50">
            <Button x:Name="BtnTools_Menu" Content="Tools" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="87" Background="#FF454A4C" Foreground="White" BorderBrush="White" BorderThickness="2" Style="{StaticResource CleanButtons}" Margin="117,10,0,0"/>
            <Button x:Name="BtnDeployment_Menu" Content="Deployment" HorizontalAlignment="Left" Height="26" Margin="25,10,0,0" VerticalAlignment="Top" Width="87" Background="#FF454A4C" Foreground="White" BorderThickness="2" Style="{StaticResource CleanButtons}" BorderBrush="White"/>
            <Button x:Name="BtnClose" Content="X" HorizontalAlignment="Right" Height="28" Margin="0,10,5,0" VerticalAlignment="Top" Width="27" FontFamily="Segoe UI Variable Display Semibold" Background="{x:Null}" FontSize="18" Foreground="White" BorderBrush="{x:Null}"/>
            <Button x:Name="BtnMin" Content="-" HorizontalAlignment="Right" Height="28" Margin="0,10,32,0" VerticalAlignment="Top" Width="27" FontFamily="Segoe UI Variable Display Semibold" Background="{x:Null}" FontSize="24" Foreground="White" BorderBrush="{x:Null}"/>
            <Label x:Name="LblStatus" Content="Waiting..." HorizontalAlignment="Right" Margin="0,1,71,0" VerticalAlignment="Top" Background="{x:Null}" FontFamily="Leelawadee" Foreground="#FF4FF307" FontSize="22"/>
        </Grid>
        <Grid x:Name="Deployment_Grid" Margin="0,50,0,0">
            <Border x:Name="Border_Clients" BorderBrush="#FF2B3842" BorderThickness="2,2,2,2" Margin="168,0,0,10" HorizontalAlignment="Left" Width="142"/>
            <Border x:Name="Border_Actions" BorderBrush="#FF2B3842" BorderThickness="2,2,2,2" Margin="10,0,0,10" HorizontalAlignment="Left" Width="142"/>
            <Border x:Name="Border_OOBE" BorderBrush="#FF2B3842" BorderThickness="2,2,2,2" Margin="326,0,0,10" HorizontalAlignment="Left" Width="142"/>
            <Border x:Name="Border_Apps" BorderBrush="#FF2B3842" BorderThickness="2,2,2,2" Margin="483,0,0,10" HorizontalAlignment="Left" Width="142"/>
            <Label x:Name="LblClients_Copy" Content="OOBE" HorizontalAlignment="Left" Height="26" Margin="334,15,0,0" VerticalAlignment="Top" Width="126" FontWeight="Bold" Foreground="#FF3D6EE6" FontSize="14" FontFamily="Leelawadee"/>
            <Label x:Name="LblDeploymentActions" Content="Actions" HorizontalAlignment="Left" Height="26" Margin="20,15,0,0" VerticalAlignment="Top" Width="126" FontWeight="Bold" Foreground="#FF3D6EE6" FontSize="14" FontFamily="Leelawadee"/>
            <Label x:Name="LblClients" Content="Client Select" HorizontalAlignment="Left" Height="26" Margin="176,15,0,0" VerticalAlignment="Top" Width="126" FontWeight="Bold" Foreground="#FF3D6EE6" FontSize="14" FontFamily="Leelawadee"/>
            <Label x:Name="LblApps" Content="Apps" HorizontalAlignment="Left" Height="26" Margin="493,15,0,0" VerticalAlignment="Top" Width="126" FontWeight="Bold" Foreground="#FF3D6EE6" FontSize="14" FontFamily="Leelawadee"/>
            <ListBox x:Name="ClientListBox" HorizontalAlignment="Left" Margin="178,119,0,17" d:ItemsSource="{d:SampleData ItemCount=5}" Background="Black" Foreground="White" Width="122" ScrollViewer.VerticalScrollBarVisibility="Auto" FontFamily="Leelawadee"/>
            <Button x:Name="BtnRunAll" Content="Run All" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="20,41,0,0" FontFamily="Leelawadee"/>
            <Button x:Name="BtnRepairWinget" Content="Repair Winget" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="20,72,0,0" FontFamily="Leelawadee"/>
            <Button x:Name="BtnInstallOffice" Content="Install O365" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="20,103,0,0" FontFamily="Leelawadee"/>
            <Button x:Name="BtnInstallLocalApps" Content="Install Local Apps" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="20,134,0,0" FontFamily="Leelawadee"/>
            <Button x:Name="BtnInstallDefaultWingetApps" Content="Install Default Winget" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="20,165,0,0" FontFamily="Leelawadee"/>
            <Button x:Name="BtnInstallCustomWingetApps" Content="Install Custom Winget" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="20,199,0,0" FontFamily="Leelawadee"/>
            <Button x:Name="BtnUninstallBloat" Content="Uninstall Bloat" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="20,230,0,0" FontFamily="Leelawadee"/>
            <Button x:Name="BtnUninstallLanguagePacks" Content="Uninstall Lng Packs" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="20,261,0,0" FontFamily="Leelawadee"/>
            <Button x:Name="BtnSetPowerOptions" Content="Set Power Options" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="20,292,0,0" FontFamily="Leelawadee"/>
            <Button x:Name="BtnSetTimeZone" Content="Set Timezone" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="20,323,0,0" FontFamily="Leelawadee"/>
            <Button x:Name="BtnClientChooser" Content="Re-Load Clients" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="178,41,0,0" FontFamily="Leelawadee"/>
            <Button x:Name="BtnManualClientSelect" Content="Manual Selection" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="178,81,0,0" FontFamily="Leelawadee"/>
            <Image x:Name="ImgM5Logo" HorizontalAlignment="Left" Height="110" Margin="640,19,0,0" VerticalAlignment="Top" Width="191" Source="https://www.startpage.com/av/proxy-image?piurl=https%3A%2F%2Faustinlogodesigns.com%2Fwp-content%2Fuploads%2F2021%2F03%2FMagna5.png&amp;sp=1767385950T18ce8b63c54018ffd07ee97aa3eb381391227e8f9098fcea21e743fca961a19b"/>
            <Label x:Name="LblCopyright" Content="Created By: Brandon Swarek" Height="27" VerticalAlignment="Bottom" Width="210" FontFamily="Leelawadee" FontSize="16" Foreground="White" HorizontalAlignment="Right"/>
            <Button x:Name="BtnNVIDIAApp" Content="NVIDIA App" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="493,41,0,0" FontFamily="Leelawadee"/>
            <Button x:Name="BtnAMDApp" Content="AMDApp" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="493,81,0,0" FontFamily="Leelawadee"/>
        </Grid>
    </Grid>
</Window>
"@

# 1. Show Splashscreen
$Splash = Load-VisualStudioXaml -RawXaml $splashXML
$Splash.Show()
Start-Sleep -Seconds 5
$Splash.Close()

# 2. Load main GUI object (This makes $Main exist!)
$Main = Load-VisualStudioXaml -RawXaml $mainXML

# --- FUNCTIONS SECTION ---

# --- Function from InstallDefaultWingetApps.ps1 ---
function Install-DefaultWingetApps {
    # Pre-defined list of IDs
    $Apps = @("Google.Chrome", "7zip.7zip", "VideoLAN.VLC")

    foreach ($App in $Apps) {
        # Process runs and displays output in its own console window area
        Start-Process winget -ArgumentList "install --id $App --silent --accept-source-agreements" -Wait -PassThru -NoNewWindow
    }

    return "Completed"
}


# --- Function from TestFunction.ps1 ---
function TestFunction {
	Write-Host "Hello, World!"
	Start-Sleep -Seconds 10
	Write-Host "Sleepy!"
}



# --- Function from Update-Status.ps1 ---
function Update-Status {
    param(
        [string]$Message,
        [ValidateSet("Busy", "Ready")]
        [string]$State
    )

    $LblStatus.Content = $Message

    if ($State -eq "Busy") {
        $LblStatus.Foreground = [System.Windows.Media.Brushes]::Red
    } else {
        $LblStatus.Foreground = [System.Windows.Media.Brushes]::LimeGreen
    }

    [System.Windows.Forms.Application]::DoEvents()
}


# --- UI ELEMENT MAPPING ---
$BtnInstallDefaultWingetApps = $Main.FindName("BtnInstallDefaultWingetApps")
$LblStatus         = $Main.FindName("LblStatus")


# --- BUTTON CLICK EVENTS ---
$BtnInstallDefaultWingetApps.Add_Click({
    Update-Status -Message "Busy..." -State "Busy"
    [System.Windows.Forms.Application]::DoEvents()
    Install-DefaultWingetApps
    Update-Status -Message "Ready..." -State "Ready"
})

# 3. OPEN THE WINDOW (Last Step)
$Main.ShowDialog()
