<#
    .SYNOPSIS
        Robusta Worker - ChromeDriver Guncelleyici Kurumsal Arayuzu (WPF GUI)

    .DESCRIPTION
        Robusta RPA Worker sanal makineleri (Windows VM) icin gelistirilmis,
        harici kutuphane gerektirmeyen (zero-dependency) asil, kurumsal ve profesyonel
        WPF arayuzu. Mavi ve kurumsal slate tonlarinda, acilir cekmece (Expander) mimarisi
        ve donmayan PowerShell Runspace arka plan isleyisi ile calisir.
        Kullanicinin acik Chrome sekmelerine asla dokunmaz.
#>

[CmdletBinding()]
param(
    [string]$DriverDir = '',
    [string]$ChromeExePath = ''
)

# Gerekli .NET Assembly'leri
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# Script ve Core Engine konumu
$guiScriptDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($guiScriptDir)) {
    $guiScriptDir = (Get-Location).Path
}

$coreScriptPath = Join-Path $guiScriptDir 'ChromeDriverUpdater.ps1'
if (-not (Test-Path -LiteralPath $coreScriptPath)) {
    [System.Windows.MessageBox]::Show(
        "Cekirdek betik bulunamadi:`n$coreScriptPath",
        "Robusta ChromeDriver Updater - Hata",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Error
    )
    exit 1
}

# Core Engine fonksiyonlarini ice aktar
. $coreScriptPath -ImportOnly

# Yapilandirma yukle
$appConfig = Get-AppConfig
if (-not [string]::IsNullOrEmpty($DriverDir)) { $appConfig.DriverDir = $DriverDir }
if (-not [string]::IsNullOrEmpty($ChromeExePath)) { $appConfig.ChromeExePath = $ChromeExePath }

# XAML Tanimlamasi (Noble Corporate Light Theme - Deep Blue & Slate with Expandable Drawers)
$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Robusta • ChromeDriver"
        Height="540" Width="820"
        MinHeight="440" MinWidth="740"
        WindowStartupLocation="CenterScreen"
        Background="#F1F5F9"
        FontFamily="Segoe UI, -apple-system, Tahoma, Arial"
        TextOptions.TextFormattingMode="Display"
        UseLayoutRounding="True">

    <Window.Resources>
        <!-- Modern Corporate Dynamic Progress Bar Style -->
        <Style x:Key="CorporateProgressBar" TargetType="ProgressBar">
            <Setter Property="Height" Value="4"/>
            <Setter Property="Background" Value="#E2E8F0"/>
            <Setter Property="Foreground" Value="#1D4ED8"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ProgressBar">
                        <Border Background="{TemplateBinding Background}" CornerRadius="2" ClipToBounds="True">
                            <Grid x:Name="PART_Track">
                                <Border x:Name="PART_Indicator" HorizontalAlignment="Left" Background="{TemplateBinding Foreground}" CornerRadius="2"/>
                                <Border x:Name="IndeterminateGlow" Background="{TemplateBinding Foreground}" HorizontalAlignment="Left" Width="180" CornerRadius="2" Visibility="Collapsed">
                                    <Border.RenderTransform>
                                        <TranslateTransform x:Name="GlowTranslate" X="-180"/>
                                    </Border.RenderTransform>
                                </Border>
                            </Grid>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsIndeterminate" Value="True">
                                <Setter TargetName="PART_Indicator" Property="Visibility" Value="Collapsed"/>
                                <Setter TargetName="IndeterminateGlow" Property="Visibility" Value="Visible"/>
                                <Trigger.EnterActions>
                                    <BeginStoryboard>
                                        <Storyboard RepeatBehavior="Forever">
                                            <DoubleAnimation Storyboard.TargetName="GlowTranslate"
                                                             Storyboard.TargetProperty="X"
                                                             From="-180" To="850"
                                                             Duration="0:0:1.4"/>
                                        </Storyboard>
                                    </BeginStoryboard>
                                </Trigger.EnterActions>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Primary Action Button (Executive Cobalt Blue) -->
        <Style x:Key="PrimaryButton" TargetType="Button">
            <Setter Property="Background" Value="#1D4ED8"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="18,9"/>
            <Setter Property="FontSize" Value="12.5"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#1E40AF"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#172554"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Background" Value="#94A3B8"/>
                                <Setter Property="Cursor" Value="Arrow"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Secondary Action Button -->
        <Style x:Key="SecondaryButton" TargetType="Button">
            <Setter Property="Background" Value="#FFFFFF"/>
            <Setter Property="Foreground" Value="#1E293B"/>
            <Setter Property="BorderBrush" Value="#CBD5E1"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="14,7"/>
            <Setter Property="FontSize" Value="11.5"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="secBorder" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="6" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="secBorder" Property="Background" Value="#F1F5F9"/>
                                <Setter TargetName="secBorder" Property="BorderBrush" Value="#94A3B8"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="secBorder" Property="Background" Value="#E2E8F0"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="secBorder" Property="Opacity" Value="0.45"/>
                                <Setter Property="Cursor" Value="Arrow"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Small Utility Button -->
        <Style x:Key="SmallUtilityButton" TargetType="Button">
            <Setter Property="Background" Value="#FFFFFF"/>
            <Setter Property="Foreground" Value="#475569"/>
            <Setter Property="BorderBrush" Value="#CBD5E1"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,4"/>
            <Setter Property="FontSize" Value="10.5"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="smBorder" Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="4" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="smBorder" Property="Background" Value="#F1F5F9"/>
                                <Setter TargetName="smBorder" Property="BorderBrush" Value="#94A3B8"/>
                                <Setter Property="Foreground" Value="#1E293B"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="smBorder" Property="Background" Value="#E2E8F0"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="smBorder" Property="Opacity" Value="0.45"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Textbox Style -->
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#FFFFFF"/>
            <Setter Property="Foreground" Value="#0F172A"/>
            <Setter Property="BorderBrush" Value="#CBD5E1"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="9,5"/>
            <Setter Property="FontSize" Value="11.5"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
        </Style>

        <!-- Checkbox Style -->
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#334155"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="Margin" Value="0,0,18,0"/>
        </Style>

        <!-- Corporate Expander (Drawer / Cekmece) Style -->
        <Style x:Key="CorporateExpander" TargetType="Expander">
            <Setter Property="Background" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="#E2E8F0"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Margin" Value="0,0,0,10"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Expander">
                        <Border Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="8">
                            <Border.Effect>
                                <DropShadowEffect Color="#0F172A" Direction="270" ShadowDepth="1" BlurRadius="5" Opacity="0.03"/>
                            </Border.Effect>
                            <Grid>
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/>
                                    <RowDefinition Height="*"/>
                                </Grid.RowDefinitions>
                                <ToggleButton Grid.Row="0"
                                              IsChecked="{Binding IsExpanded, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}"
                                              Cursor="Hand" Background="#FFFFFF" BorderThickness="0">
                                    <ToggleButton.Template>
                                        <ControlTemplate TargetType="ToggleButton">
                                            <Border x:Name="tbBorder" Background="{TemplateBinding Background}" CornerRadius="8,8,0,0" Padding="14,10">
                                                <ContentPresenter/>
                                            </Border>
                                            <ControlTemplate.Triggers>
                                                <Trigger Property="IsMouseOver" Value="True">
                                                    <Setter TargetName="tbBorder" Property="Background" Value="#F8FAFC"/>
                                                </Trigger>
                                            </ControlTemplate.Triggers>
                                        </ControlTemplate>
                                    </ToggleButton.Template>
                                    <DockPanel LastChildFill="True">
                                        <Path x:Name="Arrow" DockPanel.Dock="Right" Data="M7.41 8.59L12 13.17l4.59-4.58L18 10l-6 6-6-6 1.41-1.41z"
                                              Fill="#64748B" Width="11" Height="11" Stretch="Uniform" VerticalAlignment="Center" Margin="10,0,0,0" RenderTransformOrigin="0.5,0.5">
                                            <Path.RenderTransform>
                                                <RotateTransform Angle="0"/>
                                            </Path.RenderTransform>
                                        </Path>
                                        <ContentPresenter ContentSource="Header" VerticalAlignment="Center"/>
                                    </DockPanel>
                                </ToggleButton>
                                <Border x:Name="ExpContent" Grid.Row="1" Visibility="Collapsed"
                                        BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="0,1,0,0"
                                        Background="#F8FAFC" Padding="14,12" CornerRadius="0,0,8,8">
                                    <ContentPresenter/>
                                </Border>
                            </Grid>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsExpanded" Value="True">
                                <Setter TargetName="ExpContent" Property="Visibility" Value="Visible"/>
                                <Setter TargetName="Arrow" Property="RenderTransform">
                                    <Setter.Value>
                                        <RotateTransform Angle="180"/>
                                    </Setter.Value>
                                </Setter>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid Margin="18">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/> <!-- Minimal Header -->
            <RowDefinition Height="*"/>    <!-- Scrollable Body with Cards and Drawers -->
            <RowDefinition Height="Auto"/> <!-- Minimal Footer -->
        </Grid.RowDefinitions>

        <!-- 1. MINIMAL EXECUTIVE HEADER -->
        <Border Grid.Row="0" Background="#FFFFFF" CornerRadius="8" Padding="16,12" Margin="0,0,0,12" BorderBrush="#E2E8F0" BorderThickness="1">
            <Border.Effect>
                <DropShadowEffect Color="#0F172A" Direction="270" ShadowDepth="1" BlurRadius="5" Opacity="0.03"/>
            </Border.Effect>
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <Border Background="#1E40AF" CornerRadius="4" Padding="7,3" Margin="0,0,10,0">
                        <TextBlock Text="ROBUSTA" Foreground="White" FontWeight="Bold" FontSize="11"/>
                    </Border>
                    <TextBlock Text="ChromeDriver Updater" FontSize="16" FontWeight="Bold" Foreground="#0F172A" VerticalAlignment="Center"/>
                </StackPanel>

                <!-- Status Pill -->
                <Border Name="BadgeStatus" Grid.Column="1" Background="#EFF6FF" CornerRadius="14" Padding="12,5" VerticalAlignment="Center" BorderBrush="#BFDBFE" BorderThickness="1">
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                        <Ellipse Name="DotStatus" Width="7" Height="7" Fill="#1D4ED8" Margin="0,0,6,0" VerticalAlignment="Center"/>
                        <TextBlock Name="TxtBadgeStatus" Text="DENETLENIYOR" Foreground="#1E40AF" FontWeight="Bold" FontSize="10.5"/>
                    </StackPanel>
                </Border>
            </Grid>
        </Border>

        <!-- 2. SCROLLABLE BODY -->
        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Margin="0,0,0,10" Focusable="False">
            <StackPanel>
                <!-- STATUS METRICS & PRIMARY ACTIONS -->
                <Border Background="#FFFFFF" CornerRadius="8" Padding="16" Margin="0,0,0,10" BorderBrush="#E2E8F0" BorderThickness="1">
                    <Border.Effect>
                        <DropShadowEffect Color="#0F172A" Direction="270" ShadowDepth="1" BlurRadius="5" Opacity="0.03"/>
                    </Border.Effect>
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <!-- 3-Column Metrics -->
                        <Grid Grid.Row="0" Margin="0,0,0,14">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="1"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="1"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>

                            <!-- Chrome Column -->
                            <StackPanel Grid.Column="0" Margin="4,0,12,0">
                                <StackPanel Orientation="Horizontal" Margin="0,0,0,4">
                                    <Path Data="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 17.93c-3.95-.49-7-3.85-7-7.93 0-.62.08-1.21.21-1.79L9 15v1c0 1.1.9 2 2 2v1.93zm6.9-2.54c-.26-.81-1-1.39-1.9-1.39h-1v-3c0-.55-.45-1-1-1H8v-2h2c.55 0 1-.45 1-1V7h2c1.1 0 2-.9 2-2v-.41c2.93 1.19 5 4.06 5 7.41 0 2.08-.8 3.97-2.1 5.39z" Fill="#1E40AF" Width="12" Height="12" Stretch="Uniform" Margin="0,0,6,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="GOOGLE CHROME" FontSize="10" FontWeight="Bold" Foreground="#1E40AF"/>
                                </StackPanel>
                                <TextBlock Name="TxtChromeVer" Text="..." FontSize="20" FontWeight="SemiBold" Foreground="#0F172A"/>
                                <TextBlock Name="TxtChromeSub" Text="Sistem Tarayicisi" FontSize="10.5" Foreground="#64748B" Margin="0,2,0,0" TextTrimming="CharacterEllipsis"/>
                            </StackPanel>

                            <!-- Separator 1 -->
                            <Rectangle Grid.Column="1" Fill="#E2E8F0" Margin="0,2,0,2"/>

                            <!-- Driver Column -->
                            <StackPanel Grid.Column="2" Margin="14,0,12,0">
                                <StackPanel Orientation="Horizontal" Margin="0,0,0,4">
                                    <Path Data="M19 8h-1V6c0-1.66-1.34-3-3-3h-6C7.34 3 6 4.34 6 6v2H5c-1.1 0-2 .9-2 2v8c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2v-8c0-1.1-.9-2-2-2zM8 6c0-.55.45-1 1-1h6c.55 0 1 .45 1 1v2H8V6zm11 12H5v-8h14v8z" Fill="#0369A1" Width="12" Height="12" Stretch="Uniform" Margin="0,0,6,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="HEDEF SURUCU" FontSize="10" FontWeight="Bold" Foreground="#0369A1"/>
                                </StackPanel>
                                <TextBlock Name="TxtDriverVer" Text="..." FontSize="20" FontWeight="SemiBold" Foreground="#0F172A"/>
                                <TextBlock Name="TxtDriverSub" Text="C:\RobustaWorker\driver" FontSize="10.5" Foreground="#64748B" Margin="0,2,0,0" TextTrimming="CharacterEllipsis"/>
                            </StackPanel>

                            <!-- Separator 2 -->
                            <Rectangle Grid.Column="3" Fill="#E2E8F0" Margin="0,2,0,2"/>

                            <!-- Match Status Column -->
                            <Border Name="CardMatch" Grid.Column="4" Margin="14,0,4,0">
                                <StackPanel>
                                    <StackPanel Orientation="Horizontal" Margin="0,0,0,4">
                                        <Path Name="PathMatchIcon" Data="M12 2L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-3zm-2 16l-4-4 1.41-1.41L10 15.17l6.59-6.59L18 10l-8 8z" Fill="#4338CA" Width="12" Height="12" Stretch="Uniform" Margin="0,0,6,0" VerticalAlignment="Center"/>
                                        <TextBlock Text="DURUM" FontSize="10" FontWeight="Bold" Foreground="#4338CA"/>
                                        <TextBlock Name="TxtMatchTag" Text="" FontSize="10" Foreground="#94A3B8" Margin="4,0,0,0"/>
                                    </StackPanel>
                                    <TextBlock Name="TxtMatchTitle" Text="Bekleniyor" FontSize="16" FontWeight="Bold" Foreground="#0F172A"/>
                                    <TextBlock Name="TxtMatchDesc" Text="Denetim bekleniyor" FontSize="10.5" Foreground="#64748B" Margin="0,2,0,0" TextTrimming="CharacterEllipsis"/>
                                </StackPanel>
                            </Border>
                        </Grid>

                        <!-- Primary Action Buttons Row -->
                        <Border Grid.Row="1" BorderBrush="#F1F5F9" BorderThickness="0,1,0,0" Padding="0,12,0,0">
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="Auto"/>
                                </Grid.ColumnDefinitions>
                                <Button Name="BtnUpdate" Style="{StaticResource PrimaryButton}" HorizontalAlignment="Left">
                                    <StackPanel Orientation="Horizontal">
                                        <Path Data="M19 9h-4V3H9v6H5l7 7 7-7zM5 18v2h14v-2H5z" Fill="#FFFFFF" Width="13" Height="13" Stretch="Uniform" Margin="0,0,8,0" VerticalAlignment="Center"/>
                                        <TextBlock Text="Senkronize Et" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Button>
                                <Button Name="BtnCheck" Style="{StaticResource SecondaryButton}" Grid.Column="1">
                                    <StackPanel Orientation="Horizontal">
                                        <Path Data="M12 4V1L8 5l4 4V6c3.31 0 6 2.69 6 6 0 1.01-.25 1.97-.7 2.8l1.46 1.46C19.54 15.03 20 13.57 20 12c0-4.42-3.58-8-8-8zm0 14c-3.31 0-6-2.69-6-6 0-1.01.25-1.97.7-2.8L5.24 7.74C4.46 8.97 4 10.43 4 12c0 4.42 3.58 8 8 8v3l4-4-4-4v3z" Fill="#1E40AF" Width="12" Height="12" Stretch="Uniform" Margin="0,0,8,0" VerticalAlignment="Center"/>
                                        <TextBlock Text="Denetle" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Button>
                            </Grid>
                        </Border>
                    </Grid>
                </Border>

                <!-- DRAWER 1: CONFIG & ADVANCED OPTIONS -->
                <Expander Name="ExpConfig" Style="{StaticResource CorporateExpander}" IsExpanded="False">
                    <Expander.Header>
                        <DockPanel LastChildFill="True">
                            <Path Data="M19.14 12.94c.04-.3.06-.61.06-.94 0-.32-.02-.64-.07-.94l2.03-1.58c.18-.14.23-.41.12-.61l-1.92-3.32c-.12-.22-.37-.29-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54c-.04-.24-.24-.41-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.05.3-.09.63-.09.94s.02.64.07.94l-2.03 1.58c-.18.14-.23.41-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6 3.6z"
                                  Fill="#475569" Width="13" Height="13" Stretch="Uniform" Margin="0,0,8,0" VerticalAlignment="Center"/>
                            <TextBlock Text="Dizinler ve Gelismis Ayarlar" FontSize="12" FontWeight="SemiBold" Foreground="#1E293B" VerticalAlignment="Center"/>
                        </DockPanel>
                    </Expander.Header>
                    <StackPanel>
                        <!-- Driver Path -->
                        <Grid Margin="0,0,0,8">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="120"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Text="Driver Dizini:" VerticalAlignment="Center" Foreground="#475569" FontSize="11" FontWeight="SemiBold"/>
                            <TextBox Name="TxtDriverDir" Grid.Column="1" Margin="4,0,6,0"/>
                            <Button Name="BtnBrowseDriver" Style="{StaticResource SecondaryButton}" Grid.Column="2" Content="Gozat..." Margin="0,0,4,0" Padding="10,5"/>
                            <Button Name="BtnOpenDriver" Style="{StaticResource SecondaryButton}" Grid.Column="3" Content="Ac" Padding="10,5"/>
                        </Grid>

                        <!-- Chrome Path -->
                        <Grid Margin="0,0,0,10">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="120"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Text="Chrome.exe Yolu:" VerticalAlignment="Center" Foreground="#475569" FontSize="11" FontWeight="SemiBold"/>
                            <TextBox Name="TxtChromeExe" Grid.Column="1" Margin="4,0,6,0"/>
                            <Button Name="BtnBrowseChrome" Style="{StaticResource SecondaryButton}" Grid.Column="2" Content="Gozat..." Margin="0,0,4,0" Padding="10,5"/>
                            <Button Name="BtnAutoDetect" Style="{StaticResource SecondaryButton}" Grid.Column="3" Content="Otomatik Bul" Padding="10,5"/>
                        </Grid>

                        <!-- Checkbox Options -->
                        <WrapPanel Orientation="Horizontal" Margin="0,2,0,10">
                            <CheckBox Name="ChkUpdateBrowserFirst" Content="Once gercek Chrome'u UIA ile ac ve guncelle (Relaunch)" IsChecked="True"/>
                            <CheckBox Name="ChkAutoKill" Content="Kilitli ChromeDriver sureclerini kapat" IsChecked="True"/>
                            <CheckBox Name="ChkCleanTarget" Content="Artik dosyalari temizle (.log, .txt)" IsChecked="True"/>
                            <CheckBox Name="ChkForce" Content="Zorla indir (Force)" IsChecked="False"/>
                        </WrapPanel>

                        <!-- Utility Action Buttons -->
                        <Border BorderBrush="#E2E8F0" BorderThickness="0,1,0,0" Padding="0,8,0,0">
                            <StackPanel Orientation="Horizontal">
                                <Button Name="BtnKillProcesses" Style="{StaticResource SecondaryButton}" Margin="0,0,8,0" Padding="10,5">
                                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                        <Path Data="M6 6h12v12H6z" Fill="#DC2626" Width="9" Height="9" Stretch="Uniform" Margin="0,0,6,0" VerticalAlignment="Center"/>
                                        <TextBlock Text="Kilitli ChromeDriver'i Kapat" FontSize="11" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Button>
                                <Button Name="BtnCleanTarget" Style="{StaticResource SecondaryButton}" Margin="0,0,8,0" Padding="10,5">
                                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                        <Path Data="M19.36 10.04l-4.4-4.4a1.996 1.996 0 0 0-2.83 0l-1.41 1.41 5.66 5.66 1.41-1.41c.78-.78.78-2.05 0-2.83zM3 21h8l8.04-8.04-5.66-5.66L3 17.66V21z" Fill="#475569" Width="10" Height="10" Stretch="Uniform" Margin="0,0,6,0" VerticalAlignment="Center"/>
                                        <TextBlock Text="Hedef Klasoru Temizle" FontSize="11" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Button>
                                <Button Name="BtnOpenLogs" Style="{StaticResource SecondaryButton}" Padding="10,5">
                                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                        <Path Data="M10 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2h-8l-2-2z" Fill="#2563EB" Width="10" Height="10" Stretch="Uniform" Margin="0,0,6,0" VerticalAlignment="Center"/>
                                        <TextBlock Text="Log Klasorunu Ac" FontSize="11" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Button>
                            </StackPanel>
                        </Border>
                    </StackPanel>
                </Expander>

                <!-- DRAWER 2: AUDIT LOG CONSOLE -->
                <Expander Name="ExpLog" Style="{StaticResource CorporateExpander}" IsExpanded="False">
                    <Expander.Header>
                        <DockPanel LastChildFill="True">
                            <Path Data="M4 17h16v2H4zm13-6.17L15.59 9.4 12 13 8.41 9.4 7 10.83l5 5 5-5zM12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z"
                                  Fill="#475569" Width="13" Height="13" Stretch="Uniform" Margin="0,0,8,0" VerticalAlignment="Center"/>
                            <TextBlock Text="Islem Gunlugu (Audit Log)" FontSize="12" FontWeight="SemiBold" Foreground="#1E293B" VerticalAlignment="Center"/>
                        </DockPanel>
                    </Expander.Header>
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="180"/>
                        </Grid.RowDefinitions>

                        <!-- Log Toolbar -->
                        <Border Grid.Row="0" Background="#F1F5F9" CornerRadius="4,4,0,0" Padding="8,5" BorderBrush="#E2E8F0" BorderThickness="1,1,1,0">
                            <Grid>
                                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                    <Ellipse Width="6" Height="6" Fill="#059669" Margin="0,0,6,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="CANLI KONSOL" FontSize="10" FontWeight="Bold" Foreground="#475569" VerticalAlignment="Center"/>
                                </StackPanel>
                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                                    <Button Name="BtnCopyLog" Style="{StaticResource SmallUtilityButton}" Content="Kopyala" Margin="0,0,4,0"/>
                                    <Button Name="BtnClearLog" Style="{StaticResource SmallUtilityButton}" Content="Temizle" Margin="0,0,4,0"/>
                                    <Button Name="BtnOpenLogFile" Style="{StaticResource SmallUtilityButton}" Content="Dosyayi Ac"/>
                                </StackPanel>
                            </Grid>
                        </Border>

                        <!-- Text Area -->
                        <TextBox Name="TxtLogConsole" Grid.Row="1"
                                 Background="#F8FAFC" Foreground="#0F172A"
                                 FontFamily="Consolas, Cascadia Mono, Courier New" FontSize="11"
                                 IsReadOnly="True" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"
                                 BorderBrush="#E2E8F0" BorderThickness="1,0,1,1" Padding="10" TextWrapping="Wrap"/>
                    </Grid>
                </Expander>
            </StackPanel>
        </ScrollViewer>

        <!-- 3. MINIMAL FOOTER -->
        <Grid Grid.Row="2">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <!-- Progress Bar -->
            <ProgressBar Name="ProgressBarMain" Style="{StaticResource CorporateProgressBar}" Grid.Row="0" Margin="0,0,0,6"/>

            <!-- Status Details -->
            <Grid Grid.Row="1">
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Name="TxtFooterStatus" Text="Hazir." FontSize="11" Foreground="#475569" FontWeight="SemiBold"/>
                    <TextBlock Name="TxtLastUpdate" Text="" FontSize="10.5" Foreground="#94A3B8" Margin="10,0,0,0"/>
                </StackPanel>
                <TextBlock Text="v2.0" FontSize="10.5" Foreground="#94A3B8" HorizontalAlignment="Right" VerticalAlignment="Center"/>
            </Grid>
        </Grid>
    </Grid>
</Window>
'@

# XAML Yukle
$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# Kontrol Referanslari
$badgeStatus      = $window.FindName('BadgeStatus')
$dotStatus        = $window.FindName('DotStatus')
$txtBadgeStatus   = $window.FindName('TxtBadgeStatus')

$txtChromeVer     = $window.FindName('TxtChromeVer')
$txtChromeSub     = $window.FindName('TxtChromeSub')
$txtDriverVer     = $window.FindName('TxtDriverVer')
$txtDriverSub     = $window.FindName('TxtDriverSub')

$cardMatch        = $window.FindName('CardMatch')
$pathMatchIcon    = $window.FindName('PathMatchIcon')
$txtMatchTag      = $window.FindName('TxtMatchTag')
$txtMatchTitle    = $window.FindName('TxtMatchTitle')
$txtMatchDesc     = $window.FindName('TxtMatchDesc')

$expConfig        = $window.FindName('ExpConfig')
$expLog           = $window.FindName('ExpLog')

$txtDriverDir     = $window.FindName('TxtDriverDir')
$btnBrowseDriver  = $window.FindName('BtnBrowseDriver')
$btnOpenDriver    = $window.FindName('BtnOpenDriver')

$txtChromeExe     = $window.FindName('TxtChromeExe')
$btnBrowseChrome  = $window.FindName('BtnBrowseChrome')
$btnAutoDetect    = $window.FindName('BtnAutoDetect')

$chkUpdateBrowserFirst = $window.FindName('ChkUpdateBrowserFirst')
$chkAutoKill           = $window.FindName('ChkAutoKill')
$chkCleanTarget        = $window.FindName('ChkCleanTarget')
$chkForce              = $window.FindName('ChkForce')

$btnUpdate        = $window.FindName('BtnUpdate')
$btnCheck         = $window.FindName('BtnCheck')
$btnKillProcesses = $window.FindName('BtnKillProcesses')
$btnCleanTarget   = $window.FindName('BtnCleanTarget')
$btnOpenLogs      = $window.FindName('BtnOpenLogs')

$btnCopyLog       = $window.FindName('BtnCopyLog')
$btnClearLog      = $window.FindName('BtnClearLog')
$btnOpenLogFile   = $window.FindName('BtnOpenLogFile')
$txtLogConsole    = $window.FindName('TxtLogConsole')

$progressBarMain  = $window.FindName('ProgressBarMain')
$txtFooterStatus  = $window.FindName('TxtFooterStatus')
$txtLastUpdate    = $window.FindName('TxtLastUpdate')

# Kontrolleri Mevcut Ayarlarla Doldur
$txtDriverDir.Text   = $appConfig.DriverDir
$txtChromeExe.Text   = $appConfig.ChromeExePath
$chkUpdateBrowserFirst.IsChecked = if ($null -ne $appConfig.PSObject.Properties['UpdateBrowserFirst']) { [bool]$appConfig.UpdateBrowserFirst } else { $true }
$chkAutoKill.IsChecked           = $appConfig.AutoKillProcesses
$chkCleanTarget.IsChecked        = $appConfig.CleanTarget
$chkForce.IsChecked              = $appConfig.Force

if ($appConfig.LastUpdated) {
    $txtLastUpdate.Text = "Son Guncelleme: $($appConfig.LastUpdated)"
}

# Tum Eylem Butonlari Listesi
$actionButtons = @($btnUpdate, $btnCheck, $btnKillProcesses, $btnCleanTarget, $btnBrowseDriver, $btnOpenDriver, $btnBrowseChrome, $btnAutoDetect)

function Set-ActionButtonsState {
    param([bool]$Enabled)
    foreach ($btn in $actionButtons) {
        if ($btn) { $btn.IsEnabled = $Enabled }
    }
}

function Save-CurrentGuiConfig {
    $cfg = Get-AppConfig
    $cfg.DriverDir          = $txtDriverDir.Text.Trim()
    $cfg.ChromeExePath      = $txtChromeExe.Text.Trim()
    $cfg.UpdateBrowserFirst = [bool]$chkUpdateBrowserFirst.IsChecked
    $cfg.AutoKillProcesses  = [bool]$chkAutoKill.IsChecked
    $cfg.CleanTarget        = [bool]$chkCleanTarget.IsChecked
    $cfg.Force              = [bool]$chkForce.IsChecked
    Save-AppConfig -Config $cfg
}

function Update-GuiStatusCards {
    param([psobject]$StatusInfo)

    if ($StatusInfo.ChromeVersion) {
        $txtChromeVer.Text = $StatusInfo.ChromeVersion
        $txtChromeSub.Text = "Sistem Tarayicisi"
        $txtChromeSub.ToolTip = $StatusInfo.ChromeExePath
    } else {
        $txtChromeVer.Text = "Bulunamadi"
        $txtChromeSub.Text = "Tespit Edilemedi"
        $txtChromeSub.ToolTip = "chrome.exe tespit edilemedi"
    }

    if ($StatusInfo.DriverVersion) {
        $txtDriverVer.Text = $StatusInfo.DriverVersion
        $txtDriverSub.Text = "C:\RobustaWorker\driver"
        $txtDriverSub.ToolTip = $StatusInfo.DriverExePath
    } else {
        $txtDriverVer.Text = "Bulunamadi"
        $txtDriverSub.Text = "Surucu Yok"
        $txtDriverSub.ToolTip = "Hedefte chromedriver.exe bulunamadi"
    }

    $conv = [System.Windows.Media.BrushConverter]::new()

    switch ($StatusInfo.Status) {
        'UpToDate' {
            $badgeStatus.Background    = $conv.ConvertFromString('#ECFDF5')
            $badgeStatus.BorderBrush   = $conv.ConvertFromString('#A7F3D0')
            $dotStatus.Fill            = $conv.ConvertFromString('#059669')
            $txtBadgeStatus.Text       = "GUNCEL"
            $txtBadgeStatus.Foreground = $conv.ConvertFromString('#065F46')

            $cardMatch.BorderBrush     = $conv.ConvertFromString('#10B981')
            $pathMatchIcon.Fill        = $conv.ConvertFromString('#059669')
            $txtMatchTitle.Text        = "Senkronize"
            $txtMatchTitle.Foreground  = $conv.ConvertFromString('#047857')
            $txtMatchDesc.Text         = "Surum eslesmesi tam"
        }
        'UpdateNeeded' {
            $badgeStatus.Background    = $conv.ConvertFromString('#FFFBEB')
            $badgeStatus.BorderBrush   = $conv.ConvertFromString('#FDE68A')
            $dotStatus.Fill            = $conv.ConvertFromString('#D97706')
            $txtBadgeStatus.Text       = "GUNCELLEME GEREKLI"
            $txtBadgeStatus.Foreground = $conv.ConvertFromString('#92400E')

            $cardMatch.BorderBrush     = $conv.ConvertFromString('#F59E0B')
            $pathMatchIcon.Fill        = $conv.ConvertFromString('#D97706')
            $txtMatchTitle.Text        = "Uyumsuz"
            $txtMatchTitle.Foreground  = $conv.ConvertFromString('#B45309')
            $txtMatchDesc.Text         = "Guncelleme gerekli"
        }
        'DriverMissing' {
            $badgeStatus.Background    = $conv.ConvertFromString('#FEF2F2')
            $badgeStatus.BorderBrush   = $conv.ConvertFromString('#FECACA')
            $dotStatus.Fill            = $conv.ConvertFromString('#DC2626')
            $txtBadgeStatus.Text       = "SURUCU EKSIK"
            $txtBadgeStatus.Foreground = $conv.ConvertFromString('#991B1B')

            $cardMatch.BorderBrush     = $conv.ConvertFromString('#EF4444')
            $pathMatchIcon.Fill        = $conv.ConvertFromString('#DC2626')
            $txtMatchTitle.Text        = "Surucu Eksik"
            $txtMatchTitle.Foreground  = $conv.ConvertFromString('#B91C1C')
            $txtMatchDesc.Text         = "Hedefte chromedriver yok"
        }
        'ChromeNotFound' {
            $badgeStatus.Background    = $conv.ConvertFromString('#FEF2F2')
            $badgeStatus.BorderBrush   = $conv.ConvertFromString('#FECACA')
            $dotStatus.Fill            = $conv.ConvertFromString('#DC2626')
            $txtBadgeStatus.Text       = "CHROME EKSIK"
            $txtBadgeStatus.Foreground = $conv.ConvertFromString('#991B1B')

            $cardMatch.BorderBrush     = $conv.ConvertFromString('#EF4444')
            $pathMatchIcon.Fill        = $conv.ConvertFromString('#DC2626')
            $txtMatchTitle.Text        = "Chrome Yok"
            $txtMatchTitle.Foreground  = $conv.ConvertFromString('#B91C1C')
            $txtMatchDesc.Text         = "Chrome dosya yolu belirtilmeli"
        }
        default {
            $badgeStatus.Background    = $conv.ConvertFromString('#EFF6FF')
            $badgeStatus.BorderBrush   = $conv.ConvertFromString('#BFDBFE')
            $dotStatus.Fill            = $conv.ConvertFromString('#1D4ED8')
            $txtBadgeStatus.Text       = "DENETLENIYOR"
            $txtBadgeStatus.Foreground = $conv.ConvertFromString('#1E40AF')

            $cardMatch.BorderBrush     = $conv.ConvertFromString('#E2E8F0')
            $pathMatchIcon.Fill        = $conv.ConvertFromString('#1E40AF')
            $txtMatchTitle.Text        = "Bekleniyor"
            $txtMatchTitle.Foreground  = $conv.ConvertFromString('#0F172A')
            $txtMatchDesc.Text         = "Surum denetimi bekleniyor"
        }
    }
}

# ----------------- ASENKRON GOREV YONETIMI (RUNSPACE) -----------------

$activeRunspace = $null
$activePowerShell = $null

$uiTimer = New-Object System.Windows.Threading.DispatcherTimer
$uiTimer.Interval = [TimeSpan]::FromMilliseconds(80)

# Ortak paylasilan senkronizasyon nesnesi
$sharedState = [hashtable]::Synchronized(@{
    Logs            = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
    StatusText      = "Hazir."
    StatusLevel     = "IDLE"
    Progress        = 0
    IsIndeterminate = $false
    IsFinished      = $false
    Result          = $null
    TaskType        = ''
})

$uiTimer.Add_Tick({
    # 1. Loglari siradan cek ve konsola bas
    while ($sharedState.Logs.Count -gt 0) {
        $line = $sharedState.Logs[0]
        $sharedState.Logs.RemoveAt(0)
        $txtLogConsole.AppendText("$line`r`n")
        $txtLogConsole.ScrollToEnd()
    }

    # 2. Durum metni ve progress bar guncelle
    $txtFooterStatus.Text = $sharedState.StatusText
    $progressBarMain.IsIndeterminate = $sharedState.IsIndeterminate
    if (-not $sharedState.IsIndeterminate) {
        $progressBarMain.Value = $sharedState.Progress
    }

    # 3. Islem bitti mi kontrol et
    if ($sharedState.IsFinished) {
        $uiTimer.Stop()
        $progressBarMain.IsIndeterminate = $false

        # Gorsel Dil (Visual Language):
        # Basari   -> Net ve Canli Yesil (#16A34A / #15803D)
        # Hata     -> Belirgin Kirmizi    (#DC2626 / #B91C1C)
        # Uyari    -> Kurumsal Amber     (#D97706 / #B45309)
        # Normal   -> Kurumsal Mavi      (#1D4ED8 / #475569)
        $conv = New-Object System.Windows.Media.BrushConverter
        if ($sharedState.StatusLevel -eq 'SUCCESS') {
            $progressBarMain.Foreground = $conv.ConvertFromString('#16A34A')
            $progressBarMain.Value = 100
            $txtFooterStatus.Foreground = $conv.ConvertFromString('#15803D')
        } elseif ($sharedState.StatusLevel -eq 'ERROR') {
            $progressBarMain.Foreground = $conv.ConvertFromString('#DC2626')
            $progressBarMain.Value = 100
            $txtFooterStatus.Foreground = $conv.ConvertFromString('#B91C1C')
        } elseif ($sharedState.StatusLevel -eq 'WARN') {
            $progressBarMain.Foreground = $conv.ConvertFromString('#D97706')
            $progressBarMain.Value = 100
            $txtFooterStatus.Foreground = $conv.ConvertFromString('#B45309')
        } else {
            $progressBarMain.Foreground = $conv.ConvertFromString('#1D4ED8')
            $txtFooterStatus.Foreground = $conv.ConvertFromString('#475569')
        }

        # Runspace temizligi
        if ($activePowerShell) {
            try { $null = $activePowerShell.EndInvoke($script:asyncResultHandle) } catch {}
            $activePowerShell.Dispose()
            $activePowerShell = $null
        }
        if ($activeRunspace) {
            try { $activeRunspace.Close(); $activeRunspace.Dispose() } catch {}
            $activeRunspace = $null
        }

        # Butonlari yeniden aktif et
        Set-ActionButtonsState -Enabled $true

        # Eger guncelleme veya kontrol islemi bittiyse durum kartlarini guncelle
        if ($sharedState.TaskType -in @('Update', 'Check')) {
            $inspection = Get-ChromeDriverInspectionStatus `
                -DriverDir $txtDriverDir.Text.Trim() `
                -ChromeExePath $txtChromeExe.Text.Trim()
            Update-GuiStatusCards -StatusInfo $inspection
        }

        # Son guncelleme saatini tazele
        $latestCfg = Get-AppConfig
        if ($latestCfg.LastUpdated) {
            $txtLastUpdate.Text = "Son Guncelleme: $($latestCfg.LastUpdated)"
        }
    }
})

function Start-GuiBackgroundTask {
    param(
        [Parameter(Mandatory)][string]$TaskType,
        [Parameter(Mandatory)][scriptblock]$WorkerScript,
        [hashtable]$TaskOptions = @{}
    )

    if ($activeRunspace -ne $null) { return }

    Set-ActionButtonsState -Enabled $false
    $sharedState.Logs.Clear()
    $sharedState.Progress = 0
    $sharedState.IsIndeterminate = $true
    $sharedState.IsFinished = $false
    $sharedState.TaskType = $TaskType
    $sharedState.StatusText = "Islem baslatiliyor..."
    $sharedState.StatusLevel = "RUNNING"
    $sharedState.Result = $null

    # Islem baslarken progress bar'i ve footer'i kurumsal maviye sifirla
    $conv = New-Object System.Windows.Media.BrushConverter
    $progressBarMain.Foreground = $conv.ConvertFromString('#1D4ED8')
    $txtFooterStatus.Foreground = $conv.ConvertFromString('#475569')

    $activeRunspace = [RunspaceFactory]::CreateRunspace()
    $activeRunspace.Open()

    $activePowerShell = [PowerShell]::Create()
    $activePowerShell.Runspace = $activeRunspace

    $null = $activePowerShell.AddScript($WorkerScript)
    $null = $activePowerShell.AddArgument($sharedState)
    $null = $activePowerShell.AddArgument($coreScriptPath)
    $null = $activePowerShell.AddArgument($TaskOptions)

    $script:asyncResultHandle = $activePowerShell.BeginInvoke()
    $uiTimer.Start()
}

# ----------------- BUTON ETKINLIKLERI (EVENT HANDLERS) -----------------

# 1. ChromeDriver'i Guncelle Butonu
$btnUpdate.Add_Click({
    Save-CurrentGuiConfig

    # Otomatik olarak log cekmecesini acarak kullaniciya anlik ilerlemeyi goster
    if ($expLog -ne $null) {
        $expLog.IsExpanded = $true
    }

    $taskOpts = @{
        DriverDir          = $txtDriverDir.Text.Trim()
        ChromeExePath      = $txtChromeExe.Text.Trim()
        Force              = [bool]$chkForce.IsChecked
        AutoKill           = [bool]$chkAutoKill.IsChecked
        CleanTarget        = [bool]$chkCleanTarget.IsChecked
        UpdateBrowserFirst = [bool]$chkUpdateBrowserFirst.IsChecked
    }

    $workerUpdate = {
        param($state, $corePath, $options)
        try {
            $state.StatusText = "Cekirdek motor yukleniyor..."
            . $corePath -ImportOnly

            $logBlock = {
                param($line, $lvl)
                $state.Logs.Add($line)
            }

            $progressBlock = {
                param($p)
                $state.Progress = $p
                $state.IsIndeterminate = $false
            }

            $state.StatusText = "Guncelleme operasyonu calisiyor..."
            $res = Invoke-ChromeDriverUpdate `
                -DriverDir $options.DriverDir `
                -ChromeExePath $options.ChromeExePath `
                -Force:$options.Force `
                -AutoKillProcesses:$options.AutoKill `
                -CleanTarget:$options.CleanTarget `
                -UpdateBrowserFirst:$options.UpdateBrowserFirst `
                -LogCb $logBlock `
                -ProgressCb $progressBlock

            $state.Result = $res
            if ($res.Success) {
                $state.StatusText = if ($res.Updated) { "Basariyla guncellendi!" } else { "Zaten guncel." }
                $state.Progress = 100
                $state.IsIndeterminate = $false
                $state.StatusLevel = 'SUCCESS'
            } else {
                $state.StatusText = "Hata: $($res.Message)"
                $state.Progress = 100
                $state.IsIndeterminate = $false
                $state.StatusLevel = 'ERROR'
            }
        } catch {
            $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            $state.Logs.Add("[$now] [HATA] Sistem hatasi: $($_.Exception.Message)")
            $state.StatusText = "Hata: $($_.Exception.Message)"
            $state.Progress = 100
            $state.IsIndeterminate = $false
            $state.StatusLevel = 'ERROR'
        } finally {
            $state.IsFinished = $true
        }
    }

    Start-GuiBackgroundTask -TaskType 'Update' -WorkerScript $workerUpdate -TaskOptions $taskOpts
})

# 2. Durumu Kontrol Et Butonu
$btnCheck.Add_Click({
    Save-CurrentGuiConfig

    $taskOpts = @{
        DriverDir     = $txtDriverDir.Text.Trim()
        ChromeExePath = $txtChromeExe.Text.Trim()
    }

    $workerCheck = {
        param($state, $corePath, $options)
        try {
            $state.StatusText = "Surumler denetleniyor..."
            . $corePath -ImportOnly

            $info = Get-ChromeDriverInspectionStatus -DriverDir $options.DriverDir -ChromeExePath $options.ChromeExePath
            $state.Result = $info

            $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            $state.Logs.Add("[$now] [BILGI] Chrome: $($info.ChromeVersion) | Driver: $($info.DriverVersion)")

            if ($info.IsMatch) {
                $state.StatusText = "Sistem guncel ve uyumlu."
                $state.Logs.Add("[$now] [BASARILI] Surucu ile tarayici tam uyumlu.")
                $state.StatusLevel = 'SUCCESS'
            } else {
                $state.StatusText = "Guncelleme gerekli."
                $state.Logs.Add("[$now] [UYARI] Surucu surumu uyusmuyor. Guncelleme yapiniz.")
                $state.StatusLevel = 'WARN'
            }
            $state.Progress = 100
            $state.IsIndeterminate = $false
        } catch {
            $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            $state.Logs.Add("[$now] [HATA] Denetim hatasi: $($_.Exception.Message)")
            $state.StatusText = "Denetim hatasi."
            $state.Progress = 100
            $state.IsIndeterminate = $false
            $state.StatusLevel = 'ERROR'
        } finally {
            $state.IsFinished = $true
        }
    }

    Start-GuiBackgroundTask -TaskType 'Check' -WorkerScript $workerCheck -TaskOptions $taskOpts
})

# 3. ChromeDriver Kapat Butonu (Sadece kilitli chromedriver.exe surecini kapatir)
$btnKillProcesses.Add_Click({
    $workerKill = {
        param($state, $corePath, $options)
        try {
            $state.StatusText = "Kilitli ChromeDriver surecleri kapatiliyor..."
            . $corePath -ImportOnly

            $logBlock = {
                param($line, $lvl)
                $state.Logs.Add($line)
            }

            $killed = Stop-ChromeProcesses -LogCb $logBlock
            $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            if ($killed) {
                $state.StatusText = "ChromeDriver surecleri kapatildi."
                $state.Logs.Add("[$now] [BASARILI] Kilitli ChromeDriver surecleri kapatildi.")
                $state.StatusLevel = 'SUCCESS'
            } else {
                $state.StatusText = "Aktif ChromeDriver sureci bulunamadi."
                $state.Logs.Add("[$now] [BILGI] Kapatilacak aktif ChromeDriver sureci yok.")
                $state.StatusLevel = 'IDLE'
            }
            $state.Progress = 100
            $state.IsIndeterminate = $false
        } catch {
            $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            $state.Logs.Add("[$now] [HATA] Surec hatasi: $($_.Exception.Message)")
            $state.StatusText = "Surec hatasi."
            $state.Progress = 100
            $state.IsIndeterminate = $false
            $state.StatusLevel = 'ERROR'
        } finally {
            $state.IsFinished = $true
        }
    }

    Start-GuiBackgroundTask -TaskType 'Kill' -WorkerScript $workerKill
})

# 4. Hedefi Temizle Butonu
$btnCleanTarget.Add_Click({
    $taskOpts = @{
        DriverDir = $txtDriverDir.Text.Trim()
    }

    $workerClean = {
        param($state, $corePath, $options)
        try {
            $state.StatusText = "Artik dosyalar temizleniyor..."
            . $corePath -ImportOnly

            $logBlock = {
                param($line, $lvl)
                $state.Logs.Add($line)
            }

            Clean-TargetDirectory -DriverDir $options.DriverDir -LogCb $logBlock
            $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            $state.Logs.Add("[$now] [BASARILI] Artik dosyalar temizlendi.")
            $state.StatusText = "Temizlik tamamlandi."
            $state.Progress = 100
            $state.IsIndeterminate = $false
            $state.StatusLevel = 'SUCCESS'
        } catch {
            $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            $state.Logs.Add("[$now] [HATA] Temizlik hatasi: $($_.Exception.Message)")
            $state.StatusText = "Temizlik hatasi."
            $state.Progress = 100
            $state.IsIndeterminate = $false
            $state.StatusLevel = 'ERROR'
        } finally {
            $state.IsFinished = $true
        }
    }

    Start-GuiBackgroundTask -TaskType 'Clean' -WorkerScript $workerClean -TaskOptions $taskOpts
})

# 5. Dizin ve Dosya Seciciler
$btnBrowseDriver.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Robusta Worker ChromeDriver Hedef Klasoru"
    $dlg.SelectedPath = if (Test-Path -LiteralPath $txtDriverDir.Text) { $txtDriverDir.Text } else { "C:\" }
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtDriverDir.Text = $dlg.SelectedPath
        Save-CurrentGuiConfig
        $btnCheck.RaiseEvent((New-Object System.Windows.RoutedEventArgs ([System.Windows.Controls.Button]::ClickEvent)))
    }
})

$btnOpenDriver.Add_Click({
    $path = $txtDriverDir.Text.Trim()
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
    [System.Diagnostics.Process]::Start('explorer.exe', $path) | Out-Null
})

$btnBrowseChrome.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title = "Google Chrome (chrome.exe)"
    $dlg.Filter = "chrome.exe|chrome.exe|Tum Dosyalar (*.*)|*.*"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtChromeExe.Text = $dlg.FileName
        Save-CurrentGuiConfig
        $btnCheck.RaiseEvent((New-Object System.Windows.RoutedEventArgs ([System.Windows.Controls.Button]::ClickEvent)))
    }
})

$btnAutoDetect.Add_Click({
    $detected = Find-InstalledChromeExe
    if ($detected) {
        $txtChromeExe.Text = $detected
        Save-CurrentGuiConfig
        $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $txtLogConsole.AppendText("[$now] [BASARILI] Chrome tespit edildi: $detected`r`n")
        $txtLogConsole.ScrollToEnd()
        $btnCheck.RaiseEvent((New-Object System.Windows.RoutedEventArgs ([System.Windows.Controls.Button]::ClickEvent)))
    } else {
        [System.Windows.MessageBox]::Show(
            "Sistemde otomatik Chrome kurulumu bulunamadi. Lutfen 'Gozat' butonunu kullanarak chrome.exe dosyasini manuel olarak seciniz.",
            "Otomatik Tespit",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Warning
        )
    }
})

# 6. Log Butonlari
$btnOpenLogs.Add_Click({
    $logDir = Join-Path $guiScriptDir 'logs'
    if (-not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    [System.Diagnostics.Process]::Start('explorer.exe', $logDir) | Out-Null
})

$btnCopyLog.Add_Click({
    if ($txtLogConsole.Text) {
        [System.Windows.Clipboard]::SetText($txtLogConsole.Text)
        $txtFooterStatus.Text = "Panoya kopyalandi."
    }
})

$btnClearLog.Add_Click({
    $txtLogConsole.Clear()
    $txtFooterStatus.Text = "Gunluk temizlendi."
})

$btnOpenLogFile.Add_Click({
    $logFile = Join-Path (Join-Path $guiScriptDir 'logs') 'ChromeDriverUpdater.log'
    if (Test-Path -LiteralPath $logFile) {
        [System.Diagnostics.Process]::Start('notepad.exe', $logFile) | Out-Null
    } else {
        [System.Windows.MessageBox]::Show("Henuz log dosyasi olusturulmamis.", "Bilgi", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    }
})

# 7. Pencere Kapanirken Temizlik
$window.Add_Closing({
    Save-CurrentGuiConfig
    if ($uiTimer) { $uiTimer.Stop() }
    if ($activePowerShell) {
        try { $activePowerShell.Stop(); $activePowerShell.Dispose() } catch {}
    }
    if ($activeRunspace) {
        try { $activeRunspace.Close(); $activeRunspace.Dispose() } catch {}
    }
})

# 8. Pencere Yuklendiginde Otomatik Ilk Denetim
$window.Add_Loaded({
    $initialInspection = Get-ChromeDriverInspectionStatus `
        -DriverDir $txtDriverDir.Text.Trim() `
        -ChromeExePath $txtChromeExe.Text.Trim()
    Update-GuiStatusCards -StatusInfo $initialInspection
    
    $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $txtLogConsole.AppendText("[$now] [BILGI] Konsol hazir.`r`n")
    if ($initialInspection.IsMatch) {
        $txtLogConsole.AppendText("[$now] [BASARILI] Chrome ($($initialInspection.ChromeVersion)) ile ChromeDriver uyumlu.`r`n")
    } else {
        $txtLogConsole.AppendText("[$now] [BILGI] Senkronize etmek icin 'Senkronize Et' butonunu kullanabilirsiniz.`r`n")
    }
})

# Arayuzu Goster
$null = $window.ShowDialog()
