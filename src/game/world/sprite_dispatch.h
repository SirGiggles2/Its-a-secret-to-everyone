/* sprite_dispatch.h — native sprite subsystem dispatch (Phase 4).
 *
 * Native rewrite of src/oracle/world/sprite_runtime.c. Both ROMs link.
 * Pure C, no transpile shims (cross-subsystem core helper
 * z01_reset_cur_sprite_index inlined per NES semantics).
 *
 * Phase 4 first sprite batch: rolling sprite index helpers + OAM hide
 * + Link priority-drop for horizontal door transitions.
 */

#ifndef SPRITE_DISPATCH_H
#define SPRITE_DISPATCH_H

#ifdef __cplusplus
extern "C" {
#endif

/* Bump the rolling sprite-write cursor (RollingSpriteIndex at $0341).
 * Wraps from $27 -> $00 (40 sprite slots used per frame). NES
 * CycleCurSpriteIndex (Z_01.asm). */
void sprite_cycle_cur_sprite_index(void);

/* As above but takes the previous index as a parameter (= "in A"
 * NES register-passing convention) and returns the new value. */
unsigned char sprite_cycle_sprite_index_in_a(unsigned char idx);

/* Hide all 24 dynamic-object OAM slots by writing $F8 to their Y byte
 * (off-screen). Then bump the high-priority OAM cursor at $0342.
 * Mirrors NES HideObjectSprites. */
void sprite_hide_object_sprites(void);

/* During a side-doorway scroll, force Link's top-half OAM sprites
 * (slot 18 left half + 19 right half) into "behind background"
 * priority (OAM attr bit $20) so the door arch tiles render over
 * his head/torso. Mirrors NES ShowLinkSpritesBehindHorizontalDoors
 * (Z_01.asm:1594-ish). */
void sprite_show_link_sprites_behind_horizontal_doors(void);

#ifdef __cplusplus
}
#endif

#endif /* SPRITE_DISPATCH_H */
