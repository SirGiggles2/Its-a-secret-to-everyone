/* uw_map_data.h — pause dungeon-map data, captured LIVE from NES Z1 SRAM
 * (tools/parity/pause_golden/uw_capture_all_levels.lua). Self-contained:
 * NOT derived from data/rooms/dungeons.c (whose LevelBlockAttrs regen
 * diverges from live NES). Indexed by level 1..9 (index 0 unused).
 * Door blocks: [0]=UW1Q1 (L1-6), [1]=UW2Q1 (L7-9). */
#ifndef UW_MAP_DATA_H
#define UW_MAP_DATA_H
extern const unsigned char k_uw_map_start[10];     /* StartRoomId $6BAD */
extern const unsigned char k_uw_map_rot[10];       /* SubmenuMapRotation $6BAB */
extern const unsigned char k_uw_map_tri[10];       /* TriforceRoomId $6BAE */
extern const unsigned char k_uw_map_mask[10][16];  /* SubmenuMapMask $6BBD */
extern const unsigned char k_uw_door_a[2][128];    /* LevelBlockAttrsA */
extern const unsigned char k_uw_door_b[2][128];    /* LevelBlockAttrsB */
/* level (1..9) -> door block index. */
#define UW_DOOR_BLOCK(level) ((unsigned char)((level) >= 7u ? 1u : 0u))
#endif
