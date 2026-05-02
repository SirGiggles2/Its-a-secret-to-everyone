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
/* Redux ALttP-style diagonal sword (16x16). Used in Redux arc swing. */
void roomrom_sprites_set_sword_diagonal(short x, short y,
                                        unsigned char hflip,
                                        unsigned char vflip);

/* S7 v5 beam: sword shot projectile (slot 2). NES Z1 draws sword shot
 * via Anim_WriteItemSprites with the same tile pattern as the sword
 * itself (Z_07.asm:3437 DrawSwordShotOrMagicShot, item slot $22 →
 * ItemFrameTiles offset $29 = $20 vertical / $82 horizontal). Per
 * Z_07.asm:3459 the only frame-to-frame variation is a palette-index
 * rotation (FrameCounter & 3) — the sprite SHAPE does not flip or
 * rotate. NES base attribute per direction (RDirectionToWeaponBase
 * Attribute, Z_07.asm:3804): UP=$00, DOWN=$80 (vflip), LEFT=$00 (set
 * via [0F] hflip in DrawSwordShotOrMagicShot:3469), RIGHT=$00.
 *
 * Earlier Genesis impl approximated the palette flash by cycling
 * vflip+hflip each frame; that creates a visible orientation flicker
 * not present on NES. Drop the flicker and apply the NES per-direction
 * flip exactly. Vertical beam = single 8x8 (matches NES @Narrow path
 * for tile $20). Horizontal beam keeps 16x16 because top row of the
 * sword_horz blob contains NES tiles $82+$84 in column-major order. */
void roomrom_sprites_set_beam(short x, short y, link_face_t face);
void roomrom_sprites_clear_beam(void);

/* S7 v6 boomerang (slot 3). 8-phase rotation cycle from
 * BoomerangFrameCycle / BoomerangBaseSpriteAttrCycle. phase_idx is
 * masked to bottom 3 bits. */
void roomrom_sprites_set_boomerang(short x, short y,
                                   unsigned char phase_idx);
void roomrom_sprites_clear_boomerang(void);

/* S7 v7 arrow (slot 4). vertical 8x16 (UP/DOWN, vflip on DOWN). LEFT
 * and RIGHT clear (horizontal CHR not yet extracted). */
void roomrom_sprites_set_arrow(short x, short y, link_face_t face);
void roomrom_sprites_clear_arrow(void);

/* S7 v8 bomb (slot 5) + explosion (slot 6). */
void roomrom_sprites_set_bomb(short x, short y);
void roomrom_sprites_clear_bomb(void);
void roomrom_sprites_set_explosion(short x, short y, unsigned char timer);
void roomrom_sprites_clear_explosion(void);

/* Phase 1: select item-atlas variant (orig vs redux). Affects the next
 * call to roomrom_sprites_upload_chr (item CHR is variant-selected at
 * upload time). */
void roomrom_sprites_set_redux(unsigned char redux);

#endif
