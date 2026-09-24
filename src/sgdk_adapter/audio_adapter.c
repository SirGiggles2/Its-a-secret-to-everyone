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
#include "../../data/audio/sfx_pcm_stairs.h"  /* NES cave stairs SFX (#8 / XGM id 71), synth */
#include "platform_abi.h"   /* nes_ram (A4-pinned) for probe sentinels */
#include "../../data/audio_music/ow_theme_xgm.h"
#include "../../data/audio_music/uw_theme_xgm.h"
#include <z80_ctrl.h>
#include <snd/sound.h>
#include <snd/xgm.h>

extern void music_play(unsigned char song_bitmap);
extern void music_tick(void);

/* Driver storage is linker-owned; fixed low-RAM addresses collide with C BSS.
 * Native RAM base follows platform_abi (A4 Debug or pointer RoomRom). */
volatile unsigned char audio_apu_shadow[0x16];
volatile unsigned char *audio_native_ram_base = 0;

static u8 xgm_initialized = 0;
static u8 s_current_xgm_song = 0;
static u8 sfx_next_channel = 0;  /* round-robin index 0..2 → CH2..CH4 */

/* XGM-driver song ownership flag, shared with src/audio_driver.asm's
 * music_tick (label `xgm_owns_chip` at MUSIC_BASE+$2C = $FFE02C).
 * Writing this from C is sufficient — the asm gate reads the same byte.
 * When 1, the XGM Z80 driver is playing a VGM/XGM song (currently the
 * OW theme blob) and owns FM ch1-5 + PSG. The legacy 68k FM driver MUST
 * NOT tick while this is set, or its tick_sq1 writes will race the
 * Z80's chip accesses. Cleared when XGM_stopPlay hands ownership back. */
static volatile u8 * const xgm_owns_chip_ptr = (volatile u8 *)0x00FFE02CUL;
static volatile u8 * const music_song_ptr = (volatile u8 *)0x00FFE000UL;
static volatile u8 * const music_song_req_ptr = (volatile u8 *)0x00FFE001UL;

#define SONG_OW_BITMAP  0x01u
#define SONG_UW_BITMAP  0x40u

static const u8 *xgm_blob_for_song(unsigned char song)
{
    if (song == SONG_OW_BITMAP) return ow_theme_xgm;
    if (song == SONG_UW_BITMAP) return uw_theme_xgm;
    return 0;
}

void audio_xgm_init(void)
{
    audio_native_ram_base = nes_ram;
    if (xgm_initialized) return;
    xgm_initialized = 1;

    Z80_loadDriver(Z80_DRIVER_XGM, 1);

    for (u8 i = 0; i < SFX_PCM_COUNT; i++) {
        XGM_setPCM(sfx_pcm_table[i].id,
                   sfx_pcm_table[i].data,
                   sfx_pcm_table[i].len);
    }
    /* SFX #8 = NES cave stairs (XGM id 71 = SFX_PCM_ID_BASE + 7), synthesized
     * separately from the DMC bank (it is an APU-noise sound, not a sample). */
    XGM_setPCM(SFX_PCM_STAIRS_ID, sfx_pcm_stairs, SFX_PCM_STAIRS_LEN);
}

void audio_music_play(unsigned char song)
{
    const u8 *xgm_song = xgm_blob_for_song(song);

    /* OW and UW route through SGDK's XGM Z80 driver. The checked-in
     * ow_theme_xgm.c and uw_theme_xgm.c arrays are compiled XGC-style
     * blobs produced by xgmtool from the source VGMs. */
    if (xgm_song) {
        if (!xgm_initialized) audio_xgm_init();

        /* Keep legacy debug/probe song cells coherent even while the
         * legacy tick is gated off and cannot consume m_song_req itself. */
        *music_song_ptr = song;
        *music_song_req_ptr = 0;

        if (!*xgm_owns_chip_ptr || s_current_xgm_song != song) {
            if (*xgm_owns_chip_ptr) {
                XGM_stopPlay();
            }
            *xgm_owns_chip_ptr = 1;       /* gate legacy music_tick BEFORE Z80 starts */
            XGM_startPlay(xgm_song);
            s_current_xgm_song = song;
        }
        return;
    }

    /* Non-OW song: hand chip ownership back to legacy FM driver. */
    if (*xgm_owns_chip_ptr) {
        XGM_stopPlay();
        *xgm_owns_chip_ptr = 0;
        s_current_xgm_song = 0;
    }
    music_play(song);
}

void audio_sfx_play(unsigned char sfx)
{
    if (!xgm_initialized) audio_xgm_init();
    /* 1..SFX_PCM_COUNT = DMC bank; SFX_PCM_COUNT+1 (=8) = synth stairs SFX,
     * which maps to SFX_PCM_ID_BASE+(8-1)=71=SFX_PCM_STAIRS_ID below. */
    if (sfx == 0 || sfx > SFX_PCM_COUNT + 1) return;

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
    /* music_tick itself gates on xgm_owns_chip (set above). The check
     * here is redundant but cheap and makes intent explicit at the call
     * site; the asm gate is the source of truth and covers genesis_shell
     * VBlankISR's direct music_tick callers too. */
    if (*xgm_owns_chip_ptr) return;
    music_tick();
}
