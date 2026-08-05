/* save_game.c — bridge the save serializer to persistent cart SRAM.
 *
 * WHY THIS EXISTS
 * ---------------
 * save_serializer.c builds a slot image in the NES RAM mirror via
 * SAVE_BYTE(off) = nes_ram[NES_SRAM_BASE + off]. In Debug.md nes_ram is
 * A4-pinned to $FF8000, so that image lives at $FFE000.
 *
 * sram_adapter.c moves data between cart SRAM and a DIFFERENT work-RAM
 * mirror at SRAM_MIRROR_BASE = $FF6000, which is below the A4 window.
 *
 * The two halves were written against different regions and never
 * connected, which is why save_slot_serialize() had no callers: writing a
 * slot updated $FFE000 and nothing ever pushed it to the cart, so every
 * save was lost at power-off.
 *
 * This TU owns the copy between the serializer image and the adapter
 * mirror, and nothing else. Slot geometry is shared and asserted below:
 * SAVE_SLOT_STRIDE (serializer) must equal SRAM_SAVE_SLOT_BYTES (adapter)
 * or the two layers disagree about where slot N begins.
 */

#include "save_game.h"
#include "save_serializer.h"
#include "save_state.h"
#include "platform_abi.h"
#include "sram_abi.h"

extern void sram_save_load(unsigned char slot, void *dst);
extern void sram_save_store(unsigned char slot, const void *src);

#ifdef __STDC_VERSION__
_Static_assert(SAVE_SLOT_STRIDE == SRAM_SAVE_SLOT_BYTES,
               "serializer slot stride must match cart SRAM slot stride");
_Static_assert(SAVE_SLOT_PAYLOAD_BYTES <= SAVE_SLOT_STRIDE,
               "slot payload must fit inside one slot stride");
#endif

/* Scratch staging buffer. One slot. Deliberately not shared with either
 * mirror so a partial copy can never corrupt the live image. */
static unsigned char s_slot_buf[SAVE_SLOT_STRIDE];

unsigned char save_game_write_slot(unsigned char slot_idx)
{
    unsigned short base;
    unsigned short i;

    if (slot_idx >= SAVE_SLOT_COUNT) {
        return 0u;
    }

    /* 1. Build the slot image in the serializer's mirror ($FFE000 region). */
    if (!save_slot_serialize(slot_idx)) {
        return 0u;
    }

    /* 2. Lift that image into a linear buffer. */
    base = (unsigned short)((unsigned short)slot_idx * SAVE_SLOT_STRIDE);
    for (i = 0u; i < SAVE_SLOT_STRIDE; ++i) {
        s_slot_buf[i] = SAVE_BYTE((unsigned short)(base + i));
    }

    /* 3. Commit to cart SRAM. sram_save_store refreshes the adapter mirror
     *    first so the other two slots are preserved, then commits all. */
    sram_save_store(slot_idx, s_slot_buf);
    return 1u;
}

unsigned char save_game_read_slot(unsigned char slot_idx)
{
    unsigned short base;
    unsigned short i;

    if (slot_idx >= SAVE_SLOT_COUNT) {
        return 0u;
    }

    /* 1. Pull the slot out of cart SRAM. */
    sram_save_load(slot_idx, s_slot_buf);

    /* 2. Lay it into the serializer's mirror. */
    base = (unsigned short)((unsigned short)slot_idx * SAVE_SLOT_STRIDE);
    for (i = 0u; i < SAVE_SLOT_STRIDE; ++i) {
        SAVE_BYTE((unsigned short)(base + i)) = s_slot_buf[i];
    }

    /* 3. Validate magic + checksum, then apply to live inventory RAM.
     *    save_slot_deserialize refuses an invalid slot, so a blank or
     *    corrupt cart cannot overwrite a live game. */
    return save_slot_deserialize(slot_idx);
}

unsigned char save_game_slot_is_valid(unsigned char slot_idx)
{
    unsigned short base;
    unsigned short i;

    if (slot_idx >= SAVE_SLOT_COUNT) {
        return 0u;
    }

    sram_save_load(slot_idx, s_slot_buf);
    base = (unsigned short)((unsigned short)slot_idx * SAVE_SLOT_STRIDE);
    for (i = 0u; i < SAVE_SLOT_STRIDE; ++i) {
        SAVE_BYTE((unsigned short)(base + i)) = s_slot_buf[i];
    }
    return save_slot_validate(slot_idx);
}
