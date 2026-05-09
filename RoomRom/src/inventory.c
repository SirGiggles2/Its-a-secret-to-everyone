#include "inventory.h"

/* Phase 6 Task 6.10.4 — singleton inventory storage.
 *
 * Boot defaults match the NES Z1 fresh-save profile:
 *   - 3 heart containers, 3 current full hearts (heart_values = 0x33).
 *   - HeartPartial empty.
 *   - 0 rupees, 0 keys, 0 bombs (NES MaxBombs default = 8).
 *   - No items, no bow/wand/boomerang/etc.
 *
 * The singleton is zero-initialized first; the populated fields below
 * land via the static initializer so save-load work in Phase 0 can
 * replace the literal once authored. */

inventory_t g_inventory = {
    .items            = 0u,
    .bombs            = 0u,
    .arrow            = INV_ARROW_NONE,
    .bow              = 0u,
    .candle           = INV_CANDLE_NONE,
    .food             = 0u,
    .potion           = 0u,
    .raft             = 0u,
    .book             = 0u,
    .ring             = INV_RING_NONE,
    .ladder           = 0u,
    .magic_key        = 0u,
    .bracelet         = 0u,
    .letter           = INV_LETTER_NONE,
    .compass_q1       = 0u,
    .map_q1           = 0u,
    .compass_l9       = 0u,
    .map_l9           = 0u,
    .clock            = 0u,
    .rupees           = 0u,
    .keys             = 0u,
    .heart_values     = 0x33u,         /* 3 max / 3 current */
    .heart_partial    = 0u,
    .triforce         = 0u,
    .boomerang_wood   = 0u,
    .boomerang_magic  = 0u,
    .magic_shield     = INV_SHIELD_WOOD,
    .max_bombs        = MAX_BOMBS_DEFAULT,
    .rupees_to_add    = 0u,
    .rupees_to_sub    = 0u,
    .world_flags      = 0u,
    .selected_b_item  = 0u,
};
