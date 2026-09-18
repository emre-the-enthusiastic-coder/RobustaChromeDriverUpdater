# Robusta Worker - ChromeDriver Guncelleyici (v2.0)

Robusta RPA Worker sanal makineleri (Windows VM) icin gelistirilmis, **harici kutuphane ve yazilim dili gerektirmeyen (Zero-Dependency)** akilli ChromeDriver guncelleme ve yonetim araci.

Bu arac, sistemde kurulu Google Chrome surumu ile hedefteki (`C:\RobustaWorker\driver\chromedriver.exe`) surucuyu karsilastirir, uyumsuzluk tespit ederse Google Storage ve Chrome for Testing altyapisindan dogrudan ve guvenle guncel surumu indirip kurar.

Hem **modern masaustu arayuzu (WPF GUI)** ile tek tikla gorsel yonetim, hem de **komut satiri (CLI / Sessiz mod)** ile Robusta is akislari ve Windows Gorev Zamanlayicisi icinden tam otomatik calisma destegi sunar.

---

## 🎯 Cozulen Problem

Robusta Worker robotlari web otomasyonu yaparken, sanal makinedeki Google Chrome tarayicisi arka planda otomatik guncellendiginde su kritik hata meydana gelir:

> `SessionNotCreatedException: This version of ChromeDriver only supports Chrome version X. Current browser version is Y...`

Bu hata olustugunda ChromeDriver guncellenene kadar tum web RPA surecleri durur. Bu arac:
1. Surum farkini aninda tespit eder.
2. Hedef klasorde kilitli kalan `chromedriver.exe` sureclerini kapatir (Kullanicinin acik Google Chrome tarayicisina ve sekmelerine ASLA dokunmaz).
3. Hedef klasordeki eski `chromedriver.log`, `.txt` ve artik dosyalari temizler.
4. Google Storage uzerinden dogru surumu indirir, acar ve hedefe yerlestirir.
5. Kurulan surucunun calisirligini `--version` ile dogrular.
6. Hedef klasorde **SADECE** temiz bir `chromedriver.exe` birakir.

---

## 🚀 Temel Ozellikler

* **Sifir Harici Bagimlilik (Zero-Dependency):** Python, Node.js, .NET SDK, Chocolatey veya harici PowerShell modulu gerektirmez. Windows 10, 11 ve Windows Server 2016/2019/2022 isletim sistemlerinde yerlesik bulunan Windows PowerShell 5.1+ ve .NET Framework ile kutudan ciktigi gibi calisir.
* **Cift Mod Calisma (Dual-Mode):**
  * **Grafik Arayuz (GUI):** Kurumsal hafif temali, canli log akisli, donmayan WPF arayuzu.
  * **Komut Satiri (CLI):** Parametrelerle calisan, standart cikis kodlari (Exit Codes) ureten sessiz mod (`-Silent`).
* **Akilli UI Automation (UIA) Entegrasyonu:**
  * Google Chrome'u `chrome://settings/help` uzerinden acar, Windows UI Automation ile bekleyen guncelleme ("Yeniden baslat" butonu) olup olmadigini tarar.
  * Bekleyen guncelleme varsa butona tiklayarak Chrome'u yeniden baslatir ve guncelligi dogrular.
  * Kullanicinin Brave veya diger Chromium tarayicilarina kesinlikle dokunmaz; yalnizca hedef Google Chrome surecini izole yonetir.
* **Dinamik Gorsel Geri Bildirim (Visual Language):**
  * WPF arayuzunde durum basariyla sonuclanirsa Progress Bar canli yesile (`#16A34A`), hata veya engelle karsilasirsa belirgin kirmiziya (`#DC2626`) doner.
* **Donmayan Asenkron Mimari:** PowerShell Runspace ve DispatcherTimer altyapisi sayesinde indirme ve ayiklama sirasinda arayuz asla kilitlenmez ("Yanit Vermiyor / Not Responding" olmaz).
* **Akilli Indirme ve Yedek Mekanizma:**
  * Once dogrudan Google Storage URL'sini dener (`chrome-for-testing-public`).
  * 404 veya surum numarasi ozel bir patch ise otomatik olarak Chrome for Testing (CFT) JSON API'sinden en yakin eslesen surumu bulur.
* **Otomatik Temizlik & Izolasyon:**
  * Hedefteki (`driver`) log ve artiklari temizler.
  * Kendi loglarini ve gecici calisma dosyalarini scriptin kendi alt dizinlerinde (`logs/`, `temp/`) izole sekilde tutar.
* **Ayarlari Hatirlama (`config.json`):** Arayuzde secilen hedef klasor ve secenekler bir sonraki acilista otomatik hatirlanir.

---

## 📁 Dosya Yapisi

```text
D:\ChromeDriverUpdater\
│
├── ChromeDriverUpdater.ps1        # Cekirdek motor ve ortak calistirici (CLI & GUI yonlendirici)
├── ChromeDriverUpdater-GUI.ps1    # Modern WPF Grafik Arayuzu (Donmayan Runspace & Dinamik Renk)
├── Invoke-ChromeRelaunchUIA.ps1   # Chrome UIA arayuz tarama ve otomatik yeniden baslatma (Relaunch) motoru
├── Run-CompleteSync.bat           # 2 Asamali Tam Senkronizasyon (UIA Relaunch + ChromeDriver Sync)
├── Launch-GUI.bat                 # Arayuzu konsol penceresi olmadan baslatan cift tiklama kisayolu
├── Run-Silent.bat                 # Otomasyonlar ve Task Scheduler icin sessiz calistirici
├── Install-ScheduledTask.ps1      # Windows Gorev Zamanlayicisi'na otomatik gorev ekleyici
├── config.json                    # Varsayilan ve son kullanilan yapilandirma ayarlari
└── logs\                          # Islem gunluklerinin tutuldugu klasor (Git tarafindan ignore edilir)
    └── .gitkeep                   # Klasor yapisinin korunmasi icin referans dosyasi
```

---

## 🖥️ 1. Grafik Arayuz (GUI) Kullanimi

Sanal makinede cift tiklayarak yonetmek isteyen Robusta kullanicilari ve sistem yoneticileri icin sade, minimalist ve kurumsal arayuz:

1. `Launch-GUI.bat` dosyasina cift tiklayin.
2. Siyah konsol penceresi acilmadan, dogrudan kurumsal hafif arayuz ekrana gelir.
3. **Ana Gorunum (Sade Dashboard):**
   * **Chrome Surumu:** Sistemde tespit edilen Google Chrome versiyonu.
   * **Hedef Surucu:** `C:\RobustaWorker\driver` konumundaki ChromeDriver versiyonu.
   * **Durum Gostergesi:** Senkronizasyon ve saglik durumu (`GUNCEL`, `GUNCELLEME GEREKLI`, `SURUCU EKSIK`).
   * **Ana Eylemler:**
     * **`Senkronize Et` (Vurgulu Mavi):** Surucuyu tek tikla indirir, kurar ve dogrular. Otomatik olarak islem gunlugu cekmecesini acar.
     * **`Denetle`:** Hizli surum kontrolu yapar ve durumu tazeler.
4. **Acilir Cekmeceler (Expanders):**
   * **`Dizinler ve Gelismis Ayarlar` Cekmecesi:**
     * Driver dizini ve Chrome.exe dosya yolu secicileri, klasor acma ve otomatik tespit.
     * Kilitli surecleri kapatma, artik dosyalari temizleme ve zorla indirme (Force) opsiyonlari.
     * Hizli araclar: `Kilitli ChromeDriver'i Kapat`, `Hedef Klasoru Temizle`, `Log Klasorunu Ac`.
   * **`Islem Gunlugu (Audit Log)` Cekmecesi:**
     * Canli konsol akisi, panoya kopyalama, gunluk temizleme ve log dosyasini Notepad ile acma.

---

## ⚡ 2. Komut Satiri (CLI) Kullanimi

Robusta isleri, batch scriptleri veya uzaktan yonetim icin komut satiri parametreleri:

### Temel Komutlar:

```powershell
# 1. Varsayilan ayarlarla sessiz guncelleme (C:\RobustaWorker\driver)
powershell.exe -ExecutionPolicy Bypass -File .\ChromeDriverUpdater.ps1 -Silent

# 2. Ozel hedef klasor belirterek calistirma
powershell.exe -ExecutionPolicy Bypass -File .\ChromeDriverUpdater.ps1 -DriverDir "D:\Robusta\driver" -Silent

# 3. Yalnizca surum durumunu kontrol etme (Indirme yapmaz)
powershell.exe -ExecutionPolicy Bypass -File .\ChromeDriverUpdater.ps1 -CheckOnly -Silent

# 4. Surucu guncel olsa dahi zorla yeniden indirme (Force)
powershell.exe -ExecutionPolicy Bypass -File .\ChromeDriverUpdater.ps1 -Force -Silent

# 5. Yalnizca hedef klasordeki artik loglari temizleme
powershell.exe -ExecutionPolicy Bypass -File .\ChromeDriverUpdater.ps1 -CleanOnly -Silent
```

Veya hazir batch dosyasi ile:
```cmd
Run-Silent.bat
```

### CLI Parametre Tablosu:

| Parametre | Tur | Aciklama |
|---|---|---|
| `-DriverDir` | String | ChromeDriver'in kurulacagi klasor (Varsayilan: `C:\RobustaWorker\driver`). |
| `-ChromeExePath` | String | `chrome.exe` dosya yolu. Belirtilmezse sistemden otomatik bulunur. |
| `-Silent` | Switch | Arayuz acmaz, loglari konsola ve log dosyasina yazar. |
| `-CheckOnly` | Switch | Indirme yapmaz, yalnizca surumleri karsilastirir ve cikis kodu doner. |
| `-Force` | Switch | Surumler ayni olsa bile zorla yeniden indirir ve kurar. |
| `-KillProcesses` | Switch | Islem oncesi kilitli `chromedriver.exe` islemlerini kapatir (Chrome tarayicisina dokunmaz). |
| `-NoKillProcesses`| Switch | Surecleri kapatma adimini atlar. |
| `-CleanOnly` | Switch | Yalnizca hedefteki log ve artik dosyalari temizler. |
| `-UpdateBrowserFirst` | Switch | Once Google Chrome'u UIA ile acar, bekleyen guncelleme varsa Relaunch yapar, ardindan surucuyu senkronize eder. |
| `-NoBrowserUpdate` | Switch | Tarayici UIA kontrolunu atlayarak dogrudan mevcut Chrome surumunu baz alir. |
| `-LogPath` | String | Ozel log dosyasi yolu belirtmek icin kullanilir. |
| `-GUI` | Switch | Grafik kullanici arayuzunu acar. |

### Cikis Kodlari (Exit Codes):

Otomasyon scriptlerinizde `%ERRORLEVEL%` veya `$LASTEXITCODE` ile kontrol edebilirsiniz:

| Kod | Durum | Anlami |
|:---:|---|---|
| **`0`** | **Basarili** | Islem basariyla tamamlandi veya surucu zaten guncel. |
| **`1`** | **Hata** | Indirme, tasima, yetki veya dogrulama sirasinda hata olustu (loglara bakin). |
| **`2`** | **Guncelleme Gerekli** | `-CheckOnly` calistirildiginda surum uyumsuzlugu oldugunu belirtir. |

---

## 🤖 3. Robusta RPA Surecleriyle Entegrasyon

Robusta Worker uzerinde bir web otomasyon gorevi baslamadan hemen once `Run-Silent.bat` veya PowerShell scripti on-adim (Pre-task) olarak calistirilabilir.

### Ornek Batch Wrapper (`Pre-RobustaCheck.bat`):
```cmd
@echo off
echo [Robusta] ChromeDriver kontrol ediliyor...
call "D:\ChromeDriverUpdater\Run-Silent.bat"

if %ERRORLEVEL% EQU 0 (
    echo [Robusta] ChromeDriver hazir ve guncel. Gorev baslatiliyor.
    exit /b 0
) else (
    echo [Robusta] [HATA] ChromeDriver guncellenemedi! Hata kodu: %ERRORLEVEL%
    exit /b 1
)
```

Bu sayede Chrome gece guncellense dahi, sabahki ilk Robusta gorevi otomatik olarak surucuyu gunceller ve gorev hataya dusmeden devam eder.

---

## ⏰ 4. Windows Gorev Zamanlayicisi (Task Scheduler) ile Otomasyon

ChromeDriver'in sanal makinede her gun otomatik guncellenmesini saglamak icin `Install-ScheduledTask.ps1` scripti hazirlanmistir:

```powershell
# Yonetici (Administrator) PowerShell penceresinde:

# Her gun saat 05:00'te calisacak gorev ekle:
.\Install-ScheduledTask.ps1 -DailyAt "05:00"

# Veya VM her basladiginda (Sistem Acilisinda) calisacak gorev ekle:
.\Install-ScheduledTask.ps1 -AtStartup

# Ozel hedef klasor ile gorev ekle:
.\Install-ScheduledTask.ps1 -DriverDir "C:\RobustaWorker\driver" -DailyAt "04:30"

# Mevcut gorevi sistemden kaldir:
.\Install-ScheduledTask.ps1 -Uninstall
```

Bu komut, Windows Gorev Zamanlayicisi'nda en yuksek yetkiyle (`SYSTEM` hesabi) arka planda calisacak sekilde `Robusta-ChromeDriver-AutoUpdater` adli bir gorev kaydeder.

---

## 🔧 5. Yapilandirma Dosyasi (`config.json`)

Aracin varsayilan davranisi `config.json` uzerinden yonetilebilir. Arayuzden degisiklik yapildiginda bu dosya otomatik guncellenir:

```json
{
  "DriverDir": "C:\\RobustaWorker\\driver",
  "ChromeExePath": "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
  "AutoKillProcesses": true,
  "CleanTarget": true,
  "Force": false,
  "UpdateBrowserFirst": true,
  "LastUpdated": ""
}
```

---

## ❓ 6. Sorun Giderme ve SSS

### S: Dosya indirme sirasinda "Access Denied / Erisim Engellendi" hatasi aliyorum?
**C:** Robusta Worker servisi veya acik bir Chrome oturumu `C:\RobustaWorker\driver\chromedriver.exe` dosyasini kilitli tutuyor olabilir. Arayuzdeki **"Surecleri Sonlandir"** butonuna basin veya `-KillProcesses` parametresi ile scripti Yonetici (Run as Administrator) olarak calistirin.

### S: Sanal makinede internet erisimi proxy arkasinda ise ne yapilmali?
**C:** PowerShell oturumu sistemin varsayilan Windows Internet secenekleri (WinINet / Proxy) ayarlarini otomatik kullanir. Gerekirse sanal makinede `netsh winhttp import proxy source=ie` komutu verilebilir.

### S: Google Chrome cok eski bir surumse (Chrome 114 ve oncesi)?
**C:** Arac, Chrome 115 ve sonrasi icin resmi `chrome-for-testing-public` deposunu ve CFT JSON API'sini kullanir. Eski surumler icin de Google Storage uzerindeki ilgili surum arşivlerine erisim saglar.

### S: Log dosyasina nereden ulasabilirim?
**C:** Tum islemler scriptin yanindaki `logs\ChromeDriverUpdater.log` dosyasina kaydedilir. Arayuzdeki **"Log Dosyasi"** butonuna basarak Not Defteri ile dogrudan acabilirsiniz.
