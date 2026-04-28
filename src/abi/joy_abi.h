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

#endif /* JOY_ABI_H */
