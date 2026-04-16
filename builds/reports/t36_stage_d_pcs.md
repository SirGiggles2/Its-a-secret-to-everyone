# T36 Stage D — PC Resolution of Cave-Interior State Writers

## Probe result (bus-write bp on $FF0098/$FF00AC/$FF000F, mode $0B only)

First mode-$0B hits after scroll-in (at Gen t=287..295):

```
t=287 objstate val=$00 PC=$00050172             — SetUpCommonCaveObjects(+$12)
t=288 facedir  val=$08 PC=$00034A0C             — InitModeB_EnterCave_Bank5(+$26)
t=289..293 movedir val=$08 PC=$00049796         — auto-walk-out-of-stair driver
t=294 movedir  val=$FF PC=$0005218E             — ???  (invalid-dir sentinel, starts here)
t=294 objstate val=$40 PC=$00032188             — SetUpCommonCaveObjects(+$28)
```

After t=294, movedir oscillates $00/$FF at PCs $5218E, $51EE4, $34950, and
**NO further writes to $0098 (facedir) appear** for remainder of walk_down.
NES capture shows facedir *does* update to $04 at t=646 when Down held.
→ conclusion: a writer that fires on NES during mode $0B input-processing
is skipped on Gen.

## PC→label resolution (via builds/whatif.lst)

| PC | Nearest label | Interpretation |
|----|---------------|----------------|
| $34A0C | `InitModeB_EnterCave_Bank5` (z_01.asm:3898) +$26 | line 3914: `move.b D0,($0098,A4)` with D0=8. **Correct** — spec says "facing up" on cave enter. |
| $32160 | `SetUpCommonCaveObjects` (z_01.asm:433) +$28 | writes objstate=$40. Needs source inspection. |
| $49796 | stair-descent auto-walker | writes movedir=$08 per frame while Link auto-steps out of stair. Stops at t=293 (Link reaches $D5). |
| $5218E, $51EE4, $34950 | post-init movedir writers | spam $00/$FF. Inside FormatStatusBarText region in lst — likely HUD-unrelated `_anon_z01_30` branch. |

## What this means

`InitModeB_EnterCave_Bank5` setting facedir=$08 is **correct behavior**
(both NES and Gen show facedir=$08 on cave entry). The bug is downstream:

- **Gen's Walker_Move during mode $0B does not write facedir from
  prev_held input**. No PC $0098-write fires after t=288 on Gen.
- On NES, once Down is pressed at t=646, facedir gets updated to $04.
  Something in the NES input path (likely the `jsr Walker_Move` →
  `Link_EndMoveAndAnimate` or related object-animation chain) writes
  facedir based on the direction derived from input.
- That writer chain is **either not reached** or **guarded-out** on
  Gen during mode $0B.

## Next investigation

Add a fourth bp target during the probe: **PC trace at `Walker_Move`
entry** (resolve via lst — likely near z_07.asm:4150). If Walker_Move
is called every frame on Gen during mode $0B but no $0098 write
happens, then one of its callees (MoveObject, Link_EndMoveAndAnimate,
or a facing-update helper) has a transpile bug that skips the write.

Alt diagnostic: add per-frame PC sampling at a fixed timepoint inside
the Link update (e.g. sample PC once per NMI from Gen side during
t=640..660) and see which branch Gen takes vs NES.

## Raw data

`builds/reports/t36_cave_statewrite.txt` (2405 lines of mode-$0B
state writes with PC+frame+value+y).
