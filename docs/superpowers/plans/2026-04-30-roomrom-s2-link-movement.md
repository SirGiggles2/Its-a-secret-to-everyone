# RoomRom S2 — Link Movement + Clean Tile Sourcing — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Drop the S1 surgical `link_down_chr[128]` embed, source Link's tiles from the already-extracted `common_chr` block, and add D-pad movement with playfield clamp.

**Architecture:** Sprite module externs `common_chr`, copies Link's 4 NES tiles ($58/$59/$0A/$0B) into a dedicated VRAM region in Genesis 2x2 column-major order at boot. Per frame, main loop reads D-pad, mutates `s_link_x/y` with clamp, calls a new `roomrom_sprites_set_link_pos()` that writes to the VDP sprite cache and DMAs the single-entry update.

**Tech Stack:** SGDK 2.00, C, M68K, `RoomRom/build.bat`. Verification = build + visual probe + Read PNG.

**Spec:** [docs/superpowers/specs/2026-04-30-roomrom-s2-link-movement-design.md](../specs/2026-04-30-roomrom-s2-link-movement-design.md)

---

## File structure

| File | Status | Responsibility |
|---|---|---|
| `RoomRom/src/roomrom_sprites.h` | modify | + `roomrom_sprites_set_link_pos` decl |
| `RoomRom/src/roomrom_sprites.c` | modify | drop embed; copy Link tiles from `common_chr`; add per-frame setter |
| `RoomRom/src/main.c` | modify | drop room-jump block; add Link x/y state + clamp + per-frame set |
| `RoomRom/probe_roomrom_link_visible.lua` | modify | extend to verify movement and clamp |
| memory `project_chr_extractor_seam_bug.md` | rewrite | extractor not broken; common.c holds Link |

---

## Reference values (used across tasks)

- `common_chr` declared in `data/chr/common.c` as `const unsigned char common_chr[7616]` (verified Read).
- Per `data/chr/MANIFEST.json` block "common": `genesis_vram_tile_start = 936`. Use as `COMMON_VRAM_TILE_BASE`.
- Link facing-down standstill NES tile IDs: `0x58 (TL), 0x59 (BL), 0x0A (TR), 0x0B (BR)`.
- Existing constants in `roomrom_sprites.c`: `SPRITE_VRAM_TILE_BASE = 512`, `SPRITE_BLOCK_TILE_COUNT = 232`, `LINK_VRAM_TILE = SPRITE_VRAM_TILE_BASE + SPRITE_BLOCK_TILE_COUNT = 744`.
- Playfield clamp: x ∈ [0, 240], y ∈ [32, 208].

---

## Task 1: Update memory note about extractor

**Files:**
- Rewrite: `C:/Users/Jake Diggity/.claude/projects/C--Users-Jake-Diggity-Documents-GitHub-FINAL-TRY/memory/project_chr_extractor_seam_bug.md`

**Why:** Memory written during S1's /spritefix said the extractor was broken. Diff against `data/chr/common.c` shows extractor is correct — Link's gameplay tiles are present at the expected NES tile IDs in `common_chr`. The S1 confusion was routing/naming: Z1 calls Link's tiles "CommonSpritePatterns" not "OWSpritePatterns" so they end up in `common.c`, not `sprites.c`. Update memory so future-self doesn't waste time fixing a non-bug.

- [ ] **Step 1: Replace the file content with the corrected note.**

```markdown
---
name: Link tiles live in common.c, not sprites.c
description: Z1 routes Link/sword/heart tiles to "CommonSpritePatterns" so extractor places them in data/chr/common.c at NES tile IDs; data/chr/sprites.c holds OW enemies
type: project
---

`tools/extract_chr.py` is correct. The S1 /spritefix reported a "wrong seam" — that conclusion was wrong. Verified by offline diff: `data/chr/common.c` (= `common_chr[7616]`, 238 tiles) holds Link's gameplay sprites at NES tile IDs 1:1. Tile $58 in `common_chr` = Link standstill TL.

Routing rule: Zelda 1 NES separates sprite CHR into PatternBlockOWSP (overworld enemies — Octorok, Leever, Tektite) and CommonSpritePatterns (always-loaded sprites — Link, sword, heart, shield). The extractor places OWSP into `data/chr/sprites.c` and CommonSpritePatterns into `data/chr/common.c`. The naming "sprites.c" is misleading because Link is the obvious sprite to look for there.

**How to apply:**
- For Link tiles, source from `common_chr + nes_tile_id * 32`.
- For OW enemies (Octorok / Leever / Tektite), source from `sprites_chr + offset_within_owsp_block`. Map at `data/chr/MANIFEST.json` block "sprites".
- Do not touch `tools/extract_chr.py` looking for Link.
```

- [ ] **Step 2: Update `MEMORY.md` index entry to point at the corrected note.**

In `C:/Users/Jake Diggity/.claude/projects/C--Users-Jake-Diggity-Documents-GitHub-FINAL-TRY/memory/MEMORY.md`, replace the line:

```
- [extract_chr.py sprite seam wrong](project_chr_extractor_seam_bug.md) — sprites pulled from PRG $D15B (intro/title bank), should be $807F (gameplay); Link gameplay tiles missing from sprites.c
```

with:

```
- [Link tiles live in common.c not sprites.c](project_chr_extractor_seam_bug.md) — Z1 routes Link/sword/heart to CommonSpritePatterns; extractor is correct, naming is misleading
```

- [ ] **Step 3: No commit (memory files are not under repo control).**

---

## Task 2: Add `_set_link_pos` to header

**Files:**
- Modify: `RoomRom/src/roomrom_sprites.h`

- [ ] **Step 1: Read current header.**

Run: `Read RoomRom/src/roomrom_sprites.h` to confirm shape.

- [ ] **Step 2: Add the new declaration after `_spawn_link`.**

Replace:
```c
void roomrom_sprites_upload_chr(void);    /* one-shot at boot */
void roomrom_sprites_load_palette(void);  /* call after every load_room() */
void roomrom_sprites_spawn_link(short x, short y);
```
with:
```c
void roomrom_sprites_upload_chr(void);    /* one-shot at boot */
void roomrom_sprites_load_palette(void);  /* call after every load_room() */
void roomrom_sprites_spawn_link(short x, short y);
void roomrom_sprites_set_link_pos(short x, short y);
```

- [ ] **Step 3: Commit.**

```
git -C "<worktree>" add RoomRom/src/roomrom_sprites.h
git -C "<worktree>" commit -m "RoomRom: declare roomrom_sprites_set_link_pos for per-frame movement"
```

(Use HEREDOC + Co-Authored-By trailer.)

---

## Task 3: Replace surgical embed with `common_chr` source

**Files:**
- Modify: `RoomRom/src/roomrom_sprites.c`

- [ ] **Step 1: Replace the file's top section (externs + constants + `link_down_chr`) with `common_chr` extern + new constants.**

Replace this block (everything from line 1 through the `link_down_chr[128]` array's closing `};`):

```c
#include <genesis.h>
#include "roomrom_sprites.h"
#include "render_abi.h"

/* Sprite CHR block from data/chr/sprites.c. Note: the extractor pulls this
 * from the wrong PRG bank (intro/title sprite seam, not gameplay), so it does
 * NOT contain Link's gameplay tiles. We embed Link's 4 tiles below as a fix.
 * Long-term: tools/extract_chr.py needs its sprite seam corrected from
 * PRG $D15B to PRG $807F (verified via /spritefix probe). */
extern const unsigned char sprites_chr[7424];
extern const unsigned char misc_palettes[1208];

#define SPRITE_VRAM_TILE_BASE  512u
#define SPRITE_CHR_BYTES       7424u

#define SPRITE_BLOCK_TILE_COUNT 232u
#define LINK_VRAM_TILE         (SPRITE_VRAM_TILE_BASE + SPRITE_BLOCK_TILE_COUNT)

/* Link facing-down standstill, 4 tiles in Genesis 2x2 column-major order
 * (TL, BL, TR, BR). Sourced from NES gameplay CHR-RAM at NES tile IDs
 * $58, $59, $0A, $0B (verified via OAM dump in BizHawk: spr18 tile=$58,
 * spr19 tile=$0A, palette 0). NES 2bpp -> Genesis 4bpp converted offline. */
static const unsigned char link_down_chr[128] = {
    /* tile $58 (TL) */
    0x00, 0x00, 0x01, 0x11, 0x00, 0x00, 0x11, 0x11, 0x00, 0x20, 0x13, 0x33,
    0x00, 0x20, 0x33, 0x33, 0x00, 0x22, 0x32, 0x12, 0x00, 0x22, 0x32, 0x32,
    0x00, 0x02, 0x22, 0x22, 0x00, 0x01, 0x12, 0x23,
    /* tile $59 (BL) */
    0x03, 0x33, 0x33, 0x22, 0x33, 0x23, 0x33, 0x31, 0x32, 0x22, 0x33, 0x23,
    0x33, 0x23, 0x33, 0x21, 0x33, 0x23, 0x33, 0x23, 0x33, 0x33, 0x33, 0x21,
    0x02, 0x22, 0x22, 0x30, 0x00, 0x00, 0x33, 0x30,
    /* tile $0A (TR) */
    0x11, 0x10, 0x00, 0x00, 0x11, 0x11, 0x00, 0x00, 0x33, 0x31, 0x02, 0x00,
    0x33, 0x33, 0x02, 0x00, 0x21, 0x23, 0x22, 0x00, 0x23, 0x23, 0x22, 0x00,
    0x22, 0x22, 0x23, 0x00, 0x32, 0x21, 0x13, 0x00,
    /* tile $0B (BR) */
    0x22, 0x11, 0x33, 0x30, 0x11, 0x11, 0x23, 0x30, 0x31, 0x12, 0x22, 0x30,
    0x33, 0x33, 0x22, 0x20, 0x31, 0x11, 0x12, 0x00, 0x11, 0x11, 0x00, 0x00,
    0x03, 0x33, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
};
```

with:

```c
#include <genesis.h>
#include "roomrom_sprites.h"
#include "render_abi.h"

/* Sprite CHR sources.
 * sprites_chr (data/chr/sprites.c) holds OW enemy tiles (Octorok / Leever /
 * Tektite). common_chr (data/chr/common.c) holds the always-loaded sprites
 * including Link, sword, heart. NES tile IDs in common_chr are 1:1 (NES
 * tile $58 = common_chr + 0x58*32). */
extern const unsigned char sprites_chr[7424];
extern const unsigned char common_chr[7616];
extern const unsigned char misc_palettes[1208];

#define SPRITE_VRAM_TILE_BASE   512u
#define SPRITE_CHR_BYTES        7424u
#define SPRITE_BLOCK_TILE_COUNT 232u

/* Per data/chr/MANIFEST.json: common block lives at VRAM tile 936. Plus 238
 * tiles to land just past it for our Link slot. */
#define COMMON_VRAM_TILE_BASE   936u
#define COMMON_CHR_BYTES        7616u
#define COMMON_BLOCK_TILE_COUNT 238u

#define LINK_VRAM_TILE          (COMMON_VRAM_TILE_BASE + COMMON_BLOCK_TILE_COUNT)
```

- [ ] **Step 2: Rewrite `roomrom_sprites_upload_chr` to upload both blocks + the Link 4-tile dedicated copy from `common_chr`.**

Replace the existing `roomrom_sprites_upload_chr` function with:

```c
void roomrom_sprites_upload_chr(void)
{
    /* Main sprite block (OW enemies — kept for S3+). */
    render_chr_upload((unsigned short)(SPRITE_VRAM_TILE_BASE * 32u),
                      sprites_chr, SPRITE_CHR_BYTES);

    /* Common sprite block (always-loaded gameplay sprites including Link). */
    render_chr_upload((unsigned short)(COMMON_VRAM_TILE_BASE * 32u),
                      common_chr, COMMON_CHR_BYTES);

    /* Link facing-down standstill — copy 4 tiles from common_chr into the
     * dedicated LINK_VRAM_TILE region in Genesis 2x2 column-major order
     * (TL, BL, TR, BR). NES tile IDs: $58, $59, $0A, $0B. */
    {
        static const unsigned char link_down_nes_ids[4] = {
            0x58u, 0x59u, 0x0Au, 0x0Bu
        };
        unsigned char i;
        for (i = 0; i < 4; i++) {
            unsigned short src_off = (unsigned short)link_down_nes_ids[i] * 32u;
            render_chr_upload((unsigned short)((LINK_VRAM_TILE + i) * 32u),
                              common_chr + src_off, 32u);
        }
    }
}
```

- [ ] **Step 3: Add `roomrom_sprites_set_link_pos` at the bottom of the file.**

Append after `roomrom_sprites_spawn_link`:

```c
void roomrom_sprites_set_link_pos(short x, short y)
{
    VDP_setSpriteFull(0,
                      (s16)x,
                      (s16)y,
                      SPRITE_SIZE(2, 2),
                      TILE_ATTR_FULL(PAL3, 1, 0, 0, LINK_VRAM_TILE),
                      0);
    VDP_updateSprites(1, DMA);
}
```

- [ ] **Step 4: Build clean.**

Run: `cmd.exe /c "cd /d \"C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY-roomrom-s1\\RoomRom\" && build.bat"`
Expected: clean build, no `FAIL:`. ROM produced.

- [ ] **Step 5: Commit.**

```
git -C "<worktree>" add RoomRom/src/roomrom_sprites.c
git -C "<worktree>" commit -m "RoomRom: source Link tiles from common_chr; add _set_link_pos"
```

---

## Task 4: Wire D-pad movement in main.c

**Files:**
- Modify: `RoomRom/src/main.c`

- [ ] **Step 1: Replace the D-pad room-jump block with Link movement.**

Read main.c. Find this block (current lines ~117-131):

```c
        {
            /* UW grid: 16 cols x 8 rows (room_id = (row<<4)|col, col 0..15).
             * OW grid: 16 cols x 8 rows. Same bounds. */
            u8 max_col = 15u;
            u8 max_row = 7u;
            if      ((pressed & BUTTON_LEFT)  && col > 0)        col--;
            else if ((pressed & BUTTON_RIGHT) && col < max_col)  col++;
            else if ((pressed & BUTTON_UP)    && row > 0)        row--;
            else if ((pressed & BUTTON_DOWN)  && row < max_row)  row++;
            else continue;
        }

        s_room_id = (u8)((row << 4) | col);
        load_room(s_room_id);
```

Replace with:

```c
        /* D-pad now drives Link movement (1 px/frame, held). Room-jump nav
         * removed — see S2 spec. */
        if (joy & BUTTON_LEFT)  s_link_x--;
        if (joy & BUTTON_RIGHT) s_link_x++;
        if (joy & BUTTON_UP)    s_link_y--;
        if (joy & BUTTON_DOWN)  s_link_y++;
        if (s_link_x < 0)   s_link_x = 0;
        if (s_link_x > 240) s_link_x = 240;
        if (s_link_y < 32)  s_link_y = 32;
        if (s_link_y > 208) s_link_y = 208;
        roomrom_sprites_set_link_pos(s_link_x, s_link_y);
```

- [ ] **Step 2: Add Link x/y state at the top of main.c (next to existing static state).**

Find:
```c
static scene_t s_scene = SCENE_OW;
static u8 s_room_id = 0x77;   /* exposed for Lua overlay */
```
Add immediately after:
```c
static short s_link_x = 128;
static short s_link_y =  88;
```

- [ ] **Step 3: Remove the `col`/`row` local declarations that are no longer used.**

In `int main(...)`, find:
```c
    u16 joy_prev = 0;
    u8 col, row;
```
Replace with:
```c
    u16 joy_prev = 0;
```

Also remove the per-iteration `col = ...; row = ...;` calculation block immediately after `joy_prev = joy;`. It looks like:
```c
        col = s_room_id & 0x0F;
        row = s_room_id >> 4;
```
Delete those two lines outright.

- [ ] **Step 4: Update spawn call to use the static state.**

The existing `roomrom_sprites_spawn_link(128, 88);` call should be changed to:
```c
roomrom_sprites_spawn_link(s_link_x, s_link_y);
```

- [ ] **Step 5: Build.**

Run the build command. Expected clean.

- [ ] **Step 6: Commit.**

```
git -C "<worktree>" add RoomRom/src/main.c
git -C "<worktree>" commit -m "RoomRom: D-pad moves Link 1px/frame with playfield clamp"
```

---

## Task 5: Extend probe to verify movement and clamp

**Files:**
- Modify: `RoomRom/probe_roomrom_link_visible.lua`

- [ ] **Step 1: Replace probe contents with movement-aware version.**

```lua
-- probe_roomrom_link_visible.lua
-- Boot RoomRom.md, exercise B/C/A/Start + D-pad movement + clamp.
-- BizHawk Genesis core uses unprefixed button names ("B" not "P1 B").

local OUT = os.getenv("CODEX_BIZHAWK_ROOT") or ""
if OUT == "" or OUT == nil then OUT = "." end
local OUTDIR = OUT .. "/RoomRom/out"

local function wait(n)
    for _ = 1, n do
        emu.frameadvance()
    end
end

local function press(btn)
    for _ = 1, 3 do
        joypad.set({[btn] = true}, 1)
        emu.frameadvance()
    end
    joypad.set({}, 1)
    wait(60)
end

local function hold(btn, frames)
    for _ = 1, frames do
        joypad.set({[btn] = true}, 1)
        emu.frameadvance()
    end
    joypad.set({}, 1)
    wait(10)
end

-- Boot.
wait(180)
client.screenshot(OUTDIR .. "/probe_link_00_spawn.png")

-- Walk Right ~60 px.
hold("Right", 60); client.screenshot(OUTDIR .. "/probe_link_01_walk_right.png")

-- Walk Down ~60 px.
hold("Down", 60);  client.screenshot(OUTDIR .. "/probe_link_02_walk_down.png")

-- Hold Down for 240 frames so Link clamps at the bottom edge.
hold("Down", 240); client.screenshot(OUTDIR .. "/probe_link_03_clamp_bottom.png")

-- Hold Up for 300 frames so Link clamps at the top.
hold("Up", 300);   client.screenshot(OUTDIR .. "/probe_link_04_clamp_top.png")

-- Toggle to UW with B; verify Link still rendered.
press("B"); client.screenshot(OUTDIR .. "/probe_link_05_uw.png")

print("probe done")
client.exit()
```

- [ ] **Step 2: Commit.**

```
git -C "<worktree>" add RoomRom/probe_roomrom_link_visible.lua
git -C "<worktree>" commit -m "RoomRom: extend probe to verify movement + clamp + UW transition"
```

---

## Task 6: Run probe and verify visually

**Files:** none modified.

- [ ] **Step 1: Stage ROM + run probe via bizhawkScript skill pattern.**

Stage:
```
cp "<worktree>/RoomRom/out/RoomRom.md" /c/tmp/RoomRom.md
cp "<worktree>/RoomRom/probe_roomrom_link_visible.lua" /c/tmp/probe_link.lua
```

Edit `/c/tmp/probe_link.lua` to hard-code `OUTDIR = "C:/tmp"` for path safety.

Launch with the documented PowerShell `Start-Process` form (see bizhawkScript skill).

- [ ] **Step 2: Read each screenshot.**

For each of:
- `probe_link_00_spawn.png` → Link at center (128, 88)
- `probe_link_01_walk_right.png` → Link visibly right of center, no tile garbage
- `probe_link_02_walk_down.png` → Link visibly below + right
- `probe_link_03_clamp_bottom.png` → Link at y=208, did not exit playfield
- `probe_link_04_clamp_top.png` → Link at y=32, did not enter HUD
- `probe_link_05_uw.png` → UW scene with Link visible, palette intact

- [ ] **Step 3: Cross-check against NES live reference.**

Use the existing `/c/tmp/nes_link_overworld.png` as the canonical Link shape. Genesis Link in `probe_link_00_spawn.png` should be visually equivalent (allowing for Genesis CRAM color quantization).

- [ ] **Step 4: If any failure, fix and re-run.**

Common failures:
- Link disappears after movement → confirm `roomrom_sprites_set_link_pos` calls `VDP_updateSprites`.
- Tile corruption → confirm `LINK_VRAM_TILE` calculation; ensure `common_chr` upload doesn't overlap `sprites_chr` upload.
- Clamp wrong → re-check the `<` vs `<=` in clamp branches.
- Toggle drops Link → palette reload missing; confirm `_load_palette` still called from `load_room` tail.

---

## Task 7: Tag closure

**Files:** none modified.

- [ ] **Step 1: Move tag.**

```
git -C "<worktree>" tag -d roomrom-s1-closed     # if it points at S1 head
git -C "<worktree>" tag -a roomrom-s2-closed -m "RoomRom S2 closed: Link walks 1px/frame with playfield clamp; tiles sourced from common_chr"
```

(Don't delete `roomrom-s1-closed` — leave it on the S1 commit. Just create `roomrom-s2-closed` on the new HEAD.)

- [ ] **Step 2: Final code review.**

Dispatch a code-reviewer subagent on the S2 range (`roomrom-s1-closed..HEAD`), check spec coverage, note any followup items.

---

## Self-review

**Spec coverage:**
- Spec § Architecture (sprite module changes) → Tasks 2, 3
- Spec § main.c per-frame contract → Task 4
- Spec § common.c sourcing → Task 3 step 1, 2
- Spec § Verify steps (5 visual checks) → Task 5, 6
- Spec § File-level changes → all tasks cover all listed files
- Spec § Memory note rewrite → Task 1

**Placeholder scan:** none. Every step has actual code/text.

**Type/symbol consistency:**
- `roomrom_sprites_set_link_pos(short x, short y)` — declared in Task 2, defined in Task 3 step 3, called in Task 4 step 1. Signatures match.
- `s_link_x`, `s_link_y` — defined `short` in Task 4 step 2, used `short` in clamp + setter call.
- `LINK_VRAM_TILE` derives from `COMMON_VRAM_TILE_BASE + COMMON_BLOCK_TILE_COUNT = 936 + 238 = 1174`. Note: the `demo_chr` block also expects to live at VRAM 1174 per MANIFEST. RoomRom doesn't load demo_chr, so this is unused VRAM space — safe. Documented as risk in spec §VRAM.

No issues found.
