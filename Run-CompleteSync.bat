@echo off
title Robusta Worker - Tam Senkronizasyon (UIA Chrome Relaunch + ChromeDriver)
echo ======================================================================
echo ROBUSTA WORKER - TAM SENKRONIZASYON ISLEMI BASLATILIYOR
echo ----------------------------------------------------------------------
echo 1. Adim: Google Chrome UIA ile acilacak ve bekleyen guncelleme
echo          varsa Chrome YENIDEN BASLATILACAKTIR (Relaunch).
echo 2. Adim: Kesinlesen guncel Chrome surumune gore C:\RobustaWorker\driver
echo          altindaki chromedriver.exe senkronize edilecektir.
echo ======================================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ChromeDriverUpdater.ps1" -UpdateBrowserFirst

echo.
echo ======================================================================
echo Islem tamamlandi. Cikis icin bir tusa basin.
echo ======================================================================
pause >nul
