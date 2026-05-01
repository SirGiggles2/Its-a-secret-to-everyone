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
"%GCC%" %CFLAGS% %INCS% -c "%PROJ%\src\ow_room_render_roomrom.c" -o "%OUT%\ow_room_render.o"
if errorlevel 1 ( echo FAIL: ow_room_render.c & exit /b 1 )

echo [3] Compiling roomrom_hud.c...
"%GCC%" %CFLAGS% %INCS% -c "%PROJ%\src\roomrom_hud.c" -o "%OUT%\roomrom_hud.o"
if errorlevel 1 ( echo FAIL: roomrom_hud.c & exit /b 1 )

echo [3] Compiling uw_room_render_roomrom.c...
"%GCC%" %CFLAGS% %INCS% -c "%PROJ%\src\uw_room_render_roomrom.c" -o "%OUT%\uw_room_render.o"
if errorlevel 1 ( echo FAIL: uw_room_render_roomrom.c & exit /b 1 )

echo [3] Compiling uw_room_blob.c...
"%GCC%" %CFLAGS% %INCS% -c "%PROJ%\src\uw_room_blob.c" -o "%OUT%\uw_room_blob.o"
if errorlevel 1 ( echo FAIL: uw_room_blob.c & exit /b 1 )

echo [3] Compiling roomrom_sprites.c...
"%GCC%" %CFLAGS% %INCS% -c "%PROJ%\src\roomrom_sprites.c" -o "%OUT%\roomrom_sprites.o"
if errorlevel 1 ( echo FAIL: roomrom_sprites.c & exit /b 1 )

echo [3] Compiling roomrom_combat.c...
"%GCC%" %CFLAGS% %INCS% -c "%PROJ%\src\roomrom_combat.c" -o "%OUT%\roomrom_combat.o"
if errorlevel 1 ( echo FAIL: roomrom_combat.c & exit /b 1 )

echo [3] Compiling roomrom_boomerang.c...
"%GCC%" %CFLAGS% %INCS% -c "%PROJ%\src\roomrom_boomerang.c" -o "%OUT%\roomrom_boomerang.o"
if errorlevel 1 ( echo FAIL: roomrom_boomerang.c & exit /b 1 )

echo [3] Compiling roomrom_arrow.c...
"%GCC%" %CFLAGS% %INCS% -c "%PROJ%\src\roomrom_arrow.c" -o "%OUT%\roomrom_arrow.o"
if errorlevel 1 ( echo FAIL: roomrom_arrow.c & exit /b 1 )

echo [3] Compiling roomrom_bomb.c...
"%GCC%" %CFLAGS% %INCS% -c "%PROJ%\src\roomrom_bomb.c" -o "%OUT%\roomrom_bomb.o"
if errorlevel 1 ( echo FAIL: roomrom_bomb.c & exit /b 1 )

echo [3] Compiling overworld.c...
"%GCC%" %CFLAGS% %INCS% -c "%REPO%\data\rooms\overworld.c" -o "%OUT%\overworld.o"
if errorlevel 1 ( echo FAIL: overworld.c & exit /b 1 )

echo [3] Compiling overworld_bg.c...
"%GCC%" %CFLAGS% %INCS% -c "%REPO%\data\chr\overworld_bg.c" -o "%OUT%\overworld_bg.o"
if errorlevel 1 ( echo FAIL: overworld_bg.c & exit /b 1 )

echo [3] Compiling dungeons.c...
"%GCC%" %CFLAGS% %INCS% -c "%REPO%\data\rooms\dungeons.c" -o "%OUT%\dungeons.o"
if errorlevel 1 ( echo FAIL: dungeons.c & exit /b 1 )

echo [3] Compiling underworld_bg.c...
"%GCC%" %CFLAGS% %INCS% -c "%REPO%\data\chr\underworld_bg.c" -o "%OUT%\underworld_bg.o"
if errorlevel 1 ( echo FAIL: underworld_bg.c & exit /b 1 )

echo [3] Compiling redux_overworld.c...
"%GCC%" %CFLAGS% %INCS% -c "%PROJ%\src\redux_overworld.c" -o "%OUT%\redux_overworld.o"
if errorlevel 1 ( echo FAIL: redux_overworld.c & exit /b 1 )

echo [3] Compiling redux_overworld_bg.c...
"%GCC%" %CFLAGS% %INCS% -c "%PROJ%\src\redux_overworld_bg.c" -o "%OUT%\redux_overworld_bg.o"
if errorlevel 1 ( echo FAIL: redux_overworld_bg.c & exit /b 1 )

echo [3] Compiling redux_uw_bg.c...
"%GCC%" %CFLAGS% %INCS% -c "%PROJ%\src\redux_uw_bg.c" -o "%OUT%\redux_uw_bg.o"
if errorlevel 1 ( echo FAIL: redux_uw_bg.c & exit /b 1 )

echo [3] Compiling redux_hud_chr.c...
"%GCC%" %CFLAGS% %INCS% -c "%PROJ%\src\redux_hud_chr.c" -o "%OUT%\redux_hud_chr.o"
if errorlevel 1 ( echo FAIL: redux_hud_chr.c & exit /b 1 )

echo [3] Compiling common.c...
"%GCC%" %CFLAGS% %INCS% -c "%REPO%\data\chr\common.c" -o "%OUT%\common.o"
if errorlevel 1 ( echo FAIL: common.c & exit /b 1 )

echo [3] Compiling sprites.c...
"%GCC%" %CFLAGS% %INCS% -c "%REPO%\data\chr\sprites.c" -o "%OUT%\sprites.o"
if errorlevel 1 ( echo FAIL: sprites.c & exit /b 1 )

echo [3] Compiling palettes.c...
"%GCC%" %CFLAGS% %INCS% -c "%REPO%\data\misc\palettes.c" -o "%OUT%\palettes.o"
if errorlevel 1 ( echo FAIL: palettes.c & exit /b 1 )

rem ---------------------------------------------------------------------------
rem Step 4: Link
rem ---------------------------------------------------------------------------
echo [4] Linking...
set "OBJS=%OUT%\main.o %OUT%\render_adapter_sgdk.o %OUT%\ow_room_render.o %OUT%\uw_room_render.o %OUT%\uw_room_blob.o %OUT%\roomrom_hud.o %OUT%\roomrom_sprites.o %OUT%\roomrom_combat.o %OUT%\roomrom_boomerang.o %OUT%\roomrom_arrow.o %OUT%\roomrom_bomb.o %OUT%\overworld.o %OUT%\overworld_bg.o %OUT%\dungeons.o %OUT%\underworld_bg.o %OUT%\redux_overworld.o %OUT%\redux_overworld_bg.o %OUT%\redux_uw_bg.o %OUT%\redux_hud_chr.o %OUT%\common.o %OUT%\palettes.o %OUT%\sprites.o"
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
