/* mode_save.c — GameMode $0D (Save), native body.
 *
 * NES source: reference/aldonunez/Z_02.asm:2779 UpdateModeDSave, reached
 * from UpdateMode_JumpTable entry 13 (Z_07.asm:1627).
 *
 * NES structure: Sub0 formats file B and copies the profile into it
 * (items, deaths, active, quest, name, world flags; hearts refilled on the
 * profile), Sub1 validates B and copies it to file A, Sub2 goes to
 * GameMode 0 submode 1.
 *
 * T-100: save_game_save_current() runs Sub0 + CopyFileBToFileA collapsed
 * onto file A (save_serializer.c) and commits the whole NES save block to
 * cart SRAM. File A bytes and profile side effects match the NES; the
 * A/B power-loss protocol is replaced by one atomic commit.
 *
 * T-149: Sub2 goes to GameMode 0 submode 1 as on the NES; the Genesis
 * main loop then returns to its File Select.
 */

#include "mode_save.h"
#include "save_game.h"
#include "platform_abi.h"

/* NES Variables.inc. */
#define MODE_SAVE_GAME_MODE    RAM(0x0012u)
#define MODE_SAVE_GAME_SUBMODE RAM(0x0013u)
#define MODE_SAVE_CUR_SLOT     RAM(0x0016u)

/* Last save result, readable by probes and by any UI that wants to report
 * failure. 0 = no attempt yet, 1 = committed, 2 = refused (bad slot). */
unsigned char g_mode_save_last_result = 0u;

/* T-149: NES timing (save_roundtrip NES frames f130-f136, FrameCounter
 * $AE-$B1): Sub0 (format file B + copy the profile) finishes on the
 * first tick in mode $0D; Sub1 (validate B, CopyFileBToFileA) lags and
 * finishes, with Sub2 (-> GameMode 0 submode 1), two ticks after Sub0.
 * Rows after each tick: $0D/0, $0D/1, $00/1. */
static unsigned char s_sub0_fc;

void mode13_save_update(void)
{
    const unsigned char fc = RAM(0x0015u);
    if (MODE_SAVE_GAME_SUBMODE == 0u) {
        /* Sub0 + CopyFileBToFileA collapsed onto file A (T-100). */
        g_mode_save_last_result = save_game_save_current() ? 1u : 2u;
        MODE_SAVE_GAME_SUBMODE = 1u;
        s_sub0_fc = fc;
        return;
    }
    if ((unsigned char)(fc - s_sub0_fc) < 2u) return;
    /* UpdateModeDSave_Sub2: GameMode 0 submode 1 (the title's save
     * validation, then the menu); the Genesis front end takes over there
     * (a4_probe_main.c). */
    MODE_SAVE_GAME_MODE = 0u;
    MODE_SAVE_GAME_SUBMODE = 1u;
}
