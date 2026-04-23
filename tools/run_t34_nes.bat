@echo off
setlocal EnableExtensions
for %%I in ("%~dp0..") do set "ROOT=%%~fI"

powershell -ExecutionPolicy Bypass -File "%ROOT%\tools\launch_bizhawk.ps1" -RomPath "Legend of Zelda, The (USA).nes" -LuaPath "tools\bizhawk_t34_movement_nes_capture.lua" -Core "NesHawk" -Wait
exit /b %ERRORLEVEL%
