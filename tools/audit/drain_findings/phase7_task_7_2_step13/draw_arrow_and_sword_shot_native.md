# Phase 7 Task 7.2 step 13 — native DrawArrow + DrawSwordShotOrMagicShot

## Task header (Drain Rule D1)

- **NES source**: `reference/aldonunez/Z_07.asm:3437 DrawSwordShotOrMagicShot`
                  + `reference/aldonunez/Z_07.asm:3908 DrawArrow`
                  + helpers `OffsetAndDrawArrow` (4293) and
                  `L_DrawArrowOrBoomerang` (4299).
                  Tables: `RDirectionToWeaponFrame` (3795),
                  `RDirectionToWeaponBaseAttribute` (3804),
                  `RDirectionToOffsetsX/Y` (3807/3810).
- **Drained C**:  NEW — `src/game/world/draw_dispatch.c::draw_arrow`
                  + `draw_sword_shot_or_magic_shot`. Helper tables
                  `k_r_dir_to_weapon_frame`, `k_r_dir_to_weapon_base_attr`,
                  `k_r_dir_to_offsets_x`, `k_r_dir_to_offsets_y`.
- **Coverage**:   FULL — both NES bodies fully translated. Existing
                  drained chain reused for Anim_FetchObjPosForSpriteDescriptor
                  (`sprite_anim_fetch_obj_pos`),
                  Anim_SetSpriteDescriptorAttributes
                  (`core_anim_set_sprite_desc_attrs`),
                  Anim_WriteItemSprites (static `anim_write_item_sprites`
                  in same file), GetOppositeDir (`core_get_opposite_dir`).
- **Stance**:     EXTEND — drain primitives pre-existed; step 13 adds
                  the two weapon-draw bodies that compose them.

## Drain shape

Both bodies share the reverse-direction-index pattern:

```
Y = (core_get_opposite_dir(OBJ_DIR(slot)) >> 8) & 0x03
DRAW_FRAME = k_r_dir_to_weapon_frame[Y]
attr_base  = k_r_dir_to_weapon_base_attr[Y]
```

DrawSwordShotOrMagicShot adds:
- Vertical-Y bump for horizontal directions (`+3` to DRAW_Y when low
  2 bits of OBJ_DIR set).
- Palette flash via `(FrameCounter & 3) | attr_base` written through
  core_anim_set_sprite_desc_attrs.
- Player-vs-monster item-slot pick:
  - `slot >= $0D` (player shot): bit 7 of OBJ_STATE -> $23 (magic) else $22 (sword).
  - `slot <  $0D` (monster shot): OBJ_TYPE == $57 -> $22, else $23.
- Left-facing flip via `DRAW_FLIP_H = 1` when Y == 2.

DrawArrow adds:
- Left-facing flip via `DRAW_FLIP_H = 1` when OBJ_DIR == $02.
- Palette pick: monster arrow ($5B at slot < $0D) -> attr + 2 (palette
  row 6); else attr + InvArrow ($0659) - 1 (palette row 4 wood / 5 silver).
- OffsetAndDrawArrow inline: DRAW_X = ObjX + offsets_x[Y], DRAW_Y =
  ObjY + offsets_y[Y].
- L_DrawArrowOrBoomerang spark check: state high nibble == $20 ->
  override palette to row 1 (Anim_SetSpriteDescriptorAttributes(1)).
- Item slot fixed at $02 (arrow).

## Bridge wiring (enemy_projectile_bridge.c)

Step 12 stubs replaced with native calls:

```c
void c_draw_arrow(unsigned int slot)
{
    draw_arrow(slot);
}

void c_draw_sword_shot_or_magic_shot(unsigned int slot)
{
    draw_sword_shot_or_magic_shot(slot);
}
```

Now the $5B arrow row + $57/$58/$59 sword/magic shot rows pick up
visible OAM writes through the existing item-sprite chain (which
already reaches nes_ram[$0200..$02FF]). The OAM->SAT router still owes
the conversion to Genesis SAT slots (separate task #7), but at the
NES-side boundary the data is now correct.

## Header export

`src/game/world/draw_dispatch.h`:

```c
void draw_arrow(unsigned int slot);
void draw_sword_shot_or_magic_shot(unsigned int slot);
```

Both delegate to the static `anim_write_item_sprites` already in the
file, so no other static helpers had to be promoted.

## Verification — 12/12 PASS

Existing walker probe trace (5 slots) unchanged — no regression from
step 12:

```
slot 1 type=$07 alive 1->1 xy=(128,128)->(128,115) dir=$08 anim=5->4 draw=$03->$00 spd=$00->$20
slot 2 type=$03 alive 1->1 xy=( 64, 96)->( 51, 96) dir=$02 anim=1->1 draw=$00->$00 spd=$00->$20
slot 3 type=$05 alive 1->1 xy=( 55,160)->( 27,160) dir=$02 anim=1->1 draw=$00->$00 spd=$20->$20
slot 4 type=$2A alive 1->1 xy=(183, 96)->(155, 96) dir=$02 anim=6->7 draw=$01->$00 spd=$20->$20
slot 5 type=$0B alive 1->1 xy=(192,151)->(192,123) dir=$08 anim=6->7 draw=$01->$00 spd=$20->$20
>>> WALKER TICK TRACE: PASS <<<  G1..G12 ALL PASS
```

Build: green. Walker dispatch rows still tick + advance position. The
new code paths are not yet exercised by the multi-slot probe (no $5B
or $57 in seeded slots 1-5), but the draws would now produce real OAM
output instead of no-ops.

## Master plan checklist progress

After step 13 — Phase 7 Task 7.2 walker-family checklist:

- [x] octorok walking
- [x] moblin walking
- [x] stalfos walking
- [x] goriya walking
- [x] darknut walking
- [x] projectile hook (UPDATE rows + draw helpers both native)
- [ ] probe movement+collision  (movement done; collision via
                                 c_check_monster_collisions exists,
                                 needs probe extension for visible
                                 outcome)
- [ ] probe damage+death+drop   (combat hook not wired)
- [ ] commit family             (final phase commit)

Step 13 closes the second half of the projectile-hook line item: shot
rows ($53-$5A) tick AND draw natively. $5B / $5C are still NULL at
the dispatch level (separate NES bodies, separate drain steps).

## Rolled-forward TODOs

- Drain `UpdateMonsterArrow` ($5B) — NES UpdateRodOrArrow / UpdateArrowOrBoomerang
  branch (Z_07.asm:3813 / 4322).
- Drain `UpdateArrowOrBoomerang` ($5C body).
- Probe extension: sample dynamically-spawned shot slots to prove
  draw_arrow / draw_sword_shot_or_magic_shot run in-game.
- OAM->SAT router (task #7): nes_ram[$0200..$02FF] -> Genesis SAT
  slots 10+; needed before any drained sprite is *visible* in the
  emulator output.
- Lynel ($01/$02) UPDATE drain.
- Rope ($29) / Gel ($2C) wiring (drains exist, just need rows).
- `c_obj_shove` native (combat damage hook) — still stubbed.
- Walker_CheckTileCollision (room tile registry).
