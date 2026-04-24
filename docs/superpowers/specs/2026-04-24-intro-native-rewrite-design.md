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

## Scope Caveat

"Title + fades untouched" refers to their **logic** — title palette cycle, "PUSH START" blink, fade-out sequencing, and fade-in sequencing all remain as-is. However, the rewrite **does** touch the frontend ↔ VDP boundary in two ways the legacy code does not assume today:

1. VDP Reg 16 is flipped V64 ↔ V32 during fade-out / `intro_handoff`.
2. `frontdemo_init_demo_phase_1` and `frontdemo_animate_phase_1` dispatchers gain a takeover short-circuit that bypasses legacy phase-1 subphases while intro owns the screen.

Both are narrow, contained, and documented in the Integration Hook section. No legacy phase-0 code, no title code, and no post-showcase fade/file-select code is modified.

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

void intro_handoff(void);                 // V32 → V64, restore file-select CHR/palette
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

### Build Integration

`build.bat` requires concrete changes to incorporate the new modules and asset pipeline. Current build wiring:

- [build.bat:104](build.bat:104) compiles a fixed `C_SOURCES` list.
- [build.bat:113](build.bat:113) compiles a fixed `C_GEN_SOURCES` list (gen-forwarder files).
- [build.bat:134](build.bat:134) runs `tools/emit_gen_wrappers.py --check` as a gate.

**Changes required:**

1. **Pre-compile step — run asset extractor.** Before the `C_SOURCES` compile loop, add:
   ```
   echo [2a.0/4] Extracting intro assets from NES reference ROM...
   "%PYTHON%" "%ROOT%\tools\extract_intro_assets.py" --nes-rom "%ZELDA_NES_ROM%" --out-dir "%ROOT%\src\gen"
   if errorlevel 1 exit /b 1
   ```
   `ZELDA_NES_ROM` env var is set by a pre-build shim (or read from `.nes_rom_path` local file). Extract tool is idempotent — re-runs only if NES ROM mtime > output mtime.

2. **Register new C modules.** Append `intro_common intro_story intro_showcase` to `C_SOURCES` at [build.bat:104](build.bat:104). These compile from `src/intro_*.c` into `C_OBJS` via the existing loop — no new loop logic needed.

3. **Register generated C asset file.** Append `intro_story_tilemap intro_showcase_tilemap intro_palette` to `C_GEN_SOURCES` at [build.bat:105](build.bat:105). The extract tool emits each as a `.c` file in `src/gen/` compatible with the existing `C_GEN_SOURCES` loop.

4. **Ingest binary CHR blobs.** `intro_font_chr.bin`, `intro_art_chr.bin`, and `intro_restore_chr.bin` are raw binary. Embed via one of:
   - Extractor emits a wrapping C file (`intro_font_chr.c`) with `const unsigned char intro_font_chr[] = { ... };` — fits the existing `C_GEN_SOURCES` model (preferred, zero new build wiring).
   - Or: add an `objcopy --rename-section .data=.rodata -I binary -O elf32-m68k` step per `.bin` file and link the resulting `.o` into the ELF.

   Preferred approach: emit `.c` wrappers from the extract tool. Keeps build.bat changes minimal.

5. **Asset validation gate.** After extraction, optionally add `tools/extract_intro_assets.py --verify` as a second call to re-check SHA hashes of emitted assets against committed reference SHAs (`src/gen/intro_asset_hashes.txt`). Fails build if assets drift.

No other build wiring needs to change. Linker script, ELF layout, and objcopy step remain as-is because new objects slot into `%C_OBJS%` the same way existing ones do.

### Integration Hook

Phase-1 progression in the current code is split across **two dispatchers**, both of which the intro rewrite must interpose on:

- `frontdemo_init_demo_phase_1()` ([src/frontend_runtime.c:145](src/frontend_runtime.c:145)) runs story-prep subphases (0 = clear artifacts, 1 = transfer story palette, 2 = transfer story tiles).
- `frontdemo_animate_phase_1()` ([src/frontend_runtime.c:291](src/frontend_runtime.c:291)) runs story-scroll + item-showcase animation subphases (0/1/2/3/4).

A single-case swap in either dispatcher does **not** own the full story → showcase → handoff progression. The rewrite takes control at the earliest story-related subphase and holds it through handoff.

**Takeover mechanism:** a static flag `g_intro_takeover` (owned by `intro_common.c`) is armed when the first story-related subphase in `frontdemo_init_demo_phase_1` is reached. While armed, **both** dispatchers short-circuit to `intro_story_tick()` for every phase-1 subphase. Legacy phase-1 subphase handlers (`c_import_init_demo_subphase_clear_artifacts`, `c_import_init_demo_subphase_transfer_story_palette`, `c_import_init_demo_subphase_transfer_story_tiles`, `c_import_animate_demo_phase1_subphase0..3`, `frontdemo_animate_demo_phase1_subphase4`) are **not called** for the duration of the intro takeover.

```c
void frontdemo_init_demo_phase_1(void) {
    if (g_intro_takeover || intro_should_take_over()) {
        intro_story_tick();
        return;
    }
    switch (FRONTEND_DEMO_SUBPHASE) {
        case 0: c_import_init_demo_subphase_clear_artifacts(); break;
        case 1: c_import_init_demo_subphase_transfer_story_palette(); break;
        case 2: c_import_init_demo_subphase_transfer_story_tiles(); break;
        default: break;
    }
}

void frontdemo_animate_phase_1(void) {
    if (g_intro_takeover) {
        intro_story_tick();
        return;
    }
    switch (FRONTEND_DEMO_SUBPHASE) {
        case 0: c_import_animate_demo_phase1_subphase0(); break;
        /* …remaining legacy cases… */
    }
}
```

`intro_should_take_over()` is a one-shot predicate that returns 1 the first time the init-phase-1 handler is entered during phase 1 (i.e., `RAM(0x042C) != 0`), then arms `g_intro_takeover`.

`intro_story_tick()` lives in `intro_common.c` with signature `void intro_story_tick(void)`. It owns a small static state (current sub-stage enum, entered-flag) and dispatches `intro_story_enter/update` → `intro_showcase_enter/update` → `intro_handoff` in sequence. One-shot enter-if-first on each sub-stage transition. When `intro_handoff` completes, it:
1. Clears `g_intro_takeover` (dispatchers return to legacy behavior)
2. Advances `FRONTEND_DEMO_SUBPHASE` / `SUBMODE_VALUE` / `MODE_VALUE` to the exact legacy state the pipeline expects post-showcase (exact state captured during implementation by reading the values the legacy flow would have arrived at had the original subphase chain completed)

State-capture step is done once during implementation: run legacy code (with Start-skip workaround to avoid the crash) and snapshot the FRONTEND state at the moment showcase-end would occur. Bake those values into a constant initializer used by `intro_handoff`.

### Handoff Details

`intro_handoff()` restores the **file-select / frontend state**, not gameplay state. Gameplay CHR and palette are loaded by the existing mode-2 / mode-3 path when the player selects a save slot — the rewrite does not touch that path.

Handoff steps:

1. Switch VDP Reg 16 to V64 ($9011).
2. DMA the file-select restore CHR (`intro_restore_chr`) to VRAM. This blob is captured once during implementation by snapshotting VRAM state at the point the legacy flow reaches file select (with Start-skip workaround). Baked into `src/gen/intro_restore_chr.c` at build time.
3. Reload the file-select CRAM snapshot (`intro_restore_palette`), captured the same way.
4. Reset VSRAM to the value the legacy frontend assumes post-showcase.
5. Clear plane A + B nametables to their expected post-showcase state (typically zero; confirmed during implementation).
6. Advance `FRONTEND_DEMO_SUBPHASE` / `SUBMODE_VALUE` / `MODE_VALUE` to the exact values the legacy pipeline would hold post-showcase. These values are captured in the same snapshot pass and stored as constants in `intro_handoff_state.h`.
7. Clear `g_intro_takeover`.

After step 7, legacy dispatchers return to their normal switch statements and the legacy fade-in / file-select pipeline runs unchanged under V64.

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
