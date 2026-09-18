@echo off
title Robusta - Chrome UIA Relaunch Testi
echo ======================================================================
echo Chrome UIA Otomatik Yeniden Baslatma (Relaunch) Testi Baslatiliyor...
echo DIKKAT: Bekleyen guncelleme varsa Chrome YENIDEN BASLATILACAKTIR.
echo ======================================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Invoke-ChromeRelaunchUIA.ps1"

echo.
echo ======================================================================
echo Islem tamamlandi. Cikis icin bir tusa basin.
echo ======================================================================
pause >nul
