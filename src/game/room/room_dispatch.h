/* room_dispatch.h — native room subsystem dispatch (Phase 4).
 *
 * Native rewrite of select leaves from src/oracle/room/room_runtime.c.
 * Both ROMs link.
 */

#ifndef ROOM_DISPATCH_H
#define ROOM_DISPATCH_H

#ifdef __cplusplus
extern "C" {
#endif

/* Read SRAM room-flags pointer + return current room's flag byte.
 * Stashes pointer to SAVEFILE_PTR_LO/HI as side effect. NES GetRoomFlags. */
unsigned char room_get_room_flags(void);

/* Decode CUR_ROOM_ID into (row << 8) | col. NES SplitRoomId. */
unsigned int room_split_room_id(void);

/* if CUR_LEVEL == 0 return 0; else return (SRAM[$6A7E + col] & $80).
 * NES IsDarkRoom. */
unsigned char room_is_dark_room(unsigned int col);

/* ROOM_SFX_MAIN = $80; ROOM_SFX_AUX = $80. NES SilenceSound. */
void room_silence_sound(void);

/* Scan slots ROOM_MAX_MONSTER_SLOT..0 for living monsters. If none,
 * clear LINK_DAMAGE_DISABLE_FLAG and bump ROOM_MONSTER_ALL_DEAD.
 * NES CheckHasLivingMonsters. */
void room_check_has_living_monsters(void);

#ifdef __cplusplus
}
#endif

#endif /* ROOM_DISPATCH_H */
