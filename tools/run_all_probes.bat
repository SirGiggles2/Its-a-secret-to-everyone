@echo off
setlocal EnableExtensions EnableDelayedExpansion

for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "EMU=C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe"
set "ROM=%ROOT%\builds\whatif.md"
set "REPORT_DIR=%ROOT%\builds\reports"
set "SUMMARY=%REPORT_DIR%\regression_summary.txt"

if not exist "%EMU%" (
    echo ERROR: BizHawk not found: %EMU%
    exit /b 1
)
if not exist "%ROM%" (
    echo ERROR: ROM not found: %ROM%
    exit /b 1
)
if not exist "%REPORT_DIR%" mkdir "%REPORT_DIR%"

echo.>"%SUMMARY%"
echo WHAT IF Regression Suite > "%SUMMARY%"
echo Run: %date% %time% >> "%SUMMARY%"
echo ROM:  %ROM% >> "%SUMMARY%"
echo ================================================================= >> "%SUMMARY%"

set "PASS_COUNT=0"
set "FAIL_COUNT=0"
set "ERROR_COUNT=0"

:: Registry of probes: name|lua_file|report_file|milestone
set PROBE_COUNT=0
set PROBE[0]=Boot T7/T8/T9/T10/T11|bizhawk_boot_probe.lua|bizhawk_boot_probe.txt
set PROBE[1]=PPU Latch T12|bizhawk_ppu_latch_probe.lua|bizhawk_ppu_latch_probe.txt
set PROBE[2]=PPU Increment T13|bizhawk_ppu_increment_probe.lua|bizhawk_ppu_increment_probe.txt
set PROBE[3]=PPU Ctrl T14|bizhawk_ppu_ctrl_probe.lua|bizhawk_ppu_ctrl_probe.txt
set PROBE[4]=Scroll Latch T15|bizhawk_scroll_latch_probe.lua|bizhawk_scroll_latch_probe.txt
set PROBE[5]=MMC1 State T11b|bizhawk_mmc1_probe.lua|bizhawk_mmc1_probe.txt
:: Phase 1/2/6 diary-reintegration (Zelda27.48+): exercises $005C one-shot,
:: VRamForceBlankGate, _mode_transition_check, $A10003 controller port,
:: C→Select remap, NMI/input probe counters, and Phase 6 DMA VRAM clear.
set PROBE[6]=Phase 1/2/6 Verify|bizhawk_phase1_verify.lua|bizhawk_phase1_verify.txt

for /l %%i in (0,1,6) do (
    for /f "tokens=1,2,3 delims=|" %%a in ("!PROBE[%%i]!") do (
        set "PNAME=%%a"
        set "PLUA=%ROOT%\tools\%%b"
        set "PREPORT=%REPORT_DIR%\%%c"

        if not exist "!PLUA!" (
            echo [SKIP] !PNAME! -- script not found
            echo [SKIP] !PNAME! >> "%SUMMARY%"
            set /a ERROR_COUNT+=1
        ) else (
            echo Running !PNAME! ...
            if exist "!PREPORT!" del /f /q "!PREPORT!" >nul 2>nul

            pushd "C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64" >nul
            start "" /wait "%EMU%" "--lua=!PLUA!" "%ROM%"
            popd >nul

            if exist "!PREPORT!" (
                :: Find the last PASS/FAIL summary line
                set "RESULT=UNKNOWN"
                for /f "delims=" %%L in (!PREPORT!) do (
                    set "LINE=%%L"
                    echo !LINE! | findstr /i "ALL PASS" >nul && set "RESULT=PASS"
                    echo !LINE! | findstr /i ": FAIL" >nul && set "RESULT=FAIL"
                )
                if "!RESULT!"=="PASS" (
                    echo [PASS] !PNAME!
                    echo [PASS] !PNAME! >> "%SUMMARY%"
                    set /a PASS_COUNT+=1
                ) else (
                    echo [FAIL] !PNAME!
                    echo [FAIL] !PNAME! >> "%SUMMARY%"
                    set /a FAIL_COUNT+=1
                )
            ) else (
                echo [ERROR] !PNAME! -- report not generated
                echo [ERROR] !PNAME! -- report not generated >> "%SUMMARY%"
                set /a ERROR_COUNT+=1
            )
        )
    )
)

echo. >> "%SUMMARY%"
echo ================================================================= >> "%SUMMARY%"
echo PASS: %PASS_COUNT%  FAIL: %FAIL_COUNT%  ERROR/SKIP: %ERROR_COUNT% >> "%SUMMARY%"

echo.
echo =================================================================
echo Regression Summary
echo =================================================================
type "%SUMMARY%"

if %FAIL_COUNT% gtr 0 exit /b 1
if %ERROR_COUNT% gtr 0 exit /b 2
exit /b 0
