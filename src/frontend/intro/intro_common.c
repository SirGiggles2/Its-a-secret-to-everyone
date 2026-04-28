#include "intro_common.h"

/* Legacy attract-takeover bridge symbols -- kept as no-op stubs so
 * frontend_runtime.c:296-298 links without modification. Under native
 * intro (intro_main owns boot) this path is never reached at runtime.
 * Task 8: cooperative-takeover bridge is dead; intro_handoff() replaced
 * by intro_start_pressed() in intro_handoff.c.
 */
unsigned char g_intro_takeover = 0;

unsigned char intro_should_take_over(void) {
    return 0;   /* always 0 -- native intro owns boot, legacy path never arms */
}

void intro_story_tick(void) {
    /* no-op: native intro handles story; legacy attract path is dead */
}
