#ifndef ROOMROM_SPRITES_H
#define ROOMROM_SPRITES_H

/* RoomRom sprite/OAM scaffold.
 *
 * Owns PAL1 (NES SPR PALRAM) + the sprite-CHR VRAM region. PAL2 is borrowed
 * dynamically by the sword-beam color flash. Renders Link as slot 0 +
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

void roomrom_sprites_upload_chr(void);    /* one-shot at boot (persistent + items) */
/* PR-4 split: persistent CHR (common + Link walk/attack) covers tiles
 * 1025..1310 — overlaps SCENE_OBJ at 1069..1204. Re-uploading on every
 * scene change clobbers level_chr_swap output. Boot calls _persistent +
 * _items; scene_load calls _items only. */
void roomrom_sprites_upload_persistent_chr(void);
void roomrom_sprites_upload_items_chr(void);
void roomrom_sprites_load_palette(void);  /* call after every load_room() */
void roomrom_sprites_invalidate_cache(void);
void roomrom_sprites_spawn_link(short x, short y);
void roomrom_sprites_set_link_pos(short x, short y);
void roomrom_sprites_set_link_pose(short x, short y,
                                   link_face_t face, unsigned char frame);

/* Pose with explicit palette index (RENDER_PAL0..PAL3). Used by the
 * invincibility-flash path: when LINK_STUN_TIMER > 0, caller cycles
 * pal_index across (FrameCounter & $03) so Link visually flickers
 * through 4 palettes. Default rendering uses PAL1. */
void roomrom_sprites_set_link_pose_pal(short x, short y,
                                       link_face_t face, unsigned char frame,
                                       unsigned char pal_index);


/* S7 v4 combat. */
void roomrom_sprites_set_link_attack_pose(short x, short y, link_face_t face);

/* sub_pal: NES sprite sub-palette index (0-3).
 * NES @CalcSwordAttrs (Z_07.asm:4471): sub-pal = base_attr + Items - 1.
 * base_attr = 0 (RDirectionToWeaponBaseAttribute for sword), so
 * sub-pal == Items - 1.  Wood sword (Items=1) -> 0, white (Items=2) -> 1,
 * magic (Items=3) -> 2.  Callers resolve via sword_subpal_for_items(). */
void roomrom_sprites_set_sword_vertical(short x, short y, unsigned char vflip,
                                        unsigned char sub_pal);
void roomrom_sprites_set_sword_horizontal(short x, short y, unsigned char hflip,
                                          unsigned char sub_pal);
void roomrom_sprites_clear_sword(void);
/* Redux ALttP-style diagonal sword (16x16). Used in Redux arc swing.
 * sub_pal: same NES @CalcSwordAttrs derivation as above. */
void roomrom_sprites_set_sword_diagonal(short x, short y,
                                        unsigned char hflip,
                                        unsigned char vflip,
                                        unsigned char sub_pal);

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
 * flip exactly. Vertical beam = single 8x16 (matches NES @Narrow path
 * for tile $20 in 8x16 sprite mode). Horizontal beam is 16x16: two NES
 * 8x16 OAM entries side by side, with draw offsets applied from object
 * coordinates in the renderer.
 *
 * Phase B (2026-05-18 VRAM cleanup): pal_index cycles RENDER_PAL1/PAL2/
 * PAL3 across frames so the beam color flashes through NES SPR sub-pals
 * 0..2 via OAM pal field. Previous scheme rewrote PAL2[0..3] per frame
 * via CRAM subrange upload, which blocked PAL2 from holding sub-pal 1
 * colors permanently (needed for bomb/explosion routing). */
void roomrom_sprites_set_beam(short x, short y, link_face_t face,
                              unsigned char pal_index);
void roomrom_sprites_clear_beam(void);

/* S7 v6 boomerang (slot 3). 8-phase rotation cycle from
 * BoomerangFrameCycle / BoomerangBaseSpriteAttrCycle. phase_idx is
 * masked to bottom 3 bits.
 * sub_pal: NES sprite sub-palette index (0-3). Per NES
 * DrawBoomerangAndCheckCollision (Z_07.asm:3437) -> base attribute = 0
 * (RDirectionToWeaponBaseAttribute = 0 for all dirs); callers pass
 * sub_pal=0. */
void roomrom_sprites_set_boomerang(short x, short y,
                                   unsigned char phase_idx,
                                   unsigned char sub_pal);
void roomrom_sprites_clear_boomerang(void);

/* S7 v7 arrow (slot 4). vertical 8x16 (UP/DOWN, vflip on DOWN). LEFT
 * and RIGHT clear (horizontal CHR not yet extracted).
 * sub_pal: NES sprite sub-palette index (0-3). Per NES
 * UpdateRodOrArrow (Z_07.asm:4322) -> arrow item slot 2 -> frame 0/1
 * (vert/horz) -> tile $28/$86 -> base attr 0 (sub-pal 0). */
void roomrom_sprites_set_arrow(short x, short y, link_face_t face,
                               unsigned char sub_pal);
void roomrom_sprites_clear_arrow(void);

/* S7 v8 bomb (slot 5) + explosion (slot 6).
 * sub_pal: NES sprite sub-palette index (0-3). Per NES DrawCloud
 * (Z_07.asm:4912) both bomb-visible state and cloud animation frames
 * use sprite attribute Y=1, so callers pass sub_pal=1. */
void roomrom_sprites_set_bomb(short x, short y, unsigned char sub_pal);
void roomrom_sprites_clear_bomb(void);
void roomrom_sprites_set_explosion(short x, short y, unsigned char timer,
                                   unsigned char sub_pal);
void roomrom_sprites_clear_explosion(void);

/* Task 5.9.1 room-item sprite (slot 7). Renders the room-pickup item
 * at the NES (item_x, item_y) position.
 *
 * Phase K (2026-05-18): item_id-aware dispatch. Triforce (NES item_id
 * 0x1B = UW_ITEM_ID_TRIFORCE) uses the extracted TRIFORCE_PIECE tile
 * (2x2 wide, sub-pal 2). Other item_ids (compass, map, heart container,
 * etc) fall back to boomerang glyph placeholder until their CHR is
 * extracted in a follow-up sub-project.
 *
 * sub_pal: NES sub-palette (typically 0 for room items). */
void roomrom_sprites_set_room_item(short x, short y,
                                   unsigned char item_id,
                                   unsigned char sub_pal);
void roomrom_sprites_clear_room_item(void);

/* Candle fire (slot 8). Owned here so gameplay code does not write SAT
 * entries directly outside the sprite module.
 *
 * Phase P (2026-05-18): frame_index 0..3 selects animation frame
 * (F0/F1/F2/F3). Manifest carries all 4 entries per NES Z_07.asm:4622
 * UpdateFire cadence. Caller advances frame from per-instance timer. */
void roomrom_sprites_set_candle_fire(short x, short y,
                                     unsigned char hflip,
                                     unsigned char sub_pal,
                                     unsigned char frame_index);
void roomrom_sprites_clear_candle_fire(void);

/* Magic rod shot (slot 9). Vertical 8x16 (UP/DOWN) or horizontal 16x16
 * (LEFT/RIGHT, hflip on LEFT). sub_pal: 0..2 (NES "flash" cycles 0..3
 * via FrameCounter & 3; Genesis 3-pal atlas wraps to 0..2). Per NES
 * UpdateSwordShotOrMagicShot (Z_07.asm:3437) item slot $23 — frame 0
 * = tile $7A, frame 1 = tile $7C. */
void roomrom_sprites_set_magic_shot(short x, short y, link_face_t face,
                                    unsigned char sub_pal);
void roomrom_sprites_clear_magic_shot(void);

/* Phase 1: select item-atlas variant (orig vs redux). Affects the next
 * call to roomrom_sprites_upload_chr (item CHR is variant-selected at
 * upload time). */
void roomrom_sprites_set_redux(unsigned char redux);

/* Phase P (2026-05-18) fairy spark — generic API; caller picks slot.
 * NES Z_04.asm:11508 DrawFairy cadence: frame toggles every 4 vblanks
 * via FrameCounter ASL & 0x04 >> 2. Manifest carries F0/F1 tile entries
 * (tile $50/$51 frame 0, tile $52/$53 frame 1; sub-pal 1 forced).
 *
 * slot: SAT slot in the enemy bridge range (>= ROOMROM_SPRITE_SLOT_ENEMY_FIRST).
 * frame_index: 0 or 1 (mod 2).
 * link_to: next SAT slot in chain (per sprite link rules). */
void roomrom_sprites_set_fairy_spark(unsigned char slot,
                                     short x, short y,
                                     unsigned char frame_index,
                                     unsigned char link_to);

#endif
