# Native File Select Rewrite — Design

**Status:** Draft.
**Branch:** TBD (suggest `feat/native-file-select`).
**Predecessor specs:** `2026-04-26-native-intro-main-rom-design.md` (architectural model), `2026-04-24-intro-native-rewrite-design.md` (intro_demo proof pattern).

## Goal

Replace the transpiled (6502→M68K) File Select Screen 1 with a native M68K/C implementation. Match Zelda Redux look exactly (Link palette per save state, NAME tile shift, heart row flip, dash tile reuse). Add two new menu rows below ERASE SAVE: **PLAYERS** (1-4 cycle, global SRAM byte, future co-op consumer) and **OPTIONS** (sub-menu exposing 16 condensed Redux features as toggles/radios with working-copy commit semantics).

Native FS Screen 2 is **out of scope**. Game Over → FS and save-and-quit → FS paths stay transpiled (deferred future spec). Only the intro Start press handoff to FS gets native treatment in v1 main-ROM landing.

## Decisions

Recorded from brainstorm:

| # | Decision |
|---|---|
| Q1 | Standalone proof ROM at `tools/file_select_demo/` first, promote `src/fs_*.c` to main ROM after. Mirrors intro_demo pattern. |
| Q2 | PLAYERS = global SRAM byte (1-4). Future co-op feature consumer; engine wiring deferred. |
| Q3 | OPTIONS contents = 16 condensed Redux features (see SRAM schema). LOW HEALTH WARNING was the seed feature, expanded to full Redux options menu. |
| Q4 | Linear-column nav. Cursor visits 7 stops: slot1, slot2, slot3, COPY SAVE, ERASE SAVE, PLAYERS, OPTIONS. |
| Q5 | PLAYERS row interaction = inline left/right cycle. No popup. |
| Q6 | OPTIONS submenu = single page with inline category headers (GRAPHICS / AUDIO / COMBAT / GAMEPLAY). Cursor skips headers. |
| Q7 | Save semantics = working copy in RAM. B from any row commits + exits. A on SAVE row commits + exits. No revert path. |
| Q8 | Main-ROM v1 entry = intro Start press only. Game Over / save-and-quit deferred. |
| Q9 | SRAM = NES save slots untouched at original offsets, OPTIONS bytes in fresh region $7000+. PLAYERS = global byte. |
| Q10 | Slot pick handoff = empty → transpiled register-name, saved → transpiled gameplay (NES original behavior). |
| Q11 | Cursor = single heart sprite, sits on selected row (slot rows AND action rows). Link brightness palette = preserve Redux byte-exact (`$0F,$29,$27,$17` saved / dim variants empty per `Zelda1-Redux/src/code/menus/file_select.asm:75`). |
| Q12 | FS music = same NES FS song bitmap. Exact value TBD plan-write. |
| Q13 | Iterative landing v1→v6 (see Sequencing). |
| Q14 | Defaults: PLAYERS=1, all OPTIONS = REDUX (first listed value), AUTOMAP=ON, DUNGEON COLR=ON. |
| Q15 | Engine wiring v1 = store-only for 14 of 16 OPTIONS. Wire 2 rows end-to-end as proof: LOW HP SFX, AUTOMAP. Other 14 wire as per-feature follow-on specs. |
| Q16 | COPY/ERASE flow = preserve Redux exactly (prompt source, prompt dest, commit). |
| App | Approach 2: phase-machine module split, mirrors intro pattern. |

## Architecture

### Reset / boot integration

**Proof ROM** (`tools/file_select_demo/`):
- New `tools/file_select_demo/boot.asm` — VDP/RAM init, IPL lower, `jsr fs_main`. Mirrors `tools/intro_demo/boot.asm`.
- New `tools/file_select_demo/build.bat` — compile `src/fs_*.c` + own boot, link own ROM. **No code duplication** with main ROM.
- Mock SRAM init: proof ROM ships with one occupied test slot (name "TESTLINK", 8 hearts) and two empty slots so visual differentiation between bright/dim Link is testable from frame 1.

**Main ROM (v6)**:
- `vblank_mode` dispatcher pattern from intro spec stays unchanged.
- New `.bss` byte `fs_native_active` next to `vblank_mode` (and other named RAM-map symbols per intro spec). 0 = transpiled FS reachable via legacy path (unused after v6 lands), 1 = native FS owns FS-mode dispatch. Seeded by `intro_handoff` flow before transferring control.
- `src/intro_handoff.c:intro_start_pressed` modified: instead of `intro_to_file_select_trampoline()` (which jumps into transpiled FS), calls `fs_main()` (native).
- ASM trampoline `intro_to_file_select_trampoline` becomes dead in main ROM. Symbol kept linkable per intro spec drain policy. Physical removal handled in future drain spec.
- Native `fs_main` runs phase loop. On slot pick (FS_HANDOFF phase), calls new ASM trampoline `fs_to_transpiled_trampoline` which restores translated runtime register contract, seeds NES RAM contract for register-name OR gameplay mode, flips `vblank_mode=1`, jumps to `translated_mainloop_reentry`.

### VBlank model

**Proof ROM**: `boot.asm` installs minimal VBlank handler that ticks `s_fs_frame_counter` longword and calls `music_tick`. No translated `IsrNmi` plumbing needed.

**Main ROM (v6)**: reuses intro spec dispatcher. Native path (`vblank_mode=0`) ticks `s_fs_frame_counter` (sharing the symbol with intro is OK — intro phase is already done by the time FS runs).

### Phase machine

```
fs_main:
    fs_init()                       ; load SRAM, render static layout, music start
    s_fs_phase = FS_NAV
    for (;;) {
        wait_vblank();              ; spin on s_fs_frame_counter
        fs_phase_step();            ; dispatch on s_fs_phase
        fs_input_poll();            ; latch + dispatch input
    }

phases (s_fs_phase byte values, also written to nes_ram[$07F0] as probe):
    FS_LOAD              ; one-shot: render static UI, draw all slots, init cursor
    FS_NAV               ; D-Pad up/down moves cursor, A/Start = action per row,
                         ; D-Pad L/R only when cursor on PLAYERS row (inline cycle,
                         ; not its own phase)
    FS_COPY_SRC          ; COPY pressed, prompt "select source slot"
    FS_COPY_DST          ; source picked, prompt "select dest slot"
    FS_ERASE_PICK        ; ERASE pressed, prompt "select slot to erase"
    FS_ERASE_CONFIRM     ; "are you sure?" Redux flow
    FS_OPTIONS           ; submenu loop (own internal sub-state for nav/edit/commit)
    FS_HANDOFF           ; trampoline to register-name or gameplay
```

### RAM contract

Named `.bss` symbols (all zero-initialized):

| Symbol | Type | Purpose |
|---|---|---|
| `s_fs_frame_counter` | `volatile uint32_t` | VBlank-ticked, drives `wait_vblank` spin |
| `s_fs_phase` | `uint8_t` | Current phase value (also probe `nes_ram[$07F0]`) |
| `s_fs_cursor` | `uint8_t` | 0..6 (slot1, slot2, slot3, COPY, ERASE, PLAYERS, OPTIONS) |
| `s_fs_options_cursor` | `uint8_t` | 0..N row index in OPTIONS submenu |
| `s_fs_options_working[N_OPTIONS]` | `uint8_t[]` | Working copy of OPTIONS values, loaded at FS_OPTIONS enter, committed on B/SAVE-row exit. `N_OPTIONS = 16`. |
| `s_fs_players_value` | `uint8_t` | Working copy of PLAYERS (1..4), committed on every change |
| `s_fs_copy_src_slot`, `s_fs_erase_slot` | `uint8_t` | Transient state for COPY/ERASE flows |
| `fs_native_active` | `uint8_t` | Dispatcher flag (main ROM only, lives next to `vblank_mode`) |

`N_OPTIONS = 16` per condensed list (see SRAM schema).

## Components

| File | Role | Status |
|---|---|---|
| `src/fs_main.c` | Boot entry. Phase loop. Music start. Calls `fs_init`, then forever loop. | NEW |
| `src/fs_phase.c/.h` | Phase enum + dispatcher. `s_fs_phase` global. RAM probe write each step. | NEW |
| `src/fs_render.c/.h` | VDP primitives: clear screen, draw row text, draw heart cursor at row Y, draw Link sprite per slot with bright/dim palette swap, render border, render OPTIONS row with current value text, render OPTIONS category header. | NEW |
| `src/fs_input.c/.h` | Controller read, latch release-then-press, ignore first 4 frames after boot. Same idiom as intro `poll_start`. | NEW |
| `src/fs_options.c/.h` | OPTIONS submenu phase logic. Working-copy management. Cursor with header skip. SAVE row handler. B-button commit. | NEW |
| `src/fs_sram.c/.h` | Save slot read/write (NES SRAM offsets). OPTIONS region read/write. PLAYERS byte. Schema magic header check + default-init. | NEW |
| `src/fs_handoff.c/.h` | Build entry contract for register-name vs gameplay. Call ASM trampoline. | NEW |
| `src/fs_copy_erase.c/.h` | COPY/ERASE prompt phases (FS_COPY_SRC, FS_COPY_DST, FS_ERASE_PICK, FS_ERASE_CONFIRM). SRAM byte-copy and zero. | NEW |
| `src/gen/fs_*.c` | Generated assets via `tools/extract_fs_assets.py`: tilemap for static UI, palettes (Link bright/dim, border, font), font CHR, Link sprite frames CHR, heart cursor sprite CHR. | NEW |
| `src/genesis_shell.asm` | (v6) Add `fs_to_transpiled_trampoline` ASM. Add `fs_native_active` `.bss` symbol. | MODIFIED |
| `src/intro_handoff.c` | (v6) Final tail-call swaps from `intro_to_file_select_trampoline()` to `fs_main()`. | MODIFIED |
| `tools/file_select_demo/boot.asm` | Standalone proof ROM boot. VDP init, IPL lower, `jsr fs_main`. Mock SRAM init for test slots. | NEW |
| `tools/file_select_demo/build.bat` | Compile proof ROM from `src/fs_*.c` + own `boot.asm`. | NEW |
| `tools/extract_fs_assets.py` | Extract static FS layout tilemap, palettes, font, Link sprite, heart cursor from NES ROM. Mirrors `extract_intro_assets.py`. Emits `fs_asset_hashes.txt`. | NEW |
| `tools/file_select_test/probe_phase_sequence.lua` | RAM probe for `$07F0..$07F3`, asserts phase byte sequence under scripted input. | NEW |
| `tools/file_select_test/probe_options_persist.lua` | Boot proof ROM, scripted input flips OPTIONS values, soft-reset, verify SRAM persistence + magic header intact. | NEW |
| `tools/file_select_test/probe_handoff.lua` | (v6) Verify A4/A5/D7 contract, NES RAM contract bytes, PPUCTRL mirrors, `vblank_mode` flip after slot select. | NEW |
| `tools/file_select_test/cmp/` | Golden-frame comparison harness. Reuses intro_demo `cmp/` infrastructure, retargeted to FS. | NEW |

## Data flow

### Boot (proof ROM)

```
RESET → boot.asm:EntryPoint
    ├─ VDP init (V32 mode, planes, CRAM clear, SAT clear)
    ├─ RAM zero, .bss init
    ├─ SRAM mock-init (one test slot occupied for visual diff)
    ├─ IPL lower
    └─ jsr fs_main

fs_main:
    ├─ fs_sram_load_slots()             (read 3 NES slots from SRAM)
    ├─ fs_sram_load_options_or_init()   (verify magic header,
    │                                    if absent write defaults from Q14)
    ├─ fs_render_static_layout()        (border, "-SELECT-" header,
    │                                    NAME / LIFE column headers,
    │                                    COPY SAVE, ERASE SAVE, PLAYERS, OPTIONS rows)
    ├─ fs_render_all_slots()            (3 Link sprites, brightness per occupancy,
    │                                    name + heart count for occupied)
    ├─ fs_render_cursor(0)              (heart sprite at slot1 Y position)
    ├─ music_play(SONG_FS_BIT)          (TBD bitmap value)
    ├─ s_fs_phase = FS_NAV
    └─ for (;;) { wait_vblank(); fs_phase_step(); fs_input_poll(); }
```

### Boot (main ROM v6)

```
intro_main runs (existing native intro)
on Start press:
    intro_handoff.c:intro_start_pressed():
        ├─ probe: nes_ram[$07F2] = $AA
        ├─ vdp_display_off()
        ├─ clear_plane($C000), clear_plane($E000)
        ├─ vdp_set_mode_v64()
        ├─ vdp_set_vscroll(0)
        ├─ fs_native_active = 1   (set via fs_dispatcher_seed asm helper)
        └─ fs_main()              (no return)
```

### Per-frame loop

```
NMI fires (every vblank)
  └─ VBlankISR (proof or main-native): bsr music_tick
                                        addq.l #1, s_fs_frame_counter
                                        rte

fs_main loop:
    wait_vblank()            spin on counter change
    fs_phase_step()          dispatch on s_fs_phase
                             write nes_ram[$07F0] = s_fs_phase
                             write nes_ram[$07F1] = s_fs_cursor
                             redraw any animation (cursor blink, etc.)
    fs_input_poll()          read controller, latch release-then-press,
                             ignore first 4 frames after boot
                             dispatch to phase handler
```

### FS_NAV input handling

```
D-Pad up        s_fs_cursor--, redraw cursor sprite (skip wrap or wrap-to-bottom — TBD plan-write)
D-Pad down      s_fs_cursor++, redraw cursor sprite
A or Start      action per cursor position:
                  0..2 -> s_fs_phase = FS_HANDOFF (slot select)
                  3    -> s_fs_phase = FS_COPY_SRC
                  4    -> s_fs_phase = FS_ERASE_PICK
                  5    -> (PLAYERS row) no-op on A; L/R cycles inline (handled below)
                  6    -> s_fs_phase = FS_OPTIONS, fs_options_enter()
D-Pad L/R       if s_fs_cursor == 5 (PLAYERS):
                    s_fs_players_value = cycle(s_fs_players_value, dir)   // 1..4
                    fs_sram_write_players(s_fs_players_value)             // immediate persist
                    fs_render_players_row()
                else: ignore
B               ignored on FS_NAV (no parent)
```

### FS_OPTIONS submenu

```
fs_options_enter():
    s_fs_options_working[*] = fs_sram_read_options()
    s_fs_options_cursor = first non-header row
    fs_render_options_screen()    // clear, draw 14 rows + 4 category headers + SAVE row, draw cursor

per frame in FS_OPTIONS:
    D-Pad up/down       move cursor, skip header rows
    D-Pad L/R or A      if on toggle row: flip s_fs_options_working[row]
                        if on radio row: cycle s_fs_options_working[row] within choice set
                        if on SAVE row: same as B (commit + exit)
                        redraw row
    B                   fs_sram_commit_options(s_fs_options_working)
                        fs_render_static_layout()
                        fs_render_all_slots()
                        fs_render_cursor(s_fs_cursor)   // restore prev cursor pos
                        s_fs_phase = FS_NAV
```

### COPY SAVE flow (Redux-exact)

```
FS_COPY_SRC (entered from FS_NAV cursor=3, A pressed):
    fs_render_prompt("COPY FROM:")
    cursor restricted to slot rows (0..2)
    on A:  s_fs_copy_src_slot = s_fs_cursor; s_fs_phase = FS_COPY_DST
    on B:  s_fs_phase = FS_NAV (cancel)

FS_COPY_DST:
    fs_render_prompt("COPY TO:")
    cursor restricted to slot rows (0..2), can't pick same as src
    on A:  fs_sram_copy_slot(src, dst)
           fs_render_all_slots()        // refresh Link bright/dim, name display
           s_fs_phase = FS_NAV
    on B:  s_fs_phase = FS_NAV
```

### ERASE SAVE flow (Redux-exact)

```
FS_ERASE_PICK (entered from FS_NAV cursor=4, A pressed):
    fs_render_prompt("ERASE WHICH?")
    cursor restricted to slot rows (0..2)
    on A:  s_fs_erase_slot = s_fs_cursor; s_fs_phase = FS_ERASE_CONFIRM
    on B:  s_fs_phase = FS_NAV

FS_ERASE_CONFIRM:
    fs_render_prompt("ARE YOU SURE? Y/N")
    on A:  fs_sram_erase_slot(s_fs_erase_slot)
           fs_render_all_slots()
           s_fs_phase = FS_NAV
    on B:  s_fs_phase = FS_NAV
```

### Slot select handoff (FS_HANDOFF, main ROM v6)

```
FS_HANDOFF (cursor on slot N, A pressed):
    probe: nes_ram[$07F2] = $AA
    vdp_display_off()
    clear_plane($C000), clear_plane($E000)
    vdp_set_mode_v64()
    vdp_set_vscroll(0)
    if slot N empty:
        mode_target = MODE_REGISTER_NAME
        seed RAM contract for register-name entry
    else:
        mode_target = MODE_GAMEPLAY_LOAD
        write current_save_slot byte = N
        seed RAM contract for save-load + gameplay entry
    fs_to_transpiled_trampoline(mode_target)

fs_to_transpiled_trampoline(mode_target):       ; ASM in genesis_shell.asm
    move.l  #$00FF0000, A4
    move.l  #$00FF0200, A5
    moveq   #-1, D7
    move.b  mode_target, GAMEMODE_OFFSET(A4)
    move.b  #0, SUBMODE_OFFSET(A4)
    move.b  #1, FRONT_START_RELEASE_GATE_OFFSET(A4)
    move.b  #0, VRAM_FORCE_BLANK_GATE_OFFSET(A4)
    ; re-enable PPUCTRL bit 7 (NMI enable) via _ppu_write_0
    move.b  ($00FF,A4), D0
    ori.b   #$80, D0
    bsr     _ppu_write_0
    move.b  #1, vblank_mode
    move.b  #0, fs_native_active
    jmp     translated_mainloop_reentry
```

### TBDs (resolved during plan-write, before v6 codes)

1. `MODE_REGISTER_NAME`, `MODE_GAMEPLAY_LOAD` exact NES values from disasm.
2. `current_save_slot` RAM offset.
3. `translated_mainloop_reentry` symbol — same identification work as intro spec TBD #3.
4. NES FS music song bitmap value.
5. Per-slot save data load symbol in transpiled code (does mode-entry auto-load, or do we explicitly call loader?).
6. NES SRAM offsets for save slots (cite NES disasm; also verify against existing `_sram_load_save_slots` in `genesis_shell.asm`).
7. Cursor wrap behavior on FS_NAV (top↔bottom wrap, or hard stop at edges) — pick to match Redux.
8. Heart cursor sprite tile index in NES CHR — extract via `tools/extract_fs_assets.py`.
9. Static UI tilemap layout — extract NES nametable bytes for FS frame 1 and adjust for two extra rows (PLAYERS, OPTIONS) below ERASE SAVE.

## SRAM schema

### Save slots (UNCHANGED)

NES original layout. Three slots at NES SRAM offsets per existing `_sram_load_save_slots` mapping. Native FS reads/writes byte-exact same bytes. Transpiled gameplay sees identical layout. **Zero risk** of breaking existing save data.

### OPTIONS region

Fresh SRAM region at `$7000`+ (verify unused range during plan-write — likely safe given NES SRAM usage caps well below this). One byte per OPTIONS row for clarity and easy debug. Total = 14 bytes.

| Row | Offset | Type | Values |
|---|---|---|---|
| LINK GFX | $7000 | radio | 0=REDUX, 1=NES |
| TUNIC COLOR | $7001 | radio | 0=TUNIC, 1=RING, 2=NES |
| FONT | $7002 | radio | 0=REDUX, 1=BIG, 2=FDS |
| HUD | $7003 | radio | 0=REDUX, 1=NES |
| AUTOMAP | $7004 | toggle | 0=ON, 1=OFF |
| OW COLUMNS | $7005 | radio | 0=REDUX, 1=NES |
| DUNGEON COLR | $7006 | toggle | 0=ON, 1=OFF |
| LOW HP SFX | $7007 | radio | 0=BEEP, 1=HEART, 2=OFF |
| SWORD ARC | $7008 | radio | 0=ALTTP, 1=NES |
| DIAG SWORD | $7009 | toggle | 0=ON, 1=OFF |
| LIKE LIKES | $700A | radio | 0=SHIELD, 1=RUPEES |
| BOSSES | $700B | radio | 0=REDUX, 1=NES |
| BOMB UPGRADE | $700C | radio | 0=+10, 1=+5 |
| START HEARTS | $700D | radio | 0=FULL, 1=3 |
| LOST WOODS | $700E | radio | 0=NES, 1=REDUX |
| SECRETS | $700F | radio | 0=REDUX, 1=NES |

Total rows by category: GRAPHICS (LINK GFX, TUNIC, FONT, HUD, AUTOMAP, OW COLUMNS, DUNGEON COLR) = 7. AUDIO (LOW HP SFX) = 1. COMBAT (SWORD ARC, DIAG SWORD, LIKE LIKES, BOSSES) = 4. GAMEPLAY (BOMB UPGRADE, START HEARTS, LOST WOODS, SECRETS) = 4. **Total = 16 rows.** SRAM region $7000..$700F (16 bytes).

`N_OPTIONS = 16`, so `s_fs_options_working[16]`.

### PLAYERS byte

Single global byte at `$7080`. Values 1..4. Default 1.

### Schema magic header

At `$7100`: 3 bytes `$F5,$1C,$71` ("FS Init Token"). At `$7103`: 1 byte schema version (currently `$01`). On boot, if header absent OR version mismatch, native FS writes all defaults per Q14, then writes header.

### Memory map summary

```
$6000..$6FFF   NES original save slots (unchanged)
$7000..$700F   OPTIONS values (16 bytes, one per row)
$7080          PLAYERS byte (1..4)
$7100..$7103   Schema magic header + version
```

## Sequencing — incremental land order

Each step ships independently with own test gate. Long-term-best per standing rule.

### v1 — Static FS render (proof ROM)
- New `tools/file_select_demo/` proof ROM, `boot.asm`, `build.bat`.
- New `tools/extract_fs_assets.py` — extract NES FS tilemap, palettes, font CHR, Link sprite CHR, heart cursor CHR. Emit `src/gen/fs_*.c`.
- New `src/fs_render.c` — render static layout once.
- New `src/fs_main.c` skeleton — call render, infinite loop, no input.
- **Gate:** golden frame at frame 60 matches expected layout (border, headers, 3 slots with mock data, 2 new rows visible).

### v2 — Cursor + nav (proof ROM)
- New `src/fs_input.c` — controller poll, latch.
- New `src/fs_phase.c` — phase enum, dispatcher.
- FS_LOAD → FS_NAV. D-Pad up/down moves cursor across all 7 stops.
- A/Start = no-op for non-PLAYERS rows in v2.
- Music plays.
- **Gate:** RAM probe `$07F0` = FS_NAV after frame 60. RAM probe `$07F1` cycles 0→6→0 under scripted D-Pad input.

### v3 — PLAYERS inline cycle + SRAM
- New `src/fs_sram.c` — schema header check + default-init + load + save.
- D-Pad L/R on PLAYERS row cycles 1↔2↔3↔4, immediate SRAM persist.
- Mock SRAM init in proof ROM `boot.asm` zeros region (forces default-init path).
- **Gate:** Layer 1 (RAM probe) + new Layer 4 (SRAM persist): scripted input cycles PLAYERS, soft-reset, verify byte at $7080.

### v4 — COPY / ERASE flow
- New `src/fs_copy_erase.c` — FS_COPY_SRC, FS_COPY_DST, FS_ERASE_PICK, FS_ERASE_CONFIRM.
- New `fs_sram_copy_slot`, `fs_sram_erase_slot` helpers.
- Render prompt overlays.
- **Gate:** RAM probe phase byte sequence under scripted COPY+ERASE input. SRAM byte-compare verifies copy semantics.

### v5a — OPTIONS submenu render
- New `src/fs_options.c` — FS_OPTIONS phase, render screen with 4 category headers + 16 rows + SAVE row (21 rendered lines total, ~17 cursor-stoppable rows).
- Cursor with header skip.
- L/R/A cycles working-copy values.
- **No SRAM** in v5a — values reset to defaults each enter (proves UI standalone).
- **Gate:** golden frame on FS_OPTIONS screen, RAM probe on `s_fs_options_cursor` skips headers correctly.

### v5b — OPTIONS commit + working copy
- B button + A on SAVE row commits `s_fs_options_working` → SRAM via `fs_sram_commit_options`.
- Enter loads from SRAM into working copy.
- **Gate:** scripted input flips toggles, B exits, soft-reset, re-enter OPTIONS, values match.

### v5c — Wire LOW HP SFX into engine (proof of consumer pattern)
- Identify transpiled audio code path that emits low-health beep (likely `audio_driver.asm` low-HP beep callsite).
- Add SRAM byte read at the callsite. Branch on value: 0=BEEP (default behavior), 1=HEART (alternate sound — requires patch from "Low Hearts Sound.ips" port), 2=OFF (skip beep).
- Compile-time gate: if alternate sound asset not yet ported, value 1 falls back to value 0 with warning comment.
- **Gate:** scripted input sets each LOW HP SFX value, hard-reset, verify SRAM byte; manual audio listen for now (golden audio test = future).

### v5d — Wire AUTOMAP into engine
- Identify transpiled HUD/automap render code path.
- Add SRAM byte read. Branch: 0=ON (Redux automap), 1=OFF (skip automap render).
- **Gate:** golden frame compare with AUTOMAP=ON vs AUTOMAP=OFF inside game (requires entering gameplay from FS — covered by v6).

### v6 — Promote to main ROM
- Add `fs_to_transpiled_trampoline` ASM in `genesis_shell.asm`.
- Add `fs_native_active` `.bss` symbol.
- Modify `src/intro_handoff.c:intro_start_pressed` final tail to `fs_main()` instead of `intro_to_file_select_trampoline`.
- New `src/fs_handoff.c` — FS_HANDOFF phase, builds register-name vs gameplay entry contract, calls trampoline.
- Resolve all TBDs from "Data flow / TBDs" before coding.
- **Gate:** Layer 3 handoff smoke (probe_handoff.lua) — verify A4/A5/D7 contract, NES RAM contract bytes, PPUCTRL bit 7, vblank_mode flip, fs_native_active flip. Plus full gameplay entry smoke (boot intro → Start → FS → A on saved slot → reach gameplay loop, RAM probe verifies game-mode byte).

## Testing

### Layer 1 — RAM probe sequence (fast CI gate, every step v2+)

Lives at `tools/file_select_test/probe_phase_sequence.lua`.

- BizHawk Lua boots ROM, runs scripted input sequence, dumps `$07F0..$07F3` every 30 frames to CSV.
- Asserts phase byte sequence matches expected.
- Asserts cursor position changes per D-Pad input.
- Runtime: ~15 s/ROM.

### Layer 2 — Golden frame compare (visual regression, every step v1+)

- BizHawk capture every 30 frames during scripted nav, save PNG to `builds/reports/file_select/gen_NNNNN.png`.
- Compare against baseline captured from Redux NES ROM (same scripted input sequence).
- Indexed-mask compare for layout/timing as hard gate; SSIM/pHash with threshold for pixel-level.
- Runtime: ~1 min/ROM.
- Reuses intro_demo `cmp/` infrastructure.

### Layer 3 — Handoff smoke (v6 only)

Lives at `tools/file_select_test/probe_handoff.lua`.

- Boot intro → wait Title → Start press → wait FS_NAV → script slot select on saved slot → assert: A4=$00FF0000, A5=$00FF0200, D7=-1, GAMEMODE byte = MODE_GAMEPLAY_LOAD, PPUCTRL bit 7 set, vblank_mode=1, fs_native_active=0.
- Repeat with empty slot → assert GAMEMODE = MODE_REGISTER_NAME.
- Repeat with cursor on COPY then slot pick → assert COPY-flow path.
- 4 sub-tests, ~10 s each.

### Layer 4 — SRAM persistence (v3+)

Lives at `tools/file_select_test/probe_options_persist.lua`.

- Boot proof ROM, scripted input flips OPTIONS values, soft-reset, verify SRAM bytes at `$7000..$700F`.
- Same for PLAYERS at `$7080`.
- Verify magic header at `$7100..$7103` after default-init.
- Runtime: ~10 s.

### Build integration

- `tools/file_select_demo/build.bat` step "post-link" runs Layer 1 + Layer 4 automatically. Build fails on mismatch.
- Layer 2 manual via `tools/file_select_test/run_full.bat` before commit.
- Layer 3 in main ROM `build.bat` post-link (v6+).

## Risks

- **R1 — Transpiled register-name / gameplay entry contract drift.** TBDs #1, #2, #3, #5 must be locked in plan-write. Any wrong RAM byte = transpiled code crashes or misbehaves on entry. Mitigation: cross-reference NES disasm and existing `_sram_load_save_slots` paths.
- **R2 — NES FS song bitmap unknown.** Mitigation: dump audio_driver call from running NES ROM during FS to identify bitmap value.
- **R3 — SRAM region $7000+ conflicts with transpiled use.** Mitigation: grep `genesis_shell.asm` and translated code for any SRAM access in `$7000..$71FF` range; pick alternate region if conflict found.
- **R4 — COPY/ERASE prompt UI pixel-faithful is hard.** Redux uses NES dialog rendering. Mitigation: extract NES nametable bytes for prompt screens via `tools/extract_fs_assets.py`, render byte-exact.
- **R5 — Engine wiring for LOW HP SFX + AUTOMAP touches transpiled code that may be drained.** Mitigation: verify both code paths still in build before v5c/v5d. If drained, revive symbol or pick alternate consumer.
- **R6 — `_ppu_write_0` register clobber.** Trampoline depends on A4/A5/D7 surviving. Mitigation: verify in plan-write (same risk as intro spec R6 — likely already verified there).
- **R7 — Heart cursor sprite reuse vs. dedicated tile.** NES uses heart sprite from gameplay tileset for cursor. Mitigation: extract via `tools/extract_fs_assets.py`, ensure tile lives in FS-mode CHR bank.
- **R8 — `s_fs_frame_counter` symbol collision with intro's frame counter in main ROM.** Mitigation: rename to `s_fs_frame_counter` (already done in spec), confirm `s_intro_frame_counter` unused once intro phase ends.

## Out of scope

- **Native FS Screen 2** (separate spec).
- **Engine wiring for the other 14 of 16 OPTIONS rows** (per-feature follow-on specs; the spec for each will: identify consumer, gate on SRAM byte, port any new asset).
- **Game Over → FS path** — stays transpiled (separate spec).
- **Save-and-quit → FS path** — stays transpiled (separate spec).
- **Co-op multiplayer engine work** — PLAYERS byte stored only, no consumer (far-future spec).
- **Transpiled FS removal / drain** — symbols stay linkable per intro spec drain policy (drain queue concern).
- **Audio engine changes** — `audio_driver.asm` unchanged, only call-site SRAM read for LOW HP SFX wiring in v5c.

## NES-truth pin-downs

These behaviors must be preserved exactly. No "simplifications" allowed in implementation:

| Behavior | Value | Source |
|---|---|---|
| Link bright palette (saved slot) | `$0F,$29,$27,$17` | `Zelda1-Redux/src/code/menus/file_select.asm:75-78` |
| Link dim palette (empty slot) | `$0F,$22,...` (3 variants per slot) | same |
| NAME header tile shift | one tile left | `Zelda1-Redux/src/code/menus/file_select.asm:7` |
| Heart row flip | `adc.b #$12` / `adc.b #$07` swap | `Zelda1-Redux/src/code/menus/file_select.asm:13-16` |
| Dash tile reuse | `$2F` (was `$62`) | `Zelda1-Redux/src/code/menus/file_select.asm:25-66` |
| FS song bitmap | `$80` | `src/frontend_runtime.c:71` (`ITEM_SFX_SECONDARY = 0x80`) — DriveSong bit-7 set → demo/title phrase loop; Mode 1 inherits, no new write |
| Cursor sprite | NES heart sprite, single-tile, vertical position per row | NES disasm |
