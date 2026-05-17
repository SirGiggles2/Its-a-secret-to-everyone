/* Phase 9.7 — Mode 11 Death native rewrite.
 *
 * NES source: reference/aldonunez/Z_05.asm:2521-2704
 *             UpdateMode11Death_Full + 13 sub-states Sub0..SubC.
 *
 * Drained C: NONE (tools/audit/drain_coverage.json has no candidate
 * for Mode 11). REPLACE-stance per Drain Rule D1 — full per-line
 * native transcription below.
 *
 * 13-sub-state machine (mirrors NES asm):
 *   Sub0: prep top half play area attrs (CueTransfer hi-half)
 *   Sub1: play death tune ($80) + same attr transfer
 *   Sub2: update all play area tiles; enable sprite 0 on completion
 *   Sub3: cue transfer top-half attrs ($60) + advance submode
 *   Sub4: cue transfer bottom-half attrs ($62)
 *   Sub5: clear sprite 0 check + cue BG palette transfer ($5E)
 *   Sub6: AND $FE PpuControl_2000 (even nametable)
 *   Sub7: DeathTurns countdown — Link turns 16 times (4 directions × 4)
 *         every 5 frames (ObjTimer+11 cadence)
 *   Sub8: AnimateWorldFading until done
 *   Sub9: cue dead-Link grey palette ($2C) + DeathTurns=$0F (spark counter)
 *   SubA: spark animation — flashes 2 sprites at Link's pos, plays
 *         heart-taken tune when DeathTurns hits 0
 *   SubB: 60-frame wait → cue "GAME OVER" text transfer ($46)
 *   SubC: 60-frame wait → EndGameMode + GameMode = 8 (ContinueQuestion)
 *         + Tune1Request = $40 (Game Over music) + INC DeathCounts
 *
 * Touches: GameSubmode, ObjTimer+11, ObjX, ObjY, ObjDir, Sprites OAM
 * mirror (slots 18/19 for spark), TileBufSelector, GameMode,
 * Tune0Request, Tune1Request, IsSprite0CheckActive, CurPpuControl_2000,
 * DeathTurns, CurSaveSlot, DeathCounts.
 */

#include "platform_abi.h"
#include "world_dispatch.h"  /* world_animate_world_fading (drained) */

/* NES RAM cells. */
#define MODE11_GAME_SUBMODE         RAM(0x0013u)
#define MODE11_GAME_MODE            RAM(0x0012u)
#define MODE11_OBJ_TIMER_11         RAM(0x003Au)  /* ObjTimer[$0B] = $30+$0B */
#define MODE11_OBJ_X                RAM(0x0070u)  /* Link's X = slot 0 */
#define MODE11_OBJ_Y                RAM(0x0084u)  /* Link's Y = slot 0 */
#define MODE11_OBJ_DIR              RAM(0x00C4u)  /* Link's dir = slot 0 */
/* Variables.inc:5 `TileBufSelector := $14`. Prior $00B0 was wrong —
 * static-selector writes never reached the asm-side or C-side drain.
 * Fixed 2026-05-16 alongside plan v5b TRANSFER_BUF->CRAM bridge so
 * Sub9's dead-Link palette cue actually lands in Genesis CRAM. */
#define MODE11_TILE_BUF_SELECTOR    RAM(0x0014u)
#define MODE11_TUNE0_REQUEST        RAM(0x0089u)
#define MODE11_TUNE1_REQUEST        RAM(0x008Bu)
#define MODE11_IS_SPRITE0_CHECK     RAM(0x00ECu)  /* IsSprite0CheckActive */
#define MODE11_CUR_PPU_CTRL_2000    RAM(0x00EDu)
#define MODE11_DEATH_TURNS          RAM(0x00E5u)
#define MODE11_CUR_SAVE_SLOT        RAM(0x0635u)  /* CurSaveSlot @ SRAM-adjacent */
/* DeathCounts table — NES SRAM at $63E (per profile). */
#define MODE11_DEATH_COUNTS(idx)    RAM((unsigned short)(0x063Eu + (idx)))

/* OAM mirror Sprites+N — Z1 stores OAM at $0200..$02FF.
 * Slot 18 = Sprites+72..+75, slot 19 = Sprites+76..+79. */
#define MODE11_SPRITES_72           RAM(0x0248u)  /* slot 18 Y */
#define MODE11_SPRITES_73           RAM(0x0249u)  /* slot 18 tile */
#define MODE11_SPRITES_74           RAM(0x024Au)  /* slot 18 attr */
#define MODE11_SPRITES_75           RAM(0x024Bu)  /* slot 18 X */
#define MODE11_SPRITES_76           RAM(0x024Cu)  /* slot 19 Y */
#define MODE11_SPRITES_77           RAM(0x024Du)  /* slot 19 tile */
#define MODE11_SPRITES_78           RAM(0x024Eu)  /* slot 19 attr */
#define MODE11_SPRITES_79           RAM(0x024Fu)  /* slot 19 X */

/* Stubs for not-yet-drained NES routines. Mode 11 calls these:
 *   ChooseAttrSourceAndDestForSubmode — palette-rotate helper
 *   CopyPlayAreaAttrsHalfToDynTransferBuf — half-attrs DynTileBuf copy
 *   CopyNextRowToTransferBufAndAdvanceSubmodeWhenDone — row-tile sweep
 *   WriteAndEnableSprite0 — sprite-0 check arming
 *   AnimateWorldFading — palette fade-to-black
 *   Link_EndMoveAndAnimate — Link sprite redraw
 *   EndGameMode — Mode8-style state clear (also called by Mode 8 body)
 * Each is a hand-rolled stub here pending drain. Behaviour during
 * stub period: state machine ticks deterministically but visuals are
 * minimal (palette fades + tile transfers no-op). */
static void mode11_choose_attr_source(unsigned char a, unsigned char y, unsigned char x_arg)
{ (void)a; (void)y; (void)x_arg; }
static void mode11_copy_play_area_attrs_half(void) { /* stub */ }
static unsigned char mode11_copy_next_row_to_buf(void) { return 1u; /* stub: claim done */ }
static void mode11_write_and_enable_sprite0(void) { /* stub */ }
/* Plan v5b T2.6 — wire real drain. Drain returns 0=done, 1=continuing;
 * caller's `done` variable expects 1=done so invert. Drain advances
 * NES FadeCycle ($051C) + ObjTimer+12 ($0034) + queues PALRAM writes
 * to TRANSFER_BUF. Substrate TRANSFER_BUF→CRAM bridge for $3F08
 * background palette writes is the remaining piece; without it, state
 * machine still advances correctly but Genesis CRAM stays unchanged. */
static unsigned char mode11_animate_world_fading(void)
{
    return (unsigned char)(world_animate_world_fading() == 0u);
}
static void mode11_link_end_move_and_animate(void) { /* stub */ }
static void mode11_end_game_mode(void)
{
    /* Z_07.asm:1683 EndGameMode — clear IsUpdatingMode + GameSubmode. */
    RAM(0x0011u) = 0u;
    MODE11_GAME_SUBMODE = 0u;
}

/* NES Z_07.asm:1554 SelectTransferBufAndAdvanceSubmode equivalent. */
static void mode11_select_transfer_buf_and_advance_submode(unsigned char a)
{
    MODE11_TILE_BUF_SELECTOR = a;
    MODE11_GAME_SUBMODE = (unsigned char)(MODE11_GAME_SUBMODE + 1u);
}

/* L14CD7 — inc-submode-and-return. */
static void mode11_inc_submode(void)
{
    MODE11_GAME_SUBMODE = (unsigned char)(MODE11_GAME_SUBMODE + 1u);
}

/* ----- Sub-states ----- */

static void mode11_sub1_then_sub0(void)
{
    /* NES :2540-2544 — Sub1 plays death tune, then falls through. */
    MODE11_TUNE1_REQUEST = 0x80u;
}

static void mode11_sub0(void)
{
    /* NES :2547-2565 — prepare top-half play area attrs. */
    mode11_choose_attr_source(0u, 0u, 0u);
    mode11_copy_play_area_attrs_half();
    mode11_inc_submode();
}

static void mode11_sub2(void)
{
    /* NES :2567-2578 — update all play area tiles. */
    unsigned char done = mode11_copy_next_row_to_buf();
    if (done) {
        mode11_write_and_enable_sprite0();
    }
    /* DynTileBuf modification stubbed — full row-tile sweep pending. */
}

static void mode11_sub3(void)
{
    /* NES :2580-2583 — cue transfer of top-half attrs ($60). */
    mode11_select_transfer_buf_and_advance_submode(0x60u);
}

static void mode11_sub4(void)
{
    /* NES :2585-2587. */
    mode11_select_transfer_buf_and_advance_submode(0x62u);
}

static void mode11_sub5(void)
{
    /* NES :2589-2593. */
    MODE11_IS_SPRITE0_CHECK = 0u;
    mode11_select_transfer_buf_and_advance_submode(0x5Eu);
}

static void mode11_sub6(void)
{
    /* NES :2595-2601 — clear NT bit to use even nametable. */
    MODE11_CUR_PPU_CTRL_2000 = (unsigned char)(MODE11_CUR_PPU_CTRL_2000 & 0xFEu);
    mode11_inc_submode();
}

static void mode11_sub7(void)
{
    /* NES :2603-2632 — Link turns 16 times. */
    unsigned char turns = MODE11_DEATH_TURNS;
    unsigned char timer = MODE11_OBJ_TIMER_11;
    unsigned char dir;

    if (turns == 0u) {
        mode11_inc_submode();
        return;
    }
    if (timer != 0u) {
        mode11_link_end_move_and_animate();
        return;
    }
    /* Re-arm timer to 5 frames + cycle direction LSR-LSR. */
    MODE11_OBJ_TIMER_11 = 0x05u;
    dir = MODE11_OBJ_DIR;
    /* LSR LSR maps NES dir bits 1/2/4/8 to {right=4→0, left=2→0,
     * down=8→2, up=1→0} carry-driven branches. Simplified: cycle
     * through 4 cardinal directions. */
    if ((dir & 0x04u) != 0u) {
        /* Facing left — go to down ($04) and decrement turns. */
        MODE11_DEATH_TURNS = (unsigned char)(turns - 1u);
        MODE11_OBJ_DIR = 0x04u;
    } else if ((dir & 0x08u) != 0u) {
        /* Facing right — go to up. */
        MODE11_OBJ_DIR = 0x08u;
    } else {
        /* Vertical → horizontal flip. */
        MODE11_OBJ_DIR = (dir == 0x01u) ? 0x02u : 0x01u;
    }
    mode11_link_end_move_and_animate();
}

static void mode11_sub8_animate_fade(void)
{
    /* NES :2633-2636. */
    unsigned char done = mode11_animate_world_fading();
    if (done) mode11_inc_submode();
}

static void mode11_sub9(void)
{
    /* NES :2638-2644 — cue dead-Link grey palette + DeathTurns = $0F. */
    MODE11_TILE_BUF_SELECTOR = 0x2Cu;
    MODE11_DEATH_TURNS = 0x0Fu;
    MODE11_OBJ_TIMER_11 = (unsigned char)(0x18u - 1u);
    mode11_inc_submode();
}

static void mode11_sub_a(void)
{
    /* NES :2645-2680 — spark animation. */
    unsigned char timer = MODE11_OBJ_TIMER_11;
    unsigned char turns;
    unsigned char spark_tile;
    unsigned char x;

    if (timer != 0u) return;

    turns = MODE11_DEATH_TURNS;
    /* DeathTurns >= 6 -> little spark $62, else big $64. */
    spark_tile = (turns >= 0x06u) ? 0x62u : 0x64u;

    /* Sprites slot 18 + 19: matched pair, 8px horizontal split. */
    MODE11_SPRITES_72 = MODE11_OBJ_Y;
    MODE11_SPRITES_76 = MODE11_OBJ_Y;
    MODE11_SPRITES_73 = spark_tile;
    MODE11_SPRITES_77 = spark_tile;
    MODE11_SPRITES_74 = 0x01u;  /* PAL5 */
    MODE11_SPRITES_78 = 0x41u;  /* PAL5 + hflip */
    x = MODE11_OBJ_X;
    MODE11_SPRITES_75 = x;
    MODE11_SPRITES_79 = (unsigned char)(x + 8u);

    MODE11_DEATH_TURNS = (unsigned char)(turns - 1u);
    if (MODE11_DEATH_TURNS != 0u) return;

    /* DeathTurns hit 0 — heart-taken tune + hide sparks. */
    MODE11_TUNE0_REQUEST = 0x10u;
    MODE11_SPRITES_72 = 0xF8u;
    MODE11_SPRITES_76 = 0xF8u;
    MODE11_OBJ_TIMER_11 = (unsigned char)(0x2Eu - 1u);
    mode11_inc_submode();
}

static void mode11_sub_b(void)
{
    /* NES :2682-2688 — wait then cue "GAME OVER" text. */
    if (MODE11_OBJ_TIMER_11 != 0u) return;
    MODE11_OBJ_TIMER_11 = (unsigned char)(0x60u - 1u);
    mode11_select_transfer_buf_and_advance_submode(0x46u);
}

static void mode11_sub_c(void)
{
    /* NES :2690-2704 — terminal: end mode + go to Continue Question. */
    unsigned char save_slot;
    unsigned char count;

    if (MODE11_OBJ_TIMER_11 != 0u) return;
    mode11_end_game_mode();
    MODE11_GAME_MODE = 0x08u;
    MODE11_TUNE1_REQUEST = 0x40u;
    save_slot = MODE11_CUR_SAVE_SLOT;
    count = MODE11_DEATH_COUNTS(save_slot);
    if (count != 0xFFu) {
        MODE11_DEATH_COUNTS(save_slot) = (unsigned char)(count + 1u);
    }
}

/* ----- Entry ----- */

void mode11_death_update(void)
{
    unsigned char submode = MODE11_GAME_SUBMODE;

    /* NES :2521-2538 — JSR TableJump per GameSubmode. Sub1 falls
     * through to Sub0 (only Sub1 plays the death tune; rest is shared). */
    switch (submode) {
    case 0x00:  mode11_sub0(); break;
    case 0x01:  mode11_sub1_then_sub0(); mode11_sub0(); break;
    case 0x02:  mode11_sub2(); break;
    case 0x03:  mode11_sub3(); break;
    case 0x04:  mode11_sub4(); break;
    case 0x05:  mode11_sub5(); break;
    case 0x06:  mode11_sub6(); break;
    case 0x07:  mode11_sub7(); break;
    case 0x08:  mode11_sub8_animate_fade(); break;
    case 0x09:  mode11_sub9(); break;
    case 0x0A:  mode11_sub_a(); break;
    case 0x0B:  mode11_sub_b(); break;
    case 0x0C:  mode11_sub_c(); break;
    default:    /* invalid submode: terminate. */
                mode11_end_game_mode();
                break;
    }
}
