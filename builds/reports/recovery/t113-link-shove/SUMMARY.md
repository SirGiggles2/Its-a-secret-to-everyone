# T-113 Link shove grid state — evidence

Lockstep `t110_fire` (Link hit by his own fire -> shove down, NES Obj_Shove).
Cells Link X $70, Y $84, ObjGridOffset $394, ObjPosFrac $3A8, ObjQSpeedFrac
$3BC, ShoveDir $C0, ShoveDistance $D3, frames 77-137: 540/540 equal to NES
(LTO build before the fix: 421/540; Link Y 79->81 vs NES 7A->7E).

Fix (RoomRom/src/main.c, Link movement): publish s_link_grid_offset to $394
before c_obj_shove(0) and read it back after (the end-of-tick publish used to
overwrite the shove's grid edits with the stale static); publish $3BC = $60.
Not covered here: CheckTileObjectsBlocking in Link movement (T-120).
