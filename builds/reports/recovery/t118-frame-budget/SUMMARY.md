# T-118 frame budget — evidence

Metric: Genesis lag frames (FrameCounter $15 not advancing between per-frame
RAM dumps) vs NES on the same lockstep preset. Genesis f0 always shows one
stalled frame: the harness writes the NES FrameCounter into $15 at sync
(profile of f0-1: half idle, one tick per frame) — excluded below.
Bar (user 2026-09-25): Genesis lag <= NES; faster than NES is fine.

| preset | NES | start of T-118 | now |
|---|---|---|---|
| t114_uw_wall (L1, 5 Stalfos, key door, bomb wall, UW scrolls) | 37 | 89 | 36 |
| t105_scroll (OW scroll) | 2 | 3 | 2 |
| t110_bomb | 0 | 0 | 0 |
| whole 20-preset suite (pre-LTO base) | 92 | 185 (incl. f0) | see per-preset |

Changes (commits):
- c248e5cf HUD count/heart cells redrawn only when changed.
- 322b206c sprite emit translation tables (exhaustively checked: 0 of 262144
  tile/attr/state pairs differ).
- c9cc2631 lockstep --pc-profile (68K PC histogram) + pc_profile.py.
- 8251ccca -flto for C units (suite: traces identical where lag equal).
- 2140cf5c CHR upload through real VRAM DMA (dungeon entry 28 -> 17, NES 19).
- c87e6000 HUD kept across room changes.
- c8e094af UW room render streamed + table driven (30k vs 59k instr/room).
- 096a3b5e door command completion writes PlayAreaTiles only (NES LayOutDoors).

Byte checks on the way: verify_plane / verify_play_area 704/704 in t050_*,
t114 $63/$53; HUD window and CHR regions byte-identical to the previous
build where the run's inventory/scene matched.
