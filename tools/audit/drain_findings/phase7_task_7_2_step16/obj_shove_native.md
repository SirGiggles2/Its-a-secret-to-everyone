# Phase 7 Task 7.2 step 16 — native Obj_Shove drain

## Task header (Drain Rule D1)

- **NES source**: `reference/aldonunez/Z_07.asm:2274 Obj_Shove`
                  + helpers `EnsureObjectAligned` (2086),
                  `CheckPersonBlocking` (Z_01.asm:3108),
                  `ResetShoveInfo`/`ShoveMoveMin` (2333/2346),
                  `ResetMovingDir` (used by CheckPersonBlocking).
                  Tables: none.
- **Drained C**:  `src/game/enemies/enemy_walker_bridge.c::c_obj_shove`
                  + statics `shove_ensure_object_aligned`,
                  `shove_check_person_blocking`. Calls drained
                  `core_get_opposite_dir`, `core_reset_moving_dir`,
                  `collision_get_colliding_tile_moving`,
                  `object_bound_by_room_with_dir`.
- **Coverage**:   FULL — entire NES body translated, including
                  init-phase perpendicular-shove handling, Link's
                  bounce-backward branch, person-blocking check, and
                  the 4-pixel grid-aware move loop.
- **Stance**:     REPLACE — was a step-6 stub
                  (`OBJ(NES_OBJ_SHOVE_DIR, slot) = 0u;`). Stub never
                  fired in walker probe (combat damage not wired) so
                  parity test is degenerate; drain is correct-by-
                  construction against NES bytecode, verified non-
                  regressing in the existing 12/12 walker trace.

## Drain shape

NES Obj_Shove has two phases gated on the high bit of `ObjShoveDir`:

```
init phase  (high bit set):
  - clear high bit
  - if obj facing horizontal AND shove dir horizontal -> OK
  - if obj facing vertical   AND shove dir vertical   -> OK
  - else perpendicular: if grid-aligned, allow; otherwise
      - non-Link slot: ResetShoveInfo
      - Link slot 0:   bounce shove backward (opposite of Link facing)

move phase  (high bit clear):
  - if ShoveDistance == 0 -> ResetShoveInfo
  - else loop 4 pixels:
      - if grid_offset == 0:
          align X/Y to 8-pixel grid + Y |= 5
          tile = collision_get_colliding_tile_moving(slot)
          if tile >= ObjectFirstUnwalkableTile -> ResetShoveInfo
      - bound = object_bound_by_room_with_dir(dir, slot)
      - if bound == 0 -> ResetShoveInfo
      - if slot 1 type is grumble moblin ($36) or person ($4B..$52):
          shove_check_person_blocking()
          if $0F cleared -> ResetShoveInfo
      - delta = (dir & $05) ? +1 : -1
      - decrement ShoveDistance
      - advance grid_offset; wrap to 0 on multiple of $10 (or 8 for Link)
      - if dir & $03 (horizontal bits): ObjX += delta
        else                            ObjY += delta
```

`shove_ensure_object_aligned` mirrors NES EnsureObjectAligned exactly:
when grid_offset is 0, snap X to `& $F8` and Y to `(& $F8) | $05` (NES
uses ObjY top-left + 5px hot-spot offset).

`shove_check_person_blocking` mirrors NES CheckPersonBlocking exactly:
if Link Y < $8E AND moving-dir bit-3 set (moving up), zero $0F via
core_reset_moving_dir; else leave $0F alone. NES uses absolute
ObjY/ObjDir at slot 0 — translated as `OBJ(NES_OBJ_Y, 0u)` and
`RAM(NES_LINK_MOVING_DIR)`.

## Why this matters / why it can't be regression-tested yet

Combat hit detection is not wired in Phase 7 Task 7.2 (`c_obj_shove`
called only from `wanderer_update_common` when `MON_SHOVE_DIR(slot) !=
0`, and nothing in the current dispatch sets that). So the probe trace
shows zero behavioral change from this drain — every walker still
moves the same distances on the same frames, because the gate at
`enemy_walker_bridge.c:87` (`if (OBJ(NES_OBJ_SHOVE_DIR, slot) != 0u)`)
never fires.

What the drain unlocks:

- When the combat damage hook lands (rolled-forward TODO `c_obj_shove
  native (combat damage hook) — still stubbed` is now CLOSED), monsters
  taking sword/projectile hits will receive proper knockback animation
  identical to NES — sliding 4 pixels per frame in ShoveDir until
  ShoveDistance hits 0 or they slam into a wall, with the correct
  perpendicular-shove guard so a horizontal-facing octorock cannot be
  shoved sideways while mid-stride.
- The sticky bug class around "shoved enemy walks through a wall
  because grid alignment was skipped" is structurally avoided — the
  drain matches NES grid-snap behavior.

## Verification — 12/12 PASS unchanged

Existing walker probe trace:

```
slot 1 type=$07 alive 1->1 xy=(128,128)->(128,96) dir=$08->$08 anim=5->4 draw=$03->$03 spd=$00->$00
slot 2 type=$03 alive 1->1 xy=( 64, 96)->( 31, 96) dir=$02->$02 anim=1->1 draw=$00->$00 spd=$00->$00
slot 3 type=$05 alive 1->1 xy=( 55,160)->(172,160) dir=$02->$02 anim=1->1 draw=$00->$00 spd=$20->$20
slot 4 type=$2A alive 1->1 xy=(183, 96)->( 44, 96) dir=$02->$02 anim=6->1 draw=$01->$01 spd=$20->$20
slot 5 type=$0B alive 1->1 xy=(192,151)->(192, 12) dir=$08->$08 anim=6->1 draw=$01->$01 spd=$20->$20
>>> WALKER TICK TRACE: PASS <<<  G1..G12 ALL PASS
```

Identical to step-13 + step-14 deltas — confirms the drain doesn't
disturb the no-shove path. Build: green.

## Master plan checklist progress

After step 16 — Phase 7 Task 7.2 walker-family checklist:

- [x] octorok walking
- [x] moblin walking
- [x] stalfos walking
- [x] goriya walking
- [x] darknut walking
- [x] projectile hook (UPDATE rows + draw helpers both native, live
                       $5B consumer captured)
- [ ] probe movement+collision  (movement done; collision via
                                 c_check_monster_collisions exists,
                                 needs probe extension for visible
                                 outcome)
- [ ] probe damage+death+drop   (combat hook not wired — but Obj_Shove
                                 is now native, ready for the day the
                                 hook lands)
- [ ] commit family             (final phase commit)

Step 16 closes the rolled-forward TODO `c_obj_shove native (combat
damage hook) — still stubbed`. Full damage flow still gated on the
`Walker_CheckTileCollision (room tile registry)` and
`UpdateRodOrArrow / UpdateArrowOrBoomerang` drains.

## Rolled-forward TODOs

- Drain `UpdateRodOrArrow` / `UpdateArrowOrBoomerang` ($5B/$5C
  bodies) — Z_07.asm:3813 / 4322. Step 15. Multi-hour.
- OAM->SAT router (task #7).
- Lynel ($01/$02) UPDATE drain.
- Rope ($29) / Gel ($2C) wiring (drains exist, just need rows).
- Walker_CheckTileCollision (room tile registry).
- Combat damage hook (`enemy_walker_runtime` does not call
  `c_obj_shove` — wanderer path does. Need to wire walker hit ->
  ShoveDir for the new native body to fire on octorok/moblin/etc.).
