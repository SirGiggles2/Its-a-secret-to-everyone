@echo off
setlocal EnableExtensions

for %%I in ("%~dp0.") do set "ROOT=%%~fI"
if not defined PYTHON set "PYTHON="
if not defined VASM set "VASM="
set "RAW_ROM=%ROOT%\builds\whatif_raw.md"
set "OUT_ROM=%ROOT%\builds\whatif.md"
set "OUT_LST=%ROOT%\builds\whatif.lst"

if exist "%LOCALAPPDATA%\Python\bin\python.exe" set "PYTHON=%LOCALAPPDATA%\Python\bin\python.exe"
if "%PYTHON%"=="" if exist "%LOCALAPPDATA%\Python\pythoncore-3.14-64\python.exe" set "PYTHON=%LOCALAPPDATA%\Python\pythoncore-3.14-64\python.exe"
if "%PYTHON%"=="" if exist "%LOCALAPPDATA%\Programs\Python\Python314\python.exe" set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python314\python.exe"
if "%PYTHON%"=="" if exist "%LOCALAPPDATA%\Programs\Python\Python313\python.exe" set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python313\python.exe"
if "%PYTHON%"=="" if exist "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
if "%PYTHON%"=="" if exist "C:\Python313\python.exe" set "PYTHON=C:\Python313\python.exe"
if "%PYTHON%"=="" if exist "C:\Python312\python.exe" set "PYTHON=C:\Python312\python.exe"
if "%PYTHON%"=="" where python.exe >nul 2>nul && set "PYTHON=python.exe"
if "%PYTHON%"=="" where py.exe >nul 2>nul && set "PYTHON=py.exe"

if "%PYTHON%"=="" (
    echo ERROR: Python was not found.
    exit /b 1
)

if exist "%ROOT%\build\toolchain\vasmm68k_mot.exe" set "VASM=%ROOT%\build\toolchain\vasmm68k_mot.exe"
if "%VASM%"=="" if exist "%ROOT%\..\build\toolchain\vasmm68k_mot.exe" set "VASM=%ROOT%\..\build\toolchain\vasmm68k_mot.exe"
if "%VASM%"=="" if exist "%ROOT%\..\NES-TO-SEGA-GENESIS\build\toolchain\vasmm68k_mot.exe" set "VASM=%ROOT%\..\NES-TO-SEGA-GENESIS\build\toolchain\vasmm68k_mot.exe"
if "%VASM%"=="" if exist "%ROOT%\..\..\build\toolchain\vasmm68k_mot.exe" set "VASM=%ROOT%\..\..\build\toolchain\vasmm68k_mot.exe"
if "%VASM%"=="" if exist "%ROOT%\..\..\NES-TO-SEGA-GENESIS\build\toolchain\vasmm68k_mot.exe" set "VASM=%ROOT%\..\..\NES-TO-SEGA-GENESIS\build\toolchain\vasmm68k_mot.exe"

if "%VASM%"=="" (
    echo ERROR: Missing assembler.
    echo        Checked %ROOT%\build\toolchain\vasmm68k_mot.exe
    echo        Checked %ROOT%\..\build\toolchain\vasmm68k_mot.exe
    echo        Checked %ROOT%\..\NES-TO-SEGA-GENESIS\build\toolchain\vasmm68k_mot.exe
    echo        Checked %ROOT%\..\..\build\toolchain\vasmm68k_mot.exe
    echo        Checked %ROOT%\..\..\NES-TO-SEGA-GENESIS\build\toolchain\vasmm68k_mot.exe
    exit /b 1
)

if not exist "%ROOT%\src\main.asm" (
    echo ERROR: Missing source file %ROOT%\src\main.asm
    exit /b 1
)

if not exist "%ROOT%\builds" mkdir "%ROOT%\builds"

echo [1/9] Extracting graphics...
"%PYTHON%" "%ROOT%\tools\extract_chr.py"
if errorlevel 1 exit /b 1

echo [2/9] Extracting rooms...
"%PYTHON%" "%ROOT%\tools\extract_rooms.py"
if errorlevel 1 exit /b 1

echo [3/9] Extracting enemy tables...
"%PYTHON%" "%ROOT%\tools\extract_enemies.py"
if errorlevel 1 exit /b 1

echo [4/9] Extracting misc tables...
"%PYTHON%" "%ROOT%\tools\extract_misc.py"
if errorlevel 1 exit /b 1

echo [5/9] Extracting audio tables...
"%PYTHON%" "%ROOT%\tools\extract_audio.py"
if errorlevel 1 exit /b 1

echo [6/9] Extracting frontend tables...
"%PYTHON%" "%ROOT%\tools\extract_frontend.py"
if errorlevel 1 exit /b 1

echo [7/9] Assembling WHAT IF ROM...
pushd "%ROOT%\src" >nul
"%VASM%" -Fbin -m68000 -maxerrors=5000 -I. -Iincludes -Iscenes -Idata -L "%OUT_LST%" -o "%RAW_ROM%" main.asm
if errorlevel 1 (
    popd >nul
    exit /b 1
)
popd >nul

echo [8/9] Fixing checksum...
"%PYTHON%" "%ROOT%\tools\fix_checksum.py" "%RAW_ROM%" "%OUT_ROM%"
if errorlevel 1 exit /b 1
if exist "%RAW_ROM%" del "%RAW_ROM%" >nul 2>nul

echo [9/9] Verifying integrity...
"%PYTHON%" "%ROOT%\tools\check_phase0_integrity.py" --lst "%OUT_LST%" --rom "%OUT_ROM%"
if errorlevel 1 exit /b 1

if not defined PHASE_ARCHIVE set "PHASE_ARCHIVE=3"

if defined PHASE_ARCHIVE (
    echo [archive] Saving build as P%PHASE_ARCHIVE%.n...
    "%PYTHON%" "%ROOT%\tools\archive_phase_build.py" --phase %PHASE_ARCHIVE% --rom "%OUT_ROM%" --lst "%OUT_LST%" --out-dir "%ROOT%\builds\archive"
    if errorlevel 1 exit /b 1
)

echo.
echo Build complete: %OUT_ROM%
echo Listing: %OUT_LST%
exit /b 0
