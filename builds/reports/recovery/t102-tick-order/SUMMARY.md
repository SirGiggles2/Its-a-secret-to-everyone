# T-102 play-tick order

NES source: Z_07.asm UpdateMode5Play (UpdatePlayer -> chase target -> weapons
$0D..$12 -> object loop $B..1 -> tail), UpdatePlayer (halted state $40 returns;
Link_HandleInput, Walker_Move, Link_EndMoveAndAnimate -> AnimateLinkBase),
IsUpdatingMode skip when UpdatePlayer changed the mode, Walker_Move clears [0E];
Z_05.asm InitMode6 / InitMode7 Sub1 / UpdateMode7SubmodeAndDrawLink
(Link_EndMoveAndAnimateBetweenRooms during OW scrolls).

Genesis (RoomRom/src/main.c): the gameplay block that ran before input is now
play_update_objects() + play_finish(), called after input and Link movement;
objects are skipped on a frame whose movement started a scroll. Link's
AnimateLinkBase is roomrom_combat_end_move_and_animate(), run after movement
(also on the scroll-start frame) and on the NES-counted scroll frames. Removed
all one-frame compensations (link_step_after_wield, immediate weapon updates in
try_swing / wield_rod / arrow / boomerang, wield-frame pose redraw).

Suite (tools/lockstep presets, per-frame, same frame index, GameMode 5 frames):
Link X/Y/Dir/ObjState/AnimCounter/AnimFrame/GridOffset equal to NES in 25 of 29
presets (before: every moving preset diverged from f31 on Dir/AnimCounter).
Remaining: Link Y from enemy-contact knockback in hud_marker/ow_walk/t050_wall/
t050_rock_push (enemy RNG phase, counts unchanged by this task) and t114 dungeon
entry staging (pre-existing route divergence).
Weapons: all t116_* and arrow/boomerang presets 0 slot diffs, t116_shot_hit
GridOffset now equal (Walker_Move [0E] reset).
Scroll: Link anim during OW scroll follows the NES per-submode counts
(t105_*), one frame early after the accepted faster Genesis scroll.
Sprites: walk frame-toggle frame, scroll, wield frames PASS (verify_sprites).
Lag total GEN 103 / NES 110 (t114 36/37).
