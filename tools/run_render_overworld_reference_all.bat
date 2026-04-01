@echo off
setlocal EnableExtensions

for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "PYTHON_CMD=python"
if defined PYTHON set "PYTHON_CMD=%PYTHON%"

%PYTHON_CMD% "%ROOT%\tools\render_overworld_reference_all.py"
exit /b %ERRORLEVEL%
