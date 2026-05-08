/* PR-4a CHR-TRANSIENT-SCENE state machine — framework.
 *
 * See level_chr_swap.h for state semantics.
 *
 * Stance (D1): EXTEND — the upload steps reuse SGDK VDP_loadTileData,
 * but the multi-VBlank scheduling + BLANK collapse + ready-gate are
 * Genesis-native (no NES analog; NES PPU CHR-RAM banks swap in a single
 * scanline). Drained-C reference: src/game/world/draw_dispatch.c +
 * src/game/enemies/enemy_dispatch.c sub-pal attr lookup is consumed
 * here only as the eventual *content* selector; the residency state
 * machine itself is a Genesis-side resource manager.
 */
#include <genesis.h>
#include "level_chr_swap.h"
#include "../roomrom_vram_map.h"

/* Per-scene contract resolver. PR-4a wires the UW levels' enemy
 * contracts only; OW NPC / cave-dweller hooks land in PR-4b. */
static const roomrom_vram_contract_t *contract_for_scene(roomrom_scene_id_t s)
{
    switch (s) {
    case ROOMROM_SCENE_UW_L1: return &roomrom_vram_contract_uw_l1_enemies;
    case ROOMROM_SCENE_UW_L2: return &roomrom_vram_contract_uw_l2_enemies;
    case ROOMROM_SCENE_UW_L3: return &roomrom_vram_contract_uw_l3_enemies;
    case ROOMROM_SCENE_UW_L4: return &roomrom_vram_contract_uw_l4_enemies;
    case ROOMROM_SCENE_UW_L5: return &roomrom_vram_contract_uw_l5_enemies;
    case ROOMROM_SCENE_UW_L6: return &roomrom_vram_contract_uw_l6_enemies;
    case ROOMROM_SCENE_UW_L7: return &roomrom_vram_contract_uw_l7_enemies;
    case ROOMROM_SCENE_UW_L8: return &roomrom_vram_contract_uw_l8_enemies;
    case ROOMROM_SCENE_UW_L9: return &roomrom_vram_contract_uw_l9_enemies;
    case ROOMROM_SCENE_OVERWORLD: return &roomrom_vram_contract_overworld_enemies;
    default: return 0;
    }
}

static level_chr_swap_state_t s_state = LEVEL_CHR_SWAP_IDLE;
static roomrom_scene_id_t      s_target = ROOMROM_SCENE_BOOT;
static roomrom_scene_id_t      s_active = ROOMROM_SCENE_BOOT;
static const roomrom_vram_contract_t *s_target_contract = 0;

static unsigned long  s_total_bytes_dma = 0u;
static unsigned short s_request_count = 0u;

/* Half-bank split: PR-4 spec splits ENEMY+BOSS DMA across two VBlanks
 * (NTSC budget ~7790 B; ENEMY can hit 8 KB). Half = ceil(blob_bytes/2)
 * rounded to a 32-byte tile boundary. */
static unsigned short half_bytes(unsigned short total)
{
    unsigned short half = (unsigned short)((total + 31u) >> 1);
    return (unsigned short)((half + 31u) & (unsigned short)~31u);
}

void level_chr_swap_init(void)
{
    s_state = LEVEL_CHR_SWAP_IDLE;
    s_target = ROOMROM_SCENE_BOOT;
    s_active = ROOMROM_SCENE_BOOT;
    s_target_contract = 0;
    s_total_bytes_dma = 0u;
    s_request_count = 0u;
}

void level_chr_swap_request(roomrom_scene_id_t scene)
{
    /* Same scene already READY → no-op. */
    if (s_active == scene && s_state == LEVEL_CHR_SWAP_READY) {
        return;
    }

    s_target = scene;
    s_target_contract = contract_for_scene(scene);
    s_state = LEVEL_CHR_SWAP_REQUESTED;
    s_request_count = (unsigned short)(s_request_count + 1u);
}

void level_chr_swap_tick(void)
{
    const roomrom_vram_contract_t *c = s_target_contract;

    switch (s_state) {
    case LEVEL_CHR_SWAP_IDLE:
    case LEVEL_CHR_SWAP_READY:
        return;

    case LEVEL_CHR_SWAP_REQUESTED: {
        if (c == 0 || c->tile_count == 0u || c->blob_bytes == 0u) {
            /* Empty contract: PR-4a state. Collapse to READY in one
             * tick — no DMA work to do. */
            s_active = s_target;
            s_state = LEVEL_CHR_SWAP_READY;
            return;
        }
        /* PR-4b: BLANK = zero-fill the SCENE_OBJ tile range. Wired in
         * 4b once we ship a zero buffer + DMA call. For 4a we still
         * advance state so the probe can observe transitions. */
        s_state = LEVEL_CHR_SWAP_BLANK;
        return;
    }

    case LEVEL_CHR_SWAP_BLANK: {
        /* PR-4b: first half of CHR DMA. */
        s_state = LEVEL_CHR_SWAP_DMA_SCENE_A;
        return;
    }

    case LEVEL_CHR_SWAP_DMA_SCENE_A: {
        /* PR-4b: second half of CHR DMA. */
        if (c != 0) {
            (void)half_bytes(c->blob_bytes); /* sized; impl in PR-4b. */
        }
        s_state = LEVEL_CHR_SWAP_DMA_SCENE_B;
        return;
    }

    case LEVEL_CHR_SWAP_DMA_SCENE_B: {
        s_active = s_target;
        s_state = LEVEL_CHR_SWAP_READY;
        return;
    }

    default:
        s_state = LEVEL_CHR_SWAP_IDLE;
        return;
    }
}

level_chr_swap_state_t level_chr_swap_state(void)        { return s_state; }
roomrom_scene_id_t     level_chr_swap_active_scene(void) { return s_active; }
unsigned char level_chr_swap_is_ready(void)
{
    return (unsigned char)(s_state == LEVEL_CHR_SWAP_READY ? 1u : 0u);
}
unsigned long  level_chr_swap_total_bytes_dma(void) { return s_total_bytes_dma; }
unsigned short level_chr_swap_request_count(void)   { return s_request_count; }
