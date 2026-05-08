@echo off
setlocal EnableExtensions

rem ===========================================================================
rem  Sole Build Target Amendment 2026-05-08:
rem  Root build.bat is dead. The only build script is Debug.bat (sole target
rem  Debug.md). The legacy aliases that this script used to emit are retired.
rem  See CLAUDE.md "Sole build target" + master plan amendment block.
rem ===========================================================================
echo.
echo ===========================================================================
echo  ABORT: build.bat is retired ^(sole target Debug.md, see Debug.bat^).
echo  Run the correct script instead:
echo      .\Debug.bat
echo ===========================================================================
echo.
exit /b 1
