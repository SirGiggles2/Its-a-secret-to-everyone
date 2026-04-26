/* tools/intro_demo/intro_phase.c
 *
 * Phase machine. Title phases implemented here; story phases will
 * delegate to story_runtime_step() (Task 15).
 */
#include "intro_phase.h"
#include "intro_title.h"
#include "story_runtime.h"

static intro_phase_t s_phase = PHASE_TITLE_LOAD;
static unsigned short s_phase_counter = 0;

void intro_phase_init(void) {
    s_phase = PHASE_TITLE_LOAD;
    s_phase_counter = 0;
}

static void goto_phase(intro_phase_t next) {
    s_phase = next;
    s_phase_counter = 0;
}

void intro_phase_step(void) {
    switch (s_phase) {
        case PHASE_TITLE_LOAD:
            intro_title_setup();
            goto_phase(PHASE_TITLE_DISPLAY);
            break;

        case PHASE_TITLE_DISPLAY:
            intro_title_step();
            s_phase_counter++;
            if (s_phase_counter >= TITLE_DISPLAY_FRAMES) {
                /* Begin fade-out: paint cycle 0 immediately, then count
                 * down its delay before advancing to cycle 1. */
                intro_title_fade_reset();
                intro_title_fade_apply(0);
                goto_phase(PHASE_TITLE_FADEOUT);
            }
            break;

        case PHASE_TITLE_FADEOUT:
            /* Continue glow + waterfall anim during fade so the title
             * keeps moving as the palette fades to black. */
            intro_title_step();
            intro_title_fade_step();
            if (intro_title_fade_done()) {
                intro_title_blackout();
                goto_phase(PHASE_BLACK_HOLD);
            }
            break;

        case PHASE_BLACK_HOLD:
            s_phase_counter++;
            if (s_phase_counter >= BLACK_HOLD_FRAMES) {
                goto_phase(PHASE_STORY_LOAD);
            }
            break;

        case PHASE_STORY_LOAD:
            story_runtime_load();
            goto_phase(PHASE_STORY_RUN);
            break;

        case PHASE_STORY_RUN:
            story_runtime_step();
            if (story_runtime_at_end()) {
                story_runtime_clear_end();
                goto_phase(PHASE_TITLE_LOAD);
            }
            break;
    }
}
