/* Phase 7 Task 7.2 step 3 — wire first init dispatch row (slow octorok / ghini).
 *
 * Drain Rule D1 stance: EXTEND. Function-pointer tables are the dispatch
 * shape (verbatim NES InitObject_JumpTable at Z_07.asm:5601). Tasks 7.3-7.7
 * fill rows one family at a time, paired with the shim plumbing each
 * family needs.
 *
 * Step 3 wires INIT only for ENEMY_TYPE 0x07 (RedSlowOctorock / Ghini).
 * Update-side dispatch is still NULL — enrt_update_rope and friends call
 * c_walker_move / z07_anim_advance_and_fetch / c_check_monster_collisions
 * which are not yet linked into Debug.md. Update wiring lands in Task 7.3
 * paired with native drain or shim plumbing for those primitives. Per
 * Drain Rule D1 we route z07_reset_obj_state to the already-linked
 * core_reset_obj_state body in src/game/core/core_dispatch.c (drain at
 * src/core/core_runtime.c:327). Forwarder is one line, not a stub.
 *
 * Hard rule WT-5 (RoomRom freeze, 2026-05-09): this file lives at
 * src/game/enemies/ instead of RoomRom/src/. ENEMY_* macros are still
 * supplied by RoomRom/src/roomrom_enemy_state.h until Task 7.7 lands a
 * promoted version under src/state/.
 */

#include "enemy_loop.h"
#include "roomrom_enemy_state.h"          /* still in RoomRom/src/ pre-WT-5 */
#include "platform_abi.h"
#include "probes/enemy_loop_probe.h"      /* step 4 live-tick publish */

/* Forward decls — defined in src/oracle/enemies/enemy_walker_runtime.c
 * and src/game/core/core_dispatch.c respectively. Both objects are
 * already linked into Debug.md per build_debug.py ROOMROM_C_SOURCES. */
extern void enrt_init_slow_octorock_or_ghini(unsigned int slot);
extern void enrt_update_rope(unsigned int slot);  /* walker UPDATE row $07 */
extern unsigned char core_reset_obj_state(unsigned int slot);

/* z07_reset_obj_state forwarder. enrt_octorock_common (same TU as the
 * init we wire below) calls this symbol. The drained body lives at
 * src/core/core_runtime.c:327 and was promoted into the native core
 * dispatch as core_reset_obj_state — call it directly. Avoids dragging
 * in src/gen/z_07.c (which would also pull room_runtime + core_runtime
 * + collision_runtime + their state header chains). Per --gc-sections
 * + -ffunction-sections, only this single forwarder is retained. */
unsigned char z07_reset_obj_state(unsigned int slot)
{
    return core_reset_obj_state(slot);
}

/* Function-pointer tables. Designated initializers leave unset rows at
 * NULL. Tasks 7.3-7.7 fan out by adding rows here without otherwise
 * modifying the file. */
const enemy_init_fn enemy_init_fns[ENEMY_LOOP_TYPE_MAX] = {
    [0x07] = enrt_init_slow_octorock_or_ghini,
    /* RedSlowOctorock — NES InitObject_JumpTable[$07] @ Z_07.asm:5601.
     * Body: enrt_octorock_common(slot, 32) → enrt_init_walker(slot).
     * Sets WALK_SPEED=$20, MOVE_TIMER=(slot+1)<<4, OBJ_STATE=0,
     * DRAW_FRAME=0, ANIM_TIMER=6, then computes DIR from LINK_X/LINK_Y
     * vs OBJ_X/OBJ_Y (h_dir or v_dir, whichever has larger diff). */
};

const enemy_update_fn enemy_update_fns[ENEMY_LOOP_TYPE_MAX] = {
    /* Step 4 (debate 2026-05-09 verdict, Option C) wires UPDATE row
     * $07. enrt_update_rope is the walker UPDATE handler for Octorok /
     * Moblin / Stalfos / Goriya / Darknut / Rope variants — per NES
     * ObjectActions table the Red Slow Octorock ($07) update slot
     * resolves to the rope/octorock walker tick body. Primitives
     * (c_walker_move stub + c_check_monster_collisions +
     * c_draw_object_not_mirrored_with_frame + z07_anim_advance_and_fetch
     * + z01_anim_set_sprite_desc_attrs + z01_abs) supplied by
     * src/game/enemies/enemy_walker_bridge.c. Walker_Move drain pending
     * — animation / palette / collision / draw run; movement frozen. */
    [0x07] = enrt_update_rope,
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
    /* Step 4 pre-tick snapshot — captures slot state BEFORE the
     * dispatch loop runs. Used to localize where TYPE clears: if pre
     * still shows $07 but post is $00, the dispatch / update body
     * killed the slot. */
    enemy_loop_probe_publish_pre();

    for (slot = ENEMY_LOOP_SLOT_FIRST; slot <= ENEMY_LOOP_SLOT_LAST; ++slot) {
        unsigned char t;
        enemy_update_fn fn;
        if (ENEMY_ALIVE_FLAG(slot) == 0u) continue;
        t = (unsigned char)ENEMY_TYPE(slot);
        if (t >= ENEMY_LOOP_TYPE_MAX) continue;
        fn = enemy_update_fns[t];
        if (fn != 0) fn(slot);
    }

    /* Step 4 live-tick publish — last so block reflects post-tick
     * cells. Lua reads $FF7F00 to confirm UPDATE chain ran. */
    enemy_loop_probe_publish_live();
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
