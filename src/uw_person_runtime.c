#include "uw_person_runtime.h"

extern void z01_set_up_common_cave_objects(unsigned int x, unsigned int slot, unsigned int y);
extern void z01_play_character_sfx(void);
extern unsigned char z01_get_room_flag_uw_item_state(void);
extern void z01_set_room_flag_uw_item_state(void);
extern void z01_cue_transfer_buf_and_advance_state(unsigned int val);
extern unsigned char z01_abs(unsigned int val);
extern void z01_init_one_simple_object(unsigned int slot);
extern void z01_update_person_state_reset_char_offset(void);
extern void z01_cue_transfer_blank_person_wares(void);
extern void z01_uw_person_complex_state_delay_and_quit(void);
extern void z01_unhalt_link(void);
extern void z01_update_person_state_do_nothing(void);
extern void z01_init_underworld_person_do_nothing(void);
extern unsigned char z07_anim_fetch_obj_pos(unsigned int slot);
extern void z07_destroy_monster(unsigned int slot);
extern void z07_reset_moving_dir(void);
extern void c_check_monster_collisions(unsigned int slot);
extern void c_animate_item_object(unsigned char item_type, unsigned int slot);
extern void c_draw_object_mirrored(unsigned int slot);
extern void c_draw_object_not_mirrored(unsigned int slot);
extern void c_link_end_move_and_animate_bank1(void);
extern void c_update_person_state_textbox(void);
extern const unsigned char UnderworldPersonTextSelectorsA[];
extern const unsigned char UnderworldPersonTextSelectorsC[];
extern const unsigned char TextboxLineAddrsLo[];
extern const unsigned char RupeeStashXs[];
extern const unsigned char RupeeStashYs[];
extern const unsigned char LifeOrMoneyItemXs[];
extern const unsigned char LifeOrMoneyItemTypes[];

static unsigned char uwrt_compare_hearts_to_containers(void) {
    unsigned char hearts = RAM(0x066F);
    unsigned char filled = hearts & 0x0F;
    RAM(0x0000) = filled;
    return hearts >> 4;
}

static void uwrt_complex_state_begin(void) {
    unsigned char obj = RAM(0x0350);
    if (obj == 0x4F)
        RAM(0x0014) = 108;
    RAM(0x0029) = 10;
    RAM(0x00AD)++;
}

void uwrt_person_draw_and_check_collisions(unsigned int slot) {
    uwrt_person_check_collisions(slot);
    z07_anim_fetch_obj_pos(slot);
    c_draw_object_mirrored(slot);
}

void uwrt_init_underworld_person_b(unsigned int slot) {
    static const unsigned char text_selectors[] = {0x2A, 0x38, 0x3A, 0x2C, 0x40, 0x42, 0x42, 0x3C};
    unsigned char obj_type;
    unsigned char idx;
    z01_set_up_common_cave_objects(120, slot, 0x80);
    obj_type = RAM(0x034F + slot);
    idx = (unsigned char)(obj_type - 0x4B);
    RAM(0x0415) = text_selectors[idx];
    z01_play_character_sfx();
}

void uwrt_init_underworld_person_c(unsigned int slot) {
    unsigned char obj_type;
    unsigned char idx;
    z01_set_up_common_cave_objects(120, slot, 0x80);
    z01_play_character_sfx();
    obj_type = RAM(0x034F + slot);
    idx = (unsigned char)(obj_type - 0x4B);
    RAM(0x0415) = UnderworldPersonTextSelectorsC[idx];
    if (obj_type != 0x4B)
        return;
    if (RAM(0x0671) != 0xFF)
        return;
    RAM(0x04CE) = 1;
    RAM(0x00AC) = 0;
    z07_destroy_monster(slot);
}

void uwrt_init_grumble_full(unsigned int slot) {
    unsigned char item_state;
    z01_set_up_common_cave_objects(120, slot, 0x80);
    RAM(0x0415) = 36;
    RAM(0x045F) = TextboxLineAddrsLo[2];
    item_state = z01_get_room_flag_uw_item_state();
    if (item_state == 0) {
        z01_play_character_sfx();
        return;
    }
    RAM(0x00AC) = 0;
    RAM(0x0350) = 0;
}

void uwrt_init_rupee_stash_full(unsigned int slot) {
    unsigned char i;
    (void)slot;
    RAM(0x0001) = RAM(0x04BF + slot);
    RAM(0x0000) = 53;
    for (i = 10; i >= 1; --i) {
        z01_init_one_simple_object(i);
        RAM(0x0070 + i) = RupeeStashXs[i - 1];
        RAM(0x0084 + i) = RupeeStashYs[i - 1];
    }
}

void uwrt_update_life_or_money_state_0(void) {
    RAM(0x0029) = 10;
    z01_cue_transfer_buf_and_advance_state(118);
}

void uwrt_underworld_person_destroy_if_taken(unsigned int slot) {
    unsigned char item_state = z01_get_room_flag_uw_item_state();
    if (item_state == 0) {
        z01_play_character_sfx();
        return;
    }
    RAM(0x00AC) = 0;
    z07_destroy_monster(slot);
}

void uwrt_init_life_or_money_full(unsigned int slot) {
    z01_set_up_common_cave_objects(120, slot, 0x80);
    RAM(0x0415) = 54;
    RAM(0x045F) = TextboxLineAddrsLo[2];
    uwrt_underworld_person_destroy_if_taken(slot);
}

void uwrt_person_flag_item_taken_and_advance_state(void) {
    z01_set_room_flag_uw_item_state();
    RAM(0x0029) = 64;
    z01_cue_transfer_buf_and_advance_state(30);
}

void uwrt_check_person_blocking(void) {
    if (RAM(0x0084) >= 0x8E)
        return;
    if ((RAM(0x000F) & 0x08) == 0)
        return;
    z07_reset_moving_dir();
}

void uwrt_update_grumble1(void) {
    unsigned char val = RAM(0x00AC + 15);
    if ((val & 0x80) == 0)
        return;
    RAM(0x00AC) = 64;
    RAM(0x0602) = 4;
    uwrt_person_flag_item_taken_and_advance_state();
}

void uwrt_init_underworld_person_a(unsigned int slot) {
    unsigned char idx;
    z01_set_up_common_cave_objects(120, slot, 0x80);
    idx = (unsigned char)(RAM(0x034F + slot) - 0x4B);
    RAM(0x0415) = UnderworldPersonTextSelectorsA[idx];
    if (RAM(0x0350) == 0x4F) {
        uwrt_underworld_person_destroy_if_taken(slot);
        return;
    }
    z01_play_character_sfx();
}

void uwrt_update_complex_state_sense_link(void) {
    unsigned char ydiff;
    unsigned char max_bombs;
    if (RAM(0x0350) != 0x4F)
        return;
    if (RAM(0x0070) != 0x78)
        return;
    ydiff = (unsigned char)(RAM(0x0084) - 0x98);
    if (z01_abs((unsigned int)ydiff) >= 6)
        return;
    if (RAM(0x066D) < 100)
        return;
    RAM(0x067E) = (unsigned char)(100 + RAM(0x067E));
    RAM(0x0604) = 8;
    max_bombs = (unsigned char)(RAM(0x067C) + 4);
    RAM(0x067C) = max_bombs;
    RAM(0x0658) = max_bombs;
    uwrt_person_flag_item_taken_and_advance_state();
}

void uwrt_update_life_or_money_state_2(void) {
    int i;
    for (i = 1; i >= 0; --i) {
        unsigned char ydiff;
        if (RAM(0x0070) != LifeOrMoneyItemXs[i])
            continue;
        ydiff = (unsigned char)(RAM(0x0084) - 0x98);
        if (z01_abs((unsigned int)ydiff) >= 6)
            continue;
        if (i != 0) {
            if (RAM(0x066D) < 50)
                return;
            RAM(0x067E) = (unsigned char)(50 + RAM(0x067E));
        } else {
            unsigned char hearts = RAM(0x066F);
            unsigned char containers = hearts & 0xF0;
            if (containers >= 0x30) {
                unsigned char new_cont = (unsigned char)(containers - 0x10);
                int partial = (int)(hearts & 0x0F) - 1;
                RAM(0x0000) = new_cont;
                if (partial < 0)
                    partial = 0;
                RAM(0x066F) = new_cont | (unsigned char)partial;
            } else {
                RAM(0x066F) = containers;
                RAM(0x0670) = 0;
            }
        }
        RAM(0x0604) = 8;
        RAM(0x04CE) = 1;
        uwrt_person_flag_item_taken_and_advance_state();
        return;
    }
}

void uwrt_person_check_collisions(unsigned int slot) {
    unsigned char killed;
    c_check_monster_collisions(slot);
    killed = RAM(0x0406);
    if (killed) {
        RAM(0x04CC) = killed;
        RAM(0x0406) = 0;
    }
}

void uwrt_draw_life_or_money_items(void) {
    int i;
    for (i = 1; i >= 0; --i) {
        RAM(0x0083) = LifeOrMoneyItemXs[i];
        RAM(0x0097) = 0x98;
        c_animate_item_object(LifeOrMoneyItemTypes[i], 19);
    }
}

void uwrt_update_grumble3(void) {
    c_link_end_move_and_animate_bank1();
    if (RAM(0x0029) != 0) {
        z01_init_underworld_person_do_nothing();
        return;
    }
    RAM(0x00AC + 15) = 0;
    RAM(0x065D) = 0;
    RAM(0x00AC) = 0;
    RAM(0x0350) = 0;
    z01_init_underworld_person_do_nothing();
}

void uwrt_update_person_complex(unsigned int slot) {
    unsigned char state = RAM(0x00AD);
    if (state != 4 || (RAM(0x0015) & 1) == 0) {
        uwrt_person_draw_and_check_collisions(slot);
        if (RAM(0x0350) == 0x4F) {
            RAM(0x0083) = 120;
            RAM(0x0097) = 0x98;
            c_animate_item_object(24, 19);
        }
    }
    switch (RAM(0x00AD)) {
        case 0: uwrt_complex_state_begin(); break;
        case 1: c_update_person_state_textbox(); break;
        case 2: uwrt_update_complex_state_sense_link(); break;
        case 3: z01_cue_transfer_blank_person_wares(); break;
        case 4: z01_uw_person_complex_state_delay_and_quit(); break;
    }
}

void uwrt_update_person_full(unsigned int slot) {
    unsigned char level = RAM(0x0010);
    if ((unsigned char)level < 3 || level == 5 || level == 7) {
        uwrt_update_person_complex(slot);
        return;
    }
    uwrt_person_draw_and_check_collisions(slot);
    switch (RAM(0x00AD)) {
        case 0: z01_update_person_state_reset_char_offset(); break;
        case 1: c_update_person_state_textbox(); break;
        case 2: z01_update_person_state_do_nothing(); break;
    }
}

void uwrt_update_grumble_full(unsigned int slot) {
    unsigned char state = RAM(0x00AD);
    if (state != 3 || (RAM(0x0015) & 1) == 0) {
        uwrt_person_check_collisions(slot);
        z07_anim_fetch_obj_pos(slot);
        c_draw_object_not_mirrored(slot);
    }
    switch (RAM(0x00AD)) {
        case 0: c_update_person_state_textbox(); break;
        case 1: uwrt_update_grumble1(); break;
        case 2: z01_cue_transfer_blank_person_wares(); break;
        case 3: uwrt_update_grumble3(); break;
    }
}

void uwrt_update_life_or_money_full(unsigned int slot) {
    unsigned char state = RAM(0x00AD);
    if (state != 4 || (RAM(0x0015) & 1) == 0) {
        uwrt_person_draw_and_check_collisions(slot);
        uwrt_draw_life_or_money_items();
    }
    switch (RAM(0x00AD)) {
        case 0: uwrt_update_life_or_money_state_0(); break;
        case 1: c_update_person_state_textbox(); break;
        case 2: uwrt_update_life_or_money_state_2(); break;
        case 3: z01_cue_transfer_blank_person_wares(); break;
        case 4: z01_uw_person_complex_state_delay_and_quit(); break;
    }
}
