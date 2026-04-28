#ifndef INTRO_COMMON_H
#define INTRO_COMMON_H
#ifdef __cplusplus
extern "C" {
#endif

/* Legacy attract-takeover bridge. Bodies in intro_common.c.
 * All vdp_* IO primitives have been moved to render_adapter.c
 * and renamed to render_* (S1.F4). */
extern unsigned char g_intro_takeover;
unsigned char intro_should_take_over(void);
void intro_story_tick(void);

#ifdef __cplusplus
}
#endif
#endif
