@echo off
rem ========================================================================
rem Robusta Worker - ChromeDriver Updater (GUI Baslatici)
rem Windows VM'lerde konsol penceresi acilmadan dogrudan WPF arayuzunu baslatir.
rem ========================================================================

cd /d "%~dp0"
start "" powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0ChromeDriverUpdater.ps1" -GUI %*
exit /b 0
