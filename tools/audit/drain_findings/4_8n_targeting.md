# Drain Finding — Phase 4 Task 4.8 (native port) — targeting helpers

**Per Rule D1 Gate 1.** Drain MATCH proof + native port for the 3
targeting subsystem helpers. Establishes
`src/game/combat/targeting_dispatch.{h,c}` scaffold + `NATIVE_TARGETING`
cutover gate. Pure leaf functions — used by enemy AI per-monster
updaters for pursuit and diagonal speed selection.

## Targets

| Side | Path | Lines |
|------|------|-------|
| Native (new) | `src/game/combat/targeting_dispatch.{h,c}` | `targeting_get_one_direction_and_distance_to_target`, `targeting_get_directions_and_distances_to_target`, `targeting_calc_diagonal_speed_index` |
| Drain | `src/oracle/combat/targeting_runtime.c` (3-67) |
| NES asm | `reference/aldonunez/Z_01.asm` (GetOneDirectionAndDistanceToTarget, GetDirectionsAndDistancesToTarget, CalcDiagonalSpeedIndex) |
| State accessors | `src/state/targeting_state.h` | `TARGET_DIR_ACCUM/MIN/MAX/H_DIST/V_DIST/H_DIR/V_DIR` (zero-page scratch) |

## Stance

**REWRITE-MIRROR (drain MATCH).** All three are pure C leaves with no
shims. Drain mirrors NES exactly per Rule D1 (drain primary, NES asm
secondary). Native ports preserve drain control flow:

- `get_one_direction_and_distance_to_target`: writes
  `TARGET_MIN_COORD`/`TARGET_MAX_COORD`, halves `TARGET_H_DIR` if origin
  is below target, increments `TARGET_DIR_ACCUM` if dist < 9, returns
  unsigned distance.
- `get_directions_and_distances_to_target`: invokes the unary helper
  twice with `TARGET_H_DIR = 2` then `= 8`, latching `TARGET_V_DIR =
  TARGET_H_DIR` between calls (NES uses A as the dir-accumulator).
- `calc_diagonal_speed_index`: bubble-sort H/V into max/min, refine the
  speed-table index by stepping toward 0 or 8 while `H_DIST - V_DIST >=
  V_DIST`, then return.

## Cutover

`tools/gen_wrappers/z_01_manifest.json` entries dropped:
`z01_get_one_direction_and_distance_to_target`,
`z01_get_directions_and_distances_to_target`,
`z01_calc_diagonal_speed_index`.

`src/gen/z_01.c` now hand-writes the 3 wrappers under `#ifdef
NATIVE_TARGETING`. Default OFF preserves Title.md byte-identical
(forwards to `targrt_*` oracle drain). Define `NATIVE_TARGETING` to
route Title.md through `src/game/combat/targeting_dispatch.c`.
RoomRom.md links the native dispatch unconditionally via
`RoomRom/build.bat` (`targeting_dispatch.c` -> `targeting_dispatch.o`).

## Verification

- `build_all.ps1` green: Title.md + RoomRom.md both link.
- Drain MATCH per visual inspection (32 + 28 lines C; semantics
  identical).
- No callers in RoomRom yet — calls land when enemy per-monster
  updaters port (zol/gel/walker pursuit, jumper aim).

## Phase 4 cutover gate count

15 cutover gates → **16** with `NATIVE_TARGETING`. (Cave x3, World,
Object, Sprite, Progress, Trap, Core, Enemy, Collision, Room, Hud,
Weapon, Targeting.)
