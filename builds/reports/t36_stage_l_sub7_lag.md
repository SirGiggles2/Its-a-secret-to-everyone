# T36 Stage L — Sub=7 Handler 1-Frame Lag (Plan)

## Evidence

Parity gate fails at t=307 first-diff. From capture JSONs:

| Frame | NES sub | NES (x,y) | Gen sub | Gen (x,y) |
|-------|---------|-----------|---------|-----------|
| 305   | 6       | ($40,$5D) | 7       | ($40,$5D) |
| 306   | 7       | ($40,$5D) | 7       | ($40,$5D) |
| 307   | 8       | ($70,$DD) | 7       | ($40,$5D) |
| 308   | 8       | ($70,$DB) | 8       | ($70,$DB) |

Gen enters sub=7 same frame as NES (or possibly 1 earlier), but the
sub=7 handler **does not finish in one frame on Gen**. Sub advances
from 7 → 8 on t=308 for Gen, t=307 for NES.

Statewrite trace at `builds/reports/t36_cave_statewrite.txt`:

```
WR f=931 t=307 cavetype val=00 PC=$4FEAC mode=0B y=5D ...
WR f=931 t=307 cavetype val=6A PC=$4622E mode=0B y=5D ...
WR f=931 t=307 facedir  val=08 PC=$34A6A mode=0B y=DD ...
```

Gen's sub=7 work (cave spawn, Link teleport to ($70,$DD)) happens
at f=931. Sub increment happens on the NEXT frame's dispatch. So
Gen is spending frame 931 executing `InitModeB_EnterCave_Bank5`
to completion, then frame 932 dispatches sub=8.

NES does the same work at f=930 and dispatches sub=8 at f=931.

## Handler

`z_01.asm:3906 InitModeB_EnterCave_Bank5`:

```
  move.b  ($0013,A4),D0
  move.b  D0,-(A5)                       ; PHA submode
  jsr     InitMode_EnterRoom             ; 1st heavy call
  jsr     ResetInvObjState
  moveq   #112,D0
  move.b  D0,($0070,A4)                  ; Link x = $70
  move.b  #$DD,D0
  move.b  D0,($0084,A4)                  ; Link y = $DD
  moveq   #8,D0
  move.b  D0,($0098,A4)                  ; facedir = 8
  jsr     Link_EndMoveAndAnimate
  jsr     RunCrossRoomTasksAndBeginUpdateMode_PlayModesNoCellar  ; 2nd heavy
  move.b  (A5)+,D0                       ; PLA submode
  move.b  D0,($0013,A4)                  ; restore
  moveq   #0,D0
  move.b  D0,($0011,A4)
  addq.b  #1,($0013,A4)                  ; submode++
  moveq   #48,D0
  move.b  D0,($0394,A4)                  ; autowalk = 48
  moveq   #1,D0
  move.b  D0,($005A,A4)
  rts
```

No frame-split loops. Always runs to completion within one call.

## Hypothesis

The game loop calls `InitModeB` once per frame and `sub=7` advances
to 8 at end of handler execution. For Gen to need 2 frames in sub=7,
one of:

1. **The game loop is skipping dispatch on some frames on Gen.**
   Something in the VBlank ISR or main loop intermittently bails
   before reaching mode/sub dispatch. T8_NMI_CADENCE = 81.4%
   (pre-existing regression) is consistent with this — 18.6% of
   frames miss NMI entirely.
2. **Link_EndMoveAndAnimate or RunCrossRoomTasks… invokes a PPU
   wait-loop** that spins an extra frame on Gen due to PPU-bit-6
   toggle timing mismatch.
3. **$005C / $0015 / other one-shot gate** that's not cleared for
   this exact sub-state transition, so handler enters but exits
   early without incrementing `$0013` on first call.

## Why hypothesis (1) is most likely

Pre-existing T8 NMI cadence at 81.4% (228/280 frames) means
roughly 1 frame per 6 drops. If the cave-enter scenario just
happens to land a missed NMI on frame f=930 (mode $0B sub=7 should
have run), the handler doesn't execute that frame. Next frame
f=931 gets it. This would explain the 1-frame lag without any
cave-specific bug.

## Single-point fix

**Do not touch cave code.** Fix T8 NMI cadence first. If cadence
goes to 95%+, cave parity will likely auto-close 9/9.

T8 failure mode from `builds/reports/bizhawk_boot_probe.txt`:

```
first_nmi=f20  eligible=280  with_nmi=228  multi_nmi=0  rate=81.4%
```

NMI fires in 228 of 280 eligible frames. 52 missed NMIs in the
first 300 frames. Previous "NMI cadence fix" (commit `6c25a3c7`)
brought cadence from 2.5% → 97.8% by NOPping DriveAudio and
CopyCommonCodeToRam. Something landed since that re-introduced
load into the VBlank path.

## Scope change

T36 is blocked on T8 regression. T36 residual 1-frame lag is not
independently fixable — it's a symptom of the NMI drop rate.

Next actionable work:

1. `git log --oneline --since="commit 6c25a3c7" -- src/nes_io.asm src/genesis_shell.asm src/zelda_translated` to find what added CPU load.
2. Check `IsrNmi` (genesis_shell.asm) for new work items.
3. Check for MMC1 or bank-copy inserts in VBlank path.
4. Restore cadence to 95%+.

Not starting that in this session — hand off to next.
