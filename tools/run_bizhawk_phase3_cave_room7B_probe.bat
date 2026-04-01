@echo off
setlocal EnableExtensions

for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "BIZHAWK=%ROOT%\tools\launch_bizhawk.ps1"
set "ROM=%ROOT%\builds\WHAT IF.smd"
set "SCRIPT=%ROOT%\tools\bizhawk_phase3_cave_room7B_probe.lua"
set "OUT=%ROOT%\builds\reports\bizhawk_phase3_cave_room7B_probe.txt"

if not exist "%ROM%" (
    echo ERROR: ROM not found: %ROM%
    exit /b 1
)
if not exist "%SCRIPT%" (
    echo ERROR: Lua script not found: %SCRIPT%
    exit /b 1
)

powershell -ExecutionPolicy Bypass -File "%BIZHAWK%" "%ROM%" "%SCRIPT%" >nul 2>&1
if errorlevel 1 (
    echo ERROR: BizHawk launch failed
    exit /b 1
)

if exist "%OUT%" (
    type "%OUT%"
) else (
    echo ERROR: Probe output not found: %OUT%
    exit /b 1
)
exit /b 0
