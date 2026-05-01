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
#define LINK_POSE_COUNT         8u   /* 4 facings x 2 frames */

/* Sword tiles follow Link's 32 pose tiles. 4 tiles total: 2 for UP, 2 for DOWN.
 * Each is an 8x16 sprite (1x2 in 8x8 tile units). */
#define SWORD_VRAM_TILE         (LINK_VRAM_TILE + LINK_POSE_COUNT * LINK_TILES_PER_POSE)
#define SWORD_TILES_PER_FACE    2u   /* 1 wide x 2 tall */
#define SWORD_FACE_COUNT        2u   /* UP, DOWN — LEFT/RIGHT TODO */
#define SWORD_NES_TILE_UP_TOP   0x20u  /* blade tip pointing up */
#define SWORD_NES_TILE_UP_BOT   0x21u  /* guard + handle */
#define SWORD_NES_TILE_DN_TOP   0x22u  /* handle + guard */
#define SWORD_NES_TILE_DN_BOT   0x23u  /* blade tip pointing down */

typedef struct {
    unsigned char nes_ids[4];     /* TL, BL, TR, BR (Genesis 2x2 column-major) */
    unsigned char per_tile_hflip; /* bitmask: bit 0 = TL flipped, bit 1 = BL, etc. */
} link_pose_def_t;

/* Pose table values from /spritefix NES live OAM capture (S3 plan T1).
 * pose_index = face*2 + frame. Down values cross-checked against S1
 * findings. UP/LEFT/RIGHT captured 2026-04-30 from BizHawk Z1 gameplay. */
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

void roomrom_sprites_upload_chr(void)
{
    /* OW enemy sprite block. */
    render_chr_upload((unsigned short)(SPRITE_VRAM_TILE_BASE * 32u),
                      sprites_chr, SPRITE_CHR_BYTES);

    /* Common gameplay sprite block (Link, sword, hearts). */
    render_chr_upload((unsigned short)(COMMON_VRAM_TILE_BASE * 32u),
                      common_chr, COMMON_CHR_BYTES);

    /* Pre-upload all 8 Link poses (32 tiles), baking per-tile hflip
     * so render-side sprite hflip is always 0. */
    {
        unsigned char p, t, i;
        unsigned char buf[32];
        for (p = 0; p < LINK_POSE_COUNT; p++) {
            for (t = 0; t < LINK_TILES_PER_POSE; t++) {
                unsigned short nes_off = (unsigned short)link_poses[p].nes_ids[t] * 32u;
                for (i = 0; i < 32; i++) buf[i] = common_chr[nes_off + i];
                if (link_poses[p].per_tile_hflip & (1u << t)) {
                    hflip_tile_inplace(buf);
                }
                render_chr_upload(
                    (unsigned short)((LINK_VRAM_TILE + p*LINK_TILES_PER_POSE + t) * 32u),
                    buf, 32u);
            }
        }
    }

    /* S7: upload 4 sword tiles ($20-$23) starting at SWORD_VRAM_TILE.
     * Layout: tile 0 = UP top, 1 = UP bottom, 2 = DOWN top, 3 = DOWN bottom.
     * Tile IDs verified by ASCII decode of common_chr (RoomRom tools/out
     * common_chr_tiles_full.txt); see S7 spec design doc. */
    {
        static const unsigned char sword_nes[4] = {
            SWORD_NES_TILE_UP_TOP, SWORD_NES_TILE_UP_BOT,
            SWORD_NES_TILE_DN_TOP, SWORD_NES_TILE_DN_BOT
        };
        unsigned char i;
        for (i = 0; i < 4; i++) {
            unsigned short nes_off = (unsigned short)sword_nes[i] * 32u;
            render_chr_upload(
                (unsigned short)((SWORD_VRAM_TILE + i) * 32u),
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
    /* Slot 0 link = 1 so the chain reaches slot 1 (sword). Slot 1 stays
     * Y-hidden when sword is inactive. */
    VDP_setSpriteFull(0,
                      (s16)x,
                      (s16)y,
                      SPRITE_SIZE(2, 2),
                      /* Priority=0 (low) so HIGH-priority BG door tiles
                       * render in front of Link as he walks through. */
                      TILE_ATTR_FULL(PAL3, 0, 0, 0, tile),
                      1);
    VDP_updateSprites(2, DMA);
}

void roomrom_sprites_spawn_link(short x, short y)
{
    /* Init slot 1 (sword) to hidden, terminator link, before first link draw. */
    VDP_setSpriteFull(1,
                      (s16)-32,
                      (s16)-32,
                      SPRITE_SIZE(1, 2),
                      TILE_ATTR_FULL(PAL3, 0, 0, 0, SWORD_VRAM_TILE),
                      0);
    roomrom_sprites_set_link_pose(x, y, LINK_FACE_DOWN, 0u);
}

void roomrom_sprites_set_link_pos(short x, short y)
{
    roomrom_sprites_set_link_pose(x, y, LINK_FACE_DOWN, 0u);
}

/* Sword tile offsets within the SWORD_VRAM_TILE region. Each face is 2 tiles
 * (top + bottom of an 8x16 vertical sprite). */
#define SWORD_VRAM_UP   (SWORD_VRAM_TILE + 0u)  /* tiles 0,1 */
#define SWORD_VRAM_DN   (SWORD_VRAM_TILE + 2u)  /* tiles 2,3 */

void roomrom_sprites_set_sword_pose(link_face_t face, short x, short y)
{
    unsigned short tile;
    switch (face) {
    case LINK_FACE_UP:
        tile = SWORD_VRAM_UP;
        break;
    case LINK_FACE_DOWN:
        tile = SWORD_VRAM_DN;
        break;
    default:
        /* LEFT/RIGHT TODO — horizontal sword tiles not yet captured.
         * Hide sword for v1 by clearing. */
        roomrom_sprites_clear_sword();
        return;
    }
    VDP_setSpriteFull(1,
                      (s16)x,
                      (s16)y,
                      SPRITE_SIZE(1, 2),  /* 8 wide x 16 tall */
                      TILE_ATTR_FULL(PAL3, 0, 0, 0, tile),
                      0);                  /* terminator */
    VDP_updateSprites(2, DMA);
}

void roomrom_sprites_clear_sword(void)
{
    VDP_setSpriteFull(1,
                      (s16)-32,
                      (s16)-32,
                      SPRITE_SIZE(1, 2),
                      TILE_ATTR_FULL(PAL3, 0, 0, 0, SWORD_VRAM_TILE),
                      0);
    VDP_updateSprites(2, DMA);
}
