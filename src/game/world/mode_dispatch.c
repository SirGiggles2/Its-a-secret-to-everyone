/* Phase 9.7 — Gameplay-mode dispatcher.
 *
 * NES source: reference/aldonunez/Z_07.asm:1608 UpdateMode + 1613
 * UpdateMode_JumpTable (20 modes, $00 Demo .. $13 WinGame).
 *
 * Per master plan Phase 9.7, the dispatcher fires UpdateModeN_Full
 * based on GameMode ($FF0012). Each handler updates its sub-state
 * machine then returns. Phase 9.7 scaffold lands the dispatcher with
 * Mode 8 ContinueQuestion wired to its native body (commit 46cf0581);
 * other modes stay as stubs until their bodies port.
 *
 * Stance: PARTIAL — Mode 8 ADOPT (calls mode8_continue_question_update);
 * Modes 0/1/2/3/4/5/6/7/9/A/B/C/D/E/F/10/11/12/13 stubbed.
 */

#include "mode_dispatch.h"
#include "mode_continue_question.h"
#include "mode_death.h"
#include "mode_endlevel.h"
#include "platform_abi.h"

/* NES Variables.inc GameMode := $12. */
#define MODE_DISPATCH_GAME_MODE RAM(0x0012u)

/* Forward decls for not-yet-drained mode bodies. Each stub returns
 * without state change so caller's loop continues. Bodies port per
 * Phase 9.7 follow-up. */
static void mode_stub(void)
{
    /* no-op — body deferred. */
}

/* Mode 8 ContinueQuestion — Phase 9.7 native body (commit 46cf0581). */
extern void mode8_continue_question_update(void);

/* Entry: dispatch on GameMode value. Mirrors NES JSR TableJump at
 * Z_07.asm:1611. */
void mode_dispatch_update(void)
{
    unsigned char mode = MODE_DISPATCH_GAME_MODE;

    switch (mode) {
    case 0x00: mode_stub(); break;  /* Mode 0 Demo */
    case 0x01: mode_stub(); break;  /* Mode 1 Menu (FileSelect) */
    case 0x02: mode_stub(); break;  /* Mode 2 Load */
    case 0x03: mode_stub(); break;  /* Mode 3 Unfurl */
    case 0x04: mode_stub(); break;  /* Mode 4 Enter (between rooms) */
    case 0x05: mode_stub(); break;  /* Mode 5 Play */
    case 0x06: mode_stub(); break;  /* Mode 6 Leave (between rooms) */
    case 0x07: mode_stub(); break;  /* Mode 7 Scroll */
    case 0x08: mode8_continue_question_update(); break;  /* RESOLVED Phase 9.7 */
    case 0x09: mode_stub(); break;  /* Mode 9 Play variant */
    case 0x0A: mode_stub(); break;  /* Mode A Play variant */
    case 0x0B: mode_stub(); break;  /* Mode B Play variant */
    case 0x0C: mode_stub(); break;  /* Mode C Play variant */
    case 0x0D: mode_stub(); break;  /* Mode D Save */
    case 0x0E: mode_stub(); break;  /* Mode E Register */
    case 0x0F: mode_stub(); break;  /* Mode F Elimination */
    case 0x10: mode_stub(); break;  /* Mode 10 Stairs */
    case 0x11: mode11_death_update(); break;  /* Phase 9.7 native (commit pending) */
    case 0x12: mode12_endlevel_update(); break;  /* Phase 9.7 native */
    case 0x13: mode_stub(); break;  /* Mode 13 WinGame */
    default:   mode_stub(); break;
    }
}
