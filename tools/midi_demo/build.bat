@echo off
setlocal

set "ROOT=%~dp0..\..\"
for %%I in ("%ROOT%.") do set "ROOT=%%~fI"

set "DEMO_DIR=%ROOT%\tools\midi_demo"
set "OUT_DIR=%DEMO_DIR%\out"
set "MIDI_SRC=%ROOT%\Zelda - Ocarina of Time - Great Fairy's fountain.mid"

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

set "PYTHON="
if exist "%LOCALAPPDATA%\Python\bin\python.exe"                                 set "PYTHON=%LOCALAPPDATA%\Python\bin\python.exe"
if "%PYTHON%"=="" if exist "%LOCALAPPDATA%\Python\pythoncore-3.14-64\python.exe" set "PYTHON=%LOCALAPPDATA%\Python\pythoncore-3.14-64\python.exe"
if "%PYTHON%"=="" if exist "%LOCALAPPDATA%\Programs\Python\Python314\python.exe" set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python314\python.exe"
if "%PYTHON%"=="" if exist "%LOCALAPPDATA%\Programs\Python\Python313\python.exe" set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python313\python.exe"
if "%PYTHON%"=="" if exist "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
if "%PYTHON%"=="" where python.exe >nul 2>nul                       && set "PYTHON=python.exe"
if "%PYTHON%"=="" where py.exe     >nul 2>nul                       && set "PYTHON=py.exe"
if "%PYTHON%"=="" (
    echo ERROR: python not found
    exit /b 1
)

set "VASM="
if exist "%ROOT%\build\toolchain\vasmm68k_mot.exe"                                              set "VASM=%ROOT%\build\toolchain\vasmm68k_mot.exe"
if "%VASM%"=="" if exist "%ROOT%\..\NES-TO-SEGA-GENESIS\build\toolchain\vasmm68k_mot.exe"      set "VASM=%ROOT%\..\NES-TO-SEGA-GENESIS\build\toolchain\vasmm68k_mot.exe"
if "%VASM%"=="" if exist "D:\Zelda port\vasmm68k_mot.exe"                                       set "VASM=D:\Zelda port\vasmm68k_mot.exe"
if "%VASM%"=="" where vasmm68k_mot.exe >nul 2>nul                                               && set "VASM=vasmm68k_mot.exe"
if "%VASM%"=="" (
    echo ERROR: vasmm68k_mot.exe not found
    exit /b 1
)

set "M68K_BIN=%ROOT%\build\toolchain\sgdk_bin\bin"
set "M68K_GCC=%M68K_BIN%\gcc.exe"
set "M68K_LD=%M68K_BIN%\ld.exe"
set "M68K_OBJCOPY=%M68K_BIN%\objcopy.exe"

set "CFLAGS=-m68000 -ffreestanding -nostdlib -nostartfiles -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2"

echo [midi_demo] Compiling MIDI -> event blob
"%PYTHON%" "%DEMO_DIR%\compile_midi.py" "%MIDI_SRC%" "%OUT_DIR%\midi_data.bin"
if errorlevel 1 exit /b 1

echo [midi_demo] Compiling main.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%DEMO_DIR%\main.c" -o "%OUT_DIR%\main.o"
if errorlevel 1 exit /b 1

echo [midi_demo] Compiling link_sprite.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%DEMO_DIR%\link_sprite.c" -o "%OUT_DIR%\link_sprite.o"
if errorlevel 1 exit /b 1

echo [midi_demo] Compiling link_palette.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%DEMO_DIR%\link_palette.c" -o "%OUT_DIR%\link_palette.o"
if errorlevel 1 exit /b 1

echo [midi_demo] Assembling boot.asm
"%VASM%" -Felf -m68000 -L "%OUT_DIR%\boot.lst" -o "%OUT_DIR%\boot.o" "%DEMO_DIR%\boot.asm"
if errorlevel 1 exit /b 1

echo [midi_demo] Assembling midi_player.asm
pushd "%DEMO_DIR%"
"%VASM%" -Felf -m68000 -L "%OUT_DIR%\midi_player.lst" -o "%OUT_DIR%\midi_player.o" "%DEMO_DIR%\midi_player.asm"
if errorlevel 1 (popd & exit /b 1)
popd

echo [midi_demo] Linking
"%M68K_LD%" -T "%DEMO_DIR%\midi_demo.ld" -o "%OUT_DIR%\midi_demo.elf" ^
    "%OUT_DIR%\boot.o" ^
    "%OUT_DIR%\main.o" ^
    "%OUT_DIR%\link_sprite.o" ^
    "%OUT_DIR%\link_palette.o" ^
    "%OUT_DIR%\midi_player.o"
if errorlevel 1 exit /b 1

echo [midi_demo] objcopy -^> raw bin
"%M68K_OBJCOPY%" -O binary "%OUT_DIR%\midi_demo.elf" "%OUT_DIR%\midi_demo.bin"
if errorlevel 1 exit /b 1

echo [midi_demo] fix checksum + pad
"%PYTHON%" "%ROOT%\tools\fix_checksum.py" "%OUT_DIR%\midi_demo.bin" "%OUT_DIR%\midi_demo.md"
if errorlevel 1 exit /b 1

echo [midi_demo] DONE: %OUT_DIR%\midi_demo.md
endlocal
