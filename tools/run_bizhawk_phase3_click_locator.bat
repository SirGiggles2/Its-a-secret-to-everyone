@echo off
setlocal EnableExtensions

for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "ROM=%ROOT%\builds\whatif.md"
set "LUA=%ROOT%\tools\bizhawk_phase3_click_locator.lua"
set "REPORT_DIR=%ROOT%\builds\reports"
set "REPORT=%REPORT_DIR%\bizhawk_phase3_click_locator.txt"

if not exist "%ROM%" (
    echo ERROR: Missing ROM: %ROM%
    exit /b 1
)

if not exist "%LUA%" (
    echo ERROR: Missing Lua script: %LUA%
    exit /b 1
)

if not exist "%REPORT_DIR%" mkdir "%REPORT_DIR%"

echo Launching BizHawk click locator...
echo Left-click in the game window to capture coordinates.
echo Report output: %REPORT%

echo.
powershell -ExecutionPolicy Bypass -File "%ROOT%\tools\launch_bizhawk.ps1" -RomPath "%ROM%" -LuaPath "%LUA%" -Wait
set "EMU_EXIT=%ERRORLEVEL%"

echo.
echo BizHawk exit code: %EMU_EXIT%
if exist "%REPORT%" (
    echo --- Latest click report ---
    type "%REPORT%"
)

exit /b %EMU_EXIT%
