@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem =============================================================================
rem run_all_gates.bat — Phase 0 one-liner for parity + perf regression detection.
rem
rem Runs in sequence:
rem   1. build.bat       (transpile + assemble + checksum)
rem   2. T34 movement parity (NES capture + Gen capture + comparator)
rem   3. T35 scroll parity   (NES capture + Gen capture + comparator)
rem   4. Room $77 parity     (NES capture + Gen capture + comparator)
rem   5. Room $76 parity     (NES capture + Gen capture + comparator)
rem   6. Perf sample + regression check
rem
rem Report summary: builds/reports/regression_summary_gates.txt
rem Exit code = number of FAIL gates.
rem
rem Required env:
rem   NES_ROM  — path to NES Zelda ROM for *_nes_capture.lua
rem              (default: %ROOT%\reference\zelda.nes)
rem =============================================================================

for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "EMU=C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe"
set "BIZHAWK_DIR=C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64"
set "ROM=%ROOT%\builds\whatif.md"
set "REPORT_DIR=%ROOT%\builds\reports"
set "SUMMARY=%REPORT_DIR%\regression_summary_gates.txt"

if "%NES_ROM%"=="" set "NES_ROM=%ROOT%\reference\zelda.nes"

rem ---------------- Python locator (mirrors build.bat) ----------------
set "PYTHON="
if exist "%LOCALAPPDATA%\Python\bin\python.exe"                         set "PYTHON=%LOCALAPPDATA%\Python\bin\python.exe"
if "%PYTHON%"=="" if exist "%LOCALAPPDATA%\Programs\Python\Python313\python.exe" set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python313\python.exe"
if "%PYTHON%"=="" where python.exe >nul 2>nul && set "PYTHON=python.exe"
if "%PYTHON%"=="" (
    echo ERROR: Python not found.
    exit /b 1
)

if not exist "%EMU%" (
    echo ERROR: BizHawk not found: %EMU%
    exit /b 1
)
if not exist "%REPORT_DIR%" mkdir "%REPORT_DIR%"

rem ---------------- Summary header ----------------
echo. > "%SUMMARY%"
echo WHAT IF Gate Suite >> "%SUMMARY%"
echo Run: %date% %time% >> "%SUMMARY%"
echo ROM: %ROM% >> "%SUMMARY%"
echo NES ROM: %NES_ROM% >> "%SUMMARY%"
echo ================================================================= >> "%SUMMARY%"

set "PASS_COUNT=0"
set "FAIL_COUNT=0"
set "ERROR_COUNT=0"

rem ---------------- [1] Build ----------------
echo [1/6] Building ROM...
call "%ROOT%\build.bat"
if errorlevel 1 (
    echo [ERROR] build.bat failed
    echo [ERROR] build.bat failed >> "%SUMMARY%"
    set /a ERROR_COUNT+=1
    goto :summary
)
if not exist "%ROM%" (
    echo [ERROR] ROM not generated: %ROM%
    echo [ERROR] ROM not generated >> "%SUMMARY%"
    set /a ERROR_COUNT+=1
    goto :summary
)

rem ---------------- Helper: run_gate name lua_nes lua_gen comparator_cmd ----------------
rem Usage: call :run_gate "T34 Movement" lua_nes lua_gen "compare_cmd" report_file
rem Writes PASS/FAIL to summary, increments counters.

rem ---------------- [2] T34 Movement ----------------
echo [2/6] T34 Movement Parity...
call :capture "T34 NES capture" "%ROOT%\tools\bizhawk_t34_movement_nes_capture.lua" "%NES_ROM%"
call :capture "T34 Gen capture" "%ROOT%\tools\bizhawk_t34_movement_gen_capture.lua" "%ROM%"
"%PYTHON%" "%ROOT%\tools\compare_t34_movement_parity.py"
call :record_result "T34 Movement" "%REPORT_DIR%\t34_movement_parity_report.txt"

rem ---------------- [3] T35 Scroll ----------------
echo [3/6] T35 Scroll Parity...
call :capture "T35 NES capture" "%ROOT%\tools\bizhawk_t35_scroll_nes_capture.lua" "%NES_ROM%"
call :capture "T35 Gen capture" "%ROOT%\tools\bizhawk_t35_scroll_gen_capture.lua" "%ROM%"
"%PYTHON%" "%ROOT%\tools\compare_t35_scroll_parity.py"
call :record_result "T35 Scroll" "%REPORT_DIR%\bizhawk_t35_scroll_parity_report.txt"

rem ---------------- [4] Room $77 ----------------
echo [4/6] Room $77 Parity...
set "CODEX_TARGET_ROOM_ID=0x77"
call :capture "Room $77 NES capture" "%ROOT%\tools\bizhawk_room77_nes_capture.lua" "%NES_ROM%"
call :capture "Room $77 Gen capture" "%ROOT%\tools\bizhawk_room77_gen_capture.lua" "%ROM%"
"%PYTHON%" "%ROOT%\tools\compare_room77_parity.py" --room-id 0x77
call :record_result "Room $77" "%REPORT_DIR%\room77_parity_report.txt"

rem ---------------- [5] Room $76 ----------------
echo [5/6] Room $76 Parity...
set "CODEX_TARGET_ROOM_ID=0x76"
call :capture "Room $76 NES capture" "%ROOT%\tools\bizhawk_room77_nes_capture.lua" "%NES_ROM%"
call :capture "Room $76 Gen capture" "%ROOT%\tools\bizhawk_room77_gen_capture.lua" "%ROM%"
"%PYTHON%" "%ROOT%\tools\compare_room77_parity.py" --room-id 0x76
call :record_result "Room $76" "%REPORT_DIR%\room76_parity_report.txt"
set "CODEX_TARGET_ROOM_ID="

rem ---------------- [6] Perf Sample ----------------
echo [6/6] Perf Sample...
call :capture "Perf sample" "%ROOT%\tools\bizhawk_perf_sample.lua" "%ROM%"
"%PYTHON%" "%ROOT%\tools\compare_perf.py"
call :record_result "Perf regression" "%REPORT_DIR%\perf_report.txt"

:summary
echo. >> "%SUMMARY%"
echo ================================================================= >> "%SUMMARY%"
echo PASS: %PASS_COUNT%  FAIL: %FAIL_COUNT%  ERROR/SKIP: %ERROR_COUNT% >> "%SUMMARY%"

echo.
echo =================================================================
echo Gate Summary
echo =================================================================
type "%SUMMARY%"

if %FAIL_COUNT% gtr 0 exit /b 1
if %ERROR_COUNT% gtr 0 exit /b 2
exit /b 0

rem ==========================================================================
rem Subroutines
rem ==========================================================================

:capture
  rem %~1 = name, %~2 = lua path, %~3 = ROM path
  if not exist "%~2" (
      echo [SKIP] %~1 -- script not found: %~2
      echo [SKIP] %~1 >> "%SUMMARY%"
      set /a ERROR_COUNT+=1
      exit /b 0
  )
  if not exist "%~3" (
      echo [SKIP] %~1 -- ROM not found: %~3
      echo [SKIP] %~1 >> "%SUMMARY%"
      set /a ERROR_COUNT+=1
      exit /b 0
  )
  pushd "%BIZHAWK_DIR%" >nul
  start "" /wait "%EMU%" "--lua=%~2" "%~3"
  popd >nul
exit /b 0

:record_result
  rem %~1 = gate name, %~2 = report file to scan
  if not exist "%~2" (
      echo [ERROR] %~1 -- report not generated
      echo [ERROR] %~1 >> "%SUMMARY%"
      set /a ERROR_COUNT+=1
      exit /b 0
  )
  set "RESULT=UNKNOWN"
  for /f "delims=" %%L in (%~2) do (
      set "LINE=%%L"
      echo !LINE! | findstr /i "ALL PASS" >nul && set "RESULT=PASS"
      echo !LINE! | findstr /i "0 FAIL" >nul && set "RESULT=PASS"
      echo !LINE! | findstr /i ": FAIL" >nul && set "RESULT=FAIL"
      echo !LINE! | findstr /i "PASS:" >nul && (
          echo !LINE! | findstr /i "FAIL: 0" >nul && set "RESULT=PASS"
      )
      echo !LINE! | findstr /i ": PASS" >nul && set "RESULT=PASS"
  )
  if "!RESULT!"=="PASS" (
      echo [PASS] %~1
      echo [PASS] %~1 >> "%SUMMARY%"
      set /a PASS_COUNT+=1
  ) else (
      echo [FAIL] %~1 ^(scan result: !RESULT!^)
      echo [FAIL] %~1 >> "%SUMMARY%"
      set /a FAIL_COUNT+=1
  )
exit /b 0
