# Intro Heart Flash — Design

**Date:** 2026-04-25
**Scope:** intro_demo standalone ROM (`tools/intro_demo/`)
**Goal:** Make the recovery-heart icon (NES item `0x22`, tile `$F3`) flash through NES `DemoPhase0Subphase1`'s 14-cycle palette animation while it is on screen during the treasures scroll. All other items — including container heart, fairy, clock, rupee, etc. — must stay static.

## Background

The NES intro item showcase animates by cycling 14 full PALRAM states (`Z_02.asm` `DemoPhase0Subphase1`, lines 1111-1167). Every sprite in the affected palette flashes together on NES. On the current Genesis port (`tools/intro_demo/main.c`), there is no per-frame palette animation — the combined CRAM is uploaded once and all items render statically.

The user wants only the recovery heart cell to flash, matching NES color sequence and timing exactly. Container heart, despite sharing NES sprite pal 0, must remain static.

## Strategy

Route the heart's 4bpp tile pixels to a dedicated CRAM region (Genesis palette 1, slots 8-11) so per-frame CRAM writes affect only the heart cell. Container and other palette-1 items continue referencing slots 4-7, untouched.

Existing infrastructure makes this cheap:

* `tools/intro_demo/intro_blink_chr.c` — already encodes heart pair `$F2/$F3` with `color_shift=8` (tile pixels reference palette slots 8-11).
* `tools/intro_demo/intro_demo_palettes.c` — already extracts the 14 cycles with NES delays from `Z_02.asm:1111-1167`.

## Architecture

```
intro_blink_chr.c (existing 256 B blob, 8 tiles)
   ├── tiles 0-1 = heart $F2/$F3, color_shift=8 → THIS FEATURE
   └── tiles 2-7 = container/triforce/rupee     → reserved for follow-up

main.c
   ├── Upload first 64 B of intro_blink_chr at VRAM $4040 (Gen tiles 514-515)
   ├── Seed pal1[8..11] from intro_demo_palette_cycles[0][0..3] at startup
   └── Per-vblank state machine: when heart visible, advance cycle, write 4 CRAM words

compose_treasures_tilemap.py
   └── Special-case item_id 0x22 → cell points at Gen tiles 514/515, palette = 1
```

## VRAM layout

| Range | Contents | Size | Notes |
|-------|----------|------|-------|
| `$0000` | common BG CHR | per existing | unchanged |
| `$0E00` | font CHR | per existing | unchanged |
| `$1E40` | misc CHR (Gen tiles 242-255) | 448 B | unchanged — heart-via-bg path retained for non-flashing fallback |
| `$2000` | sprite CHR (Gen tiles 256-511) | per existing | unchanged |
| `$4000` | punct CHR (Gen tiles 512-513) | 64 B | existing |
| `$4040` | **heart blink pair** (Gen tiles 514-515) | 64 B | **new** |

No collisions; punct ends at `$403F`.

## CRAM layout (slot offset = `pal*16 + idx`)

Genesis palette 1:

| Slot | Contents | Behavior |
|------|----------|----------|
| 0 | backdrop | static |
| 1-3 | NES BG pal 0 (story) | static |
| 4-7 | NES sprite pal 0 (container, fairy, etc.) | static |
| **8-11** | **heart-only color cycle (4 words)** | **animated each cycle** |
| 12-15 | unused | reserved (future rupee per `intro_blink_chr.c` shift=12) |

Cycle source: `intro_demo_palette_cycles[c][0..3]` (originally pal 1 slots 4-7), redirected to slots 8-11.

## Tilemap change

`compose_treasures_tilemap.py::place_icon`, after computing `pal`/`use_bg`:

```python
HEART_BLINK_TOP = 514
HEART_BLINK_BOT = 515
if item_id == 0x22:
    row_top[col] = cell(1, HEART_BLINK_TOP)
    row_bot[col] = cell(1, HEART_BLINK_BOT)
    return
```

Palette forced to 1 (heart's NES sprite pal 0 mapping), regardless of `icon_pal()` lookup, to match the slot-8-11 plan.

## Runtime state machine (main.c)

State (function-local statics in `main`):
```c
unsigned char  heart_cycle_idx   = 0;
unsigned char  heart_delay_left  = intro_demo_palette_delays[0];
unsigned char  heart_visible_prev = 0;
```

Heart pixel range computed at compile time:
```c
const unsigned long HEART_TOP_PX = (intro_story_tilemap_rows + GAP_ROWS + 2) * 8u;
const unsigned long HEART_BOT_PX = HEART_TOP_PX + 16u;  /* 2 rows tall */
```

Visibility test (each vblank):
```c
unsigned char heart_visible =
    (pixel_count + 224u > HEART_TOP_PX) && (pixel_count < HEART_BOT_PX);
```

Animation step (each vblank, only when visible, NOT gated by tick):
```c
if (heart_visible) {
    if (heart_delay_left == 0) {
        heart_cycle_idx = (unsigned char)((heart_cycle_idx + 1u) % 14u);
        heart_delay_left = intro_demo_palette_delays[heart_cycle_idx];
        const unsigned short *cyc = intro_demo_palette_cycles[heart_cycle_idx];
        cram_write_one(1*16 + 8,  cyc[0]);
        cram_write_one(1*16 + 9,  cyc[1]);
        cram_write_one(1*16 + 10, cyc[2]);
        cram_write_one(1*16 + 11, cyc[3]);
    } else {
        heart_delay_left--;
    }
}
```

Initial CRAM seed (after `cram_upload(intro_combined_palette, 64)`):
```c
{
    const unsigned short *cyc = intro_demo_palette_cycles[0];
    cram_write_one(1*16 + 8,  cyc[0]);
    cram_write_one(1*16 + 9,  cyc[1]);
    cram_write_one(1*16 + 10, cyc[2]);
    cram_write_one(1*16 + 11, cyc[3]);
}
```

Loop restart (when `pixel_count >= total_pixels`):
```c
heart_cycle_idx  = 0;
heart_delay_left = intro_demo_palette_delays[0];
/* Re-seed CRAM */
const unsigned short *cyc = intro_demo_palette_cycles[0];
cram_write_one(1*16 + 8,  cyc[0]);
cram_write_one(1*16 + 9,  cyc[1]);
cram_write_one(1*16 + 10, cyc[2]);
cram_write_one(1*16 + 11, cyc[3]);
```

CRAM writes occur inside the `wait_vblank()` block (already at top of loop), so no display artifacts.

Cycle wrap (`% 14`): heart visible → cycle continuously. NES intro phase ends after one pass, but our scroll loops, so wrapping matches the user's "while on screen" intent. Frozen when `heart_visible` is false.

## Error / edge cases

* Heart enters/exits visible window mid-cycle: state preserved (no reset on transition).
* Initial story pause / end pause: `pixel_count` never enters `[128, 368)` during these phases (heart is below screen) — animation idle.
* Loop restart: explicit reset to cycle 0 + CRAM reseed. No torn state.
* NTSC Genesis 59.92 Hz vs NES 60.10 Hz: 0.3% drift over 14 cycles — visually identical.

## Testing

1. `run_build.bat` (or intro_demo equivalent) — ROM compiles clean.
2. Run in BizHawk Genesis (`bizhawkScript` skill, `EmuHawk.exe --lua=…`).
3. Visual checks:
   - Heart cell flashes through NES color sequence while on screen.
   - Container heart, fairy, clock, etc. **do not flash**.
   - Story scroll text/colors unaffected.
   - White-out cycles 12-13 affect heart only.
   - After scroll loop restart: heart resumes from cycle 0.
4. Optional NES side-by-side: capture NES intro PALRAM at heart-visible frames, compare hex of pal-0 sprite slots to `intro_demo_palette_cycles[c][0..3]` decoded.

## Out of scope (follow-up)

* Rupee flash — `intro_blink_chr.c` already has rupee pair at `color_shift=12` (slots 12-15). Apply same pattern, separate cycle slice.
* Triforce flash — pair already at `color_shift=8` in blink CHR. Need its own dedicated palette-region (cannot reuse heart's slots 8-11 of pal 1 unless it lives in different palette, e.g. pal 3 slots 8-11).
* Container heart flash — explicitly excluded by user.

## Files touched

* `tools/intro_demo/main.c` — extern decls, blink CHR upload, state machine, init/restart hooks.
* `tools/intro_demo/compose_treasures_tilemap.py` — heart cell redirect.
* `tools/intro_demo/intro_treasures_tilemap.c` — regenerated.

* `tools/intro_demo/build.bat` — add generate+compile+link steps for `intro_blink_chr.c` and `intro_demo_palettes.c` (currently absent from build).

No new files.
