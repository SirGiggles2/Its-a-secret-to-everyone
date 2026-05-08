#ifndef ROOMROM_MAGIC_SHOT_H
#define ROOMROM_MAGIC_SHOT_H

/* RoomRom magic rod shot (the projectile fired when B-item = ROD).
 *
 * NES Z1 reference: Z_07.asm:4351 UpdateSwordOrRod (rod state machine,
 * ObjState 1..5 → spawn shot at state 3, slot $0E) +
 * Z_07.asm:3408 UpdateSwordShotOrMagicShot (projectile motion + draw).
 *
 * Tile dispatch via Anim_ItemFrameTiles[$2B + frame]:
 *   frame 0 (vertical):   $7A + $7B (8x16 in PPU 8x16 mode)
 *   frame 1 (horizontal): $7C + $7D + $7E + $7F (wide flippable, 16x16)
 *
 * Sub-pal flashes per FrameCounter & 3 (cycles 0..3 every frame). Genesis
 * sub-pal 3 disabled (atlas dropped to 3-pal); cycle 0..2 instead.
 *
 * Wand-extending visual (rod sprite at Link's hand) deferred.
 */

#include "roomrom_sprites.h"

void roomrom_magic_shot_init(void);
void roomrom_magic_shot_fire(link_face_t face, short link_x, short link_y);
void roomrom_magic_shot_update(void);
unsigned char roomrom_magic_shot_active(void);

#endif
