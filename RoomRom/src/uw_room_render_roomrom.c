#include "uw_room_render_roomrom.h"
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

void roomrom_uw_room_render_load_palette(unsigned char room_id)
{
    unsigned short pal16[16];
    unsigned char slot, i;
    unsigned short level_off = (unsigned short)(UW_LEVELINFO_BASE +
        ((unsigned short)(s_uw_level - 1u) * UW_LEVELINFO_SIZE) +
        UW_LEVELINFO_PAL_OFFSET);

    (void)room_id;

    for (slot = 0; slot < 4; slot++) {
        for (i = 0; i < 16; i++)
            pal16[i] = 0;
        for (i = 0; i < 4; i++)
            pal16[i] = nes_color_to_cram(
                rooms_dungeons[level_off + slot * 4 + i]);
        render_load_palette(slot, pal16);
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

void roomrom_uw_room_render_fill_plane_a(unsigned char room_id)
{
    unsigned char col, row;
    unsigned char floor_tile = 0x70;

    for (row = 0; row < ROOMROM_ROOM_ROWS; row++) {
        for (col = 0; col < ROOMROM_ROOM_COLS; col++) {
            unsigned char t = (unsigned char)(floor_tile + ((col + row) & 1));
            write_tile_raw(col, row, t, 1);
        }
    }

    write_tile_raw(2, 1, 0x15, 0); /* L */
    write_tile_raw(3, 1, digit_tile(s_uw_level), 0);

    write_tile_raw(6, 1, 0x1B, 0); /* R */
    write_tile_raw(7, 1, digit_tile((unsigned char)(room_id >> 4)), 0);
    write_tile_raw(8, 1, digit_tile(room_id), 0);
}
