# Phase 8 Task 8.1 — Boss Framework

- **NES source**: `reference/aldonunez/Z_05.asm:8154-8250`
                  (CreateRoomObjects — the per-room reward / push-block
                  spawner called from the tail of InitMode_EnterRoom);
                  `Z_07.asm:771-820` (MoveAndDrawRoomItem / room item
                  slot 19); `Z_07.asm:5453` (RoomKillCount inc on
                  monster death); `Z_04.asm:10999`
                  (Ganon_ActivateRoomItem — re-arms slot 19 on
                  triforce-piece pickup).
- **Drained C**:  NONE for `CreateRoomObjects`. Per-boss INIT/UPDATE
                  bodies (Aquamentus / Dodongo / Manhandla / Gleeok /
                  Gohma / Digdogger / Lamnola / Patra / Ganon) live in
                  `src/oracle/enemies/enemy_boss_runtime.c` and are
                  PRIMARY for Tasks 8.2–8.10. `CreateRoomObjects` is
                  not in `tools/audit/drain_coverage.json` candidate
                  set — only the transpiled body at
                  `src/zelda_translated/z_05.asm:9033` (REPLACE
                  target).
- **Coverage**:   PARTIAL — `boss_framework_room_init`
                  (CreateRoomObjects) covers OW heart-container path,
                  UW per-room L-block reward, secret-trigger gating
                  (3 = last_boss, 7 = foes_for_item), and
                  triforce-piece X-offset. Push-block branch
                  (`LBA_D & 0x40` → `FindAndCreatePushBlockObject`
                  @ `Z_05.asm:5461`) is intentionally a no-op pending
                  a Phase 8 follow-up step that drains
                  FindAndCreatePushBlockObject — boss rooms never
                  trigger this branch, push blocks live in shop /
                  hint rooms.
- **Stance**:     REPLACE for `boss_framework_room_init` — verbatim
                  transcribe of NES asm into a native body that
                  touches the same RAM cells (RoomItemId,
                  ObjState/Type/X/Y[19], deactivation flag) as the
                  transpiled equivalent. Per-boss forwarders for
                  Tasks 8.2+ will be ADOPT (thin call into drained
                  `enrt_*` bodies).

## State substrate (`src/state/boss_state.h`)

Pure NES address mapping — no logic. Authoritative offsets verified
against `reference/aldonunez/Variables.inc` (`RoomItemId := $AB`)
and `CommonVars.inc` (`ObjRoomItemId := $98`,
`RoomKillCount := $34F`).

| Macro | NES address | Source line |
|-------|------------|-------------|
| `BOSS_ROOM_ITEM_SLOT` (=19) | object slot const | `Z_07.asm:813` |
| `BOSS_ROOM_ITEM_NONE` (=0x3F) | sentinel | `Z_07.asm:797` |
| `BOSS_ITEM_ID_HEART_CONTAINER` (0x1A) | OW reward | `Z_05.asm:8230` |
| `BOSS_ITEM_ID_TRIFORCE_PIECE` (0x1B) | UW boss reward | `Z_05.asm:8216` |
| `BOSS_ITEM_ID_MASTER_SWORD_PLACEHOLDER` (0x03) | "no item" stand-in | `Z_05.asm:8174` |
| `BOSS_OW_HEART_CONTAINER_ROOM` (0x5F) | OW gate | `Z_05.asm:8244` |
| `BOSS_OW_HEART_CONTAINER_X/Y` (0xC0/0x90) | OW spawn coords | `Z_05.asm:8235-8236` |
| `BOSS_GAMEMODE_PLAY` (0x05) | OW mode gate | `Z_05.asm:8240` |
| `BOSS_LBA_E_ITEM_MASK` (0x1F) | room-item id bits | `Z_05.asm:8178` |
| `BOSS_LBA_F_SECRET_MASK` (0x07) | secret-trigger bits | `Z_05.asm:8189` |
| `BOSS_LBA_D_PUSH_BLOCK_MASK` (0x40) | push-block bit | `Z_05.asm:8201` |
| `BOSS_LBA_E_TRIFORCE_X_OFFSET` (0x08) | triforce X shift | `Z_05.asm:8220` |
| `BOSS_SECRET_TRIGGER_LAST_BOSS` (0x03) | gated by boss death | `Z_05.asm:8190` |
| `BOSS_SECRET_TRIGGER_FOES_ITEM` (0x07) | gated by RoomKillCount | `Z_05.asm:8193` |
| `BOSS_ROOM_ITEM_ID` | `$AB` | `Variables.inc:52` |
| `BOSS_ROOM_ITEM_STATE` | `$98+19` (= `$AB`, intentional NES alias) | `Z_05.asm:8157` |
| `BOSS_ROOM_ITEM_TYPE/X/Y` | `$EB+19` / `$70+19` / `$84+19` | `Z_05.asm:8208-8210` |
| `BOSS_ROOM_KILL_COUNT` | `$34F` | `CommonVars.inc:10`, `Z_07.asm:5453` |
| `BOSS_CUR_LEVEL` | `$10` | `Z_05.asm:8161` |
| `BOSS_GAMEMODE` | `$12` | `Z_05.asm:8240` |

## Native body (`src/game/enemies/bosses/boss_framework.c`)

`void boss_framework_room_init(unsigned char room_id);` — single
entry point called from `enemy_loop_room_init` after
`enemy_assign_spawn_positions`. Mirrors the NES tail-call ordering:
monster slots placed first, then `CreateRoomObjects` populates
slot 19.

Branch ladder (matches Z_05.asm):

| Path | NES line | Behavior |
|------|---------|----------|
| OW + mode 5 + room $5F | 8230-8245 | spawn heart container at (0xC0, 0x90) |
| OW + (not mode 5 or not room $5F) | 8244 | deactivate slot 19 (state := 0xFF) |
| UW + room flag UW item taken | 8166 | deactivate slot 19 |
| UW + LBA_E low 5 == 0x03 | 8174 | deactivate slot 19, keep id |
| UW + secret trigger == 3 / 7 | 8190-8195 | deactivate slot 19, keep id |
| UW + LBA_D bit 6 (push block) | 8201 | **DEFERRED** no-op (push-block path) |
| UW + item id == 0x1B (triforce) | 8220 | shift spawn X left by 8 px |
| UW default | 8207-8210 | spawn at `world_get_shortcut_or_item_xy_for_room(room_id)` |

UW already-taken check routes through
`progress_get_room_flag_uw_item_state()`
(`src/game/world/progress_dispatch.h`) — the drained native progress
selector lives here, not via the `z01_*` shim layer (those shims
live in `src/gen/z_01.c` and are not linked into `Debug.md`).

XY for non-OW reward comes from
`world_get_shortcut_or_item_xy_for_room(room_id)` exposed by
`src/game/world/world_dispatch.h` (drained as
`worldrt_get_shortcut_or_item_xy_for_room` in
`src/oracle/world/world_runtime.c`).

## Wired pipeline (`src/game/enemies/enemy_loop.c`)

```c
enemy_assign_spawn_positions(room_id, tmpl);

/* Phase 8 Task 8.1 step 3 — room-item slot 19 reward setup. */
boss_framework_room_init(room_id);

if (loaded == 0u && DUNGEON_ROOM_OBJ_COUNT == 0u) {
    return;
}
```

Call site sits between the per-room monster placement and the
per-slot init dispatch — matches NES `InitMode_EnterRoom`
(`Z_05.asm:1700-1820`) which tail-calls `CreateRoomObjects`
(`Z_05.asm:8154`) after `AssignObjSpawnPositions`.

## Implementation steps

| Step | Commit | Artifact |
|------|--------|----------|
| 1 | `d6ba6f33` | `src/state/boss_state.h` substrate + `src/game/enemies/bosses/.gitkeep` |
| 2 | `06fc0818` | `src/game/enemies/bosses/boss_framework.{h,c}` native body + `tools/debug/build_debug.py` TU registration |
| 3 | `76784a29` | `src/game/enemies/enemy_loop.c` wires `boss_framework_room_init` + linker fix routing UW already-taken via `progress_get_room_flag_uw_item_state` |

## Push-block branch deferral

`Z_05.asm:8200-8203` short-circuits to
`FindAndCreatePushBlockObject` (`Z_05.asm:5461`) when
`LBA_D & 0x40` is set. That body is not yet drained or shimmed for
native callers; activating the branch would also require populating
a transient object slot used by the push-block sprite. The branch
is intentionally a no-op until Phase 8 follow-up drains
`FindAndCreatePushBlockObject`. Boss rooms (the Task 8.1 + 8.2-8.10
focus) do not trigger this branch — push blocks gate shortcut
shop / hint rooms, none of which contain bosses.

Tracking: `out_of_phase_tasks[]` entry deferred until the drain
pass surfaces a candidate row in
`tools/audit/drain_coverage.json`.

## Build verification

```
REQUIRE_GENERATED_ASSETS=1 python tools/debug/build_debug.py
→ builds/Debug.md
```

Clean — only pre-existing `LINK_X` / `LINK_Y` redefinition warnings
between `enemy_state.h` and `world_state.h` (not introduced by
Task 8.1).

## Status

CLOSE — Task 8.1 Boss Framework substrate + native CreateRoomObjects
body + enemy_loop wiring complete. Per-boss tasks (8.2 Aquamentus,
8.3 Dodongo, …) build on this substrate; their per-boss INIT/UPDATE
bodies are already drained in `enemy_boss_runtime.c` so subsequent
tasks are ADOPT-stance forwarders, not REPLACE bodies.
