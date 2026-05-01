#ifndef ROOMROM_VRAM_MAP_H
#define ROOMROM_VRAM_MAP_H

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
 * Layout (post-Phase-3):
 *   tile 0                                  blank (transparent fallback)
 *   tile 1   .. 1 + 4*303 - 1 = 1212        BG bank (NES BG + HUD tiles,
 *                                            4 sub-pal copies x 303 tiles)
 *   tile 1213 .. 1213 + 312 - 1 = 1524      SPR bank (Link, sword, items,
 *                                            common_chr sprite half --
 *                                            sub-pal 0 only for now)
 *   tile 1525 .. 1535                       reserved / future
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
 * Tile bank ends at 1524 -- 11 tiles of headroom before the table region.
 * Audit command:  python RoomRom/tools/audit_vram_tile_usage.py
 *
 * Notes:
 * - SPR sub-pal stride = 312 covers common_chr full (238) + Link walk (32)
 *   + Link attack (16) + item atlas (26). sprites_chr (232 OW enemies) is
 *   NOT in the bank -- enemies are out-of-scope per RoomRom roadmap; they
 *   re-enter the bank when ported.
 * - SPR currently single-copy (sub-pal 0) since all RoomRom OAM uses NES
 *   sprite sub-pal 0. ROOMROM_SPR_TILE_BASE_PAL(s) reserves the math but
 *   only s=0 is populated. Future enemy work expands to s=1..3.
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
#define ROOMROM_SPR_SUBPAL_COUNT        1u      /* sub-pal 0 only; expand later */

#define ROOMROM_BG_TILE_BASE_PAL(s)  \
    (ROOMROM_BG_TILE_BASE  + (unsigned short)(s) * ROOMROM_BG_TILE_COUNT_PER_PAL)
#define ROOMROM_SPR_TILE_BASE_PAL(s) \
    (ROOMROM_SPR_TILE_BASE + (unsigned short)(s) * ROOMROM_SPR_TILE_COUNT_PER_PAL)

#endif
