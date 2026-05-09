# Phase 6 Task 6.1 — LinkState Promote + PlayerState[4] Shape

- **NES source**:
  - Object slot 0 (Link) cells in `reference/aldonunez/Variables.inc`:
    `ObjX`/`ObjY` (pos), `ObjPosFrac`/`ObjQSpeedFrac` (sub-px),
    `ObjDir`/`ObjInputDir`/`LINK_MOVING_DIR` (dirs), `ObjState`/`ObjMetastate`,
    `ObjMovingLimit`/`ObjGridOffset`, `ObjAnimCounter`/`ObjAnimFrame`,
    `ObjInvincibilityTimer`/`ObjInvincibilityMask`,
    `ObjShoveDir`/`ObjShoveDistance`, `ObjShootTimer`/`LINK_HALT_FLAG`,
    `ObjHP`, `MODE11_DEATH_TIMER`/`DEATH_FRAME_COUNTER`, `LINK_ROOM_SCRATCH`.
  - Z_07.asm dispatchers consume slot 0 directly: `:472` frame update gate,
    movement / item-use / animation routines all `,X = $00`.
- **Drained C**:  N/A — `src/state/link_state.h` is RoomRom-native typed
  shape mirroring NES slot-0 cell-by-cell; PRIMARY drained C in
  `src/game/{combat,items}/*_runtime.c` still keys on `RAM(NES_OBJ_*+i)`
  arrays — drain migration tracked separately under combat/items.
- **Coverage**:   PARTIAL (struct + array shape + budget envelope landed;
  RoomRom consumers migrated; legacy `RAM()` shims kept for incremental
  promotion of remaining call-sites; render_budget_emit() enforcement
  pending).
- **Stance**:     ADOPT (struct fields named after NES `ObjXxx` cells;
  size widths chosen to match NES storage class).

## Verified parity (shape + invariants)

| Master-plan checkbox | Landed | Evidence |
| --- | --- | --- |
| Migrate `link_state.h` from `RAM(addr)` macros to typed C struct | ✅ | `src/state/link_state.h:49-114` `typedef struct LinkState` |
| Position fields (x, y, sub-pixel x/y) | ✅ | `link_state.h:52-58` `x`/`y` + `pos_frac`/`qspeed_frac` |
| Direction / facing | ✅ | `link_state.h:66-69` `dir`/`face`/`input_dir`/`moving_dir` |
| Action state | ✅ | `link_state.h:72-73` `state`/`metastate` |
| Animation frame / timer | ✅ | `link_state.h:81-82` `anim_counter`/`anim_frame` |
| Invincibility timer | ✅ | `link_state.h:86-87` `invincibility_timer`/`invincibility_mask` |
| Damage / knockback state | ✅ | `link_state.h:91-92` `shove_dir`/`shove_distance` |
| Item-use state | ✅ | `link_state.h:98-101` `shoot_timer`/`halt_flag`/`item_use_kind`/`item_use_timer` |
| Death state | ✅ | `link_state.h:108-109` `death_timer`/`death_frame_counter` |
| `typedef LinkState PlayerState` | ✅ | `link_state.h:118` |
| `PlayerState players[4]` + `g_player_count` (default 1) | ✅ | `player_state.h:24-27`, `player_state.c:10-11` |
| Genesis sprite-per-line budget envelope | ✅ | `render_budget.h:31-52` 80-total / 20-per-line + reservation columns + `#error` static-check |
| Probe `player_state_size_invariant` (`sizeof * 4 + headroom < SRAM`) | ✅ | `player_state.c:25-33` `_Static_assert` 512-byte SRAM budget |
| Replace raw RoomRom globals with `players[0].*` | ✅ (partial) | `RoomRom/src/main.c:281,284,287,290,482-484,519,524,534,588-592,791,866,902,988-989` plus 80+ further `players[0].*` accesses |

## Diverges from NES (deliberate)

| Aspect | NES | RoomRom impl | Reason |
| --- | --- | --- | --- |
| `dir` encoding tokens | NES bit-mask 0x01 RIGHT / 0x02 LEFT / 0x04 DOWN / 0x08 UP in `ObjDir` | RoomRom keeps NES bitfield numerically but ALSO carries an ordinal `link_face_t` enum in `face` (sprites side) | Avoids macro / enum collision with `roomrom_sprites.h` `LINK_FACE_*` and `LINK_DIR_*` enums (`link_state.h:39-47`) |
| Field width | NES is 8-bit per cell | `x` / `y` are signed 16-bit | Genesis room-edge math + scroll require sign + range across 256 px playfield + scroll buffer |
| Storage | NES is parallel arrays `ObjX[16]`, `ObjY[16]`, … | C is array-of-struct `players[4]` | Drained C still keys on parallel arrays under `RAM()`; conversion is per-subsystem — see Deferred section |

## Deferred (Task 6.1-followup)

| Behavior | NES anchor | Why deferred | Re-entry trigger |
| --- | --- | --- | --- |
| Delete legacy `RAM()` shims (`LINK_MOVING_DIR`, `LINK_ROOM_SCRATCH`, `LINK_HALT_FLAG`, `MODE11_DEATH_TIMER`, `DEATH_FRAME_COUNTER`) | Variables.inc cell aliases | Drained C in `src/game/**` + `src/oracle/**` still reads via shims (31 files) — can't break them mid-Phase-6 | Per-subsystem migration: combat (Task 6.11), room (Phase 8 OW/UW), cave/object (post-promotion to `src/game/`) |
| `verify_no_alias_collisions.py` for `link_state.h` | tools gate | Script not yet authored — would scan macro names against enum tokens | This task — fold into Phase 6 close gate step |
| `render_budget_emit()` enforcement on SAT writes | `src/sgdk_adapter/` writer | Frame compose path still calls `VDP_setSpriteFull` directly; budget accumulator unused at runtime | Phase 6 sprite render sweep — fold into Task 6.x sprite-pipe pass |
| Migrate parallel-array drains (`src/game/combat/*_runtime.c`) to `players[0]` | `Z_07.asm` slot-0 `,X` loads | PRIMARY drained C still array-shaped; struct-shape conversion is mechanical but big | Phase 6 Task 6.11 (combat collision) + Phase 7 (enemies) |
| Multi-player slots `players[1..3]` populated | N/A (Phase 13) | Phase 13 deliberately deferred per debate 002 | Phase 13 Optional 4-Player Mode |

## Probe / contract

- Compile-time invariant: `_Static_assert` in `player_state.c:28-33` —
  `sizeof(PlayerState) * 4 + 16 < 512`.
- Static contract goal: `tools/debug/test_link_state_contract.py` —
  `LinkState` field offsets stable across commits (struct-layout
  regression guard); `players[0]` referenced at expected RoomRom main.c
  call-sites; `g_player_count == 1` at boot.
- Runtime probe: not required for shape-only landing; deferred to
  multiplayer sweep.

## Gate

- 4-line task header: filled.
- Gate 1 (per-function diff): N/A — shape-only task, no per-function
  rewrite. Per-cell field naming matches NES `ObjXxx` 1:1.
- Gate 2 (per-RAM-cell trace): satisfied by `_Static_assert` size
  invariant + cell-name parity. Will be re-validated under Phase 6
  close gate when last legacy shim deletes.
- Gate 3 (per-scenario oracle): deferred to Phase 13 milestone tag
  (4-player save-state regression).

## Action items added to deferral ledger

1. Author `tools/audit/verify_no_alias_collisions.py` — scan
   `link_state.h` macro names against `link_face_t` / `link_dir_t`
   enum tokens, fail on collision.
2. Implement `render_budget_emit()` in `src/sgdk_adapter/` and route
   all SAT writes through it (Phase 6 sprite-pipe sweep).
3. Per-subsystem migration plan to delete the 5 legacy `RAM()` shims:
   combat (Task 6.11), room/world dispatch (Phase 8), cave/object
   (post-promotion).
4. Convert drained `src/game/combat/*_runtime.c` array-of-cell
   accesses to `players[0]` after combat collision lands (Task 6.11).
