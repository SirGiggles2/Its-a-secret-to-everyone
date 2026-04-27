#include "intro_common.h"
#include "intro_handoff.h"
#include "nes_abi.h"  /* RAM(addr) macro */

#define VDP_CTRL_WORD (*(volatile unsigned short *)0x00C00004)
#define VDP_DATA_WORD (*(volatile unsigned short *)0x00C00000)
#define VDP_CTRL_LONG (*(volatile unsigned long  *)0x00C00004)

unsigned char g_intro_takeover = 0;
unsigned char g_intro_saved_ppuctrl = 0;  /* set by intro_should_take_over, restored by intro_handoff */

static unsigned char s_takeover_armed = 0;
static unsigned char s_substage = 0;   /* 0 = handoff */

unsigned char intro_should_take_over(void) {
    if (s_takeover_armed) return g_intro_takeover;
    if (RAM(0x042C) == 0) return 0;   /* still phase-0 (title) — wait for attract to arm */
    g_intro_takeover = 1;
    s_takeover_armed = 1;
    s_substage = 0;
    /* Per codex .481 plan: do NOT touch PPUCTRL / NMI. Keep IsrNmi alive
     * so heartbeat and legacy transfer pipeline continue. */
    return 1;
}

void intro_story_tick(void) {
    if (!g_intro_takeover) return;
    nes_ram[0x07F3] = s_substage;

    /* Native intro (intro_main/intro_phase) handles story+items.
     * Legacy path (frontend_runtime) just calls handoff when done. */
    intro_handoff();
    /* Re-arm so next attract cycle takes over again. intro_handoff
     * already cleared g_intro_takeover; also clear the armed latch. */
    s_takeover_armed = 0;
    s_substage = 0;
}

/* VDP primitives — real bodies follow. Stubs so early linker checks pass. */
void vdp_set_mode_v32(void) {
    /* VDP Reg 16 = $9000 (H32 x V32). 32x32 plane = 2 KB at $C000-$C7FF.
     * Row stride = 32 cells * 2 = 64 bytes — matches vdp_write_nametable_row. */
    VDP_CTRL_WORD = 0x9000;
}

void vdp_set_mode_v64(void) {
    /* VDP Reg 16 = $9011 (H64 x V64). Matches gameplay default. */
    VDP_CTRL_WORD = 0x9011;
}
void vdp_dma_to_vram(unsigned long src, unsigned short dst, unsigned short len) {
    /* CPU-based VRAM upload (DMA path commented out — GPGX hang risk).
     * Writes `len` bytes from `src` to VRAM[dst..dst+len] via word writes.
     * Slower than DMA (~0.5ms for 4 KB) but reliable in display-off. */
    const unsigned short *p = (const unsigned short *)src;
    unsigned short words = (unsigned short)(len >> 1);

    /* Ensure auto-increment = 2 (word stride). */
    VDP_CTRL_WORD = 0x8F02;

    /* Open VRAM write at dst. */
    unsigned long cmd = 0x40000000UL | ((unsigned long)(dst & 0x3FFF) << 16)
                                     | ((dst >> 14) & 0x0003);
    VDP_CTRL_LONG = cmd;

    /* Stream words. */
    for (unsigned short i = 0; i < words; i++) {
        VDP_DATA_WORD = p[i];
    }
}
void vdp_write_nametable_row(unsigned short plane_base, unsigned short row,
                             const unsigned short *cells) {
    /* plane_base = plane A base ($4000) or plane B base ($6000).
     * row = 0..31 (V32 plane). Writes 32 cells (64 bytes). */
    unsigned short addr = (unsigned short)(plane_base + (row * 64));
    unsigned long cmd = 0x40000000UL | ((unsigned long)(addr & 0x3FFF) << 16)
                                     | ((addr >> 14) & 0x0003);
    VDP_CTRL_LONG = cmd;
    for (int i = 0; i < 32; i++) {
        VDP_DATA_WORD = cells[i];
    }
}
void vdp_set_vscroll(unsigned short value) {
    /* VSRAM write to address $00 (plane A vscroll). */
    VDP_CTRL_LONG = 0x40000010UL;
    VDP_DATA_WORD = value;
}
void vdp_load_cram(const unsigned short *src, unsigned short count) {
    /* CRAM write starting at CRAM address 0. count = words (max 64). */
    VDP_CTRL_LONG = 0xC0000000UL;
    for (unsigned short i = 0; i < count; i++) {
        VDP_DATA_WORD = src[i];
    }
}

#define Z80_BUSREQ_WORD (*(volatile unsigned short *)0x00A11100)
#define Z80_RESET_WORD  (*(volatile unsigned short *)0x00A11200)

void vdp_display_off(void) {
    /* Reg 1 = $8134: display OFF, VBlank IRQ, DMA, M5 (matches genesis_shell). */
    VDP_CTRL_WORD = 0x8134;
}

void vdp_display_on(void) {
    /* Reg 1 = $8174: DISP=1, VBlank IRQ, DMA, M5. */
    VDP_CTRL_WORD = 0x8174;
}

void vdp_z80_stop(void) {
    /* Hold Z80 bus so 68K DMA has uncontended access to VRAM. */
    Z80_BUSREQ_WORD = 0x0100;
    while ((Z80_BUSREQ_WORD & 0x0100) != 0) { /* wait BUSACK */ }
}

void vdp_z80_release(void) {
    Z80_BUSREQ_WORD = 0x0000;
}

void vdp_irq_mask(void) {
    __asm__ volatile ("ori.w #0x0700,%sr");
}

void vdp_irq_unmask(void) {
    __asm__ volatile ("andi.w #0xF8FF,%sr");
}
