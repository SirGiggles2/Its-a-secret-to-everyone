# Phase 7 Task 7.2 step 7 — walker family dispatch wiring (moblin/goriya/stalfos/lynel-init/darknut-init/fast-octo)

## Task header (Drain Rule D1)

- **NES source**: `reference/aldonunez/Z_07.asm:5601` InitObject_JumpTable +
                  `reference/aldonunez/Z_04.asm:5295` UpdateObject_JumpTable
- **Drained C**:  `src/oracle/enemies/enemy_walker_runtime.c`
                  (enrt_init_walker, enrt_init_darknut,
                  enrt_init_fast_octorock, enrt_update_moblin,
                  enrt_update_stalfos)
                  + `src/oracle/enemies/enemy_wanderer_runtime.c`
                  (enrt_update_goriya,
                  enrt_walker_set_input_dir_and_try_shooting_boomerang)
                  + `src/game/enemies/enemy_walker_bridge.c`
                  (NEW step 7: z07_anim_set_obj_hflip,
                  enrt_animate_and_draw_common_object)
- **Coverage**:   PARTIAL — moblin update body is bare in drain (no
                  anim/draw/coll); NES UpdateMoblin tail-jumps to
                  _TryShooting and the central UpdateObject dispatcher
                  handles post-call animate/draw. Our enemy_loop_tick
                  has no central post-dispatch animate/draw yet — moblin
                  walks but does not draw sprites until that hook lands
                  (step 8). Goriya/stalfos/octorock fully drawn.
- **Stance**:     EXTEND — composes already-drained primitives with two
                  new bridge forwarders (z07_anim_set_obj_hflip +
                  enrt_animate_and_draw_common_object) inlined to avoid
                  dragging src/oracle/enemies/enemy_runtime.c (and its
                  legacy_bridge.h chain) into the link.

## What changed

### `src/game/enemies/enemy_walker_bridge.c`

1. **`z07_anim_set_obj_hflip(slot)` — forwarder.** Routes to
   `sprite_anim_set_obj_hflip` (already linked in
   `src/game/world/sprite_dispatch.c:100`). Mirrors `src/gen/z_07.c`
   `NATIVE_SPRITE` branch — `z_07.c` is not linked into Debug.md so we
   forward directly.

2. **`enrt_animate_and_draw_common_object(val, slot)` — native body.**
   3-line composition matching `src/oracle/enemies/enemy_runtime.c:4`:
   `z07_anim_advance_and_fetch(val, slot); z07_anim_set_obj_hflip(slot);
   c_draw_object_not_mirrored_with_frame(0, slot);`. Inlined here
   instead of linking `enemy_runtime.c` because the latter pulls in
   `enemy_runtime_private.h` + `legacy_bridge.h` chain. Used by
   `enrt_update_stalfos`.

### `src/game/enemies/enemy_loop.c`

Filled out `enemy_init_fns[]` and `enemy_update_fns[]` walker family
rows per NES jump tables:

| Type | Init                              | Update                       |
|------|-----------------------------------|------------------------------|
| $01  | `enrt_init_walker` (Lynel blue)   | (no drain — step 8+)         |
| $02  | `enrt_init_walker` (Lynel red)    | (no drain — step 8+)         |
| $03  | `enrt_init_walker` (Moblin blue)  | `enrt_update_moblin` (bare)  |
| $04  | `enrt_init_walker` (Moblin red)   | `enrt_update_moblin` (bare)  |
| $05  | `enrt_init_walker` (Goriya blue)  | `enrt_update_goriya` (full)  |
| $06  | `enrt_init_walker` (Goriya red)   | `enrt_update_goriya` (full)  |
| $07  | `enrt_init_slow_octorock_or_ghini`| `enrt_update_octorock` (step 6) |
| $08  | `enrt_init_fast_octorock`         | `enrt_update_octorock`        |
| $09  | `enrt_init_slow_octorock_or_ghini`| `enrt_update_octorock`        |
| $0A  | `enrt_init_fast_octorock`         | `enrt_update_octorock`        |
| $0B  | `enrt_init_darknut` (blue)        | (no drain — step 8+)         |
| $0C  | `enrt_init_darknut` (red)         | (no drain — step 8+)         |
| $2A  | `enrt_init_walker` (Stalfos)      | `enrt_update_stalfos` (full) |

`enrt_update_octorock` switches on `ENEMY_TYPE` internally for
slow/fast + red/blue qspeed + turn-rate variants — single body
covers $07-$0A.

## Verification

`probe_walker_tick_trace.lua` still 6/6 PASS — $07 octorok behavior
unchanged from step 6 (probe seeds only slot 1 with type $07; step 7
adds dispatch rows for other types but does not affect this trace).

```
init probe magic = 'EL' (expect 'EL')
[t+  0] f=   19 alive=1/1 type=$07 x=$80 y=$80 dir=$08 anim=5 draw=$03 spd=$00
[t+ 30] f=   33 alive=1/1 type=$07 x=$80 y=$80 dir=$08 anim=3 draw=$03 spd=$20
[t+ 40] f=   38 alive=1/1 type=$07 x=$80 y=$7F dir=$08 anim=4 draw=$00 spd=$00
[t+120] f=   75 alive=1/1 type=$07 x=$80 y=$7F dir=$08 anim=3 draw=$00 spd=$00
  PASS  G1 magic 'TK' (publisher fired)
  PASS  G2 frame_counter advanced (19 -> 75)
  PASS  G3 ENEMY_ALIVE_FLAG(1) stays 1
  PASS  G4 ENEMY_TYPE(1) stays $07
  PASS  G5 anim_timer OR draw_frame advanced
  PASS  G6 X OR Y advanced
>>> WALKER TICK TRACE: PASS <<<
```

## Behavioral notes

- **Moblin draw deferred**: `enrt_update_moblin` is a 3-line drain
  (turn rate + wanderer + try_shoot). NES UpdateMoblin in `Z_04.asm`
  is the same shape — it tail-jumps to `_TryShooting` and relies on
  the NES `UpdateObject` dispatcher's post-call animate/draw stage.
  Our `enemy_loop_tick` does not have that central stage yet, so a
  moblin slot will tick state and walk but will not appear visually
  until either:
  (a) step 8 extends `enrt_update_moblin` with an explicit draw tail
      (matching `enrt_update_octorock`'s pattern), or
  (b) `enemy_loop_tick` grows a post-dispatch animate/draw hook
      mirroring NES UpdateObject.
  Path (a) is simpler and matches Drain Rule D1 EXTEND stance.

- **Lynel ($01/$02)** + **Darknut ($0B/$0C)** UPDATE bodies are not
  drained yet — slots will init (DIR + WALK_SPEED set) but will not
  tick (NULL row in `enemy_update_fns[]` is no-op per
  `enemy_loop_tick` guard). Drain landing in step 8+.

- **Rope ($29)** and **Gel ($2C)** have drained UPDATE bodies
  (`enrt_update_rope`, `enrt_update_gel`) but step 7 deliberately
  does not wire them — they have different init shapes (rope: leever-
  style speed-ramp; gel: x-shift draw quirk) that warrant their own
  family review. Wired in step 8+ when projectile hook lands.

## Deferred TODOs (rolled forward from step 6 + new step 7 items)

1. **Central post-dispatch animate/draw hook** in `enemy_loop_tick`
   — mirrors NES UpdateObject. Without it, bare drain bodies (moblin)
   never visually render. OR extend each bare body with explicit draw
   tail. Ship-blocker for Phase 7 Task 7.2 master plan checklist
   "moblin / stalfos walking" visibility.

2. **`c_shoot_if_wanted` native** — projectile spawn (master plan
   "projectile hook"). Required for any visible attack from
   octorok/moblin/stalfos/goriya. Stub returns 0 throughout.

3. **`c_obj_shove` native** — knockback. Wire when combat-damage hook
   applies push-dir.

4. **Walker_CheckTileCollision** — needs room tile registry. Octorok
   currently phases through walls.

5. **Lynel ($01/$02) UpdateLynel drain** — in `Z_04.asm` UpdateLynel.
   Body shape: lynel charges horizontally, has fireball attack.

6. **Darknut ($0B/$0C) UpdateDarknut drain** — in `Z_04.asm`
   UpdateDarknut. Body shape: directional shield blocks attacks from
   facing direction.

7. **Rope ($29) wiring** — `enrt_update_rope` already drained
   (`enemy_walker_runtime.c:97`). One-line add to dispatch table.

8. **Gel ($2C) wiring** — `enrt_update_gel` already drained
   (`enemy_walker_runtime.c:163`). Same.

9. **Blue-monster shoot-bypass** — NES UpdateMoblin _TryShooting has
   "if blue moblin / blue lynel / blue octorock then always-try"
   bypass missing in C drain `enrt_try_shooting`. Folded into native
   shoot path when projectile hook lands.

10. **Single-slot probe coverage** — current
    `probe_walker_tick_trace.lua` only seeds slot 1 with type $07.
    Step 8+ needs multi-slot multi-type seeding to verify moblin /
    goriya / stalfos dispatch actually runs without trapping.
