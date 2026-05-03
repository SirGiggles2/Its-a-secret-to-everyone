/* enemy_dispatch.c — native enemy subsystem dispatch (Phase 4).
 *
 * Phase 4 first enemy batch: 5 trivial leaf helpers. Pure C, no
 * shims. Drain MATCH per finding 4_7n.
 */

#include "enemy_dispatch.h"
#include "platform_abi.h"      /* RAM, OBJ, NES_OBJ_TYPE */
#include "enemy_state.h"       /* ENEMY_OAM_HIDE_*, ENEMY_SFX_*, ENEMY_NEXT_SHOT_SLOT */

unsigned int enemy_find_empty_monster_slot(void)
{
    /* drain at enemy_runtime.c:12-20. NES FindEmptyMonsterSlot.
     * Scan slots 11..1 (skip slot 0 = Link); first empty slot wins. */
    for (signed char i = 11; i >= 1; i--) {
        if (OBJ(NES_OBJ_TYPE, (unsigned char)i) == 0u) {
            ENEMY_NEXT_SHOT_SLOT = (unsigned char)i;
            return (unsigned int)(unsigned char)i;
        }
    }
    return 0u;
}

void enemy_hide_sprites_over_link(void)
{
    /* drain at enemy_common_runtime.c:4-7. */
    ENEMY_OAM_HIDE_0 = 0xF8u;
    ENEMY_OAM_HIDE_1 = 0xF8u;
}

void enemy_play_secret_found_tune(void)
{
    /* drain at enemy_common_runtime.c:9-11. */
    ENEMY_SFX_SECRET = 4u;
}

void enemy_play_boss_death_cry(void)
{
    /* drain at enemy_common_runtime.c:13-16. */
    ENEMY_SFX_BOSS_CRY = 2u;
    ENEMY_SFX_BOSS_CRY_FLAGS = 0x80u;
}

void enemy_gohma_play_parry_tune(void)
{
    /* drain at enemy_common_runtime.c:18-20. */
    ENEMY_SFX_PARRY = 1u;
}
