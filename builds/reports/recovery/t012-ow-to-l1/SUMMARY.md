# T-012 OW start -> Level 1 entrance (no staging) + T-137 fixes

Preset `tools/lockstep/presets/t012_route.json` (play clock): new file, start
room $77 -> walk to the sword cave (no teleport stage) -> sword -> $67 ->
$68 -> $58 -> $48 -> $38 -> $37 -> L1 door (tile $F3) -> room $73.
Route rooms picked with `tools/lockstep/ow_map.py`.

## Result (lockstep, NES vs Genesis, 2186 play ticks)

Link X/Y/dir, HP, room, GameMode, all live object slots (type, X, Y, dir),
FrameCounter and Random: **equal every tick** from the sync tick to the end
inside L1 room $73 (only stale-dir cells of the cave fires differ, ticks
63-79). Both lose the same half heart in $48.

## Root causes found (NES asm first, then Genesis)

1. Fast loads skipped the NES per-frame NMI work (FrameCounter, Random,
   timers). Genesis keeps the fast load and runs the missing NES frames' work
   at once: cave entry 29, leave cave 32, level load 12 (`nes_frames_catch_up`).
   Before: FC 20 behind after the first cave, octoroks turned the other way,
   Link died in $67.
2. Stairs: NES moves on `FrameCounter & 3 == 0`, not from the first frame,
   and not on InitMode10's own frame.
3. Cave walk-in: NES shows the floor frame in submode 8, then a settle frame
   with no object update. Step out: InitMode5Play takes its own frame.
4. Objects: NES leaves room objects, shots and dropped items uninitialized
   ($492 != 0) and runs InitObject on their first update; Genesis initialized
   at spawn (different Random) and used $492 inverted (1 = live). Now NES
   meaning everywhere; shots wait a frame like the NES; init table rows
   $5B/$5C/$5D fixed.
5. Edge-spawn rooms ($68): NES FindNextEdgeSpawnCell/InitMonsterFromEdge
   ported exactly (tile map < $84, distance test after, long timer);
   CurEdgeSpawnCell seeded $40 like NES ClearRam.
6. `_TryShooting` random-gate exit wrote the q-speed (NES does not): red
   fast octorok moved at $40 instead of $30.
7. InitLeever did not fall through into InitSlowOctorockOrGhini; red leever
   grid truncation wrote $470 instead of ObjGridOffset $394.
8. Link invincibility timer: NES decrements at UpdatePlayer start on
   FrameCounter parity (was Genesis tick parity, after collisions).
9. Stairs/cave trigger (warp coordinator) now runs right after Link moves and
   skips weapons/objects that tick, like NES UpdatePlayer's mode change.

Harness: tick clock counts a FrameCounter jump of N as N ticks (rows padded),
reviewed (5 findings, 4 fixed, 1 by design).
