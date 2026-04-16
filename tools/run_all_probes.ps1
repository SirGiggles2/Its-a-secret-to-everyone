param()
$ErrorActionPreference = 'Stop'
$ROOT = (Resolve-Path "$PSScriptRoot\..").Path
$EMU  = 'C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe'
$ROM  = Join-Path $ROOT 'builds\whatif.md'
$REPORT = Join-Path $ROOT 'builds\reports'
$SUMMARY = Join-Path $REPORT 'regression_summary.txt'

if (-not (Test-Path $EMU)) { Write-Error "BizHawk not found: $EMU"; exit 1 }
if (-not (Test-Path $ROM)) { Write-Error "ROM not found: $ROM"; exit 1 }

# Probes read $env:CODEX_BIZHAWK_ROOT to resolve worktree paths for
# whatif.lst landmark lookup and report output. Without this they fall
# back to the main tree and write reports in the wrong place.
$env:CODEX_BIZHAWK_ROOT = $ROOT

"WHAT IF Regression Suite"           | Set-Content $SUMMARY
"Run:  $(Get-Date)"                  | Add-Content $SUMMARY
"ROM:  $ROM"                         | Add-Content $SUMMARY
"================================="  | Add-Content $SUMMARY

$probes = @(
  @{ Name='Boot T7/T8/T9/T10/T11'; Lua='bizhawk_boot_probe.lua';       Out='bizhawk_boot_probe.txt' },
  @{ Name='PPU Latch T12';         Lua='bizhawk_ppu_latch_probe.lua';  Out='bizhawk_ppu_latch_probe.txt' },
  @{ Name='PPU Increment T13';     Lua='bizhawk_ppu_increment_probe.lua'; Out='bizhawk_ppu_increment_probe.txt' },
  @{ Name='PPU Ctrl T14';          Lua='bizhawk_ppu_ctrl_probe.lua';   Out='bizhawk_ppu_ctrl_probe.txt' },
  @{ Name='Scroll Latch T15';      Lua='bizhawk_scroll_latch_probe.lua'; Out='bizhawk_scroll_latch_probe.txt' },
  @{ Name='MMC1 State T11b';       Lua='bizhawk_mmc1_probe.lua';       Out='bizhawk_mmc1_probe.txt' },
  @{ Name='Phase 1/2/6 Verify';    Lua='bizhawk_phase1_verify.lua';    Out='bizhawk_phase1_verify.txt' }
)

$pass = 0; $fail = 0; $err = 0
foreach ($p in $probes) {
    $lua = Join-Path $ROOT "tools\$($p.Lua)"
    $rpt = Join-Path $REPORT $p.Out
    if (-not (Test-Path $lua)) {
        "[SKIP] $($p.Name)" | Tee-Object -FilePath $SUMMARY -Append
        $err++; continue
    }
    if (Test-Path $rpt) { Remove-Item $rpt -Force }
    Write-Host "Running $($p.Name) ..."
    # BizHawk's arg parser splits on whitespace even inside quoted --lua=<path>
    # unless the whole argv element is quoted at the cmd layer. Start-Process
    # re-joins -ArgumentList with spaces and doesn't re-quote, so we pre-wrap
    # each path in embedded double-quotes to force cmd-level quoting.
    $luaArg = '"--lua=' + $lua + '"'
    $romArg = '"' + $ROM + '"'
    Start-Process -FilePath $EMU -ArgumentList $luaArg,$romArg -Wait -NoNewWindow
    if (-not (Test-Path $rpt)) {
        "[ERROR] $($p.Name) -- report not generated" | Tee-Object -FilePath $SUMMARY -Append
        $err++; continue
    }
    $lines = Get-Content $rpt
    $result = 'UNKNOWN'
    foreach ($l in $lines) {
        if ($l -match 'ALL PASS') { $result = 'PASS' }
        if ($l -match ': FAIL')   { $result = 'FAIL' }
    }
    if ($result -eq 'PASS') {
        "[PASS] $($p.Name)" | Tee-Object -FilePath $SUMMARY -Append
        $pass++
    } elseif ($result -eq 'FAIL') {
        "[FAIL] $($p.Name)" | Tee-Object -FilePath $SUMMARY -Append
        $fail++
    } else {
        "[ERROR] $($p.Name) -- no PASS/FAIL marker" | Tee-Object -FilePath $SUMMARY -Append
        $err++
    }
}

"" | Add-Content $SUMMARY
"================================="  | Add-Content $SUMMARY
"PASS: $pass  FAIL: $fail  ERROR/SKIP: $err" | Add-Content $SUMMARY

Write-Host ""
Write-Host "================================================================="
Write-Host "Regression Summary"
Write-Host "================================================================="
Get-Content $SUMMARY | Write-Host

if ($fail -gt 0) { exit 1 }
if ($err  -gt 0) { exit 2 }
exit 0
