# T-090 / T-092 — debug gate, NES new game, status-bar A/B boxes, item atlas

Debug gate (T-090): `g_debug_session` is set only by the title A+B+C / X+Y+Z
chord (src/debug/a4_probe_main.c) and cleared on the File Select path. Every
gameplay debug input in RoomRom/src/main.c (X teleport, Y move style, UW
shutter/door chords, C+Start cave toggles, Mode scene toggle, C map toggle,
Z item cycle, Z+Start quest toggle) and the wooden-sword seed require it.

New game (T-092): keys are NES InvKeys $66E (was a private 99), the B item is
derived from SelectedItemSlot $656, the sword swing requires Items $657
(NES WieldSword). Lockstep `newgame`: Items block $656-$67F byte-identical
to NES at the last frame.

Status bar: port of DrawStatusBarItemsAndEnsureItemSelected +
FindAndSelectOccupiedItemSlot (hud_runtime.c) and DrawItemBySlot tile/attr
(draw_dispatch.c draw_item_icon). `verify_sprites.py` (NES OAM vs Genesis SAT,
pixels + palette): no sword / sword 1 / 2 / 3 with wooden boomerang — all
sprites exact (5/5), NES empty boxes on new game reproduced.

Item atlas table: the hand-written NES-tile -> atlas-index table in
enemy_render.c had 42 of 76 entries pointing at other tiles (live NES CHR
comparison). Now generated from the manifest
(tools/atlas/gen_item_tile_atlas_idx.py, freshness-gated): 38 of 38 drawable
item tiles + $F3 pixel-identical to live NES CHR. Unverified: ring $76/$77
(atlas bytes = manifest; this OW capture's CHR $76 differs; needs a capture
with the ring on screen, T-121).

Link draw Y: NES draws Link ObjY+2 in the overworld and cellars
(Link_EndMoveAndAnimate @Animate); Genesis drew ObjY. OW captures now pair
Link at the same dy as every other gameplay sprite.

Regression: t050_tree / t050_wall PlayAreaTiles + plane 704/704, t110_fire
verify_weapon PASS, t110_bomb bomb slots and InvBombs equal per frame except
the known one-frame-late first press (T-102; the fixed --gen-lag 1 alignment
flags the second bomb, which now lands on the NES frame).
