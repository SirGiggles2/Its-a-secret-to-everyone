/* save_game.h — persistent save/load entry points.
 *
 * save_serializer.c builds slot images in the NES RAM mirror; it does NOT
 * persist them. These three functions are the only API that reaches cart
 * SRAM, so a save actually survives power-off.
 *
 * Slot indices are 0..SAVE_SLOT_COUNT-1. Every function returns 0 on a
 * bad slot index and never traps.
 */
#ifndef SAVE_GAME_H
#define SAVE_GAME_H

/* Serialize live inventory RAM into slot_idx and commit it to cart SRAM.
 * Returns 1 on success, 0 on bad slot. */
unsigned char save_game_write_slot(unsigned char slot_idx);

/* Load slot_idx from cart SRAM and apply it to live inventory RAM.
 * Returns 1 only if magic + checksum validated; an invalid or blank slot
 * returns 0 and leaves live RAM untouched. */
unsigned char save_game_read_slot(unsigned char slot_idx);

/* Returns 1 if cart SRAM holds a valid (magic + checksum) slot_idx.
 * Does not modify live inventory RAM. Intended for File Select, which
 * must show which slots are occupied without loading them. */
unsigned char save_game_slot_is_valid(unsigned char slot_idx);

#endif /* SAVE_GAME_H */
