#include <genesis.h>
#include "roomrom_sprites.h"
#include "render_abi.h"
#include "roomrom_item_chr.h"
#include "roomrom_vram_map.h"
/* FU3: renderer reads from atlas/items_chr_x4 (byte-identical to legacy
 * expanded_sprite_chr via FU2).  ROOMROM_ITEM_TILE_* tile-index constants
 * stay sourced from roomrom_item_chr.h (the 8-item legacy manifest header)
 * because item tile indices into the blob are the same in both pipelines.
 * P4a: atlas headers for ATLAS_ASSERT_SIZE and named dispatch constants. */
#include "atlas/items_chr_x4.h"
#include "atlas/items_chr.h"
#include "atlas/atlas_dispatch.h"

/* Compile-time dispatch size checks for items that have a direct 1:1
 * atlas entry with matching single-tile W/H (SPRITE_SIZE(1,1)):
 * BOMB   -> SPRITE_SIZE(1,1)  -> W_BOMB=1, H_BOMB=1   (NES_NARROW) */
ATLAS_ASSERT_SIZE(BOMB, 1, 1);
/* BOOMERANG -> SPRITE_SIZE(1,1) -> W_BOOMERANG=1, H_BOOMERANG=1 (NES_NARROW) */
ATLAS_ASSERT_SIZE(BOOMERANG, 1, 1);

/* TODO(Phase 6 cleanup): add ATLAS_ASSERT_SIZE for sword_vert/horz,
 * arrow_vert/horz, explosion, sword_diag once items_chr.h gains multi-tile
 * W/H dispatch entries for those draw rules (NES_NARROW 1x2, NES_SLIM 2x1).
 * Also replace ROOMROM_ITEM_TILE_* tile-index expressions with
 * ROOMROM_ATLAS_ITEMS_<NAME>_OFFSET / 32 once the atlas ordering is
 * reconciled with the legacy blob ordering. */

/* P4b: Link renderer migration - DEFERRED.
 * link_chr.h now emits W_x/H_x dispatch defines (FU1). However, the Link
 * upload path still reads tiles from common_chr via upload_pose(); the atlas
 * link_chr.c blob is not compiled into the build.  ATLAS_ASSERT_SIZE for
 * Link poses is deferred until the upload path switches to atlas/link_chr.
 *
 * TODO(Phase-4b / Phase 6): switch upload_pose() to read from atlas/link_chr;
 * replace LINK_VRAM_TILE + pose offsets with
 *   ROOMROM_LINK_TILE_BASE + ROOMROM_ATLAS_LINK_<POSE>_OFFSET / 32
 * and add ATLAS_ASSERT_SIZE(FACE_DOWN_F1, 2, 2) etc. per-pose. */

/* Sprite CHR source.
 * common_chr (data/chr/common.c) holds the always-loaded sprites including
 * Link, sword, heart. sprites_chr (OW enemies) is OUT-OF-SCOPE for RoomRom
 * currently and is no longer uploaded -- frees ~232 tiles in the SPR bank.
 * NES tile IDs in common_chr are 1:1 (NES tile $58 = common_chr + 0x58*32). */
extern const unsigned char common_chr[7616];

#define COMMON_VRAM_TILE_BASE   ROOMROM_SPR_TILE_BASE
#define COMMON_CHR_BYTES        7616u
#define COMMON_BLOCK_TILE_COUNT 238u

#define LINK_VRAM_TILE          (COMMON_VRAM_TILE_BASE + COMMON_BLOCK_TILE_COUNT)
#define LINK_TILES_PER_POSE     4u
#define LINK_POSE_COUNT         8u   /* 4 facings x 2 walk frames */

/* S7 v4: attack poses follow the 8 walk poses. 4 attack poses (one per
 * facing), 4 tiles each = 16 contiguous tiles. */
#define ATTACK_POSE_COUNT       4u
#define ATTACK_VRAM_TILE        (LINK_VRAM_TILE + LINK_POSE_COUNT * LINK_TILES_PER_POSE)

/* Phase 1: item atlas tiles live in their own contiguous block starting
 * after Link attack poses. Tile offsets come from the live NES item CHR
 * generator (RoomRom/src/roomrom_item_chr.h). Replaces the old guessed
 * common_chr-sourced literals at $82..$89 / $36..$3D / etc. */
#define ITEM_VRAM_TILE          (ATTACK_VRAM_TILE + ATTACK_POSE_COUNT * LINK_TILES_PER_POSE)

#define SWORD_VERT_VRAM_TILE    (ITEM_VRAM_TILE + ROOMROM_ITEM_TILE_SWORD_VERT)
#define SWORD_HORZ_VRAM_TILE    (ITEM_VRAM_TILE + ROOMROM_ITEM_TILE_SWORD_HORZ)
#define BOOMERANG_VRAM_TILE     (ITEM_VRAM_TILE + ROOMROM_ITEM_TILE_BOOMERANG)
#define ARROW_VERT_VRAM_TILE    (ITEM_VRAM_TILE + ROOMROM_ITEM_TILE_ARROW_VERT)
#define ARROW_HORZ_VRAM_TILE    (ITEM_VRAM_TILE + ROOMROM_ITEM_TILE_ARROW_HORZ)
#define BOMB_VRAM_TILE          (ITEM_VRAM_TILE + ROOMROM_ITEM_TILE_BOMB)
#define EXPLOSION_VRAM_TILE     (ITEM_VRAM_TILE + ROOMROM_ITEM_TILE_EXPLOSION)
#define SWORD_DIAG_VRAM_TILE    (ITEM_VRAM_TILE + ROOMROM_ITEM_TILE_SWORD_DIAG)

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

/* Phase 1: item-atlas variant selector. 0 = orig, 1 = redux. Read at
 * upload time by roomrom_sprites_upload_chr to pick the correct slice
 * of roomrom_item_chr[][]. */
static unsigned char s_item_chr_variant = 0u;  /* ROOMROM_ITEM_VARIANT_ORIG */

void roomrom_sprites_set_redux(unsigned char redux)
{
    s_item_chr_variant = redux ? 1u : 0u;
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
#ifndef COMMON_SPRITE_PATTERN_TILE_COUNT
/* NES Z1 always-loaded sprite pattern block: tiles 0x00..0x6F (= 112)
 * are the canonical Link/Sword/Boomerang/etc. CHR. Any pose tile_id
 * >= 112 means the source CHR isn't in common_chr — should be sourced
 * from item atlas (Phase 1) or a future per-room CHR slot. Filling
 * with zeros prevents accidental garbage from extractor over-reach. */
#define COMMON_SPRITE_PATTERN_TILE_COUNT 112u
#endif

static void upload_pose(unsigned short vram_tile_base,
                        const link_pose_def_t *pose)
{
    unsigned char t, i;
    unsigned char buf[32];
    for (t = 0; t < LINK_TILES_PER_POSE; t++) {
        unsigned short nes_off = (unsigned short)pose->nes_ids[t] * 32u;
        if (pose->nes_ids[t] >= COMMON_SPRITE_PATTERN_TILE_COUNT) {
            for (i = 0; i < 32; i++) buf[i] = 0;
        } else {
            for (i = 0; i < 32; i++) buf[i] = common_chr[nes_off + i];
        }
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
    /* Phase 3: sprite bank is 1x (sub-pal 0 only). sprites_chr (OW
     * enemies) deferred -- not uploaded. Common gameplay sprite block
     * (Link, sword, hearts) goes first. */
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

    /* FU3 (atlas pipeline): 4 sub-pal copies of the item atlas from the
     * atlas/items_chr_x4 blob (byte-identical to legacy expanded_sprite_chr
     * via gen_atlas.py FU2).  Blob layout: pal0_bytes||pal1_bytes||
     * pal2_bytes||pal3_bytes; per-pal stride =
     * ROOMROM_ATLAS_ITEMS_X4_PER_PAL_BYTES.
     *
     * Link / sword body / common sprite tiles continue to upload to the
     * 1x SPR bank above; only the item atlas gets the 4x treatment. */
    {
        unsigned short variant = s_item_chr_variant;
        unsigned char  s;
        for (s = 0; s < 4u; s++) {
            unsigned short vram_tile = (unsigned short)ROOMROM_ITEM_TILE_BASE_PAL(s);
            unsigned long  blob_off  = (unsigned long)(ROOMROM_ATLAS_ITEMS_X4_PER_PAL_BYTES)
                                       * (unsigned long)s;
            render_chr_upload(
                (unsigned short)(vram_tile * 32u),
                &roomrom_atlas_items_x4[variant][blob_off],
                (unsigned short)ROOMROM_ATLAS_ITEMS_X4_PER_PAL_BYTES
            );
        }
    }
}

void roomrom_sprites_load_palette(void)
{
    /* Phase 4: PAL1 holds NES sprite PALRAM, loaded by the BG palette path
     * (roomrom_bg_palette_load_palram_full writes PAL0 + PAL1 from full
     * 32-byte NES PALRAM). This stub kept for ABI compatibility with
     * existing call sites. */
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
                      TILE_ATTR_FULL(PAL1,0, 0, 0, tile),
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
                      TILE_ATTR_FULL(PAL1,0, 0, 0, tile),
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
                      TILE_ATTR_FULL(PAL1,0, 0, 0, SWORD_VERT_VRAM_TILE),
                      2);
    VDP_setSpriteFull(2,
                      (s16)-32,
                      (s16)-32,
                      SPRITE_SIZE(1, 1),
                      TILE_ATTR_FULL(PAL2,0, 0, 0, SWORD_VERT_VRAM_TILE),
                      3);
    VDP_setSpriteFull(3,
                      (s16)-32,
                      (s16)-32,
                      SPRITE_SIZE(1, 1),
                      TILE_ATTR_FULL(PAL1,0, 0, 0, BOOMERANG_VRAM_TILE),
                      4);
    VDP_setSpriteFull(4,
                      (s16)-32,
                      (s16)-32,
                      SPRITE_SIZE(1, 2),
                      TILE_ATTR_FULL(PAL1,0, 0, 0, ARROW_VERT_VRAM_TILE),
                      5);
    VDP_setSpriteFull(5,
                      (s16)-32,
                      (s16)-32,
                      SPRITE_SIZE(1, 1),
                      TILE_ATTR_FULL(PAL1,0, 0, 0, BOMB_VRAM_TILE),
                      6);
    VDP_setSpriteFull(6,
                      (s16)-32,
                      (s16)-32,
                      SPRITE_SIZE(2, 1),
                      TILE_ATTR_FULL(PAL1,0, 0, 0, EXPLOSION_VRAM_TILE),
                      0);
    roomrom_sprites_set_link_pose(x, y, LINK_FACE_DOWN, 0u);
}

void roomrom_sprites_set_link_pos(short x, short y)
{
    roomrom_sprites_set_link_pose(x, y, LINK_FACE_DOWN, 0u);
}

void roomrom_sprites_set_sword_vertical(short x, short y, unsigned char vflip,
                                        unsigned char sub_pal)
{
    unsigned short tile = (unsigned short)(ROOMROM_ITEM_TILE_BASE_PAL(sub_pal)
                                           + ROOMROM_ITEM_TILE_SWORD_VERT);
    VDP_setSpriteFull(1,
                      (s16)x,
                      (s16)y,
                      SPRITE_SIZE(1, 2),
                      TILE_ATTR_FULL(PAL1,0, vflip, 0, tile),
                      2);
    VDP_updateSprites(3, DMA);
}

void roomrom_sprites_set_sword_horizontal(short x, short y, unsigned char hflip,
                                          unsigned char sub_pal)
{
    unsigned short tile = (unsigned short)(ROOMROM_ITEM_TILE_BASE_PAL(sub_pal)
                                           + ROOMROM_ITEM_TILE_SWORD_HORZ);
    VDP_setSpriteFull(1,
                      (s16)x,
                      (s16)y,
                      SPRITE_SIZE(2, 2),
                      TILE_ATTR_FULL(PAL1,0, 0, hflip, tile),
                      2);
    VDP_updateSprites(3, DMA);
}

void roomrom_sprites_clear_sword(void)
{
    VDP_setSpriteFull(1,
                      (s16)-32,
                      (s16)-32,
                      SPRITE_SIZE(1, 2),
                      TILE_ATTR_FULL(PAL1,0, 0, 0, SWORD_VERT_VRAM_TILE),
                      2);
    VDP_updateSprites(3, DMA);
}

/* Redux ALttP-style diagonal sword. Per NES Anim_WriteItemSprites,
 * tiles in [$20,$62) take the @Narrow path which draws ONE 8x16 sprite
 * (not 16x16). Tile $48 + auto-paired $49 only. */
void roomrom_sprites_set_sword_diagonal(short x, short y,
                                        unsigned char hflip,
                                        unsigned char vflip,
                                        unsigned char sub_pal)
{
    unsigned short tile = (unsigned short)(ROOMROM_ITEM_TILE_BASE_PAL(sub_pal)
                                           + ROOMROM_ITEM_TILE_SWORD_DIAG);
    VDP_setSpriteFull(1,
                      (s16)x,
                      (s16)y,
                      SPRITE_SIZE(1, 2),
                      TILE_ATTR_FULL(PAL1,0, vflip, hflip, tile),
                      2);
    VDP_updateSprites(3, DMA);
}

/* S7 v5 sword beam (slot 2). NES Z1 sword shot draws via the same
 * Anim_WriteItemSprites path as the held sword (Z_07.asm:3437):
 *   - Vertical (UP/DOWN, RDirectionToWeaponFrame=0): tile $20, falls
 *     into @Narrow path → single 8x8 sprite. Base attr from
 *     RDirectionToWeaponBaseAttribute: UP=$00, DOWN=$80 (vflip).
 *   - Horizontal (LEFT/RIGHT, frame=1): tile $82, falls into @Wide /
 *     HorizontallyFlippableSpritePair → 2 8x8 sprites side-by-side
 *     (NES tiles $82 + $84). Base attr 0 for both; LEFT direction
 *     sets [0F]=1 in DrawSwordShotOrMagicShot:3471 to hflip the pair.
 *
 * Per Z_07.asm:3459 the per-frame attribute is
 *   ATTR = base | (FrameCounter & 3)
 * — the bottom 2 bits cycle palette index for a color flash. The
 * sprite SHAPE never flips or rotates between frames. On Genesis we
 * don't have 4 sprite palettes wired up to imitate the flash, so the
 * beam renders with a static palette and only the NES per-direction
 * base attribute. Better than the earlier vflip/hflip frame-cycle
 * approximation, which introduced an orientation flicker not present
 * on NES.
 *
 * Vertical beam = SPRITE_SIZE(1, 1) (8x8, NES-faithful single tile).
 * Horizontal beam keeps SPRITE_SIZE(2, 2): in column-major SGDK
 * iteration the top row of the sword_horz blob is NES tiles $82+$84
 * (the exact pair NES draws), and the bottom row holds the unused
 * sword_horz tiles $83+$85 — visually close enough until the CHR
 * blob is reshaped to a 16x8 layout. */
void roomrom_sprites_set_beam(short x, short y, link_face_t face)
{
    unsigned char vertical = (unsigned char)((face == LINK_FACE_UP
                                           || face == LINK_FACE_DOWN)
                                          ? 1u : 0u);
    unsigned char vflip = (unsigned char)((face == LINK_FACE_DOWN) ? 1u : 0u);
    unsigned char hflip = (unsigned char)((face == LINK_FACE_LEFT) ? 1u : 0u);
    /* Beam uses PAL2 (dedicated flash bank). roomrom_combat update_beam
     * rewrites PAL2[0..3] each frame with a different NES sprite sub-
     * palette to imitate Z1's color flash (Z_07.asm:3459). */
    if (vertical) {
        VDP_setSpriteFull(2,
                          (s16)x,
                          (s16)y,
                          SPRITE_SIZE(1, 1),
                          TILE_ATTR_FULL(PAL2,0, vflip, hflip,
                                         SWORD_VERT_VRAM_TILE),
                          3);
    } else {
        VDP_setSpriteFull(2,
                          (s16)x,
                          (s16)y,
                          SPRITE_SIZE(2, 2),
                          TILE_ATTR_FULL(PAL2,0, vflip, hflip,
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
                      SPRITE_SIZE(1, 1),
                      TILE_ATTR_FULL(PAL2,0, 0, 0, SWORD_VERT_VRAM_TILE),
                      3);
    VDP_updateSprites(4, DMA);
}

/* S7 v6 boomerang (slot 3). NES Z1 draws boomerang as a SINGLE 8x8
 * sprite via the @Narrow path in Anim_WriteSpecificItemSprites
 * (Z_01.asm:5279). Tile $36 is in [$20,$62), so $07 := 0 → only the
 * left half of the sprite pair is written. The "spin" comes from
 * cycling 3 frame tiles ($36/$38/$3A) and 4 flip combos ($00,$40,
 * $C0,$80) per BoomerangFrameCycle / BoomerangBaseSpriteAttrCycle
 * at Z_07.asm:3779.
 * Earlier code rendered SPRITE_SIZE(2,2) which packed 4 sequential
 * blob tiles into a 16x16 quad, producing the "two boomerangs"
 * visual ($37 + $39 are not part of frame 0 — they belong to other
 * animation phases). 8x8 single-tile is the NES-faithful shape. */
static const unsigned char k_boomerang_frame_cycle[8] = {
    0u, 1u, 2u, 1u, 0u, 1u, 2u, 1u
};
static const unsigned char k_boomerang_attr_cycle[8] = {
    0x00u, 0x00u, 0x00u, 0x40u, 0x40u, 0xC0u, 0x80u, 0x80u
};

void roomrom_sprites_set_boomerang(short x, short y,
                                   unsigned char phase_idx,
                                   unsigned char sub_pal)
{
    unsigned char p = (unsigned char)(phase_idx & 0x7u);
    unsigned char frame_n = k_boomerang_frame_cycle[p];   /* 0, 1, or 2 */
    unsigned char attr    = k_boomerang_attr_cycle[p];
    unsigned char vflip   = (unsigned char)((attr & 0x80u) ? 1u : 0u);
    unsigned char hflip   = (unsigned char)((attr & 0x40u) ? 1u : 0u);
    unsigned short tile   = (unsigned short)(ROOMROM_ITEM_TILE_BASE_PAL(sub_pal)
                                             + ROOMROM_ITEM_TILE_BOOMERANG
                                             + (unsigned short)frame_n * 2u);
    VDP_setSpriteFull(3,
                      (s16)x,
                      (s16)y,
                      SPRITE_SIZE(1, 1),
                      TILE_ATTR_FULL(PAL1,0, vflip, hflip, tile),
                      4);
    VDP_updateSprites(5, DMA);
}

void roomrom_sprites_clear_boomerang(void)
{
    VDP_setSpriteFull(3,
                      (s16)-32,
                      (s16)-32,
                      SPRITE_SIZE(1, 1),
                      TILE_ATTR_FULL(PAL1,0, 0, 0, BOOMERANG_VRAM_TILE),
                      4);
    VDP_updateSprites(5, DMA);
}

/* S7 v7 arrow (slot 4). Vertical 8x16 for UP/DOWN, horizontal 16x16
 * for LEFT/RIGHT (hflip on LEFT).
 * sub_pal selects which 4-copy bank to read (NES base attr = 0). */
void roomrom_sprites_set_arrow(short x, short y, link_face_t face,
                               unsigned char sub_pal)
{
    unsigned short tile_vert = (unsigned short)(ROOMROM_ITEM_TILE_BASE_PAL(sub_pal)
                                                + ROOMROM_ITEM_TILE_ARROW_VERT);
    unsigned short tile_horz = (unsigned short)(ROOMROM_ITEM_TILE_BASE_PAL(sub_pal)
                                                + ROOMROM_ITEM_TILE_ARROW_HORZ);
    switch (face) {
    case LINK_FACE_UP:
        VDP_setSpriteFull(4, (s16)x, (s16)y, SPRITE_SIZE(1, 2),
                          TILE_ATTR_FULL(PAL1,0, 0, 0, tile_vert),
                          5);
        break;
    case LINK_FACE_DOWN:
        VDP_setSpriteFull(4, (s16)x, (s16)y, SPRITE_SIZE(1, 2),
                          TILE_ATTR_FULL(PAL1,0, 1, 0, tile_vert),
                          5);
        break;
    case LINK_FACE_LEFT:
        /* Phase 1: horizontal arrow ($86..$89) now sourced from live NES
         * item atlas. RIGHT renders as-is, LEFT mirrors via hflip. */
        VDP_setSpriteFull(4, (s16)x, (s16)y, SPRITE_SIZE(2, 2),
                          TILE_ATTR_FULL(PAL1,0, 0, 1, tile_horz),
                          5);
        break;
    case LINK_FACE_RIGHT:
        VDP_setSpriteFull(4, (s16)x, (s16)y, SPRITE_SIZE(2, 2),
                          TILE_ATTR_FULL(PAL1,0, 0, 0, tile_horz),
                          5);
        break;
    default:
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
                      TILE_ATTR_FULL(PAL1,0, 0, 0, ARROW_VERT_VRAM_TILE),
                      5);
    VDP_updateSprites(7, DMA);
}

/* S7 v8 bomb (slot 5). NES Z1 DrawBomb (Z_07.asm:4869) -> DrawCloud ->
 * Anim_WriteItemSprites with item slot $01, frame 0 -> ItemFrameTiles[$03]
 * = $34. Tile $34 in [$20, $62) -> @Narrow path -> single 8x8 sprite.
 * sub_pal selects which 4-copy bank to read (NES DrawCloud sets Y=1). */
void roomrom_sprites_set_bomb(short x, short y, unsigned char sub_pal)
{
    unsigned short tile = (unsigned short)(ROOMROM_ITEM_TILE_BASE_PAL(sub_pal)
                                           + ROOMROM_ITEM_TILE_BOMB);
    VDP_setSpriteFull(5,
                      (s16)x,
                      (s16)y,
                      SPRITE_SIZE(1, 1),
                      TILE_ATTR_FULL(PAL1,0, 0, 0, tile),
                      6);
    VDP_updateSprites(7, DMA);
}

void roomrom_sprites_clear_bomb(void)
{
    VDP_setSpriteFull(5,
                      (s16)-32,
                      (s16)-32,
                      SPRITE_SIZE(1, 1),
                      TILE_ATTR_FULL(PAL1,0, 0, 0, BOMB_VRAM_TILE),
                      6);
    VDP_updateSprites(7, DMA);
}

/* S7 v8 explosion (slot 6). NES Z1 cloud cluster uses item slot $01
 * frames 1-3 = ItemFrameTiles[$04..$06] = $70/$72/$74. Each tile in
 * [$6C, $7C) -> @Wide -> Anim_WriteMirroredSpritePair (Z_01.asm:5304):
 * 2 8x8 sprites side-by-side, right = left hflipped, total 16x8 per
 * frame. The CHR generator pre-bakes the hflipped right tile next to
 * each raw tile (mirrored_16x8 draw rule), so each NES frame occupies
 * 2 sequential Genesis tiles in the blob:
 *
 *   blob[EXPLOSION_VRAM_TILE + 0..1]  = $70 + $70 hflipped (frame 0)
 *   blob[EXPLOSION_VRAM_TILE + 2..3]  = $72 + $72 hflipped (frame 1)
 *   blob[EXPLOSION_VRAM_TILE + 4..5]  = $74 + $74 hflipped (frame 2)
 *
 * SGDK SPRITE_SIZE(2, 1) renders the 16x8 cluster as one sprite by
 * picking up tile T (left) and T+1 (right). Cycle phase advances
 * every EXPLOSION_PHASE_FRAMES ticks of the bomb's explode timer
 * (NES cycles every ~2 frames between cluster positions; the
 * single-cluster Genesis impl uses a slower cadence so each frame
 * is visible). Frame 4 cluster is drawn 4 times at NES BombCloud
 * offsets (Z_07.asm:4924-4974); Genesis impl draws ONE cluster
 * centered on the bomb origin. */
#define EXPLOSION_PHASE_FRAMES 6u

void roomrom_sprites_set_explosion(short x, short y, unsigned char timer,
                                   unsigned char sub_pal)
{
    /* timer counts DOWN from BOMB_EXPLODE_FRAMES (24). Map to phase 0..2
     * advancing every 6 elapsed frames so each NES frame holds for ~6
     * Genesis ticks (4 phases over 24 frames, clamped to 0..2).
     * sub_pal selects which 4-copy bank to read (NES DrawCloud sets Y=1). */
    unsigned char elapsed = (unsigned char)(24u - (unsigned char)(timer & 0x1Fu));
    unsigned char phase   = (unsigned char)((elapsed / EXPLOSION_PHASE_FRAMES) % 3u);
    unsigned short tile   = (unsigned short)(ROOMROM_ITEM_TILE_BASE_PAL(sub_pal)
                                             + ROOMROM_ITEM_TILE_EXPLOSION
                                             + (unsigned short)phase * 2u);
    VDP_setSpriteFull(6,
                      (s16)x,
                      (s16)y,
                      SPRITE_SIZE(2, 1),
                      TILE_ATTR_FULL(PAL1,0, 0, 0, tile),
                      0);
    VDP_updateSprites(7, DMA);
}

void roomrom_sprites_clear_explosion(void)
{
    VDP_setSpriteFull(6,
                      (s16)-32,
                      (s16)-32,
                      SPRITE_SIZE(2, 1),
                      TILE_ATTR_FULL(PAL1,0, 0, 0, EXPLOSION_VRAM_TILE),
                      0);
    VDP_updateSprites(7, DMA);
}
