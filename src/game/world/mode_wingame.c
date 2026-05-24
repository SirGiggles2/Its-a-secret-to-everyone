/* mode_wingame.c — Mode 0x13 WinGame dispatch (Tier 4 scaffold).
 *
 * NES source: reference/aldonunez/Z_02.asm:3236 UpdateMode13WinGame.
 * Drained C: NONE (no candidate row in tools/audit/drain_coverage.json
 * for mode 13). Per Drain Rule D1 with no drain candidate, stance =
 * GREENFIELD; NES asm is the spec.
 *
 * Submode state machine (Z_02.asm:3239 jump table):
 *   Sub0  flash + advance after $C0 frames (NATIVE)
 *   Sub1  Peace text part 1 — Link + Zelda + triforces + text scroller
 *   Sub2  Peace text part 2 — same body, delay-only
 *   Sub3  credits scroll (NATIVE: nametable scroll + DrawCredits hook)
 *   Sub4  end / soft-reset on Start (NATIVE: Start gate; soft-reset stubbed)
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
 *   PeaceCharDelayCounter   $0412
 *   PeaceCharIndex          $0413
 *   CreditsTileOffset       $050B
 *   VScrollAddrHi           $0058
 *   VScrollAddrLo           $00E2
 *   CurVScroll              $00FC
 *   SwitchNameTablesReq     $005C
 *   Tune0Request            $0604
 *   ButtonsPressed          $00F4
 *   DynTileBuf              $0302..$0325 (transfer-buf scratch)
 *   LevelInfo_PalettesTransferBuf  SRAM $6B7E (24 bytes palette template)
 */

#include "platform_abi.h"
#include "mode_wingame.h"

/* NES RAM aliases. */
#define M13_GAME_SUBMODE          RAM(0x0013u)
#define M13_GAME_MODE             RAM(0x0012u)
#define M13_OBJ_TIMER_0           RAM(0x0030u)
#define M13_ITEM_LIFT_TIMER       RAM(0x0506u)
#define M13_ENDING_FLASH_TIMER    RAM(0x004Du)
#define M13_PEACE_DELAY           RAM(0x0412u)
#define M13_PEACE_CHAR_INDEX      RAM(0x0413u)
#define M13_TUNE0_REQUEST         RAM(0x0604u)
#define M13_TILE_BUF_SELECTOR     RAM(0x0014u)
#define M13_BUTTONS_PRESSED       RAM(0x00F4u)
#define M13_CREDITS_TILE_OFFSET   RAM(0x050Bu)
#define M13_VSCROLL_ADDR_HI       RAM(0x0058u)
#define M13_VSCROLL_ADDR_LO       RAM(0x00E2u)
#define M13_CUR_VSCROLL           RAM(0x00FCu)
#define M13_SWITCH_NT_REQ         RAM(0x005Cu)
#define M13_DYN_TILE_BUF(off)     RAM((unsigned short)(0x0302u + (off)))

/* NES SRAM. */
#define M13_NES_SRAM_BASE                  0x6000u
#define M13_LEVEL_INFO_PALETTES_TRANSFER   0x0B7Eu  /* $6B7E - $6000 */

/* EndingFlashColors (Z_02.asm:3247): 4-color cycle for palette flash. */
static const unsigned char k_ending_flash_colors[4] = {
    0x0Fu, 0x12u, 0x16u, 0x2Au
};

/* PeaceTextboxCharTransferRecTemplate (Z_02.asm:3383): 5-byte template. */
static const unsigned char k_peace_textbox_template[5] = {
    0x22u, 0xA4u, 0x01u, 0x24u, 0xFFu
};

/* PeaceTextboxCharAddrsLo (Z_02.asm:3386): 52 VRAM-lo offsets. */
static const unsigned char k_peace_textbox_addrs_lo[52] = {
    0xACu, 0xADu, 0xAEu, 0xAFu, 0xB0u, 0xB1u, 0xB2u, 0xB3u,
    0xE4u, 0xE5u, 0xE6u, 0xE7u, 0xE8u, 0xE9u, 0xEAu, 0xEBu,
    0xECu, 0xEDu, 0xEEu, 0xEFu, 0xF0u, 0xF1u, 0xF2u, 0xF3u,
    0xF4u, 0xF5u, 0xF6u, 0xF7u, 0xF8u, 0xF9u, 0xFAu, 0xFBu,
    0x46u, 0x47u, 0x48u, 0x49u, 0x4Au, 0x4Bu, 0x4Cu, 0x4Du,
    0x4Eu, 0x4Fu, 0x50u, 0x51u, 0x52u, 0x53u, 0x54u, 0x55u,
    0x56u, 0x57u, 0x58u, 0x59u
};

/* PeaceText (Z_02.asm:3395): "FINALLY, PEACE RETURNS TO HYRULE.
 *                             THIS ENDS THE STORY,". 52 chars + $FF. */
static const unsigned char k_peace_text[53] = {
    0x0Fu, 0x12u, 0x17u, 0x0Au, 0x15u, 0x15u, 0x22u, 0x28u,
    0x19u, 0x0Eu, 0x0Au, 0x0Cu, 0x0Eu, 0x24u, 0x1Bu, 0x0Eu,
    0x1Du, 0x1Eu, 0x1Bu, 0x17u, 0x1Cu, 0x24u, 0x1Du, 0x18u,
    0x24u, 0x11u, 0x22u, 0x1Bu, 0x1Eu, 0x15u, 0x0Eu, 0x2Cu,
    0x1Du, 0x11u, 0x12u, 0x1Cu, 0x24u, 0x0Eu, 0x17u, 0x0Du,
    0x1Cu, 0x24u, 0x1Du, 0x11u, 0x0Eu, 0x24u, 0x1Cu, 0x1Du,
    0x18u, 0x1Bu, 0x22u, 0x2Cu, 0xFFu
};

/* Stubs — keep silent for now. Full HideAllSprites needs OAM-table
 * wipe in render_adapter (Plane A SAT clear) which is a follow-up.
 * DrawLinkZeldaTriforces needs item-sprite scaffolding for slot 2 +
 * slot 19 (cross-subsystem). For Sub1 character emit we ONLY need to
 * stamp into DynTileBuf — transfer_buf_drain emits the $22 records
 * into Plane A via the bridge added in commit 44395652. */
static void mode13_hide_all_sprites(void)            { /* Z_07.asm — TBD */ }
static void mode13_draw_link_zelda_triforces(void)   { /* Z_02.asm:3301 — TBD */ }
static void mode13_draw_credits(void)                { /* Z_02.asm DrawCredits — TBD */ }
static void mode13_end_game_mode(void)               { /* Z_05.asm:7487 — TBD */ }

/* Sub0: flash + DrawLinkZeldaTriforces (UNCHANGED from prior commit). */
static void mode13_sub0_flash(void)
{
    mode13_hide_all_sprites();

    M13_ITEM_LIFT_TIMER = (unsigned char)(M13_ITEM_LIFT_TIMER + 1u);

    unsigned char timer = M13_ITEM_LIFT_TIMER;

    if (timer == 0xC0u) {
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
    /* Bump TRANSFER_BUF_POS so transfer_buf_drain walks it. */
    RAM(0x0301u) = 5u;

    unsigned char y = (unsigned char)M13_PEACE_CHAR_INDEX;
    if (y >= sizeof k_peace_text) {
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
    unsigned char lo = (y < (unsigned char)sizeof k_peace_textbox_addrs_lo)
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
    M13_ENDING_FLASH_TIMER = (unsigned char)(M13_ENDING_FLASH_TIMER - 1u);

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
static const unsigned char k_credits_last_screen[2] = { 0x02u, 0x03u };
static const unsigned char k_credits_last_vscroll[2] = { 0x78u, 0x00u };

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

    /* Q1 quest = list[0] = $02 ; Q2 quest = list[1] = $03.
     * QuestNumbers read happens via inventory state; for Q1 baseline
     * use index 0. (TODO: thread quest selector from main state.) */
    unsigned char y = 0u;

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
