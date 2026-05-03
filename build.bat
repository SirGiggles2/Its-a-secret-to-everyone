@echo off
setlocal EnableExtensions

rem ---------------------------------------------------------------------------
rem REQUIRE_GENERATED_ASSETS — strict generated-only build gate (Task 1.11)
rem
rem   Default (unset): soft-warning mode.  Checked-in data/ and src/gen/ files
rem     are used as a fallback when GENERATED_ASSET_ROOT is missing or
rem     incomplete.  A WARNING is printed but the build continues.  This is the
rem     normal developer workflow until all Phase 1 extractors are complete.
rem
rem   Set to 1: strict mode.  Any compile step that reads a Nintendo-derived
rem     file from data/, src/data/, src/gen/, or RoomRom/data/ without a
rem     matching entry in the generated manifest at GENERATED_ASSET_ROOT will
rem     print "STRICT GATE FAIL: <path>" and abort the build (exit /b 1).
rem     Use this mode when verifying legal reproducibility:
rem
rem       set REQUIRE_GENERATED_ASSETS=1
rem       build.bat
rem
rem     Or invoke through tools\builder\strict_build_check.py which sets the
rem     flag, runs both targets, and collects all FAIL lines.
rem
rem   This gate is currently EXPECTED TO FAIL (Phase 1 extractors incomplete).
rem   It becomes mandatory (must be green) at Phase 1.10 close per master plan.
rem   See docs/audit/strict_build_gate.md for the full policy.
rem ---------------------------------------------------------------------------

for %%I in ("%~dp0.") do set "ROOT=%%~fI"

set "PYTHON="
set "VASM="
rem Phase 0 rename (master plan Task 0.2): whatif -> Title.
rem whatif.* aliases REMOVED 2026-05-02 (user hard rule).
set "RAW_ROM=%ROOT%\builds\Title_raw.md"
set "OUT_ROM=%ROOT%\builds\Title.md"
set "OUT_LST=%ROOT%\builds\Title.lst"

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
rem SGDK gates (debate 003, Rules SGDK-1/SGDK-2)
rem
rem   check_sgdk_pin.py        — SGDK submodule SHA must match tools/sgdk_pin.json
rem   check_adapter_boundary.py — owned src/game/, src/frontend/ must not include
rem                              SGDK public headers
rem   check_raw_vdp.py          — owned src/game/, src/frontend/, src/zelda_translated/
rem                              must not touch raw VDP registers
rem
rem   To intentionally bump the SGDK pin: pass --accept-sgdk-bump and update
rem   tools/sgdk_pin.json + docs/sgdk_audit.md in the same commit.
rem ---------------------------------------------------------------------------
echo [SGDK gate] check_sgdk_pin.py
"%PYTHON%" "%ROOT%\tools\check_sgdk_pin.py" %SGDK_PIN_ARGS%
if errorlevel 1 exit /b 1

echo [SGDK gate] check_adapter_boundary.py
"%PYTHON%" "%ROOT%\tools\check_adapter_boundary.py"
if errorlevel 1 exit /b 1

echo [SGDK gate] check_raw_vdp.py
"%PYTHON%" "%ROOT%\tools\check_raw_vdp.py"
if errorlevel 1 exit /b 1

rem ---------------------------------------------------------------------------
rem Worktree gates (debate 004, Rules WT-1/WT-3/WT-4)
rem
rem   check_no_whatif.py            — legacy alias gone; no whatif refs in code
rem   check_frontend_boundary.py    — owned src/game/, RoomRom/src/ must not
rem                                  include src/frontend/* headers (Phase 12
rem                                  promotion gate)
rem   active_scope.py --quiet       — refresh .active_scope + docs/audit/active_scope.md
rem
rem   Substrate-dual-rom gate (check_substrate_dual_rom.py) is wired into
rem   pre-commit / pre-push hook, NOT here, because it triggers a RoomRom
rem   rebuild on substrate diffs (slow on every Title build).
rem ---------------------------------------------------------------------------
echo [WT gate] check_no_whatif.py
"%PYTHON%" "%ROOT%\tools\gates\check_no_whatif.py"
if errorlevel 1 exit /b 1

echo [WT gate] check_frontend_boundary.py
"%PYTHON%" "%ROOT%\tools\gates\check_frontend_boundary.py"
if errorlevel 1 exit /b 1

echo [WT gate] active_scope.py (refresh pointer)
"%PYTHON%" "%ROOT%\tools\audit\active_scope.py" --quiet

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
rem [2] Assemble to ELF object, link via m68k-elf-ld + genesis.ld, strip
rem     to flat binary via objcopy. Stage-2a pivot: vasm -Fbin is gone;
rem     we now have a real linker stage that C object files can be linked
rem     into (Stage 2b+). genesis_shell.asm is still the sole asm root.
rem ---------------------------------------------------------------------------
set "ELF_OBJ=%ROOT%\builds\Title.o"
set "ELF_OUT=%ROOT%\builds\Title.elf"
set "C_OBJ_DIR=%ROOT%\builds\obj"
set "LD_SCRIPT=%ROOT%\build\genesis.ld"
set "M68K_BIN=%ROOT%\build\toolchain\sgdk_bin\bin"
set "M68K_GCC=%M68K_BIN%\gcc.exe"
set "M68K_LD=%M68K_BIN%\ld.exe"
set "M68K_OBJCOPY=%M68K_BIN%\objcopy.exe"

if not exist "%M68K_LD%" (
    echo ERROR: m68k-elf toolchain not found at %M68K_BIN%
    echo        Expected m68k-elf-ld + objcopy at build\toolchain\sgdk_bin\bin\
    exit /b 1
)

rem ---------------------------------------------------------------------------
rem Strict generated-asset gate helper.
rem
rem   When REQUIRE_GENERATED_ASSETS=1, call :check_generated <file-path> before
rem   compiling any Nintendo-derived source.  The helper verifies the file is
rem   listed in %GENERATED_ASSET_ROOT%\manifest.json (or a per-dir manifest).
rem   If the manifest is absent or the entry is missing it prints
rem   "STRICT GATE FAIL: <path>" and sets the GATE_FAIL flag.
rem   At the end of this section GATE_FAIL is tested; if set the build aborts.
rem
rem   In soft-warning mode (REQUIRE_GENERATED_ASSETS unset) the helper is a
rem   no-op; the existing checked-in fallback data is silently accepted.
rem ---------------------------------------------------------------------------
set "GATE_FAIL="

rem ---------------------------------------------------------------------------
rem [2a.0/4] Asset extraction — run extractors to populate GENERATED_ASSET_ROOT
rem ---------------------------------------------------------------------------
echo [2a.0/4] Extracting intro assets from reference data...
"%PYTHON%" "%ROOT%\tools\extract_intro_assets.py"
if errorlevel 1 exit /b 1

echo [2a.0b/4] Extracting File Select assets from live CHR-RAM dump...
"%PYTHON%" "%ROOT%\tools\extract_fs_assets.py"
if errorlevel 1 exit /b 1

echo [2a.0c/4] Verifying data/MANIFEST.sha256 matches data/ tree...
"%PYTHON%" "%ROOT%\tools\probes\check_data_manifest.py"
if errorlevel 1 (
    echo.
    echo data/ output differs from committed manifest.
    echo Re-run: python tools\build_data.py
    echo Then commit data\MANIFEST.sha256 if intentional.
    exit /b 1
)

if not exist "%C_OBJ_DIR%" mkdir "%C_OBJ_DIR%"

rem ---------------------------------------------------------------------------
rem C objects (Stage 2b+).  -B tells gcc where to find cc1 / cpp since the
rem SGDK extraction flattens bin\ instead of using libexec\gcc\... .
rem   -ffixed-a4 pins A4=NES_RAM across every C function (matches the asm
rem   contract); without it gcc will clobber A4 on calls and break interop.
rem
rem NOTE on -B trailing backslash: gcc expects the prefix path to end with
rem a separator so it concatenates e.g. "bin\" + "cc1.exe" to find cc1.
rem cmd parses a trailing backslash+space as a line-continuation in some
rem contexts, so pass the -B arg SEPARATELY (not from a joined variable).
rem ---------------------------------------------------------------------------
rem C_SOURCES split around the frontend block to preserve original link order:
rem   C_SOURCES_PRE  → C_FRONTEND → C_SOURCES_MID → C_FRONTEND_INTRO → C_FRONTEND_FS
rem   (original order: ...room_object_runtime frontend_runtime save_menu_runtime intro_* fs_*)
rem B5a: enemies → src/game/enemies/
rem B5b: combat/collision/targeting → src/game/combat/
rem B5c: room → src/game/room/
rem B5d: cave/uw_person → src/game/cave/
rem B5f: hud → src/game/hud/
rem B5g: item/weapon → src/game/items/
rem B5h: core_runtime → src/core/; object/sprite/world/progress/trap/c_move_object → src/game/world/
set "C_CORE_RT=core_runtime"
set "C_GAME_WORLD_PRE=c_move_object object_runtime"
set "C_GAME_ENEMIES=c_wanderer enemy_runtime enemy_common_runtime enemy_walker_runtime enemy_wanderer_runtime enemy_block_runtime enemy_wallmaster_runtime enemy_flyer_runtime enemy_boss_runtime enemy_gleeok_runtime enemy_dodongo_runtime enemy_manhandla_runtime enemy_lamnola_runtime enemy_projectile_runtime"
set "C_GAME_CAVE=uw_person_runtime cave_runtime"
set "C_GAME_HUD=hud_runtime"
set "C_GAME_ITEMS=item_runtime weapon_runtime"
set "C_GAME_WORLD_MID=world_runtime sprite_runtime"
set "C_GAME_COMBAT_A=combat_runtime collision_runtime link_collision_runtime"
set "C_GAME_WORLD_POST=progress_runtime"
set "C_GAME_COMBAT_B=targeting_runtime"
set "C_GAME_WORLD_TRAP=trap_runtime"
set "C_GAME_ROOM=room_runtime room_load_runtime room_mode_runtime room_transfer_runtime room_player_runtime room_object_runtime ow_room_render ow_room_debug"
set "C_FRONTEND=frontend_runtime"
set "C_SOURCES_MID=save_menu_runtime"
set "C_FRONTEND_INTRO=intro_common intro_story intro_handoff intro_main intro_phase intro_title"
set "C_FRONTEND_FS=fs_main fs_render fs_phase fs_input fs_handoff"
set "C_GEN_TRANSPILE=z_01 z_02 z_03 z_04 z_05 z_06 z_07"
set "C_DATA_INTRO=intro_font_chr intro_art_chr intro_palette intro_story_tilemap intro_restore_chr intro_restore_palette intro_title_bg_chr intro_title_sprite_chr intro_title_palette intro_title_tilemap intro_title_fade intro_title_glow intro_common_bg_chr intro_sprite_chr intro_misc_chr intro_punct_chr intro_blink_chr intro_combined_palette intro_treasures_tilemap"
set "C_DATA_FS=fs_palette fs_static_tilemap fs_static_attr fs_link_sprite_chr fs_heart_cursor_chr fs_bg_chr_full"
set "C_DATA_ROOMS=overworld"
set "C_DATA_CHR=overworld_bg common"
set "C_DATA_MISC=palettes"
rem Write object list to response file during compile loop. CMD line-length
rem limit (~8KB) breaks once %C_OBJS% accumulates too many fs_*/intro_*
rem paths. Convert backslashes to forward slashes in the response file —
rem ld treats backslashes as escape sequences when reading @file args.
set "LD_RESP=%C_OBJ_DIR%\link_objs.rsp"
set "OBJ_DIR_FS=%C_OBJ_DIR:\=/%"
if exist "%LD_RESP%" del "%LD_RESP%"
echo [2a/4] Compiling core/c_runtime.c...
"%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src" -I "%ROOT%\src\state" -I "%ROOT%\src\core" -I "%ROOT%\src\abi" -I "%ROOT%\src\frontend" -I "%ROOT%\src\frontend\intro" -I "%ROOT%\src\frontend\fs" -I "%ROOT%\src\game\enemies" -I "%ROOT%\src\game\combat" -I "%ROOT%\src\game\room" -I "%ROOT%\src\game\cave" -I "%ROOT%\src\game\hud" -I "%ROOT%\src\game\items" -I "%ROOT%\src\game\world" -I "%ROOT%\sgdk\inc" -c "%ROOT%\src\core\c_runtime.c" -o "%C_OBJ_DIR%\c_runtime.o"
if errorlevel 1 exit /b 1
>> "%LD_RESP%" echo "%OBJ_DIR_FS%/c_runtime.o"

echo [2a.fixture/4] Compiling tools/probes/sram_layout_test.c (compile-only)...
"%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -c "%ROOT%\tools\probes\sram_layout_test.c" -o "%C_OBJ_DIR%\sram_layout_test.o"
if errorlevel 1 exit /b 1
rem fixture .o is not appended to LD_RESP — static asserts already fired

echo [2a.adapter/4] Compiling src/sgdk_adapter/render_adapter.c...
"%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src\abi" -I "%ROOT%\src\sgdk_adapter" -I "%ROOT%\src\frontend\intro" -c "%ROOT%\src\sgdk_adapter\render_adapter.c" -o "%C_OBJ_DIR%\render_adapter.o"
if errorlevel 1 exit /b 1
>> "%LD_RESP%" echo "%OBJ_DIR_FS%/render_adapter.o"

echo [2a.adapter/4] Compiling src/sgdk_adapter/audio_adapter.c (XGM-wired)...
"%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src\abi" -I "%ROOT%\src\sgdk_adapter" -I "%ROOT%\data\audio" -I "%ROOT%\sgdk\inc" -I "%ROOT%\sgdk\inc\snd" -c "%ROOT%\src\sgdk_adapter\audio_adapter.c" -o "%C_OBJ_DIR%\audio_adapter.o"
if errorlevel 1 exit /b 1
>> "%LD_RESP%" echo "%OBJ_DIR_FS%/audio_adapter.o"

echo [2a.adapter/4] Compiling data/audio/sfx_pcm.c (XGM PCM bank)...
"%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\data\audio" -I "%ROOT%\sgdk\inc" -c "%ROOT%\data\audio\sfx_pcm.c" -o "%C_OBJ_DIR%\sfx_pcm.o"
if errorlevel 1 exit /b 1
>> "%LD_RESP%" echo "%OBJ_DIR_FS%/sfx_pcm.o"

echo [2a.adapter/4] Compiling src/sgdk_adapter/joy_adapter.c (compile-only)...
"%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src\abi" -I "%ROOT%\src\sgdk_adapter" -c "%ROOT%\src\sgdk_adapter\joy_adapter.c" -o "%C_OBJ_DIR%\joy_adapter.o"
if errorlevel 1 exit /b 1
rem adapter .o not in LD_RESP — no live caller until Phase F retargets frontend

echo [2a.adapter/4] Compiling src/sgdk_adapter/sram_adapter.c (compile-only)...
"%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src\abi" -I "%ROOT%\src\sgdk_adapter" -c "%ROOT%\src\sgdk_adapter\sram_adapter.c" -o "%C_OBJ_DIR%\sram_adapter.o"
if errorlevel 1 exit /b 1
rem adapter .o not in LD_RESP — no live caller until Phase F retargets frontend

echo [2a.state/4] Compiling src/state/palette_tick.c (compile-only)...
"%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src" -I "%ROOT%\src\state" -I "%ROOT%\src\abi" -c "%ROOT%\src\state\palette_tick.c" -o "%C_OBJ_DIR%\palette_tick.o"
if errorlevel 1 exit /b 1
rem state .o not in LD_RESP yet — wired into LD_RESP when first caller (RoomRom-promoted runtime or src/frontend/intro) registers a toggle.

for %%F in (%C_CORE_RT%) do (
    echo [2a/4] Compiling core/%%F.c...
    "%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src" -I "%ROOT%\src\state" -I "%ROOT%\src\core" -I "%ROOT%\src\abi" -I "%ROOT%\src\frontend" -I "%ROOT%\src\frontend\intro" -I "%ROOT%\src\frontend\fs" -I "%ROOT%\src\game\enemies" -I "%ROOT%\src\game\combat" -I "%ROOT%\src\game\room" -I "%ROOT%\src\game\cave" -I "%ROOT%\src\game\hud" -I "%ROOT%\src\game\items" -I "%ROOT%\src\game\world" -I "%ROOT%\sgdk\inc" -c "%ROOT%\src\core\%%F.c" -o "%C_OBJ_DIR%\%%F.o"
    if errorlevel 1 exit /b 1
    >> "%LD_RESP%" echo "%OBJ_DIR_FS%/%%F.o"
)
for %%F in (%C_GAME_WORLD_PRE%) do (
    echo [2a/4] Compiling game/world/%%F.c...
    "%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src" -I "%ROOT%\src\state" -I "%ROOT%\src\core" -I "%ROOT%\src\abi" -I "%ROOT%\src\frontend" -I "%ROOT%\src\frontend\intro" -I "%ROOT%\src\frontend\fs" -I "%ROOT%\src\game\enemies" -I "%ROOT%\src\game\combat" -I "%ROOT%\src\game\room" -I "%ROOT%\src\game\cave" -I "%ROOT%\src\game\hud" -I "%ROOT%\src\game\items" -I "%ROOT%\src\game\world" -I "%ROOT%\sgdk\inc" -c "%ROOT%\src\game\world\%%F.c" -o "%C_OBJ_DIR%\%%F.o"
    if errorlevel 1 exit /b 1
    >> "%LD_RESP%" echo "%OBJ_DIR_FS%/%%F.o"
)
for %%F in (%C_GAME_ENEMIES%) do (
    echo [2a/4] Compiling game/enemies/%%F.c...
    "%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src" -I "%ROOT%\src\state" -I "%ROOT%\src\core" -I "%ROOT%\src\abi" -I "%ROOT%\src\frontend" -I "%ROOT%\src\frontend\intro" -I "%ROOT%\src\frontend\fs" -I "%ROOT%\src\game\enemies" -I "%ROOT%\src\game\combat" -I "%ROOT%\src\game\room" -I "%ROOT%\src\game\cave" -I "%ROOT%\src\game\hud" -I "%ROOT%\src\game\items" -I "%ROOT%\src\game\world" -I "%ROOT%\sgdk\inc" -c "%ROOT%\src\game\enemies\%%F.c" -o "%C_OBJ_DIR%\%%F.o"
    if errorlevel 1 exit /b 1
    >> "%LD_RESP%" echo "%OBJ_DIR_FS%/%%F.o"
)
for %%F in (%C_GAME_CAVE%) do (
    echo [2a/4] Compiling game/cave/%%F.c...
    "%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src" -I "%ROOT%\src\state" -I "%ROOT%\src\core" -I "%ROOT%\src\abi" -I "%ROOT%\src\frontend" -I "%ROOT%\src\frontend\intro" -I "%ROOT%\src\frontend\fs" -I "%ROOT%\src\game\enemies" -I "%ROOT%\src\game\combat" -I "%ROOT%\src\game\room" -I "%ROOT%\src\game\cave" -I "%ROOT%\src\game\hud" -I "%ROOT%\src\game\items" -I "%ROOT%\src\game\world" -I "%ROOT%\sgdk\inc" -c "%ROOT%\src\game\cave\%%F.c" -o "%C_OBJ_DIR%\%%F.o"
    if errorlevel 1 exit /b 1
    >> "%LD_RESP%" echo "%OBJ_DIR_FS%/%%F.o"
)
for %%F in (%C_GAME_HUD%) do (
    echo [2a/4] Compiling game/hud/%%F.c...
    "%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src" -I "%ROOT%\src\state" -I "%ROOT%\src\core" -I "%ROOT%\src\abi" -I "%ROOT%\src\frontend" -I "%ROOT%\src\frontend\intro" -I "%ROOT%\src\frontend\fs" -I "%ROOT%\src\game\enemies" -I "%ROOT%\src\game\combat" -I "%ROOT%\src\game\room" -I "%ROOT%\src\game\cave" -I "%ROOT%\src\game\hud" -I "%ROOT%\src\game\items" -I "%ROOT%\src\game\world" -I "%ROOT%\sgdk\inc" -c "%ROOT%\src\game\hud\%%F.c" -o "%C_OBJ_DIR%\%%F.o"
    if errorlevel 1 exit /b 1
    >> "%LD_RESP%" echo "%OBJ_DIR_FS%/%%F.o"
)
for %%F in (%C_GAME_ITEMS%) do (
    echo [2a/4] Compiling game/items/%%F.c...
    "%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src" -I "%ROOT%\src\state" -I "%ROOT%\src\core" -I "%ROOT%\src\abi" -I "%ROOT%\src\frontend" -I "%ROOT%\src\frontend\intro" -I "%ROOT%\src\frontend\fs" -I "%ROOT%\src\game\enemies" -I "%ROOT%\src\game\combat" -I "%ROOT%\src\game\room" -I "%ROOT%\src\game\cave" -I "%ROOT%\src\game\hud" -I "%ROOT%\src\game\items" -I "%ROOT%\src\game\world" -I "%ROOT%\sgdk\inc" -c "%ROOT%\src\game\items\%%F.c" -o "%C_OBJ_DIR%\%%F.o"
    if errorlevel 1 exit /b 1
    >> "%LD_RESP%" echo "%OBJ_DIR_FS%/%%F.o"
)
for %%F in (%C_GAME_WORLD_MID%) do (
    echo [2a/4] Compiling game/world/%%F.c...
    "%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src" -I "%ROOT%\src\state" -I "%ROOT%\src\core" -I "%ROOT%\src\abi" -I "%ROOT%\src\frontend" -I "%ROOT%\src\frontend\intro" -I "%ROOT%\src\frontend\fs" -I "%ROOT%\src\game\enemies" -I "%ROOT%\src\game\combat" -I "%ROOT%\src\game\room" -I "%ROOT%\src\game\cave" -I "%ROOT%\src\game\hud" -I "%ROOT%\src\game\items" -I "%ROOT%\src\game\world" -I "%ROOT%\sgdk\inc" -c "%ROOT%\src\game\world\%%F.c" -o "%C_OBJ_DIR%\%%F.o"
    if errorlevel 1 exit /b 1
    >> "%LD_RESP%" echo "%OBJ_DIR_FS%/%%F.o"
)
for %%F in (%C_GAME_COMBAT_A%) do (
    echo [2a/4] Compiling game/combat/%%F.c...
    "%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src" -I "%ROOT%\src\state" -I "%ROOT%\src\core" -I "%ROOT%\src\abi" -I "%ROOT%\src\frontend" -I "%ROOT%\src\frontend\intro" -I "%ROOT%\src\frontend\fs" -I "%ROOT%\src\game\enemies" -I "%ROOT%\src\game\combat" -I "%ROOT%\src\game\room" -I "%ROOT%\src\game\cave" -I "%ROOT%\src\game\hud" -I "%ROOT%\src\game\items" -I "%ROOT%\src\game\world" -I "%ROOT%\sgdk\inc" -c "%ROOT%\src\game\combat\%%F.c" -o "%C_OBJ_DIR%\%%F.o"
    if errorlevel 1 exit /b 1
    >> "%LD_RESP%" echo "%OBJ_DIR_FS%/%%F.o"
)
for %%F in (%C_GAME_WORLD_POST%) do (
    echo [2a/4] Compiling game/world/%%F.c...
    "%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src" -I "%ROOT%\src\state" -I "%ROOT%\src\core" -I "%ROOT%\src\abi" -I "%ROOT%\src\frontend" -I "%ROOT%\src\frontend\intro" -I "%ROOT%\src\frontend\fs" -I "%ROOT%\src\game\enemies" -I "%ROOT%\src\game\combat" -I "%ROOT%\src\game\room" -I "%ROOT%\src\game\cave" -I "%ROOT%\src\game\hud" -I "%ROOT%\src\game\items" -I "%ROOT%\src\game\world" -I "%ROOT%\sgdk\inc" -c "%ROOT%\src\game\world\%%F.c" -o "%C_OBJ_DIR%\%%F.o"
    if errorlevel 1 exit /b 1
    >> "%LD_RESP%" echo "%OBJ_DIR_FS%/%%F.o"
)
for %%F in (%C_GAME_COMBAT_B%) do (
    echo [2a/4] Compiling game/combat/%%F.c...
    "%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src" -I "%ROOT%\src\state" -I "%ROOT%\src\core" -I "%ROOT%\src\abi" -I "%ROOT%\src\frontend" -I "%ROOT%\src\frontend\intro" -I "%ROOT%\src\frontend\fs" -I "%ROOT%\src\game\enemies" -I "%ROOT%\src\game\combat" -I "%ROOT%\src\game\room" -I "%ROOT%\src\game\cave" -I "%ROOT%\src\game\hud" -I "%ROOT%\src\game\items" -I "%ROOT%\src\game\world" -I "%ROOT%\sgdk\inc" -c "%ROOT%\src\game\combat\%%F.c" -o "%C_OBJ_DIR%\%%F.o"
    if errorlevel 1 exit /b 1
    >> "%LD_RESP%" echo "%OBJ_DIR_FS%/%%F.o"
)
for %%F in (%C_GAME_WORLD_TRAP%) do (
    echo [2a/4] Compiling game/world/%%F.c...
    "%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src" -I "%ROOT%\src\state" -I "%ROOT%\src\core" -I "%ROOT%\src\abi" -I "%ROOT%\src\frontend" -I "%ROOT%\src\frontend\intro" -I "%ROOT%\src\frontend\fs" -I "%ROOT%\src\game\enemies" -I "%ROOT%\src\game\combat" -I "%ROOT%\src\game\room" -I "%ROOT%\src\game\cave" -I "%ROOT%\src\game\hud" -I "%ROOT%\src\game\items" -I "%ROOT%\src\game\world" -I "%ROOT%\sgdk\inc" -c "%ROOT%\src\game\world\%%F.c" -o "%C_OBJ_DIR%\%%F.o"
    if errorlevel 1 exit /b 1
    >> "%LD_RESP%" echo "%OBJ_DIR_FS%/%%F.o"
)
for %%F in (%C_GAME_ROOM%) do (
    echo [2a/4] Compiling game/room/%%F.c...
    "%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src" -I "%ROOT%\src\state" -I "%ROOT%\src\core" -I "%ROOT%\src\abi" -I "%ROOT%\src\frontend" -I "%ROOT%\src\frontend\intro" -I "%ROOT%\src\frontend\fs" -I "%ROOT%\src\game\enemies" -I "%ROOT%\src\game\combat" -I "%ROOT%\src\game\room" -I "%ROOT%\src\game\cave" -I "%ROOT%\src\game\hud" -I "%ROOT%\src\game\items" -I "%ROOT%\src\game\world" -I "%ROOT%\sgdk\inc" -c "%ROOT%\src\game\room\%%F.c" -o "%C_OBJ_DIR%\%%F.o"
    if errorlevel 1 exit /b 1
    >> "%LD_RESP%" echo "%OBJ_DIR_FS%/%%F.o"
)
for %%F in (%C_FRONTEND%) do (
    echo [2a/4] Compiling frontend/%%F.c...
    "%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src" -I "%ROOT%\src\state" -I "%ROOT%\src\core" -I "%ROOT%\src\abi" -I "%ROOT%\src\frontend" -I "%ROOT%\src\frontend\intro" -I "%ROOT%\src\frontend\fs" -I "%ROOT%\src\game\enemies" -I "%ROOT%\src\game\combat" -I "%ROOT%\src\game\room" -I "%ROOT%\src\game\cave" -I "%ROOT%\src\game\hud" -I "%ROOT%\src\game\items" -I "%ROOT%\src\game\world" -I "%ROOT%\sgdk\inc" -c "%ROOT%\src\frontend\%%F.c" -o "%C_OBJ_DIR%\%%F.o"
    if errorlevel 1 exit /b 1
    >> "%LD_RESP%" echo "%OBJ_DIR_FS%/%%F.o"
)
for %%F in (%C_SOURCES_MID%) do (
    echo [2a/4] Compiling %%F.c...
    "%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src" -I "%ROOT%\src\state" -I "%ROOT%\src\core" -I "%ROOT%\src\abi" -I "%ROOT%\src\frontend" -I "%ROOT%\src\frontend\intro" -I "%ROOT%\src\frontend\fs" -I "%ROOT%\src\game\enemies" -I "%ROOT%\src\game\combat" -I "%ROOT%\src\game\room" -I "%ROOT%\src\game\cave" -I "%ROOT%\src\game\hud" -I "%ROOT%\src\game\items" -I "%ROOT%\src\game\world" -I "%ROOT%\sgdk\inc" -c "%ROOT%\src\%%F.c" -o "%C_OBJ_DIR%\%%F.o"
    if errorlevel 1 exit /b 1
    >> "%LD_RESP%" echo "%OBJ_DIR_FS%/%%F.o"
)
for %%F in (%C_FRONTEND_INTRO%) do (
    echo [2a/4] Compiling frontend/intro/%%F.c...
    "%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src" -I "%ROOT%\src\state" -I "%ROOT%\src\core" -I "%ROOT%\src\abi" -I "%ROOT%\src\frontend" -I "%ROOT%\src\frontend\intro" -I "%ROOT%\src\frontend\fs" -I "%ROOT%\src\game\enemies" -I "%ROOT%\src\game\combat" -I "%ROOT%\src\game\room" -I "%ROOT%\src\game\cave" -I "%ROOT%\src\game\hud" -I "%ROOT%\src\game\items" -I "%ROOT%\src\game\world" -I "%ROOT%\sgdk\inc" -c "%ROOT%\src\frontend\intro\%%F.c" -o "%C_OBJ_DIR%\%%F.o"
    if errorlevel 1 exit /b 1
    >> "%LD_RESP%" echo "%OBJ_DIR_FS%/%%F.o"
)
for %%F in (%C_FRONTEND_FS%) do (
    echo [2a/4] Compiling frontend/fs/%%F.c...
    "%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src" -I "%ROOT%\src\state" -I "%ROOT%\src\core" -I "%ROOT%\src\abi" -I "%ROOT%\src\frontend" -I "%ROOT%\src\frontend\intro" -I "%ROOT%\src\frontend\fs" -I "%ROOT%\src\game\enemies" -I "%ROOT%\src\game\combat" -I "%ROOT%\src\game\room" -I "%ROOT%\src\game\cave" -I "%ROOT%\src\game\hud" -I "%ROOT%\src\game\items" -I "%ROOT%\src\game\world" -I "%ROOT%\sgdk\inc" -c "%ROOT%\src\frontend\fs\%%F.c" -o "%C_OBJ_DIR%\%%F.o"
    if errorlevel 1 exit /b 1
    >> "%LD_RESP%" echo "%OBJ_DIR_FS%/%%F.o"
)
rem --- strict gate: src/gen/ files are Nintendo-derived transpiler output ---
if defined REQUIRE_GENERATED_ASSETS (
    for %%F in (%C_GEN_TRANSPILE%) do (
        call :check_generated "%ROOT%\src\gen\%%F.c"
    )
)
for %%F in (%C_GEN_TRANSPILE%) do (
    echo [2a/4] Compiling gen/%%F.c...
    "%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src" -I "%ROOT%\src\state" -I "%ROOT%\src\core" -I "%ROOT%\src\abi" -I "%ROOT%\src\frontend" -I "%ROOT%\src\frontend\intro" -I "%ROOT%\src\frontend\fs" -I "%ROOT%\src\game\enemies" -I "%ROOT%\src\game\combat" -I "%ROOT%\src\game\room" -I "%ROOT%\src\game\cave" -I "%ROOT%\src\game\hud" -I "%ROOT%\src\game\items" -I "%ROOT%\src\game\world" -I "%ROOT%\data\intro" -I "%ROOT%\data\fs" -I "%ROOT%\sgdk\inc" -c "%ROOT%\src\gen\%%F.c" -o "%C_OBJ_DIR%\%%F.o"
    if errorlevel 1 exit /b 1
    >> "%LD_RESP%" echo "%OBJ_DIR_FS%/%%F.o"
)
rem --- strict gate: data/intro/ files are Nintendo-derived extracted assets ---
if defined REQUIRE_GENERATED_ASSETS (
    for %%F in (%C_DATA_INTRO%) do (
        call :check_generated "%ROOT%\data\intro\%%F.c"
    )
)
for %%F in (%C_DATA_INTRO%) do (
    echo [2a/4] Compiling data/intro/%%F.c...
    "%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src" -I "%ROOT%\src\state" -I "%ROOT%\src\core" -I "%ROOT%\src\abi" -I "%ROOT%\src\frontend" -I "%ROOT%\src\frontend\intro" -I "%ROOT%\src\frontend\fs" -I "%ROOT%\src\game\enemies" -I "%ROOT%\src\game\combat" -I "%ROOT%\src\game\room" -I "%ROOT%\src\game\cave" -I "%ROOT%\src\game\hud" -I "%ROOT%\src\game\items" -I "%ROOT%\src\game\world" -I "%ROOT%\data\intro" -I "%ROOT%\data\fs" -I "%ROOT%\sgdk\inc" -c "%ROOT%\data\intro\%%F.c" -o "%C_OBJ_DIR%\%%F.o"
    if errorlevel 1 exit /b 1
    >> "%LD_RESP%" echo "%OBJ_DIR_FS%/%%F.o"
)
rem --- strict gate: data/fs/ files are Nintendo-derived extracted assets ---
if defined REQUIRE_GENERATED_ASSETS (
    for %%F in (%C_DATA_FS%) do (
        call :check_generated "%ROOT%\data\fs\%%F.c"
    )
)
for %%F in (%C_DATA_FS%) do (
    echo [2a/4] Compiling data/fs/%%F.c...
    "%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src" -I "%ROOT%\src\state" -I "%ROOT%\src\core" -I "%ROOT%\src\abi" -I "%ROOT%\src\frontend" -I "%ROOT%\src\frontend\intro" -I "%ROOT%\src\frontend\fs" -I "%ROOT%\src\game\enemies" -I "%ROOT%\src\game\combat" -I "%ROOT%\src\game\room" -I "%ROOT%\src\game\cave" -I "%ROOT%\src\game\hud" -I "%ROOT%\src\game\items" -I "%ROOT%\src\game\world" -I "%ROOT%\data\intro" -I "%ROOT%\data\fs" -I "%ROOT%\sgdk\inc" -c "%ROOT%\data\fs\%%F.c" -o "%C_OBJ_DIR%\%%F.o"
    if errorlevel 1 exit /b 1
    >> "%LD_RESP%" echo "%OBJ_DIR_FS%/%%F.o"
)
rem --- strict gate: data/rooms/ files are Nintendo-derived extracted assets ---
if defined REQUIRE_GENERATED_ASSETS (
    for %%F in (%C_DATA_ROOMS%) do (
        call :check_generated "%ROOT%\data\rooms\%%F.c"
    )
)
for %%F in (%C_DATA_ROOMS%) do (
    echo [2a/4] Compiling data/rooms/%%F.c...
    "%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -c "%ROOT%\data\rooms\%%F.c" -o "%C_OBJ_DIR%\%%F.o"
    if errorlevel 1 exit /b 1
    >> "%LD_RESP%" echo "%OBJ_DIR_FS%/%%F.o"
)
rem --- strict gate: data/chr/ files are Nintendo-derived CHR assets ---
if defined REQUIRE_GENERATED_ASSETS (
    for %%F in (%C_DATA_CHR%) do (
        call :check_generated "%ROOT%\data\chr\%%F.c"
    )
)
for %%F in (%C_DATA_CHR%) do (
    echo [2a/4] Compiling data/chr/%%F.c...
    "%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -c "%ROOT%\data\chr\%%F.c" -o "%C_OBJ_DIR%\%%F.o"
    if errorlevel 1 exit /b 1
    >> "%LD_RESP%" echo "%OBJ_DIR_FS%/%%F.o"
)
rem --- strict gate: data/misc/ files are Nintendo-derived palette/misc assets ---
if defined REQUIRE_GENERATED_ASSETS (
    for %%F in (%C_DATA_MISC%) do (
        call :check_generated "%ROOT%\data\misc\%%F.c"
    )
)
for %%F in (%C_DATA_MISC%) do (
    echo [2a/4] Compiling data/misc/%%F.c...
    "%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -c "%ROOT%\data\misc\%%F.c" -o "%C_OBJ_DIR%\%%F.o"
    if errorlevel 1 exit /b 1
    >> "%LD_RESP%" echo "%OBJ_DIR_FS%/%%F.o"
)

rem --- strict gate: abort if any Nintendo-derived file failed manifest check ---
if defined GATE_FAIL (
    echo.
    echo STRICT GATE FAIL: one or more Nintendo-derived source files are not covered
    echo by the generated manifest at GENERATED_ASSET_ROOT.  Run the Phase 1
    echo extractors first, or unset REQUIRE_GENERATED_ASSETS for soft-warning mode.
    echo See docs/audit/strict_build_gate.md for guidance.
    exit /b 1
)

echo [2/4] Assembling genesis_shell.asm -^> ELF object...
pushd "%ROOT%\src" >nul
"%VASM%" -Felf -m68000 -maxerrors=5000 -L "%OUT_LST%" -o "%ELF_OBJ%" genesis_shell.asm
if errorlevel 1 (
    popd >nul
    exit /b 1
)
popd >nul

echo [3/4] Linking ELF -^> Title.elf...
"%M68K_LD%" -T "%LD_SCRIPT%" -o "%ELF_OUT%" "%ELF_OBJ%" @"%LD_RESP%" -L "%ROOT%\sgdk\lib" -lmd -lgcc
if errorlevel 1 exit /b 1

echo [gate] verifying gen/ forwarders ...
"%PYTHON%" "%ROOT%\tools\emit_gen_wrappers.py" --check
if errorlevel 1 (
    echo [gate] FAIL: gen/ forwarders drift from manifest
    exit /b 1
)
echo [gate] OK

echo [4/4] objcopy -^> raw binary, fix checksum...
"%M68K_OBJCOPY%" -O binary "%ELF_OUT%" "%RAW_ROM%"
if errorlevel 1 exit /b 1

"%PYTHON%" "%ROOT%\tools\fix_checksum.py" "%RAW_ROM%" "%OUT_ROM%"
if errorlevel 1 exit /b 1
if exist "%RAW_ROM%" del "%RAW_ROM%" >nul 2>nul

rem ---------------------------------------------------------------------------
rem [4] Archive — incremental ZeldaPHASE.VERSION build
rem
rem   PHASE   matches the active milestone number (T-number) — e.g. 37 while
rem           T37 sword pickup is the in-progress blocker, 38 when T38 enemy
rem           AI opens, and so on. Edit build_phase.txt to bump. When phase
rem           bumps, reset build_counter.txt to 0 so VERSION starts from 1
rem           within each phase.
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

rem Read current phase (default matches the active T-milestone; bump via build_phase.txt)
set "PHASE=37"
if exist "%PHASE_FILE%" set /p PHASE=<"%PHASE_FILE%"

rem Increment build number
set /a BUILD_NUM=%BUILD_NUM%+1

rem Archive ROM and listing via Python (reliable on all launch contexts)
set "TAG=Zelda%PHASE%.%BUILD_NUM%"
"%PYTHON%" -c "import shutil, sys; src_rom=sys.argv[1]; src_lst=sys.argv[2]; dst=sys.argv[3]; ctr=sys.argv[4]; shutil.copy2(src_rom, dst+'.md'); shutil.copy2(src_lst, dst+'.lst'); open(ctr,'w').write(sys.argv[5]); print('Archived as: '+dst.split('\\')[-1])" "%OUT_ROM%" "%OUT_LST%" "%ARCHIVE_DIR%\%TAG%" "%COUNTER_FILE%" "%BUILD_NUM%"
if errorlevel 1 echo WARNING: archive step failed (non-fatal)

rem ---------------------------------------------------------------------------
rem [S0] Warning-only legacy symbol lint
rem
rem Runs after the ROM is produced and archived but before any post-build
rem probes that may exit non-zero (e.g. phase-sequence probe). Always exits
rem zero — never fails the build at S0. Spec Section 8.1 graduates the
rem invariant to fail at S1.
rem ---------------------------------------------------------------------------
"%PYTHON%" "%ROOT%\tools\probes\lint_legacy_symbols.py"

rem ---------------------------------------------------------------------------
rem [5] Phase-sequence probe (Layer 1 test)
rem
rem Boots the ROM headlessly, samples phase bytes every 60 frames for 4000
rem frames, asserts the expected phase loop. Skipped if BizHawk not present
rem locally. Failure here means the native intro phase machine regressed.
rem
rem BizHawk must be launched from its own directory (paths with spaces require
rem the copy-and-launch pattern from the bizhawkScript skill).
rem ---------------------------------------------------------------------------
set "BIZHAWK_EXE="
set "BIZHAWK_DIR="
if exist "C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe" (
    set "BIZHAWK_EXE=C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe"
    set "BIZHAWK_DIR=C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64"
)
if "%BIZHAWK_EXE%"=="" if exist "C:\BizHawk\EmuHawk.exe" (
    set "BIZHAWK_EXE=C:\BizHawk\EmuHawk.exe"
    set "BIZHAWK_DIR=C:\BizHawk"
)
if "%BIZHAWK_EXE%"=="" if exist "%LOCALAPPDATA%\BizHawk\EmuHawk.exe" (
    set "BIZHAWK_EXE=%LOCALAPPDATA%\BizHawk\EmuHawk.exe"
    set "BIZHAWK_DIR=%LOCALAPPDATA%\BizHawk"
)
if "%BIZHAWK_EXE%"=="" if exist "%USERPROFILE%\BizHawk\EmuHawk.exe" (
    set "BIZHAWK_EXE=%USERPROFILE%\BizHawk\EmuHawk.exe"
    set "BIZHAWK_DIR=%USERPROFILE%\BizHawk"
)

if "%BIZHAWK_EXE%"=="" (
    echo [5/5] BizHawk not found - skipping intro phase probe
) else (
    echo [5/5] Running phase-sequence probe...
    del /q "%ROOT%\tools\intro_test\out\phase_sequence.csv" 2>nul
    del /q "%ROOT%\tools\intro_test\out\phase_sequence.done" 2>nul
    rem Copy script and ROM into BizHawk dir (path-with-spaces workaround).
    copy /y "%ROOT%\tools\intro_test\probe_phase_sequence.lua" "%BIZHAWK_DIR%\probe_phase_sequence.lua" >nul 2>nul
    copy /y "%OUT_ROM%" "%BIZHAWK_DIR%\Title.md" >nul 2>nul
    rem Launch BizHawk with array-style args via PowerShell; set env var so
    rem the Lua script can resolve the out/ path back to the repo.
    powershell -Command "& { $env:CODEX_BIZHAWK_ROOT='%ROOT%'; Start-Process -Wait -FilePath '%BIZHAWK_EXE%' -ArgumentList @('--lua=probe_phase_sequence.lua','Title.md') -WorkingDirectory '%BIZHAWK_DIR%' }"
    if errorlevel 1 (
        echo [5/5] WARNING: BizHawk exited non-zero - probe may be incomplete
    )
    "%PYTHON%" "%ROOT%\tools\intro_test\check_probe_sequence.py"
    if errorlevel 1 (
        echo [5/5] FAIL: probe sequence assertion failed
        exit /b 1
    )
    echo [5/5] OK: phase probe passed
)

echo.
echo Build complete: %OUT_ROM%
echo Listing:        %OUT_LST%

rem ---------------------------------------------------------------------------
rem whatif.* alias REMOVED 2026-05-02 (user hard rule). build.bat must NEVER
rem emit whatif.md, whatif.lst, or whatif.elf again. Probes / launchers that
rem still reference whatif.* must migrate to Title.* before they can run.
rem ---------------------------------------------------------------------------

rem ---------------------------------------------------------------------------
rem [6] Git auto-commit — builds/ is gitignored as of debate 002 cleanup; this
rem     stage is preserved for backwards compatibility but should be a no-op.
rem ---------------------------------------------------------------------------
git -C "%ROOT%" add builds\Title.md builds\Title.lst >nul 2>nul
git -C "%ROOT%" diff --cached --quiet >nul 2>nul
if errorlevel 1 (
    git -C "%ROOT%" commit -m "build: %TAG%" --only -- builds\Title.md builds\Title.lst >nul 2>nul
    if errorlevel 1 (
        echo WARNING: git commit failed
    ) else (
        echo Committed:   %TAG%
    )
) else (
    echo No changes to commit.
)

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
