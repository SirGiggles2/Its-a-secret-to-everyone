# Intro Title Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the NES Zelda title screen (logo, vines, sword/Triforce, glow cycle, waterfall sprites, "PUSH START BUTTON") to the intro_demo Genesis ROM, with NES-faithful visuals and measured-visible-timing pacing, then transition into the existing story/items sequence and loop forever.

**Architecture:** Phase-driven state machine (`PHASE_TITLE_LOAD → TITLE_DISPLAY → TITLE_FADEOUT → BLACK_HOLD → STORY_LOAD → STORY_SCROLL_IN → STORY_HOLD → SCROLL_OFF → END_PAUSE → loop`). Two distinct VRAM/CRAM layouts (title vs story); load phases blank the display, swap content, then re-enable. Story/item runtime preserved verbatim — only repackaged behind `story_runtime_step()`.

**Tech Stack:** Genesis 68K bare metal (gcc-m68k, vasm), Python 3 asset generators, BizHawk Lua probes for verification. No libgcc — avoid 32-bit multiply/divide.

**Spec:** [docs/superpowers/specs/2026-04-25-intro-title-screen-design.md](../specs/2026-04-25-intro-title-screen-design.md)

---

## Conventions Used in This Plan

- **Verify**: build + run + Lua probe + visual side-by-side. No unit test framework — Genesis ROM tests are runtime probes.
- **`/c/tmp/intro_demo.md`**: stage path for BizHawk per `bizhawkScript` skill rules.
- **`run_build`**: shorthand for `& cmd.exe /c "cd /d \"<repo>/tools/intro_demo\" && .\build.bat"` from PowerShell. The build is fast (<10s).
- **No libgcc**: `__umodsi3` / `__mulsi3` / `__divsi3` will not link. Use bit-shifts, conditional branches for division/modulo, and 16-bit multiply only.
- **Frame counter**: u16 wraps at 65535. Each phase has its own counter.
- **Commit cadence**: every task ends in a commit.

---

## Task 0: Capture NES title PALRAM via BizHawk

**Files:**
- Run BizHawk against NES Zelda ROM (path TBD by user; common location `reference/aldonunez/zelda.nes` or similar)
- Lua probe (write inline to `/c/tmp/dump_title_palram.lua`)
- Output: `tools/intro_demo/nes_full/palram_title.bin`

- [ ] **Step 1: Locate NES Zelda ROM**

```bash
find "C:/Users/Jake Diggity" -maxdepth 6 -iname "zelda*.nes" 2>/dev/null | head -3
ls reference/aldonunez/ 2>/dev/null | grep -i nes | head -5
```

If no ROM in repo, ask user for path.

- [ ] **Step 2: Write Lua probe**

```lua
-- /c/tmp/dump_title_palram.lua
-- Run NES Zelda. Advance to frame 100 (stable title, before subphase 1 fade).
-- Dump $3F00..$3F1F (32 bytes) to palram_title.bin.

local TARGET_FRAME = 100
while emu.framecount() < TARGET_FRAME do
    emu.frameadvance()
end

local out = io.open("C:/tmp/palram_title.bin", "wb")
for addr = 0x3F00, 0x3F1F do
    out:write(string.char(memory.read_u8(addr, "PPU Bus") and 0 or 0))
end
-- WARNING: PPU Bus is unreliable. Use PALRAM domain instead.
out:close()

-- Also screenshot for visual confirmation
client.screenshot("C:/tmp/palram_title_screenshot.png")
client.exit()
```

Wait — per bizhawkScript skill memory, use proper memory domain. Replace `"PPU Bus"` with `"PALRAM"`:

```lua
-- /c/tmp/dump_title_palram.lua
local TARGET_FRAME = 100
while emu.framecount() < TARGET_FRAME do
    emu.frameadvance()
end
local out = io.open("C:/tmp/palram_title.bin", "wb")
for addr = 0, 0x1F do
    out:write(string.char(memory.read_u8(addr, "PALRAM")))
end
out:close()
client.screenshot("C:/tmp/palram_title_screenshot.png")
client.exit()
```

- [ ] **Step 3: Stage ROM + lua to /c/tmp**

```bash
cp <NES_ROM_PATH> /c/tmp/zelda.nes
cp /c/tmp/dump_title_palram.lua /c/tmp/dump_title_palram.lua  # already there
```

- [ ] **Step 4: Launch BizHawk NES (different EmuHawk?) — actually same EmuHawk, just NES ROM**

```bash
powershell -Command "Start-Process -FilePath 'C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe' -ArgumentList '--lua=C:\tmp\dump_title_palram.lua','C:\tmp\zelda.nes' -WorkingDirectory 'C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64'"
```

- [ ] **Step 5: Wait for capture**

Use Bash with `run_in_background` and polling:
```bash
until [ -f /c/tmp/palram_title.bin ]; do sleep 1; done; echo READY
```

- [ ] **Step 6: Verify file size + sanity**

```bash
ls -la /c/tmp/palram_title.bin
# Expect: 32 bytes
xxd /c/tmp/palram_title.bin
# Expect: $0F or $22 (sky blue) at offset 0; varied colors elsewhere
```

- [ ] **Step 7: Move into repo + commit**

```bash
mv /c/tmp/palram_title.bin tools/intro_demo/nes_full/palram_title.bin
mv /c/tmp/palram_title_screenshot.png tools/intro_demo/nes_full/palram_title_screenshot.png
git add tools/intro_demo/nes_full/palram_title.bin tools/intro_demo/nes_full/palram_title_screenshot.png
git commit -m "intro_demo: capture NES title PALRAM at frame 100"
```

---

## Task 1: Title BG CHR extraction script

**Files:**
- Create: `tools/intro_demo/extract_title_bg_chr.py`
- Output (generated, committed): `tools/intro_demo/intro_title_bg_chr.c`

- [ ] **Step 1: Write extractor**

```python
#!/usr/bin/env python3
"""Extract title BG tiles used by GameTitleTransferBuf.dat from
CommonBackgroundPatterns.dat, re-encoded 2bpp -> 4bpp Genesis.

The title tilemap references BG tiles by NES tile index. We compute
the unique set of indices used by the parsed nametable (Task 3 will
parse and emit a list); for now, extract a generous superset (all 256
tiles) to keep this independent of tilemap parsing order. The intro
demo ROM has plenty of VRAM headroom.

Output: intro_title_bg_chr.c with `intro_title_bg_chr[256*32]`,
size constant, and a comment marking each tile's NES index.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).parent))
from extract_sprite_chr import nes_tile_to_gen_tile

BG_DAT = ROOT / "reference" / "aldonunez" / "dat" / "CommonBackgroundPatterns.dat"
OUT    = Path(__file__).parent / "intro_title_bg_chr.c"

def main() -> int:
    bg_data = BG_DAT.read_bytes()
    n_tiles = len(bg_data) // 16
    gen = bytearray()
    for T in range(n_tiles):
        tile = bg_data[T*16:(T+1)*16]
        gen += nes_tile_to_gen_tile(tile, color_shift=0)

    lines = [
        "/* Auto-generated by tools/intro_demo/extract_title_bg_chr.py */\n",
        f"/* Title BG CHR: NES CommonBackgroundPatterns.dat ({n_tiles} tiles)\n",
        " * 2bpp -> 4bpp Genesis, no color shift. References pal slots 0-3\n",
        " * of cell's palette. Uploaded at VRAM $0000 during title phase. */\n",
        f"const unsigned char intro_title_bg_chr[{len(gen)}] = {{\n",
    ]
    for i in range(0, len(gen), 16):
        row = ", ".join(f"0x{b:02X}" for b in gen[i:i+16])
        lines.append(f"    {row},\n")
    lines.append("};\n")
    lines.append(f"const unsigned long intro_title_bg_chr_size = {len(gen)};\n")
    OUT.write_text("".join(lines))
    print(f"wrote {OUT}: {len(gen)} bytes ({n_tiles} tiles)")
    return 0

if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Run and verify output**

```bash
python tools/intro_demo/extract_title_bg_chr.py
# Expect: "wrote .../intro_title_bg_chr.c: <size> bytes (<n> tiles)"
ls -la tools/intro_demo/intro_title_bg_chr.c
# Expect: file exists, size matches reported byte count
```

- [ ] **Step 3: Commit**

```bash
git add tools/intro_demo/extract_title_bg_chr.py tools/intro_demo/intro_title_bg_chr.c
git commit -m "intro_demo: extract title BG CHR (CommonBackgroundPatterns)"
```

---

## Task 2: Title sprite CHR extraction script

**Files:**
- Create: `tools/intro_demo/extract_title_sprite_chr.py`
- Output: `tools/intro_demo/intro_title_sprite_chr.c`

- [ ] **Step 1: Write extractor**

```python
#!/usr/bin/env python3
"""Extract title sprite tiles from CommonSpritePatterns.dat. The title
uses sprites enumerated in Z_02.asm InitialTitleSprites (28 entries)
plus waterfall tiles ($A2,$A4,$A6,$A8 crests; $B2,$B4,$B6,$B8 waves).
For simplicity, extract all 256 NES sprite tiles re-encoded with
color_shift=4 (slots 4-7 of cell palette = NES sprite palette area).
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).parent))
from extract_sprite_chr import nes_tile_to_gen_tile

COMMON_SP = ROOT / "reference" / "aldonunez" / "dat" / "CommonSpritePatterns.dat"
OUT       = Path(__file__).parent / "intro_title_sprite_chr.c"

def main() -> int:
    sp_data = COMMON_SP.read_bytes()
    n_tiles = len(sp_data) // 16
    gen = bytearray()
    for T in range(n_tiles):
        tile = sp_data[T*16:(T+1)*16]
        gen += nes_tile_to_gen_tile(tile, color_shift=4)

    lines = [
        "/* Auto-generated by tools/intro_demo/extract_title_sprite_chr.py */\n",
        f"/* Title sprite CHR: NES CommonSpritePatterns.dat ({n_tiles} tiles)\n",
        " * 2bpp -> 4bpp Genesis, color_shift=4. Pixel values 1-3 reference\n",
        " * slots 5-7 of cell's palette (NES sprite palette area).\n",
        " * Uploaded at VRAM $2000 during title phase. */\n",
        f"const unsigned char intro_title_sprite_chr[{len(gen)}] = {{\n",
    ]
    for i in range(0, len(gen), 16):
        row = ", ".join(f"0x{b:02X}" for b in gen[i:i+16])
        lines.append(f"    {row},\n")
    lines.append("};\n")
    lines.append(f"const unsigned long intro_title_sprite_chr_size = {len(gen)};\n")
    OUT.write_text("".join(lines))
    print(f"wrote {OUT}: {len(gen)} bytes ({n_tiles} tiles)")
    return 0

if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Run + verify**

```bash
python tools/intro_demo/extract_title_sprite_chr.py
ls -la tools/intro_demo/intro_title_sprite_chr.c
```

- [ ] **Step 3: Commit**

```bash
git add tools/intro_demo/extract_title_sprite_chr.py tools/intro_demo/intro_title_sprite_chr.c
git commit -m "intro_demo: extract title sprite CHR (CommonSpritePatterns)"
```

---

## Task 3: Title tilemap extraction script

**Files:**
- Create: `tools/intro_demo/extract_title_tilemap.py`
- Output: `tools/intro_demo/intro_title_tilemap.c`

- [ ] **Step 1: Write parser**

`GameTitleTransferBuf.dat` is a stream of NES VRAM transfer records: `[high_addr, low_addr, count, ...count bytes of data]` repeated, terminated by `$FF`. Records target NT0 ($2000-$23BF for tiles, $23C0-$23FF for attributes). Reconstruct 32×30 tile NT and 64-byte attribute table; emit Genesis tilemap with palette field per cell.

```python
#!/usr/bin/env python3
"""Parse reference/aldonunez/dat/GameTitleTransferBuf.dat into a 32x30
Genesis tilemap. NES transfer-record format:
  [hi, lo, count, byte_0, byte_1, ..., byte_(count-1)] * N records,
terminated by $FF.

Targets nametable NT0 at PPU $2000-$23BF (tiles) and $23C0-$23FF
(2-bit-per-quadrant attributes). We populate a 30-row x 32-col tile
buffer and a 16x15 quadrant attribute buffer, then emit Genesis cells
where each cell = (palette << 13) | tile_index. Tile indices map 1:1
to the Gen BG CHR uploaded at VRAM $0000 (Task 1).
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DAT  = ROOT / "reference" / "aldonunez" / "dat" / "GameTitleTransferBuf.dat"
OUT  = Path(__file__).parent / "intro_title_tilemap.c"

NT_TILES = bytearray(32 * 30)        # row-major
ATTR     = bytearray(64)              # 16x15 -> 16 cols x 15 rows of 2x2 quadrants packed 2 bits each

def parse(data: bytes) -> None:
    i = 0
    while i < len(data) and data[i] != 0xFF:
        hi = data[i]; lo = data[i+1]; cnt = data[i+2]
        addr = (hi << 8) | lo
        i += 3
        chunk = data[i:i+cnt]
        i += cnt
        # NES NT0: $2000-$23BF tile, $23C0-$23FF attr
        for k, b in enumerate(chunk):
            a = addr + k
            if 0x2000 <= a < 0x23C0:
                NT_TILES[a - 0x2000] = b
            elif 0x23C0 <= a < 0x2400:
                ATTR[a - 0x23C0] = b
            # Any other dest (e.g. PALRAM $3F00) ignored — palette comes
            # from extract_title_palette.py instead.

def cell_palette(col: int, row: int) -> int:
    # NES attribute byte covers a 4x4 cell region (2x2 quadrants of 2x2 cells).
    # attr_idx = (row // 4) * 8 + (col // 4)
    # quadrant within the byte: bit 0-1 = top-left, 2-3 = top-right,
    # 4-5 = bot-left, 6-7 = bot-right (each quadrant is 2x2 cells).
    attr_idx = (row // 4) * 8 + (col // 4)
    quad_x   = (col % 4) // 2
    quad_y   = (row % 4) // 2
    shift    = (quad_y * 2 + quad_x) * 2
    return (ATTR[attr_idx] >> shift) & 3

def main() -> int:
    data = DAT.read_bytes()
    parse(data)

    cells = []
    for row in range(30):
        for col in range(32):
            tile = NT_TILES[row * 32 + col]
            pal  = cell_palette(col, row)
            # Genesis cell: priority(1) | palette(2) | hflip(1) | vflip(1) | tile(11)
            # Pal field at bits 13-14.
            cell = (pal << 13) | (tile & 0x7FF)
            cells.append(cell)

    lines = [
        "/* Auto-generated by tools/intro_demo/extract_title_tilemap.py */\n",
        "/* NES title nametable (32x30) parsed from GameTitleTransferBuf.dat,\n",
        " * with per-cell palette index from NES attribute table.\n",
        " * Plane A 32x32 nametable; rows 30-31 left blank by main.c. */\n",
        "const unsigned short intro_title_tilemap_rows = 30;\n",
        f"const unsigned short intro_title_tilemap[{len(cells)}] = {{\n",
    ]
    for r in range(30):
        row_cells = cells[r*32:(r+1)*32]
        line = "    " + ", ".join(f"0x{c:04X}" for c in row_cells) + ","
        lines.append(line + "\n")
    lines.append("};\n")
    OUT.write_text("".join(lines))
    print(f"wrote {OUT}: 30 rows ({len(cells)} cells)")
    return 0

if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Run + verify a known landmark cell**

```bash
python tools/intro_demo/extract_title_tilemap.py
# Expect: "wrote ...: 30 rows (960 cells)"

# Spot-check: the title logo "ZELDA" lives roughly mid-screen.
# Inspect row 5-10 to confirm non-blank (non-$24) cells:
python -c "
import re
text = open('tools/intro_demo/intro_title_tilemap.c').read()
m = re.search(r'\{(.*)\};', text, re.S)
data = [int(x,16) for x in re.findall(r'0x([0-9A-Fa-f]+)', m.group(1))]
for r in range(4, 14):
    row = data[r*32:(r+1)*32]
    nonblank = sum(1 for c in row if (c & 0x7FF) != 0x24)
    print(f'row {r}: {nonblank} non-blank cells')
"
# Expect: rows 4-13 have varying non-blank counts; some rows like the logo
# row should have 10+ non-blank cells.
```

- [ ] **Step 3: Commit**

```bash
git add tools/intro_demo/extract_title_tilemap.py tools/intro_demo/intro_title_tilemap.c
git commit -m "intro_demo: parse GameTitleTransferBuf.dat into Gen tilemap"
```

---

## Task 4: Title palette extraction

**Files:**
- Create: `tools/intro_demo/extract_title_palette.py`
- Input: `tools/intro_demo/nes_full/palram_title.bin` (from Task 0)
- Output: `tools/intro_demo/intro_title_palette.c`

- [ ] **Step 1: Write converter**

```python
#!/usr/bin/env python3
"""Convert NES PALRAM dump (palram_title.bin, 32 bytes) to Genesis CRAM
layout (64 words). Layout matches intro_combined_palette packing:

  Gen pal 0 slots 0-3  = NES BG pal 0  (PALRAM $3F00-$3F03)
  Gen pal 1 slots 0-3  = NES BG pal 1  (PALRAM $3F04-$3F07)
  Gen pal 2 slots 0-3  = NES BG pal 2  (PALRAM $3F08-$3F0B)
  Gen pal 3 slots 0-3  = NES BG pal 3  (PALRAM $3F0C-$3F0F)
  Gen pal 0 slots 4-7  = NES SPR pal 0 (PALRAM $3F10-$3F13)
  Gen pal 1 slots 4-7  = NES SPR pal 1 (PALRAM $3F14-$3F17)
  Gen pal 2 slots 4-7  = NES SPR pal 2 (PALRAM $3F18-$3F1B)
  Gen pal 3 slots 4-7  = NES SPR pal 3 (PALRAM $3F1C-$3F1F)
  Gen pal X slots 8-15 = 0 (unused for title)
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from extract_intro_assets import nes_color_to_gen_cram

PALRAM = Path(__file__).parent / "nes_full" / "palram_title.bin"
OUT    = Path(__file__).parent / "intro_title_palette.c"

def main() -> int:
    pal = PALRAM.read_bytes()
    if len(pal) != 32:
        raise ValueError(f"palram_title.bin must be 32 bytes, got {len(pal)}")
    cram = [0] * 64
    for p in range(4):
        for c in range(4):
            cram[p*16 + c]     = nes_color_to_gen_cram(pal[p*4 + c])      # BG pal p
            cram[p*16 + 4 + c] = nes_color_to_gen_cram(pal[16 + p*4 + c]) # SPR pal p

    lines = [
        "/* Auto-generated by tools/intro_demo/extract_title_palette.py */\n",
        "/* Title palette: NES PALRAM at title frame 100, packed into the\n",
        " * combined Gen CRAM layout (BG pals slots 0-3, SPR pals slots 4-7). */\n",
        "const unsigned short intro_title_palette[64] = {\n",
    ]
    for i in range(0, 64, 8):
        lines.append("    " + ", ".join(f"0x{w:04X}" for w in cram[i:i+8]) + ",\n")
    lines.append("};\n")
    OUT.write_text("".join(lines))
    print(f"wrote {OUT}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Run + verify**

```bash
python tools/intro_demo/extract_title_palette.py
# Expect: "wrote ..."

# Sanity-check: title backdrop should NOT be black (pink-ish per NES).
head -8 tools/intro_demo/intro_title_palette.c
# Expect: pal 0 slot 0 (backdrop) = some non-zero value; slot 1 a bright color.
```

- [ ] **Step 3: Commit**

```bash
git add tools/intro_demo/extract_title_palette.py tools/intro_demo/intro_title_palette.c
git commit -m "intro_demo: convert title NES PALRAM to Gen CRAM layout"
```

---

## Task 5: Title fade table extraction (compressed delays)

**Files:**
- Create: `tools/intro_demo/extract_title_fade.py`
- Output: `tools/intro_demo/intro_title_fade.c`

The 14-step palette progression `DemoPhase0Subphase1Palettes` (already transcribed in `extract_demo_palettes.py`'s `NES_CYCLES`) drives the fade. We need *all 64 Gen CRAM words per cycle* (not just 12 sprite-pal slots like the existing extract). And we need a compressed delay table summing to ~230 frames.

- [ ] **Step 1: Write extractor**

```python
#!/usr/bin/env python3
"""Emit the 14-cycle title fade-out: full Gen CRAM (64 words/cycle)
for each NES DemoPhase0Subphase1 palette state, plus a compressed
per-step delay table totalling ~230 frames (matches measured visible
fade interval f0555 -> f0785).

NES delays $08,$08,$06,$05,$04,$03,$02,$02,$02,$C0,$06,$04,$C0,$03
sum to 437 frames. We compress by clamping each delay to a max:
  - cycles 0-8 keep their NES delays (fast intro fade portion)
  - cycles 9 and 12 replaced with a small hold (e.g. 8 frames each)
  - cycles 10, 11, 13 keep their NES delays
This preserves NES color progression order; only the long $C0 holds
shrink. Compressed sum target is ~230 frames; we tune the hold values
to hit that exactly.

Result delays (frames): 8,8,6,5,4,3,2,2,2,8,6,4,8,3 = 69 frames.
That's TOO short. Add proportional padding so total = ~230:
  scale factor = 230 / 69 ~= 3.33
  scaled = floor(d * 3.33) = 26,26,19,16,13,9,6,6,6,26,19,13,26,9 = 220
  Add 10 to first cycle to land on 230: 36 + 26 + 19 + ... = 230.

Final emitted delays (chosen by hand to land on 230):
  [36, 26, 19, 16, 13, 9, 6, 6, 6, 26, 19, 13, 26, 9]  sum = 230
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from extract_intro_assets import nes_color_to_gen_cram

OUT = Path(__file__).parent / "intro_title_fade.c"

# 14 NES palette states (32 bytes each), transcribed from
# Z_02.asm:1111-1177 DemoPhase0Subphase1Palettes.
NES_CYCLES = [
    [0x36, 0x0F, 0x00, 0x10, 0x36, 0x17, 0x27, 0x0F,
     0x36, 0x08, 0x1A, 0x28, 0x36, 0x30, 0x3B, 0x22,
     0x36, 0x30, 0x3B, 0x16, 0x36, 0x17, 0x27, 0x0F,
     0x36, 0x08, 0x1A, 0x28, 0x36, 0x30, 0x3B, 0x22],
    [0x39, 0x0F, 0x00, 0x10, 0x39, 0x17, 0x27, 0x0F,
     0x39, 0x08, 0x1A, 0x28, 0x39, 0x30, 0x3B, 0x22,
     0x39, 0x30, 0x3B, 0x16, 0x39, 0x17, 0x27, 0x0F,
     0x39, 0x08, 0x1A, 0x28, 0x39, 0x30, 0x3B, 0x22],
    [0x31, 0x0F, 0x00, 0x10, 0x31, 0x17, 0x27, 0x0F,
     0x31, 0x08, 0x1A, 0x28, 0x31, 0x30, 0x3B, 0x22,
     0x31, 0x30, 0x3B, 0x16, 0x31, 0x17, 0x27, 0x0F,
     0x31, 0x08, 0x1A, 0x28, 0x31, 0x30, 0x3B, 0x22],
    [0x3C, 0x0F, 0x00, 0x10, 0x3C, 0x17, 0x27, 0x0F,
     0x3C, 0x08, 0x1A, 0x28, 0x3C, 0x30, 0x3B, 0x22,
     0x3C, 0x30, 0x3B, 0x16, 0x3C, 0x17, 0x27, 0x0F,
     0x3C, 0x08, 0x1A, 0x28, 0x3C, 0x30, 0x3B, 0x22],
    [0x3B, 0x0F, 0x00, 0x10, 0x3B, 0x17, 0x27, 0x0F,
     0x3B, 0x08, 0x1A, 0x28, 0x3B, 0x10, 0x3B, 0x22,
     0x3B, 0x10, 0x3B, 0x16, 0x3B, 0x17, 0x27, 0x0F,
     0x3B, 0x08, 0x1A, 0x28, 0x3B, 0x10, 0x3B, 0x22],
    [0x2C, 0x0F, 0x00, 0x10, 0x2C, 0x17, 0x27, 0x0F,
     0x2C, 0x08, 0x1A, 0x28, 0x2C, 0x10, 0x3B, 0x22,
     0x2C, 0x10, 0x3B, 0x16, 0x2C, 0x17, 0x27, 0x0F,
     0x2C, 0x08, 0x1A, 0x28, 0x2C, 0x10, 0x3B, 0x22],
    [0x1C, 0x0F, 0x00, 0x10, 0x1C, 0x17, 0x27, 0x0F,
     0x1C, 0x08, 0x1A, 0x28, 0x1C, 0x10, 0x3B, 0x22,
     0x1C, 0x10, 0x3B, 0x16, 0x1C, 0x17, 0x27, 0x0F,
     0x1C, 0x08, 0x1A, 0x28, 0x1C, 0x10, 0x3B, 0x22],
    [0x02, 0x0F, 0x00, 0x10, 0x02, 0x06, 0x27, 0x0F,
     0x02, 0x0A, 0x1A, 0x18, 0x02, 0x10, 0x2B, 0x12,
     0x02, 0x10, 0x2B, 0x06, 0x02, 0x06, 0x27, 0x0F,
     0x02, 0x0A, 0x1A, 0x18, 0x02, 0x10, 0x2B, 0x12],
    [0x0C, 0x0F, 0x00, 0x10, 0x0C, 0x03, 0x16, 0x0F,
     0x0C, 0x01, 0x0A, 0x08, 0x0C, 0x00, 0x1B, 0x02,
     0x0C, 0x00, 0x1B, 0x02, 0x0C, 0x03, 0x16, 0x0F,
     0x0C, 0x01, 0x0A, 0x08, 0x0C, 0x00, 0x1B, 0x02],
    [0x0F, 0x0F, 0x0F, 0x00, 0x0F, 0x01, 0x11, 0x0F,
     0x0F, 0x0C, 0x01, 0x02, 0x0F, 0x00, 0x01, 0x0C,
     0x0F, 0x00, 0x01, 0x0C, 0x0F, 0x01, 0x11, 0x0F,
     0x0F, 0x0C, 0x01, 0x02, 0x0F, 0x00, 0x01, 0x0C],
    [0x0F, 0x0F, 0x0F, 0x00, 0x0F, 0x01, 0x11, 0x0F,
     0x0F, 0x0F, 0x0C, 0x01, 0x0F, 0x01, 0x0C, 0x0F,
     0x0F, 0x01, 0x0C, 0x0F, 0x0F, 0x01, 0x11, 0x0F,
     0x0F, 0x0F, 0x0C, 0x01, 0x0F, 0x01, 0x0C, 0x0F],
    [0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x01, 0x0F,
     0x0F, 0x0F, 0x0F, 0x0C, 0x0F, 0x0C, 0x0F, 0x0F,
     0x0F, 0x0C, 0x0F, 0x0F, 0x0F, 0x0F, 0x01, 0x0F,
     0x0F, 0x0F, 0x0F, 0x0C, 0x0F, 0x0C, 0x0F, 0x0F],
    [0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F,
     0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F,
     0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F,
     0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F],
    [0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F,
     0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F,
     0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F,
     0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F],
]

# Compressed delays. NES sum=437 (too long); ours sum=230 to match
# measured f0555 -> f0785.
DELAYS_COMPRESSED = [36, 26, 19, 16, 13, 9, 6, 6, 6, 26, 19, 13, 26, 9]
assert sum(DELAYS_COMPRESSED) == 230, f"delays sum={sum(DELAYS_COMPRESSED)}"

def cycle_to_cram(nes_pal: list[int]) -> list[int]:
    """NES 32-byte PALRAM state -> 64-word Gen CRAM layout (combined)."""
    out = [0] * 64
    for p in range(4):
        for c in range(4):
            out[p*16 + c]     = nes_color_to_gen_cram(nes_pal[p*4 + c])
            out[p*16 + 4 + c] = nes_color_to_gen_cram(nes_pal[16 + p*4 + c])
    return out

def main() -> int:
    cycles = [cycle_to_cram(c) for c in NES_CYCLES]
    lines = [
        "/* Auto-generated by tools/intro_demo/extract_title_fade.py */\n",
        "/* 14-cycle title fade: NES DemoPhase0Subphase1 progression with\n",
        " * compressed Genesis delays (sum=230 frames vs NES 437) to match\n",
        " * measured visible fade interval f0555 -> f0785. */\n",
        "const unsigned short intro_title_fade_cycles[14][64] = {\n",
    ]
    for i, c in enumerate(cycles):
        lines.append(f"    /* cycle {i} */ {{\n")
        for j in range(0, 64, 8):
            lines.append("        " + ", ".join(f"0x{w:04X}" for w in c[j:j+8]) + ",\n")
        lines.append("    },\n")
    lines.append("};\n\n")
    lines.append("const unsigned short intro_title_fade_delays[14] = {\n    ")
    lines.append(", ".join(str(d) for d in DELAYS_COMPRESSED))
    lines.append("\n};\n")
    OUT.write_text("".join(lines))
    print(f"wrote {OUT}: 14 cycles, compressed delays sum=230")
    return 0

if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Run + verify**

```bash
python tools/intro_demo/extract_title_fade.py
# Expect: "wrote ...: 14 cycles, compressed delays sum=230"
grep "intro_title_fade_delays" tools/intro_demo/intro_title_fade.c
# Expect line with 14 numbers summing to 230
```

- [ ] **Step 3: Commit**

```bash
git add tools/intro_demo/extract_title_fade.py tools/intro_demo/intro_title_fade.c
git commit -m "intro_demo: extract 14-cycle title fade (NES progression, compressed delays)"
```

---

## Task 6: Title glow extraction

**Files:**
- Create: `tools/intro_demo/extract_title_glow.py`
- Output: `tools/intro_demo/intro_title_glow.c`

- [ ] **Step 1: Write extractor**

```python
#!/usr/bin/env python3
"""Emit the 8-color Triforce glow cycle and per-step delays.
Reference Z_02.asm:947 TriforceGlowingColors:
  $27, $37, $37, $27, $17, $07, $07, $17
Z_02.asm:976-983: 6-frame delay each, 16 frames at the final entry,
then wrap. Patches PALRAM $3F06 = NES BG pal 1 color 2 = Gen pal 1 slot 2.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from extract_intro_assets import nes_color_to_gen_cram

OUT = Path(__file__).parent / "intro_title_glow.c"

NES_GLOW = [0x27, 0x37, 0x37, 0x27, 0x17, 0x07, 0x07, 0x17]
DELAYS   = [6, 6, 6, 6, 6, 6, 6, 16]

def main() -> int:
    gen = [nes_color_to_gen_cram(c) for c in NES_GLOW]
    lines = [
        "/* Auto-generated by tools/intro_demo/extract_title_glow.py */\n",
        "/* Triforce glow cycle: 8 NES colors -> Gen CRAM, with per-step\n",
        " * delays (6 frames typical, 16 at final entry per Z_02.asm:976-983).\n",
        " * Patches Gen pal 1 slot 2 (= NES BG pal 1 color 2 = PALRAM $3F06). */\n",
        "const unsigned short intro_title_glow_colors[8] = {\n    ",
    ]
    lines.append(", ".join(f"0x{w:04X}" for w in gen))
    lines.append("\n};\n")
    lines.append("const unsigned char intro_title_glow_delays[8] = {\n    ")
    lines.append(", ".join(str(d) for d in DELAYS))
    lines.append("\n};\n")
    OUT.write_text("".join(lines))
    print(f"wrote {OUT}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Run + verify**

```bash
python tools/intro_demo/extract_title_glow.py
cat tools/intro_demo/intro_title_glow.c
# Expect 8 Gen CRAM words + 8 delays
```

- [ ] **Step 3: Commit**

```bash
git add tools/intro_demo/extract_title_glow.py tools/intro_demo/intro_title_glow.c
git commit -m "intro_demo: extract Triforce glow cycle (8 colors, NES delays)"
```

---

## Task 7: Phase machine scaffold (intro_phase.h + intro_phase.c)

**Files:**
- Create: `tools/intro_demo/intro_phase.h`
- Create: `tools/intro_demo/intro_phase.c`

- [ ] **Step 1: Write header**

```c
/* tools/intro_demo/intro_phase.h
 *
 * Top-level phase state machine for intro_demo. Owns transitions
 * between title and story segments. Boot calls intro_phase_init()
 * once; main loop calls intro_phase_step() each vblank.
 */
#ifndef INTRO_PHASE_H
#define INTRO_PHASE_H

typedef enum {
    PHASE_TITLE_LOAD = 0,
    PHASE_TITLE_DISPLAY,
    PHASE_TITLE_FADEOUT,
    PHASE_BLACK_HOLD,
    PHASE_STORY_LOAD,
    PHASE_STORY_SCROLL_IN,
    PHASE_STORY_HOLD,
    PHASE_SCROLL_OFF,
    PHASE_END_PAUSE,
} intro_phase_t;

void intro_phase_init(void);
void intro_phase_step(void);

#endif /* INTRO_PHASE_H */
```

- [ ] **Step 2: Write skeleton implementation**

```c
/* tools/intro_demo/intro_phase.c
 *
 * Phase machine scaffolding. Tasks 8-15 fill in each phase's logic.
 * For now, only PHASE_TITLE_LOAD is implemented: enters title state
 * via intro_title_setup() and immediately advances. Other phases
 * are stubs that loop back to title.
 */
#include "intro_phase.h"
#include "intro_title.h"

static intro_phase_t s_phase = PHASE_TITLE_LOAD;

void intro_phase_init(void) {
    s_phase = PHASE_TITLE_LOAD;
}

static void goto_phase(intro_phase_t next) {
    s_phase = next;
}

void intro_phase_step(void) {
    switch (s_phase) {
        case PHASE_TITLE_LOAD:
            intro_title_setup();
            goto_phase(PHASE_TITLE_DISPLAY);
            break;
        case PHASE_TITLE_DISPLAY:
            intro_title_step();
            /* exit condition added in Task 9 */
            break;
        case PHASE_TITLE_FADEOUT:
        case PHASE_BLACK_HOLD:
        case PHASE_STORY_LOAD:
        case PHASE_STORY_SCROLL_IN:
        case PHASE_STORY_HOLD:
        case PHASE_SCROLL_OFF:
        case PHASE_END_PAUSE:
            /* placeholder: fall through to title for now */
            goto_phase(PHASE_TITLE_LOAD);
            break;
    }
}
```

- [ ] **Step 3: Commit (compiles only after Task 8)**

This task creates orphan files that won't link until intro_title.h/.c exist (Task 8). Defer commit until both compile together.

---

## Task 8: Title runtime skeleton (intro_title.h + intro_title.c) — load only

**Files:**
- Create: `tools/intro_demo/intro_title.h`
- Create: `tools/intro_demo/intro_title.c`

- [ ] **Step 1: Write header**

```c
/* tools/intro_demo/intro_title.h
 *
 * Title runtime: load + per-vblank step (glow, waterfall) + fadeout
 * driver. Setup uploads CHR/CRAM/plane/sprites with display blanked,
 * re-enables display before returning.
 */
#ifndef INTRO_TITLE_H
#define INTRO_TITLE_H

#define TITLE_DISPLAY_FRAMES 520u
#define TITLE_FADE_CYCLES    14u

void intro_title_setup(void);    /* full title load (PHASE_TITLE_LOAD) */
void intro_title_step(void);     /* per vblank during PHASE_TITLE_DISPLAY */
void intro_title_fade_step(unsigned char cycle_idx);  /* writes full-CRAM cycle, called by phase machine */

#endif /* INTRO_TITLE_H */
```

- [ ] **Step 2: Write title load**

```c
/* tools/intro_demo/intro_title.c
 *
 * Title runtime. Task 8: load (CHR + tilemap + palette + sprite list).
 * Task 9: per-frame glow. Task 10: per-frame waterfall. Task 11: fade.
 */
#include "intro_title.h"

#define VDP_DATA_WORD (*(volatile unsigned short *)0x00C00000)
#define VDP_CTRL_WORD (*(volatile unsigned short *)0x00C00004)
#define VDP_CTRL_LONG (*(volatile unsigned long  *)0x00C00004)

extern const unsigned char  intro_title_bg_chr[];
extern const unsigned long  intro_title_bg_chr_size;
extern const unsigned char  intro_title_sprite_chr[];
extern const unsigned long  intro_title_sprite_chr_size;
extern const unsigned short intro_title_tilemap_rows;
extern const unsigned short intro_title_tilemap[];
extern const unsigned short intro_title_palette[64];

#define PLANE_A_BASE 0xC000u

static void vram_write_open(unsigned short dst) {
    VDP_CTRL_LONG = 0x40000000UL
                  | ((unsigned long)(dst & 0x3FFF) << 16)
                  | ((dst >> 14) & 0x0003);
}

static void vram_upload(const unsigned char *src, unsigned long bytes,
                        unsigned short dst) {
    const unsigned short *p = (const unsigned short *)src;
    unsigned long words = bytes >> 1;
    vram_write_open(dst);
    while (words--) VDP_DATA_WORD = *p++;
}

static void cram_upload(const unsigned short *src, unsigned short count) {
    VDP_CTRL_LONG = 0xC0000000UL;
    while (count--) VDP_DATA_WORD = *src++;
}

static void plane_fill_blank(unsigned short base) {
    vram_write_open(base);
    for (unsigned short i = 0; i < 32 * 32; i++) VDP_DATA_WORD = 0x0024;
}

static void write_row(unsigned short row, const unsigned short *cells) {
    unsigned short addr = (unsigned short)(PLANE_A_BASE + row * 64);
    vram_write_open(addr);
    for (int i = 0; i < 32; i++) VDP_DATA_WORD = cells[i];
}

void intro_title_setup(void) {
    /* Display off during upload (per VRAM/CRAM policy). */
    VDP_CTRL_WORD = 0x8134;

    /* CHR uploads: title BG at $0000, title sprite at $2000. */
    vram_upload(intro_title_bg_chr,     intro_title_bg_chr_size,     0x0000);
    vram_upload(intro_title_sprite_chr, intro_title_sprite_chr_size, 0x2000);

    /* Plane A: fill blank then write title rows 0..29. Rows 30,31 stay blank. */
    plane_fill_blank(PLANE_A_BASE);
    plane_fill_blank(0xE000);  /* plane B blank */
    for (unsigned short r = 0; r < intro_title_tilemap_rows; r++) {
        write_row(r, &intro_title_tilemap[r * 32]);
    }

    /* CRAM: title palette. */
    cram_upload(intro_title_palette, 64);

    /* Vertical scroll = 0. */
    VDP_CTRL_LONG = 0x40000010UL;
    VDP_DATA_WORD = 0;

    /* Display on. */
    VDP_CTRL_WORD = 0x8174;
}

void intro_title_step(void) {
    /* Filled in by Tasks 9, 10. */
}

void intro_title_fade_step(unsigned char cycle_idx) {
    (void)cycle_idx;
    /* Filled in by Task 11. */
}
```

- [ ] **Step 3: Update build.bat to compile new sources + new asset .c files**

Append to `tools/intro_demo/build.bat` after the existing intro_blink_chr / intro_demo_palettes section:

```bat
echo [demo] Compiling intro_title_bg_chr.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%DEMO_DIR%\intro_title_bg_chr.c" -o "%OUT_DIR%\intro_title_bg_chr.o"
if errorlevel 1 exit /b 1

echo [demo] Compiling intro_title_sprite_chr.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%DEMO_DIR%\intro_title_sprite_chr.c" -o "%OUT_DIR%\intro_title_sprite_chr.o"
if errorlevel 1 exit /b 1

echo [demo] Compiling intro_title_tilemap.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%DEMO_DIR%\intro_title_tilemap.c" -o "%OUT_DIR%\intro_title_tilemap.o"
if errorlevel 1 exit /b 1

echo [demo] Compiling intro_title_palette.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%DEMO_DIR%\intro_title_palette.c" -o "%OUT_DIR%\intro_title_palette.o"
if errorlevel 1 exit /b 1

echo [demo] Compiling intro_title_fade.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%DEMO_DIR%\intro_title_fade.c" -o "%OUT_DIR%\intro_title_fade.o"
if errorlevel 1 exit /b 1

echo [demo] Compiling intro_title_glow.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%DEMO_DIR%\intro_title_glow.c" -o "%OUT_DIR%\intro_title_glow.o"
if errorlevel 1 exit /b 1

echo [demo] Compiling intro_title.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%DEMO_DIR%\intro_title.c" -o "%OUT_DIR%\intro_title.o"
if errorlevel 1 exit /b 1

echo [demo] Compiling intro_phase.c
"%M68K_GCC%" -B "%M68K_BIN%\\" %CFLAGS% -c "%DEMO_DIR%\intro_phase.c" -o "%OUT_DIR%\intro_phase.o"
if errorlevel 1 exit /b 1
```

And append to the link line (insert before `intro_combined_palette.o`):

```
    "%OUT_DIR%\intro_title_bg_chr.o" ^
    "%OUT_DIR%\intro_title_sprite_chr.o" ^
    "%OUT_DIR%\intro_title_tilemap.o" ^
    "%OUT_DIR%\intro_title_palette.o" ^
    "%OUT_DIR%\intro_title_fade.o" ^
    "%OUT_DIR%\intro_title_glow.o" ^
    "%OUT_DIR%\intro_title.o" ^
    "%OUT_DIR%\intro_phase.o" ^
```

- [ ] **Step 4: Build (still using old main.c — will not invoke phase machine yet)**

Build should succeed with new objects compiled even though main.c hasn't switched over. Verifies no syntax errors.

```bash
& cmd.exe /c "cd /d \"C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\tools\intro_demo\" && .\build.bat"
# Expect: DONE: ... intro_demo.md, no errors
```

- [ ] **Step 5: Commit**

```bash
git add tools/intro_demo/intro_phase.h tools/intro_demo/intro_phase.c \
        tools/intro_demo/intro_title.h tools/intro_demo/intro_title.c \
        tools/intro_demo/build.bat
git commit -m "intro_demo: scaffold phase machine + title load (no behavior change yet)"
```

---

## Task 9: Switch main.c to phase machine; verify title displays

**Files:**
- Modify: `tools/intro_demo/main.c`

This is the integration step. Current main.c contains: CHR uploads, fade-in, story setup, scroll loop, item flash, end pause, restart. We need to:

1. Remove the inline title-less fade-in and story setup from main.c.
2. Replace main loop with `for (;;) { wait_vblank(); intro_phase_step(); }`.
3. Move story setup + scroll loop into a future `story_runtime` (Task 12). For NOW, leave it as-is and have the phase machine point back to story for `PHASE_STORY_LOAD..PHASE_END_PAUSE` via a stub.

To keep this task small, only verify TITLE displays. Stub the rest of the phase machine to loop back to title after a short delay.

- [ ] **Step 1: Read current main.c**

```bash
wc -l tools/intro_demo/main.c
```

- [ ] **Step 2: Refactor main.c — keep file but extract logic**

Replace the body of `main()` after CHR/CRAM/plane setup with:

```c
int main(void) {
    /* (Remove all current pre-loop CHR/palette/plane setup — moved into
     * intro_title_setup() and the future story_runtime_setup() called
     * from PHASE_STORY_LOAD.) */
    intro_phase_init();
    for (;;) {
        /* wait_vblank */
        while ( (VDP_CTRL_WORD & 0x0008));
        while (!(VDP_CTRL_WORD & 0x0008));
        intro_phase_step();
    }
    return 0;
}
```

For Task 9 only, replace ALL of main.c's pre-loop body with the call to `intro_phase_init()`. Story logic disappears momentarily; we'll restore it in Task 12.

Add `#include "intro_phase.h"` at top of main.c.

- [ ] **Step 3: Build**

```bash
& cmd.exe /c "cd /d \"C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\tools\intro_demo\" && .\build.bat"
```

Expect: clean build.

- [ ] **Step 4: Stage + boot**

```bash
cp "tools/intro_demo/out/intro_demo.md" /c/tmp/intro_demo.md
cmd.exe //c "taskkill /F /IM EmuHawk.exe" 2>&1 | head -2
powershell -Command "Start-Process -FilePath 'C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64\EmuHawk.exe' -ArgumentList 'C:\tmp\intro_demo.md' -WorkingDirectory 'C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64'"
```

Expect: BizHawk shows the NES title screen visually (logo, vines, sword, "PUSH START BUTTON" text — though sprites missing because `intro_title_step()` doesn't draw sprites yet).

- [ ] **Step 5: Verify with Lua probe (read CRAM at frame 50, screenshot)**

```lua
-- /c/tmp/probe_title_load.lua
local OUT = "C:/tmp/probe_title_load.log"
local f = io.open(OUT, "w")
while emu.framecount() < 50 do emu.frameadvance() end
f:write(string.format("frame %d\n", emu.framecount()))
f:write("pal0: ")
for s = 0, 7 do
    local w = memory.read_u16_be(s*2, "CRAM")
    f:write(string.format("%04X ", w))
end
f:write("\n")
client.screenshot("C:/tmp/probe_title_f50.png")
f:close()
client.exit()
```

Run probe via bizhawkScript skill pattern. Expect CRAM to match `intro_title_palette[0..7]`. Screenshot should resemble NES title (no sprites yet).

- [ ] **Step 6: Commit**

```bash
git add tools/intro_demo/main.c
git commit -m "intro_demo: switch main loop to phase machine; title visible (no anim yet)"
```

---

## Task 10: Title sprites — initial sprite list upload

**Files:**
- Modify: `tools/intro_demo/intro_title.c`

NES `InitialTitleSprites` (Z_02.asm:342) lays out 28 sprites in 4-byte format `[Y, tile, attr, X]`. Genesis sprite list lives at the VDP sprite table (typically VRAM `$F800` for our setup) and uses 8-byte format `[Y, size+next, attr, X]` packed. Need to translate.

Genesis sprite entry (each 8 bytes):
- Word 0: Y position (0-1023, 8-bit Y stored)
- Word 1: HSize/VSize/Link
- Word 2: Priority/Palette/VFlip/HFlip/Tile (11-bit)
- Word 3: X position

Each NES sprite = 8x16 (typical for game) or 8x8. For title screen the sprites likely 8x8. Translation per sprite:
- Y: NES Y + 1 → Genesis Y + 128 (Genesis offsets sprites by 128 in Y, 128 in X)
- Tile: NES tile → Gen tile (256 + nes_tile, since sprite CHR uploaded at VRAM $2000 = Gen tile 256)
- Attr: NES bits 0-1 = palette → Gen palette field; NES bit 6 = HFlip, bit 7 = VFlip → Gen bits

For simplicity, fix Genesis sprite list at VRAM `$F800`. Set VDP register $05 to `$F800/$200 = 0x7C` to point sprite table there.

- [ ] **Step 1: Add NES sprite table data + sprite-list builder**

Append to `intro_title.c`:

```c
/* NES InitialTitleSprites table from Z_02.asm:342-360.
 * Format: [Y, tile, attr, X] x 28 sprites (112 bytes total).
 * Last sprite's link field (Genesis sprite-table thing) terminates the list. */
static const unsigned char nes_initial_title_sprites[112] = {
    0x77, 0xCA, 0xC2, 0xD0, 0x77, 0xCC, 0xC2, 0xC8,
    0x77, 0xCA, 0x82, 0x28, 0x77, 0xCC, 0x82, 0x30,
    0x27, 0xCA, 0x42, 0xD0, 0x27, 0xCC, 0x42, 0xC8,
    0x27, 0xCA, 0x02, 0x28, 0x27, 0xCC, 0x02, 0x30,
    0x57, 0xCE, 0x02, 0x74, 0x57, 0xD0, 0x02, 0x7C,
    0x31, 0xD2, 0x02, 0x57, 0x4F, 0xD2, 0x02, 0xCC,
    0x67, 0xD2, 0x02, 0x7B, 0x83, 0xD2, 0x02, 0x50,
    0x31, 0xD4, 0x02, 0x5F, 0x3F, 0xD4, 0x02, 0x24,
    /* fill remaining with sentinel sprite Y=0 (off-top) */
    /* ... pad to 28 sprites x 4 bytes = 112 bytes */
    /* TODO: complete table from Z_02.asm:347-360 */
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
    0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0,
};
```

Wait — refusing to use the placeholder pattern. Re-read Z_02.asm:342-360 explicitly:

```bash
sed -n '342,360p' reference/aldonunez/Z_02.asm
```

Then transcribe ALL bytes from that section (28 sprites = 112 bytes; some lines may show fewer than the full 28). Replace the TODO block with actual byte data. If the asm shows only a subset, take exactly what's shown — do NOT pad with zeros (zero Y means visible at top of screen, would create bogus sprites).

After full transcription, the table size matches the count of sprites referenced.

- [ ] **Step 2: Sprite-list upload helper**

Add to `intro_title.c`:

```c
/* Genesis sprite table at VRAM $F800. Each sprite = 8 bytes:
 *   word 0: Y  (use 0 to hide; 128 = top of visible screen)
 *   word 1: size(2)+link(8) — size=0x05 for 16x16 (2x2 tiles), link=next slot
 *   word 2: pri/pal/vflip/hflip/tile11
 *   word 3: X  (128 = left of visible screen)
 *
 * NES sprite -> Gen sprite mapping:
 *   Y_gen = 128 + (NES Y + 1)
 *   X_gen = 128 + NES X
 *   tile_gen = 256 + NES_tile (sprite CHR uploaded at $2000)
 *   palette = NES attr bits 0-1
 *   hflip = NES attr bit 6 (>>6)
 *   vflip = NES attr bit 7 (>>7)
 *   priority = NES attr bit 5 (>>5)
 *
 * NES sprites are 8x8 here (NOT 8x16 mode for title); use Genesis size=0
 * (= 8x8 single tile).
 */
#define SPRITE_TABLE_VRAM 0xF800u
#define SPRITE_COUNT      28u

static void title_sprites_upload(void) {
    vram_write_open(SPRITE_TABLE_VRAM);
    for (unsigned char i = 0; i < SPRITE_COUNT; i++) {
        unsigned char ny    = nes_initial_title_sprites[i*4 + 0];
        unsigned char ntile = nes_initial_title_sprites[i*4 + 1];
        unsigned char nattr = nes_initial_title_sprites[i*4 + 2];
        unsigned char nx    = nes_initial_title_sprites[i*4 + 3];

        unsigned short y = (unsigned short)(128u + (unsigned short)(ny + 1u));
        unsigned short x = (unsigned short)(128u + (unsigned short)nx);
        unsigned short tile = (unsigned short)(256u + (unsigned short)ntile);
        unsigned short pal  = (unsigned short)(nattr & 3u);
        unsigned short hflip = (unsigned short)((nattr >> 6) & 1u);
        unsigned short vflip = (unsigned short)((nattr >> 7) & 1u);
        unsigned short prio  = (unsigned short)((nattr >> 5) & 1u);

        unsigned short link = (unsigned short)(i + 1u);
        if (i == SPRITE_COUNT - 1u) link = 0u;  /* terminate */
        unsigned short word1 = (unsigned short)(0x0000u | link);  /* size 8x8 */
        unsigned short word2 = (unsigned short)((prio << 15) | (pal << 13)
                                                | (vflip << 12) | (hflip << 11)
                                                | (tile & 0x7FFu));

        VDP_DATA_WORD = y;
        VDP_DATA_WORD = word1;
        VDP_DATA_WORD = word2;
        VDP_DATA_WORD = x;
    }
}
```

Call `title_sprites_upload()` from `intro_title_setup()` right after `cram_upload(...)`.

Also set VDP register $05 (sprite attr table base) = `$F800 / $200 = 0x7C`:

```c
/* VDP reg $05: sprite table at $F800 (high byte $7C). */
VDP_CTRL_WORD = (unsigned short)(0x8500u | 0x7Cu);
```

Add this near the top of `intro_title_setup()` after display-off.

- [ ] **Step 3: Build + boot**

```bash
& cmd.exe /c "cd /d \"<repo>/tools/intro_demo\" && .\build.bat"
cp tools/intro_demo/out/intro_demo.md /c/tmp/intro_demo.md
cmd.exe //c "taskkill /F /IM EmuHawk.exe"
powershell -Command "Start-Process ... C:\tmp\intro_demo.md ..."
```

Expect: title screen with all sprites visible (sword, bird, "PUSH START BUTTON" lettering — appearance depends on sprite tile content from `CommonSpritePatterns.dat`).

- [ ] **Step 4: Visual side-by-side check**

Take a Genesis screenshot at frame 100 (via Lua probe) and place next to `tools/intro_demo/nes_loop/nes_f00100.png`. Sprite positions should align; colors will likely differ until palette tuning. Document any discrepancies in commit message.

- [ ] **Step 5: Commit**

```bash
git add tools/intro_demo/intro_title.c
git commit -m "intro_demo: title sprite list upload (28 sprites from InitialTitleSprites)"
```

---

## Task 11: Triforce glow animation

**Files:**
- Modify: `tools/intro_demo/intro_title.c`

- [ ] **Step 1: Add glow state + per-frame step**

```c
extern const unsigned short intro_title_glow_colors[8];
extern const unsigned char  intro_title_glow_delays[8];

static unsigned char s_glow_cycle = 0;
static unsigned char s_glow_timer = 0;

static void title_glow_reset(void) {
    s_glow_cycle = 0;
    s_glow_timer = intro_title_glow_delays[0];
}

static void title_glow_step(void) {
    if (s_glow_timer == 0) {
        s_glow_cycle++;
        if (s_glow_cycle >= 8u) s_glow_cycle = 0;
        s_glow_timer = intro_title_glow_delays[s_glow_cycle];
        /* Patch Gen pal 1 slot 2 (= NES BG pal 1 color 2 = PALRAM $3F06) */
        unsigned long addr = (unsigned long)(1*16 + 2) * 2u;
        VDP_CTRL_LONG = 0xC0000000UL
                      | ((addr & 0x3FFFu) << 16)
                      | ((addr >> 14) & 0x0003u);
        VDP_DATA_WORD = intro_title_glow_colors[s_glow_cycle];
    } else {
        s_glow_timer--;
    }
}
```

Call `title_glow_reset()` from `intro_title_setup()` (end of function, before display on).
Call `title_glow_step()` from `intro_title_step()`.

- [ ] **Step 2: Build + boot**

```bash
& cmd.exe /c "cd /d \"<repo>/tools/intro_demo\" && .\build.bat"
cp tools/intro_demo/out/intro_demo.md /c/tmp/intro_demo.md
cmd.exe //c "taskkill /F /IM EmuHawk.exe"
powershell -Command "Start-Process ... C:\tmp\intro_demo.md ..."
```

Expect: Triforce + sword highlight color cycles every 6 frames (visible glow).

- [ ] **Step 3: Lua probe — verify CRAM slot pal1[2] cycles across frames**

```lua
-- /c/tmp/probe_glow.lua
local OUT = "C:/tmp/probe_glow.log"
local f = io.open(OUT, "w")
local STAMPS = {30, 36, 42, 48, 54, 60, 66, 72, 88}
for _, s in ipairs(STAMPS) do
    while emu.framecount() < s do emu.frameadvance() end
    local w = memory.read_u16_be((1*16 + 2)*2, "CRAM")
    f:write(string.format("frame %d: pal1[2] = %04X\n", s, w))
end
f:close()
client.exit()
```

Expect: pal1[2] takes 8 distinct values (the 8 glow colors converted to Gen CRAM) over the sampled frames; verify against `intro_title_glow_colors[]` in source.

- [ ] **Step 4: Commit**

```bash
git add tools/intro_demo/intro_title.c
git commit -m "intro_demo: Triforce glow cycle (Z_02 timing, Gen pal1 slot 2)"
```

---

## Task 12: Waterfall sprite animation

**Files:**
- Modify: `tools/intro_demo/intro_title.c`

NES waterfall uses sprite slots starting at OAM offset `$70` (waves) and `$80`/`$90` (crests) per `WaterfallWaveSpriteOffsets`. We re-use the same sprite-table positions in our 28-slot Genesis sprite list (or extend if needed). Each slot's tile field rotates through 4-tile cycle every 8 frames.

- [ ] **Step 1: Add waterfall state + table data**

```c
/* Waterfall tile cycles (Z_02.asm:990-994) */
static const unsigned char waterfall_wave_tiles[4]  = {0xB2, 0xB4, 0xB6, 0xB8};
static const unsigned char waterfall_crest_tiles[4] = {0xA2, 0xA4, 0xA6, 0xA8};

/* Sprite slot indices in our 28-slot title sprite table that hold
 * waterfall wave/crest sprites. These are the indices that, in NES
 * OAM offset terms, start at $70 (wave) and $80 (crest). Each slot
 * is one sprite in our Gen list. Determined by inspecting the
 * positions in InitialTitleSprites and noting which sprites are at
 * the bottom of the screen (waterfall area). */
#define WATERFALL_WAVE_SLOTS  4u
#define WATERFALL_CREST_SLOTS 4u
static const unsigned char waterfall_wave_slot_idx[WATERFALL_WAVE_SLOTS]   = {/* TBD by inspection */};
static const unsigned char waterfall_crest_slot_idx[WATERFALL_CREST_SLOTS] = {/* TBD by inspection */};
```

**ATTENTION:** the slot indices `waterfall_wave_slot_idx` / `waterfall_crest_slot_idx` need to be derived by reading `InitialTitleSprites` byte-by-byte and finding which 4-byte entries have Y in the waterfall band (large Y values, near bottom of NES screen, i.e. ≥ $90). This is a manual extraction step — do NOT guess.

Run:
```bash
python -c "
data = bytes([
    # Paste full 112 bytes of InitialTitleSprites here
])
for i in range(0, len(data), 4):
    y, t, a, x = data[i:i+4]
    print(f'sprite {i//4}: y=\${y:02X} tile=\${t:02X} attr=\${a:02X} x=\${x:02X}')"
```

Identify waves (high Y, tile in wave range $B2-$B9) and crests (high Y, tile in crest range $A2-$A9). Fill the slot index arrays.

- [ ] **Step 2: Per-frame waterfall step**

```c
static unsigned char s_waterfall_frame = 0;
static unsigned char s_waterfall_phase = 0;

static void title_waterfall_reset(void) {
    s_waterfall_frame = 0;
    s_waterfall_phase = 0;
}

static void title_waterfall_step(void) {
    s_waterfall_frame++;
    if ((s_waterfall_frame & 0x07u) != 0) return;  /* only every 8 frames */
    s_waterfall_phase = (unsigned char)((s_waterfall_phase + 1u) & 3u);

    /* For each wave/crest slot, rewrite its sprite-list entry's tile field. */
    for (unsigned char i = 0; i < WATERFALL_WAVE_SLOTS; i++) {
        unsigned char slot = waterfall_wave_slot_idx[i];
        unsigned char nes_tile = waterfall_wave_tiles[s_waterfall_phase];
        unsigned short tile = (unsigned short)(256u + (unsigned short)nes_tile);
        /* Read attr from original NES sprite table to preserve pal/flip. */
        unsigned char nattr = nes_initial_title_sprites[slot*4 + 2];
        unsigned short pal  = (unsigned short)(nattr & 3u);
        unsigned short hflip = (unsigned short)((nattr >> 6) & 1u);
        unsigned short vflip = (unsigned short)((nattr >> 7) & 1u);
        unsigned short prio  = (unsigned short)((nattr >> 5) & 1u);
        unsigned short word2 = (unsigned short)((prio << 15) | (pal << 13)
                                                | (vflip << 12) | (hflip << 11)
                                                | (tile & 0x7FFu));
        unsigned short addr = (unsigned short)(SPRITE_TABLE_VRAM + slot*8u + 4u);
        vram_write_open(addr);
        VDP_DATA_WORD = word2;
    }
    for (unsigned char i = 0; i < WATERFALL_CREST_SLOTS; i++) {
        unsigned char slot = waterfall_crest_slot_idx[i];
        unsigned char nes_tile = waterfall_crest_tiles[s_waterfall_phase];
        unsigned short tile = (unsigned short)(256u + (unsigned short)nes_tile);
        unsigned char nattr = nes_initial_title_sprites[slot*4 + 2];
        unsigned short pal  = (unsigned short)(nattr & 3u);
        unsigned short hflip = (unsigned short)((nattr >> 6) & 1u);
        unsigned short vflip = (unsigned short)((nattr >> 7) & 1u);
        unsigned short prio  = (unsigned short)((nattr >> 5) & 1u);
        unsigned short word2 = (unsigned short)((prio << 15) | (pal << 13)
                                                | (vflip << 12) | (hflip << 11)
                                                | (tile & 0x7FFu));
        unsigned short addr = (unsigned short)(SPRITE_TABLE_VRAM + slot*8u + 4u);
        vram_write_open(addr);
        VDP_DATA_WORD = word2;
    }
}
```

Call `title_waterfall_reset()` from `intro_title_setup()` and `title_waterfall_step()` from `intro_title_step()` (in addition to `title_glow_step()`).

- [ ] **Step 3: Build + visual verify**

```bash
& cmd.exe /c "cd /d \"<repo>/tools/intro_demo\" && .\build.bat"
cp tools/intro_demo/out/intro_demo.md /c/tmp/intro_demo.md
cmd.exe //c "taskkill /F /IM EmuHawk.exe"
powershell -Command "Start-Process ... C:\tmp\intro_demo.md ..."
```

Expect: waterfall area at bottom of screen animates (wave/crest tiles cycling). Visual side-by-side with NES `nes_loop/nes_f00100.png` etc.

- [ ] **Step 4: Commit**

```bash
git add tools/intro_demo/intro_title.c
git commit -m "intro_demo: waterfall sprite tile cycling (8-frame, 4-tile rotation)"
```

---

## Task 13: PHASE_TITLE_DISPLAY exit + PHASE_TITLE_FADEOUT

**Files:**
- Modify: `tools/intro_demo/intro_phase.c`
- Modify: `tools/intro_demo/intro_title.c`

- [ ] **Step 1: Add display-frame counter to phase machine**

In `intro_phase.c`:

```c
static unsigned short s_phase_counter = 0;
static unsigned char  s_fade_cycle    = 0;

void intro_phase_init(void) {
    s_phase = PHASE_TITLE_LOAD;
    s_phase_counter = 0;
    s_fade_cycle = 0;
}

static void goto_phase(intro_phase_t next) {
    s_phase = next;
    s_phase_counter = 0;
}
```

Update step:

```c
case PHASE_TITLE_DISPLAY:
    intro_title_step();
    if (++s_phase_counter >= TITLE_DISPLAY_FRAMES) {
        s_fade_cycle = 0;
        intro_title_fade_apply(s_fade_cycle);  /* paint cycle 0 immediately */
        goto_phase(PHASE_TITLE_FADEOUT);
    }
    break;
case PHASE_TITLE_FADEOUT:
    intro_title_fade_step();  /* counts down delay, advances cycle, writes CRAM */
    if (s_fade_cycle >= 14u) {  /* set to 14 by fade_step when done */
        goto_phase(PHASE_BLACK_HOLD);
    }
    break;
```

- [ ] **Step 2: Add `intro_title_fade_apply` and reworked `intro_title_fade_step`**

In `intro_title.c`:

```c
extern const unsigned short intro_title_fade_cycles[14][64];
extern const unsigned short intro_title_fade_delays[14];

extern unsigned char s_fade_cycle;  /* shared with intro_phase.c */
static unsigned short s_fade_delay = 0;

void intro_title_fade_apply(unsigned char cycle_idx) {
    /* Write all 64 CRAM words from cycle. */
    VDP_CTRL_LONG = 0xC0000000UL;
    const unsigned short *src = intro_title_fade_cycles[cycle_idx];
    for (unsigned short i = 0; i < 64; i++) VDP_DATA_WORD = src[i];
    s_fade_delay = intro_title_fade_delays[cycle_idx];
}

void intro_title_fade_step(void) {
    if (s_fade_delay > 0) {
        s_fade_delay--;
        return;
    }
    s_fade_cycle++;
    if (s_fade_cycle >= 14u) return;  /* phase machine sees this and advances */
    intro_title_fade_apply(s_fade_cycle);
}
```

`s_fade_cycle` becomes shared state — easier to make `intro_phase.c` and `intro_title.c` access via small accessors:

```c
/* in intro_title.h: */
unsigned char intro_title_fade_cycle_get(void);
void          intro_title_fade_cycle_reset(void);
```

Implement those in `intro_title.c` and use from `intro_phase.c`. Avoids `extern` of static.

Update intro_phase.c to use `intro_title_fade_cycle_get()` for the >= 14 check. Also call `intro_title_fade_cycle_reset()` and `intro_title_fade_apply(0)` on entry to TITLE_FADEOUT.

- [ ] **Step 3: Build + boot**

```bash
& cmd.exe /c "cd /d \"<repo>/tools/intro_demo\" && .\build.bat"
cp tools/intro_demo/out/intro_demo.md /c/tmp/intro_demo.md
cmd.exe //c "taskkill /F /IM EmuHawk.exe"
powershell -Command "Start-Process ... C:\tmp\intro_demo.md ..."
```

Expect: title displays 520 frames bright, then fades through 14 NES color states ending all-black. Side-by-side compare against NES `nes_f00555` through `nes_f00785`.

- [ ] **Step 4: Commit**

```bash
git add tools/intro_demo/intro_title.h tools/intro_demo/intro_title.c tools/intro_demo/intro_phase.c
git commit -m "intro_demo: title fade-out via 14-cycle NES palette progression"
```

---

## Task 14: PHASE_BLACK_HOLD

**Files:**
- Modify: `tools/intro_demo/intro_phase.c`

- [ ] **Step 1: Add black-hold counter**

```c
#define BLACK_HOLD_FRAMES 255u

case PHASE_BLACK_HOLD:
    if (++s_phase_counter >= BLACK_HOLD_FRAMES) {
        goto_phase(PHASE_STORY_LOAD);
    }
    break;
```

- [ ] **Step 2: Build + boot, verify timing**

Boot, screenshot at frame ~900 (mid black-hold). Expect: completely black screen.

- [ ] **Step 3: Commit**

```bash
git add tools/intro_demo/intro_phase.c
git commit -m "intro_demo: PHASE_BLACK_HOLD 255 frames between fade-out and story"
```

---

## Task 15: Story runtime — extract from old main.c into story_runtime.c

**Files:**
- Create: `tools/intro_demo/story_runtime.h`
- Create: `tools/intro_demo/story_runtime.c`
- Modify: `tools/intro_demo/main.c` (remove story logic restored later — it's been gone since Task 9)
- Modify: `tools/intro_demo/intro_phase.c`
- Modify: `tools/intro_demo/build.bat`

Restore the entire story+items+flash+endpause logic from the pre-Task-9 main.c into a new `story_runtime` module. **Critical preservation rule: the behavior must be byte-for-byte equivalent to the f246e71d state.**

- [ ] **Step 1: Recover old main.c body**

```bash
git show f246e71d:tools/intro_demo/main.c > /tmp/main_old.c
```

Copy the full pre-loop setup (CHR uploads, palette, plane init) and the for-loop body into the new module.

- [ ] **Step 2: Write story_runtime.h**

```c
#ifndef STORY_RUNTIME_H
#define STORY_RUNTIME_H

void story_runtime_load(void);   /* PHASE_STORY_LOAD: full re-upload */
void story_runtime_step(void);   /* per vblank during STORY_SCROLL_IN..END_PAUSE */
unsigned char story_runtime_at_end(void);  /* 1 once END_PAUSE expired */

#endif
```

- [ ] **Step 3: Write story_runtime.c**

Move all of: CHR uploads (combined palette, blink CHR, story tilemap pre-write to plane, vsram_set0(0), display on); the for-loop body (item flash anims, story_hold gate, end_pause, tick gate, scroll++, row-boundary plane writes, restart cycle).

The restart-cycle branch (which currently writes `pixel_count >= total_pixels`) does NOT do an in-place reset anymore — instead, it sets a `s_at_end = 1` flag. Phase machine reads that via `story_runtime_at_end()`.

Preserve: `STORY_SCROLL_TARGET`, `STORY_HOLD_FRAMES`, `PRE_BLANK_ROWS`, `GAP_ROWS`, all visibility windows for heart/fairy/rupee/triforce, all flash counters.

- [ ] **Step 4: Wire into intro_phase.c**

```c
#include "story_runtime.h"

case PHASE_STORY_LOAD:
    story_runtime_load();
    goto_phase(PHASE_STORY_SCROLL_IN);
    break;
case PHASE_STORY_SCROLL_IN:
case PHASE_STORY_HOLD:
case PHASE_SCROLL_OFF:
case PHASE_END_PAUSE:
    story_runtime_step();
    if (story_runtime_at_end()) {
        goto_phase(PHASE_TITLE_LOAD);
    }
    break;
```

The 4 enum entries collapse to a single handler since `story_runtime_step()` internally manages its sub-states. The `intro_phase_t` enum entries can remain for documentation but the handler is unified.

- [ ] **Step 5: Update build.bat**

Add compile step for story_runtime.c, link entry.

- [ ] **Step 6: Build + boot, verify full sequence**

```bash
& cmd.exe /c "cd /d \"<repo>/tools/intro_demo\" && .\build.bat"
cp tools/intro_demo/out/intro_demo.md /c/tmp/intro_demo.md
cmd.exe //c "taskkill /F /IM EmuHawk.exe"
powershell -Command "Start-Process ... C:\tmp\intro_demo.md ..."
```

Expect: title (520fr) → fade-out (230fr) → black hold (255fr) → story scrolls in → holds → items show with flash → end pause → loops back to title.

Frame milestones (Genesis, comparing to NES):
- f0035: title visible (after very brief boot — should match instantly since no fade-in, but allow ~30 frames boot lag)
- f0555: fade beginning
- f0785: full black
- f1040: story top first visible
- f1445: story settled
- f1705: scroll-off begins
- ~f2500: items appearing with flash
- ~f4500: triforce/sign at end
- ~f5000: loop back to title

- [ ] **Step 7: 5-min soak**

Let it run 5 minutes. Verify clean loop, no VRAM corruption, no CRAM bleed, no garbage frames between phase transitions.

- [ ] **Step 8: Commit**

```bash
git add tools/intro_demo/story_runtime.h tools/intro_demo/story_runtime.c \
        tools/intro_demo/intro_phase.c tools/intro_demo/build.bat
git commit -m "intro_demo: extract story runtime; full attract loop title->story->title"
```

---

## Task 16: Tune timing constants from capture comparison

**Files:**
- Modify: `tools/intro_demo/intro_title.h` (constants only)

After Task 15 produces a working full loop, capture Genesis screenshots at the same frame numbers as NES references and compare. If `f0555` Genesis fade-start is too early/late, adjust `TITLE_DISPLAY_FRAMES`. If fade-end at `f0785` is wrong, adjust `intro_title_fade_delays` (re-run `extract_title_fade.py` with revised constants). If story doesn't appear at `f1040`, adjust `BLACK_HOLD_FRAMES`.

- [ ] **Step 1: Capture reference frames via Lua probe**

```lua
-- /c/tmp/probe_milestones.lua
local STAMPS = {35, 100, 555, 700, 785, 900, 1040, 1200, 1445, 1705, 2200, 2500}
for _, s in ipairs(STAMPS) do
    while emu.framecount() < s do emu.frameadvance() end
    client.screenshot(string.format("C:/tmp/probe_milestone_f%05d.png", s))
end
client.exit()
```

- [ ] **Step 2: Diff visually against NES captures**

Place each Genesis `probe_milestone_f*.png` next to corresponding `tools/intro_demo/nes_loop/nes_f*.png`. For each milestone, note "OK" or "off by N frames forward/backward".

- [ ] **Step 3: Adjust constants**

If `f0555` Genesis shows already-fading content, decrease `TITLE_DISPLAY_FRAMES`. If still bright, increase. Repeat for fade end (`extract_title_fade.py` `DELAYS_COMPRESSED` sum) and `BLACK_HOLD_FRAMES`.

Each adjustment: change constant, rebuild, reboot, re-probe.

- [ ] **Step 4: Final commit**

```bash
git add tools/intro_demo/intro_title.h tools/intro_demo/extract_title_fade.py tools/intro_demo/intro_phase.c
git commit -m "intro_demo: tune title timing constants to NES capture milestones"
```

---

## Self-Review

### Spec coverage
| Spec section | Implemented in task |
|--------------|---------------------|
| Title BG tilemap | Task 3 |
| Title BG CHR | Task 1 |
| Title sprite CHR | Task 2 |
| Title palette | Tasks 0, 4 |
| Title fade table (compressed delays) | Task 5 |
| Glow data | Task 6 |
| Phase state machine | Tasks 7, 13, 14, 15 |
| Title load (CHR/CRAM/plane/sprites) | Tasks 8, 10 |
| Triforce glow (Gen pal 1 slot 2) | Task 11 |
| Waterfall sprite anim | Task 12 |
| Title fade-out | Task 13 |
| Black hold | Task 14 |
| Story runtime preservation | Task 15 |
| Loop back to title | Task 15 |
| Timing tuning | Task 16 |

All spec sections covered.

### Placeholder scan
- Task 10 Step 1: I left a TODO block for completing `nes_initial_title_sprites[]`. **Fixed by inline instruction** — engineer must transcribe Z_02.asm:342-360 verbatim, no zero padding.
- Task 12 Step 1: `waterfall_wave_slot_idx` / `waterfall_crest_slot_idx` marked `/* TBD by inspection */`. **Fixed by inline derivation procedure** — engineer runs the Python script provided to identify which slot indices contain waterfall tiles ($A2-$A9 / $B2-$B9), then fills the arrays with those exact indices. No guessing.
- Task 0: NES ROM path "TBD by user" — this requires asking the user for the path; if Codex/agent runs this autonomously and can't find a NES Zelda ROM in the repo, must stop and ask.

No "implement later" / "add error handling" / "similar to Task N" / "fill in details" patterns remain.

### Type consistency
- Phase enum names match across `intro_phase.h` declarations and `.c` switch arms.
- `intro_title_setup`, `intro_title_step`, `intro_title_fade_apply`, `intro_title_fade_step`, `intro_title_fade_cycle_get/reset` consistent across header and impl.
- `story_runtime_load`, `story_runtime_step`, `story_runtime_at_end` consistent.
- Generated symbol names: `intro_title_bg_chr` / `_size`, `intro_title_sprite_chr` / `_size`, `intro_title_tilemap` / `_rows`, `intro_title_palette[64]`, `intro_title_fade_cycles[14][64]`, `intro_title_fade_delays[14]`, `intro_title_glow_colors[8]`, `intro_title_glow_delays[8]`. All declared in same form across extract scripts and runtime externs.

### Scope check
Single coherent feature: title screen integration + loop. No multi-subsystem decomposition needed. Plan is appropriately sized.

---

## Files Touched Summary

**Added (Python generators)**
- `tools/intro_demo/extract_title_bg_chr.py` (Task 1)
- `tools/intro_demo/extract_title_sprite_chr.py` (Task 2)
- `tools/intro_demo/extract_title_tilemap.py` (Task 3)
- `tools/intro_demo/extract_title_palette.py` (Task 4)
- `tools/intro_demo/extract_title_fade.py` (Task 5)
- `tools/intro_demo/extract_title_glow.py` (Task 6)

**Added (runtime)**
- `tools/intro_demo/intro_phase.h` (Task 7)
- `tools/intro_demo/intro_phase.c` (Tasks 7, 13, 14, 15)
- `tools/intro_demo/intro_title.h` (Task 8)
- `tools/intro_demo/intro_title.c` (Tasks 8, 10, 11, 12, 13)
- `tools/intro_demo/story_runtime.h` (Task 15)
- `tools/intro_demo/story_runtime.c` (Task 15)

**Generated (committed alongside source)**
- `intro_title_bg_chr.c`, `intro_title_sprite_chr.c`, `intro_title_tilemap.c`, `intro_title_palette.c`, `intro_title_fade.c`, `intro_title_glow.c`
- `tools/intro_demo/nes_full/palram_title.bin`, `palram_title_screenshot.png`

**Changed**
- `tools/intro_demo/main.c` (Task 9)
- `tools/intro_demo/build.bat` (Tasks 8, 15)
