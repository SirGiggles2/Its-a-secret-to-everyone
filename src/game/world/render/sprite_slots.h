/* sprite_slots.h — H32 SAT slot contract (single source of truth).
 *
 * NES Z1 PPU has 64 OAM entries. Sega Genesis H32 mode also caps at 64
 * hardware sprites. After retiring the 32-sprite HUD backdrop strip
 * (PD priority 1: best long-term outcome), the H32 SAT is gameplay-only:
 *
 *   0..9   — Link, items, projectiles, weapons (named per-slot below)
 *   10..11 — HUD equipped-item sprites
 *   12..13 — Original HUD player/compass position markers
 *   14..63 — enemy bridge (mirrors NES OAM scatter via enemy_render)
 *   64+    — never used in H32
 *
 * The opaque black HUD underlay now comes from BG_A tile 0 (PAL0 color 0),
 * produced by clear_hud_underlay_for_row_base() in RoomRom/src/main.c.
 *
 * SAT chain: each slot's link field points to the next slot in render
 * order (0->1->2->...->9->10 enemy bridge entry). Per
 * `feedback_genesis_sprite_link_chain` memory: any slot with link=0 in
 * the middle of the chain hides downstream slots.
 *
 * Phase Z (2026-05-18 VRAM cleanup org): every renderer placing sprites
 * MUST use these named constants. Hard-coded literals (0..9, 10, 42,
 * 63) are forbidden. Phase Y lint gate will enforce.
 */
#ifndef SPRITE_SLOTS_H
#define SPRITE_SLOTS_H

/* --- Gameplay slot assignments (0..9). Defined by sprite_render.c
 * ownership (set/clear function per slot). ---
 *
 * Link occupies slot 0 (head sprite of the SAT chain). Sword + beam
 * are weapon projectiles owned by combat_runtime.c. Projectiles (3..6)
 * are owned by per-item runtime files in src/game/items/. Candle /
 * magic shot are FX sprites also owned by combat / item paths. */
#define ROOMROM_SPRITE_SLOT_LINK            0u  /* Player sprite (Link, 2x2) */
#define ROOMROM_SPRITE_SLOT_SWORD           1u  /* Sword body (held during swing) */
#define ROOMROM_SPRITE_SLOT_BEAM            2u  /* Sword beam projectile (post-MakeSwordShot) */
#define ROOMROM_SPRITE_SLOT_BOOMERANG       3u  /* Boomerang in flight */
#define ROOMROM_SPRITE_SLOT_ARROW           4u  /* Arrow projectile */
#define ROOMROM_SPRITE_SLOT_BOMB            5u  /* Bomb (pre-explosion) */
#define ROOMROM_SPRITE_SLOT_EXPLOSION       6u  /* Bomb cloud animation */
#define ROOMROM_SPRITE_SLOT_ROOM_ITEM       7u  /* Room-pickup item (triforce / key / map) */
#define ROOMROM_SPRITE_SLOT_CANDLE_FIRE     8u  /* Candle flame FX */
#define ROOMROM_SPRITE_SLOT_MAGIC_SHOT      9u  /* Magic rod projectile */
#define ROOMROM_SPRITE_SLOT_HUD_B_ITEM     10u  /* HUD B-item LEFT half */
#define ROOMROM_SPRITE_SLOT_HUD_B_ITEM_R   11u  /* HUD B-item RIGHT half (hflip) */
#define ROOMROM_SPRITE_SLOT_HUD_PLAYER     12u  /* Original map player dot */
#define ROOMROM_SPRITE_SLOT_HUD_COMPASS    13u  /* Original map Triforce dot */

/* --- Chain / range bounds --- */
#define ROOMROM_SPRITE_SLOT_LINK_FIRST       ROOMROM_SPRITE_SLOT_LINK
#define ROOMROM_SPRITE_SLOT_GAMEPLAY_LAST    ROOMROM_SPRITE_SLOT_HUD_COMPASS
#define ROOMROM_SPRITE_SLOT_ENEMY_FIRST     14u
#define ROOMROM_SPRITE_SLOT_LAST_H32        63u
#define ROOMROM_SPRITE_UPLOAD_COUNT_H32     64u

/* --- Static asserts (caught at compile time per Phase Z) --- */
#ifdef __STDC_VERSION__
_Static_assert(ROOMROM_SPRITE_SLOT_GAMEPLAY_LAST < ROOMROM_SPRITE_SLOT_ENEMY_FIRST,
               "gameplay slots must not overlap enemy bridge range");
_Static_assert(ROOMROM_SPRITE_SLOT_ENEMY_FIRST <= ROOMROM_SPRITE_SLOT_LAST_H32,
               "enemy bridge must fit within H32 hardware sprite cap");
_Static_assert(ROOMROM_SPRITE_UPLOAD_COUNT_H32 == ROOMROM_SPRITE_SLOT_LAST_H32 + 1u,
               "upload count must cover slot 0 through LAST_H32");
#endif

#endif /* SPRITE_SLOTS_H */
