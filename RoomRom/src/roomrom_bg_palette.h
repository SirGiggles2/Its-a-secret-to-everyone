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

#endif
