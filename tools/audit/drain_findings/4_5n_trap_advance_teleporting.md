# Drain Finding — Phase 4 Task 4.5 (native port) — `trap_advance_teleporting_level_index`

**Per Rule D1 Gate 1.** Drain MATCH proof + native port for the trap
teleport-cycle helper. Establishes `src/game/world/trap_dispatch.{h,c}`
scaffold + `NATIVE_TRAP` cutover gate.

## Targets

| Side | Path | Lines |
|------|------|-------|
| Native (new) | `src/game/world/trap_dispatch.{h,c}` | `trap_advance_teleporting_level_index` |
| Drain | `src/oracle/world/trap_runtime.c` | 81-86 |
| NES asm | `reference/aldonunez/Z_01.asm` | AdvanceTeleportingLevelIndex |
| NES vars | `reference/aldonunez/Variables.inc` | `TELEPORT_LEVEL_INDEX := $0523` (per src/state/trap_state.h), `LINK_DIR := $0098` |
| State accessors | `src/state/trap_state.h`, `world_state.h` | `TELEPORT_LEVEL_INDEX`, `LINK_DIR` |

## Drain MATCH proof

| Drain (81-86) | NES AdvanceTeleportingLevelIndex | Verdict |
|---------------|-----------------------------------|---------|
| `TELEPORT_LEVEL_INDEX++` | `INC TELEPORT_LEVEL_INDEX` | **MATCH** |
| `if ((LINK_DIR & 0x09) == 0) TELEPORT_LEVEL_INDEX -= 2` | NES `LDA LINK_DIR / AND #$09 / BNE @Exit / DEC / DEC` | **MATCH** — bits $09 = up ($08) + right ($01); when neither set, undo increment AND step back one (net -1 from original). |

**Drain verdict: FULL MATCH** vs NES.

## Native port

Mechanical translation. No semantic changes. Pure C, no shims.

## Cutover gate

- New gate: `NATIVE_TRAP` (independent from prior gates).
- 1 hand-written z01_* wrapper in src/gen/z_01.c.
- Default OFF → oracle drain.
- Defined ON → native (drop-in FULL MATCH).
- RoomRom links unconditionally (build.bat compiles trap_dispatch.c).

## Stance update

Phase 4 Task 4.5 (Stance: ADOPT) — first trap batch. 1/10 of
src/oracle/world/trap_runtime.c ported. Remaining 9 functions reach
into transpile shims (`z01_init_one_simple_object`,
`z07_anim_advance_and_fetch`, `z01_anim_set_sprite_desc_attrs`,
`c_draw_object_not_mirrored_with_frame`, `z01_check_link_collision`,
`z01_destroy_whirlwind`, `c_go_to_next_mode_from_play`,
`z01_set_up_whirlwind`) — defer until corresponding subsystem ports
land (core/link_collision/etc.).

## Provenance

- 2026-05-03. Author: Claude Opus.
