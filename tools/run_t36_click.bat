@echo off
set "ROOT=C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.claude\worktrees\angry-dijkstra"
set "EMU=C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe"
set "ROM=C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\Legend of Zelda, The (USA).nes"
set "LUA=%ROOT%\tools\bizhawk_t36_click_probe.lua"
set "CODEX_BIZHAWK_ROOT=%ROOT%"
cd /d "C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64"
del /q "NES\SaveRAM\Legend of Zelda, The.SaveRAM" 2>nul
"%EMU%" "--lua=%LUA%" "%ROM%"
exit /b %ERRORLEVEL%
