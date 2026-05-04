/* draw_dispatch.h — native sprite-descriptor / OAM draw pipeline
 * (Phase 4).
 *
 * Native rewrite of the DrawObjectMirrored / DrawObjectNotMirrored
 * chain in reference/aldonunez/Z_01.asm + the Anim_Write* OAM-mirror
 * writers. Both ROMs link.
 *
 * Pipeline:
 *   draw_object_mirrored / draw_object_not_mirrored
 *     -> draw_object_with_type
 *     -> draw_object_with_anim
 *     -> draw_object_with_anim_and_specific_sprites
 *     -> anim_write_horizontally_flippable_sprite_pair
 *        | anim_write_mirrored_sprite_pair
 *     -> anim_write_sprite_pair
 *     -> anim_write_sprite_pair_not_flashing -- writes 2 sprites
 *        to nes_ram[$0200..$02FF] OAM mirror.
 *
 * Replaces transpile-bridge shim chain c_draw_object_*. See
 * tools/audit/drain_findings/4_12n_draw_object.md.
 */

#ifndef DRAW_DISPATCH_H
#define DRAW_DISPATCH_H

#ifdef __cplusplus
extern "C" {
#endif

/* DrawObjectMirrored. frame in ZP_TMPD entry-side ($000D) per asm
 * convention: actual D0=frame is loaded by callers via ZP_TMPD.
 * Native version takes frame explicitly. NES Z_01.asm:2058. */
void draw_object_mirrored(unsigned char frame, unsigned int slot);

/* DrawObjectNotMirrored. Same as mirrored except mirrored=0.
 * NES Z_01.asm:2069. */
void draw_object_not_mirrored(unsigned char frame, unsigned int slot);

/* DrawObjectMirrored variant: frame already in TMPD via D0; here
 * frame is passed explicit. Used by per-monster updaters that
 * compute their own frame. NES DrawObjectMirroredWithFrame. */
void draw_object_mirrored_with_frame(unsigned char frame, unsigned int slot);

/* DrawObjectNotMirroredWithFrame. */
void draw_object_not_mirrored_with_frame(unsigned char frame, unsigned int slot);

#ifdef __cplusplus
}
#endif

#endif /* DRAW_DISPATCH_H */
