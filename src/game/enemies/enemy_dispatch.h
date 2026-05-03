/* enemy_dispatch.h — native enemy subsystem dispatch (Phase 4).
 *
 * Native rewrite of src/oracle/enemies/enemy_runtime.c +
 * enemy_common_runtime.c. Both ROMs link. RoomRom needs this most
 * directly — current enemy gap (no monsters in OW per user feedback)
 * traces to oracle-only enemy update/draw. Native ports start with
 * leaf helpers, build up to full per-monster updaters.
 */

#ifndef ENEMY_DISPATCH_H
#define ENEMY_DISPATCH_H

#ifdef __cplusplus
extern "C" {
#endif

/* Find an empty monster slot in 11..1 (skipping slot 0 = Link).
 * Stashes result into ENEMY_NEXT_SHOT_SLOT and returns it. Returns 0
 * if no slot free. NES FindEmptyMonsterSlot. drain at
 * src/oracle/enemies/enemy_runtime.c:12-20. */
unsigned int enemy_find_empty_monster_slot(void);

/* Hide top two priority sprite slots (OAM 0, 1) by writing $F8 to
 * their Y bytes. Used during scrolling transitions to avoid Link
 * top-half sprites bleeding above doorway tiles. NES
 * HideSpritesOverLink. drain at enemy_common_runtime.c:4-7. */
void enemy_hide_sprites_over_link(void);

/* SFX trivials: play "secret found" tune (Z1 secret reveal),
 * boss death cry, gohma parry tune. drain at enemy_common_runtime.c:9-20. */
void enemy_play_secret_found_tune(void);
void enemy_play_boss_death_cry(void);
void enemy_gohma_play_parry_tune(void);

#ifdef __cplusplus
}
#endif

#endif /* ENEMY_DISPATCH_H */
