# T-011 Sword cave: pickup, lift, exit (user: "Link is invisible" after the first cave)

Presets: `t011_sword_cave` (enter, wait for the text, step right under the
sword, take it, walk out), `t011_exit_idle` (same, then stand still after
the step out), `t011_sword_swing_exit`.

## Found (NES capture first, tick-aligned lockstep)

1. **Invisible Link (user report).** The stairs behind-background effect
   raises the plane cells around the cave mouth to high priority. NES only
   sets Link's sprite priority bit while he walks in/out; Genesis never
   lowered the cells, so a Link standing at the mouth after StepOutside was
   hidden behind the ground (`t011_exit_idle` tick 1100: SAT has Link at
   ($40,$56), framebuffer shows no Link). `cave_fade_restore_arch()` lowers
   exactly the raised cells when StepOutside ends; load_room forgets them.
2. Cave halt timing: NES InitCave (object loop, first play tick) halts Link
   after that tick's UpdatePlayer moved him one pixel (Up held through the
   walk-in: NES rests at $D4). Genesis halted at the cave swap ($D5), so
   every later step ran a tick early and the first turn went the other way
   (Right tap moved 16 px instead of 8, sword missed). Deferred to the
   person's first update.
3. GameMode: NES caves run in mode $0B (stairs $10); Genesis reported $05,
   and TakeItem only lifts the item outside mode 5. Now $10 / $0B.
4. Item lift (NES CheckLiftItem / DrawLinkLiftingItem) was not ported:
   ItemLiftTimer $80, Link halted, lift pose $78/$79 + $08 (one hand for a
   half-width item), item 16 px above, raw ObjY (no OW +2). NES tiles $78/$79
   come from the extracted demo block (`data/chr/demo.c`, now linked); the
   SPR_BASE+$78 copy is under the scene-enemy overlay, so they get their own
   VRAM (1376-1377, unused in OW/cave/UW/boss snapshots).
5. Static transfer buffers $1E BlankTextBoxLines and $2A BlankPersonWares
   were dropped: the old man's text stayed after the sword was taken.
6. Exit trigger one tick early and one pixel too far (NES CheckCaveEdge runs
   before the move).

## Evidence (framebuffer vs NES, colour-mapped, 256x224)

`t011_sword_cave`: tick 502 0 px, 503 3 px, 520 (lift) 0 px, 640 0 px,
700 0 px (was 971-1151 px). Pickup tick, lift timer, halt, person hide
equal to NES every tick. Exit mode $0A on tick 806 both.
`t011_exit_idle`: Link visible after StepOutside (was hidden).
