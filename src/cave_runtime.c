#include "cave_runtime.h"
#include "combat_state.h"

extern unsigned char z07_anim_fetch_obj_pos(unsigned int slot);
extern void c_draw_object_mirrored(unsigned int slot);
extern void c_draw_object_not_mirrored(unsigned int slot);
extern void c_animate_item_object(unsigned char item_type, unsigned int slot);
extern void c_link_end_move_and_draw_bank1(void);
extern void z01_inc_cave_state(void);
extern void z01_post_credit(unsigned int val);
extern void z01_post_debit(unsigned int amount);
extern void z01_copy_price_list_template(void);
extern void z01_cue_transfer_buf_and_advance_state(unsigned int val);
extern void z01_cue_transfer_blank_person_wares(void);
extern void z01_unhalt_link(void);
extern void z01_set_up_common_cave_objects(unsigned int x, unsigned int slot, unsigned int y);
extern unsigned char z01_abs(unsigned int val);
extern void c_take_item(unsigned char item_type);
extern void z01_take_item(unsigned char item_type);
extern unsigned char progrt_get_room_flag_uw_item_state(void);
extern void progrt_set_room_flag_uw_item_state(void);
extern const unsigned char CaveWareXs[];
extern const unsigned char HintCaveTextSelectors0[];
extern const unsigned char OverworldPersonTextSelectors[];
extern const unsigned char MoneyGameLossAmounts[];
extern const unsigned char MoneyGamePermutations[];
extern const unsigned char MoneyGamePermutationEndIndexes[];
extern const unsigned char TextboxLineAddrsLo[];
extern const unsigned char PersonTextAddrs[];
extern const unsigned char TextboxCharTransferRecTemplate[];

#define NES_SRAM_BASE 0x6000u

static void cavert_init_cave_continue(void) {
    unsigned char cave_idx = (unsigned char)(CAVE_ROOM_TYPE - 0x6A);
    unsigned char sel_byte = OverworldPersonTextSelectors[cave_idx];
    CAVE_TEXT_SELECTOR = sel_byte & 0x3F;
    CAVE_TMP3 = sel_byte & 0xC0;
    {
        unsigned char ware_off = (unsigned char)(3 * cave_idx);
        for (unsigned char i = 0; i < CAVE_WARES_PER_ROOM; i++) {
            unsigned char item = nes_ram[NES_SRAM_BASE + 0x0A7E + ware_off + i];
            CAVE_WARE_ITEM(i) = item;
            RAM(i) = item & 0xC0;
            CAVE_PRICE(i) = nes_ram[NES_SRAM_BASE + 0x0ABA + ware_off + i];
        }
    }
    {
        unsigned char cave_flags = (unsigned char)(CAVE_TMP3 >> 6)
                                 | CAVE_TMP0
                                 | (unsigned char)(CAVE_TMP2 >> 4)
                                 | (unsigned char)(CAVE_TMP1 >> 2);
        CAVE_FLAGS = cave_flags;
        if (cave_flags & 0x20) {
            unsigned char thresh = 0xFF;
            unsigned char perm_idx = 6;
            while (thresh >= CAVE_RANDOM_A) {
                thresh = (unsigned char)(thresh - 0x2B);
                perm_idx--;
                if (perm_idx == 0) {
                    break;
                }
            }
            {
                unsigned char end_idx = MoneyGamePermutationEndIndexes[perm_idx];
                CAVE_MONEY_GAME_PERM(2) = MoneyGamePermutations[end_idx];
                CAVE_MONEY_GAME_PERM(1) = MoneyGamePermutations[(unsigned char)(end_idx - 1)];
                CAVE_MONEY_GAME_PERM(0) = MoneyGamePermutations[(unsigned char)(end_idx - 2)];
            }
            CAVE_MONEY_GAME_AMOUNT(0) = MoneyGameLossAmounts[CAVE_RANDOM_B & 1];
            CAVE_MONEY_GAME_AMOUNT(1) = 10;
            CAVE_MONEY_GAME_AMOUNT(2) = (CAVE_RANDOM_B & 2) ? 50 : 20;
            for (signed int j = 2; j >= 0; j--) {
                unsigned char perm = CAVE_MONEY_GAME_PERM((unsigned char)j);
                CAVE_PRIZE_ORDER((unsigned char)j) = CAVE_MONEY_GAME_AMOUNT(perm);
            }
        }
    }
    CAVE_TEXT_CHAR_INDEX = 0;
    CAVE_TEXT_LINE_ADDR_LO = TextboxLineAddrsLo[2];
}

static void cavert_prepend_sign_to_price(unsigned char val, unsigned char off) {
    unsigned char sign = (val == 0x14 || val == 0x32) ? 100 : 98;
    CAVE_TRANSFER_BUF_PRICE_SIGN(off) = sign;
}

static unsigned char cavert_swap_space_and_sign(unsigned char d0) {
    if (d0 == 0x24) {
        unsigned char tmp = CAVE_TMP4;
        CAVE_TMP4 = d0;
        d0 = tmp;
    }
    return d0;
}

void cavert_clear_prices_cave_flag(void) {
    CAVE_FLAGS &= 0xF7;
}

void cavert_update_person_state_delay_then_hide(void) {
    if (CAVE_DELAY_TIMER == 0) {
        CAVE_ROOM_TYPE = 0;
    }
}

void cavert_format_decimal_byte(unsigned char val) {
    unsigned char units = val % 10;
    unsigned char rest = val / 10;
    unsigned char tens = rest % 10;
    unsigned char hundreds = rest / 10;
    CAVE_TMP3 = units;
    if (hundreds == 0) {
        hundreds = 0x24;
        if (tens == 0) {
            tens = 0x24;
        }
    }
    CAVE_TMP2 = tens;
    CAVE_TMP1 = hundreds;
}

void cavert_write_prices_to_dynamic_transfer_buf(unsigned char price_char) {
    unsigned char price_index = 0;
    RAM(0x0305) = price_char;
    CAVE_TRANSFER_PRICE_COUNT = 0;
    CAVE_TRANSFER_PRICE_OFFSET = 0;
    do {
        unsigned char price = CAVE_PRICE(price_index);
        unsigned char dash;
        unsigned char off;
        if (price == 0) {
            CAVE_TMP1 = 0x24;
            CAVE_TMP2 = 0x24;
            CAVE_TMP3 = 0x24;
        } else {
            cavert_format_decimal_byte(price);
        }
        dash = (CAVE_FLAGS & 0x80) ? 98 : 0x24;
        CAVE_TMP4 = dash;
        off = CAVE_TRANSFER_PRICE_OFFSET;
        CAVE_TRANSFER_BUF_PRICE_TENS(off) = cavert_swap_space_and_sign(CAVE_TMP2);
        CAVE_TRANSFER_BUF_PRICE_HUNDREDS(off) = cavert_swap_space_and_sign(CAVE_TMP1);
        CAVE_TRANSFER_BUF_PRICE_UNITS(off) = CAVE_TMP3;
        CAVE_TRANSFER_PRICE_OFFSET = off + 4;
        price_index++;
        CAVE_TRANSFER_PRICE_COUNT = price_index;
    } while (price_index < CAVE_WARES_PER_ROOM);
    CAVE_DELAY_TIMER = 10;
    z01_cue_transfer_buf_and_advance_state(10);
}

void cavert_write_prices_transfer_buf(void) {
    z01_copy_price_list_template();
    cavert_write_prices_to_dynamic_transfer_buf(33);
}

void cavert_update_person_state_textbox(void) {
    unsigned char ch;
    unsigned char char_idx;
    unsigned short ptr;
    c_link_end_move_and_draw_bank1();
    if (CAVE_DELAY_TIMER != 0) {
        return;
    }
    CAVE_DELAY_TIMER = 6;
    for (signed int i = 4; i >= 0; i--) {
        RAM(CAVE_TRANSFER_BUF_CHAR_BASE + (unsigned char)i) = TextboxCharTransferRecTemplate[(unsigned char)i];
    }
    do {
        RAM(0x0303) = CAVE_TEXT_LINE_ADDR_LO;
        CAVE_TEXT_LINE_ADDR_LO++;
        CAVE_TMP0 = PersonTextAddrs[CAVE_TEXT_SELECTOR];
        CAVE_TMP1 = PersonTextAddrs[CAVE_TEXT_SELECTOR + 1];
        char_idx = CAVE_TEXT_CHAR_INDEX;
        CAVE_TEXT_CHAR_INDEX++;
        ptr = ((unsigned short)CAVE_TMP1 << 8) | CAVE_TMP0;
        ch = nes_ram[ptr + char_idx] & 0x3F;
    } while (ch == 0x25);
    RAM(0x0305) = ch;
    CAVE_TEXT_TICK_SFX = 16;
    {
        unsigned char line_flags = nes_ram[ptr + char_idx] & 0xC0;
        unsigned char line_index;
        if (line_flags == 0) {
            return;
        }
        if (line_flags == 0xC0) {
            line_index = 2;
        } else if (line_flags == 0x40) {
            line_index = 1;
        } else {
            line_index = 0;
        }
        CAVE_TEXT_LINE_ADDR_LO = TextboxLineAddrsLo[line_index];
        if (line_index == 2) {
            CAVE_PERSON_STATE++;
            z01_unhalt_link();
        }
    }
}

void cavert_init_cave(unsigned int slot) {
    z01_set_up_common_cave_objects(120, slot, 0x80);
    {
        unsigned char room_type = CAVE_ROOM_TYPE;
        if (room_type == 0x72 || room_type == 0x71 || room_type >= 0x7B || room_type < 0x6E) {
            if (progrt_get_room_flag_uw_item_state() != 0) {
                CAVE_ROOM_TYPE = 0;
                z01_unhalt_link();
                return;
            }
        }
    }
    cavert_init_cave_continue();
}

void cavert_draw_cave_person(unsigned int slot) {
    z07_anim_fetch_obj_pos(slot);
    if ((unsigned char)CAVE_ROOM_TYPE < 0x7B)
        c_draw_object_mirrored(slot);
    else
        c_draw_object_not_mirrored(slot);
}

void cavert_draw_cave_items(void) {
    if (CAVE_FLAGS & 4) {
        CAVE_ACTIVE_WARE_INDEX = 2;
        do {
            unsigned char i = CAVE_ACTIVE_WARE_INDEX;
            unsigned char item;
            RAM(0x0083) = CaveWareXs[i];
            RAM(0x0097) = 0x98;
            item = CAVE_WARE_ITEM(i) & 0x3F;
            if (item != 0x3F)
                c_animate_item_object(item, CAVE_WARE_DRAW_SLOT);
            CAVE_ACTIVE_WARE_INDEX--;
        } while ((signed char)CAVE_ACTIVE_WARE_INDEX >= 0);
    }
    if (CAVE_FLAGS & 8) {
        RAM(0x0083) = 48;
        RAM(0x0097) = 0xAB;
        c_animate_item_object(24, CAVE_WARE_DRAW_SLOT);
    }
}

void cavert_update_transfer_prices(void) {
    if (!(CAVE_FLAGS & 8)) {
        z01_inc_cave_state();
        return;
    }
    cavert_write_prices_transfer_buf();
}

void cavert_update_talk_shop_or_door_charge(void) {
    signed int i;
    if (!(CAVE_FLAGS & 1)) {
            CAVE_PERSON_STATE = 8;
            if (CAVE_ROOM_TYPE == 0x71) {
                CAVE_DOOR_REPAIR_RUPEE_DELTA += 20;
                progrt_set_room_flag_uw_item_state();
            }
            return;
        }
    if (CAVE_DOOR_REPAIR_RUPEE_DELTA != 0)
        return;
    for (i = 2; i >= 0; --i) {
        unsigned char item;
        unsigned char dist;
        unsigned char flags30;
        item = CAVE_WARE_ITEM(i) & 0x3F;
        if (item == 0x3F)
            continue;
        if (RAM(0x0070) != CaveWareXs[i])
            continue;
        dist = z01_abs((unsigned int)(unsigned char)(RAM(0x0084) - 0x98));
        if (dist >= 6)
            continue;
        CAVE_SELECTED_WARE_INDEX = (unsigned char)i;
        flags30 = CAVE_FLAGS & 0x30;
        if (flags30) {
            if (!(flags30 & 0x10)) {
                CAVE_PERSON_STATE = 5;
                return;
            }
            if (LINK_RUPEES < CAVE_PRICE(i))
                return;
            z01_post_debit(CAVE_PRICE(i));
            CAVE_PERSON_STATE = 5;
            return;
        }
        if (CAVE_FLAGS & 2) {
            if (LINK_RUPEES < CAVE_PRICE(i))
                return;
            z01_post_debit(CAVE_PRICE(i));
        }
        if (CAVE_FLAGS & 0x40) {
            unsigned char min_hearts = (CAVE_ROOM_TYPE == 0x6C) ? 64 : 0xB0;
            if (min_hearts < LINK_HEARTS)
                return;
        }
        progrt_set_room_flag_uw_item_state();
        CAVE_WARE_ITEM(i) = 0xFF;
        c_take_item(item);
        z01_cue_transfer_buf_and_advance_state(30);
        CAVE_DELAY_TIMER = 64;
        cavert_clear_prices_cave_flag();
        return;
    }
}

void cavert_update_hint_or_money_game(void) {
    if (CAVE_FLAGS & 0x10) {
        unsigned char base_off = (CAVE_ROOM_TYPE == 0x75) ? 0 : 3;
        unsigned char sel_idx = base_off + CAVE_SELECTED_WARE_INDEX;
        CAVE_TEXT_SELECTOR = HintCaveTextSelectors0[sel_idx];
        CAVE_TEXT_LINE_ADDR_LO = TextboxLineAddrsLo[2];
        CAVE_TEXT_CHAR_INDEX = 0;
        cavert_clear_prices_cave_flag();
        z01_cue_transfer_buf_and_advance_state(30);
        return;
    }
    if ((unsigned char)CAVE_ROOM_TYPE >= 0x7B) {
        z01_copy_price_list_template();
        cavert_write_prices_to_dynamic_transfer_buf(36);
        CAVE_TEXT_TICK_SFX = 8;
        progrt_set_room_flag_uw_item_state();
        CAVE_PERSON_STATE = 8;
        z01_post_credit(CAVE_PRICE(1));
        return;
    }
    if ((unsigned char)LINK_RUPEES < 0x0A)
        return;
    CAVE_TEXT_TICK_SFX = 8;
    CAVE_PRICE(0) = CAVE_PRIZE_ORDER(0);
    CAVE_PRICE(1) = CAVE_PRIZE_ORDER(1);
    CAVE_PRICE(2) = CAVE_PRIZE_ORDER(2);
    cavert_write_prices_transfer_buf();
    CAVE_PERSON_STATE = 8;
    cavert_prepend_sign_to_price(CAVE_PRIZE_ORDER(0), 1);
    cavert_prepend_sign_to_price(CAVE_PRIZE_ORDER(1), 5);
    cavert_prepend_sign_to_price(CAVE_PRIZE_ORDER(2), 9);
    {
        unsigned char chosen = CAVE_SELECTED_WARE_INDEX;
        unsigned char amount = CAVE_PRIZE_ORDER(chosen);
        if (amount == 0x14 || amount == 0x32)
            z01_post_credit(amount);
        else
            z01_post_debit(amount);
    }
}

void cavert_update_cave_person(unsigned int slot) {
    unsigned char state = CAVE_PERSON_STATE;
    if (!(state == 4 && (RAM(0x0015) & 1))) {
        cavert_draw_cave_person(slot);
        if (CAVE_ROOM_TYPE == 0x74 && CAVE_ROOM_SCRIPT_STATE != 2) {
            if (RAM(0x0656) == 0x0F && (CAVE_LINK_INPUT_FLAGS & 0x40)) {
                RAM(0x0602) = 4;
                CAVE_ROOM_SCRIPT_STATE++;
                RAM(0x0656) = 7;
            } else {
                if (CAVE_LINK_ACTION_TIMER == 0x40)
                    z01_unhalt_link();
                return;
            }
        }
        cavert_draw_cave_items();
    }
    switch (CAVE_PERSON_STATE) {
        case 0: cavert_update_transfer_prices(); break;
        case 1: cavert_update_person_state_textbox(); break;
        case 2: cavert_update_talk_shop_or_door_charge(); break;
        case 3: z01_cue_transfer_blank_person_wares(); break;
        case 4: cavert_update_person_state_delay_then_hide(); break;
        case 5: cavert_update_hint_or_money_game(); break;
        case 6: z01_cue_transfer_blank_person_wares(); break;
        case 7: cavert_update_person_state_textbox(); break;
        case 8: break;
    }
}

void cavert_try_take_item(unsigned int slot) {
    if (RAM(0x03A8 + slot) >= 0xF0) {
        return;
    }
    {
        unsigned char dy = (unsigned char)(RAM(0x0084) + 3 - OBJ_Y(slot));
        if (z01_abs(dy) >= 9) {
            return;
        }
    }
    {
        unsigned char dx = (unsigned char)(RAM(0x0070) - OBJ_X(slot));
        if (z01_abs(dx) >= 9) {
            return;
        }
    }
    OBJ_STATE(slot) = 0xFF;
    OBJ_Y(slot) = 0xFF;
    if (slot == CAVE_WARE_DRAW_SLOT) {
        progrt_set_room_flag_uw_item_state();
    }
    z01_take_item(CAVE_TMP4);
}

void cavert_try_take_room_item(void) {
    unsigned int slot = CAVE_WARE_DRAW_SLOT;
    if ((CAVE_LINK_ACTION_TIMER & 0xC0) == 0x40) {
        return;
    }
    if (progrt_get_room_flag_uw_item_state() != 0) {
        return;
    }
    if (OBJ_STATE(slot) & 0x80) {
        return;
    }
    CAVE_TMP4 = OBJ_DIR(slot);
    cavert_try_take_item(slot);
}
