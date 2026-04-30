#include "ow_room_render_roomrom.h"
#include "render_abi.h"

extern const unsigned char rooms_overworld[];
extern const unsigned char rooms_overworld_redux[];
extern const unsigned short rooms_overworld_redux_heap_offsets[16];
extern const unsigned char common_chr[7616];
extern const unsigned char overworld_bg_chr[4160];
extern const unsigned char redux_overworld_bg_chr[4160];
extern const unsigned char redux_overworld_secret_chr[384];
extern const unsigned char redux_automap_chr[1024];
extern const unsigned char misc_palettes[1208];

#define LEVEL_INFO_OW_OFFSET 768
#define OW_ATTRS_A_OFFSET    0
#define OW_ATTRS_B_OFFSET    128
#define OW_ATTRS_D_OFFSET    384
#define OW_LAYOUTS_OFFSET    1166
#define OW_HEAP_BLOB_OFFSET  3150

#define LEVEL_INFO_PALETTE_OFFSET (LEVEL_INFO_OW_OFFSET + 3)

#define OW_VDP_TILE_BASE          1u
#define COMMON_BG_TILE_COUNT      112u
#define OW_BG_TILE_COUNT          130u
#define COMMON_MISC_TILE_COUNT    14u
#define REDUX_AUTOMAP_TILE_COUNT  32u
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

static const unsigned char s_tile_object_primary_ow_redux[6] = {
    0xC8,0x58,0x5C,0xBC,0xC0,0xC0
};

static const unsigned char s_pal_to_attr[4] = {
    0x00,0x55,0xAA,0xFF
};

/* Heap byte offsets from data/rooms/MANIFEST.json "ow_heap_offsets" */
static const unsigned short s_heap_offsets[16] = {
    0,53,102,168,236,286,346,405,464,526,591,660,721,775,841,893
};

static unsigned char s_roomrom_map_id = ROOMROM_MAP_ORIGINAL;

/* S5 collision: walkable metatile grid for the current OW room. Filled
 * during fill_plane_a; queried by main loop pre-step.
 * 16 cols x 11 rows, 1 = walkable, 0 = blocking. */
static unsigned char s_walkable[16][11];

/* OW walkable NES tile IDs. Sourced from
 *   reference/aldonunez/Z_07.asm WalkableTiles ($8D,$91,$9C,$AC,$AD,$CC,$D2,$D5,$DF)
 * plus paths/sand/stairs/shore/redux variants observed in s_primary_squares
 * and s_secondary_squares_redux. */
static unsigned char ow_walkable_primary(unsigned char primary)
{
    switch (primary) {
        case 0x03: case 0x04:
        case 0x24: case 0x26:
        case 0x54: case 0x56: case 0x58: case 0x5C:
        case 0x6F: case 0x70:
        case 0x74: case 0x75: case 0x76: case 0x77:
        case 0x84:
        case 0x8D:
        case 0x91:
        case 0x9C:
        case 0xAC: case 0xAD:
        case 0xCC:
        case 0xD2: case 0xD5: case 0xDF:
            return 1u;
        default:
            return 0u;
    }
}

unsigned char roomrom_ow_room_render_walkable_at(unsigned char col,
                                                 unsigned char row)
{
    if (col >= 16u || row >= 11u) return 0u;
    return s_walkable[col][row];
}

static const unsigned char s_secondary_squares_redux[64] = {
    0x24,0x24,0x24,0x24,0x6F,0x6F,0x6F,0x6F,
    0xF3,0xF3,0xF3,0xF3,0xFA,0xFA,0xFA,0xFA,
    0xF3,0x24,0xF3,0x24,0x90,0x95,0x90,0x95,
    0x8F,0x90,0x8F,0x90,0x95,0x96,0x95,0x96,
    0x8E,0x93,0x90,0x95,0x90,0x95,0x92,0x97,
    0x74,0x74,0x75,0x75,0x76,0x77,0x76,0x77,
    0x54,0x24,0x56,0x24,0x24,0x24,0x24,0x24,
    0x26,0x26,0x26,0x26,0x89,0x88,0x8B,0x88
};

static const unsigned char *roomrom_rooms(void)
{
    return (s_roomrom_map_id == ROOMROM_MAP_REDUX) ? rooms_overworld_redux
                                                   : rooms_overworld;
}

static const unsigned short *roomrom_heap_offsets(void)
{
    return (s_roomrom_map_id == ROOMROM_MAP_REDUX) ? rooms_overworld_redux_heap_offsets
                                                   : s_heap_offsets;
}

static const unsigned char *roomrom_secondary_squares(void)
{
    return (s_roomrom_map_id == ROOMROM_MAP_REDUX) ? s_secondary_squares_redux
                                                   : s_secondary_squares;
}

void roomrom_ow_room_render_set_map(unsigned char map_id)
{
    s_roomrom_map_id = (map_id == ROOMROM_MAP_REDUX) ? ROOMROM_MAP_REDUX
                                                     : ROOMROM_MAP_ORIGINAL;
}

unsigned char roomrom_ow_room_render_get_map(void)
{
    return s_roomrom_map_id;
}

static unsigned short nes_color_to_cram(unsigned char color)
{
    unsigned short off = (unsigned short)color * 2u;
    return (unsigned short)misc_palettes[off] |
           ((unsigned short)misc_palettes[off + 1] << 8);
}

void roomrom_ow_room_render_load_palette(unsigned char room_id)
{
    unsigned short pal16[16];
    unsigned char slot, i;
    const unsigned char *rooms = roomrom_rooms();

    (void)room_id;

    /* PAL3 reserved for sprites (see roomrom_sprites). BG owns PAL0..PAL2. */
    for (slot = 0; slot < 3; slot++) {
        for (i = 0; i < 16; i++)
            pal16[i] = 0;
        for (i = 0; i < 4; i++)
            pal16[i] = nes_color_to_cram(
                rooms[LEVEL_INFO_PALETTE_OFFSET + slot * 4 + i]);
        render_load_palette(slot, pal16);
    }
}

static unsigned char normalize_primary_tile(unsigned char raw)
{
    if (raw >= 0xE5 && raw <= 0xEA) {
        unsigned char idx = (unsigned char)(raw - 0xE5);
        if (s_roomrom_map_id == ROOMROM_MAP_REDUX)
            return s_tile_object_primary_ow_redux[idx];
        return s_tile_object_primary_ow[idx];
    }
    return raw;
}

void roomrom_ow_room_render_upload_chr(void)
{
    const unsigned char *ow_chr =
        (s_roomrom_map_id == ROOMROM_MAP_REDUX) ? redux_overworld_bg_chr
                                                : overworld_bg_chr;

    render_chr_upload((unsigned short)(OW_VDP_TILE_BASE * 32u),
                      common_chr + COMMON_BG_CHR_OFFSET,
                      (unsigned short)(COMMON_BG_TILE_COUNT * 32u));
    render_chr_upload((unsigned short)((OW_VDP_TILE_BASE + 0x30u) * 32u),
                      redux_automap_chr,
                      (unsigned short)(REDUX_AUTOMAP_TILE_COUNT * 32u));
    if (s_roomrom_map_id == ROOMROM_MAP_REDUX) {
        render_chr_upload((unsigned short)((OW_VDP_TILE_BASE + 0x54u) * 32u),
                          redux_overworld_secret_chr,
                          (unsigned short)(12u * 32u));
    }
    render_chr_upload((unsigned short)((OW_VDP_TILE_BASE + COMMON_BG_TILE_COUNT) * 32u),
                      ow_chr,
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

/* Palette uses src tile coords (where the tile semantically lives in its
 * source room). Plane write uses dst tile coords (where the tile actually
 * lands on the BG plane — supports off-room rendering during scroll). */
static void write_tile_at(unsigned char src_tile_col, unsigned char src_tile_row,
                          unsigned char dst_tile_col, unsigned char dst_tile_row,
                          unsigned char raw_tile,
                          unsigned char outer_pal,
                          unsigned char inner_pal)
{
    unsigned char pal = ow_tile_palette(src_tile_col, src_tile_row,
                                        outer_pal, inner_pal);
    render_set_plane_a_word(dst_tile_col,
                            (unsigned short)(dst_tile_row + ROOMROM_ROOM_FIRST_ROW),
                            tile_word(raw_tile, pal));
}

static void write_tile(unsigned char tile_col, unsigned char tile_row,
                       unsigned char raw_tile,
                       unsigned char outer_pal,
                       unsigned char inner_pal)
{
    write_tile_at(tile_col, tile_row, tile_col, tile_row,
                  raw_tile, outer_pal, inner_pal);
}

static void write_square_at(unsigned char src_col, unsigned char dst_col,
                            unsigned char row,
                            unsigned char tile_tl, unsigned char tile_bl,
                            unsigned char tile_tr, unsigned char tile_br,
                            unsigned char outer_pal,
                            unsigned char inner_pal)
{
    unsigned char src_tc = (unsigned char)(src_col << 1);
    unsigned char dst_tc = (unsigned char)(dst_col << 1);
    unsigned char tile_row = (unsigned char)(row << 1);

    write_tile_at(src_tc,     tile_row,     dst_tc,     tile_row,
                  tile_tl, outer_pal, inner_pal);
    write_tile_at(src_tc,     tile_row + 1, dst_tc,     tile_row + 1,
                  tile_bl, outer_pal, inner_pal);
    write_tile_at(src_tc + 1, tile_row,     dst_tc + 1, tile_row,
                  tile_tr, outer_pal, inner_pal);
    write_tile_at(src_tc + 1, tile_row + 1, dst_tc + 1, tile_row + 1,
                  tile_br, outer_pal, inner_pal);
}

static void write_square(unsigned char col, unsigned char row,
                         unsigned char tile_tl, unsigned char tile_bl,
                         unsigned char tile_tr, unsigned char tile_br,
                         unsigned char outer_pal,
                         unsigned char inner_pal)
{
    write_square_at(col, col, row,
                    tile_tl, tile_bl, tile_tr, tile_br,
                    outer_pal, inner_pal);
}

/* Render a single source metatile column from `room_id` into plane
 * metatile column `dst_col`. `src_col` selects which column of the
 * source room (so palette/attribute logic uses src coords). Updates
 * s_walkable[dst_col] for collision queries. Plane writes wrap at 32
 * plane cols via SGDK's setTileMapXY. */
static void render_one_metatile_col(unsigned char room_id,
                                    unsigned char src_col,
                                    unsigned char dst_col)
{
    const unsigned char *rooms = roomrom_rooms();
    const unsigned short *heap_offsets = roomrom_heap_offsets();
    const unsigned char *secondary_squares = roomrom_secondary_squares();
    unsigned char outer_pal = rooms[OW_ATTRS_A_OFFSET + room_id] & 0x03;
    unsigned char inner_pal = rooms[OW_ATTRS_B_OFFSET + room_id] & 0x03;
    unsigned char unique_id = rooms[OW_ATTRS_D_OFFSET + room_id] & 0x7F;
    const unsigned char *col_dirs = &rooms[OW_LAYOUTS_OFFSET +
                                            (unsigned short)unique_id * 16];
    unsigned char desc        = col_dirs[src_col];
    unsigned char heap_idx    = (desc >> 4) & 0x0F;
    unsigned char col_in_heap = desc & 0x0F;
    const unsigned char *heap_ptr = &rooms[OW_HEAP_BLOB_OFFSET + heap_offsets[heap_idx]];
    unsigned short y = 0;
    unsigned char cols_found = col_in_heap;
    unsigned char row = 0;
    unsigned char repeat_state = 0;

    while (1) {
        if (heap_ptr[y] & 0x80) {
            if (cols_found == 0) break;
            cols_found--;
        }
        y++;
    }
    heap_ptr += y;

    while (row < 11) {
        unsigned char sq_byte = heap_ptr[0];
        unsigned char sq_idx  = sq_byte & 0x3F;
        unsigned char tile_tl, tile_bl, tile_tr, tile_br;
        unsigned char primary_for_walk;

        if (sq_idx >= 0x10) {
            unsigned char p = normalize_primary_tile(s_primary_squares[sq_idx]);
            tile_tl = p;
            tile_bl = p + 1;
            tile_tr = p + 2;
            tile_br = p + 3;
            primary_for_walk = p;
        } else {
            unsigned char b = (unsigned char)(sq_idx * 4);
            tile_tl = secondary_squares[b];
            tile_bl = secondary_squares[b + 1];
            tile_tr = secondary_squares[b + 2];
            tile_br = secondary_squares[b + 3];
            primary_for_walk = tile_tl;
        }

        write_square_at(src_col, dst_col, row,
                        tile_tl, tile_bl, tile_tr, tile_br,
                        outer_pal, inner_pal);
        s_walkable[dst_col & 0x0F][row] = ow_walkable_primary(primary_for_walk);
        row++;

        if (sq_byte & 0x40) {
            repeat_state ^= 0x40;
            if (repeat_state != 0) continue;
        }
        heap_ptr++;
    }
}

void roomrom_ow_room_render_fill_one_col(unsigned char room_id,
                                         unsigned char src_col,
                                         unsigned char dst_col)
{
    render_one_metatile_col(room_id, src_col & 0x0F, dst_col & 0x1F);
}

void roomrom_ow_room_render_fill_plane_a(unsigned char room_id)
{
    unsigned char col;
    for (col = 0; col < 16; col++) {
        render_one_metatile_col(room_id, col, col);
    }
}

/* Old monolithic body kept for reference until verified equivalent; now dead. */
#if 0
void roomrom_ow_room_render_fill_plane_a_OLD(unsigned char room_id)
{
    unsigned char unique_id;
    unsigned char outer_pal;
    unsigned char inner_pal;
    const unsigned char *col_dirs;
    const unsigned char *rooms = roomrom_rooms();
    const unsigned short *heap_offsets = roomrom_heap_offsets();
    const unsigned char *secondary_squares = roomrom_secondary_squares();
    unsigned char col;

    outer_pal = rooms[OW_ATTRS_A_OFFSET + room_id] & 0x03;
    inner_pal = rooms[OW_ATTRS_B_OFFSET + room_id] & 0x03;
    unique_id = rooms[OW_ATTRS_D_OFFSET + room_id] & 0x7F;
    col_dirs  = &rooms[OW_LAYOUTS_OFFSET + (unsigned short)unique_id * 16];

    for (col = 0; col < 16; col++) {
        unsigned char desc       = col_dirs[col];
        unsigned char heap_idx   = (desc >> 4) & 0x0F;
        unsigned char col_in_heap = desc & 0x0F;
        const unsigned char *heap_ptr;
        unsigned short y;
        unsigned char cols_found;
        unsigned char row;
        unsigned char repeat_state;

        heap_ptr = &rooms[OW_HEAP_BLOB_OFFSET + heap_offsets[heap_idx]];

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
            unsigned char primary_for_walk;

            if (sq_idx >= 0x10) {
                unsigned char p = normalize_primary_tile(s_primary_squares[sq_idx]);
                tile_tl = p;
                tile_bl = p + 1;
                tile_tr = p + 2;
                tile_br = p + 3;
                primary_for_walk = p;
            } else {
                unsigned char b = (unsigned char)(sq_idx * 4);
                tile_tl = secondary_squares[b];
                tile_bl = secondary_squares[b + 1];
                tile_tr = secondary_squares[b + 2];
                tile_br = secondary_squares[b + 3];
                /* Classify secondary squares by their TL tile id (close enough
                 * for v1; secondary squares are rare and mostly path/edge). */
                primary_for_walk = tile_tl;
            }

            write_square(col, row, tile_tl, tile_bl, tile_tr, tile_br,
                         outer_pal, inner_pal);
            s_walkable[col][row] = ow_walkable_primary(primary_for_walk);
            row++;

            if (sq_byte & 0x40) {
                repeat_state ^= 0x40;
                if (repeat_state != 0) continue;
            }
            heap_ptr++;
        }
    }
}
#endif
