/* PR-4 CHR-TRANSIENT-SCENE: per-level / per-scene CHR DMA state machine.
 *
 * Spec: docs/superpowers/specs/2026-05-07-whole-chr-rollout-design.md PR-4.
 *
 * Owns the SCENE_OBJ region (transient slot inside the SPR bank, after
 * Link / sword / common). On scene change, requests an upload of the
 * scene's enemies / NPC / boss CHR per the contracts in
 * roomrom_scene_vram_contracts.{h,c}. Multi-VBlank state machine bounds
 * worst-case DMA volume per VBlank to fit NTSC budget (~7790 B/VBlank;
 * a single ENEMY bank can be 8 KB → split across 2 VBlanks).
 *
 * States (per spec line 130):
 *   IDLE         no swap pending; bank static.
 *   REQUESTED    scene_load enqueued a target; not yet acted on.
 *   BLANK        zero-fill the SCENE_OBJ tile range (collapses sub-pal
 *                aliases of stale content — Codex P0-2).
 *   DMA_SCENE_A  first half of CHR DMA committed.
 *   DMA_SCENE_B  second half committed.
 *   READY        bank live; gameplay can resume.
 *
 * Each state advances exactly one tick (one VBlank) per call to
 * level_chr_swap_tick(). Empty contracts (tile_count == 0) collapse
 * REQUESTED → READY in a single tick (no DMA work to do).
 *
 * Gate: level_chr_swap_is_ready() must return non-zero before the
 * gameplay loop trusts SCENE_OBJ tiles. (Wired in PR-4b once a probe
 * actually consumes a tile from the bank.)
 */
#ifndef ROOMROM_LEVEL_CHR_SWAP_H
#define ROOMROM_LEVEL_CHR_SWAP_H

#include "roomrom_scene_vram_contracts.h"

typedef enum {
    LEVEL_CHR_SWAP_IDLE = 0,
    LEVEL_CHR_SWAP_REQUESTED = 1,
    LEVEL_CHR_SWAP_BLANK = 2,
    LEVEL_CHR_SWAP_DMA_SCENE_A = 3,
    LEVEL_CHR_SWAP_DMA_SCENE_B = 4,
    LEVEL_CHR_SWAP_READY = 5,
    LEVEL_CHR_SWAP_STATE_COUNT
} level_chr_swap_state_t;

/* Init: must be called once at boot before any request/tick. */
void level_chr_swap_init(void);

/* Enqueue a swap to scene's enemy/NPC bank. Idempotent: requesting the
 * same scene that is already READY is a no-op. */
void level_chr_swap_request(roomrom_scene_id_t scene);

/* Advance the state machine one step. Call once per VBlank from main
 * loop AFTER SYS_doVBlankProcess (DMA queue must be drained before we
 * issue our own). */
void level_chr_swap_tick(void);

/* Inspectors (probes + future gameplay gate). */
level_chr_swap_state_t level_chr_swap_state(void);
roomrom_scene_id_t level_chr_swap_active_scene(void);
unsigned char level_chr_swap_is_ready(void);

/* Stats (probe-visible, never reset). Counts every DMA byte the state
 * machine has issued since boot. PR-4a always reports 0 because all
 * contracts are tile_count=0; PR-4b populates and the count climbs. */
unsigned long level_chr_swap_total_bytes_dma(void);
unsigned short level_chr_swap_request_count(void);

#endif /* ROOMROM_LEVEL_CHR_SWAP_H */
