/* Phase 9.7 — Mode 8 ContinueQuestion native rewrite.
 *
 * NES source: reference/aldonunez/Z_05.asm:2207-2306
 *             UpdateMode8ContinueQuestion_Full.
 *
 * Drained C: NONE. tools/audit/drain_coverage.json has no candidate
 * row for Mode 8. This file is the GREENFIELD native transcription
 * per Drain Rule D1 (NES asm wins ties — full per-line port below).
 *
 * Stance: REPLACE — verbatim per-line transcription of the NES asm
 * body. Touches the same RAM cells (GameSubmode $13, ObjTimer+1 $30,
 * Sprites OAM mirror, HeartValues, HeartPartial, GameMode,
 * IsUpdatingMode, DynTileBuf) as the transpiled equivalent that
 * lives at src/zelda_translated/z_05.asm.
 *
 * State machine (mirrors NES asm):
 *   Entry: ASL GameSubmode. Carry set (high bit set) -> animating
 *     selection. Carry clear -> input poll.
 *   Input poll:
 *     - Start pressed: ORA #$80 into GameSubmode (mark animating),
 *       ObjTimer+1 = $40 (flash 64 frames).
 *     - Select pressed: Tune0Request = 1 (rupee sound), GameSubmode
 *       cycles 0->1->2->0.
 *     - Else: redraw cursor sprite.
 *   Animate:
 *     - ObjTimer+1 = 0: handle activated; reset Link state, set
 *       GameMode per selection table, restore 3 hearts.
 *     - Else: flash NT attribute every 4 frames.
 *
 * Selection table (Mode8SelectionToMode):
 *   submode 0 = $03 Continue
 *   submode 1 = $0D Save
 *   submode 2 = $00 Retry  -> retry path also INC IsUpdatingMode
 */

#include "platform_abi.h"
#include "../../state/inventory.h"

/* NES RAM cells (per reference/aldonunez/Variables.inc + CommonVars.inc). */
#define MODE8_GAME_SUBMODE      RAM(0x0013u)
#define MODE8_OBJ_TIMER_1       RAM(0x0030u)  /* ObjTimer[1] = Link's timer */
#define MODE8_GAME_MODE         RAM(0x0012u)
#define MODE8_IS_UPDATING_MODE  RAM(0x0011u)
#define MODE8_TUNE0_REQUEST     RAM(0x0089u)
#define MODE8_HEART_VALUES      RAM(0x066Fu)  /* HeartValues */
#define MODE8_HEART_PARTIAL     RAM(0x0670u)  /* HeartPartial */

/* OAM mirror — first sprite slot (selection cursor sprite). NES OAM
 * lives at $0200..$02FF; Sprites+0 = Y, Sprites+1 = tile, Sprites+2
 * = attr, Sprites+3 = X. */
#define MODE8_SPRITE_Y          RAM(0x0200u)
#define MODE8_SPRITE_TILE       RAM(0x0201u)
#define MODE8_SPRITE_ATTR       RAM(0x0202u)
#define MODE8_SPRITE_X          RAM(0x0203u)

/* DynTileBuf — dynamic VRAM-write queue at $0500 (NES). 5-byte
 * transfer records: { vram_addr_hi, vram_addr_lo, ?, fill_byte,
 * terminator $FF }. */
#define MODE8_DYN_TILE_BUF(off) RAM((unsigned short)(0x0500u + (off)))

/* NES Z_05.asm:2192-2206 static tables, verbatim. */
static const unsigned char k_mode8_base_sprite_values[3] = {
    0xF3u, 0x02u, 0x40u  /* tile, attr, X */
};
static const unsigned char k_mode8_sprite_ys[3] = {
    0x4Fu, 0x67u, 0x7Fu  /* selection 0/1/2 cursor Y positions */
};
static const unsigned char k_mode8_selection_to_mode[3] = {
    0x03u, 0x0Du, 0x00u  /* Continue / Save / Retry */
};
static const unsigned char k_mode8_flash_transfer_record[5] = {
    0x23u, 0xD2u, 0x43u, 0x00u, 0xFFu  /* DynTileBuf header for NT-attr flash */
};
static const unsigned char k_mode8_flash_attrs_addr_lo[3] = {
    0xD2u, 0xDAu, 0xE2u  /* per-selection NT-attr low-byte */
};

/* NES Z_05.asm:1378 ButtonsPressed bit layout:
 *   bit 7 = right, 6 = left, 5 = down, 4 = up,
 *   bit 3 = start, 2 = select, 1 = B, 0 = A.
 * Z_05.asm:2214 AND #$10 = Start; :2217 AND #$20 = Select.
 * Adapter must populate RAM($00F7) ButtonsPressed before this call. */
#define MODE8_BUTTONS_PRESSED   RAM(0x00F7u)
#define MODE8_BTN_START         0x10u
#define MODE8_BTN_SELECT        0x20u

/* External — Phase 9.7 follow-up: ResetPlayerState, EndGameMode,
 * SilenceAllSound are NES routines not yet drained. Mode 8 calls
 * them at HandleActivated. Stubs here keep the link clean; real
 * drains land per their respective subsystem ports. */
static void mode8_reset_player_state(void)  { /* stub: ResetPlayerState NES Z_07.asm */ }
static void mode8_end_game_mode(void)       { /* stub: EndGameMode NES Z_07.asm */ }
static void mode8_silence_all_sound(void)   { /* stub: SilenceAllSound NES Z_07.asm */ }

/* ----- Sub-paths ----- */

static void mode8_draw_cursor(void)
{
    unsigned char submode = MODE8_GAME_SUBMODE & 0x03u;
    /* NES :2230-2235 — copy 3 bytes (tile, attr, X) into Sprites+1..+3
     * using NES "LDA Mode8BaseSpriteValues,Y / STA Sprites+1,Y / DEY /
     * BPL :-" loop with Y starting at 2. */
    MODE8_SPRITE_TILE = k_mode8_base_sprite_values[0];
    MODE8_SPRITE_ATTR = k_mode8_base_sprite_values[1];
    MODE8_SPRITE_X    = k_mode8_base_sprite_values[2];
    /* NES :2238-2240 — set Y by submode. */
    MODE8_SPRITE_Y = k_mode8_sprite_ys[submode];
}

static void mode8_activate_option(void)
{
    /* NES :2243-2249. */
    MODE8_GAME_SUBMODE = (unsigned char)(MODE8_GAME_SUBMODE | 0x80u);
    MODE8_OBJ_TIMER_1  = 0x40u;
}

static void mode8_animate_selection(void)
{
    unsigned char timer = MODE8_OBJ_TIMER_1;
    unsigned char submode_index;
    unsigned char i;

    /* NES :2252-2253. */
    if (timer == 0u) {
        /* @HandleActivated. */
        MODE8_GAME_SUBMODE = (unsigned char)(MODE8_GAME_SUBMODE & 0x03u);
        submode_index = MODE8_GAME_SUBMODE;
        mode8_reset_player_state();
        MODE8_GAME_MODE = k_mode8_selection_to_mode[submode_index];
        /* NES :2293-2298 — heart restore. */
        MODE8_HEART_VALUES  = (unsigned char)((MODE8_HEART_VALUES & 0xF0u) | 0x02u);
        MODE8_HEART_PARTIAL = 0xFFu;
        mode8_end_game_mode();
        /* NES :2300-2304 — Retry path increments IsUpdatingMode. */
        if (submode_index == 0x02u) {
            MODE8_GAME_SUBMODE = (unsigned char)(submode_index - 1u);
            MODE8_IS_UPDATING_MODE = (unsigned char)(MODE8_IS_UPDATING_MODE + 1u);
        }
        mode8_silence_all_sound();
        return;
    }

    /* NES :2256-2261 — copy 5-byte flash transfer record to DynTileBuf. */
    for (i = 0u; i < 5u; ++i) {
        MODE8_DYN_TILE_BUF(i) = k_mode8_flash_transfer_record[i];
    }
    /* NES :2265-2269 — patch lo byte by selection. */
    MODE8_DYN_TILE_BUF(1) = k_mode8_flash_attrs_addr_lo[MODE8_GAME_SUBMODE & 0x03u];
    /* NES :2270-2278 — every 4 frames pick attr 0x00 vs 0x55. */
    MODE8_DYN_TILE_BUF(3) = ((timer & 0x04u) != 0u) ? 0x55u : 0x00u;
}

/* ----- Entry ----- */

void mode8_continue_question_update(void)
{
    unsigned char submode = MODE8_GAME_SUBMODE;
    unsigned char buttons;

    /* NES :2208-2212 — ASL GameSubmode; carry set = animating. */
    if ((submode & 0x80u) != 0u) {
        mode8_animate_selection();
        return;
    }

    buttons = MODE8_BUTTONS_PRESSED;

    /* NES :2213-2215 — Start pressed -> activate. */
    if ((buttons & MODE8_BTN_START) != 0u) {
        mode8_activate_option();
        return;
    }

    /* NES :2216-2228 — Select pressed -> cycle submode 0->1->2->0. */
    if ((buttons & MODE8_BTN_SELECT) != 0u) {
        MODE8_TUNE0_REQUEST = 0x01u;
        submode = (unsigned char)(submode + 1u);
        if (submode == 0x03u) submode = 0x00u;
        MODE8_GAME_SUBMODE = submode;
    }

    mode8_draw_cursor();
}
