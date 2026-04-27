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
uint8_t s_fs_players_value;

#define M68K_RAM ((volatile uint8_t *)0x00FF0000)

void fs_phase_init(void) {
    s_fs_phase = FS_LOAD;
    s_fs_cursor = 0;
    s_fs_players_value = 1;   /* default 1 player; persistence deferred to SRAM follow-up */
}

void fs_phase_step(void) {
    /* RAM probe contract: $07F0=phase, $07F1=cursor, $07F2=players value */
    M68K_RAM[0x07F0] = s_fs_phase;
    M68K_RAM[0x07F1] = s_fs_cursor;
    M68K_RAM[0x07F2] = s_fs_players_value;
    switch (s_fs_phase) {
        case FS_LOAD:
            fs_render_clear_screen();
            fs_render_static_layout();
            fs_render_extra_rows();          /* v3: PLAYERS + OPTIONS labels */
            fs_render_players_row(s_fs_players_value);
            fs_render_all_slots();
            fs_render_cursor(s_fs_cursor);
            s_fs_phase = FS_NAV;
            break;
        case FS_NAV:
            /* Idle — input dispatch in fs_main moves cursor + cycles PLAYERS. */
            break;
        default:
            break;  /* FS_COPY_*, FS_ERASE_*, FS_OPTIONS, FS_HANDOFF land in v4+ */
    }
}
