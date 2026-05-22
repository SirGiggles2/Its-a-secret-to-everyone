/* cave_fade.h — cave-entry / cave-exit fade sequencer.
 *
 * Drives a multi-phase palette fade through the existing CRAM snapshot/
 * apply primitives (src/abi/render_abi.h render_cram_fade_capture +
 * render_cram_fade_apply) so cave transitions ramp instead of snap.
 *
 * Phase order on entry: OUT_ENTRY (N frames, OW palette dims to black) ->
 *   SWAP_ENTRY (1 frame, stamps cave plane + palette, fires entry callback)
 *   -> IN_CAVE (N frames, cave palette ramps up from black) -> IDLE.
 *
 * Phase order on exit:  OUT_EXIT  (N frames, cave palette dims to black) ->
 *   SWAP_EXIT  (1 frame, restores OW plane + palette, fires exit callback)
 *   -> IN_OW  (N frames, OW palette ramps up from black) -> IDLE.
 *
 * RoomRom main loop calls cave_fade_tick once per frame while
 * cave_fade_is_active() returns true. Tick advances the phase by one
 * step; SWAP phases call cave_init / cave_exit + plane fill / palette
 * apply + the registered callback (which handles Link reposition +
 * scene-state bookkeeping).
 *
 * Decoupled from world_animate_world_fading() because the OW fade-cycle
 * palette table (NES SRAM $6BFA) only describes OW colors, not cave
 * subpal 2+3; CRAM-snapshot+dim works on any palette state.
 */

#ifndef CAVE_FADE_H
#define CAVE_FADE_H

#include "../../cave/cave_dispatch.h"  /* cave_id_t */

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    CAVE_FADE_IDLE        = 0,
    CAVE_FADE_OUT_ENTRY   = 1,
    CAVE_FADE_SWAP_ENTRY  = 2,
    CAVE_FADE_IN_CAVE     = 3,
    CAVE_FADE_OUT_EXIT    = 4,
    CAVE_FADE_SWAP_EXIT   = 5,
    CAVE_FADE_IN_OW       = 6
} cave_fade_phase_t;

typedef struct {
    /* Called at SWAP_ENTRY (cave is now visible, palette is black ->
     * ramps up next phase). Owner stamps Link to cave-bottom + sets
     * scene state. */
    void (*on_swap_entry)(cave_id_t cid);
    /* Called at SWAP_EXIT (OW restored, palette black -> ramps up).
     * Owner stamps Link to return position + clears scene-cave state. */
    void (*on_swap_exit)(void);
} cave_fade_callbacks_t;

void              cave_fade_set_callbacks(const cave_fade_callbacks_t *cb);

/* Kick off cave-entry fade. Records cid for SWAP_ENTRY; captures live
 * CRAM (OW palette) so the OUT_ENTRY phase has the right snapshot to
 * dim. No-op if a fade is already active. */
void              cave_fade_begin_enter(cave_id_t cid);

/* Kick off cave-exit fade. Captures live CRAM (cave palette) for the
 * OUT_EXIT phase + records the OW room_id to restore on SWAP_EXIT.
 * No-op if a fade is already active. */
void              cave_fade_begin_exit(unsigned char return_room_id);

/* True while phase != IDLE. Callers use this to gate gameplay tick. */
unsigned char     cave_fade_is_active(void);

/* Current phase — handy for probes + diagnostics. */
cave_fade_phase_t cave_fade_phase_current(void);

/* Per-frame advance. Must run once per VBlank while is_active. */
void              cave_fade_tick(void);

#ifdef __cplusplus
}
#endif

#endif /* CAVE_FADE_H */
