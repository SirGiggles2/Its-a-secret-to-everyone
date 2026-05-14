#ifndef ROOMROM_COMBAT_H
#define ROOMROM_COMBAT_H

/* RoomRom S7 v4: sword swing.
 *
 * NES Z1 reference (reference/aldonunez/Z_05.asm WieldSword + Z_07.asm
 * UpdateSwordOrRod + PlayerToWeaponOffsetsX/Y at Z_07:4337):
 *
 *   - Player ObjState set to $10 (wielding) on swing start.
 *   - Sword has 5 visible-window states:
 *       state 1 (5 frames): windup, sword raised UP regardless of
 *                            facing.
 *       state 2 (8 frames): full extend in facing direction (the
 *                            "slash").
 *       state 3 (1 frame):  mid-retract.
 *       state 4 (1 frame):  almost retracted.
 *       state 5 (1 frame):  invisible — sword sprite hidden, Link's
 *                            body returns to walk pose.
 *   - Total swing window: 16 frames. Re-swing locked the entire window.
 *
 * Body sprite changes during the swing (states 1-4): Link draws as
 * attack pose tiles ($14/$16 down, $18/$1A up, $10/$12 left/right).
 * See roomrom_sprites_set_link_attack_pose.
 *
 * Sword tiles (NES Anim_ItemFrameTiles, Z_01.asm:5202):
 *   vertical (UP/DOWN, state 1, states 2-4 vertical facings) = $20
 *   horizontal (LEFT/RIGHT in states 2-4) = $82
 */

#include "roomrom_sprites.h"

void roomrom_combat_init(void);
void roomrom_combat_try_swing(link_face_t face, short link_x, short link_y);
void roomrom_combat_update(short link_x, short link_y, link_face_t face);
unsigned char roomrom_combat_link_locked(void);

/* Apply a -2 px Y bias to sword + beam when Link is in a dungeon
 * (NES Z1 dungeons render sword/beam 2 px higher than overworld due
 * to a different sprite Y baseline). 0 = OW (no bias), 1 = UW. */
void roomrom_combat_set_uw(unsigned char in_uw);

/* Redux mode toggle (per docs/audit/redux_touchpoints.md, diagonal
 * sword + ALttP-style sword arc are out-of-scope IPS extensions of
 * NES Z1). v11 hooks the flag so future patches can vary timing or
 * dispatch alternate animation paths without touching the cardinal
 * combat state machine. Currently a no-op flag — reserved for v11+. */
void roomrom_combat_set_redux(unsigned char redux);

#endif
