@echo off
setlocal EnableExtensions
for %%I in ("%~dp0..") do set "ROOT=%%~fI"

powershell -ExecutionPolicy Bypass -File "%ROOT%\tools\launch_bizhawk.ps1" -RomPath "builds\whatif.md" -LuaPath "tools\bizhawk_t34_movement_gen_capture.lua" -Wait
exit /b %ERRORLEVEL%
