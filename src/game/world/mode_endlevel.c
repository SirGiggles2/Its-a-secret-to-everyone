/* Phase 9.7 — Mode 12 EndLevel native rewrite.
 *
 * NES source: reference/aldonunez/Z_05.asm:5534-5606
 *             UpdateMode12EndLevel_Full.
 *
 * Drained C: NONE. tools/audit/drain_coverage.json has no candidate
 * row for Mode 12. This file is the GREENFIELD native transcription
 * per Drain Rule D1 (NES asm wins ties — full per-line port below).
 *
 * Stance: REPLACE — verbatim per-line transcription of the NES asm
 * body. Touches RAM cells:
 *   GameSubmode      $13
 *   ObjTimer         $30  (slot 0 — Link / mode-machine timer)
 *   TileBufSelector  $7A  (selects which 16-byte palette window the
 *                          next PPU transfer copies)
 *   World_IsFillingHearts $0640  (heart-fill animation tick gate)
 *   ObjX+12          $80+12 = $8C (curtain-effect tracker column)
 *   CurPpuControl_2000 $FF (mirror of $2000 PPUCTRL; bit 2 = VRAM
 *                          address increment 32 vs 1)
 *   PpuControl_2000  $2000 (live PPUCTRL register)
 *
 * State machine (mirrors NES asm Sub0..Sub4):
 *   Pre-dispatch:
 *     HideObjectSprites
 *     DrawLinkLiftingItem
 *     Jump table on GameSubmode.
 *
 *   Sub0 — delay:
 *     if ObjTimer != 0: return.
 *     ObjTimer = $30 (run Sub1 for 47 frames).
 *     INC GameSubmode.
 *
 *   Sub1 — flash screen + start heart-fill:
 *     if ObjTimer == 0:
 *         World_IsFillingHearts = 2.  (TODO: NES asm comment "why 2?")
 *         INC GameSubmode.
 *     else:
 *         Y = $18 (LevelPaletteTransferBuf).
 *         if (ObjTimer & 7) >= 4:
 *             Y = $78 (WhitePaletteBottomHalfTransferBuf).
 *         TileBufSelector = Y.
 *         return.
 *
 *   Sub2 — wait for heart-fill to finish:
 *     UpdateHeartsAndRupees.
 *     if World_IsFillingHearts != 0: return.
 *     fall through to Sub3 setup (NES uses BEQ :+ to next-submode-timer
 *     setup at end of Sub3, here we INC submode + set timer).
 *
 *   Sub3 — curtain effect:
 *     if ObjTimer != 0: return.
 *     UpdateWorldCurtainEffect.
 *     if ObjX[12] < $11:    (column reached the middle)
 *         ObjTimer = $80.   (delay 127 frames for Sub4).
 *         INC GameSubmode.
 *     (else: stay in Sub3 next frame.)
 *
 *   Sub4 — finalize:
 *     if ObjTimer != 0: return.
 *     HideAllSprites.
 *     CurPpuControl_2000 &= ~$04   (VRAM increment 1).
 *     PpuControl_2000 = CurPpuControl_2000.
 *     EndGameMode12.
 */

#include "platform_abi.h"
#include "mode_endlevel.h"

/* NES RAM cells. */
#define M12_GAME_SUBMODE         RAM(0x0013u)
#define M12_OBJ_TIMER_0          RAM(0x0030u)  /* ObjTimer[0] */
#define M12_TILE_BUF_SELECTOR    RAM(0x007Au)
#define M12_WORLD_FILLING_HEARTS RAM(0x0640u)
#define M12_OBJ_X_12             RAM((unsigned short)(0x0080u + 12u))
#define M12_CUR_PPU_CTRL_2000    RAM(0x00FFu)

/* Sub2 transition: NES asm BEQ falls through to "set up Sub3 timer".
 * Looking at Z_05.asm:5582 "BEQ :+", the `:+` label is the same line
 * label inside Sub3 that sets ObjTimer = $80 + INC GameSubmode. We
 * mirror by directly poking those cells when World_IsFillingHearts
 * clears. */
#define MODE12_SUB3_DELAY_FRAMES 0x80u

/* Sub1 palette transfer buf selectors. */
#define MODE12_LEVEL_PAL_BUF     0x18u
#define MODE12_WHITE_BOTTOM_BUF  0x78u

/* PpuControl_2000 bit 2 = VRAM address increment (0=1, 1=32). */
#define MODE12_PPUCTRL_INC32     0x04u

/* Stub callees — bodies not yet drained. Each touches state outside
 * Mode 12's own RAM cells, so we leave them as no-op trampolines for
 * the focused-PR follow-up that ports them. */
static void mode12_hide_object_sprites(void)        { /* Z_07.asm:611 */ }
static void mode12_draw_link_lifting_item(void)     { /* Z_07.asm:1055 */ }
static void mode12_update_hearts_and_rupees(void)   { /* Z_07.asm:2033 */ }
static void mode12_update_world_curtain_effect(void){ /* Z_07.asm — TBD */ }
static void mode12_hide_all_sprites(void)           { /* Z_07.asm — TBD */ }
static void mode12_end_game_mode_12(void)           { /* Z_05.asm:7487 */ }

/* PpuControl_2000 mirror live write — defer to MMIO adapter. The
 * Genesis-side VDP register write is bound by SGDK adapter; the
 * NES mirror cell is the source of truth so we just update RAM. */
static inline void mode12_write_ppu_ctrl(unsigned char value)
{
    M12_CUR_PPU_CTRL_2000 = value;
    /* Live $2000 write deferred — graphical effect is "VRAM increment
     * goes back to 1", which is the default state on Genesis-side
     * VDP_setAutoInc(2). No-op until full PPUCTRL shim lands. */
}

static void mode12_sub0(void)
{
    if (M12_OBJ_TIMER_0 != 0u) {
        return;
    }
    M12_OBJ_TIMER_0 = 0x30u;
    ++M12_GAME_SUBMODE;
}

static void mode12_sub1(void)
{
    unsigned char timer = M12_OBJ_TIMER_0;
    if (timer == 0u) {
        M12_WORLD_FILLING_HEARTS = 0x02u;
        ++M12_GAME_SUBMODE;
        return;
    }

    unsigned char y = MODE12_LEVEL_PAL_BUF;
    if ((timer & 0x07u) >= 0x04u) {
        y = MODE12_WHITE_BOTTOM_BUF;
    }
    M12_TILE_BUF_SELECTOR = y;
}

static void mode12_sub2(void)
{
    mode12_update_hearts_and_rupees();
    if (M12_WORLD_FILLING_HEARTS != 0u) {
        return;
    }
    M12_OBJ_TIMER_0 = MODE12_SUB3_DELAY_FRAMES;
    ++M12_GAME_SUBMODE;
}

static void mode12_sub3(void)
{
    if (M12_OBJ_TIMER_0 != 0u) {
        return;
    }
    mode12_update_world_curtain_effect();
    if (M12_OBJ_X_12 >= 0x11u) {
        return;
    }
    M12_OBJ_TIMER_0 = MODE12_SUB3_DELAY_FRAMES;
    ++M12_GAME_SUBMODE;
}

static void mode12_sub4(void)
{
    if (M12_OBJ_TIMER_0 != 0u) {
        return;
    }
    mode12_hide_all_sprites();
    unsigned char ctrl = (unsigned char)(M12_CUR_PPU_CTRL_2000 & (unsigned char)~MODE12_PPUCTRL_INC32);
    mode12_write_ppu_ctrl(ctrl);
    mode12_end_game_mode_12();
}

void mode12_endlevel_update(void)
{
    mode12_hide_object_sprites();
    mode12_draw_link_lifting_item();

    unsigned char submode = M12_GAME_SUBMODE;
    switch (submode) {
    case 0x00u: mode12_sub0(); break;
    case 0x01u: mode12_sub1(); break;
    case 0x02u: mode12_sub2(); break;
    case 0x03u: mode12_sub3(); break;
    case 0x04u: mode12_sub4(); break;
    default:    /* NES TableJump would crash; we no-op. */ break;
    }
}
