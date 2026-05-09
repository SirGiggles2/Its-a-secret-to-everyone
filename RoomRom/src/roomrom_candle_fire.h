/* Task 5.8.1 candle fire projectile (RoomRom-local).
 *
 * NES authority: Z_01.asm:WieldCandle (3948-3987), Z_07.asm:UpdateFire
 *                (4622-4768). Q-speed $20 (0.5 px/frame), distance $10
 *                then stand $3F frames, anim cycle 4 frames.
 *
 * Slice-1 placeholder visual: explosion glyph from items_chr_x4 atlas
 * (true 4-frame red-pal NES fire CHR not yet extracted — see
 * project_chr_extraction_items_blocker memory). Full anim/red-pal
 * parity deferred to 5.8.2.
 *
 * Sprite slot 8 (avoids conflict with arrow slot 4 + room-item slot 7).
 */

#ifndef ROOMROM_CANDLE_FIRE_H
#define ROOMROM_CANDLE_FIRE_H

#include "roomrom_sprites.h"

void roomrom_candle_fire_init(void);
void roomrom_candle_fire_spawn(link_face_t face, short link_x, short link_y);
void roomrom_candle_fire_update(void);
unsigned char roomrom_candle_fire_active(void);

/* NES Z_01.asm:3967 UsedCandle: per-room flag, blocks 2nd blue-candle
 * spawn. Reset on room transition (load_room). Red candle ignores. */
unsigned char roomrom_candle_fire_used_this_room(void);
void          roomrom_candle_fire_mark_used(void);
void          roomrom_candle_fire_room_reset(void);

#endif
