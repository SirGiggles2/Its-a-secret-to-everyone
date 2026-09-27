# T-125 Frame budget: no gameplay slowdown

User bar (2026-09-26): "There should be no slowdown. It should be better. We're
on the genesis." Faithful Zelda, but NES hardware limits (slowdown, load
freezes) are not spec.

## Probe

`RoomRom/src/main.c` roomrom_debug_tick writes, every tick, into the 6502
stack page (unused by the port, masked by the lockstep diff):
`$01FE` = frames the previous tick ran past its own (0 = fit), `$01FF` = VDP
V counter when it finished. Lag frame = FrameCounter `$15` unchanged between
consecutive trace frames (both platforms).

## Causes found and fixed

1. Busy OW room ($38, 6 octoroks, `t123_slow_tiles`): ticks of 10.6-11.5k
   68000 instructions, 3 lag frames (NES 0). Link drawn twice per frame,
   9-entry walkable scan per collision probe, byte-indexed timer countdown,
   40-iteration OAM hide loop, 10-step no-B-item search: all cut (same
   results). t123 lag 19 -> 16 (NES 16).
2. Gleeok ran at half speed (3 heads: 109 lag frames in 110, NES 0):
   - every Gleeok sprite was written to NES OAM (emitted by the boss-room
     OAM sweep) and to a Gleeok sub-cache (emitted again): each body / neck
     / head sprite was in the SAT twice. Sub-cache removed.
   - per-byte `(ptr),Y` pointer loads for the 18 neck bytes per neck, twice
     per neck per frame: pointers resolved once.
   - boss OAM sweep used the full translate functions per sprite; now the
     xlat tables (boss sub-pal 3 split applied in xlat_sat).
   - monster-vs-weapon checks force-inlined (call overhead x6 per part).
   - pad 2 read as 3-button (NES controller 2 has no extra buttons).
3. Dungeon entry load was a single 17-frame tick (NES 17): per-cell VDP
   addressing in the room clear and the curtain save. Row runs now: 9
   frames (screen black during it).
4. Pause open: 64x64 plane clear as long writes.

## Evidence

Full lockstep suite `t125d` (40 presets + `t129_enemy_sweep`), lag frames
GEN / NES:

- total 277 / 365 (before T-125: 320 / 333).
- `t123_slow_tiles` 16 / 16 (the 16 are room-scroll loads on both).
- `t129_enemy_sweep` (every object type staged): 21 / 32; gameplay (mode 5)
  lag 0 (was 210, all Gleeok). Remaining GEN lag is mode 2/4/7 loads only.
  Gleeok 1/2/3/4 necks: lag 0/0/0/0, latest tick end V line 124/159/191/222.
- dungeon entry load 17 -> 9 frames (NES 17).
- `t121_ring*` pause open 4 / 0, but NES builds the menu over MenuState 1..7
  before its scroll starts; Genesis starts the scroll 3 frames earlier.
- `t120_cave_person` 9 / 2 at the cave load: NOT hidden. NES blanks the
  playfield at mode $0B and shows the cave at once; Genesis kept the OW up and
  painted the cave over 9 visible frames (write_tile_at per cell). Fixed
  under T-134.

Render changes checked: curtain play area vs NES aligned by curtain step
(gen f1417/1427/1437 vs nes f1437/1447/1457, t129): 0 differing px each.
Boss xlat: s_xlat_tile holds translate_tile(t, 0) for boss tiles and
xlat_sat applies the only attrs-dependent branch (sub-pal 3, tile != $F3),
the same result as translate_tile(t, attrs). Gleeok SAT duplicates at
f8976: before 11 positions doubled (body 2x, necks 6x for 3 necks), after
only one per neck (3x/4x = overlapping neck segments).

Trace changes vs `t125a`: frames after a shortened load run earlier against
the frame-scripted inputs (t132: Link meets an enemy at f1854 the NES Link
doesn't); q2_ow differs only at harness frame 0.

Margin: Gleeok-4 ticks end by V line 222 of 224; heavier future scenes need
more headroom (tracked on T-125).
