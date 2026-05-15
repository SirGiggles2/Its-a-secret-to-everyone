/* enemy_render.h — NES OAM mirror -> Genesis SAT bridge.
 *
 * NES source:
 *   reference/aldonunez/Z_01.asm:5365 Anim_WriteSprite (drained body)
 *   reference/aldonunez/Z_01.asm:4958 SpriteOffsets (verbatim table)
 *   reference/aldonunez/Z_01.asm:3088 CycleCurSpriteIndex
 *   reference/aldonunez/Variables.inc:82 Sprites := $0200 (OAM mirror)
 *   reference/aldonunez/Variables.inc:87 RollingSpriteIndex := $0341
 *
 * Drained C: NONE prior. This file ships the drained Anim_WriteSprite +
 * a Genesis-native end-of-tick sweep that copies NES OAM mirror at
 * $0200..$02FF into the SGDK SAT.
 *
 * Stance: GREENFIELD per Drain Rule D1 — drain_coverage.json has no
 * candidate row for the sprite render primitive. NES asm wins ties.
 *
 * Bridge layout:
 *   - anim_write_sprite_drained(tile, slot)    drained Z_01.asm:5365 body.
 *     Writes 4 OAM bytes at nes_ram[$0200+offset] + cycles
 *     RollingSpriteIndex.
 *   - enemy_render_sweep_oam_to_sat()           Genesis-native sweep.
 *     Reads NES OAM mirror, writes SGDK SAT slots 32-72 for enemy
 *     sprites (Link/items keep 0-31). Caller invokes once per tick
 *     after enemy_loop_tick + before SYS_doVBlankProcess.
 *
 * Tile-ID translation (initial pass):
 *   NES tile id -> SCENE_OBJ tile_base + nes_tile_id. NES Z1 sprite
 *   tiles live at $00..$BF in 8x16 mode. Our SCENE_OBJ slot at
 *   roomrom_vram_map.h::ROOMROM_SPR_TILE_BASE+44 holds enemy CHR.
 *   Per-enemy refined mapping lands in follow-up commits.
 */

#ifndef ENEMY_RENDER_H
#define ENEMY_RENDER_H

void anim_write_sprite_drained(unsigned int tile, unsigned int slot);
void enemy_render_sweep_oam_to_sat(void);
void enemy_render_reset_oam(void);

/* 2026-05-15 native renderer. Reads per-slot latched sprite state
 * (populated by anim_write_sprite_drained), emits <= 11 Genesis SAT
 * entries per frame. ~50 → ~11 SAT writes per frame on busy rooms. */
void enemy_render_native_sweep(void);
void enemy_render_native_reset(void);

#endif
