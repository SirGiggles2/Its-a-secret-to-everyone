#include "uw_room_render_roomrom.h"
#include "uw_room_blob.h"
#include "render_abi.h"

extern const unsigned char rooms_dungeons[];
extern const unsigned char common_chr[7616];
extern const unsigned char underworld_bg_chr[4160];
extern const unsigned char misc_palettes[1208];

#define UW_LEVELBLOCK_SIZE       768u
#define UW_LEVELINFO_SIZE        256u
#define UW_LEVELINFO_BASE        3072u
#define UW_LEVELINFO_PAL_OFFSET  3u

#define UW_VDP_TILE_BASE         1u
#define COMMON_BG_TILE_COUNT     112u
#define UW_BG_TILE_COUNT         130u
#define COMMON_MISC_TILE_COUNT   14u
#define COMMON_BG_CHR_OFFSET     (112u * 32u)
#define COMMON_MISC_CHR_OFFSET   (224u * 32u)

static unsigned char s_uw_map_id = ROOMROM_MAP_ORIGINAL;
static unsigned char s_uw_level  = 1u;

void roomrom_uw_room_render_set_map(unsigned char map_id)
{
    s_uw_map_id = (map_id == ROOMROM_MAP_REDUX) ? ROOMROM_MAP_REDUX
                                                 : ROOMROM_MAP_ORIGINAL;
}

unsigned char roomrom_uw_room_render_get_map(void)
{
    return s_uw_map_id;
}

void roomrom_uw_room_render_set_level(unsigned char level)
{
    if (level < ROOMROM_UW_LEVEL_MIN) level = ROOMROM_UW_LEVEL_MIN;
    if (level > ROOMROM_UW_LEVEL_MAX) level = ROOMROM_UW_LEVEL_MAX;
    s_uw_level = level;
}

unsigned char roomrom_uw_room_render_get_level(void)
{
    return s_uw_level;
}

static unsigned short nes_color_to_cram(unsigned char color)
{
    unsigned short off = (unsigned short)color * 2u;
    return (unsigned short)misc_palettes[off] |
           ((unsigned short)misc_palettes[off + 1] << 8);
}

static int find_blob_entry(unsigned char level, unsigned char room_id)
{
    unsigned short i;
    unsigned char want_map = (s_uw_map_id == ROOMROM_MAP_REDUX) ? 1u : 0u;
    for (i = 0; i < g_uw_room_count; i++) {
        if (g_uw_room_index[i][0] == want_map &&
            g_uw_room_index[i][1] == level &&
            g_uw_room_index[i][2] == room_id) {
            return (int)i;
        }
    }
    return -1;
}

static void load_palette_from_blob(int idx)
{
    unsigned short pal16[16];
    unsigned char slot, i;
    const unsigned char *pal = g_uw_room_palette[idx];
    for (slot = 0; slot < 4; slot++) {
        for (i = 0; i < 16; i++)
            pal16[i] = 0;
        for (i = 0; i < 4; i++)
            pal16[i] = nes_color_to_cram(pal[slot * 4 + i]);
        render_load_palette(slot, pal16);
    }
}

static void load_palette_from_levelinfo(void)
{
    unsigned short pal16[16];
    unsigned char slot, i;
    unsigned short level_off = (unsigned short)(UW_LEVELINFO_BASE +
        ((unsigned short)(s_uw_level - 1u) * UW_LEVELINFO_SIZE) +
        UW_LEVELINFO_PAL_OFFSET);
    for (slot = 0; slot < 4; slot++) {
        for (i = 0; i < 16; i++)
            pal16[i] = 0;
        for (i = 0; i < 4; i++)
            pal16[i] = nes_color_to_cram(
                rooms_dungeons[level_off + slot * 4 + i]);
        render_load_palette(slot, pal16);
    }
}

void roomrom_uw_room_render_load_palette(unsigned char room_id)
{
    int idx = find_blob_entry(s_uw_level, room_id);
    if (idx >= 0) {
        load_palette_from_blob(idx);
    } else {
        load_palette_from_levelinfo();
    }
}

void roomrom_uw_room_render_upload_chr(void)
{
    render_chr_upload((unsigned short)(UW_VDP_TILE_BASE * 32u),
                      common_chr + COMMON_BG_CHR_OFFSET,
                      (unsigned short)(COMMON_BG_TILE_COUNT * 32u));
    render_chr_upload((unsigned short)((UW_VDP_TILE_BASE + COMMON_BG_TILE_COUNT) * 32u),
                      underworld_bg_chr,
                      (unsigned short)(UW_BG_TILE_COUNT * 32u));
    render_chr_upload((unsigned short)((UW_VDP_TILE_BASE + COMMON_BG_TILE_COUNT + UW_BG_TILE_COUNT) * 32u),
                      common_chr + COMMON_MISC_CHR_OFFSET,
                      (unsigned short)(COMMON_MISC_TILE_COUNT * 32u));
}

/* Stub renderer.
 *
 * The NES dungeon room render path (z_05.asm LayoutUWFloor + WriteSquareUW
 * + ColumnDirectoryUW) interprets per-room column directories, level-specific
 * column heaps, and 8-entry primary square table. Faithfully porting that
 * pipeline takes more time than this round budgets, so for now this stub:
 *   - Clears plane A play area to a flat dungeon-floor square (PrimarySquaresUW[4] = $70).
 *   - Writes the level number and room id as glyphs for diagnostic visibility.
 *
 * Real renderer ports the LayoutUWFloor logic in a follow-up commit. */
static void write_tile_raw(unsigned char col, unsigned char row,
                           unsigned char raw_tile, unsigned char pal)
{
    unsigned short word = (unsigned short)(((unsigned short)(pal & 0x03) << 13) |
                                            ((unsigned short)raw_tile + UW_VDP_TILE_BASE));
    render_set_plane_a_word(col, (unsigned short)(row + ROOMROM_ROOM_FIRST_ROW), word);
}

static unsigned char digit_tile(unsigned char d)
{
    return (unsigned char)(d & 0x0F);
}

static unsigned char attr_palette_for(const unsigned char *attr,
                                       unsigned char nt_col,
                                       unsigned char nt_row)
{
    /* AT covers NT in 8x8 grid of 32x32 quads. Each AT byte holds 4
     * 2-bit palette quads laid out: bits 0-1=TL, 2-3=TR, 4-5=BL, 6-7=BR.
     * AT byte index: (nt_row/4)*8 + (nt_col/4). */
    unsigned char at_idx = (unsigned char)(((nt_row >> 2) << 3) | (nt_col >> 2));
    unsigned char byte = attr[at_idx & 0x3F];
    unsigned char shift = (unsigned char)((((nt_row >> 1) & 1u) << 2) |
                                          (((nt_col >> 1) & 1u) << 1));
    return (unsigned char)((byte >> shift) & 0x03u);
}

static void blit_blob(int idx)
{
    const unsigned char *nt = g_uw_room_nt[idx];
    const unsigned char *attr = g_uw_room_attr[idx];
    unsigned char row, col;
    for (row = 0; row < ROOMROM_UW_BLOB_ROWS; row++) {
        for (col = 0; col < ROOMROM_UW_BLOB_COLS; col++) {
            unsigned char raw = nt[row * ROOMROM_UW_BLOB_COLS + col];
            /* Play area starts at NT row 8 (HUD occupies rows 0..7). */
            unsigned char nt_row = (unsigned char)(row + 8u);
            unsigned char pal = attr_palette_for(attr, col, nt_row);
            write_tile_raw(col, row, raw, pal);
        }
    }
}

static void draw_placeholder(unsigned char room_id)
{
    unsigned char col, row;
    unsigned char floor_tile = 0x70;
    for (row = 0; row < ROOMROM_ROOM_ROWS; row++) {
        for (col = 0; col < ROOMROM_ROOM_COLS; col++) {
            unsigned char t = (unsigned char)(floor_tile + ((col + row) & 1));
            write_tile_raw(col, row, t, 1);
        }
    }
    write_tile_raw(2, 1, 0x15, 0);
    write_tile_raw(3, 1, digit_tile(s_uw_level), 0);
    write_tile_raw(6, 1, 0x1B, 0);
    write_tile_raw(7, 1, digit_tile((unsigned char)(room_id >> 4)), 0);
    write_tile_raw(8, 1, digit_tile(room_id), 0);
}

void roomrom_uw_room_render_fill_plane_a(unsigned char room_id)
{
    int idx = find_blob_entry(s_uw_level, room_id);
    if (idx >= 0) {
        blit_blob(idx);
    } else {
        draw_placeholder(room_id);
    }
}
