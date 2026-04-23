/* z_07.c — C port of z_07 leaf functions.
 * Data tables and remaining code stay in z_07.asm.
 */

#include "../nes_abi.h"

#define NES_SRAM_BASE  0x6000u

void z07_hide_all_sprites(void) {
    for (unsigned char i = 0; i < 64; i++)
        RAM(0x0200 + (unsigned short)i * 4) = 0xF8;
}

unsigned char z07_get_unique_room_id(void) {
    unsigned char room = RAM(0x00EB);
    return nes_ram[NES_SRAM_BASE + 0x09FE + room] & 0x3F;
}

void z07_clear_room_history(void) {
    RAM(0x0529) = 0;
    for (signed char i = 5; i >= 0; i--)
        RAM(0x0621 + (unsigned char)i) = 0;
}

void z07_reset_player_state(void) {
    RAM(0x00AC) = 0;
    RAM(0x066C) = 0;
}

unsigned char z07_reset_moving_dir(void) {
    RAM(0x000F) = 0;
    return 0;
}

void z07_ensure_object_aligned(unsigned int slot) {
    if (RAM(0x0394 + slot) != 0) return;
    RAM(0x0070 + slot) &= 0xF8;
    RAM(0x0084 + slot) = (RAM(0x0084 + slot) & 0xF8) | 0x05;
}

unsigned char z07_get_room_flags(void) {
    unsigned char ptr_lo = nes_ram[NES_SRAM_BASE + 0x0BAF];
    unsigned char ptr_hi = nes_ram[NES_SRAM_BASE + 0x0BB0];
    RAM(0x00) = ptr_lo;
    RAM(0x01) = ptr_hi;
    unsigned short ptr = ((unsigned short)ptr_hi << 8) | ptr_lo;
    unsigned char room_id = RAM(0x00EB);
    return nes_ram[ptr + room_id];
}

void z07_mark_room_visited(void) {
    unsigned char flags = z07_get_room_flags();
    flags |= 0x20;
    unsigned short ptr = ((unsigned short)RAM(0x01) << 8) | RAM(0x00);
    unsigned char room_id = RAM(0x00EB);
    nes_ram[ptr + room_id] = flags;
}

unsigned char z07_reset_obj_state(unsigned int slot) {
    RAM(0x00AC + slot) = 0;
    return 0;
}

void z07_set_shot_spreading_state(unsigned int slot) {
    RAM(0x00AC + slot)++;
    RAM(0x0098 + slot) = 0xFE;
}

void z07_roll_over_anim_counter(unsigned int slot) {
    RAM(0x03D0 + slot) = RAM(0x00);
    RAM(0x03E4 + slot) ^= 0x01;
}

void z07_decrement_invincibility_timer(unsigned int slot) {
    if (RAM(0x04F0 + slot) == 0) return;
    if (RAM(0x0015) & 1) return;
    RAM(0x04F0 + slot)--;
}

void z07_update_dead_dummy(unsigned int slot) {
    RAM(0x0602) = 32;
    RAM(0x0405 + slot) = 16;
}

unsigned char z07_end_game_mode(void) {
    RAM(0x0011) = 0;
    RAM(0x0013) = 0;
    return 0;
}

void z07_set_shove_info_with0(unsigned int val, unsigned int slot) {
    RAM(0x00C0 + slot) = (unsigned char)val;
    RAM(0x00D3 + slot) = (unsigned char)val;
}

void z07_reset_obj_metastate(unsigned int slot) {
    RAM(0x0405 + slot) = 0;
}

unsigned char z07_anim_fetch_obj_pos(unsigned int slot) {
    RAM(0x0000) = RAM(0x0070 + slot);
    RAM(0x0001) = RAM(0x0084 + slot);
    RAM(0x000F) = 0;
    return 0;
}

void z07_anim_set_obj_hflip(unsigned int slot) {
    RAM(0x000F) = RAM(0x03E4 + slot);
}

unsigned int z07_walker_alt_dir_get_opposite(void) {
    unsigned char dir = RAM(0x000F);
    if (dir & 0x0A)
        return dir >> 1;
    return (dir << 1) & 0xFF;
}

void z07_reset_obj_metastate_and_timer(unsigned int slot) {
    RAM(0x0028 + slot) = 0;
    z07_reset_obj_metastate(slot);
}

void z07_init_flute_secret(unsigned int slot) {
    RAM(0x051A) = 1;
    RAM(0x0028 + slot) = 0;
    z07_reset_obj_metastate(slot);
}

void z07_deactivate_shot(unsigned int slot) {
    z07_reset_obj_state(slot);
}

void z07_deactivate_link_shot(void) {
    z07_reset_obj_state(14);
}

void z07_walker_alt_dir_end_loop(void) {
    RAM(0x000E) = 0;
}

void z07_reset_shove_info(unsigned int slot) {
    z07_set_shove_info_with0(0, slot);
}

void z07_go_to_next_mode(void) {
    RAM(0x0012)++;
    z07_end_game_mode();
}

unsigned int z07_find_empty_monster_slot(void) {
    for (signed char i = 11; i >= 1; i--) {
        if (RAM(0x034F + (unsigned char)i) == 0) {
            RAM(0x0059) = (unsigned char)i;
            return (unsigned int)(unsigned char)i;
        }
    }
    return 0;
}

extern void z01_destroy_object_wram(unsigned int val, unsigned int slot);

void z07_destroy_monster(unsigned int slot) {
    RAM(0x034F + slot) = 0;
    z01_destroy_object_wram(0, slot);
}

void z07_set_type_and_clear_object(unsigned int type, unsigned int slot) {
    RAM(0x034F + slot) = (unsigned char)type;
    z01_destroy_object_wram(0, slot);
}

void z07_init_tile_obj_or_item(unsigned int slot) {
    RAM(0x04BF + slot) = 0x81;
    z07_reset_obj_metastate_and_timer(slot);
}

void z07_anim_advance_and_fetch(unsigned int val, unsigned int slot) {
    RAM(0x0000) = (unsigned char)val;
    RAM(0x03D0 + slot)--;
    if (RAM(0x03D0 + slot) == 0) {
        z07_roll_over_anim_counter(slot);
    }
    z07_anim_fetch_obj_pos(slot);
}

extern const unsigned char LevelSongIds[];

void z07_go_to_next_mode_play_level_song(void) {
    unsigned char level = RAM(0x0010);
    RAM(0x0600) = LevelSongIds[level];
    z07_go_to_next_mode();
    RAM(0x0394) = 0;
}

void z07_go_to_next_mode_reset_grid_offset(void) {
    z07_go_to_next_mode();
    RAM(0x0394) = 0;
}

extern unsigned int z01_get_opposite_dir(unsigned int dir);

void z07_reverse_obj_dir(unsigned int slot) {
    unsigned char dir = RAM(0x0098 + slot);
    unsigned char new_dir = (unsigned char)z01_get_opposite_dir(dir);
    RAM(0x0098 + slot) = new_dir;
    RAM(0x000F) = new_dir;
}

extern const unsigned char SaveSlotToPaletteRowOffset[];
extern const unsigned char MenuPalettesTransferBuf[];

void z07_patch_and_cue_level_palettes_transfer(void) {
    unsigned char slot = RAM(0x0016);
    unsigned char row_off = SaveSlotToPaletteRowOffset[slot];
    unsigned char color = MenuPalettesTransferBuf[20 + row_off];
    nes_ram[0x6000u + 0x0B92] = color;
    RAM(0x0014) = 24;
    RAM(0x0013)++;
}

extern const unsigned char PlayAreaColumnAddrs[];
extern const unsigned char WalkableTiles[];
extern const unsigned char ReverseDirections[];

static const unsigned char walkable_count = 9;

unsigned char z07_get_collidable_tile(unsigned int hotspot_offset, unsigned int slot) {
    RAM(0x0004) = (unsigned char)hotspot_offset;
    unsigned char y_pos = RAM(0x0084 + slot);
    unsigned char adjusted_y = (unsigned char)(y_pos + 0x0B);
    unsigned char dir = RAM(0x000F);

    unsigned char tile_y = adjusted_y;
    unsigned char tile_x;

    if (dir & 0x0C) {
        if (dir & 0x04) {
            if (adjusted_y < 0xDD)
                tile_y = (unsigned char)(adjusted_y + (unsigned char)hotspot_offset);
        } else {
            tile_y = (unsigned char)(adjusted_y + (unsigned char)hotspot_offset);
        }
        tile_x = RAM(0x0070 + slot);
    } else {
        tile_x = RAM(0x0070 + slot);
        if (dir & 0x01) {
            if (tile_x < 0xF0)
                tile_x = (unsigned char)(tile_x + (unsigned char)hotspot_offset);
        } else {
            if (tile_x >= 0x10)
                tile_x = (unsigned char)(tile_x + (unsigned char)hotspot_offset);
        }
    }

    unsigned char col_idx = (tile_x & 0xF8) >> 2;
    unsigned short col_addr = ((unsigned short)PlayAreaColumnAddrs[col_idx] |
                               ((unsigned short)PlayAreaColumnAddrs[col_idx + 1] << 8));

    unsigned char row_idx = (unsigned char)((tile_y - 0x40) >> 3);

    unsigned char tile = nes_ram[col_addr + row_idx];
    RAM(0x049E + slot) = tile;

    if (dir & 0x0C) {
        unsigned char next_row = (unsigned char)(row_idx + 0x16);
        unsigned char next_tile = nes_ram[col_addr + next_row];
        if (next_tile >= tile)
            RAM(0x049E + slot) = next_tile;
    }

    tile = RAM(0x049E + slot);

    if (RAM(0x0010) == 0) {
        tile = RAM(0x049E + slot);
        for (signed char i = (signed char)(walkable_count - 1); i >= 0; i--) {
            if (tile == WalkableTiles[i]) {
                tile = 0x26;
                break;
            }
        }
        RAM(0x049E + slot) = tile;

        if (slot == 0) {
            if (RAM(0x00EB) == 0x1F) {
                if (dir & 0x0C) {
                    if (RAM(0x0070) == 0x80 && RAM(0x0084) < 0x56) {
                        RAM(0x049E) = 0x26;
                    }
                }
            }
        }
    }

    return RAM(0x049E + slot);
}

unsigned char z07_get_collidable_tile_still(unsigned int slot) {
    RAM(0x000F) = 0;
    return z07_get_collidable_tile(0, slot);
}

unsigned char z07_get_colliding_tile_moving(unsigned int slot) {
    unsigned char hotspot;
    if (slot == 0)
        hotspot = 0xF8;
    else
        hotspot = 0xF0;

    unsigned char dir = RAM(0x000F);
    if (dir & 0x05) {
        if (dir & 0x04)
            hotspot = 8;
        else
            hotspot = 16;
    }
    return z07_get_collidable_tile(hotspot, slot);
}


/* --- batch 44 --- */

void z07_do_nothing(void) {}

unsigned char z07_walker_alt_dir_get_random_perpendicular(unsigned int slot) {
    unsigned char rnd = nes_ram[0x0018 + slot];
    unsigned char dir = nes_ram[0x0098 + slot];
    unsigned int idx = (rnd & 0x80) ? 0 : 1;
    if (dir & 0x0C) idx += 2;
    return ReverseDirections[idx];
}

/* --- batch 45 --- */

extern void z01_init_grumble_full(unsigned int slot);
extern void z01_init_rupee_stash_full(unsigned int slot);

void z07_init_grumble(unsigned int slot) {
    z01_init_grumble_full(slot);
}

void z07_init_rupee_stash(unsigned int slot) {
    z01_init_rupee_stash_full(slot);
}

/* --- batch 51 --- */

void z07_init_mode3_sub1(void) {
    unsigned char room_id;
    if (RAM(0x0010) != 0 || RAM(0x0526) == 0xFF) {
        room_id = nes_ram[NES_SRAM_BASE + 0x0BAD];
    } else {
        room_id = RAM(0x0526);
    }
    RAM(0x00EB) = room_id;
    if (room_id == RAM(0x0526)) {
        RAM(0x0526) = 0xFF;
    }
    z07_patch_and_cue_level_palettes_transfer();
}

/* --- batch 79 --- */

static void animate_link_obj_state(void) {
    unsigned char state = RAM(0x00AC);
    unsigned char major = state & 0x30;
    if (major == 0x10 || major == 0x20) {
        if (state & 0x0F)
            RAM(0x00AC) = state | 0x30;
        else
            RAM(0x00AC) = state + 1;
        RAM(0x03E4) = 1;
    } else if (major == 0x30) {
        RAM(0x00AC) = state & 0xC0;
    }
}

void z07_animate_object_walking(unsigned int slot) {
    if (--RAM(0x03D0 + slot) == 0) {
        if (slot == 0) animate_link_obj_state();
        RAM(0x0000) = 6;
        z07_roll_over_anim_counter(slot);
    }
    z07_anim_fetch_obj_pos(slot);
    unsigned char dir = RAM(0x0098 + slot) & 0x0C;
    if (dir != 0) {
        z07_anim_set_obj_hflip(slot);
    } else {
        if (!(RAM(0x0098 + slot) & 1)) RAM(0x000F)++;
    }
}
