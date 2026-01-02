Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$inputXML = @"
<Window x:Name="Main_GUI" x:Class="DepthWPFFramework.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
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
        </Grid>
        <Grid x:Name="Deployment_Grid" Margin="0,50,0,0">
            <Border x:Name="Border_Clients" BorderBrush="#FF2B3842" BorderThickness="2,2,2,2" Margin="168,0,0,10" HorizontalAlignment="Left" Width="142">
                <ListBox x:Name="ClientListBox" HorizontalAlignment="Center" Margin="0,78,0,8" d:ItemsSource="{d:SampleData ItemCount=5}" Background="Black" Foreground="White" Width="122" ScrollViewer.VerticalScrollBarVisibility="Auto"/>
            </Border>
            <Border x:Name="Border_Actions" BorderBrush="#FF2B3842" BorderThickness="2,2,2,2" Margin="10,0,0,10" HorizontalAlignment="Left" Width="142"/>
            <Button x:Name="BtnRunAll" Content="Run All" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="20,41,0,0" FontFamily="Leelawadee"/>
            <Label x:Name="LblDeploymentActions" Content="Actions" HorizontalAlignment="Left" Height="26" Margin="20,15,0,0" VerticalAlignment="Top" Width="126" FontWeight="Bold" Foreground="#FF3D6EE6" FontSize="14" FontFamily="Leelawadee"/>
            <Label x:Name="LblClients" Content="Client Select" HorizontalAlignment="Left" Height="26" Margin="176,15,0,0" VerticalAlignment="Top" Width="126" FontWeight="Bold" Foreground="#FF3D6EE6" FontSize="14" FontFamily="Leelawadee"/>
            <Button x:Name="BtnRunAll_Copy" Content="Run All" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="20,72,0,0" FontFamily="Leelawadee"/>
            <Button x:Name="BtnRunAll_Copy1" Content="Run All" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="20,103,0,0" FontFamily="Leelawadee"/>
            <Button x:Name="BtnRunAll_Copy2" Content="Run All" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="20,134,0,0" FontFamily="Leelawadee"/>
            <Button x:Name="BtnRunAll_Copy3" Content="Run All" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="20,165,0,0" FontFamily="Leelawadee"/>
            <Button x:Name="BtnRunAll_Copy4" Content="Run All" HorizontalAlignment="Left" Height="26" VerticalAlignment="Top" Width="122" Background="#FF1C5971" Foreground="White" BorderThickness="1,1,1,1" Style="{StaticResource CleanButtons}" BorderBrush="White" Margin="20,41,0,0" FontFamily="Leelawadee"/>
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
        </Grid>
    </Grid>
</Window>
"@

# --- AUTOMATIC CLEANING SECTION ---
# This wipes out the Visual Studio 'junk' so PowerShell doesn't crash
$inputXML = $inputXML -replace 'mc:Ignorable="d"','' `
                      -replace "x:Class.*?[^\x20]*",' ' `
                      -replace "xmlns:local.*?[^\x20]*",' ' `
                      -replace 'd:ItemsSource=".*?"',' ' `
                      -replace 'd:SampleData=".*?"',' ' `
                      -replace 'd:DesignHeight=".*?"',' ' `
                      -replace 'd:DesignWidth=".*?"',' '

[xml]$xaml = $inputXML
$reader = New-Object System.Xml.XmlNodeReader $xaml
$Window = [Windows.Markup.XamlReader]::Load($reader)
$Window.ShowDialog()