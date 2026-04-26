# Native Intro in Main ROM — Design

**Status:** Draft, post Codex review pass 2.
**Branch:** `feat/intro-native-rewrite`.
**Predecessor specs:** `2026-04-24-intro-native-rewrite-design.md` (standalone proof), `2026-04-25-intro-title-screen-design.md`, `2026-04-25-intro-heart-flash-design.md`.

## Goal

Replace the transpiled (6502→M68K) intro sequence in the main ROM with a native M68K/C implementation. The transpiled intro currently crashes during the title→fade→story→item-scroll path. The standalone proof ROM at `tools/intro_demo/` runs title + fade + story successfully but has no item scroll and no Start handling. This design folds the proof into the main ROM, completes the loop, and adds Start handoff to the existing transpiled file-select path.

Native file-select is **out of scope** and tracked as a separate future spec.

## Decisions

Recorded from brainstorm:

| # | Decision |
|---|---|
| Q1 | Full native intro replaces transpiled intro in main ROM. |
| Q2 | Start press in any phase exits to file select. |
| Q3 | Native intro owns reset path. `genesis_shell.asm` calls `intro_main` instead of `IsrReset`. |
| Q4 | Native ASM dispatcher in `VBlankISR` selects native vs transpiled path via a RAM mode flag. No runtime vector patching. |
| Q5 | Full PHASE_SHOWCASE port (item scroll), NES-faithful. |
| Q6 | Promote `tools/intro_demo/*.c` sources to `src/intro_*.c`. Single source of truth. |
| Q7 | Verification = both RAM probes (fast CI gate) and golden-frame compare (visual regression). |

## Architecture

### Reset path

Native intro does **not** replace `IsrReset` wholesale. The pre-intro init block in `genesis_shell.asm:213-420` (VDP regs, RAM zero, SAT shadow clear, A4/A5/D7 seed, DynTileBuf sentinel, `_current_window_bank`/`LAST_GAMEMODE` seed, controller TH init, SRAM mapper enable, `_sram_load_save_slots`) keeps running. Only the final dispatch changes:

```
genesis_shell.asm:213-420   pre-intro init (unchanged)
genesis_shell.asm:NEW       move.b #0, vblank_mode      ; native path active
genesis_shell.asm:421       lower IPL (interrupts unmasked)
genesis_shell.asm:CHANGED   jsr intro_main              ; was: jsr IsrReset
```

`vblank_mode` is seeded in ASM **before** IPL is lowered. No race window where a VBlank could fire with `vblank_mode=1` while PPUCTRL is still clear (which would deadlock the transpiled wrapper waiting on PPUCTRL bit 7).

### VBlank dispatch

The existing single ROM `VBlankISR` at `genesis_shell.asm:452` becomes a dispatcher gated on `vblank_mode`:

```
VBlankISR:
    tst.b   vblank_mode
    bne     .transpiled
    ; native path
    bsr     music_tick
    addq.w  #1, s_frame_counter
    rte
.transpiled:
    ; existing wrapper, gates on PPUCTRL bit 7, calls translated IsrNmi
    ; (unchanged from current code at genesis_shell.asm:452-485)
```

The existing wrapper that calls translated `IsrNmi` (which is an `rts` subroutine, not an autovector handler) stays the real vector target. No runtime vector patching. Same vec 30 always.

### Phase machine

```
intro_main:
    intro_phase_init()              ; s_phase = PHASE_TITLE_LOAD
    music_play(SONG_INTRO_BIT)      ; SONG_INTRO_BIT = $80
    for (;;) {
        wait_vblank();              ; spin on s_frame_counter change
        intro_phase_step();
        poll_start();               ; on press → handoff trampoline
    }

phases:
    PHASE_TITLE_LOAD → PHASE_TITLE_DISPLAY → PHASE_TITLE_FADEOUT
    → PHASE_BLACK_HOLD
    → PHASE_STORY_LOAD → PHASE_STORY_RUN  (covers story text + items as
                                            ONE continuous vertical scroll
                                            per intro_demo proof)
    → loop to PHASE_TITLE_LOAD

Story + item scroll are one phase, not two. story_runtime concatenates
pre-blank rows + story tilemap + GAP_ROWS + treasures tilemap, scrolls
the union, and toggles item-flash sprites (heart, fairy, rupee, triforce)
based on pixel-count visibility windows. This matches NES behavior and
intro_demo's working implementation. No separate PHASE_SHOWCASE.
```

### Start handoff

Start press in any phase invokes ASM trampoline `intro_to_file_select_trampoline`. The trampoline restores the translated runtime register contract, seeds the file-select entry RAM contract, re-enables the translated NMI heartbeat via both PPU_CTRL mirrors, flips the dispatcher to transpiled path, and jumps to a translated main-loop re-entry point that expects mode initialization to happen normally.

## Components

| File | Role |
|---|---|
| `src/intro_main.c` | Boot entry from `genesis_shell.asm`. Runs phase machine, polls Start. |
| `src/intro_phase.c/.h` | Phase enum + dispatcher. Lifted from `tools/intro_demo/intro_phase.c`, +SHOWCASE phases. |
| `src/intro_title.c/.h` | Title load/step/fade/blackout. Lifted from `tools/intro_demo/intro_title.c`. |
| `src/intro_story.c/.h` | Story scroll runtime. Replaces existing stub. Lifted from `tools/intro_demo/story_runtime.c` story half. |
| `src/intro_showcase.c/.h` | Existing stub files; deleted in step 5. Items handled inside `intro_story.c` per intro_demo design (one continuous scroll). |
| `src/intro_handoff.c` | Start dispatch path. Existing file evolved; calls ASM trampoline. |
| `src/intro_common.c` | VDP primitives. Existing, kept. |
| `src/gen/intro_*.c` | Generated assets via `tools/extract_intro_assets.py`. Existing, kept. |
| `src/genesis_shell.asm` | Edits: `vblank_mode` seed before IPL, `jsr intro_main` swap, VBlankISR dispatcher, trampoline definition. |
| `tools/intro_demo/build.bat` | Standalone smoke ROM, recompiled to use `src/intro_*.c`. No code duplication. |

`vblank_mode` is a named `.bss` symbol allocated in the documented RAM map block alongside `LAST_GAMEMODE`, `VRamForceBlankGate`, and `_current_window_bank`. ASM-visible label, written only by ASM (boot seed and trampoline). C code never touches it.

## Data flow

### Boot

```
RESET → genesis_shell:EntryPoint
    ├─ VDP/RAM/SAT init, A4/A5/D7 seed, controller, SRAM, save slots
    ├─ move.b #0, vblank_mode
    ├─ lower IPL
    └─ jsr intro_main
intro_main:
    ├─ s_frame_counter = 0
    ├─ music_play($80)
    ├─ intro_phase_init()
    └─ main loop forever
```

### Per-frame

```
NMI fires (vec 30, every vblank, ~60 Hz)
  └─ VBlankISR (single ROM dispatcher):
       ├─ tst.b vblank_mode
       │   ├─ =0 (native): bsr music_tick; addq #1,s_frame_counter; rte
       │   └─ ≠0 (transpiled): existing PPUCTRL-bit-7 gate + IsrNmi call; rte

main loop in intro_main:
    wait_vblank()           → spin until s_frame_counter changes
    intro_phase_step()      → dispatch on s_phase, write VDP/CRAM/VRAM directly
    poll_start()            → controller read, release-then-press latch,
                              ignore first 4 frames (cold-read junk)
                              → on press: jsr intro_to_file_select_trampoline
```

### Start handoff trampoline (ASM)

```
intro_to_file_select_trampoline:
    ; 1. Restore translated runtime register contract.
    move.l  #$00FF0000, A4
    move.l  #$00FF0200, A5
    moveq   #-1, D7

    ; 2. (No VDP work here. The C-side handoff path in intro_handoff.c is
    ;     responsible for vdp_display_off, plane clears, V64 mode, vscroll=0
    ;     BEFORE calling this trampoline. Trampoline is ASM-only and limited
    ;     to register-contract restore + RAM seed + vector-mode flip.)

    ; 3. Seed file-select entry RAM contract.
    move.b  #MODE_FILESELECT, GAMEMODE_OFFSET(A4)        ; TBD: exact offset
    move.b  #0, SUBMODE_OFFSET(A4)
    move.b  #0, FRONTEND_DEMO_PHASE_OFFSET(A4)
    move.b  #0, FRONTEND_DEMO_SUBPHASE_OFFSET(A4)
    move.b  #1, FRONT_START_RELEASE_GATE_OFFSET(A4)      ; Start consumed
    move.b  #0, VRAM_FORCE_BLANK_GATE_OFFSET(A4)
    ; song_request seed for file-select music — TBD bitmap value

    ; 4. Re-enable translated NMI heartbeat.
    ;    Updates BOTH ($00FF,A4) gameplay mirror AND (PPU_CTRL).l absolute
    ;    via existing _ppu_write_0 API in nes_io.asm:283.
    move.b  ($00FF,A4), D0
    ori.b   #$80, D0                ; bit 7 = NMI enable
    bsr     _ppu_write_0

    ; 5. Flip dispatcher to transpiled path.
    move.b  #1, vblank_mode

    ; 6. Resume translated main loop at a re-entry point that re-runs
    ;    mode initialization normally. NOT an arbitrary dispatch label.
    jmp     translated_mainloop_reentry
```

### TBDs (resolved during plan-write, before coding step 5)

1. `MODE_FILESELECT` value — pull from NES disasm `Mode_FileSelect` constant.
2. RAM offsets for `GAMEMODE`, `SUBMODE`, `FRONTEND_DEMO_PHASE`, `FRONTEND_DEMO_SUBPHASE`, `FRONT_START_RELEASE_GATE`, `VRAM_FORCE_BLANK_GATE` — known from existing `intro_handoff.c` constants.
3. `translated_mainloop_reentry` symbol — likely `_main_loop` or `_GameLoop` in z_01/z_02. Identify the entry point that re-runs `InitMode1` / equivalent mode-dispatch logic.
4. File-select song request bitmap.
5. Whether `_ppu_write_0` preserves A4/A5/D7 (almost certainly yes, since it's translated code that runs under the same register contract — but verify by reading `nes_io.asm:283` body).

## Error handling

### Compile-time

- Phase enum exhaustive switch with `default: __builtin_unreachable()` so missing cases warn.
- Asset hash check via existing `tools/extract_intro_assets.py` emitting `intro_asset_hashes.txt`. Build fails on asset extraction drift.

### Runtime probes (kept in ship, ~8 bytes)

- `nes_ram[$07F0]` = current phase value, written each step.
- `nes_ram[$07F1]` = frame counter low byte.
- `nes_ram[$07F2]` = handoff progress marker. `$AA` written before trampoline, `$BB` after restore — pattern carried from existing `intro_handoff.c`.
- `nes_ram[$07F3]` = phase sub-state (story scroll position, showcase index, etc.).

If main ROM hangs, BizHawk RAM watch shows exact phase + sub-state.

### Hard-error sentinels

- Music: silent fail OK. `audio_driver` handles bad bitmap.
- VDP: errors not detectable on hardware. Rely on golden-frame test.
- Start: ignore first 4 frames after boot (controller cold-read junk). Latch release-then-press.

### No backwards-compat

- Transpiled attract-mode bodies (`UpdateMode0Demo`, `InitDemo_RunTasks`, `InitMode1`, `UpdateMode1Menu`, `TitleScreen`, `StoryScroll`, etc.) become unreachable at runtime under native intro. **Symbols stay linkable.** Dispatch tables in `z_07.asm:2487`, `z_07.asm:2874` still reference them. Physical removal would create link errors; that is a separate drain-queue concern handled in a future spec.
- No legacy fallback flag. If native intro breaks, fix native — do not add escape hatch.

## NES-truth pin-downs

These behaviors must be preserved exactly. No "simplifications" allowed in implementation:

| Behavior | Value | Source |
|---|---|---|
| Title song bitmap | `$80` | `genesis_shell.asm:368`, `audio_driver.asm:691` |
| Story scroll cadence | 0.5 px/frame (advance only when `FrameCounter & 1`) | `z_02.asm:703,731` |
| Item flash cadence | sprite-palette toggle on `FrameCounter & $08` | `z_07.asm:2023` |
| Item showcase | scroll-driven + per-object sprite anim, flashing via sprite attribute selection (NOT title-fade CRAM cycle) | NES disasm |

## Testing

### Layer 1 — RAM probe sequence (fast CI gate)

- BizHawk Lua boots ROM, runs 4000 frames, dumps `$07F0..$07F3` every 60 frames to CSV.
- Asserts phase byte sequence matches expected (`0,1,2,3,4,5,6,7,0,1,...`).
- Asserts handoff marker `$07F2` reaches `$BB` after injected Start press at frame N.
- Runtime: ~30 s/ROM. Catches state-machine regressions.
- Lives at `tools/intro_test/probe_phase_sequence.lua`.

### Layer 2 — Golden frame compare (visual regression)

- BizHawk capture every 5 frames during 4000-frame run, save PNG to `builds/reports/intro_main/gen_NNNNN.png`.
- Compare against NES golden capture at `tools/intro_demo/nes_loop/`.
- **Not byte-identical.** Use indexed-mask compare (layout/timing) as hard gate; SSIM/pHash with threshold after palette normalization for pixel-level visual regression. NES 64-color → Genesis 9-bit RGB quantization makes byte-exact unrealistic.
- Runtime: ~2 min/ROM.
- Reuses existing `tools/intro_demo/cmp/` harness, retargeted to main ROM build.

### Layer 3 — Start handoff smoke (split into two)

**Layer 3a — `handoff_contract` (HARD gate, blocks merge):**
- Inject Start press at mid-TITLE_DISPLAY, mid-FADEOUT, mid-STORY_RUN, mid-SHOWCASE_RUN.
- For each, assert: trampoline ran (handoff marker `$BB`), A4/A5/D7 contract restored (verify via probe RAM bytes set by trampoline), NES RAM file-select contract bytes match expected, `vblank_mode` flipped to 1, both PPUCTRL mirrors have bit 7 set.
- 4 sub-tests, ~10 s each.
- Lives at `tools/intro_test/probe_start_handoff.lua`.

**Layer 3b — `full_file_select_smoke` (OPTIONAL, won't block intro merge):**
- Full BizHawk run after Start press, ~120 frames into transpiled file-select.
- Assert frame buffer not all-black, asserts file-select UI elements draw.
- Failure indicates transpiled file-select cold-start bug — separate concern, fixed in future native file-select spec. Does not gate intro merge.

### Build integration

- `build.bat` step 4 (post-link): runs Layer 1 automatically. Build fails on assertion mismatch.
- Layer 2 + Layer 3a manual via `tools/intro_test/run_full.bat` before commit.
- `tools/intro_demo/build.bat` standalone smoke ROM runs Layer 1 + Layer 2 only (no Start handoff path; no transpiled file-select to verify).

## Sequencing — incremental land order

Each step ships independently, gated by its own test:

1. **ASM trampoline + `vblank_mode` dispatcher.** Add `vblank_mode` `.bss` symbol. Modify VBlankISR to branch on it. Default `vblank_mode=1` (transpiled). Main ROM behavior unchanged. Verify build green, no regression.
2. **`intro_main` scaffold.** Add `src/intro_main.c` with empty phase loop. Modify `genesis_shell.asm` to seed `vblank_mode=0` before IPL lower and `jsr intro_main` instead of `jsr IsrReset`. intro_main sits in vblank loop forever. Probe RAM bytes prove control transfer.
3. **Promote intro_demo phases to `src/`.** Move `intro_phase.c`, `intro_title.c`, `story_runtime.c` → `src/intro_*.c`. Wire into `intro_main`. Title + fade + story play in main ROM. Update `tools/intro_demo/build.bat` to compile from `src/`. Layer 1 + Layer 2 tests pass on both ROMs.
4. **Delete stub showcase files.** `src/intro_showcase.c/.h` no longer needed — items already part of story_runtime continuous scroll. Remove from build, delete files. Layer 1 + Layer 2 still pass (no behavior change).
5. **Start handoff trampoline.** Implement ASM `intro_to_file_select_trampoline` per Section "Data flow / Start handoff trampoline." Resolve all TBDs (MODE_FILESELECT, RAM offsets, mainloop re-entry symbol, file-select song bitmap, `_ppu_write_0` register preservation) **before** coding. Layer 3a `handoff_contract` test gates merge. Layer 3b `full_file_select_smoke` runs but tolerated if fails.
6. **(Optional, future spec.)** Native file-select rewrite if transpiled file-select doesn't cold-start cleanly.

## Risks

- **R1 — Pre-intro shell init touches state intro doesn't expect.** `_sram_load_save_slots` writes save-slot RAM. Intro should not read save state; if it ever does, document the read explicitly.
- **R3 — TBD slippage.** All TBDs (Section "Data flow") must be concrete before step 5 begins. Block step 5 on TBD list checked off in plan.
- **R4 — Audio bitmap drift.** `$80` confirmed for title music; story / item-scroll phases may use different songs in NES original. Verify by dumping NES audio events per phase during golden-frame capture.
- **R5 — Standalone intro_demo drift after `src/` promotion.** `tools/intro_demo/build.bat` must compile same `src/intro_*.c` files. Enforce in build script. No parallel copy of intro phase code.
- **R6 — `_ppu_write_0` register clobber.** Trampoline depends on A4/A5/D7 surviving the call. Translated code under register contract should preserve them, but verify in plan-write by reading `nes_io.asm:283` body.

## Out of scope

- Native file-select. Separate spec, separate ship.
- Native gameplay. Stays transpiled.
- Audio engine changes. `audio_driver.asm` untouched.
- New asset extraction. Existing `tools/extract_intro_assets.py` covers everything.
- Drain-queue cleanup. Symbols stay linkable; dead-code removal handled separately.
- Rewriting transpiled `IsrNmi`. Stays as-is, called via VBlankISR wrapper when `vblank_mode=1`.

## Codex review history

- **Pass 1** identified three P0 blockers (runtime vector patching, wrong vector / wrong handler shape, missing register contract on handoff) and two P1s (drain symbol deletion, story scroll cadence). All folded into design.
- **Pass 2** identified three P1s (PPU_CTRL mirror update incomplete, `vblank_mode` boot race, ad-hoc RAM placement). All folded into design. Architecture ruled materially sound.
