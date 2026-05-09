/* enemy_boss_bridge.c -- Phase 7 Task 7.3 step 7 vire UPDATE primitives
 * bridge.
 *
 * Resolves the 5 c_* / z04_* primitives consumed by enrt_update_vire
 * (entry point) + transitively by enrt_update_vire_state /
 * enrt_check_vire_collisions / enrt_draw_vire in
 * src/oracle/enemies/enemy_boss_runtime.c (linked Task 7.3 step 7):
 *
 *   c_gel_move_splitting       -> enrt_gel_move_splitting
 *                                 (enemy_common_runtime.c:226)
 *   z04_update_common_wanderer -> enrt_update_common_wanderer
 *                                 (enemy_wanderer_runtime.c:44)
 *   c_anim_advance_and_fetch   -> sprite_anim_advance_and_fetch
 *                                 (sprite_dispatch.c:105) — same back-end
 *                                 used by z07_anim_advance_and_fetch in
 *                                 walker_bridge; vire calls the c_-named
 *                                 entry directly.
 *   c_find_empty_monster_slot  -> enrt_find_empty_monster_slot
 *                                 (enemy_runtime.c:12) — also stashes
 *                                 ENEMY_NEXT_SHOT_SLOT for c_shoot.
 *   c_shoot                    -> writes ENEMY_SHOT_TYPE_SCRATCH (= ZP_TMP0
 *                                 = ENEMY_VIRE_SPLIT_TYPE) then forwards
 *                                 to enrt_shoot (enemy_boss_runtime.c:434).
 *
 * Stance: EXTEND. All callees are drained C (PRIMARY evidence per
 * Drain Rule D1). No NES asm linkage. No transpiled-bank fallback.
 *
 * Hard rule WT-5: lives at src/game/enemies/, not RoomRom/.
 *
 * NOTE — ENEMY_THROWER_SLOT ($0340) is read by enrt_shoot but not
 * written by any current call-site in the vire chain. NES Shoot uses
 * CurObjIndex (the X register) implicitly. Our enemy_loop_tick does
 * not yet write ENEMY_THROWER_SLOT per-slot. Step 7 lands the link
 * surface; step 8+ probe will validate runtime correctness and add
 * the dispatcher write if needed.
 */

#include "platform_abi.h"             /* RAM, OBJ, NES_OBJ_TYPE, CARRY_SET */
#include "roomrom_enemy_state.h"      /* ENEMY_SHOT_TYPE_SCRATCH macros */
#include "world/sprite_dispatch.h"    /* sprite_anim_advance_and_fetch */
#include "core/core_dispatch.h"       /* core_set_type_and_clear_object */

/* Forward declarations of drained twins. Bodies in src/oracle/enemies/. */
extern unsigned int enrt_gel_move_splitting(unsigned int slot);
extern void         enrt_update_common_wanderer(unsigned int turn_rate,
                                                unsigned int slot);
extern unsigned int enrt_shoot(void);

/* z07_set_type_and_clear_object — required by enrt_shoot
 * (enemy_boss_runtime.c:437). Drained native twin lives in
 * core_dispatch.c:490 as core_set_type_and_clear_object. Same body
 * NES Z_07.asm SetTypeAndClearObject — sets ObjType[slot]=type then
 * zeroes scratch fields. */
void z07_set_type_and_clear_object(unsigned int type, unsigned int slot)
{
    core_set_type_and_clear_object(type, slot);
}

unsigned int c_gel_move_splitting(unsigned int slot)
{
    return enrt_gel_move_splitting(slot);
}

void z04_update_common_wanderer(unsigned int turn_rate, unsigned int slot)
{
    enrt_update_common_wanderer(turn_rate, slot);
}

void c_anim_advance_and_fetch(unsigned int val, unsigned int slot)
{
    sprite_anim_advance_and_fetch(val, slot);
}

/* c_find_empty_monster_slot — native body. enemy_runtime.c (which
 * carries enrt_find_empty_monster_slot) is NOT linked into Debug.md
 * (would pull enrt_animate_and_draw_common_object + its full chain).
 * Body verbatim from enemy_runtime.c:12 — scan slots 11..1 for
 * ObjType==0, stash into ENEMY_NEXT_SHOT_SLOT, return slot index. */
unsigned char c_find_empty_monster_slot(void)
{
    signed char i;
    for (i = 11; i >= 1; i--) {
        if (OBJ(NES_OBJ_TYPE, (unsigned char)i) == 0u) {
            ENEMY_NEXT_SHOT_SLOT = (unsigned char)i;
            return (unsigned char)i;
        }
    }
    return 0u;
}

unsigned int c_shoot(unsigned int type)
{
    /* ENEMY_SHOT_TYPE_SCRATCH = ZP_TMP0 — same cell vire's call-site
     * already populated via ENEMY_VIRE_SPLIT_TYPE (also ZP_TMP0).
     * Writing again is idempotent and forward-compatible with future
     * c_shoot consumers that don't pre-populate. */
    ENEMY_SHOT_TYPE_SCRATCH = (unsigned char)type;
    return enrt_shoot();
}
