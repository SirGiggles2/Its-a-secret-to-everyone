/* Task 5.9: UW item-room manifest accessor + pickup wrapper.
 *
 * NES authority: Z_05.asm:8169-8222 + Z_01.asm:4002-4020.
 * Drained predicates (callable):
 *   src/game/room/room_dispatch.c:597 room_has_compass
 *   src/game/room/room_dispatch.c:603 room_has_map
 * Inventory storage: src/state/item_state.h:26 INVENTORY_VALUE(slot)
 *   = nes_ram[$0657 + slot] (in-bounds for RoomRom 2 KB nes_ram).
 *
 * Slice-1 does NOT call drained item_take_item (G3: externs not
 * linked). RoomRom-local wrapper writes INVENTORY_VALUE bytes directly.
 * Triforce wrapper bypasses GAME_MODE=18 conflict (G5).
 */

#ifndef ROOMROM_UW_ITEM_ROOM_META_H
#define ROOMROM_UW_ITEM_ROOM_META_H

#include "../data/uw_item_rooms.h"

unsigned char roomrom_uw_item_for_room(unsigned char level,
                                       unsigned char quest,
                                       unsigned char room_id,
                                       struct uw_item_room_meta *out);

/* Room-tracking persistence: s_item_taken[room_id] = 1 after pickup. */
unsigned char roomrom_uw_item_taken(unsigned char room_id);
void          roomrom_uw_item_set_taken(unsigned char room_id);
void          roomrom_uw_item_clear_taken(void);

/* Slice-1 pickup wrapper — writes INVENTORY_VALUE(slot) |=
 * LevelMask[level-1]. For triforce ($1B), also flips
 * s_triforce_pickup_active. Returns 1 if pickup applied. */
unsigned char roomrom_uw_item_pickup(unsigned char level,
                                     unsigned char room_id,
                                     unsigned char item_id);

unsigned char roomrom_uw_triforce_pickup_active(void);

unsigned char roomrom_uw_item_inv_compass(void);  /* INVENTORY_VALUE(16) */
unsigned char roomrom_uw_item_inv_map(void);      /* INVENTORY_VALUE(17) */
unsigned char roomrom_uw_item_inv_triforce(void); /* INVENTORY_VALUE(19) */

void roomrom_uw_item_publish_persist(void);

#define ROOMROM_DEBUG_ITEM_TAKEN_BASE  0x00FF7D00UL
#define ROOMROM_DEBUG_ITEM_TAKEN_BYTES 256u

#endif /* ROOMROM_UW_ITEM_ROOM_META_H */
