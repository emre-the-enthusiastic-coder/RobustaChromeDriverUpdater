@echo off
rem ========================================================================
rem Robusta Worker - ChromeDriver Updater (Sessiz / CLI Calistirici)
rem Robusta RPA gorevleri, Scheduled Tasks veya CMD betikleri icin uygundur.
rem ========================================================================

cd /d "%~dp0"
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0ChromeDriverUpdater.ps1" -Silent %*
exit /b %ERRORLEVEL%
