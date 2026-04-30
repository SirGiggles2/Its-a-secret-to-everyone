# RoomRom S3 — Walk Animation + 4-Facing

**Date:** 2026-04-30
**Status:** Draft, awaiting approval
**Predecessor:** 2026-04-30-roomrom-s2-link-movement-design.md (S2 closed at tag `roomrom-s2-closed`)
**Successors (planned):** S4 edge-triggered room transitions; S5 BG collision

## Goal

Make Link animate while walking, with 4 facings tracked across input releases. Replaces S2's static-frame placeholder. After S3, Link visually matches NES gameplay reference (allowing for Genesis CRAM color quantization).

## Non-goals

- BG collision (S5)
- Edge-triggered room transitions (S4)
- Variable speed / running
- Sword / item sprites
- Sub-pixel motion or fractional frame counters
- Multiple animation layers (e.g. shield bobbing)
- Diagonal facing (4 cardinal only; diagonal input picks H over V)

## Inputs

- `data/chr/common.c` — `common_chr[7616]`. Holds Link's gameplay tiles at 1:1 NES tile IDs.
- Down-direction tile IDs known from S1 /spritefix OAM dump (`/c/tmp/oam_full.txt`):
  - Standstill: TL=$58, BL=$59, TR=$0A, BR=$0B (no flip)
  - Walk:      TL=$5A, BL=$5B, TR=$08, BR=$09 (right column needs per-tile hflip vs standstill)
- Up/left/right tile IDs **not** known. T1 probe captures them by walking Link in each direction in BizHawk Zelda 1 and dumping OAM.

## Architecture

### Sprite module — pose model

Add a single new public entry:

```c
typedef enum {
    LINK_FACE_DOWN  = 0,
    LINK_FACE_UP    = 1,
    LINK_FACE_LEFT  = 2,
    LINK_FACE_RIGHT = 3
} link_face_t;

void roomrom_sprites_set_link_pose(short x, short y,
                                   link_face_t face, unsigned char frame);
```

`frame` is 0 or 1. `face` is one of the four cardinal directions. Anything else is undefined.

`roomrom_sprites_set_link_pos()` from S2 is **kept** as a thin wrapper that calls `_set_link_pose(x, y, LINK_FACE_DOWN, 0)`, so any non-main caller continues to compile. main.c will call `_set_link_pose` directly.

`roomrom_sprites_spawn_link()` is unchanged in signature; internally it now picks the (DOWN, 0) pose.

### VRAM layout

S3 reserves **32 tiles** for Link's poses (4 facings × 2 frames × 4 tiles). Lives at:

```
LINK_VRAM_TILE = COMMON_VRAM_TILE_BASE + COMMON_BLOCK_TILE_COUNT  /* = 936 + 238 = 1174 */
```

Pose `(face, frame)` occupies tiles `[LINK_VRAM_TILE + (face*2 + frame)*4 .. +3]` in Genesis 2x2 column-major (TL, BL, TR, BR).

### Pose definition table

In `roomrom_sprites.c`:

```c
typedef struct {
    unsigned char nes_ids[4];     /* TL, BL, TR, BR — NES tile IDs in common_chr */
    unsigned char per_tile_hflip; /* bitmask: bit 0 = TL flipped, bit 1 = BL, bit 2 = TR, bit 3 = BR */
} link_pose_def_t;

static const link_pose_def_t link_poses[8] = {
    /* DOWN  frame 0 */ { {0x58, 0x59, 0x0A, 0x0B}, 0x0 },
    /* DOWN  frame 1 */ { {0x5A, 0x5B, 0x08, 0x09}, 0xC }, /* TR+BR pre-hflipped (matches NES per-sprite hflip on right half) */
    /* UP    frame 0 */ { {0x??, 0x??, 0x??, 0x??}, 0x? },
    /* UP    frame 1 */ { {0x??, 0x??, 0x??, 0x??}, 0x? },
    /* LEFT  frame 0 */ { {0x??, 0x??, 0x??, 0x??}, 0x? },
    /* LEFT  frame 1 */ { {0x??, 0x??, 0x??, 0x??}, 0x? },
    /* RIGHT frame 0 */ { {0x??, 0x??, 0x??, 0x??}, 0x? },
    /* RIGHT frame 1 */ { {0x??, 0x??, 0x??, 0x??}, 0x? },
};
```

`?` cells filled by T1 probe. Two facings (LEFT or RIGHT) often share tiles; whichever is hflipped will set its `per_tile_hflip` to `0xF` (all four tiles flipped) to mirror the other facing's tiles. T1 decides the canonical side from the live OAM.

### Per-tile hflip baked at upload

`render_chr_upload` is byte-copy-only; it cannot flip. So the sprite module pre-flips bytes at upload time:

```c
static void chr_upload_maybe_flip(unsigned short vram_tile,
                                  const unsigned char *src, unsigned char flip)
{
    if (!flip) {
        render_chr_upload(vram_tile * 32u, src, 32u);
    } else {
        unsigned char buf[32];
        /* For each row r (4 bytes), reverse the 8 horizontal pixels. */
        unsigned char r;
        for (r = 0; r < 8; r++) {
            unsigned char b0 = src[r*4 + 0], b1 = src[r*4 + 1],
                          b2 = src[r*4 + 2], b3 = src[r*4 + 3];
            /* swap nibbles within each byte AND reverse byte order in the row */
            buf[r*4 + 0] = ((b3 & 0xF0) >> 4) | ((b3 & 0x0F) << 4);
            buf[r*4 + 1] = ((b2 & 0xF0) >> 4) | ((b2 & 0x0F) << 4);
            buf[r*4 + 2] = ((b1 & 0xF0) >> 4) | ((b1 & 0x0F) << 4);
            buf[r*4 + 3] = ((b0 & 0xF0) >> 4) | ((b0 & 0x0F) << 4);
        }
        render_chr_upload(vram_tile * 32u, buf, 32u);
    }
}
```

`_upload_chr()` iterates all 8 poses × 4 tiles, picks `nes_ids[i]` from `common_chr`, calls `chr_upload_maybe_flip` with the per-tile flip flag.

### main.c additions

State:

```c
static link_face_t s_link_face = LINK_FACE_DOWN;
static u8          s_link_frame = 0;
static u8          s_link_anim_tick = 0;
#define LINK_ANIM_PERIOD 8u
```

Per frame, replacing the current WALK-mode body:

```c
u16 dir = joy & (BUTTON_LEFT|BUTTON_RIGHT|BUTTON_UP|BUTTON_DOWN);

/* Update facing. Horizontal wins over vertical when both are pressed. */
if      (dir & BUTTON_LEFT)  s_link_face = LINK_FACE_LEFT;
else if (dir & BUTTON_RIGHT) s_link_face = LINK_FACE_RIGHT;
else if (dir & BUTTON_UP)    s_link_face = LINK_FACE_UP;
else if (dir & BUTTON_DOWN)  s_link_face = LINK_FACE_DOWN;

if (dir) {
    if (++s_link_anim_tick >= LINK_ANIM_PERIOD) {
        s_link_frame ^= 1u;
        s_link_anim_tick = 0;
    }
} else {
    s_link_frame = 0;
    s_link_anim_tick = 0;
}

/* Existing motion + clamp from S2. */
if (joy & BUTTON_LEFT)  s_link_x--;
if (joy & BUTTON_RIGHT) s_link_x++;
if (joy & BUTTON_UP)    s_link_y--;
if (joy & BUTTON_DOWN)  s_link_y++;
if (s_link_x < 0)   s_link_x = 0;
if (s_link_x > 240) s_link_x = 240;
if (s_link_y < 56)  s_link_y = 56;
if (s_link_y > 208) s_link_y = 208;

roomrom_sprites_set_link_pose(s_link_x, s_link_y, s_link_face, s_link_frame);
```

TELEPORT mode unchanged.

## Per-frame contract

`_set_link_pose()` writes `vdpSpriteCache[0]` and DMAs one entry. No SPR engine. Sprite-table coords still use SGDK's internal +0x80 offset — caller passes screen coords.

Sprite attribute fields:
- size = `SPRITE_SIZE(2,2)`
- priority = 1
- vflip = 0
- hflip = 0 (per-tile flips already baked into VRAM)
- tile-index = `LINK_VRAM_TILE + (face*2 + frame)*4`
- palette = PAL3
- link = 0

## Verification

S3 done when:

1. Build clean.
2. Boot: Link facing down standstill at (128, 88), pose `(DOWN, 0)`.
3. Hold Right 60 frames: Link's screen position increases by ~60 px, animation cycles between frame 0 and 1, sprite visibly alternates feet/arms.
4. Release Right, hold Down 30 frames: Link faces DOWN, walks.
5. Release, hold Up 30 frames: Link faces UP, walks.
6. Release, hold Left 30 frames: Link faces LEFT, walks.
7. Release all input for 30 frames: Link holds frame 0 of LEFT (last facing).
8. Side-by-side comparison with NES live capture in same direction: visually equivalent shape.
9. TELEPORT mode still works (X to switch, D-pad jumps rooms).

## File-level changes

| File | Action |
|---|---|
| `RoomRom/src/roomrom_sprites.h` | + `link_face_t` enum, + `_set_link_pose` decl |
| `RoomRom/src/roomrom_sprites.c` | + pose table, + `chr_upload_maybe_flip`, expand `_upload_chr` to 32 tiles, + `_set_link_pose` |
| `RoomRom/src/main.c` | + face/frame/tick state, replace WALK body with anim-aware logic |
| `RoomRom/probe_roomrom_link_visible.lua` | extend to capture each facing in turn |

## Spec self-review

- [x] No "TBD" outside the explicit T1 probe placeholders (`?` in pose table; rest of design is concrete)
- [x] Architecture matches existing module conventions
- [x] Sprite hflip mechanism explicitly handled (bake at upload, render with attr.hflip = 0)
- [x] Verify steps observable
- [x] Scope bounded
- [x] No silent behavior changes to TELEPORT mode or B/C/A/Start
