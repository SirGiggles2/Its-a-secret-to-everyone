/* uw_map_builder.h — dynamic dungeon-map glyph builder.
 *
 * NES source (authoritative): Z_05.asm
 *   Submenu_WriteSheetMapRowTransferRecord (7530-7619)
 *   Submenu_WriteScanningMapRoomMark        (7659-7713)
 *   CalcOpenDoorwayMask                      (7726-7761)
 *   FindDoorAttrByDoorBit                    (4520-4560)
 *
 * Produces the 8-row x 16-col underworld map glyph grid for the current
 * dungeon, reading LIVE visited + door state exactly as the NES does:
 *   - unvisited room (world-flag bit $20 clear) -> $F5 (blank)
 *   - visited room -> 4-bit open-doorway mask (up/down/left/right
 *     walkability) -> glyph $E2 + mask  (range $E2..$F1)
 *   - each row rotated right by LevelInfo_SubmenuMapRotation
 *   - cols blanked where LevelInfo_SubmenuMapMask[col] & MapRowMasks[row]==0
 *
 * Data sources (verified — see commit msg):
 *   door attrs : installed LevelBlockAttrsA/B in nes_ram ($687E/$68FE)
 *                (the LevelBlock install IS byte-aligned)
 *   visited    : live world flags via the savefile room-flags pointer
 *                ($6BAF/$6BB0), the same path gameplay uses
 *   rotation / : rooms_dungeons[] blob, FoeCounts-anchored (the flat
 *   mask /       LevelInfo install is misaligned by 4 so we never read
 *   triforce     nes_ram $6BAB/$6BBD/$6BAE here)
 */
#ifndef UW_MAP_BUILDER_H
#define UW_MAP_BUILDER_H

/* Fill out[8][16] with the live dungeon-map glyph grid for (level 1..9,
 * quest 1..2). out[row][col] indexes room (row<<4 | col) in display space
 * (post-rotate, post-mask). Out of range -> all-blank ($F5). */
void uw_map_build(unsigned char level, unsigned char quest, unsigned char out[8][16]);

/* Per-level/quest LevelInfo fields from the live-NES-captured tables
 * (uw_map_data). level 1..9, quest 1..2; out-of-range -> 0. */
unsigned char uw_map_rotation(unsigned char level, unsigned char quest);     /* low nibble */
unsigned char uw_map_triforce_room(unsigned char level, unsigned char quest);

#endif /* UW_MAP_BUILDER_H */
