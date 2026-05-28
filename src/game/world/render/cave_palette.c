#include "cave_palette.h"
#include "bg_palette.h"
#include "render_abi.h"

/* NES PPU bytes for cave BG subpal 2+3 (Z_06.asm:714). */
static const unsigned char k_cave_subpal_2_3_nes[8] = {
    0x0F, 0x30, 0x00, 0x12,   /* subpal 2: black, white, gray, blue   */
    0x0F, 0x07, 0x0F, 0x17    /* subpal 3: black, brown, black, orange */
};

/* Phase I1 (2026-05-27, debate 057 BUG 1): NES SPR subpal 2 = bonfire
 * fire colors. Verified at reference/aldonunez/dat/LevelInfoOW.dat
 * bytes 27-30 of PalettesTransferBuf (header $3F $00 $20 + 32 palette
 * bytes; SPR subpal 2 starts at offset 27 = $3F18 in PPU PALRAM).
 * Same colors all caves — uniform per Sonnet R3 finding. */
static const unsigned char k_cave_spr_subpal_2_nes[4] = {
    0x0F, 0x16, 0x27, 0x30    /* black, red-orange, orange-yellow, white */
};

void cave_palette_apply(void)
{
    unsigned short cram[8];
    unsigned char i;
    for (i = 0u; i < 8u; i++) {
        cram[i] = roomrom_bg_palette_nes_to_cram(k_cave_subpal_2_3_nes[i]);
    }
    /* PAL0 starts at CRAM slot 0; subpal 2+3 occupy slots 8..15. */
    render_cram_subrange_upload(8u, cram, 8u);

    /* Phase I1: upload SPR subpal 2 for bonfire colors. NES bonfire
     * (ObjType $40 StandingFire) uses attr=2 → SPR subpal 2. Without
     * this upload, PAL1 sub-pal 2 inherits OW state which may render
     * incorrect fire colors. CRAM slot 24-27 = PAL1 sub-pal 2. */
    unsigned short spr_cram[4];
    for (i = 0u; i < 4u; i++) {
        spr_cram[i] = roomrom_bg_palette_nes_to_cram(k_cave_spr_subpal_2_nes[i]);
    }
    render_cram_subrange_upload(24u, spr_cram, 4u);
}
