#ifndef ROOMROM_HUD_H
#define ROOMROM_HUD_H

void roomrom_hud_upload_chr(void);
void roomrom_hud_draw(unsigned char hud_id, unsigned char room_id,
                      unsigned char is_underworld);

/* Phase 6 Task 6.10.6 (Step A): per-frame live overlay of count/heart
 * cells from g_inventory. Cheap; safe to call every frame after the
 * first roomrom_hud_draw(). No-op until HUD has been drawn at least
 * once. */
void roomrom_hud_refresh_dynamic(void);

/* Plan v5c T6.5 — per-frame mini-map position marker + palette flash.
 * NES Z_01.asm:4095-4146 renders flashing marker sprite at computed
 * (x,y) from room_id every 16 frames. Port: BG tile $51 with palette
 * alternation. No-op for UW (redux automap path) or before HUD drawn. */
void roomrom_hud_refresh_marker(unsigned char room_id,
                                unsigned char is_underworld,
                                unsigned char frame_counter);

#endif
