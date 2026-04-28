/*
 * Audio API public surface (S1 Phase D, Task D2).
 *
 * Owned C in src/frontend/ and src/game/ calls audio_* functions
 * here instead of calling music_play / music_tick directly. The
 * implementation (src/sgdk_adapter/audio_adapter.c) initially forwards
 * to existing music_play / music_tick in src/audio_driver.asm; Phase F
 * migrates those forwarders onto SGDK audio API per call site.
 *
 * Spec ref: 2026-04-27-native-genesis-rewrite-design.md Section 4.3
 * Plan retarget (step 3/4) deferred to Phase F - D2 is compile-only.
 */

#ifndef AUDIO_ABI_H
#define AUDIO_ABI_H

/* Request a song change. song is the song bitmap passed to music_play.
 * Call from any mode; music_tick in the VBlank handler picks it up. */
void audio_music_play(unsigned char song);

/* Play a one-shot sound effect. sfx identifies the effect. Not yet
 * dispatched in the underlying driver; stub exists for ABI stability. */
void audio_sfx_play(unsigned char sfx);

/* VBlank audio tick. Call once per VBlank (replaces direct music_tick
 * call in genesis_shell.asm VBlank handler). Retarget deferred to
 * Phase F; genesis_shell.asm still calls music_tick directly in D-phase. */
void audio_tick_vblank(void);

#endif /* AUDIO_ABI_H */
