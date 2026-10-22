@echo off
setlocal
cd /d "%~dp0.."
title ST-LINK rescue flash - do not close this window
powershell -NoProfile -ExecutionPolicy Bypass -NoExit -File "%~dp0Flash-Fixed.ps1"
if errorlevel 1 (
  echo.
  echo If the window above shows a script-signature error, run this once in PowerShell:
  echo   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
  pause
)
