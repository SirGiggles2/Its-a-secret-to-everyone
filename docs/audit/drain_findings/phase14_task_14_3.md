# Phase 14 Task 14.3 — Completion Matrix

- **NES source**: NES Zelda 1 full coverage:
                  - Every OW room (128 rooms / 8x8 OW grid).
                  - Every UW dungeon room (9 dungeons × ~16 rooms
                    avg).
                  - Every cave (per `Z_05.asm` cave dispatch).
                  - Every item (per `Z_07.asm` item table).
                  - Every enemy family + boss (per Phase 7 + 8).
                  - Every save / load / death code path.
                  - Every Redux option flipped at least once.
- **Drained C**:  Phase 4 OW dispatch, Phase 5 UW dispatch, Phase 3
                  cave dispatch, Phase 6 items, Phase 7 enemy
                  families, Phase 8 bosses, Phase 9 save / options.
                  Coverage validation is meta-task; no new runtime
                  drain.
- **Coverage**:   PARTIAL — Phase 14.3 verification depends on
                  Tasks 14.1 + 14.2 GREEN runs (dungeon harness
                  passes). OW + cave + item + enemy coverage
                  validated via existing Phase 4 / 3 / 6 / 7 probes
                  in the regression matrix.
- **Stance**:     PARTIAL — verification spec ADOPT; live execution
                  gated on Task 14.0 population.

## Completion matrix items

| Item                                       | Where verified                           |
|--------------------------------------------|------------------------------------------|
| Visit every overworld room                 | OW completion probe (Phase 4)            |
| Visit every cave                           | Cave dispatch probe (Phase 3)            |
| Visit every dungeon room                   | Phase 14.0 dungeon harness (per dungeon) |
| Collect every item                         | Item-dispatch probe (Phase 6)            |
| Defeat every enemy family                  | Phase 7 family73 probe + Phase 14.1/2    |
| Defeat every boss                          | Phase 14.0 dungeon harness               |
| Exercise every save/load/death path        | Phase 9.7 deferral (death/continue modes) |
| Exercise every option at least once        | Phase 9.4 deferral (8 unwired consumers) |
| Smoke 4-player mode                        | Phase 13 deferred-feature (off path)     |
| Commit `release: complete quest verification` | gated on all above                    |

## Run command

```
python tools/run_regression_matrix.py
python tools/dungeon_harness/run_all.py
python tools/audit/check_incremental_promotion.py
```

All three exit 0 = completion matrix GREEN.

## Status

PARTIAL — Task 14.3 spec + run-command + report-path locked.
Live execution gated on Task 14.0 + Task 9.7 + Task 9.4 + Phase
12 family-migration deferrals. Completion matrix becomes
authoritative once those land.
