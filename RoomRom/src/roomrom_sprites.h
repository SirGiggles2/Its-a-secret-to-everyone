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

typedef enum {
    LINK_FACE_DOWN  = 0,
    LINK_FACE_UP    = 1,
    LINK_FACE_LEFT  = 2,
    LINK_FACE_RIGHT = 3
} link_face_t;

void roomrom_sprites_upload_chr(void);    /* one-shot at boot */
void roomrom_sprites_load_palette(void);  /* call after every load_room() */
void roomrom_sprites_spawn_link(short x, short y);
void roomrom_sprites_set_link_pos(short x, short y);
void roomrom_sprites_set_link_pose(short x, short y,
                                   link_face_t face, unsigned char frame);

/* S7 combat: sword sprite (slot 1). Sword tile data uploaded inside
 * roomrom_sprites_upload_chr alongside Link poses. set_sword_pose draws
 * sword 8x16 in current facing direction at the given screen coords;
 * clear_sword hides it (Y off-screen). UP/DOWN supported in v1; LEFT/RIGHT
 * fall through to clear (TODO horizontal sword tiles). */
void roomrom_sprites_set_sword_pose(link_face_t face, short x, short y);
void roomrom_sprites_clear_sword(void);

#endif
