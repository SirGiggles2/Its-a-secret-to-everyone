#ifndef ROOMROM_VRAM_MAP_H
#define ROOMROM_VRAM_MAP_H

#include "roomrom_item_chr.h"

/* RoomRom VRAM tile map -- single source of truth.
 *
 * Concrete numeric values committed after running
 * RoomRom/tools/audit_vram_tile_usage.py on the Phase 1 baseline trees.
 *
 * Pre-Phase-3 (current): only sub-pal 0 is populated; existing CHR
 * uploads land at the legacy hard-coded bases (HUD_TILE_BASE = 1,
 * SPRITE_VRAM_TILE_BASE = 512, COMMON_VRAM_TILE_BASE = 936). This header
 * defines the *target* post-expansion layout; Phase 3 relocates the
 * upload addresses + emits the 4 sub-pal tile copies to fill the bank.
 *
 * Layout (post-Phase-3, post-ITEM-bank, per `audit_vram_tile_usage.py`):
 *   tile 0                                  blank (transparent fallback)
 *   tile 1   .. 1 + 4*256 - 1 = 1024        BG bank (NES BG + HUD tiles,
 *                                            4 sub-pal copies x 256 tiles)
 *   tile 1025 .. 1025 + 312 - 1 = 1336      SPR bank (Link, sword body,
 *                                            common_chr sprite half --
 *                                            intentionally 1x: every
 *                                            sprite in this bank only
 *                                            uses NES sprite sub-pal 0)
 *   tile 1337 .. 1337 + 4*31 - 1 = 1460     ITEM bank (item atlas:
 *                                            sword, beam, boomerang,
 *                                            arrow, bomb, explosion,
 *                                            sword_diag -- 4 sub-pal
 *                                            copies x 31 tiles, NES
 *                                            DrawCloud/etc cite sub-pal
 *                                            1+ per tile)
 *   tile 1461 .. 1535                       reserved / future
 *   tile 1536+                              VDP plane / window / SAT / HScroll
 *                                            tables (SGDK default layout
 *                                            allocates $C000+ for tables;
 *                                            1536 = $C000 / 32).
 *
 * VRAM table addresses (SGDK default, see sgdk/src/vdp.c:23-27):
 *   plane B  = $C000  (tiles 1536..1791 in 64x32 mode)
 *   window   = $D000  (tiles 1664..1791)
 *   plane A  = $E000  (tiles 1792..2047)
 *   hscroll  = $F000  (tiles 1920..1935)
 *   SAT      = $F400  (tiles 1952..1971)
 *
 * Tile bank ends at 1460 -- 75 tiles of headroom before the table region.
 * Audit command:  python RoomRom/tools/audit_vram_tile_usage.py
 *
 * Notes:
 * - SPR sub-pal stride = 312 covers common_chr full (238) + Link walk (32)
 *   + Link attack (16) + item atlas (26). sprites_chr (232 OW enemies) is
 *   NOT in the bank -- enemies are out-of-scope per RoomRom roadmap; they
 *   re-enter the bank when ported.
 * - SPR is intentionally 1x (sub-pal 0 only). The full SPR bank at 4x
 *   would be 549*4=2196 tiles and collide with the VDP table region at
 *   tile 1536. Items -- the only sprite category with non-trivial NES
 *   sub-pal variation -- live in the dedicated ITEM bank below with
 *   their own 4x sub-pal expansion.
 * - HUD shares the BG bank: HUD tiles ARE NES BG tiles, same expansion
 *   rule, same sub-pal stride.
 */

/* Per-sub-pal stride is 256 because NES BG addresses tiles by 8-bit NES
 * tile ID. OW renderer uploads common BG (112) + OW BG (130) + common
 * misc (14) = 256 distinct NES tile slots; redux automap (32) and secrets
 * (12) get patched into existing slots, not appended. HUD custom tiles
 * (3) likewise live at NES IDs $50..$52 (shared bank). */
#define ROOMROM_BG_TILE_BASE            1u
#define ROOMROM_BG_TILE_COUNT_PER_PAL   256u
#define ROOMROM_BG_SUBPAL_COUNT         4u
#define ROOMROM_SPR_TILE_BASE           1025u   /* 1 + 4*256 */
#define ROOMROM_SPR_TILE_COUNT_PER_PAL  312u
#define ROOMROM_SPR_SUBPAL_COUNT        1u      /* intentionally 1x: items use the dedicated ITEM bank below for sub-pal 1+ variation; SPR-bank sprites (Link, sword body, common) only ever use NES sprite sub-pal 0 */

#define ROOMROM_BG_TILE_BASE_PAL(s)  \
    (ROOMROM_BG_TILE_BASE  + (unsigned short)(s) * ROOMROM_BG_TILE_COUNT_PER_PAL)
#define ROOMROM_SPR_TILE_BASE_PAL(s) \
    (ROOMROM_SPR_TILE_BASE + (unsigned short)(s) * ROOMROM_SPR_TILE_COUNT_PER_PAL)

/* Item atlas sub-bank: per-category 4x sub-pal expansion. NES Z1 draws
 * bomb / explosion with sprite sub-pal 1; future sword-level upgrades
 * use sub-pal 1 / 2 (Items inventory). Other persistent sprites
 * (Link, sword, beam, common) only ever use sub-pal 0 -- they stay in
 * the 1x SPR bank above.
 *
 * VRAM math: ITEM bank starts immediately after the SPR bank end and
 * holds 4 copies of the item atlas (sub-pal 0..3), each ITEM_TILE_COUNT
 * tiles wide. Total = 4 * ITEM_TILE_COUNT.
 *
 * ITEM_TILE_COUNT_PER_PAL is sourced from the generated header
 * roomrom_item_chr.h (ROOMROM_ITEM_CHR_TILE_COUNT). The verifier
 * tools/verify_vram_budget.py confirms ITEM bank does not overlap
 * with VDP table region or any other VRAM consumer. */
#define ROOMROM_ITEM_TILE_BASE          (ROOMROM_SPR_TILE_BASE + ROOMROM_SPR_TILE_COUNT_PER_PAL)
#define ROOMROM_ITEM_TILE_COUNT_PER_PAL ROOMROM_ITEM_CHR_TILE_COUNT
#define ROOMROM_ITEM_SUBPAL_COUNT       4u
#define ROOMROM_ITEM_TILE_BASE_PAL(s) \
    (ROOMROM_ITEM_TILE_BASE + (unsigned short)(s) * ROOMROM_ITEM_TILE_COUNT_PER_PAL)

#endif
