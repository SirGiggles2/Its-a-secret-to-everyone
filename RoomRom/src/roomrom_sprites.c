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
#define LINK_TILES_PER_POSE     4u
#define LINK_POSE_COUNT         8u   /* 4 facings x 2 walk frames */

/* S7 v4: attack poses follow the 8 walk poses. 4 attack poses (one per
 * facing), 4 tiles each = 16 contiguous tiles. */
#define ATTACK_POSE_COUNT       4u
#define ATTACK_VRAM_TILE        (LINK_VRAM_TILE + LINK_POSE_COUNT * LINK_TILES_PER_POSE)

/* Sword tile data follows the attack poses. NES Z1 sword:
 *   Anim_ItemFrameTiles[0] = $20 (vertical 8x16, narrow / half-width)
 *   Anim_ItemFrameTiles[1] = $82 (horizontal 16x16, hflip-able)
 * Vertical: 2 8x8 tiles ($20 top + $21 bottom).
 * Horizontal: 4 8x8 tiles ($82+$83 left half, $84+$85 right half). */
#define SWORD_VERT_VRAM_TILE    (ATTACK_VRAM_TILE + ATTACK_POSE_COUNT * LINK_TILES_PER_POSE)
#define SWORD_VERT_TILE_COUNT   2u
#define SWORD_HORZ_VRAM_TILE    (SWORD_VERT_VRAM_TILE + SWORD_VERT_TILE_COUNT)
#define SWORD_HORZ_TILE_COUNT   4u

/* S7 v6 boomerang: 8 tiles ($36..$3D) for 3 frame shapes that overlap.
 * Frame 0 uses tiles offset 0..3 (= $36..$39), frame 1 offset 2..5
 * (= $38..$3B), frame 2 offset 4..7 (= $3A..$3D). Each frame is a
 * 16x16 wide sprite drawn as SPRITE_SIZE(2,2) column-major
 * TL/BL/TR/BR. */
#define BOOMERANG_VRAM_TILE     (SWORD_HORZ_VRAM_TILE + SWORD_HORZ_TILE_COUNT)
#define BOOMERANG_TILE_COUNT    8u

/* S7 v7 arrow: 6 tiles. Vertical = $28 + $29 (2 tiles, narrow 8x16),
 * horizontal = $86 + $87 + $88 + $89 (4 tiles, wide 16x16). */
#define ARROW_VERT_VRAM_TILE    (BOOMERANG_VRAM_TILE + BOOMERANG_TILE_COUNT)
#define ARROW_VERT_TILE_COUNT   2u
#define ARROW_HORZ_VRAM_TILE    (ARROW_VERT_VRAM_TILE + ARROW_VERT_TILE_COUNT)
#define ARROW_HORZ_TILE_COUNT   4u

/* S7 v8 bomb: 2 tiles for body ($24/$25, narrow 8x16) and 4 tiles
 * for explosion ($32/$33/$34/$35, wide 16x16). */
#define BOMB_VRAM_TILE          (ARROW_HORZ_VRAM_TILE + ARROW_HORZ_TILE_COUNT)
#define BOMB_TILE_COUNT         2u
#define EXPLOSION_VRAM_TILE     (BOMB_VRAM_TILE + BOMB_TILE_COUNT)
#define EXPLOSION_TILE_COUNT    4u

typedef struct {
    unsigned char nes_ids[4];     /* TL, BL, TR, BR (Genesis 2x2 column-major) */
    unsigned char per_tile_hflip; /* bitmask: bit 0 = TL flipped, bit 1 = BL, etc. */
} link_pose_def_t;

/* Walk poses. pose_index = face*2 + frame. Captured from NES live OAM. */
static const link_pose_def_t link_poses[LINK_POSE_COUNT] = {
    /* DOWN  frame 0 */ { {0x58u, 0x59u, 0x0Au, 0x0Bu}, 0x0u },
    /* DOWN  frame 1 */ { {0x5Au, 0x5Bu, 0x08u, 0x09u}, 0xCu },
    /* UP    frame 0 */ { {0x0Cu, 0x0Du, 0x0Eu, 0x0Fu}, 0x0u },
    /* UP    frame 1 */ { {0x0Eu, 0x0Fu, 0x0Cu, 0x0Du}, 0xFu },
    /* LEFT  frame 0 */ { {0x06u, 0x07u, 0x04u, 0x05u}, 0xFu },
    /* LEFT  frame 1 */ { {0x02u, 0x03u, 0x00u, 0x01u}, 0xFu },
    /* RIGHT frame 0 */ { {0x04u, 0x05u, 0x06u, 0x07u}, 0x0u },
    /* RIGHT frame 1 */ { {0x00u, 0x01u, 0x02u, 0x03u}, 0x0u },
};

/* Attack poses (Link wielding sword, body sprite changes during the swing
 * window — Z1 sets Player ObjState = $10 when WieldSword fires). NES tile
 * IDs from probe_nes_link_swing_capture.lua, 2026-04-30:
 *   DOWN: slot18=$14, slot19=$16, no flip
 *   UP  : slot18=$18, slot19=$1A, no flip
 *   LEFT: slot18=$12 hflip, slot19=$10 hflip (mirror of RIGHT)
 *   RIGHT:slot18=$10, slot19=$12, no flip
 * In 8x16 NES sprite mode, slot18 tile $XX expands to common_chr tiles
 * $XX (top) + $XX+1 (bottom). So 4 8x8 tiles per facing. */
static const link_pose_def_t attack_poses[ATTACK_POSE_COUNT] = {
    /* DOWN  */ { {0x14u, 0x15u, 0x16u, 0x17u}, 0x0u },
    /* UP    */ { {0x18u, 0x19u, 0x1Au, 0x1Bu}, 0x0u },
    /* LEFT  */ { {0x12u, 0x13u, 0x10u, 0x11u}, 0xFu },
    /* RIGHT */ { {0x10u, 0x11u, 0x12u, 0x13u}, 0x0u },
};

static unsigned short nes_to_cram(unsigned char nes_idx)
{
    unsigned short off = (unsigned short)(nes_idx & 0x3Fu) * 2u;
    return (unsigned short)misc_palettes[off]
         | ((unsigned short)misc_palettes[off + 1] << 8);
}

/* Horizontally flip a Genesis 4bpp 8x8 tile (32 bytes) in place.
 * Each row is 4 bytes (2 pixels per byte, high nibble = left pixel). */
static void hflip_tile_inplace(unsigned char *t)
{
    unsigned char r;
    for (r = 0; r < 8; r++) {
        unsigned char b0 = t[r*4 + 0], b1 = t[r*4 + 1],
                      b2 = t[r*4 + 2], b3 = t[r*4 + 3];
        t[r*4 + 0] = (unsigned char)(((b3 & 0xF0u) >> 4) | ((b3 & 0x0Fu) << 4));
        t[r*4 + 1] = (unsigned char)(((b2 & 0xF0u) >> 4) | ((b2 & 0x0Fu) << 4));
        t[r*4 + 2] = (unsigned char)(((b1 & 0xF0u) >> 4) | ((b1 & 0x0Fu) << 4));
        t[r*4 + 3] = (unsigned char)(((b0 & 0xF0u) >> 4) | ((b0 & 0x0Fu) << 4));
    }
}

/* Helper: upload one pose's 4 tiles into VRAM, baking per-tile hflip. */
static void upload_pose(unsigned short vram_tile_base,
                        const link_pose_def_t *pose)
{
    unsigned char t, i;
    unsigned char buf[32];
    for (t = 0; t < LINK_TILES_PER_POSE; t++) {
        unsigned short nes_off = (unsigned short)pose->nes_ids[t] * 32u;
        for (i = 0; i < 32; i++) buf[i] = common_chr[nes_off + i];
        if (pose->per_tile_hflip & (1u << t)) {
            hflip_tile_inplace(buf);
        }
        render_chr_upload(
            (unsigned short)((vram_tile_base + t) * 32u),
            buf, 32u);
    }
}

void roomrom_sprites_upload_chr(void)
{
    /* OW enemy sprite block. */
    render_chr_upload((unsigned short)(SPRITE_VRAM_TILE_BASE * 32u),
                      sprites_chr, SPRITE_CHR_BYTES);

    /* Common gameplay sprite block (Link, sword, hearts). */
    render_chr_upload((unsigned short)(COMMON_VRAM_TILE_BASE * 32u),
                      common_chr, COMMON_CHR_BYTES);

    /* Walk poses (32 tiles). */
    {
        unsigned char p;
        for (p = 0; p < LINK_POSE_COUNT; p++) {
            upload_pose(
                (unsigned short)(LINK_VRAM_TILE + p * LINK_TILES_PER_POSE),
                &link_poses[p]);
        }
    }

    /* Attack poses (16 tiles). */
    {
        unsigned char p;
        for (p = 0; p < ATTACK_POSE_COUNT; p++) {
            upload_pose(
                (unsigned short)(ATTACK_VRAM_TILE + p * LINK_TILES_PER_POSE),
                &attack_poses[p]);
        }
    }

    /* Sword vertical: 2 tiles ($20 top, $21 bottom) for the 8x16 narrow
     * sword used facing UP / DOWN. */
    {
        unsigned char i;
        unsigned char nes_ids[SWORD_VERT_TILE_COUNT] = { 0x20u, 0x21u };
        for (i = 0; i < SWORD_VERT_TILE_COUNT; i++) {
            unsigned short nes_off = (unsigned short)nes_ids[i] * 32u;
            render_chr_upload(
                (unsigned short)((SWORD_VERT_VRAM_TILE + i) * 32u),
                common_chr + nes_off, 32u);
        }
    }

    /* Sword horizontal: 4 tiles ($82, $83, $84, $85) for the 16x16
     * horizontal sword used facing LEFT / RIGHT. SGDK SPRITE_SIZE(2,2)
     * tile order is column-major: TL=$82, BL=$83, TR=$84, BR=$85. */
    {
        unsigned char i;
        unsigned char nes_ids[SWORD_HORZ_TILE_COUNT] = {
            0x82u, 0x83u, 0x84u, 0x85u
        };
        for (i = 0; i < SWORD_HORZ_TILE_COUNT; i++) {
            unsigned short nes_off = (unsigned short)nes_ids[i] * 32u;
            render_chr_upload(
                (unsigned short)((SWORD_HORZ_VRAM_TILE + i) * 32u),
                common_chr + nes_off, 32u);
        }
    }

    /* Boomerang: 8 contiguous tiles $36..$3D from common_chr. */
    {
        unsigned char i;
        for (i = 0; i < BOOMERANG_TILE_COUNT; i++) {
            unsigned char nes_id = (unsigned char)(0x36u + i);
            unsigned short nes_off = (unsigned short)nes_id * 32u;
            render_chr_upload(
                (unsigned short)((BOOMERANG_VRAM_TILE + i) * 32u),
                common_chr + nes_off, 32u);
        }
    }

    /* Arrow vertical: $28, $29. */
    {
        unsigned char ids[ARROW_VERT_TILE_COUNT] = { 0x28u, 0x29u };
        unsigned char i;
        for (i = 0; i < ARROW_VERT_TILE_COUNT; i++) {
            unsigned short nes_off = (unsigned short)ids[i] * 32u;
            render_chr_upload(
                (unsigned short)((ARROW_VERT_VRAM_TILE + i) * 32u),
                common_chr + nes_off, 32u);
        }
    }

    /* Arrow horizontal: $86, $87, $88, $89. */
    {
        unsigned char ids[ARROW_HORZ_TILE_COUNT] = { 0x86u, 0x87u, 0x88u, 0x89u };
        unsigned char i;
        for (i = 0; i < ARROW_HORZ_TILE_COUNT; i++) {
            unsigned short nes_off = (unsigned short)ids[i] * 32u;
            render_chr_upload(
                (unsigned short)((ARROW_HORZ_VRAM_TILE + i) * 32u),
                common_chr + nes_off, 32u);
        }
    }

    /* Bomb body: $24, $25. */
    {
        unsigned char ids[BOMB_TILE_COUNT] = { 0x24u, 0x25u };
        unsigned char i;
        for (i = 0; i < BOMB_TILE_COUNT; i++) {
            unsigned short nes_off = (unsigned short)ids[i] * 32u;
            render_chr_upload(
                (unsigned short)((BOMB_VRAM_TILE + i) * 32u),
                common_chr + nes_off, 32u);
        }
    }

    /* Explosion: $32, $33, $34, $35 (column-major TL/BL/TR/BR). */
    {
        unsigned char ids[EXPLOSION_TILE_COUNT] = { 0x32u, 0x33u, 0x34u, 0x35u };
        unsigned char i;
        for (i = 0; i < EXPLOSION_TILE_COUNT; i++) {
            unsigned short nes_off = (unsigned short)ids[i] * 32u;
            render_chr_upload(
                (unsigned short)((EXPLOSION_VRAM_TILE + i) * 32u),
                common_chr + nes_off, 32u);
        }
    }
}

void roomrom_sprites_load_palette(void)
{
    unsigned short pal16[16];
    unsigned char i;
    for (i = 0; i < 16; i++) pal16[i] = 0;
    pal16[0] = nes_to_cram(0x0Fu);
    pal16[1] = nes_to_cram(0x29u);
    pal16[2] = nes_to_cram(0x27u);
    pal16[3] = nes_to_cram(0x17u);
    render_load_palette(3 /* PAL3 */, pal16);
}

void roomrom_sprites_set_link_pose(short x, short y,
                                   link_face_t face, unsigned char frame)
{
    unsigned short pose_idx = (unsigned short)face * 2u + (unsigned short)frame;
    unsigned short tile = LINK_VRAM_TILE + pose_idx * LINK_TILES_PER_POSE;
    VDP_setSpriteFull(0,
                      (s16)x,
                      (s16)y,
                      SPRITE_SIZE(2, 2),
                      TILE_ATTR_FULL(PAL3, 0, 0, 0, tile),
                      1);
    VDP_updateSprites(2, DMA);
}

void roomrom_sprites_set_link_attack_pose(short x, short y, link_face_t face)
{
    unsigned short pose_idx = (unsigned short)face;
    unsigned short tile = ATTACK_VRAM_TILE + pose_idx * LINK_TILES_PER_POSE;
    VDP_setSpriteFull(0,
                      (s16)x,
                      (s16)y,
                      SPRITE_SIZE(2, 2),
                      TILE_ATTR_FULL(PAL3, 0, 0, 0, tile),
                      1);
    VDP_updateSprites(2, DMA);
}

void roomrom_sprites_spawn_link(short x, short y)
{
    /* SAT chain: 0 (Link) -> 1 (sword) -> 2 (beam) -> 3 (boomerang) -> end. */
    VDP_setSpriteFull(1,
                      (s16)-32,
                      (s16)-32,
                      SPRITE_SIZE(1, 2),
                      TILE_ATTR_FULL(PAL3, 0, 0, 0, SWORD_VERT_VRAM_TILE),
                      2);
    VDP_setSpriteFull(2,
                      (s16)-32,
                      (s16)-32,
                      SPRITE_SIZE(1, 2),
                      TILE_ATTR_FULL(PAL3, 0, 0, 0, SWORD_VERT_VRAM_TILE),
                      3);
    VDP_setSpriteFull(3,
                      (s16)-32,
                      (s16)-32,
                      SPRITE_SIZE(2, 2),
                      TILE_ATTR_FULL(PAL3, 0, 0, 0, BOOMERANG_VRAM_TILE),
                      4);
    VDP_setSpriteFull(4,
                      (s16)-32,
                      (s16)-32,
                      SPRITE_SIZE(1, 2),
                      TILE_ATTR_FULL(PAL3, 0, 0, 0, ARROW_VERT_VRAM_TILE),
                      5);
    VDP_setSpriteFull(5,
                      (s16)-32,
                      (s16)-32,
                      SPRITE_SIZE(1, 2),
                      TILE_ATTR_FULL(PAL3, 0, 0, 0, BOMB_VRAM_TILE),
                      6);
    VDP_setSpriteFull(6,
                      (s16)-32,
                      (s16)-32,
                      SPRITE_SIZE(2, 2),
                      TILE_ATTR_FULL(PAL3, 0, 0, 0, EXPLOSION_VRAM_TILE),
                      0);
    roomrom_sprites_set_link_pose(x, y, LINK_FACE_DOWN, 0u);
}

void roomrom_sprites_set_link_pos(short x, short y)
{
    roomrom_sprites_set_link_pose(x, y, LINK_FACE_DOWN, 0u);
}

void roomrom_sprites_set_sword_vertical(short x, short y, unsigned char vflip)
{
    VDP_setSpriteFull(1,
                      (s16)x,
                      (s16)y,
                      SPRITE_SIZE(1, 2),
                      TILE_ATTR_FULL(PAL3, 0, vflip, 0, SWORD_VERT_VRAM_TILE),
                      2);
    VDP_updateSprites(3, DMA);
}

void roomrom_sprites_set_sword_horizontal(short x, short y, unsigned char hflip)
{
    VDP_setSpriteFull(1,
                      (s16)x,
                      (s16)y,
                      SPRITE_SIZE(2, 2),
                      TILE_ATTR_FULL(PAL3, 0, 0, hflip, SWORD_HORZ_VRAM_TILE),
                      2);
    VDP_updateSprites(3, DMA);
}

void roomrom_sprites_clear_sword(void)
{
    VDP_setSpriteFull(1,
                      (s16)-32,
                      (s16)-32,
                      SPRITE_SIZE(1, 2),
                      TILE_ATTR_FULL(PAL3, 0, 0, 0, SWORD_VERT_VRAM_TILE),
                      2);
    VDP_updateSprites(3, DMA);
}

/* S7 v5 sword beam (slot 2). Reuses sword vertical/horizontal tiles.
 * NES Z1 cycles palette index each frame for a flash effect
 * (DrawSwordShotOrMagicShot, Z_07.asm:3459):
 *     ATTR = (FrameCounter & 3) | RDirectionToWeaponBaseAttribute[Y]
 * On Genesis, PAL0-2 hold BG colors so we can't cheaply rotate palette
 * index. Approximate by toggling vflip + hflip each frame (4 phases:
 * 0=no flip, 1=hflip, 2=vflip, 3=both). Visible flicker at the tile
 * silhouette level. */
void roomrom_sprites_set_beam(short x, short y,
                              unsigned char vertical,
                              unsigned char frame_phase)
{
    unsigned char vflip = (unsigned char)((frame_phase & 0x2u) ? 1u : 0u);
    unsigned char hflip = (unsigned char)((frame_phase & 0x1u) ? 1u : 0u);
    if (vertical) {
        VDP_setSpriteFull(2,
                          (s16)x,
                          (s16)y,
                          SPRITE_SIZE(1, 2),
                          TILE_ATTR_FULL(PAL3, 0, vflip, hflip,
                                         SWORD_VERT_VRAM_TILE),
                          3);
    } else {
        VDP_setSpriteFull(2,
                          (s16)x,
                          (s16)y,
                          SPRITE_SIZE(2, 2),
                          TILE_ATTR_FULL(PAL3, 0, vflip, hflip,
                                         SWORD_HORZ_VRAM_TILE),
                          3);
    }
    VDP_updateSprites(4, DMA);
}

void roomrom_sprites_clear_beam(void)
{
    VDP_setSpriteFull(2,
                      (s16)-32,
                      (s16)-32,
                      SPRITE_SIZE(1, 2),
                      TILE_ATTR_FULL(PAL3, 0, 0, 0, SWORD_VERT_VRAM_TILE),
                      3);
    VDP_updateSprites(4, DMA);
}

/* S7 v6 boomerang (slot 3). 8-phase rotation cycle from
 * BoomerangFrameCycle (0,1,2,1,0,1,2,1) and BoomerangBaseSpriteAttrCycle
 * ($00,$00,$00,$40,$40,$C0,$80,$80) at Z_07.asm:3779. */
static const unsigned char k_boomerang_frame_cycle[8] = {
    0u, 1u, 2u, 1u, 0u, 1u, 2u, 1u
};
static const unsigned char k_boomerang_attr_cycle[8] = {
    0x00u, 0x00u, 0x00u, 0x40u, 0x40u, 0xC0u, 0x80u, 0x80u
};

void roomrom_sprites_set_boomerang(short x, short y,
                                   unsigned char phase_idx)
{
    unsigned char p = (unsigned char)(phase_idx & 0x7u);
    unsigned char frame_n = k_boomerang_frame_cycle[p];   /* 0, 1, or 2 */
    unsigned char attr    = k_boomerang_attr_cycle[p];
    unsigned char vflip   = (unsigned char)((attr & 0x80u) ? 1u : 0u);
    unsigned char hflip   = (unsigned char)((attr & 0x40u) ? 1u : 0u);
    unsigned short tile   = (unsigned short)(BOOMERANG_VRAM_TILE
                                             + (frame_n * 2u));
    VDP_setSpriteFull(3,
                      (s16)x,
                      (s16)y,
                      SPRITE_SIZE(2, 2),
                      TILE_ATTR_FULL(PAL3, 0, vflip, hflip, tile),
                      4);
    VDP_updateSprites(5, DMA);
}

void roomrom_sprites_clear_boomerang(void)
{
    VDP_setSpriteFull(3,
                      (s16)-32,
                      (s16)-32,
                      SPRITE_SIZE(2, 2),
                      TILE_ATTR_FULL(PAL3, 0, 0, 0, BOOMERANG_VRAM_TILE),
                      4);
    VDP_updateSprites(5, DMA);
}

/* S7 v7 arrow (slot 4). Vertical 8x16 for UP/DOWN, horizontal 16x16
 * for LEFT/RIGHT (hflip on LEFT). */
void roomrom_sprites_set_arrow(short x, short y, link_face_t face)
{
    switch (face) {
    case LINK_FACE_UP:
        VDP_setSpriteFull(4, (s16)x, (s16)y, SPRITE_SIZE(1, 2),
                          TILE_ATTR_FULL(PAL3, 0, 0, 0,
                                         ARROW_VERT_VRAM_TILE),
                          5);
        break;
    case LINK_FACE_DOWN:
        VDP_setSpriteFull(4, (s16)x, (s16)y, SPRITE_SIZE(1, 2),
                          TILE_ATTR_FULL(PAL3, 0, 1, 0,
                                         ARROW_VERT_VRAM_TILE),
                          5);
        break;
    case LINK_FACE_LEFT:
    case LINK_FACE_RIGHT:
    default:
        /* Horizontal arrow tiles ($86-$89) live in a Z1 CHR-bank that
         * isn't part of the always-loaded common_chr Genesis blob.
         * Until those bytes are extracted, hide LEFT/RIGHT arrow
         * rather than render the wrong tiles (which would be HUD
         * letters at common_chr tile offsets $86-$89). */
        roomrom_sprites_clear_arrow();
        return;
    }
    VDP_updateSprites(5, DMA);
}

void roomrom_sprites_clear_arrow(void)
{
    VDP_setSpriteFull(4,
                      (s16)-32,
                      (s16)-32,
                      SPRITE_SIZE(1, 2),
                      TILE_ATTR_FULL(PAL3, 0, 0, 0, ARROW_VERT_VRAM_TILE),
                      5);
    VDP_updateSprites(7, DMA);
}

/* S7 v8 bomb (slot 5). 8x16 sprite at fuse position. */
void roomrom_sprites_set_bomb(short x, short y)
{
    VDP_setSpriteFull(5,
                      (s16)x,
                      (s16)y,
                      SPRITE_SIZE(1, 2),
                      TILE_ATTR_FULL(PAL3, 0, 0, 0, BOMB_VRAM_TILE),
                      6);
    VDP_updateSprites(7, DMA);
}

void roomrom_sprites_clear_bomb(void)
{
    VDP_setSpriteFull(5,
                      (s16)-32,
                      (s16)-32,
                      SPRITE_SIZE(1, 2),
                      TILE_ATTR_FULL(PAL3, 0, 0, 0, BOMB_VRAM_TILE),
                      6);
    VDP_updateSprites(7, DMA);
}

/* S7 v8 explosion (slot 6). 16x16 sprite. timer is the residual frame
 * countdown — animate by toggling vflip+hflip every 4 frames so the
 * burst looks lively without needing extra tile data. */
void roomrom_sprites_set_explosion(short x, short y, unsigned char timer)
{
    unsigned char phase = (unsigned char)((timer >> 2) & 0x3u);
    unsigned char vflip = (unsigned char)((phase & 0x2u) ? 1u : 0u);
    unsigned char hflip = (unsigned char)((phase & 0x1u) ? 1u : 0u);
    /* Anchor the 16x16 explosion sprite so its center aligns with the
     * 8x16 bomb position. Bomb's top-left was at (x, y); shift the
     * 16x16 explosion 4 px left and 0 px up so its center coincides. */
    short ex = (short)(x - 4);
    VDP_setSpriteFull(6,
                      (s16)ex,
                      (s16)y,
                      SPRITE_SIZE(2, 2),
                      TILE_ATTR_FULL(PAL3, 0, vflip, hflip,
                                     EXPLOSION_VRAM_TILE),
                      0);
    VDP_updateSprites(7, DMA);
}

void roomrom_sprites_clear_explosion(void)
{
    VDP_setSpriteFull(6,
                      (s16)-32,
                      (s16)-32,
                      SPRITE_SIZE(2, 2),
                      TILE_ATTR_FULL(PAL3, 0, 0, 0, EXPLOSION_VRAM_TILE),
                      0);
    VDP_updateSprites(7, DMA);
}
