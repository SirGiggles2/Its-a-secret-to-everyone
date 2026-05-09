# Phase 7 Task 7.2 step 19 — damage path observable end-to-end

## Task header (Drain Rule D1)

- **NES source**: `reference/aldonunez/Z_01.asm:5421 CheckMonsterCollisions`
                  + `:5545 CheckLinkCollision` + 6 weapon helpers
                  (`CheckMonsterBoomerangOrFoodCollision`,
                  `CheckMonsterSwordShotOrMagicShotCollision`,
                  `CheckMonsterBombOrFireCollision` x2,
                  `CheckMonsterSwordCollision`,
                  `CheckMonsterArrowOrRodCollision`).
                  Damage core: `Z_07.asm:2274 Obj_Shove`,
                  `combat_runtime.c::combat_deal_damage` /
                  `combat_handle_monster_died`,
                  `core_runtime.c::core_update_dead_dummy`.
- **Drained C**:  Body — `src/oracle/combat/link_collision_runtime.c::lcrt_check_monster_collisions`
                  + `src/game/combat/link_collision_dispatch.c::link_collision_check_monster_collisions`
                  (already drained pre-step-19).
                  Probe — `src/game/enemies/probes/enemy_loop_probe.c`
                  step 19 seed (sword slot 13 OBJ_STATE=2 + MON_HP(1)=$08
                  + ITEM_SWORD_LEVEL=1 + LINK_DIR=1) +
                  `publish_damage_viz()` block at $FF7FD8.
                  Lua reader — `tools/debug/probes/probe_walker_tick_trace.lua`
                  `dmg_viz()` + G15/G16/G17 gates.
- **Coverage**:   N/A (probe extension; no NES body drained at this step
                  — all drain artifacts pre-existed).
- **Stance**:     EXTEND existing $FF7E00 / $FF7F00 / $FF7F40 / $FF7F80 /
                  $FF7FA8 / $FF7FCC probe family. New $FF7FD8 block =
                  16 bytes ('DM' magic + 11 cell bytes + 3 reserved).
                  Block end = $FF7FE7.

## Drain shape

Probe init (after force_spawn 5 walkers) seeds the player sword in
slot 13 (outside the enemy_loop iterator range 1..11, so nothing
overwrites it per-frame):

```
ITEM_SWORD_LEVEL = 1
LINK_DIR         = 1   // any non-zero so dir & 0x0C check is sane
OBJ_STATE(13)    = 2   // sword swing state
OBJ_X(13)        = 0x80
OBJ_Y(13)        = 0x80   // coincident with slot 1 octorok
OBJ_DIR(13)      = 1
MON_HP(1)        = 0x08   // < dmg=$10 so first hit kills
```

Per-frame the drained walker UPDATE chain runs
`c_check_monster_collisions(slot)` ->
`link_collision_check_monster_collisions(slot)`. For slot 1:

```
world_get_object_middle(1)   // bbox center -> COMBAT_HITBOX_X/Y
hit_reaction(1) == 0          // first frame
collision_check_monster_sword_collision(1, 13)
  COMBAT_WEAPON_SLOT = 13
  COMBAT_DAMAGE_TYPE = 1
  OBJ_STATE(13) == 2 -> proceed
  k_sword_damage_points[0] = $10
  collision_check_monster_stabbing_collision(1, $10)
    COMBAT_DAMAGE_AMOUNT = $10
    COMBAT_THRESHOLD_X/Y = 12/16 (LINK_DIR & 0x0C != 0)
    collision_check_monster_slender_weapon_collision2(1)
      bbox check -> COMBAT_COLLIDED = 1
    collision_parry_or_shove(1, 13)
      link_collision_begin_shove(1)
        MON_SHOVE_DIR(1) = COMBAT_SHOVE_DIR | $80 = $81
        MON_SHOVE_TIMER(1) = $40
        MON_HIT_REACTION(1) = $10
    collision_handle_monster_weapon_collision(1, 13)
      combat_deal_damage(1)
        SFX_COMBAT = 2
        hp ($08) < dmg ($10) -> combat_handle_monster_died(1)
          ROOM_KILL_COUNT++
          core_update_dead_dummy(1)
            DEATH_FRAME_COUNTER = $20
            MON_METASTATE(1) = $10
```

Subsequent frames: `MON_HIT_REACTION(1) == $10` early-returns from
`link_collision_check_monster_collisions`, freezing the cells at the
first-hit values for the rest of the trace window.

## Verification — 17/17 PASS

```
STEP 19 DAMAGE-VIZ -- $FF7FD8 (slot 1 octorok damage cells)
  magic 'DM' = 'DM'
  hp_seed=$08 first=$08 last=$08
  hit_reaction first=$10 last=$10
  shove_dir/timer first=($81,$40) last=($81,$40)
  metastate first=$10 last=$10 (16=death)
  mon_type first=$07 last=$07 (0x60=drop)
  death_frame first=$20 last=$20 (32=set on death)
  kill_count first=1 last=1
  sword_state(13) first=$02 last=$02 (expect $02)
  harm_flag first=$00 last=$00
  ...
  PASS  G15 damage-viz magic 'DM' present (publisher fired)
  PASS  G16 ROOM_KILL_COUNT bumped (death observed) 1 -> 1
  PASS  G17 death/drop state set (metastate=$10 mon_type=$07)
>>> WALKER TICK TRACE: PASS <<<
```

Reading the cells:

- `hp_live == $08 == hp_seed`: NES `combat_deal_damage` does NOT
  decrement when `hp < damage`. It routes straight to
  `combat_handle_monster_died`. So a stationary HP value here is
  expected, not a missed write. Death is the visible signal.
- `hit_reaction == $10`: `link_collision_begin_shove` fires the 16-frame
  hit-stun. After the first frame the early-return at
  `link_collision_check_monster_collisions` line `if (MON_HIT_REACTION(monster_slot)) return;`
  prevents re-damage every subsequent frame, which is why all the
  damage cells freeze at the first-hit values.
- `shove_dir == $81`: top bit ($80) marks active shove + low bits ($01)
  encode shove direction. NES Obj_Shove (step 16 drain) consumes this.
- `shove_timer == $40`: 64-frame shove window. Matches NES asm constant.
- `metastate == $10`: 16 = death-anim entry per `core_update_dead_dummy`
  drain.
- `death_frame == $20`: 32-frame global death-animation hold. Drives
  the screen-flash + dummy-monster swap on NES.
- `kill_count == 1`: `ROOM_KILL_COUNT` bumped exactly once. Hit-reaction
  early-return prevents re-counting.
- `sword_state(13) == $02`: untouched across the trace (no walker UPDATE
  row writes slot 13).
- `harm_flag == $00`: `COMBAT_HARM_FLAG` increments only on Link harm,
  not monster harm. Stays 0 because Link parked at (0,0) doesn't
  collide with anything.

## What this proves / does not prove

PROVES:

- Walker checklist line "probe damage+death+drop" — first 2 of 3
  (damage + death) are now visible end-to-end as instrumentation
  evidence.
- `link_collision_check_monster_collisions` -> 6 weapon helpers ->
  `collision_check_monster_sword_collision` -> stabbing collision ->
  `collision_parry_or_shove` -> `link_collision_begin_shove` ->
  `collision_handle_monster_weapon_collision` -> `combat_deal_damage`
  -> `combat_handle_monster_died` -> `core_update_dead_dummy` chain
  is structurally complete. Every link executes against a real
  drained body.
- `MON_HP / MON_HIT_REACTION / MON_SHOVE_DIR / MON_SHOVE_TIMER /
  MON_METASTATE / DEATH_FRAME_COUNTER / ROOM_KILL_COUNT` macro paths
  read live RAM cells (no compile-time constants masking).

DOES NOT PROVE:

- Drop spawn. `MON_TYPE(1) == $07 != $60` across the trace, so the
  death-anim metastate-advance path that converts type to `$60`
  (dropped item) never fires. NES does this in `UpdateMetaObject` at
  `Z_07.asm:5403` when `metastate & $10 == $10` and the death animation
  completes. That handler isn't wired into our enemy_loop dispatch yet
  — when ENEMY_TYPE is a normal walker like $07, the dispatch routes
  to `enrt_update_octorock`, not `UpdateMetaObject`. Either the walker
  UPDATE rows need a `if (METASTATE != 0) call_meta_object_handler()`
  branch, or a separate dispatch table for dying-monster slots.
- Stationary sword behavior matches a real Link swing. The probe seeds
  OBJ_STATE(13)=2 statically; in real gameplay the sword cycles
  through states 1->2->3 and back to 0 over ~10 frames, and the bbox
  position is computed from Link's pose. Both are out of scope for
  step 19 (probe is a damage-pipe smoke test, not a Link-action sim).
- That `combat_deal_damage`'s HP-decrement branch is correct under
  load. Step 19 only exercises the `hp < damage` death branch. To
  verify the `hp -= damage` branch would need MON_HP(1) seeded
  >= $20 + a multi-hit window with HIT_REACTION decrement.

## Master plan checklist progress

After step 19 — Phase 7 Task 7.2 walker-family checklist:

- [x] octorok walking
- [x] moblin walking
- [x] stalfos walking
- [x] goriya walking
- [x] darknut walking
- [x] projectile hook
- [x] probe movement+collision (step 17 closed)
- [x] probe damage+death (step 19 closes 2/3 of damage+death+drop:
                          MON_HP/SHOVE/HIT_REACTION/METASTATE/
                          DEATH_FRAME/KILL_COUNT all set on first-frame
                          sword hit; walker checklist treats death as
                          the proof of damage path correctness)
- [ ] probe drop          (death-anim metastate-advance handler not
                          wired into enemy_loop dispatch; separate task)
- [ ] commit family       (final phase commit)

## Rolled-forward TODOs

- Drain `UpdateRodOrArrow` / `UpdateArrowOrBoomerang` ($5B/$5C
  bodies). Step 15. Multi-hour.
- OAM->SAT router (task #7).
- Lynel ($01/$02) UPDATE drain.
- Rope ($29) / Gel ($2C) wiring.
- Room init that writes `$034A` (ObjectFirstUnwalkableTile) — last
  prereq before c_walker_check_tile_collision body activates.
- `UpdateMetaObject` (Z_07.asm:5403) drain + dispatch wiring for
  dying-monster slots — last prereq before drop spawn ($60 type
  conversion) becomes observable.
