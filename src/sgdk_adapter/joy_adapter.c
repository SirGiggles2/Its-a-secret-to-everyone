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

/* Full 16-bit SGDK read for port 0 — needed for 6-button MODE/X/Y/Z bits.
 * Returns SGDK BUTTON_* bitmask (BUTTON_MODE = 0x0800).
 *
 * Root cause from systematic debugging 2026-05-19: SGDK's JOY_readJoypad
 * returns the internal joyState[] array which is normally refreshed by
 * JOY_update() called from SGDK's VBlank handler. The native intro_main
 * frontend uses its own wait_vblank() (spin on $00FF0FF8) and bypasses
 * SGDK's VBlank chain, so joyState[] is never refreshed and reads return
 * 0 (or stale data). Gameplay context runs SGDK VBlank so MODE works
 * there but title context does not.
 *
 * Fix: call JOY_update() inline before JOY_readJoypad to force a fresh
 * poll. JOY_init() runs once lazily for peripheral detection. */
extern unsigned short JOY_readJoypad(unsigned short joy);
extern void JOY_init(void);
extern void JOY_update(void);
#define JOY_1 0x0000u

unsigned short joy_read_full(void)
{
    static unsigned char inited = 0u;
    if (!inited) {
        JOY_init();
        inited = 1u;
    }
    JOY_update();
    return JOY_readJoypad(JOY_1);
}
