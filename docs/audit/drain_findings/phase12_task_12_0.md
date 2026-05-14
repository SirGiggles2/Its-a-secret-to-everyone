# Phase 12 Task 12.0 — Incremental Promotion Gate

- **NES source**: N/A — process gate, no NES surface.
- **Drained C**:  N/A.
- **Coverage**:   FULL (gate tool + audit doc landed).
- **Stance**:     ADOPT — implements the master plan Task 12.0
                  remediation per debate (Codex + Opus 11-phase
                  integration-cliff risk). Incremental promotion
                  replaces the late-bulk Task 12.2 single high-risk
                  merge.

## Deliverables

`tools/audit/check_incremental_promotion.py` — lists every
`RoomRom/src/*.c` TU with bucket classification, target path,
on-disk reconciliation against
`docs/audit/roomrom_promotion_audit.md`. Exits 0 today (baseline
pass); exits 2 once a Phase 12.2 PR introduces a deferral count
breach > 1 phase without a documented blocker.

`docs/audit/roomrom_promotion_audit.md` — Task 12.1 baseline audit
of 36 RoomRom/src .c TUs grouped into 4 buckets (harness-only,
shared-gameplay, generated-asset, obsolete-debug). Family-ordered
migration plan for Phase 12.2.

## Baseline counts (2026-05-14)

| Bucket           | Count | Action |
|------------------|-------|--------|
| harness-only     | 2     | Stays in `RoomRom/src/`.            |
| shared-gameplay  | 27    | Migrates to `src/game/<sub>/` or `src/state/`. |
| generated-asset  | 7     | Migrates to `data/<sub>/`.          |
| obsolete-debug   | 0     | (none).                              |

All 36 on-disk TUs are classified; zero unclassified-on-disk;
zero stale-classification rows.

## Promotion order

Per master plan rule (one family at a time). Order in
`roomrom_promotion_audit.md` § "Promotion order":

1. substrate-singletons (inventory, pause, rng) — 3 TUs.
2. palette + bg/ow_palette — 3 TUs.
3. items (arrow, bomb, boomerang, candle_fire, magic_shot) — 5 TUs.
4. combat (combat, link_damage) — 2 TUs.
5. HUD — 1 TU.
6. world meta + render — 6 TUs.
7. dungeon meta + render — 7 TUs.
8. generated-asset (incl. redux_*) — 7 TUs.

Smallest blast radius first; substrate-singletons unblock per-state
tests; items + combat are isolated subsystems with stable APIs.

## Status

CLOSE — Task 12.0 gate tool + audit doc shipped. Phase 12.2 PRs
ride this gate (one family per PR, exit-2 floor protects accidental
regression).
