@echo off
setlocal EnableExtensions

for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "ROM=%ROOT%\builds\whatif.md"
set "LUA=%ROOT%\tools\bizhawk_phase3_overworld_full_probe.lua"
set "REPORT_DIR=%ROOT%\builds\reports"
set "JSON_REPORT=%REPORT_DIR%\bizhawk_phase3_overworld_full_probe.json"
set "TEXT_REPORT=%REPORT_DIR%\bizhawk_phase3_overworld_full_probe.txt"

if not exist "%ROM%" (
    echo ERROR: Missing ROM: %ROM%
    exit /b 1
)

if not exist "%LUA%" (
    echo ERROR: Missing Lua probe script: %LUA%
    exit /b 1
)

if not exist "%REPORT_DIR%" mkdir "%REPORT_DIR%"
if exist "%JSON_REPORT%" del /f /q "%JSON_REPORT%" >nul 2>nul
if exist "%TEXT_REPORT%" del /f /q "%TEXT_REPORT%" >nul 2>nul

powershell -ExecutionPolicy Bypass -File "%ROOT%\tools\launch_bizhawk.ps1" -RomPath "%ROM%" -LuaPath "%LUA%" -Wait
set "EMU_EXIT=%ERRORLEVEL%"

if not "%EMU_EXIT%"=="0" (
    echo BizHawk exit code: %EMU_EXIT%
    exit /b %EMU_EXIT%
)

set "PYTHON_CMD=python"
if defined PYTHON set "PYTHON_CMD=%PYTHON%"

%PYTHON_CMD% "%ROOT%\tools\check_overworld_full_fidelity.py"
set "CHECK_EXIT=%ERRORLEVEL%"

if exist "%TEXT_REPORT%" (
    echo.
    type "%TEXT_REPORT%"
)

exit /b %CHECK_EXIT%
