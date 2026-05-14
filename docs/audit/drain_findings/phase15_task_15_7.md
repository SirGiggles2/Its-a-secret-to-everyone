# Phase 15 Task 15.7 — CRAM And Palette Optimization

- **NES source**: NES PPU uses 4 BG subpalettes + 4 sprite subpalettes.
                  Genesis CRAM holds 4 palettes (PAL0..PAL3) × 16
                  colors. PAL0/PAL1 packed NES BG / sprite; PAL2/PAL3
                  available for Redux overlays.
- **Drained C**:  `src/state/palette_state.h` +
                  `src/state/palette_tick.c` +
                  `RoomRom/src/roomrom_bg_palette.c` +
                  `RoomRom/src/roomrom_ow_palette.c` +
                  `RoomRom/src/roomrom_palette_tick.c` (Phase 2 + 6
                  inline 15a work).
- **Coverage**:   PARTIAL — PAL0/PAL1 packing done inline; palette
                  dirty flags + batched CRAM updates partially in
                  tree via existing tick. Pre/post optimization CRAM
                  dump diff probe NOT shipped. No-flashing /
                  reduced-flashing option-aware path tracked under
                  Phase 9.4 deferred consumer
                  (`no_reduced_flashing` ✓ wired at
                  `draw_dispatch.c:568+640`).
- **Stance**:     PARTIAL — packing ADOPT; dirty-flag verifier +
                  CRAM-dump regression probe deferred.

## Deferral

`phase15_cram_dirty_flag_audit` — palette dirty-flag verifier +
CRAM-dump diff probe + transition/fade routine NES-palette-ownership
safety check.

## Status

CLOSE (with dirty-flag-audit deferral).
