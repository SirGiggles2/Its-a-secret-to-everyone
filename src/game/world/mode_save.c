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
 * DIVERGENCE (recorded, T-097): Sub2 returns to Play here, not to GameMode
 * 0 submode 1 as on the NES; the continue/save flow is rebuilt in T-097.
 */

#include "mode_save.h"
#include "save_game.h"
#include "platform_abi.h"

/* NES Variables.inc. */
#define MODE_SAVE_GAME_MODE    RAM(0x0012u)
#define MODE_SAVE_GAME_SUBMODE RAM(0x0013u)
#define MODE_SAVE_CUR_SLOT     RAM(0x0016u)

/* GameMode $05 = Play. Where a completed save returns to. */
#define MODE_PLAY 0x05u

/* Last save result, readable by probes and by any UI that wants to report
 * failure. 0 = no attempt yet, 1 = committed, 2 = refused (bad slot). */
unsigned char g_mode_save_last_result = 0u;

void mode13_save_update(void)
{
    unsigned char slot = MODE_SAVE_CUR_SLOT;

    (void)slot;
    if (save_game_save_current()) {
        g_mode_save_last_result = 1u;
    } else {
        /* Bad slot index. Do not silently pretend the game was saved:
         * leave the marker so a probe or UI can tell the difference
         * between "saved" and "refused". */
        g_mode_save_last_result = 2u;
    }

    MODE_SAVE_GAME_SUBMODE = 0u;
    MODE_SAVE_GAME_MODE = MODE_PLAY;
}
