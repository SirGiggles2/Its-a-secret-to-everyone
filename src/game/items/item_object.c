/* item_object.c — dropped-item slot tick (Plan v5c).
 *
 * NES source: reference/aldonunez/Z_04.asm:11236 UpdateItem +
 *             reference/aldonunez/Z_01.asm:4364 TryTakeItem.
 *
 * Drained C: NONE (no _runtime.c candidate — owned greenfield port).
 * Coverage:  NONE
 * Stance:    EXTEND (table-bind only; body native)
 *
 * Wires enemy_update_fns[0x60] so dropped-item slots created by
 * SetUpDroppedItem (enemy_walker_bridge.c:854) tick autonomously:
 *   - every other frame decrement Item_ObjItemLifetime (META_ITEM_LIFETIME)
 *   - destroy slot at lifetime 0
 *   - Link bbox 9x9 vs item — if hit: item_take_item(id) + destroy slot
 *
 * MVP scope: Link-only pickup. NES also lets active sword/boomerang/arrow
 * pick up items (the 4-taker loop @LoopItemTaker, Z_04.asm:11275). Deferred
 * — rare edge case in practice (sword-tip pickup is barely noticeable).
 */

#include <stdint.h>
#include "platform_abi.h"
#include "enemy_state.h"          /* ENEMY_X/Y/TYPE/ALIVE_FLAG/PLAYER_OBJ_* */
#include "combat_state.h"         /* OBJ_STATE alias */
#include "item_dispatch.h"        /* item_take_item */

/* META_ITEM_LIFETIME = Item_ObjItemLifetime ($03A8+slot).
 * META_ITEM_ID       = Item_ObjItemId      ($00AC+slot, aliases OBJ_STATE).
 *
 * Same defines used by enemy_walker_bridge.c::native_set_up_dropped_item. */
#define META_ITEM_LIFETIME(slot)  OBJ(0x03A8, (slot))
#define META_ITEM_ID(slot)        OBJ(0x00AC, (slot))

/* DestroyMonster_Bank4 — clear slot. Inline to avoid the static binding
 * in enemy_walker_bridge.c. Same fields as native_destroy_monster. */
static void item_obj_destroy(unsigned int slot)
{
    ENEMY_TYPE(slot)          = 0u;
    ENEMY_MOVE_TIMER(slot)    = 0u;
    OBJ_STATE(slot)           = 0u;
    ENEMY_INVINCIBILITY(slot) = 0u;
    ENEMY_ALIVE_FLAG(slot)    = 0u;
    ENEMY_METASTATE(slot)     = 0u;
}

/* unsigned 8-bit abs(a - b). */
static unsigned char u8_abs_diff(unsigned char a, unsigned char b)
{
    return (a >= b) ? (unsigned char)(a - b) : (unsigned char)(b - a);
}

/* TryTakeItem (NES Z_01.asm:4364) — Link-only variant. Returns 1 if
 * item taken (caller destroys slot), 0 if no collision yet. */
static unsigned char item_obj_try_take_link(unsigned int slot)
{
    unsigned char lifetime = (unsigned char)META_ITEM_LIFETIME(slot);
    unsigned char link_x;
    unsigned char link_y;
    unsigned char item_x;
    unsigned char item_y;
    unsigned char item_id;

    /* NES grace period: lifetime $F0..$FF = newly spawned, not yet
     * pickable. Prevents Link from instantly grabbing drops that land
     * on him. */
    if (lifetime >= 0xF0u) return 0u;

    link_x = (unsigned char)ENEMY_PLAYER_OBJ_X;
    link_y = (unsigned char)ENEMY_PLAYER_OBJ_Y;
    item_x = (unsigned char)ENEMY_X(slot);
    item_y = (unsigned char)ENEMY_Y(slot);

    /* NES: |Y_link+3 - Y_item| >= 9 → exit. Y bias of 3 accounts for
     * Link sprite center vs feet offset. */
    if (u8_abs_diff((unsigned char)(link_y + 3u), item_y) >= 9u) return 0u;
    if (u8_abs_diff(link_x, item_x) >= 9u) return 0u;

    /* Capture item_id BEFORE the deactivate writes (META_ITEM_ID aliases
     * OBJ_STATE = $00AC, and NES writes ObjState = $FF as part of
     * deactivate, clobbering item id — NES preserves it in scratch $04
     * before the write). */
    item_id = (unsigned char)META_ITEM_ID(slot);

    /* NES TryTakeItem deactivate: ObjState = $FF, ObjY = $FF. */
    OBJ_STATE(slot)  = 0xFFu;
    ENEMY_Y(slot)    = 0xFFu;

    item_take_item(item_id);
    return 1u;
}

/* UpdateItem (NES Z_04.asm:11236) — registered at enemy_update_fns[0x60]. */
void item_object_update(unsigned int slot)
{
    unsigned char lifetime;
    unsigned char frame_counter;

    /* Every other frame, decrement lifetime. NES:
     *   LDA FrameCounter
     *   LSR
     *   BCC :+
     *   DEC Item_ObjItemLifetime, X
     *
     * After LSR, BCC branches if the SHIFTED-OUT bit was 0 → i.e. if
     * (FrameCounter & 1) was 0. So decrement on ODD frames. */
    frame_counter = (unsigned char)RAM(0x0015);
    if ((frame_counter & 1u) != 0u) {
        lifetime = (unsigned char)META_ITEM_LIFETIME(slot);
        if (lifetime != 0u) {
            META_ITEM_LIFETIME(slot) = (uint8_t)(lifetime - 1u);
        }
    }

    /* If lifetime reached 0, destroy slot. */
    if ((unsigned char)META_ITEM_LIFETIME(slot) == 0u) {
        item_obj_destroy(slot);
        return;
    }

    /* NES would call AnimateItemObject here to publish the item sprite.
     * Genesis port skips: sprite_render dispatch picks up live ENEMY_TYPE
     * + ENEMY_X/Y on its own. Per-item AnimateItemObject lookup table
     * (NES item-sprite anim) is deferred — drop currently renders as
     * whatever the type-$60 sprite map produces. Visual placeholder. */

    /* NES: if player halted (ObjState & $C0 == $40), exit before any
     * pickup check. Mode 5 Play is deferred — Link state machine isn't
     * porting halted state yet. Skip the check. */

    if (item_obj_try_take_link(slot)) {
        item_obj_destroy(slot);
    }
}
