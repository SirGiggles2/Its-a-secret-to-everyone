# T-116 (sword part) — NES sword + Link item-use state

NES source: Z_05 WieldSword / WieldWeapon, Z_01 PlaceWeaponForPlayerState
[AndAnim] / PlaceWeapon, Z_07 UpdateSwordOrRod, AnimateLinkBase /
AnimateLinkObjState, Walker_Move (movement gate), Link_EndMoveAndAnimate
@Animate. Genesis: src/game/combat/combat_runtime.c (vanilla path; Redux arc
kept), item wields in bomb.c / candle_fire.c / boomerang.c / arrow.c,
room-entry Link init in enemy_loop_room_init.

Per-frame cells, lockstep presets pressing A facing up / down / left / right
(tmp_sw*): Link ObjState $AC, ObjAnimCounter $3D0, sword ObjState $B9,
counter $3DD, X $7D, Y $91, dir $A5, Link X/Y — identical to NES on every
frame of the swing (21 frames x 4 directions), swing starts on the same
frame as NES (lag 0). Before: Genesis ran a custom 8-frame swing without the
5-frame state 1 (NES 15 frames), damage and the sword shot 5 frames early.

Sprites (verify_sprites.py, pixels + palette) mid-swing: sword + Link attack
pose exact in all four directions. Link walking (newgame f128-f206, left and
up): exact; walk frame now from NES ObjAnimFrame $3E4 on the NES 6-frame
cadence (was a private 8-frame toggle; baked left/right poses are stored in
the opposite frame order).

Link item-use state: every wield sets Link ObjState $10 (sword/bomb/arrow
AndAnim, candle/boomerang plain); Link can move again at state $3x (NES
Walker_Move), A/B only while $AC = 0. Sword Y bias removed (it compensated
the missing Link +2 in the overworld, fixed in T-092).

Known, tracked: the Genesis tick still runs weapons before input (T-102): the
Link step for a frame happens at the start of the next tick, so the walking
counter phase leads NES by one count; the wield frame compensates.

## Arrow (slot $12) and boomerang (slot $0F)

Ported as NES objects (arrow.c / boomerang.c; MoveShot / MoveObject /
targeting drains). Lockstep presets tmp_arrowR / tmp_arrowU / tmp_boomR:
slot cells State, X, Y, Dir, GridOffset, PosFrac, QSpeed, AnimCounter,
MovingLimit plus Link $AC/$3D0 and rupees — 0 differences over the whole
life of each weapon (arrow flight + spark + reset, 35 / 24 frames; boomerang
out + slow-down + return + catch, 79 frames), same start frame as NES.
Diagonal throw (tmp_boomUR): same state sequence, start position differs
because Genesis Link does not apply NES Link_FilterInput (NES ObjInputDir
$08 where Genesis has $09 on the first diagonal frame) -> T-122.

Full suite after the sword/Link-state change (vs T-119 build): lag frames
150 -> 103 (NES 92); Link + enemy slot 1-5 positions equal to NES more
often in 16 of 20 presets.

## Sword shot / magic shot (slot $0E), rod (slot $12), book fire (T-112)

NES source: Z_07 MakeSwordShot, @MakeMagicShot, SetUpWeaponWithState,
UpdateSwordShotOrMagicShot, DrawSwordShotOrMagicShot, HandleShotBlocked,
SetShotSpreadingState, SpreadShot, UpdateRodOrArrow / UpdateSwordOrRod
(rod: item slot 8, attr | 1); Z_05 WieldRod / WieldWeapon; Z_01 WieldCandle
(book: via candle_fire_wield_from_shot). Genesis: src/game/items/sword_shot.c
(new), combat_runtime.c update_sword_or_rod(slot) + roomrom_combat_wield_rod,
core_handle_shot_blocked book branch, weapon sprite cache slot $0E
(enemy_render.c). Native beam + magic_shot.c removed.

Item atlas: rod horizontal $8A-$8D and spread $30/$31 added to
item_chr_manifest.json from the live NES CHR dump (t114 UW and t123 OW
dumps identical; Redux ROM bytes at the same PRG offsets equal the original,
checked against the $82 sword tile Redux does change).

Lockstep presets tools/lockstep/presets/t116_*.json (FrameCounter aligned by
a stage write so the flash palette phase is comparable):
- Slot cells (State, X, Y, Dir, Grid, Frac, QSpeed, AnimCounter, Limit, Link
  $AC/$3D0, rupees): 0 diffs, lag 0 — sword shot up/right/left/down (flight +
  spread), magic shot up/right/left, rod slot $12 x3, book fire slot $10 (79
  frames).
- Sprites (verify_sprites.py, pixels + palette): 21/21 checkpoints PASS —
  wield frame, mid-flight, mid-spread, rod swing, magic shot, book fire.
- t116_shot_hit (beam into a stunned tektite): tektite HP / metastate /
  shove / timers and shot state/X/Y/dir 0 diffs f380-499 after the
  DestroyObject_WRAM fix (Genesis kept shove + $4F0 after the kill).
  Shot GridOffset differs: MoveShot keeps the old offset when scratch $0E is
  nonzero, and Genesis runs enemies before weapons (T-102), leaving $0E set.

Also fixed on the way: Link's pose now follows NES ObjAnimFrame $3E4 every
frame (after an item use NES shows frame 1), attack pose faces ObjDir for
any item (was the sword's latched face), and the wield frame itself draws the
attack pose.
