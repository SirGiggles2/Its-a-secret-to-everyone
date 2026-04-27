@echo off
setlocal

set "ROOT=%~dp0..\..\"
for %%I in ("%ROOT%.") do set "ROOT=%%~fI"

set "DEMO_DIR=%ROOT%\tools\intro_demo"
set "OUT_DIR=%DEMO_DIR%\out"
set "GEN_DIR=%ROOT%\src\gen"
set "SRC_DIR=%ROOT%\src"

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

set "PYTHON="
if exist "%LOCALAPPDATA%\Python\bin\python.exe"                         set "PYTHON=%LOCALAPPDATA%\Python\bin\python.exe"
if "%PYTHON%"=="" if exist "%LOCALAPPDATA%\Python\pythoncore-3.14-64\python.exe" set "PYTHON=%LOCALAPPDATA%\Python\pythoncore-3.14-64\python.exe"
if "%PYTHON%"=="" if exist "%LOCALAPPDATA%\Programs\Python\Python314\python.exe" set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python314\python.exe"
if "%PYTHON%"=="" if exist "%LOCALAPPDATA%\Programs\Python\Python313\python.exe" set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python313\python.exe"
if "%PYTHON%"=="" if exist "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
if "%PYTHON%"=="" where python.exe >nul 2>nul                       && set "PYTHON=python.exe"
if "%PYTHON%"=="" where py.exe     >nul 2>nul                       && set "PYTHON=py.exe"

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

rem   -ffixed-a4 pins A4 as NES_RAM base, matching nes_abi.h usage in src/intro_phase.c
rem   -I "%SRC_DIR%" lets src/ headers (intro_phase.h, intro_story.h, nes_abi.h) resolve
set "CFLAGS=-m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%SRC_DIR%""

echo [demo] Generating src/gen/ assets via central extractor
"%PYTHON%" "%ROOT%\tools\extract_intro_assets.py"
if errorlevel 1 exit /b 1

echo [demo] Compiling main.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%DEMO_DIR%\main.c" -o "%OUT_DIR%\main.o"
if errorlevel 1 exit /b 1

echo [demo] Compiling intro_font_chr.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%GEN_DIR%\intro_font_chr.c" -o "%OUT_DIR%\intro_font_chr.o"
if errorlevel 1 exit /b 1

echo [demo] Compiling intro_common_bg_chr.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%GEN_DIR%\intro_common_bg_chr.c" -o "%OUT_DIR%\intro_common_bg_chr.o"
if errorlevel 1 exit /b 1

echo [demo] Compiling intro_palette.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%GEN_DIR%\intro_palette.c" -o "%OUT_DIR%\intro_palette.o"
if errorlevel 1 exit /b 1

echo [demo] Compiling intro_combined_palette.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%GEN_DIR%\intro_combined_palette.c" -o "%OUT_DIR%\intro_combined_palette.o"
if errorlevel 1 exit /b 1

echo [demo] Compiling intro_story_tilemap.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%GEN_DIR%\intro_story_tilemap.c" -o "%OUT_DIR%\intro_story_tilemap.o"
if errorlevel 1 exit /b 1

echo [demo] Compiling intro_punct_chr.c (custom comma + apostrophe tiles)
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%GEN_DIR%\intro_punct_chr.c" -o "%OUT_DIR%\intro_punct_chr.o"
if errorlevel 1 exit /b 1

echo [demo] Compiling intro_treasures_tilemap.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%GEN_DIR%\intro_treasures_tilemap.c" -o "%OUT_DIR%\intro_treasures_tilemap.o"
if errorlevel 1 exit /b 1

echo [demo] Compiling intro_sprite_chr.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%GEN_DIR%\intro_sprite_chr.c" -o "%OUT_DIR%\intro_sprite_chr.o"
if errorlevel 1 exit /b 1

echo [demo] Compiling intro_misc_chr.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%GEN_DIR%\intro_misc_chr.c" -o "%OUT_DIR%\intro_misc_chr.o"
if errorlevel 1 exit /b 1

echo [demo] Compiling intro_blink_chr.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%GEN_DIR%\intro_blink_chr.c" -o "%OUT_DIR%\intro_blink_chr.o"
if errorlevel 1 exit /b 1

echo [demo] Generating intro_demo_palettes.c (Z_02 DemoPhase0Subphase1 cycles)
"%PYTHON%" "%DEMO_DIR%\extract_demo_palettes.py"
if errorlevel 1 exit /b 1

echo [demo] Compiling intro_demo_palettes.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%DEMO_DIR%\intro_demo_palettes.c" -o "%OUT_DIR%\intro_demo_palettes.o"
if errorlevel 1 exit /b 1

echo [demo] Compiling intro_title_bg_chr.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%GEN_DIR%\intro_title_bg_chr.c" -o "%OUT_DIR%\intro_title_bg_chr.o"
if errorlevel 1 exit /b 1

echo [demo] Compiling intro_title_sprite_chr.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%GEN_DIR%\intro_title_sprite_chr.c" -o "%OUT_DIR%\intro_title_sprite_chr.o"
if errorlevel 1 exit /b 1

echo [demo] Compiling intro_title_tilemap.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%GEN_DIR%\intro_title_tilemap.c" -o "%OUT_DIR%\intro_title_tilemap.o"
if errorlevel 1 exit /b 1

echo [demo] Compiling intro_title_palette.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%GEN_DIR%\intro_title_palette.c" -o "%OUT_DIR%\intro_title_palette.o"
if errorlevel 1 exit /b 1

echo [demo] Compiling intro_title_fade.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%GEN_DIR%\intro_title_fade.c" -o "%OUT_DIR%\intro_title_fade.o"
if errorlevel 1 exit /b 1

echo [demo] Compiling intro_title_glow.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%GEN_DIR%\intro_title_glow.c" -o "%OUT_DIR%\intro_title_glow.o"
if errorlevel 1 exit /b 1

echo [demo] Compiling src/intro_title.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%SRC_DIR%\intro_title.c" -o "%OUT_DIR%\intro_title.o"
if errorlevel 1 exit /b 1

echo [demo] Compiling src/intro_phase.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%SRC_DIR%\intro_phase.c" -o "%OUT_DIR%\intro_phase.o"
if errorlevel 1 exit /b 1

echo [demo] Compiling src/intro_story.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%SRC_DIR%\intro_story.c" -o "%OUT_DIR%\intro_story.o"
if errorlevel 1 exit /b 1

echo [demo] Assembling boot.asm
"%VASM%" -Felf -m68000 -L "%OUT_DIR%\boot.lst" -o "%OUT_DIR%\boot.o" "%DEMO_DIR%\boot.asm"
if errorlevel 1 exit /b 1

echo [demo] Linking
"%M68K_LD%" -T "%DEMO_DIR%\intro_demo.ld" -o "%OUT_DIR%\intro_demo.elf" ^
    "%OUT_DIR%\boot.o" ^
    "%OUT_DIR%\main.o" ^
    "%OUT_DIR%\intro_common_bg_chr.o" ^
    "%OUT_DIR%\intro_font_chr.o" ^
    "%OUT_DIR%\intro_palette.o" ^
    "%OUT_DIR%\intro_story_tilemap.o" ^
    "%OUT_DIR%\intro_treasures_tilemap.o" ^
    "%OUT_DIR%\intro_punct_chr.o" ^
    "%OUT_DIR%\intro_sprite_chr.o" ^
    "%OUT_DIR%\intro_misc_chr.o" ^
    "%OUT_DIR%\intro_blink_chr.o" ^
    "%OUT_DIR%\intro_demo_palettes.o" ^
    "%OUT_DIR%\intro_combined_palette.o" ^
    "%OUT_DIR%\intro_title_bg_chr.o" ^
    "%OUT_DIR%\intro_title_sprite_chr.o" ^
    "%OUT_DIR%\intro_title_tilemap.o" ^
    "%OUT_DIR%\intro_title_palette.o" ^
    "%OUT_DIR%\intro_title_fade.o" ^
    "%OUT_DIR%\intro_title_glow.o" ^
    "%OUT_DIR%\intro_title.o" ^
    "%OUT_DIR%\intro_phase.o" ^
    "%OUT_DIR%\intro_story.o"
if errorlevel 1 exit /b 1

echo [demo] objcopy -> raw bin
"%M68K_OBJCOPY%" -O binary "%OUT_DIR%\intro_demo.elf" "%OUT_DIR%\intro_demo.bin"
if errorlevel 1 exit /b 1

echo [demo] fix checksum + pad
"%PYTHON%" "%ROOT%\tools\fix_checksum.py" "%OUT_DIR%\intro_demo.bin" "%OUT_DIR%\intro_demo.md"
if errorlevel 1 exit /b 1

echo [demo] DONE: %OUT_DIR%\intro_demo.md
endlocal
