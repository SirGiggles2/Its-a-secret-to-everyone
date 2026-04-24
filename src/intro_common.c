#include "intro_common.h"
#include "intro_story.h"
#include "intro_showcase.h"
#include "intro_handoff.h"
#include "nes_abi.h"  /* RAM(addr) macro */

#define VDP_CTRL_WORD (*(volatile unsigned short *)0x00C00004)

unsigned char g_intro_takeover = 0;

static unsigned char s_takeover_armed = 0;
static unsigned char s_substage = 0;   /* 0 = story, 1 = showcase, 2 = handoff */
static unsigned char s_entered = 0;

unsigned char intro_should_take_over(void) {
    if (s_takeover_armed) return g_intro_takeover;
    if (RAM(0x042C) == 0) return 0;
    g_intro_takeover = 1;
    s_takeover_armed = 1;
    s_substage = 0;
    s_entered = 0;
    return 1;
}

void intro_story_tick(void) {
    if (!g_intro_takeover) return;

    if (s_substage == 0) {
        if (!s_entered) { intro_story_enter(); s_entered = 1; }
        if (intro_story_update()) { s_substage = 1; s_entered = 0; }
        return;
    }
    if (s_substage == 1) {
        if (!s_entered) { intro_showcase_enter(); s_entered = 1; }
        if (intro_showcase_update()) { s_substage = 2; s_entered = 0; }
        return;
    }
    intro_handoff();
}

/* VDP primitives — real bodies follow. Stubs so early linker checks pass. */
void vdp_set_mode_v32(void) {
    /* VDP Reg 16 = $9001 (H64 x V32). See src/genesis_shell.asm:236. */
    VDP_CTRL_WORD = 0x9001;
}

void vdp_set_mode_v64(void) {
    /* VDP Reg 16 = $9011 (H64 x V64). Matches gameplay default. */
    VDP_CTRL_WORD = 0x9011;
}
void vdp_dma_to_vram(unsigned long src, unsigned short dst, unsigned short len) { (void)src; (void)dst; (void)len; }
void vdp_write_nametable_row(unsigned short plane_base, unsigned short row,
                             const unsigned short *cells) {
    (void)plane_base; (void)row; (void)cells;
}
void vdp_set_vscroll(unsigned short value) { (void)value; }
void vdp_load_cram(const unsigned short *src, unsigned short count) {
    (void)src; (void)count;
}
