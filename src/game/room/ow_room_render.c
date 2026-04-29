#include "ow_room_render.h"
#include "render_abi.h"

extern const unsigned char rooms_overworld[3090];
extern const unsigned char overworld_bg_chr[4160];

#define LEVEL_INFO_OW_OFFSET 768
#define OW_ATTRS_A_OFFSET    0
#define OW_ATTRS_B_OFFSET    128
#define OW_ATTRS_D_OFFSET    384
#define OW_LAYOUTS_OFFSET    1166
#define OW_HEAP_BLOB_OFFSET  2126

/* PrimarySquaresOW from Z_05.asm line 5731 (56 entries).
 * NES accesses this table with the raw sq_idx (0-63); indices 56-63 fall into
 * SecondarySquaresOW[0..7] due to ROM table adjacency, so we replicate that here. */
static const unsigned char s_primary_squares[64] = {
    0x24,0x6F,0xF3,0xFA,0x98,0x90,0x8F,0x95,
    0x8E,0x90,0x74,0x76,0xF3,0x24,0x26,0x89,
    0x03,0x04,0x70,0xC8,0xBC,0x8D,0x8F,0x93,
    0x95,0xC4,0xCE,0xD8,0xB0,0xB4,0xAA,0xAC,
    0xB8,0x9C,0xA6,0x9A,0xA2,0xA0,0xE5,0xE6,
    0xE7,0xE8,0xE9,0xEA,0xC0,0xE0,0x78,0x7A,
    0x7E,0x80,0xCC,0xD0,0xD4,0xDC,0x89,0x84,
    0x24,0x24,0x24,0x24,0x6F,0x6F,0x6F,0x6F  /* SecondarySquaresOW[0..7] */
};

/* SecondarySquaresOW from Z_05.asm line 5740 */
static const unsigned char s_secondary_squares[64] = {
    0x24,0x24,0x24,0x24,0x6F,0x6F,0x6F,0x6F,
    0xF3,0xF3,0xF3,0xF3,0xFA,0xFA,0xFA,0xFA,
    0x98,0x95,0x26,0x26,0x90,0x95,0x90,0x95,
    0x8F,0x90,0x8F,0x90,0x95,0x96,0x95,0x96,
    0x8E,0x93,0x90,0x95,0x90,0x95,0x92,0x97,
    0x74,0x74,0x75,0x75,0x76,0x77,0x76,0x77,
    0xF3,0x24,0xF3,0x24,0x24,0x24,0x24,0x24,
    0x26,0x26,0x26,0x26,0x89,0x88,0x8B,0x88
};

/* Heap byte offsets from data/rooms/MANIFEST.json "ow_heap_offsets" */
static const unsigned short s_heap_offsets[16] = {
    0,53,102,168,236,286,346,405,464,526,591,660,721,775,841,893
};

/* 4 areas x 4 palette slots x 4 Genesis CRAM colors (only indices 0-3 used by 2bpp tiles).
 * area = rooms_overworld[LEVEL_INFO_OW_OFFSET + room_id] >> 6.
 * Colors derived from NES Zelda 1 overworld palette via NesColorToGenesisCRAM. */
static const unsigned short s_ow_area_pal4[4][16] = {
    /* area 0: standard Hyrule north */
    { 0x0000,0x04AE,0x026C,0x0028, 0x0000,0x00A0,0x0060,0x06C6,
      0x0000,0x0E80,0x0E00,0x0EA4, 0x0000,0x0ACE,0x068E,0x004E },
    /* area 1: mountain */
    { 0x0000,0x0EEE,0x0AAA,0x0888, 0x0000,0x04AE,0x026C,0x0028,
      0x0000,0x0E80,0x0E00,0x0EA4, 0x0000,0x00A0,0x0060,0x0000 },
    /* area 2: water/desert */
    { 0x0000,0x0E80,0x0E00,0x0EA4, 0x0000,0x04AE,0x026C,0x0028,
      0x0000,0x00A0,0x0060,0x06C6, 0x0000,0x0000,0x0000,0x0000 },
    /* area 3: south forest (rooms 0x60-0x7F incl. 0x77) */
    { 0x0000,0x04AE,0x026C,0x0028, 0x0000,0x00A0,0x0060,0x06C6,
      0x0000,0x00A0,0x0060,0x06C6, 0x0000,0x0E80,0x0E00,0x0EA4 },
};

void ow_room_render_load_palette(unsigned char room_id)
{
    unsigned char area = rooms_overworld[LEVEL_INFO_OW_OFFSET + room_id] >> 6;
    unsigned short pal16[16];
    unsigned char slot, i;
    for (i = 4; i < 16; i++) pal16[i] = 0;
    for (slot = 0; slot < 4; slot++) {
        for (i = 0; i < 4; i++)
            pal16[i] = s_ow_area_pal4[area][slot * 4 + i];
        render_load_palette(slot, pal16);
    }
}

static void write_square(unsigned char col, unsigned char row,
                         unsigned char tile_tl, unsigned char tile_bl,
                         unsigned char tile_tr, unsigned char tile_br,
                         unsigned char pal)
{
    unsigned short pc = (unsigned short)(col * 2);
    unsigned short pr = (unsigned short)(row * 2 + 2);
    unsigned short pal_bits = (unsigned short)pal << 13;
    unsigned short w;

    /* NES tile index >= 130: CHR pattern is blank in ROM; collapse to tile 0 */
    w = pal_bits | ((tile_tl < 130) ? (unsigned short)tile_tl : 0u);
    render_set_plane_a_word(pc,     pr,     w);
    w = pal_bits | ((tile_bl < 130) ? (unsigned short)tile_bl : 0u);
    render_set_plane_a_word(pc,     pr + 1, w);
    w = pal_bits | ((tile_tr < 130) ? (unsigned short)tile_tr : 0u);
    render_set_plane_a_word(pc + 1, pr,     w);
    w = pal_bits | ((tile_br < 130) ? (unsigned short)tile_br : 0u);
    render_set_plane_a_word(pc + 1, pr + 1, w);
}

void ow_room_render_upload_chr(void)
{
    render_chr_upload(0x0000, overworld_bg_chr, 4160);
}

/*
 * ow_room_palette() -- derive the Genesis palette index (0..3) for a square.
 *
 * Mirrors FillPlayAreaAttrs (Z_05.asm line 984):
 *   - outer_pal = AttrsA[room_id] & 0x03  (fills borders and first attr-row)
 *   - inner_pal = AttrsB[room_id] & 0x03  (fills inner area, attr-rows 1..5)
 *
 * Genesis square (col, row) maps to NES attribute byte via:
 *   attr_col = col / 2  (0..7)
 *   attr_row = row / 2  (0..5, where row = 0..10 are the 11 square rows)
 *
 * FillPlayAreaAttrs fills PlayAreaAttrs[0..47] which corresponds to NES
 * attribute table rows 2..7 (genesis square rows 4..10).  Genesis square
 * rows 0..3 fall in the NES HUD attribute area which uses the outer palette.
 *
 * Within PlayAreaAttrs:
 *   pa_row 0 (genesis sq rows 4,5): entirely outer (inner loop starts at
 *            PlayAreaAttrs offset 9, so row 0 = offsets 0-7 = all outer)
 *   pa_rows 1..3 (genesis sq rows 6..10): border cols (0,7) = outer,
 *            inner cols (1..6) = inner
 *
 * Simplified condition: outer unless attr_row >= 3 && attr_col in [1..6].
 */
static unsigned char ow_room_palette(unsigned char col, unsigned char row,
                                     unsigned char outer_pal,
                                     unsigned char inner_pal)
{
    unsigned char attr_col = col >> 1;   /* col / 2 */
    unsigned char attr_row = row >> 1;   /* row / 2 */

    /* Border columns always use outer palette */
    if (attr_col == 0 || attr_col == 7) {
        return outer_pal;
    }
    /* attr_row < 3: HUD area (rows 0-3) + PlayAreaAttrs row 0 (rows 4-5) = outer */
    if (attr_row < 3) {
        return outer_pal;
    }
    /* Inner area: attr_rows 3..5, attr_cols 1..6 = inner palette */
    return inner_pal;
}

void ow_room_render_fill_plane_a(unsigned char room_id)
{
    unsigned char unique_id;
    unsigned char outer_pal;
    unsigned char inner_pal;
    const unsigned char *col_dirs;
    unsigned char col;

    outer_pal = rooms_overworld[OW_ATTRS_A_OFFSET + room_id] & 0x03;
    inner_pal = rooms_overworld[OW_ATTRS_B_OFFSET + room_id] & 0x03;
    unique_id = rooms_overworld[OW_ATTRS_D_OFFSET + room_id] & 0x3F;
    col_dirs  = &rooms_overworld[OW_LAYOUTS_OFFSET + (unsigned short)unique_id * 16];

    for (col = 0; col < 16; col++) {
        unsigned char desc       = col_dirs[col];
        unsigned char heap_idx   = (desc >> 4) & 0x0F;
        unsigned char col_in_heap = desc & 0x0F;
        const unsigned char *heap_ptr;
        unsigned short y;
        unsigned char cols_found;
        unsigned char row;
        unsigned char repeat_state;

        heap_ptr = &rooms_overworld[OW_HEAP_BLOB_OFFSET + s_heap_offsets[heap_idx]];

        /* Each column block opens with a bit7-set byte that doubles as the first tile row */
        y = 0;
        cols_found = col_in_heap;
        while (1) {
            if (heap_ptr[y] & 0x80) {
                if (cols_found == 0) break;
                cols_found--;
            }
            y++;
        }
        heap_ptr += y;

        row = 0;
        repeat_state = 0;
        while (row < 11) {
            unsigned char sq_byte = heap_ptr[0];
            unsigned char sq_idx  = sq_byte & 0x3F;
            unsigned char tile_tl, tile_bl, tile_tr, tile_br;
            unsigned char pal;

            if (sq_idx >= 0x10) {
                unsigned char p = s_primary_squares[sq_idx];
                tile_tl = p;
                tile_bl = p + 1;
                tile_tr = p + 2;
                tile_br = p + 3;
            } else {
                unsigned char b = (unsigned char)(sq_idx * 4);
                tile_tl = s_secondary_squares[b];
                tile_bl = s_secondary_squares[b + 1];
                tile_tr = s_secondary_squares[b + 2];
                tile_br = s_secondary_squares[b + 3];
            }

            pal = ow_room_palette(col, row, outer_pal, inner_pal);
            write_square(col, row, tile_tl, tile_bl, tile_tr, tile_br, pal);
            row++;

            if (sq_byte & 0x40) {
                repeat_state ^= 0x40;
                if (repeat_state != 0) continue;
            }
            heap_ptr++;
        }
    }
}
