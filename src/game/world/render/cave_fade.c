/* cave_fade.c — NES Link-descend cave-entry animation.
 *
 * NES Z_05.asm:1400 InitMode10 + Z_05.asm:2308 UpdateMode10Stairs_Full.
 * 64-frame descend (16 px × 4 frames/px). After descend, instant scene
 * swap to cave. Exit is instant (snap) — user-trigger via C+START chord.
 */

#include "cave_fade.h"
#include "cave_palette.h"
#include "ow_render.h"

/* NES InitMode10 + UpdateMode10Stairs: 16 pixels down, 1 px every 4
 * frames = 64 frames total. */
#define CAVE_DESCEND_PIXELS   16u
#define CAVE_DESCEND_FRAMES_PER_PX 4u
#define CAVE_DESCEND_TOTAL_FRAMES \
    (CAVE_DESCEND_PIXELS * CAVE_DESCEND_FRAMES_PER_PX)

static cave_fade_phase_t     s_phase          = CAVE_FADE_IDLE;
static unsigned char         s_frame_counter  = 0u;  /* 0..63 for descend */
static unsigned char         s_step_idx       = 0u;  /* 0..15 px steps emitted */
static cave_id_t             s_pending_cid    = 0u;
static unsigned char         s_return_room_id = 0u;
static cave_fade_callbacks_t s_cb             = { 0, 0, 0 };

void cave_fade_set_callbacks(const cave_fade_callbacks_t *cb)
{
    if (cb != 0) {
        s_cb = *cb;
    }
}

void cave_fade_begin_enter(cave_id_t cid)
{
    if (s_phase != CAVE_FADE_IDLE) {
        return;
    }
    s_pending_cid   = cid;
    s_frame_counter = 0u;
    s_step_idx      = 0u;
    s_phase         = CAVE_FADE_LINK_DESCEND;
}

void cave_fade_begin_exit(unsigned char return_room_id)
{
    if (s_phase != CAVE_FADE_IDLE) {
        return;
    }
    s_return_room_id = return_room_id;
    s_phase          = CAVE_FADE_SWAP_EXIT;
}

unsigned char cave_fade_is_active(void)
{
    return (unsigned char)(s_phase != CAVE_FADE_IDLE);
}

cave_fade_phase_t cave_fade_phase_current(void)
{
    return s_phase;
}

void cave_fade_tick(void)
{
    switch (s_phase) {
    case CAVE_FADE_LINK_DESCEND: {
        /* NES: every 4th frame INC ObjY. We count frames; when
         * (frame_counter & 3) == 3 we are about to roll into a multiple
         * of 4 — emit one descend step + bump idx. After 16 steps, swap. */
        s_frame_counter = (unsigned char)(s_frame_counter + 1u);
        if ((s_frame_counter & 0x03u) == 0u) {
            if (s_cb.on_descend_step != 0) {
                s_cb.on_descend_step(s_step_idx);
            }
            s_step_idx = (unsigned char)(s_step_idx + 1u);
            if (s_step_idx >= CAVE_DESCEND_PIXELS) {
                s_phase = CAVE_FADE_SWAP_ENTRY;
            }
        }
        break;
    }

    case CAVE_FADE_SWAP_ENTRY:
        /* Instant: cave state init + cave plane fill + cave palette
         * stamp. Mirrors the three calls that pre-anim lived inline at
         * RoomRom/src/main.c. Owner callback then handles Link
         * reposition (cave-bottom) + scene flip. */
        (void)cave_init(s_pending_cid);
        roomrom_cave_room_render_fill_plane_a((unsigned char)s_pending_cid);
        roomrom_ow_room_render_publish_play_area_tiles();
        cave_palette_apply();
        if (s_cb.on_swap_entry != 0) {
            s_cb.on_swap_entry(s_pending_cid);
        }
        s_phase = CAVE_FADE_IDLE;
        break;

    case CAVE_FADE_SWAP_EXIT:
        /* Instant: cave teardown + OW plane refill + OW palette
         * restore. Owner callback handles Link reposition + HUD reset
         * + scene flip. */
        cave_exit();
        roomrom_ow_room_render_fill_plane_a(s_return_room_id);
        roomrom_ow_room_render_publish_play_area_tiles();
        roomrom_ow_room_render_load_palette(s_return_room_id);
        if (s_cb.on_swap_exit != 0) {
            s_cb.on_swap_exit();
        }
        s_phase = CAVE_FADE_IDLE;
        break;

    case CAVE_FADE_IDLE:
    default:
        break;
    }
}
