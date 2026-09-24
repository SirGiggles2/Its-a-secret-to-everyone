/* mode_save.c — GameMode $0D (Save), native body.
 *
 * NES source: reference/aldonunez/Z_02.asm:2779 UpdateModeDSave, reached
 * from UpdateMode_JumpTable entry 13 (Z_07.asm:1627).
 *
 * NES structure: three submodes. Sub0 formats "file B", copies the $28
 * (40) byte Items block from the live profile into it, stores a checksum
 * and marks it uncommitted; the later submodes commit and transition.
 * That A/B dance exists because the NES writes battery RAM in place and
 * needs a half-written file to be detectable after a power loss.
 *
 * DIVERGENCE (recorded, deliberate): this port commits in one step.
 * save_game_write_slot() serializes into the mirror, checksums, and hands
 * a complete slot image to sram_save_store(), which refreshes the cart
 * mirror, overwrites only the target slot, and commits. The cart is never
 * left holding a partially written slot, so the A/B protocol has nothing
 * to protect against here. Behaviour visible to the player is identical:
 * the slot either updates or it does not.
 *
 * What IS preserved from the NES: the slot index comes from CurSaveSlot
 * ($16), and the payload is the 40-byte Items block at $657 — the same
 * base and length the NES copies (Variables.inc: Items := $657, and
 * UpdateModeDSave_Sub0 copies $28 bytes).
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

    if (save_game_write_slot(slot)) {
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
