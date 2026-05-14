/* RoomRom warp coordinator (Task 5.4).
 *
 * NES source: reference/aldonunez/Z_05.asm:CheckWarps (line 7213) +
 *             HandleWarpOW (line 7313).
 *
 * Owns a 4-state warp machine (IDLE / PREPARE / ANIM / LOAD / RESUME +
 * ABORT). Decision logic mirrors the OW half of HandleWarpOW; the LOAD
 * step calls roomrom_main_apply_warp_outcome() through
 * roomrom_main_state.h to apply the outcome atomically.
 *
 * Slice 1 (Task 5.4) implements OW->UW Level 1 entry only. Cave
 * (selector >= 0x40), L2-L9, Q2 entry, mode-$10 visible semantics, and
 * UW->OW exit are deferred. See spec for the full deferral list.
 */

#ifndef ROOMROM_WORLD_TRANSITION_H
#define ROOMROM_WORLD_TRANSITION_H

#include "roomrom_main_state.h"

typedef enum {
    RR_WARP_IDLE    = 0,
    RR_WARP_PREPARE = 1,
    RR_WARP_ANIM    = 2,  /* mode $10 placeholder; 0-frame in slice 1 */
    RR_WARP_LOAD    = 3,
    RR_WARP_RESUME  = 4,
    RR_WARP_ABORT   = 5
} rr_warp_state_t;

typedef struct {
    unsigned char version;                              /* slice-1 = 1 */
    unsigned char source_room_id;
    unsigned char source_underground_entrance_tile;     /* post-collapse */
    unsigned char source_underground_entrance_tile_raw; /* pre-collapse */
    short         source_link_x;
    short         source_link_y;
    unsigned char source_link_face;
    unsigned char dest_level;
    unsigned char dest_quest;
    unsigned char dest_room_id;
    unsigned char dest_link_face;
} rr_warp_save_state_t;

void roomrom_world_transition_init(void);
void roomrom_world_transition_tick(void);

/* Returns 1 while the coordinator is in any non-IDLE state. main.c
 * skips movement / input / scroll-machine work for that frame. */
unsigned char roomrom_world_transition_is_active(void);

/* Read-only view of the latched save state (valid in PREPARE through
 * RESUME; reset to zero in IDLE). Returned pointer is stable for the
 * lifetime of the coordinator. */
const rr_warp_save_state_t *roomrom_world_transition_save_state(void);

/* Slice-1 dev-loop signal. The coordinator increments this each time
 * an OW selector resolves to a level NOT present in the slice-1 manifest
 * (e.g. L2-L9 entrance walked onto). BizHawk Lua probes can read this
 * RAM byte and surface "selector matched but manifest miss" without
 * looking like the warp silently broke. */
unsigned char roomrom_world_transition_unsupported_selector_count(void);

/* Task 5.6: cellar dispatch counters. Probes use these to verify a
 * UW-stair fire produced cellar entry/exit. Reset to zero by init. */
unsigned char roomrom_world_transition_cellar_entry_count(void);
unsigned char roomrom_world_transition_cellar_exit_count(void);

/* Slice-1 stub: NES `Tune1Request = 0` / `FluteTimer = 0` post-warp
 * silence ([Z_05.asm:7290-7294]). RoomRom has no high-level audio
 * driver wrapper; this is a no-op until the audio bridge lands.
 * Defined in the .c so the call site is correct today. */
void roomrom_audio_silence_for_warp(void);

#endif /* ROOMROM_WORLD_TRANSITION_H */
