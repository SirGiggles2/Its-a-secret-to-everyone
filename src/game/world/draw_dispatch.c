/* draw_dispatch.c — native sprite-descriptor / OAM draw pipeline
 * (Phase 4).
 *
 * Drain MATCH for the NES asm side; written from
 * reference/aldonunez/Z_01.asm:1958-2477 directly, since there's no
 * existing C drain (the chain only exists as transpiled M68K asm).
 *
 * NES sources (Z_01.asm):
 *   DrawObjectMirrored / DrawObjectNotMirrored (2058 / 2069)
 *   DrawObjectWithType (2094)
 *   DrawObjectWithAnim (2112)
 *   DrawObjectWithAnimAndSpecificSprites (2135)
 *   Anim_WriteHorizontallyFlippableSpritePair (2224)
 *   Anim_WriteMirroredSpritePair (2471)
 *   Anim_WriteSpritePair (2261)
 *   Anim_WriteSpritePairNotFlashing (2284)
 *
 * Tables baked inline (Z_01.asm:1958..2041):
 *   ObjAnimations[127], ObjAnimFrameHeap[228],
 *   ObjAnimAttrHeap[228], SpriteOffsets[41].
 */

#include "draw_dispatch.h"
#include <stdint.h>
#include "platform_abi.h"
#include "scratch_state.h"     /* ZP_TMP0..ZP_TMPF */
#include "object_state.h"      /* OBJ_TYPE */
#include "combat_state.h"      /* MON_STATUS_FLAGS, MON_HIT_REACTION */
#include "core/core_dispatch.h"      /* core_anim_set_sprite_desc_attrs */
#include "world/sprite_dispatch.h"   /* sprite_cycle_cur_sprite_index */

/* --------------------------------------------------------------- */
/* Zero-page scratch slot semantic aliases for the draw pipeline.   */
/* These are the exact NES ZP slots the asm uses.                  */
/* --------------------------------------------------------------- */
#define DRAW_X              ZP_TMP0   /* $00 = sprite X */
#define DRAW_Y              ZP_TMP1   /* $01 = sprite Y */
#define DRAW_LEFT_TILE      ZP_TMP2   /* $02 = left tile */
#define DRAW_RIGHT_TILE     ZP_TMP3   /* $03 = right tile */
#define DRAW_LEFT_ATTR      ZP_TMP4   /* $04 = left attrs */
#define DRAW_RIGHT_ATTR     ZP_TMP5   /* $05 = right attrs */
#define DRAW_HAS_TWO_SIDES  ZP_TMP7   /* $07 = has two sides (1 = yes) */
#define DRAW_OBJ_INDEX      ZP_TMP8   /* $08 = slot/object index */
#define DRAW_X_SEPARATION   ZP_TMPA   /* $0A = X separation */
#define DRAW_MIRRORED       ZP_TMPC   /* $0C = mirrored flag */
#define DRAW_FRAME          ZP_TMPD   /* $0D = frame */
#define DRAW_ANIM_INDEX     ZP_TMPE   /* $0E = animation index */
#define DRAW_FLIP_H         ZP_TMPF   /* $0F = horizontal flip flag */

/* OAM mirror + sprite-index registers (NES RAM). */
#define DRAW_CUR_SPRITE_INDEX     RAM(0x0341u)
#define DRAW_LEFT_SPRITE_OFFSET   RAM(0x0343u)
#define DRAW_RIGHT_SPRITE_OFFSET  RAM(0x0344u)
#define DRAW_OAM_X(off)           RAM(0x0203u + (unsigned short)(off))
#define DRAW_OAM_Y(off)           RAM(0x0200u + (unsigned short)(off))
#define DRAW_OAM_TILE(off)        RAM(0x0201u + (unsigned short)(off))
#define DRAW_OAM_ATTR(off)        RAM(0x0202u + (unsigned short)(off))

/* MON_HIT_REACTION lives at $04F0+slot in the asm (`$04F0,A4,D2.W`).
 * combat_state.h's MON_HIT_REACTION(slot) macro resolves to the same
 * RAM offset; use it directly. */

/* --------------------------------------------------------------- */
/* Tables — extracted from Z_01.asm:1958..2041.                    */
/* --------------------------------------------------------------- */

/* ObjAnimations[127] (Z_01.asm:1958). Indexes ObjAnimFrameHeap +
 * ObjAnimAttrHeap. */
static const unsigned char k_obj_animations[127] = {
    0x00u, 0x08u, 0x0Bu, 0x0Fu, 0x13u, 0x17u, 0x5Cu, 0x60u,
    0x1Bu, 0x1Bu, 0x21u, 0x21u, 0x64u, 0x6Au, 0x27u, 0x29u,
    0x2Bu, 0x35u, 0x3Fu, 0x70u, 0x74u, 0x76u, 0x76u, 0x78u,
    0x7Au, 0x7Eu, 0x80u, 0x49u, 0x82u, 0x84u, 0x86u, 0x4Bu,
    0x4Fu, 0x4Fu, 0x51u, 0x51u, 0x88u, 0x8Cu, 0x90u, 0x90u,
    0x92u, 0x94u, 0x96u, 0x98u, 0x99u, 0x99u, 0x99u, 0x53u,
    0x54u, 0x9Au, 0x9Bu, 0x9Bu, 0xA5u, 0xA5u, 0xABu, 0xABu,
    0xACu, 0xAEu, 0xAEu, 0xAFu, 0xAFu, 0xB2u, 0xB8u, 0xB8u,
    0x08u, 0x08u, 0xC6u, 0xC6u, 0xC6u, 0xC6u, 0xC6u, 0xC6u,
    0xC8u, 0xC8u, 0xC9u, 0xC9u, 0xCAu, 0xCAu, 0xCAu, 0xCAu,
    0xCAu, 0xCAu, 0xCAu, 0xCAu, 0x09u, 0x09u, 0x0Au, 0x0Au,
    0x0Bu, 0x0Bu, 0x0Bu, 0x0Bu, 0x0Bu, 0x0Bu, 0xCBu, 0x55u,
    0x55u, 0x55u, 0x55u, 0x55u, 0x55u, 0x55u, 0x56u, 0x57u,
    0x57u, 0xCBu, 0xCCu, 0x58u, 0x58u, 0x58u, 0x58u, 0x58u,
    0x58u, 0x58u, 0x58u, 0x58u, 0x59u, 0x59u, 0x59u, 0x59u,
    0x5Au, 0x5Au, 0x5Au, 0x5Au, 0x5Bu, 0x5Bu, 0x5Bu
};

/* ObjAnimFrameHeap[228] (Z_01.asm:1977). Per-frame left tile index. */
static const unsigned char k_obj_anim_frame_heap[228] = {
    0x00u, 0x04u, 0x08u, 0x0Cu, 0x10u, 0x10u, 0x14u, 0x18u,
    0x5Cu, 0x9Eu, 0x44u, 0xCEu, 0xD2u, 0xD6u, 0xDAu, 0xCEu,
    0xD2u, 0xD6u, 0xDAu, 0xF0u, 0xF4u, 0xF8u, 0xFCu, 0xF0u,
    0xF4u, 0xF8u, 0xFCu, 0xB4u, 0xB0u, 0xB0u, 0xB8u, 0xB2u,
    0xB2u, 0xB4u, 0xB0u, 0xB0u, 0xB8u, 0xB2u, 0xB2u, 0xCAu,
    0xCCu, 0xCAu, 0xCCu, 0xBCu, 0xBEu, 0xC0u, 0xC0u, 0xC2u,
    0xC4u, 0xC0u, 0xC0u, 0xBCu, 0xBEu, 0xBCu, 0xBEu, 0xC0u,
    0xC0u, 0xC2u, 0xC4u, 0xC0u, 0xC0u, 0xBCu, 0xBEu, 0xBCu,
    0xBEu, 0xECu, 0xEEu, 0xECu, 0xEEu, 0xECu, 0xEEu, 0xBCu,
    0xBEu, 0xC6u, 0xC8u, 0xA0u, 0xA8u, 0xA4u, 0xACu, 0x90u,
    0xE8u, 0xE4u, 0xE0u, 0x94u, 0xF3u, 0xC9u, 0xBDu, 0xC1u,
    0x98u, 0x9Au, 0x9Cu, 0xF8u, 0xB8u, 0xBCu, 0xB0u, 0xB4u,
    0xB8u, 0xBCu, 0xB0u, 0xB4u, 0xB8u, 0xACu, 0xB4u, 0xBCu,
    0xB0u, 0xB4u, 0xB8u, 0xACu, 0xB4u, 0xBCu, 0xB0u, 0xB4u,
    0xACu, 0xAEu, 0xB0u, 0xB2u, 0xA8u, 0xAAu, 0x92u, 0x94u,
    0xA0u, 0xA2u, 0xA6u, 0xA4u, 0xA2u, 0xA4u, 0xD8u, 0xDAu,
    0x00u, 0x00u, 0x9Au, 0x9Cu, 0x9Au, 0x9Cu, 0x9Au, 0x9Cu,
    0xB4u, 0xB8u, 0xBCu, 0xBEu, 0xB4u, 0xB8u, 0xBCu, 0xBEu,
    0xFCu, 0xFEu, 0xACu, 0x9Cu, 0xA0u, 0xA4u, 0xA0u, 0xA4u,
    0xA8u, 0x8Eu, 0xA4u, 0xDCu, 0xE0u, 0xE4u, 0xE8u, 0xECu,
    0xF0u, 0xF4u, 0xF8u, 0xFAu, 0xFEu, 0xF4u, 0xF6u, 0xFEu,
    0xFCu, 0xF0u, 0xF8u, 0xB0u, 0xF6u, 0xF0u, 0xD4u, 0xFCu,
    0xFEu, 0xF8u, 0xE8u, 0xEAu, 0xE0u, 0xE4u, 0xECu, 0xECu,
    0xD0u, 0xD4u, 0xD8u, 0xDCu, 0xE0u, 0xE4u, 0xC0u, 0xC8u,
    0xC4u, 0xCCu, 0xE8u, 0xEAu, 0x72u, 0x74u, 0xDEu, 0xEEu,
    0xF8u, 0x96u, 0x98u, 0xB1u
};

/* ObjAnimAttrHeap[228] (Z_01.asm:2006). Per-frame attr byte (palette
 * row + flip flags). */
static const unsigned char k_obj_anim_attr_heap[228] = {
    0x00u, 0x00u, 0x00u, 0x00u, 0x00u, 0x00u, 0x00u, 0x00u,
    0x02u, 0x00u, 0x00u, 0x01u, 0x01u, 0x01u, 0x01u, 0x02u,
    0x02u, 0x02u, 0x02u, 0x03u, 0x03u, 0x03u, 0x03u, 0x02u,
    0x02u, 0x02u, 0x02u, 0x02u, 0x82u, 0x02u, 0x02u, 0x82u,
    0x02u, 0x01u, 0x81u, 0x01u, 0x01u, 0x81u, 0x01u, 0x01u,
    0x01u, 0x02u, 0x02u, 0x02u, 0x02u, 0x01u, 0x01u, 0x01u,
    0x01u, 0x01u, 0x01u, 0x02u, 0x02u, 0x02u, 0x02u, 0x02u,
    0x02u, 0x02u, 0x02u, 0x02u, 0x02u, 0x02u, 0x02u, 0x03u,
    0x03u, 0x03u, 0x03u, 0x03u, 0x03u, 0x03u, 0x03u, 0x03u,
    0x03u, 0x02u, 0x02u, 0x02u, 0x02u, 0x02u, 0x02u, 0x02u,
    0x02u, 0x01u, 0x01u, 0x01u, 0x02u, 0x03u, 0x03u, 0x03u,
    0x02u, 0x02u, 0x00u, 0x02u, 0x01u, 0x01u, 0x01u, 0x01u,
    0x02u, 0x02u, 0x02u, 0x02u, 0x02u, 0x02u, 0x02u, 0x02u,
    0x02u, 0x02u, 0x01u, 0x01u, 0x01u, 0x01u, 0x01u, 0x01u,
    0x01u, 0x01u, 0x01u, 0x01u, 0x03u, 0x03u, 0x03u, 0x03u,
    0x00u, 0x00u, 0x02u, 0x02u, 0x02u, 0x02u, 0x03u, 0x03u,
    0x03u, 0x03u, 0x01u, 0x01u, 0x02u, 0x02u, 0x03u, 0x03u,
    0x01u, 0x01u, 0x01u, 0x01u, 0x02u, 0x02u, 0x02u, 0x02u,
    0x01u, 0x01u, 0x01u, 0x01u, 0x02u, 0x02u, 0x02u, 0x02u,
    0x02u, 0x02u, 0x01u, 0x03u, 0x03u, 0x03u, 0x03u, 0x03u,
    0x03u, 0x03u, 0x03u, 0x03u, 0x03u, 0x01u, 0x01u, 0x01u,
    0x01u, 0x01u, 0x01u, 0x02u, 0x00u, 0x00u, 0x03u, 0x01u,
    0x01u, 0x01u, 0x01u, 0x01u, 0x01u, 0x01u, 0x01u, 0x01u,
    0x03u, 0x03u, 0x03u, 0x03u, 0x03u, 0x03u, 0x03u, 0x03u,
    0x03u, 0x03u, 0x03u, 0x03u, 0x03u, 0x03u, 0x02u, 0x02u,
    0x01u, 0x01u, 0x02u, 0x03u
};

/* SpriteOffsets[41] (Z_01.asm:2035). Indexed by CUR_SPRITE_INDEX
 * ($0341); produces left+right OAM byte offsets. */
static const unsigned char k_sprite_offsets[41] = {
    0x60u, 0xBCu, 0x64u, 0xB8u, 0x68u, 0xB4u, 0x6Cu, 0xB0u,
    0x70u, 0xCCu, 0x74u, 0xC8u, 0x78u, 0xC4u, 0x7Cu, 0xC0u,
    0x80u, 0xDCu, 0x84u, 0xD8u, 0x88u, 0xD4u, 0x8Cu, 0xD0u,
    0x90u, 0xECu, 0x94u, 0xE8u, 0x98u, 0xE4u, 0x9Cu, 0xE0u,
    0xA0u, 0xFCu, 0xA4u, 0xF8u, 0xA8u, 0xF4u, 0xACu, 0xF0u,
    0x60u
};

/* --------------------------------------------------------------- */
/* Forward decls.                                                  */
/* --------------------------------------------------------------- */
static void anim_write_sprite_pair_not_flashing(void);
static void anim_write_sprite_pair(unsigned int slot);
static void anim_write_horizontally_flippable_sprite_pair(unsigned int slot);
static void anim_write_mirrored_sprite_pair(unsigned int slot);
static void draw_object_with_anim_and_specific_sprites(unsigned int slot);
static void draw_object_with_anim(unsigned char frame, unsigned int slot);
static void draw_object_with_type(unsigned char frame, unsigned int slot,
                                  unsigned char anim_idx);

/* --------------------------------------------------------------- */
/* Anim_WriteSpritePairNotFlashing (Z_01.asm:2284).                 */
/* Writes 2 sprites to OAM mirror at $0200..$02FF.                  */
/* --------------------------------------------------------------- */
static void anim_write_sprite_pair_not_flashing(void)
{
    unsigned char off = (unsigned char)DRAW_LEFT_SPRITE_OFFSET;
    unsigned char d3  = 0u;     /* loop counter (left=0, right=1) */

    do {
        const unsigned char tile =
            (unsigned char)RAM(0x0002u + d3); /* TMP2/3 */
        DRAW_OAM_TILE(off) = tile;

        const unsigned char y = (unsigned char)DRAW_Y;
        DRAW_OAM_Y(off) = y;

        unsigned char x = (unsigned char)DRAW_X;
        DRAW_OAM_X(off) = x;

        const unsigned char xsep = (unsigned char)DRAW_X_SEPARATION;
        DRAW_X = (uint8_t)(x + xsep);   /* TMP0 += xsep for next sprite */

        const unsigned char attr =
            (unsigned char)RAM(0x0004u + d3); /* TMP4/5 */
        DRAW_OAM_ATTR(off) = attr;

        off = (unsigned char)DRAW_RIGHT_SPRITE_OFFSET;

        if ((unsigned char)DRAW_OBJ_INDEX != 0u) {
            sprite_cycle_cur_sprite_index();
        }

        ++d3;
        DRAW_HAS_TWO_SIDES =
            (uint8_t)((unsigned char)DRAW_HAS_TWO_SIDES - 1u);
    } while ((signed char)(unsigned char)DRAW_HAS_TWO_SIDES >= 0);
}

/* Anim_WriteSpritePair (Z_01.asm:2261). Apply hit-flash palette
 * override if MON_HIT_REACTION(slot) is non-zero, then call
 * not-flashing writer. */
static void anim_write_sprite_pair(unsigned int slot)
{
    const unsigned char hit = (unsigned char)MON_HIT_REACTION(slot);
    if (hit != 0u) {
        for (signed char d3 = 1; d3 >= 0; --d3) {
            unsigned char attr =
                (unsigned char)RAM(0x0004u + (unsigned char)d3);
            attr = (unsigned char)(attr & 0xFCu);
            attr = (unsigned char)(attr | (hit & 0x03u));
            RAM(0x0004u + (unsigned char)d3) = attr;
        }
    }
    anim_write_sprite_pair_not_flashing();
}

/* Anim_WriteHorizontallyFlippableSpritePair (Z_01.asm:2224). If
 * DRAW_FLIP_H is set, swap tiles + toggle attr bit 6 on both sides
 * before writing. */
static void anim_write_horizontally_flippable_sprite_pair(unsigned int slot)
{
    if ((unsigned char)DRAW_FLIP_H != 0u) {
        const unsigned char tmp_left = (unsigned char)DRAW_LEFT_TILE;
        DRAW_LEFT_TILE = (uint8_t)DRAW_RIGHT_TILE;
        DRAW_RIGHT_TILE = tmp_left;

        DRAW_LEFT_ATTR =
            (uint8_t)((unsigned char)DRAW_LEFT_ATTR ^ 0x40u);
        DRAW_RIGHT_ATTR =
            (uint8_t)((unsigned char)DRAW_RIGHT_ATTR ^ 0x40u);
    }
    anim_write_sprite_pair(slot);
}

/* Anim_WriteMirroredSpritePair (Z_01.asm:2471). Set right tile =
 * left tile, toggle right attr flip-H bit, then write. */
static void anim_write_mirrored_sprite_pair(unsigned int slot)
{
    DRAW_RIGHT_TILE = (uint8_t)DRAW_LEFT_TILE;
    DRAW_RIGHT_ATTR =
        (uint8_t)((unsigned char)DRAW_RIGHT_ATTR ^ 0x40u);
    anim_write_sprite_pair(slot);
}

/* DrawObjectWithAnimAndSpecificSprites (Z_01.asm:2135).
 * Looks up frame tiles + attrs from heaps, sets sprite descriptors,
 * dispatches to write writer. */
static void draw_object_with_anim_and_specific_sprites(unsigned int slot)
{
    DRAW_OBJ_INDEX = (uint8_t)slot;
    DRAW_HAS_TWO_SIDES = 1u;
    DRAW_X_SEPARATION = 8u;

    const unsigned char anim_idx = (unsigned char)DRAW_ANIM_INDEX;
    const unsigned char frame = (unsigned char)DRAW_FRAME;

    /* d0 = ObjAnimations[anim_idx] + frame ; d3 = d0; left tile */
    unsigned char tile_idx =
        (unsigned char)(k_obj_animations[anim_idx] + frame);
    const unsigned char left_tile = k_obj_anim_frame_heap[tile_idx];
    DRAW_LEFT_TILE = left_tile;
    DRAW_RIGHT_TILE = (uint8_t)(left_tile + 2u);

    /* If object is Link or weapon/room-item slot >= $D, force
     * UseTableAttr (skip the half-width / ignore-attr branches). */
    int use_table_attr = 0;
    if (slot == 0u || slot >= 0x0Du) {
        use_table_attr = 1;
    } else {
        const unsigned char status =
            (unsigned char)MON_STATUS_FLAGS(slot);
        if (status & 0x02u) {
            /* Half-width draw branch: -- DRAW_HAS_TWO_SIDES; jmp
             * Anim_WriteSpritePair (skip attr setup). */
            DRAW_HAS_TWO_SIDES =
                (uint8_t)((unsigned char)DRAW_HAS_TWO_SIDES - 1u);
            anim_write_sprite_pair(slot);
            return;
        }
        if (status & 0x08u) {
            /* Ignore sprite attribute table — drop straight to
             * mirror/flip dispatch. */
            goto dispatch_mirror_flip;
        }
        use_table_attr = 1;
    }

    if (use_table_attr) {
        const unsigned char attr_byte = k_obj_anim_attr_heap[tile_idx];
        core_anim_set_sprite_desc_attrs((unsigned int)attr_byte);
    }

dispatch_mirror_flip:
    /* If Link (slot 0), always horizontally-flippable (never
     * mirrored). Else respect DRAW_MIRRORED. */
    if (slot == 0u) {
        anim_write_horizontally_flippable_sprite_pair(slot);
        return;
    }
    if ((unsigned char)DRAW_MIRRORED != 0u) {
        anim_write_mirrored_sprite_pair(slot);
        return;
    }
    anim_write_horizontally_flippable_sprite_pair(slot);
}

/* DrawObjectWithAnim (Z_01.asm:2112). Sets DRAW_FRAME + DRAW_ANIM_INDEX +
 * DRAW_OBJ_INDEX, picks left/right SpriteOffset by CUR_SPRITE_INDEX,
 * Link-special-cases sprite offsets to fixed $48/$4C, then dispatches. */
static void draw_object_with_anim(unsigned char frame, unsigned int slot)
{
    DRAW_FRAME = frame;
    DRAW_ANIM_INDEX = (uint8_t)DRAW_ANIM_INDEX; /* unchanged */
    DRAW_OBJ_INDEX = (uint8_t)slot;

    const unsigned char cur_idx = (unsigned char)DRAW_CUR_SPRITE_INDEX;
    DRAW_LEFT_SPRITE_OFFSET = k_sprite_offsets[cur_idx & 0x3Fu];
    if (slot == 0u) {
        /* Link: hardcode $48 / $4C. */
        DRAW_LEFT_SPRITE_OFFSET = 0x48u;
        DRAW_RIGHT_SPRITE_OFFSET = 0x4Cu;
    } else {
        DRAW_RIGHT_SPRITE_OFFSET =
            k_sprite_offsets[(cur_idx + 1u) & 0x3Fu];
    }
    draw_object_with_anim_and_specific_sprites(slot);
}

/* DrawObjectWithType (Z_01.asm:2094). DRAW_ANIM_INDEX = obj_type + 1. */
static void draw_object_with_type(unsigned char frame, unsigned int slot,
                                  unsigned char anim_idx)
{
    DRAW_ANIM_INDEX = (uint8_t)(anim_idx + 1u);
    draw_object_with_anim(frame, slot);
}

/* DrawObjectMirrored (Z_01.asm:2058). mirrored=1; anim_idx = OBJ_TYPE.
 * NES uses RAM($034F + slot) — that's OBJ_TYPE(slot). */
void draw_object_mirrored(unsigned char frame, unsigned int slot)
{
    DRAW_MIRRORED = 1u;
    const unsigned char anim_idx = (unsigned char)OBJ_TYPE(slot);
    draw_object_with_type(frame, slot, anim_idx);
}

/* DrawObjectNotMirrored (Z_01.asm:2069). mirrored=0; anim_idx=OBJ_TYPE. */
void draw_object_not_mirrored(unsigned char frame, unsigned int slot)
{
    DRAW_MIRRORED = 0u;
    const unsigned char anim_idx = (unsigned char)OBJ_TYPE(slot);
    draw_object_with_type(frame, slot, anim_idx);
}

/* DrawObjectMirroredWithFrame (Z_01.asm:4520-ish). Same as mirrored
 * but caller supplies frame. */
void draw_object_mirrored_with_frame(unsigned char frame, unsigned int slot)
{
    draw_object_mirrored(frame, slot);
}

void draw_object_not_mirrored_with_frame(unsigned char frame,
                                         unsigned int slot)
{
    draw_object_not_mirrored(frame, slot);
}
