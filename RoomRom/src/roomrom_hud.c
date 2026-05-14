#include <genesis.h>
#include "roomrom_hud.h"
#include "ow_room_render_roomrom.h"
#include "render_abi.h"
#include "roomrom_vram_map.h"
#include "expanded_bg_chr.h"
#include "../../src/state/inventory.h"
/* P4c: atlas header included for named constant reference and future
 * ATLAS_ASSERT_SIZE hooks.
 *
 * hud_chr.h provides ROOMROM_ATLAS_HUD_HUD_*_OFFSET byte-offset constants
 * into the roomrom_atlas_hud blob and W_HUD_x/H_HUD_x dispatch defines.
 *
 * Migration gap: this renderer addresses HUD content as raw NES BG tile IDs
 * (e.g., TILE_FULL_HEART = 0xF2u) passed to hud_word() which calls
 * ROOMROM_BG_TILE_BASE_PAL(pal) + raw_tile.  The atlas hud_chr offsets are
 * atlas-blob-local indices (heart_full at byte 0, digit_0 at byte 96, etc.)
 * and do NOT correspond to NES BG tile IDs.  The roomrom_atlas_hud blob is
 * also not currently uploaded to VRAM -- HUD content is sourced from the
 * expanded BG CHR bank which already contains NES BG tiles at their native
 * NES tile-ID positions.
 *
 * Additionally, hud_chr.h W_HUD_x/H_HUD_x dispatch defines describe sprite
 * SPRITE_SIZE widths, but this renderer uses VDP_setTileMapXY (BG tile maps),
 * not VDP_setSpriteFull.  ATLAS_ASSERT_SIZE has nothing to verify here.
 *
 * TODO(Phase-4c / Phase 6): once the HUD CHR upload path is reworked to
 * source tiles from roomrom_atlas_hud rather than the expanded BG bank:
 *   1. Replace raw tile-ID literals with
 *      ROOMROM_ATLAS_HUD_HUD_<NAME>_OFFSET / 32
 *      (after confirming NES tile IDs match atlas byte ordering).
 *   2. Add ATLAS_ASSERT_SIZE-equivalent BG-tile checks (need a new
 *      ATLAS_ASSERT_BG_TILE macro for tile-map rather than sprite use). */
#include "atlas/hud_chr.h"

#define HUD_TILE_SPACE  0x24u
#define TILE_DASH       0x62u
#define TILE_LOW_X      0x21u
#define TILE_FULL_HEART 0xF2u
#define TILE_HALF_HEART 0xF3u
#define TILE_EMPTY_HEART 0xF4u
#define TILE_GRAY_MAP   0xF5u
#define TILE_REDUX_HEART_OUTLINE 0x50u
#define TILE_ORIGINAL_MAP_MARKER 0x51u
#define TILE_REDUX_HEART_FILL    0x52u
#define COMMON_BG_CHR_OFFSET     (112u * 32u)
#define COMMON_MISC_CHR_OFFSET   (224u * 32u)
#define COMMON_MISC_TILE_BASE    0xF2u
#define REDUX_AUTOMAP_TILE_BASE  0x30u
#define REDUX_AUTOMAP_TILE_COUNT 32u

static unsigned char s_hud_pal[ROOMROM_HUD_ROWS][ROOMROM_ROOM_COLS];

static const unsigned char s_hud_custom_chr[96] = {
    0x01,0x10,0x01,0x10,
    0x10,0x01,0x10,0x01,
    0x10,0x00,0x00,0x01,
    0x10,0x00,0x00,0x01,
    0x01,0x00,0x00,0x10,
    0x00,0x10,0x01,0x00,
    0x00,0x01,0x10,0x00,
    0x00,0x00,0x00,0x00,

    0x00,0x00,0x00,0x00,
    0x00,0x01,0x10,0x00,
    0x00,0x13,0x31,0x00,
    0x01,0x33,0x33,0x10,
    0x00,0x13,0x31,0x00,
    0x00,0x01,0x10,0x00,
    0x00,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00,

    0x00,0x00,0x00,0x00,
    0x01,0x10,0x01,0x10,
    0x01,0x11,0x11,0x10,
    0x01,0x11,0x11,0x10,
    0x00,0x11,0x11,0x00,
    0x00,0x01,0x10,0x00,
    0x00,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00
};

/* NES Zelda overworld HUD, captured from live NES at room $77.
 * NT cols 2-9 rows 3-6: 8x4 gray map block (tile $F5).
 * NT col 11-13 rows 3,5,6: rupee/key/bomb count (icon, 'X', digit).
 * NT col 15-20 rows 3-6: B/A item slot frames.
 * NT col 23-28 row 3: "-LIFE-" header.
 * NT col 22-24 row 6: 3 full hearts. */
static const unsigned char s_original_hud_macro[] = {
    /* Attribute table $23C0..$23CF - matches NES exactly. */
    0x23,0xC0,0x10,
    0x00,0x00,0x40,0x00,0x00,0x44,0x55,0x55,
    0x00,0x00,0x04,0x00,0x00,0x44,0x55,0x55,

    /* Row 3: gray map row 0, rupee count, B/A box top, -LIFE- */
    0x20,0x62,0x08, TILE_GRAY_MAP,TILE_GRAY_MAP,TILE_GRAY_MAP,TILE_GRAY_MAP,
                    TILE_GRAY_MAP,TILE_GRAY_MAP,TILE_GRAY_MAP,TILE_GRAY_MAP,
    0x20,0x6B,0x03, 0xF7,TILE_LOW_X,0x00,
    0x20,0x6F,0x06, 0x69,0x0B,0x6B,0x69,0x0A,0x6B,
    0x20,0x77,0x06, TILE_DASH,0x15,0x12,0x0F,0x0E,TILE_DASH,

    /* Row 4: gray map row 1, B/A vertical edges */
    0x20,0x82,0x08, TILE_GRAY_MAP,TILE_GRAY_MAP,TILE_GRAY_MAP,TILE_GRAY_MAP,
                    TILE_GRAY_MAP,TILE_GRAY_MAP,TILE_GRAY_MAP,TILE_GRAY_MAP,
    0x20,0x8F,0x01, 0x6C,
    0x20,0x91,0x01, 0x6C,
    0x20,0x92,0x01, 0x6C,
    0x20,0x94,0x01, 0x6C,

    /* Row 5: gray map row 2, key count, B/A vertical edges */
    0x20,0xA2,0x08, TILE_GRAY_MAP,TILE_GRAY_MAP,TILE_GRAY_MAP,TILE_GRAY_MAP,
                    TILE_GRAY_MAP,TILE_GRAY_MAP,TILE_GRAY_MAP,TILE_GRAY_MAP,
    0x20,0xAB,0x03, 0xF9,TILE_LOW_X,0x00,
    0x20,0xAF,0x01, 0x6C,
    0x20,0xB1,0x01, 0x6C,
    0x20,0xB2,0x01, 0x6C,
    0x20,0xB4,0x01, 0x6C,

    /* Row 6: gray map row 3, bomb count, B/A box bottom, hearts */
    0x20,0xC2,0x08, TILE_GRAY_MAP,TILE_GRAY_MAP,TILE_GRAY_MAP,TILE_GRAY_MAP,
                    TILE_GRAY_MAP,TILE_GRAY_MAP,TILE_GRAY_MAP,TILE_GRAY_MAP,
    0x20,0xCB,0x03, 0x61,TILE_LOW_X,0x00,
    0x20,0xCF,0x06, 0x6E,0x6A,0x6D,0x6E,0x6A,0x6D,
    0x20,0xD6,0x03, TILE_FULL_HEART,TILE_FULL_HEART,TILE_FULL_HEART,
    0xFF
};

static const unsigned char s_redux_ow_hud_macro[] = {
    0x23,0xC0,0x10,
    0x44,0x55,0x55,0x00,0x00,0xC0,0xFF,0x70,
    0x44,0x55,0x05,0x00,0x00,0xC0,0xAF,0x3A,

    0x20,0x76,0x08, 0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37,
    0x20,0x96,0x08, 0x38,0x39,0x3A,0x3B,0x3C,0x3D,0x3E,0x3F,
    0x20,0xB6,0x08, 0x40,0x41,0x42,0x43,0x44,0x45,0x46,0x47,
    0x20,0xD6,0x08, 0x48,0x49,0x4A,0x4B,0x4C,0x4D,0x4E,0x4F,

    0x20,0x63,0x12,
    TILE_DASH,0x15,0x12,0x0F,0x0E,TILE_DASH,HUD_TILE_SPACE,HUD_TILE_SPACE,HUD_TILE_SPACE,HUD_TILE_SPACE,HUD_TILE_SPACE,HUD_TILE_SPACE,
    0x69,0x0B,0x6B,0x69,0x0A,0x6B,
    0x20,0xCF,0x06, 0x6E,0x6A,0x6D,0x6E,0x6A,0x6D,
    0x20,0x8F,0xC2, 0x6C,
    0x20,0x91,0xC2, 0x6C,
    0x20,0x92,0xC2, 0x6C,
    0x20,0x94,0xC2, 0x6C,
    0x20,0x6B,0x84, 0xF7,0xF9,0x65,0x61,
    0xFF
};

static const unsigned char s_redux_uw_hud_macro[] = {
    0x23,0xC0,0x10,
    0x44,0x55,0x55,0x00,0x00,0xC0,0xFF,0x70,
    0x44,0x55,0x05,0x00,0x00,0xC0,0xAF,0x3A,

    0x20,0x63,0x12,
    TILE_DASH,0x15,0x12,0x0F,0x0E,TILE_DASH,HUD_TILE_SPACE,HUD_TILE_SPACE,HUD_TILE_SPACE,HUD_TILE_SPACE,HUD_TILE_SPACE,HUD_TILE_SPACE,
    0x69,0x0B,0x6B,0x69,0x0A,0x6B,
    0x20,0xCF,0x06, 0x6E,0x6A,0x6D,0x6E,0x6A,0x6D,
    0x20,0x8F,0xC2, 0x6C,
    0x20,0x91,0xC2, 0x6C,
    0x20,0x92,0xC2, 0x6C,
    0x20,0x94,0xC2, 0x6C,
    0x20,0x6B,0x84, 0xF7,0xF9,0x65,0x61,
    0xFF
};

static unsigned short hud_word(unsigned char raw_tile, unsigned char pal)
{
    /* Phase 4: HUD = NES BG content. Sub-pal selector lives in tile index
     * (pixel-biased copy in the BG bank); Gen pal-slot bits stay 0.  The
     * Window plane still treats pixel 0 as transparent, so HUD glyphs must
     * sit above the sprite-backed black underlay during vertical scrolls. */
    unsigned short tile = (unsigned short)(ROOMROM_BG_TILE_BASE_PAL(pal & 0x03)
                                           + (unsigned short)raw_tile);
    return TILE_ATTR_FULL(PAL0, 1, 0, 0, tile);
}

static void draw_hud_tile(unsigned char col, unsigned char row,
                          unsigned char raw_tile, unsigned char pal)
{
    if (col >= ROOMROM_ROOM_COLS || row >= ROOMROM_HUD_ROWS)
        return;
    VDP_setTileMapXY(WINDOW, hud_word(raw_tile, pal), col, row);
}

static void draw_hud_tile_b(unsigned char col, unsigned char row,
                            unsigned char raw_tile, unsigned char pal)
{
    (void)col;
    (void)row;
    (void)raw_tile;
    (void)pal;
    /* PR-2c: BG_B shares BG_A's $C000 scroll surface. HUD lives on WINDOW;
     * writing BG_B HUD shadows would erase wrapped room rows after vertical
     * scrolls. */
}

static void draw_hud_tile_attr(unsigned char col, unsigned char row,
                               unsigned char raw_tile)
{
    draw_hud_tile(col, row, raw_tile, s_hud_pal[row][col]);
}

static void clear_hud_pal(void)
{
    unsigned char row, col;
    for (row = 0; row < ROOMROM_HUD_ROWS; row++) {
        for (col = 0; col < ROOMROM_ROOM_COLS; col++)
            s_hud_pal[row][col] = 0;
    }
}

static void clear_hud_b(void)
{
    /* PR-2c: BG_B mirrors BG_A at $C000, so this must not clear rows 0..6.
     * Those rows are live bottom-room rows after an upward vertical scroll. */
}

static void clear_hud_window(void)
{
    VDP_clearTileMapRect(WINDOW, 0, 0, ROOMROM_ROOM_COLS, ROOMROM_HUD_ROWS);
}

static void apply_attr_byte(unsigned char attr_offset, unsigned char attr)
{
    unsigned char nt_row_base = (unsigned char)((attr_offset >> 3) << 2);
    unsigned char col_base = (unsigned char)((attr_offset & 0x07) << 2);
    unsigned char q;

    for (q = 0; q < 4; q++) {
        unsigned char pal = (unsigned char)((attr >> (q << 1)) & 0x03);
        unsigned char q_col = (unsigned char)(col_base + ((q & 1u) << 1));
        unsigned char q_nt_row = (unsigned char)(nt_row_base + ((q >> 1) << 1));
        unsigned char dy, dx;
        for (dy = 0; dy < 2; dy++) {
            unsigned char nt_row = (unsigned char)(q_nt_row + dy);
            if (nt_row == 0 || nt_row > ROOMROM_HUD_ROWS)
                continue;
            for (dx = 0; dx < 2; dx++) {
                unsigned char col = (unsigned char)(q_col + dx);
                if (col < ROOMROM_ROOM_COLS)
                    s_hud_pal[nt_row - 1u][col] = pal;
            }
        }
    }
}

static void apply_transfer_macro(const unsigned char *macro)
{
    unsigned short i = 0;
    while (macro[i] != 0xFF) {
        unsigned short addr = (unsigned short)(((unsigned short)macro[i] << 8) | macro[i + 1]);
        unsigned char spec = macro[i + 2];
        unsigned char len = (unsigned char)(spec & 0x3Fu);
        unsigned char vertical = (unsigned char)(spec & 0x80u);
        unsigned char repeat = (unsigned char)(spec & 0x40u);
        unsigned char n;
        i += 3;

        if (addr >= 0x23C0u && addr < 0x2400u) {
            unsigned char attr_offset = (unsigned char)(addr - 0x23C0u);
            for (n = 0; n < len; n++)
                apply_attr_byte((unsigned char)(attr_offset + n), macro[i + n]);
            i += len;
            continue;
        }

        if (addr >= 0x2000u && addr < 0x23C0u) {
            unsigned char nt_row = (unsigned char)((addr - 0x2000u) >> 5);
            unsigned char col = (unsigned char)((addr - 0x2000u) & 0x1Fu);
            for (n = 0; n < len; n++) {
                unsigned char raw_tile = repeat ? macro[i] : macro[i + n];
                if (nt_row > 0 && nt_row <= ROOMROM_HUD_ROWS)
                    draw_hud_tile_attr(col, (unsigned char)(nt_row - 1u), raw_tile);
                if (vertical)
                    nt_row++;
                else
                    col++;
            }
            i += repeat ? 1u : len;
        } else {
            i += repeat ? 1u : len;
        }
    }
}

/* Phase 6 Task 6.10.6 (Step A): live-read HUD count cell.
 * NES Z_01.asm:2922 FormatDecimalCountByte format: 123 -> "123",
 * 23 -> "X23", 3 -> "X3 ". Three cells at col, col+1, col+2: hundreds /
 * tens / ones, with the 'X' (TILE_LOW_X) replacing the hundreds cell when
 * value < 100, and a trailing space when value < 10 (single low digit
 * shifted left into tens, ones blanked).
 *
 * NES is byte-wide (0..255) for each count. RoomRom widens rupees to
 * 16-bit; clamp display to 999 so the 3-digit window stays legal. */
static void draw_count_cell(unsigned short value, unsigned char col,
                            unsigned char row, unsigned char pal)
{
    unsigned short v = (value > 999u) ? 999u : value;
    unsigned char hundreds = (unsigned char)(v / 100u);
    unsigned char tens     = (unsigned char)((v / 10u) % 10u);
    unsigned char ones     = (unsigned char)(v % 10u);
    unsigned char tile_h, tile_t, tile_o;

    if (hundreds != 0u) {
        tile_h = hundreds;
        tile_t = tens;
        tile_o = ones;
    } else if (tens != 0u) {
        tile_h = TILE_LOW_X;
        tile_t = tens;
        tile_o = ones;
    } else {
        tile_h = TILE_LOW_X;
        tile_t = ones;
        tile_o = HUD_TILE_SPACE;
    }
    draw_hud_tile(col,                       row, tile_h, pal);
    draw_hud_tile((unsigned char)(col + 1u), row, tile_t, pal);
    draw_hud_tile((unsigned char)(col + 2u), row, tile_o, pal);
}

/* Phase 6 Task 6.11 (Step A): live heart row. NES splits hearts across
 * NT rows 5 (top halves) and 6 (bottom halves) at cols 22..29 (8 hearts).
 * RoomRom currently paints only HUD row 5 (= NT row 6) cols 22..24. Up
 * to 3 hearts visible until the row-5 outline pass lands.
 *
 * NES tile $F2=full, $F3=half, $F4=empty. heart_values: hi=max, lo=cur.
 * heart_partial: 0 -> empty, otherwise half (NES treats anything > 0 as
 * a partial heart; full heart only when cur >= max + 1 effectively). */
static void draw_hearts_row(unsigned char col, unsigned char row,
                            unsigned char hud_id)
{
    unsigned char hv = g_inventory.heart_values;
    unsigned char hp = g_inventory.heart_partial;
    unsigned char max_h = heart_values_max(hv);
    unsigned char cur_h = heart_values_cur(hv);
    unsigned char visible = (max_h > 3u) ? 3u : max_h;
    unsigned char i;

    /* Bound for first-boot zero state — display 3 outline hearts so the
     * HUD looks alive even before save-load wires heart_values. */
    if (max_h == 0u) {
        max_h = 3u;
        cur_h = 3u;
        visible = 3u;
    }

    for (i = 0; i < 3u; i++) {
        unsigned char tile;
        if (i >= visible) {
            tile = HUD_TILE_SPACE;
        } else if (i < cur_h) {
            tile = TILE_FULL_HEART;
        } else if (i == cur_h && hp > 0u) {
            tile = TILE_HALF_HEART;
        } else {
            tile = TILE_EMPTY_HEART;
        }
        if (hud_id == ROOMROM_MAP_REDUX) {
            /* Redux paints a soft outline on BG_B and the heart on Window. */
            draw_hud_tile_b((unsigned char)(col + i), row,
                            TILE_REDUX_HEART_OUTLINE, 0);
            draw_hud_tile((unsigned char)(col + i), row, tile, 1);
        } else {
            draw_hud_tile((unsigned char)(col + i), row, tile, 1);
        }
    }
}

/* Redux 4-row count strip at cols 12..14, HUD rows 2..5 (rupee/key/-/bomb).
 * Row 4 currently carries no NES analogue; show heart-count there for now. */
static void draw_status_counts_redux(void)
{
    draw_count_cell(g_inventory.rupees,                      12u, 2u, 0u);
    draw_count_cell((unsigned short)g_inventory.keys,        12u, 3u, 0u);
    draw_count_cell((unsigned short)heart_values_cur(g_inventory.heart_values),
                                                              12u, 4u, 0u);
    draw_count_cell((unsigned short)g_inventory.bombs,       12u, 5u, 0u);
}

/* Original HUD count strip mirrors NES rows 3/5/6 = HUD rows 2/4/5. The
 * static macro paints icon at col 11 + "X 0 " at cols 12..14. We overlay
 * the live 3-digit count at cols 12..14, leaving the icon untouched. */
static void draw_status_counts_original(void)
{
    draw_count_cell(g_inventory.rupees,                12u, 2u, 0u);
    draw_count_cell((unsigned short)g_inventory.keys,  12u, 4u, 0u);
    draw_count_cell((unsigned short)g_inventory.bombs, 12u, 5u, 0u);
}

static void draw_original_map_marker(unsigned char room_id)
{
    unsigned char col = (unsigned char)(2u + ((room_id & 0x0Fu) >> 1));
    unsigned char row = (unsigned char)(2u + ((room_id >> 4) >> 1));
    draw_hud_tile(col, row, TILE_ORIGINAL_MAP_MARKER, 2);
}

static void upload_common_hud_tile(unsigned char subpal, unsigned char raw_tile)
{
    const unsigned char *src = common_chr_x4 + subpal * COMMON_CHR_PER_PAL_BYTES;
    unsigned short dst = (unsigned short)(ROOMROM_BG_TILE_BASE_PAL(subpal)
                                          + (unsigned short)raw_tile);

    if (raw_tile < 0x70u) {
        src += COMMON_BG_CHR_OFFSET + (unsigned short)raw_tile * 32u;
    } else if (raw_tile >= COMMON_MISC_TILE_BASE) {
        src += COMMON_MISC_CHR_OFFSET
            + (unsigned short)(raw_tile - COMMON_MISC_TILE_BASE) * 32u;
    } else {
        return;
    }

    render_chr_upload((unsigned short)(dst * 32u), src, 32u);
}

static void upload_common_hud_tile_range(unsigned char subpal,
                                         unsigned char first,
                                         unsigned char last)
{
    unsigned char raw_tile;
    for (raw_tile = first; raw_tile <= last; raw_tile++)
        upload_common_hud_tile(subpal, raw_tile);
}

static void upload_common_hud_chr(unsigned char subpal)
{
    upload_common_hud_tile_range(subpal, 0x00u, 0x15u);
    upload_common_hud_tile_range(subpal, 0x20u, 0x24u);
    upload_common_hud_tile_range(subpal, 0x61u, 0x6Eu);
    upload_common_hud_tile_range(subpal, 0xF7u, 0xF9u);
}

static void upload_redux_automap_chr(unsigned char subpal)
{
    unsigned short dst = (unsigned short)(ROOMROM_BG_TILE_BASE_PAL(subpal)
                                          + REDUX_AUTOMAP_TILE_BASE);
    render_chr_upload((unsigned short)(dst * 32u),
                      redux_automap_chr_x4
                        + subpal * REDUX_AUTOMAP_CHR_PER_PAL_BYTES,
                      (unsigned short)(REDUX_AUTOMAP_TILE_COUNT * 32u));
}

void roomrom_hud_upload_chr(void)
{
    /* Phase 3: write 4 sub-pal copies of the 3-tile custom HUD CHR into
     * the BG bank. Bias rule per nibble: out = (in==0) ? 0 : (s*4 + in). */
    unsigned char buf[sizeof(s_hud_custom_chr)];
    unsigned char s, i;
    for (s = 0; s < 4; s++) {
        upload_common_hud_chr(s);
        upload_redux_automap_chr(s);
        for (i = 0; i < sizeof(s_hud_custom_chr); i++) {
            unsigned char b = s_hud_custom_chr[i];
            unsigned char hi = (b >> 4) & 0x0F;
            unsigned char lo = b & 0x0F;
            unsigned char ho = (hi == 0) ? 0 : (s * 4 + hi);
            unsigned char lz = (lo == 0) ? 0 : (s * 4 + lo);
            buf[i] = (unsigned char)((ho << 4) | lz);
        }
        render_chr_upload(
            (unsigned short)((ROOMROM_BG_TILE_BASE_PAL(s) + TILE_REDUX_HEART_OUTLINE) * 32u),
            buf,
            (unsigned short)sizeof(s_hud_custom_chr));
    }
}

/* Phase 6 Task 6.10.6 (Step A): cached HUD identity so the per-frame
 * dynamic refresh knows where to paint counts/hearts without re-running
 * the static transfer macro. */
static unsigned char s_hud_id_cached = 0xFFu;

static void draw_hud_dynamic(unsigned char hud_id)
{
    if (hud_id == ROOMROM_MAP_REDUX) {
        draw_status_counts_redux();
        /* Redux heart row anchored at col 4 of HUD row 5 (top of display). */
        draw_hearts_row(4u, 5u, hud_id);
    } else {
        draw_status_counts_original();
        /* Original NES paints hearts at NT row 6 cols 22..24 = HUD row 5. */
        draw_hearts_row(22u, 5u, hud_id);
    }
}

void roomrom_hud_draw(unsigned char hud_id, unsigned char room_id,
                      unsigned char is_underworld)
{
    const unsigned char *macro = s_original_hud_macro;
    if (hud_id == ROOMROM_MAP_REDUX)
        macro = is_underworld ? s_redux_uw_hud_macro : s_redux_ow_hud_macro;

    clear_hud_pal();
    clear_hud_window();
    clear_hud_b();
    apply_transfer_macro(macro);
    if (hud_id != ROOMROM_MAP_REDUX) {
        draw_original_map_marker(room_id);
    }
    s_hud_id_cached = hud_id;
    (void)is_underworld;
    draw_hud_dynamic(hud_id);
    (void)inventory_hud_consume_dirty();
}

/* Phase 6 Task 6.10.6 (Step A): per-frame live overlay. Repaints just
 * the dynamic count/heart cells from g_inventory. Cheap (fewer than 20
 * VDP_setTileMapXY calls) and keeps the rupee tick / damage path
 * observable without re-running the full static macro.
 *
 * SAT DMA Lag Fix Plan D (debate 2026-05-09): dirty-gate via inventory
 * snapshot. ~99% of ticks have unchanged inventory; skipping the redraw
 * saves ~15 active-display VDP_setTileMapXY writes per skipped frame. */
void roomrom_hud_refresh_dynamic(void)
{
    if (s_hud_id_cached == 0xFFu)
        return; /* HUD has not been drawn yet — nothing to refresh. */
    if (!inventory_hud_consume_dirty()) {
        return; /* Inventory unchanged — skip the VDP traffic. */
    }
    draw_hud_dynamic(s_hud_id_cached);
}
