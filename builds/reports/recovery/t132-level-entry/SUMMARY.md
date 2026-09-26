# T-132 Dungeon entry and exit, NES sequence

Genesis entered a level at once (Link placed mid-room at Y $85, player
control ~170 frames early) and walked out of the start room into a
non-existent room $83 below it.

NES source: Z_05.asm InitMode10 / UpdateMode10Stairs_Full (tile $24:
stairs sound, Y+1 every 4th frame to Y+$10, PutLinkBehindBackground),
Z_06/Z_07 modes 2 and 3 (InitMode3_Sub8: X $78, Y LevelInfo_StartY,
facing up), Z_01.asm UpdateWorldCurtainEffect (columns $10-k / $11+k,
ObjTimer 5), GoToNextModePlayLevelSong (mode 4 submode 0, InitMode_EnterRoom
walk-in). Exit: CalculateNextRoomForDoor (NextRoomId >= $80) ->
EndGameMode12 (CurLevel 0, mode 2, UndergroundExitType 2, Tune0 $80),
OW curtain, InitMode_EnterRoom method 1 (X = LevelBlockAttrsA & $F0,
Y = (LevelBlockAttrsF & 7) * 16 + $4D; entered through $24: start $10
lower, stairs sound, facing down), StepOutside (Y-1 every 4th frame).

## Evidence (lockstep t131_uw_doors f1300-1530, t132_uw_exit f1600-1800)

- Stairs descent f1300-1388: GameMode, X, Y, ObjAnimCounter, ObjAnimFrame,
  FrameCounter equal to NES every frame (1 FC cell at the load frame).
- Descent framebuffer f1330/1345/1360/1375/1386, Link + entrance region:
  0 differing px (Link hidden behind the ground, visible in the opening).
  Required fixing the Link-behind-BG stamp: it assumed an unscrolled
  32-row plane, so no cell was ever marked (caves too).
- Curtain: 16 steps, 5 frames apart, same columns; HUD during mode 3/4
  pixel-exact (no counts/hearts/map dot/B item until the NES draws them).
- Walk-in 13 frames, Y $DD -> $CD, same as NES. Genesis reaches play 15
  frames earlier (load 16 frames vs NES 31: faster load).
- Exit: OW curtain + step out (Y $8D -> $7D, 1 px / 4 frames) equal in
  shape; Genesis 9 frames earlier (skips NES mode 6/7 frames and loads
  faster).
