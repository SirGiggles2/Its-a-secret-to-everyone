#ifndef NES_RAM_SYNC_H
#define NES_RAM_SYNC_H

/* Plan v5a Tier-1 bridge — sync C-side state into NES RAM mirror cells
 * so future NES native consumers (FluteTimer, Link_HandleInput, AI
 * chase-target, HUD readers) see live values without per-call adapters.
 *
 * Each entry-point is called once per roomrom_debug_tick() frame from
 * RoomRom/src/main.c. All three are byte-wide writes into nes_ram[];
 * cost is negligible (<10 cycles each).
 *
 *   T1.1  nes_ram_sync_input        — $00F8 ButtonsPressed (edge)
 *                                     $00FA ButtonsDown    (held)
 *   T1.2  nes_ram_sync_inventory_hearts
 *                                   — $066F HeartValues (hi=max, lo=cur)
 *                                     $0670 HeartPartial
 *   T1.3  nes_ram_sync_link_face    — $008C ObjDir[0]
 *
 * NES source: reference/aldonunez/Z_07.asm:660-705 ReadInputs;
 *             Variables.inc:257-258 HeartValues/HeartPartial;
 *             Variables.inc ObjDir[0]=$008C.
 *
 * Drained C : NEW (this file). EXTENDs existing per-tick sync block
 *             added to roomrom_debug_tick on 2026-05-16.
 * Coverage  : NONE for the NES-write side; FULL for the C-side reads
 *             (joypad: SGDK JOY_readJoypad; hearts: g_inventory;
 *             face: players[0].face).
 * Stance    : EXTEND.
 */

#include "types.h"

#ifdef __cplusplus
extern "C" {
#endif

/* T1.1 — translate SGDK joypad bits into NES $FA/$FB layout.
 *   held         = current frame held bits   (raw or AB-swapped)
 *   edge_pressed = bits new this frame       (same swap convention)
 *
 * NES bit layout (Z_07 ReadInputs result):
 *   $80 A   $40 B   $20 Select   $10 Start
 *   $08 Up  $04 Down $02 Left    $01 Right
 *
 * Caller passes both pre-computed because RoomRom main already derives
 * `pressed = joy & ~s_joy_prev` before this call and may AB-swap it;
 * recomputing prev->edge inside this helper would race that flow.
 *
 * Writes:
 *   nes_ram[$00F8] = ButtonsPressed (edge: bits set this frame, cleared
 *                    next)
 *   nes_ram[$00FA] = ButtonsDown    (held: 1 while button is down)
 */
void nes_ram_sync_input(u16 held, u16 edge_pressed);

/* T1.2 — mirror inventory hearts into NES HUD-readable cells. */
void nes_ram_sync_inventory_hearts(void);

/* T1.3 — refresh ObjDir[0] from the canonical C-side face. AI chase
 * targets read this cell each tick; today's seed-once-at-debug-enter
 * goes stale on any C-side face change. */
void nes_ram_sync_link_face(void);

#ifdef __cplusplus
}
#endif

#endif /* NES_RAM_SYNC_H */
