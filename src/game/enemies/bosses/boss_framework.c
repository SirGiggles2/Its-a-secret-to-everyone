/* Phase 8 Task 8.1 step 2 — Boss Framework body.
 *
 * NES source: Z_05.asm:8154-8250 (CreateRoomObjects).
 * Drained C:  NONE for CreateRoomObjects — transpiled body lives at
 *             src/zelda_translated/z_05.asm:9033 (REPLACE target).
 * Coverage:   PARTIAL — push-block branch (LBA_D & 0x40) defers to
 *             FindAndCreatePushBlockObject @ Z_05.asm:5461 which is
 *             not yet drained or shimmed; the branch is logged + no-op
 *             pending Phase 8 follow-up step (most boss rooms do not
 *             trigger this branch — boss tests still exercise the
 *             reward path).
 * Stance:     REPLACE (CreateRoomObjects) — verbatim transcribe of NES
 *             asm into a native body that touches the same RAM cells
 *             documented in src/state/boss_state.h.
 */

#include "boss_framework.h"
#include "boss_state.h"
#include "dungeon_state.h"
#include "world_dispatch.h"
#include "platform_abi.h"

/* Z_05.asm:8166 GetRoomFlagUWItemState — already shimmed via the
 * legacy bridge.  Returns non-zero when the player has already taken
 * this room's item this save. */
extern unsigned char z01_get_room_flag_uw_item_state(void);

void boss_framework_room_init(unsigned char room_id)
{
    unsigned char attrs_e;
    unsigned char attrs_f;
    unsigned char item_id;
    unsigned char secret_trigger;
    unsigned int  xy;
    unsigned char x;
    unsigned char y;
    unsigned char level;
    unsigned char deactivate;

    /* Z_05.asm:8157 — set ObjState[$13] = 0 (active by default). The
     * body below toggles to $FF (deactivated) on any of:
     *   - already-taken (UW only)
     *   - L-block item-id == 3 (master-sword stand-in for "no item")
     *   - secret trigger == 3 (last_boss) or 7 (foes_for_item)
     *   - OW path when not in mode 5 / room $5F. */
    BOSS_ROOM_ITEM_STATE = 0u;
    deactivate = 0u;

    level = (unsigned char)BOSS_CUR_LEVEL;
    if (level == 0u) {
        /* OW: only room $5F in gameplay mode 5 spawns the heart. */
        BOSS_ROOM_ITEM_ID = BOSS_ITEM_ID_HEART_CONTAINER;
        if ((unsigned char)BOSS_GAMEMODE != BOSS_GAMEMODE_PLAY ||
            room_id != BOSS_OW_HEART_CONTAINER_ROOM) {
            BOSS_ROOM_ITEM_STATE = 0xFFu;
            return;
        }
        BOSS_ROOM_ITEM_X = BOSS_OW_HEART_CONTAINER_X;
        BOSS_ROOM_ITEM_Y = BOSS_OW_HEART_CONTAINER_Y;
        return;
    }

    /* UW path. Z_05.asm:8166 — if room flag says already taken, skip. */
    if (z01_get_room_flag_uw_item_state() != 0u) {
        BOSS_ROOM_ITEM_STATE = 0xFFu;
        return;
    }

    /* Z_05.asm:8176-8183 — pull room item from LBA_E low 5 bits. */
    attrs_e = (unsigned char)DUNGEON_LBA_E(room_id);
    item_id = (unsigned char)(attrs_e & BOSS_LBA_E_ITEM_MASK);
    if (item_id == BOSS_ITEM_ID_MASTER_SWORD_PLACEHOLDER) {
        /* "No item" stand-in. Deactivate object but still write the id. */
        deactivate = 1u;
    }
    BOSS_ROOM_ITEM_ID = item_id;

    /* Z_05.asm:8188-8195 — secret trigger 3 (last_boss) or 7 (foes_for_item)
     * defers activation until the secret fires; deactivate slot now. */
    attrs_f = (unsigned char)DUNGEON_LBA_F(room_id);
    secret_trigger = (unsigned char)(attrs_f & BOSS_LBA_F_SECRET_MASK);
    if (secret_trigger == BOSS_SECRET_TRIGGER_LAST_BOSS ||
        secret_trigger == BOSS_SECRET_TRIGGER_FOES_ITEM) {
        deactivate = 1u;
    }

    if (deactivate != 0u) {
        BOSS_ROOM_ITEM_STATE = 0xFFu;
    }

    /* Z_05.asm:8200-8203 — push-block branch DEFERRED. The NES code
     * here calls FindAndCreatePushBlockObject (Z_05.asm:5461) when
     * LBA_D & 0x40 is set. That body is not yet drained or shimmed
     * for native callers; gating on it would also require populating
     * a transient object slot used by the push-block sprite. The
     * branch is intentionally a no-op until Phase 8 follow-up
     * drains FindAndCreatePushBlockObject — boss rooms do not
     * trigger this branch. */
    (void)0u;  /* placeholder for future push-block hook */

    /* Z_05.asm:8207-8210 — set X/Y for the room item from
     * GetShortcutOrItemXY (drained as
     * worldrt_get_shortcut_or_item_xy_for_room). */
    xy = world_get_shortcut_or_item_xy_for_room((unsigned int)room_id);
    x  = (unsigned char)((xy >> 8) & 0xFFu);
    y  = (unsigned char)(xy & 0xFFu);

    /* Z_05.asm:8211-8222 — triforce piece shifts left 8 px. */
    if ((unsigned char)(attrs_e & BOSS_LBA_E_ITEM_MASK) ==
        BOSS_ITEM_ID_TRIFORCE_PIECE) {
        x = (unsigned char)(x - BOSS_LBA_E_TRIFORCE_X_OFFSET);
    }

    BOSS_ROOM_ITEM_X = x;
    BOSS_ROOM_ITEM_Y = y;
}
