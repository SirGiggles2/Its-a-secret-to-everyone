/* enemy_flyer_bridge.c -- Phase 7 Task 7.3 step 3 flyer UPDATE
 * primitives bridge.
 *
 * Per Task 7.2 step 4/5 walker bridge precedent + Drain Rule D1
 * (drain primary, NES asm secondary tiebreaker):
 *
 *   - Directions8                       — NATIVE const drain (NES
 *                                         Z_04.asm:11540).
 *   - c_move_flyer                      — forwards to enrt_move_flyer
 *                                         (already drained at
 *                                         enemy_flyer_runtime.c:175).
 *   - c_control_keese_flight            — NATIVE state-table dispatch
 *                                         (NES Z_04.asm:1201). 6-row
 *                                         ControlKeeseFlight_JumpTable;
 *                                         rows 0/1/4/5 forward to
 *                                         already-drained leaves; rows
 *                                         2/3 (Flyer_Chase /
 *                                         Flyer_Wander) NATIVE drain
 *                                         from NES Z_04.asm:11707 / 11844.
 *   - c_reset_shove_info                — NATIVE 2-cell zero (NES
 *                                         Z_07.asm:2333).
 *   - c_draw_object_mirrored_with_frame — forwards to native
 *                                         draw_object_mirrored_with_frame
 *                                         (world/draw_dispatch.c:421).
 *
 * Hard rule WT-5: lives at src/game/enemies/, not RoomRom/.
 *
 * Primitives consumed by the keese chain (enrt_update_keese,
 * enrt_init_blue_keese, enrt_init_red_or_black_keese in
 * src/oracle/enemies/enemy_flyer_runtime.c). With these resolved the
 * Task 7.3 step 3 dispatch rows for $1B/$1C/$1D can wire without
 * pulling unresolved symbols past --gc-sections.
 */

#include "platform_abi.h"               /* RAM, OBJ */
#include "enemy_state.h"                /* ENEMY_*, LINK_X/Y aliases */
#include "world/draw_dispatch.h"        /* draw_object_mirrored_with_frame */

/* Drained leaves in src/oracle/enemies/enemy_flyer_runtime.c. */
extern void enrt_move_flyer(unsigned int slot);
extern void enrt_flyer_speed_up(unsigned int slot);
extern void enrt_flyer_slow_down(unsigned int slot);
extern void enrt_flyer_keese_decide_state(unsigned int slot);
extern void enrt_flyer_delay(unsigned int slot);

/* z04_*: c_shims.asm xrefs that forward to transpiled NES bodies in
 * z_04.asm. Debug.md does not link the transpiled bank, so these
 * symbols must resolve via native equivalents. All three NES bodies
 * already have drained C twins, but the oracle TU calls the z04_*
 * names — re-export the drained bodies under those names here. */
void z04_flyer_set_flying_state(unsigned int val, unsigned int slot);
void z04_flyer_compare_max_speed(unsigned char speed, unsigned int slot);
void z04_flyer_set_state_and_turns(unsigned int state, unsigned int slot);

/* NES Z_04.asm:11540 Directions8. 8-way unit-direction table.
 * Indexed 0..7 by Flyer_Chase / Flyer_Wander turn logic. Bit layout
 * follows NES ObjDir convention: $01=right, $02=left, $04=down,
 * $08=up; combined diagonals { $05, $06, $09, $0A }. */
const unsigned char Directions8[8] = {
    0x08u, 0x09u, 0x01u, 0x05u, 0x04u, 0x06u, 0x02u, 0x0Au
};

void c_move_flyer(unsigned int slot)
{
    /* enrt_move_flyer is the drained body of NES MoveFlyer
     * (Z_04.asm:11590). Forwarder isolates the c_-named ABI shim from
     * the oracle TU's enrt_-named drain so dispatch rows can pull
     * either name without symbol churn. */
    enrt_move_flyer(slot);
}

/* NES Z_04.asm:11579 Flyer_SetFlyingState. One-line drain mirroring
 * enrt_flyer_set_flying_state (flyer_runtime.c:147). */
void z04_flyer_set_flying_state(unsigned int val, unsigned int slot)
{
    ENEMY_AI_STATE(slot) = (unsigned char)val;
}

/* NES Z_04.asm:11584 Flyer_CompareMaxSpeed. Mirrors
 * enrt_flyer_compare_max_speed (flyer_runtime.c:70). */
void z04_flyer_compare_max_speed(unsigned char speed, unsigned int slot)
{
    if (speed < (unsigned char)ENEMY_MAX_AIR_SPEED) {
        return;
    }
    z04_flyer_set_flying_state(1u, slot);
}

/* NES Z_04.asm:11228 Flyer_SetStateAndTurns. Mirrors native
 * enemy_flyer_set_state_and_turns (enemy_dispatch.c:104), but with
 * matching signature for the c_shims-style call site in
 * enrt_flyer_keese_decide_state (sets ENEMY_TURN_TIMER = 6). */
void z04_flyer_set_state_and_turns(unsigned int state, unsigned int slot)
{
    ENEMY_AI_STATE(slot)   = (unsigned char)state;
    ENEMY_TURN_TIMER(slot) = 6u;
}

void c_reset_shove_info(unsigned int slot)
{
    /* NES Z_07.asm:2333 ResetShoveInfo. Two-cell zero — clears
     * ObjShoveDir ($00C0) + ObjShoveDistance ($00D3). Falls through
     * to SetShoveInfoWith0 in NES; same observable. */
    ENEMY_OBJ_SHOVE_DIR(slot) = 0u;
    OBJ(0x00D3u, slot)        = 0u;
}

void c_draw_object_mirrored_with_frame(unsigned int frame, unsigned int slot)
{
    draw_object_mirrored_with_frame((unsigned char)frame, slot);
}

/* NES Z_04.asm:11883 GetObjDir8Index. Find slot's ENEMY_DIR in
 * Directions8 by scanning index 7 -> 0. NES uses BPL after DEY which
 * exits at -1 (Y=$FF) with no fallthrough store; the trailing $C8
 * (INY) sets Y back to 0 — equivalent to "default 0". */
static unsigned char flyer_get_obj_dir8_index(unsigned int slot)
{
    const unsigned char d = (unsigned char)ENEMY_DIR(slot);
    for (signed char y = 7; y >= 0; --y) {
        if (Directions8[y] == d) {
            return (unsigned char)y;
        }
    }
    return 0u;
}

/* NES Z_04.asm:11707 Flyer_Chase. Turn towards player a number of
 * times; after Flyer_ObjTurns (ENEMY_TURN_TIMER) hits 0, go to flying
 * state 1 via Flyer_SetFlyingState. Each turn delays $10 frames in
 * ObjTimer (ENEMY_MOVE_TIMER).
 *
 * TurnTowardsPlayer8 builds a target direction in [00] from
 * ChaseTargetX/Y vs ObjX/Y, then performs:
 *
 *   - LoopLeft: scan 3 indices (idx+1, idx, idx-1). On exact target
 *     match, leave ObjDir untouched (already aiming the right way).
 *   - LoopRight: scan 3 indices (idx-1, idx, idx+1). For each:
 *       * BIT (Directions8[y] & target) — must share a component.
 *       * TestDir: (Directions8[y] | target) < 7 — accept (turn).
 *         Else NextLoopRight (try next index).
 *   - Default fallback (no acceptable turn): use Directions8[idx+1].
 */
static void flyer_chase(unsigned int slot)
{
    if ((unsigned char)ENEMY_MOVE_TIMER(slot) != 0u) {
        return;
    }

    /* Decrement turn counter; on zero -> SetFlyingState1. */
    {
        unsigned char turns = (unsigned char)(ENEMY_TURN_TIMER(slot) - 1u);
        ENEMY_TURN_TIMER(slot) = turns;
        if (turns == 0u) {
            z04_flyer_set_flying_state(1u, slot);
            return;
        }
    }

    /* SetDelayAndTurn: $10-frame delay. */
    ENEMY_MOVE_TIMER(slot) = 0x10u;

    /* TurnTowardsPlayer8: build target direction.
     * ChaseTargetX/Y live at NES $0061/$0062 (ENEMY_PLAYER_OBJ_X aliases
     * are $0070/$0084, NOT chase target — distinct cells). Use raw RAM
     * read so behavior mirrors NES exactly. */
    unsigned char target = 0u;
    {
        unsigned char lx = (unsigned char)RAM(0x0061u);
        unsigned char ox = (unsigned char)ENEMY_X(slot);
        if (lx > ox) {
            target = 1u;            /* right */
        } else if (lx < ox) {
            target = 2u;            /* left */
        }
    }
    {
        unsigned char ly = (unsigned char)RAM(0x0062u);
        unsigned char oy = (unsigned char)ENEMY_Y(slot);
        if (ly != oy) {
            /* NES: BCS branch -> Y stays 1 -> down ($04); fall-through
             * INY -> Y=2 -> up ($08). After two ASLs Y becomes Y*4. */
            unsigned char vbits = (ly < oy) ? 0x08u : 0x04u;
            target = (unsigned char)(target | vbits);
        }
    }

    const unsigned int idx = (unsigned int)flyer_get_obj_dir8_index(slot);

    /* LoopLeft: 3 iterations from y=idx+1, decrementing. Exact-match
     * exit means current ObjDir already aims at target — return as-is. */
    {
        unsigned int y = (idx + 1u) & 7u;
        for (int n = 0; n < 3; ++n) {
            if (Directions8[y] == target) {
                return;
            }
            y = (y - 1u) & 7u;
        }
    }

    /* LoopRight: 3 iterations from y=idx-1, incrementing. */
    {
        unsigned int y = (idx + 7u) & 7u;       /* idx-1 mod 8 */
        for (int n = 0; n < 3; ++n) {
            const unsigned char dir = Directions8[y];
            if ((dir & target) != 0u) {
                /* TestDir: (dir | target) < 7 -> accept this index. */
                if ((unsigned int)(dir | target) < 7u) {
                    ENEMY_DIR(slot) = dir;
                    return;
                }
                /* else fall through to NextLoopRight (try next). */
            }
            y = (y + 1u) & 7u;
        }
    }

    /* Default fallback — NES DEY after 3 INYs from idx-1 lands at
     * idx+1. SetDir8ForIndex stores Directions8[idx+1] into ObjDir. */
    {
        const unsigned int chosen = (idx + 1u) & 7u;
        ENEMY_DIR(slot) = Directions8[chosen];
    }
}

/* NES Z_04.asm:11844 Flyer_Wander. Same delay/turn-counter shape as
 * Flyer_Chase, but new direction is randomly turned left/right/none
 * via Random+1, X (ENEMY_RNG_B). */
static void flyer_wander(unsigned int slot)
{
    if ((unsigned char)ENEMY_MOVE_TIMER(slot) != 0u) {
        return;
    }

    {
        unsigned char turns = (unsigned char)(ENEMY_TURN_TIMER(slot) - 1u);
        ENEMY_TURN_TIMER(slot) = turns;
        if (turns == 0u) {
            z04_flyer_set_flying_state(1u, slot);
            return;
        }
    }

    ENEMY_MOVE_TIMER(slot) = 0x10u;

    /* TurnRandomlyDir8: idx-relative turn keyed off RNG. */
    unsigned int idx = (unsigned int)flyer_get_obj_dir8_index(slot);
    const unsigned char rnd = (unsigned char)ENEMY_RNG_B(slot);

    if (rnd >= 0xA0u) {
        /* don't turn */
    } else if (rnd >= 0x50u) {
        idx = (idx + 1u) & 7u;       /* turn right */
    } else {
        idx = (idx + 7u) & 7u;       /* turn left (idx-1 mod 8) */
    }
    ENEMY_DIR(slot) = Directions8[idx];
}

/* NES Z_04.asm:1201 ControlKeeseFlight. 6-row jump table:
 *   0: Flyer_SpeedUp           (drained: enrt_flyer_speed_up)
 *   1: Flyer_KeeseDecideState  (drained: enrt_flyer_keese_decide_state)
 *   2: Flyer_Chase             (NATIVE: this file)
 *   3: Flyer_Wander            (NATIVE: this file)
 *   4: Flyer_SlowDown          (drained: enrt_flyer_slow_down)
 *   5: Flyer_Delay             (drained: enrt_flyer_delay)
 *
 * NES TableJump out-of-range = undefined. Default branch is no-op
 * (matches transpile's safe-table default). */
void c_control_keese_flight(unsigned int slot)
{
    const unsigned char state = (unsigned char)ENEMY_AI_STATE(slot);
    switch (state) {
    case 0u: enrt_flyer_speed_up(slot);          break;
    case 1u: enrt_flyer_keese_decide_state(slot); break;
    case 2u: flyer_chase(slot);                  break;
    case 3u: flyer_wander(slot);                 break;
    case 4u: enrt_flyer_slow_down(slot);         break;
    case 5u: enrt_flyer_delay(slot);             break;
    default: break;
    }
}
