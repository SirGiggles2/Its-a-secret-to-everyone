@echo off
rem build_all.bat — thin wrapper around build_all.ps1.
rem Per debate 006 D3: build BOTH ROMs (Title.md + RoomRom.md) every commit
rem touching shared substrate. PowerShell wrapper used because cmd.exe `call`
rem semantics drop ERRORLEVEL across nested .bat scripts inconsistently.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0build_all.ps1"
exit /b %ERRORLEVEL%
