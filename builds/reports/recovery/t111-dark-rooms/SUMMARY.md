# T-111 UW dark rooms by palette; T-126 OW mazes

## T-111
NES source: Z_05.asm IsDarkRoom_Bank5 (LevelBlockAttrsE bit 7),
InitMode7_Sub5/Sub6 (fade to black, cycle $40, before scrolling into a dark
room from a light or candle-lit one), InitMode4 Sub2/Sub3 (fade to light,
cycle $C0, entering a light room from an unlit dark one; CandleState reset
on entry), Z_04.asm UpdateCandle, Z_07.asm UpdateFire (standing fire in the
UW calls UpdateCandle) and UpdateMode5Play (BrighteningRoom replaces the play
update), Z_01.asm AnimateWorldFading (drained: world_animate_world_fading).
Genesis: src/game/dungeon/uw_dark.c (new), RoomRom/src/main.c hooks,
candle_fire.c. Removed: plane blanking (fill_plane_a_dark) for dark rooms,
persistent per-room lit table use, relight-on-button-press, Ganon room
plane reveal hack (the palette fade now reveals it, as on NES).

Lockstep tools/lockstep/presets/t111_dark_candle.json (OW route to L5
through the Lost Hills, L5 $76 -> dark $66, blue candle):
- FadeCycle $51C / BrighteningRoom $51E / CandleState $51F: candle
  brightening identical frame for frame (f4401 $C0 .. f4432 $C4, state 1->2).
  Fade to black before the scroll: same values and 10-frame cadence, starts
  30 frames earlier on Genesis (at scroll start instead of after the mode 7
  init submodes; faster transition, accepted).
- BG palette NES PALRAM vs Genesis CRAM PAL0 (same NES->CRAM LUT): 16/16 in
  the light room (f4100), the dark room (f4380: rows 2-3 $0F/$0F/$0F/$0A and
  all $0F) and after the candle (f4433).
- verify_plane f4433: playfield 704/704 tiles + sub-palettes exact.

## T-126 (found on the way)
The OW Lost Hills ($1B, Up x4) and Lost Woods ($61, U-L-D-L) mazes were not
run: Genesis scrolled straight to the next room. CalculateNextRoomForDoor ->
CheckMazes (drained world_check_mazes) now runs on every OW edge crossing.
Same preset: room sequence $1B loops three times, $0B on the fourth Up, both
consoles (NES f3240 / GEN f3241).
