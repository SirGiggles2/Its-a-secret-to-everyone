# Phase 8 Task 8.3 — Dodongo

- **NES source**: `reference/aldonunez/Z_07.asm:5295` UpdateObject_JumpTable
                  rows $31/$32 → `Z_04.asm:5856` UpdateDodongo;
                  `Z_04.asm:5856-6005` (UpdateDodongo +
                  UpdateDodongoState_JumpTable +
                  UpdateDodongoState0_Move +
                  UpdateDodongoState1_Bloated_JumpTable +
                  UpdateDodongoState1_Bloated_Sub_Wait +
                  UpdateDodongoState1_Bloated_Sub_Die +
                  UpdateDodongoState1_Bloated_Sub_End +
                  UpdateDodongoState2_Stunned);
                  `Z_07.asm:5601` InitObject_JumpTable rows $31/$32
                  → `Z_04.asm:4893` InitDodongo;
                  `reference/aldonunez/ObjVars.inc:55-57`
                  (Dodongo_ObjBloatedSubstate=$42C,
                  Dodongo_ObjBombHits=$437,
                  Dodongo_ObjBloatedTimer=$45E).
- **Drained C**:  `src/oracle/enemies/enemy_dodongo_runtime.c:21`
                  `enrt_init_dodongo`; same file: `enrt_dodongo_check_collisions`
                  / `enrt_dodongo_check_bomb_hit` / `enrt_dodongo_draw`
                  / `enrt_update_dodongo_state2_stunned` /
                  `enrt_update_dodongo_state1_bloated_sub_die` /
                  `enrt_update_dodongo_bloated_sub_end` /
                  `enrt_dodongo_dec_bloated_timer`. Drain primary.
- **Coverage**:   FULL — `boss_dodongo_update` (the UpdateDodongo
                  umbrella) composes drained primitives with native
                  ports of the un-drained branches: State0_Move,
                  Bloated_Sub_Wait, the state dispatcher, and the
                  bloated substate dispatcher.
- **Stance**:     EXTEND — drained Dodongo primitives consumed
                  verbatim; un-drained branches transcribed per-line
                  from `Z_04.asm:5876-5993` into native bodies in
                  `src/game/enemies/bosses/boss_dodongo.c`. Forwarders
                  for the four extern callees the drain references
                  (`c_get_object_middle`, `c_check_monster_sword_collision`,
                  `z07_update_dead_dummy`, `z04_update_dodongo_bloated_sub_end`)
                  resolve to the dispatcher entry points already in
                  the link (`world_get_object_middle`,
                  `collision_check_monster_sword_collision`,
                  `core_update_dead_dummy`) plus the in-TU drained twin
                  for the bloated_sub_end alias.

## State / substate model

NES top-level state = `ObjState[$AC + slot]` = `ENEMY_STATE_TIMER`:

| State | NES symbol | Native dispatch |
|------|------------|-----------------|
| 0 | `UpdateDodongoState0_Move` | `boss_dodongo_state0_move` (native, this TU) |
| 1 | `UpdateDodongoState1_Bloated` | `boss_dodongo_state1_bloated` (native dispatcher) |
| 2 | `UpdateDodongoState2_Stunned` | `enrt_update_dodongo_state2_stunned` (drain) |

Bloated substate = `Dodongo_ObjBloatedSubstate` ($42C =
`ENEMY_TURN_TIMER`):

| Substate | NES symbol | Native dispatch |
|----------|------------|-----------------|
| 0 / 1 / 2 | `Sub_Wait` | `boss_dodongo_state1_bloated_sub_wait` (native, this TU) |
| 3 | `Sub_Die` | `enrt_update_dodongo_state1_bloated_sub_die` (drain) |
| 4 | `Sub_End` | `enrt_update_dodongo_bloated_sub_end` (drain) |

Bomb-hit counter = `Dodongo_ObjBombHits` ($437 = `ENEMY_FLAP_PHASE`).
Bloated timer = `Dodongo_ObjBloatedTimer` ($45E = `ENEMY_BLOATED_TIMER`).
DodongoBloatedWaitTimes = `{$20, $40, $40}` (per substate).

## Wired pipeline

`src/game/enemies/enemy_loop.c`:

```c
[0x31] = enrt_init_dodongo,                  /* INIT */
[0x32] = enrt_init_dodongo,                  /* INIT (alt) */
[0x31] = boss_dodongo_update,                /* UPDATE */
[0x32] = boss_dodongo_update,                /* UPDATE (alt) */
```

Both NES rows ($31 and $32) fan to the same UpdateDodongo body —
preserved verbatim.

`boss_dodongo_update` calls (per `Z_04.asm:5856-5860`):

```c
boss_dodongo_update_state(slot);   /* native dispatcher */
enrt_dodongo_check_collisions(slot);
enrt_dodongo_check_bomb_hit(slot);
enrt_dodongo_draw(slot);
```

## State0_Move trick (Z_04.asm:5876-5919)

NES `UpdateDodongoState0_Move` pre-shifts ObjX by `+$10` when not
facing left so `Wanderer_TargetPlayer` evaluates from the other side
of the long sprite (Dodongo is two tiles wide). The X delta is
saved on the 6502 stack, then re-applied (additively, with
wrap-around) after the call to undo the shift. The native port
mirrors this:

```c
if ((dir & 0x0Du) != 0u) {
    ENEMY_X(slot) += 0x10u;        /* shift right by $10 */
    saved_offset = 0xF0u;          /* signed -$10 to undo */
}
ENEMY_AIR_SPEED(slot) = 0x20u;     /* turn rate $20 */
enrt_wanderer_target_player(slot);
ENEMY_X(slot) += saved_offset;     /* unshift */
if (ENEMY_X(slot) < 0x20u) {
    ENEMY_DIR(slot) = 0x01u;       /* clamp to facing right */
}
```

`ENEMY_AIR_SPEED` ($041F) is the alias for ObjTurnRate per
enemy_state.h:23.

## Bloated_Sub_Wait substate machine (Z_04.asm:5945-5993)

Three behaviors keyed off `Dodongo_ObjBloatedTimer`:

| Pre-DEY timer | Behavior |
|---------------|----------|
| `1` | Advance substate (`++`); if new substate ≥ 2 and bomb_hits < 2, force substate = 4 (transition to End → state 0 moving). Then dec timer. |
| `≥ 2` | Just dec timer. |
| `0` | Reseed timer from `DodongoBloatedWaitTimes[substate]`; if substate == 0 deactivate first bomb slot (object slot 16) + bomb_hits++; then dec timer. |

The "fall-through to dec" pattern is faithful to the NES asm — the
final `DEC Dodongo_ObjBloatedTimer` runs on every path.

## Callee shims for the drain

`src/oracle/enemies/enemy_dodongo_runtime.c` references four extern
primitives via `enemy_runtime_private.h`. They are not present under
those names but are drained under dispatcher names already linked
into `Debug.md`:

| Drain extern | Resolved to |
|--------------|-------------|
| `c_get_object_middle` | `world_get_object_middle` (`src/game/world/world_dispatch.c`) |
| `c_check_monster_sword_collision` | `collision_check_monster_sword_collision` (`src/game/combat/collision_dispatch.c:323`) |
| `z07_update_dead_dummy` | `core_update_dead_dummy` (`src/game/core/core_dispatch.c:546`) |
| `z04_update_dodongo_bloated_sub_end` | `enrt_update_dodongo_bloated_sub_end` (in-TU drain) |

The shim block in `boss_dodongo.c` is the single point of resolution
for every Dodongo primitive — no `c_shims.asm` lookup, no legacy
bank Z_04 linkage.

## Build verification

```
REQUIRE_GENERATED_ASSETS=1 python tools/debug/build_debug.py
→ builds/Debug.md
```

Clean. New TUs added to the link set:
- `src/oracle/enemies/enemy_dodongo_runtime.c`
- `src/game/enemies/bosses/boss_dodongo.c`

## Live-room probe deferral

Same caveat as Task 8.2: in-emulator Level 1-style boss-room probe
requires the `InitMode_EnterRoom` gameplay state machine
(`Z_05.asm:1700-1820`) to be wired through scroll / pause / shutter.
Tracked under Task 8.11 Boss Matrix.

## Status

CLOSE — Dodongo full INIT + UPDATE coverage. Native bridge body
covers every Z_04 UpdateDodongo branch by composing drained
primitives + transcribed Move/Sub_Wait/dispatchers. No primitive
gaps at link.
