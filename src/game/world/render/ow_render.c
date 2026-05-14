#include "ow_render.h"
#include "render_abi.h"
#include "../../../../RoomRom/src/roomrom_vram_map.h"
#include "../bg_palette.h"  /* Phase 12.2 promoted */
#include "../ow_palette.h"  /* Phase 12.2 promoted */
#include "../../../../RoomRom/src/expanded_bg_chr.h"

extern const unsigned char rooms_overworld[];
extern const unsigned char rooms_overworld_redux[];
extern const unsigned short rooms_overworld_redux_heap_offsets[16];

#define LEVEL_INFO_OW_OFFSET 768
#define OW_ATTRS_A_OFFSET    0
#define OW_ATTRS_B_OFFSET    128
#define OW_ATTRS_D_OFFSET    384
#define OW_LAYOUTS_OFFSET    1166
#define OW_HEAP_BLOB_OFFSET  3150

/* Phase 4: legacy LEVEL_INFO_PALETTE_OFFSET path replaced by live NES
 * PALRAM data (g_roomrom_ow_palram). Define kept for any out-of-tree
 * consumer; not used internally. */
#define LEVEL_INFO_PALETTE_OFFSET (LEVEL_INFO_OW_OFFSET + 3)

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

/* Task 5.4: raw NES BG tile id cache for the active 32x22 playfield.
 *
 * Populated as a side effect of fill_plane_a / fill_one_col_at. Cells are
 * indexed [tile_col][tile_row] in NES BG tile units (not metatiles). The
 * warp coordinator queries this through roomrom_ow_room_render_raw_tile_at
 * after Link's foot pixel is mapped to (col, row).
 *
 * SLICE-1 SEMANTICS:
 *   - "stable" = the cache reflects a complete fill_plane_a for the
 *     currently rendered room AND no partial column writes have happened
 *     since.
 *   - Single-column writes (scroll seam) flip the stable flag off; the
 *     coordinator must wait for the next full fill before checking warps.
 *   - Tile mutations from secrets, bombed rocks, burnt bushes, pushed
 *     blocks are NOT republished here. Those visual changes are out of
 *     scope for slice 1; future ticket adds a publish hook.
 */
#define ROOMROM_OW_RAW_TILE_COLS  32u  /* 16 metatiles x 2 tiles per metatile */
#define ROOMROM_OW_RAW_TILE_ROWS  22u  /* 11 metatiles x 2 tiles per metatile */
static unsigned char s_raw_tiles[ROOMROM_OW_RAW_TILE_COLS][ROOMROM_OW_RAW_TILE_ROWS];
static unsigned char s_raw_tiles_stable = 0u;

/* OW walkable NES tile IDs. Sourced from
 *   reference/aldonunez/Z_07.asm WalkableTiles ($8D,$91,$9C,$AC,$AD,$CC,$D2,$D5,$DF)
 * plus paths/sand/stairs/shore/redux variants observed in s_primary_squares
 * and s_secondary_squares_redux.
 *
 * Task 5.4 addition: $F3 (sand). NES OW $37 L1 entrance is metatile (7,4)
 * sq=$0C with BG tiles [$F3,$24,$F3,$24] — secondary metatile whose
 * tile_tl=$F3 is the renderer's primary_for_walk key. NES treats $F3 as
 * walkable (it's the sand path tile); without this, Link is blocked
 * before ever reaching the entrance. Verified against NES extraction
 * of LevelBlockOW.dat + RoomLayoutsOW.dat. */
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
        case 0xF3:                          /* NES sand path (Z1 OW) */
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

void roomrom_ow_room_render_load_palette(unsigned char room_id)
{
    unsigned char map = (s_roomrom_map_id == ROOMROM_MAP_REDUX) ? 1u : 0u;
    (void)room_id;
    /* Live NES PALRAM extracted from each ROM's LevelInfoOW transfer buffer.
     * Loads Gen PAL0 (NES BG sub-pals 0..3 packed) and Gen PAL1 (NES SPR
     * sub-pals 0..3 packed). Per-room sub-pal-3 patches deferred. */
    roomrom_bg_palette_load_palram_full(g_roomrom_ow_palram[map]);
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
    /* Phase 3: 4 sub-pal banks. Each NES BG section is uploaded 4 times,
     * once per Gen PAL0 sub-pal slot, from the corresponding pixel-biased
     * copy in the *_x4 expanded array. NES tile T sub-pal s lives at Gen
     * VRAM tile ROOMROM_BG_TILE_BASE_PAL(s) + T. */
    unsigned char s;
    const unsigned char redux = (s_roomrom_map_id == ROOMROM_MAP_REDUX);
    const unsigned char *ow_x4 = redux ? redux_overworld_bg_chr_x4
                                       : overworld_bg_chr_x4;
    const unsigned short ow_per_pal_bytes = redux
        ? REDUX_OVERWORLD_BG_CHR_PER_PAL_BYTES
        : OVERWORLD_BG_CHR_PER_PAL_BYTES;
    for (s = 0; s < 4; s++) {
        unsigned short bank_tile = ROOMROM_BG_TILE_BASE_PAL(s);
        /* common BG section (NES tiles 0..0x6F) */
        render_chr_upload((unsigned short)(bank_tile * 32u),
                          common_chr_x4 + s * COMMON_CHR_PER_PAL_BYTES + COMMON_BG_CHR_OFFSET,
                          (unsigned short)(COMMON_BG_TILE_COUNT * 32u));
        /* redux automap (NES tiles starting at 0x30) */
        render_chr_upload((unsigned short)((bank_tile + 0x30u) * 32u),
                          redux_automap_chr_x4 + s * REDUX_AUTOMAP_CHR_PER_PAL_BYTES,
                          (unsigned short)(REDUX_AUTOMAP_TILE_COUNT * 32u));
        if (redux) {
            /* redux secrets (NES tiles starting at 0x54) */
            render_chr_upload((unsigned short)((bank_tile + 0x54u) * 32u),
                              redux_overworld_secret_chr_x4 + s * REDUX_OVERWORLD_SECRET_CHR_PER_PAL_BYTES,
                              (unsigned short)(12u * 32u));
        }
        /* OW BG section (NES tiles 0x70..0xF1) */
        render_chr_upload((unsigned short)((bank_tile + COMMON_BG_TILE_COUNT) * 32u),
                          ow_x4 + s * ow_per_pal_bytes,
                          (unsigned short)(OW_BG_TILE_COUNT * 32u));
        /* common misc (NES tiles 0xF2..0xFF) */
        render_chr_upload((unsigned short)((bank_tile + COMMON_BG_TILE_COUNT + OW_BG_TILE_COUNT) * 32u),
                          common_chr_x4 + s * COMMON_CHR_PER_PAL_BYTES + COMMON_MISC_CHR_OFFSET,
                          (unsigned short)(COMMON_MISC_TILE_COUNT * 32u));
    }
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
    /* Phase 4: NES sub-pal selector lives in the tile index (pixel-biased
     * sub-pal copy); Gen pal-slot bits stay 0 (PAL0 owns NES BG). */
    return (unsigned short)(ROOMROM_BG_TILE_BASE_PAL(pal & 0x03)
                            + (unsigned short)raw_tile);
}

/* Task 5.4: when set, write_tile_at also records the raw NES BG tile id
 * into s_raw_tiles. fill_plane_a brackets a full-room render with this
 * flag and sets s_raw_tiles_stable on completion. Single-column writers
 * leave it off so partial fills don't poison the cache. */
static unsigned char s_raw_tile_capture_active = 0u;

/* PR-2: target plane for nametable writes. 0=BG_A (default, current room),
 * 1=BG_B (V scroll staging slot for incoming room). Caller toggles via
 * roomrom_ow_room_render_set_target_plane before render_room_into_slot. */
static unsigned char s_target_plane = 0u;

void roomrom_ow_room_render_set_target_plane(unsigned char plane)
{
    s_target_plane = plane ? 1u : 0u;
}

static unsigned short wrapped_plane_row(unsigned short row)
{
    return (unsigned short)(row & (ROOMROM_PLANE_ROWS - 1u));
}

/* Palette uses src tile coords (where the tile semantically lives in its
 * source room). Plane write uses dst tile coords (where the tile actually
 * lands on the BG plane — supports off-room rendering during scroll). */
static void write_tile_at(unsigned char src_tile_col, unsigned char src_tile_row,
                          unsigned char dst_tile_col, unsigned char dst_tile_row,
                          unsigned char dst_row_base,
                          unsigned char raw_tile,
                          unsigned char outer_pal,
                          unsigned char inner_pal)
{
    unsigned char pal = ow_tile_palette(src_tile_col, src_tile_row,
                                        outer_pal, inner_pal);
    unsigned short row_addr = wrapped_plane_row(
        (unsigned short)(dst_row_base + dst_tile_row + ROOMROM_ROOM_FIRST_ROW));
    unsigned short word = tile_word(raw_tile, pal);
    if (s_target_plane) render_set_plane_b_word(dst_tile_col, row_addr, word);
    else                render_set_plane_a_word(dst_tile_col, row_addr, word);
    /* Cache key = SOURCE-room BG tile (0..31, 0..21), not plane dst col.
     * Plane placement varies by scroll slot, but the warp coordinator
     * checks tiles in the source-room coordinate space (link_x >> 3,
     * (link_y - HUD) >> 3). Keying by src_tile_col makes the cache
     * a logical room snapshot that is independent of slot 0 vs 1. */
    if (s_raw_tile_capture_active &&
        src_tile_col < ROOMROM_OW_RAW_TILE_COLS &&
        src_tile_row < ROOMROM_OW_RAW_TILE_ROWS) {
        s_raw_tiles[src_tile_col][src_tile_row] = raw_tile;
    }
}

static void write_square_at(unsigned char src_col, unsigned char dst_col,
                            unsigned char dst_row_base,
                            unsigned char row,
                            unsigned char tile_tl, unsigned char tile_bl,
                            unsigned char tile_tr, unsigned char tile_br,
                            unsigned char outer_pal,
                            unsigned char inner_pal)
{
    unsigned char src_tc = (unsigned char)(src_col << 1);
    unsigned char dst_tc = (unsigned char)(dst_col << 1);
    unsigned char tile_row = (unsigned char)(row << 1);

    write_tile_at(src_tc,     tile_row,     dst_tc,     tile_row,     dst_row_base,
                  tile_tl, outer_pal, inner_pal);
    write_tile_at(src_tc,     tile_row + 1, dst_tc,     tile_row + 1, dst_row_base,
                  tile_bl, outer_pal, inner_pal);
    write_tile_at(src_tc + 1, tile_row,     dst_tc + 1, tile_row,     dst_row_base,
                  tile_tr, outer_pal, inner_pal);
    write_tile_at(src_tc + 1, tile_row + 1, dst_tc + 1, tile_row + 1, dst_row_base,
                  tile_br, outer_pal, inner_pal);
}

/* Render a single source metatile column from `room_id` into plane
 * metatile column `dst_col`. `src_col` selects which column of the
 * source room (so palette/attribute logic uses src coords). Updates
 * s_walkable[dst_col] for collision queries. Plane writes wrap at 32
 * plane cols via SGDK's setTileMapXY. */
static void render_one_metatile_col(unsigned char room_id,
                                    unsigned char src_col,
                                    unsigned char dst_col,
                                    unsigned char dst_row_base)
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

        write_square_at(src_col, dst_col, dst_row_base, row,
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
    roomrom_ow_room_render_fill_one_col_at(room_id, src_col, dst_col, 0);
}

void roomrom_ow_room_render_fill_one_col_at(unsigned char room_id,
                                            unsigned char src_col,
                                            unsigned char dst_col,
                                            unsigned char dst_row_base)
{
    /* Single-column write: cache is no longer a coherent snapshot of
     * one room; flip stability off until the next full fill_plane_a. */
    s_raw_tiles_stable = 0u;
    render_one_metatile_col(room_id, src_col & 0x0F, dst_col & 0x1F,
                            dst_row_base);
}

void roomrom_ow_room_render_fill_plane_a(unsigned char room_id)
{
    unsigned char col;
    s_raw_tiles_stable = 0u;
    s_raw_tile_capture_active = 1u;
    for (col = 0; col < 16; col++) {
        render_one_metatile_col(room_id, col, col, 0);
    }
    s_raw_tile_capture_active = 0u;
    s_raw_tiles_stable = 1u;
}

unsigned char roomrom_ow_room_render_raw_tile_at(unsigned char tile_col,
                                                 unsigned char tile_row)
{
    if (tile_col >= ROOMROM_OW_RAW_TILE_COLS ||
        tile_row >= ROOMROM_OW_RAW_TILE_ROWS) {
        return 0u;
    }
    return s_raw_tiles[tile_col][tile_row];
}

unsigned char roomrom_ow_room_render_is_stable(void)
{
    return s_raw_tiles_stable;
}

/* Task 5.4: callers using fill_one_col_at for a full 16-column room
 * paint (e.g. main.c::render_room_into_slot in load_room) bracket the
 * loop with begin/mark to declare the cache stable on the active slot.
 *
 *   begin: clears cache + stable flag and turns capture on so each
 *          fill_one_col_at populates the raw-tile cache.
 *   mark:  turns capture off and asserts stable. */
void roomrom_ow_room_render_begin_full_fill(void)
{
    s_raw_tiles_stable = 0u;
    s_raw_tile_capture_active = 1u;
}

void roomrom_ow_room_render_mark_stable(void)
{
    s_raw_tile_capture_active = 0u;
    s_raw_tiles_stable = 1u;
}

/* Task 5.4 cache export for BizHawk Lua probes.
 * Layout @ $FF7400:
 *   off 0..1: magic 'T','C'
 *   off 2:    cols (32)
 *   off 3:    rows (22)
 *   off 4..:  raw tile bytes, column-major: cache[col*22 + row]
 * Total: 4 + 704 = 708 bytes. */
#define ROOMROM_OW_RAW_TILE_PROBE_BASE 0x00FF7400UL

void roomrom_ow_room_render_publish_cache(void)
{
    volatile unsigned char *p =
        (volatile unsigned char *)ROOMROM_OW_RAW_TILE_PROBE_BASE;
    unsigned char col, row;

    p[0] = 0x54u;  /* 'T' */
    p[1] = 0x43u;  /* 'C' */
    p[2] = (unsigned char)ROOMROM_OW_RAW_TILE_COLS;
    p[3] = (unsigned char)ROOMROM_OW_RAW_TILE_ROWS;

    for (col = 0; col < ROOMROM_OW_RAW_TILE_COLS; col++) {
        for (row = 0; row < ROOMROM_OW_RAW_TILE_ROWS; row++) {
            p[4u + (unsigned short)col * ROOMROM_OW_RAW_TILE_ROWS + row] =
                s_raw_tiles[col][row];
        }
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
