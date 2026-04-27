/* src/intro_phase.c
 *
 * Phase dispatcher. Task 3 ships this as a placeholder: each phase
 * just writes its enum value to nes_ram[$07F0] and counts down 60
 * frames before advancing. Tasks 4-5 replace placeholder bodies with
 * lifts from intro_demo.
 */
#include "intro_phase.h"
#include "nes_abi.h"

static intro_phase_t s_phase;
static unsigned short s_counter;

static void goto_phase(intro_phase_t next) {
    s_phase = next;
    s_counter = 0;
    nes_ram[0x07F0] = (unsigned char)next;
}

void intro_phase_init(void) {
    s_phase = PHASE_TITLE_LOAD;
    s_counter = 0;
    nes_ram[0x07F0] = (unsigned char)PHASE_TITLE_LOAD;
}

void intro_phase_step(void) {
    s_counter++;
    if (s_counter < 60u) return;

    switch (s_phase) {
        case PHASE_TITLE_LOAD:    goto_phase(PHASE_TITLE_DISPLAY); break;
        case PHASE_TITLE_DISPLAY: goto_phase(PHASE_TITLE_FADEOUT); break;
        case PHASE_TITLE_FADEOUT: goto_phase(PHASE_BLACK_HOLD);    break;
        case PHASE_BLACK_HOLD:    goto_phase(PHASE_STORY_LOAD);    break;
        case PHASE_STORY_LOAD:    goto_phase(PHASE_STORY_RUN);     break;
        case PHASE_STORY_RUN:     goto_phase(PHASE_TITLE_LOAD);    break;
        default:                  __builtin_unreachable();
    }
}
