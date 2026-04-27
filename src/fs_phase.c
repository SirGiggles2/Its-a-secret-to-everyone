/* src/fs_phase.c — phase dispatcher + RAM probe writes.
 *
 * RAM probe at $00FF07F0/F1 readable from BizHawk Lua via "68K RAM" domain
 * at offsets $07F0/$07F1 (the 68K RAM window starts at Genesis $FF0000).
 */
#include "fs_phase.h"
#include "fs_render.h"
#include <stdint.h>

uint8_t s_fs_phase;
uint8_t s_fs_cursor;

#define M68K_RAM ((volatile uint8_t *)0x00FF0000)

void fs_phase_init(void) {
    s_fs_phase = FS_LOAD;
    s_fs_cursor = 0;
}

void fs_phase_step(void) {
    M68K_RAM[0x07F0] = s_fs_phase;
    M68K_RAM[0x07F1] = s_fs_cursor;
    switch (s_fs_phase) {
        case FS_LOAD:
            fs_render_clear_screen();
            fs_render_static_layout();
            fs_render_all_slots();
            fs_render_cursor(s_fs_cursor);
            s_fs_phase = FS_NAV;
            break;
        case FS_NAV:
            /* Idle — input dispatch in fs_main moves cursor + transitions phase. */
            break;
        default:
            break;  /* FS_COPY_*, FS_ERASE_*, FS_OPTIONS, FS_HANDOFF land in v3+ */
    }
}
