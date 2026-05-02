#include "uw_room_render_roomrom.h"
#include "uw_room_blob.h"
#include "render_abi.h"
#include "roomrom_vram_map.h"
#include "roomrom_bg_palette.h"
#include "expanded_bg_chr.h"

extern const unsigned char rooms_dungeons[];

#define UW_LEVELBLOCK_SIZE       768u
#define UW_LEVELINFO_SIZE        256u
#define UW_LEVELINFO_BASE        3072u
#define UW_LEVELINFO_PAL_OFFSET  3u

#define COMMON_BG_TILE_COUNT     112u
#define UW_BG_TILE_COUNT         130u
#define COMMON_MISC_TILE_COUNT   14u
#define COMMON_BG_CHR_OFFSET     (112u * 32u)
#define COMMON_MISC_CHR_OFFSET   (224u * 32u)

static unsigned char s_uw_map_id = ROOMROM_MAP_ORIGINAL;
static unsigned char s_uw_level  = 1u;
static unsigned char s_uw_quest  = 1u;

/* S5.5 collision: walkable metatile grid for the current UW room.
 * Filled during blit_blob; queried by main loop. 16 cols x 11 rows. */
static unsigned char s_uw_walkable[16][11];

/* UW wall + locked-door classifier. Blob nt[] stores NES tile IDs
 * (sourced from CIRAM via probe_nes_uw_l1_floodwalk.lua), so we match
 * against NES tile IDs directly.
 *
 * Wall set: aggregated wall_tiles[] + border_fill_tile across all 9
 * levels x 2 quests in RoomRom/data/uw_level*_*_manifest.json (same
 * 14 IDs every level).
 *
 * Locked-door / shutter art ($98..$A3): NES Z1 renders closed doors
 * with these tile IDs. door_type 0 (open) uses $74..$77 as walkable
 * threshold; door_type >= 1 (shut/walled/bombable/locked) places art
 * from the $98..$A3 family into the doorway NT cells. Blocking this
 * range means locked / walled / bombable / shutter doors all behave
 * as walls, while open doors still pass. */
static unsigned char uw_walkable_tile_id(unsigned char t)
{
    /* Walls. */
    switch (t) {
        case 0xB8u: case 0xBCu:
        case 0xC0u: case 0xC4u: case 0xC8u: case 0xCCu:
        case 0xD0u: case 0xD4u: case 0xD8u: case 0xDCu: case 0xDEu:
        case 0xE0u:
        case 0xF5u: case 0xF6u:
            return 0u;
        default:
            break;
    }
    /* Locked / shutter / walled door art. */
    if (t >= 0x98u && t <= 0xA3u) return 0u;
    return 1u;
}

unsigned char roomrom_uw_room_render_walkable_at(unsigned char col,
                                                 unsigned char row)
{
    if (col >= 16u || row >= 11u) return 0u;
    return s_uw_walkable[col][row];
}

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

void roomrom_uw_room_render_set_quest(unsigned char quest)
{
    if (quest < ROOMROM_UW_QUEST_MIN) quest = ROOMROM_UW_QUEST_MIN;
    if (quest > ROOMROM_UW_QUEST_MAX) quest = ROOMROM_UW_QUEST_MAX;
    s_uw_quest = quest;
}

unsigned char roomrom_uw_room_render_get_quest(void)
{
    return s_uw_quest;
}

static int find_blob_entry(unsigned char level, unsigned char room_id)
{
    unsigned short i;
    unsigned char want_map = (s_uw_map_id == ROOMROM_MAP_REDUX) ? 1u : 0u;
    unsigned char want_quest = s_uw_quest;
    for (i = 0; i < g_uw_room_count; i++) {
        if (g_uw_room_index[i][0] == want_map &&
            g_uw_room_index[i][1] == want_quest &&
            g_uw_room_index[i][2] == level &&
            g_uw_room_index[i][3] == room_id) {
            return (int)i;
        }
    }
    return -1;
}

static void load_palette_from_blob(int idx)
{
    /* g_uw_room_palette[idx][32] = full per-room NES PALRAM captured from
     * BizHawk runtime; bytes 0..15 = NES BG sub-pals 0..3, 16..31 = SPR. */
    roomrom_bg_palette_load_palram_full(g_uw_room_palette[idx]);
}

static void load_palette_from_levelinfo(void)
{
    unsigned char buf[16];
    unsigned char i;
    unsigned short level_off = (unsigned short)(UW_LEVELINFO_BASE +
        ((unsigned short)(s_uw_level - 1u) * UW_LEVELINFO_SIZE) +
        UW_LEVELINFO_PAL_OFFSET);
    for (i = 0; i < 16; i++) buf[i] = rooms_dungeons[level_off + i];
    /* Sprite half (PAL1) preserved from prior room load. Levelinfo
     * fallback only fires when blob lookup misses. */
    roomrom_bg_palette_load_bg_only(buf);
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
    /* Phase 3: 4 sub-pal banks. NES tile T sub-pal s lives at Gen VRAM
     * tile ROOMROM_BG_TILE_BASE_PAL(s) + T. */
    unsigned char s;
    if (s_uw_map_id == ROOMROM_MAP_REDUX) {
        /* Redux UW: 256-tile live PPU dump uploaded into each sub-pal bank. */
        for (s = 0; s < 4; s++) {
            unsigned short bank_tile = ROOMROM_BG_TILE_BASE_PAL(s);
            render_chr_upload((unsigned short)(bank_tile * 32u),
                              redux_uw_bg_chr_x4 + s * REDUX_UW_BG_CHR_PER_PAL_BYTES,
                              (unsigned short)(256u * 32u));
        }
        return;
    }
    for (s = 0; s < 4; s++) {
        unsigned short bank_tile = ROOMROM_BG_TILE_BASE_PAL(s);
        render_chr_upload((unsigned short)(bank_tile * 32u),
                          common_chr_x4 + s * COMMON_CHR_PER_PAL_BYTES + COMMON_BG_CHR_OFFSET,
                          (unsigned short)(COMMON_BG_TILE_COUNT * 32u));
        render_chr_upload((unsigned short)((bank_tile + COMMON_BG_TILE_COUNT) * 32u),
                          underworld_bg_chr_x4 + s * UNDERWORLD_BG_CHR_PER_PAL_BYTES,
                          (unsigned short)(UW_BG_TILE_COUNT * 32u));
        render_chr_upload((unsigned short)((bank_tile + COMMON_BG_TILE_COUNT + UW_BG_TILE_COUNT) * 32u),
                          common_chr_x4 + s * COMMON_CHR_PER_PAL_BYTES + COMMON_MISC_CHR_OFFSET,
                          (unsigned short)(COMMON_MISC_TILE_COUNT * 32u));
    }
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
/* Door art tiles that render IN FRONT of Link as he walks through.
 * Verified by dumping L1Q1 R73 blob NT:
 *   N doorway (rows 1-3): $78,$79,$7A,$7B,$7C arches + $24 interior
 *   E doorway (rows 9-12): $88,$89,$8A,$8B posts
 *   S doorway (rows 18-20): $7D,$7E,$7F,$80,$81 bottom arches
 * Walkable floor / thresholds ($74,$75,$76,$77) stay LOW priority so
 * Link renders normally on them. Locked-art ($98..$AF) also blocks. */
static unsigned char uw_is_door_tile(unsigned char t)
{
    if (t >= 0x78u && t <= 0x81u) return 1u;
    if (t >= 0x88u && t <= 0x8Bu) return 1u;
    if (t >= 0x98u && t <= 0xAFu) return 1u;
    return 0u;
}

static void write_tile_raw_at(unsigned char col, unsigned char row,
                           unsigned char dst_row_base,
                           unsigned char raw_tile, unsigned char pal)
{
    /* Phase 4: NES sub-pal selector lives in the tile index (pixel-biased
     * sub-pal copy); Gen pal-slot bits stay 0 (PAL0 owns NES BG).
     * Priority bit (0x8000) preserved for door art. */
    unsigned short pri = uw_is_door_tile(raw_tile) ? 0x8000u : 0u;
    unsigned short word = (unsigned short)(pri |
        (ROOMROM_BG_TILE_BASE_PAL(pal & 0x03) + (unsigned short)raw_tile));
    render_set_plane_a_word(col, (unsigned short)(dst_row_base + row +
                                                  ROOMROM_ROOM_FIRST_ROW), word);
}

static void write_tile_raw(unsigned char col, unsigned char row,
                           unsigned char raw_tile, unsigned char pal)
{
    write_tile_raw_at(col, row, 0, raw_tile, pal);
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
    unsigned char mt_col, mt_row;
    for (row = 0; row < ROOMROM_UW_BLOB_ROWS; row++) {
        for (col = 0; col < ROOMROM_UW_BLOB_COLS; col++) {
            unsigned char raw = nt[row * ROOMROM_UW_BLOB_COLS + col];
            /* Play area starts at NT row 8 (HUD occupies rows 0..7). */
            unsigned char nt_row = (unsigned char)(row + 8u);
            unsigned char pal = attr_palette_for(attr, col, nt_row);
            write_tile_raw(col, row, raw, pal);
        }
    }
    /* Build walkable grid: each metatile (mt_col, mt_row) classified by
     * its TL plane tile (= nt[mt_row*2 * COLS + mt_col*2]). */
    for (mt_row = 0; mt_row < 11; mt_row++) {
        for (mt_col = 0; mt_col < 16; mt_col++) {
            unsigned char tl = nt[(mt_row * 2u) * ROOMROM_UW_BLOB_COLS + (mt_col * 2u)];
            s_uw_walkable[mt_col][mt_row] = uw_walkable_tile_id(tl);
        }
    }
}

/* S6.5 scroll: render two plane cols (one metatile col) of `room_id` from
 * blob src_col into plane dst_col. src_col / dst_col are metatile cols (0..15).
 * Falls back to no-op if room not found in blob (stays as previous content). */
static void blit_blob_one_metacol_at(int idx, unsigned char src_col,
                                     unsigned char dst_col,
                                     unsigned char dst_row_base)
{
    const unsigned char *nt   = g_uw_room_nt[idx];
    const unsigned char *attr = g_uw_room_attr[idx];
    unsigned char row;
    unsigned char mt_row;
    unsigned char src_p0 = (unsigned char)(src_col << 1);
    unsigned char src_p1 = (unsigned char)(src_p0 + 1);
    unsigned char dst_p0 = (unsigned char)(dst_col << 1);
    unsigned char dst_p1 = (unsigned char)(dst_p0 + 1);
    for (row = 0; row < ROOMROM_UW_BLOB_ROWS; row++) {
        unsigned char nt_row = (unsigned char)(row + 8u);
        unsigned char raw0 = nt[row * ROOMROM_UW_BLOB_COLS + src_p0];
        unsigned char raw1 = nt[row * ROOMROM_UW_BLOB_COLS + src_p1];
        unsigned char pal0 = attr_palette_for(attr, src_p0, nt_row);
        unsigned char pal1 = attr_palette_for(attr, src_p1, nt_row);
        write_tile_raw_at(dst_p0, row, dst_row_base, raw0, pal0);
        write_tile_raw_at(dst_p1, row, dst_row_base, raw1, pal1);
    }
    /* S5.5: populate walkable grid for this metatile col. Use TL plane
     * tile of each metatile row. Indexed by dst_col (must be 0..15). */
    if (dst_col < 16u) {
        for (mt_row = 0; mt_row < 11u; mt_row++) {
            unsigned char tl = nt[(mt_row * 2u) * ROOMROM_UW_BLOB_COLS + (src_col * 2u)];
            s_uw_walkable[dst_col][mt_row] = uw_walkable_tile_id(tl);
        }
    }
}

static void draw_placeholder(unsigned char room_id)
{
    unsigned char col, row;
    unsigned char mt_col, mt_row;
    unsigned char floor_tile = 0x70;
    for (row = 0; row < ROOMROM_ROOM_ROWS; row++) {
        for (col = 0; col < ROOMROM_ROOM_COLS; col++) {
            unsigned char t = (unsigned char)(floor_tile + ((col + row) & 1));
            write_tile_raw(col, row, t, 1);
        }
    }
    /* Placeholder rooms: all metatiles walkable. */
    for (mt_row = 0; mt_row < 11; mt_row++)
        for (mt_col = 0; mt_col < 16; mt_col++)
            s_uw_walkable[mt_col][mt_row] = 1u;
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

void roomrom_uw_room_render_fill_one_col(unsigned char room_id,
                                         unsigned char src_col,
                                         unsigned char dst_col)
{
    roomrom_uw_room_render_fill_one_col_at(room_id, src_col, dst_col, 0);
}

void roomrom_uw_room_render_fill_one_col_at(unsigned char room_id,
                                            unsigned char src_col,
                                            unsigned char dst_col,
                                            unsigned char dst_row_base)
{
    int idx = find_blob_entry(s_uw_level, room_id);
    if (idx >= 0) {
        blit_blob_one_metacol_at(idx, src_col & 0x0F, dst_col & 0x1F,
                                 dst_row_base);
    }
    /* If room not found in blob, leave plane content unchanged (caller's
     * responsibility to only request known rooms during scroll). */
}
