@echo off
setlocal EnableExtensions

for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "TOOLS=%ROOT%\tools"
set "ROM=%ROOT%\builds\whatif.md"
set "FAIL=0"

call :run "Overworld All-Rooms Reference" "%TOOLS%\run_render_overworld_reference_all.bat"
call :run "Overworld Full Runtime Fidelity" "%TOOLS%\run_bizhawk_phase3_overworld_full_probe.bat"
call :run "Cave Probe Room77" "%TOOLS%\run_bizhawk_phase3_cave_probe.bat"
call :run "Cave Probe Room76" "%TOOLS%\run_bizhawk_phase3_cave_room76_probe.bat"
call :run "Cave Probe Room67" "%TOOLS%\run_bizhawk_phase3_cave_room67_probe.bat"
call :run "Cave Probe Room78" "%TOOLS%\run_bizhawk_phase3_cave_room78_probe.bat"
call :run "Cave Probe Room70" "%TOOLS%\run_bizhawk_phase3_cave_room70_probe.bat"
call :run "Cave Probe Room7C" "%TOOLS%\run_bizhawk_phase3_cave_room7C_probe.bat"
call :run "Cave Probe Room71" "%TOOLS%\run_bizhawk_phase3_cave_room71_probe.bat"
call :run "Cave Probe Room75" "%TOOLS%\run_bizhawk_phase3_cave_room75_probe.bat"
call :run "Cave Probe Room7B" "%TOOLS%\run_bizhawk_phase3_cave_room7B_probe.bat"
call :run "Dungeon Probe" "%TOOLS%\run_bizhawk_phase3_dungeon_probe.bat"
call :run "Room Probe" "%TOOLS%\run_bizhawk_phase3_room_probe.bat"
call :run "Room Fidelity Probe" "%TOOLS%\run_bizhawk_phase3_room_fidelity_probe.bat"
call :run "Navigation Probe Right" "%TOOLS%\run_bizhawk_phase3_navigation_probe.bat"
call :run "Navigation Probe Left" "%TOOLS%\run_bizhawk_phase3_left_navigation_probe.bat"
call :run "Navigation Probe Up" "%TOOLS%\run_bizhawk_phase3_up_navigation_probe.bat"
call :run "Navigation Probe Down" "%TOOLS%\run_bizhawk_phase3_down_navigation_probe.bat"

echo.
if "%FAIL%"=="0" (
    echo PHASE3 FULL PARITY: PASS
    exit /b 0
) else (
    echo PHASE3 FULL PARITY: FAIL
    exit /b 1
)

:run
echo.
set "RUN_NAME=%~1"
set "RUN_PATH=%~2"
echo [RUN] %RUN_NAME%
call "%RUN_PATH%"
if errorlevel 1 (
    echo [FAIL] %RUN_NAME%
    set "FAIL=1"
) else (
    echo [PASS] %RUN_NAME%
)
exit /b 0
