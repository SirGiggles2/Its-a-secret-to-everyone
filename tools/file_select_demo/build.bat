@echo off
setlocal

set "ROOT=%~dp0..\..\"
for %%I in ("%ROOT%.") do set "ROOT=%%~fI"

set "DEMO_DIR=%ROOT%\tools\file_select_demo"
set "OUT_DIR=%DEMO_DIR%\out"
set "GEN_DIR=%ROOT%\src\gen"
set "SRC_DIR=%ROOT%\src"

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

set "PYTHON="
if exist "%LOCALAPPDATA%\Python\bin\python.exe"                              set "PYTHON=%LOCALAPPDATA%\Python\bin\python.exe"
if "%PYTHON%"=="" if exist "%LOCALAPPDATA%\Python\pythoncore-3.14-64\python.exe" set "PYTHON=%LOCALAPPDATA%\Python\pythoncore-3.14-64\python.exe"
if "%PYTHON%"=="" if exist "%LOCALAPPDATA%\Programs\Python\Python314\python.exe" set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python314\python.exe"
if "%PYTHON%"=="" if exist "%LOCALAPPDATA%\Programs\Python\Python313\python.exe" set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python313\python.exe"
if "%PYTHON%"=="" if exist "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
if "%PYTHON%"=="" where python.exe >nul 2>nul                               && set "PYTHON=python.exe"
if "%PYTHON%"=="" where py.exe     >nul 2>nul                               && set "PYTHON=py.exe"

set "VASM="
if exist "%ROOT%\build\toolchain\vasmm68k_mot.exe"                                         set "VASM=%ROOT%\build\toolchain\vasmm68k_mot.exe"
if "%VASM%"=="" if exist "%ROOT%\..\NES-TO-SEGA-GENESIS\build\toolchain\vasmm68k_mot.exe" set "VASM=%ROOT%\..\NES-TO-SEGA-GENESIS\build\toolchain\vasmm68k_mot.exe"
if "%VASM%"=="" if exist "D:\Zelda port\vasmm68k_mot.exe"                                  set "VASM=D:\Zelda port\vasmm68k_mot.exe"
if "%VASM%"=="" where vasmm68k_mot.exe >nul 2>nul                                          && set "VASM=vasmm68k_mot.exe"
if "%VASM%"=="" (
    echo ERROR: vasmm68k_mot.exe not found
    exit /b 1
)

set "M68K_BIN=%ROOT%\build\toolchain\sgdk_bin\bin"
set "M68K_GCC=%M68K_BIN%\gcc.exe"
set "M68K_LD=%M68K_BIN%\ld.exe"
set "M68K_OBJCOPY=%M68K_BIN%\objcopy.exe"

set "CFLAGS=-m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%SRC_DIR%""

echo [fs_demo] Generating src/gen/ assets via extract_fs_assets.py
"%PYTHON%" "%ROOT%\tools\extract_fs_assets.py"
if errorlevel 1 exit /b 1

echo [fs_demo] Compiling src\fs_main.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%SRC_DIR%\fs_main.c" -o "%OUT_DIR%\fs_main.o"
if errorlevel 1 exit /b 1

echo [fs_demo] Compiling src\fs_render.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%SRC_DIR%\fs_render.c" -o "%OUT_DIR%\fs_render.o"
if errorlevel 1 exit /b 1

echo [fs_demo] Compiling gen\fs_palette.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%GEN_DIR%\fs_palette.c" -o "%OUT_DIR%\fs_palette.o"
if errorlevel 1 exit /b 1

echo [fs_demo] Compiling gen\fs_static_tilemap.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%GEN_DIR%\fs_static_tilemap.c" -o "%OUT_DIR%\fs_static_tilemap.o"
if errorlevel 1 exit /b 1

echo [fs_demo] Compiling gen\fs_link_sprite_chr.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%GEN_DIR%\fs_link_sprite_chr.c" -o "%OUT_DIR%\fs_link_sprite_chr.o"
if errorlevel 1 exit /b 1

echo [fs_demo] Compiling gen\fs_heart_cursor_chr.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%GEN_DIR%\fs_heart_cursor_chr.c" -o "%OUT_DIR%\fs_heart_cursor_chr.o"
if errorlevel 1 exit /b 1

echo [fs_demo] Compiling gen\fs_font_chr.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%GEN_DIR%\fs_font_chr.c" -o "%OUT_DIR%\fs_font_chr.o"
if errorlevel 1 exit /b 1

echo [fs_demo] Compiling gen\fs_border_chr.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%GEN_DIR%\fs_border_chr.c" -o "%OUT_DIR%\fs_border_chr.o"
if errorlevel 1 exit /b 1

echo [fs_demo] Compiling gen\fs_bg_chr_full.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%GEN_DIR%\fs_bg_chr_full.c" -o "%OUT_DIR%\fs_bg_chr_full.o"
if errorlevel 1 exit /b 1

echo [fs_demo] Compiling src\intro_common.c (shared VDP primitives)
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%SRC_DIR%\intro_common.c" -o "%OUT_DIR%\intro_common.o"
if errorlevel 1 exit /b 1

echo [fs_demo] Assembling boot.asm
"%VASM%" -Felf -m68000 -L "%OUT_DIR%\boot.lst" -o "%OUT_DIR%\boot.o" "%DEMO_DIR%\boot.asm"
if errorlevel 1 exit /b 1

echo [fs_demo] Linking
"%M68K_LD%" -T "%DEMO_DIR%\file_select_demo.ld" -o "%OUT_DIR%\fs_demo.elf" ^
    "%OUT_DIR%\boot.o" ^
    "%OUT_DIR%\intro_common.o" ^
    "%OUT_DIR%\fs_main.o" ^
    "%OUT_DIR%\fs_render.o" ^
    "%OUT_DIR%\fs_palette.o" ^
    "%OUT_DIR%\fs_static_tilemap.o" ^
    "%OUT_DIR%\fs_link_sprite_chr.o" ^
    "%OUT_DIR%\fs_heart_cursor_chr.o" ^
    "%OUT_DIR%\fs_font_chr.o" ^
    "%OUT_DIR%\fs_border_chr.o" ^
    "%OUT_DIR%\fs_bg_chr_full.o"
if errorlevel 1 exit /b 1

echo [fs_demo] objcopy -> raw bin
"%M68K_OBJCOPY%" -O binary "%OUT_DIR%\fs_demo.elf" "%OUT_DIR%\fs_demo.bin"
if errorlevel 1 exit /b 1

echo [fs_demo] fix checksum + pad
"%PYTHON%" "%ROOT%\tools\fix_checksum.py" "%OUT_DIR%\fs_demo.bin" "%OUT_DIR%\fs_demo.md"
if errorlevel 1 exit /b 1

echo [fs_demo] DONE: %OUT_DIR%\fs_demo.md
endlocal
