/* src/fs_render.h
 *
 * VDP primitives for File Select. Each function writes plane bytes
 * directly via vdp_* helpers in intro_common.h (shared infra).
 */
#ifndef FS_RENDER_H
#define FS_RENDER_H

#include <stdint.h>

void fs_render_clear_screen(void);
void fs_render_static_layout(void);          /* border, "-SELECT-", NAME/LIFE headers,
                                                COPY/ERASE/PLAYERS/OPTIONS row labels */
void fs_render_slot(uint8_t slot_idx);       /* Link sprite (bright/dim), name, hearts */
void fs_render_all_slots(void);
void fs_render_cursor(uint8_t row);          /* heart sprite at row Y */
void fs_render_players_row(uint8_t value);   /* PLAYERS row with current 1..4 */

#endif
