@echo off
setlocal EnableExtensions

rem ---------------------------------------------------------------------------
rem RoomRom build script ? standalone SGDK project for room render testing.
rem Boots straight to overworld room 0x77, no game init, no file select.
rem Output: out\RoomRom.md
rem ---------------------------------------------------------------------------

for %%I in ("%~dp0.") do set "PROJ=%%~fsI"
set "REPO=%PROJ%\.."
set "SGDK=%REPO%\sgdk"
set "BIN=%SGDK%\bin"
set "LIB=%SGDK%\lib"
set "OUT=%PROJ%\out"

set "TOOLBIN=%REPO%\build\toolchain\sgdk_bin\bin"
set "GCC=%TOOLBIN%\gcc.exe"
set "LD=%TOOLBIN%\ld.exe"
set "OBJCOPY=%TOOLBIN%\objcopy.exe"

if not exist "%GCC%" (
    echo ERROR: gcc not found at %GCC%
    exit /b 1
)

if not exist "%OUT%" mkdir "%OUT%"

rem Change to project dir so .incbin "out/rom_head.bin" resolves correctly
cd /d "%PROJ%"

rem ---------------------------------------------------------------------------
rem Compiler flags (match makefile.gen release config)
rem ---------------------------------------------------------------------------
set "CFLAGS=-DSGDK_GCC -m68000 -Wall -Wno-main -Wno-unused-parameter -fno-builtin -ffunction-sections -fdata-sections -fms-extensions -Os -fomit-frame-pointer -B%TOOLBIN%\"
set "INCS=-I%PROJ%\src -I%SGDK%\inc -I%SGDK%\res -I%REPO%\src\abi -I%REPO%\src\game\room"

rem ---------------------------------------------------------------------------
rem Step 1: Compile ROM header (must be first ? sega.s .incbin-s it)
rem ---------------------------------------------------------------------------
echo [1] Compiling rom_head.c...
"%GCC%" %CFLAGS% %INCS% -c "%SGDK%\src\boot\rom_head.c" -o "%OUT%\rom_head.o"
if errorlevel 1 ( echo FAIL: rom_head.c & exit /b 1 )

echo [1] objcopy rom_head.o -^> rom_head.bin...
"%OBJCOPY%" -O binary "%OUT%\rom_head.o" "%OUT%\rom_head.bin"
if errorlevel 1 ( echo FAIL: rom_head objcopy & exit /b 1 )

rem ---------------------------------------------------------------------------
rem Step 2: Compile sega.s boot stub (references out/rom_head.bin)
rem ---------------------------------------------------------------------------
echo [2] Compiling sega.s...
"%GCC%" -x assembler-with-cpp -Wa,--register-prefix-optional,--bitwise-or %CFLAGS% %INCS% -c "%SGDK%\src\boot\sega.s" -o "%OUT%\sega.o"
if errorlevel 1 ( echo FAIL: sega.s & exit /b 1 )

rem ---------------------------------------------------------------------------
rem Step 3: Compile project C files
rem ---------------------------------------------------------------------------
echo [3] Compiling main.c...
"%GCC%" %CFLAGS% %INCS% -c "%PROJ%\src\main.c" -o "%OUT%\main.o"
if errorlevel 1 ( echo FAIL: main.c & exit /b 1 )

echo [3] Compiling render_adapter_sgdk.c...
"%GCC%" %CFLAGS% %INCS% -c "%PROJ%\src\render_adapter_sgdk.c" -o "%OUT%\render_adapter_sgdk.o"
if errorlevel 1 ( echo FAIL: render_adapter_sgdk.c & exit /b 1 )

echo [3] Compiling ow_room_render.c...
"%GCC%" %CFLAGS% %INCS% -c "%REPO%\src\game\room\ow_room_render.c" -o "%OUT%\ow_room_render.o"
if errorlevel 1 ( echo FAIL: ow_room_render.c & exit /b 1 )

echo [3] Compiling overworld.c...
"%GCC%" %CFLAGS% %INCS% -c "%REPO%\data\rooms\overworld.c" -o "%OUT%\overworld.o"
if errorlevel 1 ( echo FAIL: overworld.c & exit /b 1 )

echo [3] Compiling overworld_bg.c...
"%GCC%" %CFLAGS% %INCS% -c "%REPO%\data\chr\overworld_bg.c" -o "%OUT%\overworld_bg.o"
if errorlevel 1 ( echo FAIL: overworld_bg.c & exit /b 1 )

rem ---------------------------------------------------------------------------
rem Step 4: Link
rem ---------------------------------------------------------------------------
echo [4] Linking...
set "OBJS=%OUT%\main.o %OUT%\render_adapter_sgdk.o %OUT%\ow_room_render.o %OUT%\overworld.o %OUT%\overworld_bg.o"
"%GCC%" -m68000 -B%TOOLBIN%\ -n -T "%SGDK%\md.ld" -nostdlib "%OUT%\sega.o" %OBJS% "%LIB%\libmd.a" "%LIB%\libgcc.a" -o "%OUT%\rom.out" -Wl,--gc-sections
if errorlevel 1 ( echo FAIL: link & exit /b 1 )

rem ---------------------------------------------------------------------------
rem Step 5: Binary + checksum
rem ---------------------------------------------------------------------------
echo [5] objcopy ELF -^> flat binary...
"%OBJCOPY%" -O binary "%OUT%\rom.out" "%OUT%\RoomRom_raw.md"
if errorlevel 1 ( echo FAIL: objcopy final & exit /b 1 )

echo [5] fix_checksum...
python "%REPO%\tools\fix_checksum.py" "%OUT%\RoomRom_raw.md" "%OUT%\RoomRom.md"
if errorlevel 1 ( echo FAIL: fix_checksum & exit /b 1 )

del "%OUT%\RoomRom_raw.md" >nul 2>nul

echo.
echo RoomRom built: %OUT%\RoomRom.md
