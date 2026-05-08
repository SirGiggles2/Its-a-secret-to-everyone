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
#include "enemy_chr.h"
#include "../roomrom_vram_map.h"

/* Per-scene contract resolver. PR-4b wires UW enemy banks via
 * PatternBlockUWSP{127,358,469}. OW NPC / cave-dweller hooks land
 * in PR-4c. */
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

/* Per-scene CHR blob resolver. NES UW levels share three banks per
 * z_03.asm:67-89 dispatch:
 *   UWSP127 → L1, L2, L7
 *   UWSP358 → L3, L5, L8
 *   UWSP469 → L4, L6, L9
 * PR-4c: OW NPC + cave-dweller bank = single OWSP block (z_03.asm:42),
 * 1x sub-pal (sprites use NES sprite sub-pal 0..3 via per-OBJ ObjAttr,
 * not via CHR replication). */
static const unsigned char *enemy_blob_for_scene(roomrom_scene_id_t s)
{
    switch (s) {
    case ROOMROM_SCENE_UW_L1:
    case ROOMROM_SCENE_UW_L2:
    case ROOMROM_SCENE_UW_L7:
        return roomrom_atlas_enemy_uwsp127;
    case ROOMROM_SCENE_UW_L3:
    case ROOMROM_SCENE_UW_L5:
    case ROOMROM_SCENE_UW_L8:
        return roomrom_atlas_enemy_uwsp358;
    case ROOMROM_SCENE_UW_L4:
    case ROOMROM_SCENE_UW_L6:
    case ROOMROM_SCENE_UW_L9:
        return roomrom_atlas_enemy_uwsp469;
    case ROOMROM_SCENE_OVERWORLD:
        return roomrom_atlas_enemy_owsp;
    default:
        return 0;
    }
}

/* SCENE_OBJ slot is sized for the largest contract (4x UWSP = 136 tiles).
 * BLANK clears the full slot before every DMA so smaller contracts (OW
 * 114 tiles) don't leave stale tail bytes from the previous scene. */
#define SCENE_OBJ_SLOT_TILES 136u

static level_chr_swap_state_t s_state = LEVEL_CHR_SWAP_IDLE;
static roomrom_scene_id_t      s_target = ROOMROM_SCENE_BOOT;
static roomrom_scene_id_t      s_active = ROOMROM_SCENE_BOOT;
static const roomrom_vram_contract_t *s_target_contract = 0;

static unsigned long  s_total_bytes_dma = 0u;
static unsigned short s_request_count = 0u;

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
            /* Empty contract: collapse to READY in one tick. */
            s_active = s_target;
            s_state = LEVEL_CHR_SWAP_READY;
            return;
        }
        s_state = LEVEL_CHR_SWAP_BLANK;
        return;
    }

    case LEVEL_CHR_SWAP_BLANK: {
        /* Zero-fill the FULL SCENE_OBJ slot, not just c->tile_count.
         * Codex P0-2: prevents stale sub-pal aliases from showing during
         * the half-DMA gap when bank shrinks (e.g. UW 136 → OW 114 leaves
         * 22 stale tiles unless we BLANK the full slot). CPU fill (no
         * DMA queue cost). */
        if (c != 0 && c->tile_count > 0u) {
            VDP_fillTileData(0u, c->tile_base, SCENE_OBJ_SLOT_TILES, FALSE);
            s_total_bytes_dma += (unsigned long)SCENE_OBJ_SLOT_TILES * 32ul;
        }
        s_state = LEVEL_CHR_SWAP_DMA_SCENE_A;
        return;
    }

    case LEVEL_CHR_SWAP_DMA_SCENE_A: {
        const unsigned char *blob = enemy_blob_for_scene(s_target);
        if (c != 0 && blob != 0 && c->tile_count > 0u) {
            unsigned short half_a = (unsigned short)(c->tile_count >> 1);
            if (half_a > 0u) {
                VDP_loadTileData((const u32 *)(blob + c->blob_offset),
                                 c->tile_base, half_a, TRUE);
                s_total_bytes_dma += (unsigned long)half_a * 32ul;
            }
        }
        s_state = LEVEL_CHR_SWAP_DMA_SCENE_B;
        return;
    }

    case LEVEL_CHR_SWAP_DMA_SCENE_B: {
        const unsigned char *blob = enemy_blob_for_scene(s_target);
        if (c != 0 && blob != 0 && c->tile_count > 0u) {
            unsigned short half_a = (unsigned short)(c->tile_count >> 1);
            unsigned short half_b = (unsigned short)(c->tile_count - half_a);
            if (half_b > 0u) {
                unsigned long off = (unsigned long)c->blob_offset
                                  + (unsigned long)half_a * 32ul;
                VDP_loadTileData((const u32 *)(blob + off),
                                 (unsigned short)(c->tile_base + half_a),
                                 half_b, TRUE);
                s_total_bytes_dma += (unsigned long)half_b * 32ul;
            }
        }
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
