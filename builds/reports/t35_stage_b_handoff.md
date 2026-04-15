# T35 Stage B — Handoff Note

Status: **stuck in plan phase after 2 failed hypotheses.** Per /whatnext
stop-rule, not attempting a third code-inspection pass; need live CPU
tracing to distinguish remaining branches.

## What Stage A proved

`builds/reports/bizhawk_t35_scroll_parity_report.txt` — 6/9 gates pass.
Three fail, all symptoms of one root cause:
- `T35_SCROLL_RAMP_PARITY` — Gen `CurHScroll` ($FF00FD) never decrements.
- `T35_FINAL_MODE` — Gen stuck at `mode=$07` (NES settles `mode=$05`).
- `T35_ROUND_TRIP_READY` — Link x diverges because scroll never commits.

## What Stage B probe proved

Added IsUpdatingMode ($11) + SecretColorCycle ($51A) + WhirlwindState
($522) to the Gen capture. Timeline at the stall:

| t | mode | sub | isupd | secret | whirl | dir | room | hsc |
|---|---|---|---|---|---|---|---|---|
| 175 | $07 | $02 | $00 | $00 | $00 | $02 | $77 | $00 |
| 176 | $07 | $03 | $00 | $00 | $00 | $02 | $77 | $00 |
| 177 | $07 | $04 | $00 | $00 | $00 | $02 | $77 | $00 |
| 178 | $07 | $04 | $00 | $00 | $00 | $02 | $77 | $00 |
| 179 | $07 | $05 | $00 | $00 | $00 | $02 | $77 | $00 |
| 180 | $07 | $05 | $00 | $00 | $00 | $02 | $77 | $00 |
| **181** | $07 | $00 | $01 | $00 | $00 | $02 | **$76** | $00 |
| 182+ | $07 | $00 | $01 | $00 | $00 | $02 | $76 | $00 |

**Critical new datum:** room ID flips $77→$76 at the exact frame
sub/isupd reset. So whatever ran at end-of-frame 181 committed the
new room AND reset the mode-7 sub/isupd state — i.e., the scroll
**actually completed** logically (CalcNextRoom committed). But
`hscroll` never ticks ($00 throughout), `mode` never advances to
$04, and Update phase loops Sub0 forever because
`UpdateMode7Scroll_Sub0` writes `CurHScroll=0` first thing and then
`Inc2Submodes` should bump sub to $02 — neither happens.

This rules out "Init path stuck" entirely. The Update path is being
called repeatedly with sub=0 dispatching `UpdateMode7Scroll_Sub0` at
[z_05.asm:1263](../../src/zelda_translated/z_05.asm:1263). For that
to leave sub=0 forever, either:
- `_m68k_tablejump` is mis-dispatching with D0=0 → wrong handler
- Sub0 returns via a path that bypasses both ScrollHorizontal and
  Inc2Submodes (e.g. ScrollUp branch taken erroneously)
- Some other writer sets sub=0 each frame after Sub0 finishes

At t=181 something writes `submode=0` + `isupd=1` while leaving `mode=7`.
**CORRECTION (post-handoff static review):** NES semantics at
`reference/aldonunez/Z_07.asm:520` are `LDA IsUpdatingMode; BNE @Update` —
isupd=1 BRANCHES to `@Update` → `JSR UpdateMode`. isupd=0 falls through
to `JSR InitializeGameOrMode`. Transpile at `z_07.asm:1634-1637` matches.

So with mode=7, isupd=1, sub=0 the frame dispatches:
`UpdateMode` → `UpdateMode7Scroll` → `UpdateMode7SubmodeAndDrawLink` →
`UpdateMode7ScrollSubmode` (table dispatch on sub) →
**`UpdateMode7Scroll_Sub0`** at `src/zelda_translated/z_05.asm:1263`.

For left scroll (dir bit 2 = 0), Sub0 calls `ScrollHorizontal` which
`jmp Inc2Submodes` → sub should become $02. Trace shows sub stays $00 —
either `Inc2Submodes` path not reached OR an explicit write resets sub=0
each frame. **Suspect surface is now `UpdateMode7Scroll_Sub0` dir-test
branch polarity / `ScrollHorizontal` / `Inc2Submodes`, NOT the Init path.**

## Hypotheses (ranked; both failed code-inspection)

**H1: `UpdateMode7Scroll_Sub7` runs but writes to wrong address.**
Transpile at [z_05.asm:1439](../../src/zelda_translated/z_05.asm:1439) is
byte-exact with reference — sets sub=1, isupd=0, mode=4. If Sub7 ran,
trace would show those values, not the observed sub=0/isupd=1/mode=7.
**Disproven** — observed values are opposite.

**H2: `InitMode7_Sub0` dispatches but `L1433A_IncSubmode` doesn't reach
($0013,A4).** Transpile looks correct; `_m68k_tablejump` at
[nes_io.asm:2325](../../src/nes_io.asm:2325) verified sound. A4 =
$FF0000 verified at [genesis_shell.asm:323](../../src/genesis_shell.asm:323).
**Cannot prove or disprove from inspection.**

## Who writes (submode=0, isupd=1) at t=181?

This is the unresolved question. Candidates to investigate with a CPU
trace breakpoint on **writes to $FF0011 taking value $01** in the frame
window around t=181 (absolute frame ≈ 802 based on T0=621):

- `ScrollLeft` room-change commit path in NES room-logic
- Mode7 "init" re-entry triggered by scroll ramp completion
- A Genesis-shell glue routine that I haven't located

## Build options (once cause known)

1. If a Gen-only glue path writes isupd=1 — remove that write.
2. If transpiled `UpdateMode7Scroll_Sub7` is reached but A4 got
   clobbered by a prior call — find the clobbering routine.
3. If the transpiler emitted a wrong branch polarity somewhere in
   Sub5/Sub6/Sub7 — fix transpile, regenerate, rebuild.

## Static inspection complete — verified byte-exact

Compared transpile vs NES reference for the full call chain at stall:
- `UpdateMode7ScrollSubmode` dispatch (z_05.asm:1248) ✓
- `UpdateMode7Scroll_Sub0` dir tests (z_05.asm:1263) ✓
- `ScrollHorizontal` left path + level branches (z_05.asm:1294) ✓
- `Inc2Submodes` double-addq (z_05.asm:1288) ✓
- `UpdateMode7Scroll_Sub4And5_TransferNTAttrs` bottom-half (z_05.asm:1464) ✓
- `CueTransferPlayAreaAttrsHalfAndAdvanceSubmode` addq (z_05.asm:3111) ✓
- `UpdateMode7Scroll_Sub6` level + dark-room (z_05.asm:1417) ✓
- `UpdateMode7Scroll_Sub7` commit (z_05.asm:1439) ✓
- `_m68k_tablejump` pop/index/jump (nes_io.asm:2325) ✓
- `Link_EndMoveAndAnimateBetweenRooms` entry (z_07.asm:4889) ✓
- ISR Mode-7-detection (z_07.asm:1634) ✓

No direct writes to $FF0011/$FF0013 in nes_io.asm / genesis_shell.asm.

Exhausted by /whatnext stop-rule — no further static pass warranted.

## Live write-bp evidence (commit WIP) — `builds/reports/t35_writebp_gen.txt`

Ran `tools/run_t35_writebp_gen.bat`. Output captured writes to $FF0011 / $FF0013
across full boot + transition. T0 gate never fired (mode=5 room=$77 60-frame
stable check didn't trigger), so WINDOW heartbeat lines absent, but raw PC log
is complete. Key PCs correlated via `builds/whatif.lst`:

- `PC=0x00034888/0x0003488C` → `BeginUpdateMode` (z_01.asm:3708)
  writes `sub=0; addq.b #1,isupd` — byte-exact vs NES `INC IsUpdatingMode`.
- `PC=0x0005037A/0x0005037E` → `EndGameMode` — `isupd=0; sub=0`.
- `PC=0x00045194` → `_anon_z05_21` (InitMode7_Sub0 tail / `L1433A_IncSubmode`)
- `PC=0x000450DA` → InitMode7 sub-2 area
- `PC=0x0004620E` → `CueTransferPlayAreaAttrsHalfAndAdvanceSubmode` area

**None of BeginUpdateMode / EndGameMode is buggy — both byte-exact.**

## Real smoking gun — parity report diagnostics

`builds/reports/bizhawk_t35_scroll_parity_report.txt`:

```
DIAG sub_first_diff      t=176  nes=$02 gen=$03   ← Gen ahead by 1 submode
DIAG cur_col_first_diff  t=182  nes=$41 gen=$FF   ← column arg corrupted
DIAG hscroll_first_diff  t=184  nes=$FC gen=$00   ← scroll never ticks
DIAG mode_first_diff     t=250  nes=$04 gen=$07   ← Gen stuck in Mode 7
```

Gen submode **advances one extra time** around t=176. Prior hypotheses H1/H2
focused on Sub0/Sub7 transitions — this shifts suspect to the Sub2→Sub3 area.
`CurCol=$FF` at t=182 means scroll row/column init loaded a bad column index,
which makes subsequent hscroll writes target nowhere and scroll stalls.

## Resume plan (next session)

1. Narrow write-bp watch to window t=170..190 only (skip earlier boot
   chatter) by setting T0 manually in the probe based on known 618-frame
   bootflow length rather than the broken mode=5 gate.
2. Log writes to `$FF0013` (sub) AND `$FF003E` (CurCol) and `$FF0026`
   (scroll-related) simultaneously.
3. Identify which routine writes sub=$03 at or before t=176 that NES
   doesn't — that's the extra submode advance path.
4. Check `InitMode7_Sub2_TransferPlayAreaAttrsToNT1/NT2` and
   `CueTransferPlayAreaAttrsHalfAndAdvanceSubmode` at z_05.asm:3111 — the
   submode-+1 path that runs after transfer buffer flush.

## How to resume

1. Load `builds/whatif.md` in BizHawk. Replay `tools/bootflow_gen.txt`
   via `tools/run_t35_gen.bat` — rig halts naturally.
2. Enable CPU write breakpoint: write to $FF0011 with value $01.
3. Examine call stack at break. Note routine name from symbol map.
4. Same for write breakpoint $FF0013 with value $00 (submode clear).
5. Correlate the two writes — same routine? Different?

Once the culprit is identified, fix is likely 1–3 lines.

## Files

- Probe: [tools/bizhawk_t35_scroll_gen_capture.lua](../../tools/bizhawk_t35_scroll_gen_capture.lua)
- Capture data: [builds/reports/t35_scroll_gen_capture.json](t35_scroll_gen_capture.json)
- NES reference: [reference/aldonunez/Z_05.asm:1030](../../reference/aldonunez/Z_05.asm:1030)
- Transpile: [src/zelda_translated/z_05.asm:951](../../src/zelda_translated/z_05.asm:951)
