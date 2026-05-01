#ifndef ROOMROM_COMBAT_H
#define ROOMROM_COMBAT_H

/* RoomRom S7: combat (sword + beam).
 *
 * NES Zelda 1 reference (z_05.asm WieldSword + z_07.asm UpdateSwordOrRod):
 *   - State 1 lasts 5 frames: sword extends out from Link in current facing
 *   - State 2 lasts 1 frame: sword retracts; Link returns to walk pose
 *   - Re-swing locked while state != 0
 *
 * v1 scope: UP/DOWN sword facings only (vertical sword tiles $20-$23 in
 * common_chr). LEFT/RIGHT sword tiles + sword beam projectile are TBD —
 * captured live in S7 follow-up.
 */

#include "roomrom_sprites.h"

void roomrom_combat_init(void);
void roomrom_combat_try_swing(link_face_t face, short link_x, short link_y);
void roomrom_combat_update(short link_x, short link_y, link_face_t face);
unsigned char roomrom_combat_link_locked(void);

#endif
