@echo off
set "ROOT=C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.claude\worktrees\nifty-chandrasekhar"
set "EMU=C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe"
set "ROM=%ROOT%\builds\whatif.md"
set "LUA=%ROOT%\tools\bizhawk_t34_movement_gen_capture.lua"
set "CODEX_BIZHAWK_ROOT=%ROOT%"
cd /d "C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64"
rem Wipe Genesis SaveRAM so game boots fresh (no auto-load of existing saves).
del /q "Genesis\SaveRAM\whatif.SaveRAM" 2>nul
del /q "Genesis\SaveRAM\whatif.SaveRAM.bak" 2>nul
"%EMU%" "--lua=%LUA%" "%ROM%"
exit /b %ERRORLEVEL%
