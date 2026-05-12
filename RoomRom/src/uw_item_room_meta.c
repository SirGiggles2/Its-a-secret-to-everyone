/* Task 5.9: UW item-room manifest + slice-1 pickup wrapper.
 *
 * Stance per Rule D1:
 *   ADOPT  — INVENTORY_VALUE storage layout (item_state.h:26)
 *   EXTEND — RoomRom-local pickup wrapper (G3: externs for
 *            item_take_item not linked yet).
 *   STUB   — Triforce wrapper bypasses GAME_MODE=18 transition (G5).
 */

#include "uw_item_room_meta.h"
#include "inventory.h"
#include "../data/uw_item_rooms.h"

/* INVENTORY_VALUE() lives in src/state/item_state.h, but pulling that
 * header drags ABI plumbing. Slice-1 reproduces the macro contract
 * locally — same byte address space. */
#include "../../src/state/item_state.h"

/* LevelMasks per Z_07.asm:747-748. */
static const unsigned char LEVEL_MASKS[8] = {
    0x01u, 0x02u, 0x04u, 0x08u, 0x10u, 0x20u, 0x40u, 0x80u
};

static unsigned char s_item_taken[256];
static unsigned char s_triforce_pickup_active;

unsigned char roomrom_uw_item_for_room(unsigned char level,
                                       unsigned char quest,
                                       unsigned char room_id,
                                       struct uw_item_room_meta *out)
{
    unsigned short idx_plus_one;
    if (out == 0) return 0u;
    if (level >= 10u || quest >= 3u || room_id >= 128u) return 0u;
    idx_plus_one = uw_item_room_lookup[level][quest][room_id];
    if (idx_plus_one == 0u) return 0u;
    *out = uw_item_rooms[(unsigned short)(idx_plus_one - 1u)];
    return 1u;
}

unsigned char roomrom_uw_item_taken(unsigned char room_id)
{
    return s_item_taken[room_id];
}

void roomrom_uw_item_set_taken(unsigned char room_id)
{
    s_item_taken[room_id] = 1u;
}

void roomrom_uw_item_clear_taken(void)
{
    unsigned short i;
    for (i = 0u; i < 256u; i++) s_item_taken[i] = 0u;
    s_triforce_pickup_active = 0u;
}

unsigned char roomrom_uw_item_pickup(unsigned char level,
                                     unsigned char room_id,
                                     unsigned char item_id)
{
    unsigned char mask;
    if (level < 1u || level > 8u) return 0u;
    mask = LEVEL_MASKS[level - 1u];
    switch (item_id) {
    case UW_ITEM_ID_COMPASS:
        INVENTORY_VALUE(UW_INV_SLOT_COMPASS) |= mask;
        break;
    case UW_ITEM_ID_MAP:
        INVENTORY_VALUE(UW_INV_SLOT_MAP) |= mask;
        break;
    case UW_ITEM_ID_TRIFORCE:
        /* G5: bypass item_take_item GAME_MODE=18 transition.
         * Slice-1 also defers writing the InvTriforce byte until
         * the actual NES slot id is confirmed via item_take_item
         * bridge (G3). Just flip the slice-1 stub flag. */
        s_triforce_pickup_active = 1u;
        break;
    default:
        /* Other item ids: slice-1 records pickup but does not write
         * inventory bits (full bridge to drained item_take_item is
         * deferred — G3). */
        break;
    }
    s_item_taken[room_id] = 1u;
    inventory_hud_mark_dirty();
    return 1u;
}

unsigned char roomrom_uw_triforce_pickup_active(void)
{
    return s_triforce_pickup_active;
}

unsigned char roomrom_uw_item_inv_compass(void)
{
    return (unsigned char)INVENTORY_VALUE(UW_INV_SLOT_COMPASS);
}

unsigned char roomrom_uw_item_inv_map(void)
{
    return (unsigned char)INVENTORY_VALUE(UW_INV_SLOT_MAP);
}

unsigned char roomrom_uw_item_inv_triforce(void)
{
    /* Slice-1: triforce inventory bit not yet written to nes_ram
     * (G3 deferral); s_triforce_pickup_active is the canonical
     * pickup signal. Return the stub flag for mirror parity. */
    return s_triforce_pickup_active;
}

void roomrom_uw_item_publish_persist(void)
{
    volatile unsigned char *dst =
        (volatile unsigned char *)ROOMROM_DEBUG_ITEM_TAKEN_BASE;
    unsigned short i;
    for (i = 0u; i < 256u; i++) dst[i] = s_item_taken[i];
}
