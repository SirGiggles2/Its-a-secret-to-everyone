/*
 * Render adapter implementation (S1 Phase D, Task D1).
 *
 * Forwards to existing vdp_ helpers in src/frontend/intro/intro_common.c.
 * Phase F migrates each forwarder to SGDK's VDP_, DMA_, PAL_ API. The
 * adapter exists now so frontend code can be retargeted call-site by
 * call-site without editing call signatures again at S11+.
 *
 * Compile-only at S1 Phase D: no live caller exists until F-phase
 * frontend cutover wires render_set_plane_a_word etc. into intro/fs
 * code. The .o is produced and dropped (not in LD_RESP) - adding
 * unreferenced functions to the ROM would shift bytes for no behavior.
 */

#include "render_adapter.h"

/* Forward declarations of existing helpers we wrap. Definitions live
 * in src/frontend/intro/intro_common.c. Re-declared here to avoid
 * pulling intro_common.h (which includes intro-specific decls we
 * don't need at the adapter layer). */

extern void vdp_dma_to_vram(unsigned long src, unsigned short dst,
                            unsigned short len);
extern void vdp_load_cram(const unsigned short *src, unsigned short count);

/* VDP plane A nametable base for the current H32 video mode. Locked
 * at $C000 in our genesis_shell.asm boot path. The nametable entry
 * write address is computed as plane_base + (row * 64 + col) * 2. */
#define PLANE_A_BASE 0xC000u

/* CRAM color words per palette. */
#define CRAM_COLORS_PER_PAL 16u

/* ---- Public API ---- */

void render_set_plane_a_word(unsigned short col, unsigned short row,
                             unsigned short word)
{
    /* Compute VRAM nametable byte address, then DMA 1 word.
     * For sparse single-word writes a direct VDP_CTRL/VDP_DATA poke is
     * cheaper, but we have no helper for that today; F-phase replaces
     * with SGDK VDP_setTileMapXY. For now, DMA path keeps wiring valid
     * if a caller appears (no caller exists at S1 D-phase). */
    unsigned short vram_addr =
        (unsigned short)(PLANE_A_BASE + (row * 64u + col) * 2u);
    unsigned short tmp = word;
    vdp_dma_to_vram((unsigned long)&tmp, vram_addr, 1);
}

void render_load_palette(unsigned short idx, const unsigned short *src)
{
    /* CRAM is byte-indexed but vdp_load_cram writes contiguously
     * starting at the CRAM cursor set by the caller - until we own a
     * cursor-set helper, this forwarder loads from idx*16 worth into
     * the cursor. F-phase replaces with SGDK PAL_setPalette which
     * takes the slot index directly. */
    (void)idx;
    vdp_load_cram(src, CRAM_COLORS_PER_PAL);
}

void render_chr_upload(unsigned short vram_addr,
                       const unsigned char *src,
                       unsigned short byte_count)
{
    /* DMA word count = byte_count / 2 (vdp_dma_to_vram expects word len). */
    vdp_dma_to_vram((unsigned long)src, vram_addr,
                    (unsigned short)(byte_count >> 1));
}
