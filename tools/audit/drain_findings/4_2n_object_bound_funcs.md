# Drain Finding — Phase 4 Task 4.2 (native port) — object bound family

**Per Rule D1 Gate 1.** Drain MATCH proof + native port for 4
object-bound functions used by collision detection + enemy AI.

## Targets

| Side | Path | Lines |
|------|------|-------|
| Native (new) | `src/game/world/object_dispatch.{h,c}` | `object_bound_direction_horizontally`, `_vertically`, `object_bound_by_room`, `object_bound_by_room_with_dir` |
| Drain | `src/oracle/world/object_runtime.c` | 74-113 + static helper at 3-6 |
| NES asm | `reference/aldonunez/Z_01.asm` | 3312-3370 (BoundDirectionHorizontally), 3382+ (BoundDirectionVertically), 3457-3461 (BoundByRoom) |
| NES vars | `reference/aldonunez/Variables.inc` | `ObjX := $0070`, `ObjY := $0084`, `ObjType := $034F`, `RoomBoundLeft := $0346` (= NES_BOUND_LEFT), `RoomBoundRight := $0347`, `RoomBoundTop := $0348`, `RoomBoundBottom := $0349`, scratch `$0F` (= NES_OBJ_DIR — direction-arg, not per-slot ObjDir at $98), scratch `$00` (= NES_TMP0) |

## Drain MATCH proof — `BoundDirectionHorizontally`

| NES (Z_01.asm 3313-3370) | Drain (74-87) | Verdict |
|--------------------------|---------------|---------|
| `LDY #$02 / LDA ObjX,X / STA $00` | `x = RAM(NES_OBJ_X+slot); RAM(NES_TMP0) = x` | **MATCH** (Y=$02 is the left dir-bit kept in Y for the BoundDirectionReturn test). |
| `CPX #$00 / BEQ @Left` | drain implicit `if (slot != 0u && ...)` | **MATCH** (NES skips shift for slot 0 = Link). |
| `CPX #$0D / BCS :+ / LDA ObjType,X / CMP #$5C / BNE @Left / : LDA $00 / CLC / ADC #$0B / STA $00` | `if (slot != 0u && (slot >= 0x0Du \|\| RAM(NES_OBJ_TYPE+slot) == 0x5Cu)) { RAM(NES_TMP0) = (uint8_t)(x + 0x0Bu); }` | **MATCH** — slot >= $0D OR type == $5C (boomerang) → shift +$0B. |
| `@Left: LDA $00 / CMP RoomBoundLeft / BCC BoundDirectionReturn` | `if (RAM(NES_TMP0) < RAM(NES_BOUND_LEFT)) { reset_moving_dir_if_mask(2); return; }` | **MATCH** — left bound crossed → clear NES_OBJ_DIR if bit $02 set. |
| `CPX #$00 / BEQ @Right / CPX #$0D / BCS :+ / LDA ObjType,X / CMP #$5C / BNE @Right / : LDA $00 / SEC / SBC #$17 / STA $00` | `if (slot != 0u && ...) { RAM(NES_TMP0) -= 0x17u; }` | **MATCH** — same gate, shift -$17 (so net offset from x is +$0B - $17 = -$0C). |
| `@Right: LDY #$01 / LDA $00 / CMP RoomBoundRight / BCC L6825_Exit` | `if (RAM(NES_TMP0) >= RAM(NES_BOUND_RIGHT)) { reset_moving_dir_if_mask(1); }` | **MATCH** — right bound crossed → clear if bit $01 set. |
| `BoundDirectionReturn: TYA / AND $0F / BEQ exit / JMP ResetMovingDir` | `if (RAM(NES_OBJ_DIR) & dir_bit) { RAM(NES_OBJ_DIR) = 0; }` | **MATCH** — drain's `objrt_reset_moving_dir_if_mask` encapsulates the NES BoundDirectionReturn logic. |

## Drain MATCH proof — `BoundDirectionVertically`

Same structure as horizontal but on Y axis with shifts $0F (top) /
$21 (bottom) and direction bits $08 (up) / $04 (down). Drain
(89-102) mirrors the structure exactly. **MATCH**.

## Drain MATCH proof — `BoundByRoom` + `BoundByRoomWithA`

| NES (Z_01.asm 3457-3461) | Drain (104-113) | Verdict |
|--------------------------|------------------|---------|
| `JSR BoundDirectionHorizontally / JSR BoundDirectionVertically / LDA $0F / RTS` | `objrt_bound_direction_horizontally(slot); objrt_bound_direction_vertically(slot); return RAM(NES_OBJ_DIR);` | **MATCH** |
| Caller writes `$0F = direction` then JSR BoundByRoom | `objrt_bound_by_room_with_dir`: `RAM(NES_OBJ_DIR) = direction; return objrt_bound_by_room(slot);` | **MATCH** (manifest mismaps `z01_bound_by_room_with_a` → drain `_with_dir` because NES uses A register but drain renames param). |

**Drain verdict: 4 functions FULL MATCH** vs NES.

## Native port

Mechanical translation of drain. No semantic changes. File-static
inline `object_reset_moving_dir_if_mask` mirrors drain's static helper.

| Function | Drain | Native | Verdict |
|----------|-------|--------|---------|
| reset_moving_dir helper | static fn | `static inline` | **MATCH** |
| bound_direction_horizontally | drain | drop-in | **MATCH** |
| bound_direction_vertically | drain | drop-in | **MATCH** |
| bound_by_room | drain | drop-in | **MATCH** |
| bound_by_room_with_dir | drain | drop-in | **MATCH** |

**Native verdict: FULL MATCH** for all 4 functions. No deferred TODOs.

## Cutover gate

- New gate: `NATIVE_OBJECT` (independent from `NATIVE_WORLD` — world
  + object subsystems are exposed separately).
- Title.md callsites `z01_bound_direction_horizontally`, `_vertically`,
  `z01_bound_by_room`, `z01_bound_by_room_with_a` share the gate.
- Default OFF → oracle drain (FULL MATCH).
- Defined ON → native (drop-in FULL MATCH).
- RoomRom links unconditionally (build.bat compiles object_dispatch.c
  beside cave_dispatch.o + world_dispatch.o).

## Stance update

Phase 4 Task 4.2 (Stance: ADOPT) — first object_runtime ports. 4 of
8 functions in `src/oracle/world/object_runtime.c` ported. Remaining:
`objrt_move_object` (largest), `objrt_add_q_speed_to_position_fraction`,
`objrt_sub_q_speed_from_position_fraction`, `objrt_move_shot`. Next
batch.

## Provenance

- 2026-05-03. Author: Claude Opus.
- Variables.inc cited per process improvement from finding 3_2.
