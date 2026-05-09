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
 * (init), src/oracle/enemies/enemy_wanderer_runtime.c (goriya update),
 * src/game/enemies/enemy_walker_bridge.c (step-6 native octorock),
 * and src/game/core/core_dispatch.c (reset). All linked into Debug.md
 * per build_debug.py ROOMROM_C_SOURCES + step-6 unblock stubs. */
extern void enrt_init_slow_octorock_or_ghini(unsigned int slot);
extern void enrt_init_walker(unsigned int slot);                 /* step 7 */
extern void enrt_init_darknut(unsigned int slot);                /* step 7 */
extern void enrt_init_fast_octorock(unsigned int slot);          /* step 7 */
extern void enrt_update_octorock(unsigned int slot);  /* step 6 native */
extern void enrt_update_moblin(unsigned int slot);               /* step 7 */
extern void enrt_update_goriya(unsigned int slot);               /* step 7 */
extern void enrt_update_stalfos(unsigned int slot);              /* step 7 */
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
    /* NES InitObject_JumpTable @ Z_07.asm:5601.
     * $01-$06 = InitWalker (Lynel/Moblin/Goriya families).
     * $07/$09 = InitSlowOctorockOrGhini (sets WALK_SPEED=$20).
     * $08/$0A = InitFastOctorock (sets WALK_SPEED=$30).
     * $0B/$0C = InitDarknut (INVINCIBILITY $F6 + WALK_SPEED $20/$28).
     * $2A     = InitWalker (Stalfos).
     *
     * RedSlowOctorock body: enrt_octorock_common(slot, 32) →
     * enrt_init_walker(slot) — sets WALK_SPEED, MOVE_TIMER=(slot+1)<<4,
     * OBJ_STATE=0, DRAW_FRAME=0, ANIM_TIMER=6, then computes DIR from
     * LINK_X/LINK_Y vs OBJ_X/OBJ_Y (h_dir or v_dir, whichever has
     * larger diff). */
    [0x01] = enrt_init_walker,                 /* BlueLynel */
    [0x02] = enrt_init_walker,                 /* RedLynel */
    [0x03] = enrt_init_walker,                 /* BlueMoblin */
    [0x04] = enrt_init_walker,                 /* RedMoblin */
    [0x05] = enrt_init_walker,                 /* BlueGoriya */
    [0x06] = enrt_init_walker,                 /* RedGoriya */
    [0x07] = enrt_init_slow_octorock_or_ghini, /* RedSlowOctorock */
    [0x08] = enrt_init_fast_octorock,          /* RedFastOctorock */
    [0x09] = enrt_init_slow_octorock_or_ghini, /* BlueSlowOctorock */
    [0x0A] = enrt_init_fast_octorock,          /* BlueFastOctorock */
    [0x0B] = enrt_init_darknut,                /* BlueDarknut */
    [0x0C] = enrt_init_darknut,                /* RedDarknut */
    [0x2A] = enrt_init_walker,                 /* Stalfos */
};

const enemy_update_fn enemy_update_fns[ENEMY_LOOP_TYPE_MAX] = {
    /* NES UpdateObject_JumpTable @ Z_04.asm:5295.
     * $03/$04 = UpdateMoblin (turn rate $A0 + Wanderer + _TryShoot $5B).
     * $05/$06 = UpdateGoriya (Wanderer + boomerang $5C try).
     * $07-$0A = UpdateOctorock (this file, native, step 6).
     * $2A     = UpdateStalfos (Wanderer + animate-and-draw + sword $57).
     *
     * Step 6 fixed $07 = RedSlowOctorock semantically (was reusing
     * enrt_update_rope which is actually $29). Step 7 wires the rest of
     * the walker family using already-drained UPDATE bodies in
     * src/oracle/enemies/{enemy_walker,enemy_wanderer}_runtime.c.
     *
     * NOTE: enrt_update_moblin is intentionally bare in the drain
     * (no anim/draw/collision tail) — NES UpdateMoblin tail-jumps to
     * _TryShooting which returns directly to the dispatch caller. The
     * NES dispatcher (UpdateObject) handles post-call animate/draw
     * centrally. Our enemy_loop_tick does not yet have a central
     * post-dispatch animate/draw, so moblin walks but does not draw
     * sprites until that hook lands (step 8 / next task).
     *
     * Future rows ($01/$02 lynel, $0B/$0C darknut, $29 rope) need new
     * drain bodies (no _runtime.c entry yet) and will land in step 8+. */
    [0x03] = enrt_update_moblin,    /* BlueMoblin (drained, anim/draw deferred) */
    [0x04] = enrt_update_moblin,    /* RedMoblin */
    [0x05] = enrt_update_goriya,    /* BlueGoriya (drained, full body) */
    [0x06] = enrt_update_goriya,    /* RedGoriya */
    [0x07] = enrt_update_octorock,  /* RedSlowOctorock (step 6 native) */
    [0x08] = enrt_update_octorock,  /* RedFastOctorock — color/qspeed branch in body */
    [0x09] = enrt_update_octorock,  /* BlueSlowOctorock */
    [0x0A] = enrt_update_octorock,  /* BlueFastOctorock */
    [0x2A] = enrt_update_stalfos,   /* Stalfos (drained, full body) */
};

/* Internal: clear an enemy slot's scratch state per NES room-init
 * (Z_05.asm:1684-1699 — the per-slot init loop run for slots $B..1
 * BEFORE InitObject_JumpTable[ObjType,X]).
 *
 * Step 10 finding: prior implementation zeroed WALK_SPEED / ANIM_TIMER
 * / METASTATE — wrong vs NES, which seeds defaults:
 *   ObjQSpeedFrac = $20  (Z_05.asm:1696 — DEFAULT speed)
 *   ObjAnimCounter = 1   (Z_05.asm:1694 — INC from 0)
 *   ObjMetastate   = 1   (Z_05.asm:1695 — INC from 0; "first cloud state")
 * Octorok/Darknut init wrappers explicitly override WALK_SPEED so they
 * are unaffected. Bare-InitWalker types ($01-$06,$2A) inherit the $20
 * default — that's what unblocks goriya/stalfos walking (their UPDATE
 * bodies don't re-seed WALK_SPEED; first quest stalfos UPDATE BEQs out
 * past the @SetSpeed branch entirely). */
static void clear_slot_scratch(unsigned int slot)
{
    ENEMY_DIR(slot)            = 0u;
    ENEMY_STATE_TIMER(slot)    = 0u;
    ENEMY_LIFE(slot)           = 0u;
    ENEMY_METASTATE(slot)      = 1u;          /* NES default: first cloud state */
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
    ENEMY_WALK_SPEED(slot)     = 0x20u;       /* NES Z_05.asm:1696 default */
    ENEMY_ANIM_TIMER(slot)     = 1u;          /* NES default INC from 0 */
    ENEMY_PUSH_DIR_SCRATCH(slot) = 0u;
    ENEMY_FLAP_PHASE(slot)     = 0u;
    ENEMY_FLYER_X_FINE(slot)   = 0u;
    ENEMY_STUN_TIMER(slot)     = 0u;          /* Z_05.asm:1693 ObjStunTimer */
    ENEMY_OBJ_SHOVE_DIR(slot)  = 0u;          /* ResetShoveInfo */
    OBJ(0x00D3u, slot)         = 0u;          /* ObjShoveDistance */
    ENEMY_MOVE_TIMER(slot)     = (unsigned char)slot;  /* InitObject preamble */
    ENEMY_ALIVE_FLAG(slot)     = 1u;          /* mark slot occupied */
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
    enemy_loop_force_spawn_typed(slot, 0x07u, x, y, dir);
}

void enemy_loop_force_spawn_typed(unsigned int slot,
                                  unsigned char enemy_type,
                                  unsigned char x,
                                  unsigned char y,
                                  unsigned char dir)
{
    /* Step 8 generic seed. Probe-side hook used to verify step-7
     * dispatch rows ($03/$04 moblin, $05/$06 goriya, $2A stalfos)
     * actually tick without crashing. Same shape as the octorok
     * seed: clear scratch, set type/x/y/dir, dispatch init row. */
    enemy_init_fn fn;
    if (slot < ENEMY_LOOP_SLOT_FIRST || slot > ENEMY_LOOP_SLOT_LAST) return;
    if (enemy_type >= ENEMY_LOOP_TYPE_MAX) return;

    ENEMY_TYPE(slot) = enemy_type;
    ENEMY_X(slot) = x;
    ENEMY_Y(slot) = y;
    clear_slot_scratch(slot);
    ENEMY_DIR(slot) = dir;

    fn = enemy_init_fns[enemy_type];
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
