# RoomRom BG Palette + Item Atlas + CHR Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore byte-accurate NES BG sub-palette 3 colors in RoomRom by replacing direct NES-pal-to-Genesis-slot mapping with packed-palette + pixel-biased CHR expansion. Bundles the live NES item atlas wiring + live PALRAM capture + HUD/Window cutover in five shippable phases.

**Architecture:** Genesis VDP has 4 palette slots × 16 entries vs NES 4 BG + 4 SPR sub-pals × 4 entries. Pack all 4 NES BG sub-pals into Gen PAL0, all 4 NES SPR sub-pals into Gen PAL1, store 4 pixel-biased CHR copies per NES tile in VRAM, and route NES sub-pal selector through the tile-index instead of the Gen pal-slot field. PAL2/3 stay reserved.

**Tech Stack:** SGDK (Genesis), C (RoomRom render path), Python 3 (CHR + palette generators), BizHawk Lua (NES PALRAM probe), vasm (legacy ASM, untouched), Windows batch (build).

**Spec:** [docs/superpowers/specs/2026-05-01-roomrom-bg-palette-chr-expansion-design.md](../specs/2026-05-01-roomrom-bg-palette-chr-expansion-design.md)

**Worktree:** `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY-roomrom-s1` (branch `roomrom-s1`).

**Phase shippability:**
- Phase 1 ships item ART fix on its own.
- Phase 2 + 2.5 are infrastructure; ship together once VRAM relocation passes smoke.
- Phase 3 + 4 form the slot-collision cutover; ship together.
- Phase 5 verifies + locks in the result.

---

## Phase 1 — Item Atlas Wiring

Phase 1 ships visible item-art fix. Keeps the existing `slot < 3` BG load and PAL3-sprite mapping. Sub-pal 0 only.

### Task 1.1: Confirm live NES item CHR dumps

**Files:**
- Read: `RoomRom/out/nes_item_chr_pt0_orig.bin`
- Read: `RoomRom/out/nes_item_chr_pt0_redux.bin`
- Read: `RoomRom/out/nes_item_chr_manifest_probe_orig.json`
- Read: `RoomRom/out/nes_item_chr_manifest_probe_redux.json`

- [ ] **Step 1: Verify dumps exist**

Run: `ls RoomRom/out/nes_item_chr_pt0_*.bin RoomRom/out/nes_item_chr_manifest_probe_*.json`

Expected: All four files listed.

- [ ] **Step 2: Spot-check binary size**

Run: `wc -c RoomRom/out/nes_item_chr_pt0_orig.bin`

Expected: 4096 bytes (NES PT0 = 256 tiles × 16 bytes 2bpp).

- [ ] **Step 3: Spot-check manifest contents**

Read both JSONs. Each must list per-item entries with `nes_tile_id`, `tile_count`, `variant`, `chr_offset`. No `guessed_common_chr: true`.

- [ ] **Step 4: If any file missing, regenerate**

Run from `C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY-roomrom-s1`:

```powershell
python RoomRom\tools\gen_item_chr_manifest.py --chr-dump orig=RoomRom\out\nes_item_chr_pt0_orig.bin --chr-dump redux=RoomRom\out\nes_item_chr_pt0_redux.bin
```

Expected: re-emits the manifest JSONs without errors.

### Task 1.2: Generate roomrom_item_chr.{c,h}

**Files:**
- Read: `RoomRom/tools/gen_item_chr_blob.py`
- Create: `RoomRom/src/roomrom_item_chr.c`
- Create: `RoomRom/src/roomrom_item_chr.h`

- [ ] **Step 1: Read generator**

Read `RoomRom/tools/gen_item_chr_blob.py`. Confirm it consumes the manifests and emits a 4bpp Genesis tile array per variant + per-item tile-offset macros.

- [ ] **Step 2: Run generator**

Run from worktree root:

```powershell
python RoomRom\tools\gen_item_chr_blob.py
```

Expected: writes `RoomRom/src/roomrom_item_chr.c` + `.h`. Print confirms total tile count.

- [ ] **Step 3: Inspect generated header**

Read `RoomRom/src/roomrom_item_chr.h`. Must declare:

```c
#define ROOMROM_ITEM_VARIANT_ORIG  0u
#define ROOMROM_ITEM_VARIANT_REDUX 1u

extern const unsigned char *const roomrom_item_chr[2];
extern const unsigned short roomrom_item_chr_byte_count;

#define ROOMROM_ITEM_TILE_SWORD_VERT     /* offset */
#define ROOMROM_ITEM_TILE_SWORD_HORZ     /* offset */
#define ROOMROM_ITEM_TILE_BOOMERANG      /* offset */
#define ROOMROM_ITEM_TILE_ARROW_VERT     /* offset */
#define ROOMROM_ITEM_TILE_ARROW_HORZ     /* offset */
#define ROOMROM_ITEM_TILE_BOMB           /* offset */
#define ROOMROM_ITEM_TILE_EXPLOSION      /* offset */
```

If any item missing, fix `gen_item_chr_blob.py` to emit it.

- [ ] **Step 4: Commit**

```bash
git add RoomRom/src/roomrom_item_chr.c RoomRom/src/roomrom_item_chr.h
git commit -m "roomrom: generate live NES item atlas (orig + redux)"
```

### Task 1.3: Add set_redux APIs

**Files:**
- Modify: `RoomRom/src/roomrom_sprites.h`
- Modify: `RoomRom/src/roomrom_combat.h`
- Modify: `RoomRom/src/roomrom_sprites.c`
- Modify: `RoomRom/src/roomrom_combat.c`

- [ ] **Step 1: Add declarations**

Edit `RoomRom/src/roomrom_sprites.h`. Append before the closing include guard:

```c
void roomrom_sprites_set_redux(unsigned char redux);
```

Edit `RoomRom/src/roomrom_combat.h`. Append:

```c
void roomrom_combat_set_redux(unsigned char redux);
```

- [ ] **Step 2: Add static state + setter to sprites.c**

Edit `RoomRom/src/roomrom_sprites.c`. After the existing `static const link_pose_def_t attack_poses[...]` block, add:

```c
static unsigned char s_item_chr_variant = ROOMROM_ITEM_VARIANT_ORIG;

void roomrom_sprites_set_redux(unsigned char redux)
{
    s_item_chr_variant = redux ? ROOMROM_ITEM_VARIANT_REDUX
                               : ROOMROM_ITEM_VARIANT_ORIG;
}
```

Add `#include "roomrom_item_chr.h"` near the top after the existing `#include "render_abi.h"`.

- [ ] **Step 3: Same for combat.c**

Edit `RoomRom/src/roomrom_combat.c`. Add:

```c
#include "roomrom_item_chr.h"

static unsigned char s_combat_item_variant = ROOMROM_ITEM_VARIANT_ORIG;

void roomrom_combat_set_redux(unsigned char redux)
{
    s_combat_item_variant = redux ? ROOMROM_ITEM_VARIANT_REDUX
                                  : ROOMROM_ITEM_VARIANT_ORIG;
}
```

- [ ] **Step 4: Compile-only check**

Run: `RoomRom\build.bat`

Expected: compiles. Item atlas not yet wired into uploads — variant variable unused for now.

- [ ] **Step 5: Commit**

```bash
git add RoomRom/src/roomrom_sprites.h RoomRom/src/roomrom_combat.h RoomRom/src/roomrom_sprites.c RoomRom/src/roomrom_combat.c
git commit -m "roomrom: add set_redux APIs for item atlas variant switching"
```

### Task 1.4: Replace item literals in roomrom_sprites.c

**Files:**
- Modify: `RoomRom/src/roomrom_sprites.c` (item VRAM macros + `roomrom_sprites_upload_chr`)

- [ ] **Step 1: Replace VRAM tile macros**

In `RoomRom/src/roomrom_sprites.c`, replace the block from `#define SWORD_VERT_VRAM_TILE` through `#define EXPLOSION_TILE_COUNT` with:

```c
/* Item atlas tiles live in their own contiguous block starting after
 * Link attack poses. Tile offsets come from the live NES item CHR
 * generator (RoomRom/src/roomrom_item_chr.h). */
#define ITEM_VRAM_TILE          (ATTACK_VRAM_TILE + ATTACK_POSE_COUNT * LINK_TILES_PER_POSE)

#define SWORD_VERT_VRAM_TILE    (ITEM_VRAM_TILE + ROOMROM_ITEM_TILE_SWORD_VERT)
#define SWORD_HORZ_VRAM_TILE    (ITEM_VRAM_TILE + ROOMROM_ITEM_TILE_SWORD_HORZ)
#define BOOMERANG_VRAM_TILE     (ITEM_VRAM_TILE + ROOMROM_ITEM_TILE_BOOMERANG)
#define ARROW_VERT_VRAM_TILE    (ITEM_VRAM_TILE + ROOMROM_ITEM_TILE_ARROW_VERT)
#define ARROW_HORZ_VRAM_TILE    (ITEM_VRAM_TILE + ROOMROM_ITEM_TILE_ARROW_HORZ)
#define BOMB_VRAM_TILE          (ITEM_VRAM_TILE + ROOMROM_ITEM_TILE_BOMB)
#define EXPLOSION_VRAM_TILE     (ITEM_VRAM_TILE + ROOMROM_ITEM_TILE_EXPLOSION)
```

- [ ] **Step 2: Replace item upload section in `roomrom_sprites_upload_chr`**

Locate the per-item upload loops (sword vertical/horizontal, boomerang, arrow vertical/horizontal, bomb, explosion). They iterate over `0x82..0x89` and other guessed `common_chr` literals.

Replace the entire post-attack-pose item upload section with one block:

```c
    /* Item atlas: live NES CHR, variant-selected. */
    render_chr_upload((unsigned short)(ITEM_VRAM_TILE * 32u),
                      roomrom_item_chr[s_item_chr_variant],
                      roomrom_item_chr_byte_count);
```

- [ ] **Step 3: Add common-block guard in `upload_pose`**

Modify `upload_pose`. Before the existing tile-byte copy, add:

```c
    #ifndef COMMON_SPRITE_PATTERN_TILE_COUNT
    #define COMMON_SPRITE_PATTERN_TILE_COUNT 112u
    #endif
```

Then in the inner copy loop replace `for (i = 0; i < 32; i++) buf[i] = common_chr[nes_off + i];` with:

```c
        if (pose->nes_ids[t] >= COMMON_SPRITE_PATTERN_TILE_COUNT) {
            for (i = 0; i < 32; i++) buf[i] = 0;
        } else {
            for (i = 0; i < 32; i++) buf[i] = common_chr[nes_off + i];
        }
```

- [ ] **Step 4: Re-enable horizontal arrow**

Search `roomrom_arrow.c` for any `#if 0` / commented-out horizontal-arrow rendering. Re-enable using `ARROW_HORZ_VRAM_TILE`. If not present already, add a horizontal arrow draw branch that mirrors the vertical path but selects `ARROW_HORZ_VRAM_TILE` and a horizontal sprite size (2x1 or 2x2 per atlas).

- [ ] **Step 5: Build**

Run: `RoomRom\build.bat`

Expected: compiles. ROM at `RoomRom/out/RoomRom.md`.

- [ ] **Step 6: Emu smoke**

Use bizhawkScript skill. Boot RoomRom. Probe Link swing with sword (UP/DOWN/LEFT/RIGHT). Confirm vertical + horizontal sword art is the live NES sword shape, not garbage from `common_chr` $82+.

- [ ] **Step 7: Commit**

```bash
git add RoomRom/src/roomrom_sprites.c RoomRom/src/roomrom_arrow.c
git commit -m "roomrom: route item sprites through live NES item atlas"
```

### Task 1.5: Wire set_redux on toggles in main.c

**Files:**
- Modify: `RoomRom/src/main.c`

- [ ] **Step 1: Add includes + helper**

Edit `RoomRom/src/main.c`. Add `#include "roomrom_sprites.h"` and `#include "roomrom_combat.h"` near other RoomRom includes. Then add a static helper:

```c
static unsigned char current_redux_flag(void)
{
    if (s_scene == SCENE_UW)
        return (unsigned char)(roomrom_uw_room_render_get_map() != 0u);
    return (unsigned char)(roomrom_ow_room_render_get_map() != 0u);
}
```

(If `s_scene`/`SCENE_UW`/`SCENE_OW` are named differently in `main.c`, use the existing names — read the file to confirm.)

- [ ] **Step 2: Call set_redux after boot upload**

Find where `roomrom_sprites_upload_chr()` is called during boot. Immediately after that call, add:

```c
    roomrom_sprites_set_redux(current_redux_flag());
    roomrom_combat_set_redux(current_redux_flag());
```

- [ ] **Step 3: Call set_redux on every toggle**

Find each scene-toggle / map-toggle handler (C-button toggle for redux, scene toggle for OW↔UW, etc.). After each handler updates the map/scene state, append:

```c
        roomrom_sprites_set_redux(current_redux_flag());
        roomrom_combat_set_redux(current_redux_flag());
        roomrom_sprites_upload_chr();
```

`roomrom_sprites_upload_chr` re-uploads the variant-selected atlas. Call it on map toggle only (not level/quest toggles — those keep variant the same).

- [ ] **Step 4: Build + smoke**

Run: `RoomRom\build.bat`

Boot RoomRom. C-toggle to redux; confirm sword/items render with redux art. Toggle back; confirm orig art returns. No stale CHR.

- [ ] **Step 5: Commit**

```bash
git add RoomRom/src/main.c
git commit -m "roomrom: drive item atlas variant on scene/map toggle"
```

### Task 1.6: Update build.bat + add item verifier

**Files:**
- Modify: `RoomRom/build.bat`
- Create: `RoomRom/tools/verify_item_chr_manifest.py`

- [ ] **Step 1: Add roomrom_item_chr.c to build**

Read `RoomRom/build.bat`. Find the line listing `RoomRom/src/*.c` for compilation. Append `roomrom_item_chr.c` to the source list (or confirm wildcard already includes it).

- [ ] **Step 2: Write the verifier**

Create `RoomRom/tools/verify_item_chr_manifest.py`:

```python
"""Hard gate: rejects guessed common-CHR item literals + manifest mismatch.

Exit code 0 = pass, 1 = fail.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPRITES_C = ROOT / "src" / "roomrom_sprites.c"
MANIFEST_ORIG = ROOT / "out" / "nes_item_chr_manifest_probe_orig.json"
MANIFEST_REDUX = ROOT / "out" / "nes_item_chr_manifest_probe_redux.json"
ITEM_CHR_H = ROOT / "src" / "roomrom_item_chr.h"

FORBIDDEN_LITERALS = {0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89}
LITERAL_RE = re.compile(r"\b0x([0-9A-Fa-f]{2})u?\b")

def fail(msg):
    print(f"verify_item_chr_manifest: FAIL: {msg}", file=sys.stderr)
    sys.exit(1)

def main():
    if not SPRITES_C.exists():
        fail(f"missing {SPRITES_C}")
    src = SPRITES_C.read_text(encoding="utf-8")
    bad = set()
    for m in LITERAL_RE.finditer(src):
        v = int(m.group(1), 16)
        if v in FORBIDDEN_LITERALS:
            bad.add(v)
    if bad:
        fail(f"forbidden NES item-tile literals in roomrom_sprites.c: "
             f"{sorted(hex(b) for b in bad)} (route via item atlas)")
    for path in (MANIFEST_ORIG, MANIFEST_REDUX):
        if not path.exists():
            fail(f"missing manifest {path}")
        m = json.loads(path.read_text(encoding="utf-8"))
        for entry in m.get("items", []):
            if entry.get("guessed_common_chr"):
                fail(f"manifest {path.name} has guessed_common_chr=true: "
                     f"{entry.get('name')}")
    if not ITEM_CHR_H.exists():
        fail(f"missing {ITEM_CHR_H}")
    print("verify_item_chr_manifest: OK")

if __name__ == "__main__":
    main()
```

- [ ] **Step 3: Run verifier**

Run from worktree root: `python RoomRom\tools\verify_item_chr_manifest.py`

Expected: `verify_item_chr_manifest: OK`. If FAIL, fix the underlying issue (manifest or sprites.c) and re-run.

- [ ] **Step 4: Commit**

```bash
git add RoomRom/build.bat RoomRom/tools/verify_item_chr_manifest.py
git commit -m "roomrom: link item atlas + add verifier gate"
```

### Task 1.7: Phase 1 acceptance

- [ ] **Step 1: Full build**

Run: `RoomRom\build.bat`

Expected: emits `RoomRom/out/RoomRom.md`.

- [ ] **Step 2: Run verifier**

Run: `python RoomRom\tools\verify_item_chr_manifest.py`

Expected: `OK`.

- [ ] **Step 3: Emu smoke matrix**

Use bizhawkScript. For each of: `(orig, redux) × (OW, UW) × (sword vertical, sword horizontal, beam, boomerang, arrow vertical, arrow horizontal, bomb, explosion)`, capture a screenshot at frame where the sprite is on-screen.

Confirm: sprite ART matches NES, no garbage tiles, no `$82..$89` smearing. (Sprite COLOR may still be off — Phase 4 fixes color.)

- [ ] **Step 4: Tag Phase 1 complete**

```bash
git tag roomrom-phase1-items
```

---

## Phase 2 — Live PALRAM Capture + Central Converter

Phase 2 is data + infrastructure only. No renderer changes.

### Task 2.1: Write probe_nes_bg_palette_manifest.lua

**Files:**
- Create: `RoomRom/probe_nes_bg_palette_manifest.lua`

- [ ] **Step 1: Read existing OW probe for reference**

Find an existing RoomRom probe lua (e.g. `RoomRom/probe_nes_uw_l1_floodwalk.lua` if present, or any `probe_nes_*.lua`). Note the BizHawk API patterns: `memory.usememorydomain("PALRAM")`, `joypad.set`, frame stepping.

- [ ] **Step 2: Write the OW palette probe**

Create `RoomRom/probe_nes_bg_palette_manifest.lua`:

```lua
-- BG palette manifest probe.
-- For each of 128 OW rooms (NES room id 0x00..0x7F), teleport, settle, dump
-- PALRAM 32 bytes. Outputs JSON to RoomRom/out/nes_bg_palette_manifest_<rom>.json.
--
-- Run twice: once with vanilla Z1 ROM, once with Redux ROM (BizHawk loads
-- whichever ROM is currently selected; this script reads which one via
-- the user-provided rom_label arg).

local rom_label = os.getenv("ROOMROM_ROM_LABEL") or "orig"
local out_dir = os.getenv("ROOMROM_OUT_DIR") or
                "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY-roomrom-s1/RoomRom/out"
local out_path = string.format("%s/nes_bg_palette_manifest_%s.json", out_dir, rom_label)

local ROOM_ADDR_NES = 0x00EB        -- Z1 RAM: current overworld room id
local TELEPORT_ENABLE = 0x064E      -- Z1 cheat hook (per existing teleport probes)
local SETTLE_FRAMES = 12

memory.usememorydomain("PALRAM")
local function dump_palram32()
    local b = {}
    for i = 0, 31 do b[#b+1] = memory.readbyte(i) end
    return b
end

memory.usememorydomain("System Bus")
local function set_room(id)
    -- Match the teleport pattern from the existing UW probe.
    memory.writebyte(ROOM_ADDR_NES, id)
    -- Step a frame so the engine notices.
    emu.frameadvance()
end

local entries = {}
for room = 0, 127 do
    set_room(room)
    for _ = 1, SETTLE_FRAMES do emu.frameadvance() end
    memory.usememorydomain("PALRAM")
    local pr = dump_palram32()
    memory.usememorydomain("System Bus")
    local mask = memory.readbyte(0x2001)
    entries[#entries + 1] = {
        room_id = room,
        rom_label = rom_label,
        palram = pr,
        ppu_mask = mask,
        settle_frames = SETTLE_FRAMES,
    }
end

local function tojson(t)
    local function emit(v)
        if type(v) == "table" then
            if #v > 0 then
                local parts = {}
                for i = 1, #v do parts[i] = emit(v[i]) end
                return "[" .. table.concat(parts, ",") .. "]"
            end
            local parts = {}
            for k, vv in pairs(v) do
                parts[#parts+1] = string.format("\"%s\":%s", k, emit(vv))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        elseif type(v) == "number" then
            return tostring(v)
        elseif type(v) == "string" then
            return string.format("%q", v)
        elseif type(v) == "boolean" then
            return v and "true" or "false"
        end
        return "null"
    end
    return emit(t)
end

local f = io.open(out_path, "w")
f:write("{\"rom_label\":\"" .. rom_label .. "\",\"entries\":")
f:write(tojson(entries))
f:write("}")
f:close()
print("Wrote " .. out_path)
```

(Notes: PALRAM domain dump is the user-required source. 12-frame settle matches spec. Teleport hook uses Z1 RAM `$00EB`; confirm the existing teleport mechanism in other RoomRom probes — adapt if RoomRom uses a different teleport address such as `$064E`/`$0606`.)

- [ ] **Step 3: Verify probe parses**

Run BizHawk with the probe via the bizhawkScript skill. Initial run on vanilla Z1 ROM with `ROOMROM_ROM_LABEL=orig`. Confirm `RoomRom/out/nes_bg_palette_manifest_orig.json` written and parseable:

```powershell
python -c "import json,pathlib; print(len(json.loads(pathlib.Path('RoomRom/out/nes_bg_palette_manifest_orig.json').read_text())['entries']))"
```

Expected: `128`.

- [ ] **Step 4: Run probe on redux ROM**

Re-launch BizHawk with redux ROM loaded, `ROOMROM_ROM_LABEL=redux`. Run probe. Confirm `nes_bg_palette_manifest_redux.json` written, 128 entries.

- [ ] **Step 5: Commit**

```bash
git add RoomRom/probe_nes_bg_palette_manifest.lua RoomRom/out/nes_bg_palette_manifest_orig.json RoomRom/out/nes_bg_palette_manifest_redux.json
git commit -m "roomrom: capture live NES OW BG palettes (orig + redux, 128 rooms)"
```

### Task 2.2: Write gen_bg_palette_blob.py

**Files:**
- Create: `RoomRom/tools/gen_bg_palette_blob.py`
- Create (output): `RoomRom/src/roomrom_ow_palette.c`
- Create (output): `RoomRom/src/roomrom_ow_palette.h`

- [ ] **Step 1: Write generator**

Create `RoomRom/tools/gen_bg_palette_blob.py`:

```python
"""Generate roomrom_ow_palette.{c,h} from live NES PALRAM manifests.

Output schema:
    extern const unsigned char g_roomrom_ow_palram[2][128][32];

Map index 0 = original, 1 = redux. Stored as raw NES PALRAM bytes (32 each:
16 BG + 16 SPR). nes_to_cram conversion stays in roomrom_bg_palette.c at
runtime (single source of truth for color conversion).
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "out"
SRC_DIR = ROOT / "src"

INPUTS = [
    ("orig",  OUT_DIR / "nes_bg_palette_manifest_orig.json"),
    ("redux", OUT_DIR / "nes_bg_palette_manifest_redux.json"),
]

def load_manifest(path):
    data = json.loads(path.read_text(encoding="utf-8"))
    entries = data.get("entries", [])
    if len(entries) != 128:
        raise SystemExit(f"{path}: expected 128 entries, got {len(entries)}")
    table = [None] * 128
    for e in entries:
        rid = e["room_id"]
        pr  = e["palram"]
        if not (0 <= rid < 128):
            raise SystemExit(f"{path}: room_id {rid} out of range")
        if len(pr) != 32:
            raise SystemExit(f"{path}: room {rid} palram len {len(pr)}")
        table[rid] = pr
    if any(row is None for row in table):
        raise SystemExit(f"{path}: missing rooms")
    return table

def emit_c(rom_tables, out_c, out_h):
    h_lines = [
        "/* Generated by RoomRom/tools/gen_bg_palette_blob.py. Do not edit. */",
        "#ifndef ROOMROM_OW_PALETTE_H",
        "#define ROOMROM_OW_PALETTE_H",
        "",
        "extern const unsigned char g_roomrom_ow_palram[2][128][32];",
        "",
        "#endif",
    ]
    out_h.write_text("\n".join(h_lines) + "\n", encoding="utf-8")

    c_lines = [
        "/* Generated by RoomRom/tools/gen_bg_palette_blob.py. Do not edit. */",
        "#include \"roomrom_ow_palette.h\"",
        "",
        "const unsigned char g_roomrom_ow_palram[2][128][32] = {",
    ]
    for rom_idx, (label, table) in enumerate(rom_tables):
        c_lines.append(f"    /* map {rom_idx} = {label} */ {{")
        for rid, row in enumerate(table):
            row_hex = ", ".join(f"0x{b:02X}" for b in row)
            c_lines.append(f"        /* room 0x{rid:02X} */ {{ {row_hex} }},")
        c_lines.append("    },")
    c_lines.append("};")
    out_c.write_text("\n".join(c_lines) + "\n", encoding="utf-8")

def main():
    rom_tables = []
    for label, path in INPUTS:
        if not path.exists():
            raise SystemExit(f"missing input {path}")
        rom_tables.append((label, load_manifest(path)))
    emit_c(rom_tables, SRC_DIR / "roomrom_ow_palette.c",
                       SRC_DIR / "roomrom_ow_palette.h")
    print("wrote roomrom_ow_palette.{c,h}")

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run generator**

Run: `python RoomRom\tools\gen_bg_palette_blob.py`

Expected: writes `RoomRom/src/roomrom_ow_palette.{c,h}`. No errors.

- [ ] **Step 3: Inspect emitted C**

Read first ~10 lines of `RoomRom/src/roomrom_ow_palette.c`. Confirm shape `[2][128][32]` and first row contains `0x0F` at index 0 (NES universal backdrop).

- [ ] **Step 4: Commit**

```bash
git add RoomRom/tools/gen_bg_palette_blob.py RoomRom/src/roomrom_ow_palette.c RoomRom/src/roomrom_ow_palette.h
git commit -m "roomrom: generate OW PALRAM blob (orig + redux, [2][128][32])"
```

### Task 2.3: Write roomrom_bg_palette module

**Files:**
- Create: `RoomRom/src/roomrom_bg_palette.h`
- Create: `RoomRom/src/roomrom_bg_palette.c`

- [ ] **Step 1: Write header**

Create `RoomRom/src/roomrom_bg_palette.h`:

```c
#ifndef ROOMROM_BG_PALETTE_H
#define ROOMROM_BG_PALETTE_H

/* Centralized NES->Genesis palette conversion + bulk loaders.
 *
 * load_palram_full writes Gen PAL0 (16 colors from palram32[0..15]) and
 * Gen PAL1 (16 colors from palram32[16..31]). Does NOT touch PAL2/PAL3.
 *
 * load_bg_only writes Gen PAL0 only. Use when caller has BG-half bytes.
 */

unsigned short roomrom_bg_palette_nes_to_cram(unsigned char nes_color);
void roomrom_bg_palette_load_palram_full(const unsigned char *palram32);
void roomrom_bg_palette_load_bg_only(const unsigned char *palram16);

#endif
```

- [ ] **Step 2: Write implementation**

Create `RoomRom/src/roomrom_bg_palette.c`:

```c
#include "roomrom_bg_palette.h"
#include "render_abi.h"

/* Reuse the existing misc_palettes NES-color-index -> Gen-CRAM-word LUT. */
extern const unsigned char misc_palettes[1208];

unsigned short roomrom_bg_palette_nes_to_cram(unsigned char nes_color)
{
    unsigned short off = (unsigned short)(nes_color & 0x3Fu) * 2u;
    return (unsigned short)misc_palettes[off]
         | ((unsigned short)misc_palettes[off + 1] << 8);
}

static void load_slot16(unsigned char gen_slot, const unsigned char *nes16)
{
    unsigned short pal16[16];
    unsigned char i;
    for (i = 0; i < 16; i++) {
        pal16[i] = roomrom_bg_palette_nes_to_cram(nes16[i]);
    }
    render_load_palette(gen_slot, pal16);
}

void roomrom_bg_palette_load_palram_full(const unsigned char *palram32)
{
    load_slot16(0, palram32 + 0);   /* Gen PAL0 = NES BG sub-pals 0..3 */
    load_slot16(1, palram32 + 16);  /* Gen PAL1 = NES SPR sub-pals 0..3 */
}

void roomrom_bg_palette_load_bg_only(const unsigned char *palram16)
{
    load_slot16(0, palram16);
}
```

- [ ] **Step 3: Add to build**

Edit `RoomRom/build.bat`. Append `roomrom_bg_palette.c` and `roomrom_ow_palette.c` to source list.

- [ ] **Step 4: Compile-only check**

Run: `RoomRom\build.bat`

Expected: builds. Modules linked, not yet called from renderers.

- [ ] **Step 5: Commit**

```bash
git add RoomRom/src/roomrom_bg_palette.h RoomRom/src/roomrom_bg_palette.c RoomRom/build.bat
git commit -m "roomrom: central nes_to_cram + load_palram_full (writes PAL0+PAL1 only)"
```

### Task 2.4: Add verify_bg_palette_manifest verifier

**Files:**
- Create: `RoomRom/tools/verify_bg_palette_manifest.py`

- [ ] **Step 1: Write the verifier**

Create `RoomRom/tools/verify_bg_palette_manifest.py`:

```python
"""Hard gate: BG palette manifests + generated header shape.

Exit code 0 = pass, 1 = fail.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INPUTS = [
    ("orig",  ROOT / "out" / "nes_bg_palette_manifest_orig.json"),
    ("redux", ROOT / "out" / "nes_bg_palette_manifest_redux.json"),
]
HEADER = ROOT / "src" / "roomrom_ow_palette.h"
SOURCE = ROOT / "src" / "roomrom_ow_palette.c"

def fail(msg):
    print(f"verify_bg_palette_manifest: FAIL: {msg}", file=sys.stderr)
    sys.exit(1)

def check_manifest(label, path):
    if not path.exists():
        fail(f"missing {path}")
    data = json.loads(path.read_text(encoding="utf-8"))
    entries = data.get("entries", [])
    if len(entries) != 128:
        fail(f"{label}: expected 128 entries, got {len(entries)}")
    seen = set()
    for e in entries:
        rid = e["room_id"]
        pr  = e["palram"]
        if rid in seen:
            fail(f"{label}: duplicate room_id 0x{rid:02X}")
        seen.add(rid)
        if len(pr) != 32:
            fail(f"{label}: room 0x{rid:02X} palram len {len(pr)} != 32")
        if pr[0] != 0x0F:
            fail(f"{label}: room 0x{rid:02X} palram[0]=0x{pr[0]:02X} != 0x0F")
        if all(b == 0 for b in pr):
            fail(f"{label}: room 0x{rid:02X} all-zero palram (capture invalid)")

def check_header():
    if not HEADER.exists():
        fail(f"missing {HEADER}")
    text = HEADER.read_text(encoding="utf-8")
    if not re.search(r"g_roomrom_ow_palram\[2\]\[128\]\[32\]", text):
        fail("header shape != [2][128][32]")
    if not SOURCE.exists():
        fail(f"missing {SOURCE}")

def main():
    for label, path in INPUTS:
        check_manifest(label, path)
    check_header()
    print("verify_bg_palette_manifest: OK")

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run verifier**

Run: `python RoomRom\tools\verify_bg_palette_manifest.py`

Expected: `OK`. If FAIL, fix the underlying capture or generator and re-run.

- [ ] **Step 3: Commit**

```bash
git add RoomRom/tools/verify_bg_palette_manifest.py
git commit -m "roomrom: add BG palette manifest verifier gate"
```

---

## Phase 2.5 — VRAM Layout Definition

Phase 2.5 is a pure refactor. Audit current per-scene tile usage, commit concrete numeric VRAM constants in a single header, then relocate sprite + HUD bases to derive from those constants. No expansion, no slot-map cutover.

### Task 2.5.1: Build the VRAM tile audit reporter

**Files:**
- Create: `RoomRom/tools/audit_vram_tile_usage.py`

- [ ] **Step 1: Write the auditor**

Create `RoomRom/tools/audit_vram_tile_usage.py`:

```python
"""Per-scene VRAM tile-usage auditor for RoomRom (pre-expansion baseline).

Reports current tile counts per category. Used to commit concrete numeric
VRAM constants in roomrom_vram_map.h before Phase 3 expansion.

Categories:
  BG bank inputs (post-expansion will be x4):
    - common_chr BG section          (COMMON_BG_TILE_COUNT)
    - overworld_bg_chr               (OW_BG_TILE_COUNT)
    - underworld_bg_chr              (UW_BG_TILE_COUNT)
    - redux_overworld_bg_chr         (REDUX_OW_BG_TILE_COUNT)
    - redux_overworld_secret_chr     (12)
    - redux_uw_bg_chr (256 tiles)    (256)
    - redux_automap_chr              (32)
    - common_chr misc section        (14)
    - HUD custom 3 tiles             (3)

  SPR bank inputs (post-expansion will be x4):
    - sprites_chr                    (232)
    - common_chr sprite section      (112)
    - Link walk + attack poses       (32 + 16)
    - item atlas tiles               (from roomrom_item_chr.h)

Sums per scene:
  OW orig          = BG common + OW + redux automap + HUD custom + SPR set
  OW redux         = BG common + redux OW + redux secret + redux automap + HUD + SPR
  UW orig          = BG common + UW + HUD + SPR
  UW redux         = BG common + redux UW + HUD + SPR
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

CONSTS = {
    "COMMON_BG_TILE_COUNT":       112,
    "OW_BG_TILE_COUNT":           130,
    "UW_BG_TILE_COUNT":           130,
    "COMMON_MISC_TILE_COUNT":     14,
    "REDUX_AUTOMAP_TILE_COUNT":   32,
    "REDUX_SECRET_TILE_COUNT":    12,
    "REDUX_UW_TILE_COUNT":        256,
    "SPRITE_BLOCK_TILE_COUNT":    232,
    "COMMON_BLOCK_TILE_COUNT":    238,  # full common_chr block including sprite half
    "LINK_WALK_TILE_COUNT":       32,
    "LINK_ATTACK_TILE_COUNT":     16,
    "HUD_CUSTOM_TILE_COUNT":      3,
}

def get_item_atlas_tiles():
    h = (ROOT / "src" / "roomrom_item_chr.h").read_text(encoding="utf-8")
    m = re.search(r"roomrom_item_chr_byte_count\s*=\s*(\d+)", h)
    if m:
        return int(m.group(1)) // 32
    # Fallback: parse byte_count from .c
    c = (ROOT / "src" / "roomrom_item_chr.c").read_text(encoding="utf-8")
    m = re.search(r"roomrom_item_chr_byte_count\s*=\s*(\d+)", c)
    if m:
        return int(m.group(1)) // 32
    return 0

def main():
    item_tiles = get_item_atlas_tiles()
    print(f"item atlas tiles: {item_tiles}")

    bg_ow_orig = (CONSTS["COMMON_BG_TILE_COUNT"]
                  + CONSTS["OW_BG_TILE_COUNT"]
                  + CONSTS["COMMON_MISC_TILE_COUNT"]
                  + CONSTS["REDUX_AUTOMAP_TILE_COUNT"]
                  + CONSTS["HUD_CUSTOM_TILE_COUNT"])
    bg_ow_redux = bg_ow_orig + CONSTS["REDUX_SECRET_TILE_COUNT"]
    bg_uw_orig = (CONSTS["COMMON_BG_TILE_COUNT"]
                  + CONSTS["UW_BG_TILE_COUNT"]
                  + CONSTS["COMMON_MISC_TILE_COUNT"]
                  + CONSTS["HUD_CUSTOM_TILE_COUNT"])
    bg_uw_redux = (CONSTS["REDUX_UW_TILE_COUNT"]
                   + CONSTS["HUD_CUSTOM_TILE_COUNT"])
    bg_max = max(bg_ow_orig, bg_ow_redux, bg_uw_orig, bg_uw_redux)
    print(f"BG tiles per scene: ow_orig={bg_ow_orig} ow_redux={bg_ow_redux} "
          f"uw_orig={bg_uw_orig} uw_redux={bg_uw_redux} max={bg_max}")

    spr_total = (CONSTS["SPRITE_BLOCK_TILE_COUNT"]
                 + CONSTS["COMMON_BLOCK_TILE_COUNT"]
                 + CONSTS["LINK_WALK_TILE_COUNT"]
                 + CONSTS["LINK_ATTACK_TILE_COUNT"]
                 + item_tiles)
    print(f"SPR tiles total: {spr_total}")

    bg_x4 = bg_max * 4
    spr_x4 = spr_total * 4
    print(f"After 4x expansion: BG={bg_x4} SPR={spr_x4} sum={bg_x4 + spr_x4}")
    print(f"Genesis 4bpp tile budget: 2048 (64KB / 32B)")

    if bg_x4 + spr_x4 > 2048:
        print("WARNING: 4x expansion exceeds VRAM budget — per-scene residency required",
              file=sys.stderr)

    # Suggested concrete constants:
    suggested_bg_per_pal = bg_max
    suggested_spr_per_pal = spr_total
    suggested_bg_base = 1
    suggested_spr_base = suggested_bg_base + 4 * suggested_bg_per_pal
    print()
    print("Suggested roomrom_vram_map.h constants:")
    print(f"  ROOMROM_BG_TILE_BASE          = {suggested_bg_base}")
    print(f"  ROOMROM_BG_TILE_COUNT_PER_PAL = {suggested_bg_per_pal}")
    print(f"  ROOMROM_SPR_TILE_BASE         = {suggested_spr_base}")
    print(f"  ROOMROM_SPR_TILE_COUNT_PER_PAL= {suggested_spr_per_pal}")
    print(f"  Total VRAM tiles used         = {suggested_spr_base + 4 * suggested_spr_per_pal - 1}")

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run audit**

Run: `python RoomRom\tools\audit_vram_tile_usage.py`

Expected: prints concrete suggested constants. Save the output for the next task — these become the values committed in `roomrom_vram_map.h`.

- [ ] **Step 3: If audit warns budget exceeded**

If 4x expansion warns budget overrun, options:
- Reduce per-scene BG by trimming unused redux assets in this header (per-scene residency).
- Document the overage; Phase 3 will use per-scene residency mode.

For Phase 2.5: take the audit numbers as-is. The plan downstream may load less than full 4x at runtime; the VRAM map sizes the bank for the worst-case scene.

- [ ] **Step 4: Commit auditor**

```bash
git add RoomRom/tools/audit_vram_tile_usage.py
git commit -m "roomrom: add VRAM tile-usage auditor"
```

### Task 2.5.2: Commit roomrom_vram_map.h with concrete values

**Files:**
- Create: `RoomRom/src/roomrom_vram_map.h`

- [ ] **Step 1: Capture audit numbers**

Run audit again, copy concrete numbers from "Suggested" block. Variables below — substitute with actual audit output:

- `BG_PER_PAL` ← audit's `ROOMROM_BG_TILE_COUNT_PER_PAL`
- `SPR_PER_PAL` ← audit's `ROOMROM_SPR_TILE_COUNT_PER_PAL`
- `SPR_BASE` ← `1 + 4 * BG_PER_PAL`

- [ ] **Step 2: Write header with concrete values**

Create `RoomRom/src/roomrom_vram_map.h` (replace `<BG_PER_PAL>`, `<SPR_BASE>`, `<SPR_PER_PAL>` with the audit numbers):

```c
#ifndef ROOMROM_VRAM_MAP_H
#define ROOMROM_VRAM_MAP_H

/* RoomRom VRAM tile map — single source of truth.
 *
 * VRAM tile 0 reserved as blank (transparent + bounds-check fallback).
 *
 * BG bank: NES BG + HUD tiles. Stride per sub-pal = ROOMROM_BG_TILE_COUNT_PER_PAL.
 * Sub-pal s tile lives at ROOMROM_BG_TILE_BASE + s * ROOMROM_BG_TILE_COUNT_PER_PAL + nes_tile_id.
 *
 * SPR bank: Link, sword, items, etc. Stride per sub-pal = ROOMROM_SPR_TILE_COUNT_PER_PAL.
 *
 * Concrete numeric values were committed after running
 * RoomRom/tools/audit_vram_tile_usage.py against the current trees
 * (Phase 2.5 baseline). Re-run the auditor + bump these constants if
 * scene tile counts grow.
 */

#define ROOMROM_BG_TILE_BASE            1u
#define ROOMROM_BG_TILE_COUNT_PER_PAL   <BG_PER_PAL>u
#define ROOMROM_SPR_TILE_BASE           <SPR_BASE>u
#define ROOMROM_SPR_TILE_COUNT_PER_PAL  <SPR_PER_PAL>u

/* Pre-expansion (Phase 2.5) layout uses sub-pal 0 only. Phase 3 unlocks 1..3. */
#define ROOMROM_BG_TILE_BASE_PAL(s)  \
    (ROOMROM_BG_TILE_BASE  + (unsigned short)(s) * ROOMROM_BG_TILE_COUNT_PER_PAL)
#define ROOMROM_SPR_TILE_BASE_PAL(s) \
    (ROOMROM_SPR_TILE_BASE + (unsigned short)(s) * ROOMROM_SPR_TILE_COUNT_PER_PAL)

#endif
```

- [ ] **Step 3: Compile-only check**

Run: `RoomRom\build.bat`

Expected: header alone doesn't break build (no consumers yet).

- [ ] **Step 4: Commit**

```bash
git add RoomRom/src/roomrom_vram_map.h
git commit -m "roomrom: define VRAM map (Phase 2.5 baseline; pre-expansion)"
```

### Task 2.5.3: Relocate sprite + HUD bases to derive from VRAM map

**Files:**
- Modify: `RoomRom/src/roomrom_sprites.c`
- Modify: `RoomRom/src/roomrom_hud.c`
- Modify: `RoomRom/src/roomrom_combat.c`
- Modify: `RoomRom/src/roomrom_arrow.c`, `RoomRom/src/roomrom_bomb.c`, `RoomRom/src/roomrom_boomerang.c`

- [ ] **Step 1: Sprites.c — derive sprite bases**

Edit `RoomRom/src/roomrom_sprites.c`. Add `#include "roomrom_vram_map.h"` after existing includes. Replace:

```c
#define SPRITE_VRAM_TILE_BASE   512u
#define COMMON_VRAM_TILE_BASE   936u
```

with:

```c
#define SPRITE_VRAM_TILE_BASE   ROOMROM_SPR_TILE_BASE
#define COMMON_VRAM_TILE_BASE   (ROOMROM_SPR_TILE_BASE + SPRITE_BLOCK_TILE_COUNT)
```

(Keeps the same relative layout: sprites_chr first, then common_chr, then Link, then items.)

- [ ] **Step 2: HUD.c — derive HUD base**

Edit `RoomRom/src/roomrom_hud.c`. Add `#include "roomrom_vram_map.h"`. Replace:

```c
#define HUD_TILE_BASE   1u
```

with:

```c
#define HUD_TILE_BASE   ROOMROM_BG_TILE_BASE
```

- [ ] **Step 3: combat / arrow / bomb / boomerang — same pattern**

For each of `RoomRom/src/roomrom_combat.c`, `roomrom_arrow.c`, `roomrom_bomb.c`, `roomrom_boomerang.c`: add `#include "roomrom_vram_map.h"`. Audit any hard-coded tile-base literals (e.g. `512u`, `936u`) and replace with `ROOMROM_SPR_TILE_BASE` or derived expressions.

For files that derive everything via macros from sprites.h / sprites.c constants, no change needed beyond the include.

- [ ] **Step 4: Build**

Run: `RoomRom\build.bat`

Expected: compiles. ROM size unchanged. No literal `512u`/`936u`/`1u` for tile bases remaining (search for stragglers):

Run: `grep -nE "(\b512u\b|\b936u\b)" RoomRom/src/roomrom_*.c`

Expected: empty (or only comment hits).

- [ ] **Step 5: Emu smoke (pre-expansion)**

Boot RoomRom. Confirm OW + UW render unchanged from end of Phase 1. HUD position correct, sword/items render correct ART.

- [ ] **Step 6: Commit**

```bash
git add RoomRom/src/roomrom_sprites.c RoomRom/src/roomrom_hud.c RoomRom/src/roomrom_combat.c RoomRom/src/roomrom_arrow.c RoomRom/src/roomrom_bomb.c RoomRom/src/roomrom_boomerang.c
git commit -m "roomrom: derive sprite + HUD bases from roomrom_vram_map.h"
```

### Task 2.5.4: Write verify_vram_budget verifier

**Files:**
- Create: `RoomRom/tools/verify_vram_budget.py`

- [ ] **Step 1: Identify VDP table addresses from SGDK config**

Read `sgdk/inc/vdp.h` or equivalent. Note the VRAM addresses for plane-A nametable, plane-B nametable, Window nametable, SAT, H-scroll table. SGDK defaults (confirm against actual config):

- Plane A: `0xC000`
- Plane B: `0xE000`
- Window: `0xB000`
- SAT: `0xBC00`
- H-scroll: `0xB800`

Each is a fixed VRAM byte address. Convert to tile index by `addr / 32`.

- [ ] **Step 2: Write verifier**

Create `RoomRom/tools/verify_vram_budget.py`:

```python
"""Hard gate: VRAM tile-bank ranges do not overlap each other or VDP tables.

Reads constants from RoomRom/src/roomrom_vram_map.h.
Reads VDP layout from SGDK config (or hardcoded defaults if unavailable).

Exit code 0 = pass, 1 = fail.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VRAM_MAP_H = ROOT / "src" / "roomrom_vram_map.h"

# Default SGDK VRAM layout (bytes -> tiles by /32). Override via env if needed.
VDP_TABLES = {
    "plane_a":  (0xC000, 0xC000 + 0x2000),
    "plane_b":  (0xE000, 0xE000 + 0x2000),
    "window":   (0xB000, 0xB000 + 0x0800),
    "h_scroll": (0xB800, 0xB800 + 0x0400),
    "sat":      (0xBC00, 0xBC00 + 0x0280),
}

def fail(msg):
    print(f"verify_vram_budget: FAIL: {msg}", file=sys.stderr)
    sys.exit(1)

def parse_constants():
    text = VRAM_MAP_H.read_text(encoding="utf-8")
    consts = {}
    for name in ("ROOMROM_BG_TILE_BASE",
                 "ROOMROM_BG_TILE_COUNT_PER_PAL",
                 "ROOMROM_SPR_TILE_BASE",
                 "ROOMROM_SPR_TILE_COUNT_PER_PAL"):
        m = re.search(rf"#define\s+{name}\s+(\d+)u", text)
        if not m:
            fail(f"missing {name} in {VRAM_MAP_H}")
        consts[name] = int(m.group(1))
    return consts

def tile_range_bytes(base_tile, tile_count):
    start = base_tile * 32
    end = (base_tile + tile_count) * 32
    return (start, end)

def overlaps(a, b):
    return not (a[1] <= b[0] or b[1] <= a[0])

def main():
    c = parse_constants()
    bg_range  = tile_range_bytes(c["ROOMROM_BG_TILE_BASE"],
                                  4 * c["ROOMROM_BG_TILE_COUNT_PER_PAL"])
    spr_range = tile_range_bytes(c["ROOMROM_SPR_TILE_BASE"],
                                  4 * c["ROOMROM_SPR_TILE_COUNT_PER_PAL"])

    if c["ROOMROM_SPR_TILE_BASE"] < c["ROOMROM_BG_TILE_BASE"] + 4 * c["ROOMROM_BG_TILE_COUNT_PER_PAL"]:
        fail("SPR base overlaps BG bank — sprite tiles would clobber BG copies")

    if overlaps(bg_range, spr_range):
        fail(f"BG range {bg_range} overlaps SPR range {spr_range}")

    for name, vdp_range in VDP_TABLES.items():
        if overlaps(bg_range, vdp_range):
            fail(f"BG range {bg_range} collides with VDP {name} {vdp_range}")
        if overlaps(spr_range, vdp_range):
            fail(f"SPR range {spr_range} collides with VDP {name} {vdp_range}")

    if spr_range[1] > 0x10000:
        fail(f"SPR range end 0x{spr_range[1]:X} exceeds 64KB VRAM")

    print(f"verify_vram_budget: OK  BG={bg_range} SPR={spr_range}")

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run verifier**

Run: `python RoomRom\tools\verify_vram_budget.py`

Expected: `OK`. If FAIL with VDP collision, the audit-suggested SPR base or sizes need revision — bump base or shrink banks and update `roomrom_vram_map.h`.

- [ ] **Step 3: Commit**

```bash
git add RoomRom/tools/verify_vram_budget.py
git commit -m "roomrom: add VRAM budget verifier (range non-overlap vs VDP tables)"
```

### Task 2.5.5: Phase 2.5 acceptance

- [ ] **Step 1: Full build**

Run: `RoomRom\build.bat`. Expected: builds clean.

- [ ] **Step 2: All verifiers green**

```powershell
python RoomRom\tools\verify_item_chr_manifest.py
python RoomRom\tools\verify_bg_palette_manifest.py
python RoomRom\tools\verify_vram_budget.py
```

Expected: all `OK`.

- [ ] **Step 3: Emu smoke**

Boot RoomRom. Verify OW + UW + items still render at end-of-Phase-1 quality. Phase 2.5 is a refactor — no visible change.

- [ ] **Step 4: Tag**

```bash
git tag roomrom-phase2-5-vram-map
```

---

## Phase 3 — CHR Expansion (BG + Sprite)

Phase 3 generates 4 pixel-biased copies per NES tile. Locked numeric VRAM map from Phase 2.5 sizes the banks. Renderer cutover happens in Phase 4 — Phase 3 only emits the new tile data.

### Task 3.1: Write expand_bg_chr.py with input assertions

**Files:**
- Create: `RoomRom/tools/expand_bg_chr.py`
- Create (output): `RoomRom/data/expanded/*.bin`

- [ ] **Step 1: Write expander**

Create `RoomRom/tools/expand_bg_chr.py`:

```python
"""Expand BG CHR bins to 4 pixel-biased Genesis 4bpp tile copies.

Per-pixel rule: out_pixel = (in_pixel == 0) ? 0 : (s * 4 + in_pixel)
where s in {0..3} is the sub-pal index.

Input assertion: source nibbles must be in {0..3}. The script aborts if any
input pixel is >= 4 (means the source is already biased — never re-bias).

Output layout per input file:
    <base>_pal0.bin (s=0; identical to input for sanity)
    <base>_pal1.bin (s=1)
    <base>_pal2.bin (s=2)
    <base>_pal3.bin (s=3)

For Phase 3 use the concatenated single-file output:
    <base>_x4.bin = pal0 || pal1 || pal2 || pal3
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INPUTS = [
    ROOT / "data" / "chr" / "common.bin",            # has BG section
    ROOT / "data" / "chr" / "overworld_bg.bin",
    ROOT / "data" / "chr" / "underworld_bg.bin",
    ROOT / "data" / "chr" / "redux_overworld_bg.bin",
    ROOT / "data" / "chr" / "redux_uw_bg.bin",
]
OUT_DIR = ROOT / "data" / "expanded"

def assert_unbiased(buf, label):
    """Source must use pixel values 0..3 only (NES 2bpp range)."""
    for i, byte in enumerate(buf):
        hi = (byte >> 4) & 0x0F
        lo = byte & 0x0F
        if hi > 3 or lo > 3:
            raise SystemExit(
                f"{label}: byte {i} = 0x{byte:02X} contains pixel value > 3 "
                f"(hi={hi}, lo={lo}). Refusing to re-bias an already-biased "
                f"input. Inputs must be raw NES 2bpp expanded to 4bpp.")

def bias_byte(b, s):
    hi = (b >> 4) & 0x0F
    lo = b & 0x0F
    hi_out = 0 if hi == 0 else (s * 4 + hi)
    lo_out = 0 if lo == 0 else (s * 4 + lo)
    return ((hi_out & 0x0F) << 4) | (lo_out & 0x0F)

def expand(src):
    out = []
    for s in range(4):
        out.append(bytes(bias_byte(b, s) for b in src))
    return out

def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for path in INPUTS:
        if not path.exists():
            print(f"warn: missing {path}, skipping", file=sys.stderr)
            continue
        buf = path.read_bytes()
        assert_unbiased(buf, path.name)
        copies = expand(buf)
        base = path.stem
        for s, c in enumerate(copies):
            (OUT_DIR / f"{base}_pal{s}.bin").write_bytes(c)
        cat = b"".join(copies)
        (OUT_DIR / f"{base}_x4.bin").write_bytes(cat)
        print(f"{path.name}: {len(buf)}B -> {len(cat)}B (4x)")

if __name__ == "__main__":
    main()
```

(Note: The actual paths under `data/chr/` may differ — RoomRom may use `data/chr/common.c` baked-in arrays. If the source CHR is C arrays, not raw bins, write a sister extractor that runs `gcc -E` or hand-parses the C array first. Adjust input paths to wherever the unbiased source lives.)

- [ ] **Step 2: Run expander**

Run: `python RoomRom\tools\expand_bg_chr.py`

Expected: writes `*_x4.bin` files under `RoomRom/data/expanded/`. Print confirms 4x size for each.

If FAIL with "pixel value > 3", the input is already biased OR uses Genesis 4bpp colors > 3 organically (impossible for CHR converted from NES 2bpp). Investigate the input source.

- [ ] **Step 3: Commit**

```bash
git add RoomRom/tools/expand_bg_chr.py RoomRom/data/expanded/
git commit -m "roomrom: expand BG CHR to 4 pixel-biased copies (PAL0 packing)"
```

### Task 3.2: Write expand_sprite_chr.py with same rule

**Files:**
- Create: `RoomRom/tools/expand_sprite_chr.py`
- Create (output): `RoomRom/data/expanded/sprite_*_x4.bin`

- [ ] **Step 1: Write expander**

Create `RoomRom/tools/expand_sprite_chr.py`:

```python
"""Expand sprite CHR (Link, item atlas, sprites_chr enemies) to 4 sub-pal copies.

Same rule as BG: out_pixel = (in_pixel == 0) ? 0 : (s * 4 + in_pixel).
Same input assertion: nibbles must be 0..3.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INPUTS = [
    ROOT / "data" / "chr" / "sprites.bin",
    ROOT / "data" / "chr" / "common.bin",          # sprite half (Link, sword, hearts)
    ROOT / "out" / "nes_item_chr_pt0_orig.bin",
    ROOT / "out" / "nes_item_chr_pt0_redux.bin",
]
OUT_DIR = ROOT / "data" / "expanded"

def assert_unbiased(buf, label):
    for i, byte in enumerate(buf):
        hi = (byte >> 4) & 0x0F
        lo = byte & 0x0F
        if hi > 3 or lo > 3:
            raise SystemExit(f"{label}: byte {i} = 0x{byte:02X} pixel > 3")

def bias_byte(b, s):
    hi = (b >> 4) & 0x0F
    lo = b & 0x0F
    return (((0 if hi == 0 else s*4+hi) & 0x0F) << 4) | \
           ((0 if lo == 0 else s*4+lo) & 0x0F)

def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for path in INPUTS:
        if not path.exists():
            print(f"warn: missing {path}, skipping", file=sys.stderr)
            continue
        buf = path.read_bytes()
        # Item CHR pt0 dump is 4096B NES 2bpp. Convert to 4bpp first.
        if path.suffix == ".bin" and "item_chr_pt0" in path.name:
            buf = nes_2bpp_to_4bpp(buf)
        assert_unbiased(buf, path.name)
        cat = b""
        for s in range(4):
            cat += bytes(bias_byte(b, s) for b in buf)
        out = OUT_DIR / f"sprite_{path.stem}_x4.bin"
        out.write_bytes(cat)
        print(f"{path.name}: {len(buf)}B -> {len(cat)}B (4x)")

def nes_2bpp_to_4bpp(buf):
    """Convert NES 2bpp tile data (16B/tile) to Genesis 4bpp (32B/tile)
    with pixel values 0..3 only (no sub-pal bias yet)."""
    out = bytearray()
    for tile_off in range(0, len(buf), 16):
        plane0 = buf[tile_off : tile_off + 8]
        plane1 = buf[tile_off + 8 : tile_off + 16]
        for row in range(8):
            p0 = plane0[row]
            p1 = plane1[row]
            for col_pair in range(4):
                hi_bit = 7 - col_pair * 2
                lo_bit = hi_bit - 1
                hi_pix = ((p0 >> hi_bit) & 1) | (((p1 >> hi_bit) & 1) << 1)
                lo_pix = ((p0 >> lo_bit) & 1) | (((p1 >> lo_bit) & 1) << 1)
                out.append(((hi_pix & 0x0F) << 4) | (lo_pix & 0x0F))
    return bytes(out)

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run expander**

Run: `python RoomRom\tools\expand_sprite_chr.py`

Expected: writes `sprite_*_x4.bin` files. Print confirms 4x size.

- [ ] **Step 3: Spot-check first tile pal0**

Read first 32 bytes of `RoomRom/data/expanded/sprite_common_x4.bin`. Confirm bytes are identical to the input common BG section's first 32 bytes (s=0 copy is unchanged).

Read bytes 32..63 of the same file (start of pal1 copy). Confirm they differ — pal1 biases nonzero pixels by +4.

- [ ] **Step 4: Commit**

```bash
git add RoomRom/tools/expand_sprite_chr.py RoomRom/data/expanded/sprite_*_x4.bin
git commit -m "roomrom: expand sprite CHR to 4 pixel-biased copies (PAL1 packing)"
```

### Task 3.3: Add sub-pal tile-base macros

**Files:**
- Modify: `RoomRom/src/roomrom_vram_map.h` (extend with `_PAL(s)` macros if not already there)
- Modify: `RoomRom/src/ow_room_render_roomrom.c`
- Modify: `RoomRom/src/uw_room_render_roomrom.c`
- Modify: `RoomRom/src/roomrom_sprites.c`
- Modify: `RoomRom/src/roomrom_hud.c`

- [ ] **Step 1: Confirm `_PAL(s)` macros exist**

Read `RoomRom/src/roomrom_vram_map.h`. Confirm `ROOMROM_BG_TILE_BASE_PAL(s)` and `ROOMROM_SPR_TILE_BASE_PAL(s)` are defined (added in Task 2.5.2). If not, add them.

- [ ] **Step 2: Add specific aliases for renderer call sites**

Edit `RoomRom/src/ow_room_render_roomrom.c`. Replace:

```c
#define OW_VDP_TILE_BASE          1u
```

with:

```c
#include "roomrom_vram_map.h"
#define OW_VDP_TILE_BASE_PAL(s) ROOMROM_BG_TILE_BASE_PAL(s)
```

Same in `uw_room_render_roomrom.c`:

```c
#include "roomrom_vram_map.h"
#define UW_VDP_TILE_BASE_PAL(s) ROOMROM_BG_TILE_BASE_PAL(s)
```

In `roomrom_hud.c`:

```c
#define HUD_TILE_BASE_PAL(s) ROOMROM_BG_TILE_BASE_PAL(s)
```

In `roomrom_sprites.c`:

```c
#define LINK_VRAM_TILE_PAL(s) (ROOMROM_SPR_TILE_BASE_PAL(s) + (LINK_VRAM_TILE - ROOMROM_SPR_TILE_BASE))
#define ITEM_VRAM_TILE_PAL(s) (ROOMROM_SPR_TILE_BASE_PAL(s) + (ITEM_VRAM_TILE - ROOMROM_SPR_TILE_BASE))
/* Add similar _PAL aliases for SWORD_VERT, SWORD_HORZ, BOOMERANG, ARROW_VERT,
 * ARROW_HORZ, BOMB, EXPLOSION VRAM tile macros. */
```

- [ ] **Step 3: Build (no callsite changes yet)**

Run: `RoomRom\build.bat`

Expected: builds clean. New macros declared but unused. Original `OW_VDP_TILE_BASE` etc still callable for now.

- [ ] **Step 4: Commit**

```bash
git add RoomRom/src/roomrom_vram_map.h RoomRom/src/ow_room_render_roomrom.c RoomRom/src/uw_room_render_roomrom.c RoomRom/src/roomrom_hud.c RoomRom/src/roomrom_sprites.c
git commit -m "roomrom: add per-sub-pal tile-base macros"
```

### Task 3.4: Switch CHR uploader to write 4 banks

**Files:**
- Modify: `RoomRom/src/ow_room_render_roomrom.c` (`roomrom_ow_room_render_upload_chr`)
- Modify: `RoomRom/src/uw_room_render_roomrom.c` (`roomrom_uw_room_render_upload_chr`)
- Modify: `RoomRom/src/roomrom_sprites.c` (`roomrom_sprites_upload_chr`)
- Modify: `RoomRom/src/roomrom_hud.c` (HUD CHR upload)

- [ ] **Step 1: OW upload — 4 banks**

Edit `roomrom_ow_room_render_upload_chr`. Replace each `render_chr_upload(... ow_chr ...)` call with a loop over `s = 0..3`, uploading the corresponding pal-`s` bank from `RoomRom/data/expanded/`:

```c
extern const unsigned char ow_bg_chr_x4[];        /* bound at link */
extern const unsigned short ow_bg_chr_x4_byte_count;

void roomrom_ow_room_render_upload_chr(void)
{
    unsigned char s;
    unsigned short per_pal = OW_BG_TILE_COUNT * 32u;
    for (s = 0; s < 4; s++) {
        render_chr_upload(
            (unsigned short)(OW_VDP_TILE_BASE_PAL(s) * 32u),
            ow_bg_chr_x4 + s * per_pal,
            per_pal);
    }
    /* Same loop pattern for redux_overworld_bg_chr_x4, redux_automap (if it
     * also gets expansion), and the common BG section. */
}
```

The expanded `*_x4.bin` files should be linked as C arrays (write a small `.c` wrapper for each, or `.incbin` from inside an existing `.s` if vasm is in scope — but RoomRom uses pure SGDK C, so use a generator: `tools/embed_expanded_bins.py` that writes `RoomRom/src/expanded_chr.c` with arrays for each).

- [ ] **Step 2: UW upload — same pattern**

Same shape in `roomrom_uw_room_render_upload_chr`. Loop 4 banks of `underworld_bg_chr_x4` + redux variant.

- [ ] **Step 3: Sprites upload — 4 banks**

In `roomrom_sprites_upload_chr`, replace single uploads of `sprites_chr` and `common_chr` with 4-pass loop using the expanded arrays. Same for the item atlas (now upload from `roomrom_item_chr_x4`).

- [ ] **Step 4: HUD custom tiles — 4 banks**

In `roomrom_hud.c`, the custom 96-byte tile array (`s_hud_custom_chr`) is currently single-copy. Pre-bias at compile time: change the array literal so each tile appears 4 times (s=0,1,2,3 copies), or call the runtime expander once at boot. Simpler: write a Python step that emits `s_hud_custom_chr_x4` directly.

For now, hand-expand by replacing the 96-byte array with a 384-byte array containing the 4 copies. Use the expander script offline.

- [ ] **Step 5: Build**

Run: `RoomRom\build.bat`

Expected: ROM grows by ~3x BG CHR + ~3x sprite CHR. New ROM size noted.

- [ ] **Step 6: Commit**

```bash
git add RoomRom/src/ow_room_render_roomrom.c RoomRom/src/uw_room_render_roomrom.c RoomRom/src/roomrom_sprites.c RoomRom/src/roomrom_hud.c RoomRom/src/expanded_chr.c
git commit -m "roomrom: upload 4 sub-pal CHR banks per scene"
```

### Task 3.5: Phase 3 acceptance

- [ ] **Step 1: Verifiers**

```powershell
python RoomRom\tools\verify_item_chr_manifest.py
python RoomRom\tools\verify_bg_palette_manifest.py
python RoomRom\tools\verify_vram_budget.py
```

Expected: all `OK`.

- [ ] **Step 2: Build**

Run: `RoomRom\build.bat`. Expected: builds clean.

- [ ] **Step 3: Emu smoke**

Boot RoomRom. Confirm scene STILL renders correctly (sub-pal 0 only path is what's exercised pre-cutover). Phase 3 changes upload but renderer still references sub-pal 0 base — visual baseline unchanged.

- [ ] **Step 4: Tag**

```bash
git tag roomrom-phase3-chr-expansion
```

---

## Phase 4 — Renderer Wiring + Slot-Map Cutover

Phase 4 activates Phase 2 PALRAM data + Phase 3 CHR banks. Includes HUD/Window cutover.

### Task 4.1: HUD slot-map cutover

**Files:**
- Modify: `RoomRom/src/roomrom_hud.c`

- [ ] **Step 1: Replace `hud_word`**

Edit `RoomRom/src/roomrom_hud.c`. Replace:

```c
static unsigned short hud_word(unsigned char raw_tile, unsigned char pal)
{
    return (unsigned short)(((unsigned short)(pal & 0x03) << 13) |
                            ((unsigned short)raw_tile + HUD_TILE_BASE));
}
```

with:

```c
static unsigned short hud_word(unsigned char raw_tile, unsigned char sub_pal)
{
    /* HUD is NES BG content. Tile word selects which sub-pal copy via tile
     * index; Genesis pal-slot bits stay 0 (PAL0). */
    return (unsigned short)(HUD_TILE_BASE_PAL(sub_pal & 0x03)
                            + (unsigned short)raw_tile);
}
```

- [ ] **Step 2: Build + smoke**

Run: `RoomRom\build.bat`. Boot RoomRom. Confirm HUD renders with NES colors (hearts red, map gray, "-LIFE-" text correct).

- [ ] **Step 3: Commit**

```bash
git add RoomRom/src/roomrom_hud.c
git commit -m "roomrom: HUD tile word uses HUD_TILE_BASE_PAL(s) (PAL0 always)"
```

### Task 4.2: OW palette loader → live PALRAM

**Files:**
- Modify: `RoomRom/src/ow_room_render_roomrom.c`

- [ ] **Step 1: Add includes**

Edit `RoomRom/src/ow_room_render_roomrom.c`. Add at top:

```c
#include "roomrom_bg_palette.h"
#include "roomrom_ow_palette.h"
```

Drop the local `nes_color_to_cram` function — replaced by central converter.

- [ ] **Step 2: Replace loader body**

Replace `roomrom_ow_room_render_load_palette` body with:

```c
void roomrom_ow_room_render_load_palette(unsigned char room_id)
{
    unsigned char map = (s_roomrom_map_id == ROOMROM_MAP_REDUX) ? 1u : 0u;
    const unsigned char *p = g_roomrom_ow_palram[map][room_id & 0x7F];
    roomrom_bg_palette_load_palram_full(p);
}
```

- [ ] **Step 3: Build + smoke**

Run: `RoomRom\build.bat`. Boot OW. Confirm color is correct for OW screen 0x77 + at least one redux OW screen.

- [ ] **Step 4: Commit**

```bash
git add RoomRom/src/ow_room_render_roomrom.c
git commit -m "roomrom: OW palette loader pulls live NES PALRAM (PAL0+PAL1)"
```

### Task 4.3: UW palette loader → shared loader

**Files:**
- Modify: `RoomRom/src/uw_room_render_roomrom.c`

- [ ] **Step 1: Add include + drop local converter**

Edit `RoomRom/src/uw_room_render_roomrom.c`. Add `#include "roomrom_bg_palette.h"`. Drop local `nes_color_to_cram`.

- [ ] **Step 2: Replace `load_palette_from_blob`**

```c
static void load_palette_from_blob(int idx)
{
    roomrom_bg_palette_load_palram_full(g_uw_room_palette[idx]);
}
```

- [ ] **Step 3: Replace `load_palette_from_levelinfo`**

```c
static void load_palette_from_levelinfo(void)
{
    unsigned char buf[16];
    unsigned char i;
    unsigned short level_off = (unsigned short)(UW_LEVELINFO_BASE +
        ((unsigned short)(s_uw_level - 1u) * UW_LEVELINFO_SIZE) +
        UW_LEVELINFO_PAL_OFFSET);
    for (i = 0; i < 16; i++) {
        buf[i] = rooms_dungeons[level_off + i];
    }
    roomrom_bg_palette_load_bg_only(buf);
    /* Sprite half (PAL1) preserved from prior room load. */
}
```

- [ ] **Step 4: Build + smoke**

Run: `RoomRom\build.bat`. Boot UW L1. Confirm BG-pal-3 tiles (statues, doors) now render with NES BG-pal-3 colors instead of sword colors.

- [ ] **Step 5: Commit**

```bash
git add RoomRom/src/uw_room_render_roomrom.c
git commit -m "roomrom: UW palette loaders use shared loader (PAL0+PAL1)"
```

### Task 4.4: OW + UW tile-word cutover

**Files:**
- Modify: `RoomRom/src/ow_room_render_roomrom.c` (`tile_word`)
- Modify: `RoomRom/src/uw_room_render_roomrom.c` (`write_tile_raw_at`)

- [ ] **Step 1: Replace OW `tile_word`**

```c
static unsigned short tile_word(unsigned char raw_tile, unsigned char sub_pal)
{
    return (unsigned short)(OW_VDP_TILE_BASE_PAL(sub_pal & 0x03)
                            + (unsigned short)raw_tile);
}
```

- [ ] **Step 2: Replace UW `write_tile_raw_at` body**

Inside `write_tile_raw_at`, replace the `word` build with:

```c
    unsigned short word = (unsigned short)(pri |
        (UW_VDP_TILE_BASE_PAL(pal & 0x03) + (unsigned short)raw_tile));
```

(`pri` = `0x8000` priority bit for door arches, kept from existing code.)

- [ ] **Step 3: Search for stragglers**

Run: `grep -nE "0x03[uU]?\)\s*<<\s*13" RoomRom/src/*.c`

Expected: no output. If any hit remains, replace it with `_PAL(s)` form.

- [ ] **Step 4: Build + smoke**

Run: `RoomRom\build.bat`. Boot OW + UW. Confirm BG colors match NES across all 4 sub-palettes. Specifically test:
- L1 R0 (uses BG-pal-3)
- L1 R73 (door art)
- OW 0x77 (test scene)
- OW 0x00 (start screen)

- [ ] **Step 5: Commit**

```bash
git add RoomRom/src/ow_room_render_roomrom.c RoomRom/src/uw_room_render_roomrom.c
git commit -m "roomrom: BG tile word uses sub-pal-in-tile-index (PAL0 always)"
```

### Task 4.5: Sprite + combat → PAL1 + sub-pal in tile

**Files:**
- Modify: `RoomRom/src/roomrom_sprites.c`
- Modify: `RoomRom/src/roomrom_combat.c`
- Modify: `RoomRom/src/roomrom_arrow.c`, `roomrom_bomb.c`, `roomrom_boomerang.c`

- [ ] **Step 1: Switch SAT writes to PAL1 + tile-index sub-pal**

In `roomrom_sprites.c`, find every `TILE_ATTR_FULL(PAL3, ...)` call. Replace with `TILE_ATTR_FULL(PAL1, ...)`. For tile pointer, replace `LINK_VRAM_TILE + pose_idx * LINK_TILES_PER_POSE` with `LINK_VRAM_TILE_PAL(0) + pose_idx * LINK_TILES_PER_POSE` (Link uses sub-pal 0; matches NES).

Same for combat module item draws — replace `PAL3` with `PAL1`, replace each item VRAM macro with its `_PAL(0)` form unless the item documents a different NES sub-pal.

- [ ] **Step 2: Drop old PAL3 sprite palette load**

In `roomrom_sprites.c`, delete `roomrom_sprites_load_palette` body (the function that wrote PAL3). Replace with:

```c
void roomrom_sprites_load_palette(void)
{
    /* Phase 4: sprite palette (PAL1) loaded via roomrom_bg_palette
     * roomrom_bg_palette_load_palram_full at room change. This stub kept
     * for ABI compatibility with existing call sites. */
}
```

- [ ] **Step 3: Build + smoke**

Run: `RoomRom\build.bat`. Boot RoomRom. Confirm:
- Link renders with NES Link colors (skin, green tunic).
- Sword renders with NES sword colors.
- Items render with their NES sprite colors.
- BG-pal-3 tiles still render correct (no regression from Phase 4.4).

- [ ] **Step 4: Commit**

```bash
git add RoomRom/src/roomrom_sprites.c RoomRom/src/roomrom_combat.c RoomRom/src/roomrom_arrow.c RoomRom/src/roomrom_bomb.c RoomRom/src/roomrom_boomerang.c
git commit -m "roomrom: sprites + items render via PAL1 + sub-pal-in-tile-index"
```

### Task 4.6: Phase 4 acceptance

- [ ] **Step 1: Slot-map verifier**

(Built in Phase 5 next, but pre-build a one-liner:)

```powershell
grep -rn "(pal & 0x03) << 13" RoomRom/src
grep -rn "slot < 3" RoomRom/src
```

Both expected: empty.

- [ ] **Step 2: Full smoke matrix**

Boot RoomRom, run through: orig + redux × OW + UW × scene/map/level/quest toggles. No stale CHR. No stale palettes. No regressions.

- [ ] **Step 3: Tag**

```bash
git tag roomrom-phase4-cutover
```

---

## Phase 5 — Verifiers + Acceptance

### Task 5.1: Write verify_slot_map.py

**Files:**
- Create: `RoomRom/tools/verify_slot_map.py`

- [ ] **Step 1: Write verifier**

Create `RoomRom/tools/verify_slot_map.py`:

```python
"""Hard gate: no NES-pal-to-Genesis-slot patterns + no slot<3 BG loaders.

Scans RoomRom render + HUD + sprite + combat + projectile sources.
Exit code 0 = pass, 1 = fail.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCAN = [
    "src/ow_room_render_roomrom.c",
    "src/uw_room_render_roomrom.c",
    "src/roomrom_hud.c",
    "src/roomrom_sprites.c",
    "src/roomrom_combat.c",
    "src/roomrom_arrow.c",
    "src/roomrom_bomb.c",
    "src/roomrom_boomerang.c",
]

PAT_PAL_SHIFT = re.compile(r"\(?\s*pal\s*&\s*0x03\s*\)?\s*<<\s*13", re.IGNORECASE)
PAT_SLOT3     = re.compile(r"\bslot\s*<\s*3\b")
PAT_HUD_PAL2  = re.compile(r"TILE_ATTR_FULL\s*\(\s*PAL[23]\s*,")

def fail(msg):
    print(f"verify_slot_map: FAIL: {msg}", file=sys.stderr)
    sys.exit(1)

def main():
    bad = []
    for rel in SCAN:
        path = ROOT / rel
        if not path.exists():
            bad.append((rel, 0, "missing file"))
            continue
        text = path.read_text(encoding="utf-8")
        for ln, line in enumerate(text.splitlines(), start=1):
            # Skip comments
            stripped = line.strip()
            if stripped.startswith("//") or stripped.startswith("/*") or \
               stripped.startswith("*"):
                continue
            if PAT_PAL_SHIFT.search(line):
                bad.append((rel, ln, f"(pal & 0x03) << 13: {stripped}"))
            if PAT_SLOT3.search(line) and "BG" in stripped.upper():
                bad.append((rel, ln, f"slot < 3 BG loop: {stripped}"))
            if rel.endswith("roomrom_hud.c") and PAT_HUD_PAL2.search(line):
                bad.append((rel, ln, f"HUD PAL2/3 write: {stripped}"))
    if bad:
        for rel, ln, msg in bad:
            print(f"  {rel}:{ln}  {msg}", file=sys.stderr)
        fail(f"{len(bad)} slot-map violations")
    print("verify_slot_map: OK")

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run verifier**

Run: `python RoomRom\tools\verify_slot_map.py`

Expected: `OK`. Any FAIL = leftover Phase 4 stragglers — fix and re-run.

- [ ] **Step 3: Commit**

```bash
git add RoomRom/tools/verify_slot_map.py
git commit -m "roomrom: slot-map verifier (HUD + render + sprite + combat scope)"
```

### Task 5.2: NES side-by-side acceptance probe

**Files:**
- Create: `RoomRom/probe_nes_genesis_palette_match.lua`
- Create: `RoomRom/tools/verify_palette_match.py`

- [ ] **Step 1: Probe captures NES PALRAM + Gen CRAM at same room**

Create `RoomRom/probe_nes_genesis_palette_match.lua`. The probe:

1. Runs first against vanilla NES Z1 ROM. Teleports to L1 R0, settles 12 frames, dumps PALRAM 32 bytes → `out/match_nes_l1_r0.json`.
2. Operator manually re-runs against the Genesis RoomRom ROM (BizHawk Genesis core, RoomRom.md loaded). Teleports the RoomRom equivalent room, settles, dumps CRAM 64 words → `out/match_gen_l1_r0.json`.
3. Repeat for: L1 R0, L1 R73, OW 0x77, OW 0x00, redux UW R0, redux OW 0x77.

Skeleton:

```lua
-- Set ROOMROM_PROBE_LABEL=l1_r0_nes (or _gen, etc)
local label = os.getenv("ROOMROM_PROBE_LABEL") or "l1_r0_nes"
local out_path = string.format(
    "C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY-roomrom-s1/RoomRom/out/match_%s.json",
    label)

local kind = label:match("(%a+)$") or ""
local entries = {}
if kind == "nes" then
    memory.usememorydomain("PALRAM")
    for i = 0, 31 do entries[#entries+1] = memory.readbyte(i) end
elseif kind == "gen" then
    memory.usememorydomain("CRAM")
    for i = 0, 127, 2 do
        local lo = memory.readbyte(i)
        local hi = memory.readbyte(i+1)
        entries[#entries+1] = lo + hi * 256
    end
end

local f = io.open(out_path, "w")
f:write("{\"label\":\"" .. label .. "\",\"data\":[")
for i, v in ipairs(entries) do
    f:write(tostring(v))
    if i < #entries then f:write(",") end
end
f:write("]}")
f:close()
```

- [ ] **Step 2: Capture sample rooms**

Run probe twice per room (NES + Gen). Save 12 JSONs total.

- [ ] **Step 3: Write match verifier**

Create `RoomRom/tools/verify_palette_match.py`:

```python
"""Acceptance gate: Gen CRAM == nes_to_cram(NES PALRAM byte) per loaded color.

For each sample room, loads match_<room>_nes.json + match_<room>_gen.json.
Walks PALRAM[0..15] (PAL0) + PALRAM[16..31] (PAL1). For each byte,
computes expected Gen CRAM word via misc_palettes LUT, compares to actual.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Reuse misc_palettes LUT (NES color idx -> Gen CRAM word). Read it from
# wherever it's emitted for RoomRom; here we hardcode the file path.
MISC_PALETTES_BIN = ROOT / "data" / "misc_palettes.bin"

SAMPLES = ["l1_r0", "l1_r73", "ow_77", "ow_00", "redux_uw_r0", "redux_ow_77"]

def load_lut():
    return MISC_PALETTES_BIN.read_bytes()

def nes_to_cram(lut, idx):
    off = (idx & 0x3F) * 2
    return lut[off] | (lut[off+1] << 8)

def fail(msg):
    print(f"verify_palette_match: FAIL: {msg}", file=sys.stderr)
    sys.exit(1)

def main():
    lut = load_lut()
    bad = 0
    for s in SAMPLES:
        nes_path = ROOT / "out" / f"match_{s}_nes.json"
        gen_path = ROOT / "out" / f"match_{s}_gen.json"
        if not nes_path.exists() or not gen_path.exists():
            print(f"skip {s}: missing capture")
            continue
        nes = json.loads(nes_path.read_text(encoding="utf-8"))["data"]
        gen = json.loads(gen_path.read_text(encoding="utf-8"))["data"]
        # PAL0 = nes[0..15], PAL1 = nes[16..31]
        # Gen CRAM is 64 words. PAL0 = gen[0..15], PAL1 = gen[16..31].
        for slot, (nes_off, gen_off) in enumerate([(0, 0), (16, 16)]):
            for i in range(16):
                exp = nes_to_cram(lut, nes[nes_off + i])
                act = gen[gen_off + i]
                if exp != act:
                    bad += 1
                    print(f"  {s} PAL{slot} entry {i}: "
                          f"nes=0x{nes[nes_off+i]:02X} "
                          f"expected_cram=0x{exp:04X} actual=0x{act:04X}",
                          file=sys.stderr)
    if bad:
        fail(f"{bad} palette entry mismatches")
    print("verify_palette_match: OK")

if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run verifier**

Run: `python RoomRom\tools\verify_palette_match.py`

Expected: `OK`. Any FAIL = palette pipeline mismatch — investigate misc_palettes LUT, PALRAM source, or load order.

- [ ] **Step 5: Commit**

```bash
git add RoomRom/probe_nes_genesis_palette_match.lua RoomRom/tools/verify_palette_match.py RoomRom/out/match_*.json
git commit -m "roomrom: NES↔Genesis palette match probe + verifier (6 sample rooms)"
```

### Task 5.3: Final acceptance + tag

- [ ] **Step 1: All verifiers green**

```powershell
python RoomRom\tools\verify_item_chr_manifest.py
python RoomRom\tools\verify_bg_palette_manifest.py
python RoomRom\tools\verify_vram_budget.py
python RoomRom\tools\verify_slot_map.py
python RoomRom\tools\verify_palette_match.py
```

Expected: all `OK`.

- [ ] **Step 2: Full build clean**

Run: `RoomRom\build.bat`. Expected: emits `RoomRom/out/RoomRom.md`.

- [ ] **Step 3: Smoke matrix**

Boot RoomRom. For each of orig + redux × OW + UW × all toggles: capture screenshot, confirm:
- BG colors match NES (no slot collision artifacts)
- HUD colors match NES
- Sprite (Link, sword, items) colors match NES
- No stale CHR / stale palettes after toggles

- [ ] **Step 4: Tag**

```bash
git tag roomrom-phase5-complete
```

- [ ] **Step 5: Update memory**

Add a new memory entry recording the completion + slot-map architecture, so future sessions don't re-introduce the `(pal & 0x03) << 13` pattern.

---

## Spec Coverage Self-Check

Spec sections vs plan tasks:

| Spec section | Plan task |
|--------------|-----------|
| Slot map (PAL0/PAL1 packing) | Task 4.2, 4.3, 4.5 |
| HUD/Window rule | Task 2.5.3, 4.1 |
| Tile pixel bias (`v == 0 ? 0 : s*4+v`) | Task 3.1, 3.2 |
| Renderer rule (sub-pal in tile index) | Task 3.3, 4.4, 4.5 |
| Palette load (PAL0+PAL1 only) | Task 2.3 |
| Phase 1 — Item atlas | Tasks 1.1–1.7 |
| Phase 2 — Live PALRAM capture | Tasks 2.1–2.4 |
| Phase 2.5 — VRAM map | Tasks 2.5.1–2.5.5 |
| Phase 3 — CHR expansion | Tasks 3.1–3.5 |
| Phase 4 — Renderer cutover | Tasks 4.1–4.6 |
| Phase 5 — Verifiers + acceptance | Tasks 5.1–5.3 |
| `verify_slot_map` scans HUD | Task 5.1 |
| Acceptance: Gen CRAM == nes_to_cram(PALRAM byte) | Task 5.2 |
| `verify_vram_budget` non-overlap check | Task 2.5.4 |
| Concrete VRAM constants (audit-then-commit) | Tasks 2.5.1–2.5.2 |
| CHR expansion asserts unbiased input | Task 3.1, 3.2 |

All spec sections covered.
