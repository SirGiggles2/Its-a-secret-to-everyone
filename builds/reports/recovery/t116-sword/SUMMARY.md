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
