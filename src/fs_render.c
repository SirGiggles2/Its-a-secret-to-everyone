/* src/fs_render.c — VDP primitives for native File Select. */
#include "fs_render.h"
#include "intro_common.h"   /* vdp_write_nametable_row, vdp_load_cram, etc. */
#include <stdint.h>

/* Generated assets. */
extern const uint16_t fs_link_palettes[4][4];
extern const uint8_t  fs_static_tilemap[960];
extern const uint8_t  fs_link_sprite_chr[];
extern const uint8_t  fs_heart_cursor_chr[];
extern const uint8_t  fs_font_chr[];
extern const uint8_t  fs_border_chr[];

#define PLANE_A_BASE 0xC000

void fs_render_clear_screen(void) {
    unsigned short zero_row[32];
    for (unsigned short i = 0; i < 32; i++) zero_row[i] = 0;
    /* V32 plane = 32 rows; clear all 30 visible rows. */
    for (unsigned short row = 0; row < 30; row++) {
        vdp_write_nametable_row(PLANE_A_BASE, row, zero_row);
    }
}

void fs_render_static_layout(void) {
    /* Translate fs_static_tilemap byte stream to plane A nametable rows.
     * Genesis cell = 16 bits: priority(1) | palette(2) | flipV(1) | flipH(1) | tile(11).
     * NES tile byte goes into low 11 bits; palette = 0; no flip.
     * V32 plane fits all 30 NES rows (PLAYERS/OPTIONS rows live at 28..29).
     */
    unsigned short cells[32];
    for (unsigned short row = 0; row < 30; row++) {
        for (unsigned short col = 0; col < 32; col++) {
            uint8_t tile = fs_static_tilemap[row * 32 + col];
            cells[col] = (uint16_t)tile;  /* palette 0, no flip */
        }
        vdp_write_nametable_row(PLANE_A_BASE, row, cells);
    }
}

/* Slot/cursor/players renders fleshed in next tasks. */
void fs_render_slot(uint8_t slot_idx) { (void)slot_idx; }
void fs_render_all_slots(void) {
    for (uint8_t i = 0; i < 3; i++) fs_render_slot(i);
}
void fs_render_cursor(uint8_t row) { (void)row; }
void fs_render_players_row(uint8_t value) { (void)value; }
