@echo off
title Robusta - Chrome About UIA Denetimi
echo ======================================================================
echo Chrome About (chrome://settings/help) UIA Agac Denetimi Baslatiliyor...
echo (Bu test sadece tarama yapar, Chrome'u YENIDEN BASLATMAZ)
echo ======================================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Inspect-ChromeAboutUIA.ps1"

echo.
echo ======================================================================
echo Islem tamamlandi. Pencereyi kapatmak icin bir tusa basin.
echo ======================================================================
pause >nul
