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

/* Walker alt-dir cluster (NES Plan-C drained from Z_07). */

/* Compute opposite of ENEMY_FRAME_FLAGS direction bit. If $0A bits set
 * (UP|LEFT), shift right; else shift left. NES WalkerAltDirGetOpposite.
 * drain at enemy_wanderer_runtime.c:14-19. */
unsigned int enemy_walker_alt_dir_get_opposite(void);

/* Clear ENEMY_BLOCKED_FLAG. NES WalkerAltDirEndLoop.
 * drain at enemy_wanderer_runtime.c:21-23. */
void enemy_walker_alt_dir_end_loop(void);

/* Pick a random perpendicular direction for slot via ENEMY_RNG_A and
 * ENEMY_DIR. Uses NES ReverseDirections table ($08 $04 $02 $01).
 * NES WalkerAltDirGetRandomPerpendicular. drain at enemy_wanderer_runtime.c:25-31. */
unsigned char enemy_walker_alt_dir_get_random_perpendicular(unsigned int slot);

/* Boss / mob init/state trivials. drain at enemy_boss_runtime.c. */

/* ENEMY_AI_STATE = state, ENEMY_TURN_TIMER = 6. NES FlyerSetStateAndTurns. */
void enemy_flyer_set_state_and_turns(unsigned int state, unsigned int slot);

/* core_anim_set_sprite_desc_attrs(3) — boss palette row 3.
 * NES AnimSetSpriteDescLevelPaletteRow. */
void enemy_anim_set_sprite_desc_level_palette_row(void);

/* Aquamentus init: invincibility=$E2, sfx_boss_cry=16, X=$B0, Y=$80. */
void enemy_init_aquamentus(unsigned int slot);

/* Tektite init: pick starting dir from TektiteStartingDirs[rng_b & 3]
 * ($01 $02 $05 $0A); seed move_timer = dir << 2. NES InitTektite.
 * Table baked inline from NES Z_04.asm:1832. */
void enemy_init_tektite(unsigned int slot);

/* Ganon randomize: Y=$A0, X=GanonStartXs[sprite_attr_row & 1] ($30 or $B0).
 * NES Z_04.asm:10488 table baked inline. */
void enemy_ganon_randomize_location(unsigned int slot);

/* Jumper-boulder dir-down: only if ENEMY_TYPE == $20, OR $04 into low
 * 2 bits of dir. NES JumperPointBoulderDownward. */
void enemy_jumper_point_boulder_downward(unsigned int slot);

#ifdef __cplusplus
}
#endif

#endif /* ENEMY_DISPATCH_H */
