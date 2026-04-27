# Native Intro in Main ROM — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Spec:** `docs/superpowers/specs/2026-04-26-native-intro-main-rom-design.md`

**Goal:** Replace the transpiled (6502→M68K) intro sequence in the main ROM with the native phase machine already proven in `tools/intro_demo/`, then add a Start press handoff into the existing transpiled file-select path.

**Architecture:** The pre-intro init in `genesis_shell.asm` (VDP regs, RAM zero, A4/A5/D7 seed, save-slot load) keeps running. After IPL is lowered, ASM seeds a new `vblank_mode` RAM byte to 0 and calls `intro_main` instead of `IsrReset`. A single ROM `VBlankISR` dispatches on `vblank_mode`: 0 = native (music_tick + frame counter), 1 = transpiled (existing wrapper that gates on PPUCTRL bit 7 and calls `IsrNmi`). On Start press, an ASM trampoline restores the translated runtime register contract (A4/A5/D7), seeds the file-select entry RAM contract, re-enables the translated NMI heartbeat by writing PPUCTRL bit 7 via `_ppu_write_0`, flips `vblank_mode` to 1, and jumps to a translated main-loop re-entry symbol that re-runs mode initialization normally.

**Tech Stack:** vasm Motorola syntax assembler (`vasmm68k_mot`), m68k-elf gcc (SGDK toolchain), m68k-elf-ld with `build/genesis.ld`, BizHawk Lua scripts for verification, Python 3 for asset extraction and probe analysis.

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `src/genesis_shell.asm` | Modify | Reset path: seed `vblank_mode=0`, jump to `intro_main`. VBlankISR: dispatch on `vblank_mode`. ASM trampoline `intro_to_file_select_trampoline`. New `vblank_mode` `.bss` symbol. |
| `src/intro_main.c` | Create | Boot entry called from genesis_shell. Runs phase machine, polls Start, increments frame counter via NMI, calls handoff on Start press. |
| `src/intro_main.h` | Create | Public API: `void intro_main(void);`. |
| `src/intro_phase.c` | Create | Phase enum dispatcher. Lifted from `tools/intro_demo/intro_phase.c`. |
| `src/intro_phase.h` | Create | Phase enum + dispatcher API. Lifted from `tools/intro_demo/intro_phase.h`. |
| `src/intro_title.c` | Create | Title runtime. Lifted from `tools/intro_demo/intro_title.c`. |
| `src/intro_title.h` | Create | Title runtime API. Lifted from `tools/intro_demo/intro_title.h`. |
| `src/intro_story.c` | Replace | Story + items continuous scroll runtime. Replaces existing 44-line stub with full implementation lifted from `tools/intro_demo/story_runtime.c`. |
| `src/intro_story.h` | Replace | Story runtime API matching `tools/intro_demo/story_runtime.h`. |
| `src/intro_showcase.c` | Delete | Stub no longer needed; items handled inside intro_story. |
| `src/intro_showcase.h` | Delete | Same. |
| `src/intro_handoff.c` | Replace | Start dispatch path: VDP cleanup, then call ASM trampoline. Replaces existing 45-line legacy attract reset. |
| `src/intro_handoff.h` | Modify | Drop `intro_handoff_state_t` struct (no longer used); add `void intro_start_pressed(void);`. |
| `src/intro_common.c/.h` | Keep | VDP primitives stay; minor additions for new shared helpers if needed. |
| `build.bat` | Modify | Add `intro_main intro_phase intro_title` to `C_SOURCES`; remove `intro_showcase` and `intro_handoff_state` from gen list. |
| `tools/intro_demo/build.bat` | Modify | Compile from `src/intro_*.c` instead of `tools/intro_demo/*.c`. |
| `tools/intro_test/probe_phase_sequence.lua` | Create | Layer 1 RAM probe: assert phase byte sequence + handoff marker. |
| `tools/intro_test/probe_start_handoff.lua` | Create | Layer 3a handoff_contract test: per-phase Start injection, assert contract bytes. |
| `tools/intro_test/run_full.bat` | Create | Manual driver for Layer 2 (golden frame compare) + Layer 3a tests. |
| `tools/intro_test/check_probe_sequence.py` | Create | Build-step assertion: parse probe CSV, fail build on sequence mismatch. |

Asset files in `src/gen/intro_*.c` already exist via `tools/extract_intro_assets.py` and need no changes. The intro_demo's local copies of bg/sprite CHR (`tools/intro_demo/intro_*_chr.c` and similar generated-locally files) need to be gathered into `src/gen/` so both ROMs link against one source. That gathering happens in Task 4.

---

## Task 1: Add `vblank_mode` dispatcher to VBlankISR

**Files:**
- Modify: `src/genesis_shell.asm:445-498` (VBlankISR body)
- Modify: `src/genesis_shell.asm:118-180` (RAM map block — add `vblank_mode` reservation)

**Goal:** Introduce the dispatcher with default `vblank_mode=1` so existing main-ROM behavior is unchanged. This is a pure refactor with no functional change. Build must stay green and main ROM must still boot into transpiled gameplay.

- [ ] **Step 1: Identify the existing RAM-map documentation block in `genesis_shell.asm`**

Run: `grep -n "LAST_GAMEMODE\|VRamForceBlankGate\|_current_window_bank" src/genesis_shell.asm`

Expected: at least one hit identifying the documented RAM block where these symbols are declared. Note the line range for the next step.

- [ ] **Step 2: Add the `vblank_mode` symbol declaration**

Add this block immediately after the existing `LAST_GAMEMODE` declaration (or wherever the documented RAM map block ends). Replace `<LINE>` with the appropriate insert point:

```asm
;------------------------------------------------------------------------------
; vblank_mode — VBlankISR dispatch flag.
;   $00 = native intro path (music_tick + s_frame_counter only)
;   $01 = transpiled path (existing PPUCTRL gate + IsrNmi + ags/oam flushes)
; Owned by ASM. C never touches it. Boot ASM seeds $00 before IPL is lowered;
; the Start handoff trampoline writes $01 immediately before resuming the
; translated main loop. Single byte; aligned naturally.
;------------------------------------------------------------------------------
vblank_mode:    equ     $00FF0FFC
```

The address $FF0FFC sits in the free RAM tail $FF0FC0–$FF0FFF, after the NT_CACHE block ($FF0840–$FF0FBF). The $FF0Bxx range originally proposed in early plan drafts collides with NT_CACHE — do not use it.

Run: `grep -n "FF0FFC\|FF0FFD\|FF0FFE\|FF0FFF" src/genesis_shell.asm src/audio_driver.asm src/nes_io.asm`

Expected: no hits (or hits only in this new block). If hits, pick an unused address.

- [ ] **Step 3: Replace `VBlankISR` body with a dispatcher**

Existing body at `src/genesis_shell.asm:452-498`:

```asm
VBlankISR:
    movem.l D0-D7/A0-A6,-(SP)
    btst    #7,($00FF0804).l
    beq.s   .nmi_off
    addq.b  #1,($00FF1003).l
    bsr     _oam_dma_flush
    bsr     _ags_prearm
    bsr     _mode_transition_check
    jsr     IsrNmi
    jsr     c_probe_tick
    bsr     music_tick
    bsr     _ags_flush
.nmi_off:
    movem.l (SP)+,D0-D7/A0-A6
    rte
```

Replace with:

```asm
VBlankISR:
    movem.l D0-D7/A0-A6,-(SP)
    tst.b   (vblank_mode).l
    bne.s   .vbi_transpiled
    ; --- native intro path: music + frame counter only ---
    bsr     music_tick
    addq.l  #1,(s_intro_frame_counter).l
    bra.s   .vbi_done
.vbi_transpiled:
    ; --- existing transpiled path (unchanged) ---
    btst    #7,($00FF0804).l
    beq.s   .vbi_done
    addq.b  #1,($00FF1003).l
    bsr     _oam_dma_flush
    bsr     _ags_prearm
    bsr     _mode_transition_check
    jsr     IsrNmi
    jsr     c_probe_tick
    bsr     music_tick
    bsr     _ags_flush
.vbi_done:
    movem.l (SP)+,D0-D7/A0-A6
    rte
```

- [ ] **Step 4: Declare `s_intro_frame_counter` in the same RAM block**

Add immediately after the `vblank_mode` declaration from Step 2:

```asm
;------------------------------------------------------------------------------
; s_intro_frame_counter — incremented by VBlankISR every frame the native
; intro is active. C-side wait_vblank() spins on changes to this longword.
; Owned by ASM (writer); C reads via extern declaration.
;------------------------------------------------------------------------------
s_intro_frame_counter:  equ     $00FF0FF8   ; longword, 4 bytes
```

Run: `grep -n "FF0FF8\|FF0FF9\|FF0FFA\|FF0FFB" src/genesis_shell.asm src/audio_driver.asm src/nes_io.asm`

Expected: no hits. If hits, pick another 4-byte aligned region.

- [ ] **Step 5: Seed `vblank_mode = 1` in boot ASM (default = transpiled, unchanged behavior)**

In `src/genesis_shell.asm` between the `_sram_load_save_slots` jsr and the IPL lowering at line 425, add:

```asm
    ; Default VBlankISR dispatch = transpiled path so this task is a
    ; no-op refactor. Task 2 will change the seed to $00 once intro_main
    ; is wired in.
    move.b  #1,(vblank_mode).l
    clr.l   (s_intro_frame_counter).l
```

This must come BEFORE line 425 (`andi.w #$F8FF,SR`) so the dispatch flag is latched before any VBlank can fire.

- [ ] **Step 6: Build and verify no regression**

Run: `./build.bat`

Expected: build succeeds. `builds/whatif.md` produced. No new vasm errors. No new gcc warnings in the C compile loop.

- [ ] **Step 7: Smoke-test the ROM boots into transpiled gameplay (unchanged)**

Run via the bizhawkScript skill:

```
cmd.exe /c cd /d "C:\path\to\BizHawk" && EmuHawk.exe --lua="C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\tools\bizhawk_capture_intro_sequence.lua" "C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\builds\whatif.md"
```

(Adjust paths per the bizhawkScript skill's launch pattern.)

Expected: ROM still reaches the transpiled title path (or transpiled-intro crash, which is the documented baseline). No new hang from the dispatcher swap. Confirm by RAM-watching `vblank_mode` ($FF0FFC) = $01 and `s_intro_frame_counter` ($FF0FF8) staying at $00000000 (native path never runs in Task 1).

- [ ] **Step 8: Commit**

```bash
git add src/genesis_shell.asm
git commit -m "$(cat <<'EOF'
asm: VBlankISR dispatch on vblank_mode flag (default = transpiled)

Refactor only. Splits VBlankISR into native vs transpiled path keyed on
the new vblank_mode RAM byte. Boot seeds vblank_mode=1 before IPL lower
so existing behavior is unchanged. s_intro_frame_counter reserved for
Task 2's intro_main wait_vblank().

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Add `intro_main` scaffold and divert reset to it

**Files:**
- Create: `src/intro_main.c`
- Create: `src/intro_main.h`
- Modify: `src/genesis_shell.asm:436` (replace `jsr IsrReset` with `jsr intro_main`)
- Modify: `src/genesis_shell.asm` (change `vblank_mode` seed from 1 to 0)
- Modify: `build.bat:108` (add `intro_main` to `C_SOURCES`)

**Goal:** Native code owns the reset path. intro_main installs nothing yet — just spins in a wait_vblank loop and writes a probe byte to prove control reached it. Transpiled code never runs.

- [ ] **Step 1: Write `src/intro_main.h`**

```c
/* src/intro_main.h
 *
 * Boot entry from src/genesis_shell.asm. Owns the main loop while the
 * native intro is running. Returns by jumping (not via stack) to the
 * Start handoff trampoline; never returns to the caller normally.
 */
#ifndef INTRO_MAIN_H
#define INTRO_MAIN_H

void intro_main(void);

#endif
```

- [ ] **Step 2: Write `src/intro_main.c`**

```c
/* src/intro_main.c
 *
 * Native intro boot entry. Pre-intro shell init in genesis_shell.asm
 * has already run (VDP regs, RAM zero, A4/A5/D7 seed, save-slot load).
 * IPL is lowered. vblank_mode is 0 (native path active), so VBlankISR
 * is ticking music_tick and incrementing s_intro_frame_counter.
 *
 * For Task 2 this is a stub that:
 *   - Requests title music via music_play($80) (audio_driver.asm:691).
 *   - Writes a "we are alive" probe byte to nes_ram[$07FF].
 *   - Spins in wait_vblank() forever, bumping nes_ram[$07F1] each frame.
 *
 * Task 3+ wires the real phase machine in.
 */
#include "intro_main.h"
#include "nes_abi.h"   /* nes_ram[] base */

extern volatile unsigned long s_intro_frame_counter;  /* defined in genesis_shell.asm */
extern void music_play(unsigned char song_bitmap);    /* in audio_driver.asm */

static void wait_vblank(void) {
    unsigned long start = s_intro_frame_counter;
    while (s_intro_frame_counter == start) {
        /* spin */
    }
}

void intro_main(void) {
    music_play(0x80);         /* SongIntro per audio_driver.asm:691 */
    nes_ram[0x07FF] = 0xA1;   /* probe: intro_main entered */
    nes_ram[0x07F1] = 0;      /* frame-tick probe (low byte) */

    for (;;) {
        wait_vblank();
        nes_ram[0x07F1]++;
    }
}
```

- [ ] **Step 3: Modify `genesis_shell.asm` to flip seed and divert reset**

Find the `move.b #1,(vblank_mode).l` line added in Task 1. Change to:

```asm
    move.b  #0,(vblank_mode).l
    clr.l   (s_intro_frame_counter).l
```

Find `jsr IsrReset` at `src/genesis_shell.asm:436`. Change to:

```asm
    jsr     intro_main          ; native intro owns the loop now
```

`IsrReset` stays defined and linkable (translated code still references it via dispatch tables); we just don't call it from boot.

- [ ] **Step 4: Add `intro_main` to the C build**

In `build.bat:108`, change:

```
set "C_SOURCES=... save_menu_runtime intro_common intro_story intro_showcase intro_handoff"
```

to:

```
set "C_SOURCES=... save_menu_runtime intro_common intro_story intro_showcase intro_handoff intro_main"
```

(Append `intro_main` at the end of the list. Order is alphabetical within the runtime group is not enforced — appending is safe.)

- [ ] **Step 5: Build**

Run: `./build.bat`

Expected: build succeeds. No undefined-symbol errors for `intro_main`, `s_intro_frame_counter`, or `vblank_mode`.

- [ ] **Step 6: Boot in BizHawk and verify probes**

Launch the ROM via the bizhawkScript skill. After ~5 seconds, RAM-watch:

- `$FF0FFC` (vblank_mode) = `$00`
- `$FF07FF` (NES RAM offset $07FF — `nes_ram[0x07FF]`) = `$A1`  (intro_main entered sentinel)
- `$FF00F1` (`nes_ram[0x07F1]`) = increasing value (~0xFF after 4 seconds at 60 Hz wraps)
- `$FF0FF8` (s_intro_frame_counter) = increasing longword

Note: `nes_ram` base is `$FF0000` per `nes_abi.h`; nes_ram[0x07FF] = absolute $FF07FF. Adjust addresses if the macro maps differently — check `src/nes_abi.h` first.

Expected screen: black or whatever the boot init left in CRAM (likely black). No transpiled gameplay because IsrReset is bypassed and vblank_mode=0 suppresses the IsrNmi call path.

- [ ] **Step 7: Commit**

```bash
git add src/intro_main.c src/intro_main.h src/genesis_shell.asm build.bat
git commit -m "$(cat <<'EOF'
intro: native intro_main scaffold; reset diverted from IsrReset

Boot ASM now seeds vblank_mode=0 and calls intro_main instead of IsrReset.
intro_main is a stub that proves control transfer via probe bytes at
nes_ram[$07FF] (=$A1) and nes_ram[$07F1] (frame tick). Task 3 wires the
phase machine in.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Promote `intro_phase` to `src/`, wire into intro_main

**Files:**
- Create: `src/intro_phase.c`
- Create: `src/intro_phase.h`
- Modify: `src/intro_main.c`
- Modify: `build.bat:108` (add `intro_phase`)

**Goal:** intro_main calls `intro_phase_init()` once and `intro_phase_step()` each vblank. Phase machine has all phases declared but each phase body is a placeholder that just writes a probe byte and counts down to the next phase. Proves the dispatcher works end-to-end before lifting any of the heavy phase code.

- [ ] **Step 1: Write `src/intro_phase.h` (lift verbatim from intro_demo)**

```c
/* src/intro_phase.h
 *
 * Top-level phase state machine for the native intro. intro_main
 * calls intro_phase_init() once at boot and intro_phase_step()
 * each vblank.
 */
#ifndef INTRO_PHASE_H
#define INTRO_PHASE_H

typedef enum {
    PHASE_TITLE_LOAD = 0,
    PHASE_TITLE_DISPLAY,
    PHASE_TITLE_FADEOUT,
    PHASE_BLACK_HOLD,
    PHASE_STORY_LOAD,
    PHASE_STORY_RUN,    /* covers story text + items as one continuous
                         * scroll; intro_story owns sub-state internally */
} intro_phase_t;

void intro_phase_init(void);
void intro_phase_step(void);

#endif
```

- [ ] **Step 2: Write `src/intro_phase.c` placeholder dispatcher**

```c
/* src/intro_phase.c
 *
 * Phase dispatcher. Task 3 ships this as a placeholder: each phase
 * just writes its enum value to nes_ram[$07F0] and counts down 60
 * frames before advancing. Tasks 4-5 replace placeholder bodies with
 * lifts from intro_demo.
 */
#include "intro_phase.h"
#include "nes_abi.h"

static intro_phase_t s_phase;
static unsigned short s_counter;

static void goto_phase(intro_phase_t next) {
    s_phase = next;
    s_counter = 0;
    nes_ram[0x07F0] = (unsigned char)next;
}

void intro_phase_init(void) {
    s_phase = PHASE_TITLE_LOAD;
    s_counter = 0;
    nes_ram[0x07F0] = (unsigned char)PHASE_TITLE_LOAD;
}

void intro_phase_step(void) {
    s_counter++;
    if (s_counter < 60u) return;

    switch (s_phase) {
        case PHASE_TITLE_LOAD:    goto_phase(PHASE_TITLE_DISPLAY); break;
        case PHASE_TITLE_DISPLAY: goto_phase(PHASE_TITLE_FADEOUT); break;
        case PHASE_TITLE_FADEOUT: goto_phase(PHASE_BLACK_HOLD);    break;
        case PHASE_BLACK_HOLD:    goto_phase(PHASE_STORY_LOAD);    break;
        case PHASE_STORY_LOAD:    goto_phase(PHASE_STORY_RUN);     break;
        case PHASE_STORY_RUN:     goto_phase(PHASE_TITLE_LOAD);    break;
        default:                  __builtin_unreachable();
    }
}
```

- [ ] **Step 3: Wire `intro_phase` into `intro_main.c`**

Replace the `for(;;)` loop body in `src/intro_main.c` with:

```c
void intro_main(void) {
    nes_ram[0x07FF] = 0xA1;   /* "we entered intro_main" sentinel */
    nes_ram[0x07F1] = 0;
    intro_phase_init();

    for (;;) {
        wait_vblank();
        nes_ram[0x07F1]++;
        intro_phase_step();
    }
}
```

Add `#include "intro_phase.h"` near the top.

- [ ] **Step 4: Add `intro_phase` to the C build**

In `build.bat:108`, change `intro_main` at the end of `C_SOURCES` to `intro_main intro_phase`.

- [ ] **Step 5: Build**

Run: `./build.bat`

Expected: build succeeds.

- [ ] **Step 6: Boot in BizHawk and verify phase progression**

Launch ROM. RAM-watch `$FF07F0`. Expected sequence over time (60 frames per phase ~ 1 second):

- t=0s: $00 (PHASE_TITLE_LOAD)
- t=1s: $01 (PHASE_TITLE_DISPLAY)
- t=2s: $02 (PHASE_TITLE_FADEOUT)
- t=3s: $03 (PHASE_BLACK_HOLD)
- t=4s: $04 (PHASE_STORY_LOAD)
- t=5s: $05 (PHASE_STORY_RUN)
- t=6s: $00 again, loop

Screen still black (no phase body draws anything yet).

- [ ] **Step 7: Commit**

```bash
git add src/intro_phase.c src/intro_phase.h src/intro_main.c build.bat
git commit -m "$(cat <<'EOF'
intro: phase dispatcher with placeholder bodies

intro_main now calls intro_phase_init/step. Each phase advances after
60 frames and writes its enum to nes_ram[$07F0] for probe verification.
Phase bodies will be filled in Tasks 4-5.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Lift title runtime; gather title assets to `src/gen/`

**Files:**
- Create: `src/intro_title.c` (lift from `tools/intro_demo/intro_title.c`)
- Create: `src/intro_title.h` (lift from `tools/intro_demo/intro_title.h`)
- Modify: `src/intro_phase.c` (call real title phase functions)
- Modify: `tools/extract_intro_assets.py` (extend to emit title CHR + title palette + title fade + title glow + title tilemap, all to `src/gen/`)
- Modify: `build.bat:109` (add new gen sources to `C_GEN_SOURCES`)
- Modify: `build.bat:108` (add `intro_title` to `C_SOURCES`)

**Goal:** Title screen + fade-out + waterfall + glow renders in main ROM. Black hold also lands.

- [ ] **Step 1: Inventory title-side asset symbols required by `intro_title.c`**

Read `tools/intro_demo/intro_title.c` lines 12-22 — these are the `extern` declarations. Required symbols:

- `intro_title_bg_chr[]`, `intro_title_bg_chr_size`
- `intro_title_sprite_chr[]`, `intro_title_sprite_chr_size`
- `intro_title_tilemap_rows`, `intro_title_tilemap[]`
- `intro_title_palette[64]`
- `intro_title_fade_cycles[14][64]`, `intro_title_fade_delays[14]`
- `intro_title_glow_colors[8]`, `intro_title_glow_delays[8]`

Find their sources in intro_demo:

Run: `grep -ln "intro_title_bg_chr\|intro_title_sprite_chr\|intro_title_tilemap\|intro_title_palette\|intro_title_fade\|intro_title_glow" tools/intro_demo/`

Expected: hits in `intro_title_bg_chr.c`, `intro_title_sprite_chr.c`, `intro_title_tilemap.c`, `intro_title_palette.c`, `intro_title_fade.c`, `intro_title_glow.c` (all in `tools/intro_demo/`).

- [ ] **Step 2: Extend `tools/extract_intro_assets.py` to emit these into `src/gen/`**

Read `tools/extract_intro_assets.py` to find the existing `_emit_chr_array`, `_emit_palette`, `_emit_tilemap` helpers. The pattern from intro_demo's existing `extract_title_*.py` scripts is the source of truth for the byte layout. For each title asset, add an extraction step that:

1. Calls the same parse logic as the matching `tools/intro_demo/extract_title_<asset>.py` script.
2. Writes the C array to `src/gen/intro_title_<asset>.c` using the same `_emit_chr_array` / `_emit_palette` / `_emit_tilemap` helper.
3. Adds the new file's SHA to the manifest in `intro_asset_hashes.txt`.

For brevity here, the concrete editing steps are:

(a) Open `tools/extract_intro_assets.py`. Read the `main()` function to find where existing emits happen (around line 290-320 per the spec context).

(b) After the existing `_emit_chr_array(out_dir / "intro_art_chr.c", ...)` call, add:

```python
_emit_chr_array(out_dir / "intro_title_bg_chr.c", "intro_title_bg_chr",
                _read_title_bg_chr())
_emit_chr_array(out_dir / "intro_title_sprite_chr.c", "intro_title_sprite_chr",
                _read_title_sprite_chr())
_emit_palette(out_dir / "intro_title_palette.c", _read_title_palette())
_emit_tilemap(out_dir / "intro_title_tilemap.c", "intro_title_tilemap",
              _read_title_tilemap_cells(), _read_title_tilemap_rows())
_emit_title_fade(out_dir / "intro_title_fade.c", _read_title_fade())
_emit_title_glow(out_dir / "intro_title_glow.c", _read_title_glow())
```

(c) Implement `_read_title_bg_chr()`, `_read_title_sprite_chr()`, `_read_title_palette()`, `_read_title_tilemap_cells()`, `_read_title_tilemap_rows()`, `_read_title_fade()`, `_read_title_glow()` by lifting the parse logic from the matching `tools/intro_demo/extract_title_*.py` scripts. These scripts read from `reference/aldonunez/dat/`.

(d) Implement `_emit_title_fade(path, cycles_and_delays)` to write a C file containing both `intro_title_fade_cycles[14][64]` and `intro_title_fade_delays[14]`.

(e) Implement `_emit_title_glow(path, colors_and_delays)` to write a C file containing both `intro_title_glow_colors[8]` and `intro_title_glow_delays[8]`.

(f) Add the six new files to the SHA hash dict at the end of main().

- [ ] **Step 3: Lift `intro_title.h` to `src/intro_title.h` verbatim**

Copy `tools/intro_demo/intro_title.h` to `src/intro_title.h`. No edits required.

- [ ] **Step 4: Lift `intro_title.c` to `src/intro_title.c` verbatim**

Copy `tools/intro_demo/intro_title.c` to `src/intro_title.c`. No edits required (extern declarations match the new gen files).

- [ ] **Step 5: Wire title phases into `intro_phase.c`**

Replace the placeholder body of `src/intro_phase.c` with the real one lifted from `tools/intro_demo/intro_phase.c` (lines 1-73), but keep the probe byte writes. Concretely:

```c
#include "intro_phase.h"
#include "intro_title.h"
#include "nes_abi.h"

static intro_phase_t s_phase;
static unsigned short s_phase_counter;

static void goto_phase(intro_phase_t next) {
    s_phase = next;
    s_phase_counter = 0;
    nes_ram[0x07F0] = (unsigned char)next;
}

void intro_phase_init(void) {
    s_phase = PHASE_TITLE_LOAD;
    s_phase_counter = 0;
    nes_ram[0x07F0] = (unsigned char)PHASE_TITLE_LOAD;
}

void intro_phase_step(void) {
    switch (s_phase) {
        case PHASE_TITLE_LOAD:
            intro_title_setup();
            goto_phase(PHASE_TITLE_DISPLAY);
            break;

        case PHASE_TITLE_DISPLAY:
            intro_title_step();
            s_phase_counter++;
            if (s_phase_counter >= TITLE_DISPLAY_FRAMES) {
                intro_title_fade_reset();
                intro_title_fade_apply(0);
                goto_phase(PHASE_TITLE_FADEOUT);
            }
            break;

        case PHASE_TITLE_FADEOUT:
            intro_title_step();
            intro_title_fade_step();
            if (intro_title_fade_done()) {
                intro_title_blackout();
                goto_phase(PHASE_BLACK_HOLD);
            }
            break;

        case PHASE_BLACK_HOLD:
            s_phase_counter++;
            if (s_phase_counter >= BLACK_HOLD_FRAMES) {
                /* Story phases not wired yet (Task 5). Loop to title. */
                goto_phase(PHASE_TITLE_LOAD);
            }
            break;

        case PHASE_STORY_LOAD:
        case PHASE_STORY_RUN:
            /* Wired in Task 5. */
            goto_phase(PHASE_TITLE_LOAD);
            break;

        default:
            __builtin_unreachable();
    }
}
```

- [ ] **Step 6: Add new sources to `build.bat`**

In `build.bat:108`, append `intro_title` to `C_SOURCES`. In `build.bat:109`, append `intro_title_bg_chr intro_title_sprite_chr intro_title_palette intro_title_tilemap intro_title_fade intro_title_glow` to `C_GEN_SOURCES`.

- [ ] **Step 7: Build**

Run: `./build.bat`

Expected: build step `[2a.0/4] Extracting intro assets from reference data...` produces the new `src/gen/intro_title_*.c` files. Subsequent C compile steps succeed. No unresolved-symbol errors.

If extraction fails, debug `tools/extract_intro_assets.py` against the pre-existing `tools/intro_demo/extract_title_*.py` byte layouts before continuing.

- [ ] **Step 8: Boot in BizHawk and verify title renders**

Launch ROM. Expected:

- Title screen renders (Zelda logo, sword decorations, waterfall sprites, Triforce glow).
- After ~6.6 seconds (`TITLE_DISPLAY_FRAMES = 400` at 60 Hz), 14-cycle fade-out runs.
- After fade, screen black for ~3 seconds (`BLACK_HOLD_FRAMES = 180`).
- Loop back to title.

RAM-watch `$FF07F0` cycles 0 → 1 → 2 → 3 → 0.

- [ ] **Step 9: Commit**

```bash
git add tools/extract_intro_assets.py src/gen/intro_title_*.c \
        src/intro_title.c src/intro_title.h src/intro_phase.c build.bat
git commit -m "$(cat <<'EOF'
intro: title runtime in main ROM (waterfall + glow + 14-cycle fade)

Lifts intro_title.{c,h} verbatim from tools/intro_demo. Title CHR,
sprite CHR, palette, tilemap, fade table, and glow table extracted by
tools/extract_intro_assets.py into src/gen/. intro_phase wires
TITLE_LOAD → TITLE_DISPLAY → TITLE_FADEOUT → BLACK_HOLD → loop.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Lift story+items runtime; replace stub `intro_story.c`

**Files:**
- Replace: `src/intro_story.c` (lift body from `tools/intro_demo/story_runtime.c`)
- Replace: `src/intro_story.h` (lift API from `tools/intro_demo/story_runtime.h`)
- Modify: `src/intro_phase.c` (wire STORY_LOAD/STORY_RUN to real bodies)
- Modify: `tools/extract_intro_assets.py` (extend to emit common_bg_chr, font_chr, sprite_chr, misc_chr, punct_chr, blink_chr, combined_palette, treasures_tilemap, treasures_palette to `src/gen/`)
- Modify: `build.bat:109` (add new gen sources)
- Delete: `src/intro_showcase.c`, `src/intro_showcase.h`
- Modify: `build.bat:108` (remove `intro_showcase` from `C_SOURCES`)

**Goal:** Full story scroll plays in main ROM, including item flash. Loop completes title → fade → story+items → title.

- [ ] **Step 1: Inventory story-side asset symbols**

Read `tools/intro_demo/story_runtime.c` lines 19-35. Required externs:

- `intro_common_bg_chr[]` + size
- `intro_font_chr[]` + size  *(already in src/gen)*
- `intro_sprite_chr[]` + size
- `intro_misc_chr[]` + size
- `intro_punct_chr[]` + size
- `intro_blink_chr[]` + size
- `intro_combined_palette[64]`
- `intro_story_tilemap_rows`, `intro_story_tilemap[]`  *(already in src/gen as `intro_story_tilemap.c` — verify shape)*
- `intro_treasures_tilemap_rows`, `intro_treasures_tilemap[]`

Run: `ls src/gen/intro_*` and cross-reference. Identify which assets are missing from `src/gen/` and need new emit steps.

- [ ] **Step 2: Extend `tools/extract_intro_assets.py` for missing story assets**

Mirror the pattern from Task 4 Step 2. For each missing asset, add:

```python
_emit_chr_array(out_dir / "intro_common_bg_chr.c", "intro_common_bg_chr",
                _read_common_bg_chr())
_emit_chr_array(out_dir / "intro_sprite_chr.c", "intro_sprite_chr",
                _read_sprite_chr())
_emit_chr_array(out_dir / "intro_misc_chr.c", "intro_misc_chr",
                _read_misc_chr())
_emit_chr_array(out_dir / "intro_punct_chr.c", "intro_punct_chr",
                _read_punct_chr())
_emit_chr_array(out_dir / "intro_blink_chr.c", "intro_blink_chr",
                _read_blink_chr())
_emit_palette(out_dir / "intro_combined_palette.c", _read_combined_palette())
_emit_tilemap(out_dir / "intro_treasures_tilemap.c", "intro_treasures_tilemap",
              _read_treasures_cells(), _read_treasures_rows())
```

Implement each `_read_*` helper by lifting the parse logic from the matching `tools/intro_demo/extract_<name>.py` or `tools/intro_demo/compose_<name>.py` script. Add the new files to the SHA hash dict.

Also replace the existing `intro_story_tilemap.c` emission to ensure it matches the GameCube-version composition that `tools/intro_demo/compose_story_tilemap.py` does (the existing src/gen one may be a different layout).

Run: `git diff src/gen/intro_story_tilemap.c` after the extraction step to confirm the layout matches what story_runtime.c expects.

- [ ] **Step 3: Replace `src/intro_story.h` with the lifted API**

Replace the existing `src/intro_story.h` (currently contains `intro_story_enter` / `intro_story_update`) with:

```c
/* src/intro_story.h
 *
 * Story + items continuous-scroll runtime. PHASE_STORY_LOAD calls
 * story_load(); PHASE_STORY_RUN calls story_step() each vblank.
 * Story text and items are a single concatenated tilemap that scrolls
 * vertically; items animate via per-tile pal toggles inside step().
 */
#ifndef INTRO_STORY_H
#define INTRO_STORY_H

void intro_story_load(void);            /* PHASE_STORY_LOAD */
void intro_story_step(void);            /* per vblank during STORY_RUN */
unsigned char intro_story_at_end(void); /* 1 once full content + end pause done */
void intro_story_clear_end(void);       /* reset end flag for next loop */

#endif
```

Note: function names changed from `story_runtime_*` (intro_demo) to `intro_story_*` (main ROM convention).

- [ ] **Step 4: Replace `src/intro_story.c` with the lifted body**

Copy `tools/intro_demo/story_runtime.c` to `src/intro_story.c`. Then:

(a) Change `#include "story_runtime.h"` to `#include "intro_story.h"`.
(b) Rename the four public functions:
   - `story_runtime_load` → `intro_story_load`
   - `story_runtime_step` → `intro_story_step`
   - `story_runtime_at_end` → `intro_story_at_end`
   - `story_runtime_clear_end` → `intro_story_clear_end`

Do not touch the static helpers, internal state, or item-flash logic.

- [ ] **Step 5: Wire story phases into `intro_phase.c`**

In `src/intro_phase.c`, add `#include "intro_story.h"`. Replace the `PHASE_STORY_LOAD` / `PHASE_STORY_RUN` cases with:

```c
        case PHASE_STORY_LOAD:
            intro_story_load();
            goto_phase(PHASE_STORY_RUN);
            break;

        case PHASE_STORY_RUN:
            intro_story_step();
            if (intro_story_at_end()) {
                intro_story_clear_end();
                goto_phase(PHASE_TITLE_LOAD);
            }
            break;
```

And remove the temporary `BLACK_HOLD → TITLE_LOAD` shortcut from Task 4 — change it to `goto_phase(PHASE_STORY_LOAD)`:

```c
        case PHASE_BLACK_HOLD:
            s_phase_counter++;
            if (s_phase_counter >= BLACK_HOLD_FRAMES) {
                goto_phase(PHASE_STORY_LOAD);
            }
            break;
```

- [ ] **Step 6: Delete stub showcase files**

```bash
git rm src/intro_showcase.c src/intro_showcase.h
```

- [ ] **Step 7: Update `build.bat`**

In `build.bat:108`, remove `intro_showcase` from `C_SOURCES`.

In `build.bat:109`, append the new gen sources: `intro_common_bg_chr intro_sprite_chr intro_misc_chr intro_punct_chr intro_blink_chr intro_combined_palette intro_treasures_tilemap`.

- [ ] **Step 8: Build**

Run: `./build.bat`

Expected: extraction emits new gen files; gcc compiles clean; ld links without unresolved symbols.

If `intro_story_tilemap` references look wrong (e.g. wrong row count), verify `tools/extract_intro_assets.py` story-tilemap composition matches `tools/intro_demo/compose_story_tilemap.py`.

- [ ] **Step 9: Boot in BizHawk and verify full loop**

Launch ROM. Expected over ~30 seconds:

- t=0-7s: title with waterfall + glow
- t=7-10s: 14-cycle fade-out
- t=10-13s: black hold
- t=13s: story screen loads (text "Many years ago..." palette appears)
- t=13-25s: text scrolls up; heart, fairy, rupee, triforce items appear and flash via palette toggles
- t=25-28s: end pause
- t=28s: loop back to title

RAM-watch `$FF07F0` cycles through all 6 phase values.

- [ ] **Step 10: Commit**

```bash
git add tools/extract_intro_assets.py src/gen/intro_*.c \
        src/intro_story.c src/intro_story.h src/intro_phase.c build.bat
git rm src/intro_showcase.c src/intro_showcase.h
git commit -m "$(cat <<'EOF'
intro: story+items continuous scroll in main ROM; full loop wired

Lifts story_runtime.{c,h} from tools/intro_demo (renamed to intro_story).
PHASE_STORY_RUN handles story text + items as one continuous vertical
scroll, with item-flash sprite-pal toggles per pixel-count windows.
Black hold now flows to story instead of looping back. Stub
intro_showcase.{c,h} deleted — items handled by intro_story.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Update `tools/intro_demo/build.bat` to compile from `src/`

**Files:**
- Modify: `tools/intro_demo/build.bat`

**Goal:** Standalone smoke ROM uses the same source files as main ROM. Drift impossible.

- [ ] **Step 1: Audit current `tools/intro_demo/build.bat` source list**

Run: `grep -n "main.c\|intro_phase.c\|intro_title.c\|story_runtime.c\|intro_demo/" tools/intro_demo/build.bat`

Expected: lines compiling each from `tools/intro_demo/`. Note line numbers.

- [ ] **Step 2: Replace those compile commands to source from `src/`**

For each of the lifted files (`intro_phase.c`, `intro_title.c`, `story_runtime.c` → `src/intro_story.c`), change the `-c "%DEMO_DIR%\<name>.c"` argument to `-c "%ROOT%\src\<name>.c"`.

The intro_demo `main.c` stays in `tools/intro_demo/` because it's the standalone-ROM-only entry (different from `src/intro_main.c`, which is called from `genesis_shell.asm`).

Update the `story_runtime.c` reference to `intro_story.c` and ensure the include path picks up `src/intro_story.h` (the file path differs by name).

- [ ] **Step 3: Build the standalone smoke ROM**

Run: `tools/intro_demo/build.bat`

Expected: build succeeds. Output ROM at `tools/intro_demo/out/intro_demo.md`.

- [ ] **Step 4: Boot smoke ROM in BizHawk**

Expected: identical behavior to before promotion (title + fade + story + items + loop).

- [ ] **Step 5: Verify no source duplication remains**

Run: `diff src/intro_phase.c tools/intro_demo/intro_phase.c`

Expected: files identical (or ENOENT on the intro_demo side if the file was already deleted in Task 3-5 cleanup).

If the intro_demo copies still exist, delete them:

```bash
git rm tools/intro_demo/intro_phase.c tools/intro_demo/intro_phase.h
git rm tools/intro_demo/intro_title.c tools/intro_demo/intro_title.h
git rm tools/intro_demo/story_runtime.c tools/intro_demo/story_runtime.h
```

- [ ] **Step 6: Commit**

```bash
git add tools/intro_demo/build.bat
git rm tools/intro_demo/intro_phase.c tools/intro_demo/intro_phase.h \
       tools/intro_demo/intro_title.c tools/intro_demo/intro_title.h \
       tools/intro_demo/story_runtime.c tools/intro_demo/story_runtime.h
git commit -m "$(cat <<'EOF'
intro_demo: compile from src/ — single source of truth

Standalone intro_demo build now sources intro_phase, intro_title,
intro_story from src/. Local copies deleted to prevent drift.
intro_demo/main.c stays as the standalone-ROM entry.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Resolve handoff TBDs (research-only, no code)

**Files:**
- Create: `docs/superpowers/specs/2026-04-26-native-intro-handoff-tbds.md`

**Goal:** Identify the five TBDs the spec flagged so Task 8-10 can write actual code instead of placeholders. NO CODE in this task — only documentation. Block Tasks 8-10 on this being committed.

- [ ] **Step 1: Identify `MODE_FILESELECT` value**

Run: `grep -rn "Mode_FileSelect\|MODE_FILE_SELECT\|MODE_REGISTER\|file_select" reference/aldonunez/asm/`

Expected: a constant definition in NES disasm, e.g. `Mode_RegisterMenu = $05`. Note the exact value.

If not found in `reference/aldonunez/asm/`, check `src/zelda_translated/z_07.asm` and `src/zelda_translated/z_02.asm`:

Run: `grep -n "GameMode\|game_mode\|cmpi.b #\$0[0-9],.*GAMEMODE" src/zelda_translated/z_02.asm`

Document the value in the new spec file.

- [ ] **Step 2: Identify file-select RAM contract bytes**

Read `src/intro_handoff.c:24-32` (existing `intro_handoff` C body). It already documents the RAM byte set the legacy attract-loop uses to return to title. Cross-reference with NES disasm to figure out what file-select expects fresh on cold-entry (likely a SUPERSET of these bytes).

Document each required RAM offset and value:

| NES RAM offset | Symbol | Value on entry | Source |
|---|---|---|---|
| $00 | PPU_CTRL shadow | $80 | NES NMI gate |
| $... | GameMode | MODE_FILESELECT | NES disasm |
| $... | Submode | $00 | NES disasm |
| $042B | front_start_release_gate | $01 | intro_handoff.c:29 |
| $042C | frontend_demo_phase | $00 | intro_handoff.c:27 |
| $042D | frontend_demo_subphase | $00 | intro_handoff.c:28 |
| $0528 | frontend_delay_timer | $00 | intro_handoff.c:31 |
| $083D | vram_force_blank_gate | $00 | intro_handoff.c:30 |

Resolve each `$...`. Note GameMode and Submode addresses (likely $0... range; check `src/intro_handoff.h`'s `intro_handoff_state_t` struct field comments and grep `_GAMEMODE` in src/).

- [ ] **Step 3: Identify `translated_mainloop_reentry` symbol**

Read `src/zelda_translated/z_07.asm` around line 1448 (RunGame body) and find the post-init main loop label. Candidates: `_LoopForever`, `_main_loop`, or the label immediately after the `RunGame` `MMC1` setup.

Look for a re-entry point that runs mode dispatch on each frame. The translated NES `RunGame` typically calls `UpdateMode_n` based on `GAMEMODE` byte. We want the symbol that dispatches on GAMEMODE (so setting GAMEMODE=$05 picks file-select) and runs forever.

Run: `grep -n "_LoopForever\|_RunGame\|UpdateMode\|cmpi.b.*GAMEMODE" src/zelda_translated/z_07.asm`

Document the chosen symbol and verify it doesn't clobber A4/A5/D7 on entry.

- [ ] **Step 4: Identify file-select song bitmap**

Run: `grep -n "Song\|song\|music_play\|m_song_req" src/audio_driver.asm src/zelda_translated/z_02.asm | head -30`

Find the song bitmap value used when entering file select on NES. May be `$01`, `$02`, etc. — different bit per song. Document.

- [ ] **Step 5: Verify `_ppu_write_0` register-clobber behavior**

Read `src/nes_io.asm:283-340` (the full body). Confirm:

- A4 preserved (translated code contract)
- A5 preserved
- D7 preserved
- D0 modified (input/scratch)
- D1 modified (scratch)
- Other registers per the NT_CACHE rebuild path (which is gated on bit 4 change — bit 7 alone shouldn't trigger it)

Document the clobber list. If A4/A5/D7 might be clobbered, add a wrapper trampoline that pushes them.

- [ ] **Step 6: Write `docs/superpowers/specs/2026-04-26-native-intro-handoff-tbds.md`**

Document all 5 TBDs with values + line citations. Format:

```markdown
# Native Intro Handoff — TBD Resolution

Resolves the 5 TBDs flagged in `2026-04-26-native-intro-main-rom-design.md`
before implementation begins on Tasks 8-10.

## 1. MODE_FILESELECT value
Value: `$05` (Mode_RegisterMenu)
Source: `reference/aldonunez/asm/<file>.asm:<line>`

## 2. RAM contract
[table from Step 2]

## 3. translated_mainloop_reentry symbol
Symbol: `_LoopForever` (or actual)
Source: `src/zelda_translated/z_07.asm:<line>`
A4/A5/D7 contract on entry: [verified | restored by trampoline]

## 4. File-select song bitmap
Value: `$<XX>`
Source: `<file>:<line>`

## 5. _ppu_write_0 clobbers
Preserves: A4, A5, D7, [others]
Modifies: D0, D1, [others]
Source: `src/nes_io.asm:283-<end>`
```

- [ ] **Step 7: Commit**

```bash
git add docs/superpowers/specs/2026-04-26-native-intro-handoff-tbds.md
git commit -m "$(cat <<'EOF'
spec: resolve native intro handoff TBDs

Documents all 5 TBDs flagged by 2026-04-26-native-intro-main-rom-design:
MODE_FILESELECT value, RAM contract bytes, mainloop re-entry symbol,
file-select song bitmap, _ppu_write_0 register clobbers. Unblocks
Tasks 8-10 implementation.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Implement Start polling in `intro_main.c`

**Files:**
- Modify: `src/intro_main.c`
- Create: `src/intro_handoff.h` (replaces existing)
- Modify: `src/intro_handoff.c` (replaces body)

**Goal:** Detect Start press in any phase. C side handles VDP cleanup before calling the (still TBD) ASM trampoline. Trampoline itself comes in Task 9.

- [ ] **Step 1: Replace `src/intro_handoff.h`**

```c
/* src/intro_handoff.h
 *
 * Start press handoff from native intro to the transpiled file-select
 * path. C side handles VDP cleanup and probe markers, then calls the
 * ASM trampoline (intro_to_file_select_trampoline, defined in
 * genesis_shell.asm) which restores A4/A5/D7, seeds RAM contract,
 * re-enables NMI heartbeat, flips vblank_mode, and jumps to the
 * translated main loop.
 */
#ifndef INTRO_HANDOFF_H
#define INTRO_HANDOFF_H

void intro_start_pressed(void);   /* called by intro_main poll_start */

#endif
```

- [ ] **Step 2: Replace `src/intro_handoff.c`**

```c
/* src/intro_handoff.c
 *
 * C side of Start press handoff. Performs VDP cleanup so the screen
 * is in a known state (display off, planes blank, V64 mode, vscroll=0)
 * before the ASM trampoline restores the translated runtime register
 * contract and re-enables transpiled NMI handling.
 */
#include "intro_handoff.h"
#include "intro_common.h"   /* vdp_display_off, vdp_set_mode_v64, vdp_set_vscroll, vdp_write_nametable_row */
#include "nes_abi.h"

extern void intro_to_file_select_trampoline(void);   /* in genesis_shell.asm */

static void clear_plane(unsigned short plane_base) {
    unsigned short zero_row[32];
    unsigned short i;
    for (i = 0; i < 32; i++) zero_row[i] = 0;
    for (i = 0; i < 32; i++) {
        vdp_write_nametable_row(plane_base, i, zero_row);
    }
}

void intro_start_pressed(void) {
    nes_ram[0x07F2] = 0xAA;   /* probe: handoff begun */

    vdp_display_off();
    clear_plane(0xC000);
    clear_plane(0xE000);
    vdp_set_mode_v64();
    vdp_set_vscroll(0);

    /* Tail call into ASM trampoline. Trampoline does not return. */
    intro_to_file_select_trampoline();
}
```

- [ ] **Step 3: Add Start polling to `intro_main.c`**

Update `src/intro_main.c`:

```c
#include "intro_main.h"
#include "intro_phase.h"
#include "intro_handoff.h"
#include "nes_abi.h"

extern volatile unsigned long s_intro_frame_counter;

#define CTRL1_DATA  (*(volatile unsigned char *)0x00A10003)
#define CTRL1_CTRL  (*(volatile unsigned char *)0x00A10009)

#define BTN_START   0x20

static void wait_vblank(void) {
    unsigned long start = s_intro_frame_counter;
    while (s_intro_frame_counter == start) { /* spin */ }
}

static unsigned char read_controller_buttons(void) {
    /* TH high read = start/A/C/B */
    CTRL1_DATA = 0x40;
    /* small delay so the controller can latch */
    volatile int i;
    for (i = 0; i < 4; i++) {}
    unsigned char hi = ~CTRL1_DATA;
    /* Bit 5 = Start (with TH high) */
    return hi;
}

static unsigned char poll_start(unsigned short frame) {
    static unsigned char prev_start = 0;
    if (frame < 4u) {
        /* ignore controller cold-read junk */
        return 0;
    }
    unsigned char raw = read_controller_buttons();
    unsigned char start_now = (raw & BTN_START) ? 1 : 0;
    unsigned char pressed = (start_now && !prev_start);
    prev_start = start_now;
    return pressed;
}

void intro_main(void) {
    nes_ram[0x07FF] = 0xA1;
    nes_ram[0x07F1] = 0;
    nes_ram[0x07F2] = 0;
    intro_phase_init();

    unsigned short frame = 0;
    for (;;) {
        wait_vblank();
        nes_ram[0x07F1] = (unsigned char)(frame & 0xFF);
        intro_phase_step();
        if (poll_start(frame)) {
            intro_start_pressed();
            /* unreachable */
        }
        frame++;
    }
}
```

Confirm `0x00A10003`, `0x00A10009`, and `BTN_START = 0x20` against the existing controller-init code in genesis_shell.asm:392-396. Adjust if the actual bit assignment is different on this hardware target.

- [ ] **Step 4: Add a TEMPORARY no-op trampoline so build links**

In `src/genesis_shell.asm`, before the include of `audio_driver.asm`, add:

```asm
;==============================================================================
; intro_to_file_select_trampoline — STUB. Real body in Task 9.
; For Task 8 it just sets the handoff probe marker and stops, so we can
; verify Start press is detected and intro_start_pressed runs.
;==============================================================================
intro_to_file_select_trampoline:
    move.b  #$BB,($00FF07F2).l
    stop    #$2700
    bra.s   intro_to_file_select_trampoline
```

- [ ] **Step 5: Build**

Run: `./build.bat`

Expected: build succeeds. No unresolved-symbol errors for `intro_to_file_select_trampoline` or `intro_start_pressed`.

- [ ] **Step 6: Boot in BizHawk; verify Start detection in each phase**

Launch ROM. Watch `$FF07F2`:

- Boot: $00.
- Press Start during title (~t=2s): `$FF07F2` becomes `$AA` (intro_start_pressed entered) then `$BB` (stub trampoline reached). Screen turns black (display off).
- Soft-reset, press Start during fade (t=8s): same.
- Soft-reset, press Start during story (t=15s): same.
- Soft-reset, press Start during item visibility window (t=20s): same.

If `$FF07F2` stays at `$00` with Start held, debug controller read in `read_controller_buttons` (likely TH bit / mask issue).

- [ ] **Step 7: Commit**

```bash
git add src/intro_main.c src/intro_handoff.c src/intro_handoff.h src/genesis_shell.asm
git commit -m "$(cat <<'EOF'
intro: Start press detection + handoff stub trampoline

intro_main polls controller for Start press each frame (release-then-
press latch, ignores first 4 frames). On press, calls intro_start_pressed
which performs VDP cleanup then jumps to ASM trampoline. Trampoline is
a stub for Task 8 — sets probe marker then halts so we can verify the
end-to-end path before Task 9 wires the real handoff.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Implement real ASM `intro_to_file_select_trampoline`

**Files:**
- Modify: `src/genesis_shell.asm` (replace stub trampoline with real body)

**Goal:** Trampoline restores A4/A5/D7, seeds RAM contract, re-enables NMI heartbeat via `_ppu_write_0`, flips `vblank_mode`, jumps to translated main-loop re-entry. After Start press, the transpiled file-select path takes over.

**PREREQUISITE:** Task 7 must be complete. All values referenced below (`MODE_FILESELECT`, `GAMEMODE_OFFSET`, `SUBMODE_OFFSET`, `SONG_FILESELECT`, `translated_mainloop_reentry`) come from `docs/superpowers/specs/2026-04-26-native-intro-handoff-tbds.md`. **Substitute the documented values into the code below before building.**

- [ ] **Step 1: Replace the stub trampoline body in `genesis_shell.asm`**

Replace the Task 8 stub with this real body. Substitute `<TBD>` markers from the resolved spec:

```asm
;==============================================================================
; intro_to_file_select_trampoline — Start press handoff from native intro
; to transpiled file-select path.
;
; Preconditions (set by intro_handoff.c before calling):
;   - VDP display off, plane A/B blank, V64 mode, vscroll=0
;   - vblank_mode still = 0 (native NMI dispatcher; music_tick + counter)
;
; This trampoline:
;   1. Restores translated runtime register contract (A4/A5/D7).
;   2. Seeds NES RAM file-select entry contract (GameMode, Submode,
;      front_start_release_gate, frontend_demo_phase/subphase, etc.).
;   3. Re-enables transpiled NMI heartbeat via _ppu_write_0 with bit 7
;      set (updates both ($00FF,A4) and (PPU_CTRL).l mirrors).
;   4. Flips vblank_mode = 1 so VBlankISR routes to the transpiled path
;      starting next frame.
;   5. Jumps (not jsr) to translated main-loop re-entry symbol.
;
; Does NOT return.
;==============================================================================
intro_to_file_select_trampoline:
    move.b  #$BB,($00FF07F2).l       ; probe: trampoline entered

    ; [1] Restore translated runtime register contract.
    move.l  #$00FF0000,A4
    move.l  #$00FF0200,A5
    moveq   #-1,D7

    ; [2] Seed file-select entry RAM contract.
    ; Substitute values from handoff-tbds spec:
    move.b  #<MODE_FILESELECT>,(<GAMEMODE_ABS_ADDR>).l
    move.b  #0,(<SUBMODE_ABS_ADDR>).l
    move.b  #0,($00FF042C).l         ; frontend_demo_phase
    move.b  #0,($00FF042D).l         ; frontend_demo_subphase
    move.b  #1,($00FF042B).l         ; front_start_release_gate (Start consumed)
    move.b  #0,($00FF083D).l         ; vram_force_blank_gate
    move.b  #0,($00FF0528).l         ; frontend_delay_timer

    ; Optional: request file-select song. Skip if intro music already
    ; matches what file-select expects.
    move.b  #<SONG_FILESELECT_BITMAP>,($00FF0600).l   ; SongRequest bridge

    ; [3] Re-enable translated NMI heartbeat: PPUCTRL bit 7 = 1.
    ; _ppu_write_0 updates both ($00FF,A4) gameplay mirror AND
    ; (PPU_CTRL).l absolute mirror (per nes_io.asm:283).
    move.b  ($00FF,A4),D0            ; current PPUCTRL bits
    ori.b   #$80,D0                  ; bit 7 = NMI enable
    bsr     _ppu_write_0             ; preserves A4/A5/D7 per Task 7 spec

    ; [4] Flip dispatcher to transpiled path.
    move.b  #1,(vblank_mode).l

    ; [5] Resume translated main loop. Does not return.
    jmp     <translated_mainloop_reentry>
```

Replace `<MODE_FILESELECT>`, `<GAMEMODE_ABS_ADDR>`, `<SUBMODE_ABS_ADDR>`, `<SONG_FILESELECT_BITMAP>`, and `<translated_mainloop_reentry>` with the concrete values from `docs/superpowers/specs/2026-04-26-native-intro-handoff-tbds.md`.

- [ ] **Step 2: Build**

Run: `./build.bat`

Expected: build succeeds. No unresolved-symbol errors.

- [ ] **Step 3: Boot in BizHawk; verify Start press lands in file-select**

Launch ROM. Wait for title (~t=2s). Press Start. Watch:

- `$FF07F2` = `$BB` (trampoline ran)
- `$FF0FFC` (vblank_mode) = `$01` (transpiled dispatcher active)
- `$FF0804` (PPU_CTRL) bit 7 set
- Screen: file-select UI renders (or whatever the transpiled file-select path produces)

If file-select UI does NOT render but vblank_mode flipped correctly, the failure is in the transpiled file-select cold-start path, not the handoff. That's tracked separately as Layer 3b in the spec — does not block intro merge.

If `$FF07F2` reaches `$BB` but `$FF0FFC` stays at `$00`, the `move.b #1,(vblank_mode).l` line is failing — debug.

- [ ] **Step 4: Commit**

```bash
git add src/genesis_shell.asm
git commit -m "$(cat <<'EOF'
asm: real intro_to_file_select_trampoline

Restores translated runtime register contract (A4/A5/D7), seeds NES RAM
file-select entry contract bytes, re-enables transpiled NMI via
_ppu_write_0 with bit 7 set, flips vblank_mode to transpiled path,
jumps to translated main-loop re-entry. Does not return.

Substitutes concrete values from
docs/superpowers/specs/2026-04-26-native-intro-handoff-tbds.md.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Layer 1 RAM probe test + build-step gate

**Files:**
- Create: `tools/intro_test/probe_phase_sequence.lua`
- Create: `tools/intro_test/check_probe_sequence.py`
- Modify: `build.bat` (add post-link probe step)

**Goal:** BizHawk Lua boots ROM headlessly (or in --quit-after mode), runs N frames, dumps phase byte sequence to CSV. Python script asserts sequence matches expected. Build fails on mismatch.

- [ ] **Step 1: Write `tools/intro_test/probe_phase_sequence.lua`**

```lua
-- probe_phase_sequence.lua
-- Boots ROM, runs 4000 frames, samples nes_ram[$07F0..$07F3] every 60
-- frames, writes CSV to tools/intro_test/out/phase_sequence.csv.
-- Outputs done marker so the harness can detect completion.

local OUT_DIR  = "tools/intro_test/out"
local OUT_PATH = OUT_DIR .. "/phase_sequence.csv"
local TOTAL_FRAMES   = 4000
local SAMPLE_EVERY   = 60

os.execute('mkdir "' .. OUT_DIR .. '" 2>nul')

local f = io.open(OUT_PATH, "w")
f:write("frame,phase,frame_lo,handoff,substate\n")

local frame = 0
while frame <= TOTAL_FRAMES do
    if (frame % SAMPLE_EVERY) == 0 then
        local p  = memory.readbyte(0xFF07F0, "M68K BUS")
        local fr = memory.readbyte(0xFF07F1, "M68K BUS")
        local hf = memory.readbyte(0xFF07F2, "M68K BUS")
        local ss = memory.readbyte(0xFF07F3, "M68K BUS")
        f:write(string.format("%d,%d,%d,%d,%d\n", frame, p, fr, hf, ss))
    end
    emu.frameadvance()
    frame = frame + 1
end

f:close()

-- Done marker so the harness knows the run completed.
local d = io.open(OUT_DIR .. "/phase_sequence.done", "w")
d:write("ok")
d:close()

client.exit()
```

The exact `memory.readbyte` API depends on BizHawk version. If `"M68K BUS"` isn't recognized, try `"68K Bus"` or look up the right domain name in `tools/bizhawk_capture_intro_sequence.lua` for an example that already works in this repo.

- [ ] **Step 2: Write `tools/intro_test/check_probe_sequence.py`**

```python
#!/usr/bin/env python3
"""Asserts phase byte sequence in the probe CSV matches expected.

Expected progression after boot:
  PHASE_TITLE_LOAD (0)
  PHASE_TITLE_DISPLAY (1)  for ~400 frames
  PHASE_TITLE_FADEOUT (2)  for ~230 frames (14 cycles)
  PHASE_BLACK_HOLD (3)     for 180 frames
  PHASE_STORY_LOAD (4)
  PHASE_STORY_RUN (5)      for ~750+ frames
  loop to PHASE_TITLE_LOAD

The probe samples every 60 frames so transient phases (TITLE_LOAD,
STORY_LOAD) may not be captured every loop; the test allows them.

Fails build with non-zero exit on mismatch.
"""
import csv
import sys
from pathlib import Path

CSV_PATH = Path("tools/intro_test/out/phase_sequence.csv")
DONE_PATH = Path("tools/intro_test/out/phase_sequence.done")

ALLOWED = {0, 1, 2, 3, 4, 5}

def main() -> int:
    if not DONE_PATH.exists():
        print(f"FAIL: {DONE_PATH} missing — probe run did not complete")
        return 1
    if not CSV_PATH.exists():
        print(f"FAIL: {CSV_PATH} missing")
        return 1

    rows = list(csv.DictReader(CSV_PATH.open()))
    if len(rows) < 30:
        print(f"FAIL: only {len(rows)} samples — expected ~67")
        return 1

    # Every observed phase must be in the allowed set.
    for r in rows:
        p = int(r["phase"])
        if p not in ALLOWED:
            print(f"FAIL: frame {r['frame']} reports unknown phase {p}")
            return 1

    # We must observe at least one of each phase across the 4000-frame run.
    seen = {int(r["phase"]) for r in rows}
    for required in (1, 2, 3, 5):    # TITLE_DISPLAY, TITLE_FADEOUT, BLACK_HOLD, STORY_RUN
        if required not in seen:
            print(f"FAIL: phase {required} never observed in probe sequence")
            print("  observed phases:", sorted(seen))
            return 1

    # We must observe a loop: at least two TITLE_DISPLAY samples separated
    # by a STORY_RUN sample.
    phases = [int(r["phase"]) for r in rows]
    title_idxs = [i for i, p in enumerate(phases) if p == 1]
    story_idxs = [i for i, p in enumerate(phases) if p == 5]
    looped = any(s_i < t_i for s_i in story_idxs for t_i in title_idxs[1:])
    if not looped:
        print("FAIL: no loop — story phase never followed by title phase again")
        print("  phases:", phases)
        return 1

    print(f"OK: phase sequence valid across {len(rows)} samples; "
          f"observed {sorted(seen)}, loop confirmed")
    return 0

if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 3: Create the `tools/intro_test/out/` directory**

```bash
mkdir -p tools/intro_test/out
```

Add a `.gitignore` so probe outputs don't get committed:

```bash
cat > tools/intro_test/out/.gitignore <<EOF
*
!.gitignore
EOF
```

- [ ] **Step 4: Add probe-run step to `build.bat`**

After the existing `[4/4] Archiving build...` step (around line 167), but before the git auto-commit at line 197, insert:

```bat
echo [5/5] Running phase-sequence probe...
del /q "%ROOT%\tools\intro_test\out\phase_sequence.csv" 2>nul
del /q "%ROOT%\tools\intro_test\out\phase_sequence.done" 2>nul
"%BIZHAWK_EXE%" --lua="%ROOT%\tools\intro_test\probe_phase_sequence.lua" "%OUT_ROM%"
"%PYTHON%" "%ROOT%\tools\intro_test\check_probe_sequence.py"
if errorlevel 1 (
    echo [5/5] FAIL: probe sequence assertion failed
    exit /b 1
)
echo [5/5] OK: phase probe passed
```

Where `%BIZHAWK_EXE%` is the same launcher used by other build-time test hooks. If no other build-time BizHawk hook exists yet, define it at the top of build.bat alongside `%PYTHON%` and `%VASM%`:

```bat
set "BIZHAWK_EXE="
if exist "C:\BizHawk\EmuHawk.exe" set "BIZHAWK_EXE=C:\BizHawk\EmuHawk.exe"
if exist "%LOCALAPPDATA%\BizHawk\EmuHawk.exe" set "BIZHAWK_EXE=%LOCALAPPDATA%\BizHawk\EmuHawk.exe"
if "%BIZHAWK_EXE%"=="" (
    echo WARNING: BizHawk not found — skipping intro probe
) else (
    rem ... probe step here ...
)
```

(Adjust the search paths to match where the user's BizHawk install lives — see the bizhawkScript skill memory for the exact path used by other capture scripts in this repo.)

- [ ] **Step 5: Build and run**

Run: `./build.bat`

Expected: build succeeds, BizHawk launches, runs 4000 frames headlessly, exits, Python check reports `OK: phase sequence valid...`.

If BizHawk window stays open after frame 4000, `client.exit()` may not be supported — change to `client.SetSpeedPercent(1000); ... client.exit()` or use `--quit-after` flag.

If Python reports failure, inspect `tools/intro_test/out/phase_sequence.csv` to see which phase byte was unexpected.

- [ ] **Step 6: Commit**

```bash
git add tools/intro_test/probe_phase_sequence.lua \
        tools/intro_test/check_probe_sequence.py \
        tools/intro_test/out/.gitignore \
        build.bat
git commit -m "$(cat <<'EOF'
test: Layer 1 phase-sequence probe gates main ROM build

BizHawk Lua boots ROM, samples nes_ram[$07F0..$07F3] every 60 frames
for 4000 frames, dumps to CSV. Python check_probe_sequence.py asserts
all expected phases observed and loop completes. Build fails on mismatch.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Layer 3a Start handoff smoke test

**Files:**
- Create: `tools/intro_test/probe_start_handoff.lua`
- Create: `tools/intro_test/check_handoff_contract.py`
- Create: `tools/intro_test/run_full.bat`

**Goal:** Per-phase Start press injection. Asserts trampoline ran, vblank_mode flipped, RAM contract bytes match expected. NOT in build.bat (slower, ~2 min); manual via `run_full.bat`.

- [ ] **Step 1: Write `tools/intro_test/probe_start_handoff.lua`**

```lua
-- probe_start_handoff.lua
-- Runs ROM 4 times. Each run injects Start press at a different phase
-- timestamp: title-display (frame 60), fadeout (frame 480), story-run
-- (frame 900), late-story (frame 1500). After each press, runs 120
-- more frames then samples handoff state to CSV.

local SCENARIOS = {
    {name="title_display", press_frame=60},
    {name="fadeout",       press_frame=480},
    {name="story_run",     press_frame=900},
    {name="late_story",    press_frame=1500},
}

local OUT_DIR = "tools/intro_test/out"
os.execute('mkdir "' .. OUT_DIR .. '" 2>nul')

-- Read which scenario to run from a sentinel file (since each BizHawk
-- launch is one scenario). The wrapper batch file writes the index.
local idx_file = io.open(OUT_DIR .. "/scenario.idx", "r")
local idx = tonumber(idx_file:read("*l"))
idx_file:close()
local scn = SCENARIOS[idx]

local frame = 0
local press_done = false
while frame <= scn.press_frame + 120 do
    if frame == scn.press_frame and not press_done then
        joypad.set({Start=true}, 1)
        press_done = true
    elseif frame == scn.press_frame + 1 then
        joypad.set({Start=false}, 1)
    end
    emu.frameadvance()
    frame = frame + 1
end

-- Sample handoff state.
local out_csv = io.open(OUT_DIR .. "/handoff_" .. scn.name .. ".csv", "w")
out_csv:write("name,handoff_marker,vblank_mode,ppuctrl,gamemode,a4_low\n")
out_csv:write(string.format("%s,%d,%d,%d,%d,%d\n",
    scn.name,
    memory.readbyte(0xFF07F2, "M68K BUS"),
    memory.readbyte(0xFF0FFC, "M68K BUS"),
    memory.readbyte(0xFF0804, "M68K BUS"),
    memory.readbyte(0xFFXXXX, "M68K BUS"),  -- substitute GAMEMODE addr from handoff-tbds spec
    0
))
out_csv:close()

local d = io.open(OUT_DIR .. "/handoff_" .. scn.name .. ".done", "w")
d:write("ok")
d:close()

client.exit()
```

Substitute `0xFFXXXX` with the GAMEMODE absolute address from `docs/superpowers/specs/2026-04-26-native-intro-handoff-tbds.md`.

- [ ] **Step 2: Write `tools/intro_test/check_handoff_contract.py`**

```python
#!/usr/bin/env python3
"""Asserts each handoff scenario satisfies the contract:
  - handoff_marker == 0xBB (trampoline ran)
  - vblank_mode == 1 (transpiled dispatcher active)
  - ppuctrl bit 7 set (NMI enabled)
  - gamemode == MODE_FILESELECT (substitute value)
"""
import csv
import sys
from pathlib import Path

OUT_DIR = Path("tools/intro_test/out")

# Substitute from handoff-tbds spec
MODE_FILESELECT = 0x05  # CHANGE THIS

SCENARIOS = ["title_display", "fadeout", "story_run", "late_story"]

def check_one(name: str) -> bool:
    csv_path = OUT_DIR / f"handoff_{name}.csv"
    if not csv_path.exists():
        print(f"FAIL [{name}]: csv missing")
        return False
    row = next(csv.DictReader(csv_path.open()))
    ok = True
    if int(row["handoff_marker"]) != 0xBB:
        print(f"FAIL [{name}]: handoff_marker = {int(row['handoff_marker']):#x}, expected 0xBB")
        ok = False
    if int(row["vblank_mode"]) != 1:
        print(f"FAIL [{name}]: vblank_mode = {row['vblank_mode']}, expected 1")
        ok = False
    if (int(row["ppuctrl"]) & 0x80) == 0:
        print(f"FAIL [{name}]: ppuctrl = {int(row['ppuctrl']):#x}, bit 7 not set")
        ok = False
    if int(row["gamemode"]) != MODE_FILESELECT:
        print(f"FAIL [{name}]: gamemode = {int(row['gamemode']):#x}, expected {MODE_FILESELECT:#x}")
        ok = False
    if ok:
        print(f"OK   [{name}]")
    return ok

def main() -> int:
    all_ok = True
    for s in SCENARIOS:
        if not check_one(s):
            all_ok = False
    return 0 if all_ok else 1

if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 3: Write `tools/intro_test/run_full.bat`**

```bat
@echo off
setlocal EnableExtensions
for %%I in ("%~dp0..\..") do set "ROOT=%%~fI"

set "OUT_DIR=%ROOT%\tools\intro_test\out"
if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

set "BIZHAWK_EXE=<same as build.bat>"
set "PYTHON=<same as build.bat>"
set "OUT_ROM=%ROOT%\builds\whatif.md"

for %%S in (1 2 3 4) do (
    echo [run_full] scenario %%S
    del /q "%OUT_DIR%\handoff_*.csv" 2>nul
    del /q "%OUT_DIR%\handoff_*.done" 2>nul
    echo %%S > "%OUT_DIR%\scenario.idx"
    "%BIZHAWK_EXE%" --lua="%ROOT%\tools\intro_test\probe_start_handoff.lua" "%OUT_ROM%"
)

"%PYTHON%" "%ROOT%\tools\intro_test\check_handoff_contract.py"
exit /b %errorlevel%
```

Substitute `<same as build.bat>` with the actual paths. Or copy the Python/BizHawk locator block from build.bat.

- [ ] **Step 4: Run the smoke test**

```bash
tools/intro_test/run_full.bat
```

Expected: 4 BizHawk launches, each with a different press frame. Final Python check prints `OK [<name>]` for each scenario.

- [ ] **Step 5: Commit**

```bash
git add tools/intro_test/probe_start_handoff.lua \
        tools/intro_test/check_handoff_contract.py \
        tools/intro_test/run_full.bat
git commit -m "$(cat <<'EOF'
test: Layer 3a Start handoff contract smoke test

Per-phase Start press injection (title display, fadeout, story run,
late story) verifies trampoline ran, vblank_mode flipped, PPUCTRL bit 7
set, GAMEMODE = MODE_FILESELECT. Manual run via tools/intro_test/run_full.bat
(too slow for build.bat). Layer 3b full file-select smoke not included
— that's blocked on transpiled file-select cold-start, separate concern.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Verify intro_demo standalone build still passes Layer 1 + Layer 2

**Files:** none modified; verification only.

**Goal:** Confirm the `tools/intro_demo/build.bat` smoke ROM still works after all promotion. Catches drift introduced by Tasks 4-6.

- [ ] **Step 1: Build standalone smoke ROM**

Run: `tools/intro_demo/build.bat`

Expected: succeeds. Output at `tools/intro_demo/out/intro_demo.md`.

- [ ] **Step 2: Run Layer 1 probe against smoke ROM**

```bash
cp tools/intro_demo/out/intro_demo.md /tmp/probe_target.md
# Or modify probe_phase_sequence.lua to take ROM as an argument; details depend
# on BizHawk's lua frontend.
```

Run the same `probe_phase_sequence.lua` against `intro_demo.md`. Assert phase sequence completes — same expectations as main ROM, since they share `src/intro_phase.c`.

- [ ] **Step 3: Run Layer 2 golden frame compare against smoke ROM**

Use the existing `tools/intro_demo/cmp/` harness (the comparison logic was already proven in commits up to 04fc0974). Boot smoke ROM, capture every 5 frames over 4000 frames, compare against `tools/intro_demo/nes_loop/` using SSIM threshold (not byte-identical).

Document the SSIM threshold chosen (e.g. 0.95). If a frame falls below threshold, investigate visual regression introduced by promotion.

- [ ] **Step 4: Commit any tooling glue needed**

If new helper scripts were needed (e.g. SSIM comparator), commit them:

```bash
git add tools/intro_test/<new files if any>
git commit -m "$(cat <<'EOF'
test: Layer 2 golden frame compare vs intro_demo NES capture

SSIM-based pixel comparison (threshold 0.95) between Genesis intro_demo
and NES intro capture at tools/intro_demo/nes_loop/. Confirms
src/intro_*.c promotion didn't introduce visual regression.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review Checklist (run after writing the plan)

**Spec coverage:**
- [x] Reset path replacement (Task 2)
- [x] vblank_mode dispatcher (Task 1)
- [x] Phase machine (Tasks 3-5)
- [x] Item flash via FrameCounter bit 3 (Task 5; lifted from intro_demo which already has it)
- [x] Story scroll = 0.5 px/frame (Task 5; lifted, `s_tick ^= 1` gate)
- [x] Title music = $80 (Task 2; intro_main calls `music_play(0x80)` at boot)
- [x] Start handoff trampoline (Task 9)
- [x] PPU_CTRL both-mirrors via _ppu_write_0 (Task 9)
- [x] Layer 1 RAM probes (Task 10)
- [x] Layer 3a handoff contract (Task 11)
- [x] Layer 2 golden frame compare (Task 12)
- [x] Single-source-of-truth (Task 6)

**Placeholder scan:** No "TODO", "TBD" in steps (the Task 7 spec file documents TBDs intentionally). Task 9 has `<MODE_FILESELECT>` style markers but they're explicitly flagged as substituted from Task 7's resolved spec.

**Type/name consistency:** intro_demo's `story_runtime_*` functions are renamed to `intro_story_*` in Task 5 — usage in Task 5 Step 5 matches. `vblank_mode` symbol consistently `(vblank_mode).l` in ASM and never touched in C. `s_intro_frame_counter` consistently `extern volatile unsigned long`.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-26-native-intro-main-rom.md`. Two execution options:

**1. Subagent-Driven (recommended)** — Dispatch a fresh subagent per task, review between tasks, fast iteration. Best for a 12-task plan where each task is independently testable.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints. Heavier on context but faster handoff between tasks.

Which approach?
