@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem =============================================================================
rem run_all_probes.bat — honest regression runner.
rem
rem Two gate types:
rem   1. Single-Lua probe: one Lua script writes a report; scanner reads the
rem      final ": ALL PASS" / ": FAIL" line.
rem   2. Parity gate: NES-side capture Lua + Gen-side capture Lua + Python
rem      comparator produces a report with the same ": ALL PASS" / ": FAIL"
rem      convention.
rem
rem Absorbs all parity gates previously in run_all_gates.bat (T34 movement,
rem T35 scroll, Room $77, Room $76). run_all_gates.bat remains as a thin
rem wrapper that builds first then calls this.
rem
rem Known-red gates kept in the suite (track regressions against them, do not
rem hide): T28 title input, T29 file select, Room $76 transition settle.
rem
rem Required env (for parity gates only):
rem   NES_ROM  — path to NES Zelda ROM (default: %ROOT%\reference\zelda.nes)
rem              Parity gates SKIP gracefully if absent; single-Lua probes
rem              are unaffected.
rem =============================================================================

for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "EMU=C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe"
set "BIZHAWK_DIR=C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64"
set "ROM=%ROOT%\builds\whatif.md"
set "REPORT_DIR=%ROOT%\builds\reports"
set "SUMMARY=%REPORT_DIR%\regression_summary.txt"

if "%NES_ROM%"=="" set "NES_ROM=%ROOT%\reference\zelda.nes"

set "PYTHON="
if exist "%LOCALAPPDATA%\Python\bin\python.exe"                           set "PYTHON=%LOCALAPPDATA%\Python\bin\python.exe"
if "%PYTHON%"=="" if exist "%LOCALAPPDATA%\Programs\Python\Python313\python.exe" set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python313\python.exe"
if "%PYTHON%"=="" where python.exe >nul 2>nul && set "PYTHON=python.exe"

if not exist "%EMU%" (
    echo ERROR: BizHawk not found: %EMU%
    exit /b 1
)
if not exist "%ROM%" (
    echo ERROR: ROM not found: %ROM%
    exit /b 1
)
if not exist "%REPORT_DIR%" mkdir "%REPORT_DIR%"

echo WHAT IF Regression Suite > "%SUMMARY%"
echo Run: %date% %time% >> "%SUMMARY%"
echo ROM:     %ROM% >> "%SUMMARY%"
echo NES_ROM: %NES_ROM% >> "%SUMMARY%"
echo ================================================================= >> "%SUMMARY%"

set "PASS_COUNT=0"
set "FAIL_COUNT=0"
set "ERROR_COUNT=0"

rem ---------------- Single-Lua probes ----------------
rem Foundation (existing)
call :run_probe "Boot T7/T8/T9/T10/T11"  "bizhawk_boot_probe.lua"          "bizhawk_boot_probe.txt"
call :run_probe "PPU Latch T12"          "bizhawk_ppu_latch_probe.lua"     "bizhawk_ppu_latch_probe.txt"
call :run_probe "PPU Increment T13"      "bizhawk_ppu_increment_probe.lua" "bizhawk_ppu_increment_probe.txt"
call :run_probe "PPU Ctrl T14"           "bizhawk_ppu_ctrl_probe.lua"      "bizhawk_ppu_ctrl_probe.txt"
call :run_probe "Scroll Latch T15"       "bizhawk_scroll_latch_probe.lua"  "bizhawk_scroll_latch_probe.txt"
call :run_probe "MMC1 State T11b"        "bizhawk_mmc1_probe.lua"          "bizhawk_mmc1_probe.txt"
call :run_probe "Phase 1/2/6 Verify"     "bizhawk_phase1_verify.lua"       "bizhawk_phase1_verify.txt"

rem Graphics pipeline (newly added — previously orphaned)
call :run_probe "CHR Upload T16/T17a"    "bizhawk_chr_upload_probe.lua"    "bizhawk_chr_upload_probe.txt"
call :run_probe "Nametable T18"          "bizhawk_nametable_probe.lua"     "bizhawk_nametable_probe.txt"
call :run_probe "Palette T19"            "bizhawk_palette_probe.lua"       "bizhawk_palette_probe.txt"
call :run_probe "Attribute T20"          "bizhawk_attribute_probe.lua"     "bizhawk_attribute_probe.txt"
call :run_probe "Title Parity T22"       "bizhawk_t22_title_ram_probe.lua" "bizhawk_t22_title_ram_probe.txt"

rem Sprites / input (newly added)
call :run_probe "OAM DMA T23"            "bizhawk_t23_oam_dma_probe.lua"      "bizhawk_t23_oam_dma_probe.txt"
call :run_probe "Sprite Decode T24"      "bizhawk_t24_sprite_decode_probe.lua"   "bizhawk_t24_sprite_decode_probe.txt"
call :run_probe "Sprite Palette T25"     "bizhawk_t25_sprite_palette_probe.lua"  "bizhawk_t25_sprite_palette_probe.txt"
call :run_probe "Title Sprites T26"      "bizhawk_t26_title_sprites_probe.lua"   "bizhawk_t26_title_sprites_probe.txt"
call :run_probe "Controller T27"         "bizhawk_t27_controller_probe.lua"      "bizhawk_t27_controller_probe.txt"
call :run_probe "Title Input T28"        "bizhawk_t28_title_input_probe.lua"     "bizhawk_t28_title_input_probe.txt"
call :run_probe "File Select T29"        "bizhawk_t29_file_select_probe.lua"     "bizhawk_t29_file_select_probe.txt"

rem Gameplay (newly added)
call :run_probe "Room Load T30/T31/T32"  "bizhawk_t30_room_load_probe.lua"       "bizhawk_t30_room_load_probe.txt"
call :run_probe "Link Spawn T33"         "bizhawk_t33_link_spawn_probe.lua"      "bizhawk_t33_link_spawn_probe.txt"

rem ---------------- Parity gates (absorbed from run_all_gates.bat) ----------------
call :run_parity "T34 Movement" ^
    "bizhawk_t34_movement_nes_capture.lua" ^
    "bizhawk_t34_movement_gen_capture.lua" ^
    "compare_t34_movement_parity.py" ^
    "t34_movement_parity_report.txt"

call :run_parity "T35 Scroll" ^
    "bizhawk_t35_scroll_nes_capture.lua" ^
    "bizhawk_t35_scroll_gen_capture.lua" ^
    "compare_t35_scroll_parity.py" ^
    "bizhawk_t35_scroll_parity_report.txt"

rem Room $77 and Room $76 share a comparator and capture script; the room id
rem is selected via CODEX_TARGET_ROOM_ID and a --room-id argument.
call :run_parity_room "Room $77" "0x77" "room77_parity_report.txt"
call :run_parity_room "Room $76" "0x76" "room76_parity_report.txt"

:summary
echo. >> "%SUMMARY%"
echo ================================================================= >> "%SUMMARY%"
echo PASS: %PASS_COUNT%  FAIL: %FAIL_COUNT%  ERROR/SKIP: %ERROR_COUNT% >> "%SUMMARY%"

echo.
echo =================================================================
echo Regression Summary
echo =================================================================
type "%SUMMARY%"

if %FAIL_COUNT% gtr 0 exit /b 1
if %ERROR_COUNT% gtr 0 exit /b 2
exit /b 0

rem ==========================================================================
rem Subroutines
rem ==========================================================================

:run_probe
  rem %~1 = name, %~2 = lua filename, %~3 = report filename
  set "PNAME=%~1"
  set "PLUA=%ROOT%\tools\%~2"
  set "PREPORT=%REPORT_DIR%\%~3"

  if not exist "!PLUA!" (
      echo [SKIP] !PNAME! -- script not found: %~2
      echo [SKIP] !PNAME! -- script not found >> "%SUMMARY%"
      set /a ERROR_COUNT+=1
      exit /b 0
  )

  echo Running !PNAME! ...
  if exist "!PREPORT!" del /f /q "!PREPORT!" >nul 2>nul

  pushd "%BIZHAWK_DIR%" >nul
  start "" /wait "%EMU%" "--lua=!PLUA!" "%ROM%"
  popd >nul

  call :scan_report "!PNAME!" "!PREPORT!"
exit /b 0

:run_parity
  rem %~1 = name, %~2 = nes lua, %~3 = gen lua, %~4 = comparator py, %~5 = report
  set "GNAME=%~1"
  set "NES_LUA=%ROOT%\tools\%~2"
  set "GEN_LUA=%ROOT%\tools\%~3"
  set "CMP_PY=%ROOT%\tools\%~4"
  set "PREPORT=%REPORT_DIR%\%~5"

  if "%PYTHON%"=="" (
      echo [SKIP] !GNAME! -- Python not found
      echo [SKIP] !GNAME! -- Python not found >> "%SUMMARY%"
      set /a ERROR_COUNT+=1
      exit /b 0
  )
  if not exist "%NES_ROM%" (
      echo [SKIP] !GNAME! -- NES_ROM missing: %NES_ROM%
      echo [SKIP] !GNAME! -- NES_ROM missing >> "%SUMMARY%"
      set /a ERROR_COUNT+=1
      exit /b 0
  )
  if not exist "!NES_LUA!" (
      echo [SKIP] !GNAME! -- NES capture script not found: %~2
      echo [SKIP] !GNAME! -- capture missing >> "%SUMMARY%"
      set /a ERROR_COUNT+=1
      exit /b 0
  )
  if not exist "!GEN_LUA!" (
      echo [SKIP] !GNAME! -- Gen capture script not found: %~3
      echo [SKIP] !GNAME! -- capture missing >> "%SUMMARY%"
      set /a ERROR_COUNT+=1
      exit /b 0
  )
  if not exist "!CMP_PY!" (
      echo [SKIP] !GNAME! -- comparator not found: %~4
      echo [SKIP] !GNAME! -- comparator missing >> "%SUMMARY%"
      set /a ERROR_COUNT+=1
      exit /b 0
  )

  echo Running !GNAME! (parity) ...
  if exist "!PREPORT!" del /f /q "!PREPORT!" >nul 2>nul

  pushd "%BIZHAWK_DIR%" >nul
  start "" /wait "%EMU%" "--lua=!NES_LUA!" "%NES_ROM%"
  start "" /wait "%EMU%" "--lua=!GEN_LUA!" "%ROM%"
  popd >nul

  "%PYTHON%" "!CMP_PY!" >nul 2>nul

  call :scan_report "!GNAME!" "!PREPORT!"
exit /b 0

:run_parity_room
  rem %~1 = name, %~2 = room id hex (0x77), %~3 = report filename
  set "GNAME=%~1"
  set "ROOM_ID=%~2"
  set "PREPORT=%REPORT_DIR%\%~3"
  set "NES_LUA=%ROOT%\tools\bizhawk_room77_nes_capture.lua"
  set "GEN_LUA=%ROOT%\tools\bizhawk_room77_gen_capture.lua"
  set "CMP_PY=%ROOT%\tools\compare_room77_parity.py"

  if "%PYTHON%"=="" (
      echo [SKIP] !GNAME! -- Python not found
      echo [SKIP] !GNAME! -- Python not found >> "%SUMMARY%"
      set /a ERROR_COUNT+=1
      exit /b 0
  )
  if not exist "%NES_ROM%" (
      echo [SKIP] !GNAME! -- NES_ROM missing: %NES_ROM%
      echo [SKIP] !GNAME! -- NES_ROM missing >> "%SUMMARY%"
      set /a ERROR_COUNT+=1
      exit /b 0
  )
  if not exist "!NES_LUA!" (
      echo [SKIP] !GNAME! -- capture script not found
      echo [SKIP] !GNAME! -- capture missing >> "%SUMMARY%"
      set /a ERROR_COUNT+=1
      exit /b 0
  )

  echo Running !GNAME! (parity, room !ROOM_ID!) ...
  if exist "!PREPORT!" del /f /q "!PREPORT!" >nul 2>nul

  set "CODEX_TARGET_ROOM_ID=!ROOM_ID!"
  pushd "%BIZHAWK_DIR%" >nul
  start "" /wait "%EMU%" "--lua=!NES_LUA!" "%NES_ROM%"
  start "" /wait "%EMU%" "--lua=!GEN_LUA!" "%ROM%"
  popd >nul

  "%PYTHON%" "!CMP_PY!" --room-id !ROOM_ID! >nul 2>nul
  set "CODEX_TARGET_ROOM_ID="

  call :scan_report "!GNAME!" "!PREPORT!"
exit /b 0

:scan_report
  rem %~1 = gate name, %~2 = report file
  if not exist "%~2" (
      echo [ERROR] %~1 -- report not generated
      echo [ERROR] %~1 -- report not generated >> "%SUMMARY%"
      set /a ERROR_COUNT+=1
      exit /b 0
  )
  set "RESULT=UNKNOWN"
  for /f "delims=" %%L in (%~2) do (
      set "LINE=%%L"
      echo !LINE! | findstr /i "ALL PASS" >nul && set "RESULT=PASS"
      echo !LINE! | findstr /i ": FAIL" >nul && set "RESULT=FAIL"
  )
  if "!RESULT!"=="PASS" (
      echo [PASS] %~1
      echo [PASS] %~1 >> "%SUMMARY%"
      set /a PASS_COUNT+=1
  ) else (
      echo [FAIL] %~1
      echo [FAIL] %~1 >> "%SUMMARY%"
      set /a FAIL_COUNT+=1
  )
exit /b 0
