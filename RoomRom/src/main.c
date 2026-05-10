#include <genesis.h>
#include "roomrom_debug_runtime.h"
#include "ow_room_render_roomrom.h"
#include "uw_room_render_roomrom.h"
#include "roomrom_hud.h"
#include "roomrom_sprites.h"
#include "roomrom_combat.h"
#include "roomrom_boomerang.h"
#include "roomrom_arrow.h"
#include "roomrom_bomb.h"
#include "roomrom_magic_shot.h"
#include "roomrom_scene_load.h"
#include "roomrom_palette_tick.h"
#include "cave_dispatch.h"  /* debate 006 D2: native cave gamemode entry */
#include "uw_door_state.h"
#include "uw_walk_model.h"
#include "render_abi.h"
#include "roomrom_main_state.h"  /* Task 5.4: warp-outcome apply boundary */
#include "roomrom_world_transition.h"  /* Task 5.4: warp coordinator */
#include "uw_cellar_meta.h"             /* Task 5.6: cellar pair lookup */
#include "uw_push_block_meta.h"         /* Task 5.7: push-block manifest */
#include "roomrom_pushblock.h"           /* Task 5.7: push-block state machine */
#include "uw_dark_meta.h"                /* Task 5.8: dark-room manifest */
#include "uw_item_room_meta.h"           /* Task 5.9: item-room manifest + pickup */
#include "roomrom_candle_fire.h"         /* Task 5.8.1: candle fire projectile */
#include "roomrom_pause.h"               /* Task 6.10.1: Paused flag */
#include "roomrom_link_damage.h"         /* Task 6.11.1: HeartValues damage */
#include "inventory.h"                   /* Task 6.10.10: rupee tick */
#include "probes/metadata_probe.h"     /* Task 5.4: Gate D in-ROM probe */
#include "atlas/level_chr_swap.h"        /* PR-4a: scene-bank DMA state machine */
#include "player_state.h"                 /* Phase 6 Task 6.1: typed players[] */
#include "enemy_loop.h"                   /* Phase 7 Task 7.2 step 2 (WT-5) */
#include "enemy_loop_probe.h"             /* Phase 7 Task 7.2 step 2 probe */
#include "options_probe.h"                /* Phase 9 Task 9.1 in-ROM tests */
#include "options_persistence_probe.h"    /* Phase 9 Task 9.2 SRAM tests */
#include "options_persistence.h"          /* Phase 9 Task 9.4 load-or-default */
#include "options_consumer.h"             /* Phase 9 Task 9.4 game-start hook */
#include "options_consumer_probe.h"       /* Phase 9 Task 9.4 consumer tests */

/* Boots to overworld room 0x77.
 *
 * Modes (toggled by X):
 *   WALK       D-pad moves Link
 *   TELEPORT   D-pad jumps room (16x8 grid: room_id = (row<<4)|col)
 *
 * Walk style (toggled by Y):
 *   NES        Z1-faithful: single-axis only, grid-locked turns,
 *              QSpeed=$60 -> 1.5 px/frame avg, instant stop on release.
 *              Source: reference/aldonunez/Z_05.asm Link_HandleInput +
 *              Z_07.asm Walker_Move / MoveObject.
 *   ALTTP      8-direction (real diagonal), 8.8 sub-pixel position,
 *              cardinal vel=24, diagonal vel=16 (sqrt(2) compensation).
 *              Source: github.com/snesrev/zelda3 src/player.c
 *              Link_HandleVelocity + Link_MovePosition + kSpeedMod.
 *
 * Buttons (always):
 *   X         toggle WALK <-> TELEPORT
 *   Y         toggle NES <-> ALTTP walk style
 *   A         swing sword
 *   B         use selected B-item (boomerang/arrow/bomb/candle/rod)
 *   Z         cycle B-item slot forward
 *   C         map variant toggle (original <-> redux), per-scene
 *   START     scene toggle (overworld <-> dungeon)
 *   Z+START   (dungeon scene) toggle quest 1 <-> 2
 *
 *   MODE button is reserved (Genesis 6-button hardware mode select)
 *   and intentionally unbound. */

/* SCENE_CAVE (debate 006 D2 follow-up): native cave gamemode harness.
 * Toggle from SCENE_OW with C+START. While SCENE_CAVE is active the
 * main loop calls cave_tick per VBlank — currently a stub, so the
 * scene visually inherits OW (no dedicated cave render until Phase 4
 * native object_draw lands). C+START again exits back to SCENE_OW
 * and calls cave_exit. */
typedef enum { SCENE_OW = 0, SCENE_UW = 1, SCENE_CAVE = 2 } scene_t;
typedef enum { MODE_WALK = 0, MODE_TELEPORT = 1 } mode_t;
typedef enum { MOVE_STYLE_NES = 0, MOVE_STYLE_ALTTP = 1 } move_style_t;

/* NES Z1 movement direction (matches Z_05.asm Link_ModifyDir bit layout
 * conceptually: only one axis at a time, no diagonal). */
typedef enum {
    LINK_DIR_NONE  = 0,
    LINK_DIR_DOWN  = 1,
    LINK_DIR_UP    = 2,
    LINK_DIR_LEFT  = 3,
    LINK_DIR_RIGHT = 4
} link_dir_t;

/* TEST DEFAULTS: boot into UW room $73 (L1 entrance). 5.9 verified
 * via boot=$36 at triforce coords (auto-probe + gate_5_9 PASS);
 * default restored. */
static scene_t       s_scene       = SCENE_UW;
static mode_t        s_mode        = MODE_WALK;
static move_style_t  s_move_style  = MOVE_STYLE_NES;
static u8 s_room_id = 0x73;
/* Phase 6 Task 6.1: Link position/facing now lives in `players[0]`.
 * Boot defaults are seeded in `init_player_state()` below before any
 * scene/render code runs. */
/* Ph5.3: key inventory for UW door gating. Start with 3 for dev testing. */
static unsigned char s_link_keys = 99u;  /* Task 5.5 debug: full L1 traversal */

/* S7 B-item slot (cycle with Z, fire with B). Order roughly matches
 * Z1 inventory grid: boomerang -> bombs -> arrow -> candle -> rod. */
typedef enum {
    B_ITEM_NONE      = 0,
    B_ITEM_BOOMERANG = 1,
    B_ITEM_ARROW     = 2,
    B_ITEM_BOMB      = 3,
    B_ITEM_CANDLE    = 4,
    B_ITEM_ROD       = 5,
    B_ITEM_COUNT     = 6
} b_item_t;
static b_item_t s_b_item = B_ITEM_BOOMERANG;
static link_dir_t  s_link_dir  = LINK_DIR_NONE;  /* NES ObjDir: last active axis */
static unsigned char s_doorway_dir = UW_WALK_DOOR_NONE; /* active UW doorway */
static signed char s_link_grid_offset = 0;       /* NES ObjGridOffset: -8..8 */
static u8          s_link_pos_frac   = 0u;       /* NES single-axis sub-pixel */
static u8          s_link_subx       = 0u;       /* ALTTP per-axis sub-pixel X */
static u8          s_link_suby       = 0u;       /* ALTTP per-axis sub-pixel Y */

/* Task 5.4: NES `UndergroundExitType` analogue. Slice 1 wires this static
 * into the warp coordinator's rule-1 precondition but never writes it —
 * the writer is the deferred UW->OW exit slice. Until then the rule
 * collapses to "grid_offset == 0", which slice-1 acknowledges in the
 * spec rather than pretending it enforces both halves. */
static u8          s_underground_exit_type = 0u;

/* Task 5.8/5.9 perf: per-room cache of expensive lookups. Refreshed
 * in load_room on every room change. Per-tick reads are O(1) instead
 * of full master-table linear scan (uw_dark_rooms 261 rows +
 * uw_item_rooms 969 rows would otherwise burn ~80% of frame budget). */
static u8          s_cur_room_is_dark   = 0u;
static u8          s_cur_room_is_cellar = 0u;
static u8          s_cur_room_has_item  = 0u;
static struct uw_item_room_meta s_cur_room_item_meta;

/* Task 5.5: per-touch latch for the state-mirror diff harness. */
static unsigned char s_last_touch_dir       = 0xFFu;
static unsigned char s_last_touch_result    = 0xFFu;
static unsigned char s_last_touch_keys_pre  = 0u;
static unsigned char s_last_touch_keys_post = 0u;
static unsigned char s_last_touch_door_type = 0xFFu;
static unsigned char s_uw_shutter_trigger_count = 0u;

/* S6.6 transition state machine.
 * BG_A is a 64x64 tile staging plane split into four 32x32 screen slots.
 * The fixed HUD is drawn on Window, so BG_A can scroll as one plane in both
 * axes without a per-row vertical split. */
#define SCROLL_TOTAL_FRAMES 64u   /* 4 px/frame x 64 = 256 px = full slot */
#define SCROLL_PX_PER_FRAME 4
#define ROOMROM_SLOT_TILES 32u
#define ROOMROM_SLOT_PIXELS ((short)(ROOMROM_SLOT_TILES * 8u))
/* PR-2: 64x32 plane layout — BG_A holds active room (rows 7..28),
 * BG_B is V scroll staging (also rows 7..28). BG_A H scroll uses two
 * 32-col slots within the 64-wide plane. */
#define ROOMROM_VERTICAL_STRIDE_TILES ROOMROM_ROOM_ROWS
#define ROOMROM_PLAYFIELD_TOP_PX ((short)(ROOMROM_ROOM_FIRST_ROW * 8u))

typedef enum {
    SCROLL_NONE    = 0,
    SCROLL_H_RIGHT = 1,   /* Link walked right; new room slides in from right */
    SCROLL_H_LEFT  = 2,   /* Link walked left;  new room slides in from left */
    SCROLL_V_DOWN  = 3,   /* Link walked down;  new room slides in from bottom */
    SCROLL_V_UP    = 4    /* Link walked up;    new room slides in from top */
} scroll_state_t;

static scroll_state_t s_scroll_state    = SCROLL_NONE;
static u8             s_scroll_frame    = 0u;     /* counts up during scroll */
static u8             s_scroll_total_frames = SCROLL_TOTAL_FRAMES;
static u8             s_active_slot_x   = 0u;     /* 0 = cols 0..31, 1 = cols 32..63 */
static u8             s_active_row_base = 0u;     /* room base row in the 64-row plane */
static u8             s_transition_target = 0u;
static u8             s_transition_row_base = 0u;
/* PR-2b: BG_A is always the active plane; BG_B is V scroll staging only.
 * Incoming room is rendered into BG_B at scroll start, both planes scroll
 * independently (independent VSCROLL_PLANE), then on finalize we re-render
 * the incoming room into BG_A and clear BG_B for the next staging cycle.
 * s_scroll_v_offset = BG_B v_scroll - BG_A v_scroll, held constant across
 * the animation. -176 for V_DOWN, +176 for V_UP. */
static short          s_scroll_v_offset = 0;
static short          s_active_scroll_x = 0;
static short          s_active_scroll_y = 0;
static short          s_scroll_start_x = 0;
static short          s_scroll_start_y = 0;
static short          s_scroll_target_x = 0;
static short          s_scroll_target_y = 0;
/* Pre-scroll Link screen position (where he was when edge was crossed). */
static short          s_scroll_start_link_x = 0;
static short          s_scroll_start_link_y = 0;
/* Post-scroll Link screen position (entry pos in the new room). */
static short          s_transition_link_x = 0;
static short          s_transition_link_y = 0;

/* Increments every frame; used by Phase 2.6.5 palette tick. */
static u16 s_frame_counter = 0u;
static u16 s_joy_prev = 0u;

/* Map room metatile col 0..15 into one 32x32 staging slot. */
static u8 plane_col_for_slot(u8 src_col, u8 slot_x)
{
    return (u8)(src_col + (slot_x ? 16u : 0u));
}

static short scroll_x_offset_for_slot(u8 slot)
{
    return slot ? (short)-ROOMROM_SLOT_PIXELS : 0;
}

static u8 frames_for_scroll_delta(short delta)
{
    if (delta < 0) delta = (short)-delta;
    return (u8)((delta + SCROLL_PX_PER_FRAME - 1) / SCROLL_PX_PER_FRAME);
}

static void set_bg_scroll(short h_scroll, short v_scroll)
{
    VDP_setHorizontalScroll(BG_A, h_scroll);
    VDP_setVerticalScroll(BG_A, v_scroll);
}

static void anchor_active_slot(void)
{
    set_bg_scroll(s_active_scroll_x, s_active_scroll_y);
}

/* Render a room into the specified horizontal slot and vertical row base. */
static void render_room_into_slot(u8 room_id, u8 slot_x, u8 row_base)
{
    u8 c;
    if (s_scene == SCENE_UW) {
        for (c = 0; c < 16; c++) {
            roomrom_uw_room_render_fill_one_col_at(room_id, c,
                plane_col_for_slot(c, slot_x), row_base);
        }
    } else {
        for (c = 0; c < 16; c++) {
            roomrom_ow_room_render_fill_one_col_at(room_id, c,
                plane_col_for_slot(c, slot_x), row_base);
        }
    }
}
static u8          s_link_frame = 0u;
static u8          s_link_anim_tick = 0u;
#define LINK_ANIM_PERIOD 8u
#define LINK_GRID_SIZE   8
#define LINK_QSPEED      0x60u   /* NES Z_05.asm InitLinkSpeed: $60 = 1.5 px/frame avg */

static unsigned char link_nes_grid_at_limit(void)
{
    return (s_link_grid_offset == LINK_GRID_SIZE ||
            s_link_grid_offset == -LINK_GRID_SIZE) ? 1u : 0u;
}

static unsigned char link_nes_add_qspeed(void)
{
    unsigned short sum = (unsigned short)s_link_pos_frac + LINK_QSPEED;
    s_link_pos_frac = (u8)(sum & 0xFFu);
    if (link_nes_grid_at_limit()) return 0u;
    if (sum >= 0x100u) {
        s_link_grid_offset++;
        return 1u;
    }
    return 0u;
}

static unsigned char link_nes_sub_qspeed(void)
{
    int diff = (int)s_link_pos_frac - (int)LINK_QSPEED;
    s_link_pos_frac = (u8)(diff & 0xFF);
    if (link_nes_grid_at_limit()) return 0u;
    if (diff < 0) {
        s_link_grid_offset--;
        return 1u;
    }
    return 0u;
}

static void link_nes_finish_grid_cell(void)
{
    if (link_nes_grid_at_limit()) {
        s_link_grid_offset = 0;
    }
}

static void link_nes_move_object(link_dir_t dir)
{
    unsigned char q;
    for (q = 0u; q < 4u; q++) {
        switch (dir) {
            case LINK_DIR_RIGHT:
                if (link_nes_add_qspeed()) players[0].x++;
                break;
            case LINK_DIR_DOWN:
                if (link_nes_add_qspeed()) players[0].y++;
                break;
            case LINK_DIR_LEFT:
                if (link_nes_sub_qspeed()) players[0].x--;
                break;
            case LINK_DIR_UP:
                if (link_nes_sub_qspeed()) players[0].y--;
                break;
            default:
                return;
        }
    }
    link_nes_finish_grid_cell();
}

static void init_video(void)
{
    VDP_setScreenWidth256();
    /* PR-2 (PR-2b fix): 64x32 plane mode. Use SGDK's VDP_setPlaneSize
     * with setupVram=TRUE so SGDK's internal planeWidth/planeHeight/
     * windowWidth caches AND VRAM table addresses get configured for
     * case 11 defaults (BGB@$C000, Window@$D000, BGA@$E000, HScroll@
     * $F000, SAT@$F400). render_mode_set_h64v32 is a no-go because the
     * hand-rolled adapter doesn't update SGDK's cached state — Title's
     * 64x64 cache values stick and SGDK plane writes (VDP_setTileMapXY,
     * Window writes) land at wrong VRAM offsets. Then swap BGA/BGB so
     * BG_A holds the active room (rows 7..28) and BG_B is V scroll
     * staging during N/S transitions, copied back to BG_A on finalize.
     * Frees 192 tiles vs old 64x64 mode. */
    VDP_setPlaneSize(64, 32, TRUE);
    VDP_setBGAAddress(0xC000u);
    VDP_setBGBAddress(0xE000u);
    VDP_setWindowOnTop(ROOMROM_HUD_ROWS);
    /* PR-2b fix: keep hand-rolled adapter's stride cache in sync with the
     * 64-wide plane so render_plane_a_write_row / render_set_plane_*_word
     * (if ever used) compute the right offsets. */
    render_mode_set_h64v32();
    /* Independent H/V scroll per plane so BG_B can stage V incoming. */
    VDP_setScrollingMode(HSCROLL_PLANE, VSCROLL_PLANE);
    VDP_setHorizontalScroll(BG_A, 0);
    VDP_setVerticalScroll(BG_A, 0);
    VDP_setHorizontalScroll(BG_B, 0);
    VDP_setVerticalScroll(BG_B, 0);
}

static void load_room(u8 room_id)
{
    /* PR-2: 64x32 plane mode — clear both planes. BG_B is V scroll staging
     * and must be blank when no scroll is active so its content does not
     * leak through BG_A's transparent gaps. */
    VDP_clearPlane(BG_A, TRUE);
    VDP_clearPlane(BG_B, TRUE);
    s_doorway_dir = UW_WALK_DOOR_NONE;
    s_active_slot_x = 0u;
    /* PR-2: 32-row plane fits exactly one room (rows 7..28). row_base is
     * always 0 — no V staging stack inside BG_A. */
    s_active_row_base = 0u;
    s_active_scroll_x = 0;
    s_active_scroll_y = 0;
    /* Reset both planes' scroll registers. Subsequent renders go to BG_A
     * via the default target_plane=0 setter. */
    VDP_setHorizontalScroll(BG_A, 0);
    VDP_setVerticalScroll(BG_A, 0);
    VDP_setHorizontalScroll(BG_B, 0);
    VDP_setVerticalScroll(BG_B, 0);
    if (s_scene == SCENE_UW) {
        roomrom_uw_room_render_set_target_plane(0u);
    } else {
        roomrom_ow_room_render_set_target_plane(0u);
    }
    /* HUD is on Window; BG_A only carries staged room playfields. */
    if (s_scene == SCENE_UW) {
        roomrom_uw_room_render_load_palette(room_id);
        roomrom_hud_draw(roomrom_uw_room_render_get_map(), room_id, 1u);
    } else {
        roomrom_ow_room_render_load_palette(room_id);
        roomrom_hud_draw(roomrom_ow_room_render_get_map(), room_id, 0u);
        /* Task 5.4: bracket the OW slot paint so the raw-tile cache
         * captures every column and ends marked stable. The warp
         * coordinator's rule-5 entrance-tile check gates on this. */
        roomrom_ow_room_render_begin_full_fill();
    }
    render_room_into_slot(room_id, s_active_slot_x, s_active_row_base);
    if (s_scene == SCENE_OW) {
        roomrom_ow_room_render_mark_stable();
    }
    anchor_active_slot();
    roomrom_sprites_load_palette();   /* PAL1 - reload after BG palette write */
    /* Phase 2.6.5: reset toggle table on room load (empty at Phase 2). */
    roomrom_palette_tick_init((const unsigned char *)0);
    /* Ph5.3: init door state after room render (needs filled plane + attr cache). */
    if (s_scene == SCENE_UW) {
        u8 lvl = roomrom_uw_room_render_get_level();
        u8 q   = roomrom_uw_room_render_get_quest();
        uw_door_state_room_init(lvl, q, room_id);
        /* Task 5.8/5.9 perf: refresh per-room caches ONCE on room
         * change (linear-scan cost amortized to load_room only). */
        s_cur_room_is_dark   = roomrom_uw_room_is_dark(lvl, q, room_id);
        s_cur_room_is_cellar = roomrom_uw_room_is_cellar(lvl, q, room_id);
        s_cur_room_has_item  = roomrom_uw_item_for_room(
                                   lvl, q, room_id, &s_cur_room_item_meta);
        /* Task 5.8: dark-room render override. */
        if (s_cur_room_is_dark && !roomrom_uw_room_lit(room_id)) {
            roomrom_uw_room_render_fill_plane_a_dark();
        }
        /* Task 5.9.1: spawn room-item sprite if active + not taken. */
        if (s_cur_room_has_item &&
            s_cur_room_item_meta.active_at_spawn &&
            !roomrom_uw_item_taken(room_id)) {
            short ix = (short)s_cur_room_item_meta.item_x;
            short iy = (short)((short)s_cur_room_item_meta.item_y +
                                ROOMROM_PLAYFIELD_TOP_PX);
            roomrom_sprites_set_room_item(ix, iy, 0u);
        } else {
            roomrom_sprites_clear_room_item();
        }
    } else {
        s_cur_room_is_dark = 0u;
        s_cur_room_is_cellar = 0u;
        s_cur_room_has_item = 0u;
        roomrom_sprites_clear_room_item();
    }
    /* NES Z_01.asm:3967 UsedCandle clears on room transition — blue candle
     * regains its 1-shot per new room. Red candle ignores the flag. */
    roomrom_candle_fire_room_reset();
}

/* Phase 1: pick the live-NES item-atlas variant for the current scene+map.
 * 0 = orig (vanilla Z1), 1 = redux. Read by roomrom_sprites_set_redux +
 * roomrom_combat_set_redux at boot and after every C-button toggle. */
static unsigned char current_redux_flag(void)
{
    if (s_scene == SCENE_UW)
        return (unsigned char)(roomrom_uw_room_render_get_map() != 0u);
    return (unsigned char)(roomrom_ow_room_render_get_map() != 0u);
}

/* Task 5.4: closed scene-switch reset contract. Called by the warp
 * coordinator's LOAD step through roomrom_main_apply_warp_outcome().
 * Adding a field requires a spec amendment. Fields preserved across the
 * switch (s_link_keys, s_b_item, s_frame_counter, s_joy_prev) are NOT
 * reset here; players[0].face is overwritten by the apply outcome, not
 * reset. */
/* Forward decl: upload_scene_chr() is defined below the apply-outcome
 * function for historical layout reasons. */
static void upload_scene_chr(void);
static unsigned char link_walkable_at(short x, short y, link_dir_t dir);

static void roomrom_state_reset_for_scene_switch(void)
{
    s_doorway_dir = UW_WALK_DOOR_NONE;
    s_link_grid_offset = 0;
    s_link_pos_frac = 0u;
    s_link_subx = 0u;
    s_link_suby = 0u;
    s_link_dir = LINK_DIR_NONE;

    s_scroll_state = SCROLL_NONE;
    s_scroll_frame = 0u;
    s_scroll_total_frames = SCROLL_TOTAL_FRAMES;
    s_active_slot_x = 0u;
    s_active_row_base = 0u;
    s_transition_target = 0u;
    s_transition_row_base = 0u;
    s_active_scroll_x = 0;
    s_active_scroll_y = 0;
    s_scroll_start_x = 0;
    s_scroll_start_y = 0;
    s_scroll_target_x = 0;
    s_scroll_target_y = 0;
    s_scroll_start_link_x = 0;
    s_scroll_start_link_y = 0;
    s_transition_link_x = 0;
    s_transition_link_y = 0;

    s_link_anim_tick = 0u;
    s_link_frame = 0u;

    /* Combat: full re-init clears sword cooldown / projectile state.
     * Scene bias re-applied in roomrom_main_apply_warp_outcome step 9. */
    roomrom_combat_init();
}

/* Task 5.4: atomic warp outcome applier. Coordinator's LOAD step calls
 * this once. Order matches the spec's Handoff section. */
void roomrom_main_apply_warp_outcome(const rr_warp_outcome_t *out)
{
    if (out == 0) {
        return;
    }

    /* Step 1. */
    roomrom_state_reset_for_scene_switch();

    /* Steps 2-6: direct state writes. */
    s_scene = (scene_t)out->dest_scene;
    if (s_scene == SCENE_UW) {
        roomrom_uw_room_render_set_level(out->dest_level);
        roomrom_uw_room_render_set_quest(out->dest_quest);
    }
    s_room_id = out->dest_room_id;
    players[0].x = out->dest_link_x;
    players[0].y = out->dest_link_y;
    players[0].face = (link_face_t)out->dest_link_face;

    /* Step 7: CHR upload through the scene-load coordinator. */
    upload_scene_chr();
    roomrom_scene_load(
        (s_scene == SCENE_UW) ? ROOMROM_SCENE_UW_L1 : ROOMROM_SCENE_OVERWORLD,
        out->dest_redux_flag);
    roomrom_combat_set_redux(out->dest_redux_flag);

    /* Step 8: existing room-load path (palette + plane + door state). */
    load_room(s_room_id);

    /* Step 9: combat scene bias single-call (reset already did combat_init). */
    roomrom_combat_set_uw(s_scene == SCENE_UW);

    /* Phase 7 Task 7.2 step 2: clear enemy slots + (Task 7.7) dispatch
     * per-room ObjList init. Stub returns NULL until 7.7 lands the
     * template_id table; force-spawn hook fires from probe Lua. */
    enemy_loop_room_init(s_room_id, (unsigned char)s_scene);
}

/* Task 5.4: read-side accessors for the coordinator. Each is a one-line
 * trampoline so the coordinator never dereferences main.c statics. */
unsigned char roomrom_main_current_redux_flag(void)
{
    return current_redux_flag();
}

unsigned char roomrom_main_current_scene(void)
{
    return (unsigned char)s_scene;
}

unsigned char roomrom_main_current_room_id(void)
{
    return s_room_id;
}

short roomrom_main_current_link_x(void)
{
    return players[0].x;
}

short roomrom_main_current_link_y(void)
{
    return players[0].y;
}

signed char roomrom_main_current_link_grid_offset(void)
{
    return s_link_grid_offset;
}

unsigned char roomrom_main_current_link_face(void)
{
    return (unsigned char)players[0].face;
}

unsigned char roomrom_main_underground_exit_type(void)
{
    return s_underground_exit_type;
}

/* Task 5.7: input dir + mode accessors for push-block state machine.
 * Forward declared because input_mask_from_buttons() is defined below
 * the warp-coordinator accessor block. */
static unsigned char input_mask_from_buttons(u16 input);

unsigned char roomrom_main_current_input_dir(void)
{
    return input_mask_from_buttons(s_joy_prev);
}

unsigned char roomrom_main_current_mode(void)
{
    return (s_mode == MODE_TELEPORT) ? ROOMROM_MAIN_MODE_TELEPORT
                                      : ROOMROM_MAIN_MODE_WALK;
}

/* Task 5.4: warp-state probes exposed through roomrom_debug_runtime.h. */
unsigned char roomrom_debug_warp_is_active(void)
{
    return roomrom_world_transition_is_active();
}

unsigned char roomrom_debug_warp_unsupported_count(void)
{
    return roomrom_world_transition_unsupported_selector_count();
}

/* Task 5.4: state mirror for passive Lua probes. Called once per tick;
 * publishes the gate-B field set into a fixed 36-byte RAM block at
 * ROOMROM_DEBUG_STATE_MIRROR_BASE.
 *
 * Perf split (2026-05-09): always-on minimum (12 B) covers FPS / scene /
 * room / link xy / face — what every probe needs to lock in. Heavy work
 * (offsets 12..119 + the every-6f persistence/cache blocks) is gated on
 * the enemy-loop probe arm magic at $FF73FC..$FF73FD. Default gameplay path
 * = 12 volatile writes; armed probes get the full 120 B + secondary blocks.
 * Restores VBlank budget
 * lost to ~30 getter calls and 108 extra volatile writes per frame. */
void roomrom_debug_publish_state_mirror(void)
{
    volatile unsigned char *p =
        (volatile unsigned char *)ROOMROM_DEBUG_STATE_MIRROR_BASE;
    const rr_warp_save_state_t *save;
    unsigned char uw_level;
    unsigned char uw_quest;

    /* Always-on minimum. FPS / scene-toggle / link-trace probes only need
     * these 12 bytes; cost is one cache-line worth of volatile writes. */
    p[0]  = 0x57u;                                /* 'W' */
    p[1]  = 0x50u;                                /* 'P' */
    p[2]  = (unsigned char)(s_frame_counter >> 8);
    p[3]  = (unsigned char)(s_frame_counter);
    p[4]  = (unsigned char)s_scene;
    p[5]  = s_room_id;
    p[6]  = (unsigned char)(((unsigned short)players[0].x) >> 8);
    p[7]  = (unsigned char)((unsigned short)players[0].x);
    p[8]  = (unsigned char)(((unsigned short)players[0].y) >> 8);
    p[9]  = (unsigned char)((unsigned short)players[0].y);
    p[10] = (unsigned char)players[0].face;
    p[11] = (unsigned char)s_link_dir;

    if (!enemy_loop_probe_is_armed()) {
        return;
    }

    save = roomrom_world_transition_save_state();
    uw_level = (s_scene == SCENE_UW)
        ? roomrom_uw_room_render_get_level() : 0u;
    uw_quest = (s_scene == SCENE_UW)
        ? roomrom_uw_room_render_get_quest() : 0u;

    p[12] = (unsigned char)s_link_grid_offset;
    p[13] = s_doorway_dir;
    p[14] = roomrom_world_transition_is_active();
    p[15] = roomrom_world_transition_unsupported_selector_count();
    p[16] = uw_level;
    p[17] = uw_quest;
    p[18] = roomrom_ow_room_render_is_stable();
    p[19] = s_link_pos_frac;
    p[20] = s_underground_exit_type;
    /* Tile under Link's foot — raw NES BG tile id from the OW raw-tile
     * cache. NES GetCollidableTileStill samples at foot center =
     * (ObjX, ObjY + $0B); link_walkable_at uses the same offset. */
    if (s_scene == SCENE_OW && roomrom_ow_room_render_is_stable()) {
        short foot_y = (short)(players[0].y + 0x0B);
        if (foot_y >= ROOMROM_PLAYFIELD_TOP_PX) {
            unsigned char fc = (unsigned char)((players[0].x >> 3) & 0x1Fu);
            unsigned char fr = (unsigned char)(((foot_y - ROOMROM_PLAYFIELD_TOP_PX) >> 3) & 0x1Fu);
            p[21] = roomrom_ow_room_render_raw_tile_at(fc, fr);
        } else {
            p[21] = 0u;
        }
    } else {
        p[21] = 0u;
    }

    p[22] = save->version;
    p[23] = save->source_room_id;
    p[24] = save->source_underground_entrance_tile;
    p[25] = save->source_underground_entrance_tile_raw;
    p[26] = (unsigned char)(((unsigned short)save->source_link_x) >> 8);
    p[27] = (unsigned char)((unsigned short)save->source_link_x);
    p[28] = (unsigned char)(((unsigned short)save->source_link_y) >> 8);
    p[29] = (unsigned char)((unsigned short)save->source_link_y);
    p[30] = save->source_link_face;
    p[31] = save->dest_level;
    p[32] = save->dest_quest;
    p[33] = save->dest_room_id;
    p[34] = save->dest_link_face;
    /* Task 5.4 walkability diagnostic: metatile col/row + walkable
     * lookup for the metatile under Link. OW only; UW writes zeros. */
    if (s_scene == SCENE_OW && players[0].y >= ROOMROM_PLAYFIELD_TOP_PX) {
        unsigned char mc = (unsigned char)((players[0].x >> 4) & 0x0Fu);
        short fy = (short)(players[0].y + 0x0B - ROOMROM_PLAYFIELD_TOP_PX);
        unsigned char mr = (fy < 0) ? 0u :
                           (unsigned char)((fy >> 4) & 0x0Fu);
        if (mr > 10u) mr = 10u;
        p[35] = roomrom_ow_room_render_walkable_at(mc, mr);
        p[37] = mc;
        p[38] = mr;
    } else {
        p[35] = 0u;
        p[37] = 0u;
        p[38] = 0u;
    }
    /* Probe link_walkable_at for the UP direction so the user can see
     * whether collision allows stepping onto a tile to the north
     * (entrance approach is north-facing). Slice-1 only OW path. */
    if (s_scene == SCENE_OW) {
        p[36] = link_walkable_at(players[0].x, players[0].y, LINK_DIR_UP);
    } else {
        p[36] = 0u;
    }
    p[39] = 0u;                                    /* reserved */

    /* Task 5.5 extension: UW door state at offsets 40..71. */
    if (s_scene == SCENE_UW) {
        p[40] = uw_door_state_get_type(DOOR_DIR_E);
        p[41] = uw_door_state_get_type(DOOR_DIR_W);
        p[42] = uw_door_state_get_type(DOOR_DIR_S);
        p[43] = uw_door_state_get_type(DOOR_DIR_N);
        p[44] = uw_door_state_get_opened();
        p[45] = uw_door_state_false_timer();
        p[46] = uw_door_state_has_shutters();
    } else {
        p[40] = 0u; p[41] = 0u; p[42] = 0u; p[43] = 0u;
        p[44] = 0u; p[45] = 0u; p[46] = 0u;
    }
    p[47] = s_uw_shutter_trigger_count;
    p[48] = s_link_keys;
    p[49] = s_last_touch_keys_pre;
    p[50] = s_last_touch_keys_post;
    p[51] = s_last_touch_dir;
    p[52] = s_last_touch_result;
    p[53] = s_last_touch_door_type;
    {
        unsigned char i;
        for (i = 54u; i < 72u; i++) p[i] = 0u;  /* reserved */
    }

    /* Task 5.6 extension: cellar state at offsets 72..79. */
    p[72] = (s_scene == SCENE_UW) ? s_cur_room_is_cellar : 0u;
    p[73] = roomrom_world_transition_cellar_entry_count();
    p[74] = roomrom_world_transition_cellar_exit_count();
    p[75] = 0u;  /* pending exit reflected via room+save state already */
    p[76] = 0u; p[77] = 0u; p[78] = 0u; p[79] = 0u;  /* reserved */

    /* Task 5.7 extension: push-block state at offsets 80..95. */
    p[80] = roomrom_pushblock_state_for_room(s_room_id);
    p[81] = roomrom_pushblock_active_dir();
    p[82] = roomrom_pushblock_active_timer();
    p[83] = roomrom_pushblock_active_offset();
    p[84] = roomrom_pushblock_active_block_col();
    p[85] = roomrom_pushblock_active_block_row();
    p[86] = roomrom_pushblock_complete_count();
    p[87] = roomrom_pushblock_room_all_dead();
    p[88] = (unsigned char)roomrom_pushblock_active_state();
    p[89] = 0u; p[90] = 0u; p[91] = 0u;  /* reserved */
    p[92] = 0u; p[93] = 0u; p[94] = 0u; p[95] = 0u;  /* reserved */

    /* Task 5.8 extension: dark-room state at offsets 96..103. */
    if (s_scene == SCENE_UW) {
        p[96] = roomrom_uw_room_is_dark(uw_level, uw_quest, s_room_id);
        p[97] = roomrom_uw_room_lit(s_room_id);
    } else {
        p[96] = 0u;
        p[97] = 0u;
    }
    p[98] = roomrom_uw_dark_candle_used_count();
    p[99] = 0u; p[100] = 0u; p[101] = 0u; p[102] = 0u; p[103] = 0u;

    /* Task 5.9 extension: inventory + item pickup at offsets 104..119. */
    p[104] = s_link_keys;                                /* duplicate of 48 */
    p[105] = roomrom_uw_item_inv_compass();
    p[106] = roomrom_uw_item_inv_map();
    p[107] = roomrom_uw_item_inv_triforce();
    if (s_scene == SCENE_UW) {
        struct uw_item_room_meta m;
        if (roomrom_uw_item_for_room(uw_level, uw_quest, s_room_id, &m)) {
            p[108] = m.item_id;
        } else {
            p[108] = 0u;
        }
    } else {
        p[108] = 0u;
    }
    p[109] = roomrom_uw_item_taken(s_room_id);
    p[110] = 0u;  /* visited count — slice-1 deferral */
    p[111] = roomrom_uw_triforce_pickup_active();
    /* PR-4a CHR-TRANSIENT-SCENE state surface (probe-readable). */
    {
        unsigned short rc = level_chr_swap_request_count();
        unsigned long  bd = level_chr_swap_total_bytes_dma();
        p[112] = (unsigned char)level_chr_swap_state();
        p[113] = (unsigned char)level_chr_swap_active_scene();
        p[114] = (unsigned char)(rc >> 8);
        p[115] = (unsigned char)(rc);
        p[116] = (unsigned char)(bd >> 24);
        p[117] = (unsigned char)(bd >> 16);
        p[118] = (unsigned char)(bd >> 8);
        p[119] = (unsigned char)(bd);
    }

    /* Perf: heavy persistence + cache publishes (~2400 byte volatile
     * writes total) throttled to every 6 frames (10 Hz). Probes still
     * see fresh data within ~100ms; eliminates ~85% of frame budget
     * burned on debug RAM writes. The 120-byte $FF7200 mirror above
     * stays per-frame so the live state surface is immediate. */
    if ((s_frame_counter % 6u) == 0u) {
        roomrom_ow_room_render_publish_cache();    /* 708 B (Task 5.4) */
        roomrom_debug_publish_uw_persist();        /* 256 B (Task 5.5) */
        roomrom_pushblock_publish_persist();       /* 256 B (Task 5.7) */
        roomrom_uw_dark_publish_persist();         /* 256 B (Task 5.8) */
        roomrom_uw_item_publish_persist();         /* 256 B (Task 5.9) */
        roomrom_uw_room_render_publish_walkable(); /* 708 B (Task 5.5) */
    }
}

/* Task 5.5: copy active-level persistence row to probe block. */
void roomrom_debug_publish_uw_persist(void)
{
    unsigned char *dst = (unsigned char *)ROOMROM_DEBUG_UW_PERSIST_BASE;
    uw_door_state_copy_persist_for_active_level(dst,
        (unsigned short)ROOMROM_DEBUG_UW_PERSIST_BYTES);
}

static void upload_scene_chr(void)
{
    if (s_scene == SCENE_UW) {
        roomrom_uw_room_render_upload_chr();
    } else {
        roomrom_ow_room_render_upload_chr();
    }
    roomrom_hud_upload_chr();
}

static unsigned char input_mask_from_buttons(u16 input)
{
    unsigned char mask = 0u;
    if (input & BUTTON_RIGHT) mask |= 0x01u;
    if (input & BUTTON_LEFT)  mask |= 0x02u;
    if (input & BUTTON_DOWN)  mask |= 0x04u;
    if (input & BUTTON_UP)    mask |= 0x08u;
    return mask;
}

static link_dir_t link_face_dir(void)
{
    switch (players[0].face) {
        case LINK_FACE_RIGHT: return LINK_DIR_RIGHT;
        case LINK_FACE_LEFT:  return LINK_DIR_LEFT;
        case LINK_FACE_UP:    return LINK_DIR_UP;
        case LINK_FACE_DOWN:  return LINK_DIR_DOWN;
        default:              return LINK_DIR_DOWN;
    }
}

static link_dir_t doorway_search_dir(link_dir_t dir)
{
    return (dir == LINK_DIR_NONE) ? link_face_dir() : dir;
}

/* Task 5.5: latch wrapper around uw_door_state_touch so the state mirror
 * captures pre/post key counts + result + door type for the diff harness. */
static unsigned char link_door_touch_latched(unsigned char dir,
                                             unsigned char *keys)
{
    unsigned char result;
    s_last_touch_dir       = dir;
    s_last_touch_keys_pre  = *keys;
    s_last_touch_door_type = uw_door_state_get_type(dir);
    result = uw_door_state_touch(dir, keys);
    s_last_touch_keys_post = *keys;
    s_last_touch_result    = result;
    return result;
}

static unsigned char uw_doorway_passable(link_dir_t dir, short x, short y)
{
    unsigned char door_dir;
    unsigned char toward;

    if (!uw_walk_find_doorway(s_doorway_dir, (unsigned char)doorway_search_dir(dir),
                              x, y, &door_dir)) {
        s_doorway_dir = UW_WALK_DOOR_NONE;
        return 0u;
    }
    if (!uw_walk_door_axis_matches(door_dir, (unsigned char)dir)) return 0u;

    toward = uw_walk_dir_for_door(door_dir);
    if ((unsigned char)dir == toward &&
        !link_door_touch_latched(door_dir, &s_link_keys)) {
        return 0u;
    }

    s_doorway_dir = door_dir;
    return 1u;
}

static unsigned char uw_doorway_adjust_nes_dir(u16 input, link_dir_t *dir)
{
    unsigned char door_dir;
    unsigned char next_dir;

    if (s_scene != SCENE_UW ||
        !uw_walk_find_doorway(s_doorway_dir,
                              (unsigned char)doorway_search_dir(*dir),
                              players[0].x, players[0].y, &door_dir)) {
        s_doorway_dir = UW_WALK_DOOR_NONE;
        return 0u;
    }

    /* Task 5.5 fix: axis-match guard so Link doesn't get snapped to a
     * perpendicular door's centerline when his coords happen to land
     * inside that door's region. uw_doorway_passable already has this
     * guard (returns 0 without clearing s_doorway_dir); same shape
     * here. Without the guard, Link at (link_x in N-door-axis-range,
     * link_y == V centerline) with motion LEFT/RIGHT teleports to the
     * N-door X centerline. */
    if (!uw_walk_door_axis_matches(door_dir, (unsigned char)*dir)) {
        return 0u;
    }

    uw_walk_snap_to_doorway_axis(door_dir, &players[0].x, &players[0].y);
    s_doorway_dir = door_dir;
    next_dir = uw_walk_modify_dir_in_doorway(
        door_dir, (unsigned char)doorway_search_dir(*dir),
        input_mask_from_buttons(input));
    if (next_dir == UW_WALK_DIR_NONE) {
        *dir = LINK_DIR_NONE;
    } else {
        *dir = (link_dir_t)next_dir;
    }
    return 1u;
}

static void uw_doorway_adjust_velocity(s8 *vx, s8 *vy)
{
    unsigned char door_dir;
    link_dir_t dir = LINK_DIR_NONE;

    if (*vx > 0) dir = LINK_DIR_RIGHT;
    else if (*vx < 0) dir = LINK_DIR_LEFT;
    else if (*vy > 0) dir = LINK_DIR_DOWN;
    else if (*vy < 0) dir = LINK_DIR_UP;

    if (s_scene != SCENE_UW ||
        !uw_walk_find_doorway(s_doorway_dir,
                              (unsigned char)doorway_search_dir(dir),
                              players[0].x, players[0].y, &door_dir)) {
        s_doorway_dir = UW_WALK_DOOR_NONE;
        return;
    }

    /* Task 5.5 fix: axis-match guard (see uw_doorway_adjust_nes_dir). */
    if (!uw_walk_door_axis_matches(door_dir, (unsigned char)dir)) {
        return;
    }

    uw_walk_snap_to_doorway_axis(door_dir, &players[0].x, &players[0].y);
    s_doorway_dir = door_dir;
    if (door_dir == UW_WALK_DOOR_E || door_dir == UW_WALK_DOOR_W) {
        *vy = 0;
    } else {
        *vx = 0;
    }
}

/* S5 + S5.5 collision: returns 1 if Link's movement probe at the given
 * pixel position lands on a walkable tile in the current room.
 *
 * UW uses the NES GetCollidingTileMoving/GetCollidableTile sampler against
 * the live 8px PlayAreaTiles-equivalent cache. Doorway-axis bypass still
 * runs first so open NES door transitions keep their later Ph5.3 behavior.
 *
 * OW keeps the existing direction-dependent metatile probe. */
static unsigned char link_walkable_at(short x, short y, link_dir_t dir)
{
    short base_x = x;                       /* sprite left, NES ObjX */
    short base_y = (short)(y + 0x0B);       /* foot row, NES ObjY+$0B */
    short hot_x, hot_y;
    int col, row;
    short offset;

    if (s_scene == SCENE_UW) {
        uw_walk_probe_t probe;
        if (uw_doorway_passable(dir, x, y)) return 1u;
        uw_walk_collidable_probe((unsigned char)dir, x, y, &probe);
        return uw_walk_tile_passable(&probe,
                                     roomrom_uw_room_render_walkable_tile_at);
    }

    switch (dir) {
        case LINK_DIR_RIGHT: offset = 0x10; break;
        case LINK_DIR_DOWN:  offset = 0x08; break;
        default:             offset = -8;   break;  /* LEFT, UP, NONE */
    }

    if (dir == LINK_DIR_DOWN || dir == LINK_DIR_UP) {
        hot_x = base_x;                     /* NES takes ObjX as-is */
        if (dir == LINK_DIR_DOWN && base_y >= 0xDD) {
            hot_y = base_y;                 /* NES @AsIsX clamp */
        } else {
            hot_y = (short)(base_y + offset);
        }
    } else {
        hot_y = base_y;                     /* foot row */
        if (dir == LINK_DIR_LEFT && base_x < 0x10) {
            hot_x = base_x;                 /* NES @CheckLeftBoundary skip */
        } else if (dir == LINK_DIR_RIGHT && base_x >= 0xF0) {
            hot_x = base_x;                 /* NES right-boundary skip */
        } else if (dir == LINK_DIR_LEFT) {
            hot_x = base_x;
        } else if (dir == LINK_DIR_RIGHT) {
            hot_x = (short)(base_x + offset);
        } else {
            hot_x = (short)(base_x + offset);
        }
    }

    if (hot_y < ROOMROM_PLAYFIELD_TOP_PX) return 0u;
    col = (int)hot_x / 16;
    row = (int)(hot_y - ROOMROM_PLAYFIELD_TOP_PX) / 16;
    if (col < 0 || col > 15 || row < 0 || row > 10) return 1u;
    return roomrom_ow_room_render_walkable_at((unsigned char)col,
                                              (unsigned char)row);
}

/* S4: edge-triggered room transition. Both OW and UW use the same 16x8 grid
 * (room_id = (row<<4)|col). When Link's position crosses a playfield edge:
 *  - if the adjacent grid cell exists, load it and snap Link to the opposite
 *    edge (preserving the perpendicular coordinate);
 *  - else, clamp at the edge (no transition).
 * Resets sub-pixel/grid/anim state on transition so movement starts clean
 * in the new room. */
static void edge_load_or_clamp(void)
{
    u8 col = s_room_id & 0x0Fu;
    u8 row = (u8)(s_room_id >> 4);
    scroll_state_t want = SCROLL_NONE;

    /* Don't re-trigger while a scroll is already running. */
    if (s_scroll_state != SCROLL_NONE) return;

    /* Capture pre-edge position before clamping/snapping. */
    short pre_x = players[0].x;
    short pre_y = players[0].y;

    if (players[0].x < UW_WALK_EDGE_WEST_X) {
        if (col > 0u && (s_scene != SCENE_UW ||
                link_door_touch_latched(UW_WALK_DOOR_W, &s_link_keys))) {
            col--;
            if (s_scene == SCENE_UW) {
                uw_walk_arrival_position(UW_WALK_DOOR_W, &players[0].x, &players[0].y);
                s_doorway_dir = UW_WALK_DOOR_W;
            } else {
                players[0].x = UW_WALK_EDGE_EAST_X;
            }
            want = SCROLL_H_LEFT;
        } else { players[0].x = UW_WALK_EDGE_WEST_X; }
    } else if (players[0].x > UW_WALK_EDGE_EAST_X) {
        if (col < 15u && (s_scene != SCENE_UW ||
                link_door_touch_latched(UW_WALK_DOOR_E, &s_link_keys))) {
            col++;
            if (s_scene == SCENE_UW) {
                uw_walk_arrival_position(UW_WALK_DOOR_E, &players[0].x, &players[0].y);
                s_doorway_dir = UW_WALK_DOOR_E;
            } else {
                players[0].x = UW_WALK_EDGE_WEST_X;
            }
            want = SCROLL_H_RIGHT;
        } else { players[0].x = UW_WALK_EDGE_EAST_X; }
    }

    if (players[0].y < UW_WALK_EDGE_NORTH_Y) {
        if (row > 0u && (s_scene != SCENE_UW ||
                link_door_touch_latched(UW_WALK_DOOR_N, &s_link_keys))) {
            row--;
            if (s_scene == SCENE_UW) {
                uw_walk_arrival_position(UW_WALK_DOOR_N, &players[0].x, &players[0].y);
                s_doorway_dir = UW_WALK_DOOR_N;
            } else {
                players[0].y = UW_WALK_EDGE_SOUTH_Y;
            }
            want = SCROLL_V_UP;
        } else { players[0].y = UW_WALK_EDGE_NORTH_Y; }
    } else if (players[0].y > UW_WALK_EDGE_SOUTH_Y) {
        if (row < 7u && (s_scene != SCENE_UW ||
                link_door_touch_latched(UW_WALK_DOOR_S, &s_link_keys))) {
            row++;
            if (s_scene == SCENE_UW) {
                uw_walk_arrival_position(UW_WALK_DOOR_S, &players[0].x, &players[0].y);
                s_doorway_dir = UW_WALK_DOOR_S;
            } else {
                players[0].y = UW_WALK_EDGE_NORTH_Y;
            }
            want = SCROLL_V_DOWN;
        } else { players[0].y = UW_WALK_EDGE_SOUTH_Y; }
    }

    if (want != SCROLL_NONE) {
        s_transition_target = (u8)((row << 4) | col);
        s_transition_link_x = players[0].x;
        s_transition_link_y = players[0].y;
        /* Pre-edge screen pos clamped to playfield bounds, used as scroll
         * start. For H_RIGHT pre_x is just past 240 (clamp to 240); for
         * H_LEFT pre_x is just past 0 (clamp to 0). Y is unchanged. */
        if (pre_x < UW_WALK_EDGE_WEST_X)  pre_x = UW_WALK_EDGE_WEST_X;
        if (pre_x > UW_WALK_EDGE_EAST_X)  pre_x = UW_WALK_EDGE_EAST_X;
        if (pre_y < UW_WALK_EDGE_NORTH_Y) pre_y = UW_WALK_EDGE_NORTH_Y;
        if (pre_y > UW_WALK_EDGE_SOUTH_Y) pre_y = UW_WALK_EDGE_SOUTH_Y;
        s_scroll_start_link_x = pre_x;
        s_scroll_start_link_y = pre_y;
        s_scroll_state = want;
        s_scroll_frame = 0u;
        /* Reset sub-pixel/grid so motion starts clean post-transition. */
        s_link_pos_frac    = 0u;
        s_link_subx        = 0u;
        s_link_suby        = 0u;
        s_link_grid_offset = 0;
        s_link_anim_tick   = 0u;

        s_scroll_start_x = s_active_scroll_x;
        s_scroll_start_y = s_active_scroll_y;
        s_scroll_target_x = s_active_scroll_x;
        s_scroll_target_y = s_active_scroll_y;
        s_transition_row_base = s_active_row_base;
        /* Load new room's palette at scroll start — UW palettes vary per
         * room and the BG_A tile attributes baked into the rendered new
         * room reference whatever's in PAL0..PAL2 at render time. Old
         * room briefly shows in new palette during scroll; acceptable
         * trade vs new room wrong throughout. */
        if (s_scene == SCENE_UW)
            roomrom_uw_room_render_load_palette(s_transition_target);
        else
            roomrom_ow_room_render_load_palette(s_transition_target);
        roomrom_sprites_load_palette();
        /* Task 5.4: bracket the OW staging-slot paint so the raw-tile
         * cache captures the incoming room. mark_stable runs when the
         * scroll completes (above), not here, so the warp coordinator
         * does not fire mid-scroll while Link is still in the old room. */
        if (s_scene == SCENE_OW) {
            roomrom_ow_room_render_begin_full_fill();
        }
        if (want == SCROLL_H_RIGHT || want == SCROLL_H_LEFT) {
            u8 target_slot_x = (u8)(s_active_slot_x ^ 1u);
            /* H scroll within BG_A: render incoming into the OTHER slot
             * (cols 0..31 vs 32..63) and slide BG_A horizontally. */
            render_room_into_slot(s_transition_target,
                                  target_slot_x,
                                  s_active_row_base);
            s_scroll_target_x = scroll_x_offset_for_slot(target_slot_x);
        } else {
            /* PR-2b V scroll: render incoming into BG_B at row_base=0, then
             * slide BG_B in while BG_A scrolls out (independent v_scroll
             * per plane). 32-row plane fits exactly one room so the legacy
             * row_base wrap math is gone — incoming always lands at rows
             * 7..28 of BG_B. */
            s_transition_row_base = 0u;
            if (s_scene == SCENE_UW) {
                roomrom_uw_room_render_set_target_plane(1u);
            } else {
                roomrom_ow_room_render_set_target_plane(1u);
            }
            render_room_into_slot(s_transition_target,
                                  s_active_slot_x,
                                  0u);
            /* Reset target plane so any incidental writes during the
             * scroll go to BG_A (active). */
            if (s_scene == SCENE_UW) {
                roomrom_uw_room_render_set_target_plane(0u);
            } else {
                roomrom_ow_room_render_set_target_plane(0u);
            }
            /* BG_A target: actively scrolls out. V_DOWN -> active scrolls
             * down (v_scroll +176 = view shifts down = plane content moves
             * up on screen, i.e. active room exits via top). V_UP mirrors. */
            if (want == SCROLL_V_DOWN) {
                s_scroll_target_y = (short)(s_active_scroll_y +
                    (short)(ROOMROM_VERTICAL_STRIDE_TILES * 8));
                /* BG_B starts -176 below BG_A (so its room is below the
                 * screen at frame 0) and converges to BG_A's final scroll. */
                s_scroll_v_offset = (short)-(ROOMROM_VERTICAL_STRIDE_TILES * 8);
            } else { /* SCROLL_V_UP */
                s_scroll_target_y = (short)(s_active_scroll_y -
                    (short)(ROOMROM_VERTICAL_STRIDE_TILES * 8));
                s_scroll_v_offset = (short)(ROOMROM_VERTICAL_STRIDE_TILES * 8);
            }
            /* Initialize BG_B's V scroll to the offset position so frame 0
             * shows incoming-below (V_DOWN) or incoming-above (V_UP). */
            VDP_setVerticalScroll(BG_B,
                (short)(s_active_scroll_y + s_scroll_v_offset));
            VDP_setHorizontalScroll(BG_B, s_active_scroll_x);
        }
        {
            short dx = (short)(s_scroll_target_x - s_scroll_start_x);
            short dy = (short)(s_scroll_target_y - s_scroll_start_y);
            u8 fx = frames_for_scroll_delta(dx);
            u8 fy = frames_for_scroll_delta(dy);
            s_scroll_total_frames = (fx > fy) ? fx : fy;
            if (s_scroll_total_frames == 0u) s_scroll_total_frames = 1u;
        }
    }
}

void roomrom_debug_enter(void)
{
    /* Phase 9 Task 9.4 — load options from SRAM (or defaults) and apply
     * game-start option-driven seeds (start hearts, bomb cap) BEFORE
     * any inventory reader runs. The static `g_inventory` initializer
     * already seeds the NES vanilla profile; this layer overwrites
     * heart_values + max_bombs per the active OptionsState. */
    options_persistence_load_or_default();
    options_consumer_apply_inventory_at_start();

    /* Phase 6 Task 6.1: seed `players[0]` with NES Z1 boot defaults
     * before anything reads it. RoomRom always boots in 1-player mode;
     * Phase 13 will populate `players[1..3]` after lobby selection. */
    players[0].x    = 120;
    players[0].y    = 133;
    players[0].face = LINK_FACE_DOWN;

    s_joy_prev = 0u;
    init_video();
    /* PR-4a: init scene-bank state machine BEFORE first scene_load so the
     * first scene_load enqueues into a clean state. */
    level_chr_swap_init();
    upload_scene_chr();
    /* PR-4b regression fix: persistent sprite CHR (common 1025..1262 +
     * Link walk 1263..1294 + attack 1295..1310) was orphaned when PR-4b
     * split upload_chr; without it Link tile 1263 stays zero and Link is
     * invisible. SCENE_OBJ slot 1069..1204 lives inside common range —
     * scene_load enqueues a DMA that overwrites that window via
     * level_chr_swap_tick on subsequent frames (last-writer wins). Link
     * tiles 1263+ are outside SCENE_OBJ and survive. */
    roomrom_sprites_upload_chr();
    {
        u32 blank[8] = {0,0,0,0,0,0,0,0};
        VDP_loadTileData(blank, 0, 1, CPU);
    }
    /* P5: scene-load coordinator handles variant selection + sprite CHR
     * upload.  combat redux is not a CHR-load concern, kept separate. */
    roomrom_scene_load(
        (s_scene == SCENE_UW) ? ROOMROM_SCENE_UW_L1 : ROOMROM_SCENE_OVERWORLD,
        current_redux_flag());
    roomrom_combat_set_redux(current_redux_flag());
    load_room(s_room_id);                  /* loads BG pal + sprite PAL1 */
    roomrom_sprites_spawn_link(players[0].x, players[0].y);
    roomrom_combat_init();                 /* S7: clear sword sprite slot */
    roomrom_combat_set_uw(s_scene == SCENE_UW);  /* sword Y bias for UW */
    roomrom_boomerang_init();              /* S7 v6: clear boomerang slot */
    roomrom_arrow_init();                  /* S7 v7: clear arrow slot */
    roomrom_bomb_init();                   /* S7 v8: clear bomb + explosion slots */
    roomrom_link_damage_init();            /* Task 6.11.1: clear invincibility timer */
    roomrom_world_transition_init();       /* Task 5.4: warp coordinator */
    roomrom_pushblock_init();              /* Task 5.7: push-block state machine */
    roomrom_candle_fire_init();            /* Task 5.8.1: candle fire slot 8 */
    roomrom_magic_shot_init();             /* magic rod shot slot 9 */
    enemy_loop_room_init(s_room_id, (unsigned char)s_scene);  /* Phase 7 Task 7.2 */
    roomrom_probe_metadata_run();          /* Task 5.4 Gate D: in-ROM probe */

    /* debate 006 D2 native cave smoke: prove cave_init / cave_tick /
     * cave_exit link cleanly into RoomRom + execute without crash.
     * No visible effect yet (cave_tick is a stub); future commits add
     * SCENE_CAVE dispatch + render. cave_id 0x6A = first valid cave
     * room type per NES Z_01.asm:80.
     *
     * Phase 7 Task 7.2 step 4 ordering rule (root-cause fix 2026-05-09):
     * NES aliases CaveRoomType and ObjType+1 at $0350 — see
     * src/state/cave_state.h:83 + src/abi/platform_abi.h:80. cave_exit()
     * writes $0350=0, so any explicitly armed enemy-loop probe must run
     * after the cave smoke. */
    cave_init((cave_id_t)0x6A);
    cave_tick();
    cave_exit();

    if (enemy_loop_probe_is_armed()) {
        enemy_loop_probe_run();            /* Heavy 11-slot in-ROM stress probe. */
    }
    options_probe_run();                   /* Phase 9 Task 9.1 — pure CPU-side. */
    options_persistence_probe_run();       /* Phase 9 Task 9.2 — SRAM I/O. */
    options_consumer_probe_run();          /* Phase 9 Task 9.4 — consumer wiring. */
}

unsigned char roomrom_debug_get_scene(void)
{
    return (unsigned char)s_scene;
}

unsigned char roomrom_debug_get_room_id(void)
{
    return s_room_id;
}

short roomrom_debug_get_link_x(void)
{
    return players[0].x;
}

short roomrom_debug_get_link_y(void)
{
    return players[0].y;
}

void roomrom_debug_tick(void)
{
        SYS_doVBlankProcess();
        s_frame_counter++;
        roomrom_palette_tick_frame(s_frame_counter);
        /* PR-4a: advance scene-bank DMA state machine. Runs after
         * SYS_doVBlankProcess so the SGDK DMA queue is drained before
         * we issue our own ops. PR-5: boss state machine ticks in
         * parallel; the two share SCENE_OBJ slot but are naturally
         * serialized by request ordering (boss requested only on
         * boss-room entry, after enemy DMA has reached READY). */
        /* PR-5 probe trigger: probe pokes a scene_id (1 byte) into
         * $FF73FE; we enqueue a boss request and clear the cell. The
         * matching ack byte at $FF73FF tracks how many requests we have
         * fired (probe can read it to know the request landed). Used
         * solely by tools/debug/probe_boss_bank_dispatch.lua. */
        {
            volatile unsigned char *trig = (volatile unsigned char *)0x00FF73FEUL;
            volatile unsigned char *ack  = (volatile unsigned char *)0x00FF73FFUL;
            unsigned char req = *trig;
            if (req != 0u) {
                level_chr_boss_request((roomrom_scene_id_t)req);
                *trig = 0u;
                *ack = (unsigned char)(*ack + 1u);
            }
        }
        level_chr_swap_tick();
        level_chr_boss_tick();
        if (s_scene == SCENE_UW) uw_door_state_tick();

        /* S6.6 transition state machine. */
        if (s_scroll_state != SCROLL_NONE) {
            int num = (int)(s_scroll_frame + 1u);
            int den = (int)s_scroll_total_frames;
            short h_scroll;
            short v_scroll;
            s_joy_prev = 0u;     /* swallow input across transition */

            h_scroll = (short)(s_scroll_start_x +
                (((int)s_scroll_target_x - (int)s_scroll_start_x) * num) / den);
            v_scroll = (short)(s_scroll_start_y +
                (((int)s_scroll_target_y - (int)s_scroll_start_y) * num) / den);
            set_bg_scroll(h_scroll, v_scroll);
            /* PR-2b: BG_B follows BG_A's V scroll with a fixed offset
             * (-176 for V_DOWN, +176 for V_UP) so its incoming room
             * starts off-screen and slides in as BG_A scrolls out. */
            if (s_scroll_state == SCROLL_V_DOWN ||
                s_scroll_state == SCROLL_V_UP) {
                VDP_setVerticalScroll(BG_B,
                    (short)(v_scroll + s_scroll_v_offset));
                VDP_setHorizontalScroll(BG_B, h_scroll);
            }

            /* NES Z1 UW: Link is drawn behind door tiles during the
             * scroll (Z_07.asm ShowLinkSpritesBehindHorizontalDoors).
             * We approximate by hiding the sprite off-screen for the
             * scroll duration, then snapping to the new-room entry
             * position on finalize. */
            roomrom_sprites_set_link_pose((short)-32, (short)-32,
                                          players[0].face, 0u);

            if (s_scroll_frame >= s_scroll_total_frames - 1u) {
                u8 was_v_scroll = (u8)(s_scroll_state == SCROLL_V_DOWN ||
                                       s_scroll_state == SCROLL_V_UP);
                if (s_scroll_state == SCROLL_H_RIGHT ||
                    s_scroll_state == SCROLL_H_LEFT) {
                    s_active_slot_x ^= 1u;
                    s_active_scroll_x = s_scroll_target_x;
                    s_active_scroll_y = s_scroll_target_y;
                } else {
                    /* PR-2b V finalize: incoming room is fully visible
                     * via BG_B at this point. Re-render it into BG_A
                     * (active plane) so subsequent H scrolls and tile
                     * mutations land in the right place. Then clear BG_B
                     * and reset both planes to scroll 0. */
                    s_active_row_base = 0u;
                    s_active_scroll_x = 0;
                    s_active_scroll_y = 0;
                }
                s_room_id = s_transition_target;
                players[0].x  = s_transition_link_x;
                players[0].y  = s_transition_link_y;
                if (s_scene == SCENE_UW) {
                    roomrom_uw_room_render_load_palette(s_room_id);
                    roomrom_hud_draw(roomrom_uw_room_render_get_map(), s_room_id, 1u);
                    uw_door_state_room_init(roomrom_uw_room_render_get_level(),
                                            roomrom_uw_room_render_get_quest(),
                                            s_room_id);
                } else {
                    roomrom_ow_room_render_load_palette(s_room_id);
                    roomrom_hud_draw(roomrom_ow_room_render_get_map(), s_room_id, 0u);
                    /* Task 5.4: scroll-staging populated the raw-tile
                     * cache during edge_load_or_clamp. Cache was keyed
                     * by src col so it now reflects the new active
                     * room. Mark it stable so the warp coordinator's
                     * rule-5 check can fire. */
                    roomrom_ow_room_render_mark_stable();
                }
                roomrom_sprites_load_palette();
                if (was_v_scroll) {
                    /* Re-render incoming into BG_A (target_plane=0 is
                     * the default after the V scroll start sequence). */
                    if (s_scene == SCENE_UW) {
                        roomrom_uw_room_render_set_target_plane(0u);
                    } else {
                        roomrom_ow_room_render_set_target_plane(0u);
                        roomrom_ow_room_render_begin_full_fill();
                    }
                    render_room_into_slot(s_room_id, s_active_slot_x, 0u);
                    if (s_scene == SCENE_OW) {
                        roomrom_ow_room_render_mark_stable();
                    }
                    /* Drop staged BG_B content, reset both planes to 0. */
                    VDP_clearPlane(BG_B, TRUE);
                    VDP_setHorizontalScroll(BG_B, 0);
                    VDP_setVerticalScroll(BG_B, 0);
                    VDP_setHorizontalScroll(BG_A, 0);
                    VDP_setVerticalScroll(BG_A, 0);
                    s_scroll_v_offset = 0;
                } else {
                    anchor_active_slot();
                }
                s_scroll_state = SCROLL_NONE;
            } else {
                s_scroll_frame++;
            }
            return;
        }

        /* Task 6.10.2: NES Z_07.asm:472 gates per-frame gameplay update on
         * `Paused != 0`. Mirror that here — projectile/combat ticks freeze
         * while paused (voluntary or involuntary). Cave + scroll handling
         * already returned above; only the in-room update path is gated. */
        if (!roomrom_pause_is_active()) {
            roomrom_combat_update(players[0].x, players[0].y, players[0].face);
            roomrom_boomerang_update(players[0].x, players[0].y);
            roomrom_arrow_update();
            roomrom_bomb_update();
            roomrom_candle_fire_update();
            roomrom_magic_shot_update();
            roomrom_link_damage_tick((unsigned char)s_frame_counter);
            inventory_rupee_tick((unsigned char)s_frame_counter);
            roomrom_hud_refresh_dynamic();
            enemy_loop_tick();
        }

        u16 joy = JOY_readJoypad(JOY_1);
        u16 pressed = joy & ~s_joy_prev;
        s_joy_prev = joy;

        /* Phase 9 Task 9.4 — OPTION_ID_AB_SWAP: swap A and B button bits
         * after edge-detect so the entire downstream input dispatch sees
         * a single consistent button-mapping. s_joy_prev keeps raw bits
         * so direction-mask helpers (input_mask_from_buttons) remain
         * unaffected; only A/B-using sites in this function pick up the
         * swap. Toggling the option mid-session may cause one transient
         * frame of edge-detect skew, accepted as the simplest impl. */
        if (options_consumer_get_ab_swap()) {
            u16 ab_mask = (u16)(BUTTON_A | BUTTON_B);
            u16 joy_ab = (u16)(joy & ab_mask);
            u16 pressed_ab = (u16)(pressed & ab_mask);
            u16 joy_ab_swap = 0u;
            u16 pressed_ab_swap = 0u;
            if (joy_ab & BUTTON_A) joy_ab_swap |= (u16)BUTTON_B;
            if (joy_ab & BUTTON_B) joy_ab_swap |= (u16)BUTTON_A;
            if (pressed_ab & BUTTON_A) pressed_ab_swap |= (u16)BUTTON_B;
            if (pressed_ab & BUTTON_B) pressed_ab_swap |= (u16)BUTTON_A;
            joy = (u16)((joy & ~ab_mask) | joy_ab_swap);
            pressed = (u16)((pressed & ~ab_mask) | pressed_ab_swap);
        }

        /* SCENE_CAVE harness: tick the native cave gamemode each frame.
         * Only the C+START exit chord is honored — all other input is
         * swallowed so the chord toggle behavior stays unambiguous. */
        if (s_scene == SCENE_CAVE) {
            cave_tick();
            if ((pressed & BUTTON_START) && (joy & BUTTON_C)) {
                cave_exit();
                s_scene = SCENE_OW;
            }
            return;
        }

        if (pressed & BUTTON_X) {
            s_mode = (s_mode == MODE_WALK) ? MODE_TELEPORT : MODE_WALK;
            return;
        }

        if (pressed & BUTTON_Y) {
            s_move_style = (s_move_style == MOVE_STYLE_NES)
                         ? MOVE_STYLE_ALTTP : MOVE_STYLE_NES;
            /* Reset sub-pixel/grid state so style switch is clean. */
            s_link_pos_frac = 0u;
            s_link_subx = 0u;
            s_link_suby = 0u;
            s_link_grid_offset = 0;
            s_link_dir = LINK_DIR_NONE;
            return;
        }

        /* Task 5.5 debug stubs (UW only): exercise shutter / bombable
         * door state without combat or bomb projectile.
         *   A+B+C held + START edge-press → trigger all shutters in
         *     current UW room (uw_door_state_trigger_shutters). No-op
         *     outside UW or in rooms without shutters.
         *   B+Z held + C edge-press → bomb stub: open BOMBABLE door in
         *     Link's facing direction via uw_door_state_open_by_mask.
         * Chords pre-empt other handlers; explicit returns skip cave/
         * scene/variant toggles. */
        if (s_scene == SCENE_UW && (pressed & BUTTON_START) &&
            (joy & BUTTON_A) && (joy & BUTTON_B) && (joy & BUTTON_C)) {
            uw_door_state_trigger_shutters();
            if (s_uw_shutter_trigger_count < 0xFFu) s_uw_shutter_trigger_count++;
            return;
        }
        if (s_scene == SCENE_UW && (pressed & BUTTON_C) &&
            (joy & BUTTON_B) && (joy & BUTTON_Z)) {
            unsigned char dir;
            switch (players[0].face) {
                case LINK_FACE_RIGHT: dir = DOOR_DIR_E; break;
                case LINK_FACE_LEFT:  dir = DOOR_DIR_W; break;
                case LINK_FACE_UP:    dir = DOOR_DIR_N; break;
                case LINK_FACE_DOWN:  dir = DOOR_DIR_S; break;
                default:              dir = DOOR_DIR_S; break;
            }
            uw_door_state_open_by_mask((unsigned char)DOOR_DIR_BIT(dir));
            return;
        }

        /* C held + START press = SCENE_CAVE toggle. Detected before the
         * START-alone branch so the chord doesn't fall through to the
         * regular OW<->UW toggle. cave_id 0x6A is the first valid NES
         * cave room type per Z_01.asm:80 — pick something deterministic
         * for the harness. */
        if ((pressed & BUTTON_START) && (joy & BUTTON_C)) {
            if (s_scene == SCENE_OW) {
                (void)cave_init((cave_id_t)0x6A);
                s_scene = SCENE_CAVE;
            } else if (s_scene == SCENE_CAVE) {
                cave_exit();
                s_scene = SCENE_OW;
            }
            return;
        }

        /* MODE edge-press = scene toggle (was START 2026-04..2026-05-08).
         * Frees START to behave like NES Start (pause/inventory/etc).
         * Z held + START = quest toggle (handled below). C held + START
         * handled above. */
        if ((pressed & BUTTON_MODE) && !(joy & BUTTON_Z) && !(joy & BUTTON_C)) {
            s_scene = (s_scene == SCENE_OW) ? SCENE_UW : SCENE_OW;
            s_room_id = (s_scene == SCENE_UW) ? 0x00 : 0x77;
            upload_scene_chr();
            /* P5: scene change uses coordinator to re-upload sprite CHR
             * with correct variant. combat redux kept separate. */
            roomrom_scene_load(
                (s_scene == SCENE_UW) ? ROOMROM_SCENE_UW_L1
                                      : ROOMROM_SCENE_OVERWORLD,
                current_redux_flag());
            roomrom_combat_set_redux(current_redux_flag());
            load_room(s_room_id);
            roomrom_combat_set_uw(s_scene == SCENE_UW);
            return;
        }

        if (pressed & BUTTON_C) {
            if (s_scene == SCENE_UW) {
                u8 map_id = roomrom_uw_room_render_get_map();
                roomrom_uw_room_render_set_map(map_id ^ 1u);
            } else {
                u8 map_id = roomrom_ow_room_render_get_map();
                roomrom_ow_room_render_set_map(map_id ^ 1u);
            }
            upload_scene_chr();
            /* P5: map toggle re-uploads sprite CHR via coordinator.
             * Combat keeps its existing redux flag (v11+ alt-swing). */
            roomrom_scene_load(
                (s_scene == SCENE_UW) ? ROOMROM_SCENE_UW_L1
                                      : ROOMROM_SCENE_OVERWORLD,
                current_redux_flag());
            roomrom_combat_set_redux(current_redux_flag());
            load_room(s_room_id);
            return;
        }

        /* S7: A swings sword (NES-faithful single A-press). UW level cycle
         * moved to MODE button below. Movement is suppressed during the
         * swing so Link snaps to the swing pose for COMBAT_EXTEND_FRAMES. */
        if ((pressed & BUTTON_A) && !roomrom_combat_link_locked()) {
            roomrom_combat_try_swing(players[0].face, players[0].x, players[0].y);
        }

        /* B-item slot:
         *   Z press (alone)   = cycle B-item forward
         *   Z held + START    = quest toggle (handled below; suppress cycle)
         *   B press           = use current B-item */
        if ((pressed & BUTTON_Z) && !(joy & BUTTON_START)) {
            unsigned char nxt = (unsigned char)(s_b_item + 1u);
            if (nxt >= (unsigned char)B_ITEM_COUNT) nxt = (unsigned char)B_ITEM_BOOMERANG;
            s_b_item = (b_item_t)nxt;
        }
        if (pressed & BUTTON_B) {
            switch (s_b_item) {
            case B_ITEM_BOOMERANG:
                if (!roomrom_boomerang_active()) {
                    roomrom_boomerang_throw(players[0].face,
                                            players[0].x, players[0].y);
                }
                break;
            case B_ITEM_ARROW:
                if (!roomrom_arrow_active()) {
                    roomrom_arrow_fire(players[0].face,
                                       players[0].x, players[0].y);
                }
                break;
            case B_ITEM_BOMB:
                if (!roomrom_bomb_active()) {
                    roomrom_bomb_place(players[0].face,
                                       players[0].x, players[0].y);
                }
                break;
            case B_ITEM_CANDLE:
                /* Task 5.8.1 candle fire — visible flame projectile
                 * via dedicated module (slot 8, explosion-glyph
                 * placeholder; full red-pal NES fire CHR + 4-frame
                 * anim deferred to 5.8.2). Plus: dark-room reveal. */
                roomrom_candle_fire_spawn(players[0].face,
                                          players[0].x, players[0].y);
                if (s_scene == SCENE_UW && s_cur_room_is_dark &&
                    !roomrom_uw_room_lit(s_room_id)) {
                    roomrom_uw_room_set_lit(s_room_id);
                    roomrom_uw_dark_note_candle_used();
                    load_room(s_room_id);
                }
                break;
            case B_ITEM_ROD:
                /* Wand-extending visual deferred. Magic shot projectile
                 * fires immediately (skipping rod state machine). NES
                 * UpdateSwordOrRod state 3 -> spawn shot at slot $0E.
                 * Genesis: spawn at slot 9 directly, sub-pal flashes
                 * 0..2 per FrameCounter. */
                if (!roomrom_magic_shot_active()) {
                    roomrom_magic_shot_fire(players[0].face,
                                            players[0].x, players[0].y);
                }
                break;
            default:             break;
            }
        }

        /* Z held + START press = quest toggle (UW only). Z-held suppresses
         * the item-cycle path above so the press is unambiguous. */
        if ((pressed & BUTTON_START) && (joy & BUTTON_Z) && s_scene == SCENE_UW) {
            u8 q = roomrom_uw_room_render_get_quest();
            q = (q == ROOMROM_UW_QUEST_MIN) ? ROOMROM_UW_QUEST_MAX
                                             : ROOMROM_UW_QUEST_MIN;
            roomrom_uw_room_render_set_quest(q);
            load_room(s_room_id);
            return;
        }

        /* Task 6.10.1: bare START edge-press = NES Select-equivalent.
         * Toggles voluntary pause when no other button is held. All
         * START-with-modifier handlers already returned above, so a
         * bare START reaches here only when no chord matched. */
        if ((pressed & BUTTON_START) &&
            !(joy & (BUTTON_A | BUTTON_B | BUTTON_C |
                     BUTTON_X | BUTTON_Y | BUTTON_Z | BUTTON_MODE))) {
            roomrom_pause_toggle_voluntary();
            return;
        }
        /* Level cycle (was MODE-only) removed -- MODE is reserved hardware.
         * Reach a different level via teleport (X mode + DPAD) which warps
         * across the 16x8 room grid. */

        /* S7: while sword is mid-swing, swallow D-pad so Link freezes on
         * his swing pose. Combat module ticks below + clears sword on
         * retract, returning control. */
        if (roomrom_combat_link_locked()) {
            joy = (u16)(joy & ~(BUTTON_LEFT|BUTTON_RIGHT|BUTTON_UP|BUTTON_DOWN));
        }

        if (s_mode == MODE_TELEPORT) {
            /* D-pad edge-press warps room across the 16x8 grid. */
            u8 col = s_room_id & 0x0F;
            u8 row = s_room_id >> 4;
            if      ((pressed & BUTTON_LEFT)  && col > 0)  col--;
            else if ((pressed & BUTTON_RIGHT) && col < 15) col++;
            else if ((pressed & BUTTON_UP)    && row > 0)  row--;
            else if ((pressed & BUTTON_DOWN)  && row < 7)  row++;
            else return;
            s_room_id = (u8)((row << 4) | col);
            load_room(s_room_id);
        } else if (s_move_style == MOVE_STYLE_ALTTP) {
            /* ALTTP-style 8-direction movement, ported from
             * github.com/snesrev/zelda3 src/player.c Link_HandleVelocity
             * + Link_MovePosition + kSpeedMod. 8.8 fixed-point sub-pixel
             * per axis. Cardinal vel = 24 (kSpeedMod[0]); diagonal vel = 16
             * (kSpeedMod[1]) so sqrt(2) doesn't double diagonal speed. */

            u8 dir_bits = 0u;   /* bit 0=R, bit 1=L, bit 2=D, bit 3=U */
            if (joy & BUTTON_RIGHT) dir_bits |= 0x1u;
            if (joy & BUTTON_LEFT)  dir_bits |= 0x2u;
            if (joy & BUTTON_DOWN)  dir_bits |= 0x4u;
            if (joy & BUTTON_UP)    dir_bits |= 0x8u;

            {
                u8 has_h = (dir_bits & 0x3u) != 0u;
                u8 has_v = (dir_bits & 0xCu) != 0u;
                s8 vel = (has_h && has_v) ? (s8)16 : (s8)24;
                s8 vx = 0, vy = 0;

                if (dir_bits & 0x3u) vx = (dir_bits & 0x2u) ? (s8)-vel : vel;
                if (dir_bits & 0xCu) vy = (dir_bits & 0x8u) ? (s8)-vel : vel;
                uw_doorway_adjust_velocity(&vx, &vy);

                /* Facing: keep current if compatible with motion; else pick
                 * H over V (matches general 4-frame sprite limitation). */
                if      (vx > 0) players[0].face = LINK_FACE_RIGHT;
                else if (vx < 0) players[0].face = LINK_FACE_LEFT;
                else if (vy > 0) players[0].face = LINK_FACE_DOWN;
                else if (vy < 0) players[0].face = LINK_FACE_UP;

                if (vx || vy) {
                    if (++s_link_anim_tick >= LINK_ANIM_PERIOD) {
                        s_link_frame ^= 1u;
                        s_link_anim_tick = 0u;
                    }
                } else {
                    s_link_frame = 0u;
                    s_link_anim_tick = 0u;
                }

                /* ALTTP Link_MovePosition formula (8.8 fixed-point):
                 * tmp = subpixel + vel*16 + coord*256
                 * subpixel = tmp & 0xFF; coord = tmp >> 8.
                 * Per-axis collision check after each step enables wall-slide. */
                if (vx) {
                    short old_x = players[0].x;
                    u8    old_sub = s_link_subx;
                    link_dir_t hdir = (vx > 0) ? LINK_DIR_RIGHT : LINK_DIR_LEFT;
                    int tmp = (int)s_link_subx + ((int)vx * 16)
                            + ((int)players[0].x << 8);
                    s_link_subx = (u8)(tmp & 0xFF);
                    players[0].x = (short)(tmp >> 8);
                    if (!link_walkable_at(players[0].x, players[0].y, hdir)) {
                        players[0].x = old_x;
                        s_link_subx = old_sub;
                    }
                }
                if (vy) {
                    short old_y = players[0].y;
                    u8    old_sub = s_link_suby;
                    link_dir_t vdir = (vy > 0) ? LINK_DIR_DOWN : LINK_DIR_UP;
                    int tmp = (int)s_link_suby + ((int)vy * 16)
                            + ((int)players[0].y << 8);
                    s_link_suby = (u8)(tmp & 0xFF);
                    players[0].y = (short)(tmp >> 8);
                    if (!link_walkable_at(players[0].x, players[0].y, vdir)) {
                        players[0].y = old_y;
                        s_link_suby = old_sub;
                    }
                }
            }

            edge_load_or_clamp();
            if (!roomrom_combat_link_locked()) {
                roomrom_sprites_set_link_pose(players[0].x, players[0].y,
                                              players[0].face, s_link_frame);
            }
        } else {
            /* NES-faithful Link movement, ported from
             *   Z_05.asm Link_HandleInput / Link_ModifyDirAtGridPoint
             *   Z_07.asm Walker_Move / MoveObject / AddQSpeedToPositionFraction
             *
             * Per-frame:
             * 1. If on a grid intersection (offset == 0), pick a single-axis
             *    direction from current input (no diagonal). H over V on tie.
             * 2. If input released, stop instantly (even mid-grid). Walker_Move
             *    @ChooseObjDirOrInputDir: input=0 -> moving_dir=0.
             * 3. At grid offset 0, check the next tile before movement.
             * 4. If moving, run 4 quarter-steps. Right/down add QSpeed, left/up
             *    subtract QSpeed. Carry/borrow advances 1 px and changes signed
             *    ObjGridOffset until it reaches +8 or -8, then returns to 0. */

            u16 input = joy & (BUTTON_LEFT|BUTTON_RIGHT|BUTTON_UP|BUTTON_DOWN);
            u8 h_dir = (input & BUTTON_LEFT) ? 1u
                     : ((input & BUTTON_RIGHT) ? 2u : 0u);
            u8 v_dir = (input & BUTTON_UP)   ? 1u
                     : ((input & BUTTON_DOWN) ? 2u : 0u);

            {
                link_dir_t input_dir = LINK_DIR_NONE;
                link_dir_t moving_dir = LINK_DIR_NONE;

                if (h_dir && v_dir) {
                    /* NES Link_ModifyDirAtGridPoint with 2 inputs: in OW,
                     * picks "last walkable" (h_dir last in bit-iteration).
                     * H over V matches OW behavior. */
                    input_dir = (h_dir == 1u) ? LINK_DIR_LEFT : LINK_DIR_RIGHT;
                } else if (h_dir) {
                    input_dir = (h_dir == 1u) ? LINK_DIR_LEFT : LINK_DIR_RIGHT;
                } else if (v_dir) {
                    input_dir = (v_dir == 1u) ? LINK_DIR_UP : LINK_DIR_DOWN;
                }

                if (input != 0u) {
                    if (s_link_grid_offset == 0 || s_link_dir == LINK_DIR_NONE) {
                        s_link_dir = input_dir;
                        moving_dir = input_dir;
                    } else {
                        moving_dir = s_link_dir;
                    }
                }

                if (input != 0u) {
                    link_dir_t doorway_dir = moving_dir;
                    if (uw_doorway_adjust_nes_dir(input, &doorway_dir)) {
                        moving_dir = doorway_dir;
                        if (doorway_dir != LINK_DIR_NONE) {
                            s_link_dir = doorway_dir;
                        }
                    }
                }

                if (moving_dir != LINK_DIR_NONE) {
                    switch (moving_dir) {
                    case LINK_DIR_LEFT:  players[0].face = LINK_FACE_LEFT;  break;
                    case LINK_DIR_RIGHT: players[0].face = LINK_FACE_RIGHT; break;
                    case LINK_DIR_UP:    players[0].face = LINK_FACE_UP;    break;
                    case LINK_DIR_DOWN:  players[0].face = LINK_FACE_DOWN;  break;
                    default: break;
                    }
                }

                if (moving_dir != LINK_DIR_NONE && s_link_grid_offset == 0) {
                    if (!link_walkable_at(players[0].x, players[0].y, moving_dir)) {
                        moving_dir = LINK_DIR_NONE;
                    }
                }

                if (moving_dir != LINK_DIR_NONE) {
                    if (++s_link_anim_tick >= LINK_ANIM_PERIOD) {
                        s_link_frame ^= 1u;
                        s_link_anim_tick = 0u;
                    }
                    link_nes_move_object(moving_dir);
                } else {
                    s_link_frame = 0u;
                    s_link_anim_tick = 0u;
                }
            }

            edge_load_or_clamp();
            if (!roomrom_combat_link_locked()) {
                roomrom_sprites_set_link_pose(players[0].x, players[0].y,
                                              players[0].face, s_link_frame);
            }
        }

        /* Task 5.4: warp coordinator runs AFTER movement settles. The
         * tick is a no-op in non-OW scenes and when the OW raw-tile
         * cache isn't stable (mid-scroll). When it fires, the apply
         * step runs synchronously inside the coordinator and the next
         * frame begins in the new scene. */
        roomrom_world_transition_tick();

        /* Task 5.7: push-block state machine runs after world_transition
         * (so a coordinator-driven scene swap clears push state cleanly
         * via the room-change reset). Internally guards on UW + WALK. */
        roomrom_pushblock_tick();

        /* Task 5.9: item pickup. Reads cached per-room meta (refreshed
         * in load_room) — no per-tick 969-row scan. */
        if (s_scene == SCENE_UW && s_cur_room_has_item &&
            s_cur_room_item_meta.active_at_spawn &&
            !roomrom_uw_item_taken(s_room_id)) {
            short ix = (short)s_cur_room_item_meta.item_x;
            short iy = (short)((short)s_cur_room_item_meta.item_y +
                                ROOMROM_PLAYFIELD_TOP_PX);
            short fx = players[0].x;
            short fy = (short)(players[0].y + 0x0B);
            if (fx >= ix - 8 && fx <= ix + 16 &&
                fy >= iy && fy <= iy + 16) {
                roomrom_uw_item_pickup(
                    roomrom_uw_room_render_get_level(),
                    s_room_id, s_cur_room_item_meta.item_id);
                roomrom_sprites_clear_room_item();
            }
        }

        /* SAT DMA Lag Fix (debate 2026-05-09): single end-of-tick SAT
         * DMA via DMA_QUEUE. SYS_doVBlankProcess flushes the queue inside
         * the VBlank window. NES Z1 model: one OAM DMA per VBlank.
         * Slots 0..9 cover Link/sword/beam/boomerang/arrow/bomb/explosion/
         * room_item/candle_fire/magic_shot — count = 10. */
        VDP_updateSprites(10, DMA_QUEUE);

        /* Task 5.4: passive state mirror for BizHawk Lua probes. The
         * minimum 12 B (header/frame/scene/room/link xy/face) always
         * publishes; heavy state is gated on the probe arm magic inside
         * publish_state_mirror itself. */
        roomrom_debug_publish_state_mirror();
}

#ifndef ROOMROM_NO_STANDALONE_MAIN
int main(bool hardReset)
{
    (void)hardReset;

    roomrom_debug_enter();
    while (TRUE) {
        roomrom_debug_tick();
    }

    return 0;
}
#endif
