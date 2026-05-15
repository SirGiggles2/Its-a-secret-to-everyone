/* Phase 10.3 audio link, VBlank tick slice.
 *
 * Registers music_tick() (defined in src/audio_driver.asm) as SGDK's
 * VBlank interrupt callback so the audio driver advances one note
 * per frame. Without this, music_play() requests a song but no notes
 * play because tick_sq0..tick_noise never run.
 *
 * Genesis VBlank runs at ~60 Hz (NTSC) which matches the NES FrameCounter
 * tick rate the driver was designed against. audio_driver.asm@music_tick
 * pulls the requested song from m_song, fans out to tick_sq0/sq1/tri/
 * noise, and stays within the VBlank budget per its existing cycle
 * accounting.
 */

#include <genesis.h>

extern void music_tick(void);

static void audio_vblank_hook(void)
{
    music_tick();
}

/* Public entry called once from boot. Idempotent. */
void audio_vblank_hook_install(void)
{
    SYS_setVIntCallback(audio_vblank_hook);
}

/* Phase 10.3 audio link: SFX stub retired 2026-05-15 — real impl
 * provided by src/sgdk_adapter/audio_adapter.c::audio_sfx_play
 * (now linked into Debug.md alongside data/audio/sfx_pcm.c). */
