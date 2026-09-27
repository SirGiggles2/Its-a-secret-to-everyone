# T-135 Cave exit: NES mode $0A + step out; cave text row

## NES (captured per frame, `t134_cave_exit`)

Walking down to Y $DD: f540 mode $0A submode 0, f541 object sprites gone
(old man, fires, sword), f542 playfield black and Link gone, f546-f547 whole
screen off (LayoutRoom), black to f573, f574 mode 4: OW room shown without
Link, f575 Link at ($40,$5D) (InitMode_EnterRoom method 1: X =
LevelBlockAttrsA & $F0, Y = (LevelBlockAttrsF & 7) * 16 + $4D + $10 through
the $24 entrance), then StepOutside Y-1 every 4th frame to $4D, mode 5.

## Genesis before

Link walked back UP 16 px inside the cave (the cave_fade "ascend" mirror of
the entry), then a 13-frame freeze, then the OW at Y $63 with no step out.
Cave dialogue text drawn 8 px low (NT row r mapped to plane row r; the
Genesis frame is the NES frame without its top 8 lines, so r - 1).

## Fix

`LVL_CAVE_EXIT` (RoomRom/src/main.c): trigger tick = NES submode 0; object
sprites hidden on the next tick, Link a tick later; the playfield goes black
by parking the vertical scroll (VSync write) on plane rows 32-59 cleared
while off screen; the OW room loads behind it (hardware scroll held) with
its 16 columns computed in RAM during the black ticks
(`roomrom_ow_room_render_prepare`); reveal = one VSync scroll write; then
the T-132 StepOutside with the cave's recorded entrance tile. No
display-off: the HUD stays up (NES blanks it for 2 frames). Row fills use
long writes.

## Evidence (framebuffer vs NES, colour-mapped, whole 256x224 frame)

- f540 / f541: 49 px each (Link at the cave bottom, NES one-frame OAM
  latency while walking); was 1149 / 1079 px (text 8 px low, sprites).
- f542 black: 0 px.
- reveal gen f568 vs nes f574: 11 px (NES shows a stale piece of the old
  Link sprite over the trees for one frame; Genesis does not).
- step out gen f570 vs nes f576 (both Y $5C): 0 px.
- Genesis shows the OW 6 frames earlier than NES; its load (black screen,
  HUD up) spans f546-f551.

Suite `t135a`: lag GEN 188 / NES 369. Trace changes vs `t134a` start at
loads that got faster (f172 OW scroll, f1394 dungeon entry: long-word row
fills), timing only.
