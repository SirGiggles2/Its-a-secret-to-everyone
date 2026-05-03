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

#ifdef __cplusplus
}
#endif

#endif /* TRAP_DISPATCH_H */
