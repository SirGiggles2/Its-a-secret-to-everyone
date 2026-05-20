/* inventory_tilemap.h — V2.1 NES subscreen nametable blob. */
#ifndef INVENTORY_TILEMAP_H
#define INVENTORY_TILEMAP_H

/* 30 rows x 32 cols of NES BG tile_ids, captured from active subscreen
 * (CIRAM page 1 / $2400). Tile $24 = blank. */
extern const unsigned char k_inventory_tilemap[30][32];

#endif
