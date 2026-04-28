/*
 * Audio adapter implementation (S1 Phase D, Task D2).
 *
 * Forwards to existing music_play / music_tick in src/audio_driver.asm.
 * Phase F migrates each forwarder to SGDK audio API. The adapter exists
 * now so frontend code can be retargeted call-site by call-site without
 * editing call signatures again at S11+.
 *
 * Compile-only at S1 Phase D: no live caller exists until F-phase
 * frontend cutover wires audio_music_play etc. into intro/fs code.
 * genesis_shell.asm still calls music_tick directly; that retarget is
 * Phase F work (plan D2 step 3 deferred). The .o is produced and
 * dropped (not in LD_RESP).
 */

#include "audio_adapter.h"

/* Forward declarations of existing helpers we wrap. Definitions live
 * in src/audio_driver.asm. Declared here to avoid pulling in any
 * audio-driver-specific headers at the adapter layer. */

/* music_play: D0.b = song bitmap. GCC ABI passes first arg in D0. */
extern void music_play(unsigned char song_bitmap);

/* music_tick: call once per VBlank; no arguments. */
extern void music_tick(void);

/* ---- Public API ---- */

void audio_music_play(unsigned char song)
{
    music_play(song);
}

void audio_sfx_play(unsigned char sfx)
{
    /* No SFX dispatch in the current audio driver. Stub for ABI
     * stability; Phase F wires to SGDK XGM/PCM SFX API. */
    (void)sfx;
}

void audio_tick_vblank(void)
{
    music_tick();
}
