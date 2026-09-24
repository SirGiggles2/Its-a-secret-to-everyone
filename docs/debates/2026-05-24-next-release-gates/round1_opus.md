# Opus — Round 1 opening

The tracker is lying. 17 phases marked "complete" with 14 unverified REPLACE
entries sitting on top, plus ~30 lines of uncommitted WIP touching cave,
enemy, and audio runtime. "Complete" today means "evidence file written,"
not "ROM proven." That distinction *is* the release blocker.

**Rank-ordered top 3:**

### 1. Phase 14 dungeon harness population — `tools/dungeon_harness/run_all.py`

- **Closes:** `phase14_dungeon_harness_population` (PARTIAL → GREEN).
- **Blast radius if skipped:** All 17 close-gate `screenshot_state_evidence`
  fields are spot probes. No phase has proven Q1 L1-L9 end-to-end clear,
  let alone Q2. Without 18/18 GREEN here, every downstream packaging gate
  is asserting on faith. This is the single biggest "phase complete but
  did it actually work" hole.
- **Effort:** 2–3 wall-clock days. 9 dungeons × ~30 min scripted-input
  replay each, then debug what breaks. Inputs already templated at
  `tools/dungeon_harness/probes/dungeon_template.lua`.

### 2. Cross-emulator matrix — `tools/builder/cross_emulator_matrix.py` (new)

- **Closes:** `phase16_cross_emulator_matrix` (PARTIAL → GREEN). Best
  available proxy for `phase16_hardware_tests` (DEFERRED_HARDWARE) given
  no console on hand.
- **Blast radius:** BizHawk hides Genesis edge cases (DMA-during-active-
  display, Z80 bus arbitration, FIFO underflow). Ship-without =
  forum-rage "doesn't boot on BlastEm" within 48 h of release.
- **Effort:** 1 day. Scripted boot + 60 s capture on BlastEm + Gens-KMod
  + Exodus. Diff CRAM/VRAM snapshots vs BizHawk baseline.

### 3. From-scratch build gate — `tools/builder/from_scratch_gate.py`

- **Closes:** `phase17_from_scratch_build_gate` (DEFERRED_RELEASE).
- **Blast radius:** No reproducible build → legal exposure on
  distribution + zero confidence in `package_check`. This is the gate
  that converts "it builds on Jake's machine" into "a stranger can
  reproduce v1.0."
- **Effort:** 1 day on a fresh Win10 VM + clone + SGDK pinned install +
  byte-identical Debug.md verification.

**Defer:** audio link (Phase 10.3) blocks user reviews but not technical
ship; release v1.0-silent + v1.0.1-with-audio is a defensible split.
Builder UX + release docs (17.2, 17.4) are last-mile polish — gate them
on 1+2+3 passing first.

— Opus — Round 1 opening
