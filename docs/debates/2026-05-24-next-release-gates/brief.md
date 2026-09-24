# Debate Brief — What release-gate work must land next to ship FINAL TRY v1.0?

**Date:** 2026-05-24
**Project:** FINAL TRY — Zelda 1 NES → Sega Genesis port via SGDK + drained C
**Sole build target:** `builds/Debug.md` (1.0 MB), single script `Debug.bat`
**Active phase:** 17 — Public Builder Release (FINAL phase of master plan)

## Project state snapshot

All 17 master-plan phases are marked `complete` or `active` (Phase 17 only).
14 out-of-phase `REPLACE`-stance task entries piled up between 2026-05-16 and
2026-05-17 (cave entry chain, NES NMI sync restore, enemy visual restore,
audio dispatcher fix, Triforce mode-12 transition, boss matrix sweep, etc.).
None have a `regression_matrix_run` recorded.

The tracker says "next concrete action = Phase 8 Task 8.1 Boss Framework"
but Phase 8 is closed — that pointer is stale.

Uncommitted WIP (git status, 2026-05-24):
- `RoomRom/data/regen_sentinels.json`, `RoomRom/src/bg_sparse_chr.{c,h}`,
  `RoomRom/tools/gen_bg_sparse.py` — sparse CHR work
- `data/audio_music/ow_theme_vgm.c` + new `lm_zelda_ow_*.{bin,vgm}`,
  `sonic1.{bin,vgm,xgm}`, `ow_theme_pcm.{c,h}` — overworld VGM swap +
  PCM path
- `src/game/world/render/{cave_fade,sprite_render}.c`,
  `src/game/debug/debug_tilegrid.c`, `src/sgdk_adapter/audio_adapter.c`
- `tools/parity/diff_bg_tilemap.py` (new), drain coverage JSON updates,
  audit drain docs (combat/enemies/hud/orphans)
- Recent commits (last 5) all cave-bonfire / cave-entry chain
  (`6c4c1b63`..`4c416831`)

## Open Phase 17 release-gate deferrals

From `prime_directive_tracker.json` phase 17 evidence:

1. **`phase17_package_check_tool`** — PARTIAL. `tools/builder/package_check.py`
   exists, filters 106 banned generated assets; need: gold-master diff
   against built-from-scratch package, sha256 manifest pin for every file
   in the public zip.
2. **`phase17_builder_ux_shell`** — PARTIAL. `tools/builder/build.py
   --check-toolchain` works; need: single-command builder UX (probably
   `make-release.bat`) for end users with zero SGDK setup, error-message
   polish for missing prerequisites.
3. **`phase17_release_documentation`** — PARTIAL. `docs/RELEASE.md`
   exists but is engineering-internal; need: end-user-facing
   `INSTALL.md` / `BUILD.md` / `LEGAL.md` triad, screenshots, demo gif.
4. **`phase17_from_scratch_build_gate`** — DEFERRED_RELEASE. Gated on
   Phase 14 GREEN. `tools/builder/from_scratch_gate.py` exists as
   scaffold only; needs: fresh-clone VM run that produces a byte-
   identical `Debug.md`.
5. **`phase17_final_release_gate`** — DEFERRED_RELEASE. Orchestrator
   `tools/builder/release_gate.py` lists 7 gates, all infra present
   but `hardware_smoke` deferred per Phase 16.2.

## Upstream blockers feeding Phase 17

- **Phase 16.2 hardware_smoke** — DEFERRED_HARDWARE. Real Genesis console
  (or MegaSD / Mister FPGA) boot + 60s play probe. No CLI scope by
  definition; needs physical hardware run.
- **Phase 16 `phase16_cross_emulator_matrix`** — PARTIAL. BizHawk-only
  today; need BlastEm + Gens-KMod + Exodus runs to catch emulator-
  specific divergence.
- **Phase 14 `phase14_dungeon_harness_population`** — PARTIAL.
  `tools/dungeon_harness/manifest.json` has 18 rows (9 dungeons x Q1/Q2)
  all SKIP; needs live capture pass to produce Q1 GREEN x9 + Q2 GREEN x9.
- **Phase 11 `phase11_live_capture_pass`** — PARTIAL. 8 baselines are
  binary placeholders; needs BizHawk capture run to convert SKIP→GREEN.
- **Phase 10 `task_10_3_audio_link_into_debug_md`** + `task_10_5_audio_probes_runtime`
  — PARTIAL. Audio TUs not linked into Debug.md yet; MIDI-FS dep open;
  blocks all runtime audio probe assertions.
- **Phase 9.4 `phase94_eight_unwired_consumers`** — PARTIAL. Options
  framework wired to 6/14 consumers; 8 still unwired
  (no_reduced_flashing, low_health_warning, ab_swap, etc.) — feeds
  Phase 16 accessibility polish.

## Constraints

- Sole build target rule: any new tool/probe lands in `tools/builder/`
  or `tools/debug/probes/` or `tools/audit/`, never re-introducing
  retired ROMs (`whatif.*`, prior frontend-only, `CombinedDebug.*`).
- RoomRom freeze (WT-5): no new files under `RoomRom/`.
- Hardware smoke is out-of-CLI-scope but can be unblocked by
  cross-emulator matrix as proxy (BlastEm/Gens/Exodus).
- User is solo dev; cost = wall-clock days, not headcount.

## The question

**What is the smallest, highest-leverage release-gate work that must
land before FINAL TRY v1.0 ships?** Rank-order the top 3 items.
Justify each with: (a) which deferred gate it closes, (b) blast
radius if skipped, (c) wall-clock effort estimate.

Deliver in <= 300 words. Sharp, opinionated, with file paths.
