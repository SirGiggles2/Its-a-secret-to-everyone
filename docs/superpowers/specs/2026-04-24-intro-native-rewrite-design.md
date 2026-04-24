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
- Visual output matches NES reference at designated checkpoints (visually matched — same font, same art, same palette intent). Pixel-perfect equivalence is not a goal; plane mode, palette quantization, and tile format differ, so exact-byte frame diffs are not expected. Success is measured by visual inspection of reference captures plus a structural mismatch threshold (see Testing).
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

Genesis-native implementation with NES-sourced content (option B from brainstorm Q1). Same *visible* output as NES at designated checkpoints — same font glyphs, same art tiles, same palette intent. Wrapper technology is Genesis-native (V32 plane mode, software scroll buffer, no H-int DZ_SKIP hack, no transpiled code path). Assets are derived from the existing disassembly reference data already in the repo (see Asset Source below) — not from an external NES ROM.

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

- **`intro_common`** owns intro-stage VDP access. It is a **thin C wrapper around the existing VDP primitives in `genesis_shell.asm`** (`VDP_CTRL = $00C00004`, `VDP_DATA = $00C00000`, plus the register-write sequence at [genesis_shell.asm:220](src/genesis_shell.asm:220)). It does **not** establish a parallel VDP path and does **not** duplicate VDP ownership. The wrapper exposes typed C entry points (`vdp_set_mode_v32`, `vdp_dma_to_vram`, `vdp_write_nametable_row`, `vdp_set_vscroll`, `vdp_load_cram`) that are implemented either as direct writes to the shared `VDP_CTRL`/`VDP_DATA` constants or as calls into the existing asm helpers. Stages call `intro_common` exclusively — no raw VDP port writes in stage code. During the intro takeover window, nothing else writes the VDP; legacy writers (`frontend_runtime.c` phase-1 subphases) are short-circuited per the Integration Hook section.
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

### Asset Source

**Source of truth is the existing committed disassembly reference data in `reference/aldonunez/dat/`, not an external NES ROM.** This matches the repo's current pattern (e.g., `src/nes_io.asm` and `tools/transpile_6502.py` consume this same reference tree). Relevant files for intro:

- `reference/aldonunez/dat/DemoBackgroundPatterns.dat` — background CHR for story screen
- `reference/aldonunez/dat/DemoSpritePatterns.dat` — sprite CHR for intro
- `reference/aldonunez/dat/DemoTextFields.dat` — story text strings
- `reference/aldonunez/dat/DemoLineTextAddrs.inc` — text field address table
- `reference/aldonunez/dat/StoryTileAttrTransferBuf.dat` — palette-attribute strip
- `reference/aldonunez/dat/GameTitleTransferBuf.dat` — title-related buffer (inspect for showcase relevance)

The extract tool processes only these files. No external ROM path, no env var, no local ignore file. If a required `.dat` / `.inc` file is missing or unexpectedly sized, the tool fails the build with a clear error.

### Asset Extraction Pipeline

`tools/extract_intro_assets.py` runs at build time before the C compile stage. Reads the reference data files listed above and emits Genesis-formatted assets into `src/gen/intro_*`.

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

### Handoff State Bytes (Authoritative)

The legacy fade-in / file-select pipeline resumes from a specific RAM state. The rewrite must restore **exactly** these bytes to the values they would hold at the moment the legacy (Start-skipped) flow reaches file select:

| Address / symbol          | Current owner            | Expected post-showcase value | Source of truth             |
|---------------------------|--------------------------|------------------------------|-----------------------------|
| `MODE_VALUE`              | Global mode dispatcher   | TBD — captured at runtime    | `bizhawk_intro_state_probe.lua` |
| `SUBMODE_VALUE`           | Within-mode submode      | TBD — captured at runtime    | same                        |
| `FRONTEND_DEMO_SUBPHASE`  | Phase-1 subphase counter | TBD — captured at runtime    | same                        |
| `RAM(0x042C)`             | Phase-1 flag             | TBD — captured at runtime    | same                        |
| `RAM(0x042B)`             | `FrontendStartReleaseGate` | TBD — captured at runtime  | same                        |
| `RAM(0x083D)`             | `VRamForceBlankGate`     | TBD — captured at runtime    | same                        |
| `RAM(0x0528)`             | Frontend delay timer     | TBD — captured at runtime    | same                        |
| `ROOM_MODE_TIMER`         | Mode-progression timer   | TBD — captured at runtime    | same                        |
| `ITEM_SFX_SECONDARY`      | SFX secondary channel    | TBD — captured at runtime    | same                        |
| `ROOM_TRANSFER_BUF_SELECT`| Transfer buffer select   | TBD — captured at runtime    | same                        |

**Capture procedure** (one-time, during implementation task P0):
1. Build a debug ROM with Start-skip path traced.
2. Run `tools/bizhawk_intro_state_probe.lua` (already exists) — arm it to freeze execution the moment the flow arrives at file-select entry.
3. Dump the RAM addresses above.
4. Bake the captured values into `src/gen/intro_handoff_state.c` as a named const struct, e.g.:
   ```c
   const intro_handoff_state_t INTRO_HANDOFF_EXPECTED = {
       .mode_value = 0x??, .submode_value = 0x??, /* … */
   };
   ```
5. `intro_handoff()` writes these exact values as its final act before clearing `g_intro_takeover`.

If the probe reveals the list above is incomplete (other RAM bytes also differ between "before story" and "after showcase"), the table is extended before implementation proceeds. The capture pass is the authoritative answer, not this spec.

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

### Frame Budget (Estimate — must be measured during implementation)

Per-frame intro cost during scroll, **estimated** (not measured from current toolchain; numbers below are order-of-magnitude guidance, not proof):

- Row copy (on 1-in-8 frames): 64 bytes via DMA ≈ ~100 μs (estimate)
- VSRAM write (every frame): 2 writes ≈ ~1 μs (estimate)
- Input read + state update: assumed negligible

These numbers are unverified. The implementation plan must include an instrumented measurement task that records actual wall-clock per frame for `intro_story_update()` and `intro_showcase_update()` on the real toolchain. If measured cost exceeds 1 ms per frame, the design revisits the row-copy strategy (batch rows, use longword DMA, or offload to vblank slice).

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

Test plan reuses **existing probe/capture tools** in `tools/`. No new generic "BizHawk probe" is invented — every test names a concrete existing script or a named replacement.

### Primary: Idle Run (no-crash)

Boot ROM with zero input for entire intro sequence. Tool: `tools/bizhawk_capture_intro_sequence.lua` + `tools/analyze_intro_continuity.py` (both already in repo). Pass criteria:
- `MODE_VALUE` reaches gameplay-entry mode without hanging, resetting, or crashing.
- Intro completes end-to-end: title → fade-out → story → showcase → handoff → fade-in → file select.
- `tools/analyze_intro_continuity.py` reports no stall frames in the story/showcase window.

### Visual Parity (Checkpoint Capture)

Tool: `tools/bizhawk_capture_intro_sequence.lua` (NES side) + `tools/bizhawk_capture_intro_window.lua` (Gen side) to capture matched checkpoint frames. Analyzer: `tools/analyze_intro_scroll_window.py`.

Checkpoints:
1. Title screen stable (smoke test, should be unchanged)
2. Fade-out complete (black screen)
3. Story scroll start
4. Story scroll mid
5. Story scroll end
6. Showcase start
7. Showcase mid
8. Showcase end
9. Handoff moment (V32 → V64 transition, expect a 1-frame transition artifact allowance)
10. File select visible (smoke test, should be unchanged)

**Pass criteria:** visual inspection of each matched pair shows the same font glyphs, same art layout, same palette intent. Structural mismatch threshold ≤ 5% per checkpoint (looser than the T34 threshold because plane mode and palette quantization differ by design). Checkpoints 1 and 10 — which the rewrite does not touch — still hold to ≤ 1% mismatch as a regression guard.

### V64 Dead Zone Regression Guard

Tool: `tools/bizhawk_intro_vram_dump.lua` captures 60 consecutive frames' VRAM state during showcase scroll. Pass criteria: no stale content appears in the display window, no duplicated rows, no tear. (Since showcase runs under V32, the dead zone region does not exist during showcase — this test primarily validates the V64 → V32 mode switch actually took effect.)

### Frame Budget (Measurement Task)

Instrumented build measures `intro_story_update()` + `intro_showcase_update()` wall-clock per frame. Tool: extend `tools/bizhawk_sweep_story.lua` to timestamp entry/exit of the intro update functions. Pass criteria: < 1 ms per frame (design allowance). If measurement > 1 ms, revisit row-copy strategy per Frame Budget note above.

### Handoff State Verification

Tool: `tools/bizhawk_intro_state_probe.lua` captures RAM at the moment `intro_handoff` returns. Compares byte-for-byte against `INTRO_HANDOFF_EXPECTED` table (the same values baked into `intro_handoff_state.c`). Pass criteria: exact match — any delta means the legacy pipeline will see a different state than before the rewrite, which is a regression.

### Asset Extraction Validation

Build tool emits SHA of each extracted asset (`src/gen/intro_asset_hashes.txt`). SHAs committed to repo. Rebuild diffs SHAs to detect accidental asset regression (e.g., offset drift in the extractor or a corrupted `reference/aldonunez/dat/` file).

## Open Questions

None at design-sign-off time. Any residual questions surface in the writing-plans skill and are resolved there.

## Deletion (Follow-up, Gated Cleanup — Separate Commit)

After green build and passing all tests above, a separate commit may remove now-unreachable transpiled code. **This deletion is gated** — it does not proceed without both of the following:

### Gate 1: Static Unreachability Proof

A grep-based path map confirms none of the following legacy entry points are referenced except from within their own call graph:
- `AnimateDemoPhase1Subphase2`, `AnimateDemoPhase1Subphase3`, `AnimateDemoPhase1Subphase4` (in `z_02.asm` and the C forwarders in `src/gen/z_02.c`)
- `c_import_animate_demo_phase1_subphase0..3` (in `c_shims.asm`)
- `c_import_init_demo_subphase_clear_artifacts`, `c_import_init_demo_subphase_transfer_story_palette`, `c_import_init_demo_subphase_transfer_story_tiles` — note these may still be reached by phase-0 paths or other call sites; unreachability must be established per-symbol, not assumed.
- `frontdemo_animate_demo_phase1_subphase4` (in `frontend_runtime.c`) — this one is native C but only called from the about-to-be-short-circuited dispatcher.

Each symbol is grepped across `src/`, `tools/`, and `reference/`. If any reference remains outside the rewrite-owned takeover path, the symbol is **not** deleted in this pass.

### Gate 2: Runtime Path-Map Proof

Tool: extend `tools/bizhawk_intro_hook_probe.lua` (already exists) to instrument the legacy symbol entry addresses with a touched-flag. Run the passing idle-run test end-to-end. After the run, verify every candidate-for-deletion symbol has zero touched-flag increments. A symbol with a positive count is in use by the live path and must not be deleted.

### What This Gate Prevents

Many legacy phase-1 subphases perform palette prep, sound cue, or state setup that the rewrite might silently depend on (for example, a shared init that happens during fade-out and stashes data in a global). Deleting such a symbol before the runtime path map confirms unreachability would remove a hidden dependency and break the very handoff this rewrite is trying to make clean.

### Execution

Only when both gates pass does the deletion commit proceed. The deletion commit message must reference the gate results (grep output hash + runtime probe run id).

## References

- Memory: `project_title_story_crash` — story scroll crash background
- Memory: `project_vfix_dead_zone` — V64 dead zone full analysis and prior fix attempts
- Memory: `feedback_full_native_rewrite` — user preference for native rewrites over patching transpiled visuals
- Memory: `project_title_screen_goal` — pixel-perfect title screen long-term goal (relevant sibling)
- Commits: 98fe5f56, 88632506 — existing native YM2612/PSG music player (reused during intro, not rewritten)
