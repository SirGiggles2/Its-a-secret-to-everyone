/* src/fs_main.c — entry from boot.asm (proof ROM) or intro_handoff (main ROM v6).
 * v1: render static layout + Link sprites once, then spin forever in vblank loop.
 */
#include "fs_main.h"
#include "fs_render.h"
#include "intro_common.h"

/* Generated assets — defined in src/gen/. */
extern const uint8_t  fs_bg_chr_full[];        /* 239 tiles × 32 bytes = 7648 bytes */
extern const uint8_t  fs_link_sprite_chr[];    /* 4 tiles × 32 bytes = 128 bytes */
extern const uint8_t  fs_heart_cursor_chr[];   /* 1 tile  × 32 bytes =  32 bytes */
extern const uint16_t fs_bg_palette[4];        /* BG palette 0: black/white/dark/blue */
extern const uint16_t fs_link_palettes[4][4];  /* 4 Link palettes × 4 colors */

#define VDP_CTRL_WORD (*(volatile unsigned short *)0x00C00004)

static void wait_vblank(void) {
    while ( (VDP_CTRL_WORD & 0x0008));
    while (!(VDP_CTRL_WORD & 0x0008));
}

/* vdp_load_cram_at: load `count` palette words into CRAM at byte offset `cram_addr`.
 * Genesis CRAM: 64 words = 128 bytes. Each palette = 16 words = 32 bytes.
 * Palette 0 starts at CRAM byte 0, palette 1 at byte 32, etc.
 */
static void vdp_load_cram_at(unsigned short cram_byte_addr,
                              const unsigned short *src,
                              unsigned short count)
{
    volatile unsigned long  *vctrl = (volatile unsigned long  *)0x00C00004;
    volatile unsigned short *vdata = (volatile unsigned short *)0x00C00000;
    /* CRAM write command: CD[5:2]=0011, addr = cram_byte_addr */
    unsigned long cmd = 0xC0000000UL
                      | ((unsigned long)(cram_byte_addr & 0x007F) << 16)
                      | 0x00000000UL;
    *vctrl = cmd;
    for (unsigned short i = 0; i < count; i++) {
        *vdata = src[i];
    }
}

/* fs_init: upload CHR data and all palettes once at boot.
 *
 * CRAM layout (64 words = 4 palettes × 16 colors on Genesis):
 *   Palette 0 (CRAM byte offset   0): BG palette — black bg, white text
 *   Palette 1 (CRAM byte offset  32): Link slot 0 (green)
 *   Palette 2 (CRAM byte offset  64): Link slot 1 (blue)
 *   Palette 3 (CRAM byte offset  96): Link slot 2 (red) / dim
 *
 * BG cells use palette 0. Sprite entries use palette indices 1-3 (link) or 3 (dim/cursor).
 * To write palette N to Genesis sprite with palette selector=N in tile_attr:
 *   sprite palette N maps to CRAM palette N (same CRAM space as BG).
 *   BG tiles with palette bits=0 → CRAM palette 0.
 *
 * VRAM layout:
 *   Tile 0x00..0xEE  BG CHR full block (font 0x00-0x63, gaps, border 0xD4-0xEE)
 *   Tile 0x80..0x83  Link sprite CHR  (overwrites zero-gap at 0x80-0x83)
 *   Tile 0x84        Heart cursor CHR (overwrites zero-gap at 0x84)
 */
static void fs_init(void) {
    /* 1. Upload full BG CHR block to VRAM tile 0x00 (242 tiles × 32 bytes = 7744 bytes).
     *    CommonBG(112)+DemoBG(130)=242 tiles, covers nametable tile refs 0x00-0xF0. */
    vdp_dma_to_vram((unsigned long)fs_bg_chr_full,
                    (unsigned short)(0x00u * 32u),
                    (unsigned short)(242u * 32u));

    /* 2. Upload Link sprite CHR to VRAM tile 0x100 (above BG block, no collision).
     *    4 tiles × 32 bytes = 128 bytes. VRAM offset = 0x100 * 32 = 0x2000. */
    vdp_dma_to_vram((unsigned long)fs_link_sprite_chr,
                    (unsigned short)(0x100u * 32u),
                    (unsigned short)(4u * 32u));

    /* 3. Upload heart cursor CHR to VRAM tile 0x104 (32 bytes). */
    vdp_dma_to_vram((unsigned long)fs_heart_cursor_chr,
                    (unsigned short)(0x104u * 32u),
                    (unsigned short)(1u * 32u));

    /* 4. Load BG palette into CRAM palette 0 (black bg, white text). */
    vdp_load_cram_at(0u, fs_bg_palette, 4u);

    /* 5. Load Link palettes into CRAM palettes 1-3 (4 colors each).
     *    palette 1 = slot 0 green, palette 2 = slot 1 blue,
     *    palette 3 = slot 2 red OR dim (empty slots).
     *    v1 mock: slot 0 occupied, slots 1/2 empty → dim wins at pal 3. */
    vdp_load_cram_at(32u,  &fs_link_palettes[0][0], 4u);  /* CRAM pal 1 = slot 0 green */
    vdp_load_cram_at(64u,  &fs_link_palettes[1][0], 4u);  /* CRAM pal 2 = slot 1 blue  */
    vdp_load_cram_at(96u,  &fs_link_palettes[3][0], 4u);  /* CRAM pal 3 = dim (v1: slots 1+2 empty) */
}

void fs_main(void) {
    fs_init();
    fs_render_clear_screen();
    fs_render_static_layout();
    fs_render_cursor(0);          /* heart cursor at slot 0 (initial selection) */
    fs_render_all_slots();        /* Link sprites for all 3 save slots */
    vdp_display_on();
    for (;;) {
        wait_vblank();
        /* Phase machine + input poll added v2. */
    }
}
