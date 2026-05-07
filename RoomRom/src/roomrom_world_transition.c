/* RoomRom warp coordinator implementation (Task 5.4).
 *
 * NES source authority:
 *   reference/aldonunez/Z_05.asm:CheckWarps   (line 7213)
 *   reference/aldonunez/Z_05.asm:HandleWarpOW (line 7313)
 *
 * Stance: GREENFIELD (drain audit 2026-05-06: zero rows for these
 * symbols). NES disasm wins ties.
 *
 * Slice 1 limits OW->UW entry to manifest hits only. L2-L9 selectors
 * resolve cleanly (rule 6 passes) but rule 7 manifest membership rejects
 * them, incrementing the unsupported-selector counter so probes can
 * surface the bring-up path.
 */

#include "roomrom_world_transition.h"
#include "roomrom_main_state.h"
#include "ow_room_meta.h"
#include "ow_room_render_roomrom.h"
#include "uw_room_render_roomrom.h"
#include "uw_cellar_meta.h"
#include "../data/levelinfo_start_rooms.h"
#include "roomrom_sprites.h"  /* LINK_FACE_* enum */

/* Canonical UW Level 1 entrance spawn — matches the direct-boot
 * defaults in main.c (s_link_x = 120, s_link_y = 133). */
#define ROOMROM_WARP_UW_SPAWN_X  120
#define ROOMROM_WARP_UW_SPAWN_Y  133

/* Link's foot-tile is 8 px below the registered Y position. The
 * playfield top is ROOMROM_HUD_ROWS * 8 = 56. The (col, row) NES BG
 * tile coords used for warp-tile lookup mirror NES GetCollidableTileStill
 * sampling at (ObjX, ObjY) with playfield Y origin offset. */
#define ROOMROM_WARP_PLAYFIELD_TOP_PX  ((short)(ROOMROM_HUD_ROWS * 8u))

static rr_warp_state_t       s_state;
static rr_warp_save_state_t  s_save;
static unsigned char         s_unsupported_selector_count;

/* Task 5.6: latched flag set in IDLE on a UW-stair detect, consumed in
 * LOAD to bump the right counter. 0 = OW warp / UW-stair entry,
 * 1 = UW-stair cellar exit. */
static unsigned char         s_pending_cellar_exit;
static unsigned char         s_cellar_entry_count;
static unsigned char         s_cellar_exit_count;


static void clear_save_state(void)
{
    s_save.version = 1u;
    s_save.source_room_id = 0u;
    s_save.source_underground_entrance_tile = 0u;
    s_save.source_underground_entrance_tile_raw = 0u;
    s_save.source_link_x = 0;
    s_save.source_link_y = 0;
    s_save.source_link_face = 0u;
    s_save.dest_level = 0u;
    s_save.dest_quest = 0u;
    s_save.dest_room_id = 0u;
    s_save.dest_link_face = 0u;
}

void roomrom_world_transition_init(void)
{
    s_state = RR_WARP_IDLE;
    s_unsupported_selector_count = 0u;
    s_pending_cellar_exit = 0u;
    s_cellar_entry_count = 0u;
    s_cellar_exit_count = 0u;
    clear_save_state();
}

unsigned char roomrom_world_transition_cellar_entry_count(void)
{
    return s_cellar_entry_count;
}

unsigned char roomrom_world_transition_cellar_exit_count(void)
{
    return s_cellar_exit_count;
}

unsigned char roomrom_world_transition_is_active(void)
{
    return (unsigned char)(s_state != RR_WARP_IDLE);
}

const rr_warp_save_state_t *roomrom_world_transition_save_state(void)
{
    return &s_save;
}

unsigned char roomrom_world_transition_unsupported_selector_count(void)
{
    return s_unsupported_selector_count;
}

/* Slice-1 stub: NES `Tune1Request = 0` / `FluteTimer = 0` post-warp.
 * RoomRom currently has no high-level audio driver wrapper; the
 * audio_driver.asm substrate isn't called from RoomRom yet. The call
 * site stays so the coordinator's apply order is NES-correct from day 1. */
void roomrom_audio_silence_for_warp(void)
{
    /* TODO(audio): when the RoomRom audio driver bridge lands, write
     * Tune1Request = 0 and FluteTimer = 0 here. */
}

/* Rule 8: NES collapses warp-stair tiles ($70/$71/$72/$73) into a single
 * representative `$70` for `UndergroundEntranceTile` storage
 * ([Z_05.asm:7331-7332]). Tiles `$24` and `$88` pass through. */
static unsigned char collapse_warp_tile(unsigned char raw)
{
    if (raw >= 0x70u && raw <= 0x73u) {
        return 0x70u;
    }
    return raw;
}

/* Shared rule helpers (P1-1): used by both OW + UW detect_warp branches.
 * NES alignment + raw-tile sampling lives once. */
static unsigned char y_in_playfield(short link_y, short *y_out)
{
    short foot_y = (short)(link_y + 0x0B);
    if (foot_y < ROOMROM_WARP_PLAYFIELD_TOP_PX) return 0u;
    *y_out = (short)(foot_y - ROOMROM_WARP_PLAYFIELD_TOP_PX);
    return 1u;
}

/* OW detect_warp (rules 1-8 from Task 5.4 spec). Returns 1 + populates
 * save+outcome on hit. */
static unsigned char detect_warp_ow(unsigned char source_room_id,
                                    short link_x, short link_y,
                                    signed char grid_offset,
                                    unsigned char underground_exit_type,
                                    rr_warp_save_state_t *save_out,
                                    rr_warp_outcome_t   *outcome_out)
{
    unsigned char tile_col;
    unsigned char tile_row;
    unsigned char raw_tile;
    unsigned char attr_b;
    unsigned char selector;
    unsigned char level;
    unsigned char dest_room = 0u;
    short y_in_play;

    /* Rule 1: NES `LDA UndergroundExitType / ORA ObjGridOffset / BNE Exit`. */
    if (underground_exit_type != 0u) {
        return 0u;
    }

    /* Rule 2. */
    if (grid_offset != 0) {
        return 0u;
    }

    /* Rule 3: special-case room $22 uses & 0x07; all others use & 0x0F. */
    if (source_room_id == 0x22u) {
        if (((unsigned)link_x & 0x07u) != 0u) {
            return 0u;
        }
    } else {
        if (((unsigned)link_x & 0x0Fu) != 0u) {
            return 0u;
        }
    }

    /* Rule 4: NES uses ObjY & $0F == $0D, anchored to NES playfield top
     * Y = $5D (93). RoomRom playfield top = ROOMROM_HUD_ROWS*8 = 56.
     * Translating the alignment: foot_y = link_y + $0B must land on the
     * bottom BG row of a metatile in playfield-relative space, which
     * with PLAYFIELD_TOP_PX = 56 reduces to link_y & 0x0F == 0x05.
     * Verified against NES OW $37 entrance at metatile (7,4) sq=$0C
     * (BG tiles F3/24/F3/24): link_y=117 -> foot_y=128 -> playfield BG
     * row 9 -> $24 tile_bl. NES equivalent ObjY=$9D=157 ($0D & $0F).
     * Difference 157-117 = 40 = NES_top(93)-RoomRom_top(56)+3 sprite. */
    if (((unsigned)link_y & 0x0Fu) != 0x05u) {
        return 0u;
    }

    /* Rule 5: query raw-tile cache only if it is stable. NES samples
     * at foot center = (ObjX, ObjY + $0B); link_walkable_at uses the
     * same offset, so the warp tile-id check matches the collision
     * check Link's movement uses to step onto the entrance. */
    if (!roomrom_ow_room_render_is_stable()) {
        return 0u;
    }
    if (!y_in_playfield(link_y, &y_in_play)) {
        return 0u;
    }
    tile_col = (unsigned char)((link_x >> 3) & 0x1Fu);
    tile_row = (unsigned char)((y_in_play >> 3) & 0x1Fu);
    raw_tile = roomrom_ow_room_render_raw_tile_at(tile_col, tile_row);
    if (raw_tile != 0x24u && raw_tile != 0x88u &&
        !(raw_tile >= 0x70u && raw_tile <= 0x73u)) {
        return 0u;
    }

    /* Rule 6: selector = attr_b & 0xFC, then < 0x40 for level dispatch. */
    attr_b = roomrom_ow_meta_attr_b(source_room_id);
    selector = (unsigned char)(attr_b & 0xFCu);
    if (!roomrom_ow_meta_is_level_selector(selector)) {
        return 0u;
    }
    level = roomrom_ow_meta_level_from_selector(selector);

    /* Rule 7: manifest gate. Slice-1 quest hardcoded to 1 (no quest
     * selector in RoomRom yet). Manifest miss = silent rejection plus
     * unsupported-selector counter bump for probes. */
    if (!levelinfo_start_room_for(level, 1u, &dest_room)) {
        if (s_unsupported_selector_count < 0xFFu) {
            s_unsupported_selector_count++;
        }
        return 0u;
    }

    /* Rule 8: tile collapse for storage. */
    save_out->version = 1u;
    save_out->source_room_id = source_room_id;
    save_out->source_underground_entrance_tile_raw = raw_tile;
    save_out->source_underground_entrance_tile = collapse_warp_tile(raw_tile);
    save_out->source_link_x = link_x;
    save_out->source_link_y = link_y;
    save_out->source_link_face = roomrom_main_current_link_face();
    save_out->dest_level = level;
    save_out->dest_quest = 1u;
    save_out->dest_room_id = dest_room;
    save_out->dest_link_face = ROOMROM_MAIN_LINK_FACE_DOWN;

    outcome_out->dest_scene = ROOMROM_MAIN_SCENE_UW;
    outcome_out->dest_level = level;
    outcome_out->dest_quest = 1u;
    outcome_out->dest_room_id = dest_room;
    outcome_out->dest_link_x = ROOMROM_WARP_UW_SPAWN_X;
    outcome_out->dest_link_y = ROOMROM_WARP_UW_SPAWN_Y;
    outcome_out->dest_link_face = ROOMROM_MAIN_LINK_FACE_DOWN;
    outcome_out->dest_redux_flag = roomrom_main_current_redux_flag();
    return 1u;
}

/* UW detect_warp (Task 5.6 stair branch). Rules 0-7 per plan.
 * NES source: Z_05.asm:CheckWarps UW branch lines 7253-7301. */
static unsigned char detect_warp_uw(unsigned char source_room_id,
                                    short link_x, short link_y,
                                    signed char grid_offset,
                                    unsigned char underground_exit_type,
                                    rr_warp_save_state_t *save_out,
                                    rr_warp_outcome_t   *outcome_out)
{
    unsigned char tile_col;
    unsigned char tile_row;
    unsigned char raw_tile;
    unsigned char level;
    unsigned char quest;
    unsigned char dest_room = 0u;
    unsigned char is_cellar_exit = 0u;
    short y_in_play;

    /* Rule 1. */
    if (underground_exit_type != 0u) return 0u;
    /* Rule 2. */
    if (grid_offset != 0) return 0u;
    /* Rule 3: UW alignment same as OW non-$22. */
    if (((unsigned)link_x & 0x0Fu) != 0u) return 0u;
    /* Rule 4: same y alignment as OW. */
    if (((unsigned)link_y & 0x0Fu) != 0x05u) return 0u;
    /* Rule 5: sample raw NES BG tile at foot center. */
    if (!y_in_playfield(link_y, &y_in_play)) return 0u;
    tile_col = (unsigned char)((link_x >> 3) & 0x1Fu);
    tile_row = (unsigned char)((y_in_play >> 3) & 0x1Fu);
    level = roomrom_uw_room_render_get_level();
    quest = roomrom_uw_room_render_get_quest();
    raw_tile = roomrom_uw_room_render_raw_tile_at_room(level, quest,
                                                       source_room_id,
                                                       tile_col, tile_row);
    /* UW stair tiles are exactly $70..$73. $24/$88 are OW-only
     * (NES line 7257-7260). Slice-1 P0-2: cellar rooms have no blob
     * entry yet (draw_placeholder fires) so raw_tile_at_room returns
     * 0 — bypass rule 5 inside cellars (every aligned tile counts as
     * an exit stair until cellar BG extraction lands; documented in
     * task 5.6 deferrals). */
    if (!roomrom_uw_room_is_cellar(level, quest, source_room_id)) {
        if (raw_tile < 0x70u || raw_tile > 0x73u) return 0u;
    }

    /* Rule 6: cellar resolution. */
    if (roomrom_uw_room_is_cellar(level, quest, source_room_id)) {
        /* Cellar exit branch: dest = save state's source_room_id
         * (P0-3, latched on entry, NOT looked up in pair table). */
        if (save_out->source_room_id == 0u) {
            /* No latched source — exit invalidated (e.g. NV-RAM
             * deferral, fresh boot in cellar). Refuse. */
            return 0u;
        }
        dest_room = save_out->source_room_id;
        is_cellar_exit = 1u;
    } else {
        /* Cellar entry branch: source room → cellar via pair table. */
        if (!roomrom_uw_cellar_for_source(level, quest, source_room_id,
                                          &dest_room)) {
            return 0u;
        }
    }

    /* Rule 7: tile collapse $70..$73 → $70 (shared with OW rule 8). */
    if (is_cellar_exit) {
        /* Exit replays save state into outcome — leave latched
         * source_* fields alone. dest_* updated to point back at the
         * source room. */
        save_out->dest_level = level;
        save_out->dest_quest = quest;
        save_out->dest_room_id = dest_room;
        save_out->dest_link_face = ROOMROM_MAIN_LINK_FACE_DOWN;
    } else {
        /* Entry latches: source = current room, dest = cellar. */
        save_out->version = 1u;
        save_out->source_room_id = source_room_id;
        save_out->source_underground_entrance_tile_raw = raw_tile;
        save_out->source_underground_entrance_tile = collapse_warp_tile(raw_tile);
        save_out->source_link_x = link_x;
        save_out->source_link_y = link_y;
        save_out->source_link_face = roomrom_main_current_link_face();
        save_out->dest_level = level;
        save_out->dest_quest = quest;
        save_out->dest_room_id = dest_room;
        save_out->dest_link_face = ROOMROM_MAIN_LINK_FACE_DOWN;
    }

    outcome_out->dest_scene = ROOMROM_MAIN_SCENE_UW;
    outcome_out->dest_level = level;
    outcome_out->dest_quest = quest;
    outcome_out->dest_room_id = dest_room;
    outcome_out->dest_link_x = ROOMROM_WARP_UW_SPAWN_X;
    outcome_out->dest_link_y = ROOMROM_WARP_UW_SPAWN_Y;
    outcome_out->dest_link_face = ROOMROM_MAIN_LINK_FACE_DOWN;
    outcome_out->dest_redux_flag = roomrom_main_current_redux_flag();
    return 1u;
}

void roomrom_world_transition_tick(void)
{
    rr_warp_outcome_t outcome;

    switch (s_state) {

    case RR_WARP_IDLE: {
        /* Rule 0: scene dispatch. OW → detect_warp_ow; UW → detect_warp_uw. */
        unsigned char scene = roomrom_main_current_scene();
        unsigned char hit = 0u;
        if (scene == ROOMROM_MAIN_SCENE_OW) {
            hit = detect_warp_ow(roomrom_main_current_room_id(),
                                 roomrom_main_current_link_x(),
                                 roomrom_main_current_link_y(),
                                 roomrom_main_current_link_grid_offset(),
                                 roomrom_main_underground_exit_type(),
                                 &s_save,
                                 &outcome);
        } else if (scene == ROOMROM_MAIN_SCENE_UW) {
            unsigned char rid_before = roomrom_main_current_room_id();
            unsigned char level_now = roomrom_uw_room_render_get_level();
            unsigned char quest_now = roomrom_uw_room_render_get_quest();
            s_pending_cellar_exit =
                roomrom_uw_room_is_cellar(level_now, quest_now, rid_before);
            hit = detect_warp_uw(rid_before,
                                 roomrom_main_current_link_x(),
                                 roomrom_main_current_link_y(),
                                 roomrom_main_current_link_grid_offset(),
                                 roomrom_main_underground_exit_type(),
                                 &s_save,
                                 &outcome);
        }
        if (hit) {
            s_state = RR_WARP_PREPARE;
        }
        return;
    }

    case RR_WARP_PREPARE:
        /* Slice-1 PREPARE is a 0-frame placeholder: the save state was
         * latched in IDLE on the warp hit. ANIM is also 0-frame in
         * slice 1, so we fall straight into LOAD here. Future slices
         * (mode-$10) will hold ANIM for stairs/fade frames. */
        s_state = RR_WARP_ANIM;
        /* fallthrough into ANIM logic in same tick */
        /* fallthrough */

    case RR_WARP_ANIM:
        s_state = RR_WARP_LOAD;
        /* fallthrough into LOAD logic in same tick */
        /* fallthrough */

    case RR_WARP_LOAD:
        outcome.dest_scene    = ROOMROM_MAIN_SCENE_UW;
        outcome.dest_level    = s_save.dest_level;
        outcome.dest_quest    = s_save.dest_quest;
        outcome.dest_room_id  = s_save.dest_room_id;
        outcome.dest_link_x   = ROOMROM_WARP_UW_SPAWN_X;
        outcome.dest_link_y   = ROOMROM_WARP_UW_SPAWN_Y;
        outcome.dest_link_face = s_save.dest_link_face;
        outcome.dest_redux_flag = roomrom_main_current_redux_flag();

        roomrom_audio_silence_for_warp();
        roomrom_main_apply_warp_outcome(&outcome);
        if (s_pending_cellar_exit) {
            if (s_cellar_exit_count < 0xFFu) s_cellar_exit_count++;
        } else if (roomrom_main_current_scene() == ROOMROM_MAIN_SCENE_UW &&
                   roomrom_uw_room_is_cellar(s_save.dest_level,
                                             s_save.dest_quest,
                                             s_save.dest_room_id)) {
            if (s_cellar_entry_count < 0xFFu) s_cellar_entry_count++;
        }
        s_pending_cellar_exit = 0u;
        s_state = RR_WARP_RESUME;
        return;

    case RR_WARP_RESUME:
        /* Slice-1 RESUME is a single-frame guard. main.c sees
         * is_active() == 1 for the same frame LOAD ran in (because of
         * the same-frame fall-through above) and again on this
         * follow-up tick; movement is suppressed for one extra frame so
         * input held during warp doesn't leak into the new room's first
         * tick. */
        s_state = RR_WARP_IDLE;
        return;

    case RR_WARP_ABORT:
    default:
        s_state = RR_WARP_IDLE;
        clear_save_state();
        return;
    }
}

