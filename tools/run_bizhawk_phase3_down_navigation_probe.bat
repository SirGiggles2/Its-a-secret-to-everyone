@echo off
setlocal EnableExtensions

for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "ROM=%ROOT%\builds\whatif.md"
set "LUA=%ROOT%\tools\bizhawk_phase3_down_navigation_probe.lua"
set "REPORT_DIR=%ROOT%\builds\reports"
set "REPORT=%REPORT_DIR%\bizhawk_phase3_down_navigation_probe.txt"

if not exist "%ROM%" (
    echo ERROR: Missing ROM: %ROM%
    exit /b 1
)

if not exist "%LUA%" (
    echo ERROR: Missing Lua probe script: %LUA%
    exit /b 1
)

if not exist "%REPORT_DIR%" mkdir "%REPORT_DIR%"
if exist "%REPORT%" del /f /q "%REPORT%" >nul 2>nul

powershell -ExecutionPolicy Bypass -File "%ROOT%\tools\launch_bizhawk.ps1" -RomPath "%ROM%" -LuaPath "%LUA%" -Wait
set "EMU_EXIT=%ERRORLEVEL%"

echo BizHawk exit code: %EMU_EXIT%

if exist "%REPORT%" (
    echo.
    type "%REPORT%"
) else (
    echo.
    echo Phase 3 down navigation probe report was not generated.
)

exit /b %EMU_EXIT%
