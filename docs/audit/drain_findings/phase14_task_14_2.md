# Phase 14 Task 14.2 — Second Quest Route

- **NES source**: NES Zelda 1 Quest 2 dungeons L1..L9 (Second Quest
                  layout). Different room layouts + boss variants
                  per `Z_07.asm` quest-2 LevelInfoBlock branch.
- **Drained C**:  Same per-boss drained bodies (Phase 8). Quest-2
                  variants land via existing quest-id dispatch in
                  `progress_state.h`.
- **Coverage**:   NONE — gated on Task 14.0
                  `phase14_dungeon_harness_population` deferral.
                  9 Quest-2 manifest rows present.
- **Stance**:     PARTIAL — manifest rows ADOPT; execution gated.

## Manifest rows (Quest 2)

| Level | Boss          | Reward                |
|-------|---------------|-----------------------|
| L1Q2  | Gleeok 2-neck | TriforcePiece(1)      |
| L2Q2  | Dodongo x3    | TriforcePiece(2)      |
| L3Q2  | Manhandla     | TriforcePiece(3)      |
| L4Q2  | Gleeok 1-neck | TriforcePiece(4)      |
| L5Q2  | Digdogger     | TriforcePiece(5)      |
| L6Q2  | Gohma Red     | TriforcePiece(6)      |
| L7Q2  | Patra         | TriforcePiece(7)      |
| L8Q2  | Gleeok 4-neck | TriforcePiece(8)      |
| L9Q2  | Ganon         | ZeldaRescue           |

## Run command

```
python tools/dungeon_harness/run_all.py --quest 2
```

## Status

PARTIAL — Task 14.2 manifest rows + run-command + boss roster
locked (notably Q2 substitutes Gleeok-2 / Patra / Gleeok-4 for
Q1's Aquamentus / Aquamentus / Gohma Blue). Execution gated on
Task 14.0 population deferral.
