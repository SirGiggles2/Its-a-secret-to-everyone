/* mode_wingame.c - Mode $13 ending initialization, flash and peace text.
 *
 * NES source: reference/aldonunez/Z_02.asm:3236 UpdateMode13WinGame.
 * Drained C: existing mode_wingame, sprite/progress_dispatch and frontend
 * InitMode13_Sub3/Sub4 candidates. Coverage: PARTIAL (credits drawing and
 * final save/reset remain unfinished). Stance: EXTEND linked ownership.
 *
 * Submode state machine (Z_02.asm:3239 jump table):
 *   Sub0  flash + advance after $C0 frames (NATIVE)
 *   Sub1  Peace text part 1 — Link + Zelda + triforces + text scroller
 *   Sub2  Peace text part 2 — same body, delay-only
 *   Sub3  credits scroll (NATIVE: nametable scroll + DrawCredits hook)
 *   Sub4  end / soft-reset on Start (NATIVE: Start gate; soft-reset stubbed)
 *
 * Audio request order follows NES source; audible ending integration is
 * still open under the user's music-last direction.
 *
 * RAM cells touched (per Variables.inc + BeginEndVars.inc):
 *   GameSubmode             $0013
 *   GameMode                $0012
 *   ObjTimer[0]             $0028
 *   ItemLiftTimer           $0506
 *   EndingFlashLongTimer    $004D
 *   PeaceCharDelayCounter   $0412
 *   PeaceCharIndex          $0413
 *   CreditsTileOffset       $050B
 *   VScrollAddrHi           $0058
 *   VScrollAddrLo           $00E2
 *   CurVScroll              $00FC
 *   SwitchNameTablesReq     $005C
 *   Tune0Request            $0604
 *   ButtonsPressed          $00F8
 *   DynTileBuf              $0302..$0325 (transfer-buf scratch)
 *   LevelInfo_PalettesTransferBuf  SRAM $6B7E (36-byte record)
 */

#include "platform_abi.h"
#include "mode_wingame.h"
#include "draw_dispatch.h"
#include "sprite_dispatch.h"
#include "progress_dispatch.h"
#include "../enemies/enemy_render.h"
#include "../../../RoomRom/src/roomrom_main_state.h"  /* quest selector */

/* NES RAM aliases. */
#define M13_GAME_SUBMODE          RAM(0x0013u)
#define M13_GAME_MODE             RAM(0x0012u)
#define M13_OBJ_TIMER_0           RAM(0x0028u)
#define M13_ITEM_LIFT_TIMER       RAM(0x0506u)
#define M13_ENDING_FLASH_TIMER    RAM(0x004Du)
#define M13_PEACE_DELAY           RAM(0x0412u)
#define M13_PEACE_CHAR_INDEX      RAM(0x0413u)
#define M13_TUNE0_REQUEST         RAM(0x0604u)
#define M13_TILE_BUF_SELECTOR     RAM(0x0014u)
#define M13_BUTTONS_PRESSED       RAM(0x00F8u)
#define M13_CREDITS_TILE_OFFSET   RAM(0x050Bu)
#define M13_VSCROLL_ADDR_HI       RAM(0x0058u)
#define M13_VSCROLL_ADDR_LO       RAM(0x00E2u)
#define M13_CUR_VSCROLL           RAM(0x00FCu)
#define M13_SWITCH_NT_REQ         RAM(0x005Cu)
#define M13_DYN_TILE_BUF(off)     RAM((unsigned short)(0x0302u + (off)))

/* NES SRAM. */
#define M13_NES_SRAM_BASE                  0x6000u
#define M13_LEVEL_INFO_PALETTES_TRANSFER   0x0B7Eu  /* $6B7E - $6000 */

/* Existing ROM-extracted input; offsets are data/text/MANIFEST.json.
 * Reuse it instead of distributing another copy of the game's strings. */
extern const unsigned char nes_frontend_text[217];
#define k_ending_flash_colors       (nes_frontend_text + 51u)
#define k_peace_textbox_template     (nes_frontend_text + 55u)
#define k_peace_textbox_addrs_lo     (nes_frontend_text + 60u)
#define k_peace_text                 (nes_frontend_text + 112u)
#define k_credits_last_screen       (nes_frontend_text + 165u)
#define k_credits_last_vscroll      (nes_frontend_text + 167u)

/* NES source: Z_07 HideAllSprites; Z_02 DrawLinkZeldaTriforces.
 * Drained C: sprite_dispatch/draw_dispatch and native render caches.
 * Coverage: flash/peace-text sprites; credits/finalization remain open.
 * Stance: EXTEND the existing draw and hardware presentation owners. */
static unsigned char s_draw_link;
static void mode13_hide_all_sprites(void)
{
    unsigned short i;
    enemy_render_reset_oam();
    for (i = 0u; i < 256u; i += 4u) RAM(0x0200u + i) = 0xF8u;
    enemy_render_weapon_reset(0x13u);
    enemy_render_weapon_reset(0x10u);
    enemy_render_weapon_reset(0x11u);
    enemy_render_weapon_reset(0x0Eu);
    s_draw_link = 0u;
}
static void mode13_draw_link_zelda_triforces(void)
{
    RAM(0x0083u) = RAM(0x0070u);
    RAM(0x0097u) = (unsigned char)(RAM(0x0084u) - 0x10u);
    RAM(0x0340u) = 0u; /* Native cache publication owner, not NES scratch. */
    draw_link_ending_pose();
    s_draw_link = 1u;
    RAM(0x0340u) = 0x13u;
    draw_animate_item_object(0x1Bu, 0x13u);
    RAM(0x0340u) = 1u;
    (void)sprite_anim_fetch_obj_pos(1u);
    draw_object_mirrored(1u, 1u);
    RAM(0x0072u) = RAM(0x0071u);
    RAM(0x0086u) = (unsigned char)(RAM(0x0085u) - 0x10u);
    RAM(0x0340u) = 2u;
    draw_animate_item_object(0x1Bu, 2u);
}
static void mode13_draw_credits(void) { /* T-098 / T-051: credits presentation pending. */ }
static void mode13_end_game_mode(void) { /* T-098: quest conversion and save/reset pending. */ }

extern void roomrom_mode12_blank_column(unsigned char col);

/* InitMode13_Full (Z_02:3037-3234), before BeginUpdateMode. */
static void mode13_init(void)
{
    unsigned char i;
    s_draw_link = 3u; /* Preserve sprites until the source redraws them. */
    switch (M13_GAME_SUBMODE) {
    case 0u:
        if (M13_OBJ_TIMER_0 == 0u && RAM(0x0609u) == 0u) {
            const unsigned char dec = RAM(0x007Cu), inc = RAM(0x007Du);
            progress_update_world_curtain_effect_bank2();
            if (RAM(0x007Cu) != dec) {
                if (inc < 32u) roomrom_mode12_blank_column(inc);
                if (dec < 32u) roomrom_mode12_blank_column(dec);
            }
            if (RAM(0x007Cu) < 0x11u) {
                M13_OBJ_TIMER_0 = 0x80u;
                ++M13_GAME_SUBMODE;
            }
        }
        if (M13_GAME_SUBMODE == 0u) return;
        mode13_hide_all_sprites();
        goto draw_story;
    case 1u:
        for (i = 0u; i < 5u; ++i) M13_DYN_TILE_BUF(i) = nes_frontend_text[i];
        RAM(0x045Fu) = 0xA4u;
        RAM(0x0416u) = 0u;
        RAM(0x00ADu) = 0u;
        ++M13_GAME_SUBMODE;
        return;
    case 2u:
        if (RAM(0x0029u) == 0u) {
            unsigned char ch, idx, flags;
            RAM(0x0029u) = 6u;
            for (i = 0u; i < 5u; ++i)
                M13_DYN_TILE_BUF(i) = nes_frontend_text[43u + i];
            do {
                M13_DYN_TILE_BUF(1u) = RAM(0x045Fu);
                ++RAM(0x045Fu);
                idx = RAM(0x0416u)++;
                if (idx >= 38u) return;
                ch = nes_frontend_text[5u + idx];
            } while ((ch & 0x3Fu) == 0x25u);
            M13_DYN_TILE_BUF(3u) = (unsigned char)(ch & 0x3Fu);
            M13_TUNE0_REQUEST = 0x10u;
            flags = (unsigned char)(ch & 0xC0u);
            if (flags != 0u) {
                i = (flags == 0xC0u) ? 2u : (flags == 0x40u) ? 1u : 0u;
                RAM(0x045Fu) = nes_frontend_text[48u + i];
                if (i == 2u) { ++RAM(0x00ADu); RAM(0x00ACu) = 0u; }
            }
        }
        if (RAM(0x00ADu) != 0u) { RAM(0x0029u) = 0x50u; ++M13_GAME_SUBMODE; }
draw_story:
        RAM(0x03D0u) = 6u; /* Link_EndMoveAndDraw_Bank4. */
        roomrom_main_link_end_move_from_object();
        s_draw_link = 2u;
        RAM(0x0340u) = 1u;
        (void)sprite_anim_fetch_obj_pos(1u);
        draw_object_mirrored(0u, 1u);
        return;
    case 3u:
        if (RAM(0x0029u) != 0u) return;
        M13_TUNE0_REQUEST = 0x80u; /* SilenceSong through existing owner. */
        ++M13_GAME_SUBMODE;
        return;
    case 4u:
        M13_CREDITS_TILE_OFFSET = 8u;
        RAM(0x0011u) = 1u; /* BeginUpdateMode. */
        M13_GAME_SUBMODE = 0u;
        M13_PEACE_DELAY = M13_PEACE_CHAR_INDEX = 0u;
        mode13_hide_all_sprites();
        return;
    default: return;
    }
}

/* UpdateMode13 Sub0: flash + DrawLinkZeldaTriforces. */
static void mode13_sub0_flash(void)
{
    mode13_hide_all_sprites();

    M13_ITEM_LIFT_TIMER = (unsigned char)(M13_ITEM_LIFT_TIMER + 1u);

    unsigned char timer = M13_ITEM_LIFT_TIMER;

    if (timer == 0xC0u) {
        RAM(0x0600u) = 0x10u;  /* NES @AdvanceSubmode SongRequest. */
        M13_OBJ_TIMER_0          = 0x40u;
        M13_ENDING_FLASH_TIMER   = 0x40u;
        M13_GAME_SUBMODE         = (unsigned char)(M13_GAME_SUBMODE + 1u);
    } else {
        mode13_draw_link_zelda_triforces();
    }

    if (timer < 0x40u) {
        return;
    }

    for (unsigned char i = 0u; i <= 0x23u; ++i) {
        M13_DYN_TILE_BUF(i) = nes_ram[M13_NES_SRAM_BASE +
                                      M13_LEVEL_INFO_PALETTES_TRANSFER + i];
    }
    M13_DYN_TILE_BUF(19u) = k_ending_flash_colors[timer & 0x03u];
}

/* UpdatePeaceTextbox (Z_02.asm:3404). Emits one char every 8 frames
 * (when DelayCounter & 7 == 4) by stamping a 5-byte $22 nametable
 * record into DynTileBuf. transfer_buf_drain emits to Plane A. */
static void mode13_update_peace_textbox(void)
{
    M13_PEACE_DELAY = (unsigned char)(M13_PEACE_DELAY + 1u);
    if ((M13_PEACE_DELAY & 0x07u) != 0x04u) {
        return;
    }

    /* Copy 5-byte template to DynTileBuf[0..4]. */
    for (unsigned char i = 0u; i < 5u; ++i) {
        M13_DYN_TILE_BUF(i) = k_peace_textbox_template[i];
    }
    /* NES writes a terminated record without changing DynTileBufLen;
     * transfer_buf_drain already supports that source convention. */

    unsigned char y = (unsigned char)M13_PEACE_CHAR_INDEX;
    if (y >= 53u) {
        /* Out-of-bounds guard. NES would crash; we advance submode. */
        ++M13_GAME_SUBMODE;
        return;
    }
    unsigned char ch = k_peace_text[y];
    if (ch == 0xFFu) {
        ++M13_GAME_SUBMODE;
        return;
    }
    M13_DYN_TILE_BUF(3u) = ch;

    /* Non-space chars play tune $10 ("heart taken"). */
    if (ch != 0x24u) {
        M13_TUNE0_REQUEST = 0x10u;
    }

    M13_PEACE_CHAR_INDEX = (unsigned char)(M13_PEACE_CHAR_INDEX + 1u);

    /* Replace VRAM-lo with next char position; once it rolls past $A0
     * bump VRAM-hi from $22 -> $23 (second NT page). */
    unsigned char lo = (y < 52u)
                     ? k_peace_textbox_addrs_lo[y] : 0xACu;
    M13_DYN_TILE_BUF(1u) = lo;
    if (lo < 0xA0u) {
        M13_DYN_TILE_BUF(0u) = 0x23u;
    }
}

/* Sub1 + Sub2 share body (Z_02.asm:3350). */
static void mode13_sub1_text(void)
{
    if (M13_ENDING_FLASH_TIMER == 0u) {
        /* Advance to Sub3: load ending palette + bump submode. */
        M13_TILE_BUF_SELECTOR = 0x6Au;  /* NES selector for ending palette */
        ++M13_GAME_SUBMODE;
        return;
    }
    /* The common NMI timer owner decrements $4D every tenth tick. */

    mode13_hide_all_sprites();

    if (M13_ENDING_FLASH_TIMER < 0x04u) {
        return;  /* stop emitting + hide */
    }
    mode13_draw_link_zelda_triforces();

    /* Only Sub1 emits characters. Sub2 just delays. */
    if (M13_GAME_SUBMODE != 0x01u) {
        return;
    }
    if (M13_OBJ_TIMER_0 != 0u) {
        return;
    }
    mode13_update_peace_textbox();
}

/* Sub3: credits scroll (Z_02.asm:3508). Genesis caveat: nametable
 * vscroll happens via VSRAM register; Plane B not currently used for
 * credits. Port the NES RAM cell maintenance so state machine still
 * advances correctly; DrawCredits hook is no-op for now (full Plane B
 * scroll integration is a focused follow-up). */

static void mode13_sub3_credits(void)
{
    /* Every 8 scroll-units, redraw one credits tile row. */
    if (M13_CREDITS_TILE_OFFSET >= 0x08u) {
        M13_CREDITS_TILE_OFFSET = (unsigned char)(M13_CREDITS_TILE_OFFSET - 0x08u);
        mode13_draw_credits();
    }

    /* Add $80 to fractional scroll. Carry propagates to tile offset. */
    unsigned short sum = (unsigned short)M13_VSCROLL_ADDR_HI + 0x80u;
    M13_VSCROLL_ADDR_HI = (unsigned char)sum;
    unsigned char carry = (unsigned char)(sum >> 8);
    if (carry) {
        M13_CREDITS_TILE_OFFSET = (unsigned char)(M13_CREDITS_TILE_OFFSET + 1u);
    }

    unsigned short vsc = (unsigned short)M13_CUR_VSCROLL + carry;
    M13_CUR_VSCROLL = (unsigned char)vsc;
    unsigned char vsc_carry = 0u;
    if (vsc >= 0xF0u) {
        M13_CUR_VSCROLL = 0u;
        M13_VSCROLL_ADDR_LO = (unsigned char)(M13_VSCROLL_ADDR_LO + 1u);
        vsc_carry = 1u;
    }
    M13_SWITCH_NT_REQ = vsc_carry;

    /* NES: LDX CurSaveSlot / LDA QuestNumbers,X / BEQ Q1 else INY.
     * Genesis: roomrom_main_current_quest returns 1 (Q1) or 2 (Q2);
     * map to list index 0 (Q1) or 1 (Q2). */
    unsigned char y = (roomrom_main_current_quest() == 2u) ? 1u : 0u;

    if (M13_VSCROLL_ADDR_LO < k_credits_last_screen[y]) {
        return;
    }
    if (M13_CUR_VSCROLL < k_credits_last_vscroll[y]) {
        return;
    }
    ++M13_GAME_SUBMODE;
    M13_OBJ_TIMER_0 = 0x40u;
}

/* Sub4: hold triforce + Start-gate soft-reset (Z_02.asm:3461). */
static void mode13_sub4_finalize(void)
{
    mode13_hide_all_sprites();

    /* Skip ahead disabled for the first ObjTimer frames. */
    if (M13_OBJ_TIMER_0 != 0u) {
        return;
    }

    /* Start press → soft-reset to Mode $0D (save). NES does:
     *   EndGameMode + TurnOffAllVideo + TurnOffVideoAndClearArtifacts
     *   + SilenceAllSound + SwitchProfileToSecondQuest.
     * Our path: bump GameMode to $0D so mode_dispatch routes to Save.
     * The substrate paths (audio kill / video off / quest profile
     * switch) need cross-subsystem wiring; stub until follow-up. */
    if ((M13_BUTTONS_PRESSED & 0x10u) == 0u) {
        return;
    }
    mode13_end_game_mode();
    M13_GAME_MODE = 0x0Du;
}

void mode13_wingame_update(void)
{
    if (RAM(0x0011u) == 0u) { mode13_init(); return; }
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

unsigned char mode13_wingame_draws_link(void)
{
    return s_draw_link;
}
