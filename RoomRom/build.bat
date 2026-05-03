@echo off
setlocal EnableExtensions

rem ---------------------------------------------------------------------------
rem RoomRom build script — standalone SGDK project for room render testing.
rem Boots straight to overworld room 0x77, no game init, no file select.
rem Output: out\RoomRom.md
rem ---------------------------------------------------------------------------
rem
rem REQUIRE_GENERATED_ASSETS — strict generated-only build gate (Task 1.11)
rem
rem   Default (unset): soft-warning mode.  Checked-in data/ files are used as
rem     a fallback when GENERATED_ASSET_ROOT is missing or incomplete.  A
rem     WARNING is printed but the build continues.  This is the normal
rem     developer workflow until all Phase 1 extractors are complete.
rem
rem   Set to 1: strict mode.  Any compile step that reads a Nintendo-derived
rem     file from data/, src/data/, src/gen/, or RoomRom/data/ without a
rem     matching entry in the generated manifest at GENERATED_ASSET_ROOT will
rem     print "STRICT GATE FAIL: <path>" and abort the build (exit /b 1).
rem     Use this mode when verifying legal reproducibility:
rem
rem       set REQUIRE_GENERATED_ASSETS=1
rem       RoomRom\build.bat
rem
rem     Or invoke through tools\builder\strict_build_check.py which sets the
rem     flag, runs both targets, and collects all FAIL lines.
rem
rem   This gate is currently EXPECTED TO FAIL (Phase 1 extractors incomplete).
rem   It becomes mandatory (must be green) at Phase 1.10 close per master plan.
rem   See docs/audit/strict_build_gate.md for the full policy.
rem ---------------------------------------------------------------------------

set "GATE_FAIL="

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
rem Step 0: NES-dispatch / item CHR manifest sanity check (strict).
rem All sprite_size divergences must be documented with sprite_size_override_reason
rem in item_chr_manifest.json (atlas spec P6a). New items must reconcile with
rem NES dispatch or add an override_reason before the build will pass.
rem ---------------------------------------------------------------------------
echo [0] Verifying item CHR manifest (strict)...
python "%PROJ%\tools\verify_item_chr_manifest.py" --strict
if errorlevel 1 ( echo FAIL: item CHR manifest verify & exit /b 1 )

echo [0] verify_slot_map...
python "%PROJ%\tools\verify_slot_map.py"
if errorlevel 1 ( echo FAIL: verify_slot_map & exit /b 1 )

echo [0] verify_vram_budget...
python "%PROJ%\tools\verify_vram_budget.py"
if errorlevel 1 ( echo FAIL: verify_vram_budget & exit /b 1 )

rem ---------------------------------------------------------------------------
rem Compiler flags (match makefile.gen release config)
rem ---------------------------------------------------------------------------
rem Per debate 006 D3: define ROOMROM_BUILD so platform_abi.h selects the
rem non-A4 nes_ram variant (regular global pointer, initialized in
rem RoomRom/src/boot/nes_ram_init.c). Title.md build leaves this undefined
rem and uses the A4-pinned variant for transpile-bridge perf parity.
set "CFLAGS=-DSGDK_GCC -DROOMROM_BUILD -m68000 -Wall -Wno-main -Wno-unused-parameter -fno-builtin -ffunction-sections -fdata-sections -fms-extensions -Os -fomit-frame-pointer -B%TOOLBIN%\"
set "INCS=-I%PROJ%\src -I%SGDK%\inc -I%SGDK%\res -I%REPO%\src -I%REPO%\src\abi -I%REPO%\src\state -I%REPO%\src\game\cave -I%REPO%\src\oracle\room"

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
echo [3] Compiling boot/nes_ram_init.c (D3 substrate per debate 006)...
"%GCC%" %CFLAGS% %INCS% -c "%PROJ%\src\boot\nes_ram_init.c" -o "%OUT%\nes_ram_init.o"
if errorlevel 1 ( echo FAIL: boot/nes_ram_init.c & exit /b 1 )

echo [3] Compiling src/game/cave/cave_dispatch.c (D2 native cave per debate 006)...
"%GCC%" %CFLAGS% %INCS% -c "%REPO%\src\game\cave\cave_dispatch.c" -o "%OUT%\cave_dispatch.o"
if errorlevel 1 ( echo FAIL: src/game/cave/cave_dispatch.c & exit /b 1 )

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

rem roomrom_item_chr.c removed in atlas FU4 - superseded by atlas/items_chr_x4.c

echo [3] Compiling roomrom_bg_palette.c...
"%GCC%" %CFLAGS% %INCS% -c "%PROJ%\src\roomrom_bg_palette.c" -o "%OUT%\roomrom_bg_palette.o"
if errorlevel 1 ( echo FAIL: roomrom_bg_palette.c & exit /b 1 )

echo [3] Compiling roomrom_scene_load.c...
"%GCC%" %CFLAGS% %INCS% -c "%PROJ%\src\roomrom_scene_load.c" -o "%OUT%\roomrom_scene_load.o"
if errorlevel 1 ( echo FAIL: roomrom_scene_load.c & exit /b 1 )

echo [3] Compiling roomrom_ow_palette.c...
"%GCC%" %CFLAGS% %INCS% -c "%PROJ%\src\roomrom_ow_palette.c" -o "%OUT%\roomrom_ow_palette.o"
if errorlevel 1 ( echo FAIL: roomrom_ow_palette.c & exit /b 1 )

echo [3] Compiling expanded_bg_chr.c...
"%GCC%" %CFLAGS% %INCS% -c "%PROJ%\src\expanded_bg_chr.c" -o "%OUT%\expanded_bg_chr.o"
if errorlevel 1 ( echo FAIL: expanded_bg_chr.c & exit /b 1 )

rem expanded_sprite_chr.c removed in atlas FU4 - superseded by atlas/items_chr_x4.c

echo [3] Compiling atlas/items_chr_x4.c...
"%GCC%" %CFLAGS% %INCS% -c "%PROJ%\src\atlas\items_chr_x4.c" -o "%OUT%\atlas_items_chr_x4.o"
if errorlevel 1 ( echo FAIL: atlas/items_chr_x4.c & exit /b 1 )

rem --- strict gate: data/rooms/ + data/chr/ are Nintendo-derived extracted assets ---
if defined REQUIRE_GENERATED_ASSETS (
    call :check_generated "%REPO%\data\rooms\overworld.c"
    call :check_generated "%REPO%\data\chr\overworld_bg.c"
    call :check_generated "%REPO%\data\rooms\dungeons.c"
    call :check_generated "%REPO%\data\chr\underworld_bg.c"
)
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

rem --- strict gate: data/chr/common, sprites; data/misc/palettes are Nintendo-derived ---
if defined REQUIRE_GENERATED_ASSETS (
    call :check_generated "%REPO%\data\chr\common.c"
    call :check_generated "%REPO%\data\chr\sprites.c"
    call :check_generated "%REPO%\data\misc\palettes.c"
)
echo [3] Compiling common.c...
"%GCC%" %CFLAGS% %INCS% -c "%REPO%\data\chr\common.c" -o "%OUT%\common.o"
if errorlevel 1 ( echo FAIL: common.c & exit /b 1 )

echo [3] Compiling sprites.c...
"%GCC%" %CFLAGS% %INCS% -c "%REPO%\data\chr\sprites.c" -o "%OUT%\sprites.o"
if errorlevel 1 ( echo FAIL: sprites.c & exit /b 1 )

echo [3] Compiling palettes.c...
"%GCC%" %CFLAGS% %INCS% -c "%REPO%\data\misc\palettes.c" -o "%OUT%\palettes.o"
if errorlevel 1 ( echo FAIL: palettes.c & exit /b 1 )

rem --- strict gate: abort if any Nintendo-derived file failed manifest check ---
if defined GATE_FAIL (
    echo.
    echo STRICT GATE FAIL: one or more Nintendo-derived source files are not covered
    echo by the generated manifest at GENERATED_ASSET_ROOT.  Run the Phase 1
    echo extractors first, or unset REQUIRE_GENERATED_ASSETS for soft-warning mode.
    echo See docs/audit/strict_build_gate.md for guidance.
    exit /b 1
)

rem ---------------------------------------------------------------------------
rem Step 4: Link
rem ---------------------------------------------------------------------------
echo [4] Linking...
set "OBJS=%OUT%\nes_ram_init.o %OUT%\cave_dispatch.o %OUT%\main.o %OUT%\render_adapter_sgdk.o %OUT%\ow_room_render.o %OUT%\uw_room_render.o %OUT%\uw_room_blob.o %OUT%\roomrom_hud.o %OUT%\roomrom_sprites.o %OUT%\roomrom_combat.o %OUT%\roomrom_boomerang.o %OUT%\roomrom_arrow.o %OUT%\roomrom_bomb.o %OUT%\roomrom_bg_palette.o %OUT%\roomrom_ow_palette.o %OUT%\roomrom_scene_load.o %OUT%\expanded_bg_chr.o %OUT%\atlas_items_chr_x4.o %OUT%\overworld.o %OUT%\overworld_bg.o %OUT%\dungeons.o %OUT%\underworld_bg.o %OUT%\redux_overworld.o %OUT%\redux_overworld_bg.o %OUT%\redux_uw_bg.o %OUT%\redux_hud_chr.o %OUT%\common.o %OUT%\palettes.o %OUT%\sprites.o"
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

exit /b 0

rem ---------------------------------------------------------------------------
rem :check_generated <file-path>
rem
rem Called only when REQUIRE_GENERATED_ASSETS=1.  Checks whether the file is
rem covered by the generated manifest.  Three tiers of evidence (most to least):
rem   1. File lives under %GENERATED_ASSET_ROOT% (extractor placed it there).
rem   2. %GENERATED_ASSET_ROOT%\manifest.json mentions the basename.
rem   3. Neither — print STRICT GATE FAIL and set GATE_FAIL=1.
rem
rem In soft-warning mode this label is never called so there is zero overhead.
rem ---------------------------------------------------------------------------
:check_generated
set "_CGF=%~1"
set "_CGF_BASE=%~nx1"
rem Fast path: file was placed directly under GENERATED_ASSET_ROOT
if defined GENERATED_ASSET_ROOT (
    if exist "%GENERATED_ASSET_ROOT%\%_CGF_BASE%" goto :check_generated_ok
    rem Slower path: manifest.json present — check for basename entry
    if exist "%GENERATED_ASSET_ROOT%\manifest.json" (
        findstr /i /c:"%_CGF_BASE%" "%GENERATED_ASSET_ROOT%\manifest.json" >nul 2>nul
        if not errorlevel 1 goto :check_generated_ok
    )
)
rem Neither condition met — fail the gate
echo STRICT GATE FAIL: %_CGF%
set "GATE_FAIL=1"
goto :eof
:check_generated_ok
goto :eof
