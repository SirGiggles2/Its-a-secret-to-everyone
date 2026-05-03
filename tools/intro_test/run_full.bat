@echo off
setlocal EnableExtensions
for %%I in ("%~dp0..\..") do set "ROOT=%%~fI"

set "OUT_DIR=%ROOT%\tools\intro_test\out"
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

rem ---------------------------------------------------------------------------
rem Locate BizHawk — mirrors the probe pattern in build.bat [5/5].
rem ---------------------------------------------------------------------------
set "BIZHAWK_EXE="
set "BIZHAWK_DIR="
if exist "C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe" (
    set "BIZHAWK_EXE=C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe"
    set "BIZHAWK_DIR=C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64"
)
if "%BIZHAWK_EXE%"=="" if exist "C:\BizHawk\EmuHawk.exe" (
    set "BIZHAWK_EXE=C:\BizHawk\EmuHawk.exe"
    set "BIZHAWK_DIR=C:\BizHawk"
)
if "%BIZHAWK_EXE%"=="" if exist "%LOCALAPPDATA%\BizHawk\EmuHawk.exe" (
    set "BIZHAWK_EXE=%LOCALAPPDATA%\BizHawk\EmuHawk.exe"
    set "BIZHAWK_DIR=%LOCALAPPDATA%\BizHawk"
)
if "%BIZHAWK_EXE%"=="" if exist "%USERPROFILE%\BizHawk\EmuHawk.exe" (
    set "BIZHAWK_EXE=%USERPROFILE%\BizHawk\EmuHawk.exe"
    set "BIZHAWK_DIR=%USERPROFILE%\BizHawk"
)

if "%BIZHAWK_EXE%"=="" (
    echo ERROR: BizHawk not found - cannot run handoff smoke test
    exit /b 1
)

rem ---------------------------------------------------------------------------
rem Locate Python — mirrors build.bat.
rem ---------------------------------------------------------------------------
set "PYTHON="
if exist "%LOCALAPPDATA%\Programs\Python\Python313\python.exe" set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python313\python.exe"
if "%PYTHON%"=="" if exist "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
if "%PYTHON%"=="" where python.exe >nul 2>nul && set "PYTHON=python.exe"

if "%PYTHON%"=="" (
    echo ERROR: Python not found
    exit /b 1
)

rem ---------------------------------------------------------------------------
rem Verify ROM is built.
rem ---------------------------------------------------------------------------
set "OUT_ROM=%ROOT%\builds\Title.md"
if not exist "%OUT_ROM%" (
    echo ERROR: ROM not found at %OUT_ROM% - build it first with build.bat
    exit /b 1
)

rem ---------------------------------------------------------------------------
rem Copy script and ROM into BizHawk dir (path-with-spaces workaround).
rem This is the same pattern used by build.bat [5/5] for probe_phase_sequence.lua.
rem ---------------------------------------------------------------------------
copy /y "%ROOT%\tools\intro_test\probe_start_handoff.lua" "%BIZHAWK_DIR%\probe_start_handoff.lua" >nul 2>nul
copy /y "%OUT_ROM%" "%BIZHAWK_DIR%\Title.md" >nul 2>nul

rem ---------------------------------------------------------------------------
rem Run each scenario in sequence. Each BizHawk launch runs one Start-press
rem injection at a different intro phase (title_display / fadeout /
rem story_run / late_story).
rem ---------------------------------------------------------------------------
for %%S in (1 2 3 4) do (
    echo [run_full] scenario %%S of 4...
    del /q "%OUT_DIR%\handoff_*.csv" 2>nul
    del /q "%OUT_DIR%\handoff_*.done" 2>nul
    rem Write scenario index into out/ AND into BizHawk dir (Lua reads both).
    echo %%S > "%OUT_DIR%\scenario.idx"
    copy /y "%OUT_DIR%\scenario.idx" "%BIZHAWK_DIR%\scenario.idx" >nul 2>nul
    rem Launch BizHawk with array-style args via PowerShell; set CODEX_BIZHAWK_ROOT
    rem so the Lua script resolves out/ back to the repo (same as build.bat [5/5]).
    powershell -Command "& { $env:CODEX_BIZHAWK_ROOT='%ROOT%'; Start-Process -Wait -FilePath '%BIZHAWK_EXE%' -ArgumentList @('--lua=probe_start_handoff.lua','Title.md') -WorkingDirectory '%BIZHAWK_DIR%' }"
    if errorlevel 1 (
        echo [run_full] WARNING: BizHawk exited non-zero on scenario %%S
    )
)

echo.
echo [run_full] checking handoff contracts...
"%PYTHON%" "%ROOT%\tools\intro_test\check_handoff_contract.py"
exit /b %errorlevel%
