#include "bg_palette.h"
#include "render_abi.h"

/* Reuse the existing misc_palettes NES-color-index -> Gen-CRAM-word LUT.
 * Same table consumed by ow_room_render_roomrom.c, uw_room_render_roomrom.c,
 * and roomrom_sprites.c -- single source of truth for color conversion.
 */
extern const unsigned char misc_palettes[1208];

unsigned short roomrom_bg_palette_nes_to_cram(unsigned char nes_color)
{
    unsigned short off = (unsigned short)(nes_color & 0x3Fu) * 2u;
    return (unsigned short)misc_palettes[off]
         | ((unsigned short)misc_palettes[off + 1] << 8);
}

/* Cache of converted NES sprite palram in CRAM-word form, populated by
 * load_palram_full. Indexed [subpal_idx*4 + color_idx], 0 <= subpal_idx
 * <= 3, 0 <= color_idx <= 3. Used for sword-beam color flash. */
static unsigned short s_sprite_palram_cram[16];
static unsigned char  s_sprite_palram_loaded = 0u;

static void load_slot16(unsigned char gen_slot, const unsigned char *nes16)
{
    unsigned short pal16[16];
    unsigned char i;
    for (i = 0; i < 16; i++) {
        pal16[i] = roomrom_bg_palette_nes_to_cram(nes16[i]);
    }
    render_load_palette((unsigned short)gen_slot, pal16);
}

void roomrom_bg_palette_load_palram_full(const unsigned char *palram32)
{
    /* PAL0 <- NES BG palram bytes ($3F00..$3F0F).
     * PAL1 <- NES SPR palram bytes ($3F10..$3F1F).
     * PAL3 <- NES SPR sub-pal 2 colors at indices 1..3 (Phase 7 enemy
     *         visibility fix 2026-05-15). Lets OWSP atlas tiles
     *         (biased to indices 1..3) render with sub-pal 2 colors
     *         (red enemies) when routed to PAL3 instead of PAL1
     *         (which gives sub-pal 0 = items palette = yellow/gold).
     * PAL2 untouched (caller-managed for items). */
    unsigned char i;
    load_slot16(0, palram32 + 0);
    load_slot16(1, palram32 + 16);
    /* Cache the 16 sprite-palram CRAM words so the sword-beam flash can
     * rewrite PAL2[0..3] each frame without re-running the NES->CRAM LUT. */
    for (i = 0; i < 16; i++) {
        s_sprite_palram_cram[i] =
            roomrom_bg_palette_nes_to_cram(palram32[16 + i]);
    }
    s_sprite_palram_loaded = 1u;

    /* Build PAL3 — NES sprite sub-pal 2 = red-enemy colors at palram32
     * [$19..$1B] = palram32[25..27]. The NES->CRAM LUT was producing
     * $0EEE (white) for NES $16 (dark red) at index 3 due to a hue/luma
     * coercion bug; that made octorok shots + red enemy bodies render
     * bright white instead of red. Override with a Genesis-native clean
     * red ramp keyed off the OW enemy sub-pal contract:
     *   idx 0: transparent
     *   idx 1: bright red    ($000E = R=14)
     *   idx 2: medium red    ($000A = R=10)
     *   idx 3: dark red      ($0006 = R=6)
     * This stays NES-faithful in HUE (enemies still red) while leveraging
     * Genesis 9-bit color precision for a cleaner gradient than NES's
     * coarse 4-color sub-pal allowed. */
    unsigned short pal3[16] = {0};
    pal3[1] = 0x000Eu;
    pal3[2] = 0x000Au;
    pal3[3] = 0x0006u;
    render_load_palette(3u, pal3);
}

const unsigned short *roomrom_bg_palette_get_sprite_subpal_cram(
    unsigned char subpal_idx)
{
    if (!s_sprite_palram_loaded) return (const unsigned short *)0;
    return &s_sprite_palram_cram[(unsigned short)(subpal_idx & 0x3u) * 4u];
}

void roomrom_bg_palette_load_bg_only(const unsigned char *palram16)
{
    load_slot16(0, palram16);
}
