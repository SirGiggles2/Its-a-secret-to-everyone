/* vram_map_state.h — VRAM tile map typed-struct promotion target.
 *
 * Phase 2 (Graphics Registry) per docs/audit/state_contract.md migration
 * order. First typed-struct promotion in the codebase; demonstrates the
 * shape every later subsystem promotion follows.
 *
 * Numeric values mirror RoomRom/src/roomrom_vram_map.h, which is the
 * RoomRom-local source of truth derived from
 * RoomRom/tools/audit_vram_tile_usage.py against the Phase 1 baseline
 * trees. When RoomRom code promotes into owned src/game/, consumers will
 * read VramMapState fields instead of the ROOMROM_*_TILE_BASE_PAL macros.
 *
 * NOT yet wired to consumers — this header establishes the typed shape.
 * Wiring lands as RoomRom modules promote (Phase 12 promotion gate).
 */

#ifndef VRAM_MAP_STATE_H
#define VRAM_MAP_STATE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* One tile bank in VRAM. base_tile is the first tile index of the bank;
 * tiles_per_subpal is the per-sub-palette stride; subpal_count is the
 * number of sub-palette copies packed (1 = original NES bank, 4 = full
 * sub-palette expansion per the Phase 2 layout). */
typedef struct VramTileBank {
    uint16_t base_tile;
    uint16_t tiles_per_subpal;
    uint8_t  subpal_count;
} VramTileBank;

/* SGDK default VDP table tile addresses (see sgdk/src/vdp.c:23-27). */
typedef struct VdpTableMap {
    uint16_t plane_b_tile;   /* $C000 / 32 = 1536 */
    uint16_t window_tile;    /* $D000 / 32 = 1664 */
    uint16_t plane_a_tile;   /* $E000 / 32 = 1792 */
    uint16_t hscroll_tile;   /* $F000 / 32 = 1920 */
    uint16_t sat_tile;       /* $F400 / 32 = 1952 */
} VdpTableMap;

typedef struct VramMapState {
    VramTileBank bg;     /* NES BG + HUD tiles, 4 sub-pal copies */
    VramTileBank spr;    /* Link, sword body, common sprite (1 sub-pal) */
    VramTileBank item;   /* item atlas, 4 sub-pal copies */
    VdpTableMap  tables;
} VramMapState;

/* Default initializer mirroring RoomRom/src/roomrom_vram_map.h.
 * NOTE: ITEM bank tiles_per_subpal value depends on the generated atlas
 * (ROOMROM_ATLAS_ITEMS_X4_TILE_COUNT). Caller must fill that field
 * after including the atlas header — kept zero here to avoid an owned-C
 * dependency on the RoomRom atlas. */
#define VRAM_MAP_STATE_DEFAULT  { \
    .bg    = { .base_tile = 1u,    .tiles_per_subpal = 256u, .subpal_count = 4u }, \
    .spr   = { .base_tile = 1025u, .tiles_per_subpal = 312u, .subpal_count = 1u }, \
    .item  = { .base_tile = 1337u, .tiles_per_subpal = 0u,   .subpal_count = 4u }, \
    .tables = { \
        .plane_b_tile = 1536u, .window_tile  = 1664u, \
        .plane_a_tile = 1792u, .hscroll_tile = 1920u, \
        .sat_tile     = 1952u, \
    }, \
}

/* Tile base helpers — mirror ROOMROM_*_TILE_BASE_PAL macros. */
static inline uint16_t vram_bg_tile_base_pal(const VramMapState *m, uint8_t s) {
    return m->bg.base_tile + (uint16_t)s * m->bg.tiles_per_subpal;
}
static inline uint16_t vram_spr_tile_base_pal(const VramMapState *m, uint8_t s) {
    return m->spr.base_tile + (uint16_t)s * m->spr.tiles_per_subpal;
}
static inline uint16_t vram_item_tile_base_pal(const VramMapState *m, uint8_t s) {
    return m->item.base_tile + (uint16_t)s * m->item.tiles_per_subpal;
}

/* End-of-bank cursor for budget verification. ITEM bank is the last
 * tile bank before the VDP table region; tools/state/verify_vram_budget.py
 * (Task 2.3) must confirm item_bank_end <= tables.plane_b_tile. */
static inline uint16_t vram_item_bank_end(const VramMapState *m) {
    return m->item.base_tile +
           (uint16_t)m->item.subpal_count * m->item.tiles_per_subpal;
}

/* Compile-time sanity asserts on the default initializer math. */
_Static_assert(1u + 4u * 256u == 1025u,
               "BG bank end must equal SPR bank start");
_Static_assert(1025u + 312u == 1337u,
               "SPR bank end must equal ITEM bank start");
_Static_assert(1536u == 0xC000u / 32u,
               "Plane B tile index must be $C000 / 32");
_Static_assert(1792u == 0xE000u / 32u,
               "Plane A tile index must be $E000 / 32");

#ifdef __cplusplus
}
#endif

#endif /* VRAM_MAP_STATE_H */
