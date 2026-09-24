# Finish-line plan — 2026-09-24

Companion to `2026-09-10-project-completion.md` (task IDs, evidence rules and the live board stay there; this file only sets order and cadence). Written from inspection of: main @ f513b997 + dirty tree, branch `feat/cave-entry-transition-parity`, recovery snapshot, `builds/reports/recovery/`, `builds/play/`.

## Findings that change the plan

| # | Finding | Consequence |
|---|---|---|
| F1 | All Sep 11–24 work (~150 files: Ganon/Zelda, enemies, drops, HUD/pause, palettes, LevelInfo) is **uncommitted** on `main`. | Single-disk loss risk. Commit first. |
| F2 | `feat/cave-entry-transition-parity` (Aug 3–Sep 10, 40 commits) is **not in main**: SRAM saves (`save_game.c`, `sram_backend.c`, `mode_save.c`), File Select linked into ROM, all 11 builder extractors wired + from-scratch gate, UW generator 586/586 rooms byte-exact, injected boss rooms, Q2 dungeon maps, boss INIT parity 10/10, X+Y+Z Q2 boot. | Plan P7.2 (saves), P9.1 (Q2 entry), P10.2 (builder) and P0.14 are partly done on that branch. Merge instead of redoing. |
| F3 | Sep work captured rooms `$42`/`$32` from **live NES CIRAM** into the blob. | Violates the ship rule (assets derived only from user ROM). The branch's ROM-derived UW generator replaces this. |
| F4 | Two conflicting trackers: Prime Directive (`Phase 17`, next action "Phase 8 Task 8.1 scaffold") vs completion plan board (last update 09-12). | Retire the PD "next action" pointer; completion plan board is sole authority. |
| F5 | Throughput: 13 days produced ~35 narrow PASS scopes; P1–P10 parents all still open. Staged single-behavior fixtures dominate. | Switch default test unit to **connected routes**; fix what the route exposes. Staged fixtures only to isolate a route failure. |

## Execution order

### S0 — Secure and consolidate (blocking, ~1 session)
1. Commit dirty tree to `recovery/2026-09` (exclude `RoomRom/out/*.json` >1 MB aggregates if ignored; keep sentinels).
2. Merge `feat/cave-entry-transition-parity` into it. Hand-resolve source (`RoomRom/src/main.c`, `enemy_ganon_bridge.c`, `inventory_render.c`, `uw_map_builder.c`, `enemy_render.c`, `audio_adapter.c`, `build_debug.py`). **Never hand-merge generated files** (`uw_room_blob.c`, `uw_collision_data.c`, atlases, `data/*.inc`): regenerate from merged generators, then freshness check.
3. Drop the live-CIRAM `$42`/`$32` capture path; confirm ROM-derived generator emits both rooms byte-equal to the capture.
4. Gate: `Debug.bat` builds; regression matrix 12/12; Ganon→Zelda `reward.lua`; Aquamentus consumer; File Select→New Game; save survives hard reset. Fast-forward `main`.

### S1 — Q1 connected route as the driver (P2 → P8)
One controller-only route, checkpointed per segment via **SRAM saves** (not savestates): boot → file create → sword cave → L1 → … → L9 → Ganon → rescue → ending.
- Each segment: run, log first divergence, fix at owner, re-run that segment only.
- Opens P2.1–P2.6, P5.x, P6.x, P7.1–P7.3, P8.1–P8.4 as encountered. No staged HP/position/timer writes inside a segment.
- Route inputs recorded as replayable input files → they become the regression suite (replaces growing fixture pile).

### S2 — Breadth not on the route (parallelizable per family)
- P3 enemy families: one natural encounter per family; open rows from `docs/audit/enemy_parity/INDEX.md`.
- P6 remaining bosses: Dodongo, Manhandla, Gleeok, Digdogger, Gohma, Patra, Moldorm/Lanmola — one real kill each + variant diff.
- P4 items/secrets table; unwired dispatch rows `$2F` pond fairy, `$5E` flute secret, `$61–$68` OW objects.
- P7.4 frontend return paths; ending renderer stubs (sprites/credits/finalize).

### S3 — Q2 (P9)
Q2 route using the merged X+Y+Z boot and Q2 map data; only Q2-distinct content gets new captures.

### S4 — Audio (P7.5) — last, per user direction
Diagnose `audio_init` not called on active boot; event wiring before driver changes.

### S5 — Release (P10)
Builder from merged branch → drag-and-drop shell, clean-staging build, reproducibility repeat, package content check, generated-ROM launch.

## Cadence rules added
- Commit after every accepted task (small commits, one owner each). Never >1 day uncommitted.
- Board update per commit; no narrative >15 lines per task entry.
- Stop criterion per segment = route passes, not "focused scope PASS".
