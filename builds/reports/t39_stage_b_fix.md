# T39 Stage B — HUD Row Guard on Bulk Tilebuf Path

**Status**: Landed. HUD rows 0-3 now clean at t=40, t=500, t=820.
T36 parity unchanged at 8/9.

## What Stage A got wrong

Stage A proposed gating `_ppu_write_7` by source range (`$2000` vs
`$2400`) using a D7 tracker. That fix was applied and compiled but had
no visible effect — because Zelda does not render cave/overworld
rooms through the per-byte `_ppu_write_7` path. Cave and overworld
bulk nametable updates flow through `_transfer_tilebuf_fast`
(`src/nes_io.asm:2683`), which dispatches `$2000-$23BF` writes
directly to `.ttf_nt_range` (line 2857) — bypassing `_ppu_write_7`
entirely (line 2508 comment: "Bypasses _ppu_write_7 entirely").

## Root cause (refined)

NT_CACHE layout on overworld at t=40 (scroll offset applied by VDP
vertical-scroll register):
- Rows 0-3: `$24` blank — outside viewport, scroll shifts display
  row 0 down to NT_CACHE row 4.
- Rows 4-7: HUD tiles (`$F5` hearts, `$6C` letter tiles, etc).
- Rows 8-29: overworld playfield.

Cave room renders go to NES `$2000` directly (not `$2400`). The
tilebuf interpreter folds them into NT_CACHE at offset
`(PPU_VADDR - $2000)`, so rows 0-29 of NT_CACHE get overwritten
including rows 0-3. On NES those rows 0-3 writes land in an unused
slot because of the mid-frame scroll split; on Gen they stomp
everything the display will show at those rows.

## Fix

`src/nes_io.asm:2870-2881` — in `.ttf_nt_range` immediately after
computing `D0 = PPU_VADDR - $2000`, branch to `.ttf_nt_skip` when
`D0 < $0080`. Skips both the NT_CACHE byte write and the VDP VRAM
tile-word write for any tile whose destination row is 0-3. Loop
still advances `PPU_VADDR` correctly, preserving record parsing.

```asm
    move.w  D5,D0
    subi.w  #$2000,D0               ; D0.w = index (0..$3BF)

    ; T39 HUD row guard: offsets 0-$7F (rows 0-3) are HUD domain.
    cmpi.w  #$0080,D0
    blo.s   .ttf_nt_skip
```

## Evidence

NT_CACHE dump diff (cols 0-31, rows 0-3 only):

```
        pre (t=40)        in-cave (t=500)        post-exit (t=820)
r00:    24 24 ... 24      24 24 ... 24           24 24 ... 24
r01:    24 24 ... 24      24 24 ... 24           24 24 ... 24
r02:    24 24 ... 24      24 24 ... 24           24 24 ... 24
r03:    24 24 ... 24      24 24 ... 24           24 24 ... 24
```

All three waypoints now show rows 0-3 = pure `$24`. Before the fix,
t=500 rows 0-3 were full of `D8 DA D9 DB CE D0 CF D1` cave tiles.

Cave interior content (rows 4-29) fully preserved: textbox tiles
(`12 1D 2A 1C 24 0D 0A …` = "IT'S DANGEROUS TO …"), cave walls/floor,
and cave-person row all intact.

## T36 parity

`python tools/compare_t36_cave_parity.py` → **8/9 PASS** (unchanged
from pre-fix baseline). Residual failure is `T36_CAVE_INTERIOR_MATCH`
at t=307 (Link XY divergence inside cave), orthogonal to render path.

## Artifacts

- `builds/reports/t39_nt_gen_pre.hex` (t=40)
- `builds/reports/t39_nt_gen_in.hex` (t=500)
- `builds/reports/t39_nt_gen_post.hex` (t=820)
- `builds/reports/t39_gen_pre.png`
- `builds/reports/t39_gen_in.png`
- `builds/reports/t39_gen_post.png`

Build: `Zelda27.169`.

## Follow-up (open)

1. Cave HUD still missing: NT_CACHE rows 4-7 (where overworld HUD
   lived) get stomped by cave playfield render. HUD tiles are never
   re-written during cave because the NES HUD-render code writes to
   a distinct nametable slot handled by the scroll split. On Gen
   those writes currently go to the same NT_CACHE row as the cave
   playfield. Needs a second pass: either mirror HUD onto Plane B,
   or insert a post-render HUD-restore step. Not blocking — T39
   primary symptom (rows 0-3 stomp + post-exit residue) resolved.
2. T36 `T36_CAVE_INTERIOR_MATCH` stair-drift remains. Separate issue.
