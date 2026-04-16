@echo off
set "ROOT=C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.claude\worktrees\angry-dijkstra"
set "EMU=C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe"
set "ROM=%ROOT%\builds\whatif.md"
set "LUA=%ROOT%\tools\bizhawk_boot_probe.lua"
set "CODEX_BIZHAWK_ROOT=%ROOT%"
cd /d "C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64"
"%EMU%" "--lua=%LUA%" "%ROM%"
exit /b %ERRORLEVEL%
