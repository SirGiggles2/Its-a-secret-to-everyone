#ifndef ROOMROM_SPRITES_H
#define ROOMROM_SPRITES_H

/* RoomRom sprite/OAM scaffold.
 *
 * Owns PAL3 and the sprite-CHR VRAM region. Renders Link as slot 0 +
 * sword as slot 1.
 *
 * S7 v4 combat additions:
 *   - Attack-pose tiles uploaded alongside walk poses (4 facings, 4
 *     tiles each = 16 tiles). Wielding-sword body sprite per Z1
 *     PlayerObjState = $10 — see Z_05.asm WieldSword.
 *   - Vertical sword (UP/DOWN): 8x16 sprite, NES tile $20 (top) +
 *     $21 (bottom) from common_chr. UP no flip, DOWN vflip.
 *   - Horizontal sword (LEFT/RIGHT): 16x16 sprite, NES tiles $82-$85
 *     from common_chr. RIGHT no flip, LEFT hflip.
 *
 * NES Z1 source: reference/aldonunez/Z_01.asm Anim_ItemFrameTiles +
 * Z_07.asm RDirectionToWeaponBaseAttribute + PlayerToWeaponOffsetsX/Y.
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

/* S7 v4 combat. */
void roomrom_sprites_set_link_attack_pose(short x, short y, link_face_t face);
void roomrom_sprites_set_sword_vertical(short x, short y, unsigned char vflip);
void roomrom_sprites_set_sword_horizontal(short x, short y, unsigned char hflip);
void roomrom_sprites_clear_sword(void);

#endif
