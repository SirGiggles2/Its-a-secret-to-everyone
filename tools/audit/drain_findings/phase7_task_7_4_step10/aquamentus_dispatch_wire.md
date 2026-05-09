# Phase 7 Task 7.4 step 10 — Aquamentus boss INIT + UPDATE ($3D)

## Task header (Drain Rule D1)

- **NES source**: `Z_07.asm:5601 InitObject_JumpTable`:
                  - row $3D Aquamentus -> SwitchBank #$01 + JMP
                    `InitAquamentus` (Z_04 region).
                  `Z_07.asm:5295 UpdateObject_JumpTable`:
                  - row $3D Aquamentus -> `UpdateAquamentus` @
                    `Z_04.asm:5594-5607` -> Aquamentus_Move /
                    Aquamentus_Shoot / Aquamentus_Draw +
                    CheckMonsterCollisions + PlayBossHitCryIfNeeded
                    + ResetShoveInfo.

- **Drained C**:  - `enrt_init_aquamentus`  @
                    `src/oracle/enemies/enemy_boss_runtime.c:102`
                    (4 RAM cells, no callouts).
                  - `enrt_update_aquamentus` @
                    `src/oracle/enemies/enemy_boss_runtime.c:108`
                    (composes c_aquamentus_{move,shoot,draw} +
                    c_check_monster_collisions +
                    enrt_play_boss_hit_cry_if_needed under
                    ENEMY_PAUSE_FLAG gate).

- **Coverage**:   FULL for $3D Aquamentus — both INIT + UPDATE rows
                  wired here. Closes the boss-family blocker that
                  step 9 deferred.

- **Stance**:     EXTEND. c_aquamentus_{move,shoot,draw} are the
                  only c_shims.asm legacy-bank trampolines that
                  enrt_update_aquamentus consumes; native bodies
                  carried in `src/game/enemies/enemy_boss_bridge.c`.
                  All translations are per-line vs reference NES asm,
                  no logic divergence. Same model as Task 7.3 step 7
                  (vire) — drained-C twin lives elsewhere, native
                  bridge supplies the c_-prefixed primitives.

## Native bridge bodies added (`enemy_boss_bridge.c`)

| Function                         | NES source        | Lines (asm) |
|----------------------------------|-------------------|-------------|
| `c_aquamentus_move`              | `Z_04.asm:5612`   | 70          |
| `c_aquamentus_shoot`             | `Z_04.asm:5684`   | 60          |
| `c_aquamentus_draw`              | `Z_04.asm:5764`   | 80          |
| `c_shoot_fireball` (forwarder)   | `Z_04.asm:786`    | 1           |

### Composed primitive promoted

| Primitive               | NES source       | Native body                       |
|-------------------------|------------------|-----------------------------------|
| `draw_write_boss_sprite`| `Z_04.asm:5844`  | `src/game/world/draw_dispatch.c`  |
|                         | (tail-fused with |                                   |
|                         | `Z_01.asm:5393`  |                                   |
|                         |  Anim_EndWriteSprite) |                              |

`draw_write_boss_sprite(tile, x, y, attr)` writes 4 OAM bytes to the
rolling sprite cursor (`SpriteOffsets[CUR_SPRITE_INDEX]`) + cycles the
cursor. Reuses existing `k_sprite_offsets[41]` table (already in
draw_dispatch.c since Phase 4) and `sprite_cycle_cur_sprite_index()`.
Matches NES WriteBossSprite + Anim_EndWriteSprite tail-call exactly.

### Data tables promoted (verbatim from NES)

| Table                          | NES source        | C symbol                          |
|--------------------------------|-------------------|-----------------------------------|
| `AquamentusSpeeds[2]`          | `Z_04.asm:5609`   | `k_aquamentus_speeds`             |
| `AquamentusTiles[12]`          | `Z_04.asm:5754`   | `k_aquamentus_tiles`              |
| `AquamentusSpriteOffsetsY[6]`  | `Z_04.asm:5758`   | `k_aquamentus_sprite_offsets_y`   |
| `AquamentusSpriteOffsetsX[6]`  | `Z_04.asm:5761`   | `k_aquamentus_sprite_offsets_x`   |

## State machine summary

`c_aquamentus_move(slot)` (Z_04.asm:5612):
1. If `BOSS_OBJ_GRID_OFFSET == 0`: pick random distance 7 or $F via
   `(Random[X] & $0F) | $07`, pick random dir (`(rng & 1) + 1`), return.
2. Move once every 8 frames (`FrameCounter & 7 == 0`).
3. Clamp to [$88, $C7] X-range, reset distance to 7 on edge cross.
4. Apply speed: `X += AquamentusSpeeds[Dir-1]; distance--`.

`c_aquamentus_shoot(slot)` (Z_04.asm:5684):
- `MOVE_TIMER == 0` path: reseed timer to `Random[X] | $70`,
  spawn 3 fireballs (mid/lower/upper) via `enrt_shoot_fireball_55`
  with vertical offsets {$00, $01, $FF} stored at
  `ENEMY_BOUNCE_FLAGS(new_slot)` (NES `Aquamentus_ObjFireballOffset`
  = `$0478,Y` = same RAM cell as ENEMY_BOUNCE_FLAGS).
- `MOVE_TIMER != 0` path: every other frame (`FrameCounter & 1 == 0`),
  scan slots $0B..$00 — for each fireball ($55), add per-slot
  Y-offset to `ENEMY_Y`.

`c_aquamentus_draw(slot)` (Z_04.asm:5764):
- Frame select: tile_idx = $05 if `(FrameCounter & $10) != 0` else $0B
  — switches anim every 16 frames.
- Per-frame attr: `(INVINCIBILITY & 3) ^ 3`. Steady-state = 3
  (palette row 7 = level palette); non-zero invincibility cycles
  palette rows for hit-flash.
- Loop sprite_idx = 5..0: compute (sx, sy) from base + offset tables,
  pick tile from `k_aquamentus_tiles[tile_idx]`. Face tile $CC swaps
  to $C0 (open mouth) when `MOVE_TIMER < $20` (about-to-shoot).
- `draw_write_boss_sprite` per tile.

## RAM cell map (NES Variables.inc -> state header macros)

| NES name                          | NES addr | C macro                |
|-----------------------------------|----------|------------------------|
| `ObjType`                         | `$034F`  | `ENEMY_TYPE`           |
| `ObjX`                            | `$0070`  | `ENEMY_X`              |
| `ObjY`                            | `$0050`  | `ENEMY_Y`              |
| `ObjDir`                          | `$0098`  | `ENEMY_DIR`            |
| `ObjTimer`                        | `$0028`  | `ENEMY_MOVE_TIMER`     |
| `ObjGridOffset`                   | `$0394`  | `BOSS_OBJ_GRID_OFFSET` (file-local) |
| `Random`                          | `$0019`  | `ENEMY_RNG_B`          |
| `Aquamentus_ObjFireballOffset`    | `$0478`  | `ENEMY_BOUNCE_FLAGS`   |
| `ObjInvincibilityTimer`           | `$04B2`  | `ENEMY_INVINCIBILITY`  |
| `FrameCounter`                    | `$0015`  | `FRAME_COUNTER`        |

## Wired dispatch (delta from step 9)

| Hex | NES type   | INIT row              | UPDATE row              |
|-----|------------|------------------------|--------------------------|
| $3D | Aquamentus | `enrt_init_aquamentus` | `enrt_update_aquamentus` |

## Build verification

`python tools/debug/build_debug.py` — clean post step 10 wire. Active
scope:
- `src/game/enemies/enemy_boss_bridge.c` (+3 native bodies +
  1 forwarder + 4 data tables).
- `src/game/world/draw_dispatch.c` (+1 native body
  `draw_write_boss_sprite`).
- `src/game/world/draw_dispatch.h` (+1 prototype).
- `src/game/enemies/enemy_loop.c` (+2 dispatch rows + externs).

## Coverage advance

Task 7.4 dispatch coverage:
  UPDATE: 34 -> 35 wired rows (+1: $3D).
  INIT:   26 -> 27 wired rows (+1: $3D).

## Step 11 sequencing (next)

- step 11 — family close (multi-slot probe + Drain Rule D1 audit
            sweep across the projectile-enemy family). Verify INIT/UPDATE
            pair coverage end-to-end, document remaining gaps for
            Task 7.5 hand-off.
