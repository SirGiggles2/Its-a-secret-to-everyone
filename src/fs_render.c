/* src/fs_render.c — VDP primitives for native File Select. */
#include "fs_render.h"
#include "intro_common.h"   /* vdp_write_nametable_row, vdp_load_cram, etc. */
#include <stdint.h>

/* Generated assets. */
extern const uint16_t fs_palettes[4][4];
extern const uint8_t  fs_static_tilemap[960];
extern const uint8_t  fs_static_attr[64];
extern const uint8_t  fs_link_sprite_chr[];
extern const uint8_t  fs_heart_cursor_chr[];
extern const uint8_t  fs_font_chr[];
extern const uint8_t  fs_border_chr[];

/* CRAM palette indices (matches src/gen/fs_palette.c layout). */
#define PAL_BG_LINK     2u   /* Gen pal 2 = NES sprite pal 0 (green Link) */
#define PAL_BG_CURSOR   3u   /* Gen pal 3 = NES sprite pal 3 (heart cursor) */

#define PLANE_A_BASE  0xC000
#define PLANE_B_BASE  0xE000  /* boot.asm Reg4=$8407 → plane B @ $E000 */
#define SAT_VRAM      0xF800  /* Sprite Attribute Table — boot.asm Reg5=$857C */

/* CHR tile indices in Genesis VRAM (set by fs_init):
 *   BG CHR block at tiles 0x00..0xFF (256 tiles covering all NES BG tiles).
 *   Link sprite CHR at tile 0x100..0x103 (4 tiles: left-top, left-bot, right-top, right-bot).
 *   Heart cursor CHR at tile 0x104 (1 tile).
 *
 * We place sprite tiles ABOVE the full BG block to avoid collision: the nametable
 * references NES BG tiles 0x80-0x84 for hearts/name display, so VRAM 0x80-0x84
 * must hold those BG glyphs, not Link sprite data.
 */
#define LINK_CHR_BASE   0x100
#define HEART_CHR_BASE  0x104

/* VDP registers (word-access). */
#define VDP_CTRL_WORD (*(volatile uint16_t *)0x00C00004)
#define VDP_DATA_WORD (*(volatile uint16_t *)0x00C00000)
#define VDP_CTRL_LONG (*(volatile uint32_t *)0x00C00004)

/* ---------------------------------------------------------------------------
 * SAT write helper.
 *
 * Genesis SAT layout (each entry = 8 bytes = 4 words):
 *   word 0: Y position  (bits 9:0, +128 bias; top 6 bits = 0)
 *   word 1: size + link (bits 15:11 = size, bits 6:0 = next-sprite link)
 *   word 2: tile_attr   (pri<<15 | pal<<13 | flipV<<12 | flipH<<11 | tile[10:0])
 *   word 3: X position  (bits 9:0, +128 bias; top 6 bits = 0)
 *
 * Size field encoding (bits 15:11 of word 1):
 *   H size (bits 12:11): 00=1cell, 01=2cells, 10=3cells, 11=4cells
 *   V size (bits 14:13): 00=1cell, 01=2cells, 10=3cells, 11=4cells
 *   e.g. 2H×2V (16×16px) = H=01,V=01 → bits 14:11 = 0101 → word1 = 0x0500
 *
 * entry: sprite slot index (0..79 in H32 mode)
 * y, x: screen pixel positions INCLUDING the +128 SAT offset.
 * size: encoded size word (e.g. 0x0500 for 2×2 cells = 16×16 px).
 * tile_attr: encoded tile+palette+priority word.
 * link: next sprite index (0 = end-of-list).
 * ---------------------------------------------------------------------------
 */
static void sat_write(uint8_t entry, uint16_t y, uint16_t size_link,
                      uint16_t tile_attr, uint16_t x) {
    uint16_t addr = (uint16_t)(SAT_VRAM + (uint16_t)entry * 8U);
    /* Open VRAM write at SAT[entry]. */
    uint32_t cmd = 0x40000000UL
                 | ((uint32_t)(addr & 0x3FFF) << 16)
                 | (uint32_t)((addr >> 14) & 0x0003);
    VDP_CTRL_LONG = cmd;
    VDP_DATA_WORD = y;
    VDP_DATA_WORD = size_link;
    VDP_DATA_WORD = tile_attr;
    VDP_DATA_WORD = x;
}

/* ---------------------------------------------------------------------------
 * sat_clear: write a hidden (offscreen) entry.
 * Genesis hides a sprite when Y >= 480 in H32; simplest is Y=0 (above screen).
 * Using Y=0 (which maps to screen row -128, invisible) and link=0 to terminate.
 * ---------------------------------------------------------------------------
 */
static void sat_clear_entry(uint8_t entry) {
    sat_write(entry, 0, 0, 0, 0);
}

/* ---------------------------------------------------------------------------
 * fs_sram_slot_occupied: v1 mock — slot 0 occupied (bright), 1+2 empty (dim).
 * Real SRAM read lands in v3.1.
 * ---------------------------------------------------------------------------
 */
extern uint8_t fs_sram_slot_occupied(uint8_t slot);
__attribute__((weak)) uint8_t fs_sram_slot_occupied(uint8_t slot) {
    return slot == 0 ? 1 : 0;
}

void fs_render_clear_screen(void) {
    unsigned short zero_row[32];
    for (unsigned short i = 0; i < 32; i++) zero_row[i] = 0;
    /* V32 plane = 32 rows; clear all 32 rows of both planes.
     * Plane B must be cleared too — uninitialised cells point to VRAM tile 0,
     * which holds NES font tile 0 ('0' digit) → background fills with '0's. */
    for (unsigned short row = 0; row < 32; row++) {
        vdp_write_nametable_row(PLANE_A_BASE, row, zero_row);
        vdp_write_nametable_row(PLANE_B_BASE, row, zero_row);
    }
}

/* attr_palette_for_cell: decode NES attribute table to per-cell palette.
 *
 * NES attr byte at row=ar (0..7), col=ac (0..7) covers a 4×4 BG-cell region.
 * Each 2-bit field selects palette for one 2×2 sub-quadrant:
 *   bits 1:0 = top-left (cells [ar*4..ar*4+1, ac*4..ac*4+1])
 *   bits 3:2 = top-right (cells [ar*4..ar*4+1, ac*4+2..ac*4+3])
 *   bits 5:4 = bottom-left (cells [ar*4+2..ar*4+3, ac*4..ac*4+1])
 *   bits 7:6 = bottom-right (cells [ar*4+2..ar*4+3, ac*4+2..ac*4+3])
 */
static uint8_t attr_palette_for_cell(uint16_t row, uint16_t col) {
    uint16_t ar = row >> 2;          /* attr-row index 0..7 (last row 28-29 reuses ar=7) */
    uint16_t ac = col >> 2;
    if (ar >= 8) ar = 7;             /* clamp: 30 rows / 4 = 7.5 → ar=7 covers rows 28-29 */
    uint8_t b = fs_static_attr[ar * 8 + ac];
    uint16_t sub_row = (row >> 1) & 1u;   /* 0 = top half of 4×4, 1 = bottom half */
    uint16_t sub_col = (col >> 1) & 1u;
    uint8_t shift = (uint8_t)((sub_row << 2) | (sub_col << 1));  /* 0,2,4,6 */
    return (uint8_t)((b >> shift) & 0x03u);
}

void fs_render_static_layout(void) {
    /* Translate fs_static_tilemap + fs_static_attr to plane A nametable rows.
     * Genesis cell = 16 bits: priority(1) | palette(2) | flipV(1) | flipH(1) | tile(11).
     * Per-cell palette comes from NES attribute table; LIFE/heart-icon area uses pal 1.
     * V32 plane fits all 30 NES rows (PLAYERS/OPTIONS rows live at 28..29).
     */
    unsigned short cells[32];
    for (unsigned short row = 0; row < 30; row++) {
        for (unsigned short col = 0; col < 32; col++) {
            uint8_t tile = fs_static_tilemap[row * 32 + col];
            uint8_t pal  = attr_palette_for_cell(row, col);
            cells[col] = (uint16_t)(((uint16_t)pal & 0x3u) << 13) | (uint16_t)tile;
        }
        vdp_write_nametable_row(PLANE_A_BASE, row, cells);
    }
}

/* ---------------------------------------------------------------------------
 * fs_render_slot: write Link sprite for one save slot row.
 *
 * NES geometry (Mode1_WriteLinkSprites, Z_02.asm:2634-2638):
 *   base_y = $58 (NES screen Y), X = $30; +$18 per slot.
 *   Slot 0: NES_Y=$58, Slot 1: $70, Slot 2: $88.
 *
 * Genesis SAT coordinates = NES + 128:
 *   Slot 0: sat_y=$D8 (216), Slot 1: $F0 (240), Slot 2: $108 (264)
 *   X: sat_x = 0x30 + 128 = 0xB0 (176)
 *
 * Link occupies 2×2 cells (16×16 px) on Genesis using a single SAT entry
 * with size=0x0500 (H=2cells,V=2cells). The 4 Genesis tiles at LINK_CHR_BASE
 * cover: [0x80]=left-top, [0x81]=left-bot, [0x82]=right-top, [0x83]=right-bot.
 * Genesis stores them as col-major: tile_index=0x80 → left col, 0x82 → right col.
 *
 * Palette assignment:
 *   Occupied slot: palette index matches slot number (0,1,2) → colors green/blue/red.
 *   Empty slot: palette index 3 → dim/grey palette.
 * ---------------------------------------------------------------------------
 */
void fs_render_slot(uint8_t slot_idx) {
    /* NES Y base for Link sprites = $58; increment $18 per slot. */
    uint16_t nes_y = (uint16_t)(0x58u + (uint16_t)slot_idx * 0x18u);
    uint16_t sat_y = (uint16_t)(nes_y + 128u);   /* +128 SAT bias */
    uint16_t sat_x = (uint16_t)(0x30u + 128u);   /* NES X=$30, +128 bias → 0xB0 */

    /* v1.fix2: Genesis 4-palette budget is BG0/BG1/Link/cursor — no per-slot tint.
     * All 3 Link sprite slots use Gen pal 2 (NES sprite pal 0 = green Link).
     * v3 SRAM may revisit if per-slot color matters more than multi-pal BG fidelity.
     * Hide Link sprite for empty slots (occupied=0): sat_clear off-screen.
     */
    uint8_t occupied = fs_sram_slot_occupied(slot_idx);
    uint8_t sat_entry = (uint8_t)(1u + slot_idx);
    if (!occupied) {
        sat_clear_entry(sat_entry);
        return;
    }
    uint16_t palette = (uint16_t)PAL_BG_LINK;

    /* tile_attr: priority=0, palette=palette, no flip, tile=LINK_CHR_BASE.
     * Genesis tile_attr word: pri(15) | pal(14:13) | flipV(12) | flipH(11) | tile(10:0) */
    uint16_t tile_attr = (uint16_t)((palette & 0x3u) << 13) | (uint16_t)LINK_CHR_BASE;

    /* size_link: H=2cells,V=2cells → 0x0500; link → next sprite in SAT chain.
     * Chain: cursor (entry 0) → slot 0 (1) → slot 1 (2) → slot 2 (3) → end.
     * Slot 2 (last) terminates with link=0; others link to entry+1. */
    uint8_t next_link = (slot_idx == 2u) ? 0u : (uint8_t)(sat_entry + 1u);
    uint16_t size_link = (uint16_t)(0x0500u | next_link);

    /* Sprite entries: use slots 1, 2, 3 (slot 0 reserved for cursor). */
    sat_write(sat_entry, sat_y, size_link, tile_attr, sat_x);
}

/* ---------------------------------------------------------------------------
 * fs_render_cursor: write heart sprite at the currently selected row.
 *
 * NES OAM: Mode1CursorSpriteTriplet = {tile=$F3, attr=$03, X=$28}.
 * Mode1CursorSpriteYs = {$5C,$74,$8C,$A8,$B8} for slots 0..4.
 *
 * Genesis: heart cursor is a single 1×1 cell sprite (8×8 px).
 * Palette: attr $03 = palette 3 (4th sprite palette on NES). Use palette 3.
 * X: NES $28 = 40; sat_x = 40+128 = 168 = $A8.
 * Y: NES slot Y table values +128.
 * ---------------------------------------------------------------------------
 */
void fs_render_cursor(uint8_t row) {
    /* NES slot Y for cursor (Mode1CursorSpriteYs, Z_02.asm:2591-2592). */
    static const uint8_t cursor_ys[5] = { 0x5C, 0x74, 0x8C, 0xA8, 0xB8 };
    if (row >= 5) return;

    uint16_t sat_y = (uint16_t)(cursor_ys[row] + 128u);
    uint16_t sat_x = (uint16_t)(0x28u + 128u);   /* NES X=$28 */

    /* tile_attr: palette=PAL_BG_CURSOR (Gen pal 3 = NES sprite pal 3), no flip, tile=HEART_CHR_BASE. */
    uint16_t tile_attr = (uint16_t)((uint16_t)PAL_BG_CURSOR << 13) | (uint16_t)HEART_CHR_BASE;

    /* size: 1×1 cell (8×8 px) = 0x0000 size field.
     * link=1 chains scan to SAT entry 1 (slot 0 Link sprite). */
    uint16_t size_link = 0x0001u;

    /* SAT entry 0: cursor is always first (matches NES Sprites[0]). */
    sat_write(0, sat_y, size_link, tile_attr, sat_x);
}

void fs_render_all_slots(void) {
    for (uint8_t i = 0; i < 3; i++) fs_render_slot(i);
}

void fs_render_players_row(uint8_t value) { (void)value; }
