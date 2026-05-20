/*
 * Joypad API public surface (S1 Phase D, Task D3).
 *
 * Owned C in src/frontend/ and src/game/ calls joy_* functions here
 * instead of reading CTRL1_DATA directly. The implementation
 * (src/sgdk_adapter/joy_adapter.c) mirrors the existing Genesis 3-button
 * read pattern from intro_main.c and fs_input.c; Phase F migrates to
 * SGDK JOY_readJoypad per call site.
 *
 * NES button bitmask (sole authoritative reference at this layer):
 *   Bit 0: A
 *   Bit 1: B
 *   Bit 2: SELECT
 *   Bit 3: START
 *   Bit 4: UP
 *   Bit 5: DOWN
 *   Bit 6: LEFT
 *   Bit 7: RIGHT
 *
 * Spec ref: 2026-04-27-native-genesis-rewrite-design.md Section 4.2
 * Plan retarget (step 3) deferred to Phase F - D3 is compile-only.
 */

#ifndef JOY_ABI_H
#define JOY_ABI_H

/* NES button bitmask constants. */
#define JOY_BTN_A       0x01u
#define JOY_BTN_B       0x02u
#define JOY_BTN_SELECT  0x04u
#define JOY_BTN_START   0x08u
#define JOY_BTN_UP      0x10u
#define JOY_BTN_DOWN    0x20u
#define JOY_BTN_LEFT    0x40u
#define JOY_BTN_RIGHT   0x80u

/* Read port 0 (player 1). Returns NES-button bitmask: bits set = pressed.
 * This is a raw instantaneous read (not edge-triggered). */
unsigned char joy_read(void);

/* Read the specified port (0 = player 1, 1 = player 2).
 * Returns NES-button bitmask: bits set = pressed.
 * Port 1 (player 2) is a stub in this adapter; Phase F wires SGDK JOY. */
unsigned char joy_state(unsigned char port);

/* Full 16-bit SGDK joy state for port 0 (player 1). Wraps
 * JOY_readJoypad(JOY_1). Bit layout matches sgdk/inc/joy.h BUTTON_*:
 *   bit  0  BUTTON_UP
 *   bit  1  BUTTON_DOWN
 *   bit  2  BUTTON_LEFT
 *   bit  3  BUTTON_RIGHT
 *   bit  4  BUTTON_A
 *   bit  5  BUTTON_B
 *   bit  6  BUTTON_C
 *   bit  7  BUTTON_START
 *   bit  8  BUTTON_Z   (6-button only)
 *   bit  9  BUTTON_Y   (6-button only)
 *   bit 10  BUTTON_X   (6-button only)
 *   bit 11  BUTTON_MODE (6-button only)
 * Use when 6-button bits (X/Y/Z/MODE) are needed — joy_read()
 * 3-button protocol returns only the lower 8 bits. */
unsigned short joy_read_full(void);

#endif /* JOY_ABI_H */
