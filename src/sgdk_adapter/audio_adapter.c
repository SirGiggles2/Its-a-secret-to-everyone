/*
 * audio_adapter.c — bridge between owned game code and SGDK XGM audio.
 *
 * Music path forwards to the legacy music_play / music_tick in
 * src/audio_driver.asm (FM driver). SFX path is now wired to the SGDK
 * XGM (Doppler) Z80 driver: 4 PCM channels mixed at 14 kHz, with the 7
 * NES DMC samples ripped from the stock ROM registered as XGM SFX
 * sample IDs 64..70 (XGM reserves 1..63 for music).
 */

#include "audio_adapter.h"
#include "sfx_pcm.h"
#include "platform_abi.h"   /* nes_ram (A4-pinned) for probe sentinels */
#include <z80_ctrl.h>
#include <snd/sound.h>
#include <snd/xgm.h>

extern void music_play(unsigned char song_bitmap);
extern void music_tick(void);

static u8 xgm_initialized = 0;
static u8 sfx_next_channel = 0;  /* round-robin index 0..2 → CH2..CH4 */

void audio_xgm_init(void)
{
    if (xgm_initialized) return;
    xgm_initialized = 1;

    Z80_loadDriver(Z80_DRIVER_XGM, 1);

    for (u8 i = 0; i < SFX_PCM_COUNT; i++) {
        XGM_setPCM(sfx_pcm_table[i].id,
                   sfx_pcm_table[i].data,
                   sfx_pcm_table[i].len);
    }
}

void audio_music_play(unsigned char song)
{
    music_play(song);
}

void audio_sfx_play(unsigned char sfx)
{
    if (!xgm_initialized) audio_xgm_init();
    if (sfx == 0 || sfx > SFX_PCM_COUNT) return;

    SoundPCMChannel chan = (SoundPCMChannel)(SOUND_PCM_CH2 + sfx_next_channel);
    sfx_next_channel = (sfx_next_channel + 1) % 3;

    XGM_startPlayPCM(SFX_PCM_ID_BASE + (sfx - 1), 1, chan);

    /* Probe sentinel — count XGM SFX dispatches at NES RAM $07F0 (last
     * sfx id) and $07F1 (call counter). Lets bizhawkScript probes verify
     * the audio_sfx_play path fires without going through dmc_trigger
     * (which only writes dmc_last_idx for NES APU $4015 writes). */
    nes_ram[0x07F0u] = sfx;
    nes_ram[0x07F1u] = (unsigned char)(nes_ram[0x07F1u] + 1u);
}

void audio_tick_vblank(void)
{
    music_tick();
}
