# T36 Stage G — Stage F hypothesis disproven; new root-cause target

## Disproof of Stage F

Stage F claimed Gen SRAM[$6975]=$42 while NES=0 and blamed an
uninitialized mirror. Zero-fill of $FF6800..$FF7FFF at boot did not
change the symptom.

Write-BP on $FF6975 (Gen) identifies the real writer:

    SRAM6975 f=4   val=00 PC=0002F8A0   ; zero-fill (nes_io)
    SRAM6975 f=7   val=00 PC=00049D70
    SRAM6975 f=267 val=00 PC=00039B4E
    SRAM6975 f=466 val=42 PC=0004A6A0   ; CopyBlock_ROM

PC $4A6A0 = `_L_z06_CopyBlock_ROM_Loop` (z_06.asm:203). Caller chain:

    InitMode2_Sub0 → FetchLevelBlockDestInfo → CopyBlock_ROM
    dest ($02,$03) = $687E, end ($04,$05) = $6B7D
    → covers $687E..$6B7D (includes $6975)

This is deterministic, data-table driven, and runs identically on NES.
**NES _must_ also have $42 at $6975** after boot → level-load sequence.

## Implication

The NES per-frame capture `sram_0975 = 0` reading is either stale
(old json without the field) or the BizHawk `System Bus` NES read at
$6975 doesn't actually expose MMC1 PRG-RAM. Either way, Stage F's
SRAM-divergence claim is wrong.

## New Plan target

If both NES and Gen have $42 at $6975 at cave-enter time, both hit
InCave with `cave_index = 0`, both set $0350 = $6A. NES then clears
$0350 (and $00AC) via a downstream path that Gen doesn't reach.

Candidates for the clearing path on NES:
  1. `GetRoomFlagUWItemState` / `__far_z_01_0001` (room-already-taken)
  2. `UnhaltLink` via textbox page-3 (z_01:900)
  3. Some cave-exit / re-init that zeroes $0350 immediately

Gen's $0350=$6A persists for 260+ frames → Gen never reaches the
clearing code.

## DEFINITIVE evidence (NES capture rerun)

Rerun NES capture with sram_0975 field populated:

    NES trace: sram_0975 uniq = [0, 66]  (66 = $42)
    first_nz sram_0975 @ t=0 val=$42
    NES trace: cavetype   uniq = [0]       (never spawns person)
    NES trace: objstate   uniq = [0, 64]   ($40 from t=315..549, clears t=550)

**SRAM-divergence hypothesis is fully dead.** NES and Gen both have
$42 at $6975. Both hit the same InCave code path.

Yet **NES `$0350` never holds $6A** while Gen's `$0350` = $6A from
t=286 onward. So either:
  (a) NES doesn't execute `AssignObjSpawnPositions_InCave` at all, or
  (b) NES executes it but takes a different branch before line 2393
      `move.b D0,($0350,A4)`.

NES `$00AC` (objstate) does become $40 at t=315 — matches Gen — but
NES CLEARS it at t=550. Gen never clears. So the cave-person halt
mechanism runs on NES too; the phantom-person spawn is NOT the sole
differentiator.

## Next investigation (updated)

Rerun **NES capture** with re-added `sram_0975` plus per-frame
`$FF0350` sampling inside the correct frame range (not just where the
prior capture sampled). Confirm: does NES $0350 ever equal $6A, even
for one frame? If yes: the spawn happens on both; the bug is in
clearing. If no: the spawn itself is suppressed on NES by a predicate
Gen is missing.

Either way, the `nes_io.asm` zero-fill is a no-op for this bug and
should stay (harmless, semantically correct hygiene) but does not
close the gate.

## Files touched this stage

- `tools/bizhawk_t36_cave_gen_capture.lua` — add SRAM6975 write BP
- `src/nes_io.asm` — zero-fill $FF6800..$FF7FFF (retained, harmless)
- `builds/reports/t36_stage_g_copyblock.md` — this doc
