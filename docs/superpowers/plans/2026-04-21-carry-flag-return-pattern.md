# Carry-Flag Return Pattern Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable C porting of functions whose callers read the carry flag directly after `jsr`, by encoding carry in bit 8 of the C return value and extracting it in the shim.

**Architecture:** C functions that need to communicate carry return `unsigned int` with bit 8 = carry. A new shim variant extracts bit 8 into CCR and applies `eori #$01,CCR` normalization. This unlocks 11 functions (16 call sites) across z_04/z_05 that are currently unportable.

**Tech Stack:** C (m68k-elf-gcc), M68K assembly (vasm), Python (transpiler stubs)

**Carry semantics rule:** The C function returns `CARRY_SET` matching the **raw M68K carry** state that the original instruction would produce BEFORE the `eori #$01,CCR` normalization. The shim extracts bit 8 into CCR, then applies `eori #$01,CCR` — reproducing the original function's full behavior. For M68K `cmpi.b #N,D0`: carry SET when D0 < N (borrow). For explicit `ori #$11,CCR` (SEC): always CARRY_SET. For `andi #$EE,CCR` (CLC): never CARRY_SET.

---

### Task 1: Add CARRY_SET macro to nes_abi.h

**Files:**
- Modify: `src/nes_abi.h:50` (before closing `#endif`)

- [ ] **Step 1: Add the macro**

In `src/nes_abi.h`, add before the closing `#endif`:

```c
#define CARRY_SET 0x100u
```

- [ ] **Step 2: Build to verify no breakage**

Run: `cmd.exe /c ".\build.bat --all --no-stubs"` via PowerShell from project root.
Expected: Build succeeds, same ROM size.

- [ ] **Step 3: Commit**

```bash
git add src/nes_abi.h
git commit -m "infra: add CARRY_SET macro for carry-flag return convention"
```

---

### Task 2: Port CopyNextRowToTransferBuf (z_05, carry-returning proof of concept)

Original ASM (6 instructions):
```asm
CopyNextRowToTransferBuf:
    jsr     CopyRowToTileBuf           ; already stubbed to C
    addq.b  #1,($00E9,A4)             ; row++
    move.b  ($00E9,A4),D0             ; D0 = row
    cmpi.b  #$16,D0                   ; M68K carry SET if D0 < $16
    eori    #$01,CCR                  ; invert carry
    rts
```

Callers check carry directly: `z_05:7647 bcs` (done → advance submode), `z_05:1720 bcc` (done → exit).

Per carry rule: `cmpi.b #$16,D0` sets M68K carry when D0 < $16. C returns `CARRY_SET` when row < $16.

**Files:**
- Modify: `src/gen/z_05.c`
- Modify: `src/c_shims.asm`
- Modify: `tools/transpile_6502.py`

- [ ] **Step 1: Write C function in z_05.c**

Add at the end of `src/gen/z_05.c`:

```c
unsigned int z05_copy_next_row_to_transfer_buf(void) {
    z05_copy_row_to_tilebuf();
    RAM(0x00E9)++;
    unsigned char row = RAM(0x00E9);
    unsigned int result = row;
    if (row < 0x16)
        result |= CARRY_SET;
    return result;
}
```

- [ ] **Step 2: Add carry-returning shim to c_shims.asm**

Add `xdef c_copy_next_row_to_transfer_buf` to the xdef block.
Add `xref z05_copy_next_row_to_transfer_buf` to the xref block.

Add shim body at end of file (start new section for carry shims):

```asm
;==============================================================================
; EXPORT side — carry-returning shims.
; These extract bit 8 of D0 into CCR, then apply eori #$01,CCR to
; reproduce the original function's carry normalization.
;==============================================================================

; CopyNextRowToTransferBuf — no args. Returns D0.b=row, carry in bit 8.
c_copy_next_row_to_transfer_buf:
    jsr     z05_copy_next_row_to_transfer_buf
    btst    #8,D0
    beq.s   .cc_cnr
    ori     #$01,CCR
    eori    #$01,CCR
    rts
.cc_cnr:
    andi    #$FE,CCR
    eori    #$01,CCR
    rts
```

- [ ] **Step 3: Add transpiler stub in _patch_z05()**

Add to `tools/transpile_6502.py` in `_patch_z05()`:

```python
    text = _stub_func(text, 'CopyNextRowToTransferBuf', 'c_copy_next_row_to_transfer_buf')
```

- [ ] **Step 4: Build and verify**

Run: `cmd.exe /c ".\build.bat --all --no-stubs"` via PowerShell.
Expected: Build succeeds. Output shows `_stub_func: CopyNextRowToTransferBuf -> c_copy_next_row_to_transfer_buf`.

- [ ] **Step 5: Boot test in BizHawk**

Copy ROM to `C:\tmp\whatif.md`. Launch BizHawk. Boot to title. Press Start. Walk Link to trigger room scroll (exercises CopyNextRowToTransferBuf). Verify scroll completes cleanly.

- [ ] **Step 6: Commit**

```bash
git add src/gen/z_05.c src/c_shims.asm tools/transpile_6502.py
git commit -m "carry-flag: port CopyNextRowToTransferBuf — first carry-returning C function"
```

---

### Task 3: Port CopyNextRowToTransferBufAndAdvanceSubmodeWhenDone (z_05, 3 instr)

Calls CopyNextRowToTransferBuf (Task 2) and propagates carry.

Original ASM:
```asm
CopyNextRowToTransferBufAndAdvanceSubmodeWhenDone:
    jsr     CopyNextRowToTransferBuf   ; carry = done?
    bcs  _anon_z05_150                 ; branch if done (after eori: C=1 = done)
    rts
_anon_z05_150:
    addq.b  #1,($0013,A4)             ; advance submode
    rts
```

Its own caller (`z_05:2962`) checks `bcc` directly afterward.

In C-calling-C: `z05_copy_next_row_to_transfer_buf()` returns CARRY_SET when row < $16 (not done, raw M68K carry). After the callee shim's `eori`, ASM caller sees C=0 (not done). But we're calling C-to-C, so we see raw CARRY_SET. The original `bcs` after `eori` branches when done (C=1 after eori = NOT CARRY_SET from C). So: NOT CARRY_SET from C = done.

**Files:**
- Modify: `src/gen/z_05.c`
- Modify: `src/c_shims.asm`
- Modify: `tools/transpile_6502.py`

- [ ] **Step 1: Write C function**

Add to `src/gen/z_05.c`:

```c
extern unsigned int z05_copy_next_row_to_transfer_buf(void);

unsigned int z05_copy_next_row_advance_submode(void) {
    unsigned int result = z05_copy_next_row_to_transfer_buf();
    if (!(result & CARRY_SET)) {
        RAM(0x0013)++;
    }
    return result;
}
```

The carry propagates unchanged — same "done" flag passes through.

- [ ] **Step 2: Add shim**

Add `xdef c_copy_next_row_advance_submode` and `xref z05_copy_next_row_advance_submode`.

```asm
; CopyNextRowToTransferBufAndAdvanceSubmodeWhenDone — no args. Carry-returning.
c_copy_next_row_advance_submode:
    jsr     z05_copy_next_row_advance_submode
    btst    #8,D0
    beq.s   .cc_cnras
    ori     #$01,CCR
    eori    #$01,CCR
    rts
.cc_cnras:
    andi    #$FE,CCR
    eori    #$01,CCR
    rts
```

- [ ] **Step 3: Add transpiler stub**

```python
    text = _stub_func(text, 'CopyNextRowToTransferBufAndAdvanceSubmodeWhenDone', 'c_copy_next_row_advance_submode')
```

- [ ] **Step 4: Build and verify**

Expected: Build succeeds. Two new stubs.

- [ ] **Step 5: Commit**

```bash
git add src/gen/z_05.c src/c_shims.asm tools/transpile_6502.py
git commit -m "carry-flag: port CopyNextRowToTransferBufAndAdvanceSubmodeWhenDone"
```

---

### Task 4: Port IsQuestSecretMismatch (z_04, 22 instr, no external calls)

Pure logic — reads RAM, looks up 3-byte table, compares quest numbers. Returns carry SET (SEC) on mismatch, carry CLEAR (CLC) on match.

Original ASM:
```asm
IsQuestSecretMismatch:
    move.b  ($04CD,A4),D0
    lsr.b x6                          ; extract bits 6-7 → 0-1
    beq  ReturnFalse                  ; 0 = no secret → CLC, rts
    ; table lookup
    lea  SecretQuestNumbers,A0
    move.b (A0,D3.W),D0              ; quest number for secret type
    ; compare with save slot quest
    lea  ($062D,A4),A0
    move.b (A0,[slot].W),D1
    cmp.b  D1,D0
    beq  ReturnFalse                  ; match → CLC, rts
    ori  #$11,CCR                     ; SEC → mismatch
    rts
ReturnFalse:
    andi #$EE,CCR                     ; CLC
    rts
```

SEC = raw M68K carry SET → C returns `CARRY_SET`.
CLC = raw M68K carry CLEAR → C returns `0`.

**Files:**
- Modify: `src/gen/z_04.c`
- Modify: `src/c_shims.asm`
- Modify: `tools/transpile_6502.py`

- [ ] **Step 1: Write C function**

Add to `src/gen/z_04.c`:

```c
static const unsigned char SecretQuestNumbers[] = { 0x00, 0x00, 0x01 };

unsigned int z04_is_quest_secret_mismatch(void) {
    unsigned char val = RAM(0x04CD) >> 6;
    if (val == 0)
        return 0;
    unsigned char quest_for_secret = SecretQuestNumbers[val];
    unsigned char slot = RAM(0x0016);
    unsigned char save_quest = RAM(0x062D + slot);
    if (quest_for_secret == save_quest)
        return 0;
    return CARRY_SET;
}
```

- [ ] **Step 2: Add carry-returning shim**

Add `xdef c_is_quest_secret_mismatch` and `xref z04_is_quest_secret_mismatch`.

```asm
; IsQuestSecretMismatch — no args. Returns carry in bit 8.
c_is_quest_secret_mismatch:
    jsr     z04_is_quest_secret_mismatch
    btst    #8,D0
    beq.s   .cc_iqsm
    ori     #$01,CCR
    eori    #$01,CCR
    rts
.cc_iqsm:
    andi    #$FE,CCR
    eori    #$01,CCR
    rts
```

- [ ] **Step 3: Add transpiler stub in _patch_z04()**

```python
    text = _stub_func(text, 'IsQuestSecretMismatch', 'c_is_quest_secret_mismatch')
```

- [ ] **Step 4: Build and verify**

Expected: Build succeeds.

- [ ] **Step 5: Commit**

```bash
git add src/gen/z_04.c src/c_shims.asm tools/transpile_6502.py
git commit -m "carry-flag: port IsQuestSecretMismatch (3 call sites in z_04)"
```

---

### Task 5: Port IsDistanceSafeToSpawn (z_05, 22 instr)

Computes X and Y distance to Link using Abs (already in C), returns carry.

Original ASM: subtracts positions, calls Abs, compares with $22. If both axes < $22, jumps to `ReturnUnsafeToSpawn` (SEC). Otherwise CLC.

Per carry rule: SEC = CARRY_SET. CLC = 0.

**Files:**
- Modify: `src/gen/z_05.c`
- Modify: `src/c_shims.asm`
- Modify: `tools/transpile_6502.py`

- [ ] **Step 1: Write C function**

Add to `src/gen/z_05.c`:

```c
extern unsigned char z01_abs(unsigned int val);

unsigned int z05_is_distance_safe_to_spawn(unsigned int slot) {
    unsigned char link_x = RAM(0x0070);
    unsigned char obj_x = RAM(0x0070 + slot);
    unsigned char dx = z01_abs((unsigned char)(link_x - obj_x));
    if (dx < 0x22) {
        unsigned char link_y = RAM(0x0084);
        unsigned char obj_y = RAM(0x0084 + slot);
        unsigned char dy = z01_abs((unsigned char)(link_y - obj_y));
        if (dy < 0x22)
            return CARRY_SET;
    }
    return 0;
}
```

- [ ] **Step 2: Add carry-returning shim**

Add `xdef c_is_distance_safe_to_spawn` and `xref z05_is_distance_safe_to_spawn`.

```asm
; IsDistanceSafeToSpawn — D2=slot. Returns carry in bit 8.
c_is_distance_safe_to_spawn:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z05_is_distance_safe_to_spawn
    addq.l  #4,SP
    btst    #8,D0
    beq.s   .cc_idsts
    ori     #$01,CCR
    eori    #$01,CCR
    rts
.cc_idsts:
    andi    #$FE,CCR
    eori    #$01,CCR
    rts
```

- [ ] **Step 3: Add transpiler stub in _patch_z05()**

```python
    text = _stub_func(text, 'IsDistanceSafeToSpawn', 'c_is_distance_safe_to_spawn')
```

- [ ] **Step 4: Build and verify**

Expected: Build succeeds.

- [ ] **Step 5: Commit**

```bash
git add src/gen/z_05.c src/c_shims.asm tools/transpile_6502.py
git commit -m "carry-flag: port IsDistanceSafeToSpawn (spawn distance check)"
```

---

### Task 6: Port Sub1FromInt16At4 (z_01, 11 instr, carry-returning)

Subtracts 1 from the 16-bit value at RAM[04:05]. Returns carry from the subtraction.

Original ASM: `SBC #$01` on RAM[$04], decrements RAM[$05] on borrow. The carry after SBC = no borrow (result >= 0 unsigned).

6502 `SBC` with SEC beforehand: carry CLEAR on borrow, SET on no borrow.
Transpiler emits the `eori #$10,CCR` pair around `subx` for the X flag, then the final `eori #$01,CCR` for normalization.

Raw M68K carry after `subx`: SET on borrow. After `eori #$10,CCR` pair: X flag restored to 6502 polarity. The final `eori #$01,CCR` is on the C bit.

After the subtract: M68K `bcc` = no borrow = value didn't underflow.
After `eori`: inverted. So caller's `bcc` = DID underflow (need to dec high byte). But wait, the `bcc` in the body (`bcc _anon_z01_62`) skips the `subq.b #1,($0005,A4)` — skip decrement when no borrow. That makes sense.

For the C model: return CARRY_SET when no underflow (value >= 1, so result byte didn't wrap). This matches the raw M68K carry from `subx` = SET on borrow. Wait — M68K subtraction sets C on borrow. So after `SBC #$01`: C=1 if result wrapped below 0, C=0 if no wrap.

The `eori` at the end inverts C. Callers of Sub1FromInt16At4 check carry after call. Let me check who calls it:

Actually, the callers who matter are those checking carry AFTER `jsr Sub1FromInt16At4`. Let me verify:

```
z_01:5164 Sub1FromInt16At4 — the function itself has eori + rts
```

But is Sub1FromInt16At4 in the direct-carry-caller list? Let me check... No, it wasn't in the list of 11 targets. Its callers may do `cmpi` after calling it. Let me skip it and stay focused on the 11 targets.

Actually, looking back at the analysis, `Sub1FromInt16At4` was listed as a carry-flag function in z_01 but NOT as a direct-carry-dependent target (no caller checks carry directly after calling it). Skip it for now.

Let me refocus on remaining targets from the 11: `Gel_MoveSplitting`, `PolsVoice_GetCollidingTile`, `PolsVoice_IsSquareWalkable`, `Wizzrobe_GetCollidableTile`, `IsSafeToSpawn`, `CheckSecretTrigger`, `InitSaveRam`.

`CheckSecretTrigger` uses `_m68k_tablejump` — not portable yet.
`InitSaveRam` is 40 instr — larger but doable.
`Gel_MoveSplitting` calls un-ported functions (`GetCollidingTileMoving`, `BoundByRoom`, `MoveObject`) — blocked.
`PolsVoice_GetCollidingTile` calls `GetCollidableTile` — blocked.
`PolsVoice_IsSquareWalkable` calls `PolsVoice_GetCollidingTile` — blocked.
`Wizzrobe_GetCollidableTile` is 3 instr but falls through into `GetCollidableTile` — blocked.
`IsSafeToSpawn` calls `GetCollidableTileStill` — blocked.

So the only remaining portables are: Tasks 2-5 above. The rest are blocked on un-ported tile collision functions.

Let me replace Task 6 with something productive: porting the remaining easy non-carry functions (tiers A+B+C from the brainstorming analysis) to maximize stub count alongside the carry work.

**Files:**
- Modify: `src/gen/z_05.c`
- Modify: `src/gen/z_01.c`
- Modify: `src/c_shims.asm`
- Modify: `tools/transpile_6502.py`

- [ ] **Step 1: Write C function for CompareHeartsToContainers (z_01, 13 instr)**

This has `eori` but callers do NOT check carry directly (they use `cmpi` after). It's a value-returning function that happens to normalize carry. Port as `unsigned char`.

Add to `src/gen/z_01.c`:

```c
unsigned char z01_compare_hearts_to_containers(void) {
    unsigned char hearts = RAM(0x066F);
    unsigned char filled = hearts & 0x0F;
    RAM(0x0000) = filled;
    unsigned char containers = hearts >> 4;
    return containers;
}
```

- [ ] **Step 2: Write C function for UpdateUnderworldPersonComplexState_Begin (z_01, 10 instr)**

Has `eori` but caller pattern shows no direct carry check. Port as `void`.

Add to `src/gen/z_01.c`:

```c
void z01_uw_person_complex_state_begin(void) {
    unsigned char obj = RAM(0x0350);
    if (obj == 0x4F)
        RAM(0x0014) = 108;
    RAM(0x0029) = 10;
    RAM(0x00AD)++;
}
```

- [ ] **Step 3: Add shims for both**

Add xdef/xref for `c_compare_hearts_to_containers` / `z01_compare_hearts_to_containers` and `c_uw_person_complex_state_begin` / `z01_uw_person_complex_state_begin`.

```asm
; CompareHeartsToContainers — no args. D0.b = containers count.
c_compare_hearts_to_containers:
    jsr     z01_compare_hearts_to_containers
    rts

; UpdateUnderworldPersonComplexState_Begin — no args.
c_uw_person_complex_state_begin:
    jsr     z01_uw_person_complex_state_begin
    rts
```

- [ ] **Step 4: Add transpiler stubs**

In `_patch_z01()`:
```python
    text = _stub_func(text, 'CompareHeartsToContainers', 'c_compare_hearts_to_containers')
    text = _stub_func(text, 'UpdateUnderworldPersonComplexState_Begin', 'c_uw_person_complex_state_begin')
```

- [ ] **Step 5: Build and verify**

Expected: Build succeeds. 2 new stubs.

- [ ] **Step 6: Commit**

```bash
git add src/gen/z_01.c src/c_shims.asm tools/transpile_6502.py
git commit -m "batch 35: port CompareHeartsToContainers, UWPersonComplexState_Begin to C"
```

---

### Task 7: Port batch of simple-branching and calls-to-stubbed functions

Drain remaining tiers A+B+C — functions identified in the brainstorming analysis that don't need carry-returning shims.

**Targets (15 functions):**

From z_01 calls-to-stubbed:
- `PlayBoomerangSfx` (7 instr, calls PlayEffect)
- `InitRupeeStash_Full` — 17 instr, complex but only calls InitOneSimpleObject. SKIP if fallthrough.
  
From z_02:
- `InitMode13_Sub3` (6 instr, calls SilenceAllSound)

From z_04 simple-branching:
- `Wallmaster_PutSpriteBehindBgIfNeeded` (small, branches on sprite attrs)
- `InitDodongo` (medium, calls into reset functions)

From z_04 calls-to-stubbed:
- `InitGleeokHead` (7 instr, calls InitBlueKeese)

From z_05:
- `CopyNextRowToTransferBuf` — done in Task 2
- `UpdateMode7Scroll_Sub6` (12 instr, calls IsDarkRoom_Bank5)

From z_07:
- `ClearRam0300UpTo` (simple loop)

**Files:**
- Modify: `src/gen/z_01.c`, `src/gen/z_02.c`, `src/gen/z_04.c`, `src/gen/z_05.c`, `src/gen/z_07.c`
- Modify: `src/c_shims.asm`
- Modify: `tools/transpile_6502.py`

- [ ] **Step 1: Read each target function's ASM body**

For each function, read the ASM body from the z_XX.asm file. Verify it's self-contained (no fallthrough, no un-ported dependencies).

- [ ] **Step 2: Write C functions**

Port each verified function to C following established patterns:
- `void` for functions where no caller reads D0
- `unsigned char` for functions where callers read D0 after jsr
- `unsigned int` for carry-returning functions (with CARRY_SET)

- [ ] **Step 3: Add shims**

One shim per function, matching the arg pattern (no-arg, D2=slot, D0=val, D0+D2, etc.)

- [ ] **Step 4: Add transpiler stubs**

One `_stub_func()` call per function in the appropriate `_patch_zXX()`.

- [ ] **Step 5: Build and boot test**

Expected: Build succeeds, 5-10 new stubs. Boot in BizHawk, verify title screen.

- [ ] **Step 6: Commit**

```bash
git add src/gen/*.c src/c_shims.asm tools/transpile_6502.py
git commit -m "batch 36: port remaining tier A+B+C functions to C"
```

---

### Task 8: Boot test full regression

**Files:**
- None modified — verification only

- [ ] **Step 1: Build final ROM**

Run build, note total stub count.

- [ ] **Step 2: Launch BizHawk**

Copy to `C:\tmp\whatif.md`, launch BizHawk.

- [ ] **Step 3: Test golden path**

1. Boot to title screen — verify title renders
2. Press Start — verify file select appears
3. Select save slot — verify game starts
4. Walk between rooms — verify scroll (exercises CopyNextRowToTransferBuf carry)
5. Pick up item — verify inventory works

- [ ] **Step 4: Record results**

Write results to `builds/reports/carry_flag_regression.txt`.

---

## Summary

| Task | Function(s) | Type | New stubs |
|------|------------|------|-----------|
| 1 | Infrastructure (CARRY_SET) | Macro | 0 |
| 2 | CopyNextRowToTransferBuf | Carry-returning | 1 |
| 3 | CopyNextRow...AdvanceSubmode | Carry-returning | 1 |
| 4 | IsQuestSecretMismatch | Carry-returning | 1 |
| 5 | IsDistanceSafeToSpawn | Carry-returning | 1 |
| 6 | CompareHearts, UWPersonBegin | Standard | 2 |
| 7 | Batch of tier A+B+C | Standard | 5-10 |
| 8 | Regression test | Verification | 0 |

**Expected total new stubs: ~11-16**, bringing total from 184 to ~195-200.

## Blocked functions (future work)

These carry-returning functions are blocked on un-ported dependencies:

| Function | Blocked by |
|----------|-----------|
| Gel_MoveSplitting | GetCollidingTileMoving, BoundByRoom, MoveObject |
| PolsVoice_GetCollidingTile | GetCollidableTile |
| PolsVoice_IsSquareWalkable | PolsVoice_GetCollidingTile |
| Wizzrobe_GetCollidableTile | GetCollidableTile (fallthrough) |
| IsSafeToSpawn | GetCollidableTileStill |
| CheckSecretTrigger | _m68k_tablejump (jump table) |
| InitSaveRam | 40 instr, no blockers — candidate for next batch |

Unblocking `GetCollidableTile` / `GetCollidableTileStill` / `GetCollidingTileMoving` would unlock 5 more carry functions and their callers. That should be the next structural target after this plan.
