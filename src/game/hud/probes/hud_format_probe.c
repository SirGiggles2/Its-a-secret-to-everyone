/* Phase 9 Task 9.5 — HUD format probe (in-ROM tests). */

#include "hud_format_probe.h"
#include "../hud_dispatch.h"
#include "platform_abi.h"
#include "world_state.h"     /* TRANSFER_BUF_BYTE */
#include "combat_state.h"    /* LINK_HEARTS, LINK_PARTIAL_HEART */

#define PROBE  ((volatile unsigned char *)HUD_FORMAT_PROBE_BASE)

#define TILE_SPC   0x24u
#define TILE_FULL  0xF2u
#define TILE_EMP   0x66u   /* 102 */
#define TILE_HALF  0x65u   /* 101 */

static void stamp_magic(void)
{
    unsigned int i;
    PROBE[0] = 'H';
    PROBE[1] = 'F';
    PROBE[2] = 0x01u;
    for (i = 3u; i < 16u; ++i) PROBE[i] = 0u;
}

static unsigned char buf_eq(unsigned char start, const unsigned char *expect,
                            unsigned char count)
{
    unsigned char i;
    for (i = 0u; i < count; ++i) {
        if ((unsigned char)TRANSFER_BUF_BYTE((unsigned char)(start + i))
            != expect[i]) {
            return 0u;
        }
    }
    return 1u;
}

static void format_with(unsigned char hearts, unsigned char partial)
{
    LINK_HEARTS = hearts;
    LINK_PARTIAL_HEART = partial;
    /* hud_format_status_bar_text re-reads LINK_HEARTS / LINK_PARTIAL_HEART
     * into RAM(0x000E/000F) before formatting. */
    hud_format_status_bar_text();
}

/* ---- T0: template integrity ---------------------------------------- */
static unsigned char test_template_loaded(void)
{
    format_with(0x33u, 0u);
    return ((unsigned char)TRANSFER_BUF_BYTE(0u)  == 0x20u
         && (unsigned char)TRANSFER_BUF_BYTE(1u)  == 0xB6u
         && (unsigned char)TRANSFER_BUF_BYTE(2u)  == 0x08u
         && (unsigned char)TRANSFER_BUF_BYTE(11u) == 0x20u
         && (unsigned char)TRANSFER_BUF_BYTE(12u) == 0xD6u
         && (unsigned char)TRANSFER_BUF_BYTE(13u) == 0x08u
         && (unsigned char)TRANSFER_BUF_BYTE(40u) == 0xFFu) ? 1u : 0u;
}

/* ---- T1: hearts=$33 partial=0 -------------------------------------- *
 * full=3, containers=3, ts=12, te=12.
 * row1 (slots 0..7): all < 12 → SPC.        buf[3..10] = SPC×8
 * row2 (slots 8..15): 8..11 SPC; 12 partial=0 → EMP; 13..15 → FULL.
 *   slot N → buf[29-N]. slot 8→21, 15→14.
 *   buf[14..21] = [FULL, FULL, FULL, EMP, SPC, SPC, SPC, SPC]
 */
static unsigned char test_hearts_3_full(void)
{
    static const unsigned char row1[8] = {
        TILE_SPC, TILE_SPC, TILE_SPC, TILE_SPC,
        TILE_SPC, TILE_SPC, TILE_SPC, TILE_SPC
    };
    static const unsigned char row2[8] = {
        TILE_FULL, TILE_FULL, TILE_FULL, TILE_EMP,
        TILE_SPC,  TILE_SPC,  TILE_SPC,  TILE_SPC
    };
    format_with(0x33u, 0u);
    return (buf_eq(3u, row1, 8u) && buf_eq(14u, row2, 8u)) ? 1u : 0u;
}

/* ---- T2: hearts=$31 partial=0 -------------------------------------- *
 * full=1, containers=3, ts=12, te=14.
 * row1: all SPC.
 * row2: slot 8..11 SPC (<12); slot 12,13 EMP (<14); slot 14 EMP (==te,
 *       partial=0); slot 15 FULL (>14).
 *   buf[14..21] = [FULL, EMP, EMP, EMP, SPC, SPC, SPC, SPC]
 */
static unsigned char test_hearts_3_max_1_cur(void)
{
    static const unsigned char row1[8] = {
        TILE_SPC, TILE_SPC, TILE_SPC, TILE_SPC,
        TILE_SPC, TILE_SPC, TILE_SPC, TILE_SPC
    };
    static const unsigned char row2[8] = {
        TILE_FULL, TILE_EMP, TILE_EMP, TILE_EMP,
        TILE_SPC,  TILE_SPC, TILE_SPC, TILE_SPC
    };
    format_with(0x31u, 0u);
    return (buf_eq(3u, row1, 8u) && buf_eq(14u, row2, 8u)) ? 1u : 0u;
}

/* ---- T3: hearts=$83 partial=$80 ------------------------------------ *
 * full=3, containers=8, ts=7, te=12.
 * row1 (slots 0..7): 0..6 SPC (<7); slot 7 EMP (<12).
 *   slot N → buf[10-N]. slot 0→10, 7→3.
 *   buf[3..10] = [EMP, SPC, SPC, SPC, SPC, SPC, SPC, SPC]
 * row2 (slots 8..15): 8..11 EMP (<12); 12 FULL (==te, partial>=$80);
 *   13..15 FULL (>12).
 *   buf[14..21] = [FULL, FULL, FULL, FULL, EMP, EMP, EMP, EMP]
 */
static unsigned char test_hearts_8_max_3_cur_high_partial(void)
{
    static const unsigned char row1[8] = {
        TILE_EMP, TILE_SPC, TILE_SPC, TILE_SPC,
        TILE_SPC, TILE_SPC, TILE_SPC, TILE_SPC
    };
    static const unsigned char row2[8] = {
        TILE_FULL, TILE_FULL, TILE_FULL, TILE_FULL,
        TILE_EMP,  TILE_EMP,  TILE_EMP,  TILE_EMP
    };
    format_with(0x83u, 0x80u);
    return (buf_eq(3u, row1, 8u) && buf_eq(14u, row2, 8u)) ? 1u : 0u;
}

/* ---- T4: hearts=$83 partial=$40 ------------------------------------ *
 * Identical to T3 except slot 12 partial<$80 && !=0 → HALF (101).
 * Slot 12 → buf[17]. With buf[14..21] left-to-right that is row2[3].
 *   buf[14..21] = [FULL, FULL, FULL, HALF, EMP, EMP, EMP, EMP]
 */
static unsigned char test_hearts_8_max_3_cur_low_partial(void)
{
    static const unsigned char row1[8] = {
        TILE_EMP, TILE_SPC, TILE_SPC, TILE_SPC,
        TILE_SPC, TILE_SPC, TILE_SPC, TILE_SPC
    };
    static const unsigned char row2[8] = {
        TILE_FULL, TILE_FULL, TILE_FULL, TILE_HALF,
        TILE_EMP,  TILE_EMP,  TILE_EMP,  TILE_EMP
    };
    format_with(0x83u, 0x40u);
    return (buf_eq(3u, row1, 8u) && buf_eq(14u, row2, 8u)) ? 1u : 0u;
}

/* ---- T5: hearts=$FF partial=0 -------------------------------------- *
 * full=15, containers=15, ts=0, te=0.
 * slot 0: ==te, partial=0 → EMP.
 * slot 1..15: > 0 → FULL.
 * row1: slot 0 EMP, 1..7 FULL.
 *   buf[10]=EMP (slot 0), buf[9..3]=FULL.
 *   buf[3..10] = [FULL, FULL, FULL, FULL, FULL, FULL, FULL, EMP]
 * row2: slots 8..15 FULL.
 *   buf[14..21] = [FULL×8]
 */
static unsigned char test_hearts_15_full(void)
{
    static const unsigned char row1[8] = {
        TILE_FULL, TILE_FULL, TILE_FULL, TILE_FULL,
        TILE_FULL, TILE_FULL, TILE_FULL, TILE_EMP
    };
    static const unsigned char row2[8] = {
        TILE_FULL, TILE_FULL, TILE_FULL, TILE_FULL,
        TILE_FULL, TILE_FULL, TILE_FULL, TILE_FULL
    };
    format_with(0xFFu, 0u);
    return (buf_eq(3u, row1, 8u) && buf_eq(14u, row2, 8u)) ? 1u : 0u;
}

/* ---- T6: hearts=$00 partial=0 -------------------------------------- *
 * Degenerate: hearts==0 → all 16 slots SPC.
 *   buf[3..10] = SPC×8, buf[14..21] = SPC×8.
 */
static unsigned char test_hearts_zero(void)
{
    static const unsigned char all_spc[8] = {
        TILE_SPC, TILE_SPC, TILE_SPC, TILE_SPC,
        TILE_SPC, TILE_SPC, TILE_SPC, TILE_SPC
    };
    format_with(0u, 0u);
    return (buf_eq(3u, all_spc, 8u) && buf_eq(14u, all_spc, 8u)) ? 1u : 0u;
}

/* ---- T7: hearts=$77 partial=0 -------------------------------------- *
 * full=7, containers=7, ts=8, te=8.
 * row1 (slots 0..7): 0..7 < 8 → SPC.
 * row2: slot 8 ==te partial=0 → EMP; slots 9..15 > 8 → FULL.
 *   buf[14..21] = [FULL, FULL, FULL, FULL, FULL, FULL, FULL, EMP]
 */
static unsigned char test_hearts_7_full(void)
{
    static const unsigned char row1[8] = {
        TILE_SPC, TILE_SPC, TILE_SPC, TILE_SPC,
        TILE_SPC, TILE_SPC, TILE_SPC, TILE_SPC
    };
    static const unsigned char row2[8] = {
        TILE_FULL, TILE_FULL, TILE_FULL, TILE_FULL,
        TILE_FULL, TILE_FULL, TILE_FULL, TILE_EMP
    };
    format_with(0x77u, 0u);
    return (buf_eq(3u, row1, 8u) && buf_eq(14u, row2, 8u)) ? 1u : 0u;
}

/* ---- Driver -------------------------------------------------------- */

static void mark(unsigned int bit_idx, unsigned char *passes_io,
                 unsigned char *bits)
{
    *bits |= (unsigned char)(1u << bit_idx);
    ++(*passes_io);
}

void hud_format_probe_run(void)
{
    /* Snapshot heart cells — tests overwrite them. */
    const unsigned char saved_hearts  = (unsigned char)LINK_HEARTS;
    const unsigned char saved_partial = (unsigned char)LINK_PARTIAL_HEART;

    unsigned char bits   = 0u;
    unsigned char passes = 0u;
    const unsigned char total = 8u;

    stamp_magic();

    if (test_template_loaded())                    mark(0u, &passes, &bits);
    if (test_hearts_3_full())                      mark(1u, &passes, &bits);
    if (test_hearts_3_max_1_cur())                 mark(2u, &passes, &bits);
    if (test_hearts_8_max_3_cur_high_partial())    mark(3u, &passes, &bits);
    if (test_hearts_8_max_3_cur_low_partial())     mark(4u, &passes, &bits);
    if (test_hearts_15_full())                     mark(5u, &passes, &bits);
    if (test_hearts_zero())                        mark(6u, &passes, &bits);
    if (test_hearts_7_full())                      mark(7u, &passes, &bits);

    PROBE[3] = total;
    PROBE[4] = passes;
    PROBE[5] = bits;

    /* Restore live heart cells so subsequent gameplay sees the real
     * inventory state, not the last test value. */
    LINK_HEARTS = saved_hearts;
    LINK_PARTIAL_HEART = saved_partial;
}
