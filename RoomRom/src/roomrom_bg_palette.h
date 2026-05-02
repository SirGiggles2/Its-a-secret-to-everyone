#ifndef ROOMROM_BG_PALETTE_H
#define ROOMROM_BG_PALETTE_H

/* Centralized NES->Genesis palette conversion + bulk loaders.
 *
 * load_palram_full writes Gen PAL0 (16 colors from palram32[0..15]) and
 * Gen PAL1 (16 colors from palram32[16..31]). Does NOT touch PAL2/PAL3.
 *
 * load_bg_only writes Gen PAL0 only. Use when caller has BG-half bytes.
 */

unsigned short roomrom_bg_palette_nes_to_cram(unsigned char nes_color);
void roomrom_bg_palette_load_palram_full(const unsigned char *palram32);
void roomrom_bg_palette_load_bg_only(const unsigned char *palram16);

/* Returns pointer to 4 cached CRAM words for NES sprite sub-palette
 * `subpal_idx` (0..3) from the most recent load_palram_full. Layout
 * mirrors NES palram $3F10+$04*subpal: word 0 = universal-bg mirror
 * (transparent), words 1-3 = visible NES sub-palette colors.
 *
 * Used by the sword-beam color flash (Z_07.asm:3459 ATTR = base |
 * (FrameCounter & 3) cycles palette index per frame). Returns NULL
 * if no palram has been loaded yet. */
const unsigned short *roomrom_bg_palette_get_sprite_subpal_cram(
    unsigned char subpal_idx);

#endif
