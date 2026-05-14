# Phase 14 Task 14.1 — First Quest Route

- **NES source**: NES Zelda 1 Quest 1 dungeons L1..L9 + boss kills
                  + triforce rewards + Ganon room. Per-level
                  `LevelInfoBlock` data at canonical NES offsets.
- **Drained C**:  Per-boss bodies (Phase 8 — all 10 boss families
                  drained); per-level LevelInfoBlock data tables;
                  Phase 5 dungeon-core dispatch wired.
- **Coverage**:   NONE — gated on Task 14.0
                  `phase14_dungeon_harness_population` deferral.
                  9 Quest-1 manifest rows present in
                  `tools/dungeon_harness/manifest.json`; save
                  states + per-row probes NOT yet captured.
- **Stance**:     PARTIAL — manifest rows ADOPT (boss + reward
                  inventory per dungeon); execution gated on Task
                  14.0 population.

## Manifest rows (Quest 1)

| Level | Boss          | Reward                |
|-------|---------------|-----------------------|
| L1Q1  | Aquamentus    | TriforcePiece(1)      |
| L2Q1  | Dodongo       | TriforcePiece(2)      |
| L3Q1  | Manhandla     | TriforcePiece(3)      |
| L4Q1  | Gleeok 1-neck | TriforcePiece(4)      |
| L5Q1  | Digdogger     | TriforcePiece(5)      |
| L6Q1  | Gohma Red     | TriforcePiece(6)      |
| L7Q1  | Aquamentus    | TriforcePiece(7)      |
| L8Q1  | Gohma Blue    | TriforcePiece(8)      |
| L9Q1  | Ganon         | ZeldaRescue           |

## Run command

```
python tools/dungeon_harness/run_all.py --quest 1
```

Currently outputs `0 GREEN / 0 RED / 9 SKIP / 9 total` because
save states + per-row probes are missing.

## Status

PARTIAL — Task 14.1 manifest rows + run-command + report path
locked. Execution gated on Task 14.0 population deferral
(`phase14_dungeon_harness_population`).
