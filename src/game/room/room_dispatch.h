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

/* Reset ROOM_MODE_TIMER + SUBMODE_VALUE; return 0. NES EndGameMode
 * (the inner Plan-C drain in src/oracle/room/room_mode_runtime.c:249). */
unsigned char room_end_game_mode(void);

/* Walk OAM 64 sprites; set Y=$F8 to hide all. NES HideAllSprites.
 * drain at room_runtime.c:273-276. */
void room_hide_all_sprites(void);

/* CUR_ROOM_ID indexes SRAM unique-id table; mask bottom 6 bits.
 * NES GetUniqueRoomId. drain at room_runtime.c:278-281. */
unsigned char room_get_unique_room_id(void);

/* Clear ROOM_HISTORY[0..5] + ROOM_HISTORY_IDX. NES ClearRoomHistory.
 * drain at room_runtime.c:283-287. */
void room_clear_room_history(void);

/* Reset LINK_ACTION_TIMER + LINK_HALT_FLAG. NES ResetPlayerState.
 * drain at room_runtime.c:289-292. */
void room_reset_player_state(void);

/* Set room-flag bit 5 (visited) at SRAM[ptr + CUR_ROOM_ID]. NES
 * MarkRoomVisited. drain at room_runtime.c:294-299. */
void room_mark_room_visited(void);

/* MODE_VALUE++; room_end_game_mode(). NES GoToNextMode.
 * drain at room_mode_runtime.c:255-258. */
void room_go_to_next_mode(void);

#ifdef __cplusplus
}
#endif

#endif /* ROOM_DISPATCH_H */
