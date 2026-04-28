# S2 — Data Extraction Pipeline Implementation Plan

**Reference spec:** [docs/superpowers/specs/2026-04-27-native-genesis-rewrite-design.md](../specs/2026-04-27-native-genesis-rewrite-design.md), Section 7 stage S2.
**Reference S1 close:** [docs/audit/s1_close.md](../../audit/s1_close.md).

**Goal:** Every byte under `data/` is byte-reproducible from the locked NES ROM via `tools/extract_*.py`. `data/MANIFEST.sha256` records the SHA of every emitted file. Re-running the pipeline produces byte-identical output. Lint invariant (spec table 8.1 row 7) graduates fail at S2 close.

## Inventory at S2 start

12 extractors already exist in `tools/`:

| Script | Status | Current output |
|---|---|---|
| `extract_intro_assets.py` | wired | `data/intro/*.c` (S1 B6) |
| `extract_fs_assets.py` | wired | `data/fs/*.c` (S1 B6) |
| `extract_chr.py` | unwired | emits `.inc` (vasm) -- needs C-array port |
| `extract_audio.py` | unwired | location TBD |
| `extract_dat_sidecars.py` | unwired | binary blobs |
| `extract_demo_text.py` | unwired | text dumps |
| `extract_dmc_samples.py` | partial | `data/dmc_samples_wav/*.wav` already present |
| `extract_enemies.py` | unwired | likely emits to old `src/gen/` |
| `extract_frontend.py` | unwired | check overlap with intro/fs |
| `extract_misc.py` | unwired | grab bag |
| `extract_nes_banks.py` | utility | bank-relative offset helper |
| `extract_rooms.py` | unwired | overworld + dungeon room data |

Per spec Section 6 the target tree is `data/{chr,palettes,rooms,enemies,items,audio}/`. Existing `data/{intro,fs,dmc_samples_wav}/` is partial.

## Phase plan

Each phase ends with build green + ROM hash captured. Phase A is structural (no ROM impact). Phase B-D introduce data files; ROM hash drift expected as data is consumed by future stages but not consumed by current frontend (so initial passes are hash-neutral).

### Phase A — Pipeline harness (~1 day)

A1. **Add `tools/build_data.py`** orchestrator. Runs every `extract_*.py` in dependency order, collects emitted file paths, computes SHA256 for each, writes `data/MANIFEST.sha256`.

A2. **Add `tools/probes/check_data_manifest.py`** verifier. Re-runs `build_data.py` to a temp dir, compares to committed `data/MANIFEST.sha256`, fails on any divergence.

A3. **Wire into `build.bat`.** New phase 1.5 between transpile and C compile: run `build_data.py` (or skip if `data/MANIFEST.sha256` is up-to-date and inputs unchanged). The manifest check runs unconditionally in CI.

A4. **Lock NES ROM provenance check.** `tools/probes/locate_reference_rom.py` already exists per S0; verify it's called by every extractor before reading ROM bytes.

### Phase B — Port `extract_chr.py` to C-array output (~2 days)

CHR is the keystone. Spec S3 needs CHR in `data/chr/` to render the overworld; spec S2 acceptance gates on "every file under data/ byte-reproducible from NES ROM".

B1. Replace `.inc` emission with C-array emission. Output schema:
  - `data/chr/overworld_bg.c` -- `const unsigned char overworld_bg_chr[]`
  - `data/chr/underworld_bg.c` -- analogous
  - `data/chr/sprites.c` -- shared sprite tiles
  - `data/chr/MANIFEST.json` -- map of NES tile id -> (file, byte offset, Genesis VRAM tile index target)

B2. The MANIFEST is the load-bearing piece for the S1-deferred Q4 (NES->Genesis tile ID mapping). `normalize_gen.py` will read this map at S2 close to make `bg_tile` cross-platform diffable.

B3. Add the new files to build.bat C_DATA_* loops + LD_RESP. Hash-neutral initially (no caller).

B4. Acceptance: `python tools/extract_chr.py` produces byte-identical output across two runs. `data/MANIFEST.sha256` includes every CHR file.

### Phase C — Port audio + room + enemy extractors (~3 days)

C1. **Audio:** `extract_audio.py` -> `data/audio/songs.c` + `data/audio/sfx.c`. Existing `data/dmc_samples_wav/` stays as-is for reference; the build does not link WAVs. Format depends on driver swap decision (XGM2 at S11 may want different format -- defer the format choice; S2 ships RAW dump that S11 can transcode).

C2. **Rooms:** `extract_rooms.py` -> `data/rooms/overworld.c` + `data/rooms/dungeons.c`. Schema captures column-encoded layout, attribute bytes, and per-room metadata (enemies present, secrets, item drops).

C3. **Enemies:** `extract_enemies.py` -> `data/enemies/tables.c`. Drop tables, spawn lists, AI parameters.

C4. Each commit hash-neutral (data consumed at S6+).

### Phase D — Polish + manifest enforcement (~1 day)

D1. Migrate `extract_misc.py`, `extract_dat_sidecars.py`, `extract_demo_text.py`, `extract_frontend.py` outputs to `data/{misc,sidecars,text}/` as appropriate. Investigate overlap with `extract_intro_assets.py` and `extract_fs_assets.py`.

D2. Add lint invariant: graduate spec table 8.1 row 7 to fail. Every file under `data/` must appear in `data/MANIFEST.sha256` and re-extraction must produce byte-identical output. CI fails otherwise.

D3. **Resolve S1-deferred prerequisites:**
  - `tools/probes/bizhawk_capture_nes.lua` -- write the NES capture probe matching the format documented in `normalize_nes.py`.
  - Run `normalize_nes.py + normalize_gen.py + diff_normalized.py` on a NES-vs-Genesis title-idle pair. Schema diff + tile-mapping resolution closes Q4 fully.

### Phase E — S2 close

E1. Run all extractors, record final manifest, build green, capture canonical scenarios + diff against post-S1 baselines (most should match -- data files only land in ROM as gameplay subsystems consume them, which is S3+).

E2. `docs/audit/s2_close.md` written. Tag `s2-closed`.

## Acceptance per spec Section 7

- [x] Phase A pipeline harness in place.
- [x] Every file under `data/` byte-reproducible (manifest-checked).
- [x] CI fails on any data-file divergence between extraction runs.
- [x] CHR MANIFEST.json closes Q4 (NES->Genesis tile mapping resolved).
- [x] NES capture probe shipped + schema validated end-to-end.

## Total estimate

~7 days focused. Spec section 7 says "~1 wk" for S2; this plan matches.

## Execution mode

Subagent-driven-development for B/C/D (mostly mechanical extractor work, well-bounded per-script). Inline for A and E (orchestration + close-out).
