# FS2-F Code Audit — Mode $0E Direction Handler Path

Audit target: Defect FS2-F in Phase 10 plan. Every D-pad press on the REGISTER YOUR NAME keyboard (GameMode $0E) stalls real Mega Drive hardware for a visible moment, then recovers. Does NOT reproduce in BizHawk/gpgx. A-press char-write and A-press grid-walk both work cleanly on both emulator and real hardware, so the bug is confined to code that the direction path reaches but the A-press path does not.

## 1. Direction handler call tree

Entry: `UpdateModeERegister` at z_02.asm:2146 → `ModeE_HandleDirections` at ~2417.

Direct jsr/bsr targets reachable from the per-direction handlers (Right/Left/Up/Down) and `_L_z02_ModeE_HandleDirectionButton_FinishInput`:

- `ResetButtonRepeatState` — z_02.asm:2424 — pure RAM state clear
- `CycleCharBoardCursorY` — z_02.asm:2580 — wrap/row recompute, pure RAM + table lookup, no jsr of its own
- `ModeE_SyncCharBoardCursorToIndex` — z_02.asm:2612 — **PATCH P13**, injected by `_patch_z02 P13b` in tools/transpile_6502.py

No calls into `src/nes_io.asm` from this path. No writes to VDP control ($C00004), joypad ports, Z80 bus, or SRAM mapper ports in any reachable leaf.

## 2. A-press call tree

Entry: `_L_z02_ModeE_HandleAOrB_CheckAB` at z_02.asm:2681 (fallthrough from `UpdateModeERegister`).

- Char-write block at 2705-2715 → `ModeE_CharMap` table lookup → direct store into `$0638+$0421`
- `ModeE_SetNameCursorSpriteX` — z_02.asm:2832 — updates sprite 0 X coord, pure RAM writes
- After handler returns, the generic `UpdateMode1Menu_Sub0` tail runs `UpdateModeEandF_Idle` (2881), `ModeEandF_WriteNameCursorSpritePosition` (2818), `ModeEandF_WriteCharBoardCursorSpritePosition` (2838), `ModifyFlashingCursorY` (2867). These run on BOTH A-press and direction frames so they are not the delta.

**Key delta**: the A-press path does NOT call `ModeE_SyncCharBoardCursorToIndex` (P13). P13 is only reached from the FinishInput fall-through of the direction handlers.

## 3. Suspects

### S1 (HIGH) — P13 row-division loop could be unbounded if $041F is corrupted

P13 body at z_02.asm:2612-2645 contains:
```
.p13_row_loop:
    cmpi.b  #11,D0
    bcs.s   .p13_row_done
    subi.b  #11,D0
    addq.b  #1,D1
    bra.s   .p13_row_loop
```
Bounded to at most 4 iterations for input 0..43. If $041F is corrupted to >43 or negative (bit 7 set), the upstream wrap logic should normalize it, but if the wrap logic itself bit-rots or the input is set after the wrap, the loop could iterate far longer. Emulator cost is negligible; real hardware cost on a 68K @ 7.6 MHz for hundreds of 3-instruction iterations plus the surrounding writebacks is user-visible.

Note: the pre-P13 wrap uses `addi.b #44` and `subi.b #44` — these are correct but the `btst #7,D0` check gates on the SIGNED interpretation of an 8-bit value, which `subx.b` output from the preceding Up/Down handlers (post-P19a/P19b) may produce with unexpected bit patterns.

### S2 (HIGH) — Real delta between direction and A paths is P13 itself

Before P13 was added, the direction handlers did not call any arithmetic normalization helper. P13 was introduced in Phase 9 to make the char-board cursor sync with `$041F`. The handlers were working on console before P13 (grid walk was possible even if visually off), so the regression surface is specifically whatever P13 added.

### S3 (MEDIUM) — Joypad polling timing (_ctrl_strobe, nes_io.asm)

`ReadInputs` in z_07.asm calls into `_ctrl_strobe` which does `move.b #$40,$A10003 ; nop ; nop ; move.b $A10003,D1`. The two nops may not be enough settling time for the Genesis TH pin protocol on real hardware. This is shared by BOTH paths (A-press also polls joypad), so it can't be the sole cause of "direction-only" stall, but it could interact with a direction-specific race.

### S4 (LOW) — Interrupt / stack race in P13 body

P13 saves/restores D0/D1 through A7 around the loop. If VBlank fires mid-loop and the NMI shadow code also uses A7, theoretically possible but the shell's NMI handler is well-tested and does not corrupt main-thread state.

## 4. Recommended action for 10.5-fix (Zelda27.81)

Revert P13 entirely. The direction handlers worked on console pre-P13 (the user's description of the bug — "D-pad freezes" — is a post-P13 regression; pre-P13 there was no reported freeze, only a separate alignment issue which is now being handled by P24/P26). Re-introducing a normalization helper can be done AFTER the freeze is eliminated, in a narrower form that only runs on wrap-transition frames instead of every frame.

Concrete revert: remove the `_patch_z02` P13a/P13b blocks from tools/transpile_6502.py (or bypass them with an early `return`). Rebuild, tag as 27.81, user re-flashes and reports whether the freeze is gone.

If the freeze persists after P13 revert: the cause is NOT P13 and we need to bisect further. Likely next candidates are P19a/P19b SEC;SBC rewrites (revert those too) then the shell-side `_ctrl_strobe` timing (add more nops).

## 5. Evidence from BizHawk 10.1 FS2 probe

The probe walked the 4x11 grid without any stall. `$041F` advanced deterministically: R#1..R#11 stepped 00→0B wrapping to row 1, D#1 advanced to 16, etc. P13 output at every index matched expected formulas. No anomalous iteration counts visible (emulator cycle cost not measurable via `framecount()`).

This is consistent with "P13 is fine in gpgx, pathological on real hardware" — either due to 68K cycle cost or an edge-case input P13 can handle on emulator but not console.
