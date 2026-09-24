/* save_game.h — persistent NES-format saves (T-100).
 *
 * The NES SaveRAM block (nes_ram[$6000..$652F], see save_serializer.h) is
 * persisted byte-for-byte to cart SRAM logical $000..$52F. Options stay at
 * $800 (sram_abi.h). Slot indices are 0..2; bad indices return 0.
 */
#ifndef SAVE_GAME_H
#define SAVE_GAME_H

/* Power-on / title Start: cart -> NES save block, then the NES file A
 * validation and slot-info copy (UpdateMode0Demo_Sub1/Sub2). */
void save_game_boot(void);

/* IsSaveSlotActive[slot] from the slot info (valid after boot). */
unsigned char save_game_slot_active(unsigned char slot);

/* NES QuestNumbers[slot]: 0 = first quest, 1 = second quest. */
unsigned char save_game_slot_quest(unsigned char slot);

/* Continue: @ChoseSlot copy of file A into the live profile. Returns 1 if
 * the slot is active and was loaded, 0 otherwise (profile untouched). */
unsigned char save_game_load_slot(unsigned char slot);

/* Mode $0D save of the live profile into CurSaveSlot ($16), then commit
 * the whole block to cart SRAM. Returns 1 on success. */
unsigned char save_game_save_current(void);

#endif /* SAVE_GAME_H */
