/* src/fs_render.h
 *
 * VDP primitives for File Select. Each function writes plane bytes
 * via render_* helpers from render_abi.h (S1.F4: vdp_* removed).
 */
#ifndef FS_RENDER_H
#define FS_RENDER_H

#include <stdint.h>

void fs_render_clear_screen(void);
void fs_render_static_layout(void);          /* border, "-SELECT-", NAME/LIFE headers,
                                                COPY/ERASE row labels (NES capture) */
void fs_render_extra_rows(void);             /* v3 Redux: PLAYERS + OPTIONS labels */
void fs_render_slot(uint8_t slot_idx);       /* Link sprite (bright/dim), name, hearts */
void fs_render_all_slots(void);
void fs_render_cursor(uint8_t row);          /* heart sprite at row Y (rows 0..6) */
void fs_render_players_row(uint8_t value);   /* PLAYERS digit cell with current 1..4 */

#endif
