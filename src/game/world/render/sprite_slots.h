/* sprite_slots.h — H32 SAT slot contract (single source of truth).
 *
 * NES Z1 PPU has 64 OAM entries. Sega Genesis H32 mode also caps at 64
 * hardware sprites. After retiring the 32-sprite HUD backdrop strip
 * (PD priority 1: best long-term outcome), the H32 SAT is gameplay-only:
 *
 *   0..9   — Link, items, projectiles, weapons
 *   10..63 — enemy bridge (mirrors NES OAM scatter via enemy_render)
 *   64+    — never used in H32
 *
 * The opaque black HUD underlay now comes from BG_A tile 0 (PAL0 color 0),
 * produced by clear_hud_underlay_for_row_base() in RoomRom/src/main.c.
 *
 * Every renderer that places sprites in the 10..63 range MUST use the
 * symbolic constants below. Hard-coded literals (10, 42, 63) are forbidden.
 */
#ifndef SPRITE_SLOTS_H
#define SPRITE_SLOTS_H

#define ROOMROM_SPRITE_SLOT_LINK_FIRST       0u
#define ROOMROM_SPRITE_SLOT_GAMEPLAY_LAST    9u
#define ROOMROM_SPRITE_SLOT_ENEMY_FIRST     10u
#define ROOMROM_SPRITE_SLOT_LAST_H32        63u
#define ROOMROM_SPRITE_UPLOAD_COUNT_H32     64u

#endif /* SPRITE_SLOTS_H */
