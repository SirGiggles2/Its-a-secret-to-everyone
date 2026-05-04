/* link_collision_dispatch.h — native link-collision subsystem dispatch
 * (Phase 4).
 *
 * Native rewrite of select leaves from
 * src/oracle/combat/link_collision_runtime.c. Both ROMs link.
 *
 * Phase 4 first batch: link_be_harmed (the heart-damage core). Bigger
 * functions (harm_link, check_link_collision_*, check_monster_collisions,
 * begin_shove) defer until colrt_*, c_*, and z07_anim_* land native.
 */

#ifndef LINK_COLLISION_DISPATCH_H
#define LINK_COLLISION_DISPATCH_H

#ifdef __cplusplus
extern "C" {
#endif

/* Apply Link damage: rings shift threshold, deduct heart slack +
 * partial, on death set MODE_VALUE=17 + clear stun. NES LinkBeHarmed.
 * drain at link_collision_runtime.c:6-46. */
void link_collision_link_be_harmed(unsigned int monster_slot);

#ifdef __cplusplus
}
#endif

#endif /* LINK_COLLISION_DISPATCH_H */
