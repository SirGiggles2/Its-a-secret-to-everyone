# Phase 7 Task 7.2 step 8 — multi-slot probe verifies $03/$05/$2A wiring

## Task header (Drain Rule D1)

- **NES source**: N/A (probe-only step; no NES code path drained)
- **Drained C**:  `src/game/enemies/enemy_loop.c::enemy_loop_force_spawn_typed`
                  (NEW step 8) + extended
                  `src/game/enemies/probes/enemy_loop_probe.c`
                  + extended `tools/debug/probes/probe_walker_tick_trace.lua`
- **Coverage**:   N/A (verification step)
- **Stance**:     EXTEND — new generic spawn hook composes existing
                  `clear_slot_scratch` + `enemy_init_fns[]` dispatch.

## What changed

### `src/game/enemies/enemy_loop.h` + `.c`

Added `enemy_loop_force_spawn_typed(slot, type, x, y, dir)` — generic
seed function that lets the boot probe spawn ANY enemy type. The
existing `enemy_loop_force_spawn_slow_octorock` is now a one-line
forwarder to the typed variant.

### `src/game/enemies/probes/enemy_loop_probe.{h,c}`

1. Added `ENEMY_LOOP_MULTI_SLOT_BASE = 0xFF7F80` block layout — 4
   slots * 8 bytes (alive/type/x/y/dir/anim/draw/walk_spd per slot).

2. `enemy_loop_probe_run` now seeds 4 slots:
   - slot 1 = $07 RedSlowOctorock at (128, 128) [unchanged from step 6]
   - slot 2 = $03 BlueMoblin     at (64, 96)
   - slot 3 = $05 BlueGoriya     at (64, 160)
   - slot 4 = $2A Stalfos        at (192, 96)

3. Updated boot probe checks: alive_count expects 4, slot 2 type
   expects $03 (was 0/empty pre-step-8).

4. `enemy_loop_probe_publish_live` now publishes the multi-slot block
   alongside the slot-1 block at end of `enemy_loop_tick`.

### `tools/debug/probes/probe_walker_tick_trace.lua`

1. Read multi-slot block + dump per-slot before/after summary.
2. Added gates G7-G10:
   - G7: slot 2 (moblin) alive+type held across trace
   - G8: slot 3 (goriya) alive+type held
   - G9: slot 4 (stalfos) alive+type held
   - G10: at least one of slots 2/3/4 advanced anim/draw

## Verification

10/10 PASS:

```
slot 1 type=$07 alive 1->1 xy=(128,128)->(128,127) dir=$08 anim=5->4 draw=$03->$00 spd=$00
slot 2 type=$03 alive 1->1 xy=(64,96)->(63,96)     dir=$02 anim=0->0 draw=$00->$00 spd=$00
slot 3 type=$05 alive 1->1 xy=(64,160)->(64,160)   dir=$02 anim=0->0 draw=$00->$00 spd=$00
slot 4 type=$2A alive 1->1 xy=(192,96)->(192,96)   dir=$04 anim=237->182 draw=$00 spd=$00
  PASS  G1..G10 ALL PASS
>>> WALKER TICK TRACE: PASS <<<
```

## Behavioral observations (deferred TODOs)

1. **Goriya / Stalfos / Moblin not walking** — `clear_slot_scratch`
   in `enemy_loop.c` zeroes `ENEMY_WALK_SPEED`, and only the octorok-
   family init bodies (`enrt_octorock_common`, `enrt_init_darknut`)
   explicitly re-seed it. NES InitWalker (Z_07.asm:5601 jump $01-$06,
   $2A) presumably either inherits speed from RoomData or has a
   per-type wrapper that sets it. Step 9: review NES InitWalker
   chain + add per-type WALK_SPEED seed. Visible result: enemies
   currently stand still even though their UPDATE bodies tick.

2. **Moblin / Goriya don't draw** — bare drain bodies (no
   anim/animate-and-draw call). NES UpdateObject central post-call
   draw not yet wired. Step 9+: extend with explicit draw tail OR
   add central post-dispatch hook.

3. **Stalfos animation rapidly DECs (237→182 in 120 frames)** —
   `enrt_animate_and_draw_common_object` calls
   `z07_anim_advance_and_fetch(8, slot)` which decrements
   `ENEMY_ANIM_TIMER` by `val` (8) per frame; underflows wrap.
   This is per-NES; visible cycle would be present once draw is
   wired.

4. **Octorok slot 1 trace identical to step 6** — single-slot
   regression confirmed (G1-G6 unchanged from step 6 PASS).

## Rolled-forward TODOs (from steps 6/7)

- Central post-dispatch animate/draw hook (or extend bare bodies).
- `c_shoot_if_wanted` native (projectile hook from master plan).
- `c_obj_shove` native (combat damage hook).
- Walker_CheckTileCollision (room tile registry).
- Lynel ($01/$02) / Darknut ($0B/$0C) UPDATE drain.
- Rope ($29) / Gel ($2C) wiring (drains exist, just need rows).
- Blue-monster shoot-bypass branch in `enrt_try_shooting`.
