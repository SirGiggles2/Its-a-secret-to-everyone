# T39 Stage C — Cave HUD Restore (mode-gated rows 4-6)

**Status**: Landed in `85a18e5e` (Zelda27.170–.176). T39 now PASS at
all three waypoints (pre, in, post). T36 parity unchanged at 8/9.

## What Stage B got right

Stage B landed unconditional protection for NT_CACHE rows 0-3 via the
bulk-tilebuf dispatcher (`.ttf_nt_range` in `src/nes_io.asm`). That
cleared the dominant cave-ceiling stomp above the HUD band.

## What Stage B missed

Rows 4-6 of NT_CACHE hold the HUD icon band (hearts, rupee, keys,
bombs, compass, map indicator, map-triangle). Cave-interior renders
still stomped these rows because the overworld HUD content is written
via the same bulk-tilebuf path — so we couldn't block unconditionally
without also killing legitimate HUD writes.

First iteration (Stage C.1) gated rows 4-6 on `GameMode == $0B`
(cave). That held `pre` (overworld, t=40) and `in` (cave, t=500), but
`post` (t=820) still showed cave ceiling mixed with HUD-indicator
anchors:

```
r04: D8 DA D8 DA D8 DA D8 DA D8 DA D8 DA D8 DA D8 DA D8 DA D8 DA D8 DA D8 DA D8 DA D8 DA D8 DA D8 DA
r05: D9 DB D9 DB D9 DB D9 DB D9 DB D9 DB 21 00 24 DB D9 DB D9 DB D9 DB 24 24 24 24 24 24 24 24 D9 DB
r06: D8 DA D8 DA 26 26 26 26 26 26 26 26 21 00 24 26 26 26 26 26 26 26 F2 F2 F2 24 24 24 24 24 D8 DA
```

## Mode capture evidence

Adding `GameMode` / `TargetMode` / `ScrollY` to the t39 NT_CACHE dump
header revealed that at t=820 the state is mid-transition:

```
t=40    PPUCTRL=$B0 PPUMASK=$1E GameMode=$05 TargetMode=$00 ScrollY=$00
t=500   PPUCTRL=$B0 PPUMASK=$1E GameMode=$0B TargetMode=$0B ScrollY=$00
t=820   PPUCTRL=$B0 PPUMASK=$1E GameMode=$05 TargetMode=$0B ScrollY=$00
```

At t=820 `GameMode` has already flipped back to `$05` but `TargetMode`
still points at cave (`$0B`) — the stair-ascent animation is still in
flight. Any bulk writes in that window bypassed the `GameMode==$0B`
guard.

## Fix

`src/nes_io.asm:2875-2900` — extend the rows 4-6 skip to cover all
cave-related states:

```asm
    cmpi.w  #$0080,D0
    blo     .ttf_nt_skip               ; rows 0-3: unconditional (Stage B)
    cmpi.w  #$00E0,D0
    bhs.s   .ttf_nt_cache_ok           ; rows 7+: no guard
    cmpi.b  #$0B,($0012,A4)            ; GameMode == cave?
    beq     .ttf_nt_skip
    cmpi.b  #$10,($0012,A4)            ; GameMode == stair transition?
    beq     .ttf_nt_skip
    cmpi.b  #$0B,($005B,A4)            ; TargetMode == cave (mid-entry)?
    beq     .ttf_nt_skip
.ttf_nt_cache_ok:
```

Three mode-byte checks (`GameMode == $0B`, `GameMode == $10`,
`TargetMode == $0B`) cover the `$05 → $10 → $0B → $10 → $05` arc.
Added instructions pushed `.ttf_nt_skip` past the `.s` byte
displacement window, so the inner branches became long-form `blo` /
`beq`.

## Evidence after fix (Zelda27.176)

NT_CACHE rows 4-6 at all three waypoints:

```
pre  (t=40, mode$05, target$00):
r04: 24 24 F5 F5 F5 F5 F5 F5 F5 F5 24 24 24 24 24 6C 24 6C 6C 24 6C ...
r05: 24 24 F5 F5 F5 F5 F5 F5 F5 F5 24 F9 21 00 24 6C 24 6C 6C 24 6C ...
r06: 24 24 F5 F5 F5 F5 F5 F5 F5 F5 24 61 21 00 24 6E 6A 6D 6E 6A 6D ...

in   (t=500, mode$0B, target$0B):
r04-r06: identical to pre (HUD preserved through bulk-tilebuf writes)
r13-r14: full cave textbox "12 1D 2A 1C 24 0D 0A 17 10 0E 1B 18 1E 1C ..."
         ("IT'S DANGEROUS TO ...")

post (t=820, mode$05, target$0B):
r04-r06: identical to pre
r07+:    cave residue still in place (expected — stair transition mid-flight)
```

## Stage C.2 side experiments (tried and reverted)

Two alternate approaches were explored before landing the mode-triple
gate:

1. **Unconditional rows 4-6 block** — cleared post-exit but left
   pre-cave HUD at `$24` blank. Boot-time HUD writes also flow
   through the bulk path, so the unconditional guard starved HUD
   population.
2. **`_clear_nametable_fast` HUD-preserve** — tried skipping rows 0-6
   inside the direct clear helper. Broke boot: the helper writes
   `$24` as a pre-HUD canvas, and skipping left those rows at `$00`
   (BSS zero), producing "barcode" garbage between HUD glyphs.

Both were reverted (not in git history — iterated in a single build
session). The landed fix uses the mode-triple gate only on the bulk
path, preserving direct-clear and per-byte paths untouched.

## Regression / T36 parity

Regression baseline (new `tools/run_all_probes.ps1` driver +
env-aware probes):

```
[FAIL] Boot T7-T11           T8_NMI_CADENCE 81.4% (< 95%)   — pre-existing
[FAIL] PPU Latch T12         VRAM[$2000]=$0011 (probe stale) — pre-existing
[FAIL] PPU Increment T13     VRAM[$2000]=$0011 (probe stale) — pre-existing
[PASS] PPU Ctrl T14
[PASS] Scroll Latch T15
[PASS] MMC1 T11b
[PASS] Phase 1/2/6 Verify
```

All three FAILs reproduce on pre-Stage-B commit `4a620a13`
(Zelda27.178), confirming they are not Stage B/C regressions. T12/T13
probe assumptions on VRAM[$2000]=$2424 predate Plane A relocation to
VDP $C000 and need separate follow-up (tracked outside T39).

T36 cave parity: still 8/9 PASS. Residual
`T36_CAVE_INTERIOR_MATCH` at t=307 is the parked 1-frame obj-y phase
offset (commit `1844f7b4`) — unrelated to render path.

## Artifacts

- `builds/reports/t39_nt_gen_pre.hex`  (t=40, mode$05/target$00)
- `builds/reports/t39_nt_gen_in.hex`   (t=500, mode$0B/target$0B)
- `builds/reports/t39_nt_gen_post.hex` (t=820, mode$05/target$0B)
- `builds/reports/t39_gen_pre.png`
- `builds/reports/t39_gen_in.png`
- `builds/reports/t39_gen_post.png`
- `builds/reports/regression_summary.txt`

Builds: `Zelda27.170-.176` (Stage C iterations), `Zelda27.179` (final
verification).

## Follow-ups (out of T39 scope)

1. Probes `bizhawk_ppu_latch_probe.lua` and
   `bizhawk_ppu_increment_probe.lua` encode `VRAM[$2000]=$2424`
   expectation. Plane A now lives at VDP `$C000`; probes should read
   `$C000` (or compute the right address via the same row*$80+col*2
   scheme used in `.ttf_nt_range`).
2. T8_NMI_CADENCE 81.4% vs 95% threshold. Already investigated and
   shown orthogonal to T36 cave lag (commit `06701015`). Needs its
   own root-cause pass.
