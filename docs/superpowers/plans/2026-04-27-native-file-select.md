# Native File Select Rewrite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace transpiled NES File Select Screen 1 with native M68K/C implementation. Match Zelda Redux look (Link palette per save state, NAME tile shift, heart row flip, dash tile reuse). Add PLAYERS row (1-4 cycle) and OPTIONS submenu (16 condensed Redux features as toggles/radios with working-copy commit semantics).

**Architecture:** Standalone proof ROM at `tools/file_select_demo/` (intro_demo pattern) iterating v1-v5 with own boot/build/tests, then promoting `src/fs_*.c` to main ROM in v6 (intro Start press now lands native FS instead of transpiled). Phase machine: `FS_LOAD → FS_NAV → {FS_COPY_SRC, FS_COPY_DST, FS_ERASE_PICK, FS_ERASE_CONFIRM, FS_OPTIONS, FS_HANDOFF}`. SRAM: NES save slots untouched at original offsets, OPTIONS bytes in fresh region $7000+, PLAYERS at $7080, magic header at $7100.

**Tech Stack:** M68K GCC freestanding (`-m68000 -ffreestanding -nostdlib -ffixed-a4`), vasm Motorola syntax for ASM, Python 3 for asset extraction, BizHawk Lua for RAM probes + golden-frame capture, vasm + ld for ROM build, fix_checksum.py for header.

**Spec:** `docs/superpowers/specs/2026-04-27-native-file-select-design.md` (commit `1e66f4a1`).

---

## File Structure

### Proof ROM (`tools/file_select_demo/`)
- `boot.asm` — Genesis boot, vector table, ROM header, VDP init, `jsr fs_main`. Mirrors `tools/intro_demo/boot.asm`.
- `build.bat` — invoke asset extractor, compile each `src/fs_*.c` + `src/gen/fs_*.c` + `boot.asm`, link, objcopy, fix_checksum.
- `file_select_demo.ld` — linker script. Same shape as `tools/intro_demo/intro_demo.ld`.
- `mock_sram.c` — initialize SRAM mock test slot ("TESTLINK", 8 hearts) so v1 visual gate has bright/dim Link both visible.

### `src/` (shared with main ROM)
- `src/fs_main.c/.h` — entry point. Calls `fs_init`, `wait_vblank` loop, `fs_phase_step`, `fs_input_poll`.
- `src/fs_phase.c/.h` — phase enum (`FS_LOAD`, `FS_NAV`, `FS_COPY_SRC`, `FS_COPY_DST`, `FS_ERASE_PICK`, `FS_ERASE_CONFIRM`, `FS_OPTIONS`, `FS_HANDOFF`), dispatcher, RAM probe write at `$07F0`.
- `src/fs_render.c/.h` — VDP primitives: clear screen, draw row text, draw heart cursor at row Y, draw Link sprite per slot with palette swap (bright/dim), border render, name+heart row, draw `<` `>` markers around PLAYERS value, draw OPTIONS row with current value text, draw OPTIONS category header.
- `src/fs_input.c/.h` — controller poll, latch release-then-press, ignore first 4 frames after boot.
- `src/fs_sram.c/.h` — save slot read/write at NES SRAM offsets, OPTIONS region read/write ($7000-$700F), PLAYERS byte ($7080), magic header check + default-init ($7100-$7103).
- `src/fs_copy_erase.c/.h` — `FS_COPY_SRC`, `FS_COPY_DST`, `FS_ERASE_PICK`, `FS_ERASE_CONFIRM` phases. SRAM byte-copy + zero-out.
- `src/fs_options.c/.h` — `FS_OPTIONS` submenu phase. Working-copy management. Cursor with header skip. SAVE row handler. B-button commit.
- `src/fs_handoff.c/.h` — `FS_HANDOFF` phase. Build NES RAM contract for register-name vs gameplay. Call ASM trampoline (v6 only).
- `src/gen/fs_*.c` — generated assets via `tools/extract_fs_assets.py`. Static UI tilemap, Link sprite CHR (bright + dim variants), heart cursor sprite, font CHR, palettes.

### `src/genesis_shell.asm` (v6 only)
- New ASM trampoline `fs_to_transpiled_trampoline` — restore A4/A5/D7, seed NES RAM contract per `mode_target` arg, flip `vblank_mode=1`, jump to `translated_mainloop_reentry`.
- New `.bss` byte `fs_native_active` next to `vblank_mode`.

### `src/intro_handoff.c` (v6 only)
- Replace final `intro_to_file_select_trampoline()` call with `fs_main()`.

### `tools/extract_fs_assets.py`
- Mirror `tools/extract_intro_assets.py`. Reads NES ROM (`Zelda1-Redux/Zelda Redux.nes`), extracts FS tilemap, Link sprite CHR, heart sprite CHR, font CHR, FS palettes (Link bright `$0F,$29,$27,$17` + dim variants), border decoration. Emits `src/gen/fs_*.c` plus `src/gen/fs_asset_hashes.txt`.

### `tools/file_select_test/`
- `probe_phase_sequence.lua` — boot ROM, scripted input, sample `$07F0..$07FF` every 30 frames, write CSV.
- `check_probe_sequence.py` — read CSV, assert phase byte sequence matches expected.
- `probe_options_persist.lua` — flip OPTIONS values via input, soft-reset, verify SRAM persistence + magic header.
- `check_options_persist.py` — assertions on SRAM bytes.
- `probe_handoff.lua` (v6) — boot main ROM, intro→FS handoff verify.
- `check_handoff_contract.py` (v6) — A4/A5/D7/RAM-contract assertions.
- `cmp/` — golden-frame baseline PNGs captured from Redux NES ROM.
- `run_full.bat` — orchestrate Lua + Python check pipeline.

---

## Pre-Plan TBD Resolution

These need answers before relevant tasks code. Each gets a research task as its first step in the affected phase.

| TBD | Resolution task |
|---|---|
| #1 MODE_REGISTER_NAME, MODE_GAMEPLAY_LOAD | v6 Task R1 — grep transpiled `z_*.asm` for `Mode_RegisterYourName` / `Mode_GameLoad` constants |
| #2 current_save_slot RAM offset | v6 Task R2 — grep `genesis_shell.asm` + `_sram_load_save_slots` for slot-pointer write |
| #3 translated_mainloop_reentry symbol | v6 Task R3 — grep `genesis_shell.asm` for existing intro re-entry, identify equivalent post-FS entry |
| #4 NES FS music song bitmap | v1 Task R4 — read `audio_driver.asm:691` neighborhood, dump value used at `Mode_FileSelect` entry |
| #5 Per-slot save loader | v6 Task R5 — grep transpiled code for `LoadSaveSlot` / equivalent |
| #6 NES SRAM offsets for save slots | v3 Task R6 — read `genesis_shell.asm:_sram_load_save_slots` body, document offsets |
| #7 Cursor wrap | v2 — match Redux: top↔bottom wrap (verify via Lua probe of NES Redux ROM) |
| #8 Heart cursor sprite tile index | v1 Task R8 — extract via NES OAM dump at FS frame 60 |
| #9 Static UI tilemap layout | v1 Task R9 — extract NES nametable via Lua probe at FS frame 60 |

---

## v1 — Static FS Render (Proof ROM)

**Gate:** golden frame at frame 60 matches expected layout (border, headers, 3 slots with mock data, 2 new rows visible).

### Task v1.R4: Resolve TBD #4 — NES FS music bitmap

**Files:**
- Read: `src/audio_driver.asm`, `src/z_07.asm` (or wherever `Mode_FileSelect` lives in transpiled tree)
- Document: append finding to `docs/superpowers/specs/2026-04-27-native-file-select-design.md` "NES-truth pin-downs" table.

- [ ] **Step 1: Grep transpiled code for FS song call**

```bash
grep -rn "Mode_FileSelect\|file_select_song\|fs_song\|_audio_play" src/*.asm src/audio_driver.asm | head -40
```

Expected: hit at `Mode_FileSelect` entry showing `move.b #$NN, song_request_byte`. Capture `$NN`.

- [ ] **Step 2: Update spec NES-truth table with concrete value**

Edit `docs/superpowers/specs/2026-04-27-native-file-select-design.md`. Replace `| FS song bitmap | TBD | NES disasm + audio_driver.asm |` with `| FS song bitmap | $NN | src/audio_driver.asm:LINE |`.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-04-27-native-file-select-design.md
git commit -m "spec: lock TBD #4 native FS music bitmap value"
```

### Task v1.R8: Resolve TBD #8 — Heart cursor sprite tile index

**Files:**
- New: `tools/file_select_test/dump_fs_oam.lua`

- [ ] **Step 1: Write Lua probe to dump OAM at FS frame 60**

Create `tools/file_select_test/dump_fs_oam.lua`:

```lua
-- Boot Redux NES ROM, advance to FS, dump OAM bytes 0..255 to CSV.
local OUT = (os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY") .. "\\tools\\file_select_test\\out\\fs_oam.csv"
os.execute('mkdir "' .. (os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY") .. '\\tools\\file_select_test\\out" 2>nul')
for f = 1, 600 do emu.frameadvance() end  -- past title screen
joypad.set({ Start = true }, 1); emu.frameadvance(); joypad.set({}, 1)
for f = 1, 60 do emu.frameadvance() end
local fh = io.open(OUT, "w")
for i = 0, 255 do fh:write(string.format("%d,%02X\n", i, memory.read_u8(i, "OAM"))) end
fh:close()
client.exit()
```

- [ ] **Step 2: Run probe**

```bash
cd "tools/file_select_test"
"%BIZHAWK_DIR%\EmuHawk.exe" --lua=dump_fs_oam.lua "Zelda1-Redux/Zelda Redux.nes"
```

Expected: file `tools/file_select_test/out/fs_oam.csv` exists.

- [ ] **Step 3: Identify heart cursor tile**

Open CSV. Look for sprite at Y matching slot 1 row position (~$48), tile index = heart cursor. Document tile index in spec NES-truth table (replace `Cursor sprite | NES heart sprite, single-tile, vertical position per row | NES disasm` row with concrete `tile_index = $NN`).

- [ ] **Step 4: Commit probe + spec update**

```bash
git add tools/file_select_test/dump_fs_oam.lua docs/superpowers/specs/2026-04-27-native-file-select-design.md
git commit -m "probe: lock TBD #8 heart cursor sprite tile index"
```

### Task v1.R9: Resolve TBD #9 — Static UI tilemap

**Files:**
- New: `tools/file_select_test/dump_fs_nametable.lua`

- [ ] **Step 1: Write Lua probe to dump NES nametable at FS frame 60**

Create `tools/file_select_test/dump_fs_nametable.lua`:

```lua
local OUT = (os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY") .. "\\tools\\file_select_test\\out\\fs_nt.bin"
for f = 1, 600 do emu.frameadvance() end
joypad.set({ Start = true }, 1); emu.frameadvance(); joypad.set({}, 1)
for f = 1, 60 do emu.frameadvance() end
local fh = io.open(OUT, "wb")
for i = 0, 0x3FF do fh:write(string.char(memory.read_u8(0x2000 + i, "PPU Bus"))) end
fh:close()
client.exit()
```

- [ ] **Step 2: Run probe**

```bash
"%BIZHAWK_DIR%\EmuHawk.exe" --lua=dump_fs_nametable.lua "Zelda1-Redux/Zelda Redux.nes"
```

Expected: 1024-byte file at `tools/file_select_test/out/fs_nt.bin`.

- [ ] **Step 3: Commit**

```bash
git add tools/file_select_test/dump_fs_nametable.lua tools/file_select_test/out/fs_nt.bin
git commit -m "probe: dump Redux FS nametable for tilemap extraction"
```

### Task v1.1: Asset extractor scaffold

**Files:**
- New: `tools/extract_fs_assets.py`
- Test: build runs without error and emits `src/gen/fs_*.c` files

- [ ] **Step 1: Create extractor skeleton**

Create `tools/extract_fs_assets.py`:

```python
"""Extract Zelda Redux File Select assets from Redux NES ROM + nametable dump.

Emits src/gen/fs_static_tilemap.c, fs_palette.c, fs_font_chr.c,
fs_link_sprite_chr.c, fs_heart_cursor_chr.c, fs_border_chr.c.
Writes src/gen/fs_asset_hashes.txt with SHA256 of every output.
"""
from __future__ import annotations
import hashlib
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
ROM = REPO / "Zelda1-Redux" / "Zelda Redux.nes"
NT_DUMP = REPO / "tools" / "file_select_test" / "out" / "fs_nt.bin"
OUT_DIR = REPO / "src" / "gen"

# NES palette quantization shared with extract_intro_assets.py.
sys.path.insert(0, str(REPO / "tools"))
from extract_intro_assets import nes_color_to_gen_cram, nes_tile_to_gen_tile

def emit_palette():
    """Emit src/gen/fs_palette.c with Link bright + dim + border palettes.

    Source: Zelda1-Redux/src/code/menus/file_select.asm:75-78
        $0F,$29,$27,$17    ; Black, green, beige, brown (saved slot)
        $0F,$22,$27,$17    ; Black, blue, beige, brown
        $0F,$16,$27,$17    ; Black, red, beige, brown
    """
    LINK_PALETTES = [
        (0x0F, 0x29, 0x27, 0x17),  # slot 1 saved (green)
        (0x0F, 0x22, 0x27, 0x17),  # slot 2 saved (blue)
        (0x0F, 0x16, 0x27, 0x17),  # slot 3 saved (red)
        (0x0F, 0x00, 0x10, 0x10),  # dim variant — TBD verify against NES dump
    ]
    out = []
    out.append("/* AUTO-GENERATED — see tools/extract_fs_assets.py */")
    out.append("#include <stdint.h>")
    out.append("const uint16_t fs_link_palettes[4][4] = {")
    for pal in LINK_PALETTES:
        cram = [nes_color_to_gen_cram(c) for c in pal]
        out.append("    { " + ", ".join(f"0x{w:04X}" for w in cram) + " },")
    out.append("};")
    (OUT_DIR / "fs_palette.c").write_text("\n".join(out) + "\n")

def emit_static_tilemap():
    """Emit src/gen/fs_static_tilemap.c from fs_nt.bin dump."""
    if not NT_DUMP.exists():
        sys.stderr.write(f"ERROR: {NT_DUMP} missing — run dump_fs_nametable.lua first\n")
        sys.exit(1)
    raw = NT_DUMP.read_bytes()
    assert len(raw) == 1024
    out = []
    out.append("/* AUTO-GENERATED — see tools/extract_fs_assets.py */")
    out.append("#include <stdint.h>")
    out.append("/* 32x30 tile nametable; rows 0..29; tile index = NES tile, callers")
    out.append(" * apply Genesis CHR base offset at upload. */")
    out.append("const uint8_t fs_static_tilemap[960] = {")
    # Skip last 64 bytes (attribute table); Genesis tilemap = first 960 bytes.
    for row in range(30):
        line = "    " + ", ".join(f"0x{raw[row*32+col]:02X}" for col in range(32)) + ","
        out.append(line)
    out.append("};")
    (OUT_DIR / "fs_static_tilemap.c").write_text("\n".join(out) + "\n")

def hash_outputs():
    h = []
    for p in sorted(OUT_DIR.glob("fs_*.c")):
        digest = hashlib.sha256(p.read_bytes()).hexdigest()
        h.append(f"{digest}  {p.name}")
    (OUT_DIR / "fs_asset_hashes.txt").write_text("\n".join(h) + "\n")

if __name__ == "__main__":
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    emit_palette()
    emit_static_tilemap()
    # CHR extraction stubs — fleshed out in subsequent tasks.
    hash_outputs()
    print("[fs] assets emitted to", OUT_DIR)
```

- [ ] **Step 2: Run extractor**

```bash
python tools/extract_fs_assets.py
```

Expected: `src/gen/fs_palette.c`, `src/gen/fs_static_tilemap.c`, `src/gen/fs_asset_hashes.txt` exist.

- [ ] **Step 3: Commit**

```bash
git add tools/extract_fs_assets.py src/gen/fs_palette.c src/gen/fs_static_tilemap.c src/gen/fs_asset_hashes.txt
git commit -m "fs/extract: scaffold extractor + palette + static tilemap"
```

### Task v1.2: CHR extraction (Link sprite, heart cursor, font, border)

**Files:**
- Modify: `tools/extract_fs_assets.py`

- [ ] **Step 1: Add CHR extraction functions**

Append to `tools/extract_fs_assets.py`:

```python
# CHR extraction. NES Redux ROM has FS CHR at bank 6 (PRG offset $18000+ for CHR).
# Heart cursor tile index resolved by Task v1.R8 (see fs_oam.csv).

LINK_SPRITE_TILES = [0xC0, 0xC1, 0xC2, 0xC3]  # 8x16 Link standing front, top+bot
HEART_CURSOR_TILE = 0xF2  # PLACEHOLDER — replace with v1.R8 result before running
FONT_TILES_RANGE = (0x0A, 0x4A)  # NES FS font region (A-Z, 0-9, dash $2F)
BORDER_TILES = [0x60, 0x61, 0x62, 0x63, 0x64, 0x65]  # corners + edges; TBD verify

def _read_chr(rom_bytes: bytes, tile_idx: int, chr_base: int = 0x18010) -> bytes:
    """Read 16-byte NES tile from ROM at chr_base + tile_idx*16. Header is 16 bytes."""
    off = chr_base + tile_idx * 16
    return rom_bytes[off:off+16]

def emit_chr_array(rom: bytes, tiles: list[int], name: str, color_shift: int = 0):
    out = []
    out.append("/* AUTO-GENERATED — see tools/extract_fs_assets.py */")
    out.append("#include <stdint.h>")
    out.append(f"const uint8_t {name}[{len(tiles) * 32}] = {{")
    for tidx in tiles:
        gen_tile = nes_tile_to_gen_tile(_read_chr(rom, tidx), color_shift=color_shift)
        out.append("    " + ", ".join(f"0x{b:02X}" for b in gen_tile) + ",")
    out.append("};")
    (OUT_DIR / f"{name}.c").write_text("\n".join(out) + "\n")

def emit_chr_blocks():
    rom = ROM.read_bytes()
    emit_chr_array(rom, LINK_SPRITE_TILES, "fs_link_sprite_chr", color_shift=4)
    emit_chr_array(rom, [HEART_CURSOR_TILE], "fs_heart_cursor_chr", color_shift=4)
    font_tiles = list(range(FONT_TILES_RANGE[0], FONT_TILES_RANGE[1]))
    emit_chr_array(rom, font_tiles, "fs_font_chr")
    emit_chr_array(rom, BORDER_TILES, "fs_border_chr")
```

Update `__main__` to call `emit_chr_blocks()` before `hash_outputs()`.

- [ ] **Step 2: Run extractor**

```bash
python tools/extract_fs_assets.py
```

Expected: `src/gen/fs_link_sprite_chr.c`, `fs_heart_cursor_chr.c`, `fs_font_chr.c`, `fs_border_chr.c` exist; hash file updated.

- [ ] **Step 3: Commit**

```bash
git add tools/extract_fs_assets.py src/gen/fs_*.c src/gen/fs_asset_hashes.txt
git commit -m "fs/extract: add Link sprite + heart cursor + font + border CHR"
```

### Task v1.3: Header file `src/fs_main.h`

**Files:**
- Create: `src/fs_main.h`

- [ ] **Step 1: Write header**

```c
/* src/fs_main.h
 *
 * Boot entry from boot.asm (proof ROM) or intro_handoff.c (main ROM v6).
 * Owns main loop while native File Select is active. Returns by jumping
 * to fs_to_transpiled_trampoline (v6); never returns normally.
 */
#ifndef FS_MAIN_H
#define FS_MAIN_H

void fs_main(void);

#endif
```

- [ ] **Step 2: Commit**

```bash
git add src/fs_main.h
git commit -m "fs: add fs_main.h entry header"
```

### Task v1.4: `src/fs_render.h` API surface

**Files:**
- Create: `src/fs_render.h`

- [ ] **Step 1: Write header**

```c
/* src/fs_render.h
 *
 * VDP primitives for File Select. Each function writes plane bytes
 * directly via vdp_* helpers in intro_common.h (shared infra).
 */
#ifndef FS_RENDER_H
#define FS_RENDER_H

#include <stdint.h>

void fs_render_clear_screen(void);
void fs_render_static_layout(void);          /* border, "-SELECT-", NAME/LIFE headers,
                                                 COPY/ERASE/PLAYERS/OPTIONS row labels */
void fs_render_slot(uint8_t slot_idx);       /* Link sprite (bright/dim), name, hearts */
void fs_render_all_slots(void);
void fs_render_cursor(uint8_t row);          /* heart sprite at row Y */
void fs_render_players_row(uint8_t value);   /* PLAYERS row with current 1..4 */

#endif
```

- [ ] **Step 2: Commit**

```bash
git add src/fs_render.h
git commit -m "fs: add fs_render.h"
```

### Task v1.5: `src/fs_render.c` static layout

**Files:**
- Create: `src/fs_render.c`

- [ ] **Step 1: Implement static layout render**

```c
/* src/fs_render.c — VDP primitives for native File Select. */
#include "fs_render.h"
#include "intro_common.h"   /* vdp_write_nametable_row, vdp_load_cram, etc. */
#include <stdint.h>

/* Generated assets. */
extern const uint16_t fs_link_palettes[4][4];
extern const uint8_t  fs_static_tilemap[960];
extern const uint8_t  fs_link_sprite_chr[];
extern const uint8_t  fs_heart_cursor_chr[];
extern const uint8_t  fs_font_chr[];
extern const uint8_t  fs_border_chr[];

#define PLANE_A_BASE 0xC000

void fs_render_clear_screen(void) {
    unsigned short zero_row[32];
    for (unsigned short i = 0; i < 32; i++) zero_row[i] = 0;
    for (unsigned short row = 0; row < 28; row++) {
        vdp_write_nametable_row(PLANE_A_BASE, row, zero_row);
    }
}

void fs_render_static_layout(void) {
    /* Translate fs_static_tilemap byte stream to plane A nametable rows.
     * Genesis cell = 16 bits: priority(1) | palette(2) | flipV(1) | flipH(1) | tile(11).
     * NES tile byte goes into low 11 bits; palette = 0; no flip. Adjust palette
     * for header rows (border cells need palette 1 if border CHR uploaded to slot 16+).
     */
    unsigned short cells[32];
    for (unsigned short row = 0; row < 30 && row < 28; row++) {
        for (unsigned short col = 0; col < 32; col++) {
            uint8_t tile = fs_static_tilemap[row * 32 + col];
            cells[col] = (uint16_t)tile;  /* palette 0, no flip */
        }
        vdp_write_nametable_row(PLANE_A_BASE, row, cells);
    }
}

/* Slot/cursor/players renders fleshed in next tasks. */
void fs_render_slot(uint8_t slot_idx) { (void)slot_idx; }
void fs_render_all_slots(void) {
    for (uint8_t i = 0; i < 3; i++) fs_render_slot(i);
}
void fs_render_cursor(uint8_t row) { (void)row; }
void fs_render_players_row(uint8_t value) { (void)value; }
```

- [ ] **Step 2: Commit**

```bash
git add src/fs_render.c
git commit -m "fs/render: clear_screen + static_layout (slot/cursor/players stubs)"
```

### Task v1.6: `src/fs_main.c` skeleton

**Files:**
- Create: `src/fs_main.c`

- [ ] **Step 1: Implement entry**

```c
/* src/fs_main.c — entry from boot.asm (proof ROM) or intro_handoff (main ROM v6).
 * v1: render static layout once, then spin forever in vblank loop.
 */
#include "fs_main.h"
#include "fs_render.h"
#include "intro_common.h"

#define VDP_CTRL_WORD (*(volatile unsigned short *)0x00C00004)

static void wait_vblank(void) {
    while ( (VDP_CTRL_WORD & 0x0008));
    while (!(VDP_CTRL_WORD & 0x0008));
}

void fs_main(void) {
    fs_render_clear_screen();
    fs_render_static_layout();
    vdp_display_on();
    for (;;) {
        wait_vblank();
        /* Phase machine + input poll added v2. */
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add src/fs_main.c
git commit -m "fs/main: v1 skeleton — render layout, idle loop"
```

### Task v1.7: Proof ROM `boot.asm`

**Files:**
- Create: `tools/file_select_demo/boot.asm`

- [ ] **Step 1: Copy intro_demo boot, retarget**

```asm
;==============================================================================
; file_select_demo/boot.asm — standalone Genesis ROM boot for native FS proof.
; Mirrors tools/intro_demo/boot.asm. Calls fs_main instead of main.
;==============================================================================

VDP_DATA        equ $00C00000
VDP_CTRL        equ $00C00004
VERSION_PORT    equ $00A10001
TMSS_PORT       equ $00A14000
Z80_BUSREQ      equ $00A11100
Z80_RESET       equ $00A11200
STACK_TOP       equ $00FFFFFE

    section "vectors",code

    dc.l    STACK_TOP
    dc.l    EntryPoint
    rept    62
        dc.l    DefaultException
    endr

    section "header",data

    dc.b    "SEGA MEGA DRIVE "
    dc.b    "(C)JAKEDIGZ 2026"
    dc.b    "FS DEMO                         "
    dc.b    "                "
    dc.b    "FS DEMO                         "
    dc.b    "                "
    dc.b    "GM 00000000-00"
    dc.w    0
    dc.b    "J               "
    dc.l    $00000000
    dc.l    $0007FFFF
    dc.l    $00FF0000
    dc.l    $00FFFFFF
    dc.b    "            "
    dc.b    "            "
    rept    40
        dc.b    $20
    endr
    dc.b    "JUE             "

    section "text",code

EntryPoint:
    move.b  (VERSION_PORT).l,D0
    andi.b  #$0F,D0
    beq.s   .skip_tmss
    move.l  #$53454741,(TMSS_PORT).l
    moveq   #15,D0
.tmss_delay:
    dbra    D0,.tmss_delay
.skip_tmss:

    move.w  #$0100,(Z80_BUSREQ).l
    move.w  #$0100,(Z80_RESET).l
.z80wait:
    btst    #0,(Z80_BUSREQ).l
    bne.s   .z80wait

    move.w  #$8004,(VDP_CTRL).l
    move.w  #$8134,(VDP_CTRL).l
    move.w  #$8230,(VDP_CTRL).l
    move.w  #$832C,(VDP_CTRL).l
    move.w  #$8407,(VDP_CTRL).l
    move.w  #$857C,(VDP_CTRL).l
    move.w  #$8600,(VDP_CTRL).l
    move.w  #$8700,(VDP_CTRL).l
    move.w  #$8800,(VDP_CTRL).l
    move.w  #$8900,(VDP_CTRL).l
    move.w  #$8AFF,(VDP_CTRL).l
    move.w  #$8B00,(VDP_CTRL).l
    move.w  #$8C00,(VDP_CTRL).l
    move.w  #$8D3F,(VDP_CTRL).l
    move.w  #$8E00,(VDP_CTRL).l
    move.w  #$8F02,(VDP_CTRL).l
    move.w  #$9000,(VDP_CTRL).l
    move.w  #$9100,(VDP_CTRL).l
    move.w  #$9200,(VDP_CTRL).l

    move.l  #STACK_TOP,A7
    jsr     fs_main

.halt:
    bra.s   .halt

DefaultException:
    rte
```

- [ ] **Step 2: Commit**

```bash
git add tools/file_select_demo/boot.asm
git commit -m "fs/demo: add boot.asm (Genesis boot, jsr fs_main)"
```

### Task v1.8: Proof ROM linker script + build.bat

**Files:**
- Create: `tools/file_select_demo/file_select_demo.ld`
- Create: `tools/file_select_demo/build.bat`

- [ ] **Step 1: Linker script**

```ld
/* file_select_demo.ld — minimal Genesis link script for FS proof ROM. */
OUTPUT_FORMAT("elf32-m68k")
ENTRY(EntryPoint)

MEMORY {
    rom (rx)  : ORIGIN = 0x000000, LENGTH = 0x080000
    ram (rwx) : ORIGIN = 0xFFC000, LENGTH = 0x002000
}

SECTIONS {
    .vectors 0x000000 : { KEEP(*(vectors)) KEEP(*(.vectors)) } > rom
    .header  0x000100 : { KEEP(*(header))  KEEP(*(.header))  } > rom
    .text    0x000200 : { *(text) *(.text*) *(.rodata*)      } > rom
    .bss             : { *(.bss*) *(COMMON)                  } > ram
    /DISCARD/        : { *(.comment) *(.note*) *(.eh_frame*) }
}
```

- [ ] **Step 2: build.bat**

```bat
@echo off
setlocal
set "ROOT=%~dp0..\..\"
for %%I in ("%ROOT%.") do set "ROOT=%%~fI"

set "DEMO_DIR=%ROOT%\tools\file_select_demo"
set "OUT_DIR=%DEMO_DIR%\out"
set "GEN_DIR=%ROOT%\src\gen"
set "SRC_DIR=%ROOT%\src"

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

set "PYTHON="
if exist "%LOCALAPPDATA%\Programs\Python\Python313\python.exe" set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python313\python.exe"
if "%PYTHON%"=="" if exist "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" set "PYTHON=%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
if "%PYTHON%"=="" where python.exe >nul 2>nul && set "PYTHON=python.exe"

set "VASM=%ROOT%\build\toolchain\vasmm68k_mot.exe"
set "M68K_BIN=%ROOT%\build\toolchain\sgdk_bin\bin"
set "M68K_GCC=%M68K_BIN%\gcc.exe"
set "M68K_LD=%M68K_BIN%\ld.exe"
set "M68K_OBJCOPY=%M68K_BIN%\objcopy.exe"

set "CFLAGS=-m68000 -ffreestanding -nostdlib -nostartfiles -ffixed-a4 -fno-builtin -fomit-frame-pointer -fno-PIC -fno-common -O2 -I "%SRC_DIR%""

echo [fs_demo] Generating assets
"%PYTHON%" "%ROOT%\tools\extract_fs_assets.py" || exit /b 1

for %%F in (fs_main fs_render) do (
    echo [fs_demo] Compiling src\%%F.c
    "%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%SRC_DIR%\%%F.c" -o "%OUT_DIR%\%%F.o" || exit /b 1
)

for %%F in (fs_palette fs_static_tilemap fs_link_sprite_chr fs_heart_cursor_chr fs_font_chr fs_border_chr) do (
    echo [fs_demo] Compiling gen\%%F.c
    "%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%GEN_DIR%\%%F.c" -o "%OUT_DIR%\%%F.o" || exit /b 1
)

echo [fs_demo] Compiling intro_common.c (shared VDP primitives)
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%SRC_DIR%\intro_common.c" -o "%OUT_DIR%\intro_common.o" || exit /b 1

echo [fs_demo] Assembling boot.asm
"%VASM%" -Felf -m68000 -L "%OUT_DIR%\boot.lst" -o "%OUT_DIR%\boot.o" "%DEMO_DIR%\boot.asm" || exit /b 1

echo [fs_demo] Linking
"%M68K_LD%" -T "%DEMO_DIR%\file_select_demo.ld" -o "%OUT_DIR%\fs_demo.elf" ^
    "%OUT_DIR%\boot.o" ^
    "%OUT_DIR%\fs_main.o" ^
    "%OUT_DIR%\fs_render.o" ^
    "%OUT_DIR%\fs_palette.o" ^
    "%OUT_DIR%\fs_static_tilemap.o" ^
    "%OUT_DIR%\fs_link_sprite_chr.o" ^
    "%OUT_DIR%\fs_heart_cursor_chr.o" ^
    "%OUT_DIR%\fs_font_chr.o" ^
    "%OUT_DIR%\fs_border_chr.o" ^
    "%OUT_DIR%\intro_common.o" || exit /b 1

"%M68K_OBJCOPY%" -O binary "%OUT_DIR%\fs_demo.elf" "%OUT_DIR%\fs_demo.bin" || exit /b 1
"%PYTHON%" "%ROOT%\tools\fix_checksum.py" "%OUT_DIR%\fs_demo.bin" "%OUT_DIR%\fs_demo.md" || exit /b 1
echo [fs_demo] DONE: %OUT_DIR%\fs_demo.md
endlocal
```

- [ ] **Step 3: Build**

```bash
tools/file_select_demo/build.bat
```

Expected: `tools/file_select_demo/out/fs_demo.md` produced. No build errors.

- [ ] **Step 4: Commit**

```bash
git add tools/file_select_demo/file_select_demo.ld tools/file_select_demo/build.bat
git commit -m "fs/demo: linker script + build.bat (v1 builds clean)"
```

### Task v1.9: Visual smoke — golden frame baseline

**Files:**
- New: `tools/file_select_test/capture_v1_baseline.lua`
- New: `tools/file_select_test/cmp/v1_frame_60.png` (after capture)

- [ ] **Step 1: Capture script**

```lua
-- capture_v1_baseline.lua — boot proof ROM, capture PNG at frame 60.
local OUT = (os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY") .. "\\tools\\file_select_test\\out\\v1_frame_60.png"
os.execute('mkdir "' .. (os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY") .. '\\tools\\file_select_test\\out" 2>nul')
for f = 1, 60 do emu.frameadvance() end
client.screenshot(OUT)
client.exit()
```

- [ ] **Step 2: Run capture against fs_demo.md**

```bash
"%BIZHAWK_DIR%\EmuHawk.exe" --lua=capture_v1_baseline.lua tools/file_select_demo/out/fs_demo.md
```

Expected: PNG at `tools/file_select_test/out/v1_frame_60.png` shows static FS layout (border, "-SELECT-", NAME/LIFE, COPY SAVE, ERASE SAVE, PLAYERS, OPTIONS rows). Slots empty (no Link sprites yet — v1 stub).

- [ ] **Step 3: Visual review + commit baseline**

Open PNG. Confirm border + headers + row labels visible (slots will be empty until v3). If layout matches expected static UI, copy to `cmp/`:

```bash
copy tools\file_select_test\out\v1_frame_60.png tools\file_select_test\cmp\v1_frame_60.png
git add tools/file_select_test/capture_v1_baseline.lua tools/file_select_test/cmp/v1_frame_60.png
git commit -m "fs/test: v1 golden frame baseline (static layout)"
```

### Task v1.10: v1 close — Link sprite render

**Files:**
- Modify: `src/fs_render.c`

- [ ] **Step 1: Implement `fs_render_slot` for sprites**

Replace stub `fs_render_slot` in `src/fs_render.c`:

```c
/* Sprite Attribute Table base — points to SAT in VRAM at $F800 per boot.asm reg 5. */
#define SAT_VRAM 0xF800

/* CHR upload offsets (set by fs_init at boot — for v1 hardcode):
 *   font CHR at tile 1..  (loaded at startup)
 *   Link sprite CHR at tile $80..$83 (4 tiles, palette 1)
 *   heart cursor CHR at tile $84 (palette 1) */
#define LINK_CHR_BASE 0x80
#define HEART_CHR_BASE 0x84

/* SAT entry: y(10), size(2), pad(1), link(1), tile_attr(16), x(10).
 * For a 1-tile 8x16 sprite: size = $05 (8x16 means 1x2 cells).
 */
static void sat_write(uint8_t entry, uint16_t y, uint16_t size, uint16_t tile_attr, uint16_t x) {
    /* Write 4 words at SAT[entry*4]. */
    volatile uint16_t *vctrl = (uint16_t *)0x00C00004;
    volatile uint16_t *vdata = (uint16_t *)0x00C00000;
    uint32_t addr = SAT_VRAM + entry * 8;
    /* VRAM write addr command. */
    *vctrl = (uint16_t)(0x4000 | (addr & 0x3FFF));
    *vctrl = (uint16_t)(((addr >> 14) & 0x03));
    *vdata = y;
    *vdata = size;
    *vdata = tile_attr;
    *vdata = x;
}

extern uint8_t fs_sram_slot_occupied(uint8_t slot);  /* stub returns 0 in v1, real impl v3 */
__attribute__((weak)) uint8_t fs_sram_slot_occupied(uint8_t slot) {
    return slot == 0 ? 1 : 0;  /* v1 mock: slot 0 occupied so bright Link visible */
}

void fs_render_slot(uint8_t slot_idx) {
    /* Y position per slot: row Y = 10, 14, 18 (in cells * 8 px). */
    uint16_t y_pixels = 128 + 32 * slot_idx + 128;  /* SAT y is 128-relative on Genesis */
    uint16_t x_pixels = 64 + 128;
    uint16_t palette = fs_sram_slot_occupied(slot_idx) ? slot_idx : 3;  /* slot palette idx */
    /* tile_attr: priority=0, palette = palette<<13, tile = LINK_CHR_BASE */
    uint16_t tile_attr = (uint16_t)((palette & 0x3) << 13) | LINK_CHR_BASE;
    uint16_t size = 0x0500;  /* 8x16 sprite (1 col, 2 rows) — high byte holds size+link */
    sat_write(slot_idx, y_pixels, size, tile_attr, x_pixels);
}
```

- [ ] **Step 2: Add SAT clear + CHR upload in fs_main init**

Modify `src/fs_main.c` to upload CHR + load palettes before render:

```c
/* Add to top of fs_main.c after includes: */
extern const uint8_t  fs_link_sprite_chr[];
extern const uint8_t  fs_heart_cursor_chr[];
extern const uint16_t fs_link_palettes[4][4];

static void fs_init(void) {
    /* Upload Link sprite CHR to VRAM tile $80. */
    vdp_dma_to_vram((unsigned long)fs_link_sprite_chr, 0x80 * 32, 4 * 32);
    /* Upload heart cursor CHR to VRAM tile $84. */
    vdp_dma_to_vram((unsigned long)fs_heart_cursor_chr, 0x84 * 32, 1 * 32);
    /* Load Link palettes into CRAM slots 1, 2, 3 (slot 0 reserved for BG). */
    vdp_load_cram(fs_link_palettes[0], 16);
}
```

Update `fs_main` body:

```c
void fs_main(void) {
    fs_init();
    fs_render_clear_screen();
    fs_render_static_layout();
    fs_render_all_slots();
    vdp_display_on();
    for (;;) { wait_vblank(); }
}
```

- [ ] **Step 3: Rebuild + recapture**

```bash
tools/file_select_demo/build.bat
"%BIZHAWK_DIR%\EmuHawk.exe" --lua=tools/file_select_test/capture_v1_baseline.lua tools/file_select_demo/out/fs_demo.md
```

Expected: `tools/file_select_test/out/v1_frame_60.png` now shows slot 0 with bright Link sprite, slots 1-2 with dim Link.

- [ ] **Step 4: Update baseline + commit**

```bash
copy tools\file_select_test\out\v1_frame_60.png tools\file_select_test\cmp\v1_frame_60.png
git add src/fs_render.c src/fs_main.c tools/file_select_test/cmp/v1_frame_60.png
git commit -m "fs/render: Link sprite render with bright/dim per occupancy (v1 close)"
```

---

## v2 — Cursor + Nav (Proof ROM)

**Gate:** RAM probe `$07F0` = `FS_NAV` after frame 60. Probe `$07F1` cycles 0→6→0 under scripted D-Pad input.

### Task v2.1: `src/fs_phase.h`

**Files:**
- Create: `src/fs_phase.h`

- [ ] **Step 1: Phase enum**

```c
/* src/fs_phase.h */
#ifndef FS_PHASE_H
#define FS_PHASE_H
#include <stdint.h>

typedef enum {
    FS_LOAD = 0,
    FS_NAV,
    FS_COPY_SRC,
    FS_COPY_DST,
    FS_ERASE_PICK,
    FS_ERASE_CONFIRM,
    FS_OPTIONS,
    FS_HANDOFF,
} fs_phase_t;

extern uint8_t s_fs_phase;
extern uint8_t s_fs_cursor;

void fs_phase_init(void);
void fs_phase_step(void);

#endif
```

- [ ] **Step 2: Commit**

```bash
git add src/fs_phase.h
git commit -m "fs/phase: enum + globals header"
```

### Task v2.2: `src/fs_phase.c` dispatcher with RAM probe

**Files:**
- Create: `src/fs_phase.c`

- [ ] **Step 1: Implement**

```c
/* src/fs_phase.c — phase dispatcher with RAM probe at $07F0/$07F1. */
#include "fs_phase.h"
#include "fs_render.h"
#include <stdint.h>

uint8_t s_fs_phase;
uint8_t s_fs_cursor;

/* NES RAM at $00FF0000 + $07F0 mapped to Genesis $FF07F0. */
#define NES_RAM ((volatile uint8_t *)0x00FF0000)

void fs_phase_init(void) {
    s_fs_phase = FS_LOAD;
    s_fs_cursor = 0;
}

void fs_phase_step(void) {
    NES_RAM[0x07F0] = s_fs_phase;
    NES_RAM[0x07F1] = s_fs_cursor;
    switch (s_fs_phase) {
        case FS_LOAD:
            fs_render_clear_screen();
            fs_render_static_layout();
            fs_render_all_slots();
            fs_render_cursor(s_fs_cursor);
            s_fs_phase = FS_NAV;
            break;
        case FS_NAV:
            /* No-op per frame; input handler drives cursor + transitions. */
            break;
        default:
            break;  /* FS_COPY_*, FS_ERASE_*, FS_OPTIONS, FS_HANDOFF added later */
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add src/fs_phase.c
git commit -m "fs/phase: FS_LOAD→FS_NAV dispatcher + RAM probe"
```

### Task v2.3: `src/fs_input.h` + `src/fs_input.c`

**Files:**
- Create: `src/fs_input.h`, `src/fs_input.c`

- [ ] **Step 1: Header**

```c
/* src/fs_input.h */
#ifndef FS_INPUT_H
#define FS_INPUT_H
#include <stdint.h>

#define FS_BTN_UP     0x01
#define FS_BTN_DOWN   0x02
#define FS_BTN_LEFT   0x04
#define FS_BTN_RIGHT  0x08
#define FS_BTN_A      0x10
#define FS_BTN_B      0x20
#define FS_BTN_START  0x40

void fs_input_init(void);
uint8_t fs_input_pressed(void);   /* edge-triggered (release-then-press) */

#endif
```

- [ ] **Step 2: Implementation**

```c
/* src/fs_input.c — controller poll, edge detection. */
#include "fs_input.h"
#include <stdint.h>

static uint8_t s_prev;
static uint8_t s_boot_frames;

#define IO_PORT1_DATA (*(volatile uint8_t *)0x00A10003)
#define IO_PORT1_CTRL (*(volatile uint8_t *)0x00A10009)

void fs_input_init(void) {
    IO_PORT1_CTRL = 0x40;       /* TH out, others in */
    IO_PORT1_DATA = 0x40;
    s_prev = 0;
    s_boot_frames = 0;
}

static uint8_t read_pad(void) {
    /* Genesis 6-button read sequence — for v1 use 3-button subset. */
    uint8_t lo, hi;
    IO_PORT1_DATA = 0x00; lo = IO_PORT1_DATA & 0x3F;  /* SACBRLDU low? UDLR + ACB low; doc varies */
    IO_PORT1_DATA = 0x40; hi = IO_PORT1_DATA & 0x3F;
    /* TH=0: --SA00DU on bits 5..0. TH=1: CBRLDU. */
    uint8_t btn = 0;
    if (!(hi & 0x01)) btn |= FS_BTN_UP;
    if (!(hi & 0x02)) btn |= FS_BTN_DOWN;
    if (!(hi & 0x04)) btn |= FS_BTN_LEFT;
    if (!(hi & 0x08)) btn |= FS_BTN_RIGHT;
    if (!(hi & 0x10)) btn |= FS_BTN_B;
    if (!(hi & 0x20)) btn |= FS_BTN_A;       /* C button — used as A for FS */
    if (!(lo & 0x20)) btn |= FS_BTN_START;
    /* Map "A button" to actual A: in 3-button reading, A is on TH=0 step. */
    if (!(lo & 0x10)) btn |= FS_BTN_A;       /* override with TH=0 A bit */
    return btn;
}

uint8_t fs_input_pressed(void) {
    if (s_boot_frames < 4) { s_boot_frames++; s_prev = read_pad(); return 0; }
    uint8_t cur = read_pad();
    uint8_t edge = cur & ~s_prev;
    s_prev = cur;
    return edge;
}
```

- [ ] **Step 3: Commit**

```bash
git add src/fs_input.h src/fs_input.c
git commit -m "fs/input: 3-button controller poll + edge detection (4-frame boot ignore)"
```

### Task v2.4: Wire input + cursor nav into `fs_main`

**Files:**
- Modify: `src/fs_main.c`

- [ ] **Step 1: Add nav handling**

Update `src/fs_main.c`:

```c
/* src/fs_main.c */
#include "fs_main.h"
#include "fs_render.h"
#include "fs_phase.h"
#include "fs_input.h"
#include "intro_common.h"

#define VDP_CTRL_WORD (*(volatile unsigned short *)0x00C00004)
extern const uint8_t  fs_link_sprite_chr[];
extern const uint8_t  fs_heart_cursor_chr[];
extern const uint16_t fs_link_palettes[4][4];

static void wait_vblank(void) {
    while ( (VDP_CTRL_WORD & 0x0008));
    while (!(VDP_CTRL_WORD & 0x0008));
}

static void fs_init(void) {
    vdp_dma_to_vram((unsigned long)fs_link_sprite_chr, 0x80 * 32, 4 * 32);
    vdp_dma_to_vram((unsigned long)fs_heart_cursor_chr, 0x84 * 32, 1 * 32);
    vdp_load_cram(fs_link_palettes[0], 16);
    fs_input_init();
    fs_phase_init();
}

static void fs_input_dispatch(uint8_t edge) {
    if (s_fs_phase != FS_NAV) return;
    if ((edge & FS_BTN_UP) && s_fs_cursor > 0) {
        s_fs_cursor--; fs_render_cursor(s_fs_cursor);
    }
    if ((edge & FS_BTN_DOWN) && s_fs_cursor < 6) {
        s_fs_cursor++; fs_render_cursor(s_fs_cursor);
    }
    /* A/Start: handled in v3+ for slot pick / submenu enter. */
}

void fs_main(void) {
    fs_init();
    vdp_display_on();
    for (;;) {
        wait_vblank();
        fs_phase_step();
        fs_input_dispatch(fs_input_pressed());
    }
}
```

- [ ] **Step 2: Implement `fs_render_cursor` (heart sprite at row Y)**

In `src/fs_render.c`, replace cursor stub:

```c
/* Row Y (in pixel coords, SAT-relative +128): */
static const uint16_t CURSOR_Y_BY_ROW[7] = {
    128 + 80,   /* slot 1 */
    128 + 112,  /* slot 2 */
    128 + 144,  /* slot 3 */
    128 + 176,  /* COPY SAVE */
    128 + 192,  /* ERASE SAVE */
    128 + 208,  /* PLAYERS */
    128 + 224,  /* OPTIONS */
};

void fs_render_cursor(uint8_t row) {
    if (row > 6) return;
    /* SAT entry 7 reserved for cursor (entries 0-2 = slot Links). */
    uint16_t tile_attr = (uint16_t)(1 << 13) | HEART_CHR_BASE;  /* palette 1 */
    sat_write(7, CURSOR_Y_BY_ROW[row], 0x0000 /* 8x8 size */, tile_attr, 128 + 32);
}
```

- [ ] **Step 3: Update build.bat to compile fs_phase.c + fs_input.c**

Add to `tools/file_select_demo/build.bat` after `fs_render` compile loop:

```bat
for %%F in (fs_main fs_render fs_phase fs_input) do (
    echo [fs_demo] Compiling src\%%F.c
    "%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%SRC_DIR%\%%F.c" -o "%OUT_DIR%\%%F.o" || exit /b 1
)
```

Add `fs_phase.o fs_input.o` to linker `ld` arglist.

- [ ] **Step 4: Build**

```bash
tools/file_select_demo/build.bat
```

Expected: clean build.

- [ ] **Step 5: Commit**

```bash
git add src/fs_main.c src/fs_render.c tools/file_select_demo/build.bat
git commit -m "fs/main: wire phase + input dispatch + cursor render (v2)"
```

### Task v2.5: Layer 1 RAM probe — phase sequence test

**Files:**
- Create: `tools/file_select_test/probe_phase_sequence.lua`
- Create: `tools/file_select_test/check_probe_sequence.py`

- [ ] **Step 1: Lua probe**

```lua
-- tools/file_select_test/probe_phase_sequence.lua
local REPO = os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY"
local OUT  = REPO .. "\\tools\\file_select_test\\out\\phase_sequence.csv"
os.execute('mkdir "' .. REPO .. '\\tools\\file_select_test\\out" 2>nul')

local domain
do
    local d = memory.getmemorydomainlist()
    for _, n in ipairs(d) do if n == "68K RAM" then domain = "68K RAM" break end end
end
local function rd(addr)
    if not domain then return 0xFF end
    local off = addr - 0xFF0000
    return memory.read_u8(off, domain)
end

local fh = io.open(OUT, "w")
fh:write("frame,phase,cursor\n")

-- Sample every 30 frames, total 600 frames. Inject D-Pad sequence.
local INPUT_SEQ = {
    [60]  = { Down = true },
    [120] = { Down = true },
    [180] = { Down = true },
    [240] = { Down = true },
    [300] = { Down = true },
    [360] = { Down = true },  -- now at row 6
    [420] = { Up = true },
    [480] = { Up = true },
}

for f = 1, 600 do
    local pad = INPUT_SEQ[f]
    if pad then joypad.set(pad, 1) else joypad.set({}, 1) end
    emu.frameadvance()
    if f % 30 == 0 then
        fh:write(string.format("%d,%02X,%02X\n", f, rd(0xFF07F0), rd(0xFF07F1)))
    end
end
fh:close()
client.exit()
```

- [ ] **Step 2: Python checker**

```python
# tools/file_select_test/check_probe_sequence.py
import csv, sys
from pathlib import Path

CSV = Path(__file__).resolve().parent / "out" / "phase_sequence.csv"
if not CSV.exists():
    sys.exit(f"FAIL: {CSV} missing")

rows = list(csv.DictReader(CSV.open()))
errors = []

# After frame 30, phase must be FS_NAV (=1).
for r in rows:
    if int(r["frame"]) >= 30 and int(r["phase"], 16) != 1:
        errors.append(f"frame {r['frame']}: phase = 0x{r['phase']}, expected 0x01 (FS_NAV)")
        break

# Cursor must reach 6 by frame 390 (after 6 Down presses).
late = [r for r in rows if int(r["frame"]) == 390]
if late and int(late[0]["cursor"], 16) != 6:
    errors.append(f"frame 390: cursor = 0x{late[0]['cursor']}, expected 0x06")

if errors:
    for e in errors: print("FAIL:", e)
    sys.exit(1)
print("PASS: phase sequence matches expected")
```

- [ ] **Step 3: Run probe (expect FAIL first iter — sanity check the test wires up)**

Quick sanity: if any wiring is wrong (probe address, RAM domain, cursor write order), the test surfaces it.

```bash
"%BIZHAWK_DIR%\EmuHawk.exe" --lua=tools/file_select_test/probe_phase_sequence.lua tools/file_select_demo/out/fs_demo.md
python tools/file_select_test/check_probe_sequence.py
```

Expected (after v2.4 lands correctly): `PASS: phase sequence matches expected`.

- [ ] **Step 4: Commit probe + checker**

```bash
git add tools/file_select_test/probe_phase_sequence.lua tools/file_select_test/check_probe_sequence.py
git commit -m "fs/test: Layer 1 RAM probe — phase byte + cursor sequence (v2 gate)"
```

### Task v2.6: Music start

**Files:**
- Modify: `src/fs_main.c`

- [ ] **Step 1: Add music_play call**

v1.R4 resolved: FS is silent (`SONG_FS_BIT = 0x00`). `intro_to_file_select_trampoline` at `genesis_shell.asm:681` clears SongRequest to 0 before Mode 1. Original NES FS is also silent. Keep the `music_play(0)` call in place so the call site exists if the design ever changes. Update `src/fs_main.c`:

```c
extern void music_play(uint8_t bit);   /* declared by audio_driver, linked from main ROM */

#define SONG_FS_BIT 0x00   /* FS is silent — trampoline clears SongRequest to 0 before Mode 1 */

static void fs_init(void) {
    /* ... existing init ... */
    music_play(SONG_FS_BIT);   /* 0 = stop/silence; call kept for future design change */
}
```

For proof ROM: link a stub `music_play` if audio_driver is too heavy to pull in. Add to `tools/file_select_demo/`:

```c
/* tools/file_select_demo/music_stub.c */
void music_play(unsigned char bit) { (void)bit; }
void music_tick(void) {}
```

Add `music_stub.c` compile + link in `build.bat`.

- [ ] **Step 2: Build + verify probe still passes**

```bash
tools/file_select_demo/build.bat
python tools/file_select_test/check_probe_sequence.py
```

Expected: PASS unchanged.

- [ ] **Step 3: Commit**

```bash
git add src/fs_main.c tools/file_select_demo/music_stub.c tools/file_select_demo/build.bat
git commit -m "fs/main: music_play(SONG_FS_BIT) + stub for proof ROM (v2 close)"
```

---

## v3 — PLAYERS Inline Cycle + SRAM

**Gate:** Layer 1 RAM probe + Layer 4 SRAM persist test pass.

### Task v3.R6: Resolve TBD #6 — NES SRAM offsets

**Files:**
- Read: `src/genesis_shell.asm` (find `_sram_load_save_slots`)
- Document: append to spec NES-truth table.

- [ ] **Step 1: Find slot offsets**

```bash
grep -n "_sram_load_save_slots\|sram\|SRAM_SLOT\|SaveSlot" src/genesis_shell.asm | head -30
```

- [ ] **Step 2: Document slot 0/1/2 base addresses + slot byte size**

Edit spec NES-truth table. Add row: `Save slot offsets | $NNNN, $NNNN, $NNNN | src/genesis_shell.asm:LINE`.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-04-27-native-file-select-design.md
git commit -m "spec: lock TBD #6 NES SRAM save slot offsets"
```

### Task v3.1: `src/fs_sram.h` + `src/fs_sram.c`

**Files:**
- Create: `src/fs_sram.h`, `src/fs_sram.c`

- [ ] **Step 1: Header**

```c
/* src/fs_sram.h */
#ifndef FS_SRAM_H
#define FS_SRAM_H
#include <stdint.h>

#define FS_N_OPTIONS 16

void    fs_sram_init(void);                      /* check magic, default-init if missing */
uint8_t fs_sram_slot_occupied(uint8_t slot);     /* 1 if non-empty save in slot */
void    fs_sram_load_options(uint8_t out[FS_N_OPTIONS]);
void    fs_sram_commit_options(const uint8_t in[FS_N_OPTIONS]);
uint8_t fs_sram_read_players(void);
void    fs_sram_write_players(uint8_t value);
void    fs_sram_copy_slot(uint8_t src, uint8_t dst);
void    fs_sram_erase_slot(uint8_t slot);

#endif
```

- [ ] **Step 2: Implementation**

```c
/* src/fs_sram.c */
#include "fs_sram.h"
#include <stdint.h>

#define SRAM_BYTE(addr) (*(volatile uint8_t *)(0x00200001 + ((addr) << 1)))
/* Genesis SRAM: byte-wide on odd addresses if SRAM mapper enabled in shell.
 * Offset addr scaled per existing _sram_load_save_slots convention. */

#define SRAM_OPTIONS_BASE  0x7000
#define SRAM_PLAYERS_ADDR  0x7080
#define SRAM_MAGIC_ADDR    0x7100
#define SRAM_VERSION_ADDR  0x7103
static const uint8_t MAGIC[3] = { 0xF5, 0x1C, 0x71 };
#define FS_SCHEMA_VERSION  0x01

/* Slot occupancy detection: read first name byte; NES treats $00 as empty slot. */
#define SLOT_NAME_OFFSET(N) (0x6300 + (N) * 0x80)  /* REPLACE with v3.R6 actual offsets */

void fs_sram_init(void) {
    int magic_ok = 1;
    for (int i = 0; i < 3; i++) {
        if (SRAM_BYTE(SRAM_MAGIC_ADDR + i) != MAGIC[i]) { magic_ok = 0; break; }
    }
    if (!magic_ok || SRAM_BYTE(SRAM_VERSION_ADDR) != FS_SCHEMA_VERSION) {
        /* Default-init OPTIONS (all = 0 = REDUX/first listed). */
        for (int i = 0; i < FS_N_OPTIONS; i++) SRAM_BYTE(SRAM_OPTIONS_BASE + i) = 0;
        SRAM_BYTE(SRAM_PLAYERS_ADDR) = 1;
        for (int i = 0; i < 3; i++) SRAM_BYTE(SRAM_MAGIC_ADDR + i) = MAGIC[i];
        SRAM_BYTE(SRAM_VERSION_ADDR) = FS_SCHEMA_VERSION;
    }
}

uint8_t fs_sram_slot_occupied(uint8_t slot) {
    if (slot > 2) return 0;
    return SRAM_BYTE(SLOT_NAME_OFFSET(slot)) != 0;
}

void fs_sram_load_options(uint8_t out[FS_N_OPTIONS]) {
    for (int i = 0; i < FS_N_OPTIONS; i++) out[i] = SRAM_BYTE(SRAM_OPTIONS_BASE + i);
}

void fs_sram_commit_options(const uint8_t in[FS_N_OPTIONS]) {
    for (int i = 0; i < FS_N_OPTIONS; i++) SRAM_BYTE(SRAM_OPTIONS_BASE + i) = in[i];
}

uint8_t fs_sram_read_players(void) {
    uint8_t v = SRAM_BYTE(SRAM_PLAYERS_ADDR);
    if (v < 1 || v > 4) v = 1;
    return v;
}

void fs_sram_write_players(uint8_t value) {
    if (value < 1) value = 1;
    if (value > 4) value = 4;
    SRAM_BYTE(SRAM_PLAYERS_ADDR) = value;
}

#define SLOT_SIZE 0x80
void fs_sram_copy_slot(uint8_t src, uint8_t dst) {
    if (src > 2 || dst > 2 || src == dst) return;
    for (int i = 0; i < SLOT_SIZE; i++) {
        SRAM_BYTE(SLOT_NAME_OFFSET(dst) + i) = SRAM_BYTE(SLOT_NAME_OFFSET(src) + i);
    }
}

void fs_sram_erase_slot(uint8_t slot) {
    if (slot > 2) return;
    for (int i = 0; i < SLOT_SIZE; i++) SRAM_BYTE(SLOT_NAME_OFFSET(slot) + i) = 0;
}
```

- [ ] **Step 3: Commit**

```bash
git add src/fs_sram.h src/fs_sram.c
git commit -m "fs/sram: schema header + slot read/write + OPTIONS + PLAYERS"
```

### Task v3.2: PLAYERS row inline cycle in dispatch

**Files:**
- Modify: `src/fs_main.c`, `src/fs_render.c`

- [ ] **Step 1: Add globals**

In `src/fs_main.c`:

```c
#include "fs_sram.h"

static uint8_t s_fs_players_value;
```

- [ ] **Step 2: Init from SRAM**

In `fs_init`:

```c
fs_sram_init();
s_fs_players_value = fs_sram_read_players();
```

- [ ] **Step 3: L/R dispatch on PLAYERS row**

In `fs_input_dispatch`:

```c
if (s_fs_cursor == 5 /* PLAYERS row */) {
    if (edge & FS_BTN_LEFT) {
        s_fs_players_value = (s_fs_players_value <= 1) ? 4 : s_fs_players_value - 1;
        fs_sram_write_players(s_fs_players_value);
        fs_render_players_row(s_fs_players_value);
    }
    if (edge & FS_BTN_RIGHT) {
        s_fs_players_value = (s_fs_players_value >= 4) ? 1 : s_fs_players_value + 1;
        fs_sram_write_players(s_fs_players_value);
        fs_render_players_row(s_fs_players_value);
    }
}
```

- [ ] **Step 4: Implement `fs_render_players_row`**

In `src/fs_render.c`:

```c
extern void vdp_write_nametable_row(unsigned short plane_base, unsigned short row,
                                    const unsigned short *cells);

static const uint8_t FONT_DIGIT_TILES[] = { 0,1,2,3,4,5,6,7,8,9 };  /* TBD verify */

void fs_render_players_row(uint8_t value) {
    /* Row 23 (PLAYERS row Y in cells). Layout: "PLAYERS  < N >" — write digit
     * at column position. */
    extern void vdp_write_cell(unsigned short plane_base, unsigned short row,
                                unsigned short col, unsigned short cell);
    /* Use vdp_write_nametable_row as full-row write OR write single cell: */
    static unsigned short row_cells[32];
    /* Pre-fill with current row from static tilemap, then patch digit position. */
    for (unsigned short c = 0; c < 32; c++) {
        row_cells[c] = fs_static_tilemap[23 * 32 + c];
    }
    row_cells[14] = (uint16_t)FONT_DIGIT_TILES[value & 0x07];  /* digit position */
    vdp_write_nametable_row(0xC000, 23, row_cells);
}
```

- [ ] **Step 5: Update build.bat to include fs_sram.c**

Add `fs_sram` to compile loop + link.

- [ ] **Step 6: Build + commit**

```bash
tools/file_select_demo/build.bat
git add src/fs_main.c src/fs_render.c tools/file_select_demo/build.bat
git commit -m "fs/main: PLAYERS row L/R cycle (immediate SRAM persist)"
```

### Task v3.3: Layer 4 SRAM persist test

**Files:**
- Create: `tools/file_select_test/probe_options_persist.lua`
- Create: `tools/file_select_test/check_options_persist.py`

- [ ] **Step 1: Lua probe**

```lua
-- probe_options_persist.lua — boot, cycle PLAYERS, soft-reset, verify SRAM byte.
local REPO = os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY"
local OUT  = REPO .. "\\tools\\file_select_test\\out\\sram_after_reset.csv"
os.execute('mkdir "' .. REPO .. '\\tools\\file_select_test\\out" 2>nul')

-- Boot, advance to FS_NAV (frame 30).
for f = 1, 30 do emu.frameadvance() end
-- Move cursor to PLAYERS (5 Downs).
for d = 1, 5 do
    joypad.set({ Down = true }, 1); emu.frameadvance(); joypad.set({}, 1)
    for f = 1, 8 do emu.frameadvance() end
end
-- Press Right 2 times (PLAYERS 1 -> 2 -> 3).
for r = 1, 2 do
    joypad.set({ Right = true }, 1); emu.frameadvance(); joypad.set({}, 1)
    for f = 1, 8 do emu.frameadvance() end
end
-- Soft reset.
client.softreset()
for f = 1, 60 do emu.frameadvance() end

-- Read SRAM byte at $7080 (PLAYERS).
local domain
for _, n in ipairs(memory.getmemorydomainlist()) do
    if n == "Cart (SRAM)" or n == "SRAM" then domain = n end
end
local players = memory.read_u8(0x7080, domain or "M68K BUS")
local fh = io.open(OUT, "w")
fh:write(string.format("players,%d\n", players))
-- Magic header
for i = 0, 2 do
    local b = memory.read_u8(0x7100 + i, domain or "M68K BUS")
    fh:write(string.format("magic_%d,0x%02X\n", i, b))
end
fh:close()
client.exit()
```

- [ ] **Step 2: Python checker**

```python
# check_options_persist.py
import csv, sys
from pathlib import Path
CSV = Path(__file__).resolve().parent / "out" / "sram_after_reset.csv"
if not CSV.exists(): sys.exit(f"FAIL: {CSV} missing")
data = {row[0]: row[1] for row in csv.reader(CSV.open())}
errs = []
if int(data["players"]) != 3:
    errs.append(f"players byte = {data['players']}, expected 3")
expected_magic = [0xF5, 0x1C, 0x71]
for i, expect in enumerate(expected_magic):
    got = int(data[f"magic_{i}"], 16)
    if got != expect:
        errs.append(f"magic[{i}] = 0x{got:02X}, expected 0x{expect:02X}")
if errs:
    for e in errs: print("FAIL:", e)
    sys.exit(1)
print("PASS: SRAM persistence + magic header valid")
```

- [ ] **Step 3: Run + commit**

```bash
"%BIZHAWK_DIR%\EmuHawk.exe" --lua=tools/file_select_test/probe_options_persist.lua tools/file_select_demo/out/fs_demo.md
python tools/file_select_test/check_options_persist.py
git add tools/file_select_test/probe_options_persist.lua tools/file_select_test/check_options_persist.py
git commit -m "fs/test: Layer 4 SRAM persistence (PLAYERS cycle + magic header)"
```

---

## v4 — COPY / ERASE Flow

**Gate:** RAM probe phase byte sequence under scripted COPY+ERASE input. SRAM byte-compare verifies copy semantics.

### Task v4.1: `src/fs_copy_erase.h` + `src/fs_copy_erase.c`

**Files:**
- Create: `src/fs_copy_erase.h`, `src/fs_copy_erase.c`

- [ ] **Step 1: Header**

```c
/* src/fs_copy_erase.h */
#ifndef FS_COPY_ERASE_H
#define FS_COPY_ERASE_H
#include <stdint.h>

extern uint8_t s_fs_copy_src_slot;
extern uint8_t s_fs_erase_slot;

void fs_copy_erase_step(void);            /* dispatch for FS_COPY_*/FS_ERASE_* phases */
void fs_copy_erase_input(uint8_t edge);   /* input handler when in copy/erase phase */

#endif
```

- [ ] **Step 2: Implementation**

```c
/* src/fs_copy_erase.c */
#include "fs_copy_erase.h"
#include "fs_phase.h"
#include "fs_render.h"
#include "fs_sram.h"
#include "fs_input.h"
#include <stdint.h>

uint8_t s_fs_copy_src_slot;
uint8_t s_fs_erase_slot;

extern void fs_render_prompt(const char *text);   /* impl in fs_render.c, added below */
extern void fs_render_cursor(uint8_t row);

void fs_copy_erase_step(void) {
    /* Render prompt once on phase entry — track via static last_phase. */
    static uint8_t last_phase = 0xFF;
    if (s_fs_phase != last_phase) {
        switch (s_fs_phase) {
            case FS_COPY_SRC:     fs_render_prompt("COPY FROM:"); break;
            case FS_COPY_DST:     fs_render_prompt("COPY TO:"); break;
            case FS_ERASE_PICK:   fs_render_prompt("ERASE WHICH?"); break;
            case FS_ERASE_CONFIRM:fs_render_prompt("ARE YOU SURE? Y/N"); break;
            default: break;
        }
        last_phase = s_fs_phase;
    }
}

void fs_copy_erase_input(uint8_t edge) {
    if (edge & FS_BTN_B) {
        s_fs_phase = FS_NAV;
        fs_render_static_layout();
        fs_render_all_slots();
        fs_render_cursor(s_fs_cursor);
        return;
    }
    /* Cursor restricted to slot rows during these phases. */
    if ((edge & FS_BTN_UP) && s_fs_cursor > 0)   { s_fs_cursor--; fs_render_cursor(s_fs_cursor); }
    if ((edge & FS_BTN_DOWN) && s_fs_cursor < 2) { s_fs_cursor++; fs_render_cursor(s_fs_cursor); }
    if (edge & (FS_BTN_A | FS_BTN_START)) {
        switch (s_fs_phase) {
            case FS_COPY_SRC:
                s_fs_copy_src_slot = s_fs_cursor;
                s_fs_phase = FS_COPY_DST;
                break;
            case FS_COPY_DST:
                if (s_fs_cursor != s_fs_copy_src_slot) {
                    fs_sram_copy_slot(s_fs_copy_src_slot, s_fs_cursor);
                    fs_render_all_slots();
                }
                s_fs_phase = FS_NAV;
                fs_render_static_layout();
                fs_render_cursor(s_fs_cursor);
                break;
            case FS_ERASE_PICK:
                s_fs_erase_slot = s_fs_cursor;
                s_fs_phase = FS_ERASE_CONFIRM;
                break;
            case FS_ERASE_CONFIRM:
                fs_sram_erase_slot(s_fs_erase_slot);
                fs_render_all_slots();
                s_fs_phase = FS_NAV;
                fs_render_static_layout();
                fs_render_cursor(s_fs_cursor);
                break;
            default: break;
        }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add src/fs_copy_erase.h src/fs_copy_erase.c
git commit -m "fs/copy_erase: COPY/ERASE flow phases + input handler"
```

### Task v4.2: Prompt render

**Files:**
- Modify: `src/fs_render.h`, `src/fs_render.c`

- [ ] **Step 1: Add prompt renderer**

In `fs_render.h`:

```c
void fs_render_prompt(const char *text);  /* draw text in prompt bar at row 26 */
```

In `fs_render.c`:

```c
static uint8_t font_tile_for_char(char c) {
    if (c >= 'A' && c <= 'Z') return 0x0A + (c - 'A');
    if (c >= '0' && c <= '9') return 0x00 + (c - '0');
    if (c == '?') return 0x2E;
    if (c == ':') return 0x2D;
    if (c == ' ') return 0x24;  /* blank tile */
    return 0x24;
}

void fs_render_prompt(const char *text) {
    static unsigned short row_cells[32];
    for (unsigned short c = 0; c < 32; c++) row_cells[c] = 0x24;  /* blank */
    unsigned short col = 4;
    for (const char *p = text; *p && col < 28; p++, col++) {
        row_cells[col] = (uint16_t)font_tile_for_char(*p);
    }
    vdp_write_nametable_row(0xC000, 26, row_cells);
}
```

- [ ] **Step 2: Commit**

```bash
git add src/fs_render.h src/fs_render.c
git commit -m "fs/render: prompt bar at row 26 with ASCII-to-tile mapping"
```

### Task v4.3: Wire FS_NAV → COPY/ERASE entry

**Files:**
- Modify: `src/fs_main.c`

- [ ] **Step 1: A/Start handler in FS_NAV**

In `fs_input_dispatch`:

```c
if ((edge & (FS_BTN_A | FS_BTN_START)) && s_fs_phase == FS_NAV) {
    switch (s_fs_cursor) {
        case 0: case 1: case 2:
            s_fs_phase = FS_HANDOFF;  /* impl in v6 — for v4 stubs to NAV */
            /* v4-only stub: revert to NAV until v6 lands handoff */
            s_fs_phase = FS_NAV;
            break;
        case 3: s_fs_phase = FS_COPY_SRC;   s_fs_cursor = 0; fs_render_cursor(0); break;
        case 4: s_fs_phase = FS_ERASE_PICK; s_fs_cursor = 0; fs_render_cursor(0); break;
        case 5: /* PLAYERS — A no-op */ break;
        case 6: /* OPTIONS — handled in v5a */ break;
    }
}
```

- [ ] **Step 2: Dispatch input to copy_erase when in those phases**

```c
static void fs_input_dispatch(uint8_t edge) {
    if (s_fs_phase == FS_NAV) { /* nav input */ ... }
    else if (s_fs_phase >= FS_COPY_SRC && s_fs_phase <= FS_ERASE_CONFIRM) {
        fs_copy_erase_input(edge);
    }
}
```

- [ ] **Step 3: Add fs_phase_step dispatch to fs_copy_erase_step**

In `src/fs_phase.c`:

```c
#include "fs_copy_erase.h"

void fs_phase_step(void) {
    NES_RAM[0x07F0] = s_fs_phase;
    NES_RAM[0x07F1] = s_fs_cursor;
    switch (s_fs_phase) {
        case FS_LOAD: ...
        case FS_NAV: break;
        case FS_COPY_SRC:
        case FS_COPY_DST:
        case FS_ERASE_PICK:
        case FS_ERASE_CONFIRM:
            fs_copy_erase_step();
            break;
        default: break;
    }
}
```

- [ ] **Step 4: build.bat add fs_copy_erase.o**

- [ ] **Step 5: Build + commit**

```bash
tools/file_select_demo/build.bat
git add src/fs_main.c src/fs_phase.c tools/file_select_demo/build.bat
git commit -m "fs/main: wire FS_NAV→COPY/ERASE entry; phase dispatch routes to copy_erase"
```

### Task v4.4: COPY flow probe test

**Files:**
- Create: `tools/file_select_test/probe_copy_flow.lua`

- [ ] **Step 1: Probe**

```lua
-- probe_copy_flow.lua: cursor to COPY, A, pick slot 0 as src, A, pick slot 1 as dst, A.
-- Verify SRAM byte at slot1 first byte == slot0 first byte (after copy).
local REPO = os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY"
local OUT  = REPO .. "\\tools\\file_select_test\\out\\copy_flow.csv"

-- Set up: write a known byte to slot0[0] via memory.write_u8 (mock pre-existing save).
-- For proof ROM, mock SRAM in boot.asm; here just inject after init.
for f = 1, 30 do emu.frameadvance() end

-- Press Down 3x to reach COPY SAVE.
for d = 1, 3 do joypad.set({ Down = true }, 1); emu.frameadvance(); joypad.set({}, 1)
                for f = 1, 8 do emu.frameadvance() end end
-- A to enter COPY_SRC.
joypad.set({ A = true }, 1); emu.frameadvance(); joypad.set({}, 1)
for f = 1, 8 do emu.frameadvance() end
-- Cursor at slot 0; A picks src.
joypad.set({ A = true }, 1); emu.frameadvance(); joypad.set({}, 1)
for f = 1, 8 do emu.frameadvance() end
-- Down to slot 1, A picks dst.
joypad.set({ Down = true }, 1); emu.frameadvance(); joypad.set({}, 1)
for f = 1, 8 do emu.frameadvance() end
joypad.set({ A = true }, 1); emu.frameadvance(); joypad.set({}, 1)
for f = 1, 30 do emu.frameadvance() end

-- Phase byte should be FS_NAV again ($01).
local domain = "68K RAM"
local phase = memory.read_u8(0x07F0, domain)
local fh = io.open(OUT, "w")
fh:write(string.format("phase_after_copy,0x%02X\n", phase))
fh:close()
client.exit()
```

- [ ] **Step 2: Checker**

```python
# check_copy_flow.py
import csv, sys
from pathlib import Path
CSV = Path(__file__).resolve().parent / "out" / "copy_flow.csv"
data = {row[0]: row[1] for row in csv.reader(CSV.open())}
if int(data["phase_after_copy"], 16) != 0x01:
    sys.exit(f"FAIL: phase = {data['phase_after_copy']}, expected 0x01")
print("PASS: COPY flow returns to FS_NAV")
```

- [ ] **Step 3: Run + commit**

```bash
tools/file_select_demo/build.bat
"%BIZHAWK_DIR%\EmuHawk.exe" --lua=tools/file_select_test/probe_copy_flow.lua tools/file_select_demo/out/fs_demo.md
python tools/file_select_test/check_copy_flow.py
git add tools/file_select_test/probe_copy_flow.lua tools/file_select_test/check_copy_flow.py
git commit -m "fs/test: COPY flow probe — phase returns to NAV after dst pick"
```

---

## v5a — OPTIONS Submenu Render

**Gate:** golden frame on FS_OPTIONS screen, RAM probe on `s_fs_options_cursor` skips headers correctly.

### Task v5a.1: `src/fs_options.h` + `src/fs_options.c`

**Files:**
- Create: `src/fs_options.h`, `src/fs_options.c`

- [ ] **Step 1: Row table + header**

```c
/* src/fs_options.h */
#ifndef FS_OPTIONS_H
#define FS_OPTIONS_H
#include <stdint.h>
#include "fs_sram.h"  /* FS_N_OPTIONS */

#define FS_N_OPTIONS_DISPLAY_ROWS  21   /* 4 headers + 16 rows + 1 SAVE */

extern uint8_t s_fs_options_cursor;
extern uint8_t s_fs_options_working[FS_N_OPTIONS];

typedef struct {
    const char *label;       /* row label or category header text */
    uint8_t     is_header;   /* 1 = category header, cursor skips */
    uint8_t     option_idx;  /* index into s_fs_options_working[] (0..15), unused if header */
    uint8_t     n_choices;   /* 2 or 3 */
    const char *choices[3];  /* up to 3 values */
} fs_options_row_t;

extern const fs_options_row_t fs_options_rows[FS_N_OPTIONS_DISPLAY_ROWS];

void fs_options_enter(void);
void fs_options_step(void);
void fs_options_input(uint8_t edge);

#endif
```

- [ ] **Step 2: Implementation skeleton with row table**

```c
/* src/fs_options.c */
#include "fs_options.h"
#include "fs_phase.h"
#include "fs_render.h"
#include "fs_sram.h"
#include "fs_input.h"
#include <stdint.h>

uint8_t s_fs_options_cursor;
uint8_t s_fs_options_working[FS_N_OPTIONS];

const fs_options_row_t fs_options_rows[FS_N_OPTIONS_DISPLAY_ROWS] = {
    { "GRAPHICS",      1, 0xFF, 0, {NULL,NULL,NULL} },
    { "LINK GFX",      0,  0,   2, {"REDUX","NES",NULL} },
    { "TUNIC COLOR",   0,  1,   3, {"TUNIC","RING","NES"} },
    { "FONT",          0,  2,   3, {"REDUX","BIG","FDS"} },
    { "HUD",           0,  3,   2, {"REDUX","NES",NULL} },
    { "AUTOMAP",       0,  4,   2, {"ON","OFF",NULL} },
    { "OW COLUMNS",    0,  5,   2, {"REDUX","NES",NULL} },
    { "DUNGEON COLR",  0,  6,   2, {"ON","OFF",NULL} },
    { "AUDIO",         1, 0xFF, 0, {NULL,NULL,NULL} },
    { "LOW HP SFX",    0,  7,   3, {"BEEP","HEART","OFF"} },
    { "COMBAT",        1, 0xFF, 0, {NULL,NULL,NULL} },
    { "SWORD ARC",     0,  8,   2, {"ALTTP","NES",NULL} },
    { "DIAG SWORD",    0,  9,   2, {"ON","OFF",NULL} },
    { "LIKE LIKES",    0, 10,   2, {"SHIELD","RUPEES",NULL} },
    { "BOSSES",        0, 11,   2, {"REDUX","NES",NULL} },
    { "GAMEPLAY",      1, 0xFF, 0, {NULL,NULL,NULL} },
    { "BOMB UPGRADE",  0, 12,   2, {"+10","+5",NULL} },
    { "START HEARTS",  0, 13,   2, {"FULL","3",NULL} },
    { "LOST WOODS",    0, 14,   2, {"NES","REDUX",NULL} },
    { "SECRETS",       0, 15,   2, {"REDUX","NES",NULL} },
    { "SAVE",          0, 0xFE, 0, {NULL,NULL,NULL} },   /* 0xFE = SAVE row sentinel */
};

extern void fs_render_options_screen(void);
extern void fs_render_options_row(uint8_t display_row);
extern void fs_render_options_cursor(uint8_t display_row);

static uint8_t first_non_header_row(void) {
    for (uint8_t i = 0; i < FS_N_OPTIONS_DISPLAY_ROWS; i++) {
        if (!fs_options_rows[i].is_header) return i;
    }
    return 0;
}

void fs_options_enter(void) {
    fs_sram_load_options(s_fs_options_working);
    s_fs_options_cursor = first_non_header_row();
    fs_render_options_screen();
    fs_render_options_cursor(s_fs_options_cursor);
}

void fs_options_step(void) {
    /* Visible debug — write submenu cursor to NES RAM[$07F3] for probe. */
    *(volatile uint8_t *)0x00FF07F3 = s_fs_options_cursor;
}

void fs_options_input(uint8_t edge) {
    if (edge & FS_BTN_B) {
        fs_sram_commit_options(s_fs_options_working);
        s_fs_phase = FS_NAV;
        fs_render_static_layout();
        fs_render_all_slots();
        fs_render_cursor(s_fs_cursor);
        return;
    }
    if (edge & FS_BTN_UP) {
        if (s_fs_options_cursor > 0) {
            do { s_fs_options_cursor--; }
            while (s_fs_options_cursor > 0 && fs_options_rows[s_fs_options_cursor].is_header);
            fs_render_options_cursor(s_fs_options_cursor);
        }
    }
    if (edge & FS_BTN_DOWN) {
        if (s_fs_options_cursor < FS_N_OPTIONS_DISPLAY_ROWS - 1) {
            do { s_fs_options_cursor++; }
            while (s_fs_options_cursor < FS_N_OPTIONS_DISPLAY_ROWS - 1
                   && fs_options_rows[s_fs_options_cursor].is_header);
            fs_render_options_cursor(s_fs_options_cursor);
        }
    }
    if (edge & (FS_BTN_LEFT | FS_BTN_RIGHT | FS_BTN_A)) {
        const fs_options_row_t *r = &fs_options_rows[s_fs_options_cursor];
        if (r->option_idx == 0xFE) {
            /* SAVE row: same as B. */
            fs_sram_commit_options(s_fs_options_working);
            s_fs_phase = FS_NAV;
            fs_render_static_layout();
            fs_render_all_slots();
            fs_render_cursor(s_fs_cursor);
            return;
        }
        if (r->option_idx < FS_N_OPTIONS) {
            uint8_t v = s_fs_options_working[r->option_idx];
            if (edge & FS_BTN_LEFT)  v = (v == 0) ? r->n_choices - 1 : v - 1;
            else                      v = (v + 1) % r->n_choices;
            s_fs_options_working[r->option_idx] = v;
            fs_render_options_row(s_fs_options_cursor);
        }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add src/fs_options.h src/fs_options.c
git commit -m "fs/options: row table + enter/step/input + nav with header skip"
```

### Task v5a.2: OPTIONS render functions

**Files:**
- Modify: `src/fs_render.h`, `src/fs_render.c`

- [ ] **Step 1: Add render API**

In `fs_render.h`:

```c
void fs_render_options_screen(void);
void fs_render_options_row(uint8_t display_row);
void fs_render_options_cursor(uint8_t display_row);
```

- [ ] **Step 2: Implement**

In `fs_render.c`:

```c
#include "fs_options.h"

extern uint8_t font_tile_for_char(char c);  /* declare helper */

static void render_text_at(unsigned short row, unsigned short col, const char *s,
                            unsigned short *cells, unsigned short col_max) {
    for (; *s && col < col_max; s++, col++) {
        cells[col] = (uint16_t)font_tile_for_char(*s);
    }
}

void fs_render_options_screen(void) {
    fs_render_clear_screen();
    static unsigned short row_cells[32];
    for (uint8_t r = 0; r < FS_N_OPTIONS_DISPLAY_ROWS; r++) {
        for (unsigned short c = 0; c < 32; c++) row_cells[c] = 0x24;
        const fs_options_row_t *row = &fs_options_rows[r];
        unsigned short col = row->is_header ? 14 : 4;
        render_text_at(0, col, row->label, row_cells, 32);
        if (!row->is_header && row->option_idx < FS_N_OPTIONS) {
            uint8_t v = s_fs_options_working[row->option_idx];
            if (v < row->n_choices)
                render_text_at(0, 18, row->choices[v], row_cells, 32);
        }
        vdp_write_nametable_row(0xC000, r + 2, row_cells);  /* +2 leaves header */
    }
}

void fs_render_options_row(uint8_t display_row) {
    static unsigned short row_cells[32];
    for (unsigned short c = 0; c < 32; c++) row_cells[c] = 0x24;
    const fs_options_row_t *row = &fs_options_rows[display_row];
    render_text_at(0, 4, row->label, row_cells, 32);
    if (!row->is_header && row->option_idx < FS_N_OPTIONS) {
        uint8_t v = s_fs_options_working[row->option_idx];
        if (v < row->n_choices)
            render_text_at(0, 18, row->choices[v], row_cells, 32);
    }
    vdp_write_nametable_row(0xC000, display_row + 2, row_cells);
}

void fs_render_options_cursor(uint8_t display_row) {
    /* Heart cursor at SAT entry 7, Y from row offset. */
    uint16_t y = 128 + 16 + 8 * display_row;
    uint16_t tile_attr = (1 << 13) | HEART_CHR_BASE;
    sat_write(7, y, 0x0000, tile_attr, 128 + 16);
}
```

- [ ] **Step 3: Commit**

```bash
git add src/fs_render.h src/fs_render.c
git commit -m "fs/render: OPTIONS screen + row + cursor"
```

### Task v5a.3: Wire FS_OPTIONS into phase + main dispatch

**Files:**
- Modify: `src/fs_main.c`, `src/fs_phase.c`

- [ ] **Step 1: Phase dispatch**

In `fs_phase.c`:

```c
#include "fs_options.h"

void fs_phase_step(void) {
    NES_RAM[0x07F0] = s_fs_phase;
    NES_RAM[0x07F1] = s_fs_cursor;
    switch (s_fs_phase) {
        case FS_LOAD: ...
        case FS_OPTIONS: fs_options_step(); break;
        ...
    }
}
```

- [ ] **Step 2: Main dispatch input route**

In `fs_main.c`:

```c
static void fs_input_dispatch(uint8_t edge) {
    if (s_fs_phase == FS_NAV) { ... }
    else if (s_fs_phase >= FS_COPY_SRC && s_fs_phase <= FS_ERASE_CONFIRM) {
        fs_copy_erase_input(edge);
    }
    else if (s_fs_phase == FS_OPTIONS) {
        fs_options_input(edge);
    }
}
```

In FS_NAV cursor==6 A handler:

```c
case 6:
    s_fs_phase = FS_OPTIONS;
    fs_options_enter();
    break;
```

- [ ] **Step 3: build.bat add fs_options.o**

- [ ] **Step 4: Build + commit**

```bash
tools/file_select_demo/build.bat
git add src/fs_main.c src/fs_phase.c tools/file_select_demo/build.bat
git commit -m "fs/main: wire FS_OPTIONS — A on row 6 enters submenu, B exits"
```

### Task v5a.4: OPTIONS golden frame + cursor probe

**Files:**
- Create: `tools/file_select_test/probe_options_cursor.lua`
- Create: `tools/file_select_test/check_options_cursor.py`

- [ ] **Step 1: Probe — assert cursor skips headers**

```lua
-- probe_options_cursor.lua
local REPO = os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY"
local OUT  = REPO .. "\\tools\\file_select_test\\out\\options_cursor.csv"
for f = 1, 30 do emu.frameadvance() end
for d = 1, 6 do joypad.set({ Down = true }, 1); emu.frameadvance(); joypad.set({}, 1)
                for f = 1, 8 do emu.frameadvance() end end
joypad.set({ A = true }, 1); emu.frameadvance(); joypad.set({}, 1)
for f = 1, 30 do emu.frameadvance() end

local fh = io.open(OUT, "w")
fh:write("step,cursor\n")
fh:write(string.format("0,%d\n", memory.read_u8(0x07F3, "68K RAM")))
-- 7 Downs — cursor must visit 7 different non-header rows.
for s = 1, 7 do
    joypad.set({ Down = true }, 1); emu.frameadvance(); joypad.set({}, 1)
    for f = 1, 8 do emu.frameadvance() end
    fh:write(string.format("%d,%d\n", s, memory.read_u8(0x07F3, "68K RAM")))
end
fh:close()
client.exit()
```

- [ ] **Step 2: Checker — assert all cursor positions point to non-header rows**

```python
# check_options_cursor.py
import csv, sys
from pathlib import Path

# Expected non-header row indices (from fs_options_rows[]).
NON_HEADER_ROWS = [1, 2, 3, 4, 5, 6, 7, 9, 11, 12, 13, 14, 16, 17, 18, 19, 20]

CSV = Path(__file__).resolve().parent / "out" / "options_cursor.csv"
errs = []
for row in csv.DictReader(CSV.open()):
    cur = int(row["cursor"])
    if cur not in NON_HEADER_ROWS:
        errs.append(f"step {row['step']}: cursor={cur} is header row, should skip")
if errs:
    for e in errs: print("FAIL:", e)
    sys.exit(1)
print("PASS: cursor never lands on header row")
```

- [ ] **Step 3: Run + commit**

```bash
"%BIZHAWK_DIR%\EmuHawk.exe" --lua=tools/file_select_test/probe_options_cursor.lua tools/file_select_demo/out/fs_demo.md
python tools/file_select_test/check_options_cursor.py
git add tools/file_select_test/probe_options_cursor.lua tools/file_select_test/check_options_cursor.py
git commit -m "fs/test: OPTIONS cursor never lands on category headers"
```

---

## v5b — OPTIONS Commit + Working Copy

**Gate:** scripted input flips toggles, B exits, soft-reset, re-enter OPTIONS, values match.

### Task v5b.1: Verify enter loads from SRAM, B commits to SRAM

Already implemented in `fs_options_enter` (loads) and `fs_options_input` B-handler (commits). Test it.

**Files:**
- Create: `tools/file_select_test/probe_options_commit.lua`
- Create: `tools/file_select_test/check_options_commit.py`

- [ ] **Step 1: Probe**

```lua
-- probe_options_commit.lua
for f = 1, 30 do emu.frameadvance() end
-- Down 6, A enters OPTIONS.
for d = 1, 6 do joypad.set({ Down = true }, 1); emu.frameadvance(); joypad.set({}, 1)
                for f = 1, 8 do emu.frameadvance() end end
joypad.set({ A = true }, 1); emu.frameadvance(); joypad.set({}, 1)
for f = 1, 30 do emu.frameadvance() end
-- LINK GFX is first row. Press Right to flip 0->1.
joypad.set({ Right = true }, 1); emu.frameadvance(); joypad.set({}, 1)
for f = 1, 8 do emu.frameadvance() end
-- B exits + commits.
joypad.set({ B = true }, 1); emu.frameadvance(); joypad.set({}, 1)
for f = 1, 30 do emu.frameadvance() end
client.softreset()
for f = 1, 60 do emu.frameadvance() end
local v = memory.read_u8(0x7000, "M68K BUS")  -- LINK GFX SRAM byte
local fh = io.open((os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY") .. "\\tools\\file_select_test\\out\\options_commit.csv", "w")
fh:write(string.format("link_gfx,%d\n", v))
fh:close()
client.exit()
```

- [ ] **Step 2: Checker**

```python
# check_options_commit.py
import csv, sys
from pathlib import Path
CSV = Path(__file__).resolve().parent / "out" / "options_commit.csv"
data = {row[0]: row[1] for row in csv.reader(CSV.open())}
if int(data["link_gfx"]) != 1:
    sys.exit(f"FAIL: LINK GFX SRAM byte = {data['link_gfx']}, expected 1")
print("PASS: OPTIONS commit + reload preserves change")
```

- [ ] **Step 3: Run + commit**

```bash
"%BIZHAWK_DIR%\EmuHawk.exe" --lua=tools/file_select_test/probe_options_commit.lua tools/file_select_demo/out/fs_demo.md
python tools/file_select_test/check_options_commit.py
git add tools/file_select_test/probe_options_commit.lua tools/file_select_test/check_options_commit.py
git commit -m "fs/test: OPTIONS commit roundtrip across soft-reset"
```

---

## v5c — Wire LOW HP SFX into Engine

**Gate:** scripted input sets each LOW HP SFX value, hard-reset, verify SRAM byte; manual audio listen.

### Task v5c.1: Identify low-health beep callsite

**Files:**
- Read: `src/audio_driver.asm`, `src/z_*.asm`

- [ ] **Step 1: Grep for low-HP audio call**

```bash
grep -rn "low.*health\|LowHealth\|warn_beep\|life.*beep" src/*.asm | head -30
```

- [ ] **Step 2: Document callsite line in spec NES-truth table**

Add row to spec: `LOW HP beep callsite | src/audio_driver.asm:LINE`.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-04-27-native-file-select-design.md
git commit -m "spec: lock LOW HP beep callsite"
```

### Task v5c.2: Add SRAM read + branch at callsite

**Files:**
- Modify: `src/audio_driver.asm` (or wherever callsite lives)

- [ ] **Step 1: Insert branch**

At the identified callsite (assume `src/audio_driver.asm:NNN`):

```asm
; LOW HP SFX option:
;   0 = BEEP (default, unchanged behavior)
;   1 = HEART (alternate sound — falls back to BEEP if not implemented)
;   2 = OFF (skip beep)
SRAM_LOW_HP_SFX equ $7007

LowHpBeep:
    move.b  (SRAM_LOW_HP_SFX).l, D0      ; via SRAM mapper window
    cmp.b   #2, D0
    beq     .skip
    cmp.b   #1, D0
    beq     .heart_variant_or_fallback
    ; default beep behavior continues here:
    [existing beep code]
    rts
.heart_variant_or_fallback:
    ; v5c: heart variant not yet ported — fall back to default beep.
    [existing beep code]
    rts
.skip:
    rts
```

Note: SRAM read on Genesis goes through the SRAM mapper. Use existing pattern from `_sram_load_save_slots`.

- [ ] **Step 2: Build main ROM**

```bash
build.bat
```

Expected: clean build.

- [ ] **Step 3: Commit**

```bash
git add src/audio_driver.asm
git commit -m "fs/wire: LOW HP SFX SRAM gate at low-health beep callsite"
```

### Task v5c.3: Probe — verify SRAM value reaches engine

**Files:**
- Create: `tools/file_select_test/probe_low_hp_sfx.lua`

- [ ] **Step 1: Probe — set value, hard-reset main ROM, sample audio_driver path**

For now, just verify SRAM byte set correctly and beep-callsite reachable. Audio listen = manual.

```lua
-- probe_low_hp_sfx.lua
for f = 1, 30 do emu.frameadvance() end
for d = 1, 6 do joypad.set({ Down = true }, 1); emu.frameadvance(); joypad.set({}, 1)
                for f = 1, 8 do emu.frameadvance() end end
joypad.set({ A = true }, 1); emu.frameadvance(); joypad.set({}, 1)
-- Cursor on LINK GFX. Down to LOW HP SFX (display row 9).
for d = 1, 6 do joypad.set({ Down = true }, 1); emu.frameadvance(); joypad.set({}, 1)
                for f = 1, 8 do emu.frameadvance() end end
joypad.set({ Right = true }, 1); emu.frameadvance(); joypad.set({}, 1)
joypad.set({ Right = true }, 1); emu.frameadvance(); joypad.set({}, 1)
joypad.set({ B = true }, 1); emu.frameadvance(); joypad.set({}, 1)
for f = 1, 30 do emu.frameadvance() end
local v = memory.read_u8(0x7007, "M68K BUS")
print(string.format("LOW HP SFX = %d", v))
client.exit()
```

- [ ] **Step 2: Run + manual confirm**

```bash
"%BIZHAWK_DIR%\EmuHawk.exe" --lua=tools/file_select_test/probe_low_hp_sfx.lua tools/file_select_demo/out/fs_demo.md
```

Expected: console says `LOW HP SFX = 2`.

- [ ] **Step 3: Commit**

```bash
git add tools/file_select_test/probe_low_hp_sfx.lua
git commit -m "fs/test: LOW HP SFX value reaches SRAM byte $7007"
```

---

## v5d — Wire AUTOMAP into Engine

**Gate:** golden frame compare with AUTOMAP=ON vs AUTOMAP=OFF inside game (after v6 lands gameplay entry). For v5d alone, verify SRAM byte + branch at callsite.

### Task v5d.1: Identify automap render callsite

**Files:**
- Read: `src/z_*.asm` (HUD/automap renderer)

- [ ] **Step 1: Grep for automap render**

```bash
grep -rn "DrawAutomap\|automap\|RenderMap\|UpdateMap" src/*.asm | head -20
```

- [ ] **Step 2: Document + commit**

```bash
git add docs/superpowers/specs/2026-04-27-native-file-select-design.md
git commit -m "spec: lock AUTOMAP render callsite"
```

### Task v5d.2: Add SRAM gate

**Files:**
- Modify: identified `src/z_*.asm` automap render path.

- [ ] **Step 1: Insert branch**

```asm
SRAM_AUTOMAP equ $7004

DrawAutomap:
    move.b  (SRAM_AUTOMAP).l, D0
    bne     .skip                ; non-zero = OFF
    [existing automap render]
    rts
.skip:
    rts
```

- [ ] **Step 2: Build + commit**

```bash
build.bat
git add src/z_*.asm
git commit -m "fs/wire: AUTOMAP SRAM gate at HUD render callsite"
```

---

## v6 — Promote to Main ROM

**Gate:** Layer 3 handoff smoke + full gameplay entry smoke pass.

### Task v6.R1: Resolve TBD #1 — MODE_REGISTER_NAME, MODE_GAMEPLAY_LOAD

**Files:**
- Read: `src/z_*.asm`

- [ ] **Step 1: Grep**

```bash
grep -rn "Mode_RegisterYourName\|MODE_REGISTER\|Mode_GameLoad\|MODE_GAMEPLAY" src/*.asm | head -20
```

- [ ] **Step 2: Document + commit**

Edit spec NES-truth table: add `MODE_REGISTER_NAME`, `MODE_GAMEPLAY_LOAD` byte values + source lines.

```bash
git add docs/superpowers/specs/2026-04-27-native-file-select-design.md
git commit -m "spec: lock TBD #1 transpiled mode constants"
```

### Task v6.R2: Resolve TBD #2 — current_save_slot offset

- [ ] **Step 1: Grep**

```bash
grep -rn "current_save_slot\|save_slot_idx\|SaveSlotN\|CurrentSlot" src/*.asm | head -20
```

- [ ] **Step 2: Commit doc**

### Task v6.R3: Resolve TBD #3 — translated_mainloop_reentry

- [ ] **Step 1: Grep — same procedure as intro spec TBD #3**

```bash
grep -rn "translated_mainloop\|main_loop_reentry\|GameLoop\|MainLoop" src/*.asm | head -20
```

- [ ] **Step 2: Document + commit**

### Task v6.R5: Resolve TBD #5 — save loader symbol

- [ ] **Step 1: Grep**

```bash
grep -rn "LoadSaveSlot\|sram_load\|save_load\|LoadGame" src/*.asm | head -20
```

- [ ] **Step 2: Document + commit**

### Task v6.1: ASM trampoline + dispatcher byte

**Files:**
- Modify: `src/genesis_shell.asm`

- [ ] **Step 1: Add `.bss` byte**

In named-RAM-block section of `genesis_shell.asm`:

```asm
fs_native_active:
    ds.b    1
    even
```

- [ ] **Step 2: Add trampoline**

```asm
; fs_to_transpiled_trampoline(uint8_t mode_target)
;   mode_target in D0 (low byte) — passed by caller.
;   Restores translated runtime register contract, seeds NES RAM,
;   re-enables PPUCTRL bit 7, flips dispatcher to transpiled, jumps.
;
; Caller responsibility (in fs_handoff.c): vdp_display_off, plane clears,
; V64 mode set, vscroll=0 BEFORE calling. Trampoline is ASM-only.

fs_to_transpiled_trampoline:
    ; D0 = mode_target byte from caller (C calling convention: 1st arg in D0/D1).
    move.b  D0, -(SP)                         ; preserve mode_target
    move.l  #$00FF0000, A4
    move.l  #$00FF0200, A5
    moveq   #-1, D7
    move.b  (SP)+, D0                         ; restore
    move.b  D0, GAMEMODE_OFFSET(A4)           ; TBD: actual offset from intro spec
    move.b  #0, SUBMODE_OFFSET(A4)
    move.b  #1, FRONT_START_RELEASE_GATE_OFFSET(A4)
    move.b  #0, VRAM_FORCE_BLANK_GATE_OFFSET(A4)
    ; Re-enable PPUCTRL bit 7 (NMI enable) via _ppu_write_0.
    move.b  ($00FF,A4), D0
    ori.b   #$80, D0
    bsr     _ppu_write_0
    move.b  #1, vblank_mode
    move.b  #0, fs_native_active
    jmp     translated_mainloop_reentry
```

- [ ] **Step 3: Build main ROM, verify no link error**

```bash
build.bat
```

Expected: clean. `fs_native_active` symbol resolved.

- [ ] **Step 4: Commit**

```bash
git add src/genesis_shell.asm
git commit -m "fs/asm: fs_to_transpiled_trampoline + fs_native_active (v6 plumbing)"
```

### Task v6.2: `src/fs_handoff.h` + `src/fs_handoff.c`

**Files:**
- Create: `src/fs_handoff.h`, `src/fs_handoff.c`

- [ ] **Step 1: Header**

```c
/* src/fs_handoff.h */
#ifndef FS_HANDOFF_H
#define FS_HANDOFF_H
#include <stdint.h>

void fs_handoff_to_transpiled(uint8_t slot);

#endif
```

- [ ] **Step 2: Implementation**

```c
/* src/fs_handoff.c */
#include "fs_handoff.h"
#include "fs_sram.h"
#include "intro_common.h"
#include "nes_abi.h"
#include <stdint.h>

extern void fs_to_transpiled_trampoline(uint8_t mode_target);

#define MODE_REGISTER_NAME  0x07   /* TBD v6.R1 — placeholder, replace */
#define MODE_GAMEPLAY_LOAD  0x10   /* TBD v6.R1 — placeholder */
#define CURRENT_SAVE_SLOT_OFFSET  0x0500  /* TBD v6.R2 — placeholder */

static void clear_plane(unsigned short plane_base) {
    unsigned short zero_row[32];
    for (unsigned short i = 0; i < 32; i++) zero_row[i] = 0;
    for (unsigned short i = 0; i < 32; i++) vdp_write_nametable_row(plane_base, i, zero_row);
}

void fs_handoff_to_transpiled(uint8_t slot) {
    nes_ram[0x07F2] = 0xAA;   /* probe: handoff begun */
    vdp_display_off();
    clear_plane(0xC000);
    clear_plane(0xE000);
    vdp_set_mode_v64();
    vdp_set_vscroll(0);

    uint8_t mode_target;
    if (fs_sram_slot_occupied(slot)) {
        nes_ram[CURRENT_SAVE_SLOT_OFFSET] = slot;
        mode_target = MODE_GAMEPLAY_LOAD;
    } else {
        mode_target = MODE_REGISTER_NAME;
    }
    fs_to_transpiled_trampoline(mode_target);
    /* unreachable */
}
```

- [ ] **Step 3: Wire FS_HANDOFF in fs_phase.c**

```c
#include "fs_handoff.h"
extern uint8_t s_fs_cursor;

case FS_HANDOFF:
    fs_handoff_to_transpiled(s_fs_cursor);
    /* unreachable */
    break;
```

- [ ] **Step 4: FS_NAV slot pick wires to FS_HANDOFF (remove v4 stub)**

In `fs_main.c` slot 0/1/2 case: `s_fs_phase = FS_HANDOFF;` (not reverted to NAV).

- [ ] **Step 5: Commit**

```bash
git add src/fs_handoff.h src/fs_handoff.c src/fs_phase.c src/fs_main.c
git commit -m "fs/handoff: FS_HANDOFF phase + ASM trampoline call (slot pick path)"
```

### Task v6.3: Modify intro_handoff to call fs_main

**Files:**
- Modify: `src/intro_handoff.c`

- [ ] **Step 1: Replace trampoline call with fs_main**

```c
/* src/intro_handoff.c */
#include "intro_handoff.h"
#include "intro_common.h"
#include "nes_abi.h"
#include "fs_main.h"

extern uint8_t fs_native_active;

static void clear_plane(unsigned short plane_base) {
    unsigned short zero_row[32];
    for (unsigned short i = 0; i < 32; i++) zero_row[i] = 0;
    for (unsigned short i = 0; i < 32; i++) vdp_write_nametable_row(plane_base, i, zero_row);
}

void intro_start_pressed(void) {
    nes_ram[0x07F2] = 0xAA;
    vdp_display_off();
    clear_plane(0xC000);
    clear_plane(0xE000);
    vdp_set_mode_v64();
    vdp_set_vscroll(0);
    fs_native_active = 1;
    fs_main();   /* never returns */
}
```

- [ ] **Step 2: Build main ROM**

```bash
build.bat
```

Expected: clean build.

- [ ] **Step 3: Commit**

```bash
git add src/intro_handoff.c
git commit -m "fs/handoff: intro Start press now lands native FS instead of transpiled"
```

### Task v6.4: Layer 3 handoff smoke test

**Files:**
- Create: `tools/file_select_test/probe_handoff.lua`
- Create: `tools/file_select_test/check_handoff_contract.py`

- [ ] **Step 1: Probe**

```lua
-- probe_handoff.lua: boot main ROM, advance through intro, Start, FS, A on slot.
-- Assert post-trampoline state.
local REPO = os.getenv("CODEX_BIZHAWK_ROOT") or "C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY"
local OUT  = REPO .. "\\tools\\file_select_test\\out\\handoff.csv"

-- Past intro fade (~600 frames covers title + fade + part of story).
for f = 1, 700 do emu.frameadvance() end
joypad.set({ Start = true }, 1); emu.frameadvance(); joypad.set({}, 1)
for f = 1, 60 do emu.frameadvance() end
-- Now in native FS. Cursor on slot 0. A picks.
joypad.set({ A = true }, 1); emu.frameadvance(); joypad.set({}, 1)
for f = 1, 30 do emu.frameadvance() end

local domain = "68K RAM"
local fh = io.open(OUT, "w")
fh:write("key,value\n")
fh:write(string.format("vblank_mode,0x%02X\n", memory.read_u8(0xFF????, domain)))   -- TBD addr
fh:write(string.format("fs_native_active,0x%02X\n", memory.read_u8(0xFF????, domain)))
fh:write(string.format("gamemode,0x%02X\n", memory.read_u8(0xFF0000 + 0x07F0, domain)))  -- adjust per spec
fh:write(string.format("handoff_marker,0x%02X\n", memory.read_u8(0xFF07F2, domain)))
fh:close()
client.exit()
```

- [ ] **Step 2: Checker**

```python
# check_handoff_contract.py
import csv, sys
from pathlib import Path
CSV = Path(__file__).resolve().parent / "out" / "handoff.csv"
data = {row["key"]: row["value"] for row in csv.DictReader(CSV.open())}
errs = []
if int(data["vblank_mode"], 16) != 1:
    errs.append(f"vblank_mode = {data['vblank_mode']}, expected 1")
if int(data["fs_native_active"], 16) != 0:
    errs.append(f"fs_native_active = {data['fs_native_active']}, expected 0")
if int(data["handoff_marker"], 16) != 0xAA:
    errs.append(f"handoff_marker = {data['handoff_marker']}, expected 0xAA")
if errs:
    for e in errs: print("FAIL:", e)
    sys.exit(1)
print("PASS: handoff contract intact")
```

- [ ] **Step 3: Run + commit**

```bash
"%BIZHAWK_DIR%\EmuHawk.exe" --lua=tools/file_select_test/probe_handoff.lua builds/whatif.md
python tools/file_select_test/check_handoff_contract.py
git add tools/file_select_test/probe_handoff.lua tools/file_select_test/check_handoff_contract.py
git commit -m "fs/test: Layer 3 handoff smoke (vblank_mode + fs_native_active + marker)"
```

### Task v6.5: Full gameplay entry smoke

**Files:**
- Create: `tools/file_select_test/probe_gameplay_entry.lua`

- [ ] **Step 1: Probe — boot intro, Start, FS, A on saved slot, advance, assert game-mode byte**

```lua
-- probe_gameplay_entry.lua
for f = 1, 700 do emu.frameadvance() end
joypad.set({ Start = true }, 1); emu.frameadvance(); joypad.set({}, 1)
for f = 1, 60 do emu.frameadvance() end
joypad.set({ A = true }, 1); emu.frameadvance(); joypad.set({}, 1)
for f = 1, 240 do emu.frameadvance() end   -- give transpiled gameplay time to init

-- Sample GAMEMODE byte. Expect it to be the Mode_GameLoad / Mode_Gameplay value.
local mode = memory.read_u8(0xFF0000 + 0x07F0, "68K RAM")
print(string.format("game mode byte = 0x%02X", mode))
client.exit()
```

- [ ] **Step 2: Run + verify by eye + commit**

```bash
"%BIZHAWK_DIR%\EmuHawk.exe" --lua=tools/file_select_test/probe_gameplay_entry.lua builds/whatif.md
git add tools/file_select_test/probe_gameplay_entry.lua
git commit -m "fs/test: gameplay entry smoke (boot→FS→saved slot→game)"
```

### Task v6.6: run_full.bat — orchestrator

**Files:**
- Create: `tools/file_select_test/run_full.bat`

- [ ] **Step 1: Orchestrator**

Mirror `tools/intro_test/run_full.bat`. Run probe_phase_sequence + probe_options_persist + probe_options_commit + probe_handoff + probe_gameplay_entry. Each followed by its check_*.py.

- [ ] **Step 2: Commit**

```bash
git add tools/file_select_test/run_full.bat
git commit -m "fs/test: run_full.bat orchestrates Layer 1+3+4 + visual probes"
```

### Task v6.7: Hook Layer 1 + Layer 4 into proof-ROM build.bat

**Files:**
- Modify: `tools/file_select_demo/build.bat`

- [ ] **Step 1: Append post-link step**

```bat
echo [fs_demo] running Layer 1 + Layer 4 probes
"%BIZHAWK_EXE%" --lua=%ROOT%\tools\file_select_test\probe_phase_sequence.lua %OUT_DIR%\fs_demo.md
"%PYTHON%" %ROOT%\tools\file_select_test\check_probe_sequence.py || exit /b 1
"%BIZHAWK_EXE%" --lua=%ROOT%\tools\file_select_test\probe_options_persist.lua %OUT_DIR%\fs_demo.md
"%PYTHON%" %ROOT%\tools\file_select_test\check_options_persist.py || exit /b 1
echo [fs_demo] Layer 1 + Layer 4 PASS
```

(Use same BizHawk locator pattern as `tools/intro_test/run_full.bat`.)

- [ ] **Step 2: Commit**

```bash
git add tools/file_select_demo/build.bat
git commit -m "fs/demo: build.bat now runs Layer 1 + Layer 4 post-link"
```

### Task v6.8: Layer 3 hook into main build.bat

**Files:**
- Modify: `build.bat` (root)

- [ ] **Step 1: Append post-link step**

```bat
echo [main] running Layer 3 handoff smoke
"%BIZHAWK_EXE%" --lua=%ROOT%\tools\file_select_test\probe_handoff.lua %OUT_DIR%\whatif.md
"%PYTHON%" %ROOT%\tools\file_select_test\check_handoff_contract.py || exit /b 1
echo [main] Layer 3 PASS
```

- [ ] **Step 2: Commit**

```bash
git add build.bat
git commit -m "main/build: run Layer 3 handoff smoke post-link"
```

---

## Self-Review

Spec coverage check:

| Spec section | Tasks |
|---|---|
| Goal — native FS Screen 1, Redux look, PLAYERS, OPTIONS | v1.* (render+layout), v3.2 (PLAYERS), v5a-b (OPTIONS) |
| Q1 standalone proof ROM | v1.7 boot.asm, v1.8 build.bat |
| Q2 PLAYERS global byte | v3.1 fs_sram, v3.2 wire |
| Q3 OPTIONS = 16 features | v5a.1 row table |
| Q4 linear nav | v2.4 dispatch |
| Q5 PLAYERS inline cycle | v3.2 |
| Q6 OPTIONS categories inline, cursor skip | v5a.1 row table, v5a.4 probe |
| Q7 working copy + B/SAVE commit | v5a.1 input, v5b.1 test |
| Q8 main ROM intro→FS only v1 | v6.3 intro_handoff |
| Q9 NES SRAM slots untouched, OPTIONS $7000+ | v3.1 fs_sram |
| Q10 empty→register-name, saved→gameplay | v6.2 fs_handoff |
| Q11 heart cursor, Link bright Redux palette | v1.10, v2.4 cursor render |
| Q12 NES FS music | v1.R4 + v2.6 |
| Q13 v1→v6 sequencing | structure |
| Q14 defaults | v3.1 default-init |
| Q15 LOW HP SFX + AUTOMAP wiring | v5c, v5d |
| Q16 COPY/ERASE Redux flow | v4.* |
| SRAM schema | v3.1 |
| TBDs 1-9 | dedicated R-tasks at start of relevant phase |
| Risks R1-R8 | TBD R-tasks address R1, R2, R6; R3 SRAM region range — needs explicit check task added below |

**Gap found — R3 (SRAM region conflict):** add task before v3.1.

### Task v3.0: Verify SRAM $7000+ unused (R3 mitigation)

**Files:**
- Read: `src/genesis_shell.asm`, all `src/z_*.asm`, `src/*.c`

- [ ] **Step 1: Grep for SRAM access in $7000-$71FF range**

```bash
grep -rn "\$70[0-9A-F][0-9A-F]\|\$71[0-3][0-9A-F]\|0x70[0-9A-F][0-9A-F]\|0x71[0-3][0-9A-F]" src/*.asm src/*.c | head -40
```

- [ ] **Step 2: Document findings**

If conflict found: pick alternate SRAM region (e.g. `$7200+`), update spec SRAM schema, update `fs_sram.c` constants. If no conflict: log clean.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-04-27-native-file-select-design.md
git commit -m "spec: verify R3 — SRAM \$7000+ free for OPTIONS region"
```

---

## Placeholder scan

- v3.1 has `SLOT_NAME_OFFSET(N) (0x6300 + (N) * 0x80)` placeholder. v3.R6 resolves before v3.1 codes. Plan order: R6 first.
- v6.2 has `MODE_REGISTER_NAME = 0x07`, `MODE_GAMEPLAY_LOAD = 0x10`, `CURRENT_SAVE_SLOT_OFFSET = 0x0500` placeholders. v6.R1, v6.R2 resolve before v6.2 codes. Plan order: R1, R2, R3, R5 first.
- v2.6 `SONG_FS_BIT` resolved: `0x00` (silent). v1.R4 complete. No further R4 action needed before v2.6 codes.

All placeholders gated by R-tasks scheduled before consuming task. Plan-execution order: R-tasks always run before the task that needs the value.

## Type consistency

- `s_fs_phase` declared in `fs_phase.h`, used in `fs_phase.c`, `fs_main.c`, `fs_options.c`, `fs_copy_erase.c`. Single declaration, all `extern` matches. ✓
- `fs_render_cursor(uint8_t row)` — same signature in header + impl + callers. ✓
- `fs_sram_slot_occupied(uint8_t slot)` — declared in `fs_sram.h`, weak-default in `fs_render.c` (v1 mock), real impl in `fs_sram.c` (v3 onward). Linker overrides weak after v3 lands. ✓
- `fs_to_transpiled_trampoline(uint8_t mode_target)` — C calling convention puts D0/D1 first arg; ASM uses D0. ✓
- `s_fs_options_working[FS_N_OPTIONS]` — `FS_N_OPTIONS = 16` in `fs_sram.h`. ✓

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-04-27-native-file-select.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — execute tasks in this session using executing-plans, batch with checkpoints.

**Which approach?**
