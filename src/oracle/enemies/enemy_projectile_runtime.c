#include "enemy_projectile_runtime.h"
#include "legacy_bridge.h"
#include "combat_state.h"

/* Bounce-displacement tables for L_BounceShot. The bounce direction
 * index (0..3 from GetOppositeDir) selects width/height pairs.
 * Width table only carries the +1/-1 pair because Y dominates the
 * horizontal-bounce case in the original game; counter starts at 2.
 */
static const unsigned char enrt_shot_bounce_widths[] = {
    0x01, 0xFF
};

static const unsigned char enrt_shot_bounce_heights[] = {
    0xFE, 0x02, 0xFF, 0xFF
};

/* Diagonal-speed lookup tables for fireballs. Index 0..8 picks paired
 * X/Y q-speeds whose magnitudes sum to a constant arc.
 */
static const unsigned char enrt_fireball_qspeeds_x[] = {
    0x70, 0x68, 0x60, 0x58, 0x50, 0x3C, 0x26, 0x10
};

static const unsigned char enrt_fireball_qspeeds_y[] = {
    0x00, 0x10, 0x26, 0x3C, 0x50, 0x58, 0x60, 0x68,
    0x70
};

extern void core_reset_obj_metastate(unsigned int slot);

void enrt_init_monster_shot(unsigned int slot) {
    ENEMY_WALK_SPEED(slot) = 0xC0;
    core_reset_obj_metastate(slot);
}

/* NES Z_04.asm:200 _InitMonsterShot_Unknown54 — QSpeed $E0 variant
 * (3.5 px/frame, faster than the base $C0 flying rock). NES dispatch
 * table @ Z_07.asm:5686 maps type $54 to this entry. */
void enrt_init_monster_shot_unknown54(unsigned int slot) {
    ENEMY_WALK_SPEED(slot) = 0xE0;
    core_reset_obj_metastate(slot);
}

void enrt_init_boulder(unsigned int slot) {
    z07_reset_obj_metastate_and_timer(slot);
    enrt_init_tektite(slot);
}

void enrt_init_boulder_set(unsigned int slot) {
    ENEMY_BOULDER_SET_COUNT = 0;
    enrt_init_boulder(slot);
}

void enrt_destroy_monster_shot(unsigned int slot) {
    unsigned char type = ENEMY_TYPE(slot);
    if (type != 0x55 && type != 0x56)
        ENEMY_SHOT_COUNT--;
    z07_destroy_monster(slot);
}

void enrt_destroy_counted_monster_shot(unsigned int slot) {
    ENEMY_SHOT_COUNT--;
    z07_destroy_monster(slot);
}

void enrt_destroy_monster_bank4(unsigned int slot) {
    ENEMY_TYPE(slot) = 0;
    z07_set_shove_info_with0(0, slot);
    ENEMY_MOVE_TIMER(slot) = 0;
    ENEMY_STATE_TIMER(slot) = 0;
    ENEMY_HIT_REACTION(slot) = 0;
    ENEMY_ALIVE_FLAG(slot) = 0xFF;
    ENEMY_METASTATE(slot) = 1;
}

void enrt_shoot_fireball(unsigned int type, unsigned int source_slot) {
    unsigned int new_slot;
    ENEMY_SHOT_TYPE_SCRATCH = (unsigned char)type;
    new_slot = z07_find_empty_monster_slot();
    if (new_slot == 0)
        return;
    z07_set_type_and_clear_object(ENEMY_SHOT_TYPE_SCRATCH, new_slot);
    ENEMY_X(new_slot) = (unsigned char)(ENEMY_X(source_slot) + 4);
    ENEMY_Y(new_slot) = ENEMY_Y(source_slot);
}

void enrt_shoot_fireball_55(unsigned int source_slot) {
    enrt_shoot_fireball(85, source_slot);
}

void enrt_update_candle(void) {
    unsigned char state = ENEMY_CANDLE_STATE;
    if (state == 0) {
        if (enrt_is_dark_room_bank4(ENEMY_CANDLE_ROOM_ID) != 0) {
            ENEMY_CANDLE_FADE_TRIGGER = 0xC0;
            ENEMY_CANDLE_FADE_PHASE++;
            ENEMY_CANDLE_STATE++;
        }
    } else if (state == 1) {
        if (z01_animate_world_fading() == 0) {
            ENEMY_CANDLE_FADE_PHASE = 0;
            ENEMY_CANDLE_STATE++;
        }
    }
}

void enrt_update_boulder_set(unsigned int slot) {
    if (ENEMY_MOVE_TIMER(slot) != 0) {
        ENEMY_MOVE_TIMER(slot) = (unsigned char)(ENEMY_MOVE_TIMER(slot) + ENEMY_RNG_B(slot));
        return;
    }
    if (ENEMY_BOULDER_SET_COUNT == 3) {
        ENEMY_MOVE_TIMER(slot) = (unsigned char)(ENEMY_MOVE_TIMER(slot) + ENEMY_RNG_B(slot));
        return;
    }
    {
        unsigned int new_slot = z07_find_empty_monster_slot();
        if (new_slot == 0)
            return;

        ENEMY_BOULDER_SET_COUNT++;
        z07_set_type_and_clear_object(32, new_slot);

        {
            unsigned char rng = ENEMY_RNG_B(new_slot);
            if (LINK_X >= 0x80)
                rng |= 0x80;
            else
                rng &= 0x7F;
            ENEMY_X(new_slot) = rng;
        }
        ENEMY_Y(new_slot) = 64;
    }
    ENEMY_MOVE_TIMER(slot) = (unsigned char)((8 + ENEMY_RNG_B(slot)) & 0x1F);
}

/* L_DrawShot — sprite descriptor + flash attribute selection for shots.
 *   - Arrow ($5B)              -> DrawArrow
 *   - Sword/magic shot ($57..$59) -> DrawSwordShotOrMagicShot
 *   - Else: prep position, pick attr (flash if type >= $55, else shift X+4)
 */
void enrt_draw_shot(unsigned int slot) {
    unsigned char type = ENEMY_TYPE(slot);
    if (type == 0x5B) {
        c_draw_arrow(slot);
        return;
    }
    if (type >= 0x57 && type < 0x5A) {
        c_draw_sword_shot_or_magic_shot(slot);
        return;
    }

    /* Other shots: fetch position into RAM[$00]/RAM[$01], stash tile in
     * RAM[$0D] for the impending DrawObjectNotMirrored. */
    {
        unsigned char tile = z07_anim_fetch_obj_pos(slot);
        COMBAT_THRESHOLD_X = tile;
    }

    /* Default: flash attribute from frame counter low bits. */
    {
        unsigned int attr = (unsigned int)(ENEMY_CUR_SPRITE_ATTR_ROW & 0x03);
        unsigned char draw_type = ENEMY_TYPE(slot);
        if (draw_type < 0x55) {
            /* Flying-rock variants: shift sprite X right by 4 and force
             * sprite attribute 0 (no flashing). */
            ENEMY_SCRATCH_X = (unsigned char)(ENEMY_SCRATCH_X + 4);
            attr = 0;
        }
        z01_anim_set_sprite_desc_attrs(attr);
    }

    c_draw_object_not_mirrored(slot);
}

/* BounceShot — adjust X/Y by reverse-direction displacement vector and
 * tick the bounce counter; destroy when counter saturates, otherwise
 * fall through to L_DrawShot.
 */
void enrt_bounce_shot(unsigned int slot) {
    unsigned char bounce_dir = OBJ(0x0380, slot);
    /* GetOppositeDir packs: low byte = opposite direction, bits 8..15 =
     * direction index (D3 in asm). The bounce tables are indexed by D3. */
    unsigned int packed = z01_get_opposite_dir((unsigned int)bounce_dir);
    unsigned int dir_idx = (packed >> 8) & 0xFF;

    /* Apply Y then X displacement (6502 ADC with C=0 -> plain add). */
    {
        unsigned char y = ENEMY_Y(slot);
        ENEMY_Y(slot) = (unsigned char)(y + enrt_shot_bounce_heights[dir_idx & 3]);
    }
    {
        unsigned char x = ENEMY_X(slot);
        ENEMY_X(slot) = (unsigned char)(x + enrt_shot_bounce_widths[dir_idx & 1]);
    }

    /* Tick bounce counter; destroy when it crosses $20. */
    {
        unsigned char counter = (unsigned char)(OBJ(0x0394, slot) + 2);
        OBJ(0x0394, slot) = counter;
        if (counter >= 0x20) {
            enrt_destroy_monster_shot(slot);
            return;
        }
    }

    enrt_draw_shot(slot);
}

/* CheckShotLinkCollision — reset bounce distance, look for a Link hit;
 * if hit, prime bounce direction and switch to bounce state $30.
 */
void enrt_check_shot_link_collision(unsigned int slot) {
    OBJ(0x0394, slot) = 0;
    z01_check_link_collision(slot);
    if (ROOM_MONSTER_COLLISION_COUNT == 0)
        return;
    /* Bounce off Link's shield: copy Link's facing direction into the
     * shot's bounce-direction slot and put it into bounce state $30. */
    OBJ(0x0380, slot) = LINK_DIR;
    ENEMY_STATE_TIMER(slot) = 48;
}

/* UpdateMonsterShot — main per-frame update for slow shots (rocks,
 * arrows, sword shots, magic shots, boomerangs). State byte high nibble
 * encodes phase: $1x = active, anything else = bouncing.
 */
/* UpdateMonsterArrow (NES Z_04.asm:2102) per-frame body. Stopgap drain
 * (full UpdateArrowOrBoomerang state machine at Z_07.asm:3813 deferred).
 * Mirror the q-speed=$80 seed (2 px/frame) and fall through to
 * enrt_update_monster_shot which handles tile collision + Link
 * collision + draw via L_DrawShot ($5B draws via DrawArrow). The
 * arrow-spark/bounce state branches ($20/$30 paths) are omitted
 * pending full drain. */
void enrt_update_monster_arrow(unsigned int slot) {
    ENEMY_WALK_SPEED(slot) = 0x80u;
    enrt_update_monster_shot(slot);
}

/* BoomerangQSpeedFracsX (NES Z_07.asm:3791). */
static const unsigned char k_boomerang_qspeed_x[9] = {
    0x80, 0x78, 0x70, 0x68, 0x60, 0x4C, 0x36, 0x20, 0x00
};
/* BoomerangQSpeedFracsY (NES Z_07.asm:3787). */
static const unsigned char k_boomerang_qspeed_y[9] = {
    0x00, 0x20, 0x36, 0x4C, 0x60, 0x68, 0x70, 0x78, 0x80
};

/* UpdateArrowOrBoomerang (NES Z_07.asm:3813) — full state-machine
 * drain for $5C goriya boomerang. State byte high nibble encodes:
 *   $00 = inactive (return without doing anything)
 *   $10 = flying out from thrower (use enrt_update_monster_shot tick)
 *   $20 = sparking (on collision/block) — decrement timer, then $40
 *   $30 = slowing down (qspeed=$40, count ObjMovingLimit, then $40)
 *   $40 = returning slow toward thrower
 *   $50 = returning fast toward thrower
 *
 * Monster boomerangs ($5C) have ObjRefId (NES $042C+slot) pointing to
 * the thrower slot (the goriya). State transitions follow NES exactly
 * for the return-to-thrower path; on reach (dist < 2) the boomerang
 * destroys itself + resets thrower state (NES @CatchBoomerang gives
 * thrower a $30/$50/$70 idle timer based on Random).
 *
 * Tile collision / boundary handling: delegated to
 * enrt_update_monster_shot path. State entry done here. */
void enrt_update_arrow_or_boomerang(unsigned int slot) {
    unsigned char state    = (unsigned char)ENEMY_STATE_TIMER(slot);
    unsigned char state_hi = (unsigned char)(state & 0xF0u);

    /* @State == 0 → inactive. NES BEQ L1F49F_Exit. */
    if (state == 0u) return;

    /* State $10 → fly out. Move via enrt_update_monster_shot then
     * check boomerang range limit. NES Z_07.asm:3881-3905 reads
     * |ObjGridOffset| and compares to ObjMovingLimit; on reach,
     * transitions state $20 + sets ObjMovingLimit=$10 + anim=3
     * (HandleArrowOrBoomerangBlocked path advances to $30). */
    if (state_hi == 0x10u) {
        enrt_update_monster_shot(slot);
        /* If destroyed (type cleared), bail. */
        if ((unsigned char)ENEMY_TYPE(slot) != 0x5Cu) return;
        /* Range check. |GridOffset| >= ObjMovingLimit → blocked path. */
        {
            unsigned char grid = OBJ(NES_OBJ_GRID_OFFSET, slot);
            unsigned char abs_grid = (grid & 0x80u) ? (unsigned char)(0u - grid) : grid;
            unsigned char limit = OBJ(0x0380u, slot);
            if (abs_grid >= limit) {
                /* NES HandleArrowOrBoomerangBlocked: anim_counter=3,
                 * state += $10 → $30. ObjMovingLimit reset to $10. */
                OBJ(0x0380u, slot)      = 0x10u;
                ENEMY_DRAW_FRAME(slot)  = 3u;
                ENEMY_STATE_TIMER(slot) = 0x30u;
            }
        }
        return;
    }

    /* State $20 → spark. Decrement anim counter; on 0 advance state
     * (to $40 for boomerang, deactivate for arrow). NES Z_07.asm:3958. */
    if (state_hi == 0x20u) {
        /* Set sub-state $28 (preserve animation flag). */
        ENEMY_STATE_TIMER(slot) = 0x28u;
        if (ENEMY_DRAW_FRAME(slot) != 0u) {
            ENEMY_DRAW_FRAME(slot) =
                (unsigned char)(ENEMY_DRAW_FRAME(slot) - 1u);
        } else {
            /* Anim counter hit 0 → transition state $40 + handle blocked. */
            ENEMY_STATE_TIMER(slot) = 0x40u;
            ENEMY_DRAW_FRAME(slot)  = 3u;       /* NES @HandleBlocked sets to 3 */
            ENEMY_STATE_TIMER(slot) =
                (unsigned char)(ENEMY_STATE_TIMER(slot) + 0x10u);  /* → $50 */
        }
        return;
    }

    /* State $30 → slow down. NES Z_07.asm:4052-4099. */
    if (state_hi == 0x30u) {
        OBJ(NES_OBJ_GRID_OFFSET, slot) = 0u;
        ENEMY_WALK_SPEED(slot) = 0x40u;        /* qspeed = 1 px/frame */
        /* Edge-guard: facing-left + X<2 → state $40 to avoid wrap. */
        if (((unsigned char)ENEMY_DIR(slot) & 0x02u) != 0u
            && (unsigned char)ENEMY_X(slot) < 0x02u) {
            ENEMY_STATE_TIMER(slot) = 0x40u;
            OBJ(0x0380u, slot) = 0x20u;        /* ObjMovingLimit reset */
            return;
        }
        RAM(NES_OBJ_DIR) = (unsigned char)ENEMY_DIR(slot);
        c_move_object((unsigned short)slot);
        /* ObjMovingLimit decrement; on 0 → state $40. */
        {
            unsigned char ml = OBJ(0x0380u, slot);
            ml = (unsigned char)(ml - 1u);
            OBJ(0x0380u, slot) = ml;
            if (ml == 0u) {
                ENEMY_STATE_TIMER(slot) = 0x40u;
                OBJ(0x0380u, slot)      = 0x20u;
            }
        }
        return;
    }

    /* State $40/$50 → return to thrower. NES Z_07.asm:4101-4180.
     * Monster boomerang reads ObjRefId for thrower slot. */
    {
        unsigned char thrower_slot = OBJ(0x042Cu, slot);  /* ObjRefId */
        OBJ(NES_OBJ_GRID_OFFSET, slot) = 0u;

        z01_get_directions_and_distances_to_target(thrower_slot, slot);

        /* RAM[$00] = #axes where distance <= 8. If == 2, reached. */
        if (RAM(0x0000u) == 0x02u) {
            /* Reached thrower. Reset ObjMovingLimit + handle catch. */
            OBJ(0x0380u, slot) = 0u;
            /* Monster catch path (NES @CatchBoomerang). Set thrower
             * idle timer based on Random+slot. */
            {
                unsigned char rng = (unsigned char)ENEMY_RNG_A(slot);
                unsigned char timer;
                if (rng < 0x30u)      timer = 0x30u;
                else if (rng < 0x70u) timer = 0x50u;
                else                  timer = 0x70u;
                OBJ(0x0028u, thrower_slot) = timer;    /* ObjTimer */
                OBJ(0x00ACu, thrower_slot) = 0u;        /* ObjState idle */
            }
            enrt_destroy_counted_monster_shot(slot);
            return;
        }

        /* @MoveTowardThrower (NES Z_07.asm:4182). Diagonal speed index
         * 4 (equal X/Y); BoomerangQSpeedFracs tables. */
        {
            unsigned char vdir = (unsigned char)RAM(0x000Au);  /* vertical dir from target probe */
            unsigned char hdir = (unsigned char)RAM(0x000Bu);  /* horizontal dir */
            /* Vertical move. */
            ENEMY_WALK_SPEED(slot) = k_boomerang_qspeed_y[4];
            RAM(NES_OBJ_DIR)       = vdir;
            ENEMY_DIR(slot)        = vdir;
            c_move_object((unsigned short)slot);
            /* Horizontal move. */
            ENEMY_WALK_SPEED(slot) = k_boomerang_qspeed_x[4];
            RAM(NES_OBJ_DIR)       = hdir;
            ENEMY_DIR(slot)        = hdir;
            c_move_object((unsigned short)slot);
        }

        /* Check Link collision on returning boomerang (NES line 4235). */
        enrt_check_shot_link_collision(slot);
        if (ENEMY_COLLISION_FLAG != 0u) {
            ENEMY_DRAW_FRAME(slot) = 3u;
            ENEMY_STATE_TIMER(slot) = 0x20u;     /* spark on hit */
        }
    }
}

void enrt_update_monster_shot(unsigned int slot) {
    /* Sync transient direction byte with this object's facing. */
    ENEMY_FRAME_FLAGS = ENEMY_DIR(slot);

    {
        unsigned char state_hi = (unsigned char)(ENEMY_STATE_TIMER(slot) & 0xF0);
        if (state_hi != 0x10) {
            enrt_bounce_shot(slot);
            return;
        }
    }

    {
        unsigned char type = ENEMY_TYPE(slot);
        if (type < 0x55) {
            /* Flying-rock-class shot ($53). */
            if (ENEMY_MOVE_TIMER(slot) != 0) {
                /* Held back by timer: only check Link collision. */
                enrt_check_shot_link_collision(slot);
                if (ENEMY_COLLISION_FLAG != 0)
                    enrt_destroy_monster_shot(slot);
                return;
            }
            /* Tile collision check; destroy on contact with floor tile. */
            {
                unsigned char tile = z07_get_colliding_tile_moving(slot);
                unsigned char floor = ENEMY_DUNGEON_TILE_FLOOR;
                if (tile >= floor) {
                    enrt_destroy_monster_shot(slot);
                    return;
                }
            }
            /* Fall through to @CheckBoundary per NES Z_04.asm:846-851 —
             * after the tile-collide check, flying-rock branch JOINS
             * the boundary check. Prior drain made @CheckBoundary
             * exclusive to the else branch, so flying rocks never
             * despawned when crossing room edges (visible bug: shots
             * persisted off-screen forever, eating projectile slots). */
        }
        /* @CheckBoundary — NES Z_04.asm:847. No shots cross room edges. */
        if (z01_bound_by_room(slot) == 0) {
            enrt_destroy_monster_shot(slot);
            return;
        }
    }

    /* Move, then check for Link collision. */
    c_move_object((unsigned short)slot);
    enrt_check_shot_link_collision(slot);
    if (ENEMY_COLLISION_FLAG != 0) {
        enrt_destroy_monster_shot(slot);
        return;
    }
    /* Step 12: NES UpdateMonsterShot falls through to L_DrawShot
     * (Z_04.asm:860). Prior drain returned here; matches NES now. */
    enrt_draw_shot(slot);
}

/* Fireball_MoveOneAxis — load q-speed and position fraction, run a
 * single MoveObject pass, return the updated fraction.
 *   D0 = q-speed, D3 = position fraction (in)
 *   returns updated position fraction (D0 in asm).
 */
unsigned char enrt_fireball_move_one_axis(unsigned char qspeed, unsigned char pos_frac, unsigned int slot) {
    OBJ(0x03BC, slot) = qspeed;
    OBJ(0x03A8, slot) = pos_frac;
    c_move_object((unsigned short)slot);
    return OBJ(0x03A8, slot);
}

/* UpdateFireball — two-state monster shot: state 0 chooses an aim and
 * q-speeds, state 1 ticks the delay/move and checks for collision.
 */
void enrt_update_fireball(unsigned int slot) {
    if (ENEMY_STATE_TIMER(slot) == 0) {
        /* State 0: pick direction & speeds. */

        /* Reset horizontal/vertical position fractions. */
        OBJ(0x0451, slot) = 0;
        OBJ(0x045E, slot) = 0;

        /* Aim at Link (slot 0). Returns Link's vertical dir at RAM[$0A]
         * and horizontal dir at RAM[$0B] in the original ABI. */
        z01_get_directions_and_distances_to_target(0, slot);

        OBJ(0x0412, slot) = COMBAT_ABS_DY; /* horizontal direction */
        OBJ(0x0437, slot) = COMBAT_ABS_DX; /* vertical direction */

        /* Combined facing = horizontal | vertical. */
        ENEMY_DIR(slot) = (unsigned char)(COMBAT_ABS_DX | COMBAT_ABS_DY);

        /* Pick the diagonal speed index (mid index = 4) and look up
         * paired q-speeds. */
        {
            unsigned int idx = z01_calc_diagonal_speed_index(4) & 0xFF;
            OBJ(0x041F, slot) = enrt_fireball_qspeeds_x[idx];
            OBJ(0x0444, slot) = enrt_fireball_qspeeds_y[idx];
        }

        /* Enter state $10 with timer $10 (visible delay before motion). */
        ENEMY_STATE_TIMER(slot) = 0x10;
        ENEMY_MOVE_TIMER(slot) = 0x10;
        return;
    }

    /* State 1: delay then move + collision-check + draw. */
    if (ENEMY_MOVE_TIMER(slot) == 0) {
        /* Off the leash: room-boundary check first. */
        if (z01_bound_by_room_with_a(ENEMY_DIR(slot), slot) == 0) {
            z07_destroy_monster(slot);
            return;
        }

        /* Move along horizontal axis. */
        ENEMY_FRAME_FLAGS = OBJ(0x0412, slot);
        OBJ(0x0451, slot) = enrt_fireball_move_one_axis(OBJ(0x041F, slot), OBJ(0x0451, slot), slot);

        /* Move along vertical axis. */
        ENEMY_FRAME_FLAGS = OBJ(0x0437, slot);
        OBJ(0x045E, slot) = enrt_fireball_move_one_axis(OBJ(0x0444, slot), OBJ(0x045E, slot), slot);
    }

    /* Collision check + draw. */
    enrt_check_shot_link_collision(slot);
    if (ROOM_MONSTER_COLLISION_COUNT != 0) {
        z07_destroy_monster(slot);
        return;
    }
    enrt_draw_shot(slot);
}
