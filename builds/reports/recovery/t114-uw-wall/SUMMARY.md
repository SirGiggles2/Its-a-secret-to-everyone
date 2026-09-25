# T-114 UW bombable wall (L1 room $53) — evidence

Route (preset `t114_uw_wall`): $77 -> $78 -> $68 -> $58 -> $48 -> $38 -> $37,
enter L1, $73 -> north key door -> $63 -> $53; bomb at ($78,$5D) = NES north
hotspot. Both consoles reach $53 (stage logs).

Bugs found and fixed:
1. Door art drawn at plane row/col 0: `uw_render.c` single-tile writes
   (`write_tile_raw`, used by door patches) and the dark-room fill ignored
   the scroll slot the room was painted into. Now they use the live slot
   recorded by `roomrom_uw_room_render_fill_one_col_at` (identity after a
   full `fill_plane_a`). Before: Genesis opened the door logically
   (`s_cur_opened` $0F) but the plane kept the wall.
2. Door faces: Genesis patched 4 threshold tiles; NES LayOutDoors writes a
   12-tile face per door from 5 sets (open, locked, shutter, bombable wall,
   bombed hole). Ported (`door_state.c` layout_door) for room entry and every
   opening.
3. BG atlas: the UW (tile, sub-pal) collector walked rooms transposed
   (32 rows x 22 cols of a 22 x 32 blob), missing columns 22-31 (east doors
   drew blank). Fixed; door-face tiles force-included at every UW room's door
   cells (663 tiles; VRAM budget OK; freshness 8/8).
4. CurOpenedDoors ($EE) published (true doors only, as LayOutDoors keeps it).

Verification: `plane.txt` — room $53 after the blast, plane playfield
704/704 exact vs NES nametable (bombed hole N, open E/W/S frames).
$EE: NES $08, Genesis $08.

Known divergences (logged): NES opens the wall 8 frames after the state-4
check (TriggeredDoorCmd $06 sequence), Genesis on the check frame. Genesis
keys stay in `s_link_keys` (NES InvKeys $66E 1 -> 0, Genesis stays 1:
T-092 area, main.c). Genesis lag frames every other frame while the bomb is
out in this room (T-080).
