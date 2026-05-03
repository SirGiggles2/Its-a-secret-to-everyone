# Drain Finding — Phase 4 Task 4.2 (native port) — object move family

**Per Rule D1 Gate 1.** Closes `src/oracle/world/object_runtime.c`
native coverage (8/8 functions ported). Drain MATCH proof + native
port for the 4 remaining functions.

## Targets

| Side | Path | Lines |
|------|------|-------|
| Native (new) | `src/game/world/object_dispatch.c` | `object_move_object`, `object_add_q_speed_to_position_fraction`, `object_sub_q_speed_from_position_fraction`, `object_move_shot` |
| Drain | `src/oracle/world/object_runtime.c` | 8-72, 115-136, 138-152 |
| NES asm | `reference/aldonunez/Z_01.asm` | MoveObject, AddQSpeedToPositionFraction (3470), SubQSpeedFromPositionFraction (~3490+), MoveShot |
| NES vars | `reference/aldonunez/Variables.inc` | `ObjPosFrac := $03A8`, `ObjQSpeedFrac := $03BC`, `ObjGridOffset := $0394`, `PositiveGridCellSize := $010E` (= NES_POS_GRID_LIMIT), `NegativeGridCellSize := $010F` (= NES_NEG_GRID_LIMIT), `ShotCollisionFlag := $000E` (= NES_SHOT_COLLISION_FLAG) |
| State accessors | `src/abi/platform_abi.h` | `OBJ()`, `RAM()`, all NES_OBJ_* constants, `CARRY_SET = 0x100u` |

## Drain MATCH proof — `MoveObject`

NES-MATCH per existing drain (in production via Title.md gameplay).
Drain logic mirrors NES per-frame loop exactly:

| Block | Verdict |
|-------|---------|
| slot 0 → grid limits ($08/$F8); else ($10/$F0) | **MATCH** |
| `dir = NES_OBJ_DIR; if dir == 0 return` | **MATCH** |
| 4-iteration loop, one per direction bit ($01/$02/$04/$08) | **MATCH** |
| each iter: `frac` add/sub via QSpeedFrac, step on overflow/underflow, clamp at grid limits, advance OBJ_X/Y by step | **MATCH** |

## Drain MATCH proof — `AddQSpeedToPositionFraction`

| NES (Z_01.asm 3470-end) | Drain (115-124) | Verdict |
|--------------------------|-----------------|---------|
| `LDA ObjPosFrac,X / CLC / ADC ObjQSpeedFrac,X / STA ObjPosFrac,X` | `sum = posfrac + qspd; ObjPosFrac = (uint8_t)sum` | **MATCH** |
| `PHP / LDA ObjGridOffset,X / CMP +/- limit / BEQ @ClearCarry` | `carry = sum >> 8; if (grid == limit) carry = 0` | **MATCH** |
| `INC ObjGridOffset,X` (when carry survived) | `ObjGridOffset += carry` | **MATCH** |
| return CARRY | `return carry ? CARRY_SET : 0u` | **MATCH** |

## Drain MATCH proof — `SubQSpeedFromPositionFraction`

Mirror of add — same shape, returns CARRY_SET when no borrow occurred
AND grid offset wasn't at limit. Drain inverts the carry sense vs add
to match NES semantics. **MATCH**.

## Drain MATCH proof — `MoveShot`

| NES MoveShot | Drain (138-152) | Verdict |
|--------------|-----------------|---------|
| Set NES_OBJ_DIR = direction; JSR BoundByRoom; if 0 set ShotCollisionFlag = $80, return | `dir_result = bound_by_room_with_dir(direction, slot); if 0 NES_SHOT_COLLISION_FLAG = $80; return` | **MATCH** |
| Save grid offset; zero it; JSR MoveObject | `saved = grid_offset; grid_offset = 0; move_object(slot)` | **MATCH** |
| If !ShotCollisionFlag, restore grid_offset = saved + new; else grid_offset = saved | drain mirror | **MATCH** |

**Drain verdict: 4 functions FULL MATCH** vs NES.

## Native port

Mechanical translation of drain. No semantic changes. `object_move_shot`
calls `object_move_object` + `object_bound_by_room_with_dir` natively
so the chain stays within `src/game/world/`.

| Function | Drain | Native | Verdict |
|----------|-------|--------|---------|
| move_object | drain | drop-in (4-iter loop, 4-branch chain) | **MATCH** |
| add_q_speed_to_position_fraction | drain | drop-in | **MATCH** |
| sub_q_speed_from_position_fraction | drain | drop-in | **MATCH** |
| move_shot | drain | drop-in (calls native sub-funcs) | **MATCH** |

**Native verdict: FULL MATCH** for all 4 functions. No deferred TODOs.

## Cutover gate

- 3 new Title.md cutover hand-written wrappers: `z01_add_q_speed_to_position_fraction`,
  `z01_sub_q_speed_from_position_fraction`, `z01_move_shot` — all share
  existing `NATIVE_OBJECT` gate from finding 4_2n.
- `object_move_object` has no z01_ wrapper (called from
  src/oracle/world/c_move_object.c bridge + internally from
  object_move_shot). RoomRom + Title.md call paths remain unchanged
  by this commit.
- Default OFF → oracle drain.
- Defined ON → native (drop-in FULL MATCH).

## Stance update

Phase 4 Task 4.2 (Stance: ADOPT) — **`src/oracle/world/object_runtime.c`
fully ported (8/8 functions)**. Can retire once NATIVE_OBJECT is
verified end-to-end. Phase 4 next: `src/oracle/world/sprite_runtime.c`
+ `progress_runtime.c` + `trap_runtime.c`. Sprite work most directly
unblocks RoomRom enemy/object render gap noted by user (RoomRom OW
tiles work but no enemies/sprites yet).

## Provenance

- 2026-05-03. Author: Claude Opus.
- Variables.inc cited per process improvement from finding 3_2.
