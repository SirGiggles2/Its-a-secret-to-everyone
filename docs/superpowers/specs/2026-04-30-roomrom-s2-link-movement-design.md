# RoomRom S2 — Link Movement + Clean Tile Sourcing

**Date:** 2026-04-30
**Status:** Draft, awaiting approval
**Predecessor:** 2026-04-30-roomrom-s1-sprite-link-design.md (S1 closed at tag `roomrom-s1-closed`)
**Successors (planned):** S3 walk animation + 4-dir frames; S4 edge-triggered room load; S5 BG collision

## Goal

Two outcomes in one small slice:

1. Stop carrying the surgical `link_down_chr[128]` embed from S1. Source Link tiles from the already-extracted `data/chr/common.c` block, which contains the canonical NES "CommonSpritePatterns" data (Link, sword, hearts) at 1:1 NES tile IDs.
2. Make Link move under D-pad input. Single static frame for now (animation is S3). Hard clamp to the playfield rectangle. No edge-triggered room transitions yet (those land in S4).

## Why this scope

- Removing the embed lets S3 (animation) trivially address every walking frame by NES tile ID against `common_chr`. No more per-frame manual conversion.
- Movement without animation is a known visual placeholder (Link slides), but is the cheapest way to validate the per-frame sprite-position update path before adding tile streaming.
- Clamping vs. edge-load: edge-load needs a "neighboring room id" lookup that doesn't exist yet for OW or UW. S4 introduces it.

## Non-goals

- Walk animation, alternate facing frames, hflip
- BG-tile collision against solid map cells
- Edge-triggered room transitions
- Enemy / item sprites
- UW HUD palette regression remap (separate cleanup commit)
- Diagonal-blocked input (we accept diagonal in S2)
- Variable speed (Link walks 1 px/frame full stop)

## Inputs already in tree

- `data/chr/common.c` — `const unsigned char common_chr[7616]`, 238 tiles in NES tile-id order. Verified via offline diff: Link's facing-down standstill lives at `common_chr + 0x58*32` (TL), `+0x59*32` (BL), `+0x0A*32` (TR), `+0x0B*32` (BR).
- `data/chr/MANIFEST.json` — `common` block has `genesis_vram_tile_start: 936`. Use this as the VRAM base for the upload.
- `RoomRom/build.bat` already compiles and links `data/chr/common.c` (line 119-121). No build edits needed.

## Architecture

### `RoomRom/src/roomrom_sprites.[ch]`

Header gains one entry point:

```c
void roomrom_sprites_set_link_pos(short x, short y);
```

Internal changes:

- `extern const unsigned char common_chr[7616];` (replaces / sits alongside the existing `sprites_chr` extern).
- `link_down_chr[128]` is **deleted**. Link's 4 tiles are copied at boot from `common_chr` into a dedicated 4-tile VRAM region in Genesis 2x2 column-major order (TL, BL, TR, BR), same approach as S1 but with the source corrected.
- `roomrom_sprites_upload_chr()` uploads:
  - `common_chr` to VRAM tile **936** (per manifest).
  - Then the 4 Link tiles (NES `$58, $59, $0A, $0B`) into a dedicated `LINK_VRAM_TILE` region just past the existing sprite/common blocks.
- `roomrom_sprites_spawn_link(x, y)` retains its current role: write the sprite at the given coords once (called at boot).
- `roomrom_sprites_set_link_pos(x, y)` writes new coords each frame (used by main loop).

The dedicated 4-tile copy stays because `common_chr` stores Link's right-column tiles at non-contiguous NES IDs (`$0A/$0B`) versus left-column (`$58/$59`); Genesis sprite hardware reads `n, n+1, n+2, n+3` in column-major.

### `RoomRom/src/main.c`

State:
```c
static short s_link_x = 128;
static short s_link_y =  88;
```

Per frame, after `SYS_doVBlankProcess()`:
```c
u16 joy = JOY_readJoypad(JOY_1);
if (joy & BUTTON_LEFT)  s_link_x--;
if (joy & BUTTON_RIGHT) s_link_x++;
if (joy & BUTTON_UP)    s_link_y--;
if (joy & BUTTON_DOWN)  s_link_y++;
/* Clamp to playfield. */
if (s_link_x < 0)   s_link_x = 0;
if (s_link_x > 240) s_link_x = 240;
if (s_link_y < 32)  s_link_y = 32;   /* HUD eats top 32 px */
if (s_link_y > 208) s_link_y = 208;
roomrom_sprites_set_link_pos(s_link_x, s_link_y);
```

The existing edge-pressed D-pad → room jump block is **removed**. B/C/A/Start handlers are unchanged. Scene/ROM/level/quest toggles still work.

### Playfield bounds

| Bound | Value | Reason |
|---|---|---|
| `x_min` | 0 | room left edge |
| `x_max` | 240 | room right edge minus 16 (sprite width) |
| `y_min` | 32 | HUD reserves top 4 tiles |
| `y_max` | 208 | room bottom edge minus 16 (sprite height) |

## Per-frame contract

`SPR_update()` is not used (no SGDK SPR engine). `VDP_updateSprites(1, DMA)` runs **inside** `roomrom_sprites_set_link_pos()` so the sprite-cache write becomes visible after the next vblank. The main loop already calls `SYS_doVBlankProcess()` first; no ordering changes.

Sprite palette must still survive `load_room()` calls. The S1 reload-after-load_room logic stays.

## Verification

S2 is done when all of:

1. `RoomRom/build.bat` produces a clean ROM.
2. Boot: Link visible at room center (128, 88), green tunic, indistinguishable from S1 final result.
3. Hold Right for 60 frames: Link visibly at (188, 88), no tile corruption, no palette change.
4. Hold Down for 240 frames: Link clamps at y=208 (does not exit playfield bottom).
5. Hold Up for 240 frames at start: Link clamps at y=32 (does not enter HUD).
6. B/C/A/Start toggles: Link's position resets behavior is OK either way (S2 doesn't constrain), as long as Link is still visible after each toggle.
7. Compared against live NES screenshot at matching coordinate: same shape, same palette, recognizably-the-same Link.

## File-level changes

| File | Action |
|---|---|
| `RoomRom/src/roomrom_sprites.h` | add `_set_link_pos` decl |
| `RoomRom/src/roomrom_sprites.c` | replace `link_down_chr[128]` with `common_chr`-based 4-tile copy; add `_set_link_pos` |
| `RoomRom/src/main.c` | drop room-jump block; add Link x/y state + clamp + per-frame `_set_link_pos` |
| `RoomRom/build.bat` | no change (`common.c` already linked) |
| `RoomRom/probe_roomrom_link_visible.lua` | extend probe to hold Right then Down to verify movement + clamp |
| memory `project_chr_extractor_seam_bug.md` | rewrite: extractor not broken; Link gameplay tiles live in `common.c` |

## Risks

| Risk | Mitigation |
|---|---|
| `common_chr` extern collides with existing `data/chr/common.c` link unit (already in build) | Already linked successfully in S1; no new symbol added. Safe. |
| 1 px/frame at 60 Hz feels too fast vs. NES Zelda Link speed | NES Link walks at ~1 px/frame on a held D-pad. Match. If feels off in verify, halve to "tick every other frame." |
| Removing room-jump nav reduces tester convenience | Acceptable. C/A/Start toggles still let you change ROM/level/quest. Edge-load lands in S4 to restore the "see other rooms" capability via gameplay. |
| Sprite update ordering with HUD redraw on toggle | `_load_palette()` runs at tail of `load_room()`. Sprite position re-asserted on next frame anyway. No ordering issue. |
| Genesis VDP DMA every frame for sprite update is wasteful | One sprite cache entry written per frame, 8 bytes via DMA. Negligible. |

## Spec self-review

- [x] No "TBD" or placeholders
- [x] Every spec section has matching task hooks
- [x] Verify steps are observable (coords, clamps)
- [x] Scope bounded; S3 (anim) and S4 (edge-load) named but not specified here
- [x] Architecture matches existing module conventions
- [x] No ambiguity in clamp values, button mappings, tile sources
