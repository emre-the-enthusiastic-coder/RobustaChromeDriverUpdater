<#
    .SYNOPSIS
        Robusta Worker - ChromeDriver Otomatik Guncelleme Zamanlanmis Gorev Kurucusu

    .DESCRIPTION
        Windows Gorev Zamanlayicisi'na (Task Scheduler) ChromeDriver guncelleyici gorevini
        otomatik olarak ekler veya kaldirir. Robusta Worker VM'inde Google Chrome otomatik
        guncellendiginde, ChromeDriver'in da her sabah veya VM acilisinda otomatik
        guncellenmesini saglar.

    .PARAMETER TaskName
        Zamanlanmis gorevin adi. Varsayilan: Robusta-ChromeDriver-AutoUpdater

    .PARAMETER DailyAt
        Gorevin her gun calisacagi saat (orn: '05:00'). Varsayilan: '05:00'

    .PARAMETER AtStartup
        Gorevin VM sistem acilisinda (Startup) calismasini saglar.

    .PARAMETER AtLogon
        Gorevin kullanici oturum actiginda (Logon) calismasini saglar.

    .PARAMETER DriverDir
        Hedef Robusta driver klasoru. Varsayilan: C:\RobustaWorker\driver

    .PARAMETER Uninstall
        Mevcut zamanlanmis gorevi sistemden kaldirir.
#>

[CmdletBinding()]
param(
    [string]$TaskName = 'Robusta-ChromeDriver-AutoUpdater',
    [string]$DailyAt = '05:00',
    [switch]$AtStartup,
    [switch]$AtLogon,
    [string]$DriverDir = 'C:\RobustaWorker\driver',
    [switch]$Uninstall
)

$scriptDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($scriptDir)) {
    $scriptDir = (Get-Location).Path
}

$updaterScript = Join-Path $scriptDir 'ChromeDriverUpdater.ps1'

# Yonetici yetkisi kontrolu
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Bu scriptin Windows Gorev Zamanlayicisi'na gorev ekleyebilmesi icin 'Yonetici Olarak Calistir' (Run as Administrator) ile calistirilmasi gerekir."
}

if ($Uninstall) {
    Write-Host "Zamanlanmis gorev kaldiriliyor: $TaskName..." -ForegroundColor Yellow
    try {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
        Write-Host "Gorev basariyla kaldirildi: $TaskName" -ForegroundColor Green
    } catch {
        Write-Host "Gorev kaldirilamadi veya zaten mevcut degil: $($_.Exception.Message)" -ForegroundColor Red
    }
    exit 0
}

# Calistirilacak eylem
$psExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$taskArg = "-ExecutionPolicy Bypass -NoProfile -File `"$updaterScript`" -DriverDir `"$DriverDir`" -Silent"
$action = New-ScheduledTaskAction -Execute $psExe -Argument $taskArg -WorkingDirectory $scriptDir

# Tetikleyici (Trigger)
$triggers = @()
if ($AtStartup) {
    $triggers += New-ScheduledTaskTrigger -AtStartup
    Write-Host "Tetikleyici: Sistem Acilisi (AtStartup)" -ForegroundColor Cyan
} elseif ($AtLogon) {
    $triggers += New-ScheduledTaskTrigger -AtLogOn
    Write-Host "Tetikleyici: Kullanici Oturumu (AtLogon)" -ForegroundColor Cyan
} else {
    try {
        $triggerTime = [DateTime]::ParseExact($DailyAt, 'HH:mm', $null)
        $triggers += New-ScheduledTaskTrigger -Daily -At $DailyAt
        Write-Host "Tetikleyici: Her gun saat $DailyAt" -ForegroundColor Cyan
    } catch {
        throw "Gecersiz saat formati: $DailyAt. Lutfen 'HH:mm' formatinda giriniz (orn: '05:00')."
    }
}

# Gorev ayarlari
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 15)

$description = "Robusta Worker icin Google Chrome ve ChromeDriver surumlerini otomatik denetler ve gunceller."

try {
    # Varsa once eskiyi kaldir
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

    # Yeni gorevi kaydet (En yuksek yetkiyle SYSTEM veya Administrators altinda)
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $triggers `
        -Settings $settings `
        -Description $description `
        -RunLevel Highest `
        -User "NT AUTHORITY\SYSTEM" | Out-Null

    Write-Host "Zamanlanmis gorev basariyla olusturuldu!" -ForegroundColor Green
    Write-Host "Gorev Adi       : $TaskName"
    Write-Host "Hedef Driver    : $DriverDir"
    Write-Host "Calisma Sekli   : Sessiz CLI (-Silent)"
    Write-Host "Test etmek icin : Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Cyan
} catch {
    # SYSTEM kullanicisi ile basarisiz olursa CurrentUser ile dene
    try {
        Register-ScheduledTask `
            -TaskName $TaskName `
            -Action $action `
            -Trigger $triggers `
            -Settings $settings `
            -Description $description `
            -RunLevel Highest | Out-Null
        
        Write-Host "Zamanlanmis gorev mevcut kullanici ile basariyla olusturuldu!" -ForegroundColor Green
        Write-Host "Gorev Adi       : $TaskName"
    } catch {
        Write-Error "Zamanlanmis gorev olusturulamadi: $($_.Exception.Message)"
        exit 1
    }
}
