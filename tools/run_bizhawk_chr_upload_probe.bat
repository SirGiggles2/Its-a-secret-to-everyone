@echo off
setlocal EnableExtensions

for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "EMU=C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe"
set "ROM=%ROOT%\builds\whatif.md"
set "LUA=%ROOT%\tools\bizhawk_chr_upload_probe.lua"
set "REPORT_DIR=%ROOT%\builds\reports"
set "REPORT=%REPORT_DIR%\bizhawk_chr_upload_probe.txt"

if not exist "%EMU%" (
    echo ERROR: Missing BizHawk executable: %EMU%
    exit /b 1
)

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

pushd "C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64" >nul
start "" /wait "%EMU%" "--lua=%LUA%" "%ROM%"
set "EMU_EXIT=%ERRORLEVEL%"
popd >nul

echo BizHawk exit code: %EMU_EXIT%

if exist "%REPORT%" (
    echo.
    type "%REPORT%"
) else (
    echo.
    echo CHR upload probe report was not generated.
)

exit /b %EMU_EXIT%
