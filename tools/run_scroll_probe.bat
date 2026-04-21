@echo off
set "EMU=C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe"
set "ROM=C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\builds\whatif.md"
set "LUA=C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\tools\bizhawk_scroll_probe.lua"

pushd "C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64"
start "" "%EMU%" "--lua=%LUA%" "%ROM%"
popd
