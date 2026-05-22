/* mode_wingame.c — Mode 0x13 WinGame dispatch (Tier 4 scaffold).
 *
 * NES source: reference/aldonunez/Z_02.asm:3236 UpdateMode13WinGame.
 * Drained C: NONE (no candidate row in tools/audit/drain_coverage.json
 * for mode 13). Per Drain Rule D1 with no drain candidate, stance =
 * GREENFIELD; NES asm is the spec.
 *
 * Submode state machine (Z_02.asm:3239 jump table):
 *   Sub0  flash + advance after $C0 frames (NATIVE this commit)
 *   Sub1  ending text part 1 — wait for EndingFlashLongTimer to expire
 *         then advance (STUB this commit; Sub1 jumptable entry is
 *         duplicated, so Sub2 = Sub1)
 *   Sub2  ending text part 2 (STUB; same body as Sub1 in NES)
 *   Sub3  credits / continue (STUB)
 *   Sub4  end / soft-reset (STUB)
 *
 * Audio: when Mode 13 first ticks, audio_dispatch_tick observes the
 * GameMode change ($12->$13 or $05->$13) and plays SONG_ENDING ($10)
 * via the GM_WIN_GAME case in audio_dispatch.c:120-122. No explicit
 * SongRequest write needed here.
 *
 * RAM cells touched (per Variables.inc + BeginEndVars.inc):
 *   GameSubmode             $0013
 *   GameMode                $0012
 *   ObjTimer[0]             $0030
 *   ItemLiftTimer           $0506
 *   EndingFlashLongTimer    $004D
 *   DynTileBuf              $0302..$0325 (transfer-buf scratch)
 *   LevelInfo_PalettesTransferBuf  SRAM $6B7E (24 bytes palette template)
 */

#include "platform_abi.h"
#include "mode_wingame.h"

/* NES RAM aliases. */
#define M13_GAME_SUBMODE          RAM(0x0013u)
#define M13_OBJ_TIMER_0           RAM(0x0030u)
#define M13_ITEM_LIFT_TIMER       RAM(0x0506u)
#define M13_ENDING_FLASH_TIMER    RAM(0x004Du)
#define M13_DYN_TILE_BUF(off)     RAM((unsigned short)(0x0302u + (off)))

/* NES SRAM. */
#define M13_NES_SRAM_BASE                  0x6000u
#define M13_LEVEL_INFO_PALETTES_TRANSFER   0x0B7Eu  /* $6B7E - $6000 */

/* EndingFlashColors (Z_02.asm:3247): 4-color cycle for palette flash. */
static const unsigned char k_ending_flash_colors[4] = {
    0x0Fu, 0x12u, 0x16u, 0x2Au
};

/* Stubs — see header. Sub1/2/3/4 bodies port per follow-up. */
static void mode13_hide_all_sprites(void)            { /* Z_07.asm — TBD */ }
static void mode13_draw_link_zelda_triforces(void)   { /* Z_02.asm:3301 — TBD */ }

/* Sub0: flash + DrawLinkZeldaTriforces.
 *
 * NES asm verbatim:
 *   JSR HideAllSprites
 *   INC ItemLiftTimer
 *   LDA ItemLiftTimer
 *   CMP #$C0
 *   BEQ AdvanceSubmode
 *   JSR DrawLinkZeldaTriforces
 *   ... ChangePalette ...
 *   if (ItemLiftTimer >= $40) {
 *       copy LevelInfo_PalettesTransferBuf[0..$23] to DynTileBuf[0..$23]
 *       DynTileBuf+19 = EndingFlashColors[ItemLiftTimer & 3]
 *   }
 *
 *  AdvanceSubmode:
 *   ; (SongRequest=$10 handled by audio_dispatch; we omit)
 *   ObjTimer = $40
 *   EndingFlashLongTimer = $40
 *   INC GameSubmode
 *   (falls through to ChangePalette one more time)
 */
static void mode13_sub0_flash(void)
{
    mode13_hide_all_sprites();

    M13_ITEM_LIFT_TIMER = (unsigned char)(M13_ITEM_LIFT_TIMER + 1u);

    unsigned char timer = M13_ITEM_LIFT_TIMER;

    if (timer == 0xC0u) {
        /* Advance to Sub1: arm long timer + per-submode delay. Audio
         * dispatcher will play SONG_ENDING when GameMode 0x13 was first
         * observed (already true since we are inside mode13 path). */
        M13_OBJ_TIMER_0          = 0x40u;
        M13_ENDING_FLASH_TIMER   = 0x40u;
        M13_GAME_SUBMODE         = (unsigned char)(M13_GAME_SUBMODE + 1u);
    } else {
        mode13_draw_link_zelda_triforces();
    }

    /* ChangePalette block — runs every frame, including the
     * AdvanceSubmode fall-through. Only emits a palette record once
     * the warm-up window (frames 0..$3F) has elapsed. */
    if (timer < 0x40u) {
        return;
    }

    /* Copy SRAM[LevelInfo_PalettesTransferBuf + 0..$23] into
     * DynTileBuf[0..$23] inclusive (36 bytes). NES iterates Y=$23..0. */
    for (unsigned char i = 0u; i <= 0x23u; ++i) {
        M13_DYN_TILE_BUF(i) = nes_ram[M13_NES_SRAM_BASE +
                                      M13_LEVEL_INFO_PALETTES_TRANSFER + i];
    }
    /* Override byte at +19 with the cycling background color. */
    M13_DYN_TILE_BUF(19u) = k_ending_flash_colors[timer & 0x03u];
}

static void mode13_sub1_text(void)
{
    /* TODO Tier 4 follow-up: NES Z_02.asm:3350 UpdateMode13WinGame_Sub1
     * (text streamer + character emit + EndingFlashLongTimer decrement
     * + sprite hiding cascade). Stub: decrement long timer + auto-
     * advance so the state machine progresses instead of freezing. */
    if (M13_ENDING_FLASH_TIMER != 0u) {
        M13_ENDING_FLASH_TIMER = (unsigned char)(M13_ENDING_FLASH_TIMER - 1u);
        return;
    }
    M13_GAME_SUBMODE = (unsigned char)(M13_GAME_SUBMODE + 1u);
}

static void mode13_sub3_credits(void)
{
    /* TODO Tier 4 follow-up: NES Z_02.asm:????? credits scroll. Stub:
     * 256-frame wait then advance. */
    if (M13_OBJ_TIMER_0 != 0u) {
        return;
    }
    M13_OBJ_TIMER_0  = 0xFFu;
    M13_GAME_SUBMODE = (unsigned char)(M13_GAME_SUBMODE + 1u);
}

static void mode13_sub4_finalize(void)
{
    /* TODO Tier 4 follow-up: NES Z_02.asm end-of-game handler. Stub:
     * leave GameMode at $13 (frozen). Soft-reset path port pending. */
}

void mode13_wingame_update(void)
{
    unsigned char submode = M13_GAME_SUBMODE;

    switch (submode) {
    case 0x00u: mode13_sub0_flash();   break;
    case 0x01u: mode13_sub1_text();    break;
    case 0x02u: mode13_sub1_text();    break;  /* Sub1 + Sub2 share body */
    case 0x03u: mode13_sub3_credits(); break;
    case 0x04u: mode13_sub4_finalize();break;
    default:    /* NES TableJump would crash; no-op. */ break;
    }
}
