@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-and-run.ps1" -Install
if errorlevel 1 pause
