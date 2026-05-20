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
#include "../../../RoomRom/src/atlas/items_chr_x4.h"
#include "../../state/inventory.h"

/* Genesis VRAM tile for item N: ITEM_VRAM_TILE_BASE + ROOMROM_ITEM_TILE_<X>.
 * ITEM_VRAM_TILE_BASE = ATTACK_VRAM_TILE + 16. ATTACK = LINK + 32. LINK = SPR_BASE+238.
 * = 533 + 238 + 32 + 16 = 819. */
#define ITEM_VRAM_TILE_BASE 819u
/* SAT VRAM base, gameplay context per PR-2 Option F. */
#define SAT_VRAM_BASE_GAMEPLAY 0xF400u

/* Helper: pack a SAT entry word block and write to a SAT slot via direct
 * VRAM. Y/x are 9-bit per Genesis VDP spec; size_link packs SIZE<<8 | next. */
static void sat_write(unsigned char slot, unsigned short y,
                      unsigned short size, unsigned char link,
                      unsigned short attr, unsigned short x)
{
    unsigned short addr = (unsigned short)(SAT_VRAM_BASE_GAMEPLAY + slot * 8u);
    render_vram_open_write(addr);
    *((volatile unsigned short *)0xC00000) = y;
    *((volatile unsigned short *)0xC00000) =
        (unsigned short)((size << 8) | link);
    *((volatile unsigned short *)0xC00000) = attr;
    *((volatile unsigned short *)0xC00000) = x;
}

#define PLANE_A_BASE      0xC000u
#define BLANK_TILE        1000u
#define SUBSCREEN_SUBPAL  0u  /* PAL0 for BG */

static unsigned char s_active = 0u;

/* P6.5 cursor state — hoisted so inventory_subscreen_enter can reference. */
#define B_ITEM_SLOT_COUNT  8u
static unsigned char s_cursor_slot = 0u;
static unsigned char s_prev_joy    = 0u;
static unsigned char s_cursor_sat  = 0u;

/* P6.3 scroll state machine. NES Z_05.asm:152+ UpdateMenuCommon scrolls
 * over ~22 frames. We replicate via row-by-row replacement: each tick
 * writes one row of inventory tilemap to plane A. */
typedef enum {
    SCROLL_IDLE   = 0,
    SCROLL_IN     = 1,   /* writing inventory rows 0..N */
    SCROLL_ACTIVE = 2,   /* subscreen fully visible */
    SCROLL_OUT    = 3    /* clearing inventory rows N..0 */
} scroll_state_t;
static scroll_state_t s_scroll_state = SCROLL_IDLE;
static unsigned char  s_scroll_row   = 0u;
#define SCROLL_TOTAL_ROWS 28u

static void draw_cursor(void);   /* forward decl */
static unsigned char b_item_owned(unsigned char slot);  /* forward decl */
static void draw_item_sprites(void);   /* forward decl */
static void write_inventory_row(unsigned short row);   /* forward decl */

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

/* Draw an owned item sprite. Writes ONE SAT entry at the given pixel
 * position with the item tile_id. SIZE(1,2) = 8x16 to match NES OAM 8x16
 * mode for item icons. */
static unsigned char s_next_sat_slot;

static void draw_item_icon(unsigned char tile_offset, unsigned short y, unsigned short x)
{
    unsigned short vram_tile = (unsigned short)(ITEM_VRAM_TILE_BASE + tile_offset);
    unsigned short attr = RENDER_TILE_ATTR_FULL(RENDER_PAL1, 0, 0, 0, vram_tile);
    unsigned char link = (unsigned char)(s_next_sat_slot + 1u);
    sat_write(s_next_sat_slot, y, RENDER_SPRITE_SIZE(1, 2), link, attr, x);
    ++s_next_sat_slot;
}

/* Draw a 2x2 (16x16) item icon — for items rendered with sprite_size=(2,2)
 * like sword_horz, explosion, etc. */
static void draw_item_icon_2x2(unsigned char tile_offset, unsigned short y, unsigned short x)
{
    unsigned short vram_tile = (unsigned short)(ITEM_VRAM_TILE_BASE + tile_offset);
    unsigned short attr = RENDER_TILE_ATTR_FULL(RENDER_PAL1, 0, 0, 0, vram_tile);
    unsigned char link = (unsigned char)(s_next_sat_slot + 1u);
    sat_write(s_next_sat_slot, y, RENDER_SPRITE_SIZE(2, 2), link, attr, x);
    ++s_next_sat_slot;
}

/* Write ONE row of inventory tilemap to Plane A row N. Called row-by-row
 * by the scroll-in tick state machine (P6.3). Row content per layout:
 *   row 2  = "INVENTORY" header
 *   row 4  = "USE B BUTTON FOR THIS"
 *   row 13 = "TRIFORCE"
 *   other  = blank (item sprites overlay these rows after scroll completes) */
static void write_inventory_row(unsigned short row)
{
    /* Default: blank row. */
    unsigned short cells[32];
    unsigned short i;
    unsigned short blank_attr = RENDER_TILE_ATTR_FULL(SUBSCREEN_SUBPAL, 0, 0, 0,
                                                      BLANK_TILE);
    for (i = 0; i < 32u; ++i) cells[i] = blank_attr;
    render_plane_a_write_row(row, cells, 32u);

    /* Now overlay text on specific rows. */
    if (row == 2u)  write_text(2u,  10u, "INVENTORY");
    if (row == 4u)  write_text(4u,  6u,  "USE B BUTTON FOR THIS");
    if (row == 13u) write_text(13u, 10u, "TRIFORCE");
}

/* Draw all item icon sprites at their fixed positions. Called once when
 * scroll-in completes. */
static void draw_item_sprites(void)
{
    s_next_sat_slot = 0u;

    /* B-item row at y=$50. */
    unsigned short b_row_y = 0x80u + 0x40u;
    if (g_inventory.boomerang_wood)
        draw_item_icon(ROOMROM_ITEM_TILE_BOOMERANG, b_row_y, 0x40u);
    if (g_inventory.bombs)
        draw_item_icon(ROOMROM_ITEM_TILE_BOMB, b_row_y, 0x50u);
    if (g_inventory.bow)
        draw_item_icon(ROOMROM_ITEM_TILE_BOW, b_row_y, 0x60u);
    if (g_inventory.candle)
        draw_item_icon(ROOMROM_ITEM_TILE_CANDLE_FIRE_F0, b_row_y, 0x70u);
    if (g_inventory.items & ITEMS_BIT_WAND)
        draw_item_icon(ROOMROM_ITEM_TILE_SWORD_VERT, b_row_y, 0x80u);
    if (g_inventory.items & ITEMS_BIT_FLUTE)
        draw_item_icon(ROOMROM_ITEM_TILE_RECORDER, b_row_y, 0x90u);
    if (g_inventory.food)
        draw_item_icon(ROOMROM_ITEM_TILE_FOOD, b_row_y, 0xA0u);
    if (g_inventory.potion)
        draw_item_icon(ROOMROM_ITEM_TILE_POTION, b_row_y, 0xB0u);

    unsigned short p_row_y = 0x80u + 0x70u;
    if (g_inventory.raft)
        draw_item_icon(ROOMROM_ITEM_TILE_RAFT, p_row_y, 0x40u);
    if (g_inventory.book)
        draw_item_icon(ROOMROM_ITEM_TILE_BOOK_OF_MAGIC, p_row_y, 0x50u);
    if (g_inventory.ring)
        draw_item_icon(ROOMROM_ITEM_TILE_RING, p_row_y, 0x60u);
    if (g_inventory.ladder)
        draw_item_icon(ROOMROM_ITEM_TILE_LADDER, p_row_y, 0x70u);
    if (g_inventory.magic_key)
        draw_item_icon(ROOMROM_ITEM_TILE_MAGIC_KEY, p_row_y, 0x80u);
    if (g_inventory.bracelet)
        draw_item_icon(ROOMROM_ITEM_TILE_BRACELET, p_row_y, 0x90u);

    unsigned short t_row_y = 0x80u + 0xB0u;
    unsigned char piece;
    for (piece = 0; piece < 8u; ++piece) {
        if (g_inventory.triforce & (1u << piece)) {
            draw_item_icon(ROOMROM_ITEM_TILE_TRIFORCE_PIECE,
                           t_row_y, (unsigned short)(0x40u + piece * 0x14u));
        }
    }

    s_cursor_sat = s_next_sat_slot;
    draw_cursor();
}

void inventory_subscreen_enter(void)
{
    /* Reset HSCROLL — gameplay leaves Plane A scrolled. VSRAM left
     * alone for now; row-by-row scroll-in mechanism replaces gameplay
     * rows from top down. */
    *((volatile unsigned long *)0xC00004) = 0x7C000003UL;
    *((volatile unsigned long *)0xC00000) = 0x00000000UL;

    /* Hide all sprites during scroll-in (so frozen gameplay sprites
     * don't render over partially-built subscreen). */
    {
        unsigned char i;
        unsigned short sat_addr = SAT_VRAM_BASE_GAMEPLAY;
        render_vram_open_write(sat_addr);
        for (i = 0; i < 80u; ++i) {
            *((volatile unsigned short *)0xC00000) = 0x0000;
            *((volatile unsigned short *)0xC00000) = 0x0000;
            *((volatile unsigned short *)0xC00000) = 0x0000;
            *((volatile unsigned short *)0xC00000) = 0x0000;
        }
    }

    /* Also clear Plane B (gameplay sometimes uses it for room staging). */
    unsigned short blank_attr = RENDER_TILE_ATTR_FULL(SUBSCREEN_SUBPAL, 0, 0, 0,
                                                      BLANK_TILE);
    render_plane_fill(0xE000u, blank_attr, 64u * 32u);

    /* Start scroll-in state machine — tick will write rows progressively. */
    s_active       = 1u;
    s_scroll_state = SCROLL_IN;
    s_scroll_row   = 0u;
    s_prev_joy     = 0u;
    s_cursor_slot  = 0u;
}

/* P6.5 cursor + selection. */
static unsigned char b_item_owned(unsigned char slot)
{
    switch (slot) {
        case 0: return g_inventory.boomerang_wood;
        case 1: return (g_inventory.bombs > 0u) ? 1u : 0u;
        case 2: return g_inventory.bow;
        case 3: return (g_inventory.candle > 0u) ? 1u : 0u;
        case 4: return (g_inventory.items & ITEMS_BIT_WAND) ? 1u : 0u;
        case 5: return (g_inventory.items & ITEMS_BIT_FLUTE) ? 1u : 0u;
        case 6: return g_inventory.food;
        case 7: return (g_inventory.potion > 0u) ? 1u : 0u;
        default: return 0u;
    }
}

static void draw_cursor(void)
{
    /* B-item row Y matches inventory_subscreen_enter b_row_y. Cursor sits
     * directly under selected slot at y + 16. Use compass tile (small
     * round shape) in PAL1 as placeholder arrow indicator. */
    unsigned short y = 0x80u + 0x50u;  /* one row below B-item icons */
    unsigned short x = (unsigned short)(0x40u + s_cursor_slot * 0x10u);
    unsigned short vram_tile = (unsigned short)(ITEM_VRAM_TILE_BASE +
                                                ROOMROM_ITEM_TILE_COMPASS);
    unsigned short attr = RENDER_TILE_ATTR_FULL(RENDER_PAL1, 0, 0, 0, vram_tile);
    sat_write(s_cursor_sat, y, RENDER_SPRITE_SIZE(1, 2), 0u, attr, x);
}

void inventory_subscreen_exit(void)
{
    /* Trigger scroll-out — tick clears rows N..0 over ~28 frames. */
    s_scroll_state = SCROLL_OUT;
    s_scroll_row   = SCROLL_TOTAL_ROWS;  /* clear from bottom up */
    /* s_active stays 1 until scroll completes; tick deactivates + signals
     * main.c to call load_room. */
}

/* Query: is scroll-out done (so main.c knows to call load_room)? */
unsigned char inventory_subscreen_scrolled_out(void)
{
    return (s_scroll_state == SCROLL_IDLE && s_active == 0u);
}

void inventory_subscreen_tick(unsigned char joy_state)
{
    if (!s_active) return;

    /* P6.3 scroll state machine. */
    if (s_scroll_state == SCROLL_IN) {
        /* Write next inventory row each frame; advance until all 28 rows
         * are written. ~2 rows/frame for snappy feel (NES does ~1.3
         * rows/frame over 22 frames). */
        write_inventory_row(s_scroll_row);
        ++s_scroll_row;
        if (s_scroll_row < SCROLL_TOTAL_ROWS) {
            write_inventory_row(s_scroll_row);
            ++s_scroll_row;
        }
        if (s_scroll_row >= SCROLL_TOTAL_ROWS) {
            s_scroll_state = SCROLL_ACTIVE;
            draw_item_sprites();  /* sprites visible once BG done */
        }
        return;
    }

    if (s_scroll_state == SCROLL_OUT) {
        /* Clear rows from bottom up — gameplay rolls back into view. */
        if (s_scroll_row > 0u) {
            --s_scroll_row;
            unsigned short cells[32];
            unsigned short i;
            unsigned short blank = RENDER_TILE_ATTR_FULL(SUBSCREEN_SUBPAL, 0, 0, 0,
                                                         BLANK_TILE);
            for (i = 0; i < 32u; ++i) cells[i] = blank;
            render_plane_a_write_row(s_scroll_row, cells, 32u);
            if (s_scroll_row > 0u) {
                --s_scroll_row;
                render_plane_a_write_row(s_scroll_row, cells, 32u);
            }
        }
        if (s_scroll_row == 0u) {
            s_scroll_state = SCROLL_IDLE;
            s_active = 0u;
            /* Hide cursor sprite. */
            unsigned short sat_addr = (unsigned short)(SAT_VRAM_BASE_GAMEPLAY +
                                                       s_cursor_sat * 8u);
            render_vram_open_write(sat_addr);
            *((volatile unsigned short *)0xC00000) = 0x0000;
            *((volatile unsigned short *)0xC00000) = 0x0000;
            *((volatile unsigned short *)0xC00000) = 0x0000;
            *((volatile unsigned short *)0xC00000) = 0x0000;
        }
        return;
    }

    /* SCROLL_ACTIVE — accept input. */

    /* Joy bits per SGDK joy.h: UP=$01 DOWN=$02 LEFT=$04 RIGHT=$08
     * B=$10 C=$20 A=$40 START=$80. */
    unsigned char pressed = (unsigned char)(joy_state & ~s_prev_joy);
    s_prev_joy = joy_state;

    /* D-pad LEFT/RIGHT cycle cursor over B-item slots; skip empty. */
    if (pressed & 0x08u) {  /* RIGHT */
        unsigned char tries = 0u;
        do {
            s_cursor_slot = (unsigned char)((s_cursor_slot + 1u) % B_ITEM_SLOT_COUNT);
            ++tries;
        } while (!b_item_owned(s_cursor_slot) && tries < B_ITEM_SLOT_COUNT);
    }
    if (pressed & 0x04u) {  /* LEFT */
        unsigned char tries = 0u;
        do {
            s_cursor_slot = (unsigned char)((s_cursor_slot + B_ITEM_SLOT_COUNT - 1u) % B_ITEM_SLOT_COUNT);
            ++tries;
        } while (!b_item_owned(s_cursor_slot) && tries < B_ITEM_SLOT_COUNT);
    }

    /* A press selects current B-item. */
    if (pressed & 0x40u) {
        g_inventory.selected_b_item = s_cursor_slot;
        nes_ram[0x0656u] = s_cursor_slot;
    }

    draw_cursor();
}
