# Phase 7 Task 7.4 step 8 — fire-shooter UPDATE wires ($3F / $40)

## Task header (Drain Rule D1)

- **NES source**: `Z_07.asm:5295 UpdateObject_JumpTable`:
                  - row $3F GuardFire    -> `UpdateGuardFire` @
                    `Z_04.asm:9684` (6-instruction body).
                  - row $40 StandingFire -> `UpdateStandingFire` @
                    `Z_04.asm:257`.

- **Drained C**:  - `UpdateGuardFire`: no oracle drain candidate.
                    Native EXTEND drain @
                    `src/game/enemies/enemy_walker_bridge.c:1147`
                    (`enrt_update_guard_fire`).
                  - `UpdateStandingFire`: existing oracle drain @
                    `src/oracle/enemies/enemy_walker_runtime.c:146`
                    (`enrt_update_standing_fire`).

- **Coverage**:   PARTIAL for both rows — UPDATE wired here, INIT
                  row in `Z_07.asm:5601 InitObject_JumpTable` is
                  unspecialized for $3F / $40 (default scratch init
                  applies). No new INIT wires required.

- **Stance**:     EXTEND (native drain for GuardFire) + ADOPT
                  (oracle drain for StandingFire). All composed
                  primitives already linked via existing bridges.

## NES UpdateGuardFire body (Z_04.asm:9684)

```
LDA #$06                         ; rate = 6
JSR AnimateAndDrawCommonObject   ; wrapped by enrt_animate_and_draw_common_object
JSR CheckMonsterCollisions       ; wrapped by c_check_monster_collisions
LDA ObjMetastate, X
BEQ exit                         ; if metastate == 0, return
LDA #$5D                         ; DeadDummy type
STA ObjType, X
exit:
RTS
```

Native translation:
```c
void enrt_update_guard_fire(unsigned int slot)
{
    enrt_animate_and_draw_common_object(6u, slot);
    c_check_monster_collisions(slot);
    if ((unsigned char)ENEMY_METASTATE(slot) != 0u) {
        ENEMY_TYPE(slot) = 0x5Du;       /* DeadDummy. */
    }
}
```

## NES UpdateStandingFire body (Z_04.asm:257)

```
JSR CheckLinkCollision           -> c_check_link_collision
LDA #$02                         ; palette = 2
JSR AnimSetSpriteDescAttrs       -> z01_anim_set_sprite_desc_attrs(2)
LDA #$08                         ; DIR = down
STA ObjDir, X
JSR AnimateObjectWalking         -> z07_animate_object_walking(slot)
LDA ObjType, X
CMP #$40                         ; type == $40 StandingFire?
BEQ :skip                        ; if yes, skip frame-flags clear
LDA #$00
STA ObjFrameFlags                -> ENEMY_FRAME_FLAGS = 0
:skip
LDA #$00
JSR DrawObjectNotMirroredWithFrame -> c_draw_object_not_mirrored_with_frame(0, slot)
RTS
```

Drained at `enemy_walker_runtime.c:146`. The drained body specializes
$40 StandingFire (skips FRAME_FLAGS clear) vs $3F GuardFire (which
does clear it) — but $3F GuardFire is wired to a *different* native
body (`enrt_update_guard_fire`), so the type check in
`enrt_update_standing_fire` only matters when the drain is reused for
non-$40 callers. We use `enrt_update_standing_fire` only for $40,
so the type==$40 path is always taken (FRAME_FLAGS preserved).

## RAM cell map (NES Variables.inc -> state header macros)

| NES name        | NES addr | C macro                |
|-----------------|----------|------------------------|
| `ObjType`       | `$034F`  | `ENEMY_TYPE`           |
| `ObjMetastate`  | `$0405`  | `ENEMY_METASTATE`      |
| `ObjDir`        | `$0098`  | `ENEMY_DIR`            |
| `ObjFrameFlags` | (ZP)     | `ENEMY_FRAME_FLAGS`    |

## Wired dispatch (delta from step 7)

| Hex | NES type     | INIT row    | UPDATE row                    |
|-----|--------------|-------------|-------------------------------|
| $3F | GuardFire    | (default)   | `enrt_update_guard_fire`      |
| $40 | StandingFire | (default)   | `enrt_update_standing_fire`   |

## New bridge symbol (one new forwarder)

`enemy_projectile_bridge.c` gained `z07_animate_object_walking`
forwarder pointing at `sprite_animate_object_walking` (native body
in `src/game/world/sprite_dispatch.c:115`). NES
`c_animate_object_walking` (legacy bank shim) was the only previous
caller — now resolved via the bridge for the StandingFire UPDATE row.

## Native primitives composed (already linked)

| Primitive                                  | Native body                                      |
|--------------------------------------------|--------------------------------------------------|
| `enrt_animate_and_draw_common_object(rate)`| `enemy_walker_bridge.c:201`                      |
| `c_check_monster_collisions`               | `enemy_walker_bridge.c:166`                      |
| `c_check_link_collision`                   | `enemy_walker_bridge.c:172`                      |
| `z01_anim_set_sprite_desc_attrs(palette)`  | `enemy_walker_bridge.c:206`                      |
| `z07_animate_object_walking`               | `enemy_projectile_bridge.c` (new step 8 fwd)     |
| `c_draw_object_not_mirrored_with_frame`    | `world/draw_dispatch.c`                          |

## Build verification

`python tools/debug/build_debug.py` — clean post step 8 wire. Active
scope: `src/game/enemies/enemy_walker_bridge.c` (+1 native body),
`src/game/enemies/enemy_projectile_bridge.c` (+1 forwarder),
`src/game/enemies/enemy_loop.c` (+2 dispatch rows + externs).

## Coverage advance

Task 7.4 dispatch coverage:
  UPDATE: 32 -> 34 wired rows (+2: $3F, $40).
  INIT:   25 -> 25 wired rows (+0: both default scratch init).

Steps 9 / 10 / 11 unchanged from earlier sequencing.
