/* z_05.c — Stage 3b: C port of z_05 tile buffer copy functions.
 * Data tables and remaining code stay in z_05.asm.
 */

#include "../nes_abi.h"
#include "../room_runtime.h"
#include "../room_load_runtime.h"
#include "../room_mode_runtime.h"
#include "../room_transfer_runtime.h"
#include "../room_player_runtime.h"
#include "../room_object_runtime.h"

#define PLAY_AREA_BASE  0x6530u
#define COL_STRIDE      0x16u

/* CopyColumnToTileBuf — builds a tile transfer record for one column
 * of the play area.  NES RAM[$00E8] = target column + 1.
 * Writes header + 22 column bytes into the tile buffer at RAM[$0302+]. */
void z05_copy_column_to_tilebuf(void) {
    RAM(0x0000) = 0x1A;
    RAM(0x0001) = 0x65;

    unsigned char col = RAM(0x00E8) - 1;
    unsigned char buf = RAM(0x0301);

    RAM(0x0302 + buf) = 33;
    RAM(0x0303 + buf) = col;

    unsigned short src = PLAY_AREA_BASE + (unsigned short)col * COL_STRIDE;

    RAM(0x0304 + buf) = 0x96;
    RAM(0x031B + buf) = 0xFF;

    unsigned char dst = buf;
    for (unsigned char i = 0; i < 22; i++) {
        RAM(0x0305 + dst) = nes_ram[src + i];
        dst++;
    }
    src += 22;
    dst += 3;
    RAM(0x0301) = dst;

    RAM(0x0000) = src & 0xFF;
    RAM(0x0001) = (src >> 8) & 0xFF;
}

/* CopyRowToTileBuf — builds a tile transfer record for one row
 * of the play area.  NES RAM[$00E9] = target row.
 * Reads 32 tiles (one per column, stride $16) into tile buffer. */
void z05_copy_row_to_tilebuf(void) {
    unsigned char row = RAM(0x00E9);

    /* Set pointer 00:01 = $6530 + row (8-bit add with carry) */
    unsigned short ptr = 0x6530u + row;
    RAM(0x0000) = ptr & 0xFF;
    RAM(0x0001) = (ptr >> 8) & 0xFF;

    /* Compute VRAM dest address: $20E0 + (row+1)*$20
     * The NES loop adds $20 to $E0 for (row+1) iterations.
     * Row 0: $20E0 + $20 = $2100.  Row 1: $2100 + $20 = $2120.  etc. */
    unsigned short vram = 0x20E0u;
    for (signed char r = (signed char)row; r >= 0; r--)
        vram += 0x20;
    RAM(0x0302) = (vram >> 8) & 0xFF;
    RAM(0x0303) = vram & 0xFF;

    RAM(0x0304) = 32;
    RAM(0x0325) = 0xFF;

    /* Copy 32 tiles: one per column, stride $16 */
    unsigned short s = PLAY_AREA_BASE + row;
    for (unsigned char i = 0; i < 32; i++) {
        RAM(0x0305 + i) = nes_ram[s];
        s += COL_STRIDE;
    }

    RAM(0x0301) = 35;

    RAM(0x0000) = s & 0xFF;
    RAM(0x0001) = (s >> 8) & 0xFF;
}

/* --- Stage 4a functions --- */

static const unsigned char level_masks[] = {
    0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80
};

#define NES_SRAM_BASE  0x6000u

static unsigned char get_room_flags(void) {
    unsigned char ptr_lo = nes_ram[NES_SRAM_BASE + 0x0BAF];
    unsigned char ptr_hi = nes_ram[NES_SRAM_BASE + 0x0BB0];
    RAM(0x00) = ptr_lo;
    RAM(0x01) = ptr_hi;
    unsigned short ptr = ((unsigned short)ptr_hi << 8) | ptr_lo;
    unsigned char room_id = RAM(0x00EB);
    return nes_ram[ptr + room_id];
}

static unsigned char has_item_by_level(unsigned char base_offset) {
    unsigned char level = RAM(0x0010);
    if (level == 0) return 0;
    unsigned char idx = level - 1;
    unsigned char offset = base_offset;
    if (idx >= 8) offset += 2;
    unsigned char bit_idx = idx & 7;
    return RAM(0x0657 + offset) & level_masks[bit_idx];
}

unsigned char z05_has_compass(void) { return roomrt_has_compass(); }

unsigned char z05_has_map(void) { return roomrt_has_map(); }

void z05_calc_open_doorway_mask(unsigned int attr, unsigned int dir_idx) { roomrt_calc_open_doorway_mask(attr, dir_idx); }

void z05_add_door_flags(void) { roomrt_add_door_flags(); }

/* --- Stage 4b functions --- */

unsigned int z05_split_room_id(void) { return roomrt_split_room_id(); }

unsigned char z05_is_dark_room(unsigned int col) { return roomrt_is_dark_room(col); }

void z05_set_door_flag(unsigned int dir_idx) { roomrt_set_door_flag(dir_idx); }

void z05_reset_door_flag(unsigned int dir_idx) { roomrt_reset_door_flag(dir_idx); }

void z05_check_has_living_monsters(void) { roomrt_check_has_living_monsters(); }

void z05_silence_sound(void) { roomrt_silence_sound(); }

void z05_set_entering_doorway(void) { roomrt_set_entering_doorway(); }

/* --- Stage 4b batch 3 functions --- */

void z05_write_and_enable_sprite0(void) {
    roomld_write_and_enable_sprite0();
}

void z05_put_link_behind_background(void) {
    roomld_put_link_behind_background();
}

extern void z05_reset_inv_obj_state(void);
extern void z05_copy_row_to_tilebuf(void);
extern void z05_copy_column_to_tilebuf(void);

unsigned int z05_cycle9_in_direction(unsigned int d3_in) {
    return roomxf_cycle9_in_direction(d3_in);
}

void z05_copy_column_or_row_to_tilebuf(void) {
    roomxf_copy_column_or_row_to_tilebuf();
}

void z05_init_mode_a_sub_a_go_to_mode4(void) {
    roommd_init_mode_a_sub_a_go_to_mode4();
}

void z05_reset_inv_obj_state(void) {
    roomld_reset_inv_obj_state();
}

void z05_mask_cur_ppu_mask_grayscale(void) {
    RAM(0x00FE) &= 0xFE;
}

void z05_fill_play_area_attrs(unsigned int room_id) {
    roomld_fill_play_area_attrs(room_id);
}

void z05_setup_obj_room_bounds(void) {
    roomld_setup_obj_room_bounds();
}

void z05_init_link_speed(void) {
    roomld_init_link_speed();
}

void z05_update_mode7_scroll_sub2(void) {
    roommd_update_mode7_scroll_sub2();
}

void z05_update_mode7_scroll_sub7(void) {
    roommd_update_mode7_scroll_sub7();
}

void z05_fetch_tile_map_addr(void) {
    roomxf_fetch_tile_map_addr();
}

void z05_copy_play_area_attrs_half(unsigned int ppu_hi, unsigned int ppu_lo, unsigned int end_off) {
    roomxf_copy_play_area_attrs_half(ppu_hi, ppu_lo, end_off);
}

void z05_inc_submode(void) {
    roommd_inc_submode();
}

void z05_inc_2_submodes(void) {
    roommd_inc_2_submodes();
}

void z05_init_mode4_go_to_sub0(void) {
    roommd_init_mode4_go_to_sub0();
}

void z05_trigger_open_door(unsigned int val) {
    roomrt_trigger_open_door(val);
}

void z05_update_mode11_death_sub6(void) {
    roommd_update_mode11_death_sub6();
}

void z05_reset_vscroll_lo(void) {
    roommd_reset_vscroll_lo();
}

void z05_select_transfer_buf(unsigned int val) {
    roommd_select_transfer_buf(val);
}

void z05_touch_door_wall(void) {
    roomrt_touch_door_wall();
}

void z05_select_transfer_buf_and_inc_state(unsigned int val) {
    roommd_select_transfer_buf_and_inc_state(val);
}

void z05_block_at_wall(void) {
    roomrt_block_at_wall();
}

void z05_get_player_coords_for_direction(unsigned int dir) {
    roompl_get_player_coords_for_direction(dir);
}

/* --- Carry-flag returning functions --- */

extern void z05_copy_row_to_tilebuf(void);

unsigned int z05_copy_next_row_to_transfer_buf(void) {
    return roommd_copy_next_row_to_transfer_buf();
}

unsigned int z05_copy_next_row_advance_submode(void) {
    return roommd_copy_next_row_advance_submode();
}

extern unsigned char z01_abs(unsigned int val);

unsigned int z05_is_distance_safe_to_spawn(unsigned int slot) {
    return roompl_is_distance_safe_to_spawn(slot);
}

void z05_set_fade_cycle_and_advance_submode(unsigned int val) {
    roommd_set_fade_cycle_and_advance_submode(val);
}

void z05_set_moving_dir_and_switch_to_player_slot(unsigned int dir) {
    roompl_set_moving_dir_and_switch_to_player_slot(dir);
}

extern unsigned int z01_get_opposite_dir(unsigned int dir);

void z05_link_modify_dir_in_doorway(void) {
    roompl_link_modify_dir_in_doorway();
}

extern unsigned char z07_end_game_mode(void);

void z05_update_mode11_death_sub_c(void) {
    if (RAM(0x0033) != 0) return;
    z07_end_game_mode();
    RAM(0x0012) = 8;
    RAM(0x0602) = 64;
    unsigned char slot = RAM(0x0016);
    unsigned char continue_count = RAM(0x0630 + slot);
    if (continue_count != 0xFF)
        RAM(0x0630 + slot) = continue_count + 1;
}

void z05_update_mode7_scroll_sub6(void) {
    roommd_update_mode7_scroll_sub6();
}

extern unsigned char z07_get_collidable_tile_still(unsigned int slot);
extern unsigned char z01_compare_hearts_to_containers(void);
extern unsigned char z01_reset_room_tile_obj_info(void);

void z05_cue_transfer_play_area_attrs_half_and_advance_submode(
        unsigned int ppu_hi, unsigned int ppu_lo, unsigned int end_off) {
    roommd_cue_transfer_play_area_attrs_half_and_advance_submode(ppu_hi, ppu_lo, end_off);
}

void z05_update_mode11_death_sub2(void) {
    unsigned int result = z05_copy_next_row_advance_submode();
    if (result & CARRY_SET) {
        z05_write_and_enable_sprite0();
    }
    unsigned char val = RAM(0x0302);
    val = (unsigned char)(val + 0x08);
    RAM(0x0302) = val;
}

void z05_init_mode10(void) {
    roomobj_init_mode10();
}

void z05_setup_tile_object_ow(void) {
    roomobj_setup_tile_object_ow();
}

void z05_world_fill_hearts(void) {
    roomobj_world_fill_hearts();
}

extern void z01_begin_update_mode(void);
extern void z05_select_transfer_buf_and_inc_state(unsigned int val);

void z05_update_menu_common2(void) {
    roommd_update_menu_common2();
}

void z05_update_menu_common3(void) {
    roommd_update_menu_common3();
}

void z05_update_menu_common4(void) {
    roommd_update_menu_common4();
}

void z05_update_menu5_ow(void) {
    roommd_update_menu5_ow();
}

void z05_l1433a_inc_submode(void) {
    roommd_inc_submode();
}

void z05_init_mode7_finish(void) {
    roommd_init_mode7_finish();
}

/* --- batch 40 --- */

void z05_switch_to_nt1(void) {
    roommd_switch_to_nt1();
}

void z05_update_mode11_death_set_timer_inc_submode(unsigned int val) {
    roommd_update_mode11_death_set_timer_inc_submode(val);
}

void z05_update_mode11_death_sub4(void) {
    roommd_update_mode11_death_sub4();
}

void z05_update_mode11_death_sub5(void) {
    roommd_update_mode11_death_sub5();
}

void z05_update_mode11_death_sub9(void) {
    roommd_update_mode11_death_sub9();
}

/* --- batch 41 --- */

void z05_wield_nothing(void) {
}

void z05_end_prepare_mode(void) {
    roomobj_end_prepare_mode();
}

void z05_init_mode9_transfer_attrs(void) {
    roommd_init_mode9_transfer_attrs();
}

void z05_start_filling_hearts(void) {
    roommd_start_filling_hearts();
}

void z05_init_mode_b_sub1(void) {
    roommd_init_mode_b_sub1();
}

/* --- batch 42 --- */

unsigned int z05_check_secret_trigger_none(void) { return roomrt_check_secret_trigger_none(); }

unsigned int z05_trigger_shutters(void) {
    return roomrt_trigger_shutters();
}

unsigned int z05_return_false(void) { return roomrt_return_false(); }

unsigned int z05_check_secret_trigger_all_dead(void) {
    return roomrt_check_secret_trigger_all_dead();
}

unsigned int z05_check_secret_trigger_last_boss(void) {
    return roomrt_check_secret_trigger_last_boss();
}

unsigned int z05_check_secret_trigger_money_or_life(void) {
    return roomrt_check_secret_trigger_money_or_life();
}

unsigned int z05_check_secret_trigger_block_door(void) {
    return roomrt_check_secret_trigger_block_door();
}

/* --- batch 43 --- */
unsigned int z05_check_secret_trigger_ringleader(void) {
    return roomrt_check_secret_trigger_ringleader();
}

void z05_touch_door_open(void) {}

void z05_touch_door_bombable(void) {
    roomrt_touch_door_bombable();
}

/* --- batch 46 --- */

void z05_dec_submenu_scroll(void) {
    roomobj_dec_submenu_scroll();
}

/* --- batch 49 --- */

extern void z05_block_at_wall(void);

void z05_block_until_time(void) {
    roomrt_block_until_time();
}

/* --- batch 50 --- */

extern unsigned char LevelNumberTransferBuf[];

void z05_init_mode3_sub2(void) {
    roommd_init_mode3_sub2();
}

void z05_init_mode3_sub6(void) {
    roommd_init_mode3_sub6();
}

void z05_init_mode3_sub7(void) {
    roommd_init_mode3_sub7();
}

void z05_update_mode12_end_level_sub1(void) {
    roommd_update_mode12_end_level_sub1();
}

unsigned int z05_touch_door_false(void) {
    return roomrt_touch_door_false();
}

/* --- batch 51 --- */

extern void z07_patch_and_cue_level_palettes_transfer(void);

void z05_init_mode_a_sub1(void) {
    roommd_init_mode_a_sub1();
}

void z05_end_game_mode12(void) {
    roommd_end_game_mode12();
}

void z05_touch_door_shutter(void) {
    roomrt_touch_door_shutter();
}

void z05_save_kill_count_ow(unsigned int slot) { roomrt_save_kill_count_ow(slot); }

/* --- batch 54 --- */

void z05_init_mode3_sub3(void) {
    roommd_init_mode3_sub3();
}

void z05_init_mode3_sub4(void) {
    roommd_init_mode3_sub4();
}

void z05_init_mode3_sub5(void) {
    roommd_init_mode3_sub5();
}

