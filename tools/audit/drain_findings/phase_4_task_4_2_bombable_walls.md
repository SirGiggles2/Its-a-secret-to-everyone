# Phase 4 Task 4.2: Bombable Walls — Substrate Drain Findings

**Status:** Substrate-prepared, feature work pending. Per debate 008 disposition (B+D hybrid).

**Master plan reference:** `docs/superpowers/plans/2026-05-02-title-roomrom-full-port-master-plan.md` lines 803–811 (Task 4.2 checklist).

**Stance per Rule D1:** ADOPT for state-mutation substrate (already drain-MATCH); EXTEND with Genesis-native bomb-collision detection (no candidate drain — `Coverage: PARTIAL`).

---

## Substrate inventory (drain MATCH, native, landed in commits 9da0057c..116d84a4)

These functions in `src/game/room/room_dispatch.{c,h}` cover the state-mutation half of Task 4.2. Bombable wall implementation will call them directly.

### State-mutation substrate

| Native function | NES asm | Drained C | Coverage | Stance |
|---|---|---|---|---|
| `room_get_room_flags` | `Z_05.asm:GetRoomFlags` | `roomrt_get_room_flags` (room_runtime.c:14-22) | FULL | ADOPT |
| `room_set_door_flag(dir_idx)` | `Z_05.asm:2112 SetDoorFlag` | `roomrt_set_door_flag` (room_runtime.c:84-89) | FULL | ADOPT |
| `room_reset_door_flag(dir_idx)` | `Z_05.asm:ResetDoorFlag` | `roomrt_reset_door_flag` (room_runtime.c:91-100) | FULL | ADOPT |
| `room_trigger_open_door(val)` | `Z_05.asm:TriggerOpenDoor` | `roomrt_trigger_open_door` (room_runtime.c:157-160) | FULL | ADOPT |
| `room_touch_door_bombable` | `Z_05.asm:TouchDoor_Bombable` | `roomrt_touch_door_bombable` (room_runtime.c:232-236) | FULL | ADOPT |
| `room_touch_door_wall` | `Z_05.asm:TouchDoorWall` | `roomrt_touch_door_wall` (room_runtime.c:162-164) | FULL | ADOPT |
| `room_mark_room_visited` | `Z_07.asm:MarkRoomVisited` | `roomrt_mark_room_visited` (room_runtime.c:294-299) | FULL | ADOPT (already wired via z07_mark_room_visited) |
| `room_check_secret_trigger_block_door` | `Z_05.asm:CheckSecretTrigger_BlockDoor` | `roomrt_check_secret_trigger_block_door` (room_runtime.c:209-213) | FULL | ADOPT |
| `room_trigger_shutters` | `Z_05.asm:TriggerShutters` | `roomrt_trigger_shutters` (room_runtime.c:182-185) | FULL | ADOPT |

### Wiring gap (debate 008 Sonnet finding)

7 of the 9 functions above lack `z07_*` wrappers in `src/gen/z_07.c`. Without wrappers, `NATIVE_ROOM` flip is a no-op for them. This is the **first concrete work for Task 4.2 implementation**:

| Missing wrapper | Where to add |
|---|---|
| `z07_set_door_flag` | `src/gen/z_07.c` near existing `z07_mark_room_visited` (~line 358) |
| `z07_reset_door_flag` | same cluster |
| `z07_trigger_open_door` | same cluster |
| `z07_touch_door_bombable` | new cluster (touch-door family) |
| `z07_touch_door_wall` | same cluster |
| `z07_check_secret_trigger_block_door` | new cluster (secret-trigger family) |
| `z07_trigger_shutters` | same cluster |

Format follows existing pattern at `src/gen/z_07.c:310-444`:
```c
void z07_set_door_flag(unsigned int dir_idx) {
#ifdef NATIVE_ROOM
    room_set_door_flag(dir_idx);
#else
    roomrt_set_door_flag(dir_idx);
#endif
}
```

---

## Feature work pending (no drain — greenfield)

Task 4.2 checklist items NOT covered by today's substrate:

| Checklist item | Drained C? | Required work |
|---|---|---|
| Extract bombable wall metadata | NONE | Greenfield — `tools/builder/extract_bombable_walls.py`; per-room tile coordinate + reveal-target-room map from NES ROM |
| Add bomb explosion collision with secret wall tile | NONE candidate (collision_runtime.c covers monster/Link, not tile-secret) | EXTEND from `collision_dispatch.h` API; new function `collision_bomb_to_bombable_wall` |
| Reveal cave/stairs | PARTIAL (room_set_door_flag mutates state; tile-clear is separate) | Extend `room_dispatch` with `room_reveal_secret_tile(slot)` calling existing `c_change_tile_obj_tiles` or native equivalent |
| Persist reveal flag | FULL via `room_set_door_flag` (substrate ADOPT) | Wire-up only |
| Play reveal sound | PARTIAL (`room_go_to_next_mode_play_level_song` exists; reveal sfx is different — `SecretFoundTune`) | Use existing `enemy_play_secret_found_tune` (already native at `src/game/enemies/enemy_dispatch.h:32`) |
| Prevent repeated reveal mutation | FULL via room flags bit-test | Wire-up only |
| Verify each bombable wall class | NONE | Test/probe — BizHawk script per wall instance |

**Greenfield justification (`tools/audit/drain_coverage.py` exit-0 condition):** bomb→tile collision and bombable-wall metadata extraction have no `*_runtime.c` candidate. Tile collision lives in NES asm `Z_07.asm` BombHandler region, not in oracle drains. Approved as `Stance: GREENFIELD` for those items only — state-mutation items remain `Stance: ADOPT`.

---

## Gate plan

### Gate 1 (this file — per-function diff)
Above table satisfies Gate 1 entry for the 9 substrate functions. Each `roomrt_*` source file + line range cited; NES asm reference in `Z_05.asm` cited. Drain MATCH carries through commits 9da0057c..116d84a4 (verified by build green + RoomRom links native unconditionally).

### Gate 2 (per-RAM-cell parity oracle, before Task 4.2 phase exit)
- Snapshot SRAM bytes 0x6BAF/0x6BB0 (ROOM_FLAGS_PTR) + indirect flag byte at `*ptr+CUR_ROOM_ID` before bomb detonation.
- Run scripted bomb→bombable-wall sequence on Genesis Title.md vs NES ZeldaRedux.nes (or equivalent reference).
- Diff via `tools/parity/diff.py`. Expected: bit 5 of room flag byte transitions 0→1 on both, room marked visited.

### Gate 3 (per-scenario parity oracle, before milestone tag)
- BizHawk Lua probe: fresh boot → walk to overworld room with bombable wall (e.g. Level-1 entrance secret) → place bomb → wait for detonation → verify reveal sprite + SRAM persist.
- Bundle screenshot + SAT + SRAM dump + RAM trace per memory rule `feedback_one_big_probe`.
- Compare against `build/generated/nes_reference/` capture from Phase 1.5 harness.

---

## Estimated effort (debate 008 Opus revision)

| Phase | Hours | Output |
|---|---|---|
| 7 z07_ wrappers in src/gen/z_07.c | 2-3 | Both ROMs green, Title.md sha unchanged |
| Bombable wall metadata extractor | 3-4 | `tools/builder/extract_bombable_walls.py`, per-room JSON |
| Bomb→tile collision + reveal flow | 4-5 | Native `collision_bomb_to_bombable_wall` + RoomRom wire-up |
| Gate 2 RAM trace + Gate 3 screenshot | 2 | `tools/parity/` instances + commit |
| **Total** | **11-14** | Task 4.2 closed |

Substrate from commits 9da0057c..116d84a4 saves approximately 8 hours of state-mutation infrastructure that would otherwise have been written from scratch.

---

## Provenance

- **Debate:** `debates/008-drain-port-disposition/synthesis.md`
- **Substrate commits:** `git log --oneline 9da0057c..116d84a4`
- **Gate enforcement:** `tools/gates/check_phase_label.py` (rejects future "phase 4n" sub-labels)
- **Memory rule:** `feedback_follow_master_plan` (read master plan first action of every session)
