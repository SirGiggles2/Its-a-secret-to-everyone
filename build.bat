@echo off
setlocal EnableExtensions

for %%I in ("%~dp0.") do set "ROOT=%%~fI"

set "PYTHON="
set "VASM="
set "RAW_ROM=%ROOT%\builds\whatif_raw.md"
set "OUT_ROM=%ROOT%\builds\whatif.md"
set "OUT_LST=%ROOT%\builds\whatif.lst"

rem ---------------------------------------------------------------------------
rem Locate Python
rem ---------------------------------------------------------------------------
if exist "%LOCALAPPDATA%\Python\bin\python.exe"                         set "PYTHON=%LOCALAPPDATA%\Python\bin\python.exe"
if "%PYTHON%"=="" if exist "%LOCALAPPDATA%\Python\pythoncore-3.14-64\python.exe" set "PYTHON=%LOCALAPPDATA%\Python\pythoncore-3.14-64\python.exe"
if "%PYTHON%"=="" if exist "%LOCALAPPDATA%\Programs\Python\Python314\python.exe" set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python314\python.exe"
if "%PYTHON%"=="" if exist "%LOCALAPPDATA%\Programs\Python\Python313\python.exe" set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python313\python.exe"
if "%PYTHON%"=="" if exist "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
if "%PYTHON%"=="" if exist "C:\Python313\python.exe"                   set "PYTHON=C:\Python313\python.exe"
if "%PYTHON%"=="" if exist "C:\Python312\python.exe"                   set "PYTHON=C:\Python312\python.exe"
if "%PYTHON%"=="" where python.exe >nul 2>nul                       && set "PYTHON=python.exe"
if "%PYTHON%"=="" where py.exe     >nul 2>nul                       && set "PYTHON=py.exe"

if "%PYTHON%"=="" (
    echo ERROR: Python not found.
    exit /b 1
)

rem ---------------------------------------------------------------------------
rem Locate vasmm68k_mot
rem ---------------------------------------------------------------------------
if exist "%ROOT%\build\toolchain\vasmm68k_mot.exe"                          set "VASM=%ROOT%\build\toolchain\vasmm68k_mot.exe"
if "%VASM%"=="" if exist "%ROOT%\..\build\toolchain\vasmm68k_mot.exe"       set "VASM=%ROOT%\..\build\toolchain\vasmm68k_mot.exe"
if "%VASM%"=="" if exist "%ROOT%\..\NES-TO-SEGA-GENESIS\build\toolchain\vasmm68k_mot.exe" set "VASM=%ROOT%\..\NES-TO-SEGA-GENESIS\build\toolchain\vasmm68k_mot.exe"
if "%VASM%"=="" if exist "%ROOT%\..\..\build\toolchain\vasmm68k_mot.exe"    set "VASM=%ROOT%\..\..\build\toolchain\vasmm68k_mot.exe"
if "%VASM%"=="" if exist "%ROOT%\..\..\NES-TO-SEGA-GENESIS\build\toolchain\vasmm68k_mot.exe" set "VASM=%ROOT%\..\..\NES-TO-SEGA-GENESIS\build\toolchain\vasmm68k_mot.exe"
if "%VASM%"=="" if exist "D:\Zelda port\vasmm68k_mot.exe"                  set "VASM=D:\Zelda port\vasmm68k_mot.exe"
if "%VASM%"=="" if exist "D:\Zelda port CHAT GPT\vasmm68k_mot.exe"         set "VASM=D:\Zelda port CHAT GPT\vasmm68k_mot.exe"
if "%VASM%"=="" where vasmm68k_mot.exe >nul 2>nul                       && set "VASM=vasmm68k_mot.exe"

if "%VASM%"=="" (
    echo ERROR: vasmm68k_mot.exe not found.
    echo Expected at: %ROOT%\build\toolchain\vasmm68k_mot.exe
    exit /b 1
)

rem ---------------------------------------------------------------------------
rem Verify entry point exists
rem ---------------------------------------------------------------------------
if not exist "%ROOT%\src\genesis_shell.asm" (
    echo ERROR: Missing %ROOT%\src\genesis_shell.asm
    exit /b 1
)

if not exist "%ROOT%\builds" mkdir "%ROOT%\builds"

rem ---------------------------------------------------------------------------
rem [1] Transpiler — generate src\zelda_translated\*.asm from aldonunez source.
rem     Skipped until tools\transpile_6502.py exists (T2/T3 milestones).
rem ---------------------------------------------------------------------------
if exist "%ROOT%\tools\transpile_6502.py" (
    echo [1/3] Running 6502^>M68K transpiler ^(--all --no-stubs: nes_io.asm provides I/O^)...
    "%PYTHON%" "%ROOT%\tools\transpile_6502.py" --all --no-stubs
    if errorlevel 1 exit /b 1
) else (
    echo [1/3] Transpiler not yet present -- skipping ^(T1 shell-only build^)
)

rem ---------------------------------------------------------------------------
rem [2] Assemble — genesis_shell.asm is the root; it includes nes_io.asm,
rem     bankswitch.asm, and zelda_translated/*.asm via include directives
rem     once those files exist.
rem ---------------------------------------------------------------------------
echo [2/3] Assembling...
pushd "%ROOT%\src" >nul
"%VASM%" -Fbin -m68000 -maxerrors=5000 -L "%OUT_LST%" -o "%RAW_ROM%" genesis_shell.asm
if errorlevel 1 (
    popd >nul
    exit /b 1
)
popd >nul

rem ---------------------------------------------------------------------------
rem [3] Fix checksum
rem ---------------------------------------------------------------------------
echo [3/3] Fixing checksum...
"%PYTHON%" "%ROOT%\tools\fix_checksum.py" "%RAW_ROM%" "%OUT_ROM%"
if errorlevel 1 exit /b 1
if exist "%RAW_ROM%" del "%RAW_ROM%" >nul 2>nul

rem ---------------------------------------------------------------------------
rem [4] Archive — incremental ZeldaPHASE.VERSION build
rem
rem   PHASE   reflects the current development phase (edit build_phase.txt to
rem           bump — e.g. 3 for gameplay, 4 for enemy AI, 10+ for later work).
rem           When phase bumps, reset build_counter.txt to 0 so VERSION starts
rem           from 1 within each phase.
rem   VERSION is a monotonic counter within the current phase, incremented by
rem           every successful build.
rem
rem Archive files keep their historical phase.version — only the next build
rem takes the new numbering.
rem ---------------------------------------------------------------------------
echo [4/4] Archiving build...
set "ARCHIVE_DIR=%ROOT%\builds\archive"
set "COUNTER_FILE=%ARCHIVE_DIR%\build_counter.txt"
set "PHASE_FILE=%ARCHIVE_DIR%\build_phase.txt"

if not exist "%ARCHIVE_DIR%" mkdir "%ARCHIVE_DIR%"

rem Read current build counter (default 0)
set "BUILD_NUM=0"
if exist "%COUNTER_FILE%" set /p BUILD_NUM=<"%COUNTER_FILE%"

rem Read current phase (default 3 — gameplay phase; bump via build_phase.txt)
set "PHASE=3"
if exist "%PHASE_FILE%" set /p PHASE=<"%PHASE_FILE%"

rem Increment build number
set /a BUILD_NUM=%BUILD_NUM%+1

rem Archive ROM and listing via Python (reliable on all launch contexts)
set "TAG=Zelda%PHASE%.%BUILD_NUM%"
"%PYTHON%" -c "import shutil, sys; src_rom=sys.argv[1]; src_lst=sys.argv[2]; dst=sys.argv[3]; ctr=sys.argv[4]; shutil.copy2(src_rom, dst+'.md'); shutil.copy2(src_lst, dst+'.lst'); open(ctr,'w').write(sys.argv[5]); print('Archived as: '+dst.split('\\')[-1])" "%OUT_ROM%" "%OUT_LST%" "%ARCHIVE_DIR%\%TAG%" "%COUNTER_FILE%" "%BUILD_NUM%"
if errorlevel 1 echo WARNING: archive step failed (non-fatal)

echo.
echo Build complete: %OUT_ROM%
echo Listing:        %OUT_LST%

rem ---------------------------------------------------------------------------
rem [5] Git auto-commit — stage build outputs and archive, commit with tag name
rem ---------------------------------------------------------------------------
git -C "%ROOT%" add builds\whatif.md builds\whatif.lst builds\archive\ >nul 2>nul
git -C "%ROOT%" diff --cached --quiet >nul 2>nul
if errorlevel 1 (
    git -C "%ROOT%" commit -m "build: %TAG%" >nul 2>nul
    if errorlevel 1 (
        echo WARNING: git commit failed
    ) else (
        echo Committed:   %TAG%
    )
) else (
    echo No changes to commit.
)
exit /b 0
