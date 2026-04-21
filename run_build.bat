@echo off
cd /d "C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY"
call build.bat >build_output.txt 2>&1
echo EXIT_CODE=%ERRORLEVEL%
