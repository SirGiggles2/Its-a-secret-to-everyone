# Session Plan — Phase 7 Task 7.7 Enemy Room Matrix

**Created:** 2026-05-10
**Intent contract:** [.claude/session-intent.md](session-intent.md)

## Deliverable

`enemy_loop_room_init(room_id, scene_id)` populates ObjType+1..N from NES room
attribute tables on every overworld + dungeon room load. Force-spawn hook
becomes a debug-only override. Phase 7 close-probe set passes.

## Phase weights

- DISCOVER 5%  — already done (ObjListAddrs + RoomAttrsOW_C/D + LevelInfo extracted)
- DEFINE 10%   — clear from NES Z_05.asm:1700-1820; only edge cases need decisions
- DEVELOP 65%  — primary work: native room→template→ObjType pipeline
- DELIVER 20%  — probes (count, coords, room clear, drops, no-stuck) + commits per step

## Provider availability

🔵 Claude only — implementation-bound, no multi-AI debate needed.
Multi-AI route reserved for /octo:debate on edge cases (food-attract list, history fixup, cave special-case).

## Step ordering

1. **Step 1** — Read drain-side data shape: `src/oracle/enemies/enemy_common_runtime.c`,
   `src/oracle/enemies/enemy_runtime.h`, confirm ObjType/ObjState/ObjX/ObjY layout.
2. **Step 2** — Read NES Z_05.asm:1700-1830 in full; transcribe ModifyObjCountByHistoryOW/UW.
3. **Step 3** — Add `level_info_foe_counts` extractor (or reach into existing LevelInfo+$24 directly).
4. **Step 4** — Add `enemy_room_matrix.c` (`enemy_room_load_objects(scene, room_id)`) with header.
5. **Step 5** — Implement AssignObjSpawnPositions native body (NES Z_05.asm:1885+).
6. **Step 6** — Wire `enemy_loop_room_init` to call new path; remove force-spawn fallback.
7. **Step 7** — Probe OW room $77 (forest) — expected 5 octorocks at NES coords.
8. **Step 8** — Probe UW L1 entry (room $73) — expected per ObjList template.
9. **Step 9** — Probe room-clear → shutter open → drop spawn.
10. **Step 10** — Phase 7 family-close audit doc; tracker refresh; commit.

Each step gets its own commit with `phase 7 task 7.7 step N: <one-line>`.

## Success criteria

- `Debug.bat` green; banned-token gate green.
- Room enter → enemy slots match NES count + types for sample rooms.
- Room clear → shutter doors open + drop spawns.
- No slot stuck at off-screen / invalid coords.
- Tracker FRESH; phase 7 close gate gains evidence.

## Next action

Step 1 — read drain headers + room load runtime to confirm cell layout.
