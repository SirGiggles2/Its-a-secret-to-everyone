/* Phase 7 Task 7.2 step 2 — enemy slot iterator + type dispatch shell.
 *
 * Drain Rule D1 stance: EXTEND. Function-pointer tables are the dispatch
 * shape (verbatim NES InitObject_JumpTable at Z_07.asm:5601). Tasks 7.3-7.7
 * fill rows one family at a time, paired with the shim plumbing each
 * family needs. Step 2 ships the SHELL — every row is NULL.
 *
 * Why all-NULL right now:
 *   Walker-family drain (commit b5026c1a) compiles cleanly but its
 *   bodies call into c_walker_move / c_shoot_if_wanted / z01_abs /
 *   z07_anim_* / enrt_animate_and_draw_common_object / 30+ other
 *   primitives that are NOT yet linked into Debug.md. Wiring even one
 *   walker entry retains those objects past --gc-sections and the link
 *   fails with undefined references. Per Drain Rule D1 we don't stub
 *   shims (would silently no-op the drained behavior); we wait for
 *   real impl per family. Step 2 deliverable = iterator + clear/spawn
 *   state machine + dispatch shape.
 *
 * Hard rule WT-5 (RoomRom freeze, 2026-05-09): this file lives at
 * src/game/enemies/ instead of RoomRom/src/. ENEMY_* macros are still
 * supplied by RoomRom/src/roomrom_enemy_state.h until Task 7.7 lands a
 * promoted version under src/state/.
 */

#include "enemy_loop.h"
#include "roomrom_enemy_state.h"          /* still in RoomRom/src/ pre-WT-5 */
#include "platform_abi.h"

/* Function-pointer tables. NULL = family not drained / not in Phase 7
 * step 2 scope. Tasks 7.3-7.7 fill rows + add shim sources to
 * tools/debug/build_debug.py without modifying this file. */
const enemy_init_fn enemy_init_fns[ENEMY_LOOP_TYPE_MAX] = {
    /* All slots NULL until Task 7.3 wires walker shims. NES
     * InitObject_JumpTable shape preserved by the array length. */
    0
};

const enemy_update_fn enemy_update_fns[ENEMY_LOOP_TYPE_MAX] = {
    /* All slots NULL until Task 7.3 wires walker shims. */
    0
};

/* Internal: clear an enemy slot's scratch state per NES InitObject
 * preamble (Z_07.asm:5466-5563). Mirrors the LDA #0 / STA scratch
 * sequence the NES does BEFORE dispatching JumpTable[ObjType,X]. */
static void clear_slot_scratch(unsigned int slot)
{
    ENEMY_DIR(slot)            = 0u;
    ENEMY_STATE_TIMER(slot)    = (unsigned char)slot;
    ENEMY_LIFE(slot)           = 0u;
    ENEMY_METASTATE(slot)      = 0u;
    ENEMY_PUSH_TIMER(slot)     = 0u;
    ENEMY_AIR_SPEED(slot)      = 0u;
    ENEMY_TURN_TIMER(slot)     = 0u;
    ENEMY_AI_STATE(slot)       = 0u;
    ENEMY_BLOATED_TIMER(slot)  = 0u;
    ENEMY_BOUNCE_FLAGS(slot)   = 0u;
    ENEMY_CHARGE_SPEED(slot)   = 0u;
    ENEMY_COLLIDED_TILE(slot)  = 0u;
    ENEMY_INVINCIBILITY(slot)  = 0u;
    ENEMY_HIT_REACTION(slot)   = 0u;
    ENEMY_DRAW_FRAME(slot)     = 0u;
    ENEMY_WALK_SPEED(slot)     = 0u;
    ENEMY_ANIM_TIMER(slot)     = 0u;
    ENEMY_PUSH_DIR_SCRATCH(slot) = 0u;
    ENEMY_FLAP_PHASE(slot)     = 0u;
    ENEMY_FLYER_X_FINE(slot)   = 0u;
    ENEMY_ALIVE_FLAG(slot)     = 1u;  /* mark slot occupied */
}

void enemy_loop_room_init(unsigned char room_id, unsigned char scene_id)
{
    unsigned int slot;
    /* Clear all enemy slots on room load. */
    for (slot = ENEMY_LOOP_SLOT_FIRST; slot <= ENEMY_LOOP_SLOT_LAST; ++slot) {
        ENEMY_TYPE(slot) = 0u;        /* type 0 = DoNothing = empty */
        ENEMY_ALIVE_FLAG(slot) = 0u;
        ENEMY_X(slot) = 0u;
        ENEMY_Y(slot) = 0u;
    }

    /* Phase 7 step 2: room->template lookup deferred to Task 7.7.
     * For first probe (Q4=c) the test hook
     * enemy_loop_force_spawn_slow_octorock() fires from probe Lua to
     * seed slot 1 deterministically. Once the per-room ObjList
     * template_id table lands, this function will:
     *   1. lookup template_id = room_obj_template[scene_id][room_id]
     *   2. ptr = obj_list_for_template(template_id)
     *   3. for slot in 1..count: ENEMY_TYPE[slot] = ptr[slot-1]
     *   4. AssignObjSpawnPositions (NES Z_05.asm:1818)
     *   5. dispatch enemy_init_fns[ENEMY_TYPE[slot]]
     */
    (void)room_id;
    (void)scene_id;
}

void enemy_loop_tick(void)
{
    unsigned int slot;
    /* Q3=(b): function-pointer table dispatch. NULL = no-op (family
     * not yet wired). Q2=(c) gating done by caller — this function is
     * ONLY called inside the scroll-stable + non-paused branch of the
     * gameplay tick. */
    for (slot = ENEMY_LOOP_SLOT_FIRST; slot <= ENEMY_LOOP_SLOT_LAST; ++slot) {
        unsigned char t;
        enemy_update_fn fn;
        if (ENEMY_ALIVE_FLAG(slot) == 0u) continue;
        t = (unsigned char)ENEMY_TYPE(slot);
        if (t >= ENEMY_LOOP_TYPE_MAX) continue;
        fn = enemy_update_fns[t];
        if (fn != 0) fn(slot);
    }
}

void enemy_loop_force_spawn_slow_octorock(unsigned int slot,
                                          unsigned char x,
                                          unsigned char y,
                                          unsigned char dir)
{
    /* Q4=(c) first probe seed: one slow octorok at known (x,y,dir).
     * Used by tools/debug/probes/probe_walker_parity.lua to capture a
     * 60-frame X/Y/DIR trace at matched RNG seed for diff vs NES.
     *
     * Step 2 writes state cells only (no enrt_init_ call yet — see
     * file-level comment). Probe verifies iterator + type lookup +
     * force_spawn cell writes. Task 7.3 wires walker init + ticks. */
    enemy_init_fn fn;
    if (slot < ENEMY_LOOP_SLOT_FIRST || slot > ENEMY_LOOP_SLOT_LAST) return;

    ENEMY_TYPE(slot) = 0x07u;   /* RedSlowOctorock — NES InitObject_JumpTable[$07] */
    ENEMY_X(slot) = x;
    ENEMY_Y(slot) = y;
    clear_slot_scratch(slot);
    ENEMY_DIR(slot) = dir;

    fn = enemy_init_fns[0x07u];
    if (fn != 0) fn(slot);
}

unsigned int enemy_loop_alive_count(void)
{
    unsigned int slot, n = 0u;
    for (slot = ENEMY_LOOP_SLOT_FIRST; slot <= ENEMY_LOOP_SLOT_LAST; ++slot) {
        if (ENEMY_ALIVE_FLAG(slot) != 0u) n++;
    }
    return n;
}

unsigned char enemy_loop_get_type(unsigned int slot)
{
    if (slot < ENEMY_LOOP_SLOT_FIRST || slot > ENEMY_LOOP_SLOT_LAST) return 0u;
    return (unsigned char)ENEMY_TYPE(slot);
}
