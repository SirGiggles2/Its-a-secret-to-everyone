#include <genesis.h>
#include "roomrom_hud.h"
#include "ow_room_render_roomrom.h"
#include "render_abi.h"

#define HUD_TILE_SPACE  0x24u
#define TILE_DASH       0x62u
#define TILE_LOW_X      0x21u
#define TILE_FULL_HEART 0xF2u
#define TILE_GRAY_MAP   0xF5u
#define TILE_REDUX_HEART_OUTLINE 0x50u
#define TILE_ORIGINAL_MAP_MARKER 0x51u
#define TILE_REDUX_HEART_FILL    0x52u

#define HUD_TILE_BASE   1u

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

static const unsigned char s_redux_hud_macro[] = {
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

static unsigned short hud_word(unsigned char raw_tile, unsigned char pal)
{
    return (unsigned short)(((unsigned short)(pal & 0x03) << 13) |
                            ((unsigned short)raw_tile + HUD_TILE_BASE));
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
    if (col >= ROOMROM_ROOM_COLS || row >= ROOMROM_HUD_ROWS)
        return;
    VDP_setTileMapXY(BG_B, hud_word(raw_tile, pal), col, row);
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
    VDP_clearTileMapRect(BG_B, 0, 0, ROOMROM_ROOM_COLS, ROOMROM_HUD_ROWS);
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

static void draw_status_counts(void)
{
    static const unsigned char rows[4] = {2,3,4,5};
    unsigned char i;
    for (i = 0; i < 4; i++) {
        draw_hud_tile(12, rows[i], TILE_LOW_X, 0);
        draw_hud_tile(13, rows[i], 0x00, 0);
        draw_hud_tile(14, rows[i], HUD_TILE_SPACE, 0);
    }
}

static void draw_hearts(unsigned char hud_id)
{
    unsigned char col = (hud_id == ROOMROM_MAP_REDUX) ? 4u : 25u;
    unsigned char i;
    for (i = 0; i < 3; i++) {
        if (hud_id == ROOMROM_MAP_REDUX) {
            draw_hud_tile_b((unsigned char)(col + i), 5,
                            TILE_REDUX_HEART_OUTLINE, 0);
            draw_hud_tile((unsigned char)(col + i), 5,
                          TILE_REDUX_HEART_FILL, 1);
        } else {
            draw_hud_tile((unsigned char)(col + i), 5, TILE_FULL_HEART, 1);
        }
    }
}

static void draw_original_map_marker(unsigned char room_id)
{
    unsigned char col = (unsigned char)(2u + ((room_id & 0x0Fu) >> 1));
    unsigned char row = (unsigned char)(2u + ((room_id >> 4) >> 1));
    draw_hud_tile(col, row, TILE_ORIGINAL_MAP_MARKER, 2);
}

void roomrom_hud_upload_chr(void)
{
    render_chr_upload((unsigned short)((TILE_REDUX_HEART_OUTLINE + HUD_TILE_BASE) * 32u),
                      s_hud_custom_chr,
                      (unsigned short)sizeof(s_hud_custom_chr));
}

void roomrom_hud_draw(unsigned char hud_id, unsigned char room_id)
{
    clear_hud_pal();
    clear_hud_window();
    clear_hud_b();
    apply_transfer_macro((hud_id == ROOMROM_MAP_REDUX) ? s_redux_hud_macro
                                                       : s_original_hud_macro);
    if (hud_id == ROOMROM_MAP_REDUX) {
        draw_status_counts();
        draw_hearts(hud_id);
    } else {
        draw_original_map_marker(room_id);
    }
}
