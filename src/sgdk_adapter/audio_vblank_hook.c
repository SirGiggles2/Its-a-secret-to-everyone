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

/* Phase 10.3 audio link: SFX stub.
 *
 * audio_driver.asm@dmc_trigger calls audio_sfx_play (real impl in
 * src/sgdk_adapter/audio_adapter.c pulls XGM Z80 machinery +
 * extracted sfx_pcm.c PCM data; XGM not yet linked into Debug.md).
 * Stub no-op so the link resolves. DMC_SAMPLE_COUNT moved into
 * audio_driver.asm as an `equ` constant (gas MRI truncates xref
 * symbols to 8-bit relocation, which fails when the symbol lives
 * in .bss; an `equ` becomes an absolute constant baked into the
 * cmp.b immediate, which is what the driver expects).
 */
void audio_sfx_play(unsigned char sfx)
{
    (void)sfx;
    /* no-op until XGM SFX slice lands */
}
