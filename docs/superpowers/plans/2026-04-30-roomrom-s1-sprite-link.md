# RoomRom S1 — Sprite Scaffold + Static Link — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the sprite/OAM pipeline in the RoomRom test harness and render a single static Link sprite over the BG plane, in both OW and UW scenes, with no regressions to existing BG/HUD parity.

**Architecture:** A new `roomrom_sprites` module owns PAL3 and one global sprite-CHR upload (data/chr/sprites.c, already in Genesis 4bpp). BG palette loaders are restricted to slots 0..2 to free PAL3. Link is rendered via raw `VDP_setSprite` + `VDP_updateSprites(1, DMA)` — no SGDK SPR engine. Main loop is unchanged; sprite palette is re-loaded after every room load to survive scene/ROM/level/quest toggles.

**Tech Stack:** SGDK 2.00 (pinned), C, Motorola 68000 cross-compile via `RoomRom/build.bat`. Verification = build clean + Lua probe screenshots inspected via `Read`. No unit-test framework in this codebase; "test" means observable visual behavior.

**Spec:** [docs/superpowers/specs/2026-04-30-roomrom-s1-sprite-link-design.md](../specs/2026-04-30-roomrom-s1-sprite-link-design.md)

---

## Reference data

These values are referenced across multiple tasks. Pull them once, reuse:

- `data/chr/sprites.c` exports `const unsigned char sprites_chr[7424]` (per `data/chr/MANIFEST.json` block `"sprites"`, 232 tiles × 32 bytes = 7424).
- Genesis VRAM tile base for sprite block: **`512`** (per manifest `genesis_vram_tile_start`).
- Link facing-down standstill NES tile IDs (top-left, top-right, bottom-left, bottom-right): `0x60, 0x61, 0x70, 0x71`. Sprite rendered as `SPRITE_SIZE(2,2)`, base VRAM tile = `512 + 0x60 = 608`.
- NES sprite sub-palette 0 (Link's gameplay palette): NES color indices `$0F, $30, $16, $06` → Genesis CRAM via `nes_color_to_cram()` already in `ow_room_render_roomrom.c`.
- Sprite-table screen offset: SGDK uses `0x80` (128) origin; pass `screen_x + 0x80, screen_y + 0x80`.
- Room render area on Genesis plane: 32×28 visible tiles. Room center for Link at S1: screen `(128, 88)`.

---

## File structure

| File | Status | Responsibility |
|---|---|---|
| `RoomRom/src/roomrom_sprites.h` | **create** | Public API for the sprite module |
| `RoomRom/src/roomrom_sprites.c` | **create** | One-shot CHR upload, PAL3 load, Link spawn via raw VDP |
| `RoomRom/src/main.c` | modify | Wire init / spawn calls; re-load sprite palette after `load_room()` |
| `RoomRom/src/ow_room_render_roomrom.c` | modify | Restrict BG palette write to slots 0..2 (free PAL3) |
| `RoomRom/src/uw_room_render_roomrom.c` | modify | Same restriction for UW BG palette loaders |
| `RoomRom/build.bat` | modify | Compile `roomrom_sprites.c` and `data/chr/sprites.c`, add to OBJS |
| `RoomRom/probe_roomrom_link_visible.lua` | **create** | BizHawk probe: boot ROM, capture OW + UW screenshots, dump VDP regs |

---

## Task 1: Free PAL3 in OW and UW BG palette loaders

**Files:**
- Modify: `RoomRom/src/ow_room_render_roomrom.c:123-139` (function `roomrom_ow_room_render_load_palette`)
- Modify: `RoomRom/src/uw_room_render_roomrom.c:85-114` (functions `load_palette_from_blob` and `load_palette_from_levelinfo`)

**Why:** BG renderer currently writes all four CRAM palettes 0..3 from NES level info. Sprites need PAL3. Long-term split: BG owns PAL0..PAL2, sprites own PAL3.

- [ ] **Step 1: Read both functions to confirm exact loop bounds.**

Run:
```
grep -n "for (slot = 0; slot < 4" RoomRom/src/ow_room_render_roomrom.c RoomRom/src/uw_room_render_roomrom.c
```
Expected: three matches (one OW, two UW).

- [ ] **Step 2: Edit OW palette loader — change loop bound from 4 to 3.**

In `RoomRom/src/ow_room_render_roomrom.c`, replace:
```c
    for (slot = 0; slot < 4; slot++) {
        for (i = 0; i < 16; i++)
            pal16[i] = 0;
        for (i = 0; i < 4; i++)
            pal16[i] = nes_color_to_cram(
                rooms[LEVEL_INFO_PALETTE_OFFSET + slot * 4 + i]);
        render_load_palette(slot, pal16);
    }
```
with:
```c
    /* PAL3 reserved for sprites (see roomrom_sprites). BG owns PAL0..PAL2. */
    for (slot = 0; slot < 3; slot++) {
        for (i = 0; i < 16; i++)
            pal16[i] = 0;
        for (i = 0; i < 4; i++)
            pal16[i] = nes_color_to_cram(
                rooms[LEVEL_INFO_PALETTE_OFFSET + slot * 4 + i]);
        render_load_palette(slot, pal16);
    }
```

- [ ] **Step 3: Edit UW `load_palette_from_blob` — same change.**

In `RoomRom/src/uw_room_render_roomrom.c:85`, the function loops over palette slots from a blob. Read the function and change its slot upper bound from 4 to 3, preserving the loop structure. Add the same `/* PAL3 reserved for sprites */` comment on the line above the loop.

- [ ] **Step 4: Edit UW `load_palette_from_levelinfo` — same change.**

In `RoomRom/src/uw_room_render_roomrom.c:99`, change its slot upper bound from 4 to 3 and add the same comment.

- [ ] **Step 5: Build and confirm clean.**

Run: `cmd.exe /c "cd /d \"C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\RoomRom\" && build.bat"`
Expected: prints `RoomRom built: ...\out\RoomRom.md`. No `FAIL:` lines.

- [ ] **Step 6: Run BizHawk probe to spot-check OW room 0x77 and UW L1 entry for BG color regression.**

Use the bizhawkScript skill pattern. Probe writes one screenshot for OW room 0x77 (post-boot default) and one for UW after a B-press.

If a regression is observed (a tile that was using NES BG sub-pal 3 now black), document the tile ID and note in the commit message — this is acceptable for S1 and will be remapped in a follow-up. If no regression, even better.

- [ ] **Step 7: Commit.**

```
git add RoomRom/src/ow_room_render_roomrom.c RoomRom/src/uw_room_render_roomrom.c
git commit -m "RoomRom: free PAL3 for sprites, BG owns PAL0..PAL2"
```

---

## Task 2: Create `roomrom_sprites.h`

**Files:**
- Create: `RoomRom/src/roomrom_sprites.h`

- [ ] **Step 1: Write the header.**

```c
#ifndef ROOMROM_SPRITES_H
#define ROOMROM_SPRITES_H

/* RoomRom sprite/OAM scaffold.
 *
 * Owns PAL3 and the sprite-CHR VRAM region (tiles 512..743). Renders Link
 * as a single static 16x16 sprite via raw VDP_setSprite + VDP_updateSprites.
 * BG palette loaders must skip PAL3 — see ow_/uw_room_render_roomrom.c.
 *
 * S2+ will add motion, animation frames, and additional sprites.
 */

void roomrom_sprites_upload_chr(void);    /* one-shot at boot */
void roomrom_sprites_load_palette(void);  /* call after every load_room() */
void roomrom_sprites_spawn_link(short x, short y);

#endif
```

- [ ] **Step 2: Confirm the file builds (it has no callers yet).**

Run: `cmd.exe /c "cd /d \"C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\RoomRom\" && build.bat"`
Expected: clean build (header compiled lazily; this just verifies syntax).

- [ ] **Step 3: Commit.**

```
git add RoomRom/src/roomrom_sprites.h
git commit -m "RoomRom: add roomrom_sprites.h API skeleton"
```

---

## Task 3: Create `roomrom_sprites.c` — CHR upload

**Files:**
- Create: `RoomRom/src/roomrom_sprites.c`

- [ ] **Step 1: Write the initial .c with externs and CHR upload only.**

```c
#include <genesis.h>
#include "roomrom_sprites.h"
#include "render_abi.h"

/* Sprite CHR is exported from data/chr/sprites.c, already in Genesis 4bpp.
 * Per data/chr/MANIFEST.json the sprite block lives at VRAM tile 512. */
extern const unsigned char sprites_chr[7424];

#define SPRITE_VRAM_TILE_BASE  512u
#define SPRITE_CHR_BYTES       7424u

void roomrom_sprites_upload_chr(void)
{
    render_chr_upload((unsigned short)(SPRITE_VRAM_TILE_BASE * 32u),
                      sprites_chr, SPRITE_CHR_BYTES);
}

void roomrom_sprites_load_palette(void)
{
    /* TODO Task 4 */
}

void roomrom_sprites_spawn_link(short x, short y)
{
    (void)x; (void)y;
    /* TODO Task 5 */
}
```

- [ ] **Step 2: Build (this file isn't in build.bat yet, so the test of compilation comes in Task 6).**

Skip build for now — Task 6 wires it in. Just confirm the file is syntactically reasonable by visual review.

- [ ] **Step 3: Commit.**

```
git add RoomRom/src/roomrom_sprites.c
git commit -m "RoomRom: add roomrom_sprites.c with CHR upload (palette + spawn stubs)"
```

---

## Task 4: Implement `roomrom_sprites_load_palette`

**Files:**
- Modify: `RoomRom/src/roomrom_sprites.c`

**Why:** Write Link's NES sprite sub-palette 0 into Genesis PAL3 via the existing `render_load_palette` adapter. Hard-coded 16 colors: sub-pal 0 (Link) populated with NES `$0F, $30, $16, $06`; sub-pals 1..3 zeroed for now (reserved for enemy palettes in later slices).

- [ ] **Step 1: Add `nes_color_to_cram` reuse.**

The function lives in `ow_room_render_roomrom.c` as a static. To avoid duplication, declare it `extern` there and remove `static`, OR copy the conversion inline. Choose **inline** for S1 — keeps `ow_room_render` untouched and the conversion is 6 lines.

- [ ] **Step 2: Replace the `roomrom_sprites_load_palette` stub with this implementation.**

Replace the `TODO Task 4` block with:
```c
/* Inline copy of nes_color_to_cram (also used in ow_/uw_room_render).
 * misc_palettes is the canonical NES->CRAM lookup populated at build. */
extern const unsigned char misc_palettes[1208];

static unsigned short nes_to_cram(unsigned char nes_idx)
{
    unsigned short off = (unsigned short)(nes_idx & 0x3Fu) * 2u;
    return (unsigned short)misc_palettes[off]
         | ((unsigned short)misc_palettes[off + 1] << 8);
}

void roomrom_sprites_load_palette(void)
{
    unsigned short pal16[16];
    unsigned char i;

    for (i = 0; i < 16; i++) pal16[i] = 0;

    /* NES sprite sub-palette 0 = Link's gameplay palette ($3F10..$3F13). */
    pal16[0] = nes_to_cram(0x0F);  /* transparent / black */
    pal16[1] = nes_to_cram(0x30);  /* white  (shield highlights) */
    pal16[2] = nes_to_cram(0x16);  /* tan    (skin) */
    pal16[3] = nes_to_cram(0x06);  /* dark red / brown */

    /* sub-pals 1..3 left zero — populated in later slices for enemy colors. */

    render_load_palette(3 /* PAL3 */, pal16);
}
```

- [ ] **Step 3: Verify by building (still requires Task 6 to actually link). Visual review only.**

- [ ] **Step 4: Commit.**

```
git add RoomRom/src/roomrom_sprites.c
git commit -m "RoomRom: implement roomrom_sprites_load_palette (NES sprite pal 0 -> PAL3)"
```

---

## Task 5: Implement `roomrom_sprites_spawn_link`

**Files:**
- Modify: `RoomRom/src/roomrom_sprites.c`

- [ ] **Step 1: Replace the spawn stub with raw-VDP sprite emission.**

Replace the `TODO Task 5` block with:
```c
#define LINK_TILE_NES_BASE  0x60u   /* facing-down standstill, top-left tile */
#define LINK_VRAM_TILE     (SPRITE_VRAM_TILE_BASE + LINK_TILE_NES_BASE)

void roomrom_sprites_spawn_link(short x, short y)
{
    /* SGDK sprite-table coords: screen + 0x80 origin. */
    unsigned short sx = (unsigned short)(x + 0x80);
    unsigned short sy = (unsigned short)(y + 0x80);

    VDP_setSprite(0,
                  sy,
                  sx,
                  SPRITE_SIZE(2, 2),
                  TILE_ATTR_FULL(PAL3, 1 /*pri*/, 0 /*vflip*/, 0 /*hflip*/,
                                 LINK_VRAM_TILE),
                  0 /*link terminator*/);
    VDP_updateSprites(1, DMA);
}
```

- [ ] **Step 2: Sanity-read the file end-to-end before commit.**

Run: `Read RoomRom/src/roomrom_sprites.c`
Expected: three functions implemented, no remaining `TODO Task` strings.

- [ ] **Step 3: Commit.**

```
git add RoomRom/src/roomrom_sprites.c
git commit -m "RoomRom: implement roomrom_sprites_spawn_link via raw VDP sprite"
```

---

## Task 6: Wire `roomrom_sprites.c` and `sprites.c` into `build.bat`

**Files:**
- Modify: `RoomRom/build.bat`

- [ ] **Step 1: Add a compile step for `roomrom_sprites.c` after the `uw_room_blob.c` compile (line ~80).**

Insert these two lines after the `uw_room_blob.o` block:
```
echo [3] Compiling roomrom_sprites.c...
"%GCC%" %CFLAGS% %INCS% -c "%PROJ%\src\roomrom_sprites.c" -o "%OUT%\roomrom_sprites.o"
if errorlevel 1 ( echo FAIL: roomrom_sprites.c & exit /b 1 )
```

- [ ] **Step 2: Add a compile step for `data/chr/sprites.c` near the other CHR compiles (after `common.c` line ~117).**

Insert:
```
echo [3] Compiling sprites.c...
"%GCC%" %CFLAGS% %INCS% -c "%REPO%\data\chr\sprites.c" -o "%OUT%\sprites.o"
if errorlevel 1 ( echo FAIL: sprites.c & exit /b 1 )
```

- [ ] **Step 3: Add both objects to the link command (`OBJS=` line ~127).**

Replace:
```
set "OBJS=%OUT%\main.o %OUT%\render_adapter_sgdk.o %OUT%\ow_room_render.o %OUT%\uw_room_render.o %OUT%\uw_room_blob.o %OUT%\roomrom_hud.o %OUT%\overworld.o %OUT%\overworld_bg.o %OUT%\dungeons.o %OUT%\underworld_bg.o %OUT%\redux_overworld.o %OUT%\redux_overworld_bg.o %OUT%\redux_uw_bg.o %OUT%\redux_hud_chr.o %OUT%\common.o %OUT%\palettes.o"
```
with:
```
set "OBJS=%OUT%\main.o %OUT%\render_adapter_sgdk.o %OUT%\ow_room_render.o %OUT%\uw_room_render.o %OUT%\uw_room_blob.o %OUT%\roomrom_hud.o %OUT%\roomrom_sprites.o %OUT%\overworld.o %OUT%\overworld_bg.o %OUT%\dungeons.o %OUT%\underworld_bg.o %OUT%\redux_overworld.o %OUT%\redux_overworld_bg.o %OUT%\redux_uw_bg.o %OUT%\redux_hud_chr.o %OUT%\common.o %OUT%\palettes.o %OUT%\sprites.o"
```

- [ ] **Step 4: Build clean (with the new sources but no main.c wiring yet).**

Run: `cmd.exe /c "cd /d \"C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\RoomRom\" && build.bat"`
Expected: prints both new compile steps, links cleanly, ROM produced. The new functions are unreferenced so `-Wl,--gc-sections` may strip them — that's fine until Task 7 adds callers.

- [ ] **Step 5: Commit.**

```
git add RoomRom/build.bat
git commit -m "RoomRom: build roomrom_sprites.c and data/chr/sprites.c"
```

---

## Task 7: Wire sprite module into `main.c`

**Files:**
- Modify: `RoomRom/src/main.c`

- [ ] **Step 1: Add the include after the existing module includes.**

In `RoomRom/src/main.c:1-4`, replace:
```c
#include <genesis.h>
#include "ow_room_render_roomrom.h"
#include "uw_room_render_roomrom.h"
#include "roomrom_hud.h"
```
with:
```c
#include <genesis.h>
#include "ow_room_render_roomrom.h"
#include "uw_room_render_roomrom.h"
#include "roomrom_hud.h"
#include "roomrom_sprites.h"
```

- [ ] **Step 2: Re-load sprite palette after every `load_room()`.**

The cleanest place is inside `load_room()` itself so every navigation path gets covered. In `RoomRom/src/main.c:30-42`, replace:
```c
static void load_room(u8 room_id)
{
    VDP_clearPlane(BG_A, TRUE);
    if (s_scene == SCENE_UW) {
        roomrom_uw_room_render_load_palette(room_id);
        roomrom_uw_room_render_fill_plane_a(room_id);
        roomrom_hud_draw(roomrom_uw_room_render_get_map(), room_id);
    } else {
        roomrom_ow_room_render_load_palette(room_id);
        roomrom_ow_room_render_fill_plane_a(room_id);
        roomrom_hud_draw(roomrom_ow_room_render_get_map(), room_id);
    }
}
```
with:
```c
static void load_room(u8 room_id)
{
    VDP_clearPlane(BG_A, TRUE);
    if (s_scene == SCENE_UW) {
        roomrom_uw_room_render_load_palette(room_id);
        roomrom_uw_room_render_fill_plane_a(room_id);
        roomrom_hud_draw(roomrom_uw_room_render_get_map(), room_id);
    } else {
        roomrom_ow_room_render_load_palette(room_id);
        roomrom_ow_room_render_fill_plane_a(room_id);
        roomrom_hud_draw(roomrom_ow_room_render_get_map(), room_id);
    }
    roomrom_sprites_load_palette();   /* PAL3 — reload after BG palette write */
}
```

- [ ] **Step 3: Add init + spawn calls after the initial `load_room`.**

In `RoomRom/src/main.c:54-67`, replace:
```c
    init_video();
    upload_scene_chr();
    {
        u32 blank[8] = {0,0,0,0,0,0,0,0};
        VDP_loadTileData(blank, 0, 1, CPU);
    }
    load_room(s_room_id);
```
with:
```c
    init_video();
    upload_scene_chr();
    {
        u32 blank[8] = {0,0,0,0,0,0,0,0};
        VDP_loadTileData(blank, 0, 1, CPU);
    }
    roomrom_sprites_upload_chr();         /* one-shot sprite CHR */
    load_room(s_room_id);                  /* loads BG pal + sprite PAL3 */
    roomrom_sprites_spawn_link(128, 88);   /* center of room */
```

- [ ] **Step 4: Build clean.**

Run: `cmd.exe /c "cd /d \"C:\\Users\\Jake Diggity\\Documents\\GitHub\\FINAL TRY\\RoomRom\" && build.bat"`
Expected: ROM built, no FAIL.

- [ ] **Step 5: Commit.**

```
git add RoomRom/src/main.c
git commit -m "RoomRom: wire sprite scaffold into main, spawn static Link at center"
```

---

## Task 8: Author verification probe

**Files:**
- Create: `RoomRom/probe_roomrom_link_visible.lua`

**Why:** Automate visual verify so we never ask the user to launch BizHawk (per project memory feedback). Probe takes one screenshot in OW, presses B, takes one in UW, dumps VDP regs and CRAM, exits.

- [ ] **Step 1: Write the probe.**

```lua
-- probe_roomrom_link_visible.lua
-- Boot RoomRom.md, capture OW + UW screenshots with Link visible.
-- Output PNGs into RoomRom/out/ for inspection via Read.

local OUT = os.getenv("CODEX_BIZHAWK_ROOT") or ""
if OUT == "" then OUT = "." end
local OUTDIR = OUT .. "/RoomRom/out"

local function wait(n)
    for _ = 1, n do
        emu.frameadvance()
    end
end

-- Boot for ~2 seconds so init_video / upload_chr / spawn complete.
wait(120)

-- OW capture
client.screenshot(OUTDIR .. "/probe_link_ow.png")

-- Press B (scene toggle to UW). Genesis controller mapping.
joypad.set({["B"] = true}, 1)
wait(2)
joypad.set({["B"] = false}, 1)
wait(60)

-- UW capture
client.screenshot(OUTDIR .. "/probe_link_uw.png")

-- Dump CRAM (palette) for sanity check.
local f = io.open(OUTDIR .. "/probe_link_cram.txt", "w")
if f then
    for i = 0, 63 do
        f:write(string.format("CRAM[%02d] = $%04X\n",
                              i, memory.read_u16_be(0xC00000 + i*2, "CRAM")))
    end
    f:close()
end

print("probe done; screenshots written to " .. OUTDIR)
client.exit()
```

Note: BizHawk's CRAM access varies by core; if `memory.read_u16_be(..., "CRAM")` errors on the user's BizHawk version, drop that block — screenshots are sufficient for S1 verify.

- [ ] **Step 2: Commit.**

```
git add RoomRom/probe_roomrom_link_visible.lua
git commit -m "RoomRom: add probe_roomrom_link_visible Lua probe for S1 verify"
```

---

## Task 9: Run the probe and inspect

**Files:** none modified.

- [ ] **Step 1: Launch BizHawk with RoomRom.md and the probe (bizhawkScript skill).**

Set `CODEX_BIZHAWK_ROOT` to the repo root so the probe writes into `RoomRom/out/`. Use the same launch pattern as other probes in the codebase (the bizhawkScript skill describes it). Run in background so the loop control returns.

- [ ] **Step 2: Read both screenshots.**

```
Read C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/RoomRom/out/probe_link_ow.png
Read C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/RoomRom/out/probe_link_uw.png
```

- [ ] **Step 3: Compare against verify checklist.**

For both images:
1. BG renders normally (no obvious black tiles where map art should be).
2. A 16×16 sprite is visible at screen center, recognizable as Link facing down.
3. Link's palette: tunic green (NES `$2A` family), skin tan, shield/eyes white, dark detail brown.
4. HUD (top of screen) intact.

Common failure modes:
- **No sprite visible:** likely `VDP_updateSprites` not called or `sy` calculation wrong; recheck Task 5.
- **Sprite at wrong corner:** SGDK 0x80 origin off — verify `sx = x + 0x80, sy = y + 0x80`.
- **Wrong colors:** PAL3 not loaded after `load_room`; check Task 7 step 2 placement.
- **Garbled tile art:** sprite VRAM tile base wrong; confirm `512` from manifest.
- **Black BG tiles:** Task 1 dropped a sub-palette that some room tile referenced. Note tile + room id; not blocking for S1.

- [ ] **Step 4: If any failure, fix and re-run from this task. If pass, proceed to Task 10.**

---

## Task 10: Final verification across all toggles + commit S1 closeout

**Files:** none modified — verification only.

- [ ] **Step 1: Extend the probe (or write a one-off) to cycle B (scene), C (ROM variant), A (UW level), Start (quest).**

Drive each toggle, capture one screenshot per state. Confirm Link is present in every screenshot. The simplest form is a short script appended to the existing probe; or a new `probe_roomrom_link_toggles.lua` if cleaner.

- [ ] **Step 2: Read every screenshot, confirm Link visible in each.**

If any toggle drops Link (palette regress or sprite cleared), the most likely cause is a path that calls a renderer without going through `load_room` — fix by ensuring every code path that re-loads BG palette also calls `roomrom_sprites_load_palette`.

- [ ] **Step 3: Final commit.**

```
git add -A
git commit -m "RoomRom S1 closed: static Link sprite renders over BG in OW + UW + all toggles"
```

- [ ] **Step 4: Tag the milestone.**

```
git tag roomrom-s1-closed
```

---

## Self-review

**Spec coverage:**
- Spec § Architecture → Tasks 2, 3, 4, 5, 7
- Spec § Module API → Task 2 (header) + 3, 4, 5 (implementations)
- Spec § VRAM/palette plan → Tasks 1 (free PAL3), 3 (CHR upload), 4 (palette)
- Spec § Link sprite → Task 5
- Spec § Per-frame contract → Task 7 step 2 (re-load after load_room) + Task 5 (single VDP_updateSprites in spawn)
- Spec § Verification → Tasks 9, 10
- Spec § Risks (PAL3 conflict) → Task 1 + Task 7 step 2
- Spec § File-level changes → all listed file rows have a corresponding task

**Placeholder scan:** no `TBD`, `TODO`, "implement later", "fill in details", "appropriate", "Similar to Task N". Every step has the actual content.

**Type/symbol consistency:**
- Header declares: `roomrom_sprites_upload_chr`, `roomrom_sprites_load_palette`, `roomrom_sprites_spawn_link(short x, short y)`. Task 7 calls match exactly.
- `SPRITE_VRAM_TILE_BASE = 512` used in Tasks 3 and 5; `LINK_VRAM_TILE = SPRITE_VRAM_TILE_BASE + 0x60` derived in Task 5.
- `extern const unsigned char sprites_chr[7424]` matches `data/chr/sprites.c` declaration (verified during context exploration).
- `extern const unsigned char misc_palettes[1208]` matches the existing `ow_room_render_roomrom.c` extern.

No issues found.
