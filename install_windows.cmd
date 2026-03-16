@echo off
setlocal

where pwsh >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0install_windows.ps1" %*
) else (
    powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0install_windows.ps1" %*
)

endlocal
