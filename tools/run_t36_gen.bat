@echo off
set "ROOT=C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.claude\worktrees\angry-dijkstra"
set "EMU=C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe"
set "ROM=%ROOT%\builds\Title.md"
set "LUA=%ROOT%\tools\bizhawk_t36_cave_gen_capture.lua"
set "CODEX_BIZHAWK_ROOT=%ROOT%"
cd /d "C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64"
rem Wipe Genesis SaveRAM so game boots fresh (no auto-load of existing saves).
del /q "Genesis\SaveRAM\Title.SaveRAM" 2>nul
del /q "Genesis\SaveRAM\Title.SaveRAM.bak" 2>nul
"%EMU%" "--lua=%LUA%" "%ROM%"
exit /b %ERRORLEVEL%
