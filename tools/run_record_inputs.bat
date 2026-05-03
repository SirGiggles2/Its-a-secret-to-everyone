@echo off
setlocal EnableExtensions
for %%I in ("%~dp0..") do set "ROOT=%%~fI"

powershell -ExecutionPolicy Bypass -File "%ROOT%\tools\launch_bizhawk.ps1" -RomPath "builds\Title.md" -LuaPath "tools\bizhawk_record_inputs.lua" -Wait
exit /b %ERRORLEVEL%
