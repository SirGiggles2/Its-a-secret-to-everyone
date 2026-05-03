/* core_dispatch.c — native core subsystem dispatch (Phase 4 cross-cut).
 *
 * Phase 4 first core batch: trivial helpers that unblock Phase 3 cave
 * deferred stubs. Drain MATCH per finding 4_6n. Pure C, no shims.
 */

#include "core_dispatch.h"
#include "platform_abi.h"      /* RAM, OBJ */
#include "object_state.h"      /* OBJ_STATE */
#include "room_state.h"        /* ROOM_TRANSFER_BUF_SELECT */
#include "link_state.h"        /* DEATH_FRAME_COUNTER */
#include "object_state.h"      /* OBJ_TILE_X/_Y, OBJ_STATE, OBJ_TYPE, OBJ_SHOVE_DIR/DIST, OBJ_INV_TIMER, OBJ_METASTATE */

void core_unhalt_link(void)
{
    /* drain at core_runtime.c:56-58. NES UnhaltLink (Z_01.asm:100):
     *   LDA #$00 / STA ObjState  -- ObjState = $00AC = OBJ_STATE(0). */
    OBJ_STATE(0) = 0u;
}

void core_inc_cave_state(void)
{
    /* drain at core_runtime.c:60-62. NES IncCaveState:
     *   INC ObjState+1  -- ObjState+1 = $00AD = OBJ_STATE(1) = CAVE_PERSON_STATE. */
    OBJ_STATE(1) = (uint8_t)(OBJ_STATE(1) + 1u);
}

void core_cue_transfer_buf_and_advance_state(unsigned int val)
{
    /* drain at core_runtime.c:160-163. NES CueTransferBufAndAdvanceState:
     *   STA TileBufSelector ($14 = ROOM_TRANSFER_BUF_SELECT)
     *   INC ObjState+1 (= core_inc_cave_state).
     */
    ROOM_TRANSFER_BUF_SELECT = (unsigned char)val;
    core_inc_cave_state();
}

unsigned char core_abs(unsigned int val)
{
    /* drain at core_runtime.c:219+. NES Abs: 6502 absolute value of a
     * signed byte. */
    const signed char s = (signed char)(unsigned char)val;
    return (unsigned char)((s < 0) ? -s : s);
}

void core_post_debit(unsigned int amount)
{
    /* drain at core_runtime.c:32-34. NES PostDebit: lazy deferred
     * rupee debit accumulator at $067E. HUD tick decrements rupees
     * by 1/frame against this accumulator. */
    RAM(0x067E) = (unsigned char)(RAM(0x067E) + (unsigned char)amount);
}

void core_post_credit(unsigned int val)
{
    /* drain at core_runtime.c:107-109. NES PostCredit: lazy deferred
     * rupee credit accumulator at $067D. HUD tick increments rupees
     * by 1/frame against this accumulator. */
    RAM(0x067D) = (unsigned char)(RAM(0x067D) + (unsigned char)val);
}

void core_take_one_rupee(void)
{
    /* drain at core_runtime.c:165-168. NES TakeOneRupee:
     *   LDA #$01 / STA DEATH_FRAME_COUNTER  -- HUD anim trigger
     *   INC RAM($067D)                       -- credit accumulator++ */
    DEATH_FRAME_COUNTER = 1u;
    RAM(0x067D) = (uint8_t)(RAM(0x067D) + 1u);
}

void core_take_5_rupees(void)
{
    /* drain at core_runtime.c:195-200. NES Take5Rupees: loop
     * TakeOneRupee 5 times. */
    for (signed char i = 4; i >= 0; i--) {
        core_take_one_rupee();
    }
}

void core_cue_transfer_blank_person_wares(void)
{
    /* drain at core_runtime.c:191-193. NES UpdatePersonState_CueTransferBlankPersonWares:
     *   LDA #$2A / JMP CueTransferBufAndAdvanceState  -- selector 42 + state++ */
    core_cue_transfer_buf_and_advance_state(42u);
}

void core_destroy_object_wram(unsigned int val, unsigned int slot)
{
    /* drain at core_runtime.c:42-50. NES DestroyObjectWram. */
    OBJ_SHOVE_DIR(slot)  = (uint8_t)val;
    OBJ_SHOVE_DIST(slot) = (uint8_t)val;
    RAM(0x0028 + slot)   = (uint8_t)val;  /* ObjTimer+slot */
    OBJ_STATE(slot)      = (uint8_t)val;
    OBJ_INV_TIMER(slot)  = (uint8_t)val;
    RAM(0x0492 + slot)   = 0xFFu;
    OBJ_METASTATE(slot)  = 1u;
}

void core_destroy_whirlwind(unsigned int slot)
{
    /* drain at core_runtime.c:52-54. NES DestroyWhirlwind. */
    core_destroy_object_wram(0u, slot);
}

void core_destroy_monster(unsigned int slot)
{
    /* drain at core_runtime.c:374. NES DestroyMonster. */
    OBJ_TYPE(slot) = 0u;
    core_destroy_object_wram(0u, slot);
}

void core_set_up_common_cave_objects(unsigned int x, unsigned int slot,
                                     unsigned int y)
{
    /* drain at core_runtime.c:87-99. NES SetUpCommonCaveObjects (Z_01.asm).
     * Seeds the cave's 3 object slots (slot, slot+1, slot+2) with
     * tile-grid coords + walk frame state. */
    OBJ_TILE_X(slot) = (uint8_t)x;
    OBJ_TILE_Y(slot) = (uint8_t)y;
    RAM(0x0485 + slot) = 0u;
    RAM(0x04BF + slot) = 0x81u;
    OBJ_STATE(0) = 64u;
    /* ROOM_OBJ_TYPE(slot) = RAM($0350 + slot). For NES InitCave path,
     * slots 1 and 2 are filled with type 64. */
    RAM(0x0350 + 1u) = 64u;
    RAM(0x0350 + 2u) = 64u;
    RAM(0x0071 + slot) = 72u;
    RAM(0x0072 + slot) = 0xA8u;
    RAM(0x0085 + slot) = (uint8_t)y;
    RAM(0x0086 + slot) = (uint8_t)y;
}
