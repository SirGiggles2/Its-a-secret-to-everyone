#include <genesis.h>
#ifdef RAM
#undef RAM
#endif
#include "platform_abi.h"
#include "intro_phase.h"
#include "render_abi.h"
#include "roomrom_debug_runtime.h"

#define A4_EXPECTED 0x00FF8000UL
#define PROBE_BASE ((volatile u8 *) 0x00FF7000UL)
#define ABS_RAM ((volatile u8 *) 0x00FF8000UL)
#define VDP_CTRL_WORD (*(volatile u16 *) 0x00C00004UL)
#define PASS_FRAME_LIMIT 180U
#define CHORD_DEBUG (BUTTON_A | BUTTON_B | BUTTON_C)

typedef enum {
    COMBINED_STATE_TITLE = 0,
    COMBINED_STATE_ROOMROM = 1
} combined_state_t;

extern u32 combined_debug_get_a4(void);

static combined_state_t s_state;
static u16 s_frame;
static u16 s_fail_stage;
static u16 s_prev_joy;
static u32 s_last_a4;

static void probe_write_u16(u16 offset, u16 value)
{
    PROBE_BASE[offset + 0U] = (u8) (value >> 8);
    PROBE_BASE[offset + 1U] = (u8) value;
}

static void probe_write_u32(u16 offset, u32 value)
{
    PROBE_BASE[offset + 0U] = (u8) (value >> 24);
    PROBE_BASE[offset + 1U] = (u8) (value >> 16);
    PROBE_BASE[offset + 2U] = (u8) (value >> 8);
    PROBE_BASE[offset + 3U] = (u8) value;
}

static void probe_publish(void)
{
    PROBE_BASE[0] = 0xA4U;
    PROBE_BASE[1] = 0x4AU;
    probe_write_u16(2U, s_frame);
    probe_write_u16(4U, s_fail_stage);
    probe_write_u32(6U, s_last_a4);
    PROBE_BASE[10] = ABS_RAM[0x0012U];
    PROBE_BASE[11] = ABS_RAM[0x0013U];
    PROBE_BASE[12] = s_fail_stage ? 0xEEU : ((s_frame >= PASS_FRAME_LIMIT) ? 1U : 0U);
    PROBE_BASE[13] = (u8) s_state;
    PROBE_BASE[14] = roomrom_debug_get_scene();
    PROBE_BASE[15] = roomrom_debug_get_room_id();
    probe_write_u16(16U, (u16)roomrom_debug_get_link_x());
    probe_write_u16(18U, (u16)roomrom_debug_get_link_y());
}

static void probe_fail(u16 stage)
{
    if (!s_fail_stage)
    {
        s_fail_stage = stage;
    }
}

static void probe_check(u16 stage)
{
    s_last_a4 = combined_debug_get_a4();
    if (s_last_a4 != A4_EXPECTED)
    {
        probe_fail(stage);
        probe_publish();
        return;
    }

    RAM(0x0012) = 0xCDU;
    RAM(0x0013) = (u8) stage;
    if ((ABS_RAM[0x0012U] != 0xCDU) || (ABS_RAM[0x0013U] != (u8) stage))
    {
        probe_fail((u16) (stage | 0x8000U));
    }

    probe_publish();
}

static void combined_debug_enter_title(void)
{
    s_state = COMBINED_STATE_TITLE;
    s_prev_joy = 0u;

    /* Match the native title boot layout from genesis_shell.asm. */
    VDP_CTRL_WORD = 0x8134u; /* display off, VBlank IRQ, DMA, M5 */
    VDP_CTRL_WORD = 0x8230u; /* Plane A @ $C000 */
    VDP_CTRL_WORD = 0x832Cu; /* Window @ $B000 */
    VDP_CTRL_WORD = 0x8407u; /* Plane B @ $E000 */
    VDP_CTRL_WORD = 0x857Cu; /* SAT @ $F800 */
    VDP_CTRL_WORD = 0x8B00u; /* full-screen scroll */
    VDP_CTRL_WORD = 0x8C00u; /* H32, no interlace, no shadow/highlight */
    VDP_CTRL_WORD = 0x8D3Fu; /* H-scroll @ $FC00 */
    VDP_CTRL_WORD = 0x8F02u; /* word auto-increment */
    render_mode_set_v32();
    render_window_v_set(0u);

    RAM(0x07FF) = 0xA1u;
    RAM(0x07F1) = 0u;
    RAM(0x07F2) = 0u;
    intro_phase_init();
    intro_phase_step();
}

static void combined_debug_poll_title(void)
{
    u16 joy;
    u16 was_chord;
    u16 is_chord;

    probe_check(2U);
    SYS_doVBlankProcess();
    ++s_frame;
    probe_check(3U);
    RAM(0x07F1) = (u8) s_frame;
    intro_phase_step();

    joy = JOY_readJoypad(JOY_1);
    was_chord = (u16)(s_prev_joy & CHORD_DEBUG);
    is_chord = (u16)(joy & CHORD_DEBUG);
    s_prev_joy = joy;

    if (is_chord == CHORD_DEBUG && was_chord != CHORD_DEBUG)
    {
        s_state = COMBINED_STATE_ROOMROM;
        probe_publish();
        roomrom_debug_enter();
    }
}

int combined_debug_main_after_a4(bool hardReset)
{
    (void) hardReset;

    probe_check(1U);
    combined_debug_enter_title();

    while (TRUE)
    {
        if (s_state == COMBINED_STATE_TITLE)
        {
            combined_debug_poll_title();
        }
        else
        {
            roomrom_debug_tick();
            ++s_frame;
            probe_check(4U);
        }
    }

    return 0;
}
