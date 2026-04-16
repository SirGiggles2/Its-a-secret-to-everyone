@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem =============================================================================
rem run_all_gates.bat — build + unified regression + perf sample.
rem
rem Since run_all_probes.bat absorbed every parity gate, this script is now a
rem thin wrapper that:
rem   1. Builds the ROM (transpile + assemble + checksum)
rem   2. Runs the full regression suite (all single-Lua probes + all parity gates)
rem   3. Runs the perf sample + regression check
rem
rem Exit code mirrors run_all_probes.bat (1 = FAIL, 2 = ERROR/SKIP, 0 = all PASS)
rem plus adds 4 if the perf step fails.
rem
rem Required env (for parity gates):
rem   NES_ROM  — path to NES Zelda ROM (default: %ROOT%\reference\zelda.nes)
rem =============================================================================

for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "EMU=C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe"
set "BIZHAWK_DIR=C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64"
set "ROM=%ROOT%\builds\whatif.md"
set "REPORT_DIR=%ROOT%\builds\reports"
set "PERF_SUMMARY=%REPORT_DIR%\perf_summary.txt"

set "PYTHON="
if exist "%LOCALAPPDATA%\Python\bin\python.exe"                           set "PYTHON=%LOCALAPPDATA%\Python\bin\python.exe"
if "%PYTHON%"=="" if exist "%LOCALAPPDATA%\Programs\Python\Python313\python.exe" set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python313\python.exe"
if "%PYTHON%"=="" where python.exe >nul 2>nul && set "PYTHON=python.exe"

set "PERF_EXIT=0"

rem ---------------- [1] Build ----------------
echo [1/3] Building ROM...
call "%ROOT%\build.bat"
if errorlevel 1 (
    echo [ERROR] build.bat failed
    exit /b 3
)
if not exist "%ROM%" (
    echo [ERROR] ROM not generated: %ROM%
    exit /b 3
)

rem ---------------- [2] Unified regression suite ----------------
echo [2/3] Running regression suite...
call "%ROOT%\tools\run_all_probes.bat"
set "REGR_EXIT=%ERRORLEVEL%"

rem ---------------- [3] Perf sample ----------------
echo [3/3] Perf sample...
if not exist "%ROOT%\tools\bizhawk_perf_sample.lua" goto :perf_skip
if not exist "%ROOT%\tools\compare_perf.py"         goto :perf_skip
if "%PYTHON%"=="" goto :perf_skip

pushd "%BIZHAWK_DIR%" >nul
start "" /wait "%EMU%" "--lua=%ROOT%\tools\bizhawk_perf_sample.lua" "%ROM%"
popd >nul

"%PYTHON%" "%ROOT%\tools\compare_perf.py" > "%PERF_SUMMARY%" 2>&1
if errorlevel 1 set "PERF_EXIT=4"
type "%PERF_SUMMARY%"
goto :done

:perf_skip
echo [SKIP] Perf sample -- tool or Python missing

:done
rem Exit code: regression failure takes priority, then perf failure.
if %REGR_EXIT% neq 0 exit /b %REGR_EXIT%
if %PERF_EXIT% neq 0 exit /b %PERF_EXIT%
exit /b 0
