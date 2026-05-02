@echo off
setlocal EnableExtensions

rem ---------------------------------------------------------------------------
rem RoomRom atlas Phase 0 capability probe driver.
rem
rem Compiles tools/phase0_static_assert_probe.c against the SGDK m68k gcc
rem toolchain. If C11 _Static_assert compiles, the atlas pipeline uses the
rem _Static_assert path in src/atlas/atlas_static_assert.h. If not, fall
rem back to the C89 typedef-array trick.
rem
rem Run after a toolchain change (sgdk version bump, new host) or as a
rem manual sanity check. Not part of build.bat Step 0 (probe is a one-time
rem capability check, not a per-build gate).
rem ---------------------------------------------------------------------------

for %%I in ("%~dp0..") do set "PROJ=%%~fsI"
set "REPO=%PROJ%\.."
set "SGDK=%REPO%\sgdk"
set "TOOLBIN=%REPO%\build\toolchain\sgdk_bin\bin"
set "GCC=%TOOLBIN%\gcc.exe"
set "OUT=%PROJ%\out"

if not exist "%GCC%" (
    echo ERROR: gcc not found at %GCC%
    exit /b 1
)

if not exist "%OUT%" mkdir "%OUT%"

set "CFLAGS=-DSGDK_GCC -m68000 -Wall -Wno-main -Wno-unused-parameter -fno-builtin -ffunction-sections -fdata-sections -fms-extensions -B%TOOLBIN%\"

echo [P0] Compiling phase0_static_assert_probe.c...
"%GCC%" %CFLAGS% -c "%PROJ%\tools\phase0_static_assert_probe.c" -o "%OUT%\phase0_static_assert_probe.o"
if errorlevel 1 (
    echo.
    echo [P0] FAIL: SGDK m68k gcc does NOT support C11 _Static_assert.
    echo [P0] Edit RoomRom/src/atlas/atlas_static_assert.h to switch to the
    echo [P0] C89 typedef-array fallback path.
    exit /b 1
)

echo.
echo [P0] OK: SGDK m68k gcc supports C11 _Static_assert.
echo [P0] atlas_static_assert.h C11 path is active (no edits needed).
exit /b 0
