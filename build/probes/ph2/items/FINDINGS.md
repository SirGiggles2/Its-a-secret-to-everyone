# Phase 2 Task 2.2 close-gate evidence — bundled item probe (rev2)

**Probe:** `RoomRom/probe_roomrom_items_bundled.lua` (rev2)
**ROM:** `RoomRom/out/RoomRom.md` (built 2026-05-04 00:34:01)
**Run:** 2026-05-04 via /bizhawkScript
**Verdict:** **GREEN — 6/6 items render correctly.**

## Process

Rev1 of the probe used 1 capture per item action with 1-frame button presses + SAT slot reads. SAT reads returned all-zero (probe-side bug, SAT_BASE 0xF400 wrong for SGDK shadow-SAT pattern in this build). Single captures missed transient sprites (boomerang in flight, beam mid-trajectory, bomb fuse, explosion puff).

Rev2 (per /chuckle + /octo:debate synthesis) drops SAT readout, replaces single captures with strip captures (every 4-6 frames over 24-120 frames per item), and adds a one-shot VRAM CHR-slot tile-data dump at boot to verify atlas was DMAed into VRAM.

## Captures (99 PNGs)

| Item | Capture window | PNG count | Verdict |
|---|---|---|---|
| Sword (4 facings) | 24f stride 4 | 24 (6/facing) | **VISIBLE** in `01_sword_*_f04.png` for all 4 facings — attack pose + sword tile |
| Beam (right + down) | 30f stride 4 | 16 (8/facing) | **VISIBLE** in `02_beam_right_f04.png` — sword + beam adjacent; `f12` shows beam flying separated from Link |
| Boomerang (down + right) | 60f stride 4 | 30 (15/facing) | **VISIBLE** briefly in `03_boomerang_right_f04.png` — small green/yellow tile launched from Link's hand |
| Arrow (right) | 30f stride 4 | 8 | **VISIBLE** in `04_arrow_right_f04.png` — yellow arrow flying right of Link |
| Bomb fuse | 0–60f of `05_bomb_*` | part of 20-PNG strip | **VISIBLE** at Link's feet during fuse window |
| Bomb explosion | `05_bomb_f60.png` | 1 frame | **VISIBLE** — white/pink puff overlapping Link sprite (NES Z1 explosion graphic) |

## VRAM CHR-slot sweep (boot frame, in `probe_log.txt`)

Probe dumped 32 bytes from each of 20 VRAM tile indices spanning 0x100–0x360. Pattern: tiles 0xN00, 0xN20, 0xN80, 0xNA0, 0xNC0, 0xNE0 contain CHR data (24–32/32 nonzero bytes); tiles 0xN40, 0xN60 are blank (consistent with 31-tile-per-pal atlas where blocks straddle 32-tile-aligned boundaries). Cross-checks memory `project_chr_extraction_items_blocker` — sword_vert/horz, boomerang, arrow_vert, bomb, explosion, sword_diag tiles ARE in `roomrom_atlas_items_x4` and ARE loaded into VRAM. Horizontal arrow / candle / rod tile gaps remain (per memory) but are not exercised by this probe.

## Phase 2 close-gate steps advanced

| Step | Status |
|---|---|
| `focused_probe_set` | **PASSED** — 99 captures across 6 items, log + manifest |
| `screenshot_state_evidence` | **PASSED** — strip captures span the full sprite lifetime per item |

Steps still pending: `build_REQUIRE_GENERATED_ASSETS`, `diff_vs_nes_reference`, `regression_matrix`, `verify_no_alias_collisions` (Ph2 scope already GREEN — needs record as gate evidence), `PROBE_CYCLE_LIMIT_envelope`, `code_review_requested`, `findings_resolved_or_deferred`, `rerun_probes_and_matrix`, `phase_commit_with_report_paths`.

## Bug-detection branch outcome (per /primedirective)

Original hypothesis "items not rendering" rejected via /chuckle Step 4 NO-OP. /octo:debate synthesis (Skeptic + Pragmatist) identified probe undersampling as root cause. Rev2 fix applied and verified green. No engine-side bug. No `out_of_phase_tasks[]` entry needed; no `deferrals[]` entry needed.
