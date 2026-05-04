# Drain Finding — Phase 4 Task 4.10 (native port) — trap whirlwind helpers

**Per Rule D1 Gate 1.** Drain MATCH proof + native port for the 2
whirlwind-summon helpers in trap_runtime
(`check_init_whirlwind_and_begin_update`, `summon_whirlwind`). Extends
existing `NATIVE_TRAP` cutover gate; bakes per-level lookup tables
(TeleportYs[], LevelMasks[]) inline in `trap_dispatch.c`.

## Targets

| Side | Path | Lines |
|------|------|-------|
| Native (extended) | `src/game/world/trap_dispatch.{h,c}` | `trap_check_init_whirlwind_and_begin_update`, `trap_summon_whirlwind` |
| Drain | `src/oracle/world/trap_runtime.c` (69-110) |
| NES asm | `reference/aldonunez/Z_01.asm` (CheckInitWhirlwindAndBeginUpdate, SummonWhirlwind, TeleportYs, LevelMasks) |
| State accessors | `src/state/trap_state.h` | `TELEPORT_LEVEL_INDEX`, `TELEPORT_ACTIVE_FLAG`, `WHIRLWIND_ACTIVE_FLAG`, `MODE_TIMER` |
| Cross-deps | `core_set_up_whirlwind`, `enemy_find_empty_monster_slot`, `trap_advance_teleporting_level_index` (all native) |

## Stance

**REWRITE-MIRROR (drain MATCH).** All cross-subsystem calls are already
native. Tables baked inline:

- `k_teleport_ys[8] = { 0x8D, 0xAD, 0x8D, 0x8D, 0xAD, 0x8D, 0xAD, 0x5D }`
  (NES Z_01.asm:1226).
- `k_trap_level_masks[8] = { 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80 }`
  (same shape as progress_dispatch's `k_level_masks`; duplicated to
  avoid cross-subsystem coupling).

`check_init_whirlwind_and_begin_update`: spawn-on-active simple branch.
`summon_whirlwind`: triforce-piece mask walk + empty-slot find. The
mask rotates left/right based on `LINK_DIR & 9`, mirroring the NES
ASL/ROL semantics in C via shift-or composition.

## Cutover

`tools/gen_wrappers/z_01_manifest.json` entries dropped:
`z01_check_init_whirlwind_and_begin_update`, `z01_summon_whirlwind`.

`src/gen/z_01.c` now hand-writes the 2 wrappers under `#ifdef
NATIVE_TRAP`. Default OFF preserves Title.md byte-identical (forwards
to `trprt_*` oracle drain). Define `NATIVE_TRAP` to route Title.md
through `src/game/world/trap_dispatch.c`.

## Verification

- `build_all.ps1` green: Title.md + RoomRom.md both link.
- ROM Title.md checksum unchanged (NATIVE_TRAP default OFF).
- Trap-dispatch surface 3/10 fns native (was 1/10) — remaining 7
  reach into c_move_object / c_draw_object / c_init_mode_enter_room
  family + z01_check_link_collision; defer to future batch.
