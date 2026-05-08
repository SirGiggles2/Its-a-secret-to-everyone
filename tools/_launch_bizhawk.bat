@echo off
set "EMU=C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe"
set "ROM=C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\builds\Debug.md"

pushd "C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64"
start "" "%EMU%" "%ROM%"
popd
