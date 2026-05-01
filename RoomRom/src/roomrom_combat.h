#ifndef ROOMROM_COMBAT_H
#define ROOMROM_COMBAT_H

/* RoomRom S7 v3: sword swing (vertical only).
 *
 * NES Zelda 1 reference (z_05.asm WieldSword + z_07.asm UpdateSwordOrRod):
 *   - State 1 lasts 5 frames: sword extends out from Link in current facing
 *   - State 2 lasts 1 frame: sword retracts; Link returns to walk pose
 *   - Re-swing locked while state != 0
 *
 * v3 scope: UP/DOWN draw the real Z1 sword sprite (common_chr tiles
 * $20/$21, verified 2026-04-30 via probe_nes_sword_capture.lua —
 * see tools/out/nes_sword_capture.json). LEFT/RIGHT swings still lock
 * Link for the swing window (state machine unchanged) but the sword
 * sprite is hidden — horizontal sword tiles live in sprites_chr / NES
 * pattern table 1 and are tracked as S7b. Sword beam projectile +
 * enemy hit detection are also S7b / S8.
 */

#include "roomrom_sprites.h"

void roomrom_combat_init(void);
void roomrom_combat_try_swing(link_face_t face, short link_x, short link_y);
void roomrom_combat_update(short link_x, short link_y, link_face_t face);
unsigned char roomrom_combat_link_locked(void);

#endif
