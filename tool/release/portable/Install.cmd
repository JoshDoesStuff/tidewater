@echo off
rem Installs Tidewater for this user only (no admin): copies it to %LOCALAPPDATA%\Programs\Tidewater
rem and adds a Start menu shortcut. Run it from the unzipped Tidewater folder.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-user.ps1"
pause
