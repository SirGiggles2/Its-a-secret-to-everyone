#ifndef SRC_GAME_ENEMIES_OBJ_LISTS_H
#define SRC_GAME_ENEMIES_OBJ_LISTS_H

/* Phase 7 Task 7.2 step 2 — NES ObjLists.dat verbatim port.
 *
 * NES source: reference/aldonunez/dat/ObjLists.dat (201 bytes)
 *             reference/aldonunez/Z_05.asm:1450 ObjLists / @PlaceList
 *             InitObject_JumpTable consumer at Z_07.asm:5601
 *
 * Each ObjList is a contiguous run of ObjType bytes that maps slot index
 * (1..N) to the InitObject_JumpTable row to call when the room loads.
 * The per-room template_id -> ObjList offset mapping lives in the NES
 * @PlaceList logic (Z_05.asm:1798) which Task 7.7 will port. Until then
 * obj_list_for_room() is a stub returning NULL.
 *
 * Drain Rule D1: ADOPT (data port, function drain N/A).
 * Hard rule WT-5: file lives at src/game/enemies/, not RoomRom/data/.
 */

#ifdef __cplusplus
extern "C" {
#endif

#define ENEMY_OBJLISTS_LEN 201u

extern const unsigned char z1_obj_lists[ENEMY_OBJLISTS_LEN];

/* Returns a pointer to the start of the ObjList for (room_id, scene_id),
 * or NULL when no list applies (room is empty / Task 7.7 stub returns
 * NULL universally). Caller iterates ObjType bytes until the list-end
 * sentinel ($00 in trailing fill or external length count) — Task 7.7
 * lands the per-room length table.
 *
 * scene_id: 0 = overworld, 1 = underworld L1.. per scene bank id.
 */
const unsigned char *obj_list_for_room(unsigned char room_id,
                                       unsigned char scene_id);

#ifdef __cplusplus
}
#endif

#endif /* SRC_GAME_ENEMIES_OBJ_LISTS_H */
