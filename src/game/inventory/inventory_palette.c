/* inventory_palette.c — L4 (Phase 7 v2). */
#include "inventory_palette.h"
#include "../world/bg_palette.h"

/* Captured 2026-05-20 via build/probes/nes_subscreen_capture.lua,
 * NES Z1 USA rev 1, room $77 OW, MenuState=$08 stable.
 *
 * NES master palette indices. Converted at runtime via
 * roomrom_bg_palette_nes_to_cram (single source of truth = data/misc/palettes.c).
 *
 * Layout:
 *   $00..$03 BG PAL0: $0F black, $30 white, $00 gray, $12 blue
 *     -- text labels (INVENTORY / USE B BUTTON), HUD digits, B-item box
 *   $04..$07 BG PAL1: $0F, $16 red, $27 orange, $36 peach
 *     -- red "INVENTORY" + "USE B BUTTON FOR THIS"
 *   $08..$0B BG PAL2: $0F, $1A green, $37 yellow, $12 blue
 *     -- secondary item colors
 *   $0C..$0F BG PAL3: $0F, $17 brown, $37 yellow, $12 blue
 *     -- TRIFORCE label + triforce-piece fill
 *   $10..$13 SPR PAL0: $00, $29 green, $27 orange, $17 brown
 *     -- passive items
 *   $14..$17 SPR PAL1: $00, $02 blue, $22 purple, $30 white
 *     -- B-item box + cursor flash A
 *   $18..$1B SPR PAL2: $00, $16 red, $27 orange, $30 white
 *     -- item highlights + cursor flash B
 *   $1C..$1F SPR PAL3: $00, $0F black, $1C cyan, $16 red
 *     -- triforce piece sprites
 */
const unsigned char k_inventory_subscreen_palram[32] = {
    0x0Fu, 0x30u, 0x00u, 0x12u,
    0x0Fu, 0x16u, 0x27u, 0x36u,
    0x0Fu, 0x1Au, 0x37u, 0x12u,
    0x0Fu, 0x17u, 0x37u, 0x12u,
    0x00u, 0x29u, 0x27u, 0x17u,
    0x00u, 0x02u, 0x22u, 0x30u,
    0x00u, 0x16u, 0x27u, 0x30u,
    0x00u, 0x0Fu, 0x1Cu, 0x16u
};

/* Forward decl from render_abi.h */
extern void render_load_palette(unsigned short slot, const unsigned short *pal16);

void inventory_palette_load_subscreen(void)
{
    roomrom_bg_palette_load_palram_full(k_inventory_subscreen_palram);

    /* V2.4 fix (2026-05-24): override PAL1/PAL2/PAL3 with NES BG sub-pals
     * 1/2/3 so per-tile plane-attr PAL routing renders text red + triforce
     * yellow + label brown. Gameplay sprites paused so PAL1/2/3 SPR colors
     * unused during subscreen. load_room restores SPR colors on exit. */
    {
        unsigned short pal1[16] = {0};  /* NES BG1 = red ramp */
        unsigned short pal2[16] = {0};  /* NES BG2 = yellow ramp */
        unsigned short pal3[16] = {0};  /* NES BG3 = brown ramp */
        unsigned char i;
        for (i = 0; i < 4; i++) {
            pal1[i] = roomrom_bg_palette_nes_to_cram(k_inventory_subscreen_palram[4 + i]);
            pal2[i] = roomrom_bg_palette_nes_to_cram(k_inventory_subscreen_palram[8 + i]);
            pal3[i] = roomrom_bg_palette_nes_to_cram(k_inventory_subscreen_palram[12 + i]);
        }
        render_load_palette(1u, pal1);
        render_load_palette(2u, pal2);
        render_load_palette(3u, pal3);
    }
}
