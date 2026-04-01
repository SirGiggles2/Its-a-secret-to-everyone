@echo off
setlocal EnableExtensions

for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "EMU=C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe"
set "ROM=%ROOT%\builds\whatif.md"
set "LUA=%ROOT%\tools\bizhawk_t5_ppu_probe.lua"
set "REPORT_DIR=%ROOT%\builds\reports"
set "REPORT=%REPORT_DIR%\bizhawk_t5_ppu_probe.txt"

if not exist "%EMU%" (
    echo ERROR: Missing BizHawk executable: %EMU%
    exit /b 1
)
if not exist "%ROM%" (
    echo ERROR: Missing ROM: %ROM%
    exit /b 1
)
if not exist "%LUA%" (
    echo ERROR: Missing probe script: %LUA%
    exit /b 1
)

if not exist "%REPORT_DIR%" mkdir "%REPORT_DIR%"
if exist "%REPORT%" del /f /q "%REPORT%" >nul 2>nul

echo Running T5 PPU probe (60 frames)...
pushd "C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64" >nul
start "" /wait "%EMU%" "--lua=%LUA%" "%ROM%"
set "EMU_EXIT=%ERRORLEVEL%"
popd >nul

echo BizHawk exit code: %EMU_EXIT%
echo.
if exist "%REPORT%" (
    type "%REPORT%"
) else (
    echo ERROR: Report not generated.
    exit /b 1
)

exit /b %EMU_EXIT%
