@echo off
rem tools/probes/abi_probe.build.bat — compile the ABI probe and emit a listing.
rem Mirrors the flags build.bat uses for src/*.c (specifically -ffixed-a4).
setlocal EnableExtensions

for %%I in ("%~dp0..\..") do set "ROOT=%%~fI"

rem Resolve toolchain via the same priority list build.bat uses.
set "M68K_BIN="
if exist "%ROOT%\build\toolchain\sgdk_bin\bin\gcc.exe"                  set "M68K_BIN=%ROOT%\build\toolchain\sgdk_bin\bin"
if "%M68K_BIN%"=="" if exist "%ROOT%\..\build\toolchain\sgdk_bin\bin\gcc.exe"           set "M68K_BIN=%ROOT%\..\build\toolchain\sgdk_bin\bin"
if "%M68K_BIN%"=="" if exist "%ROOT%\..\..\build\toolchain\sgdk_bin\bin\gcc.exe"        set "M68K_BIN=%ROOT%\..\..\build\toolchain\sgdk_bin\bin"
if "%M68K_BIN%"=="" if exist "%ROOT%\..\NES-TO-SEGA-GENESIS\build\toolchain\sgdk_bin\bin\gcc.exe"  set "M68K_BIN=%ROOT%\..\NES-TO-SEGA-GENESIS\build\toolchain\sgdk_bin\bin"
if "%M68K_BIN%"=="" if exist "%ROOT%\..\..\NES-TO-SEGA-GENESIS\build\toolchain\sgdk_bin\bin\gcc.exe" set "M68K_BIN=%ROOT%\..\..\NES-TO-SEGA-GENESIS\build\toolchain\sgdk_bin\bin"

if "%M68K_BIN%"=="" (
    echo ERROR: m68k-elf toolchain not found.
    exit /b 1
)

set "GCC=%M68K_BIN%\gcc.exe"
set "OBJDUMP=%M68K_BIN%\m68k-elf-objdump.exe"
if not exist "%OBJDUMP%" set "OBJDUMP=%M68K_BIN%\objdump.exe"
set "OUT=%ROOT%\builds\abi_probe"

if not exist "%OUT%" mkdir "%OUT%"

echo [1/2] Compiling abi_probe.c with -S to produce assembly listing...
"%GCC%" -B "%M68K_BIN%\\" -m68000 -ffixed-a4 -O1 -S ^
    "%~dp0abi_probe.c" -o "%OUT%\abi_probe.s"
if errorlevel 1 exit /b 1

echo [2/2] Compiling abi_probe.c to .o and dumping with objdump...
"%GCC%" -B "%M68K_BIN%\\" -m68000 -ffixed-a4 -O1 -c ^
    "%~dp0abi_probe.c" -o "%OUT%\abi_probe.o"
if errorlevel 1 exit /b 1

"%OBJDUMP%" -d "%OUT%\abi_probe.o" > "%OUT%\abi_probe.disasm.txt"

echo Listing:  %OUT%\abi_probe.s
echo Disasm:   %OUT%\abi_probe.disasm.txt
exit /b 0
