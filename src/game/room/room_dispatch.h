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

/* Copy a 22-byte room column from PlayArea ($6530-base) into the
 * transfer buffer at TRANSFER_BUF_POS, incrementing the buffer and
 * stashing PPU dst + src ptrs. NES CopyColumnToTilebuf.
 * drain at room_transfer_runtime.c:6-32. */
void room_copy_column_to_tilebuf(void);

/* go_to_next_mode + RAM($0394)=0. NES GoToNextMode_ResetGridOffset.
 * drain at room_mode_runtime.c:267-270. */
void room_go_to_next_mode_reset_grid_offset(void);

/* ITEM_SFX_SECONDARY=LevelSongIds[CUR_LEVEL]; go_to_next_mode;
 * RAM($0394)=0. NES GoToNextMode_PlayLevelSong.
 * drain at room_mode_runtime.c:260-265. */
void room_go_to_next_mode_play_level_song(void);

/* MODE_VALUE++; SUBMODE_VALUE=0; ROOM_MODE_TIMER=0; clear RAM($000F),
 * LINK_ACTION_TIMER, RAM($00C0), RAM($00D3), LINK_STUN_TIMER. NES
 * GoToNextMode_FromPlay. drain at room_mode_runtime.c:306-315. */
void room_go_to_next_mode_from_play(void);

/* If ROOM_INPUT_DIR is non-zero and Link is at the per-direction
 * screen-edge bound, go to next mode. NES CheckScreenEdge.
 * drain at room_runtime.c:301-322. */
void room_check_screen_edge(void);

/* PPU_MASK shadow = 0; clear NES_PPU_MASK_SHADOW. NES TurnOffAllVideo
 * (Z_07.asm:1739). Genesis-native: maintain shadow for re-upload via
 * existing pipeline. drain semantics: write 0 to RAM($00FE). */
void room_turn_off_all_video(void);

/* Heart-fill animation tick: if state set, advance partial heart by
 * +6 each tick; rollover to next heart when full; stop at hearts ==
 * containers. NES WorldFillHearts.
 * drain at room_object_runtime.c:31-48. */
void room_world_fill_hearts(void);

/* SwitchBank(5) [no-op on Genesis — MMC1 was NES] + WorldFillHearts +
 * WorldChangeRupees. NES UpdateHeartsAndRupees.
 * drain at room_mode_runtime.c:323-327. */
void room_update_hearts_and_rupees(void);

/* update_world_curtain_effect; if curtain done, [skip MMC1 ctrl —
 * Genesis no-op] + dispatch by cellar flag. NES UpdateMode3Unfurl.
 * drain at room_mode_runtime.c:295-304. */
void room_update_mode3_unfurl(void);

/* turn_off_all_video; UpdateMode2Load_Full (bank-window load + Q2
 * patch dispatch); go_to_next_mode. NES UpdateMode2_Load.
 * drain at room_mode_runtime.c:317-321 + room_load_runtime.c:299-325.
 *
 * Q1 (default quest) path fully native. Q2 (second quest) level>0
 * Q2-patch loop is STAGE-1 STUB pending bake of 9 LevelInfoUWQ2Replacements
 * blobs (~600 bytes). Q2 level=0 patch_q2_rooms native. */
void room_update_mode2_load(void);

/* Read MenuPalettesTransferBuf[20 + SaveSlotToPaletteRowOffset[slot]],
 * write to SRAM($0B92), set ROOM_TRANSFER_BUF_SELECT=24, advance
 * submode. Patches the level palette row 7 to match the player's
 * personal color (selected at file-select). NES
 * PatchAndCueLevelPalettesTransfer.
 * drain at room_mode_runtime.c:272-279. */
void room_patch_and_cue_level_palettes_transfer(void);

/* If CUR_LEVEL!=0 or ROOM_ID_ALT==$FF, read room_id from SRAM($0BAD);
 * else use ROOM_ID_ALT (and clear it). Then patch_and_cue. NES
 * InitMode3_Sub1. drain at room_mode_runtime.c:281-293. */
void room_init_mode3_sub1(void);

/* ROOM_INV_OBJ_ACTIVE = 0; ROOM_INV_OBJ_STATE[0..5] = 0.
 * NES ResetInvObjState. drain at room_load_runtime.c:25-30. */
void room_reset_inv_obj_state(void);

#ifdef __cplusplus
}
#endif

#endif /* ROOM_DISPATCH_H */
