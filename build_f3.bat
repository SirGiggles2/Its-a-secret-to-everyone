@echo off
cd /d "C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY"
call "C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\build.bat" > "C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\build_f3_log.txt" 2>&1
echo BUILD_EXIT=%ERRORLEVEL% >> "C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\build_f3_log.txt"
