@echo off
setlocal EnableExtensions

rem ---------------------------------------------------------------------------
rem Dev-only combined debug target.
rem
rem Builds CombinedDebug.md through tools\combined_debug\build_combined_debug.py.
rem The target uses SGDK startup, the Title A4 RAM ABI, and RoomRom runtime
rem exports. It does not link the RoomRom fake RAM module and does not define
rem ROOMROM_BUILD.
rem ---------------------------------------------------------------------------
if not defined COMBINED_DEBUG_APPROVED (
    echo.
    echo ===========================================================================
    echo  ABORT: CombinedDebug.md is a dev-only proof target.
    echo.
    echo  To build it intentionally:
    echo      set COMBINED_DEBUG_APPROVED=1
    echo      .\CombinedDebug.bat
    echo ===========================================================================
    echo.
    exit /b 1
)

for %%I in ("%~dp0.") do set "ROOT=%%~fI"

python "%ROOT%\tools\combined_debug\build_combined_debug.py"
exit /b %ERRORLEVEL%
