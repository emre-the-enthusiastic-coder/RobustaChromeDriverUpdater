<#
    .SYNOPSIS
        Robusta Worker - ChromeDriver Guncelleyici (CLI & GUI Hibrit Surum)
    
    .DESCRIPTION
        Sistemdeki kurulu Google Chrome surumu ile Robusta Worker hedefindeki (C:\RobustaWorker\driver)
        ChromeDriver.exe surumunu karsilastirir. Gerekirse Google Storage ve Chrome for Testing
        altyapisindan en guncel ve uyumlu surumu dogrudan indirir.
        Hedef klasorde yalnizca chromedriver.exe birakir, eski artik ve log dosyalarini temizler.
        Windows VM ortamlari icin hicbir harici kutuphane, Python veya NodeJS gerektirmeden
        tamamen yerel PowerShell ve .NET Framework ile calisir.
        Hem komut satirindan (CLI) parametrelerle hem de zengin grafik arayuz (GUI) ile kullanilabilir.

    .PARAMETER DriverDir
        ChromeDriver.exe'nin yerlestirilecegi hedef klasor. Varsayilan: C:\RobustaWorker\driver
    
    .PARAMETER ChromeExePath
        Sistemdeki chrome.exe dosyasinin yolu. Belirtilmezse otomatik tespit edilir.
    
    .PARAMETER GUI
        Grafik kullanici arayuzunu (WPF GUI) acar.
    
    .PARAMETER Silent
        Sessiz modda calisir, arayuz acmaz, loglari konsola ve dosyaya yazar.
        Gorev zamanlayici ve Robusta gorevleri icin idealdir.
    
    .PARAMETER CheckOnly
        Indirme ve degisiklik yapmadan yalnizca surumleri karsilastirir.
        Guncel ise Exit Code 0, guncelleme gerekiyorsa Exit Code 2 doner.
    
    .PARAMETER Force
        Surumler ayni olsa dahi ChromeDriver'i zorla yeniden indirir ve kurar.
    
    .PARAMETER KillProcesses
        Islem oncesinde chrome.exe ve chromedriver.exe sureclerini zorla sonlandirir.
    
    .PARAMETER CleanOnly
        Yalnizca hedef klasordeki .log ve gecici artik dosyalari temizler ve cikar.
#>

[CmdletBinding(DefaultParameterSetName = 'Default')]
param(
    [Parameter(ParameterSetName = 'Default')]
    [Parameter(ParameterSetName = 'CLI')]
    [string]$DriverDir = '',

    [Parameter(ParameterSetName = 'Default')]
    [Parameter(ParameterSetName = 'CLI')]
    [string]$ChromeExePath = '',

    [Parameter(ParameterSetName = 'Default')]
    [switch]$GUI,

    [Parameter(ParameterSetName = 'CLI')]
    [switch]$Silent,

    [Parameter(ParameterSetName = 'CLI')]
    [switch]$NoGui,

    [Parameter(ParameterSetName = 'CLI')]
    [switch]$Force,

    [Parameter(ParameterSetName = 'CLI')]
    [switch]$CheckOnly,

    [Parameter(ParameterSetName = 'CLI')]
    [switch]$KillProcesses,

    [Parameter(ParameterSetName = 'CLI')]
    [switch]$NoKillProcesses,

    [Parameter(ParameterSetName = 'CLI')]
    [switch]$CleanOnly,

    [Parameter(ParameterSetName = 'CLI')]
    [string]$LogPath = '',

    [Parameter(ParameterSetName = 'CLI')]
    [int]$TimeoutSec = 120,

    [Parameter(ParameterSetName = 'Default')]
    [Parameter(ParameterSetName = 'CLI')]
    [switch]$UpdateBrowserFirst,

    [Parameter(ParameterSetName = 'Default')]
    [Parameter(ParameterSetName = 'CLI')]
    [switch]$NoBrowserUpdate,

    [switch]$ImportOnly
)

# Temel ortam ve guvenlik ayarlari
$ErrorActionPreference = 'Stop'
Set-StrictMode -Off
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Script kok dizini
$script:ScriptDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($script:ScriptDir)) {
    $script:ScriptDir = (Get-Location).Path
}

# Yapilandirma dosyasi yolu
$script:ConfigFile = Join-Path $script:ScriptDir 'config.json'

# Log dizini ve dosyasi
$script:LogDir = Join-Path $script:ScriptDir 'logs'
if (-not [string]::IsNullOrEmpty($LogPath)) {
    $script:LogFile = $LogPath
    $customLogDir = Split-Path -Parent $LogPath
    if ($customLogDir -and -not (Test-Path -LiteralPath $customLogDir)) {
        New-Item -ItemType Directory -Path $customLogDir -Force | Out-Null
    }
} else {
    $script:LogFile = Join-Path $script:LogDir 'ChromeDriverUpdater.log'
}

if (-not (Test-Path -LiteralPath $script:LogDir)) {
    New-Item -ItemType Directory -Path $script:LogDir -Force | Out-Null
}

# Temp taban dizini
$script:TempBaseDir = Join-Path $script:ScriptDir 'temp'

# ----------------- YARDIMCI FONKSIYONLAR (CORE ENGINE) -----------------

function Get-AppConfig {
    <#
        .SYNOPSIS
            config.json dosyasini okur, yoksa varsayilanlarla olusturur.
    #>
    [CmdletBinding()]
    param()

    $defaultConfig = [PSCustomObject]@{
        DriverDir          = 'C:\RobustaWorker\driver'
        ChromeExePath      = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
        AutoKillProcesses  = $true
        CleanTarget        = $true
        Force              = $false
        UpdateBrowserFirst = $true
        LastUpdated        = $null
    }

    if (Test-Path -LiteralPath $script:ConfigFile) {
        try {
            $content = Get-Content -LiteralPath $script:ConfigFile -Raw -Encoding UTF8
            $json = $content | ConvertFrom-Json
            if ($json -and $json.PSObject.Properties['DriverDir'] -and $json.DriverDir) { $defaultConfig.DriverDir = $json.DriverDir }
            if ($json -and $json.PSObject.Properties['ChromeExePath'] -and $json.ChromeExePath) { $defaultConfig.ChromeExePath = $json.ChromeExePath }
            if ($json -and $json.PSObject.Properties['AutoKillProcesses'] -and ($null -ne $json.AutoKillProcesses)) { $defaultConfig.AutoKillProcesses = [bool]$json.AutoKillProcesses }
            if ($json -and $json.PSObject.Properties['CleanTarget'] -and ($null -ne $json.CleanTarget)) { $defaultConfig.CleanTarget = [bool]$json.CleanTarget }
            if ($json -and $json.PSObject.Properties['Force'] -and ($null -ne $json.Force)) { $defaultConfig.Force = [bool]$json.Force }
            if ($json -and $json.PSObject.Properties['UpdateBrowserFirst'] -and ($null -ne $json.UpdateBrowserFirst)) { $defaultConfig.UpdateBrowserFirst = [bool]$json.UpdateBrowserFirst }
            if ($json -and $json.PSObject.Properties['LastUpdated'] -and $json.LastUpdated) { $defaultConfig.LastUpdated = $json.LastUpdated }
        } catch {
            Write-Log "Yapilandirma dosyasi okunamadi, varsayilanlar kullaniliyor: $($_.Exception.Message)" -Level 'WARN'
        }
    } else {
        Save-AppConfig -Config $defaultConfig
    }

    return $defaultConfig
}

function Save-AppConfig {
    <#
        .SYNOPSIS
            Mevcut ayarlari config.json dosyasina kaydeder.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][psobject]$Config)

    try {
        $jsonStr = $Config | ConvertTo-Json -Depth 4
        Set-Content -LiteralPath $script:ConfigFile -Value $jsonStr -Encoding UTF8 -Force
    } catch {
        Write-Log "Yapilandirma kaydedilemedi: $($_.Exception.Message)" -Level 'WARN'
    }
}

function Write-Log {
    <#
        .SYNOPSIS
            Log dosyasina ve konsola formatli cikti yazar.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS', 'DEBUG')][string]$Level = 'INFO',
        [scriptblock]$Callback = $null
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$timestamp] [$Level] $Message"

    try {
        Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 -ErrorAction Stop
    } catch {}

    if ($Callback) {
        try { & $Callback $line $Level } catch {}
    }

    switch ($Level) {
        'ERROR'   { Write-Host $line -ForegroundColor Red }
        'WARN'    { Write-Host $line -ForegroundColor Yellow }
        'SUCCESS' { Write-Host $line -ForegroundColor Green }
        'DEBUG'   { Write-Host $line -ForegroundColor DarkGray }
        default   { Write-Host $line -ForegroundColor Gray }
    }
}

function Find-InstalledChromeExe {
    <#
        .SYNOPSIS
            Sistemdeki chrome.exe calistirilabilir dosyasini bilinen dizinlerden ve kayit defterinden arar.
    #>
    [CmdletBinding()]
    param([string]$PreferredPath = '')

    if ($PreferredPath -and (Test-Path -LiteralPath $PreferredPath)) {
        return (Get-Item -LiteralPath $PreferredPath).FullName
    }

    $candidates = @()

    # 1. Registry App Paths
    $regAppPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe'
    if (Test-Path -LiteralPath $regAppPath) {
        $item = Get-ItemProperty -LiteralPath $regAppPath -ErrorAction SilentlyContinue
        if ($item -and $item.PSObject.Properties['(default)']) {
            $p = $item.'(default)'
            if ($p -and (Test-Path -LiteralPath $p)) { $candidates += $p }
        }
    }

    # 2. Standart Kurulum Dizinleri
    $candidates += @(
        'C:\Program Files\Google\Chrome\Application\chrome.exe',
        'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
        (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe'),
        (Join-Path $env:ProgramW6432 'Google\Chrome\Application\chrome.exe')
    )

    foreach ($path in ($candidates | Select-Object -Unique)) {
        if ($path -and (Test-Path -LiteralPath $path)) {
            return (Get-Item -LiteralPath $path).FullName
        }
    }

    return $null
}

function Get-InstalledChromeVersion {
    <#
        .SYNOPSIS
            Sistemde yuklu Google Chrome'un tam surum numarasini dondurur.
            Registry, dizin adlari ve dosya surum bilgilerini tarar.
    #>
    [CmdletBinding()]
    param([string]$ExePath = '')

    $candidates = @()

    # 1. Kayit Defteri Aramalari (WOW6432, HKLM, HKCU)
    $regPaths = @(
        'HKLM:\SOFTWARE\WOW6432Node\Google\Update\Clients\{8A69D345-D564-463C-AFF1-A69D9E530F96}',
        'HKLM:\SOFTWARE\Google\Update\Clients\{8A69D345-D564-463C-AFF1-A69D9E530F96}',
        'HKCU:\SOFTWARE\Google\Update\Clients\{8A69D345-D564-463C-AFF1-A69D9E530F96}',
        'HKCU:\Software\Google\Chrome\BLBeacon'
    )

    foreach ($regPath in $regPaths) {
        if (Test-Path -LiteralPath $regPath) {
            $item = Get-ItemProperty -LiteralPath $regPath -ErrorAction SilentlyContinue
            if ($item) {
                if ($item.PSObject.Properties['pv'] -and $item.pv) { $candidates += $item.pv }
                if ($item.PSObject.Properties['version'] -and $item.version) { $candidates += $item.version }
            }
        }
    }

    # 2. chrome.exe dosya dizinindeki surum alt klasoru (orn: 131.0.6778.86)
    if ($ExePath -and (Test-Path -LiteralPath $ExePath)) {
        $appDir = Split-Path -Parent $ExePath
        if (Test-Path -LiteralPath $appDir) {
            $diskVersion = Get-ChildItem -Path $appDir -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+$' } |
                Sort-Object { [version]$_.Name } -Descending |
                Select-Object -First 1 -ExpandProperty Name
            if ($diskVersion) { $candidates += $diskVersion }
        }

        # 3. chrome.exe dosyasinin ProductVersion bilgisi
        try {
            $fileVersion = (Get-Item -LiteralPath $ExePath).VersionInfo.ProductVersion
            if ($fileVersion) { $candidates += $fileVersion }
        } catch {}
    }

    $validVersions = $candidates | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' } | Select-Object -Unique

    if ($validVersions.Count -eq 0) {
        throw 'Sistemde kurulu Google Chrome surumu tespit edilemedi. Lutfen Chrome yolunu kontrol ediniz.'
    }

    $resolved = $validVersions | Sort-Object { [version]$_ } -Descending | Select-Object -First 1
    return $resolved
}

function Get-CurrentChromeDriverVersion {
    <#
        .SYNOPSIS
            Hedefteki chromedriver.exe dosyasinin surumunu --version argumani ile okur.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ExePath)

    if (-not (Test-Path -LiteralPath $ExePath)) {
        return $null
    }

    $proc = $null
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $ExePath
        $psi.Arguments = '--version'
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        $null = $proc.Start()

        $outputLine = $proc.StandardOutput.ReadLine()
        $proc.WaitForExit(3000) | Out-Null

        if ($outputLine -match 'ChromeDriver\s+(?<version>\d+\.\d+\.\d+\.\d+)') {
            return $matches['version']
        }
        return $null
    } catch {
        return $null
    } finally {
        if ($proc -and -not $proc.HasExited) { try { $proc.Kill() } catch {} }
        if ($proc) { $proc.Dispose() }
    }
}

function Stop-ChromeProcesses {
    <#
        .SYNOPSIS
            Yalnizca hedef chromedriver sureclerini sonlandirir. Chrome tarayicisina dokunmaz.
    #>
    [CmdletBinding()]
    param([scriptblock]$LogCb = $null)

    # Kullanicinin calisan Chrome sekmelerini korumak icin yalnizca chromedriver sonlandirilir
    $processNames = @('chromedriver')
    $killedAny = $false

    foreach ($name in $processNames) {
        $procs = Get-Process -Name $name -ErrorAction SilentlyContinue
        if ($procs) {
            foreach ($proc in $procs) {
                try {
                    Write-Log "ChromeDriver sureci sonlandiriliyor (PID: $($proc.Id))" -Level 'INFO' -Callback $LogCb
                    Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                    $killedAny = $true
                } catch {
                    Write-Log "Surec sonlandirilamadi (PID: $($proc.Id)): $($_.Exception.Message)" -Level 'WARN' -Callback $LogCb
                }
            }
        }
    }

    if ($killedAny) {
        Start-Sleep -Milliseconds 600
    }
    return $killedAny
}

function Clean-TargetDirectory {
    <#
        .SYNOPSIS
            Hedef klasordeki (C:\RobustaWorker\driver) chromedriver.log,
            chromedriver.txt ve eski gecici artik dosyalari temizler.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$DriverDir,
        [scriptblock]$LogCb = $null
    )

    if (-not (Test-Path -LiteralPath $DriverDir)) { return }

    $targetFiles = @(
        (Join-Path $DriverDir 'chromedriver.log'),
        (Join-Path $DriverDir 'chromedriver.txt')
    )

    # Diger olasi artiklar (.tmp, .old vb.)
    $extraArtifacts = Get-ChildItem -Path $DriverDir -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in @('.tmp', '.old', '.bak') -or $_.Name -like 'chromedriver_*.zip' }

    foreach ($file in $extraArtifacts) {
        $targetFiles += $file.FullName
    }

    foreach ($file in ($targetFiles | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $file) {
            try {
                Remove-Item -LiteralPath $file -Force -ErrorAction Stop
                Write-Log "Hedef klasor temizlendi: $file" -Level 'INFO' -Callback $LogCb
            } catch {
                Write-Log "Dosya silinemedi (Kilitli olabilir): $file" -Level 'WARN' -Callback $LogCb
            }
        }
    }
}

function Remove-OldDriverExe {
    <#
        .SYNOPSIS
            Eski chromedriver.exe dosyasini kaldirir. Kilitli ise surecleri sonlandirarak 3 kez dener.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$DriverExePath,
        [scriptblock]$LogCb = $null
    )

    if (-not (Test-Path -LiteralPath $DriverExePath)) { return }

    $attempts = 0
    $removed = $false

    while (-not $removed -and $attempts -lt 3) {
        $attempts++
        try {
            Remove-Item -LiteralPath $DriverExePath -Force -ErrorAction Stop
            $removed = $true
            Write-Log "Eski surucu silindi: $DriverExePath" -Level 'INFO' -Callback $LogCb
        } catch {
            Write-Log "Surucu dosyasi silinemedi ($attempts. deneme). Surecler durduruluyor..." -Level 'WARN' -Callback $LogCb
            Stop-ChromeProcesses -LogCb $LogCb | Out-Null
            Start-Sleep -Seconds 1
        }
    }

    if (-not $removed -and (Test-Path -LiteralPath $DriverExePath)) {
        throw "Eski chromedriver.exe silinemedi (Dosya kilitli veya yetki yetersiz). Hedef: $DriverExePath"
    }
}

function Get-ChromeDriverDownloadUrl {
    <#
        .SYNOPSIS
            Google Cloud Storage veya Chrome for Testing API uzerinden
            hedef Chrome surumu icin en uygun indirme URL'sini cozumler.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ChromeVersion,
        [scriptblock]$LogCb = $null
    )

    $platform = if ([Environment]::Is64BitOperatingSystem) { 'win64' } else { 'win32' }

    # 1. Oncelikli Yontem: Dogrudan Google Storage URL
    $directUrl = "https://storage.googleapis.com/chrome-for-testing-public/$ChromeVersion/$platform/chromedriver-$platform.zip"
    Write-Log "Dogrudan Google Storage kontrol ediliyor: $directUrl" -Level 'DEBUG' -Callback $LogCb

    try {
        $headRequest = Invoke-WebRequest -Uri $directUrl -Method Head -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        if ($headRequest.StatusCode -eq 200) {
            Write-Log "Dogrudan indirme URL'si dogrulandi (200 OK)." -Level 'INFO' -Callback $LogCb
            return @{
                Url             = $directUrl
                ResolvedVersion = $ChromeVersion
                Method          = 'DirectStorage'
            }
        }
    } catch {
        Write-Log "Dogrudan URL'de bulunamadi ($($_.Exception.Message)). CFT API yedek mekanizmasi devreye aliniyor..." -Level 'INFO' -Callback $LogCb
    }

    # 2. Yedek Yontem: Chrome for Testing Patch Versions API
    try {
        $cftApiUrl = 'https://googlechromelabs.github.io/chrome-for-testing/latest-patch-versions-per-build-with-downloads.json'
        Write-Log "CFT API sorgulaniyor: $cftApiUrl" -Level 'INFO' -Callback $LogCb
        $cftData = Invoke-RestMethod -Uri $cftApiUrl -UseBasicParsing -TimeoutSec 15

        # Versiyon on ekini al (orn: 131.0.6778)
        $versionParts = $ChromeVersion.Split('.')
        if ($versionParts.Count -ge 3) {
            $prefix = "$($versionParts[0]).$($versionParts[1]).$($versionParts[2])"
            if ($cftData.builds.$prefix) {
                $build = $cftData.builds.$prefix
                $driverDownloads = $build.downloads.chromedriver
                $match = $driverDownloads | Where-Object { $_.platform -eq $platform } | Select-Object -First 1
                if ($match) {
                    Write-Log "CFT API'den uyumlu patch surumu bulundu: $($build.version)" -Level 'SUCCESS' -Callback $LogCb
                    return @{
                        Url             = $match.url
                        ResolvedVersion = $build.version
                        Method          = 'CftApiPrefix'
                    }
                }
            }
        }
    } catch {
        Write-Log "CFT API sorgusu basarisiz: $($_.Exception.Message)" -Level 'WARN' -Callback $LogCb
    }

    # 3. Son Deneme: Standart directUrl ile devam et
    return @{
        Url             = $directUrl
        ResolvedVersion = $ChromeVersion
        Method          = 'DirectStorageFallback'
    }
}

function Download-ChromeDriverArchive {
    <#
        .SYNOPSIS
            Belirtilen URL'den ChromeDriver zip dosyasini indirir.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$Destination,
        [int]$Timeout = 120,
        [scriptblock]$LogCb = $null,
        [scriptblock]$ProgressCb = $null
    )

    Write-Log "Indiriliyor: $Url" -Level 'INFO' -Callback $LogCb
    $destDir = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    $wc = New-Object System.Net.WebClient
    try {
        if ($ProgressCb) {
            $wc.add_DownloadProgressChanged({
                param($s, $e)
                try { & $ProgressCb $e.ProgressPercentage } catch {}
            })
        }
        $wc.DownloadFile($Url, $Destination)
    } catch {
        throw "Dosya indirilemedi. URL: $Url. Hata: $($_.Exception.Message)"
    } finally {
        $wc.Dispose()
    }

    if (-not (Test-Path -LiteralPath $Destination) -or (Get-Item -LiteralPath $Destination).Length -eq 0) {
        throw "Indirme basarisiz oldu veya inen dosya bos: $Destination"
    }

    $fileSizeMB = [math]::Round(((Get-Item -LiteralPath $Destination).Length / 1MB), 2)
    Write-Log "Arsiv basariyla indirildi ($fileSizeMB MB): $Destination" -Level 'SUCCESS' -Callback $LogCb
}

function Install-ChromeDriverBinary {
    <#
        .SYNOPSIS
            Indirilen zip arsivini acar, chromedriver.exe dosyasini hedefe yerlestirir.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ZipPath,
        [Parameter(Mandatory)][string]$ExtractDir,
        [Parameter(Mandatory)][string]$TargetExePath,
        [scriptblock]$LogCb = $null
    )

    if (Test-Path -LiteralPath $ExtractDir) {
        Remove-Item -LiteralPath $ExtractDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Log "Arsiv aciliyor..." -Level 'INFO' -Callback $LogCb
    Expand-Archive -LiteralPath $ZipPath -DestinationPath $ExtractDir -Force

    $extractedExe = Get-ChildItem -Path $ExtractDir -Filter 'chromedriver.exe' -Recurse | Select-Object -First 1
    if (-not $extractedExe) {
        throw "Indirilen zip arsivi icinde chromedriver.exe bulunamadi."
    }

    $targetDir = Split-Path -Parent $TargetExePath
    if (-not (Test-Path -LiteralPath $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        Write-Log "Hedef klasor olusturuldu: $targetDir" -Level 'INFO' -Callback $LogCb
    }

    # Eski hedef dosya varsa kaldir
    Remove-OldDriverExe -DriverExePath $TargetExePath -LogCb $LogCb

    Write-Log "Yeni ChromeDriver hedefe tasiniyor: $TargetExePath" -Level 'INFO' -Callback $LogCb
    Move-Item -LiteralPath $extractedExe.FullName -Destination $TargetExePath -Force

    # Stabilite beklemesi
    $waited = 0
    while (-not (Test-Path -LiteralPath $TargetExePath) -and $waited -lt 15) {
        Start-Sleep -Seconds 1
        $waited++
    }

    if (-not (Test-Path -LiteralPath $TargetExePath)) {
        throw "Yeni ChromeDriver hedef klasore tasinamadi: $TargetExePath"
    }

    Write-Log "ChromeDriver basariyla yerlestirildi." -Level 'SUCCESS' -Callback $LogCb
}

function Get-ChromeDriverInspectionStatus {
    <#
        .SYNOPSIS
            Sistemdeki Chrome ve hedefteki ChromeDriver durumunu denetler ve ozet nesnesi dondurur.
    #>
    [CmdletBinding()]
    param(
        [string]$DriverDir = 'C:\RobustaWorker\driver',
        [string]$ChromeExePath = ''
    )

    $resolvedChromeExe = Find-InstalledChromeExe -PreferredPath $ChromeExePath
    $chromeVersion = $null
    $driverVersion = $null
    $targetExePath = Join-Path $DriverDir 'chromedriver.exe'

    if ($resolvedChromeExe) {
        try {
            $chromeVersion = Get-InstalledChromeVersion -ExePath $resolvedChromeExe
        } catch {}
    }

    if (Test-Path -LiteralPath $targetExePath) {
        $driverVersion = Get-CurrentChromeDriverVersion -ExePath $targetExePath
    }

    $status = 'Unknown'
    $isMatch = $false

    if (-not $resolvedChromeExe -or -not $chromeVersion) {
        $status = 'ChromeNotFound'
    } elseif (-not (Test-Path -LiteralPath $targetExePath)) {
        $status = 'DriverMissing'
    } elseif ($driverVersion -eq $chromeVersion) {
        $status = 'UpToDate'
        $isMatch = $true
    } else {
        $status = 'UpdateNeeded'
    }

    return [PSCustomObject]@{
        ChromeExePath = $resolvedChromeExe
        ChromeVersion = $chromeVersion
        DriverExePath = $targetExePath
        DriverVersion = $driverVersion
        Status        = $status
        IsMatch       = $isMatch
    }
}

function Invoke-ChromeDriverUpdate {
    <#
        .SYNOPSIS
            Guncelleme operasyonunun tum adimlarini calistirir.
            Hem CLI hem de GUI tarafindan ortak cagirilan ana islem orkestratorudur.
    #>
    [CmdletBinding()]
    param(
        [string]$DriverDir = 'C:\RobustaWorker\driver',
        [string]$ChromeExePath = '',
        [switch]$Force,
        [switch]$AutoKillProcesses = $true,
        [switch]$CleanTarget = $true,
        [bool]$UpdateBrowserFirst = $true,
        [switch]$NoBrowserUpdate,
        [scriptblock]$LogCb = $null,
        [scriptblock]$ProgressCb = $null
    )

    $targetExePath = Join-Path $DriverDir 'chromedriver.exe'
    $resolvedChromeExe = Find-InstalledChromeExe -PreferredPath $ChromeExePath

    $tempWorkDir = Join-Path $script:TempBaseDir "update_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    $zipPath = Join-Path $tempWorkDir 'chromedriver.zip'
    $extractDir = Join-Path $tempWorkDir 'extracted'

    Write-Log '====================================================' -Callback $LogCb
    Write-Log 'ChromeDriverUpdater islemi baslatildi.' -Callback $LogCb

    try {
        # 1. Hedef Temizligi
        if ($CleanTarget) {
            Clean-TargetDirectory -DriverDir $DriverDir -LogCb $LogCb
        }

        # 2. Gercek Google Chrome UIA Denetimi ve Relaunch (Tarayici Guncelligi Dogrulamasi)
        if (-not $resolvedChromeExe) {
            throw 'Google Chrome calistirilabilir dosyasi (chrome.exe) sistemde bulunamadi.'
        }
        $chromeVersion = Get-InstalledChromeVersion -ExePath $resolvedChromeExe
        Write-Log "Sistemdeki Google Chrome dosya surumu: $chromeVersion (Dosya: $resolvedChromeExe)" -Level 'INFO' -Callback $LogCb

        # Once tarayici UIA ile acilip bekleyen relaunch var mi kontrol edilir
        if ($UpdateBrowserFirst -and -not $NoBrowserUpdate) {
            $uiaScriptPath = Join-Path $script:ScriptDir 'Invoke-ChromeRelaunchUIA.ps1'
            if (Test-Path -LiteralPath $uiaScriptPath) {
                Write-Log '----------------------------------------------------' -Callback $LogCb
                Write-Log "ADIM 1/2: Google Chrome UIA ile acilarak guncelleme & relaunch denetleniyor..." -Level 'INFO' -Callback $LogCb
                try {
                    $uiaResult = & $uiaScriptPath `
                        -ChromeExePath $resolvedChromeExe `
                        -CleanSession:$true `
                        -WaitForRestart:$true `
                        -CloseAfterCheck:$true

                    if ($uiaResult -and $uiaResult.Success) {
                        if ($uiaResult.Relaunched -and $uiaResult.NewVersion) {
                            Write-Log "Google Chrome basariyla yeni surume guncellendi: $($uiaResult.NewVersion) (Eski: $($uiaResult.OldVersion))" -Level 'SUCCESS' -Callback $LogCb
                            $chromeVersion = $uiaResult.NewVersion
                        } elseif ($uiaResult.CurrentVersion) {
                            Write-Log "Google Chrome gercek oturumda denetlendi, zaten en guncel surumde: $($uiaResult.CurrentVersion)" -Level 'SUCCESS' -Callback $LogCb
                            $chromeVersion = $uiaResult.CurrentVersion
                        }
                    } else {
                        Write-Log "UIA tarayici denetimi uyarisi ($($uiaResult.Message)). Mevcut surumle devam ediliyor: $chromeVersion" -Level 'WARN' -Callback $LogCb
                    }
                } catch {
                    Write-Log "UIA tarayici guncelleme adiminda hata olustu: $($_.Exception.Message). Disk surumuyle ($chromeVersion) devam ediliyor." -Level 'WARN' -Callback $LogCb
                }
                Write-Log '----------------------------------------------------' -Callback $LogCb
            } else {
                Write-Log "UIA denetim betigi ($uiaScriptPath) bulunamadi, mevcut surumle ($chromeVersion) devam ediliyor." -Level 'WARN' -Callback $LogCb
            }
        }

        Write-Log "ADIM 2/2: Dogrulanan Chrome surumu ($chromeVersion) baz alinarak ChromeDriver senkronize ediliyor..." -Level 'INFO' -Callback $LogCb

        # 3. Mevcut ChromeDriver Surum Kontrolu
        $currentDriverVersion = Get-CurrentChromeDriverVersion -ExePath $targetExePath

        if ($currentDriverVersion) {
            Write-Log "Hedefteki mevcut ChromeDriver surumu: $currentDriverVersion" -Level 'INFO' -Callback $LogCb
        } else {
            Write-Log "Hedef klasorde gecerli ChromeDriver bulunamadi." -Level 'WARN' -Callback $LogCb
        }

        # 4. Guncellik Kontrolu (Force degilse)
        if (-not $Force -and ($currentDriverVersion -eq $chromeVersion)) {
            Write-Log "ChromeDriver zaten guncel (Surum: $currentDriverVersion). Indirme atlaniyor." -Level 'SUCCESS' -Callback $LogCb
            return [PSCustomObject]@{
                Success       = $true
                Updated       = $false
                ChromeVersion = $chromeVersion
                DriverVersion = $currentDriverVersion
                Message       = 'ChromeDriver zaten guncel.'
            }
        }

        if ($Force) {
            Write-Log "Zorla guncelleme modu (Force) aktif. Sürücü yeniden indirilecek." -Level 'WARN' -Callback $LogCb
        } elseif ($currentDriverVersion) {
            Write-Log "Surum uyumsuzlugu tespit edildi: Eski: $currentDriverVersion -> Yeni Hedef: $chromeVersion" -Level 'WARN' -Callback $LogCb
        } else {
            Write-Log "Yeni ChromeDriver kurulacak: $chromeVersion" -Level 'INFO' -Callback $LogCb
        }

        # 5. Surecleri Sonlandirma
        if ($AutoKillProcesses) {
            Stop-ChromeProcesses -LogCb $LogCb | Out-Null
        }

        # 6. Gecici Dizin Hazirligi
        if (-not (Test-Path -LiteralPath $script:TempBaseDir)) {
            New-Item -ItemType Directory -Path $script:TempBaseDir -Force | Out-Null
        }
        New-Item -ItemType Directory -Path $tempWorkDir -Force | Out-Null

        # 7. Indirme URL'sini Cozumleme ve Indirme
        $urlInfo = Get-ChromeDriverDownloadUrl -ChromeVersion $chromeVersion -LogCb $LogCb
        $downloadUrl = $urlInfo.Url

        Download-ChromeDriverArchive -Url $downloadUrl -Destination $zipPath -LogCb $LogCb -ProgressCb $ProgressCb

        # 8. Arsivden Cikarma ve Kurulum
        Install-ChromeDriverBinary -ZipPath $zipPath -ExtractDir $extractDir -TargetExePath $targetExePath -LogCb $LogCb

        # 9. Kurulum Dogrulamasi
        $verifiedVersion = Get-CurrentChromeDriverVersion -ExePath $targetExePath
        Write-Log "Kurulum sonrasi tespit edilen ChromeDriver surumu: $verifiedVersion" -Level 'INFO' -Callback $LogCb

        # Surum dogrulamasi (milestone eslesmesi veya birebir eslesme)
        $isMatch = ($verifiedVersion -eq $chromeVersion) -or ($verifiedVersion -eq $urlInfo.ResolvedVersion)
        if ($isMatch) {
            Write-Log "Surum dogrulandi ve ChromeDriver guncellemesi basariyla tamamlandi." -Level 'SUCCESS' -Callback $LogCb
            
            # Ayarlari guncelle (LastUpdated)
            $cfg = Get-AppConfig
            $cfg.LastUpdated = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            Save-AppConfig -Config $cfg

            return [PSCustomObject]@{
                Success       = $true
                Updated       = $true
                ChromeVersion = $chromeVersion
                DriverVersion = $verifiedVersion
                Message       = 'ChromeDriver basariyla guncellendi.'
            }
        } else {
            throw "Yeni ChromeDriver kuruldu ancak surum dogrulanamadi. (Beklenen: $chromeVersion, Bulunan: $verifiedVersion)"
        }

    } catch {
        Write-Log "HATA: $($_.Exception.Message)" -Level 'ERROR' -Callback $LogCb
        return [PSCustomObject]@{
            Success       = $false
            Updated       = $false
            ChromeVersion = $null
            DriverVersion = $null
            Message       = $_.Exception.Message
        }
    } finally {
        if (Test-Path -LiteralPath $tempWorkDir) {
            Remove-Item -LiteralPath $tempWorkDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        Write-Log 'ChromeDriverUpdater sonlandi.' -Callback $LogCb
        Write-Log '====================================================' -Callback $LogCb
    }
}

# ----------------- CALISTIRMA MODU SECIMI (CLI / GUI) -----------------

# Eger sadece fonksiyonlar import ediliyorsa calistirmadan don
if ($ImportOnly -or ($MyInvocation.InvocationName -eq '.')) {
    return
}

# Yapilandirma yukle
$config = Get-AppConfig

# Parametre onceliklendirme
if ([string]::IsNullOrEmpty($DriverDir)) { $DriverDir = $config.DriverDir }
if ([string]::IsNullOrEmpty($ChromeExePath)) { $ChromeExePath = $config.ChromeExePath }

$shouldKill = if ($NoKillProcesses) { $false } elseif ($KillProcesses) { $true } else { $config.AutoKillProcesses }
$shouldClean = $config.CleanTarget

# GUI Modu Kontrolu:
# -GUI belirtildiyse VEYA (-Silent/-NoGui/-CheckOnly/-CleanOnly belirtilmemis ve interaktif oturumsa)
$isInteractive = [Environment]::UserInteractive -and -not $Silent -and -not $NoGui -and -not $CheckOnly -and -not $CleanOnly
$launchGui = $GUI -or ($isInteractive -and ($PSCmdlet.ParameterSetName -eq 'Default'))

if ($launchGui) {
    $guiScriptPath = Join-Path $script:ScriptDir 'ChromeDriverUpdater-GUI.ps1'
    if (Test-Path -LiteralPath $guiScriptPath) {
        & $guiScriptPath -DriverDir $DriverDir -ChromeExePath $ChromeExePath
        exit 0
    } else {
        Write-Log "GUI betigi bulunamadi ($guiScriptPath), CLI modunda devam ediliyor..." -Level 'WARN'
    }
}

# ----------------- CLI CALISTIRMA AKISI -----------------

if ($CleanOnly) {
    Write-Log "Yalnizca hedef temizligi modu calistiriliyor..." -Level 'INFO'
    Clean-TargetDirectory -DriverDir $DriverDir
    exit 0
}

if ($CheckOnly) {
    Write-Log "Surum denetim modu calistiriliyor..." -Level 'INFO'
    $statusObj = Get-ChromeDriverInspectionStatus -DriverDir $DriverDir -ChromeExePath $ChromeExePath
    Write-Host "Chrome Exe     : $($statusObj.ChromeExePath)"
    Write-Host "Chrome Surumu  : $($statusObj.ChromeVersion)"
    Write-Host "Driver Exe     : $($statusObj.DriverExePath)"
    Write-Host "Driver Surumu  : $($statusObj.DriverVersion)"
    Write-Host "Durum          : $($statusObj.Status)"
    
    if ($statusObj.IsMatch) {
        Write-Log "ChromeDriver guncel." -Level 'SUCCESS'
        exit 0
    } else {
        Write-Log "ChromeDriver guncellemesi gerekli!" -Level 'WARN'
        exit 2
    }
}

# Normal Guncelleme Calistirma
$shouldUpdateBrowser = if ($NoBrowserUpdate) { $false } elseif ($UpdateBrowserFirst) { $true } else { $config.UpdateBrowserFirst }

$updateResult = Invoke-ChromeDriverUpdate `
    -DriverDir $DriverDir `
    -ChromeExePath $ChromeExePath `
    -Force:$Force `
    -AutoKillProcesses:$shouldKill `
    -CleanTarget:$shouldClean `
    -UpdateBrowserFirst:$shouldUpdateBrowser

if ($updateResult.Success) {
    exit 0
} else {
    exit 1
}
