/*
 * Joypad adapter implementation (S1 Phase D, Task D3).
 *
 * Mirrors the Genesis 3-button read sequence used in
 * src/frontend/intro/intro_main.c (read_controller_buttons) and
 * src/frontend/fs/fs_input.c (read_pad), then maps the Genesis active-low
 * button bits to the NES bitmask defined in joy_abi.h.
 *
 * Phase F migrates each call site to joy_read / joy_state and replaces
 * this implementation with SGDK JOY_readJoypad. The adapter exists now
 * so frontends can be retargeted call-site by call-site.
 *
 * Compile-only at S1 Phase D: no live caller exists until F-phase
 * frontend cutover. The .o is produced and dropped (not in LD_RESP).
 * Plan D3 step 3 (retarget frontend C call sites) deferred to Phase F.
 *
 * Hardware note:
 *   Port 1 data register at $00A10003 (CTRL1_DATA).
 *   TH=0 read (TH pulled low): bit 5 = Start (active low), bit 4 = A.
 *   TH=1 read (TH high):       bits 5..0 = C B R L D U (active low).
 *   TH output enable at $00A10009 (CTRL1_CTRL), bit 6 = TH direction.
 */

#include "joy_adapter.h"

#define CTRL1_DATA (*(volatile unsigned char *)0x00A10003u)

/* Genesis TH=0 bit masks (active-low; bit set = NOT pressed). */
#define GEN_TH0_START  0x20u   /* bit 5, TH=0 phase */
#define GEN_TH0_A      0x10u   /* bit 4, TH=0 phase */

/* Genesis TH=1 bit masks (active-low). */
#define GEN_TH1_C      0x20u   /* bit 5; used as NES A (3-btn-as-NES-A) */
#define GEN_TH1_B      0x10u   /* bit 4 */
#define GEN_TH1_RIGHT  0x08u   /* bit 3 */
#define GEN_TH1_LEFT   0x04u   /* bit 2 */
#define GEN_TH1_DOWN   0x02u   /* bit 1 */
#define GEN_TH1_UP     0x01u   /* bit 0 */

/* Read the Genesis 3-button controller on port 1.
 * Returns NES-bitmask (bit set = pressed) as defined in joy_abi.h. */
static unsigned char read_port1(void)
{
    unsigned char lo, hi;
    volatile int i;

    /* TH=0: Start and A are readable at bits 5 and 4. */
    CTRL1_DATA = 0x00;
    for (i = 0; i < 4; i++) { /* settle */ }
    lo = (unsigned char)(CTRL1_DATA & 0x3Fu);

    /* TH=1: C, B, Right, Left, Down, Up at bits 5..0. */
    CTRL1_DATA = 0x40;
    for (i = 0; i < 4; i++) { /* settle */ }
    hi = (unsigned char)(CTRL1_DATA & 0x3Fu);

    /* Restore TH=1 idle. */
    CTRL1_DATA = 0x40;

    /* Map Genesis active-low bits to NES bitmask (active-high). */
    unsigned char nes = 0;
    if (!(lo & GEN_TH0_A))     nes |= JOY_BTN_A;
    if (!(hi & GEN_TH1_C))     nes |= JOY_BTN_A;      /* C as NES A */
    if (!(hi & GEN_TH1_B))     nes |= JOY_BTN_B;
    /* SELECT has no physical Genesis equivalent; always 0. */
    if (!(lo & GEN_TH0_START)) nes |= JOY_BTN_START;
    if (!(hi & GEN_TH1_UP))    nes |= JOY_BTN_UP;
    if (!(hi & GEN_TH1_DOWN))  nes |= JOY_BTN_DOWN;
    if (!(hi & GEN_TH1_LEFT))  nes |= JOY_BTN_LEFT;
    if (!(hi & GEN_TH1_RIGHT)) nes |= JOY_BTN_RIGHT;
    return nes;
}

/* ---- Public API ---- */

unsigned char joy_read(void)
{
    return read_port1();
}

unsigned char joy_state(unsigned char port)
{
    if (port == 0u) {
        return read_port1();
    }
    /* Port 1 (player 2): stub. Phase F wires SGDK JOY_readJoypad(JOY2). */
    return 0;
}
