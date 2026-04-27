/* link_sprite.c — 16x16 Link facing down, hand-authored as 4 Genesis 4bpp tiles.
 *
 * Sprite layout for VDP "size 2x2" sprite (1 SAT entry, 4 tiles).  Tile order
 * inside a sprite is column-major: tile 0 = top-left, tile 1 = bottom-left,
 * tile 2 = top-right, tile 3 = bottom-right.
 *
 * Palette indices used (line 0):
 *   0 = transparent
 *   1 = black (eyes / boot accents)
 *   2 = green (hat + tunic)
 *   3 = flesh (face + arms)
 *   4 = brown (boots + belt)
 *   5 = white (eye whites)
 *
 * Genesis 4bpp tile encoding: 32 bytes/tile, 8 rows x 4 bytes, 2 pixels per
 * byte (high nibble = left pixel, low nibble = right pixel).
 */

const unsigned char link_sprite_chr[128] = {
    /* ---------------- Tile 0: top-left (rows 0-7, cols 0-7) ---------------- */
    0x00, 0x02, 0x22, 0x20,   /* . . . 2 2 2 2 .  */
    0x00, 0x22, 0x22, 0x22,   /* . . 2 2 2 2 2 2  */
    0x02, 0x22, 0x00, 0x00,   /* . 2 2 2 . . . .  */
    0x02, 0x00, 0x33, 0x33,   /* . 2 . . 3 3 3 3  */
    0x00, 0x03, 0x33, 0x33,   /* . . . 3 3 3 3 3  */
    0x00, 0x03, 0x15, 0x33,   /* . . . 3 1 5 3 3  */
    0x00, 0x03, 0x33, 0x33,   /* . . . 3 3 3 3 3  */
    0x00, 0x03, 0x33, 0x33,   /* . . . 3 3 3 3 3  */

    /* ---------------- Tile 1: bottom-left (rows 8-15, cols 0-7) ----------- */
    0x00, 0x22, 0x22, 0x22,   /* . . 2 2 2 2 2 2  */
    0x02, 0x22, 0x22, 0x22,   /* . 2 2 2 2 2 2 2  */
    0x22, 0x22, 0x22, 0x22,   /* 2 2 2 2 2 2 2 2  */
    0x22, 0x22, 0x22, 0x22,   /* 2 2 2 2 2 2 2 2  */
    0x02, 0x22, 0x22, 0x22,   /* . 2 2 2 2 2 2 2  */
    0x00, 0x23, 0x32, 0x22,   /* . . 2 3 3 2 2 2  */
    0x00, 0x04, 0x44, 0x40,   /* . . . 4 4 4 4 .  */
    0x00, 0x04, 0x44, 0x40,   /* . . . 4 4 4 4 .  */

    /* ---------------- Tile 2: top-right (rows 0-7, cols 8-15) ------------- */
    0x02, 0x22, 0x20, 0x00,   /* . 2 2 2 2 . . .  */
    0x22, 0x22, 0x22, 0x00,   /* 2 2 2 2 2 2 . .  */
    0x00, 0x00, 0x22, 0x20,   /* . . . . 2 2 2 .  */
    0x33, 0x33, 0x00, 0x20,   /* 3 3 3 3 . . 2 .  */
    0x33, 0x33, 0x30, 0x00,   /* 3 3 3 3 3 . . .  */
    0x33, 0x33, 0x51, 0x30,   /* 3 3 3 3 5 1 3 .  */
    0x33, 0x33, 0x33, 0x30,   /* 3 3 3 3 3 3 3 .  */
    0x33, 0x33, 0x33, 0x30,   /* 3 3 3 3 3 3 3 .  */

    /* ---------------- Tile 3: bottom-right (rows 8-15, cols 8-15) --------- */
    0x22, 0x22, 0x22, 0x00,   /* 2 2 2 2 2 2 . .  */
    0x22, 0x22, 0x22, 0x20,   /* 2 2 2 2 2 2 2 .  */
    0x22, 0x22, 0x22, 0x22,   /* 2 2 2 2 2 2 2 2  */
    0x22, 0x22, 0x22, 0x22,   /* 2 2 2 2 2 2 2 2  */
    0x22, 0x22, 0x22, 0x20,   /* 2 2 2 2 2 2 2 .  */
    0x22, 0x22, 0x33, 0x20,   /* 2 2 2 2 2 2 3 3 .  -- (typo in comment; bytes correct) */
    0x04, 0x44, 0x40, 0x00,   /* . 4 4 4 4 . . .  */
    0x04, 0x44, 0x40, 0x00,   /* . 4 4 4 4 . . .  */
};
