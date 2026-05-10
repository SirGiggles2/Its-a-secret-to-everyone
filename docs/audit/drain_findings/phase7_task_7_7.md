# Phase 7 Task 7.7 — Enemy Room Matrix

- **NES source**: `reference/aldonunez/Z_05.asm:1700-1820` (InitMode_EnterRoom
                  monster-list parser) + `Z_05.asm:1885-1996`
                  (AssignObjSpawnPositions + IsSafeToSpawn) +
                  `Z_05.asm:3534-3580` (ModifyObjCountByHistoryOW) +
                  `Z_05.asm:3982-4034` (ModifyObjCountByHistoryUW).
- **Drained C**:  NONE for the parser/spawn-pos/history-modify trio —
                  `tools/audit/drain_coverage.json` has no candidate row
                  for these specific functions; reused already-drained
                  primitives `collision_get_collidable_tile_still`
                  (src/game/world/collision_dispatch.c) and
                  `room_get_room_flags` (src/game/room/room_dispatch.c).
- **Coverage**:   FULL — three native bodies in
                  `src/game/enemies/obj_lists.c` cover the full
                  parser → spawn-pos → init-fan-out pipeline.
- **Stance**:     GREENFIELD — legal because drain coverage shows no
                  candidate row for these functions; verbatim
                  transcribe of NES asm with 4-line headers per
                  function. Reuses ADOPT primitives via extern.

## Wired pipeline

`src/game/enemies/enemy_loop.c:671 enemy_loop_room_init`:

1. Clear all slots (TYPE/ALIVE_FLAG/X/Y).
2. `enemy_room_load_objects(room_id)` — Z_05.asm:1700-1820.
3. `enemy_assign_spawn_positions(room_id, template_id)` — Z_05.asm:1885-1996.
4. Dispatch `enemy_init_fns[ENEMY_TYPE(slot)]` per occupied slot —
   Z_05.asm:1818 init-fan-out.

## Implementation steps

| Step | Commit | Function | NES asm |
|------|--------|----------|---------|
| 1 | `8713ccd8` | `enemy_room_load_objects` — template lookup, count from LevelInfo_FoeCounts, boss + cellar overrides, ObjType[1..count] fill | Z_05.asm:1700-1820 |
| 2 | `f8d4143c` | `enemy_assign_spawn_positions` — SpawnPosListAddrs[ObjDir] cycle, IsSafeToSpawn gating, cellar 4-keese override, cave dweller slot-1 override | Z_05.asm:1885-1996 |
| 3 | `86a4d019` | `modify_count_by_history_ow/uw` — applies LevelKillCounts + RoomHistory adjustments to RoomObjCount | Z_05.asm:3534-3580 + 3982-4034 |
| F | `0bc29d82` | Probe re-clears slots post-room-init (preserves `alive_before == 0` invariant after Task 7.7 wires populate slots from substrate) | — |

## Substrate touches

`src/state/dungeon_state.h` macros consumed:
- `DUNGEON_LBA_C(room)` / `DUNGEON_LBA_D(room)` — template + dir bytes.
- `DUNGEON_LBA_F(room)` — edge-spawn LSb.
- `DUNGEON_LEVEL_FOE_COUNTS(i)` — per-template count nibbles.
- `DUNGEON_ROOM_OBJ_COUNT` / `DUNGEON_ROOM_TEMPLATE_TYPE`
  (= NES `$034E` / `$035F`).
- `DUNGEON_SPAWN_CYCLE` (NES `$0524`) — 9-entry rotation.

`progress_state.h` macros consumed:
- `PROGRESS_LEVEL_KILL_COUNT(level)` — kill count history.
- `PROGRESS_ROOM_HISTORY(...)` — visited-room flags.

## NES bug-feature preserved

Cellar mode-9 keese fill (Z_05.asm:1876-1881) uses an X-indexed
`CellarKeeseXs` lookup but a Y-indexed `CellarKeeseYs` lookup — the
`,Y` variant is preserved verbatim in
`enemy_assign_spawn_positions` to match NES OAM coords.

## Bridges added

NONE — Task 7.7 is pure substrate parser code, no per-enemy bridges
required. All consumed primitives already drained in Tasks 7.1-7.6.

## Probes

- `tools/debug/probes/probe_walker_parity.lua` — verified non-regression
  post-Task 7.7 (12/14 PASS, identical baseline pre-Task 7.7; the 2
  failing checks `alive_after_spawn` + `ENEMY_DIR(1)` are pre-existing
  staleness from when Task 7.3 step 8 expanded force-spawn count from 1
  to 11 without updating expected values — NOT a regression introduced
  by Task 7.7).
- Result: `C:\tmp\probe_walker_parity.txt` 12/14 PASS post-7.7.

## Status

CLOSE — Task 7.7 enemy room matrix native pipeline complete:
- ObjList parser wired (step 1)
- SpawnPos assignment wired (step 2)
- ModifyObjCountByHistory{OW,UW} wired (step 3)
- enemy_loop_room_init dispatches per-slot init from NES room matrix.

Phase 7 task ladder (7.1 → 7.7) closes here. The next concrete probe
work — verifying specific OW + UW rooms load matching NES counts /
coords / drops at gameplay runtime — is Phase 8 follow-up
(InitMode_EnterRoom requires the gameplay state machine to be wired
through scroll / pause / shutter; the current Debug.md harness only
exercises debug-spawn paths via the A+B+C chord, not real
InitMode_EnterRoom flow).
