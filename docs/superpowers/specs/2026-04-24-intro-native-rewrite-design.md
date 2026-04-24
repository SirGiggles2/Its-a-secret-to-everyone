# Intro Sequence Native Rewrite — Design

**Date:** 2026-04-24
**Author:** Test
**Status:** Draft (pending user review)
**Scope:** Replace broken transpiled story scroll + broken transpiled item showcase with Genesis-native C modules. Keep existing title + fades untouched.

## Problem Statement

Two long-standing bugs block completion of the Zelda intro sequence:

1. **Story scroll crash** (ref: memory `project_title_story_crash`). Title screen boots correctly, fade-out works, but the story scroll stage crashes partway through. Only known workaround is pressing Start on the title screen to skip the scroll entirely and land in gameplay. The crash has been chased across many sessions with no narrow fix found.
2. **V64 dead zone on item showcase** (ref: memory `project_vfix_dead_zone`). The item showcase scrolls vertically through the curV range $C0–$EF, which in V64 mode exposes a 32-pixel dead zone that BizHawk/GPGX cannot hide. Prior mitigation attempts (mirrors, space-tile fills, post-wrap guards) all failed or made it worse. Only true fixes are V32 mode or a full software scroll buffer.

Both stages share a root property: **they are transpiled from NES 6502 and scroll vertically through a VDP range that exposes Genesis-specific issues.** A piecemeal patch approach has been exhausted. This spec proposes a full native rewrite of the affected stages, keeping the rest of the intro pipeline (title, fades, file select) intact.

## Goals

- Intro runs start-to-finish with **zero input** (no Start press required) and reaches gameplay without crashing.
- Item showcase shows no V64 dead-zone artifacts (no duplicated rows, no tear, no stale content).
- Visual output matches NES reference pixel-for-pixel for font, art, and color (palette mapped from NES to Genesis 9-bit).
- Title screen and fade transitions remain untouched (already working).
- No new regressions in gameplay handoff (mode 2 load → mode 3 unfurl → play).

## Non-Goals

- Rewriting the title screen.
- Rewriting fade-out / fade-in transitions.
- Rewriting file select / name entry / save slot UI.
- Hand-authored editable story text (assets are extracted byte-exact from NES reference).
- Attract-mode demo loop (NES title's idle gameplay demo — out of scope, original plan is to leave current behavior).

## Fidelity Target

Genesis-native implementation with pixel-exact NES content (option B from brainstorm Q1). Same visible output as NES. Wrapper technology is Genesis-native (V32 plane mode, software scroll buffer, no H-int DZ_SKIP hack, no transpiled code path). Assets (font, art, palette) extracted byte-exact from the NES reference ROM at build time.

## Architecture

### Module Layout (new files)

```
src/intro_story.c           # story scroll stage (enter/update/exit)
src/intro_showcase.c        # item showcase stage (enter/update/exit)
src/intro_common.c          # V32 plane setup, CHR DMA, VSRAM helpers, scroll logic
src/intro_common.h          # public API for the three modules
src/gen/intro_story_tilemap.c       # extracted from NES ROM at build time
src/gen/intro_showcase_tilemap.c
src/gen/intro_font_chr.bin
src/gen/intro_art_chr.bin
src/gen/intro_palette.c
tools/extract_intro_assets.py       # NES ROM → Genesis assets
```

### Public Entry Points

```c
void intro_story_enter(void);
unsigned int intro_story_update(void);   // returns 1 when stage done

void intro_showcase_enter(void);
unsigned int intro_showcase_update(void);

void intro_handoff(void);                 // V32 → V64, restore gameplay CHR/palette
```

### Stage Flow

```
[existing title screen + fade-out runs unchanged]
        ↓
  intro_story_enter / intro_story_update
        ↓ (when done)
  intro_showcase_enter / intro_showcase_update
        ↓ (when done)
  intro_handoff
        ↓
[existing fade-in + file select + play runs unchanged]
```

### Module Responsibilities

- **`intro_common`** owns all VDP writes during intro stages. Provides primitives for mode switch, CHR DMA, nametable writes, VSRAM updates, CRAM load. Stages call these exclusively — no raw VDP port writes in stage code.
- **`intro_story`** runs the story scroll. Reads its tilemap + scroll speed constants, drives `intro_common` primitives each frame.
- **`intro_showcase`** runs the item showcase. Same structure as `intro_story` with different assets.
- **Asset files in `src/gen/`** are build-tool outputs. Passive data, never edited by hand.

Shared scroll logic between story and showcase lives in `intro_common` as `intro_scroll_common(tilemap, total_rows, speed)` to avoid duplication.

## Core Technical Decisions

### VDP Mode: V32 for intro, V64 for gameplay

Intro stages use V32 mode (VDP Reg 16 = $9001, plane = 256×256 px, 32 rows tall, no dead zone). Gameplay remains V64 (Reg 16 = $9011). Mode switch happens twice:

- **V64 → V32** during the existing fade-out before story scroll (screen is black, switch is invisible).
- **V32 → V64** during `intro_handoff`, before handing control back to the legacy pipeline. If a fade-in exists between showcase and file select, it runs unchanged under V64.

This kills the V64 dead zone at the root without affecting gameplay code. No DZ_SKIP hack, no H-int split, no VRAM mirror logic needed for intro.

### Software Scroll Buffer (within V32)

Story tilemap exceeds the 32-row V32 plane (NES story is ~80+ rows when stacked vertically). Simple wrap-scrolling: as `g_scroll_pixel >> 3` crosses a row boundary, copy the next source row into the plane row that just scrolled off the top. No dead zone interaction, simple row-copy bookkeeping, one DMA per row boundary crossed (~1/8 frames at 1 px/frame).

### Asset Extraction Pipeline

`tools/extract_intro_assets.py` runs at build time before the transpile stage. Reads the original NES reference ROM and emits Genesis-formatted assets into `src/gen/intro_*`.

**ROM path:** the tool accepts the reference ROM path via CLI arg (e.g., `--nes-rom assets/nes_reference.nes`) or environment variable (e.g., `ZELDA_NES_ROM`). The ROM file is not committed to the repo (licensing); `build.bat` reads the path from a local ignored file (e.g., `.nes_rom_path` — added to `.gitignore`) or from the environment. If the path is absent, the extract tool emits a clear error and the build fails early.

**Known offsets** for font CHR, art CHR, palette table, and each tilemap region are documented inline in the extract tool as hex constants with comments tying each to its NES source. Exact offsets are verified during implementation by comparing emitted assets against NES reference screenshots.

**Conversions performed:**

- **NES CHR (2bpp, 16 bytes/tile) → Genesis CHR (4bpp, 32 bytes/tile)** — direct pixel mapping, upper 2 bitplanes zeroed, tile-for-tile correspondence preserved.
- **NES palette (byte indices 0–63) → Genesis 9-bit RGB** — via canonical NES color LUT (Nesdev reference) quantized to Genesis 3-bit per channel.
- **NES nametable bytes → Genesis nametable words** — `gen_cell = chr_base + nes_tile_idx | (nes_palette << 13)`. Preserves layout pixel-for-pixel.

Build tool validates:
- Combined font + art CHR ≤ 16KB (VRAM budget for intro CHR region)
- Each tilemap total rows ≤ 256 (software buffer wrap assumption)
- Emits SHA of each extracted asset for regression detection

### Integration Hook

Existing `frontend_runtime.c` / `frontdemo_animate_phase_1` dispatch into story scroll is the single replacement point. Current code routes story-scroll subphases via `c_import_animate_demo_phase1_*` into `z_02.asm`. Replaced with:

```c
// before (broken):
case 2: c_import_animate_demo_phase1_subphase2(); break;
// after (native):
case 2: intro_story_tick(); break;
```

`intro_story_tick()` lives in `intro_common.c` with signature `void intro_story_tick(void)`. It owns a small static state (current sub-stage, entered-flag) and dispatches `intro_story_update` / `intro_showcase_update` / `intro_handoff` in sequence. One-shot enter-if-first on each sub-stage transition. When `intro_handoff` completes, it flips existing FRONTEND state forward (e.g., by incrementing `SUBMODE_VALUE` or the equivalent legacy advance step — exact flip identified during implementation) so the legacy pipeline proceeds.

### VRAM Map During Intro

```
$0000–$3FFF   Intro CHR (font + art, 16 KB, 1024 tiles at 4bpp)
$4000–$47FF   Plane A nametable (32×32)
$4800–$4FFF   Plane B nametable (unused during intro)
$5000–$57FF   Window nametable (unused)
$5800–$59FF   HScroll table
$5C00–$5FFF   Sprite attribute table
$6000–$FFFF   Free
```

CRAM: 4 palettes × 16 colors, all loaded once in `intro_story_enter`.

### Frame Budget

Per-frame intro cost during scroll:

- Row copy (on 1-in-8 frames): 64 bytes via DMA ≈ 100 μs
- VSRAM write (every frame): 2 writes ≈ 1 μs
- Input read + state update: negligible
- **Total:** well under 1% of the 16.7 ms frame budget.

## Data Flow

```
vsync arrives
  → intro_story_update() (or intro_showcase_update, or intro_handoff)
      ├─ read CAVE_LINK_INPUT_FLAGS (unused for stage advance; idle path only)
      ├─ g_scroll_pixel += SCROLL_SPEED
      ├─ vdp_set_vscroll(g_scroll_pixel)
      ├─ if row-boundary crossed:
      │    vdp_write_nametable_row(plane_row, next_source_row)
      │    g_scroll_row_source++
      └─ if end reached: return 1 (done)
  → caller advances to next stage or hands back to legacy pipeline
```

## Error Handling

- **Build-time asset size checks.** Extract tool fails build if CHR > 16 KB or tilemap > 256 rows.
- **Runtime invariants** (debug builds only): `g_scroll_row_source ≤ story_total_rows`, plane row index wraps cleanly. Assertions elided in release.
- **No runtime recovery paths.** Assets are static and baked; can't fail at runtime.

## Testing

### Primary: Idle Run

Boot ROM with zero input for entire intro sequence. Pass criteria:
- `MODE_VALUE` reaches gameplay mode (mode 2 or later) without hanging, resetting, or crashing.
- Intro completes end-to-end: title → fade-out → story → showcase → handoff → fade-in → file select.

### Visual Parity

BizHawk Lua probe captures 10 checkpoint frames during intro:
1. Title screen stable (unchanged, smoke test)
2. Fade-out complete (black screen)
3. Story scroll start
4. Story scroll mid
5. Story scroll end
6. Showcase start
7. Showcase mid
8. Showcase end
9. Handoff (V32 → V64 transition clean)
10. File select visible (unchanged, smoke test)

Pixel-diff each checkpoint against NES reference captures. Pass criteria: < 1% mismatch per checkpoint (matches existing T34 parity harness threshold tradition).

### V64 Dead Zone Regression

Capture 60 consecutive frames during showcase scroll. Inspect plane rows 60–63 region. Pass criteria: no stale content, no duplicated rows, no tear. (Since showcase runs under V32, there is no dead zone region to inspect — this test primarily validates the mode switch happened correctly.)

### Frame Budget

Instrumented build measures `intro_story_update()` wall-clock per frame. Pass criteria: < 200 μs per frame.

### Asset Extraction Validation

Build tool emits SHA of each extracted asset. SHAs committed to repo. Rebuild diffs SHAs to detect accidental asset regression (e.g., offset drift in the extraction tool).

## Open Questions

None at design-sign-off time. Any residual questions surface in the writing-plans skill and are resolved there.

## Deletion (Follow-up, Separate Commit)

After green build and passing tests, separate commit removes now-unreachable transpiled code:

- `z_02.asm` story/showcase subphase functions (`AnimateDemoPhase1Subphase2/3/4` and callees)
- Corresponding `c_import_animate_demo_phase1_subphase*` shims in `c_shims.asm`
- `frontend_runtime.c` dispatch cases that called those shims

This deletion is not part of the initial implementation plan — it's a cleanup pass once the rewrite is proven stable.

## References

- Memory: `project_title_story_crash` — story scroll crash background
- Memory: `project_vfix_dead_zone` — V64 dead zone full analysis and prior fix attempts
- Memory: `feedback_full_native_rewrite` — user preference for native rewrites over patching transpiled visuals
- Memory: `project_title_screen_goal` — pixel-perfect title screen long-term goal (relevant sibling)
- Commits: 98fe5f56, 88632506 — existing native YM2612/PSG music player (reused during intro, not rewritten)
