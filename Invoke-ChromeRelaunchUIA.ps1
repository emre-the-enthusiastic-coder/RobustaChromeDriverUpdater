<#
    .SYNOPSIS
        Google Chrome Otomatik Yeniden Baslatma (Relaunch) ve Guncelleme Dogrulama Betigi

    .DESCRIPTION
        Google Chrome'un 'chrome://settings/help' sayfasini Windows UI Automation (UIA)
        ile denetler. Brave, Edge gibi diger Chromium tarayicilarini kesin olarak filtreler;
        yalnizca 'chrome.exe' (Google Chrome) surecini ve pencerelerini hedefler.
        Bekleyen bir guncelleme (Yeniden baslat / Relaunch butonu) varsa butona tiklar,
        Chrome'un kapanip yeni surumle acilmasini bekler ve guncellenmis yeni surum numarasini dondurur.
#>

[CmdletBinding()]
param(
    [string]$ChromeExePath = '',
    [int]$TimeoutSeconds = 30,
    [bool]$WaitForRestart = $true,
    [bool]$CleanSession = $true,
    [bool]$CloseAfterCheck = $false
)

$ErrorActionPreference = 'Stop'

# 1. Win32 ve UI Automation Kutuphanelerini Yukle
if (-not ([System.Management.Automation.PSTypeName]'ChromeRelauncherHelper').Type) {
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Threading;

public class ChromeRelauncherHelper {
    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern void SwitchToThisWindow(IntPtr hWnd, bool fAltTab);

    [DllImport("user32.dll")]
    public static extern bool BringWindowToTop(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool IsWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, IntPtr ProcessId);

    [DllImport("user32.dll")]
    public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);

    [DllImport("kernel32.dll")]
    public static extern uint GetCurrentThreadId();

    [DllImport("user32.dll")]
    public static extern bool SetCursorPos(int X, int Y);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, int dx, int dy, uint dwData, UIntPtr dwExtraInfo);

    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    public const int SW_RESTORE            = 9;
    public const int SW_SHOW               = 5;
    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP   = 0x0004;
    public const uint KEYEVENTF_KEYUP      = 0x0002;
    public const byte VK_SPACE             = 0x20;
    public const byte VK_RETURN            = 0x0D;
    public const uint WM_KEYDOWN           = 0x0100;
    public const uint WM_KEYUP             = 0x0101;

    public static void ActivateWindow(IntPtr hWnd) {
        ShowWindow(hWnd, SW_RESTORE);
        uint currentThread = GetCurrentThreadId();
        uint targetThread = GetWindowThreadProcessId(hWnd, IntPtr.Zero);
        if (currentThread != targetThread && targetThread != 0) {
            AttachThreadInput(currentThread, targetThread, true);
            SetForegroundWindow(hWnd);
            BringWindowToTop(hWnd);
            AttachThreadInput(currentThread, targetThread, false);
        } else {
            SetForegroundWindow(hWnd);
            BringWindowToTop(hWnd);
        }
        SwitchToThisWindow(hWnd, true);
        Thread.Sleep(350);
    }

    public static void ClickCoordinates(int x, int y) {
        SetCursorPos(x, y);
        Thread.Sleep(100);
        mouse_event(MOUSEEVENTF_LEFTDOWN, x, y, 0, UIntPtr.Zero);
        Thread.Sleep(100);
        mouse_event(MOUSEEVENTF_LEFTUP, x, y, 0, UIntPtr.Zero);
    }

    public static void PressSpace() {
        keybd_event(VK_SPACE, 0, 0, UIntPtr.Zero);
        Thread.Sleep(60);
        keybd_event(VK_SPACE, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
    }

    public static void PressEnter() {
        keybd_event(VK_RETURN, 0, 0, UIntPtr.Zero);
        Thread.Sleep(60);
        keybd_event(VK_RETURN, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
    }

    public static void SendEnter(IntPtr hWnd) {
        PostMessage(hWnd, WM_KEYDOWN, (IntPtr)VK_RETURN, IntPtr.Zero);
        PostMessage(hWnd, WM_KEYUP, (IntPtr)VK_RETURN, IntPtr.Zero);
    }
}
"@
}

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

$scriptDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($scriptDir)) {
    $scriptDir = (Get-Location).Path
}

# 2. Kesin Google Chrome Yolu Tespiti (Brave vb. asla secilmez)
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
    Write-Error "Google Chrome dosyasi bulunamadi: $ChromeExePath"
    exit 1
}

# SADECE Google Chrome Pencerelerini Yakalayan Fonksiyon (Brave, Edge elenir)
function Get-GoogleChromeUiaWindow {
    param(
        [string]$ExpectedExePath = '',
        [int]$WaitSec = 10,
        [IntPtr]$ExcludeHwnd = [IntPtr]::Zero
    )
    $root = [System.Windows.Automation.AutomationElement]::RootElement
    $winCond = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ClassNameProperty,
        'Chrome_WidgetWin_1'
    )
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $WaitSec) {
        $wins = $root.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)
        $candidates = @()
        foreach ($w in $wins) {
            $h = [IntPtr]$w.Current.NativeWindowHandle
            if ($ExcludeHwnd -ne [IntPtr]::Zero -and $h -eq $ExcludeHwnd) {
                continue
            }

            $procId = $w.Current.ProcessId
            $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
            if (-not $proc) { continue }

            # 1. Process Name KESINLIKLE 'chrome' olmali (Brave 'brave', Edge 'msedge' dir)
            if ($proc.ProcessName -ne 'chrome') {
                continue
            }

            # 2. Pencere basliginda Brave veya Edge olamaz
            $title = $w.Current.Name
            if ($title -match 'Brave|Edge') {
                continue
            }

            # 3. Boyut kontrolu: gercek bir tarayici penceresi en az 200x200 olmalidir (tooltip/widget elenir)
            $rect = $w.Current.BoundingRectangle
            if ($rect.Width -lt 200 -or $rect.Height -lt 200) {
                continue
            }

            # 4. Modul yolu erisilebilirse 'Google\Chrome' dogrulamasi yap
            try {
                $modPath = $proc.MainModule.FileName
                if ($modPath -and $modPath -notmatch 'Google\\Chrome') {
                    continue
                }
            } catch {}

            # Bos baslikli arkaplan / bildirim pencerelerini ele
            if (-not [string]::IsNullOrWhiteSpace($title)) {
                $candidates += $w
            }
        }

        if ($candidates.Count -gt 0) {
            # Oncelikle varsa 'Ayarlar' veya 'Chrome hakkında' baslikli olan pencereyi one al
            $settingsWin = $candidates | Where-Object { $_.Current.Name -match 'Ayarlar|Settings|Chrome hakkında' } | Select-Object -First 1
            if ($settingsWin) {
                return $settingsWin
            }
            return $candidates[0]
        }
        Start-Sleep -Milliseconds 500
    }
    return $null
}

function Navigate-ChromeToUrl {
    param(
        [System.Windows.Automation.AutomationElement]$ChromeWindow,
        [string]$Url
    )
    $hwnd = [IntPtr]$ChromeWindow.Current.NativeWindowHandle
    $editCond = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
        [System.Windows.Automation.ControlType]::Edit
    )
    $edits = $ChromeWindow.FindAll([System.Windows.Automation.TreeScope]::Descendants, $editCond)
    $omnibox = $null
    foreach ($e in $edits) {
        if ($e.Current.ClassName -eq 'OmniboxViewViews' -or $e.Current.Name -match 'Adres|Address|arama') {
            $omnibox = $e
            break
        }
    }

    if ($omnibox) {
        try {
            [ChromeRelauncherHelper]::ActivateWindow($hwnd)
            $omnibox.SetFocus()
            Start-Sleep -Milliseconds 150
            $vp = $omnibox.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
            $vp.SetValue($Url)
            Start-Sleep -Milliseconds 150
            [ChromeRelauncherHelper]::PressEnter()
            [ChromeRelauncherHelper]::SendEnter($hwnd)
            Start-Sleep -Seconds 3
            return $true
        } catch {
            return $false
        }
    }
    return $false
}

function Get-ChromeAboutDocument {
    param(
        [System.Windows.Automation.AutomationElement]$ChromeWindow,
        [int]$WaitSec = 10
    )
    $docCond = New-Object System.Windows.Automation.PropertyCondition(
        [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
        [System.Windows.Automation.ControlType]::Document
    )
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $WaitSec) {
        $docs = $ChromeWindow.FindAll([System.Windows.Automation.TreeScope]::Descendants, $docCond)
        foreach ($d in $docs) {
            if ($d.Current.Name -match 'Ayarlar|Settings|Chrome') {
                return $d
            }
        }
        Start-Sleep -Milliseconds 600
    }
    return $null
}

function Stop-GoogleChromeProcess {
    [CmdletBinding()]
    param(
        [string]$ExpectedExePath = '',
        [int]$WaitTimeoutSec = 8
    )
    $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    # SADECE process adi 'chrome' olan surecleri sec (Brave 'brave', Edge 'msedge'dir - ASLA etkilenmez)
    $chromeProcs = Get-Process -Name 'chrome' -ErrorAction SilentlyContinue
    if (-not $chromeProcs) {
        Write-Host "[$now] [CLEANUP] Calisan Google Chrome sureci yok, oturum zaten temiz." -ForegroundColor Gray
        return
    }

    Write-Host "[$now] [CLEANUP] Acik Google Chrome pencereleri/surecleri temizleniyor ($($chromeProcs.Count) surec)..." -ForegroundColor Yellow

    # 1. Once pencereli ana sureclere CloseMainWindow gonder (temiz kapanma)
    foreach ($p in $chromeProcs) {
        try {
            if ($p.MainWindowHandle -and $p.MainWindowHandle -ne [IntPtr]::Zero) {
                $p.CloseMainWindow() | Out-Null
            }
        } catch {}
    }

    # Kapanmasini bekle (maks 4 sn)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 4) {
        $remaining = Get-Process -Name 'chrome' -ErrorAction SilentlyContinue
        if (-not $remaining) { break }
        Start-Sleep -Milliseconds 400
    }

    # 2. Hala arkada kalan chrome sureci varsa yalnizca Google Chrome olanlari sonlandir
    $remaining = Get-Process -Name 'chrome' -ErrorAction SilentlyContinue
    if ($remaining) {
        foreach ($p in $remaining) {
            $isGoogle = $false
            try {
                $fn = $p.MainModule.FileName
                if ($fn -match 'Google\\Chrome' -or ($ExpectedExePath -and $fn -eq $ExpectedExePath)) {
                    $isGoogle = $true
                }
            } catch {
                # Erişim kisitlamasi olsa da process adi zaten 'chrome' (Brave 'brave'dir)
                $isGoogle = $true
            }

            if ($isGoogle) {
                try {
                    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
                } catch {}
            }
        }
        Start-Sleep -Milliseconds 800
    }

    $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "[$now] [CLEANUP] Google Chrome pencereleri kapatildi. Brave ve diger tarayicilar tamamen korundu." -ForegroundColor Green
}

# 3. Ana Isleyis
$now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
Write-Host "[$now] [RELAUNCH] Google Chrome UIA Otomatik Yeniden Baslatma baslatildi." -ForegroundColor Cyan
Write-Host "[$now] [RELAUNCH] Hedef Tarayici : $ChromeExePath (Google Chrome)" -ForegroundColor Gray

if ($CleanSession) {
    # Acik diger sekmelerle / pencerelerle karismamasi icin Chrome temizlenir (Brave vb. elenmez)
    Stop-GoogleChromeProcess -ExpectedExePath $ChromeExePath
    
    $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "[$now] [RELAUNCH] Temiz Google Chrome oturumu baslatiliyor..." -ForegroundColor Cyan
    Write-Host "[$now] [RELAUNCH] Sayfa: chrome://settings/help" -ForegroundColor Gray
    
    $chromeArgs = @(
        "chrome://settings/help",
        "--force-renderer-accessibility",
        "--no-default-browser-check",
        "--no-first-run"
    )
    $null = Start-Process -FilePath $ChromeExePath -ArgumentList $chromeArgs
    $chromeWin = Get-GoogleChromeUiaWindow -ExpectedExePath $ChromeExePath -WaitSec 15
} else {
    # Yalnizca GOOGLE CHROME penceresini ara
    $chromeWin = Get-GoogleChromeUiaWindow -ExpectedExePath $ChromeExePath -WaitSec 3
    if (-not $chromeWin) {
        Write-Host "[$now] [RELAUNCH] Calisan Google Chrome penceresi bulunamadi. Dogrudan chrome.exe ile aciliyor..." -ForegroundColor Yellow
        Start-Process -FilePath $ChromeExePath -ArgumentList "chrome://settings/help", "--force-renderer-accessibility", "--no-default-browser-check", "--no-first-run"
        $chromeWin = Get-GoogleChromeUiaWindow -ExpectedExePath $ChromeExePath -WaitSec 15
    } else {
        Write-Host "[$now] [RELAUNCH] Google Chrome penceresi baglandi: '$($chromeWin.Current.Name)'" -ForegroundColor Green
        Start-Process -FilePath $ChromeExePath -ArgumentList "chrome://settings/help"
        Start-Sleep -Seconds 2
    }
}

if (-not $chromeWin) {
    Write-Error "Google Chrome penceresi bulunamadi! (Diger tarayicilar filtrelendi)"
    exit 1
}

$hwnd = [IntPtr]$chromeWin.Current.NativeWindowHandle
Write-Host "[$now] [RELAUNCH] Aktif Google Chrome HWND: $hwnd" -ForegroundColor Green

# chrome://settings/help sayfasindaki Document ogesini bekle
$doc = Get-ChromeAboutDocument -ChromeWindow $chromeWin -WaitSec 8
if (-not $doc) {
    Write-Host "[$now] [RELAUNCH] chrome://settings/help sayfasina Omnibox ile gidiliyor..." -ForegroundColor Gray
    $null = Navigate-ChromeToUrl -ChromeWindow $chromeWin -Url "chrome://settings/help"
    $doc = Get-ChromeAboutDocument -ChromeWindow $chromeWin -WaitSec 8
}

if (-not $doc) {
    Write-Error "Google Chrome Hakkinda (chrome://settings/help) sayfasi yuklenemedi!"
    exit 1
}

Write-Host "[$now] [RELAUNCH] Belge yuklendi: '$($doc.Current.Name)'" -ForegroundColor Green

# 4. Sayfayi Tara: Sürüm, Uyarı ve Relaunch Butonu
Write-Host "[$now] [RELAUNCH] Google Chrome Hakkinda sayfasi denetleniyor..." -ForegroundColor Cyan

$btnCond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::Button
)
$textCond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::Text
)

# Metinleri oku (Surum ve Durum tespiti)
$allTexts = $doc.FindAll([System.Windows.Automation.TreeScope]::Descendants, $textCond)
$currentVersion = ''
$statusSummary = ''

foreach ($t in $allTexts) {
    $val = $t.Current.Name
    if ($val -match '\b(\d+\.\d+\.\d+\.\d+)\b') {
        $currentVersion = $Matches[1]
    }
    if ($val -match 'güncel|guncel|up to date|yeniden başlat|relaunch|güncelleniyor|updating|tamamlanması için') {
        $statusSummary = $val
    }
}

Write-Host "[$now] [RELAUNCH] Google Chrome Surumu : $currentVersion" -ForegroundColor Gray
Write-Host "[$now] [RELAUNCH] Durum Bildirimi     : $statusSummary" -ForegroundColor Gray

# Relaunch Butonunu Ara (AutomationId = 'relaunch' veya Name = 'Yeniden başlat' / 'Relaunch')
$allButtons = $doc.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
$relaunchBtn = $null

foreach ($b in $allButtons) {
    if ($b.Current.AutomationId -eq 'relaunch' -or $b.Current.Name -match 'Yeniden başlat|Relaunch') {
        $relaunchBtn = $b
        break
    }
}

if (-not $relaunchBtn) {
    $isUpToDate = $statusSummary -match 'güncel|guncel|up to date'
    $isDownloading = $statusSummary -match 'güncelleniyor|updating'

    $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    if ($CloseAfterCheck) {
        Stop-GoogleChromeProcess -ExpectedExePath $ChromeExePath
    }

    if ($isUpToDate) {
        Write-Host "[$now] [RELAUNCH] Google Chrome zaten en guncel surumde ($currentVersion). Yeniden baslatma gerekmiyor." -ForegroundColor Green
        return [PSCustomObject]@{
            Success         = $true
            Status          = 'AlreadyUpToDate'
            Relaunched      = $false
            CurrentVersion  = $currentVersion
            NewVersion      = $currentVersion
            ChromeExePath   = $ChromeExePath
            Message         = "Google Chrome gunceldir, bekleyen guncelleme yok."
        }
    } elseif ($isDownloading) {
        Write-Host "[$now] [RELAUNCH] Google Chrome guncellemeyi arka planda indiriyor." -ForegroundColor Yellow
        return [PSCustomObject]@{
            Success         = $true
            Status          = 'UpdateDownloading'
            Relaunched      = $false
            CurrentVersion  = $currentVersion
            NewVersion      = $currentVersion
            ChromeExePath   = $ChromeExePath
            Message         = "Guncelleme arka planda indiriliyor."
        }
    } else {
        Write-Host "[$now] [RELAUNCH] Bekleyen yeniden baslatma butonu bulunamadi." -ForegroundColor Yellow
        return [PSCustomObject]@{
            Success         = $true
            Status          = 'RelaunchNotFound'
            Relaunched      = $false
            CurrentVersion  = $currentVersion
            NewVersion      = $currentVersion
            ChromeExePath   = $ChromeExePath
            Message         = "Yeniden baslat butonu tespit edilemedi."
        }
    }
}

# 5. Relaunch Butonu Bulundu - Guvenli Cok Katmanli Tetikleme
$now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
Write-Host "[$now] [RELAUNCH] Google Chrome icin bekleyen guncelleme tespit edildi!" -ForegroundColor Yellow

# Adim A: Google Chrome penceresini kesin olarak one getir ve aktive et
Write-Host "[$now] [RELAUNCH] [1/4] Google Chrome penceresi on plana aliniyor..." -ForegroundColor Gray
[ChromeRelauncherHelper]::ActivateWindow($hwnd)
Start-Sleep -Milliseconds 400

# Adim B: Butona UIA uzerinden odaklan (Focus)
Write-Host "[$now] [RELAUNCH] [2/4] 'Yeniden baslat' butonuna odaklaniliyor..." -ForegroundColor Gray
try {
    $relaunchBtn.SetFocus()
    Start-Sleep -Milliseconds 250
} catch {}

# Adim C: Buton koordinatlarina fiziksel sol tiklama yap
$rect = $relaunchBtn.Current.BoundingRectangle
if ($rect.Width -gt 0 -and $rect.Height -gt 0) {
    $clickX = [int]($rect.X + ($rect.Width / 2))
    $clickY = [int]($rect.Y + ($rect.Height / 2))
    Write-Host "[$now] [RELAUNCH] [3/4] Butona fiziksel sol tiklama yapiliyor ($clickX, $clickY)..." -ForegroundColor Cyan
    [ChromeRelauncherHelper]::ClickCoordinates($clickX, $clickY)
    Start-Sleep -Milliseconds 150
}

# Adim D: Klavyeden SPACE ve ENTER tus vuruslari gonder (Odaklanmis buton tetiklemesi)
Write-Host "[$now] [RELAUNCH] [4/4] Buton aktivasyon sinyalleri gonderiliyor (Space + Invoke)..." -ForegroundColor Gray
[ChromeRelauncherHelper]::PressSpace()
Start-Sleep -Milliseconds 100

try {
    $inv = $relaunchBtn.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
    $inv.Invoke()
} catch {}

# 6. Yeniden Baslama Kontrolu ve Guvenli Fallback
Write-Host "[$now] [RELAUNCH] Yeniden baslama durumu denetleniyor (3 sn)..." -ForegroundColor Cyan
Start-Sleep -Seconds 3

# Eger pencere veya buton hala acik ve aktifse, kesin native restart URL'sini cagir
$isStillOpen = $false
try {
    if ($relaunchBtn.Current.IsEnabled -and [ChromeRelauncherHelper]::IsWindow($hwnd)) {
        $isStillOpen = $true
    }
} catch {
    # Buton veya pencere kaybolduysa kapanma baslamistir!
    $isStillOpen = $false
}

if ($isStillOpen) {
    $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "[$now] [RELAUNCH] Buton tiklamasina UI yaniti gecikti. Native 'chrome://restart' ile kesin yeniden baslatiliyor..." -ForegroundColor Yellow
    [ChromeRelauncherHelper]::ActivateWindow($hwnd)
    $null = Navigate-ChromeToUrl -ChromeWindow $chromeWin -Url "chrome://restart"
}

# 7. Chrome'un Kapanip Yeni Surumle Yeniden Acilmasini Bekle
if ($WaitForRestart) {
    $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "[$now] [RELAUNCH] Google Chrome'un kapanmasi bekleniyor..." -ForegroundColor Cyan

    # Eski pencerenin kapanmasini bekle (maks 10 sn)
    $closeSw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($closeSw.Elapsed.TotalSeconds -lt 10) {
        if (-not [ChromeRelauncherHelper]::IsWindow($hwnd)) {
            break
        }
        Start-Sleep -Milliseconds 400
    }

    Write-Host "[$now] [RELAUNCH] Google Chrome'un yeni surumle baslamasi bekleniyor..." -ForegroundColor Cyan

    # Yeni Google Chrome penceresini yakala (eski HWND haric tutulur, maks 30 sn)
    $newWin = Get-GoogleChromeUiaWindow -ExpectedExePath $ChromeExePath -WaitSec 30 -ExcludeHwnd $hwnd
    if ($newWin) {
        $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Write-Host "[$now] [RELAUNCH] Yeniden baslatilan Google Chrome penceresi yakalandi: '$($newWin.Current.Name)'" -ForegroundColor Green
        
        # Sayfanin gelmesini bekle
        Start-Sleep -Seconds 5
        $newDoc = Get-ChromeAboutDocument -ChromeWindow $newWin -WaitSec 10

        $newVersion = ''
        if ($newDoc) {
            $texts = $newDoc.FindAll([System.Windows.Automation.TreeScope]::Descendants, $textCond)
            foreach ($t in $texts) {
                if ($t.Current.Name -match '\b(\d+\.\d+\.\d+\.\d+)\b') {
                    $newVersion = $Matches[1]
                    break
                }
            }
        }

        # Eger UIA ile dogrudan yeni surum okunamadiysa dosya surumunu kontrol et
        if (-not $newVersion) {
            $newVersion = (Get-Item -LiteralPath $ChromeExePath).VersionInfo.FileVersion
        }

        $now = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Write-Host "[$now] [RELAUNCH] ========================================================" -ForegroundColor Green
        Write-Host "[$now] [RELAUNCH] GOOGLE CHROME YENIDEN BASLATMA BASARIYLA TAMAMLANDI!" -ForegroundColor Green
        Write-Host "[$now] [RELAUNCH] Eski Surum : $currentVersion" -ForegroundColor Gray
        Write-Host "[$now] [RELAUNCH] Yeni Surum : $newVersion" -ForegroundColor Green
        Write-Host "[$now] [RELAUNCH] ========================================================" -ForegroundColor Green

        if ($CloseAfterCheck) {
            Stop-GoogleChromeProcess -ExpectedExePath $ChromeExePath
        }

        return [PSCustomObject]@{
            Success        = $true
            Status         = 'RelaunchedSuccessfully'
            Relaunched     = $true
            OldVersion     = $currentVersion
            NewVersion     = $newVersion
            ChromeExePath  = $ChromeExePath
            Message        = "Google Chrome basariyla yeniden baslatildi ve yeni surume ($newVersion) guncellendi."
        }
    } else {
        Write-Warning "Google Chrome penceresi yeniden acilma zaman asimina ugradi."
        return [PSCustomObject]@{
            Success        = $true
            Status         = 'RelaunchTriggeredWindowTimeout'
            Relaunched     = $true
            OldVersion     = $currentVersion
            NewVersion     = ''
            ChromeExePath  = $ChromeExePath
            Message        = "Yeniden baslatma tetiklendi ancak pencere zamaninda yakalanamadi."
        }
    }
} else {
    return [PSCustomObject]@{
        Success        = $true
        Status         = 'RelaunchTriggered'
        Relaunched     = $true
        OldVersion     = $currentVersion
        ChromeExePath  = $ChromeExePath
        Message        = "Yeniden baslatma butonu tetiklendi."
    }
}
