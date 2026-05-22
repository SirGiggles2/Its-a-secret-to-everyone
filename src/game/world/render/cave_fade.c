/* cave_fade.c — cave-transition palette sequencer.
 *
 * Implementation per cave_fade.h. Phase enum + step counter + cached
 * pending cave_id; tick advances one step per frame. SWAP phases call
 * cave_init / cave_exit + the existing plane fill + palette stamp
 * primitives, then re-capture CRAM for the IN phase.
 *
 * No new RoomRom files (WT-5). Linked into Debug.md via
 * tools/debug/build_debug.py ROOMROM_C_SOURCES (alongside cave_palette.c).
 *
 * Rule Zero: the fade ramp uses render_cram_fade_apply (src/sgdk_adapter/
 * render_adapter.c:189) which dims captured CRAM channels by integer
 * (total-step)/total — no guessed palette values, the runtime reads
 * current CRAM via VDP CRAM-read mode.
 */

#include "cave_fade.h"
#include "cave_palette.h"
#include "ow_render.h"
#include "render_abi.h"

/* Number of frames per OUT / IN phase. 6 = ~100 ms at 60fps; subtle but
 * visible. NES cave-entry fade-to-black is ~8 frames (GameMode $10
 * transition window), so 6 is a close visual match without dragging. */
#define CAVE_FADE_STEPS 6u

static cave_fade_phase_t       s_phase            = CAVE_FADE_IDLE;
static unsigned char           s_step             = 0u;
static cave_id_t               s_pending_cid      = 0u;
static unsigned char           s_return_room_id   = 0u;
static cave_fade_callbacks_t   s_cb               = { 0, 0 };

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
    s_pending_cid = cid;
    s_step        = 0u;
    /* Snapshot current OW CRAM so OUT_ENTRY can dim from real palette. */
    render_cram_fade_capture();
    s_phase = CAVE_FADE_OUT_ENTRY;
}

void cave_fade_begin_exit(unsigned char return_room_id)
{
    if (s_phase != CAVE_FADE_IDLE) {
        return;
    }
    s_return_room_id = return_room_id;
    s_step           = 0u;
    /* Snapshot current cave CRAM so OUT_EXIT can dim from real palette. */
    render_cram_fade_capture();
    s_phase = CAVE_FADE_OUT_EXIT;
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
    case CAVE_FADE_OUT_ENTRY:
        s_step = (unsigned char)(s_step + 1u);
        render_cram_fade_apply(s_step, CAVE_FADE_STEPS);
        if (s_step >= CAVE_FADE_STEPS) {
            s_phase = CAVE_FADE_SWAP_ENTRY;
            s_step  = 0u;
        }
        break;

    case CAVE_FADE_SWAP_ENTRY:
        /* Instant: cave state init + cave plane fill + cave palette
         * stamp. Mirrors the three calls that pre-fade lived inline at
         * RoomRom/src/main.c:1898-1916. */
        (void)cave_init(s_pending_cid);
        roomrom_cave_room_render_fill_plane_a((unsigned char)s_pending_cid);
        roomrom_ow_room_render_publish_play_area_tiles();
        cave_palette_apply();
        /* Owner reposts Link to cave-bottom + scene-state bookkeeping. */
        if (s_cb.on_swap_entry != 0) {
            s_cb.on_swap_entry(s_pending_cid);
        }
        /* Re-capture cave palette for IN_CAVE ramp; then force black so
         * the user does not see a 1-frame snap. */
        render_cram_fade_capture();
        render_cram_fade_apply(CAVE_FADE_STEPS, CAVE_FADE_STEPS);
        s_phase = CAVE_FADE_IN_CAVE;
        s_step  = CAVE_FADE_STEPS;
        break;

    case CAVE_FADE_IN_CAVE:
        if (s_step == 0u) {
            s_phase = CAVE_FADE_IDLE;
            break;
        }
        s_step = (unsigned char)(s_step - 1u);
        render_cram_fade_apply(s_step, CAVE_FADE_STEPS);
        if (s_step == 0u) {
            s_phase = CAVE_FADE_IDLE;
        }
        break;

    case CAVE_FADE_OUT_EXIT:
        s_step = (unsigned char)(s_step + 1u);
        render_cram_fade_apply(s_step, CAVE_FADE_STEPS);
        if (s_step >= CAVE_FADE_STEPS) {
            s_phase = CAVE_FADE_SWAP_EXIT;
            s_step  = 0u;
        }
        break;

    case CAVE_FADE_SWAP_EXIT:
        /* Instant: cave state teardown + OW plane refill + OW palette
         * restore. Symmetric with SWAP_ENTRY. Owner callback handles
         * Link reposition + scene-state flip + HUD underlay reset
         * (needs RoomRom-local statics). */
        cave_exit();
        roomrom_ow_room_render_fill_plane_a(s_return_room_id);
        roomrom_ow_room_render_publish_play_area_tiles();
        roomrom_ow_room_render_load_palette(s_return_room_id);
        if (s_cb.on_swap_exit != 0) {
            s_cb.on_swap_exit();
        }
        /* Re-capture restored OW palette for IN_OW ramp; force black
         * to avoid 1-frame snap. */
        render_cram_fade_capture();
        render_cram_fade_apply(CAVE_FADE_STEPS, CAVE_FADE_STEPS);
        s_phase = CAVE_FADE_IN_OW;
        s_step  = CAVE_FADE_STEPS;
        break;

    case CAVE_FADE_IN_OW:
        if (s_step == 0u) {
            s_phase = CAVE_FADE_IDLE;
            break;
        }
        s_step = (unsigned char)(s_step - 1u);
        render_cram_fade_apply(s_step, CAVE_FADE_STEPS);
        if (s_step == 0u) {
            s_phase = CAVE_FADE_IDLE;
        }
        break;

    case CAVE_FADE_IDLE:
    default:
        break;
    }
}
