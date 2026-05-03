# Drain Finding — Phase 4 Task 4.1 (native port) — `world_check_mazes`

**Per Rule D1 Gate 1.** Drain MATCH proof + native port for the
forest/mountain maze step-tracker.

## Targets

| Side | Path | Lines |
|------|------|-------|
| Native (new) | `src/game/world/world_dispatch.c` | `world_check_mazes` |
| Drained C | `src/oracle/world/world_runtime.c` | 68-109 |
| NES asm | `reference/aldonunez/Z_01.asm` | 4791-4840 (CheckMazes + helpers) + 4782-4786 (ForestMazeDirs / MountainMazeDirs tables) |
| NES vars | `reference/aldonunez/Variables.inc` | `ObjDir := $0098` (= LINK_DIR), `RoomId := $00EB` (= CUR_ROOM_ID), `NextRoomId := $00EC` (drain alias `PREV_ROOM_ID` — naming bug, value matches), `MazeStep := $052F` (= WORLD_MAZE_STEP), `Tune1Request := $0602` (drain alias `WORLD_SECRET_SFX`) |
| State accessors | `src/state/world_state.h` | `LINK_DIR`, `CUR_ROOM_ID`, `PREV_ROOM_ID`, `WORLD_MAZE_STEP`, `WORLD_SECRET_SFX` macros (all RAM-backed) |

## Drain MATCH proof — block-by-block

### Forest path (room == $61)

| NES (Z_01.asm 4795-4810) | Drain (world_runtime.c 74-90) | Verdict |
|--------------------------|-------------------------------|---------|
| `CPY #$61 / BNE @CheckMountainMaze` | `if (room == 0x61)` | **MATCH** |
| `CMP ForestMazeDirs,X / BNE @Mismatch` | `if (dir != forest_dirs[step]) { ... }` | **MATCH** (drain inverts → mismatch branch wraps NES @Mismatch logic) |
| `@Mismatch: CMP #$01 / BEQ @Exit` | `if (dir == 0x01) return` | **MATCH** — right-in-forest exits maze. |
| `@Reset: JSR @ResetMazeStep / BEQ @SetNextRoom: STY NextRoomId / RTS` | `WORLD_MAZE_STEP = 0; PREV_ROOM_ID = room; return` | **MATCH** — reset step + lock current room. |
| match path: `CPX #$03 / BEQ @PlaySecretTune` | `if (step == 3) { WORLD_SECRET_SFX = 4; return; }` | **MATCH** — last step plays "secret found" tune ($04). |
| `@AdvanceMaze: INC MazeStep / @SetNextRoom: STY NextRoomId / RTS` | `WORLD_MAZE_STEP++; PREV_ROOM_ID = room; return` | **MATCH** |

### Mountain path (room == $1B)

| NES (Z_01.asm 4823-4840) | Drain (95-108) | Verdict |
|--------------------------|----------------|---------|
| `CPY #$1B / BNE @ResetMazeStep / RTS` | `if (room != 0x1B) { WORLD_MAZE_STEP = 0; return; }` | **MATCH** — non-forest non-mountain just resets. |
| `CMP MountainMazeDirs,X / BEQ @Match` | `if (dir == mountain_dirs[step])` | **MATCH** |
| `@Match: CPX #$03 / BNE @AdvanceMaze` | `if (step == 3) { WORLD_SECRET_SFX = 4; return; } step++; ...` | **MATCH** |
| Mismatch: `CMP #$02 / BNE @Reset / RTS` | `if (dir == 0x02) return; WORLD_MAZE_STEP = 0; PREV_ROOM_ID = room` | **MATCH** — left-in-mountain allows exit. |

### Tables

| NES (Z_01.asm 4782-4786) | Drain (line 69-70) | Native | Verdict |
|--------------------------|---------------------|--------|---------|
| `ForestMazeDirs: .BYTE $08, $02, $04, $02` | `forest_dirs[4] = {0x08, 0x02, 0x04, 0x02}` | same baked-in table | **MATCH** |
| `MountainMazeDirs: .BYTE $08, $08, $08, $08` | `mountain_dirs[4] = {0x08, 0x08, 0x08, 0x08}` | same baked-in table | **MATCH** |

**Verdict: worldrt_check_mazes FULL MATCH** vs NES.

## Native port

| Block | Drain | Native | Verdict |
|-------|-------|--------|---------|
| state load | `step = WORLD_MAZE_STEP; dir = LINK_DIR; room = CUR_ROOM_ID` | same | **MATCH** |
| forest path | drain body | same; `WORLD_MAZE_STEP = (uint8_t)(... + 1u)` cast | **MATCH** |
| non-maze reset | drain body | same | **MATCH** |
| mountain path | drain body | same | **MATCH** |
| tables | drain `static const` | same | **MATCH** |

**Verdict: world_check_mazes FULL MATCH** — pure C, no shims, no
deferred TODOs.

## Cutover gate

- Title.md callsite `z01_check_mazes` shares `NATIVE_WORLD` gate with
  `world_get_object_middle`.
- Default OFF → oracle drain (drain FULL MATCH).
- Defined ON → native (drop-in FULL MATCH replacement).
- Same Title.md build.bat caveat: not yet wired to compile world_dispatch.c.

## Naming nit (drain bug, low-priority cleanup)

`PREV_ROOM_ID` macro in `src/state/world_state.h` is misleading — NES
$00EC is `NextRoomId` (where Link is going to), not where he was. The
RAM byte is correctly addressed but the macro name should be
`NEXT_ROOM_ID`. Out of scope for this commit; flag for future cleanup
sweep.

## Stance update

Phase 4 Task 4.1 (Stance: ADOPT) — second world port. world_runtime.c
remaining: `worldrt_get_shortcut_or_item_xy_for_room` (uses nes_ram +
SRAM_BASE → cross-subsystem data dependency) and
`worldrt_animate_world_fading` (uses TRANSFER_BUF_BYTE +
TRANSFER_BUF_POS → cross-subsystem text/transfer pipeline). Both
defer until those subsystem primitives port.

## Provenance

- 2026-05-03. Author: Claude Opus.
- Variables.inc cited per process improvement from finding 3_2.
