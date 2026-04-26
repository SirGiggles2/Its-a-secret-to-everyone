/* tools/intro_demo/intro_phase.h
 *
 * Top-level phase state machine for intro_demo. Boot calls
 * intro_phase_init() once; the main loop calls intro_phase_step()
 * each vblank.
 */
#ifndef INTRO_PHASE_H
#define INTRO_PHASE_H

typedef enum {
    PHASE_TITLE_LOAD = 0,
    PHASE_TITLE_DISPLAY,
    PHASE_TITLE_FADEOUT,
    PHASE_BLACK_HOLD,
    PHASE_STORY_LOAD,
    PHASE_STORY_RUN,    /* covers SCROLL_IN, HOLD, SCROLL_OFF, END_PAUSE
                         * — story_runtime owns sub-state internally */
} intro_phase_t;

void intro_phase_init(void);
void intro_phase_step(void);

#endif /* INTRO_PHASE_H */
