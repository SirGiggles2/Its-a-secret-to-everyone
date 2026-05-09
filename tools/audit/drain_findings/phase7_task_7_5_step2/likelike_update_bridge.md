# Phase 7 Task 7.5 step 2 — LikeLike UPDATE bridge ($17)

## Task header (Drain Rule D1)

- **NES source**: `Z_07.asm:5295 UpdateObject_JumpTable` row $17 ->
                  `UpdateLikeLike` @ `Z_04.asm:6818-6916`
                  (~100 lines, two paths driven by ObjCaptureTimer).

- **Drained C**:  No top-level `enrt_update_like_like` exists in
                  `src/oracle/enemies/`. Helpers/composed primitives
                  ARE drained:
                  - `z04_update_common_wanderer` @
                    `enemy_boss_bridge.c:68` (forwards to
                    `enrt_update_common_wanderer`).
                  - `z07_anim_fetch_obj_pos` (already widely linked).
                  - `c_check_monster_collisions` @
                    `enemy_walker_bridge.c:166` (forwards to
                    `link_collision_check_monster_collisions`).
                  - `enemy_hide_sprites_over_link` @
                    `enemy_dispatch.c:29` (drained from
                    `enemy_common_runtime.c:4`).
                  - `draw_object_mirrored_with_frame` @
                    `world/draw_dispatch.c:421` (already drained).
                  - `draw_object_mirrored_over_link` @
                    `world/draw_dispatch.c` (NEW this step — promoted
                    from NES `Z_04.asm:763`).

- **Coverage**:   FULL for $17 LikeLike UPDATE — all NES code paths
                  covered (free-roam wander + 4-frame anim, capture
                  detect + Link state reset, captured-handle + magic
                  shield drop + draw-over-link + death-release).

- **Stance**:     EXTEND. Top-level UPDATE body is not directly drained;
                  native bridge body in `enemy_special_bridge.c` carries
                  per-line NES translation of `Z_04.asm:6818-6916`. Same
                  model as `enemy_boss_bridge.c` (Aquamentus / Vire).
                  All composed primitives already linked into Debug.md.

## Native bridge body added (`enemy_special_bridge.c`)

| Function                         | NES source         | Lines (asm) |
|----------------------------------|--------------------|-------------|
| `enrt_update_like_like`          | `Z_04.asm:6818`    | ~100        |

### NES RAM cell aliases (file-local)

| NES name                | NES addr | C macro                       |
|-------------------------|----------|-------------------------------|
| `ObjCaptureTimer`       | `$042C`  | `LIKELIKE_CAPTURE_TIMER`      |
| `LinkParalyzed`         | `$0512`  | `LINK_PARALYZED_FLAG`         |
| `InvMagicShield`        | `$0676`  | `INV_MAGIC_SHIELD`            |
| `ObjShoveDir`           | `$00C0`  | `LIKELIKE_OBJ_SHOVE_DIR`      |
| `ObjShoveDistance`      | `$00D3`  | `LIKELIKE_OBJ_SHOVE_DIST`     |

These shadow `ENEMY_TURN_TIMER` / `LINK_DAMAGE_DISABLE_FLAG` /
`LINK_SHIELD_BLOCK_FLAG` / `MON_SHOVE_DIR` / `MON_SHOVE_TIMER` (same
addresses, NES Zelda 1 reuses cells per object semantically). Naming
follows the like-like context for self-documentation; underlying
behavior is identical because the addresses match.

### Composed primitive promoted

| Primitive                          | NES source       | Native body                       |
|------------------------------------|------------------|-----------------------------------|
| `draw_object_mirrored_over_link`   | `Z_04.asm:763`   | `src/game/world/draw_dispatch.c`  |

`draw_object_mirrored_over_link(frame, slot)`:
- Sets `DRAW_MIRRORED = 1`, `DRAW_ANIM_INDEX = OBJ_TYPE(slot) + 1`,
  `DRAW_FRAME = frame`, `DRAW_OBJ_INDEX = slot`.
- Hardcodes `DRAW_LEFT_SPRITE_OFFSET = $40`, `DRAW_RIGHT_SPRITE_OFFSET = $44`
  — sprite slots $10 / $11 in the OAM mirror, fixed under Link.
- Tail-calls `draw_object_with_anim_and_specific_sprites(slot)`.

Matches NES `DrawObjectMirroredOverLink` exactly. Used here by the
Like-Like capture branch so its body draws on top of Link.

## State machine summary

`enrt_update_like_like(slot)`:

Path 1 — `LIKELIKE_CAPTURE_TIMER(slot) == 0` (free-roam):
1. `z04_update_common_wanderer(0x80, slot)` — wander + 1px-pulse.
2. 4-frame anim cycle: `--anim_counter`; on rollover set counter=$08
   and `frame = (frame + 1) & 3`.
3. `z07_anim_fetch_obj_pos(slot)` + `draw_object_mirrored_with_frame(frame, slot)`
   + `c_check_monster_collisions(slot)`.
4. If post-collision capture timer fired (Link grab landed inside
   `CheckMonsterCollisions`), seed capture state:
   - Monster X/Y = Link X/Y.
   - Clear Link's MOVE_TIMER / METASTATE / SHOVE_DIR / SHOVE_DIST.
   - Reset monster anim (frame=0, counter=$04).
   - `++LINK_PARALYZED_FLAG`.

Path 2 — `LIKELIKE_CAPTURE_TIMER(slot) != 0` (Link captured):
1. If `frame <= 2`: `--anim_counter`; on rollover counter=$04 and
   `++frame` (NES: `LDA #$02 / CMP frame / BCC = skip animate`).
2. `++LIKELIKE_CAPTURE_TIMER(slot)`. On `>= $60`: clear `INV_MAGIC_SHIELD`,
   re-pin timer at $C0 (so the bite-flash keeps replaying without
   overflowing — NES intentional).
3. `z07_anim_fetch_obj_pos(slot)` + `draw_object_mirrored_over_link(frame, slot)`
   + `c_check_monster_collisions(slot)`.
4. If `ENEMY_METASTATE(slot) != 0` (monster died from Link's sword):
   - `LINK_PARALYZED_FLAG = 0`.
   - `enemy_hide_sprites_over_link()` (sprites $10/$11 -> Y=$F8).

## Wired dispatch (delta from step 1)

| Hex | NES type | INIT row             | UPDATE row              |
|-----|----------|----------------------|-------------------------|
| $17 | LikeLike | `enrt_init_walker`   | `enrt_update_like_like` |

## Coverage advance

Task 7.5 dispatch coverage:
  INIT:   40 wired rows (no change).
  UPDATE: 45 -> 46 wired rows (+1: $17).

## Build verification

`python tools/debug/build_debug.py` — clean post step 2 wire. Active
scope:
- `src/game/enemies/enemy_special_bridge.c` (new TU, +1 native body).
- `src/game/world/draw_dispatch.c` (+1 native body
  `draw_object_mirrored_over_link`).
- `src/game/world/draw_dispatch.h` (+1 prototype).
- `src/game/enemies/enemy_loop.c` (+1 dispatch row + extern + comment).
- `tools/debug/build_debug.py` (+1 TU registration).

## Step 3 sequencing (next)

- step 3 — UpdatePolsVoice bridge ($16 UPDATE). Two states (walking
  + jumping). Helpers already drained (`enrt_pols_voice_move_x` @
  `enemy_boss_runtime.c:395`, `enrt_pols_voice_get_colliding_tile` @ :494,
  `enrt_pols_voice_is_square_walkable` @ :514). Need NES translation
  for `UpdatePolsVoice` (Z_04.asm:6533) main body + state-1 jumping
  path (Z_04.asm:6675).

- step 4 — UpdateWallmaster bridge ($27 UPDATE). Largest of the
  three. Multi-state with Link-capture submode. Helpers already drained
  (`enrt_wallmaster_calc_start_position`,
  `enrt_wallmaster_put_sprites_behind_bg_if_needed`,
  `enrt_wallmaster_prepare_to_draw`).

- step 5+ — bubble UPDATE confirm (already wired Task 7.4 step 6d) +
  vire split-behavior verify (UPDATE wired Task 7.3 step 7) +
  shield/rupee option (UnderworldPersonLifeOrMoney $52) + family close.
