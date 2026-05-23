/* NES OW sub-pal 3 ($3F1C..$3F1F) per-room snapshot captured live
 * from NES Z1 ROM via tools/parity/probe_nes_ow_subpal3_scan.lua at
 * Mode 5 InitMode5Play settle. 128 rooms x 4 bytes (universal +
 * 3 visible colors).
 *
 * Embedded into Gen as ground-truth lookup. Replaces the per-room
 * NES Z_07.asm:1483-1527 @ChooseTileObjPalette dispatch (which needs
 * LevelBlockAttrsE + LevelBlockAttrsB mirror to be populated).
 *
 * Consumer: src/game/world/ow_palette.c roomrom_ow_palette_patch_subpal3.
 */
#ifndef ROOMROM_OW_SUBPAL3_TABLE_H
#define ROOMROM_OW_SUBPAL3_TABLE_H

extern const unsigned char k_ow_subpal3_per_room[128][4];

#endif /* ROOMROM_OW_SUBPAL3_TABLE_H */
