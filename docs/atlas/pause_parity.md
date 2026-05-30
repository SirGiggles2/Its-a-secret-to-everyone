# Pause subscreen parity — OW BYTE-EXACT (2026-05-30)

## Status: OW (overworld/triforce) subscreen = **BYTE-EXACT vs NES**

`tools/parity/pause_golden/pause_byte_diff.py` verdict: **PASS — 0 gate
divergences** (NES `nes_ow/active.bin` vs Genesis `boot/active.bin`).
Supersedes the prior "VISUAL-APPROX / 45.6% / deferred" status entirely —
nothing in the OW pause is deferred.

## What is byte-exact

| Domain | Result |
|---|---|
| BG menu tilemap | 122/122 non-blank cells match, 0 pixel-delta, 0 missing |
| BG palette (PAL0) | byte-exact via misc_palettes LUT |
| Sub-pals | per-cell from live NT2 attribute table (`k_inventory_subpal`); triforce = sub-pal 1 (was wrongly 3) |
| Triforce triangle | byte-exact (atlas sub-pal 1 variant added to `gen_bg_sparse.py`) |
| Item sprites | every owned item byte-exact: tile (NES `Anim_ItemFrameTiles`), position (`SubmenuItemXs`), sub-pal, 3-mode dispatch (@Narrow/@Slim/@Mirrored) |
| Missing icons | recorder $24, candle $26, raft $6C, ladder $76, marker $3E extracted live -> `inventory_sprite_chr.c` @ VRAM $A000 |
| Cursor | 2-sprite selection box ($1E left + right h-flip), position+shape byte-exact |
| B-item box | selected item redrawn at ($40,$36) per `@DrawBreakoutItem` |
| Position marker | tile $3E at room-derived (X,Y) per `UpdatePlayerPositionMarker` |
| Compass/map | gated on CurLevel (OW omits them, matches `HasCompass`/`HasMap`) |
| **Scroll animation** | **real VSRAM ramp 174->0, 58 steps @ 3 px/frame = NES `CurVScroll` $EF->$41** (was a row-by-row fake) |

## Documented normalizations (hardware/temporal, NOT divergences)

- **SAT +128 / +$81**: Genesis SAT coordinate offset vs NES OAM. Subtracted before diff.
- **CRAM 3-bit quantize**: Genesis 3-bits/channel vs NES 6-bit master. Mapped through the project LUT.
- **Cursor flash phase**: the cursor alternates PAL2<->PAL3 every 8 frames (= NES pal5<->pal6). Both colors are byte-exact and the cadence matches; the absolute phase at one captured instant is temporal-alignment-dependent, so the differ normalizes it.

## Scroll mechanism note

Gameplay Plane A is already V64 (`main.c:639`), so the 176 px menu parks
off-screen above the viewport and VSRAM ramps it down — no plane-size
toggle. BG_A and BG_B share $C000 so both vscroll words ramp in lockstep.
HScroll ($F000) and SAT ($F400) are outside the V64 fill window ($C000-$DFFF).

## Harness

- `tools/parity/pause_golden/pause_capture_{nes,gen}.lua` — NCGD/GCGD bundles + scroll ladders
- `tools/parity/pause_golden/pause_byte_diff.py` — per-domain byte differ + gate
- `tools/parity/pause_golden/run_pause_capture.py` — launch runner

## Remaining

- **UW (dungeon) subscreen**: separate context — dungeon map render (vs
  triforce), compass + dungeon-item placement, UW position-marker math
  (`Z_05.asm:295-355`), and a real dungeon-load capture path. Not yet built.
