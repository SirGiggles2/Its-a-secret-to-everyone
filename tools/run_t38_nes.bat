@echo off
set "ROOT=C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY"
set "EMU=C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe"
set "ROM=%ROOT%\Legend of Zelda, The (USA).nes"
set "LUA=%ROOT%\tools\bizhawk_t38_enemy_nes_capture.lua"
set "CODEX_BIZHAWK_ROOT=%ROOT%"
cd /d "C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64"
del /q "NES\SaveRAM\Legend of Zelda, The.SaveRAM" 2>nul
del /q "NES\SaveRAM\Legend of Zelda, The.SaveRAM.bak" 2>nul
del /q "NES\State\Legend of Zelda, The.quickerNES.QuickSave1.State" 2>nul
"%EMU%" "--lua=%LUA%" "%ROM%"
exit /b %ERRORLEVEL%
