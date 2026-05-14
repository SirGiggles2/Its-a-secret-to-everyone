#ifndef ROOMROM_BOMB_H
#define ROOMROM_BOMB_H

/* RoomRom S7 v8 bomb.
 *
 * NES Z1 reference: Z_05.asm WieldBomb. Bomb is placed at Link's
 * facing direction (16 px ahead). Fuse counts down (~$60 = 96 frames
 * on NES). When fuse expires, explosion animation plays (~30 frames)
 * then bomb deactivates.
 *
 * Tiles (Anim_ItemFrameOffsets[5]=$0C, Anim_ItemFrameTiles[$0C]=$24):
 *   bomb body:  $24 (top), $25 (bottom) — narrow 8x16
 *   explosion: $32, $33 (left half), $34, $35 (right half)
 *              — wide 16x16 used as SPRITE_SIZE(2,2)
 *
 * RoomRom v8 simplification: 60-frame fuse, 24-frame explosion.
 */

#include "roomrom_sprites.h"

void roomrom_bomb_init(void);
void roomrom_bomb_place(link_face_t face, short link_x, short link_y);
void roomrom_bomb_update(void);
unsigned char roomrom_bomb_active(void);

#endif
