/* Phase 7 Task 7.7 step 1 — Enemy Room Matrix loader.
 *
 * NES source: reference/aldonunez/Z_05.asm:1700-1820 (InitMode_EnterRoom
 *             monster-list parse) + Z_05.asm:1885-1962 (AssignObjSpawnPositions)
 *             + Z_05.asm:3534/3982 (ModifyObjCountByHistoryOW/UW).
 * Drained C:  NONE (room-init monster-list parser not drained — only the
 *             post-init bookkeeping in src/oracle/enemies/enemy_common_runtime.c).
 * Coverage:   NONE
 * Stance:     GREENFIELD (legal — drain_coverage.json has no candidate row).
 *
 * The original Phase 7 Task 7.2 stub (obj_list_for_room → NULL) is replaced
 * with the full NES room-init monster spawn pipeline:
 *
 *   1. attr_c = LevelBlockAttrsC[room_id]; template_id = attr_c & $3F
 *   2. attr_d = LevelBlockAttrsD[room_id]
 *      if (attr_d & $80) template_id += $40            ; bit 7 -> bit 6
 *   3. foe_idx = (attr_c >> 6) & $03
 *      count   = LevelInfo_FoeCounts[foe_idx]
 *      if (template_id >= $32 && template_id < $62) count = 1   ; boss override
 *   4. ModifyObjCountByHistory{OW|UW}(template_id, count)        ; step 3
 *   5. if (GameMode == $09) { template_id = 0; count = 0; }      ; cellar
 *   6. RoomObjCount = count; if (count == 0 || template_id == 0) skip
 *   7. if (template_id < $62)
 *         for X in 1..count: ObjType[X] = template_id
 *      else
 *         src = z1_obj_lists + obj_list_offsets[template_id - $62]
 *         for X in 0..count-1: ObjType[1+X] = src[X]
 *   8. RoomObjTemplateType = ObjType[1]
 *   9. AssignObjSpawnPositions()                                  ; step 2
 *  10. for X in 1..11: if (ObjType[X]) enemy_init_fns[ObjType[X]](X)
 *
 * Step 1 lands the parser + ObjType fill + RoomObjCount/RoomObjTemplateType
 * writes. AssignObjSpawnPositions and ModifyObjCountByHistory* land in
 * subsequent step commits — for step 1, default spawn coords come from
 * SpawnPosListAddrs[ObjDir] but without IsSafeToSpawn rejection; history
 * modify is a no-op (pristine first-entry behavior).
 *
 * Hard rule WT-5: file lives at src/game/enemies/, not RoomRom/.
 */

#include "obj_lists.h"
#include "platform_abi.h"
#include "enemy_state.h"
#include "dungeon_state.h"

/* NES ObjLists.dat — 201 bytes, 30 ObjList templates concatenated. */
const unsigned char z1_obj_lists[ENEMY_OBJLISTS_LEN] = {
    /* ObjList00 @ 0  (5) */ 0x03, 0x03, 0x04, 0x03, 0x04,
    /* ObjList01 @ 5  (4) */ 0x03, 0x04, 0x03, 0x04,
    /* ObjList02 @ 9  (6) */ 0x1A, 0x1A, 0x02, 0x01, 0x02, 0x01,
    /* ObjList03 @ 15 (4) */ 0x01, 0x02, 0x01, 0x02,
    /* ObjList04 @ 19 (6) */ 0x01, 0x0F, 0x02, 0x01, 0x10, 0x02,
    /* ObjList05 @ 25 (6) */ 0x0F, 0x1A, 0x10, 0x1A, 0x0F, 0x1A,
    /* ObjList06 @ 31 (5) */ 0x09, 0x08, 0x08, 0x08, 0x08,
    /* ObjList07 @ 36 (4) */ 0x08, 0x07, 0x08, 0x07,
    /* ObjList08 @ 40 (5) */ 0x08, 0x09, 0x08, 0x09, 0x08,
    /* ObjList09 @ 45 (5) */ 0x0A, 0x07, 0x0A, 0x07, 0x07,
    /* ObjList10 @ 50 (6) */ 0x03, 0x0A, 0x04, 0x0A, 0x04, 0x04,
    /* ObjList11 @ 56 (8) */ 0x4A, 0x00, 0x00, 0x00, 0x13, 0x13, 0x00, 0x13,
    /* ObjList12 @ 64 (8) */ 0x4A, 0x00, 0x00, 0x00, 0x1B, 0x1B, 0x1B, 0x1B,
    /* ObjList13 @ 72 (8) */ 0x2B, 0x2B, 0x2B, 0x13, 0x13, 0x1B, 0x1B, 0x1B,
    /* ObjList14 @ 80 (8) */ 0x16, 0x30, 0x30, 0x1B, 0x1B, 0x16, 0x00, 0x00,
    /* ObjList15 @ 88 (8) */ 0x2B, 0x2B, 0x2B, 0x23, 0x23, 0x24, 0x23, 0x24,
    /* ObjList16 @ 96 (8) */ 0x2B, 0x2B, 0x12, 0x12, 0x12, 0x00, 0x00, 0x00,
    /* ObjList17 @104 (6) */ 0x2B, 0x2B, 0x13, 0x13, 0x17, 0x17,
    /* ObjList18 @110 (8) */ 0x2B, 0x2B, 0x0C, 0x0B, 0x0B, 0x30, 0x30, 0x30,
    /* ObjList19 @118 (8) */ 0x2B, 0x2B, 0x05, 0x05, 0x05, 0x1B, 0x1B, 0x1B,
    /* ObjList20 @126 (8) */ 0x4A, 0x00, 0x00, 0x00, 0x17, 0x17, 0x17, 0x17,
    /* ObjList21 @134 (8) */ 0x4A, 0x00, 0x00, 0x00, 0x23, 0x24, 0x23, 0x24,
    /* ObjList22 @142 (6) */ 0x16, 0x0C, 0x0B, 0x0C, 0x0B, 0x16,
    /* ObjList23 @148 (8) */ 0x2B, 0x2B, 0x2B, 0x27, 0x27, 0x27, 0x27, 0x27,
    /* ObjList24 @156 (8) */ 0x05, 0x06, 0x06, 0x05, 0x06, 0x05, 0x00, 0x00,
    /* ObjList25 @164 (5) */ 0x23, 0x23, 0x24, 0x23, 0x24,
    /* ObjList26 @169 (8) */ 0x2B, 0x17, 0x23, 0x23, 0x17, 0x24, 0x17, 0x24,
    /* ObjList27 @177 (8) */ 0x2D, 0x2D, 0x2D, 0x2C, 0x23, 0x24, 0x23, 0x24,
    /* ObjList28 @185 (8) */ 0x2D, 0x2D, 0x2D, 0x2C, 0x0C, 0x0B, 0x0C, 0x0B,
    /* ObjList29 @193 (8) */ 0x2D, 0x2D, 0x2D, 0x2C, 0x27, 0x27, 0x27, 0x27,
};

/* Offsets into z1_obj_lists, indexed by (template_id - $62). 30 entries. */
static const unsigned char obj_list_offsets[30] = {
    0,   5,   9,   15,  19,  25,  31,  36,  40,  45,
    50,  56,  64,  72,  80,  88,  96,  104, 110, 118,
    126, 134, 142, 148, 156, 164, 169, 177, 185, 193,
};

const unsigned char *obj_list_for_template(unsigned char template_id)
{
    /* NES Z_05.asm:1791 @PlaceList: template_id - $62 -> ObjListAddrs entry. */
    if (template_id < 0x62u) return (const unsigned char *)0;
    unsigned char idx = (unsigned char)(template_id - 0x62u);
    if (idx >= 30u) return (const unsigned char *)0;
    return &z1_obj_lists[obj_list_offsets[idx]];
}

/* Legacy shim — pre-Task-7.7 stub. Returns NULL; callers should migrate to
 * enemy_room_load_objects + obj_list_for_template. */
const unsigned char *obj_list_for_room(unsigned char room_id,
                                       unsigned char scene_id)
{
    (void)room_id;
    (void)scene_id;
    return (const unsigned char *)0;
}

/* NES Z_05.asm:1700-1820 verbatim port of the monster-list parse + ObjType
 * fill. Returns 1 if any objects were loaded, 0 if room is empty.
 *
 * Per-step deferrals:
 *   - ModifyObjCountByHistory{OW,UW} (step 3)        — no-op stub here.
 *   - AssignObjSpawnPositions (step 2)               — caller's responsibility.
 *
 * Cellar (mode 9) override IS applied here per NES — those rooms get 0
 * monster-list-id but AssignObjSpawnPositions injects 4 blue keese.
 */
unsigned char enemy_room_load_objects(unsigned char room_id)
{
    /* Step 1 — parse template_id + count from LevelBlockAttrs C/D. */
    unsigned char attr_c = (unsigned char)DUNGEON_LBA_C(room_id);
    unsigned char attr_d = (unsigned char)DUNGEON_LBA_D(room_id);
    unsigned char template_id = (unsigned char)(attr_c & 0x3Fu);
    if (attr_d & 0x80u) {
        template_id = (unsigned char)(template_id + 0x40u);
    }
    unsigned char foe_idx = (unsigned char)((attr_c >> 6) & 0x03u);
    unsigned char count = (unsigned char)DUNGEON_LEVEL_FOE_COUNTS(foe_idx);

    /* NES Z_05.asm:1727 — boss / non-recurring foe override: count = 1. */
    if (template_id >= 0x32u && template_id < 0x62u) {
        count = 1u;
    }

    /* Step 3 deferred: ModifyObjCountByHistory{OW,UW} (NES Z_05.asm:1740-1746).
     * For step 1 we treat every room as pristine first-entry. */
    /* TODO step 3: history modify hook here. */

    /* NES Z_05.asm:1750 — mode 9 cellar override. nes_ram is the
     * a4-register substrate base from src/abi/platform_abi.h. */
    unsigned char game_mode = nes_ram[0x0012u];
    if (game_mode == 0x09u) {
        template_id = 0u;
        count = 0u;
    }

    /* Step 7 — store count + skip if empty. */
    DUNGEON_ROOM_OBJ_COUNT = count;
    if (count == 0u || template_id == 0u) {
        return 0u;
    }

    /* Step 7a — fill ObjType array. */
    if (template_id < 0x62u) {
        /* Repeat single template across slots 1..count. */
        unsigned char x;
        for (x = 0u; x < count; ++x) {
            OBJ(NES_OBJ_TYPE, (unsigned int)(x + 1u)) = template_id;
        }
    } else {
        /* Copy ObjList[N] into slots 1..count. */
        const unsigned char *src = obj_list_for_template(template_id);
        if (src == (const unsigned char *)0) {
            DUNGEON_ROOM_OBJ_COUNT = 0u;
            return 0u;
        }
        unsigned char y;
        for (y = 0u; y < count; ++y) {
            OBJ(NES_OBJ_TYPE, (unsigned int)(y + 1u)) = src[y];
        }
    }

    /* Step 8 — RoomObjTemplateType = first template. */
    DUNGEON_ROOM_TEMPLATE_TYPE = (unsigned char)OBJ(NES_OBJ_TYPE, 1u);
    return 1u;
}
