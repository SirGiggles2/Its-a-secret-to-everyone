/* tools/intro_demo/story_runtime.h
 *
 * Story + items runtime: scroll-in, hold, scroll-off, end pause.
 * Behavior preserved from the pre-phase-machine main.c (commit f246e71d).
 */
#ifndef STORY_RUNTIME_H
#define STORY_RUNTIME_H

void story_runtime_load(void);          /* PHASE_STORY_LOAD: full setup */
void story_runtime_step(void);          /* per vblank during STORY_RUN */
unsigned char story_runtime_at_end(void); /* 1 once full content + end pause done */
void story_runtime_clear_end(void);     /* reset end flag for next loop */

#endif /* STORY_RUNTIME_H */
