#include "sprite_runtime.h"
#include "legacy_bridge.h"
#include "combat_state.h"
#include "enemy_state.h"
#include "object_state.h"
#include "room_state.h"
#include "sprite_state.h"


void sprrt_cycle_cur_sprite_index(void) {
    unsigned char idx = (unsigned char)(RAM(0x0341) + 1u);
    if (idx == 0x28) {
        z01_reset_cur_sprite_index();
    } else {
        RAM(0x0341) = idx;
    }
}

unsigned char sprrt_cycle_sprite_index_in_a(unsigned char idx) {
    idx = (unsigned char)(idx + 1u);
    if (idx == 0x28) {
        z01_reset_cur_sprite_index();
        return 0;
    }
    RAM(0x0341) = idx;
    return idx;
}

void sprrt_hide_object_sprites(void) {
    unsigned char d2 = 96;
    do {
        ROOM_OAM_BYTE(d2) = 0xF8;
        d2 = (unsigned char)(d2 + 4u);
    } while (d2 != 0);
    RAM(0x0342) = sprrt_cycle_sprite_index_in_a(RAM(0x0342));
}

void sprrt_show_link_sprites_behind_horizontal_doors(void) {
    /* NES Zelda 1: when Link's body straddles a horizontal screen edge (i.e.,
     * during a side-doorway transition), force his top-half OAM sprites into
     * "behind background" priority by setting OAM attr bit 5. _oam_dma
     * (nes_io.asm) honors bit 5 by clearing Genesis SAT word-2 bit 15, which
     * drops the sprite below high-priority Plane A pixels (every BG tile is
     * promoted to high prio in _compose_bg_tile_word). Door arch opaque
     * pixels then cover Link's head/torso; color-0 floor pixels let his feet
     * show through. Bottom-half sprites stay high-prio so feet remain on top.
     *
     * Slot layout matches original 6502 (z_01:1594): top-left = 18,
     * top-right = 19. The two halves are gated independently by Link's left
     * (link_x) and right (link_x+8) edges so the priority drop tracks the
     * half that's actually crossing the edge mid-transition. */
    unsigned char link_x  = ENEMY_PLAYER_OBJ_X;
    unsigned char x_left  = link_x;
    unsigned char x_right = (unsigned char)(link_x + 8u);
    if (x_left < 0x10u || x_left >= 0xE9u) {
        OAM_SPRITE_ATTR(18) |= 0x20u;
    }
    if (x_right < 0x10u || x_right >= 0xE9u) {
        OAM_SPRITE_ATTR(19) |= 0x20u;
    }
}

/* ---- Plan C: drained from z_07 (animation cluster) --------------------- */

static void sprrt_animate_link_obj_state(void) {
    unsigned char state = LINK_ACTION_TIMER;
    unsigned char major = state & 0x30;
    if (major == 0x10 || major == 0x20) {
        if (state & 0x0F)
            LINK_ACTION_TIMER = state | 0x30;
        else
            LINK_ACTION_TIMER = state + 1;
        OBJ_HFLIP(0) = 1;
    } else if (major == 0x30) {
        LINK_ACTION_TIMER = state & 0xC0;
    }
}

void sprrt_roll_over_anim_counter(unsigned int slot) {
    OBJ_ANIM_CNTR(slot) = COMBAT_WEAPON_SLOT;
    OBJ_HFLIP(slot) ^= 0x01;
}

unsigned char sprrt_anim_fetch_obj_pos(unsigned int slot) {
    COMBAT_WEAPON_SLOT = OBJ_TILE_X(slot);
    ENEMY_SCRATCH_Y = OBJ_TILE_Y(slot);
    ENEMY_FRAME_FLAGS = 0;
    return 0;
}

void sprrt_anim_set_obj_hflip(unsigned int slot) {
    ENEMY_FRAME_FLAGS = OBJ_HFLIP(slot);
}

void sprrt_anim_advance_and_fetch(unsigned int val, unsigned int slot) {
    COMBAT_WEAPON_SLOT = (unsigned char)val;
    OBJ_ANIM_CNTR(slot)--;
    if (OBJ_ANIM_CNTR(slot) == 0) {
        sprrt_roll_over_anim_counter(slot);
    }
    sprrt_anim_fetch_obj_pos(slot);
}

void sprrt_animate_object_walking(unsigned int slot) {
    if (--OBJ_ANIM_CNTR(slot) == 0) {
        if (slot == 0) sprrt_animate_link_obj_state();
        COMBAT_WEAPON_SLOT = 6;
        sprrt_roll_over_anim_counter(slot);
    }
    sprrt_anim_fetch_obj_pos(slot);
    unsigned char dir = ENEMY_DIR(slot) & 0x0C;
    if (dir != 0) {
        sprrt_anim_set_obj_hflip(slot);
    } else {
        if (!(ENEMY_DIR(slot) & 1)) ENEMY_FRAME_FLAGS++;
    }
}
