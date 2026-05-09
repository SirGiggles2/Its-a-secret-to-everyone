/* Phase 6 Task 6.11.1 / 6.11.3 — Link damage path.
 *
 * NES authority:
 *   Z_01.asm:5666 HarmLink            entry from monster collision
 *   Z_01.asm:5691 Link_BeHarmed       16-bit damage decode + ring divide
 *   Z_01.asm:5718 (HeartPartial sub)  borrow-from-full-hearts arithmetic
 *   Z_01.asm:5756 @HandleDied         death gate
 *   Z_07.asm:5756 DecrementInvincibilityTimer
 *                                     -1 every other frame (FrameCounter LSB)
 *
 * Damage encoding (NES 16-bit):
 *   high byte ($0D) = full hearts to subtract  (clipped to HeartValues low nib)
 *   low  byte ($0E) = HeartPartial fraction    (4-px granularity, $00..$FF)
 *
 * Ring tier divides 16-bit damage by 2 per ring level (1 ring = /2,
 * 2 rings = /4 — same as NES `LSR $0D / ROR $0E` loop). InvRing 0/1/2
 * = no/blue/red ring.
 *
 * Invincibility: NES post-harm value not yet evidenced; scaffold uses
 * $10 (16) ticks decremented every 2 frames per DecrementInvincibilityTimer.
 *
 * Coverage: PARTIAL — subtract math + invincibility tick land here;
 * shove physics (Z_01.asm BeginShove) deferred to Task 6.11.4.
 */

#ifndef ROOMROM_LINK_DAMAGE_H
#define ROOMROM_LINK_DAMAGE_H

void roomrom_link_damage_init(void);

/* Apply NES-encoded damage. dmg_hi = full hearts, dmg_lo = HeartPartial.
 * Reads InvRing for the tier divide. Returns 1 if Link died, 0 otherwise.
 * Sets invincibility timer on non-fatal hit. */
unsigned char roomrom_link_damage_apply(unsigned char dmg_hi,
                                        unsigned char dmg_lo);

/* NES Z_07.asm:5756 — decrement timer once every 2 frames. Caller passes
 * the global frame counter so a single bit (LSB) gates the DEC. */
void roomrom_link_damage_tick(unsigned char frame_counter);

unsigned char roomrom_link_damage_invincible(void);
unsigned char roomrom_link_damage_dead(void);

#endif
