#include "save_menu_runtime.h"
#include "room_state.h"

extern const unsigned char ProfileNameAddrsLo[];
extern const unsigned char ProfileNameAddrsHi[];
extern void c_import_sram_commit(void);

/* C-callable bridges for native asm helpers still in z_05/z_07. */
extern void c_hide_all_sprites(void);                 /* z_07.HideAllSprites */
extern void c_update_player_position_marker(void);    /* z_01.UpdatePlayerPositionMarker */
extern void c_move_position_markers(unsigned int vel);
extern void c_update_triforce_position_marker(void);
extern void c_update_hearts_and_rupees(void);
extern void c_submenu_cue_transfer_row_uw(void);
extern void c_submenu_cue_transfer_row_ow(void);

/* Already-drained menu helpers (gen forwarders). */
extern void z05_update_menu_common2(void);
extern void z05_update_menu_common3(void);
extern void z05_update_menu_common4(void);
extern void z05_update_menu5_ow(void);

/* Other dispatch targets that remain native asm. */
extern void c_update_menu_active(void);
extern void c_update_menu_scroll_up(void);
extern void c_update_menu_start_ow(void);

void savert_update_mode_d_save_sub2(void) {
    c_import_sram_commit();
    MODE_VALUE = 0;
    SUBMODE_VALUE = 1;
}

void savert_fetch_profile_name_address(void) {
    unsigned char idx = SAVE_SLOT_INDEX;
    COMBAT_HARM_FLAG = ProfileNameAddrsLo[idx];
    COMBAT_THRESHOLD_X = ProfileNameAddrsHi[idx];
}

/* ----------------------------------------------------------------------
 * Menu / Meters / Item-Scroll-Down dispatchers (drained from z_05).
 * Original NES asm: src/zelda_translated/z_05.asm lines 180-398.
 * State byte: ROOM_STATE_INDEX ($00E1).
 * Dispatch differs by NES_CUR_LEVEL ($0010): 0 = OW, nonzero = UW.
 * -------------------------------------------------------------------- */

/* Forward declarations for the dispatcher's case targets. */
void savert_update_menu_common_1(void);
void savert_update_menu_5_uw(void);
void savert_update_menu_scroll_down_ow(void);
void savert_update_menu_scroll_down_uw(void);

/* UpdateMenu — UW vs. OW jump-table dispatch on ROOM_STATE_INDEX. */
void savert_update_menu(void) {
    unsigned char state = ROOM_STATE_INDEX;
    unsigned char level = RAM(NES_CUR_LEVEL);
    if (level != 0) {
        /* Underworld jump table. */
        switch (state) {
            case 0: /* UpdateMenu_Return */                       return;
            case 1: savert_update_menu_common_1();                 return;
            case 2: z05_update_menu_common2();                     return;
            case 3: z05_update_menu_common3();                     return;
            case 4: z05_update_menu_common4();                     return;
            case 5: savert_update_menu_5_uw();                     return;
            case 6: savert_update_menu_scroll_down_uw();           return;
            case 7: c_update_menu_active();                        return;
            case 8: c_update_menu_scroll_up();                     return;
            default: return;
        }
    } else {
        /* Overworld jump table. */
        switch (state) {
            case 0: /* UpdateMenu_Return */                       return;
            case 1: c_update_menu_start_ow();                      return;
            case 2: savert_update_menu_common_1();                 return;
            case 3: z05_update_menu_common2();                     return;
            case 4: z05_update_menu_common3();                     return;
            case 5: z05_update_menu_common4();                     return;
            case 6: z05_update_menu5_ow();                         return;
            case 7: savert_update_menu_scroll_down_ow();           return;
            case 8: c_update_menu_active();                        return;
            case 9: c_update_menu_scroll_up();                     return;
            default: return;
        }
    }
}

/* UpdateMenuAndMeters — wrapper that runs the menu update then refreshes
 * the on-screen hearts and rupees. */
void savert_update_menu_and_meters(void) {
    savert_update_menu();
    c_update_hearts_and_rupees();
}

/* UpdateMenuCommon1 — first frame of submenu scroll-down: hide sprites,
 * reset position markers, prime hardware vscroll/NT-switch and the
 * SubmenuScrollProgress / map-scan counters. */
void savert_update_menu_common_1(void) {
    c_hide_all_sprites();
    c_update_player_position_marker();
    c_update_triforce_position_marker();
    /* Move position markers and hardware vertical scroll position
     * down 1 pixel. Switch to NT 2 to be at the bottom of NT 2. */
    FRONTEND_CUR_VSCROLL = 0xEF;
    FRONTEND_NT_SWITCH_REQ = 0xEF;
    c_move_position_markers(1);
    ROOM_STATE_INDEX++;
    /* SubmenuScrollProgress begins at $2B; decremented per frame. */
    ROOM_MENU_SCROLL_POS = 43;
    /* In UW, this scans every room ($7F..0) to build the big sheet map. */
    RAM(0x005D) = 127;
}

/* UpdateMenu5UW — cue an UW submenu transfer row, then advance state. */
void savert_update_menu_5_uw(void) {
    c_submenu_cue_transfer_row_uw();
    ROOM_STATE_INDEX++;            /* _anon_z05_1: addq.b #1,($00E1,A4) */
}

/* UpdateMenuScrollDownOW / UpdateMenuScrollDownUW share a common tail
 * (_anon_z05_2): scroll the menu down 3 pixels, then once vscroll hits
 * $41 the position marker is laid out. */
static void savert_update_menu_scroll_common(void) {
    /* Move position markers and advance nametable scrolling so that
     * we scroll down 3 pixels. */
    c_move_position_markers(3);
    unsigned char vscroll = (unsigned char)(FRONTEND_CUR_VSCROLL - 3);
    FRONTEND_CUR_VSCROLL = vscroll;
    /* Nothing else to do until VScroll reaches $41. */
    if (vscroll != 0x41) return;
    /* VScroll reached $41 — advance submenu state. */
    ROOM_STATE_INDEX++;
    /* If in OW or in a cellar, we're done. */
    unsigned char level = RAM(NES_CUR_LEVEL);
    if (level == 0) return;
    if (MODE_VALUE == 0x09) return;
    /* Compute the X coordinate of the submenu position marker.
     * Mask the low nibble of room ID, multiply by 8 (tile width),
     * stash in scratch [00]. */
    unsigned char room_id = RAM(NES_CUR_ROOM_ID);
    unsigned char low_x = (unsigned char)((room_id & 0x0F) << 3);
    RAM(NES_TMP0) = low_x;
    /* Submenu map rotation lives in SRAM at $0BAB.
     * If >= 8, treat as a left rotation by ($10 - rotation). */
    unsigned char rotation = nes_ram[NES_SRAM_BASE + 0x0BAB];
    unsigned char offset;
    if (rotation < 0x08) {
        /* Short rotation: tiles to move right. Multiply by 8. */
        offset = (unsigned char)(rotation << 3);
    } else {
        /* Long rotation: ($10 - rotation) * 8, then negated. */
        offset = (unsigned char)(-(unsigned char)((16 - rotation) << 3));
    }
    /* Position marker X = scratch[00] + offset + $62. */
    unsigned char marker_x = (unsigned char)(low_x + offset + 0x62);
    RAM(0x0253) = marker_x;
    /* Marker Y = ((room_id & $F0) >> 1) + $69. */
    unsigned char marker_y = (unsigned char)(((room_id & 0xF0) >> 1) + 0x69);
    RAM(0x0250) = marker_y;
    /* Tile $3E (dot), attributes 0 (Link palette row 4). */
    RAM(0x0251) = 62;
    RAM(0x0252) = 0;
}

void savert_update_menu_scroll_down_ow(void) {
    c_submenu_cue_transfer_row_ow();
    savert_update_menu_scroll_common();
}

void savert_update_menu_scroll_down_uw(void) {
    c_submenu_cue_transfer_row_uw();
    savert_update_menu_scroll_common();
}
