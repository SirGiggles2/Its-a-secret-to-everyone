/* subpal_routing.h — Single source of truth for NES sub-palette ->
 * Genesis CRAM / OAM pal-field mapping.
 *
 * Phase AA (2026-05-18 VRAM cleanup org). Consolidates the routing
 * logic that was previously open-coded in 3 places:
 *   - sprite_render.c ROOMROM_SUBPAL_PAL(s) macro (Phase B)
 *   - enemy_render.c translate_attrs inline computation (Phase F)
 *   - bg_palette.c CRAM load (Phase A doc only; Phase B+F code)
 *
 * Architectural foundation: see src/game/world/bg_palette.h ARCH NOTE
 * for why Genesis-4-PAL vs NES-4-BG-+-3-SPR-subpals forces this layout.
 *
 * Routing summary (post Phase B/F):
 *
 *   NES SPR sub-pal 0  ->  Genesis OAM pal=PAL1, tile pixel values 1..3
 *                          (Link, sword, common-bank sprites)
 *   NES SPR sub-pal 1  ->  Genesis OAM pal=PAL2, tile pixel values 1..3
 *                          (bomb, explosion, cloud FX)
 *   NES SPR sub-pal 2  ->  Genesis OAM pal=PAL3, tile pixel values 1..3
 *                          (candle, magic shot, red enemies)
 *   NES SPR sub-pal 3  ->  CLAMPED to sub-pal 2 (Phase B/F decision;
 *                          census shows minimal use; Phase N may restore)
 *
 *   NES BG sub-pal 0..3 -> packed into PAL0 (pixel-bias replication)
 *                          via 4x BG bank. Phase J selective dedup will
 *                          shift this to per-cell pal-bits selection.
 *
 * CRAM color slot mapping (32-bit slot index within CRAM):
 *   NES SPR sub-pal 0 colors: PAL1[0..3] = CRAM slots 16..19
 *   NES SPR sub-pal 1 colors: PAL2[0..3] = CRAM slots 32..35
 *   NES SPR sub-pal 2 colors: PAL3[0..3] = CRAM slots 48..51
 *
 * Loaders for these slots live in src/game/world/bg_palette.c
 * (roomrom_bg_palette_load_palram_full). This header defines only the
 * READER side: given an NES sub-pal index, which OAM/cell pal field?
 */
#ifndef ROOMROM_SUBPAL_ROUTING_H
#define ROOMROM_SUBPAL_ROUTING_H

#include "render_abi.h"  /* RENDER_PAL0..PAL3 */

/* NES sprite sub-pal (0..3) -> Genesis OAM pal-field value.
 * Sub-pal 3 clamps to 2. Result is suitable as the first arg to
 * RENDER_TILE_ATTR_FULL(pal, ...). */
static inline unsigned char roomrom_spr_subpal_to_pal(unsigned char nes_subpal)
{
    unsigned char clamped = (unsigned char)((nes_subpal > 2u) ? 2u : nes_subpal);
    return (unsigned char)(RENDER_PAL1 + clamped);
}

/* NES BG sub-pal (0..3) -> Genesis nametable cell pal-bits.
 * Post-Phase-J this will select PAL0..PAL3 directly. Today (4x bank)
 * the cell always sets pal=PAL0 and the sub-pal lives in the tile's
 * pixel-value encoding (see expand_bg_chr.py pixel-bias rule). */
static inline unsigned char roomrom_bg_subpal_to_pal_bits(unsigned char nes_subpal)
{
    (void)nes_subpal;  /* pre-Phase-J: always PAL0 */
    return RENDER_PAL0;
}

/* CRAM slot (0..63) where NES sprite sub-pal N's color C lives.
 * 0 <= n <= 2 (3 clamps), 0 <= c <= 3.
 * Used by transient palette tricks (sword-beam flash precursor pre-
 * Phase-B; now mostly obsolete). */
static inline unsigned short roomrom_cram_slot_for_spr_subpal(unsigned char nes_subpal,
                                                                unsigned char color)
{
    unsigned char pal = roomrom_spr_subpal_to_pal(nes_subpal);
    return (unsigned short)(pal * 16u + (color & 0x03u));
}

#endif /* ROOMROM_SUBPAL_ROUTING_H */
