@echo off
setlocal EnableExtensions

if "%~1"=="" (
    echo Usage: run_phase_build.bat PHASE_NUMBER
    exit /b 1
)

set "PHASE_ARCHIVE=%~1"
call "%~dp0..\build.bat"
exit /b %ERRORLEVEL%
