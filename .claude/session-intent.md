# Session Intent Contract — Phase 7 Task 7.7 Enemy Room Matrix

**Created:** 2026-05-10
**Source:** /octo:plan invocation post-Task-7.6 close (aquatic/terrain family).

## Job statement

Wire `enemy_loop_room_init(room_id, scene_id)` to load NES-spec enemy template
+ count from `RoomAttrsOW_C/D` (and dungeon equivalents), populate `ObjType+1..N`
slots, dispatch `enemy_init_fns[t]` per slot. Replace force-spawn debug hook
with full table-driven population. Verify count, spawn coords, no stuck slots,
shutter-door clear gate, drops.

## Auto-filled answers (CLAUDE.md autonomy override — no AskUserQuestion)

- Goal: **Build something** (room matrix wiring)
- Knowledge: **Expert** (Phase 7 task 7.1–7.6 closed; INIT 42 / UPDATE 50 wired)
- Clarity: **Clear requirements** (master plan §7.7 + NES Z_05.asm:1700-1820)
- Success: **Working solution + Production-ready** (NES parity)
- Constraints: **Must fit architecture** (drain primary, NES secondary, sole target Debug.md, no RoomRom)

## NES sources (Rule D1 secondary — wins ties)

- `reference/aldonunez/Z_05.asm:1700-1820` — monster-list-id parse, ObjType fill, AssignObjSpawnPositions trampoline
- `reference/aldonunez/Z_05.asm:1885-…` — AssignObjSpawnPositions
- `reference/aldonunez/Variables.inc:99-101` — RoomObjCount $34E / RoomObjTemplateType $35F
- `reference/aldonunez/Variables.inc:331` — LevelInfo_FoeCounts $6BA2 (offset $24 in 256-byte LevelInfo block)
- ModifyObjCountByHistoryOW / UW — bank 5 helpers

## Drained C (Rule D1 primary)

- `src/oracle/enemies/enemy_common_runtime.c` — RoomObjCount bookkeeping
- `src/oracle/enemies/enemy_runtime.h` — ObjType / ObjState / ObjX / ObjY accessors
- `src/oracle/room/room_load_runtime.c` — room mode2 load path
- `src/game/enemies/enemy_loop.c:669-693` — `enemy_loop_room_init` stub awaiting wiring (TODO at lines 680-690)

## Coverage

- **Coverage**: PARTIAL (room-init enemy load NOT drained; per-slot init dispatch landed in Task 7.2-7.6)
- **Stance**: EXTEND — adopt per-slot dispatch from Task 7.1-7.6; add room→template lookup + ObjList copy + AssignObjSpawnPositions on top.

## Steps

1. Map NES Z_05.asm:1700-1820 into `enemy_room_matrix.c` (or extend enemy_loop.c). 4-line header per Rule D1.
2. Verify data tables: `RoomAttrsOW_C/D`, dungeon equivalents, FoeCounts subarray at LevelInfo+$24, ObjListAddrs + ObjList00-29.
3. Implement `ModifyObjCountByHistoryOW/UW` per NES.
4. Wire `enemy_loop_room_init` to call new path; remove `(void)room_id; (void)scene_id;` stubs.
5. Probe: OW room $77 → expected template; UW L1 entry → template per first room.
6. Probe: room-clear gate → kill all → shutter doors open → drop appears.
7. Verify count + spawn coords match NES dump for sample of 4 OW + 4 UW rooms.
8. Commit per master plan: `gameplay: complete enemy families`.

## Boundaries

- NO RoomRom edits (`feedback_no_new_roomrom_files` standing rule).
- Sole build target Debug.md via Debug.bat.
- Drained `_runtime.c` in `src/oracle/**` is primary; NES asm is final authority on ties.
- Use existing extracted data: `src/data/object_lists.inc`, `src/data/rooms_overworld.inc`, `src/data/level_info.inc`.

## Provider availability

Skipping multi-AI orchestration — task is implementation-bound, not research.
