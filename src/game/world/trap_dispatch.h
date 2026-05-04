/* trap_dispatch.h — native trap subsystem dispatch (Phase 4).
 *
 * Native rewrite of src/oracle/world/trap_runtime.c. Both ROMs link.
 * Phase 4 first batch: trivial leaves (advance_teleporting_level_index).
 * Larger functions (whirlwind init/draw/update, summon, init_mode_b_enter_cave,
 * check_passive_tile_objects, update_trap, update_rupee_stash) defer to
 * future batches because they reach into transpile shims +
 * cross-subsystem state (link_collision, c_draw_object,
 * c_go_to_next_mode_from_play, z01_check_link_collision, etc.).
 */

#ifndef TRAP_DISPATCH_H
#define TRAP_DISPATCH_H

#ifdef __cplusplus
extern "C" {
#endif

/* Increment TELEPORT_LEVEL_INDEX, then back off by 2 if the LINK_DIR
 * vertical component (bits $09 = up + right) is clear. Effectively
 * keeps the teleport cycle on horizontal moves. Mirrors NES
 * AdvanceTeleportingLevelIndex. drain at trap_runtime.c:81-86. */
void trap_advance_teleporting_level_index(void);

/* If TELEPORT_ACTIVE_FLAG is non-zero, advance teleport state +
 * spawn a whirlwind at slot 9 with LINK_Y from TeleportYs[]. Then
 * SUBMODE_VALUE = 0; MODE_TIMER++. NES CheckInitWhirlwindAndBeginUpdate.
 * drain at trap_runtime.c:69-79. */
void trap_check_init_whirlwind_and_begin_update(void);

/* If MODE_VALUE == 5, walk LevelMasks[] to find an unconquered
 * level mask; if found and no whirlwind/teleport active, spawn
 * whirlwind in an empty enemy slot. NES SummonWhirlwind.
 * drain at trap_runtime.c:88-110. */
void trap_summon_whirlwind(void);

/* Initialize a 4 or 6-trap cluster from TrapXs/TrapYs tables (count
 * 4 normally, 6 if MON_TYPE(slot) == TRAP_OBJ_TYPE). Each new trap
 * gets its slot derived from TRAP_BASE_SLOT. NES InitTrap_Full.
 * drain at trap_runtime.c:4-17. */
void trap_init_trap_full(unsigned int slot);

/* If Link is on a tile-aligned grid + PASSIVE_OBJ_FLAG is set, scan
 * for tile types $BC..$C3, then spawn a passive bumped object adjacent
 * to Link via empty enemy slot. NES CheckPassiveTileObjects. drain
 * at trap_runtime.c:140-188. */
void trap_check_passive_tile_objects(void);

/* Animate + draw whirlwind sprite. Calls anim_advance_and_fetch +
 * anim_set_sprite_desc_attrs (palette = FRAME_COUNTER & 3) +
 * anim_set_obj_hflip + draw_object_not_mirrored_with_frame. NES
 * DrawWhirlwind. drain at trap_runtime.c:19-24. */
void trap_draw_whirlwind(unsigned int slot);

#ifdef __cplusplus
}
#endif

#endif /* TRAP_DISPATCH_H */
