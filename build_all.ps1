# build_all.ps1 — build BOTH ROMs (Title.md + RoomRom.md) per debate 006 D3.
#
# Both ROMs share src/game/ source tree. Per debate 006 Rule WT-1 + D3
# substrate: any commit touching shared substrate must build both ROMs clean.
# Failure to build either = test-matrix drift = one ROM rots.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File build_all.ps1
#   build_all.bat   (thin wrapper)
#
# Exit code: 0 if BOTH builds green; 1 if either fails.

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -LiteralPath $root

Write-Host ""
Write-Host "============================================================"
Write-Host "build_all — building Title.md (default A4-pinned ABI)"
Write-Host "============================================================"
$titleStart = Get-Date
& cmd.exe /c "$root\build.bat"
$titleRc = $LASTEXITCODE
$titleSecs = [int]((Get-Date) - $titleStart).TotalSeconds
Write-Host "  Title.md build: rc=$titleRc time=${titleSecs}s"
if ($titleRc -ne 0) {
    Write-Host ""
    Write-Host "FAIL: Title.md build broke. Test matrix drift detected." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "============================================================"
Write-Host "build_all — building RoomRom.md (-DROOMROM_BUILD non-A4 ABI)"
Write-Host "============================================================"
$roomromStart = Get-Date
& cmd.exe /c "$root\RoomRom\build.bat"
$roomromRc = $LASTEXITCODE
$roomromSecs = [int]((Get-Date) - $roomromStart).TotalSeconds
Write-Host "  RoomRom.md build: rc=$roomromRc time=${roomromSecs}s"
if ($roomromRc -ne 0) {
    Write-Host ""
    Write-Host "FAIL: RoomRom.md build broke. Test matrix drift detected." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "OK: BOTH ROMs built green." -ForegroundColor Green
Write-Host "  Title.md   : $root\builds\Title.md"
Write-Host "  RoomRom.md : $root\RoomRom\out\RoomRom.md"
Write-Host "  Total time : $($titleSecs + $roomromSecs)s"
Write-Host "============================================================" -ForegroundColor Green
exit 0
