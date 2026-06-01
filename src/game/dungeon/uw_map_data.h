/* uw_map_data.h — pause dungeon-map data, captured LIVE from NES Z1 SRAM
 * (tools/parity/pause_golden/uw_capture_all_levels.lua, quests 1 + 2).
 * Self-contained: NOT derived from data/rooms/dungeons.c (whose
 * LevelBlockAttrs regen diverges from live NES). First index = quest-1
 * (quest 1 -> 0, quest 2 -> 1); second = level 1..9 (index 0 unused).
 * Door blocks: 0=UW1Q1(L1-6) 1=UW2Q1(L7-9) 2=UW1Q2(L1-6) 3=UW2Q2(L7-9). */
#ifndef UW_MAP_DATA_H
#define UW_MAP_DATA_H
extern const unsigned char k_uw_map_start[2][10];     /* StartRoomId $6BAD */
extern const unsigned char k_uw_map_rot[2][10];       /* SubmenuMapRotation $6BAB */
extern const unsigned char k_uw_map_tri[2][10];       /* TriforceRoomId $6BAE */
extern const unsigned char k_uw_sbxoff[2][10];        /* StatusBarMapXOffset $6BAC (signed) */
extern const unsigned char k_uw_marker_color[2][10];  /* SPR sub-pal3[1] marker tint */
extern const unsigned char k_uw_map_mask[2][10][16];  /* SubmenuMapMask $6BBD */
extern const unsigned char k_uw_door_a[4][128];       /* LevelBlockAttrsA */
extern const unsigned char k_uw_door_b[4][128];       /* LevelBlockAttrsB */

/* quest 1..2 -> index 0..1 (clamped). */
#define UW_QI(quest)            ((unsigned char)((quest) == 2u ? 1u : 0u))
/* (level 1..9, quest 1..2) -> door block index. */
#define UW_DOOR_BLOCK(level, quest) \
    ((unsigned char)(((quest) == 2u ? 2u : 0u) + ((level) >= 7u ? 1u : 0u)))

#endif /* UW_MAP_DATA_H */
