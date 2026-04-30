#ifndef ROOMROM_SPRITES_H
#define ROOMROM_SPRITES_H

/* RoomRom sprite/OAM scaffold.
 *
 * Owns PAL3 and the sprite-CHR VRAM region (tiles 512..743). Renders Link
 * as a single static 16x16 sprite via raw VDP_setSprite + VDP_updateSprites.
 * BG palette loaders must skip PAL3 - see ow_/uw_room_render_roomrom.c.
 *
 * S2+ will add motion, animation frames, and additional sprites.
 */

void roomrom_sprites_upload_chr(void);    /* one-shot at boot */
void roomrom_sprites_load_palette(void);  /* call after every load_room() */
void roomrom_sprites_spawn_link(short x, short y);

#endif
