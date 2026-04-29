#include "ow_room_render.h"
#include "render_abi.h"

extern const unsigned char rooms_overworld[3090];
extern const unsigned char common_chr[7616];
extern const unsigned char overworld_bg_chr[4160];
extern const unsigned char misc_palettes[1208];

#define LEVEL_INFO_OW_OFFSET 768
#define OW_ATTRS_A_OFFSET    0
#define OW_ATTRS_B_OFFSET    128
#define OW_ATTRS_D_OFFSET    384
#define OW_LAYOUTS_OFFSET    1166
#define OW_HEAP_BLOB_OFFSET  2126

#define LEVEL_INFO_PALETTE_OFFSET (LEVEL_INFO_OW_OFFSET + 3)

#define OW_VDP_TILE_BASE          1u
#define COMMON_BG_TILE_COUNT      112u
#define OW_BG_TILE_COUNT          130u
#define COMMON_MISC_TILE_COUNT    14u
#define COMMON_BG_CHR_OFFSET      (112u * 32u)
#define COMMON_MISC_CHR_OFFSET    (224u * 32u)

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

static const unsigned char s_tile_object_primary_ow[6] = {
    0xC8,0xD8,0xC4,0xBC,0xC0,0xC0
};

static const unsigned char s_pal_to_attr[4] = {
    0x00,0x55,0xAA,0xFF
};

/* Heap byte offsets from data/rooms/MANIFEST.json "ow_heap_offsets" */
static const unsigned short s_heap_offsets[16] = {
    0,53,102,168,236,286,346,405,464,526,591,660,721,775,841,893
};

static unsigned short nes_color_to_cram(unsigned char color)
{
    unsigned short off = (unsigned short)color * 2u;
    return (unsigned short)misc_palettes[off] |
           ((unsigned short)misc_palettes[off + 1] << 8);
}

void ow_room_render_load_palette(unsigned char room_id)
{
    unsigned short pal16[16];
    unsigned char slot, i;

    (void)room_id;

    for (slot = 0; slot < 4; slot++) {
        for (i = 0; i < 16; i++)
            pal16[i] = 0;
        for (i = 0; i < 4; i++)
            pal16[i] = nes_color_to_cram(
                rooms_overworld[LEVEL_INFO_PALETTE_OFFSET + slot * 4 + i]);
        render_load_palette(slot, pal16);
    }
}

static unsigned char normalize_primary_tile(unsigned char raw)
{
    if (raw >= 0xE5 && raw <= 0xEA)
        return s_tile_object_primary_ow[raw - 0xE5];
    return raw;
}

void ow_room_render_upload_chr(void)
{
    render_chr_upload((unsigned short)(OW_VDP_TILE_BASE * 32u),
                      common_chr + COMMON_BG_CHR_OFFSET,
                      (unsigned short)(COMMON_BG_TILE_COUNT * 32u));
    render_chr_upload((unsigned short)((OW_VDP_TILE_BASE + COMMON_BG_TILE_COUNT) * 32u),
                      overworld_bg_chr,
                      (unsigned short)(OW_BG_TILE_COUNT * 32u));
    render_chr_upload((unsigned short)((OW_VDP_TILE_BASE + COMMON_BG_TILE_COUNT + OW_BG_TILE_COUNT) * 32u),
                      common_chr + COMMON_MISC_CHR_OFFSET,
                      (unsigned short)(COMMON_MISC_TILE_COUNT * 32u));
}

static unsigned char ow_tile_palette(unsigned char tile_col, unsigned char tile_row,
                                     unsigned char outer_pal,
                                     unsigned char inner_pal)
{
    unsigned char attr_index = (unsigned char)(((tile_row >> 2) << 3) + (tile_col >> 2));
    unsigned char attr_col = attr_index & 0x07;
    unsigned char attr = s_pal_to_attr[outer_pal & 0x03];
    unsigned char inner_attr = s_pal_to_attr[inner_pal & 0x03];
    unsigned char shift = 0;

    if (attr_index >= 9 && attr_index < 0x27 && attr_col != 0 && attr_col != 7) {
        if (attr_index >= 0x21)
            attr = (unsigned char)((inner_attr & 0x0F) | (attr & 0xF0));
        else
            attr = inner_attr;
    }

    if (tile_col & 0x02)
        shift += 2;
    if (tile_row & 0x02)
        shift += 4;
    return (unsigned char)((attr >> shift) & 0x03);
}

static unsigned short tile_word(unsigned char raw_tile, unsigned char pal)
{
    return (unsigned short)(((unsigned short)(pal & 0x03) << 13) |
                            ((unsigned short)raw_tile + OW_VDP_TILE_BASE));
}

static void write_tile(unsigned char tile_col, unsigned char tile_row,
                       unsigned char raw_tile,
                       unsigned char outer_pal,
                       unsigned char inner_pal)
{
    unsigned char pal = ow_tile_palette(tile_col, tile_row, outer_pal, inner_pal);
    render_set_plane_a_word(tile_col, (unsigned short)(tile_row + 2),
                            tile_word(raw_tile, pal));
}

static void write_square(unsigned char col, unsigned char row,
                         unsigned char tile_tl, unsigned char tile_bl,
                         unsigned char tile_tr, unsigned char tile_br,
                         unsigned char outer_pal,
                         unsigned char inner_pal)
{
    unsigned char tile_col = (unsigned char)(col << 1);
    unsigned char tile_row = (unsigned char)(row << 1);

    write_tile(tile_col,     tile_row,     tile_tl, outer_pal, inner_pal);
    write_tile(tile_col,     tile_row + 1, tile_bl, outer_pal, inner_pal);
    write_tile(tile_col + 1, tile_row,     tile_tr, outer_pal, inner_pal);
    write_tile(tile_col + 1, tile_row + 1, tile_br, outer_pal, inner_pal);
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

            if (sq_idx >= 0x10) {
                unsigned char p = normalize_primary_tile(s_primary_squares[sq_idx]);
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

            write_square(col, row, tile_tl, tile_bl, tile_tr, tile_br,
                         outer_pal, inner_pal);
            row++;

            if (sq_byte & 0x40) {
                repeat_state ^= 0x40;
                if (repeat_state != 0) continue;
            }
            heap_ptr++;
        }
    }
}
