/* Phase 7 Task 7.2 step 3 in-ROM probe — verifies enemy slot iterator
 * + INIT dispatch row $07 (slow octorok / ghini). See enemy_loop_probe.h
 * for block layout.
 *
 * Step-3 wiring: enemy_init_fns[$07] = enrt_init_slow_octorock_or_ghini.
 * After force_spawn the init body runs: enrt_octorock_common(slot, 32)
 * → sets WALK_SPEED, MOVE_TIMER, OBJ_STATE=0, DRAW_FRAME=0, ANIM_TIMER=6,
 * → enrt_init_walker(slot) computes DIR from LINK_X/LINK_Y vs OBJ_X/Y.
 *
 * Probe pre-sets LINK_X = LINK_Y = $80 so DIR computation is
 * deterministic (link == obj → h_dir = 2, ties resolve to h_dir).
 *
 * Probe publishes 14 (actual, expected) u16 pairs into
 * ENEMY_LOOP_PROBE_BASE. BizHawk reads the 68K RAM domain at offset
 * 0x7E00 to inspect.
 */

#include "enemy_loop_probe.h"
#include "../enemy_loop.h"
#include "../../../../RoomRom/src/roomrom_enemy_state.h"
#include "object_state.h"   /* OBJ_STATE for step-3 forwarder check */

static void put_u16_be(volatile unsigned char *p, unsigned short v)
{
    p[0] = (unsigned char)(v >> 8);
    p[1] = (unsigned char)(v & 0xFFu);
}

static void put_pair(volatile unsigned char *block, unsigned char idx,
                     unsigned short actual, unsigned short expected)
{
    volatile unsigned char *slot = &block[4u + (unsigned short)idx * 4u];
    put_u16_be(slot,     actual);
    put_u16_be(slot + 2, expected);
}

void enemy_loop_probe_run(void)
{
    volatile unsigned char *block =
        (volatile unsigned char *)ENEMY_LOOP_PROBE_BASE;
    unsigned int alive_before;
    unsigned int alive_after;

    /* Stage 1 — start clean. enemy_loop_room_init was called from
     * roomrom_debug_enter just before this probe; verify it cleared
     * slot state. */
    alive_before = enemy_loop_alive_count();

    /* Stage 2 — pin LINK position so the wired enrt_init_walker DIR
     * computation is deterministic. With LINK at the same cell as the
     * spawn target, h_dir=2 (link_x >= obj_x), v_dir=4, diff_x=diff_y=0,
     * tie resolves to ENEMY_SCRATCH_Y (= h_dir). Final DIR = 2. */
    LINK_X = 0x80u;
    LINK_Y = 0x80u;

    /* Stage 3 — deterministic seed. Slot 1, SlowOctorock at $80,$80.
     * Pre-init dir arg overwritten by enrt_init_walker — value here is
     * irrelevant after step-3 wiring. Kept at 0 for clear_slot_scratch
     * sequencing parity. */
    enemy_loop_force_spawn_slow_octorock(1u, 0x80u, 0x80u, 0u);

    /* Step 8 — seed slots 2/3/4 with moblin/goriya/stalfos to verify
     * step-7 dispatch rows tick. Spread X positions so collision
     * heuristics don't pin them. */
    enemy_loop_force_spawn_typed(2u, 0x03u, 0x40u, 0x60u, 0u); /* BlueMoblin */
    enemy_loop_force_spawn_typed(3u, 0x05u, 0x40u, 0xA0u, 0u); /* BlueGoriya */
    enemy_loop_force_spawn_typed(4u, 0x2Au, 0xC0u, 0x60u, 0u); /* Stalfos */

    alive_after = enemy_loop_alive_count();

    /* Header. */
    block[0] = 0x45u;                          /* 'E' */
    block[1] = 0x4Cu;                          /* 'L' */
    block[2] = (unsigned char)ENEMY_LOOP_PROBE_COUNT;
    block[3] = 0u;

    /* check[0]: alive_count was 0 after room_init (all slots cleared). */
    put_pair(block, 0, (unsigned short)alive_before, 0x0000u);

    /* check[1]: alive_count is 4 after step-8 force_spawn (octorok +
     * moblin + goriya + stalfos). */
    put_pair(block, 1, (unsigned short)alive_after, 0x0004u);

    /* check[2]: ENEMY_TYPE(1) == 0x07 (RedSlowOctorock). */
    put_pair(block, 2, (unsigned short)ENEMY_TYPE(1), 0x0007u);

    /* check[3]: ENEMY_X(1) == 0x80. */
    put_pair(block, 3, (unsigned short)ENEMY_X(1), 0x0080u);

    /* check[4]: ENEMY_Y(1) == 0x80. */
    put_pair(block, 4, (unsigned short)ENEMY_Y(1), 0x0080u);

    /* check[5]: ENEMY_DIR(1) == 2 — enrt_init_walker computes h_dir
     * (=2 since link_x>=obj_x) and the diff_y(0)<diff_x(0) tie resolves
     * to ENEMY_SCRATCH_Y which holds h_dir. Pre-step-3 expected $00. */
    put_pair(block, 5, (unsigned short)ENEMY_DIR(1), 0x0002u);

    /* check[6]: ENEMY_STATE_TIMER(1) == 0 — overlapping NES cell.
     * ENEMY_STATE_TIMER and OBJ_STATE both map to OBJ($AC,slot). NES
     * InitObject preamble stores slot index into $AC, then octorok
     * init's z07_reset_obj_state zeroes the same byte. Pre-step-3
     * expected $01 (no init was wired); post-step-3 the forwarder
     * fires and the cell ends at 0. */
    put_pair(block, 6, (unsigned short)ENEMY_STATE_TIMER(1), 0x0000u);

    /* check[7]: ENEMY_ALIVE_FLAG(1) == 1. */
    put_pair(block, 7, (unsigned short)ENEMY_ALIVE_FLAG(1), 0x0001u);

    /* check[8]: enemy_loop_get_type(1) == 0x07 (accessor agrees with
     * direct macro read). */
    put_pair(block, 8, (unsigned short)enemy_loop_get_type(1u), 0x0007u);

    /* check[9]: enemy_loop_get_type(2) == 0x03 (BlueMoblin seeded
     * step 8). Pre-step-8 expected 0 (slot empty). */
    put_pair(block, 9, (unsigned short)enemy_loop_get_type(2u), 0x0003u);

    /* Step-3 INIT-side checks. enrt_octorock_common(slot, 32) writes
     * these cells before delegating to enrt_init_walker. All four prove
     * the dispatch row $07 actually fired. */

    /* check[10]: ENEMY_WALK_SPEED(1) == 0x20 — speed arg passed
     * to enrt_octorock_common from enrt_init_slow_octorock_or_ghini. */
    put_pair(block, 10, (unsigned short)ENEMY_WALK_SPEED(1), 0x0020u);

    /* check[11]: ENEMY_MOVE_TIMER(1) == 0x20 — (slot+1)<<4 with slot=1
     * is 2<<4 = $20. NES seeds varied per slot to avoid tick-sync. */
    put_pair(block, 11, (unsigned short)ENEMY_MOVE_TIMER(1), 0x0020u);

    /* check[12]: ENEMY_ANIM_TIMER(1) == 6 — fixed cadence per
     * enrt_octorock_common. */
    put_pair(block, 12, (unsigned short)ENEMY_ANIM_TIMER(1), 0x0006u);

    /* check[13]: OBJ_STATE(1) == 0 — z07_reset_obj_state forwarder
     * dispatched to core_reset_obj_state and zeroed the cell. Proves
     * the forwarder linked + the drained body executed. */
    put_pair(block, 13, (unsigned short)OBJ_STATE(1), 0x0000u);

    /* Step 4 hand-off: move LINK far from the octorok before the
     * gameplay tick takes over. With both at $80,$80 the per-frame
     * c_check_monster_collisions call inside enrt_update_rope sees a
     * collision every tick — the NES collision body clears
     * ENEMY_TYPE(slot), the dispatch finds enemy_update_fns[0] = NULL,
     * and the slot freezes. Park LINK at $00,$00 (off-camera corner;
     * gameplay tick is debug-spawn idle so position is harmless) so the
     * trace probe can capture animation cadence. */
    LINK_X = 0u;
    LINK_Y = 0u;
}

/* Step 4 live-tick publisher. Called from end of enemy_loop_tick() so
 * Lua can sample slot 1 cell evolution per frame. Proves the UPDATE
 * chain (enrt_update_rope -> walker primitives) actually executes
 * even though no sprite is visible (oam_router NES OAM mirror -> SAT
 * router not yet built; tracked separately). */
/* Step 8 multi-slot publisher. Same call-site as the slot-1 publisher
 * (end of enemy_loop_tick), publishes 4 slots * 8 bytes at $FF7F80 so
 * step-8 probe can verify $03/$05/$2A dispatch rows actually tick.
 *
 * Static helper kept private — only the caller below uses it. */
static void publish_multi_slot(volatile unsigned char *base,
                               unsigned int probe_idx,
                               unsigned int slot)
{
    volatile unsigned char *p = &base[probe_idx * 8u];
    p[0] = (unsigned char)ENEMY_ALIVE_FLAG(slot);
    p[1] = (unsigned char)ENEMY_TYPE(slot);
    p[2] = (unsigned char)ENEMY_X(slot);
    p[3] = (unsigned char)ENEMY_Y(slot);
    p[4] = (unsigned char)ENEMY_DIR(slot);
    p[5] = (unsigned char)ENEMY_ANIM_TIMER(slot);
    p[6] = (unsigned char)ENEMY_DRAW_FRAME(slot);
    p[7] = (unsigned char)ENEMY_WALK_SPEED(slot);
}

void enemy_loop_probe_publish_live(void)
{
    volatile unsigned char *block =
        (volatile unsigned char *)ENEMY_LOOP_TICK_PROBE_BASE;
    volatile unsigned char *multi =
        (volatile unsigned char *)ENEMY_LOOP_MULTI_SLOT_BASE;
    static unsigned short frame_counter = 0u;
    frame_counter++;

    /* Step 8 multi-slot block. Slot 1 octorok ($07) + 2 moblin ($03) +
     * 3 goriya ($05) + 4 stalfos ($2A). */
    publish_multi_slot(multi, 0u, 1u);
    publish_multi_slot(multi, 1u, 2u);
    publish_multi_slot(multi, 2u, 3u);
    publish_multi_slot(multi, 3u, 4u);

    block[0]  = 0x54u;                                /* 'T' */
    block[1]  = 0x4Bu;                                /* 'K' */
    block[2]  = (unsigned char)(frame_counter >> 8);
    block[3]  = (unsigned char)(frame_counter & 0xFFu);
    block[4]  = (unsigned char)ENEMY_ALIVE_FLAG(1);
    block[5]  = (unsigned char)ENEMY_TYPE(1);
    block[6]  = (unsigned char)ENEMY_X(1);
    block[7]  = (unsigned char)ENEMY_Y(1);
    block[8]  = (unsigned char)ENEMY_DIR(1);
    block[9]  = (unsigned char)ENEMY_ANIM_TIMER(1);
    block[10] = (unsigned char)ENEMY_DRAW_FRAME(1);
    block[11] = (unsigned char)ENEMY_MOVE_TIMER(1);
    block[12] = (unsigned char)ENEMY_STATE_TIMER(1);
    block[13] = (unsigned char)ENEMY_WALK_SPEED(1);
    block[14] = (unsigned char)LINK_X;
    block[15] = (unsigned char)LINK_Y;
}

void enemy_loop_probe_publish_pre(void)
{
    volatile unsigned char *block =
        (volatile unsigned char *)ENEMY_LOOP_TICK_PRE_PROBE_BASE;
    /* Raw absolute pointer to the byte ENEMY_TYPE(1) maps to.
     * Debug.md A4 = $FF8000 (set by src/debug/a4_probe_asm.s entry).
     * NES OBJ_TYPE+1 offset = $034F + 1 = $0350 → physical $FF8350.
     * Bypasses the A4-pinned `nes_ram` register binding to confirm the
     * macro path and the absolute path agree. */
    volatile unsigned char *raw_type1 =
        (volatile unsigned char *)0x00FF8350UL;
    static unsigned short pre_counter = 0u;
    pre_counter++;

    block[0]  = 0x50u;                                /* 'P' */
    block[1]  = 0x52u;                                /* 'R' */
    block[2]  = (unsigned char)(pre_counter >> 8);
    block[3]  = (unsigned char)(pre_counter & 0xFFu);
    block[4]  = (unsigned char)ENEMY_ALIVE_FLAG(1);
    block[5]  = (unsigned char)ENEMY_TYPE(1);
    block[6]  = (unsigned char)ENEMY_X(1);
    block[7]  = (unsigned char)ENEMY_Y(1);
    block[8]  = (unsigned char)ENEMY_DIR(1);
    block[9]  = (unsigned char)ENEMY_ANIM_TIMER(1);
    block[10] = (unsigned char)ENEMY_DRAW_FRAME(1);
    block[11] = (unsigned char)ENEMY_MOVE_TIMER(1);
    block[12] = (unsigned char)ENEMY_STATE_TIMER(1);
    block[13] = (unsigned char)ENEMY_WALK_SPEED(1);
    block[14] = (unsigned char)LINK_X;
    block[15] = (unsigned char)LINK_Y;
    /* [16] raw byte at $FF0350 (what ENEMY_TYPE(1) should read).
     * If raw == $07 but block[5] (ENEMY_TYPE via A4) == $00, A4 is
     * broken. If both $00, the cell genuinely got cleared. */
    block[16] = *raw_type1;
}
