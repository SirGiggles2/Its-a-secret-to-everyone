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
