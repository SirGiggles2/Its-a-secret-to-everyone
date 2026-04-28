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
rem [2] Assemble to ELF object, link via m68k-elf-ld + genesis.ld, strip
rem     to flat binary via objcopy. Stage-2a pivot: vasm -Fbin is gone;
rem     we now have a real linker stage that C object files can be linked
rem     into (Stage 2b+). genesis_shell.asm is still the sole asm root.
rem ---------------------------------------------------------------------------
set "ELF_OBJ=%ROOT%\builds\whatif.o"
set "ELF_OUT=%ROOT%\builds\whatif.elf"
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

echo [2a.0/4] Extracting intro assets from reference data...
"%PYTHON%" "%ROOT%\tools\extract_intro_assets.py"
if errorlevel 1 exit /b 1

echo [2a.0b/4] Extracting File Select assets from live CHR-RAM dump...
"%PYTHON%" "%ROOT%\tools\extract_fs_assets.py"
if errorlevel 1 exit /b 1

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
set "C_SOURCES_PRE=core_runtime c_move_object c_wanderer object_runtime enemy_runtime enemy_common_runtime enemy_walker_runtime enemy_wanderer_runtime enemy_block_runtime enemy_wallmaster_runtime enemy_flyer_runtime enemy_boss_runtime enemy_gleeok_runtime enemy_dodongo_runtime enemy_manhandla_runtime enemy_lamnola_runtime enemy_projectile_runtime uw_person_runtime cave_runtime hud_runtime item_runtime weapon_runtime world_runtime sprite_runtime combat_runtime collision_runtime link_collision_runtime progress_runtime targeting_runtime trap_runtime room_runtime room_load_runtime room_mode_runtime room_transfer_runtime room_player_runtime room_object_runtime"
set "C_FRONTEND=frontend_runtime"
set "C_SOURCES_MID=save_menu_runtime"
set "C_FRONTEND_INTRO=intro_common intro_story intro_handoff intro_main intro_phase intro_title"
set "C_FRONTEND_FS=fs_main fs_render fs_phase fs_input fs_handoff"
set "C_GEN_SOURCES=z_01 z_02 z_03 z_04 z_05 z_06 z_07 intro_font_chr intro_art_chr intro_palette intro_story_tilemap intro_restore_chr intro_restore_palette intro_title_bg_chr intro_title_sprite_chr intro_title_palette intro_title_tilemap intro_title_fade intro_title_glow intro_common_bg_chr intro_sprite_chr intro_misc_chr intro_punct_chr intro_blink_chr intro_combined_palette intro_treasures_tilemap fs_palette fs_static_tilemap fs_static_attr fs_link_sprite_chr fs_heart_cursor_chr fs_bg_chr_full"
rem Write object list to response file during compile loop. CMD line-length
rem limit (~8KB) breaks once %C_OBJS% accumulates too many fs_*/intro_*
rem paths. Convert backslashes to forward slashes in the response file —
rem ld treats backslashes as escape sequences when reading @file args.
set "LD_RESP=%C_OBJ_DIR%\link_objs.rsp"
set "OBJ_DIR_FS=%C_OBJ_DIR:\=/%"
if exist "%LD_RESP%" del "%LD_RESP%"
echo [2a/4] Compiling core/c_runtime.c...
"%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src" -I "%ROOT%\src\state" -I "%ROOT%\src\core" -I "%ROOT%\src\abi" -I "%ROOT%\src\frontend" -I "%ROOT%\src\frontend\intro" -I "%ROOT%\src\frontend\fs" -c "%ROOT%\src\core\c_runtime.c" -o "%C_OBJ_DIR%\c_runtime.o"
if errorlevel 1 exit /b 1
>> "%LD_RESP%" echo "%OBJ_DIR_FS%/c_runtime.o"
for %%F in (%C_SOURCES_PRE%) do (
    echo [2a/4] Compiling %%F.c...
    "%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src" -I "%ROOT%\src\state" -I "%ROOT%\src\core" -I "%ROOT%\src\abi" -I "%ROOT%\src\frontend" -I "%ROOT%\src\frontend\intro" -I "%ROOT%\src\frontend\fs" -c "%ROOT%\src\%%F.c" -o "%C_OBJ_DIR%\%%F.o"
    if errorlevel 1 exit /b 1
    >> "%LD_RESP%" echo "%OBJ_DIR_FS%/%%F.o"
)
for %%F in (%C_FRONTEND%) do (
    echo [2a/4] Compiling frontend/%%F.c...
    "%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src" -I "%ROOT%\src\state" -I "%ROOT%\src\core" -I "%ROOT%\src\abi" -I "%ROOT%\src\frontend" -I "%ROOT%\src\frontend\intro" -I "%ROOT%\src\frontend\fs" -c "%ROOT%\src\frontend\%%F.c" -o "%C_OBJ_DIR%\%%F.o"
    if errorlevel 1 exit /b 1
    >> "%LD_RESP%" echo "%OBJ_DIR_FS%/%%F.o"
)
for %%F in (%C_SOURCES_MID%) do (
    echo [2a/4] Compiling %%F.c...
    "%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src" -I "%ROOT%\src\state" -I "%ROOT%\src\core" -I "%ROOT%\src\abi" -I "%ROOT%\src\frontend" -I "%ROOT%\src\frontend\intro" -I "%ROOT%\src\frontend\fs" -c "%ROOT%\src\%%F.c" -o "%C_OBJ_DIR%\%%F.o"
    if errorlevel 1 exit /b 1
    >> "%LD_RESP%" echo "%OBJ_DIR_FS%/%%F.o"
)
for %%F in (%C_FRONTEND_INTRO%) do (
    echo [2a/4] Compiling frontend/intro/%%F.c...
    "%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src" -I "%ROOT%\src\state" -I "%ROOT%\src\core" -I "%ROOT%\src\abi" -I "%ROOT%\src\frontend" -I "%ROOT%\src\frontend\intro" -I "%ROOT%\src\frontend\fs" -c "%ROOT%\src\frontend\intro\%%F.c" -o "%C_OBJ_DIR%\%%F.o"
    if errorlevel 1 exit /b 1
    >> "%LD_RESP%" echo "%OBJ_DIR_FS%/%%F.o"
)
for %%F in (%C_FRONTEND_FS%) do (
    echo [2a/4] Compiling frontend/fs/%%F.c...
    "%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src" -I "%ROOT%\src\state" -I "%ROOT%\src\core" -I "%ROOT%\src\abi" -I "%ROOT%\src\frontend" -I "%ROOT%\src\frontend\intro" -I "%ROOT%\src\frontend\fs" -c "%ROOT%\src\frontend\fs\%%F.c" -o "%C_OBJ_DIR%\%%F.o"
    if errorlevel 1 exit /b 1
    >> "%LD_RESP%" echo "%OBJ_DIR_FS%/%%F.o"
)
for %%F in (%C_GEN_SOURCES%) do (
    echo [2a/4] Compiling gen/%%F.c...
    "%M68K_GCC%" -B "%M68K_BIN%\\" -m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%ROOT%\src" -I "%ROOT%\src\state" -I "%ROOT%\src\core" -I "%ROOT%\src\abi" -I "%ROOT%\src\frontend" -I "%ROOT%\src\frontend\intro" -I "%ROOT%\src\frontend\fs" -c "%ROOT%\src\gen\%%F.c" -o "%C_OBJ_DIR%\%%F.o"
    if errorlevel 1 exit /b 1
    >> "%LD_RESP%" echo "%OBJ_DIR_FS%/%%F.o"
)

echo [2/4] Assembling genesis_shell.asm -^> ELF object...
pushd "%ROOT%\src" >nul
"%VASM%" -Felf -m68000 -maxerrors=5000 -L "%OUT_LST%" -o "%ELF_OBJ%" genesis_shell.asm
if errorlevel 1 (
    popd >nul
    exit /b 1
)
popd >nul

echo [3/4] Linking ELF -^> whatif.elf...
"%M68K_LD%" -T "%LD_SCRIPT%" -o "%ELF_OUT%" "%ELF_OBJ%" @"%LD_RESP%"
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
    copy /y "%OUT_ROM%" "%BIZHAWK_DIR%\whatif.md" >nul 2>nul
    rem Launch BizHawk with array-style args via PowerShell; set env var so
    rem the Lua script can resolve the out/ path back to the repo.
    powershell -Command "& { $env:CODEX_BIZHAWK_ROOT='%ROOT%'; Start-Process -Wait -FilePath '%BIZHAWK_EXE%' -ArgumentList @('--lua=probe_phase_sequence.lua','whatif.md') -WorkingDirectory '%BIZHAWK_DIR%' }"
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
rem [6] Git auto-commit — stage build outputs and archive, commit with tag name
rem ---------------------------------------------------------------------------
git -C "%ROOT%" add builds\whatif.md builds\whatif.lst builds\archive\ >nul 2>nul
git -C "%ROOT%" diff --cached --quiet >nul 2>nul
if errorlevel 1 (
    git -C "%ROOT%" commit -m "build: %TAG%" --only -- builds\whatif.md builds\whatif.lst builds\archive\ >nul 2>nul
    if errorlevel 1 (
        echo WARNING: git commit failed
    ) else (
        echo Committed:   %TAG%
    )
) else (
    echo No changes to commit.
)

exit /b 0
