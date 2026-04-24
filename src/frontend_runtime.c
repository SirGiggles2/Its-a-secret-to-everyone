#include "frontend_runtime.h"
#include "room_state.h"
#include "world_state.h"
#include "item_state.h"
#include "cave_state.h"
#include "save_state.h"
#include "enemy_state.h"

void frontdemo_animate_phase1_sub0(void) {
    if (FRAME_COUNTER & 0x01) {
        FRONTEND_CUR_VSCROLL++;
        if (FRONTEND_CUR_VSCROLL == 0xF0) {
            FRONTEND_SCROLL_SCREEN_COUNT++;
            FRONTEND_CUR_VSCROLL = 0;
            FRONTEND_NT_SWITCH_REQ++;
        }
    }
    if (FRONTEND_CUR_VSCROLL == 0x08 && FRONTEND_SCROLL_SCREEN_COUNT != 0) {
        FRONTEND_SCROLL_SCREEN_COUNT = 0;
        FRONTEND_DEMO_SUBPHASE++;
    }
}

void frontdemo_animate_phase1_sub1(void) {
    FRONTEND_DEMO_TIMER++;
    if (FRONTEND_DEMO_TIMER == 0)
        FRONTEND_DEMO_SUBPHASE++;
    FRONTEND_DEMO_LINE_TILE_HI = 41;
    FRONTEND_DEMO_LINE_TILE_LO = 0;
    FRONTEND_DEMO_LINE_ATTR_HI = 43;
    FRONTEND_DEMO_LINE_ATTR_LO = 0xE0;
}

void frontdemo_disable_fallen_objects(void) {
    unsigned char x;
    for (x = 10; x >= 1; x--) {
        if (OBJ_Y(x) == 0xF0)
            OBJ_STATE(x) = 0xFF;
    }
}

void frontdemo_init_mode1_sub2(void) {
    ROOM_TRANSFER_BUF_SELECT = 20;
    SUBMODE_VALUE++;
}

void frontdemo_end_init_demo(unsigned int val) {
    ROOM_TRANSFER_BUF_SELECT = (unsigned char)val;
    FRONTEND_DEMO_SUBPHASE = 0;
    ROOM_MODE_TIMER++;
}

void frontdemo_inc_subphase(void) {
    FRONTEND_DEMO_SUBPHASE++;
}

void frontdemo_animate_p1_end(void) {
    z07_hide_all_sprites();
    c_import_demo_animate_objects();
}

void frontdemo_animate_p1_sub3(void) {
    FRONTEND_DEMO_TIMER++;
    if (FRONTEND_DEMO_TIMER == 0)
        FRONTEND_DEMO_SUBPHASE++;
    else
        frontdemo_animate_p1_end();
}

void frontdemo_init_demo_subphase_play_title_song(void) {
    ITEM_SFX_SECONDARY = 0x80;
    frontdemo_end_init_demo(16);
}

void frontdemo_init_mode13_sub3(void) {
    if (CAVE_DELAY_TIMER != 0)
        return;
    z01_silence_all_sound();
    SUBMODE_VALUE++;
}

void frontdemo_init_mode13_sub4(void) {
    FRONTEND_CREDITS_TILE_OFFSET = 8;
    z01_begin_update_mode();
    ROOM_PUSH_TIMER = 0;
    CAVE_FLAGS = 0;
    z07_hide_all_sprites();
}

void frontname_reset_variables(unsigned int val) {
    FRONTEND_CHAR_BOARD_INDEX = (unsigned char)val;
    FRONTEND_NAME_FIELD_INIT = (unsigned char)val;
    FRONTEND_NAME_CHAR_OFFSET = (unsigned char)val;
}

void frontname_reset_button_repeat_state(unsigned int val) {
    FRONTEND_BUTTON_HELD = (unsigned char)val;
    FRONTEND_BUTTON_REPEAT_STATE = (unsigned char)val;
    FRONTEND_BUTTON_REPEAT_TIMER = (unsigned char)val;
}

void frontname_set_name_cursor_sprite_x(void) {
    FRONTEND_SPRITE_CURSOR_X = LINK_X;
}

void frontname_sync_char_board_cursor(void) {
    unsigned char idx = FRONTEND_CHAR_BOARD_INDEX;
    unsigned char row = 0;
    if (idx & 0x80)
        idx += 44;
    if (idx >= 44)
        idx -= 44;
    if (idx == 43)
        idx = 9;
    FRONTEND_CHAR_BOARD_INDEX = idx;
    while (idx >= 11) {
        idx -= 11;
        row++;
    }
    FRONTEND_NAME_CURSOR_X = (unsigned char)((idx << 4) + 0x30);
    FRONTEND_NAME_CURSOR_Y = (unsigned char)((row << 4) + 0x88);
}

void frontutil_add_a_to_0f0e(unsigned int val) {
    unsigned int sum = (unsigned char)val + FRONTEND_ADD16_LO;
    FRONTEND_ADD16_LO = (unsigned char)sum;
    FRONTEND_ADD16_HI = (unsigned char)(FRONTEND_ADD16_HI + (sum >> 8));
}

void frontutil_add_a_to_cfce(unsigned int val) {
    unsigned int sum = (unsigned char)val + FRONTEND_SAVE_ADD16_LO;
    FRONTEND_SAVE_ADD16_LO = (unsigned char)sum;
    FRONTEND_SAVE_ADD16_HI = (unsigned char)(FRONTEND_SAVE_ADD16_HI + (sum >> 8));
}

/* ============================================================================
 * Demo / intro mode dispatcher family — ported from z_02.asm
 *   InitDemo_RunTasks, InitDemo_Phase1
 *   UpdateMode0Demo, UpdateMode0Demo_Sub0, UpdateMode0Demo_Sub2
 *   AnimateDemo, AnimateDemo_Phase1
 * Original M68K jump-table dispatch is replaced with C switches. The
 * subphase callees remain in z_02.asm and are reached through IMPORT shims.
 * ============================================================================ */

void frontdemo_init_demo_phase_1(void) {
    /* Phase-1 subphase dispatch (jump table replaced by switch). */
    switch (FRONTEND_DEMO_SUBPHASE) {
        case 0: c_import_init_demo_subphase_clear_artifacts(); break;
        case 1: c_import_init_demo_subphase_transfer_story_palette(); break;
        case 2: c_import_init_demo_subphase_transfer_story_tiles(); break;
        default: break;
    }
}

void frontdemo_init_demo_run_tasks(void) {
    c_turn_off_all_video();
    if (RAM(0x042C) != 0) {
        frontdemo_init_demo_phase_1();
        return;
    }
    /* Phase-0 subphase dispatch. */
    switch (FRONTEND_DEMO_SUBPHASE) {
        case 0: c_import_init_demo_subphase_clear_artifacts(); break;
        case 1: c_import_init_demo_subphase_transfer_title_palette(); break;
        case 2: c_import_init_demo_subphase_play_title_song(); break;
        default: break;
    }
}

void frontdemo_update_mode0_demo_sub0(void) {
    /* Wait until controller bit 4 (Start) is held, then arm next phase. */
    unsigned char btn = CAVE_LINK_INPUT_FLAGS;
    if (!(btn & 0x10)) return;

    /* PATCH P11: hold VRamForceBlankGate. */
    RAM(0x083D) = 1;
    /* PATCH P12: arm FrontendStartReleaseGate. */
    RAM(0x042B) = 1;

    RAM(0x00F6) = 0x10;          /* D0 was AND #$10 → BNE taken means bit4 set */
    ITEM_SFX_SECONDARY = 0;      /* clear primary SFX */
    z01_silence_all_sound();
    RAM(0x0528) = 90;            /* delay timer */
    SUBMODE_VALUE += 1;          /* advance submode */
    c_turn_off_all_video();
    c_hide_all_sprites();
    ROOM_TRANSFER_BUF_SELECT = 18; /* room transfer buf select */
}

/* UpdateMode0Demo_Sub2 — copy save-file A data into save-slot info, format
 * any inactive slots, then fold heart values and copy names. */
void frontdemo_update_mode0_demo_sub2(void) {
    unsigned char d3, d2;
    unsigned int base;

    c_turn_off_all_video();
    SAVE_SLOT_INDEX = 0;
    z01_fetch_file_a_address_set();

    /* Loop over slots 2..0, formatting any that aren't active. */
    d3 = 2;
    while ((signed char)d3 >= 0) {
        unsigned char val;

        /* Read IsSaveSlotActive[d3] via ptr in $06/$07 → store at $0633+d3. */
        base = ((unsigned int)RAM(0x07) << 8) | RAM(0x06);
        val = nes_ram[base + d3];
        nes_ram[0x0633 + d3] = val;

        if (val == 0) {
            unsigned char saved_d3 = d3;
            SAVE_SLOT_INDEX = d3;
            z01_fetch_file_a_address_set();
            c_import_format_file_a();
            SAVE_SLOT_INDEX = 0;
            /* Refetch slot 0 set so $06/$07 (and other ptrs) are restored. */
            z01_fetch_file_a_address_set();
            d3 = saved_d3;
        }

        /* ContinueCount via ptr in $0A/$0B → store at $0630+d3. */
        base = ((unsigned int)RAM(0x0B) << 8) | RAM(0x0A);
        CONTINUE_COUNT(d3) = nes_ram[base + d3];

        /* DeathCount via ptr in $0C/$0D → store at $062D+d3. */
        base = ((unsigned int)RAM(0x0D) << 8) | RAM(0x0C);
        SAVE_SLOT_QUEST(d3) = nes_ram[base + d3];

        d3 = (unsigned char)(d3 - 1);
    }

    /* Heart loop: 6 entries, alternating (containers, partial). */
    d3 = 24;
    d2 = 0;
    while (d2 != 6) {
        base = ((unsigned int)SAVEFILE_PTR_HI << 8) | SAVEFILE_PTR_LO;
        unsigned char raw = nes_ram[base + d3];
        unsigned char store;

        if (d2 & 0x01) {
            /* Odd index: hearts-partial slot — store raw byte. */
            store = raw;
        } else {
            /* Even index: hearts-value slot — collapse high nibble into low,
             * mirror containers into hearts so display matches max HP. */
            unsigned char hi = raw & 0xF0;
            ROOM_TOUCH_DOOR_BITS = hi;
            store = (unsigned char)((hi >> 4) | hi);
        }
        nes_ram[0x0650 + d2] = store;

        d3 = (unsigned char)(d3 + 1);
        d2 = (unsigned char)(d2 + 1);

        if (d2 == 6) break;
        /* If d2 is now odd we stay on the same slot's partial byte. If even
         * we advance d3 by $26 to step into the next slot's hearts pair. */
        if (!(d2 & 0x01)) {
            d3 = (unsigned char)(d3 + 0x26);
        }
    }

    /* Name copy: 24 bytes via ptr in $04/$05 → $0638 buffer. */
    d3 = 23;
    do {
        base = ((unsigned int)RAM(0x05) << 8) | RAM(0x04);
        nes_ram[0x0638 + d3] = nes_ram[base + d3];
        d3 = (unsigned char)(d3 - 1);
    } while ((signed char)d3 >= 0);

    MODE_VALUE += 1;
    ROOM_MODE_TIMER = 0;
    SUBMODE_VALUE = 0;
}

void frontdemo_update_mode0_demo(void) {
    /* If submode != 0 OR delay $0528 != 0, dispatch submode handler. */
    if (SUBMODE_VALUE == 0 && RAM(0x0528) == 0) {
        frontdemo_animate_demo();
        if (ROOM_MODE_TIMER == 0) return;   /* Exit if no mode-prev change pending. */
        /* Fall through to submode dispatch. */
    }
    switch (SUBMODE_VALUE) {
        case 0: frontdemo_update_mode0_demo_sub0(); break;
        case 1: c_import_update_mode0_demo_sub1(); break;
        case 2: frontdemo_update_mode0_demo_sub2(); break;
        default: break;
    }
}

void frontdemo_animate_phase_1(void) {
    switch (FRONTEND_DEMO_SUBPHASE) {
        case 0: c_import_animate_demo_phase1_subphase0(); break;
        case 1: c_import_animate_demo_phase1_subphase1(); break;
        case 2: c_import_animate_demo_phase1_subphase2(); break;
        case 3: c_import_animate_demo_phase1_subphase3(); break;
        case 4: frontdemo_animate_demo_phase1_subphase4(); break;
        default: break;
    }
}

void frontdemo_animate_demo(void) {
    if (RAM(0x042C) != 0) {
        frontdemo_animate_phase_1();
        return;
    }
    switch (FRONTEND_DEMO_SUBPHASE) {
        case 0: c_import_animate_demo_phase0_subphase0(); break;
        case 1: c_import_animate_demo_phase0_subphase1(); break;
        default: break;
    }
}

static const unsigned char kTitlePaletteTransferRecord[36] = {
    0x3F,0x00,0x20,0x36,0x0F,0x00,0x10,0x36,0x17,0x27,0x0F,0x36,0x08,0x1A,0x28,0x36,
    0x30,0x3B,0x22,0x36,0x30,0x3B,0x16,0x36,0x17,0x27,0x0F,0x36,0x08,0x1A,0x28,0x36,
    0x30,0x3B,0x22,0xFF
};

void frontdemo_init_demo_subphase_transfer_title_palette(void) {
    int i;
    RAM(0x0300) = 35;
    RAM(0x0301) = 35;
    for (i = 35; i >= 0; i--) {
        RAM(0x0302 + i) = kTitlePaletteTransferRecord[i];
    }
    RAM(0x042E) = 0;
    RAM(0x042F) = 0;
    for (i = 10; i >= 0; i--) {
        RAM(0x0412 + i) = 0;
        RAM(0x041F + i) = 0;
        RAM(0x0437 + i) = 0;
    }
    for (i = 10; i >= 1; i--) {
        RAM(0x00AC + i) = 0xFF;
    }
    frontdemo_inc_subphase();
}

static const unsigned char kStoryPaletteTransferRecord[36] = {
    0x3F,0x00,0x20,0x0F,0x30,0x30,0x30,0x0F,0x21,0x30,0x30,0x0F,0x16,0x30,0x30,0x0F,
    0x29,0x1A,0x09,0x0F,0x29,0x37,0x17,0x0F,0x02,0x22,0x30,0x0F,0x16,0x27,0x30,0x0F,
    0x0B,0x1B,0x2B,0xFF
};

void frontdemo_init_demo_subphase_transfer_story_palette(void) {
    int i;
    RAM(0x0300) = 35;
    RAM(0x0301) = 35;
    for (i = 35; i >= 0; i--) {
        RAM(0x0302 + i) = kStoryPaletteTransferRecord[i];
    }
    for (i = 10; i >= 0; i--) {
        RAM(0x0412 + i) = 0;
        RAM(0x041F + i) = 0;
        RAM(0x0437 + i) = 0;
        RAM(0x0444 + i) = 0;
    }
    frontdemo_inc_subphase();
}

void frontdemo_animate_demo_phase1_subphase4(void) {
    RAM(0x041A)++;
    if (RAM(0x041A) == 0x39) {
        RAM(0x0011) = 0;
        RAM(0x041A) = 0;
        RAM(0x042C) = 0;
        RAM(0x042D) = 0;
        return;
    }
    frontdemo_animate_p1_end();
}
