/* AUTO-GENERATED — see tools/extract_fs_assets.py */
/* fs_palettes[4][4]: 4 Genesis CRAM palettes × 4 colors each.
 *   pal 0 = NES BG pal 0 (attr=0 cells)
 *   pal 1 = NES BG pal 1 (attr=1 cells: LIFE/hearts) + heart cursor
 *   pal 2 = bright Link  (occupied save slot)
 *   pal 3 = faded Link   (empty save slot — Redux dark tint)
 * Source: aldonunez/Z_06.asm:444-449 MenuPalettesTransferBuf,
 *         Zelda1-Redux/src/code/menus/file_select.asm:75-78,
 *         Zelda1-Redux/src/code/menus/menu_tweaks.asm:397-404 */
#include <stdint.h>
const uint16_t fs_palettes[4][4] = {
    { 0x0000, 0x0EEE, 0x0666, 0x0E24 },
    { 0x0000, 0x002C, 0x008E, 0x0CCE },
    { 0x0000, 0x00E6, 0x008E, 0x0048 },
    { 0x0000, 0x0082, 0x0048, 0x0024 },
};
