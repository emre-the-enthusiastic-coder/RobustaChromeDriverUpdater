<#
    .SYNOPSIS
        Google Chrome Hakkinda (chrome://settings/help) UI Automation (UIA) Analiz ve Denetim Araci

    .DESCRIPTION
        Google Chrome'u grafik arayuzle acar, 'chrome://settings/help' sayfasina gider,
        Windows UI Automation (UIA) ile erisilebilirlik agacini tarar, bekleyen guncelleme
        durumunu tespit eder ve tum DOM/UIA agac yapisini loglar.
        Kullanicinin acik Chrome sekmelerine asla zarar vermez.
#>

[CmdletBinding()]
param(
    [string]$ChromeExePath = '',
    [int]$TimeoutSeconds = 15,
    [int]$MaxDepth = 15,
    [string]$LogPath = '',
    [string]$JsonPath = ''
)

$ErrorActionPreference = 'Stop'

# Gerekli Win32 API tanimi (SendInput yerine guvenli mesaj gonderimi)
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class ChromeUiaInput {
    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    public const uint WM_KEYDOWN = 0x0100;
    public const uint WM_KEYUP   = 0x0101;
    public const int VK_RETURN   = 0x0D;

    public static void SendEnter(IntPtr hWnd) {
        PostMessage(hWnd, WM_KEYDOWN, (IntPtr)VK_RETURN, IntPtr.Zero);
        PostMessage(hWnd, WM_KEYUP, (IntPtr)VK_RETURN, IntPtr.Zero);
    }
}
"@

# UI Automation kutuphaneleri
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

$scriptDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($scriptDir)) {
    $scriptDir = (Get-Location).Path
}

# Chrome Exe tespiti
if ([string]::IsNullOrWhiteSpace($ChromeExePath)) {
    $coreScript = Join-Path $scriptDir 'ChromeDriverUpdater.ps1'
    if (Test-Path -LiteralPath $coreScript) {
        . $coreScript -ImportOnly
        if (Get-Command -Name 'Find-InstalledChromeExe' -ErrorAction SilentlyContinue) {
            $ChromeExePath = Find-InstalledChromeExe
        }
    }
    if ([string]::IsNullOrWhiteSpace($ChromeExePath) -or -not (Test-Path -LiteralPath $ChromeExePath)) {
        $commonPaths = @(
            (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'),
            (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe'),
            (Join-Path $env:LocalAppData 'Google\Chrome\Application\chrome.exe')
        )
        foreach ($p in $commonPaths) {
            if (Test-Path -LiteralPath $p) {
                $ChromeExePath = $p
                break
            }
        }
    }
}

if (-not (Test-Path -LiteralPath $ChromeExePath)) {
    Write-Error "Google Chrome bulunamadi: $ChromeExePath"
    exit 1
}

# Log dosya yollari
$logsDir = Join-Path $scriptDir 'logs'
if (-not (Test-Path -LiteralPath $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}

if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $LogPath = Join-Path $logsDir 'ChromeAbout_UIATree.log'
}
if ([string]::IsNullOrWhiteSpace($JsonPath)) {
    $JsonPath = Join-Path $logsDir 'ChromeAbout_UIATree.json'
}

# Izole otomasyon profili (Kullanicinin sekmelerini ve profilini korur)
$automationProfile = Join-Path (Join-Path $scriptDir 'temp') 'uia_profile'
if (-not (Test-Path -LiteralPath $automationProfile)) {
    New-Item -ItemType Directory -Path $automationProfile -Force | Out-Null
}

$now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
Write-Host "[$now] [UIA] 1/6 Google Chrome arayuzle baslatiliyor..." -ForegroundColor Cyan
Write-Host "[$now] [UIA]     Chrome Exe : $ChromeExePath" -ForegroundColor Gray

$chromeArgs = @(
    "--user-data-dir=$automationProfile",
    "--no-first-run",
    "--no-default-browser-check",
    "--force-renderer-accessibility"
)

$proc = Start-Process -FilePath $ChromeExePath -ArgumentList $chromeArgs -PassThru
Write-Host "[$now] [UIA]     PID: $($proc.Id)" -ForegroundColor Gray

Start-Sleep -Seconds 4

# 2. Chrome Penceresini Bul
Write-Host "[$now] [UIA] 2/6 Chrome penceresi yakalaniyor..." -ForegroundColor Cyan
$root = [System.Windows.Automation.AutomationElement]::RootElement
$winCond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ClassNameProperty,
    'Chrome_WidgetWin_1'
)

$targetWin = $null
$startTime = [System.Diagnostics.Stopwatch]::StartNew()
while ($startTime.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
    $wins = $root.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)
    foreach ($w in $wins) {
        $procId = $w.Current.ProcessId
        $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
        if (-not $proc -or $proc.ProcessName -ne 'chrome') { continue }
        if ($w.Current.Name -match 'Brave|Edge') { continue }
        if ($w.Current.Name) {
            $targetWin = $w
            break
        }
    }
    if ($targetWin) { break }
    Start-Sleep -Milliseconds 600
}

if (-not $targetWin) {
    Write-Error "Google Chrome penceresi bulunamadi!"
    exit 1
}

$hwnd = [IntPtr]$targetWin.Current.NativeWindowHandle
Write-Host "[$now] [UIA]     Pencere: '$($targetWin.Current.Name)' (HWND: $hwnd)" -ForegroundColor Green

# 3. Omnibox (Adres Cubugu) uzerinden chrome://settings/help adresine git
Write-Host "[$now] [UIA] 3/6 chrome://settings/help adresine gidiliyor..." -ForegroundColor Cyan
$editCond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::Edit
)

$edits = $targetWin.FindAll([System.Windows.Automation.TreeScope]::Descendants, $editCond)
$omnibox = $null
foreach ($e in $edits) {
    if ($e.Current.ClassName -eq 'OmniboxViewViews' -or $e.Current.Name -match 'Adres|Address|arama') {
        $omnibox = $e
        break
    }
}

if (-not $omnibox) {
    Write-Error "Adres cubugu (Omnibox) bulunamadi!"
    exit 1
}

$vp = $omnibox.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
$vp.SetValue("chrome://settings/help")
[ChromeUiaInput]::SendEnter($hwnd)

# 4. Sayfanin yuklenmesi ve guncelleme denetiminin calismasi icin bekle
Write-Host "[$now] [UIA] 4/6 Sayfa yukleniyor ve guncelleme denetimi yapiliyor (8 sn)..." -ForegroundColor Cyan
Start-Sleep -Seconds 8

# 5. Settings Document ogesini bul
Write-Host "[$now] [UIA] 5/6 Ayarlar Belgesi (Document) tespit ediliyor..." -ForegroundColor Cyan
$docCond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::Document
)

$docs = $targetWin.FindAll([System.Windows.Automation.TreeScope]::Descendants, $docCond)
$targetDoc = $null
foreach ($d in $docs) {
    if ($d.Current.Name -match 'Ayarlar|Settings|Chrome') {
        $targetDoc = $d
        break
    }
}

if (-not $targetDoc) {
    Write-Error "Ayarlar (chrome://settings/help) Document ogesi bulunamadi!"
    exit 1
}

Write-Host "[$now] [UIA]     Belge Adi: '$($targetDoc.Current.Name)'" -ForegroundColor Green

# 6. UIA Erisilebilirlik Agacini Derle
Write-Host "[$now] [UIA] 6/6 UI Automation eleman agaci derleniyor (Maks Derinlik: $MaxDepth)..." -ForegroundColor Cyan

$logLines = [System.Collections.Generic.List[string]]::new()
$treeNodes = [System.Collections.Generic.List[psobject]]::new()
$keywords = [System.Collections.Generic.List[string]]::new()

$hasRelaunchButton = $false
$detectedVersion = ''
$updateStatusText = ''
$relaunchButtonBounds = ''

function Traverse-UiaNode {
    param(
        [System.Windows.Automation.AutomationElement]$Element,
        [int]$Depth = 0,
        [int]$Max = 15
    )

    if ($null -eq $Element -or $Depth -gt $Max) { return }

    try {
        $c = $Element.Current
        $type = $c.ControlType.ProgrammaticName.Replace("ControlType.", "")
        $name = $c.Name
        $autoId = $c.AutomationId
        $cls = $c.ClassName
        $loc = $c.LocalizedControlType
        $help = $c.HelpText
        $bounds = $c.BoundingRectangle

        $boundsStr = if ($bounds.Width -gt 0) { "$([int]$bounds.X),$([int]$bounds.Y),$([int]$bounds.Width)x$([int]$bounds.Height)" } else { "" }

        $nodeObj = [PSCustomObject]@{
            Depth        = $Depth
            ControlType  = $type
            Name         = $name
            AutomationId = $autoId
            ClassName    = $cls
            Localized    = $loc
            HelpText     = $help
            Bounds       = $boundsStr
            IsEnabled    = $c.IsEnabled
            IsOffscreen  = $c.IsOffscreen
        }
        $script:treeNodes.Add($nodeObj)

        $indent = "  " * $Depth
        $nameStr = if ($name) { " Name='$name'" } else { "" }
        $idStr   = if ($autoId) { " Id='$autoId'" } else { "" }
        $clsStr  = if ($cls) { " Class='$cls'" } else { "" }
        $locStr  = if ($loc -and $loc -ne $type) { " Loc='$loc'" } else { "" }

        $line = "$indent+-- [$type]$locStr$nameStr$idStr$clsStr"
        $script:logLines.Add($line)

        # Guncelleme/Surum tespiti
        if ($autoId -eq 'relaunch' -or $name -match 'Yeniden başlat|Relaunch') {
            $script:hasRelaunchButton = $true
            $script:relaunchButtonBounds = $boundsStr
            $script:keywords.Add("[BUTON] Yeniden Başlat (Id: $autoId, Bounds: $boundsStr)")
        }

        if ($name -match 'Sürüm|Version\s+(\d+\.\d+\.\d+\.\d+)') {
            $script:detectedVersion = $name
            $script:keywords.Add("[SURUM] $name")
        }

        if ($name -match 'güncel|guncel|up to date|tamamlanması için|güncelleniyor|updating|denetleniyor|checking') {
            $script:updateStatusText = $name
            $script:keywords.Add("[DURUM] $name")
        }

        # Alt ogeleri tara
        $children = $Element.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition)
        foreach ($child in $children) {
            Traverse-UiaNode -Element $child -Depth ($Depth + 1) -Max $Max
        }
    } catch {}
}

Traverse-UiaNode -Element $targetDoc -Depth 0 -Max $MaxDepth

# 7. Log ve JSON Dosyalarini Kaydet
$header = @"
================================================================================
ROBUSTA CHROME ABOUT (chrome://settings/help) - UIA TREE DUMP
Tarih/Saat    : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Chrome Exe    : $ChromeExePath
Pencere       : $($targetWin.Current.Name)
Belge (Doc)   : $($targetDoc.Current.Name)
Toplam Düğüm  : $($treeNodes.Count)
================================================================================

--- TESPİT EDİLEN GÜNCELLEME VE SÜRÜM ÖĞELERİ ---
"@

$kwText = if ($keywords.Count -gt 0) { ($keywords | Select-Object -Unique) -join "`r`n" } else { "Özel anahtar kelime bulunamadı." }
$fullLog = $header + "`r`n" + $kwText + "`r`n`r`n--- TAM UIA HİYERARŞİK AĞAÇ YAPISI ---`r`n" + ($logLines -join "`r`n")

[System.IO.File]::WriteAllText($LogPath, $fullLog, [System.Text.Encoding]::UTF8)
$treeNodes | ConvertTo-Json -Depth 6 | Out-File -FilePath $JsonPath -Encoding UTF8 -Force

$now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
Write-Host ""
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "[$now] [UIA] AGAC BASARIYLA DERLENDI VE KAYDEDILDI!" -ForegroundColor Green
Write-Host "[$now] [UIA] Toplam Dugum  : $($treeNodes.Count)" -ForegroundColor Cyan
Write-Host "[$now] [UIA] Log Dosyasi   : $LogPath" -ForegroundColor Yellow
Write-Host "[$now] [UIA] JSON Dosyasi  : $JsonPath" -ForegroundColor Yellow
Write-Host "======================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "TESPIT EDILEN KRITIK BILGILER:" -ForegroundColor Cyan
Write-Host "  * Bekleyen Guncelleme : $(if ($hasRelaunchButton) { 'EVET (Yeniden Baslat Butonu Mevcut)' } else { 'HAYIR / GUNCEL' })" -ForegroundColor $(if ($hasRelaunchButton) { 'Yellow' } else { 'Green' })
Write-Host "  * Tespit Edilen Surum : $detectedVersion" -ForegroundColor White
Write-Host "  * Durum Aciklamasi    : $updateStatusText" -ForegroundColor White
Write-Host "======================================================================" -ForegroundColor Green

return [PSCustomObject]@{
    Success              = $true
    HasPendingUpdate     = $hasRelaunchButton
    DetectedVersion      = $detectedVersion
    StatusMessage        = $updateStatusText
    RelaunchButtonBounds = $relaunchButtonBounds
    TotalNodes           = $treeNodes.Count
    LogPath              = $LogPath
    JsonPath             = $JsonPath
}
