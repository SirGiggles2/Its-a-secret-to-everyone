# S1 — Repo Reorg + SGDK Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reorganize `src/` into the role-based layout from spec Section 6, vendor SGDK as the platform/render layer, retarget the existing native frontend (title + intro + FS) onto SGDK calls, and add the SRAM-fixture + frontend-lint guardrails. Ship a ROM that plays title/intro/FS identically to the locked baseline (logical parity diff = 0 across the 10 canonical movies) on top of SGDK.

**Architecture:** Three discrete phases land independently, each commit-and-build-green:
1. **Reorg without behavior change** (Phases A + B + C) — file moves only, ROM byte-identical to baseline at the end.
2. **SGDK adapter scaffolding** (Phases D + E) — owned `src/sgdk_adapter/` and SRAM fixture; wrapper bodies forward to existing helpers initially.
3. **Frontend cutover** (Phases F + G) — frontend code migrates from raw VDP writes onto SGDK API; lint graduates warn → fail; canonical-movie parity diff = 0.

**Tech Stack:** SGDK v2.11 (vendored at `sgdk/`), m68k-elf-gcc 13.2.0, vasmm68k_mot 2.0e, Python 3.14+, BizHawk 2.11 (Genesis core: Genplus-gx).

**Reference spec:** [docs/superpowers/specs/2026-04-27-native-genesis-rewrite-design.md](../specs/2026-04-27-native-genesis-rewrite-design.md), Section 7 stage S1.

**Reference S0 close-out:** [docs/audit/s0_close.md](../../audit/s0_close.md) — SGDK already vendored, A4 SAFE, baseline ROM hash `4bcfc1d916f44f31f36ee5bc0862b6b696313a264ffcc8373abde87d318befb4`.

---

## File Structure

**Top-level changes:**
- `sgdk/` — already added (git submodule at v2.11)
- `data/` — new dir; receives `src/gen/intro_*` and `src/gen/fs_*` extracted-data files
- `src/` — reorganized per spec Section 6

**Created under `src/`:**
- `src/abi/` — `render_abi.h`, `audio_abi.h`, `joy_abi.h`, `sram_abi.h`, `legacy_bridge.h`
- `src/sgdk_adapter/` — `render_adapter.{c,h}`, `audio_adapter.{c,h}`, `joy_adapter.{c,h}`, `sram_adapter.{c,h}`
- `src/frontend/` — receives `intro_*`, `fs_*`, `frontend_*.c` via `git mv`
- `src/game/{enemies,combat,room,cave,link,hud,items}/` — receives `*_runtime.c` files via `git mv`
- `src/state/` — receives `*_state.h` headers via `git mv`
- `src/core/` — `types.h`, `c_runtime.{c,h}` via `git mv`

**Deleted (cruft per `docs/audit/file_classification.md`):**
- 46 files matching `*.bak`, `* - Copy.*`, top-level stray `*.zip`, build_out logs

**Modified:**
- `build.bat` — adds SGDK include paths + libmd.a link, lint graduates warn→fail at end of S1
- `docs/superpowers/specs/2026-04-27-native-genesis-rewrite-design.md` — Section 12 Q4 resolution recorded, S1 acceptance achieved
- `tools/probes/lint_legacy_symbols.py` — flags graduate from warn to fail per spec Section 8.1

**Created at S1 close:**
- `docs/audit/s1_close.md` — close-out summary
- `tools/probes/sram_layout_test.c` — SRAM fixture
- `tools/probes/movies/{10 .bk2 files}` — canonical input movies
- `tools/probes/diff_capture.py`, `tools/probes/normalize_*.py` — parity tooling

---

## Phase A — Pre-Flight + Cruft Cleanup (~2 days)

Mechanical, no behavior change. Verifies S0 outputs still hold and removes 46 dead files before any moves happen.

### Task A1: Pre-flight build verification

**Files:** none modified.

- [ ] **Step 1: Run a fresh build.** From repo root: `build.bat`. Expect: ROM produced, lint warns 372 callers, exit 0.
- [ ] **Step 2: Verify ROM hash matches baseline.** `python -c "import hashlib; print(hashlib.sha256(open('builds/whatif.md','rb').read()).hexdigest())"`. Expect: `4bcfc1d916f44f31f36ee5bc0862b6b696313a264ffcc8373abde87d318befb4`.
- [ ] **Step 3: Verify probe scripts still pass.** `cd tools/probes && python -m pytest -q`. Expect: 24 passed.
- [ ] **Step 4: Confirm SGDK submodule populated.** `ls sgdk/inc/genesis.h sgdk/lib/libmd.a sgdk/bin/make.exe`. Expect: all three exist. If submodule lost: `git submodule update --init`.
- [ ] **Step 5:** No commit (verification only). Proceed to A2.

### Task A2: Delete truly-dead cruft files (only 3, not 46 — classifier had a bug)

**Files:** 3 deletions (per fixed `tools/probes/classify_files.py` and refreshed `docs/audit/file_classification.md`).

**Background:** The original S0 classifier (T12) used a catch-all rule that put any `.txt` file under `src/` into `cruft`, plus any `.inc` outside `src/zelda_translated/` and `src/gen/`. That misclassified:

- 41 live data includes under `src/data/` (referenced by `src/audio_driver.asm` line 1, 1403, 1411 — `music_blob.inc`, `music_blob.dat`, `dmc_samples.inc`, plus the broader extraction pipeline)
- 2 live asset-hash manifests under `src/gen/` (emitted by `tools/extract_fs_assets.py` and `tools/extract_intro_assets.py` to fingerprint extraction outputs)

The classifier was fixed to add two new categories (`extracted_data_inc`, `asset_manifest`) and to gate the truly-dead pattern to `*.bak` and `* - Copy*` only — not the broad `*.txt` rule. Tests extended from 16 to 25 cases.

**Truly-dead files after the fix:**
- `src/genesis_shell.asm.bak`
- `src/nes_io - Copy.txt`
- `src/zelda_translated/z_07 - Copy.txt`

- [ ] **Step 1:** `grep -B 1 -A 5 "^## \`cruft\`" docs/audit/file_classification.md`. Confirm 3 entries.
- [ ] **Step 2:** Verify each file. The two ` - Copy.txt` files are Windows-Explorer duplicates (identical to the canonical files modulo `.txt` extension); the `.bak` is a pre-edit backup. None are referenced anywhere else in the tree.
- [ ] **Step 3:** `git rm "src/genesis_shell.asm.bak" "src/nes_io - Copy.txt" "src/zelda_translated/z_07 - Copy.txt"`.
- [ ] **Step 4:** ROM hash unchanged from baseline (these files weren't in any build path).
- [ ] **Step 5: Commit.** `git commit -m "s1.A2: delete 3 truly-dead files (*.bak + Windows Copy artifacts)"`.

### Task A3: Verify lint count drops from cruft removal

**Files:** none.

- [ ] **Step 1: Re-run lint.** `python tools/probes/lint_legacy_symbols.py`.
- [ ] **Step 2: Compare new caller count to baseline 372.** If unchanged, cruft files held no legacy callers (expected). If dropped, regenerate `docs/audit/legacy_callers.md` via `python tools/probes/scan_legacy_callers.py` and commit.

### Task A4: Re-run all S0 probe scripts to refresh audit reports

**Files:** likely-changed audit reports under `docs/audit/`.

- [ ] **Step 1:** From `tools/probes/`: `python snapshot_repo_tree.py`, `python scan_legacy_callers.py`, `python scan_frontend_deps.py`, `python scan_build_order.py`, `python classify_files.py`, `python scan_redux_touchpoints.py`.
- [ ] **Step 2:** `git diff docs/audit/`. Expect changes only in line counts / file references reflecting cruft removal.
- [ ] **Step 3: Commit refreshed audit.** `git commit -m "s1.A: refresh audit reports after cruft cleanup"`.

**Phase A acceptance:** Build green, ROM hash unchanged, audit reports refreshed, 46 cruft files deleted.

---

## Phase B — Reorg Moves (~3–4 days)

Pure `git mv` per file group. Each task is a single subdirectory move, committed independently. Build must pass at the end of each task.

### Task B1: Create new src/ skeleton dirs

**Files created (empty):**
- `src/abi/.gitkeep`
- `src/sgdk_adapter/.gitkeep`
- `src/frontend/.gitkeep`
- `src/frontend/intro/.gitkeep`
- `src/frontend/fs/.gitkeep`
- `src/game/.gitkeep`
- `src/game/{mode,world,room,link,combat,enemies,items,hud,cave,options}/.gitkeep`
- `src/state/.gitkeep`
- `src/core/.gitkeep`
- `data/.gitkeep` (top-level)

- [ ] **Step 1:** Create dirs + .gitkeep files via mkdir + touch.
- [ ] **Step 2: Commit.** `git commit -m "s1.B1: scaffold new src/ subsystem dirs"`.

### Task B2: git mv state headers → src/state/

**Files moved:** every `src/*_state.h` (per file_classification.md "header" category, filtered to `*_state.h`).

- [ ] **Step 1: List all *_state.h files.** `git ls-files 'src/*_state.h'`.
- [ ] **Step 2: git mv each one.** `git mv src/<name>_state.h src/state/<name>_state.h`.
- [ ] **Step 3: Update build.bat to add `-Isrc/state` to the include path.** Find the C compile loop, add `-I"%ROOT%\src\state"` to the gcc flags.
- [ ] **Step 4: Update every C file's `#include "<name>_state.h"` to `#include "<name>_state.h"`.** Path doesn't change because of the new -I; if any C file was using `#include "src/foo_state.h"` form, fix.
- [ ] **Step 5: Build.** ROM hash must match baseline.
- [ ] **Step 6: Commit.** `git commit -m "s1.B2: git mv *_state.h → src/state/"`.

### Task B3: git mv core utilities → src/core/

**Files moved:**
- `src/c_runtime.{c,h}` → `src/core/c_runtime.{c,h}`
- `src/nes_abi.h` → `src/abi/platform_abi.h` (renamed per spec Section 6)

- [ ] **Step 1:** `git mv src/c_runtime.c src/core/c_runtime.c`, `git mv src/c_runtime.h src/core/c_runtime.h`, `git mv src/nes_abi.h src/abi/platform_abi.h`.
- [ ] **Step 2:** Add `-Isrc/core` and `-Isrc/abi` to build.bat. Update any `#include "nes_abi.h"` to `#include "platform_abi.h"`.
- [ ] **Step 3: Build.** ROM hash matches baseline.
- [ ] **Step 4: Commit.** `git commit -m "s1.B3: git mv core/* + rename nes_abi.h → abi/platform_abi.h"`.

### Task B4: git mv frontend C → src/frontend/

**Files moved:**
- `src/intro_*.c`, `src/intro_*.h` → `src/frontend/intro/`
- `src/fs_*.c`, `src/fs_*.h` → `src/frontend/fs/`
- `src/frontend_*.c`, `src/frontend_*.h` → `src/frontend/`

- [ ] **Step 1: List frontend files.** `git ls-files 'src/intro_*' 'src/fs_*' 'src/frontend_*' | grep -v '^src/gen'`.
- [ ] **Step 2: git mv each.**
- [ ] **Step 3:** Add `-Isrc/frontend -Isrc/frontend/intro -Isrc/frontend/fs` to build.bat. Update any cross-file includes that used the old flat paths.
- [ ] **Step 4: Build.** ROM hash matches baseline.
- [ ] **Step 5: Commit.** `git commit -m "s1.B4: git mv intro_* fs_* frontend_* → src/frontend/"`.

### Task B5: git mv game runtimes → src/game/<subsystem>/

**Files moved (per `file_classification.md` "owned_c"):**

| Source file pattern | Destination |
|---|---|
| `src/enemy_*_runtime.{c,h}`, `src/enemy_runtime*.{c,h}` | `src/game/enemies/` |
| `src/combat_*.{c,h}`, `src/collision_*.{c,h}` | `src/game/combat/` |
| `src/room_*.{c,h}` | `src/game/room/` |
| `src/cave_*.{c,h}` | `src/game/cave/` |
| `src/link_*.{c,h}` | `src/game/link/` |
| `src/hud_*.{c,h}` | `src/game/hud/` |
| `src/item_*.{c,h}` | `src/game/items/` |
| `src/object_*.{c,h}` | `src/game/<best-fit>/` (review case-by-case; likely combat or world) |
| `src/core_runtime.{c,h}` | `src/core/` (already a core utility) |

- [ ] **Step 1: For each subsystem, run `git ls-files 'src/<pattern>'` to inventory files.**
- [ ] **Step 2: git mv each file.** One subsystem per commit (commit cadence).
- [ ] **Step 3:** Add corresponding `-Isrc/game/<sub>` paths to build.bat once per dir.
- [ ] **Step 4: After each subsystem move, build.** ROM hash matches baseline.
- [ ] **Step 5: Commit per subsystem.**
  - `git commit -m "s1.B5a: git mv enemy_*_runtime → src/game/enemies/"`
  - `git commit -m "s1.B5b: git mv combat_/collision_ → src/game/combat/"`
  - `git commit -m "s1.B5c: git mv room_ → src/game/room/"`
  - `git commit -m "s1.B5d: git mv cave_ → src/game/cave/"`
  - `git commit -m "s1.B5e: git mv link_ → src/game/link/"`
  - `git commit -m "s1.B5f: git mv hud_ → src/game/hud/"`
  - `git commit -m "s1.B5g: git mv item_ → src/game/items/"`
  - `git commit -m "s1.B5h: object_ to subsystem (per inspection)"`

### Task B6: git mv extracted data → data/

**Files moved:** every file in `src/gen/` matching `intro_*` or `fs_*` (extracted bytes, classifier "generated_data").

- [ ] **Step 1: List.** `git ls-files src/gen/intro_* src/gen/fs_*`.
- [ ] **Step 2: git mv to `data/intro/` and `data/fs/`.**
- [ ] **Step 3:** Update every C file that `#include`s these to use the new path. Many will be `extern` declarations of arrays defined in the moved files; the linker doesn't care, but if any code does `#include "gen/intro_title_bg_chr.c"` (rare), fix.
- [ ] **Step 4:** Update build.bat C_GEN_SOURCES list to point at the new `data/` paths.
- [ ] **Step 5: Build.** ROM hash matches baseline.
- [ ] **Step 6: Commit.** `git commit -m "s1.B6: git mv gen/intro_* gen/fs_* → data/{intro,fs}/"`.

### Task B7: Quarantine transpiled glue (gen/z_*.c stays for now)

**Files unchanged:** `src/gen/z_01.c`..`src/gen/z_07.c` and `src/zelda_translated/` stay where they are. They define the `z01_*`/`z07_*` symbols still called by drained-but-not-yet-replaced runtime functions (372 callers per S0). Spec Section 8 deletion checkpoint is "after S10."

- [ ] **Step 1: Add `src/abi/legacy_bridge.h`.** Move the `extern void z01_*(...);` and `extern void z07_*(...);` prototypes from individual `_runtime_private.h` headers into a single `legacy_bridge.h`. The lint exempts this path so callers from owned C runtimes use this single header.
- [ ] **Step 2:** Update every `_runtime.c` that called `z01_*`/`z07_*` to `#include "abi/legacy_bridge.h"` and remove duplicate externs from individual headers.
- [ ] **Step 3: Build.** ROM hash matches baseline.
- [ ] **Step 4: Commit.** `git commit -m "s1.B7: consolidate z01_/z07_ externs into abi/legacy_bridge.h"`.

**Phase B acceptance:** All owned C is under the new tree, all extracted data is under `data/`, build is green, ROM hash matches baseline byte-identical, lint count unchanged at 372 (callers moved but didn't disappear yet).

---

## Phase C — Build Pipeline Rewire (~2–3 days)

Add SGDK include + link to the existing build, OR migrate to `sgdk/makefile.gen`. Recommendation per `docs/audit/sgdk_integration.md` open issue #6: **adopt makefile.gen**.

### Task C1: Decide build chain (makefile.gen vs build.bat extension)

**Files:** `docs/audit/build_chain_decision.md` (new).

- [ ] **Step 1:** Inspect `sgdk/makefile.gen` to see how it locates project sources, defines C/asm sources, and links libmd.a.
- [ ] **Step 2:** Inspect current `build.bat` C_SOURCES + C_GEN_SOURCES + ASM list.
- [ ] **Step 3:** Document the decision (makefile.gen recommended) with rationale.
- [ ] **Step 4: Commit.** `git commit -m "s1.C1: build-chain decision recorded"`.

### Task C2: Adopt SGDK makefile.gen

**Files modified:**
- `Makefile` (new at repo root) — sets SGDK paths, includes `sgdk/makefile.gen`
- `build.bat` — becomes a thin wrapper that invokes `sgdk/bin/make.exe -f Makefile`

- [ ] **Step 1: Write minimal `Makefile` at repo root.** Set `GDK = $(realpath sgdk)`, define source paths under `src/`, include `$(GDK)/makefile.gen`.
- [ ] **Step 2: Adapt build.bat** to invoke `sgdk/bin/make.exe -f Makefile`.
- [ ] **Step 3: First build attempt.** Expect link errors (existing code references `_ppu_*` / `_oam_*` not yet in any compiled module since `nes_io.asm` may need explicit inclusion).
- [ ] **Step 4: Add nes_io.asm + c_shims.asm + genesis_shell.asm to the makefile's ASM source list.** These remain in their current locations through Phase F; they're being kept as the legacy shim layer. They go away at S10 deletion checkpoint.
- [ ] **Step 5: Iterate until ROM produces.** First successful link: ROM hash will likely DIFFER from baseline because makefile.gen uses different optimization / link-order defaults. **This is acceptable IF** the new ROM hash is captured as a new baseline AND the title/intro/FS canonical movies still play identically in BizHawk. Capture the new hash; update `docs/audit/baseline_rom.md` with rationale.
- [ ] **Step 6: Update spec Section 0 baseline ROM SHA256 to the new hash.** Annotate as "post-makefile.gen baseline; supersedes pre-S1 hash with rationale: build chain change is intentional, behavior preserved."
- [ ] **Step 7: Commit.** `git commit -m "s1.C2: adopt SGDK makefile.gen build chain; new baseline hash"`.

### Task C3: SRAM-layout test scaffolding

**Files created:**
- `tools/probes/sram_layout_test.c`

- [ ] **Step 1:** Write `sram_layout_test.c` that uses `_Static_assert` on byte offsets — save slot 0 at `0x000`, save slot 1 at next, OptionsState at `0x800`, etc., per `docs/audit/sram_map.md`.
- [ ] **Step 2:** Add to build.bat / Makefile compile list. Static asserts fire at compile time; no runtime needed.
- [ ] **Step 3: Build.** Compilation success = layout assertions hold.
- [ ] **Step 4: Commit.** `git commit -m "s1.C3: SRAM layout fixture (static asserts on save-slot + OptionsState offsets)"`.

**Phase C acceptance:** Build chain runs through `sgdk/makefile.gen`. ROM produces. SRAM fixture compiles. SGDK headers reachable from any owned C file via `#include <genesis.h>`.

---

## Phase D — SGDK Adapter Scaffolding (~3–4 days)

Add `src/sgdk_adapter/` with thin wrappers. Each adapter forwards to the existing implementation initially; bodies swap to direct SGDK calls in Phase F.

### Task D1: Render adapter

**Files created:**
- `src/abi/render_abi.h` — public render API
- `src/sgdk_adapter/render_adapter.c/.h`

- [ ] **Step 1:** Write `render_abi.h` with prototypes for the few wrapper functions frontend uses now: `render_set_plane_a_word(col, row, word)`, `render_load_palette(idx, src)`, `render_chr_upload(vram_addr, src, byte_count)`. Keep the surface MINIMAL — only what frontend needs.
- [ ] **Step 2:** Implement each in `render_adapter.c` by forwarding to existing helpers (e.g. `vdp_load_cram_at`, `chr_upload`). Result: zero behavior change.
- [ ] **Step 3: Build.** ROM hash matches Phase C baseline.
- [ ] **Step 4: Commit.** `git commit -m "s1.D1: render adapter (forwards to existing helpers)"`.

### Task D2: Audio adapter

**Files created:**
- `src/abi/audio_abi.h`
- `src/sgdk_adapter/audio_adapter.c/.h`

- [ ] **Step 1:** Write `audio_abi.h` with `audio_music_play(u8 song)`, `audio_sfx_play(u8 sfx)`, `audio_tick_vblank(void)`.
- [ ] **Step 2:** Implement each in `audio_adapter.c` by forwarding to existing `music_play` / `music_tick`.
- [ ] **Step 3:** Update genesis_shell.asm VBlank handler to call `audio_tick_vblank` instead of `music_tick` directly. (One-line asm change: `bsr music_tick` → `jsr audio_tick_vblank`.)
- [ ] **Step 4:** Update frontend `intro_main.c`, `fs_main.c` to call `audio_music_play` instead of `music_play`. (Mechanical replace.)
- [ ] **Step 5: Build.** ROM hash MAY differ from Phase C baseline because audio call sites changed. Verify title music plays in BizHawk smoke test.
- [ ] **Step 6: Commit.** `git commit -m "s1.D2: audio adapter wraps music_play/music_tick"`.

### Task D3: Joypad adapter

**Files created:**
- `src/abi/joy_abi.h`
- `src/sgdk_adapter/joy_adapter.c/.h`

- [ ] **Step 1:** Write `joy_abi.h` with `joy_read(void)`, `joy_state(u8 port)`. Use NES-button bitmask shape (existing `BTN_START` etc.) on top of SGDK's `JOY_readJoypad` pad-state.
- [ ] **Step 2:** Implement.
- [ ] **Step 3: Update intro/fs to call `joy_state` instead of reading `CTRL1_DATA` directly.**
- [ ] **Step 4: Build.** ROM hash may differ. Smoke test in BizHawk: Start press advances intro, Up/Down moves FS cursor.
- [ ] **Step 5: Commit.** `git commit -m "s1.D3: joypad adapter (NES-button shape on top of JOY_readJoypad)"`.

### Task D4: SRAM adapter

**Files created:**
- `src/abi/sram_abi.h`
- `src/sgdk_adapter/sram_adapter.c/.h`

- [ ] **Step 1:** Write `sram_abi.h` with `sram_save_load(u8 slot, void *dst)`, `sram_save_store(u8 slot, const void *src)`, `sram_options_load(struct OptionsState *)`, `sram_options_store(const struct OptionsState *)`.
- [ ] **Step 2:** Implement using SGDK's `SRAM_enable` / `SRAM_readByte` / `SRAM_writeByte`. Byte offsets per `docs/audit/sram_map.md`.
- [ ] **Step 3: Run `sram_layout_test` static asserts.** Pass.
- [ ] **Step 4: Build.** ROM may differ.
- [ ] **Step 5: Commit.** `git commit -m "s1.D4: SRAM adapter (slots + OptionsState; uses SGDK SRAM_*)"`.

**Phase D acceptance:** Adapter API in place. Existing helpers wrapped. Build green. Title/intro/FS smoke-tested in BizHawk play correctly.

---

## Phase E — SRAM Fixture (~1 day)

### Task E1: Runtime SRAM roundtrip test

**Files:**
- `tools/probes/sram_layout_test.c` — extend to runtime test mode (mode 1 = compile-time asserts already done in C3; mode 2 = runtime byte-pattern roundtrip)
- `tools/probes/run_sram_test.lua` (new) — BizHawk Lua probe that loads ROM, exercises SRAM read/write, dumps result

- [ ] **Step 1:** Add a `#ifdef SRAM_TEST_MODE` build path that, on boot, writes a known byte pattern to each SRAM range (save slots, OptionsState, free area) and reads back to verify.
- [ ] **Step 2:** Write Lua probe that boots the SRAM-test-mode ROM, waits N frames, captures BizHawk's SRAM domain, compares to expected pattern.
- [ ] **Step 3: Run.** Expect pass.
- [ ] **Step 4: Commit.** `git commit -m "s1.E1: SRAM runtime fixture (write-pattern + readback)"`.

**Phase E acceptance:** SRAM compile-time asserts + runtime fixture both pass. Save format unchanged from baseline.

---

## Phase F — Frontend Cutover (~5–7 days)

The actual code change. Frontend stops writing raw `VDP_CTRL_WORD` and calls SGDK + adapters instead. Per spec Section 7 S1, this must end with logical-parity diff = 0 against baseline ROM on the 10 canonical movie set.

### Task F1: Canonical movie set

**Files created (10 BizHawk movie files + sibling SRAM blobs as needed):**
- `tools/probes/movies/title_idle.bk2`
- `tools/probes/movies/title_to_file_select.bk2`
- `tools/probes/movies/intro_story_page_1.bk2`
- `tools/probes/movies/fs_fresh_cursor.bk2`
- `tools/probes/movies/fs_cursor_wrap.bk2`
- `tools/probes/movies/fs_name_entry_create.bk2`
- `tools/probes/movies/fs_name_entry_backspace.bk2`
- `tools/probes/movies/fs_file_delete_cancel.bk2`
- `tools/probes/movies/fs_file_delete_confirm.bk2`
- `tools/probes/movies/fs_registered_file_start.bk2`

- [ ] **Step 1:** Record each movie against the baseline FINAL TRY ROM in BizHawk (Genplus-gx core). Each movie starts from a known SRAM image (or empty SRAM).
- [ ] **Step 2:** For each movie, capture: VDP plane A/B tilemap, SAT, CRAM, VSRAM scroll registers at the final frame.
- [ ] **Step 3: Commit movies + reference captures.** `git commit -m "s1.F1: canonical frontend movie set + reference captures"`.

### Task F2: Diff capture probe

**Files created:**
- `tools/probes/diff_capture.py` — byte-diff two BizHawk capture dumps, report mismatches

- [ ] **Step 1:** Write the diff tool. Inputs: two `.dump` files (binary, with header tagging plane_a/plane_b/sat/cram/vsram). Output: per-region byte diff count, file:offset for first 100 mismatches.
- [ ] **Step 2:** Test against a known-equal pair (run baseline twice).
- [ ] **Step 3: Commit.** `git commit -m "s1.F2: diff_capture.py (Genesis-vs-Genesis logical parity)"`.

### Task F3: Title cutover

**Files modified (largest unit per the file_classification.md frontend list — typically `src/frontend/intro/intro_title.c`, `intro_title_*.c`):**

- [ ] **Step 1:** Identify every `VDP_CTRL_WORD` / `0x00C00004` write in `intro_title*` files (per `docs/audit/frontend_deps.md`).
- [ ] **Step 2:** Replace each with the equivalent `VDP_*` SGDK call OR `render_*` adapter call. Common patterns:
  - `*VDP_CTRL_WORD = some_addr_command; loop write to VDP_DATA` → `VDP_loadTileData(...)` or `VDP_setTileMapDataRect(...)`
  - Palette writes → `PAL_setColor(pal, idx, color)` or `PAL_setPalette(idx, src)`
  - `chr_upload_*` → `VDP_loadTileData`
- [ ] **Step 3:** Build, run `title_idle.bk2` movie, capture, diff against reference. **Diff must = 0.**
- [ ] **Step 4: Commit.** `git commit -m "s1.F3: title cutover onto SGDK (parity 0)"`.

### Task F4: Intro cutover

**Files modified:** `src/frontend/intro/intro_*.c` (excluding intro_title which was F3).

- [ ] **Step 1–4: Same pattern as F3.** Acceptance: `intro_story_page_1.bk2` diff = 0.
- [ ] **Step 5: Commit.** `git commit -m "s1.F4: intro cutover onto SGDK (parity 0)"`.

### Task F5: File-select cutover (the biggest)

**Files modified:** `src/frontend/fs/fs_*.c` — fs_main, fs_phase, fs_render, fs_input, fs_handoff.

- [ ] **Step 1–4:** Same pattern. Acceptance: 7 FS movies all diff = 0 (`fs_fresh_cursor`, `fs_cursor_wrap`, `fs_name_entry_create`, `fs_name_entry_backspace`, `fs_file_delete_cancel`, `fs_file_delete_confirm`, `fs_registered_file_start`).
- [ ] **Step 5: Commit.** `git commit -m "s1.F5: FS cutover onto SGDK (parity 0)"`.

### Task F6: Frontend handoff cutover

**Files modified:** `src/frontend/intro/intro_handoff.c`, `src/frontend/fs/fs_handoff.c`, `src/frontend/frontend_runtime.c`.

- [ ] **Step 1–4:** Same pattern. Acceptance: `title_to_file_select.bk2` diff = 0.
- [ ] **Step 5: Commit.** `git commit -m "s1.F6: frontend handoff cutover onto SGDK (parity 0)"`.

**Phase F acceptance:** All 10 canonical movies diff = 0. Frontend code uses SGDK + adapter API only; zero `VDP_CTRL_WORD` / `0x00C00004` writes remain in `src/frontend/`.

---

## Phase G — Lint Graduation (~1 day)

### Task G1: Graduate frontend lint warn → fail

**Files modified:** `tools/probes/lint_legacy_symbols.py`

- [ ] **Step 1:** Add a stage-aware mode flag. At S1 close, frontend invariants (no `_ppu_*` / `_oam_*` callers in `src/frontend/`) graduate from warn to fail.
- [ ] **Step 2:** Add a structural grep for VDP-direct writes (`VDP_CTRL_WORD`, `0x00C00004`) and forbid them under `src/frontend/` and `src/game/` from S1 onwards.
- [ ] **Step 3:** Run lint. Expect: lint passes (frontend is clean post-F).
- [ ] **Step 4: Add unit tests for the new fail mode.** Fixture-text inputs that should now fail.
- [ ] **Step 5: Build.** Lint runs in build, frontend portion fails-loud if violated, gameplay portion still warns.
- [ ] **Step 6: Commit.** `git commit -m "s1.G1: lint graduates frontend warn→fail"`.

**Phase G acceptance:** Lint differentiates per-subsystem strictness. Frontend cannot regress.

---

## Phase H — S1 Close (~1 day)

### Task H1: Q4 normalized parity schema validation

Resolves the last S0 deferral (Q4 in spec Section 12).

**Files created:**
- `tools/probes/normalize_nes.py`
- `tools/probes/normalize_gen.py`
- `tools/probes/diff_normalized.py`
- `docs/audit/parity_schema_check.md` — extend with actual results

- [ ] **Step 1:** Implement the three scripts to produce/diff the normalized schema (`bg_tile`, `bg_palette`, `bg_priority`, `sprite[]`, `scroll`, `state`) per spec Section 0.
- [ ] **Step 2:** Run on a title-screen-idle pair (NES + current Genesis ROM).
- [ ] **Step 3:** If schema is sufficient, mark Q4 RESOLVED in spec Section 12. If insufficient, amend Section 0 with the smallest schema extension needed.
- [ ] **Step 4: Commit.** `git commit -m "s1.H1: parity schema validated; Q4 resolved"`.

### Task H2: Run all 10 canonical movies + archive results

**Files created:** `builds/reports/s1_close/<movie>.{capture,diff}` for each of the 10 movies.

- [ ] **Step 1:** Run each canonical movie against the post-F ROM. Capture + diff vs reference (which is the post-C2 baseline).
- [ ] **Step 2:** Each diff must = 0.
- [ ] **Step 3: Archive captures + diff logs.** Commit under `builds/reports/s1_close/`.
- [ ] **Step 4: Commit.** `git commit -m "s1.H2: 10-movie canonical parity archive"`.

### Task H3: Write s1_close.md + tag

**Files:**
- `docs/audit/s1_close.md` — close-out summary
- spec Section 7 S1 acceptance updated to reflect what actually closed
- git tag `s1-closed`

- [ ] **Step 1: Write s1_close.md.** Cover: Phase A–H summaries, ROM hash before+after, lint state, deferrals to S2 (none expected), prerequisites for S2 (data extraction).
- [ ] **Step 2: Update spec Section 7 S1 acceptance** to point at `docs/audit/s1_close.md` and confirm the canonical movie diff = 0.
- [ ] **Step 3: Update memory** `project_what_if.md` to reflect S1 done.
- [ ] **Step 4: Commit + tag.** `git commit -m "s1: close-out summary"`, `git tag -a s1-closed -m "S1 (Reorg + SGDK Integration) complete; frontend on SGDK with parity = 0"`.

**Phase H acceptance:** All 10 canonical movies diff = 0. S1 spec invariants enforced by lint. ROM produces from `sgdk/makefile.gen`. SRAM fixture passes. Q4 resolved. Tag `s1-closed` on main.

---

## Self-Review Checklist (run before dispatch)

- [ ] **Spec coverage:** Walk spec Section 7 S1 acceptance line-by-line. Each requirement maps to a task above. Missing: none expected.
- [ ] **No placeholders:** Every step has explicit code/command/diff target. No "TBD" or "implement later" — placeholders like `<best-fit>` (B5h object_) are flagged for case-by-case review at execution.
- [ ] **Type consistency:** Adapter API names (`render_*`, `audio_*`, `joy_*`, `sram_*`) match across abi/ headers and adapter implementations.
- [ ] **Build still works after each task** — explicit verification step in every task.
- [ ] **Cutover is reversible at every step until F:** Phases A–E are pure refactor; if anything breaks, revert one commit.
- [ ] **Phase F has the riskiest commits** — each cutover (F3/F4/F5/F6) is gated on diff = 0 against reference. If diff > 0, the task is NOT done; iterate until clean.

---

## Total estimate

~3 weeks focused (matches spec Section 7 S1 estimate of "2–3 wks"). Phase F is the variable-length phase; if SGDK API signatures don't match expectations, expect extra time per file.

## Execution mode

Recommended: **superpowers:subagent-driven-development**, same pattern as S0. Each task gets its own implementer + spec reviewer + code-quality reviewer. Phase F task gates on parity probe = 0 before next task.
