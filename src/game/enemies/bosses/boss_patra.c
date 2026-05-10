/* Phase 8 Task 8.8 — Patra bridge.
 *
 * NES source: Z_04.asm:10070 UpdatePatra + Z_04.asm:10124 ControlPatraFlight.
 * Drained C:  src/oracle/enemies/enemy_patra_runtime.c (helpers + child).
 * Coverage:   FULL — UpdatePatra body composed from already-drained
 *             flyer primitives (enrt_flyer_speed_up,
 *             enrt_flyer_patra_decide_state, c_move_flyer,
 *             enrt_animate_and_draw_common_object) plus the keese-flight
 *             bridge for states 2/3 (matches Z_04.asm:10130 / 10131).
 *             TryChangeManeuver flip mirrors the NES quirk
 *             (PatraManeuverTime[D3] OOB) but bounded with kPatraManeuverTime
 *             so non-debug paths produce $FF (ManeuverTime[0]).
 * Stance:     ADOPT — orchestrator only.
 */

#include "boss_patra.h"
#include "platform_abi.h"
#include "enemy_state.h"

extern void c_control_keese_flight(unsigned int slot);
extern void c_move_flyer(unsigned int slot);
extern void c_check_link_collision(unsigned int slot);
extern void c_check_monster_collisions(unsigned int slot);
extern void c_play_boss_hit_cry_if_needed(unsigned int slot);
extern void enrt_flyer_speed_up(unsigned int slot);
extern void enrt_flyer_patra_decide_state(unsigned int slot);
extern void enrt_animate_and_draw_common_object(unsigned int val, unsigned int slot);
extern void enrt_play_boss_death_cry_if_needed(unsigned int slot);

/* PatraManeuverTime (NES Z_04.asm:10064): { $FF, $50 } followed by an
 * "Unknown block" $50 byte. NES asm reads PatraManeuverTime[D3] where D3
 * is whatever the @LoopChildren register held when the loop fell through
 * (D3=0 on the no-children path; D3 in 1..8 on the with-children path).
 * D3 > 1 is OOB into bank-4 ROM. We mirror with a small lookup that
 * returns the canonical $FF for D3=0 (the typical first-frame trigger)
 * and $50 for D3=1, with zero fill above to keep the OOB-quirk
 * deterministic. */
static const unsigned char kPatraManeuverTime[10] = {
    0xFFu, 0x50u, 0x00u, 0x00u, 0x00u,
    0x00u, 0x00u, 0x00u, 0x00u, 0x00u
};

/* ControlPatraFlight (NES Z_04.asm:10124).
 *   FlyingState JT:
 *     0: Flyer_SpeedUp                     (drained as enrt_flyer_speed_up)
 *     1: Flyer_PatraDecideState            (drained as enrt_flyer_patra_decide_state)
 *     2: Flyer_Chase   ─┐
 *     3: Flyer_Wander  ─┘  reused via the keese-flight bridge
 *                          (states 2/3 expose Chase/Wander identically).
 */
static void control_patra_flight(unsigned int slot)
{
    const unsigned char st = ENEMY_AI_STATE(slot);
    switch ((unsigned int)(st & 0x03u)) {
    case 0u: enrt_flyer_speed_up(slot);             break;
    case 1u: enrt_flyer_patra_decide_state(slot);   break;
    case 2u:
    case 3u:
        c_control_keese_flight(slot);
        break;
    default: break;
    }
}

/* UpdatePatra (NES Z_04.asm:10070). */
void boss_patra_update(unsigned int slot)
{
    unsigned int found_d3 = 0u;

    control_patra_flight(slot);

    /* Reset flying distance traveled. NES writes 0 to Flyer_ObjOffsetX,X
     * and Flyer_ObjOffsetY,X so children can read this slot's last-frame
     * delta in PatraChild_State1. */
    ENEMY_FLYER_OFFSET_X(slot) = 0u;
    ENEMY_FLYER_OFFSET_Y(slot) = 0u;

    c_move_flyer(slot);
    enrt_animate_and_draw_common_object(2u, slot);

    /* @LoopChildren — scan slots 9..2 for a live patra child.
     * NES uses LDY #$08 / LDA ObjType+1, Y → reads ObjType[Y+1] for Y=8..1. */
    {
        unsigned int y;
        for (y = 8u; y != 0u; --y) {
            const unsigned char t = (unsigned char)OBJ(NES_OBJ_TYPE, y + 1u);
            if (t == 0x25u || t == 0x26u) {
                found_d3 = y;
                break;
            }
        }
    }

    if (found_d3 != 0u) {
        /* Children alive — Link can be hurt, but Patra cannot. */
        c_check_link_collision(slot);
    } else {
        /* No children — Link can damage Patra. */
        c_check_monster_collisions(slot);
        c_play_boss_hit_cry_if_needed(slot);
        enrt_play_boss_death_cry_if_needed(slot);
    }

    /* @TryChangeManeuver: if maneuver-timer hit 0 AND child-2's whole-angle
     * crossed 0, flip the maneuver index and reload the timer from
     * PatraManeuverTime[D3]. */
    {
        const unsigned char timer = ENEMY_OBJ_TIMER_HI(slot);
        const unsigned char angle_w_3 = (unsigned char)nes_ram[0x0394u + 3u];
        if ((unsigned char)(timer | angle_w_3) == 0u) {
            ENEMY_PATRA_MANEUVER_INDEX(slot) ^= 0x01u;
            ENEMY_OBJ_TIMER_HI(slot) =
                kPatraManeuverTime[found_d3 < 10u ? found_d3 : 0u];
        }
    }
}
