# Drain Finding — Phase 4 Task 4.9 (native port) — combat helpers

**Per Rule D1 Gate 1.** Drain MATCH proof + native port for the 3
combat subsystem helpers (parry sound, monster died, deal damage).
Establishes `src/game/combat/combat_dispatch.{h,c}` scaffold +
`NATIVE_COMBAT` cutover gate. Also adds the leaf
`core_reset_shove_info_and_inv_timer` to native core_dispatch (used by
combat_handle_monster_died).

## Targets

| Side | Path | Lines |
|------|------|-------|
| Native (new) | `src/game/combat/combat_dispatch.{h,c}` | `combat_play_parry_sound_for_damage_type`, `combat_handle_monster_died`, `combat_deal_damage` |
| Native (extended) | `src/game/core/core_dispatch.{h,c}` | `core_reset_shove_info_and_inv_timer` |
| Drain | `src/oracle/combat/combat_runtime.c` (4-40) |
| NES asm | `reference/aldonunez/Z_01.asm` (PlayParrySoundForDamageType, HandleMonsterDied, DealDamage) |
| State accessors | `src/state/combat_state.h` | `COMBAT_DAMAGE_TYPE/_AMOUNT`, `ROOM_KILL_COUNT`, `ROOM_CHAIN_KILL_COUNT`, `ROOM_CHAIN_KILL_BONUS`, `SFX_COMBAT`, `MON_HP`, `MON_STUN_TIMER` |

## Stance

**REWRITE-MIRROR (drain MATCH).** All cross-subsystem calls already
have native equivalents:

- `cobrt_play_parry_sound_for_damage_type` -> calls
  `core_play_parry_tune` (native via NATIVE_CORE).
- `cobrt_handle_monster_died` -> calls `core_update_dead_dummy` and the
  newly-added `core_reset_shove_info_and_inv_timer` (= `set_shove_info_with0(0,
  slot)` + `OBJ_INV_TIMER(slot) = 0`).
- `cobrt_deal_damage` -> internal recursion to
  `combat_handle_monster_died` on HP underflow / zero.

Drain branch structure preserved verbatim. NES dtype check uses bit
mask convention (`0x20` = sword shot, `0x08` = fire) — both bypass
parry tune.

## Cutover

`tools/gen_wrappers/z_01_manifest.json` entries dropped:
`z01_play_parry_sound_for_damage_type`, `z01_handle_monster_died`,
`z01_deal_damage`.

`src/gen/z_01.c` now hand-writes the 3 wrappers under `#ifdef
NATIVE_COMBAT`. Default OFF preserves Title.md byte-identical
(forwards to `cobrt_*` oracle drain). Define `NATIVE_COMBAT` to route
Title.md through `src/game/combat/combat_dispatch.c`. RoomRom.md
links the native dispatch unconditionally via `RoomRom/build.bat`
(`combat_dispatch.c` -> `combat_dispatch.o`).

## Verification

- `build_all.ps1` green: Title.md + RoomRom.md both link.
- Drain MATCH per visual inspection (37 lines C; semantics
  byte-equivalent to cobrt_*).
- ROM Title.md checksum unchanged (NATIVE_COMBAT default OFF).

## Phase 4 cutover gate count

16 cutover gates → **17** with `NATIVE_COMBAT`. (Cave x3, World,
Object, Sprite, Progress, Trap, Core, Enemy, Collision, Room, Hud,
Weapon, Targeting, Combat.)
