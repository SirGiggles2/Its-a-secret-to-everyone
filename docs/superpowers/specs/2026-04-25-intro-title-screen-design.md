# Intro Title Screen — Design

**Date:** 2026-04-25
**Scope:** `tools/intro_demo/` standalone Genesis ROM
**Goal:** Add the NES Zelda title screen (logo + vines + sword/Triforce + Triforce glow + waterfall sprite animation + "PUSH START BUTTON" text) before the existing story/items sequence, with NES-faithful timing and a NES-faithful 14-cycle palette fade-out into the existing intro phases. The full sequence loops indefinitely.

## Background

The existing intro_demo ROM begins with a 4-level mask fade-in into the story scroll. The user wants to expand it into the full NES attract-mode loop, beginning at the title screen. NES timing reference (user-supplied frame numbers from `tools/intro_demo/nes_loop/`):

| Frame | Event |
|-------|-------|
| f0035 | Title appears (post-boot blue/black). |
| f0555 | Title fade-out begins (NES `DemoPhase0Subphase1` palette cycles). |
| f0785 | Screen fully black. |
| f1040 | Story first appears (top row at bottom of screen). |
| f1445 | Story stops in position. |
| f1705 | Story scroll-off begins. |

Title displays 520 frames bright, fades 230 frames to black, then story phase as already implemented. Loop returns to title.

NES source references (verified, no guessing):

* `Z_02.asm:213 UpdateMode0Demo_Sub0` — Start press handler (we display "PUSH START BUTTON" but do not act on input; loop is autonomous).
* `Z_02.asm:342 InitialTitleSprites` — 28 title sprites (112 bytes, Y/tile/attr/X format).
* `Z_02.asm:944 TriforcePaletteTransferRecord` — sets BG pal 1 to `$36 $17 $27 $0F` (title-base colors).
* `Z_02.asm:947 TriforceGlowingColors` — `$27 $37 $37 $27 $17 $07 $07 $17` glow cycle (8 colors).
* `Z_02.asm:950 AnimateDemoPhase0Subphase0Artifacts` — drives sprite copy, glow timer (6 frames per color, 16-frame end hold), waterfall update.
* `Z_02.asm:990 WaterfallWaveTiles` / `:993 WaterfallCrestTiles` — 4-tile cycles for waterfall sprite animation.
* `Z_02.asm:1111 DemoPhase0Subphase1Palettes` — 14 × 32-byte palette cycles used for title fade-out.
* `Z_02.asm:1179 DemoPhase0Subphase1Delays` — `$08 $08 $06 $05 $04 $03 $02 $02 $02 $C0 $06 $04 $C0 $03` (sum = 437 frames).
* `reference/aldonunez/dat/GameTitleTransferBuf.dat` — NES title nametable as transfer-record stream (1121 bytes).

## Strategy

Replace the current ad-hoc fade + scroll with a phase-driven state machine that walks through title display, fade-out, VRAM swap, story scroll-in, hold, scroll-off, end pause, and back to title. Title and story use **two distinct VRAM/CRAM layouts**; we re-upload CHR + tilemap + palette at the boundary while the display is blanked for one frame.

### Phase State Machine

```
PHASE_TITLE_LOAD     (1 fr)    -> display off, upload title VRAM/CHR/CRAM/sprites, display on
PHASE_TITLE_DISPLAY  (515 fr)  -> title BG + glow CRAM patch + waterfall sprite cycle + "PUSH START"
PHASE_TITLE_FADEOUT  (~437 fr) -> NES DemoPhase0Subphase1: 14 palette cycles, NES delays
                                  ($08,$08,$06,$05,$04,$03,$02,$02,$02,$C0,$06,$04,$C0,$03)
PHASE_STORY_LOAD     (1 fr)    -> display off, upload story VRAM/CHR/CRAM/plane,
                                  heart-flash CRAM slots restored, display on
PHASE_STORY_SCROLL_IN          -> story streams in from below (existing logic)
                                  ends when pixel_count >= STORY_SCROLL_TARGET (216)
PHASE_STORY_HOLD     (260 fr)
PHASE_SCROLL_OFF               -> existing scroll loop, item flash anims (heart/rupee/triforce/fairy)
PHASE_END_PAUSE      (180 fr)  -> hold at TRIFORCE/sign rows
[loop -> PHASE_TITLE_LOAD]
```

Two distinct load phases: `PHASE_TITLE_LOAD` and `PHASE_STORY_LOAD`. Each is a single-vblank phase that performs CHR/CRAM/plane upload with the display blanked. On the first run, `PHASE_TITLE_LOAD` is the boot entry; on subsequent loops it's the destination of `PHASE_END_PAUSE`.

Single state variable `intro_phase` (u8) plus per-phase frame counter. Transition writes new phase value and resets counter. Phase entry hooks load any one-shot CRAM/VRAM updates.

The user-cited 230-frame fade-out is approximate; we use the full NES `Subphase1` 437-frame cycle (sum of NES delays) for fidelity. If the user wants it shorter, scaling the delay table is a one-line change.

## VRAM Layouts

### Title layout
| VRAM | Contents |
|------|----------|
| `$0000` | Title BG CHR (extracted subset of `CommonBackgroundPatterns.dat` — vines, logo letters, sword graphic) |
| `$2000` | Title sprite CHR (sword, bird, "PUSH START" font glyphs, waterfall tiles) |
| `$C000` | Plane A: title nametable from `GameTitleTransferBuf.dat`, 32×30 cells |
| Sprite list | 28 title sprites + 6-12 waterfall sprites at fixed Genesis sprite-table address |

### Story layout (current setup, unchanged)
| VRAM | Contents |
|------|----------|
| `$0000` | story common BG CHR |
| `$0E00` | story font CHR |
| `$1E40` | misc CHR (Gen tiles 242-255) |
| `$2000` | sprite CHR (Gen tiles 256-511) |
| `$4000` | punct CHR (Gen tiles 512-513) |
| `$4040` | blink CHR (Gen tiles 514-521, heart/container/triforce/rupee) |

`PHASE_STORY_LOAD` re-uploads everything for the story layout (title→story transition). `PHASE_TITLE_LOAD` performs the reverse (story→title or initial boot). Display register `$8174` cleared to `$8134` (display off) before writes, restored after.

## Asset Extraction

New Python scripts under `tools/intro_demo/`, all run from `build.bat`:

1. **`extract_title_tilemap.py`** — parse `GameTitleTransferBuf.dat` as a sequence of NES VRAM transfer records (`[high_addr, low_addr, count, ...data, $FF]`); reconstruct 32×30 nametable + 64-byte attribute table; emit Genesis tilemap with per-cell palette field. Output `intro_title_tilemap.c`.

2. **`extract_title_bg_chr.py`** — identify the unique tile indices used by the parsed title nametable; pull each from `CommonBackgroundPatterns.dat`; re-encode 2bpp→4bpp Genesis (no color shift; BG tiles reference slots 0-3 directly). Output `intro_title_bg_chr.c`.

3. **`extract_title_sprite_chr.py`** — for each unique tile referenced by `InitialTitleSprites` + `WaterfallWaveTiles` + `WaterfallCrestTiles`, pull from `CommonSpritePatterns.dat`; re-encode 2bpp→4bpp with `color_shift=4` (Genesis pal slots 4-7 = NES sprite pals). Output `intro_title_sprite_chr.c`.

4. **`extract_title_palette.py`** — BizHawk Lua probe runs the NES Zelda ROM, advances to a clean title frame (e.g. frame 100), dumps PALRAM (32 bytes), saves `palram_title.bin`. Python step converts each NES color via `nes_color_to_gen_cram` into a 64-word Gen palette layout matching `intro_combined_palette` packing (BG pals 0-3 in slots 0-3 of Gen pal 0-3, sprite pals 0-3 in slots 4-7). Output `intro_title_palette.c`.

5. **`extract_title_glow.py`** — tiny script emitting `intro_title_glow.c` with the 8 Gen-CRAM-converted glow colors and the per-color delays (6 frames each, 16 for the final color, per `Z_02.asm:976-983`).

`build.bat` runs these in sequence before compile + link, just like existing intro assets.

## Runtime Components

New files:

* `tools/intro_demo/intro_title.c` — title-phase functions:
  * `intro_title_setup(void)` — uploads title CHR, palette, plane, initial sprite list.
  * `intro_title_step(void)` — per-vblank: glow-cycle CRAM patch (writes Gen pal 1 slot 1), waterfall sprite-tile rotation (every 8 frames), no Start-press handling.

* `tools/intro_demo/intro_phase.c` — phase state machine, VRAM swap, dispatch.

* `tools/intro_demo/intro_phase.h` — phase enum + entry points.

Changed:

* `tools/intro_demo/main.c` — body shrinks to `for (;;) { wait_vblank(); intro_phase_step(); }` plus boot-time call to `intro_phase_setup_title()`. All inline phase logic moves into `intro_phase.c` and per-phase modules.

* `tools/intro_demo/build.bat` — add generate + compile steps for the 5 new extract scripts and 2 new C files; add 7 new `.o` paths to the link line.

* `tools/intro_demo/intro_treasures_tilemap.c` — unchanged (still the source of the items showcase).

## Glow Cycle Implementation

NES (`Z_02.asm:962-988`):

```
LDA TriforceGlowTimer       ; If timer non-zero, just decrement.
BNE @DecGlowTimer
LDY #$07                    ; Otherwise transfer 8-byte palette record:
@CopyTriforcePalette:        ;   $3F $04 $04 $36 $17 $27 $0F $FF
LDA TriforcePaletteTransferRecord, Y
STA DynTileBuf, Y
DEY
BPL @CopyTriforcePalette
LDY TriforceGlowCycle       ; Patch byte +5 with the glowing color:
LDA TriforceGlowingColors, Y
STA DynTileBuf+5
LDA #$06                    ; Reset timer to 6 frames (16 at end of cycle).
STA TriforceGlowTimer
INC TriforceGlowCycle
LDA TriforceGlowCycle
CMP #$08
BNE @DecGlowTimer
LDA #$10                    ; Final entry holds 16 frames before wrap.
STA TriforceGlowTimer
LDA #$00
STA TriforceGlowCycle
```

Genesis equivalent: every 6 frames (16 at end), advance `glow_cycle` and write `cram_write_one(1*16 + 1, glow_colors[glow_cycle])`. The glow recolors a single CRAM slot — no full palette upload.

## Waterfall Animation

NES code uses sprite list slots starting at offset `$70` for waterfall waves and `$80`/`$90` for crests (per `WaterfallWaveSpriteOffsets`). Each updated to next tile in 4-tile cycle every 8 frames.

Genesis equivalent: a small `waterfall_sprites[N]` table tracking the target sprite indices (within Genesis sprite list), per-frame counter, and a tile cycle index. Each 8-frame tick the sprite-list entries' tile fields rotate through `WaterfallWaveTiles` / `WaterfallCrestTiles`.

## Heart-Flash CRAM Restoration

The full-palette fade-out clobbers Gen pal 2 slots 9-11 and pal 3 slots 9-11 (which hold the NES sprite pal 1 / pal 2 colors used by the heart/rupee/triforce flash). `PHASE_VRAM_SWAP` writes these slots after re-uploading the story palette.

## Edge Cases

* **VRAM swap flicker**: display register cleared to display-off before any VRAM/CRAM writes; restored after. Single black frame is acceptable and matches NES (the screen is already black at the end of the fade-out).
* **Sprite count budget**: ~28 title sprites + ~12 waterfall sprites = 40, well under Genesis's 80-per-frame limit.
* **CRAM write budget per vblank**: per-frame work in PHASE_TITLE_DISPLAY = 1 cram_write_one (glow), maybe 1-2 sprite-list writes. PHASE_TITLE_FADEOUT writes 64 words on cycle boundaries (~512 cycles) — well within vblank budget.
* **Plane wrap during loop reset**: full reset zeroes scroll, last_row, next_source_row, fade_cycle, phase_counter, all flash counters. Repeats indefinitely.
* **NES PALRAM capture frame**: must hit a frame BETWEEN glow cycles (not mid-color), to capture the base palette. Probe targets frame 100 (well into stable title display, before subphase 1).

## Testing

1. Build clean (`tools/intro_demo/build.bat`).
2. BizHawk Genesis run with the produced `intro_demo.md`. Probe via Lua at:
   * Frame 50 — title visible, sprites + glow.
   * Frame 600 — mid-fade-out, CRAM intermediate colors visible.
   * Frame 1000 — black hold, CRAM all-zero.
   * Frame 1100 — story bottom edge appearing.
   * Frame 1700 — story held in position.
   * Frame 2200 — items visible, heart/rupee/fairy flash anims active.
3. Visual side-by-side against NES capture PNGs at matching frame numbers; verify glow cycle order, waterfall animation rhythm, fade-out color progression.
4. 5-minute soak test — confirm clean loop, no VRAM corruption, no CRAM bleed.

## Out of Scope

* Active Start-press handling (cosmetic-only "PUSH START BUTTON" per user choice B).
* NES boot-screen blue flash before f0035.
* Music / SFX (intro_demo has no audio path).

## Files Changed / Added

* **Added**: `tools/intro_demo/extract_title_tilemap.py`, `extract_title_bg_chr.py`, `extract_title_sprite_chr.py`, `extract_title_palette.py`, `extract_title_glow.py`, `intro_title.c`, `intro_phase.c`, `intro_phase.h`. Generated `intro_title_tilemap.c`, `intro_title_bg_chr.c`, `intro_title_sprite_chr.c`, `intro_title_palette.c`, `intro_title_glow.c`. Captured `palram_title.bin`.
* **Changed**: `tools/intro_demo/main.c`, `tools/intro_demo/build.bat`.

No changes to main ROM (`src/`) — this is intro_demo only.
