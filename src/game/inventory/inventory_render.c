/* inventory_render.c — see header.
 *
 * V1 layout: simple text + slot grid. Renders entire Plane A as one
 * static frame on subscreen-enter. NES reference is row-by-row scroll
 * (Z_05.asm:6763-6837 Submenu_CueTransferRowUW/OW) but for V1 we paint
 * the full layout in one frame; scroll-in animation (P6.3) wraps this.
 *
 * Tile_ids referenced:
 *   $00-$09 = digits '0'-'9' (Common BG)
 *   $0A-$23 = uppercase 'A'-'V' (Common BG; alphabet starts at $0A per Z1)
 *   $24+    = punctuation
 *   $24..$2F = various symbols (',' '!' "'" '"' '?' '-' '.' etc)
 *
 * Genesis: tile_id via bg_sparse_tile_lut[tile][sub_pal] -> slot in
 * VRAM = ROOMROM_BG_TILE_BASE + slot.
 */
#include "inventory_render.h"
#include "../../abi/platform_abi.h"
#include "../../abi/render_abi.h"
#include "../../../RoomRom/src/bg_sparse_chr.h"
#include "../../../RoomRom/src/roomrom_vram_map.h"
#include "../../state/inventory.h"

#define PLANE_A_BASE      0xC000u
#define BLANK_TILE        1000u
#define SUBSCREEN_SUBPAL  0u  /* PAL0 for BG */

static unsigned char s_active = 0u;

unsigned char inventory_subscreen_is_active(void)
{
    return s_active;
}

/* Resolve a NES tile_id to its Genesis VRAM tile via sparse LUT.
 * Returns BLANK_TILE if not in atlas. */
static unsigned short tile_for(unsigned char nes_tile, unsigned char sub_pal)
{
    unsigned short slot = bg_sparse_tile_lut[nes_tile][sub_pal];
    if (slot == 0xFFFFu) return BLANK_TILE;
    return (unsigned short)(ROOMROM_BG_TILE_BASE + slot);
}

/* Convert ASCII char to NES Z1 tile_id. Z1 BG glyph layout per common.c:
 *   '0'..'9' -> tile $00..$09
 *   'A'..'Z' -> tile $0A..$23
 *   ' '      -> tile $24 (blank)
 *   '!'      -> tile $25
 *   "'"      -> tile $26
 *   ','      -> tile $27
 *   '-'      -> tile $28 (per Z1 ROM dump)
 *   '.'      -> tile $29
 *   '?'      -> tile $2A
 *   '"'      -> tile $2B
 * Other chars fall through to BLANK_TILE. */
static unsigned char ascii_to_tile(char c)
{
    if (c >= '0' && c <= '9') return (unsigned char)(c - '0');
    if (c >= 'A' && c <= 'Z') return (unsigned char)(0x0A + (c - 'A'));
    if (c == ' ') return 0x24u;
    if (c == '!') return 0x25u;
    if (c == '\'') return 0x26u;
    if (c == ',') return 0x27u;
    if (c == '-') return 0x28u;
    if (c == '.') return 0x29u;
    if (c == '?') return 0x2Au;
    if (c == '"') return 0x2Bu;
    return 0x24u;  /* default to blank */
}

/* Write a string to Plane A row starting at col. String must fit in
 * cells_buf (up to 32 cells). */
static void write_text(unsigned short row, unsigned short col,
                       const char *str)
{
    unsigned short cells[32];
    unsigned short n = 0u;
    while (str[n] != '\0' && (col + n) < 32u && n < 32u) {
        unsigned char tid = ascii_to_tile(str[n]);
        cells[n] = RENDER_TILE_ATTR_FULL(SUBSCREEN_SUBPAL, 0, 0, 0,
                                         tile_for(tid, SUBSCREEN_SUBPAL));
        ++n;
    }
    /* Genesis VRAM write to plane A cell (row, col) for n cells. We use
     * render_plane_a_write_row which writes from col=0. To write at an
     * offset, build a full-row buffer with leading blanks. */
    unsigned short full[32];
    unsigned short i;
    unsigned short blank_attr = RENDER_TILE_ATTR_FULL(SUBSCREEN_SUBPAL, 0, 0, 0,
                                                      BLANK_TILE);
    for (i = 0; i < 32u; ++i) full[i] = blank_attr;
    for (i = 0; i < n; ++i) {
        if ((col + i) < 32u) full[col + i] = cells[i];
    }
    render_plane_a_write_row(row, full, 32u);
}

void inventory_subscreen_enter(void)
{
    /* Fill Plane A with blank tile (PAL0 backdrop = black). */
    unsigned short blank_attr = RENDER_TILE_ATTR_FULL(SUBSCREEN_SUBPAL, 0, 0, 0,
                                                      BLANK_TILE);
    render_plane_fill(PLANE_A_BASE, blank_attr, 32u * 32u);

    /* V1 minimal layout — NES Z1 inventory subscreen text. */
    write_text(3u,  3u, "INVENTORY");
    write_text(5u,  3u, "USE B BUTTON FOR THIS");
    write_text(7u,  3u, "B  A  ");

    /* Item slot grid — 4 rows x 7 cols labels.
     * NES Z1 actual slot positions are pixel-based; we approximate via
     * even-cell grid for V1 readability. */
    write_text(9u,  3u, "PASSIVE ITEMS");
    write_text(11u, 3u, "BOW  BOOM CAND ARRW BMRG WAND BAIT");
    write_text(13u, 3u, "RAFT BOOK RING LADD KEY  BRAC LETR");

    write_text(15u, 3u, "TRIFORCE");
    /* Triforce piece labels — 8 pieces */
    write_text(17u, 3u, "1 2 3 4 5 6 7 8");

    write_text(19u, 3u, "RUPEES KEYS BOMBS");
    write_text(21u, 3u, "HEARTS");

    s_active = 1u;
}

void inventory_subscreen_exit(void)
{
    s_active = 0u;
    /* Room renderer will re-paint Plane A on next room-load cycle.
     * Until then, leaving subscreen content visible is fine — RoomRom
     * main.c calls roomrom_*_room_render_load on scene transitions OR
     * we can flag a redraw here. For V1, depend on natural redraw. */
}

void inventory_subscreen_tick(unsigned char joy_state)
{
    /* P6.5 lands cursor + selection here. V1 no-op. */
    (void)joy_state;
}
