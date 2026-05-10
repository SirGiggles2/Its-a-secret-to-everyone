/* Phase 9 Task 9.7 — save slot serialization (substrate, main worktree).
 *
 * Genesis-native save format. Snapshots Link's inventory + meta cells
 * to the NES SRAM shadow region (RAM($6000..)) so they survive across
 * mode transitions and (with the sgdk_adapter SRAM IO layer wired in
 * 9.7 follow-ups) across power cycles.
 *
 * Per-slot layout (43 bytes):
 *   [0]    magic_lo       0x5A
 *   [1]    magic_hi       0xA5
 *   [2..41] inventory[40] mirror of RAM(0x0657..0x067E) — covers
 *                         LINK_HEARTS, LINK_PARTIAL_HEART, LINK_RUPEES,
 *                         LINK_BOMB_COUNT, keys, master_key, all
 *                         INVENTORY_VALUE entries.
 *   [42]   checksum       XOR of bytes 0..41
 *
 * Slot bases at SRAM(0x00 + slot*43); slot 0 occupies $6000..$602A,
 * slot 1 $602B..$6055, slot 2 $6056..$6080. Slot 3 is reserved
 * (Phase 13 multiplayer headroom).
 *
 * Magic + checksum bracket the slot so a fresh / corrupt SRAM region
 * is rejected cleanly and the caller can fall through to "new game".
 *
 * GREENFIELD stance per drain coverage scan 2026-05-10: no candidate
 * row in tools/audit/drain_coverage.json. NES InitSaveRam clears
 * $6530..$7FFF on $5A/$A5 mismatch (reference/aldonunez/Z_05.asm:7375);
 * Genesis-native serializer keeps the SAME magic byte values so a
 * shared SRAM-init path can join the two worlds in 9.7 follow-ups.
 */

#ifndef SAVE_SERIALIZER_H
#define SAVE_SERIALIZER_H

#ifdef __cplusplus
extern "C" {
#endif

#define SAVE_SLOT_COUNT          3u
#define SAVE_SLOT_BYTE_SIZE     43u
#define SAVE_INVENTORY_BYTES    40u
#define SAVE_INVENTORY_RAM_BASE 0x0657u
#define SAVE_MAGIC_LO          0x5Au
#define SAVE_MAGIC_HI          0xA5u

/* Returns 1 on success, 0 on bad slot index. Writes magic + 40-byte
 * inventory snapshot + checksum to SRAM(slot * 43 .. slot * 43 + 42). */
unsigned char save_slot_serialize(unsigned char slot_idx);

/* Returns 1 if magic + checksum validate AND state was restored;
 * 0 otherwise (live RAM unmodified on failure). */
unsigned char save_slot_deserialize(unsigned char slot_idx);

/* Magic + checksum check, no side effects. 1=valid, 0=corrupt/empty. */
unsigned char save_slot_validate(unsigned char slot_idx);

/* Compute XOR checksum over bytes [0..41] of slot. Used by serialize
 * (write side) and validate (read side). Exposed so probes can corrupt
 * a slot deterministically. */
unsigned char save_slot_compute_checksum(unsigned char slot_idx);

#ifdef __cplusplus
}
#endif

#endif /* SAVE_SERIALIZER_H */
