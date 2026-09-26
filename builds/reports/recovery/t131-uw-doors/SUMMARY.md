# T-128 / T-130 / T-131 UW collision, room item, doors and transitions

User reports (2026-09-26): "The collision underground is a little wonky
with unwalkable bricks. I can sort of walk on top of them." "The key sprite
is broken." "UW room transitions are a bit wrong and the way Link looks
when he goes through doors is wrong, especially doors on the east and west
side."

## Causes found (NES capture first, then Genesis, then diff)

1. **Every gameplay sprite drew 7 rows below NES** (OW and UW). The Genesis
   frame is the NES frame without its top 8 lines; BG and HUD sprites use
   that, gameplay sprites used NES OAM Y as the Genesis line. NES shows OAM
   Y at line Y+1, so Genesis Y must be OAM Y + 1 - 8 = OAM Y - 7 (the pause
   subscreen already used $79 = 128 - 7). Screenshot rows, same BG rows on
   both: NES Link rows 199-211, Genesis 206-218 (room $63), newgame OW
   89-101 vs 96-108. Link standing just above a brick overlapped the brick
   by 7 px: the "walk on top of bricks" look.
2. Link walkability used a Genesis walk cache; now NES
   GetCollidingTileMoving vs ObjectFirstUnwalkableTile ($34A) (T-128), and
   the OW warp coordinator uses NES CheckWarps alignment.
3. The Genesis doorway model (walk_model.c) had the horizontal doorway at
   Y $85 and N/S bounds 8 px off NES, so with NES tile collision Link
   stopped at the W door (x $10). Replaced by NES Link_FilterInput,
   Link_ModifyDirInDoorway, CheckDoorway, TouchDoor and CheckScreenEdge on
   NES RAM (src/game/dungeon/link_doorway.c).
4. UW room-to-room was a fixed 34-frame Genesis scroll with Link parked off
   screen and teleported. Now NES modes 6/7/4 (ow_scroll.c with the CurLevel
   rules): walk out of false/bombable walls, 2 px/frame horizontal and
   every-4th-frame vertical scrolling, InitMode7 Sub5/6 and InitMode4
   Sub2/3 dark fades, InitMode_EnterRoom @Method2 walk-in ($18/$28 px).
5. Link at E/W doors: NES ShowLinkSpritesBehindHorizontalDoors puts a Link
   half with X < $10 or >= $E9 behind the BG (visible only over colour 0,
   the black opening); Genesis drew Link over the wall bricks. Now Link is
   two 8x16 halves with the NES priority rule, and UW play columns 0-2 /
   29-31 are high-priority BG.
6. Link under N/S door frames: NES WriteBlankPrioritySprites keeps 8 blank
   sprites on the rows at Y $3D / $DD, so the 8-sprite line limit hides Link
   there. Genesis: X=0 sprite masking after an X!=0 lead sprite (SAT slots
   0-3).
7. Room item (key): drawn by the NES item writers (was a boomerang
   placeholder), and MoveAndDrawRoomItem: a like-like / stalfos / gibdo in
   slot 1 carries the item (room $74: key follows the stalfos).

## Evidence

Lockstep presets `t131_uw_doors` (L1 $73 -> W $72 -> E $73 -> E $74) and
`t131_uw_ndoor` ($73 -> N $63), `--snap` video snapshots + screenshots.

- Mode/submode/room sequence per frame vs NES: every transition starts on
  the NES frame (1737 W, 1758 N, 2217 E); Genesis finishes InitMode7 3
  frames earlier (NES LayOutRoom lag frames), scroll duration equal (H 128,
  V 89 frames), walk-in 13 frames both, Link X/Y path equal.
- SAT at snapshots: Link halves priority = NES OAM 18/19 behind bit
  (f1726: NES #18 x$0F a$60, #19 x$17 a$40 -> GEN s04 prio0, s05 prio1).
- Framebuffer, NES vs Genesis (colour-mapped, same rows/cols):
  - static Link after N walk-in (final frame, x112-143 y180-223): 0 px
  - N door band f1756 (Link 1 line visible): 2 px
  - W/E walk-in frames: Link hidden behind the wall bricks and visible in
    the opening on both; remaining 0-55 px per pair = the NES one-frame
    OAM-DMA display latency while Link moves.
- HUD B-item sprite (unchanged -7 rule): 0 px.

## Lag (Genesis vs NES lag frames, full suite t131e)

The HUD B-item code invalidated the gameplay sprite cache every frame (a
"safeguard" for the pause overlay), so every cached SAT write was re-sent;
now only on pause open/close. UW: t131_uw_doors 31 (NES 40), t131_uw_ndoor
31 (34), t128_uw_blocks 32 (40), t114_uw_wall 38 (37). OW presets
unchanged (+0/+1).

## Suite (t131e vs t131b)

Link cells: t050_rock_push, t050_pond_fairy, t123_slow_tiles now equal to
NES every frame; ow_walk equal 67 frames longer. OW room entry now runs
InitMode_EnterRoom at mode 4 submode 0 like NES (was at mode 5), so enemy
cells diverge at other frames (RNG phase, accepted).
