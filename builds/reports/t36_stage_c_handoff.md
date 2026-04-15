# T36 Stage C Handoff — Mode $0B Link-Move Broken on Gen

## Evidence (confirmed)

Inspected both captures frame-by-frame across walk_down (t=640..720):

| field | NES t=646..650 | Gen t=646..719 |
|-------|----------------|----------------|
| held | $04 one frame only | $04 one frame only (identical) |
| prev_held | sticks $04 | sticks $04 (identical) |
| obj_dir | $04 (Down) | $04 (Down) (identical) |
| obj_y | $D5→$D7→$D8→$DA→$DB→$DD | stays $D5 forever |
| obj_yf | stays $80 | stays $80 |

**Conclusion:** input routing is byte-identical on both sides. prev_held=$04
drives Link movement on NES. On Gen, Link-move routine for mode $0B never
advances y or yf. Pure mode-$0B handler bug.

## Scope

- Overworld (mode $05) walks fine — Gen reached stair at t=213 matching NES.
- Stair descent (mode $10), cave-interior-scroll arrival all match.
- Only mode $0B's Link-update path fails to translate prev_held → velocity.

## Update 2026-04-15: ObjState + MoveDir captured

Extended NES + Gen captures with `objstate=$00AC`, `movedir=$000F`,
`facedir=$0098` (commit after this handoff edit). Walk_down window
(t=600..720):

```
   t | NES objstate movedir facedir obj_y | GEN objstate movedir facedir obj_y
 600 | $00          $00      $08      $D5 | $40          $FF      $08      $D5
 646 | $00          $00      $04      $D7 | $40          $FF      $08      $D5
 647 | $00          $FF      $04      $D8 | $40          $01      $08      $D5
 650 | $00          $00      $04      $DD | $40          $01      $08      $D5
```

Key divergences, both persistent from cave-entry onward:
- **Gen objstate stuck at $40** while NES cycles $00/$01. High nibble $4
  ≠ $1/$2 so the Walker_Move item-state branch at z_07.asm:4231-4233
  does NOT fire; that's a different path than first hypothesized.
- **Gen movedir stuck at $FF** while NES varies $00/$01/$FF. $FF is an
  invalid direction sentinel — likely causing MoveObject to hit a
  default/no-op branch instead of the N/S/E/W step tables.
- **Gen facedir stays $08 (North)** while NES updates to $04 (South)
  when Down arrives at t=646. But obj_dir capture (at $03F8) showed
  $04 on both. So **$0098 (facedir) and $03F8 (ObjDir[slot]) have
  diverged on Gen** — these should track together.

Two distinct state-writer bugs converging on frozen Link. Next session
should:
1. Grep for `move.b .*,($0098,A4)` and `move.b .*,($00AC,A4)` in
   translated src — many matches (40+ for $00AC). Filter to those
   reached in mode-$0B flow: CheckSubroom + mode-$0B init + Walker_Move.
2. Set a BizHawk bus-write breakpoint on `$FF0098` value=$08 during
   cave interior to catch the PC writing stale North facing.
3. Likewise breakpoint `$FF00AC` value=$40 at cave-enter frame to find
   the bogus ObjState writer.

## Next step

Trace mode $0B's Link-movement dispatch in `src/zelda_translated/z_0?.asm`.
Candidates from grep: z_05.asm, z_06.asm, z_07.asm reference mode $0B /
mode-table dispatch. Find the routine that reads `$FC` (prev_held) during
mode $0B and updates `$0084` (obj_y) + `$00AC` (obj_yf). Likely a branch
polarity or operand-size transpile bug (same class as T35 sprite-0 stub).

Optionally: run a PC-capture probe around Gen t=646..660 to see which
routine executes. Model on `tools/bizhawk_t35_postscroll_probe.lua`
referenced in the prior plan.

## Gates status

6/9 PASS. Blockers:
- T36_CAVE_INTERIOR_MATCH (1px stair y drift at t=265 + no walk)
- T36_CAVE_EXIT_TRIGGERED (Gen never reaches exit coord)
- T36_ROUND_TRIP_READY (downstream of above)
