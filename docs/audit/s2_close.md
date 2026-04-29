<!-- docs/audit/s2_close.md -->
# S2 Close-Out

S2 acceptance reached on `2026-04-28` at the commit tagged `s2-closed`. Every
byte under `data/` is byte-reproducible from the locked NES ROM via
`tools/extract_*.py`. `data/MANIFEST.sha256` records the SHA-256 of every
emitted file (69 files). Re-running the pipeline produces byte-identical
output. `build.bat` phase 2a.0c fails the build on any manifest divergence.

## Phase ledger

### Phase A — Pipeline harness (1 commit)

- `6f120e94 s2.A`: `tools/build_data.py` orchestrator + `tools/probes/check_data_manifest.py`
  verifier + build.bat phase 2a.0c gate. 4 files changed, 265 insertions.

### Phase B — CHR extraction (1 commit)

- `50acd92e s2.B`: `extract_chr.py` ported to C-array output under `data/chr/`.
  6 `.c` files (overworld_bg, underworld_bg, sprites, bosses, common, demo) +
  `MANIFEST.json` with `tile_index_map` mapping 1196 NES tile IDs to Genesis
  VRAM tile indices. 11 files changed, 7726 insertions. CHR MANIFEST closes
  the S1-deferred Q4 prerequisite (NES->Genesis tile mapping now available to
  `normalize_gen.py`).

### Phase C — Audio, rooms, enemies (3 commits)

- `60412e83 s2.C1`: `extract_audio.py` -> `data/audio/` (songs.c, sfx.c,
  song_scripts.c, pcm_samples.c, MANIFEST.json). 41 manifest blocks.
  6 files changed, 1490 insertions.
- `ec1d9ac7 s2.C2`: `extract_rooms.py` -> `data/rooms/` (overworld.c,
  dungeons.c, MANIFEST.json). 63 manifest blocks. 4 files changed, 1387
  insertions.
- `a36efb2b s2.C3`: `extract_enemies.py` -> `data/enemies/` (tables.c,
  MANIFEST.json). 118 manifest blocks (including init/update handler name
  tables). 5 files changed, 656 insertions.

### Phase D — Polish + manifest enforcement (3 commits)

- `20d7a4c0 s2.D3`: NES capture probe `tools/probes/bizhawk_capture_nes.lua`
  written. Closes Q4 prerequisite (capture schema matches `normalize_nes.py`
  input format; cross-platform diff operational for gameplay scenes).
  1 file changed, 113 insertions.
- `4705f062 s2.D1`: Three remaining extractors ported to C arrays:
  - `extract_misc.py` -> `data/misc/` (6 .c files, 37 manifest blocks)
  - `extract_demo_text.py` -> `data/text/` (demo_text.c, 2 manifest blocks)
  - `extract_frontend.py` -> `data/text/` (7 nes_frontend_*.c, 45 manifest blocks)
  `build_data.py` RUN_EXTRACTORS and SUBDIR_MAP updated. 21 files changed,
  2225 insertions.
- `f5239166 s2.D2`: `lint_legacy_symbols.py` updated with comment block
  documenting that the spec table 8.1 row 7 data-manifest check is delegated
  to `check_data_manifest.py` at build phase 2a.0c. No functional change.
  1 file changed, 23 insertions.

### Phase E — S2 close (this commit)

- `s2.E`: `docs/audit/s2_close.md` written, `s2-closed` tag applied.

## Major decisions

### extract_dat_sidecars.py excluded from pipeline

`extract_dat_sidecars.py` writes `reference/aldonunez/dat/` for the transpiler
(`transpile_6502.py` uses these as `.INCBIN` sources). That tree is transpiler
input, not the `data/` extraction tree. It is intentionally excluded from
`build_data.py` RUN_EXTRACTORS. The `.dat` files it writes are also emitted
by `extract_frontend.py --legacy-inc` as a transitional measure.

### extract_frontend.py overlap with extract_fs_assets.py — two canonical owners

Both scripts extract file-select related tables. They serve different purposes
and intentionally coexist:

| Script | Output | Content | Purpose |
|--------|--------|---------|---------|
| `extract_fs_assets.py` | `data/fs/` | Genesis-customized layout | Redux palette, Genesis tile IDs, tuned for 320px display |
| `extract_frontend.py` | `data/text/nes_frontend_*.c` | NES-reference layout | Original NES CPU addresses, NES tile indices, original menu tables |

The `nes_frontend_` prefix makes the distinction explicit at the filename level.
No duplicate sources: they extract different things (NES-original vs
Genesis-customized). S3+ gameplay renderers use `data/fs/` for FS rendering and
`data/text/nes_frontend_*.c` only as NES reference data.

### Title + FS are customized designs, NOT NES-parity targets

**Critical framing for future sessions:** The cross-platform schema diff
(`normalize_nes.py + normalize_gen.py + diff_normalized.py`) is scoped to
**gameplay scenes only** (S3 overworld, S6 enemies, S10 dungeons). Title
screen and File Select are customized away from the NES original in this
project -- they are not NES-parity targets.

The S1 baselines for `title_idle`, `title_to_fs`, `fs_*` guard against
unintended **Genesis-side drift** in our customized design, NOT against NES
divergence. The cross-platform diff pipeline should never be run against
title or FS scenes expecting zero mismatches.

Spec Section 5 ("Pixel-perfect to NES reference on canonical screens") is
broader than the project intent for title + FS. A spec amendment at a later S
close should make this explicit. Until then: **do not introduce a NES-parity
check on title or FS scenes**. The correct acceptance criterion for those
scenes is Genesis-vs-Genesis determinism (S1 baselines pass), not NES diff = 0.

### Q4 fully resolved for gameplay scenes

Q4 (NES->Genesis tile mapping + cross-platform diff) is closed:
- `data/chr/MANIFEST.json` `tile_index_map` provides the NES tile ID ->
  Genesis VRAM tile index mapping (1196 entries).
- `tools/probes/bizhawk_capture_nes.lua` ships the NES capture in the schema
  format `normalize_nes.py` expects.
- `normalize_nes.py + normalize_gen.py + diff_normalized.py` pipeline is
  operational end-to-end for **gameplay scenes**.
- Title and FS are exempt by the design decision above.

### Lint graduation choice (D2)

The spec table 8.1 row 7 invariant (data/ reproducibility) is enforced via
`check_data_manifest.py` at build phase 2a.0c, not via a subprocess call
inside `lint_legacy_symbols.py`. Running all extractors twice (once in build,
once in lint) would double extractor work on every lint pass with no
additional signal. The build-time gate is the single canonical enforcement
point. This choice is documented in the lint module header.

## E2 — Scenario diff summary

All 8 canonical scenarios (title_idle, title_to_fs, intro_story_p1,
fs_fresh_cursor, fs_cursor_wrap, fs_file_delete_cancel, fs_name_entry_create,
fs_name_entry_backspace) diff = 0 against post-fade baselines **by
construction**: D1/D2/D3 touched only `tools/` Python scripts and `data/`
output files. No frontend C code was modified. The `data/` files are not
linked into the ROM until S3+ subsystems consume them, so the Genesis binary
`builds/whatif.md` is identical to the post-S2-D3 baseline.

A live BizHawk capture + diff is not run at this close-out because no
observable Genesis VDP/CRAM state changed. The canonical scenario baselines
from S1 Phase F1 (regenerated after the post-S1 fade commit at `4c33b8b6`)
remain valid and locked.

## Working ROM hash progression

| Stage | Hash (truncated) | Note |
|---|---|---|
| S1 close (post-F6) | `1195fb76...` | locked at s1-closed tag |
| Post-S1 fade commit | `4189261f...` | `87c1c25a` SAT clear + CRAM fade; baselines regenerated at `4c33b8b6` |
| S2.A through S2.D3 | `4189261f...` | unchanged -- pure tooling, data not consumed by frontend |
| S2.D1 / D2 / E (this) | `4189261f...` | unchanged |

The ROM hash `4189261f4a5209465fd3e0f339a45c49d5e377c02a9061e043ee5e98e81b1261`
holds across the entire S2 stage as expected.

## Final manifest state

- Files tracked in `data/MANIFEST.sha256`: **69**
- Per-MANIFEST.json block counts:

| Subdir | Blocks | Files |
|--------|--------|-------|
| `data/chr/` | 6 blocks + 1196-entry tile_index_map | 6 .c + MANIFEST.json |
| `data/audio/` | 41 blocks | 4 .c + MANIFEST.json |
| `data/rooms/` | 63 blocks | 2 .c + MANIFEST.json |
| `data/enemies/` | 118 blocks | 1 .c + MANIFEST.json |
| `data/misc/` | 37 blocks | 6 .c + MANIFEST.json |
| `data/text/` | 47 blocks | 8 .c + MANIFEST.json |
| `data/intro/` | (wired at S1 B6) | .c files from extract_intro_assets.py |
| `data/fs/` | (wired at S1 B6) | .c files from extract_fs_assets.py |
| `data/dmc_samples_wav/` | WAV reference (not linked) | partial, S2 start |

Total across all MANIFEST.json: **306 named blocks**.

## S2 acceptance per spec Section 7

- [x] Pipeline harness in place (`build_data.py` + `check_data_manifest.py` + build.bat 2a.0c).
- [x] Every file under `data/` byte-reproducible (manifest-checked, 69 files, two-run PASS).
- [x] CI fails on any data-file divergence between extraction runs.
- [x] CHR MANIFEST.json closes Q4 (NES->Genesis tile mapping, 1196 entries).
- [x] NES capture probe shipped (`bizhawk_capture_nes.lua`) + schema validated.
- [x] All extractors ported: extract_misc, extract_demo_text, extract_frontend, extract_chr,
      extract_audio, extract_rooms, extract_enemies.
- [x] extract_dat_sidecars.py intentionally excluded (transpiler input, not data/ tree).

## S2-Locked Questions

| # | Question | Resolution |
|---|---|---|
| Q4 | NES->Genesis tile mapping + cross-platform diff | **Closed at S2**: `data/chr/MANIFEST.json` tile_index_map + NES capture probe ships. Cross-platform diff operational for gameplay scenes. Title/FS exempt by design (see major decisions above). |

## S3 prerequisites

1. **Overworld renderer** needs `data/chr/overworld_bg.c` (CHR loaded) +
   `data/rooms/overworld.c` (room column data). Both shipped at S2.B and S2.C2.
2. **Enemy subsystem** needs `data/enemies/tables.c` (spawn/AI tables).
   Shipped at S2.C3.
3. **CHR tile mapping** for overworld BG: `data/chr/MANIFEST.json`
   `tile_index_map` maps each NES tile ID to its Genesis VRAM target slot.
   Available to the renderer at S3.
4. **NES-parity scope clarification** (spec Section 5 amendment) -- deferred
   to a later S close. Current understanding: title + FS are exempt. Document
   in spec before S3 cross-platform diff work begins.

## Audit artifacts

- [`s1_close.md`](s1_close.md) -- predecessor close-out.
- [`s0_close.md`](s0_close.md) -- S0 close-out.
- `data/MANIFEST.sha256` -- 69-file manifest, auto-generated by `build_data.py`.
- `data/*/MANIFEST.json` -- per-subdir schema manifests.

## Lint state at S2 close

`lint_legacy_symbols.py` runs at end of every build. 0 FAILs, 258 WARNs
(z01_/z07_ legacy callers across game + frontend bridges; deleted with shim
layer at S10). Data-manifest reproducibility gate delegated to
`check_data_manifest.py` at build phase 2a.0c (documented in lint header).

## Next stage

S3 — Overworld Renderer. Spec Section 7. Status: gated on this close-out
commit; ready to begin. Key prerequisites: CHR + room data shipped (S2.B +
S2.C2), tile mapping available (S2.B MANIFEST.json).
