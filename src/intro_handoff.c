#include "intro_handoff.h"
#include "intro_common.h"
#include "nes_abi.h"

extern const unsigned char  intro_restore_chr[];
extern const unsigned long  intro_restore_chr_size;
extern const unsigned short intro_restore_palette[64];

static void clear_plane(unsigned short plane_base);

void intro_handoff(void) {
    /* 1. Switch back to V64. */
    vdp_set_mode_v64();

    /* 2. Restore file-select CHR captured from legacy flow. */
    vdp_dma_to_vram((unsigned long)intro_restore_chr, 0x0000,
                    (unsigned short)intro_restore_chr_size);

    /* 3. Restore file-select CRAM. */
    vdp_load_cram(intro_restore_palette, 64);

    /* 4. Reset VSRAM to 0. */
    vdp_set_vscroll(0);

    /* 5. Clear plane A + plane B nametables. */
    clear_plane(0x4000);
    clear_plane(0x6000);

    /* 6. Write authoritative state bytes captured by probe during Task 1. */
    RAM(0x00E0) = INTRO_HANDOFF_EXPECTED.mode_value;
    RAM(0x0012) = INTRO_HANDOFF_EXPECTED.submode_value;
    RAM(0x042C) = INTRO_HANDOFF_EXPECTED.frontend_demo_subphase;
    RAM(0x042B) = INTRO_HANDOFF_EXPECTED.front_start_release_gate;
    RAM(0x083D) = INTRO_HANDOFF_EXPECTED.vram_force_blank_gate;
    RAM(0x0528) = INTRO_HANDOFF_EXPECTED.frontend_delay_timer;
    RAM(0x0013) = INTRO_HANDOFF_EXPECTED.room_mode_timer;
    RAM(0x0605) = INTRO_HANDOFF_EXPECTED.item_sfx_secondary;
    RAM(0x060E) = INTRO_HANDOFF_EXPECTED.room_transfer_buf_select;

    /* 7. Clear takeover. */
    g_intro_takeover = 0;
}

static void clear_plane(unsigned short plane_base) {
    unsigned short zero_row[32] = {0};
    for (unsigned short r = 0; r < 32; r++) {
        vdp_write_nametable_row(plane_base, r, zero_row);
    }
}
