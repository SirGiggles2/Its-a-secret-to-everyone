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
    /* CRAM load — Phase B target layout (see src/game/world/bg_palette.h
     * for the full architectural rationale + sword-beam migration).
     *
     * PAL0[0..15] <- NES BG palram ($3F00..$3F0F), sub-pals 0..3 packed
     *                via pixel-bias rule (BG_4x stays — Phase C deferred).
     * PAL1[0..15] <- NES SPR palram ($3F10..$3F1F). [0..3] = sub-pal 0
     *                (Link, sword, common); [4..15] retained for any
     *                code still doing pixel-bias.
     * PAL2[0..3]  <- NES SPR sub-pal 1 colors ($3F14..$3F17). Bomb,
     *                explosion, FX sprites route here via OAM pal=PAL2.
     *                Color 0 = universal transparent.
     * PAL3[0..3]  <- NES SPR sub-pal 2 colors ($3F18..$3F1B). Candle,
     *                magic shot, OWSP red enemies route here via
     *                OAM pal=PAL3. Color 0 = universal transparent.
     *
     * Sword-beam color flash (Z_07.asm:3459 ATTR = base | (FrameCounter
     * & 3)) is reproduced by cycling the beam sprite's OAM pal field
     * across PAL1/PAL2/PAL3 each frame in combat_runtime update_beam.
     * NO ephemeral CRAM rewrite happens here; PAL2/PAL3 stay valid for
     * concurrent bomb / candle rendering. */
    unsigned char i;
    load_slot16(0, palram32 + 0);
    load_slot16(1, palram32 + 16);
    /* Cache the 16 sprite-palram CRAM words. Retained for the beam
     * pal-cycle path (which reads sub-pal CRAM words to validate PAL2/3
     * are populated) and for any future per-sub-pal load. */
    for (i = 0; i < 16; i++) {
        s_sprite_palram_cram[i] =
            roomrom_bg_palette_nes_to_cram(palram32[16 + i]);
    }
    s_sprite_palram_loaded = 1u;

    /* PAL2[0..3] = NES SPR sub-pal 3 ($3F1D..$3F1F) — LEVEL PALETTE slot.
     * Per Z_01.asm:5357 Anim_WriteLevelPaletteSprite, enemies using anim
     * attr=$03 (Blue Moblin, Blue Goriya, Wizzrobe, etc) draw here.
     * OW L1 / UW L1: $0C $1C $2C = cyan / teal / light cyan = Blue Moblin.
     *
     * Sub-pal 1 (cloud / FX) no longer needs PAL2 — it already routes
     * through PAL1's mid slots [5..7] via biased META_ATTR_MARKER CHR
     * (see k_cloud_chr_subpal1 in enemy_render.c using pixel values 6/7,
     * PAL1 loaded with full NES sprite palram has sub-pal 1 at [5..7]).
     *
     * Sub-pal 1 enemies (if any) that route here via subpal_routing
     * (sub_pal 1 -> PAL2) will render with sub-pal 3 colors — acceptable
     * since most NES "sub-pal 1" sprites are cloud/explosion which use
     * the META path. */
    {
        unsigned short pal2[16] = {0};
        pal2[1] = roomrom_bg_palette_nes_to_cram(palram32[16 + 13]);  /* $3F1D */
        pal2[2] = roomrom_bg_palette_nes_to_cram(palram32[16 + 14]);  /* $3F1E */
        pal2[3] = roomrom_bg_palette_nes_to_cram(palram32[16 + 15]);  /* $3F1F */
        render_load_palette(2u, pal2);
    }

    /* PAL3[0..3] = NES SPR sub-pal 2 ($3F18..$3F1B = red ramp).
     * Red enemies (Octorok, Tektite, anim_attr=$02 family) render here. */
    {
        unsigned short pal3[16] = {0};
        pal3[1] = roomrom_bg_palette_nes_to_cram(palram32[16 + 9]);   /* $3F19 */
        pal3[2] = roomrom_bg_palette_nes_to_cram(palram32[16 + 10]);  /* $3F1A */
        pal3[3] = roomrom_bg_palette_nes_to_cram(palram32[16 + 11]);  /* $3F1B */
        render_load_palette(3u, pal3);
    }
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
