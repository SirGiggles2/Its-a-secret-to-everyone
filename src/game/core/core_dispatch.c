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
#include "sprite_state.h"      /* OAM_BYTE */
#include "progress_state.h"    /* SUBMODE_VALUE, PROG_ITEMS_BY_LEVEL */
#include "combat_state.h"      /* LINK_HEARTS */

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

void core_init_one_simple_object(unsigned int slot)
{
    /* drain at core_runtime.c:36-40. NES InitOneSimpleObject:
     *   $00 holds object type, $01 holds status flag byte. */
    OBJ_TYPE(slot)     = (uint8_t)RAM(0x0000u);
    RAM(0x0492 + slot) = 0u;
    RAM(0x04BF + slot) = (uint8_t)RAM(0x0001u);
}

void core_set_up_whirlwind(unsigned int slot)
{
    /* drain at core_runtime.c:64-68. NES SetUpWhirlwind:
     *   OBJ_TILE_Y(slot) = OBJ_TILE_Y(0)  -- copy Link's tile Y
     *   OBJ_TILE_X(slot) = 0
     *   OBJ_TYPE(slot)   = 46             -- whirlwind type. */
    OBJ_TILE_Y(slot) = (uint8_t)OBJ_TILE_Y(0);
    OBJ_TILE_X(slot) = 0u;
    OBJ_TYPE(slot)   = 46u;
}

void core_init_whirlwind(unsigned int val, unsigned int slot)
{
    /* drain at core_runtime.c:174-177. */
    OBJ_TILE_Y(0) = (uint8_t)val;
    core_set_up_whirlwind(slot);
}

unsigned char core_anim_set_sprite_desc_attrs(unsigned int val)
{
    /* drain at core_runtime.c:101-105. */
    RAM(0x0004u) = (uint8_t)val;
    RAM(0x0005u) = (uint8_t)val;
    return (uint8_t)val;
}

void core_set_item_value(unsigned int val, unsigned int slot3)
{
    /* drain at core_runtime.c:170-172. */
    PROG_ITEMS_BY_LEVEL(slot3) = (uint8_t)val;
}

unsigned int core_get_opposite_dir(unsigned int dir)
{
    /* drain at core_runtime.c:202-217. NES GetOppositeDir. */
    static const unsigned char opposite_dirs[] = { 0x04u, 0x08u, 0x01u, 0x02u };
    unsigned char d = (unsigned char)dir;
    signed char idx = 3;
    while (idx >= 0) {
        if (d & 1u) {
            break;
        }
        d = (unsigned char)(d >> 1);
        idx--;
    }
    if (idx < 0) {
        idx = 0;
    }
    return ((unsigned int)(unsigned char)idx << 8) |
           (unsigned int)opposite_dirs[(unsigned char)idx];
}

unsigned char core_negate(unsigned int val)
{
    /* drain at core_runtime.c:224-227. NES Negate (2's complement). */
    const unsigned char v = (unsigned char)val;
    return (unsigned char)((~v + 1u) & 0xFFu);
}

void core_begin_update_mode(void)
{
    /* drain at core_runtime.c:155-158. */
    SUBMODE_VALUE = 0u;
    RAM(0x0011) = (uint8_t)(RAM(0x0011) + 1u);  /* ROOM_MODE_TIMER */
}

void core_play_effect(unsigned int val)
{
    /* drain at core_runtime.c:229-231. */
    RAM(0x0603) = (uint8_t)(RAM(0x0603) | (uint8_t)val);  /* ROOM_SFX_AUX */
}

void core_play_sample(unsigned int val)
{
    /* drain at core_runtime.c:233+. */
    RAM(0x0601) = (uint8_t)(RAM(0x0601) | (uint8_t)val);
}

unsigned char core_compare_hearts_to_containers(void)
{
    /* drain at core_runtime.c:260-262. NES CompareHeartsToContainers. */
    return (uint8_t)(LINK_HEARTS >> 4);
}

void core_format_char_doublet(unsigned int val)
{
    /* drain at core_runtime.c:272-275. NES FormatCharDoublet. */
    RAM(0x0002u) = (uint8_t)val;
    RAM(0x0003u) = 36u;
}

unsigned char core_reset_cur_sprite_index(void)
{
    /* drain at core_runtime.c:277-280. NES ResetCurSpriteIndex. */
    RAM(0x0341u) = 0u;
    return 0u;
}

void core_uw_person_complex_state_begin(void)
{
    /* drain at core_runtime.c:264-270. NES UWPersonComplexStateBegin.
     * RAM($0029) = ObjTimer+1 (drain comment says CAVE_DELAY_TIMER alias). */
    if (RAM(0x0350u) == 0x4Fu) {  /* ROOM_OBJ_TYPE(0) */
        ROOM_TRANSFER_BUF_SELECT = 108u;
    }
    RAM(0x0029u) = 10u;
    OBJ_STATE(1) = (uint8_t)(OBJ_STATE(1) + 1u);
}

void core_play_boomerang_sfx(unsigned int sfx_id)
{
    /* drain at core_runtime.c:282-288. NES PlayBoomerangSfx. */
    if (RAM(0x003Bu) != 0u) {
        return;
    }
    core_play_effect(sfx_id);
    RAM(0x003Bu) = 10u;
}

void core_play_character_sfx(void)
{
    /* drain at core_runtime.c:9-11. */
    DEATH_FRAME_COUNTER = 8u;
}

void core_play_key_taken_tune(void)
{
    /* drain at core_runtime.c:13-16. */
    DEATH_FRAME_COUNTER = 0u;
    RAM(0x0604u) = 8u;  /* ROOM_SFX_MAIN */
}

void core_play_parry_tune(void)
{
    /* drain at core_runtime.c:237-239. */
    RAM(0x0604u) = 1u;  /* ROOM_SFX_MAIN */
}

unsigned char core_silence_all_sound(void)
{
    /* drain at core_runtime.c:24-30. */
    RAM(0x0604u) = 0x80u;  /* ROOM_SFX_MAIN */
    RAM(0x0603u) = 0x80u;  /* ROOM_SFX_AUX */
    RAM(0x0605u) = 0u;
    RAM(0x0607u) = 0u;
    return 0u;
}

void core_take_power_triforce(void)
{
    /* drain at core_runtime.c:18-22. */
    RAM(0x0509u) = (uint8_t)(RAM(0x0509u) + 1u);  /* POWER_TRIFORCE_FANFARE_FLAG */
    RAM(0x0028u) = 0xC0u;
    OBJ_STATE(0) = 64u;
}

void core_write_blank_priority_sprites(void)
{
    /* drain at core_runtime.c:241-247. NES WriteBlankPrioritySprites.
     * 8-byte template repeated 8 times = 64 OAM bytes (16 sprites). */
    static const unsigned char tmpl[8] = {
        0x3Du, 0x1Cu, 0x20u, 0x00u, 0xDDu, 0x1Cu, 0x20u, 0x00u
    };
    for (unsigned char i = 0u; i < 0x40u; i++) {
        OAM_BYTE(i) = tmpl[i & 7u];
    }
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
