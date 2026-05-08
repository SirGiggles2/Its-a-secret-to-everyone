@echo off
setlocal EnableExtensions

rem ===========================================================================
rem  Sole Build Target Amendment 2026-05-08:
rem  RoomRom\build.bat is dead. The only build script is Debug.bat at the
rem  repo root (sole target Debug.md). Gameplay sources under RoomRom\src\
rem  are still authoritative — they link into Debug.md via
rem  tools\debug\build_debug.py. This standalone harness ROM is retired.
rem ===========================================================================
echo.
echo ===========================================================================
echo  ABORT: RoomRom\build.bat is retired ^(sole target Debug.md^).
echo  Run the correct script instead:
echo      .\Debug.bat
echo ===========================================================================
echo.
exit /b 1
