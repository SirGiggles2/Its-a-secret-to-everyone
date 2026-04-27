# Native Intro Handoff — TBD Resolution

Resolves the 5 TBDs flagged in `2026-04-26-native-intro-main-rom-design.md`
before implementation begins on Tasks 8-10. All values verified against
NES disasm and translated source as of 2026-04-26.

Reference files consulted:
- `reference/aldonunez/Z_02.asm` — NES bank 2 (file-select, demo, menus)
- `reference/aldonunez/Z_07.asm` — NES fixed bank (RunGame, InitMode, UpdateMode)
- `reference/aldonunez/Variables.inc` — NES RAM symbol → address table
- `src/zelda_translated/z_02.asm` — Translated bank 2 (Genesis M68K)
- `src/zelda_translated/z_07.asm` — Translated fixed bank (Genesis M68K)
- `src/nes_io.asm` — PPU/IO shim implementations
- `src/genesis_shell.asm` — Boot entry, VBlankISR, register contract
- `src/frontend_runtime.c` — C-side Mode0 demo patches
- `src/intro_handoff.c` — Existing attract-loop-back handoff (Mode0 restore)

---

## 1. MODE_FILESELECT value

**Value:** `$01`

**Symbol used in NES source:** `UpdateMode1Menu`
(No explicit `Mode_FileSelect` constant. The file-select screen is
`GameMode = $01`, handled by `UpdateMode1Menu` in the update dispatch table.)

**NES RAM address for GameMode:** `$00FF0012`
(NES `$12`, translated offset `(GameMode,A4)` = `($0012,A4)`, absolute `$00FF0012`)

**Mode table evidence:**

`reference/aldonunez/Z_07.asm:1613-1629` — `UpdateMode_JumpTable` (0-indexed):
```
entry 0  → UpdateMode0Demo         ; attract/title loop
entry 1  → UpdateMode1Menu         ; FILE SELECT (this one)
entry 2  → UpdateMode2Load
...
entry $D → UpdateModeDSave         ; save-game prompt
entry $E → UpdateModeERegister     ; name-entry (new save)
entry $F → UpdateModeFElimination  ; delete-save
```

Mode `$01` = `UpdateMode1Menu` = the three-slot file-select listing screen
where the player picks a slot (or Register / Eliminate). This is the correct
entry point because the NES title Start-press path ends with:

`reference/aldonunez/Z_02.asm:317-320` — `UpdateMode0Demo_Sub2` end:
```asm
INC GameMode          ; $00 → $01 (file-select menu)
LDA #$00
STA IsUpdatingMode    ; = 0 (next NMI will init, not update)
STA GameSubmode       ; = 0
```

**Translated symbol references:**
- `src/zelda_translated/z_07.asm:50` — `GameMode equ $0012  ; NES RAM offset`
- `src/zelda_translated/z_07.asm:2484` — `move.b ($0012,A4),D0` in `InitMode` dispatch
- `src/zelda_translated/z_07.asm:1564` — `move.b ($0012,A4),D0` in `IsrNmi_CheckScroll`

---

## 2. RAM contract for file-select cold entry

The trampoline must seed every byte in this table. Values are derived from
the normal NES Mode0→Mode1 transition sequence in
`reference/aldonunez/Z_02.asm:197-320` and patches documented in
`src/zelda_translated/z_02.asm` and `src/frontend_runtime.c`.

| NES RAM offset | Genesis address | Symbol | Required value | Source |
|---|---|---|---|---|
| `$0011` | `$00FF0011` | `IsUpdatingMode` | `$00` | Z_02.asm:318 — Mode0→Mode1 sets this 0 so next NMI inits |
| `$0012` | `$00FF0012` | `GameMode` | `$01` | Z_02.asm:317 — `INC GameMode` from 0→1 |
| `$0013` | `$00FF0013` | `GameSubmode` | `$00` | Z_02.asm:320 — explicitly zeroed on Mode0→Mode1 |
| `$042B` | `$00FF042B` | `FrontendStartReleaseGate` | `$01` | `frontend_runtime.c:178` — set when Start pressed in Mode0; Mode1_Sub0 waits for Start release before accepting new press (z_02.asm:3284) |
| `$042C` | `$00FF042C` | `DemoPhase` | `$00` | Not read by Mode1; harmless; keep at 0 for clean state |
| `$042D` | `$00FF042D` | `DemoSubphase` | `$00` | Not read by Mode1; harmless; keep at 0 for clean state |
| `$083D` | `$00FF083D` | `VRamForceBlankGate` | `$01` | **Set to 1.** `frontend_runtime.c:176` sets it when Start is pressed. `_ppu_write_1` masks BG/sprite-enable bits while gate is held, protecting Mode1's VRAM streaming. Gate is released to 0 at end of InitMode1_Sub6 by `z_02.asm:3262` (`clr.b ($00FF083D).l`). The design spec erroneously listed `$00`; the correct value is `$01`. |
| `$0600` | `$00FF0600` | `SongRequest` | `$00` | `Z_02.asm:218-219` — Mode0_Sub0 sets SongRequest=0 before advancing; file-select runs in silence (see Section 4) |

### Additional bytes NOT required but should be clean

These bytes were mentioned in the old `intro_handoff.c` (attract-loop reset path)
but are not read during Mode1 init. The trampoline does NOT need to write them,
but a clean state is harmless:

- `$0528` (`SkippedDemo`) — only checked by `UpdateMode0Demo` (Mode0 update).
  Mode0 never runs after handoff to Mode1. No action needed.

### Translated symbol citations

- `src/zelda_translated/z_07.asm:49-51` — EQU definitions for offsets $0011/$0012/$0013
- `src/zelda_translated/z_02.asm:3283-3291` — `UpdateMode1Menu_Sub0` PATCH P12 logic
  (FrontendStartReleaseGate check and clear)
- `src/nes_io.asm:152` — `VRamForceBlankGate equ CHR_STATE_BASE+$1D ; $FF083D`
- `src/zelda_translated/z_02.asm:3261-3262` — `addq.b #1,($0011,A4)` +
  `clr.b ($00FF083D).l` at end of `InitMode1_Sub6` (sets IsUpdatingMode=1, releases gate)

---

## 3. translated_mainloop_reentry symbol

**Symbol:** `LoopForever`

**Location:** `src/zelda_translated/z_07.asm:1461`

```asm
LoopForever:
    jmp     LoopForever
```

### Why LoopForever is the right target

The Genesis port uses a VBlank-driven architecture. The main loop
(`LoopForever`) just spins; all real work happens in `VBlankISR` →
`IsrNmi`. After `vblank_mode = 1`, every VBlank fires `IsrNmi` which
does mode dispatch. The trampoline does not need to call `InitMode1`
directly — `IsrNmi` does it automatically on the first VBlank.

`IsrNmi` dispatch chain (`src/zelda_translated/z_07.asm:1653-1656`):
```asm
move.b  ($0011,A4),D0   ; IsUpdatingMode
bne     _L_z07_IsrNmi_Update
jsr     InitializeGameOrMode
jmp     _L_z07_IsrNmi_EnableNMI
```

With `IsUpdatingMode = 0` (as seeded by trampoline):
- **VBlank 1:** `InitializeGameOrMode` runs. Checks `$00F4` (`InitializedGame`).
  Since `RunGame` was never called (native intro owns boot), `$00F4 = 0`.
  Copies common code/data, sets `$00F4 = 1`. Returns. Mode init deferred to next VBlank.
- **VBlank 2:** `InitializeGameOrMode` again. `$00F4 = 1` → calls `InitMode`.
  `InitMode` dispatches on `GameMode = $01` → `InitMode1` → chain through
  submodes until `InitMode1_Sub6` sets `IsUpdatingMode = 1`.
- **VBlank 3+:** `IsUpdatingMode = 1` → `UpdateMode` → `UpdateMode1Menu`.

### Entry behavior

| Property | Value | Evidence |
|---|---|---|
| Expects A4 = `$00FF0000` | YES | `genesis_shell.asm:381` seed; `IsrNmi` reads `($00FF,A4)` immediately |
| Expects A5 = `$00FF0200` | YES | `genesis_shell.asm:382` seed; NES stack ABI |
| Expects D7 = `$FF` (or -1) | YES | `genesis_shell.asm:383` seed; 6502 SP shadow |
| First action | Spins until VBlank interrupts | `z_07.asm:1462` — `jmp LoopForever` |
| Loop semantics | NMI-driven; `IsrNmi` returns via `rts` each frame | `z_07.asm:1669` — `rts; RTI→RTS` |

**The trampoline MUST set A4, A5, D7 before jumping to LoopForever.**
`IsrNmi` uses all three from the first instruction.

### Alternative: direct call to InitializeGameOrMode

An alternative trampoline could `jsr InitializeGameOrMode` twice then
`jmp LoopForever`. This is NOT recommended — it bypasses the VBlank
timing window and would call `InitMode1_Sub0` … `InitMode1_Sub6` back-to-back
in a single frame outside of VBlank, causing VRAM writes at wrong timing.
`LoopForever` + VBlank-driven dispatch is the correct approach.

---

## 4. File-select song bitmap

**Value:** `$00` (no song — silence)

**Trampoline action:** `move.b #$00,($00FF0600).l`

### Evidence

The NES transition from title to file-select silences the music.
`reference/aldonunez/Z_02.asm:213-221` — `UpdateMode0Demo_Sub0` (Start pressed in demo):

```asm
AND #$10                ; test Start bit
STA TransferredDemoPatterns  ; store $10 (sentinel, not a song)
LDA #$00
STA SongRequest          ; ← silence: clear SongRequest
JSR SilenceAllSound
```

`SongRequest ($600)` is set to `$00` when Start is pressed. No subsequent
Mode1 handler writes a new song. `InitMode1_Sub1` through `InitMode1_Sub6`
contain no `STA SongRequest` calls
(`reference/aldonunez/Z_02.asm:2422-2586`).
`UpdateMode1Menu_Sub0` and `UpdateMode1Menu_Sub1`
(`reference/aldonunez/Z_02.asm:2601-2780`) also contain no SongRequest write.

**Conclusion:** The NES file-select screen runs in silence. The title song
(`$80`) plays during the attract loop and stops when Start is pressed.
No new song is requested when Mode1 starts.

The NES audio engine only changes songs when SongRequest is non-zero:
`reference/Disassembly by camthesaxman/bank0.asm:759-760`:
```asm
LDA musicRequest
BNE start_song
```

So writing `$00` to `$0600` keeps the music stopped (or lets it stay stopped
if it was already silenced by the native intro's song-stop before handoff).

### Song ID reference (for context)

| SongRequest bitmap | Meaning | Evidence |
|---|---|---|
| `$80` (bit 7) | Title / intro theme | Z_02.asm:464-465 `InitDemoSubphasePlayTitleSong` |
| `$00` | Silence / no change | Z_02.asm:219 Mode0_Sub0 on Start press |
| `$10` (bit 4) | Ending credits song | Z_02.asm:3286-3287 `UpdateMode13WinGame` |
| `$40` (bit 6) | Dungeon theme variant | camthesaxman/bank0.asm:799 |

---

## 5. _ppu_write_0 register clobbers

**Body:** `src/nes_io.asm:283-325`

### Register preservation analysis

| Register | Preserved? | Evidence |
|---|---|---|
| A4 | YES | Not pushed or written in either path |
| A5 | YES | Not pushed or written in either path |
| D7 | YES | Not pushed or written in either path |
| D0 | Modified | Input value, overwritten; caller should not assume it survives |
| D1 | Modified (fast path) | Used for EOR/btst scratch; not pushed in fast path |
| D0-D5, A0-A1 | Saved/restored (slow path only) | `movem.l D0-D5/A0-A1,-(SP)` / `movem.l (SP)+,D0-D5/A0-A1` at `nes_io.asm:295,324` |

**A4, A5, and D7 are unconditionally preserved in both the fast and slow paths.**
The translated runtime register contract is safe across a `jsr _ppu_write_0` call.

### Path selection

```asm
_ppu_write_0:                          ; nes_io.asm:283
    move.b  (PPU_CTRL).l, D1           ; read current $00FF0804
    eor.b   D0, D1                     ; D1 = changed bits
    move.b  D0, (PPU_CTRL).l           ; store new value
    btst    #4, D1                     ; did BG pattern table bit change?
    bne.s   .ppuw0_pt_changed          ; yes → slow path (NT_CACHE rebuild)
    rts                                ; no → fast path exit here
.ppuw0_pt_changed:
    movem.l D0-D5/A0-A1, -(SP)        ; save scratch regs
    ; ... 960-tile Plane A rebuild ...
    movem.l (SP)+, D0-D5/A0-A1        ; restore
    rts
```

### Risk assessment for trampoline use

The trampoline writes `PPUCTRL | $80` (NMI enable). Bit 4 of PPUCTRL
controls BG pattern table selection (0 = PT0 at CHR $0000, 1 = PT1 at CHR $1000).

**Boot default:** `RunGame` (which the native intro bypasses) writes `$A0` to
PPUCTRL at `z_07.asm:1457-1458`:
```asm
ori.b  #$A0, D0   ; D0 was 0 → D0 = $A0 ($80=NMI enable, $20=VRAM incr +32)
jsr    _ppu_write_0
```

Since native intro owns boot and `RunGame` is never called, `PPU_CTRL` at
`$00FF0804` holds whatever the last `_ppu_write_0` call set it to. During the
native intro, the C code accesses VDP directly and never calls `_ppu_write_0`,
so `PPU_CTRL` retains the value written by the last translated frame before
boot (which is cold boot → `genesis_shell.asm` zeros all RAM at `$FF0000..`)
→ `PPU_CTRL = $00` after RAM zero.

**Trampoline write:** `ori.b #$80, D0` where D0 = current PPU_CTRL = `$00`.
Result: D0 = `$80`. `eor.b $80, $00` → D1 = `$80`, bit 4 of D1 = 0 (bit 4
unchanged). **Fast path taken. NT_CACHE rebuild does NOT run.** Safe.

**Edge case:** if the native intro had ever written a nonzero value to
`PPU_CTRL` via `_ppu_write_0`, and bit 4 was set, the slow path would run
on the trampoline's first NMI-enable write. The NT_CACHE rebuild is correct
behavior (not harmful — just slower). A4/A5/D7 are still preserved.

### Alternative direct-write (bypasses `_ppu_write_0` entirely)

If the trampoline wants to avoid any risk of triggering the NT_CACHE rebuild
(e.g. if boot state is uncertain), it can write both mirrors directly:

```asm
; Alternative: bypass _ppu_write_0 by writing both mirrors directly.
; Sets NMI enable (bit 7). Does NOT trigger NT_CACHE rebuild.
move.b  ($00FF,A4), D0
ori.b   #$80, D0
move.b  D0, ($00FF,A4)        ; gameplay mirror (NES RAM $00FF shadow)
move.b  D0, ($00FF0804).l     ; PPU_CTRL absolute mirror
```

This bypasses the NT_CACHE consistency check entirely. The tradeoff is that
if the BG pattern table bit 4 is genuinely different between the native
intro and what the file-select code expects, the NT_CACHE will be stale and
tiles will render wrong until the first `InitMode1` sub-phase triggers a
refresh through normal VRAM streaming. For a cold boot from native intro
(PPU_CTRL = 0 → bit 4 = 0 = PT0), the file-select code expects PT0
(bit 4 = 0), so no rebuild is needed. Either approach is safe here.

---

## Trampoline pseudo-code (consolidated for Task 9)

```asm
;==============================================================================
; intro_to_file_select_trampoline
;
; Called from C (intro_main / intro_handoff) when Start is pressed.
; Caller (C code) is responsible for:
;   - Turning off VDP display (vdp_display_off)
;   - Clearing plane A and plane B nametables
;   - Setting V64 scroll mode (vdp_set_mode_v64)
;   - Setting vertical scroll to 0
;
; This trampoline is ASM-only:
;   1. Restore translated runtime register contract
;   2. Seed file-select entry RAM contract
;   3. Re-enable translated NMI heartbeat
;   4. Flip VBlankISR to transpiled path
;   5. Jump into LoopForever — first VBlank will init Mode1
;
; After this call, the native C intro NEVER returns.
;==============================================================================
intro_to_file_select_trampoline:
    ; [1] Restore translated runtime register contract.
    ;     Must be done before any NMI fires with vblank_mode=1.
    move.l  #$00FF0000, A4           ; NES_RAM_BASE
    move.l  #$00FF0200, A5           ; NES_STACK_INIT
    moveq   #-1, D7                  ; D7 = $FF (6502 SP shadow)

    ; [2] Seed file-select entry RAM contract.
    move.b  #$00, ($0011,A4)         ; IsUpdatingMode = 0 (init mode on next NMI)
    move.b  #$01, ($0012,A4)         ; GameMode = $01 (MODE_FILESELECT)
    move.b  #$00, ($0013,A4)         ; GameSubmode = 0
    move.b  #$01, ($00FF042B).l      ; FrontendStartReleaseGate = 1 (start consumed)
    move.b  #$01, ($00FF083D).l      ; VRamForceBlankGate = 1 (hold blank during init)
    move.b  #$00, ($00FF0600).l      ; SongRequest = 0 (silence; file-select has no music)

    ; [3] Re-enable translated NMI heartbeat (PPU_CTRL bit 7 = NMI enable).
    ;     Boot default: PPU_CTRL = 0. OR in $80 → fast path in _ppu_write_0
    ;     (no NT_CACHE rebuild since bit 4 unchanged from 0).
    move.b  ($00FF, A4), D0          ; read current PPU_CTRL shadow ($00FF)
    ori.b   #$80, D0                 ; set NMI enable bit
    jsr     _ppu_write_0             ; stores to $00FF0804 and ($00FF,A4)

    ; [4] Flip VBlankISR dispatcher to transpiled path.
    ;     From this point on, every VBlank fires IsrNmi.
    ;     IMPORTANT: A4/A5/D7 must be valid BEFORE this write.
    move.b  #1, (vblank_mode).l      ; $00FF0FFC: 0=native, 1=transpiled

    ; [5] Spin in LoopForever. VBlank will call IsrNmi which dispatches:
    ;     - VBlank 1: InitializeGameOrMode copies common code ($00F4=0→1)
    ;     - VBlank 2: InitMode dispatches GameMode=$01 → InitMode1 chain
    ;     - VBlank 3+: UpdateMode1Menu (file-select interactive)
    jmp     LoopForever
```

### Address reference summary

| Symbol | Genesis address | Offset form |
|---|---|---|
| `IsUpdatingMode` | `$00FF0011` | `($0011,A4)` |
| `GameMode` | `$00FF0012` | `($0012,A4)` |
| `GameSubmode` | `$00FF0013` | `($0013,A4)` |
| `FrontendStartReleaseGate` | `$00FF042B` | `($00FF042B).l` |
| `VRamForceBlankGate` | `$00FF083D` | `($00FF083D).l` or `(VRamForceBlankGate).l` |
| `SongRequest` | `$00FF0600` | `($0600,A4)` or `($00FF0600).l` |
| `PPU_CTRL` shadow (`$00FF`) | `$00FF00FF` | `($00FF,A4)` |
| `PPU_CTRL` absolute | `$00FF0804` | `(PPU_CTRL).l` |
| `vblank_mode` | `$00FF0FFC` | `(vblank_mode).l` |
| `LoopForever` | in `z_07.asm` text segment | label ref |

---

## Open questions / residual unknowns

### OQ-1: `InitializedGame` ($00F4) first-VBlank double-dispatch

When the trampoline hands off, `$00F4 = 0` because `RunGame` was never called.
On the first VBlank with `vblank_mode=1`, `InitializeGameOrMode` runs:
- Call 1: copies common code/data, sets `$00F4 = 1`, returns WITHOUT calling InitMode
- Call 2 (next VBlank): calls `InitMode` → `InitMode1`

This means there is a 1-frame delay between the trampoline executing and
Mode1 actually initializing. During that frame, the display is VDP-blanked
(because `VRamForceBlankGate=1` blocks `_ppu_write_1` from enabling the display).
This is benign — the user sees a black frame between the native intro and
the file-select appearing. No visual artifact.

**Task 9 action item:** Verify that `CopyCommonCodeToRam` and `CopyCommonDataToRam`
(called by `InitializeGameOrMode` on first VBlank) do not corrupt A4/A5/D7.
These are bank-switching routines in `z_07.asm` — they use their own scratch
registers but should respect the NES register contract. Spot-check
`src/zelda_translated/z_07.asm` around the `CopyCommonCodeToRam` label.

### OQ-2: `DemoPhase` / `DemoSubphase` ($042C / $042D) on Mode1 entry

These two bytes are only read by `UpdateMode0Demo` (Mode0). Since Mode0 never
runs after handoff, their values don't matter. The trampoline does NOT need
to write them. Leaving them at 0 (which they will be after RAM zero at boot)
is correct.

### OQ-3: `SkippedDemo` ($0528) interaction

`SkippedDemo` is only checked by `UpdateMode0Demo` at
`reference/aldonunez/Z_02.asm:200`. Mode1 and its submodes have no reference
to this address. No action needed in the trampoline.

### OQ-4: NES name data / `Names` ($638) population before Mode1

Mode1 display includes the saved-file names. `Names` at `$638` is populated
by `UpdateMode0Demo_Sub2` (`reference/aldonunez/Z_02.asm:310-316`) which copies
from save file A during the Mode0→Mode1 transition. The trampoline bypasses
this copy.

**Risk:** If the native intro is reached on a cold boot (first power-on),
`Names` at `$00FF0638` will be all zeros. Mode1's `InitMode1_FillAndTransferSlotTiles`
will render blank name tiles. This may appear as three empty-name slots.

**Mitigations (in priority order):**
1. `_sram_load_save_slots` runs before `intro_main` (`genesis_shell.asm:432`),
   so save file A data is in `$00FF6000+` before the intro starts.
2. `InitMode1_Sub6` at `reference/aldonunez/Z_02.asm:2575-2582` finds the
   first active slot via `IsSaveSlotActive`. If all three slots are inactive
   (blank ROM), it loops forever. **This is an existing NES behavior** — the
   NES also requires at least one slot to be active by the time Mode1_Sub6 runs.
3. The normal Mode0 flow runs `UpdateMode0Demo_Sub1` (which verifies/formats
   save files) and `UpdateMode0Demo_Sub2` (which copies names) before Mode1.
   The trampoline skips both. **Task 9 should decide:** either replicate the
   Sub2 name-copy in the trampoline, OR rely on the C-side `frontdemo_update_mode0_demo_sub2`
   having been called as part of the normal game-tick path before Start was pressed.
4. If the native intro exits Start only after the attract loop has spun at
   least once (which includes `frontdemo_update_mode0_demo_sub2` running),
   `Names` will already be populated.

**Recommendation for Task 9:** The attract-loop path in the existing
`frontend_runtime.c` does call `frontdemo_update_mode0_demo_sub2` before
entering Mode1. If the native intro's attract-loop-back also triggers this
path (i.e., the first attract loop always runs before Start is accepted),
this issue does not arise. Confirm by checking `intro_handoff.c` and whether
it triggers the `c_update_mode0_demo_sub2` path before calling the trampoline.

---

*This spec unblocks Tasks 8-10. All 5 TBDs are resolved with concrete values
and citations. OQ-4 (Names population) is the only non-trivial residual
risk and has a clear mitigation path for Task 9.*
