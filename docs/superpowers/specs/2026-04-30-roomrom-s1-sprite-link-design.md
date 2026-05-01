# RoomRom S1 — Sprite Scaffold + Static Link

**Date:** 2026-04-30
**Status:** Draft, awaiting approval
**Predecessors:** 2026-04-29-roomrom-overworld-design.md, 2026-04-29-roomrom-dungeon-viewer-design.md
**Successors (planned):** S2 movement, S3 edge-triggered room load, S4 collision

## Goal

Stand up the sprite/OAM pipeline in the RoomRom test harness and render a single static Link sprite over the BG plane in both OW and UW scenes. This unblocks every later subsystem that uses sprites (enemies, items, NPCs, projectiles).

S1 is intentionally minimal: one sprite, one frame, one fixed position. No movement, no animation, no collision. Subsequent slices add those.

## Non-goals (deferred)

- Link movement or animation (S2)
- Edge-of-room navigation that walks Link between rooms (S3)
- BG collision against solid tiles (S4 or skip — harness can stay noclip)
- Enemies, items, NPCs, projectiles
- Per-scene or per-room sprite palette swaps
- Sprite CHR streaming / banking
- HUD sprites (current HUD is BG-only)

## Inputs (already in tree)

- `data/chr/sprites.c` — 232 sprite tiles, **already in Genesis 4bpp format** (7424 bytes = 232 × 32). Confirmed via `data/chr/MANIFEST.json` block `"sprites"`.
- `data/chr/MANIFEST.json` — reserves global VRAM tile range 512..743 for the sprites block. BG renderer in RoomRom uses tile base 1 plus ~288 tiles; no overlap.
- NES sprite palette $3F10-$3F1F (Link's gameplay palette = sub-palette 0). Source: NES ROM (`Legend of Zelda, The (USA).nes`).

## Architecture

New module `RoomRom/src/roomrom_sprites.[ch]` mirroring the existing `roomrom_hud` and `roomrom_*_room_render` modules. Owns:

- One global VRAM region for sprite CHR (uploaded once at boot)
- One palette load into PAL3
- One `Sprite*` handle for Link (managed via SGDK `SPR_*` engine)
- A per-frame `update()` entry that wraps `SPR_update()`

`render_adapter_sgdk.c` is reused for CHR upload — no changes to the renderer ABI.

`main.c` integrates the module at three points only:

1. After `init_video()` and `upload_scene_chr()`: call `roomrom_sprites_init()`, `_upload_chr()`, `_load_palette()`, `_spawn_link()`.
2. Top of main loop after `SYS_doVBlankProcess()`: call `roomrom_sprites_update()`.
3. No changes to `load_room()`, scene/level/quest toggles, or D-pad navigation. Link state is independent of room state.

### Why a dedicated module

- Matches the codebase's per-subsystem split (one module per concern: BG render, HUD, sprites).
- Keeps `main.c` a thin harness — no SPR_* calls leak in.
- Future S2/S3/S4 slices extend the module, not `main.c`.
- Makes it trivial to drop the module later if sprite handling moves into a more general scene system.

## Module API

```c
/* RoomRom/src/roomrom_sprites.h */
#ifndef ROOMROM_SPRITES_H
#define ROOMROM_SPRITES_H

void roomrom_sprites_init(void);          /* one-shot: SPR_init() */
void roomrom_sprites_upload_chr(void);    /* one-shot: sprites_chr -> VRAM */
void roomrom_sprites_load_palette(void);  /* one-shot: NES spr pal 0 -> PAL3 */
void roomrom_sprites_spawn_link(short x, short y);
void roomrom_sprites_update(void);        /* per-frame: SPR_update() */

#endif
```

S1 deliberately exposes no setter for Link position beyond `_spawn_link`. S2 will add `_set_link_pos`.

## VRAM and palette plan

| Region | Tile range | Source | Lifetime |
|---|---|---|---|
| BG common + scene | tiles 1..~320 | existing OW/UW pipeline | reloaded on scene/ROM toggle |
| **Sprites (new)** | tiles 512..743 | `sprites_chr[7424]` | uploaded once at boot, never reloaded |

| Palette | Use | Lifetime |
|---|---|---|
| PAL0 | room BG (existing) | per-room |
| PAL1 | room BG (existing) | per-room |
| PAL2 | HUD (existing) | static after boot |
| **PAL3 (revised)** | Link sprite | overwritten at boot AND after every `load_room()` call |

**PAL3 conflict:** The BG renderer (`roomrom_ow_room_render_load_palette`) writes all four palette slots 0..3 from the NES level info, so PAL3 is currently a BG sub-palette. The fix is to modify the OW and UW BG palette loaders to write slots 0..2 only, freeing PAL3 for sprites. NES BG sub-palette 3 is rarely referenced in the OW/UW attribute tables; if any room shows a BG color regression after the change, that room will be flagged at verify and remapped in a follow-up. This is the long-term-correct split: BG owns PAL0..PAL2, sprites own PAL3.

## Link sprite definition

- Size: 16x16 px = 2×2 Genesis 8x8 tiles, equivalent to NES "8x16" Link.
- Frame for S1: facing-down standstill (canonical Link pose).
- NES tile IDs (sprites block): `0x60, 0x61, 0x70, 0x71` — top-left, top-right, bottom-left, bottom-right.
- Genesis VRAM tile indices: `512 + nes_tile_id`.
- Attribute: `TILE_ATTR_FULL(PAL3, 0 /*priority*/, 0 /*vflip*/, 0 /*hflip*/, 512 + 0x60)`.
  Priority **0** (low) per the door-priority design (`2026-04-30-roomrom-uw-door-priority-design.md`):
  Plane A door arch cells are tagged high-prio so they occlude Link; sprite
  stays low so it draws over low-prio walls/floor (sprite low > plane A low
  in the Genesis VDP layer order).
- Position: room center, screen coords `(128, 88)`. SGDK applies sprite-table Y/X offsets internally; we pass screen-space.

Implementation uses **raw VDP sprite table** (`VDP_setSprite` + `VDP_updateSprites`):

- `VDP_setSprite(0, x+0x80, y+0x80, SPRITE_SIZE(2,2), TILE_ATTR_FULL(PAL3, 0, 0, 0, 512+0x60), 0)`
- `VDP_updateSprites(1, DMA)` — DMA the single-entry sprite cache to VRAM
- One link entry, terminator at index 0 (`linkData = 0`)

S1 picks raw VDP over the SGDK `SPR_*` engine because:
- Single static sprite — no link-list management needed
- Matches the codebase's existing pattern of using SGDK as a thin VDP wrapper (the BG path uses `VDP_setTileMapXY` / `VDP_loadTileData` directly, not `MAP_*` engines)
- No `SpriteDefinition` / `Animation` / `TileSet` boilerplate for a one-frame sprite
- The SGDK `SPR_*` engine becomes the right choice in S2+ when Link animates and enemies are added; can be adopted then with no S1 rewrite (raw VDP and SPR engine coexist)

## Per-frame contract

S1 sprite is static, so no per-frame work is required after spawn. `VDP_updateSprites(1, DMA)` is called once inside `roomrom_sprites_spawn_link()`. The main loop is unchanged.

```c
while (TRUE) {
    SYS_doVBlankProcess();
    /* existing input + load_room logic, unchanged */
}
```

S2 will introduce a per-frame update entry when Link starts moving / animating.

After every `load_room()` call (including scene/ROM/level/quest toggles), `roomrom_sprites_load_palette()` must be called to re-write PAL3, because the BG palette loader runs first inside `load_room()` — see the PAL3 conflict note above. The sprite CHR upload itself is one-shot at boot and does not need replay.

## Verification

S1 is done when all of:

1. `RoomRom/build.bat` produces a clean ROM.
2. ROM boots to OW room `0x77`, BG renders as before.
3. Link 16x16 sprite visible at screen `(128, 88)` with correct palette (green tunic, peach skin, white shield highlights).
4. **B** toggle to UW: Link still visible, no palette corruption, BG still correct.
5. **C/A/Start** toggles (ROM variant, level cycle, quest toggle): Link persists across all of them.
6. BizHawk Lua probe captures one screenshot per scene with Link in frame; PNG inspected via Read.
7. No regressions in existing OW/UW BG parity (spot-check L1 entry + worldmap room 0x77).

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| BG renderer overwrites PAL3 (confirmed) | Modify `roomrom_ow_room_render_load_palette` and `roomrom_uw_room_render_load_palette` to write slots 0..2 only. Sprite module owns PAL3. Re-load sprite palette after every `load_room()` for safety. Spot-check OW + UW rooms for any tile that was using BG sub-palette 3; remap if visually broken. |
| Sprite Y/X coordinate offset confusion (SGDK adds +128 internally) | S1 verification step explicitly checks Link is on-screen at `(128,88)`, not off-screen. If hidden, adjust by the documented SGDK offset. |
| `sprites_chr` byte alignment for `VDP_loadTileData` | `render_chr_upload` already handles unaligned source via per-tile copy through aligned buffer. Reuse it. |
| Palette source for Link not yet captured from NES ROM | Hard-code from canonical Zelda 1 sprite palette 0: `$0F, $30, $16, $06` for sub-pal 0; populate other 12 colors with NES sprite sub-palettes 1..3 ($3F14..$3F1F) for completeness. Capture-from-ROM probe is non-blocking for S1. |
| Future scene-driven sprite palette swap not designed in S1 | Acceptable. S1 picks one fixed palette. S2 or later introduces swap when first non-Link sprite needs a different palette. |

## File-level changes

- **New:** `RoomRom/src/roomrom_sprites.c`
- **New:** `RoomRom/src/roomrom_sprites.h`
- **Edit:** `RoomRom/src/main.c` — add 4 init calls + 1 per-frame call
- **Edit:** `RoomRom/build.bat` — add `roomrom_sprites.c` to the source list (or whatever the existing build script does for new sources)
- **Edit (linker / object glob):** confirm new `.c` is picked up; add explicitly if build is not glob-based.
- **Probe (optional):** `RoomRom/probe_roomrom_link_visible.lua` — auto-screenshot OW + UW with Link visible for verification.

## Spec self-review

- [x] No "TBD" or placeholders
- [x] PAL3 vs PAL2 contingency stated explicitly (mitigation, not unresolved)
- [x] Verify steps concrete and observable
- [x] Scope bounded to one slice; S2/S3/S4 named but not specified here
- [x] Architecture matches existing module conventions (verified against `roomrom_hud`, `roomrom_*_room_render`)
- [x] No ambiguous requirements (every "Link visible" claim is paired with a specific coord and palette expectation)
