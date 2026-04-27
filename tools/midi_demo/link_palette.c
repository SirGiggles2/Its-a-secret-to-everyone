/* link_palette.c — 16-color CRAM palette for Link demo.
 *
 * Genesis CRAM word format: ----BBB0 GGG0 RRR0 (3-bit channels, even values).
 *   index 0 : background fill (deep blue, fairy-fountain mood)
 *   index 1 : black (outline / eyes)
 *   index 2 : green (Link's hat and tunic)
 *   index 3 : flesh (face / arms)
 *   index 4 : brown (boots / belt)
 *   index 5 : white (eye whites)
 *   indices 6..15 unused (zeroed)
 */
const unsigned short link_palette[16] = {
    0x0420,  /* 0: dark teal/blue fountain backdrop */
    0x0000,  /* 1: black */
    0x00E0,  /* 2: green */
    0x06AE,  /* 3: flesh */
    0x0248,  /* 4: brown */
    0x0EEE,  /* 5: white */
    0x0000, 0x0000, 0x0000, 0x0000,
    0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
};
