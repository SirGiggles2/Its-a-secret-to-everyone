@echo off
setlocal
set "ROOT=%~dp0..\..\"
for %%I in ("%ROOT%.") do set "ROOT=%%~fI"
set "EMU=C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe"
set "ROM=%ROOT%\tools\midi_demo\out\midi_demo.md"
set "LUA=%ROOT%\tools\midi_demo\probe.lua"
set "MIDI_DEMO_OUT=%ROOT%\tools\midi_demo\out"
set "CODEX_BIZHAWK_ROOT=C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64"
cd /d "C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64"
"%EMU%" "--lua=%LUA%" "%ROM%"
exit /b %ERRORLEVEL%
