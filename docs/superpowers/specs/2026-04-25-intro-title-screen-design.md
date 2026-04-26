# Intro Title Screen — Design

**Date:** 2026-04-25 (revised 2026-04-26 incorporating Codex review)
**Scope:** `tools/intro_demo/` standalone Genesis ROM
**Goal:** Add the NES Zelda title screen (logo + vines + sword/Triforce + Triforce glow + waterfall sprite animation + "PUSH START BUTTON" text) before the existing story/items sequence, with NES-faithful look and **measured-visible-timing-first** pacing. The full sequence loops indefinitely.

## Non-Goals

Out of scope:

* Active Start-button input handling (cosmetic "PUSH START BUTTON" only).
* Music / SFX.
* Reworking the existing story / item runtime timing unless title integration forces a narrow correction.
* Cycle-accurate reproduction of every NES internal routine.
* NES boot-screen blue flash before f0035.

## Background

NES timing reference (user-supplied frame numbers from `tools/intro_demo/nes_loop/`):

| Frame | Event |
|-------|-------|
| f0035 | Title appears (post-boot blue/black). |
| f0555 | Title fade-out begins. |
| f0785 | Screen fully black. |
| f1040 | Story first appears (top row at bottom of screen). |
| f1445 | Story stops in position. |
| f1705 | Story scroll-off begins. |

The current intro_demo has a 4-level mask fade-in into the story scroll. The user wants to replace that with the full attract loop beginning at the title screen.

NES source references (verified, no guessing):

* `Z_02.asm:213 UpdateMode0Demo_Sub0` — Start press handler (we do not act on input).
* `Z_02.asm:342 InitialTitleSprites` — 28 title sprites (112 bytes, Y/tile/attr/X format).
* `Z_02.asm:944 TriforcePaletteTransferRecord` = `$3F $04 $04 $36 $17 $27 $0F $FF` — sets BG pal 1 to `$36 $17 $27 $0F` at PALRAM `$3F04`.
* `Z_02.asm:947 TriforceGlowingColors` — `$27 $37 $37 $27 $17 $07 $07 $17` glow cycle (8 colors).
* `Z_02.asm:973-975` — patches byte `+5` of the transfer record with the glow color, i.e. PALRAM offset `$3F04 + 2 = $3F06` = **NES BG pal 1 color 2**.
* `Z_02.asm:950 AnimateDemoPhase0Subphase0Artifacts` — drives sprite copy, glow timer (6 frames per color, 16-frame end hold), waterfall update.
* `Z_02.asm:990 WaterfallWaveTiles` / `:993 WaterfallCrestTiles` — 4-tile cycles for waterfall sprite animation.
* `Z_02.asm:1111 DemoPhase0Subphase1Palettes` — 14 × 32-byte palette progression used for title fade-out.
* `Z_02.asm:1179 DemoPhase0Subphase1Delays` — `$08 $08 $06 $05 $04 $03 $02 $02 $02 $C0 $06 $04 $C0 $03` (sum = 437 frames; **not used unmodified — see Timing Policy**).
* `reference/aldonunez/dat/GameTitleTransferBuf.dat` — NES title nametable as transfer-record stream (1121 bytes).

## Timing Policy

The plan targets **measured visible timing** first, not direct copies of NES internal delay tables.

**Title bright hold.** Title should already be fully visible by f0035 and the fade should begin near f0555 → bright-hold target ≈ 520 frames. Tune to land on the measured fade-start point, not copy NES internal routine timing.

**Title fade.** The raw 14-cycle NES delay table sums to 437 frames, which is too long for the measured ~230-frame fade. **Keep the NES palette progression order from `DemoPhase0Subphase1Palettes` unchanged, but compress the per-step delays** so the total fade lands close to the measured 230 frames. This preserves the visual color progression while matching observed attract-mode timing. Compressed delay table is emitted by `extract_title_fade.py` and lives in `intro_title_fade.c`.

**Black hold before story.** After the fade reaches black (cycle 13), remain black long enough that story first becomes visible at about f1040 (i.e. ~255 frames of black hold beyond the end of the fade). This is a visible-timing requirement, not a direct NES-routine requirement.

**Story / item sequence.** Keep current Genesis story/item runtime timing logic intact unless a narrow adjustment is required to align with the measured story entry point. The existing behavior is acceptable and should not be reinterpreted as part of this work.

## Phase State Machine

```
PHASE_TITLE_LOAD               -> display off, full title CHR/CRAM/plane/sprite upload, display on
PHASE_TITLE_DISPLAY  (~520 fr) -> title BG + glow CRAM patch + waterfall sprite cycle + "PUSH START"
PHASE_TITLE_FADEOUT  (~230 fr) -> NES DemoPhase0Subphase1 palette PROGRESSION, delays COMPRESSED
PHASE_BLACK_HOLD     (~255 fr) -> CRAM all-black, plane unchanged
PHASE_STORY_LOAD               -> display off, full story CHR/CRAM/plane upload + flash slots, display on
PHASE_STORY_SCROLL_IN          -> story streams in from below (existing logic)
                                  ends when pixel_count >= STORY_SCROLL_TARGET (216)
PHASE_STORY_HOLD     (260 fr)
PHASE_SCROLL_OFF               -> existing scroll loop, item flash anims (heart/rupee/triforce/fairy)
PHASE_END_PAUSE      (180 fr)  -> hold at TRIFORCE/sign rows
[loop -> PHASE_TITLE_LOAD]
```

State variable `intro_phase` (u8) plus per-phase frame counter. Transition writes new phase value and resets counter. Phase entry hooks load any one-shot CRAM/VRAM updates.

`PHASE_BLACK_HOLD` exists explicitly so that we can tune the visible black-screen duration independently of fade-end.

## VRAM / CRAM Policy

Two distinct content layouts (title vs story). The load phases are **NOT** single-vblank swaps. The rule:

1. Disable display (`VDP_CTRL_WORD = 0x8134`).
2. Perform the full title or story uploads while the screen is black.
3. Re-enable display (`VDP_CTRL_WORD = 0x8174`) after upload + initialization state are complete.

Uploads may consume a full frame or more of wall-clock time, but because they occur while the screen is black, they are visually acceptable and close to the NES transition behavior.

### Title layout
| VRAM | Contents |
|------|----------|
| `$0000` | Title BG CHR (subset of `CommonBackgroundPatterns.dat` — vines, logo letters, sword graphic) |
| `$2000` | Title sprite CHR (sword, bird, "PUSH START" font glyphs, waterfall tiles) |
| `$C000` | Plane A: title nametable from `GameTitleTransferBuf.dat`, 32×30 cells |
| Sprite list | Genesis sprite list at fixed VRAM address; ~28 title + ~12 waterfall sprites |

### Story layout (current setup, unchanged)
| VRAM | Contents |
|------|----------|
| `$0000` | story common BG CHR |
| `$0E00` | story font CHR |
| `$1E40` | misc CHR (Gen tiles 242-255) |
| `$2000` | sprite CHR (Gen tiles 256-511) |
| `$4000` | punct CHR (Gen tiles 512-513) |
| `$4040` | blink CHR (Gen tiles 514-521) |

`PHASE_STORY_LOAD` re-uploads the story layout (title→story transition). `PHASE_TITLE_LOAD` performs the reverse (story→title or initial boot).

## Story Handoff Requirements

**Critical preservation rule.** `PHASE_STORY_LOAD` must restore the exact initialization state that the current intro boot path relies on:

* same story / treasures CHR uploads
* same combined-palette upload
* same heart-flash CRAM-slot writes (pal 2 / pal 3 slots 9-11) so the item flash anims work
* same initial plane contents (first 32 stream rows pre-written)
* same `scroll`, `last_row`, `next_source_row`, `pixel_count` reset
* same `story_hold`, `end_pause` initial state

After `PHASE_STORY_LOAD`, the story runtime should behave like the current ROM just finished booting into its known-good path. No reinterpretation of story/item timing.

## Looping Behavior

At the end of the current story/item/end-pause sequence:

* Do not instant-reset directly into story again.
* Transition to `PHASE_TITLE_LOAD`.
* Clear title runtime counters and story runtime counters independently so the second loop matches the first.
* Reload title assets and restart the full attract loop.

The existing story/item reset logic is reused internally, but the visible loop destination changes from "story restart" to "title restart".

## Asset Extraction

New Python scripts under `tools/intro_demo/`, all run from `build.bat`:

1. **`extract_title_tilemap.py`** — parse `GameTitleTransferBuf.dat` as a sequence of NES VRAM transfer records (`[high_addr, low_addr, count, ...data, $FF]`); reconstruct 32×30 nametable + 64-byte attribute table; emit Genesis tilemap with per-cell palette field. Output `intro_title_tilemap.c`.

2. **`extract_title_bg_chr.py`** — identify the unique tile indices used by the parsed title nametable; pull each from `CommonBackgroundPatterns.dat`; re-encode 2bpp→4bpp Genesis (no color shift; BG tiles reference slots 0-3 of cell's palette directly). Output `intro_title_bg_chr.c`.

3. **`extract_title_sprite_chr.py`** — for each unique tile referenced by `InitialTitleSprites` + `WaterfallWaveTiles` + `WaterfallCrestTiles`, pull from `CommonSpritePatterns.dat`; re-encode 2bpp→4bpp with `color_shift=4`. Output `intro_title_sprite_chr.c`.

4. **`extract_title_palette.py`** — runs a BizHawk Lua probe against the NES Zelda ROM, advances to a stable title frame (e.g. frame 100, before subphase 1 starts), dumps PALRAM (32 bytes), saves `palram_title.bin`. Python step converts each NES color via `nes_color_to_gen_cram` into a 64-word Gen palette layout matching `intro_combined_palette` packing. Output `intro_title_palette.c`.

5. **`extract_title_fade.py`** — emit the 14-step title fade palette progression from `DemoPhase0Subphase1Palettes`, AND a compressed Genesis delay table tuned to the ~230-frame measured fade target (preserves NES progression order, reduces per-step delay so the sum matches measured visible duration). Output `intro_title_fade.c` containing both `intro_title_fade_cycles[14][64]` (Genesis CRAM words) and `intro_title_fade_delays[14]`.

6. **`extract_title_glow.py`** — emit `intro_title_glow.c` with the 8 Gen-CRAM-converted glow colors and the per-color delays (6 frames each, 16 for the final color, per `Z_02.asm:976-983`).

`build.bat` runs these in sequence before compile + link.

## Runtime Components

New files:

* `tools/intro_demo/intro_phase.h` — phase enum + public entry points.
* `tools/intro_demo/intro_phase.c` — top-level phase machine. Owns transitions and dispatches title vs story runtimes.
* `tools/intro_demo/intro_title.h` — title runtime entry points and shared constants.
* `tools/intro_demo/intro_title.c` — title load, per-frame glow, per-frame waterfall animation, title fade driver.

Existing files preserved in behavior:

* `tools/intro_demo/main.c` — shrinks to setup + `for (;;) { wait_vblank(); intro_phase_step(); }`. Existing story / item logic moves into a story runtime path with **minimal behavioral changes**. Preserve scroll counters, row-streaming logic, flash logic, and loop reset behavior as-is wherever possible.

* `tools/intro_demo/build.bat` — add generate + compile + link steps for new assets and runtime modules.

## Triforce Glow

Keep the NES color order and timing model. **Correct destination slot:** NES patches PALRAM `$3F06` = **BG pal 1 color 2**. Genesis equivalent: patch **Gen pal 1 slot 2**.

Implementation rule:

* Advance glow color every 6 frames.
* Hold the terminal color for 16 frames.
* Wrap and repeat.

Per-vblank step writes one CRAM word: `cram_write_one(1*16 + 2, intro_title_glow_colors[glow_cycle])` only when the timer expires. No full palette upload.

## Waterfall Animation

Title-only sprite update; does not share state with the story/item runtime.

* Maintain a title-local waterfall frame counter.
* Every 8 frames, rotate waterfall sprite tile IDs.
* Use the 4-tile cycles from `WaterfallWaveTiles` and `WaterfallCrestTiles`.

Specific Genesis sprite-list slots are reserved for the wave + crest sprites at title load time; tile fields rotate per cycle.

## Edge Cases

* **Display-off upload budget**: acceptable because the screen is black; do not constrain to a single VBlank.
* **CRAM contamination**: the title fade overwrites all 64 CRAM words. `PHASE_STORY_LOAD` must restore the heart-flash slots (pal 2 / pal 3 slots 9-11) along with the story palette.
* **Loop cleanliness**: title counters and story counters reset separately so the second loop matches the first.
* **Sprite count budget**: ~28 title sprites + ~12 waterfall sprites = 40, well under Genesis's 80-per-frame limit.
* **Timing drift**: final tuning is based on capture comparison, not guessed constants; constants live in named `#define`s for easy adjustment.
* **NES PALRAM capture frame**: must hit a frame BETWEEN glow cycles (not mid-color), to capture the base palette. Probe targets ~frame 100.

## Testing

1. Build clean with `tools/intro_demo/build.bat`.
2. Run on BizHawk Genesis and capture frames around:
   * f0035 — title visible.
   * f0555 — fade begins.
   * f0785 — full black.
   * f1040 — story first visible.
   * f1445 — story settled.
   * f1705 — story scroll-off starts.
3. Side-by-side compare against NES captures for: title composition, glow order and hold timing, waterfall rhythm, fade progression, title-to-story pacing.
4. Confirm existing story/item behavior still matches its current known-good output (no regressions in scroll-in, hold, flash anims, end pause, item appearance).
5. 5-minute soak test — verify clean looping with no VRAM/CRAM corruption.

## Files Added / Changed

**Added (Python generators)**
* `tools/intro_demo/extract_title_tilemap.py`
* `tools/intro_demo/extract_title_bg_chr.py`
* `tools/intro_demo/extract_title_sprite_chr.py`
* `tools/intro_demo/extract_title_palette.py`
* `tools/intro_demo/extract_title_fade.py`
* `tools/intro_demo/extract_title_glow.py`

**Added (runtime)**
* `tools/intro_demo/intro_title.c`
* `tools/intro_demo/intro_title.h`
* `tools/intro_demo/intro_phase.c`
* `tools/intro_demo/intro_phase.h`

**Generated (committed alongside source per existing pattern)**
* `intro_title_tilemap.c`
* `intro_title_bg_chr.c`
* `intro_title_sprite_chr.c`
* `intro_title_palette.c`
* `intro_title_fade.c`
* `intro_title_glow.c`
* `palram_title.bin`

**Changed**
* `tools/intro_demo/main.c`
* `tools/intro_demo/build.bat`

**Preserved in behavior**
* current story scroll path
* current item scroll path
* current item flash behavior (heart, rupee, triforce, fairy)
* current end-pause logic
